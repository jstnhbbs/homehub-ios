ALTER TABLE `households` ADD `weather_location` text DEFAULT 'Chicago, IL' NOT NULL;
ALTER TABLE `households` ADD `weather_latitude` text DEFAULT '41.8781' NOT NULL;
ALTER TABLE `households` ADD `weather_longitude` text DEFAULT '-87.6298' NOT NULL;

CREATE TABLE `shopping_items` (
  `id` text PRIMARY KEY NOT NULL,
  `household_id` text NOT NULL,
  `title` text NOT NULL,
  `quantity` text,
  `category` text DEFAULT 'Other' NOT NULL,
  `checked` integer DEFAULT 0 NOT NULL,
  `checked_at` integer,
  `sort_order` integer DEFAULT 0 NOT NULL,
  `created_at` integer NOT NULL,
  `updated_at` integer NOT NULL,
  FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE INDEX `shopping_items_household_idx` ON `shopping_items` (`household_id`);
CREATE INDEX `shopping_items_checked_idx` ON `shopping_items` (`household_id`,`checked`);

CREATE TABLE `household_notes` (
  `id` text PRIMARY KEY NOT NULL,
  `household_id` text NOT NULL,
  `created_by_user_id` text,
  `title` text NOT NULL,
  `body` text DEFAULT '' NOT NULL,
  `color` text DEFAULT '#f8e8bf' NOT NULL,
  `pinned` integer DEFAULT 1 NOT NULL,
  `created_at` integer NOT NULL,
  `updated_at` integer NOT NULL,
  FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON UPDATE no action ON DELETE cascade,
  FOREIGN KEY (`created_by_user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE set null
);
CREATE INDEX `household_notes_household_idx` ON `household_notes` (`household_id`);
CREATE INDEX `household_notes_pinned_idx` ON `household_notes` (`household_id`,`pinned`);

CREATE TABLE `family_birthdays` (
  `id` text PRIMARY KEY NOT NULL,
  `household_id` text NOT NULL,
  `profile_id` text,
  `name` text NOT NULL,
  `birth_date` text NOT NULL,
  `notes` text,
  `gift_ideas` text,
  `notify_days_before` integer DEFAULT 7 NOT NULL,
  `created_at` integer NOT NULL,
  `updated_at` integer NOT NULL,
  FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON UPDATE no action ON DELETE cascade,
  FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE INDEX `family_birthdays_household_idx` ON `family_birthdays` (`household_id`);
CREATE INDEX `family_birthdays_profile_idx` ON `family_birthdays` (`profile_id`);

CREATE TABLE `school_subjects` (
  `id` text PRIMARY KEY NOT NULL,
  `household_id` text NOT NULL,
  `name` text NOT NULL,
  `color` text DEFAULT '#6689a3' NOT NULL,
  `pack_items` text DEFAULT '' NOT NULL,
  `sort_order` integer DEFAULT 0 NOT NULL,
  `created_at` integer NOT NULL,
  `updated_at` integer NOT NULL,
  FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE INDEX `school_subjects_household_idx` ON `school_subjects` (`household_id`);

CREATE TABLE `school_periods` (
  `id` text PRIMARY KEY NOT NULL,
  `household_id` text NOT NULL,
  `label` text NOT NULL,
  `starts_at` text DEFAULT '08:00' NOT NULL,
  `ends_at` text DEFAULT '08:45' NOT NULL,
  `sort_order` integer DEFAULT 0 NOT NULL,
  `created_at` integer NOT NULL,
  `updated_at` integer NOT NULL,
  FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE INDEX `school_periods_household_idx` ON `school_periods` (`household_id`);

CREATE TABLE `school_schedule_entries` (
  `id` text PRIMARY KEY NOT NULL,
  `household_id` text NOT NULL,
  `profile_id` text,
  `subject_id` text NOT NULL,
  `period_id` text NOT NULL,
  `weekday` integer NOT NULL,
  `room` text,
  `notes` text,
  `created_at` integer NOT NULL,
  `updated_at` integer NOT NULL,
  FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON UPDATE no action ON DELETE cascade,
  FOREIGN KEY (`profile_id`) REFERENCES `profiles`(`id`) ON UPDATE no action ON DELETE cascade,
  FOREIGN KEY (`subject_id`) REFERENCES `school_subjects`(`id`) ON UPDATE no action ON DELETE cascade,
  FOREIGN KEY (`period_id`) REFERENCES `school_periods`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE INDEX `school_schedule_household_day_idx` ON `school_schedule_entries` (`household_id`,`weekday`);
CREATE UNIQUE INDEX `school_schedule_slot_idx` ON `school_schedule_entries` (`household_id`,`profile_id`,`period_id`,`weekday`);

CREATE TABLE `notification_preferences` (
  `id` text PRIMARY KEY NOT NULL,
  `household_id` text NOT NULL,
  `user_id` text NOT NULL,
  `calendar_reminders` integer DEFAULT 1 NOT NULL,
  `chore_digest` integer DEFAULT 1 NOT NULL,
  `birthday_reminders` integer DEFAULT 1 NOT NULL,
  `school_reminders` integer DEFAULT 1 NOT NULL,
  `quiet_start` text DEFAULT '20:30' NOT NULL,
  `quiet_end` text DEFAULT '07:00' NOT NULL,
  `created_at` integer NOT NULL,
  `updated_at` integer NOT NULL,
  FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON UPDATE no action ON DELETE cascade,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE UNIQUE INDEX `notification_preferences_user_household_idx` ON `notification_preferences` (`household_id`,`user_id`);

CREATE TABLE `recycle_bin_items` (
  `id` text PRIMARY KEY NOT NULL,
  `household_id` text NOT NULL,
  `item_type` text NOT NULL,
  `item_id` text NOT NULL,
  `label` text NOT NULL,
  `snapshot` text NOT NULL,
  `deleted_at` integer NOT NULL,
  `restore_by` integer,
  FOREIGN KEY (`household_id`) REFERENCES `households`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE INDEX `recycle_bin_household_idx` ON `recycle_bin_items` (`household_id`);
CREATE INDEX `recycle_bin_type_idx` ON `recycle_bin_items` (`household_id`,`item_type`);
