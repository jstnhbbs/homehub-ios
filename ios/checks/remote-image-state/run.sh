#!/bin/sh
# Checks the real photo state used by RemoteImage, without network access or UIKit.
set -e
cd "$(dirname "$0")"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -O ../../HomeHub/Utilities/RemoteImageState.swift main.swift -o "$out/checks"
"$out/checks"
