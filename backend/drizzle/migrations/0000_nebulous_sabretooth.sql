CREATE TABLE `daily_usage` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`user_id` integer NOT NULL,
	`date` text NOT NULL,
	`total_requests` integer NOT NULL,
	`total_input_tokens` integer NOT NULL,
	`total_output_tokens` integer NOT NULL,
	`total_cost` real NOT NULL,
	`created_at` text NOT NULL,
	`updated_at` text NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE INDEX `idx_daily_usage_user_id` ON `daily_usage` (`user_id`);--> statement-breakpoint
CREATE INDEX `idx_daily_usage_date` ON `daily_usage` (`date`);--> statement-breakpoint
CREATE UNIQUE INDEX `unique_user_id_date` ON `daily_usage` (`user_id`,`date`);--> statement-breakpoint
CREATE TABLE `users` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`username` text NOT NULL,
	`device_id` text NOT NULL,
	`created_at` text NOT NULL,
	`last_upload_at` text,
	`last_sync_date` text,
	`total_requests` integer DEFAULT 0,
	`total_input_tokens` integer DEFAULT 0,
	`total_output_tokens` integer DEFAULT 0,
	`total_cost` real DEFAULT 0
);
--> statement-breakpoint
CREATE UNIQUE INDEX `users_username_unique` ON `users` (`username`);--> statement-breakpoint
CREATE UNIQUE INDEX `users_device_id_unique` ON `users` (`device_id`);--> statement-breakpoint
CREATE INDEX `idx_users_username` ON `users` (`username`);--> statement-breakpoint
CREATE INDEX `idx_users_device_id` ON `users` (`device_id`);--> statement-breakpoint
CREATE INDEX `idx_users_total_requests` ON `users` (`total_requests`);--> statement-breakpoint
CREATE INDEX `idx_users_total_cost` ON `users` (`total_cost`);