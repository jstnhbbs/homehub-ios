#!/bin/sh
# Exercises the real delegate waiters and notification serialization without device services.
set -e
cd "$(dirname "$0")"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -O ../../HomeHub/Utilities/AsyncCallbackWaiters.swift ../../HomeHub/Utilities/NotificationWorkQueue.swift main.swift -o "$out/checks"
"$out/checks"
