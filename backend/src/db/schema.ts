import {
  sqliteTable,
  text,
  integer,
  real,
  index,
  uniqueIndex,
} from "drizzle-orm/sqlite-core";
import { sql } from "drizzle-orm";

export const users = sqliteTable(
  "users",
  {
    id: integer("id", { mode: "number" }).primaryKey({ autoIncrement: true }),
    username: text("username").unique().notNull(),
    deviceId: text("device_id").unique().notNull(),
    createdAt: text("created_at").notNull(),
    lastUploadAt: text("last_upload_at"),
    lastSyncDate: text("last_sync_date"),
    totalRequests: integer("total_requests").default(0),
    totalInputTokens: integer("total_input_tokens").default(0),
    totalOutputTokens: integer("total_output_tokens").default(0),
    totalCost: real("total_cost").default(0),
  },
  (table) => ({
    usernameIdx: index("idx_users_username").on(table.username),
    deviceIdIdx: index("idx_users_device_id").on(table.deviceId),
    totalRequestsIdx: index("idx_users_total_requests").on(table.totalRequests),
    totalCostIdx: index("idx_users_total_cost").on(table.totalCost),
  }),
);

export const dailyUsage = sqliteTable(
  "daily_usage",
  {
    id: integer("id", { mode: "number" }).primaryKey({ autoIncrement: true }),
    userId: text("user_id")
      .notNull()
      .references(() => users.id),
    date: text("date").notNull(),
    totalRequests: integer("total_requests").notNull(),
    totalInputTokens: integer("total_input_tokens").notNull(),
    totalOutputTokens: integer("total_output_tokens").notNull(),
    totalCost: real("total_cost").notNull(),
    createdAt: text("created_at").notNull(),
    updatedAt: text("updated_at").notNull(),
  },
  (table) => ({
    userIdIdx: index("idx_daily_usage_user_id").on(table.userId),
    dateIdx: index("idx_daily_usage_date").on(table.date),
    uniqueUserIdDate: uniqueIndex("unique_user_id_date").on(
      table.userId,
      table.date,
    ),
  }),
);

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
export type DailyUsage = typeof dailyUsage.$inferSelect;
export type NewDailyUsage = typeof dailyUsage.$inferInsert;
