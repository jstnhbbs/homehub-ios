#!/bin/sh
# Compiles the Routines card's ordering and wording with its checks.
set -e
cd "$(dirname "$0")"
app=../../Tugboat
out="$(mktemp -d)"
swiftc -O "$app/Utilities/RoutineCardSummary.swift" "$app/Models/Routine.swift" "$app/Models/Enums.swift" "$app/Models/Profile.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" main.swift -o "$out/checks" 2>&1 | head -30
"$out/checks"
