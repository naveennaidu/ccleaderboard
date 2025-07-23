import { Hono } from "hono";
import { logger } from "hono/logger";
import { compress } from "hono/compress";
import { timing } from "hono/timing";
import type { CloudflareBindings } from "./types";
import { corsMiddleware, rateLimitMiddleware } from "./middleware";
import usersRoute from "./routes/users";
import usageRoute from "./routes/usage";
import leaderboardRoute from "./routes/leaderboard";

const app = new Hono<{ Bindings: CloudflareBindings }>();

// Global middleware
app.use("*", logger());
app.use("*", timing());
app.use("*", corsMiddleware());
app.use("/api/*", rateLimitMiddleware);

// Health check
app.get("/", (c) => {
  return c.json({
    service: "CC Leaderboard API",
    version: "1.0.0",
    status: "healthy",
  });
});

// API routes
app.route("/api/v1/users", usersRoute);
app.route("/api/v1/usage", usageRoute);
app.route("/api/v1/leaderboard", leaderboardRoute);

// 404 handler
app.notFound((c) => {
  return c.json({ error: "Not found" }, 404);
});

// Error handler
app.onError((err, c) => {
  console.error("Unhandled error:", err);
  return c.json({ error: "Internal server error" }, 500);
});

export default app;
