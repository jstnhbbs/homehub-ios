#!/bin/sh
# Compiles the image downsampling helper with its checks. Foundation, CoreGraphics and ImageIO only.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/ImageDownsampling.swift" main.swift -o "$out/checks"
"$out/checks"
