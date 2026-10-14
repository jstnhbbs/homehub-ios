#!/bin/sh
set -e
cd "$(dirname "$0")"
app=../../Tugboat
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc "$app/Services/APIClient.swift" "$app/Services/SessionCredentials.swift" \
  "$app/ViewModels/EditorSession.swift" "$app/ViewModels/NoteComposer.swift" main.swift -o "$out/checks"
"$out/checks"
