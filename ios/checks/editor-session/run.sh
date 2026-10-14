#!/bin/sh
set -e
cd "$(dirname "$0")"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc ../../HomeHub/ViewModels/EditorSession.swift main.swift -o "$out/checks"
"$out/checks"
