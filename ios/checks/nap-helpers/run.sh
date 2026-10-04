#!/bin/sh
# Compiles the date and sleep helpers, the nap models and the Profile model with their checks. The
# checks run under three device time zones, since the household's zone (not the device's) is what
# the helpers must follow.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Utilities/DateHelpers.swift" "$app/Utilities/WeekStart.swift" "$app/Utilities/NapHelpers.swift" "$app/Models/NapLog.swift" "$app/Models/Profile.swift" "$app/Models/Enums.swift" "$app/Utilities/CelebrationText.swift" "$app/Models/Birthday.swift" main.swift -o "$out/checks"
for zone in America/Chicago Pacific/Auckland UTC; do
    echo "-- device time zone: $zone"
    TZ="$zone" "$out/checks"
done
