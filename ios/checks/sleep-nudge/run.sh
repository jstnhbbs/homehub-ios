#!/bin/sh
# Compiles SleepNudgePlanner.swift with its checks and runs them.
set -e
cd "$(dirname "$0")"
app=../../Tugboat
out="$(mktemp -d)"
swiftc -O "$app/Utilities/SleepNudgePlanner.swift" "$app/Models/NapLog.swift" "$app/Models/Profile.swift" "$app/Models/Enums.swift" "$app/Utilities/CelebrationText.swift" "$app/Models/Birthday.swift" "$app/Utilities/DateHelpers.swift" "$app/Utilities/WeekStart.swift" main.swift -o "$out/checks" 2>&1 | head -30
"$out/checks"
