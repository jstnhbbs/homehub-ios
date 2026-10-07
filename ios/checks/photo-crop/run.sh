#!/bin/sh
# Compiles PhotoCropGeometry.swift with its checks and runs them. Foundation and CoreGraphics only.
set -e
cd "$(dirname "$0")"
out="$(mktemp -d)"
swiftc -O ../../HomeHub/Utilities/PhotoCropGeometry.swift main.swift -o "$out/checks"
"$out/checks"
