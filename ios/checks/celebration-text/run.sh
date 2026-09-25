#!/bin/sh
# Compiles the celebration wording helpers with their checks. Foundation only.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/CelebrationText.swift" "$app/Models/Birthday.swift" main.swift -o "$out/checks"
"$out/checks"
