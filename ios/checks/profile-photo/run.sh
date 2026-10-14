#!/bin/sh
set -e
cd "$(dirname "$0")"
sim="${1:?Pass a booted simulator UDID}"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun --sdk iphonesimulator swiftc -sdk "$sdk" -target arm64-apple-ios17.0-simulator \
  ../../Tugboat/Utilities/ImageDownsampling.swift ../../Tugboat/Utilities/ProfilePhotoHelpers.swift \
  main.swift -o "$out/checks"
xcrun simctl spawn "$sim" "$out/checks"
