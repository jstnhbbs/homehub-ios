#!/bin/sh
# Compiles the Schedule card's wording and ordering with its checks.
set -e
cd "$(dirname "$0")"
app=../../Tugboat
out="$(mktemp -d)"
swiftc -O "$app/Utilities/ScheduleCardSummary.swift" "$app/Utilities/DashboardHelpers.swift" "$app/Utilities/WeekStart.swift" "$app/Utilities/DateHelpers.swift" "$app/Models/Calendar.swift" "$app/Models/Enums.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" main.swift -o "$out/checks" 2>&1 | head -30
"$out/checks"
