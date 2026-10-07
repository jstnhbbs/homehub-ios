#!/bin/sh
# Runs the real RoutinesViewModel against an observable stand-in AppState.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -O "$app/ViewModels/RoutinesViewModel.swift" "$app/Utilities/WeekStart.swift" "$app/Utilities/DateHelpers.swift" "$app/Utilities/RoutineGrouping.swift" "$app/Utilities/CompletionHelpers.swift" "$app/Models/Enums.swift" "$app/Models/Routine.swift" "$app/Models/Profile.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" main.swift -o "$out/checks"
"$out/checks"
