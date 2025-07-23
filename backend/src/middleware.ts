import { Context, Next } from "hono";
import type { CloudflareBindings } from "./types";

const RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute
const RATE_LIMIT_MAX_REQUESTS = 100;

export async function rateLimitMiddleware(
  c: Context<{ Bindings: CloudflareBindings }>,
  next: Next,
) {
  const ip =
    c.req.header("CF-Connecting-IP") ||
    c.req.header("X-Forwarded-For") ||
    "unknown";
  const key = `rate_limit:${ip}`;

  try {
    const currentTime = Date.now();
    const windowStart = currentTime - RATE_LIMIT_WINDOW;

    const rateLimitData = (await c.env.KV.get(key, { type: "json" })) as {
      requests: number[];
      windowStart: number;
    } | null;

    let requests: number[] = [];
    if (rateLimitData) {
      requests = rateLimitData.requests.filter(
        (timestamp) => timestamp > windowStart,
      );
    }

    if (requests.length >= RATE_LIMIT_MAX_REQUESTS) {
      return c.json({ error: "Rate limit exceeded" }, 429);
    }

    requests.push(currentTime);

    await c.env.KV.put(key, JSON.stringify({ requests, windowStart }), {
      expirationTtl: Math.ceil(RATE_LIMIT_WINDOW / 1000),
    });

    await next();
  } catch (error) {
    console.error("Rate limit error:", error);
    await next();
  }
}

export function corsMiddleware() {
  return async (c: Context, next: Next) => {
    c.header("Access-Control-Allow-Origin", "*");
    c.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    c.header("Access-Control-Allow-Headers", "Content-Type, Authorization");
    c.header("Access-Control-Max-Age", "86400");

    if (c.req.method === "OPTIONS") {
      return new Response(null, { status: 204 });
    }

    await next();
  };
}
