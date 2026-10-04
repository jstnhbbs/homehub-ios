#!/bin/sh
# Compiles SnackHelpers.swift with its checks and runs them. Foundation only; main.swift declares
# the one model type SnackHelpers needs, so the whole app does not have to be compiled.
set -e
cd "$(dirname "$0")"
out="$(mktemp -d)"
swiftc -O ../../HomeHub/Utilities/SnackHelpers.swift main.swift -o "$out/checks"
"$out/checks"
