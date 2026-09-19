#!/bin/sh
# Compiles the meal-plan helpers with their checks and runs them. Foundation only, no Xcode project needed.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/MealPlanHelpers.swift" "$app/Utilities/DateHelpers.swift" "$app/Utilities/WeekStart.swift" "$app/Models/Meal.swift" "$app/Models/Enums.swift" main.swift -o "$out/checks"
"$out/checks"
