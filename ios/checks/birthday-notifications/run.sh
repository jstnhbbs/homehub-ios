#!/bin/sh
# Compiles the birthday reminder planner and notification settings with their checks. Foundation only.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/BirthdayNotificationPlanner.swift" "$app/Utilities/CelebrationText.swift" "$app/Models/NotificationSettings.swift" "$app/Utilities/DateHelpers.swift" "$app/Utilities/WeekStart.swift" "$app/Models/Birthday.swift" main.swift -o "$out/checks"
"$out/checks"
