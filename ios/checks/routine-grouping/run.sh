#!/bin/sh
# Compiles RoutineGrouping.swift with its checks and runs them. Foundation only.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/WeekStart.swift" "$app/Utilities/DateHelpers.swift" "$app/Utilities/RoutineGrouping.swift" "$app/Models/Enums.swift" "$app/Models/Routine.swift" "$app/Models/Profile.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" main.swift -o "$out/checks" 2>&1
"$out/checks"
