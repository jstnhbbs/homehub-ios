#!/bin/sh
# Compiles the shared date formatting with its checks. Foundation only.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/WeekStart.swift" "$app/Utilities/DateHelpers.swift" "$app/Utilities/CalendarHelpers.swift" "$app/Models/Calendar.swift" "$app/Models/Enums.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" main.swift -o "$out/checks"
"$out/checks"
