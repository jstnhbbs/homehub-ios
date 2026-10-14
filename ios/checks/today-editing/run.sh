#!/bin/sh
# Compiles the Today edit-mode rules with their checks.
set -e
cd "$(dirname "$0")"
app=../../Tugboat
out="$(mktemp -d)"
swiftc -O "$app/Models/Enums.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" "$app/Utilities/TodayLayoutEditing.swift" main.swift -o "$out/checks" 2>&1 | head -30
"$out/checks"
