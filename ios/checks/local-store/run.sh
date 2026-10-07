#!/bin/sh
# Exercises the real cache with SwiftData on a temporary disk store.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -O "$app/Services/HomeHubLocalStore.swift" "$app/Utilities/LocalStoreLocation.swift" "$app/Utilities/CelebrationText.swift" "$app/Models/Enums.swift" "$app/Models/Household.swift" "$app/Models/User.swift" "$app/Models/Dashboard.swift" "$app/Models/Profile.swift" "$app/Models/Routine.swift" "$app/Models/Chore.swift" "$app/Models/Meal.swift" "$app/Models/Calendar.swift" "$app/Models/NapLog.swift" "$app/Models/Grocery.swift" "$app/Models/Birthday.swift" main.swift -o "$out/checks"
"$out/checks" "$out" "$@"
