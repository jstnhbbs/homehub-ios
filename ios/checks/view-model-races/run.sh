#!/bin/sh
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -O "$app/ViewModels/MealsViewModel.swift" "$app/ViewModels/SnacksViewModel.swift" \
  "$app/Models/Enums.swift" "$app/Models/Birthday.swift" "$app/Models/Profile.swift" \
  "$app/Models/Meal.swift" "$app/Models/Recipe.swift" "$app/Models/Grocery.swift" \
  "$app/Utilities/CelebrationText.swift" "$app/Utilities/DateHelpers.swift" "$app/Utilities/WeekStart.swift" \
  "$app/Utilities/MealPlanHelpers.swift" "$app/Utilities/RecipeFormHelpers.swift" "$app/Utilities/RecipeLines.swift" \
  "$app/Utilities/IngredientMerge.swift" "$app/Utilities/SnackHelpers.swift" main.swift -o "$out/checks"
"$out/checks"
