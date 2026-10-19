#!/bin/sh
# Compiles WelcomeTour.swift with its checks and runs them. Foundation only.
set -e
cd "$(dirname "$0")"
out="$(mktemp -d)"
swiftc -O ../../Tugboat/Utilities/WelcomeTour.swift main.swift -o "$out/checks"
"$out/checks"
