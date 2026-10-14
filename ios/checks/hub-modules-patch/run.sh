#!/bin/sh
set -e
cd "$(dirname "$0")"
app=../../Tugboat
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -O "$app/Models/Enums.swift" "$app/Models/Birthday.swift" "$app/Utilities/CelebrationText.swift" "$app/Utilities/HubModulesPatch.swift" main.swift -o "$out/checks"
"$out/checks"
