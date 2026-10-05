#!/bin/sh
# Compiles the Crouton import models and file helpers with their checks. Foundation and ImageIO only.
set -e
cd "$(dirname "$0")"
app=../../HomeHub
out="$(mktemp -d)"
swiftc -O "$app/Models/CroutonRecipe.swift" "$app/Utilities/CroutonImport.swift" main.swift -o "$out/checks"
"$out/checks"
