#!/bin/sh
# Compiles MealSlotClock.swift with its checks and runs them. Foundation only.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/MealSlotClock.swift" "$app/Models/Enums.swift" main.swift -o "$out/checks"
"$out/checks"
