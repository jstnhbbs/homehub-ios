-- Identifies where an imported recipe came from ("crouton:<id from the export>"), so importing the
-- same export a second time recognises what is already here instead of adding every recipe again.
-- Recipes added any other way leave it empty, and an empty key never counts as a duplicate.
ALTER TABLE `recipes` ADD `import_key` text;
--> statement-breakpoint
CREATE UNIQUE INDEX `recipes_household_import_key_idx` ON `recipes` (`household_id`, `import_key`) WHERE `import_key` IS NOT NULL;
