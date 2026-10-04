ALTER TABLE `households` ADD `snacks_per_child` integer DEFAULT 0 NOT NULL;
--> statement-breakpoint
CREATE TABLE `snack_completions_new` (
	`household_id` text NOT NULL,
	`local_date` text NOT NULL,
	`snack_label` text NOT NULL,
	`profile_id` text DEFAULT '' NOT NULL,
	`completed_at` integer NOT NULL,
	PRIMARY KEY(`household_id`, `local_date`, `snack_label`, `profile_id`),
	FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
INSERT INTO `snack_completions_new` (`household_id`, `local_date`, `snack_label`, `profile_id`, `completed_at`)
SELECT `household_id`, `local_date`, `snack_label`, '', `completed_at` FROM `snack_completions`;
--> statement-breakpoint
DROP TABLE `snack_completions`;
--> statement-breakpoint
ALTER TABLE `snack_completions_new` RENAME TO `snack_completions`;
--> statement-breakpoint
CREATE INDEX `snack_completions_date_idx` ON `snack_completions` (`local_date`);
