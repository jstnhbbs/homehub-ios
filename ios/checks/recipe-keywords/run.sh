#!/bin/sh
# Compiles RecipeKeywords.swift with its checks and runs them. Foundation only.
set -e
cd "$(dirname "$0")"
out="$(mktemp -d)"
d=../../Tugboat/Utilities
swiftc -O $d/RecipeKeywords.swift $d/RecipeIngredientParts.swift $d/RecipeLines.swift main.swift -o "$out/checks"
"$out/checks"
