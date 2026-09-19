ALTER TABLE `routine_completions` ADD `completed_by` text REFERENCES `users`(`id`) ON DELETE SET NULL;--> statement-breakpoint
ALTER TABLE `chore_completions` ADD `completed_by` text REFERENCES `users`(`id`) ON DELETE SET NULL;
