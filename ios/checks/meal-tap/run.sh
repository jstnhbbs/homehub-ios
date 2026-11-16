#!/bin/sh
# Compiles the rules for what a tap on a meal does, with their checks.
set -e
cd "$(dirname "$0")"
app=../../Tugboat
out="$(mktemp -d)"
swiftc -O "$app/Utilities/MealTap.swift" "$app/Models/Meal.swift" "$app/Models/Enums.swift" "$app/Models/Calendar.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" "$app/Utilities/DateHelpers.swift" "$app/Utilities/WeekStart.swift" main.swift -o "$out/checks" 2>&1 | head -30
"$out/checks"
