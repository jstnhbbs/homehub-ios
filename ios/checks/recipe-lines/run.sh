#!/bin/sh
# Compiles RecipeLines.swift with its checks and runs them. Foundation only.
set -e
cd "$(dirname "$0")"
out="$(mktemp -d)"
swiftc -O ../../HomeHub/Utilities/RecipeLines.swift main.swift -o "$out/checks"
"$out/checks"
