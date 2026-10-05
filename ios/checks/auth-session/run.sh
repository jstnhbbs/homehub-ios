#!/bin/sh
# Runs the real AuthService and APIClient against a stubbed server. Foundation only.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Models/User.swift" "$app/Services/APIClient.swift" "$app/Services/SessionCredentials.swift" "$app/Services/AuthService.swift" main.swift -o "$out/checks"
"$out/checks"
