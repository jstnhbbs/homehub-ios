CREATE TABLE `recipes` (
	`id` text PRIMARY KEY NOT NULL,
	`household_id` text NOT NULL,
	`title` text NOT NULL,
	`description` text,
	`servings` text,
	`prep_time` text,
	`cook_time` text,
	`total_time` text,
	`ingredients` text DEFAULT '[]' NOT NULL,
	`directions` text DEFAULT '[]' NOT NULL,
	`nutrition` text,
	`source_url` text,
	`image_url` text,
	`notes` text,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `recipes_household_idx` ON `recipes` (`household_id`);