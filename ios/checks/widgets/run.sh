#!/bin/sh
set -e
cd "$(dirname "$0")"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc ../../Tugboat/Widgets/WidgetSnapshot.swift ../../Tugboat/Widgets/WidgetStore.swift ../../Tugboat/Widgets/WidgetPendingQueue.swift main.swift -o "$out/checks"
"$out/checks"
