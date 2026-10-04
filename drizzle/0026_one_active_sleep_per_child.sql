-- A child can only be asleep once. The app already checks before it starts a sleep, but two requests
-- at the same moment (two parents tapping together, or a retry) could both pass that check and leave
-- a child with two running sleeps. This makes the database refuse the second one.
--
-- Any child who already has more than one running sleep keeps the newest and has the older ones
-- ended at the moment the next one began, so the index below can be created on real data.
UPDATE `nap_logs`
SET
	`ended_at` = (
		SELECT MIN(`later`.`started_at`)
		FROM `nap_logs` AS `later`
		WHERE `later`.`profile_id` = `nap_logs`.`profile_id`
			AND `later`.`ended_at` IS NULL
			AND (
				`later`.`started_at` > `nap_logs`.`started_at`
				OR (`later`.`started_at` = `nap_logs`.`started_at` AND `later`.`id` > `nap_logs`.`id`)
			)
	),
	`updated_at` = CAST(strftime('%s', 'now') AS integer)
WHERE `ended_at` IS NULL
	AND EXISTS (
		SELECT 1
		FROM `nap_logs` AS `later`
		WHERE `later`.`profile_id` = `nap_logs`.`profile_id`
			AND `later`.`ended_at` IS NULL
			AND (
				`later`.`started_at` > `nap_logs`.`started_at`
				OR (`later`.`started_at` = `nap_logs`.`started_at` AND `later`.`id` > `nap_logs`.`id`)
			)
	);
--> statement-breakpoint
CREATE UNIQUE INDEX `nap_logs_one_active_per_profile_idx` ON `nap_logs` (`profile_id`) WHERE `ended_at` IS NULL;
