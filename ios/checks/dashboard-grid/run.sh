#!/bin/sh
# Compiles the Today grid packer and the card sizes with their checks.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Models/Enums.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" "$app/Utilities/DashboardGridPacker.swift" main.swift -o "$out/checks" 2>&1 | head -30
"$out/checks"
