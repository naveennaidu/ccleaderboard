import type { Config } from "drizzle-kit";

export default {
  schema: "./src/db/schema.ts",
  out: "./drizzle/migrations",
  dialect: "sqlite",
  driver: "d1-http",
  dbCredentials: {
    accountId: "972c5fb5dd57c85bbd9093c792f56a17",
    databaseId: "2d0902ba-5661-4edf-9db9-0c8cdaa9d285",
    token: "3SDIrTkt80qXVx7fN0qKUEb_7-EUBKVE1tJBLGg5",
  },
} satisfies Config;
