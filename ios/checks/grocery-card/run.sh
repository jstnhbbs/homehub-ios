#!/bin/sh
# Compiles the Groceries card's grouping and column fitting with their checks.
set -e
cd "$(dirname "$0")"
app=../../Tugboat
out="$(mktemp -d)"
swiftc -O "$app/Utilities/ColumnFit.swift" "$app/Utilities/GroceryCardSummary.swift" "$app/Models/Grocery.swift" main.swift -o "$out/checks" 2>&1 | head -30
"$out/checks"
