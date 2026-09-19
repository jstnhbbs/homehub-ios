#!/bin/sh
# Compiles IngredientMerge.swift with its checks and runs them. Foundation only, no Xcode project needed.
set -e
cd "$(dirname "$0")"
out="$(mktemp -d)"
swiftc -O ../../HomeHub/Utilities/IngredientMerge.swift main.swift -o "$out/checks"
"$out/checks"
