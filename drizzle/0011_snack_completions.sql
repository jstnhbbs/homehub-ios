CREATE TABLE `snack_completions` (
	`household_id` text NOT NULL,
	`local_date` text NOT NULL,
	`snack_label` text NOT NULL,
	`completed_at` integer NOT NULL,
	PRIMARY KEY(`household_id`, `local_date`, `snack_label`),
	FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `snack_completions_date_idx` ON `snack_completions` (`local_date`);
