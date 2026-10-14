#!/bin/sh
# Compiles the Sleep card's wording and log with its checks.
set -e
cd "$(dirname "$0")"
app=../../Tugboat
out="$(mktemp -d)"
swiftc -O "$app/Utilities/SleepCardSummary.swift" "$app/Utilities/DateHelpers.swift" "$app/Utilities/WeekStart.swift" "$app/Utilities/NapHelpers.swift" "$app/Models/NapLog.swift" "$app/Models/Profile.swift" "$app/Models/Enums.swift" "$app/Utilities/CelebrationText.swift" "$app/Models/Birthday.swift" main.swift -o "$out/checks" 2>&1 | head -30
TZ=UTC "$out/checks"
