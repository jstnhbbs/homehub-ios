#!/bin/sh
set -e
cd "$(dirname "$0")"
app=../../Tugboat
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -parse-as-library "$app/Widgets/WidgetSync.swift" "$app/Widgets/WidgetSnapshot.swift" \
 "$app/Widgets/WidgetPendingQueue.swift" "$app/Widgets/WidgetStore.swift" \
 "$app/Services/APIClient.swift" "$app/Services/SessionCredentials.swift" main.swift -o "$out/checks"
"$out/checks"
