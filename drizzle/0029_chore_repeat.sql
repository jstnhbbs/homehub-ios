ALTER TABLE `chores` ADD `repeat_unit` text DEFAULT 'day' NOT NULL;--> statement-breakpoint
ALTER TABLE `chores` ADD `repeat_interval` integer DEFAULT 1 NOT NULL;--> statement-breakpoint
ALTER TABLE `chores` ADD `due_time` text;--> statement-breakpoint
UPDATE `chores` SET `repeat_unit` = 'week' WHERE `cadence` = 'weekly';
