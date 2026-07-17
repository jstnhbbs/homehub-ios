ALTER TABLE `households` ADD `guest_invite_code` text;--> statement-breakpoint
UPDATE `households` SET `guest_invite_code` = upper(hex(randomblob(4))) WHERE `guest_invite_code` IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX `households_guest_invite_code_unique` ON `households` (`guest_invite_code`);
