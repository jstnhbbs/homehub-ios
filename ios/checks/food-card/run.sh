#!/bin/sh
# Compiles the Food card's wording and its week with their checks.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/FoodCardSummary.swift" "$app/Utilities/DashboardHelpers.swift" "$app/Utilities/WeekStart.swift" "$app/Utilities/DateHelpers.swift" "$app/Models/Meal.swift" "$app/Models/Calendar.swift" "$app/Models/Enums.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" main.swift -o "$out/checks" 2>&1 | head -30
"$out/checks"
