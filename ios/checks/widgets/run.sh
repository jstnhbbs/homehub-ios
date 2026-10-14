#!/bin/sh
set -e
cd "$(dirname "$0")"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc ../../HomeHub/Widgets/WidgetSnapshot.swift ../../HomeHub/Widgets/WidgetStore.swift main.swift -o "$out/checks"
"$out/checks"
