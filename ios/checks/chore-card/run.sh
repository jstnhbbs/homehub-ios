#!/bin/sh
# Compiles the Chores card's wording and ordering with its checks.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/WeekStart.swift" "$app/Utilities/DateHelpers.swift" "$app/Utilities/ChoreHelpers.swift" "$app/Utilities/ChoreCardSummary.swift" "$app/Models/Enums.swift" "$app/Models/Chore.swift" "$app/Models/Profile.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" main.swift -o "$out/checks" 2>&1 | head -30
"$out/checks"
