#!/bin/sh
# Compiles the Celebrations card's wording and grouping with its checks.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/CalendarHelpers.swift" "$app/Utilities/CelebrationCardSummary.swift" "$app/Utilities/BirthdayHelpers.swift" "$app/Utilities/DateHelpers.swift" "$app/Utilities/WeekStart.swift" "$app/Models/Birthday.swift" "$app/Models/Calendar.swift" "$app/Models/Profile.swift" "$app/Models/Enums.swift" "$app/Utilities/CelebrationText.swift" main.swift -o "$out/checks" 2>&1 | head -30
"$out/checks"
