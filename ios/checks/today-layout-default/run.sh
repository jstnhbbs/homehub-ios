#!/bin/sh
# Compiles the saved Today layout with its checks.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Models/Enums.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" "$app/Utilities/TodayLayoutDefault.swift" main.swift -o "$out/checks" 2>&1 | head -30
"$out/checks"
