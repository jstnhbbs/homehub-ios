-- Five tables nothing reads or writes any more.
--
-- school_*: a school-schedule feature that was "parked" and never built in the iOS app.
-- notification_preferences: reminders are scheduled on the device now, from settings kept on the device.
-- recycle_bin_items: the server saved a copy of every deleted grocery here, but there is no screen (web or
--   iOS) that can show or restore them, so the rows only piled up.
--
-- Dropped children first: the schedule entries point at the subjects and periods. Their indexes go with them.
DROP TABLE `school_schedule_entries`;
--> statement-breakpoint
DROP TABLE `school_subjects`;
--> statement-breakpoint
DROP TABLE `school_periods`;
--> statement-breakpoint
DROP TABLE `notification_preferences`;
--> statement-breakpoint
DROP TABLE `recycle_bin_items`;
