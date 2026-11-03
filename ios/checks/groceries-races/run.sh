#!/bin/sh
set -e
cd "$(dirname "$0")"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -parse-as-library ../../Tugboat/ViewModels/GroceriesViewModel.swift main.swift -o "$out/checks"
"$out/checks"
