#!/bin/sh
# Compiles BirthdayTodayHelpers.swift with its checks and runs them. Foundation only.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/BirthdayTodayHelpers.swift" "$app/Models/Birthday.swift" main.swift -o "$out/checks"
"$out/checks"
