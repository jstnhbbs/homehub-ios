ALTER TABLE `shopping_items` RENAME TO `grocery_items`;--> statement-breakpoint
DROP INDEX IF EXISTS `shopping_items_household_idx`;--> statement-breakpoint
DROP INDEX IF EXISTS `shopping_items_checked_idx`;--> statement-breakpoint
CREATE INDEX `grocery_items_household_idx` ON `grocery_items` (`household_id`);--> statement-breakpoint
CREATE INDEX `grocery_items_checked_idx` ON `grocery_items` (`household_id`,`checked`);--> statement-breakpoint
UPDATE `recycle_bin_items` SET `item_type` = 'grocery_item' WHERE `item_type` = 'shopping_item';--> statement-breakpoint
UPDATE `users` SET `hub_modules` = REPLACE(`hub_modules`, '"shopping"', '"groceries"') WHERE `hub_modules` LIKE '%"shopping"%';
