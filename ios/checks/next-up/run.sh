#!/bin/sh
# Compiles the Today banner's "next timed item" rule with its checks.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/NextUpSummary.swift" "$app/Utilities/ChoreHelpers.swift" "$app/Utilities/DateHelpers.swift" "$app/Utilities/WeekStart.swift" "$app/Models/Chore.swift" "$app/Models/Calendar.swift" "$app/Models/Profile.swift" "$app/Models/Enums.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" main.swift -o "$out/checks" 2>&1 | head -30
TZ=UTC "$out/checks"
