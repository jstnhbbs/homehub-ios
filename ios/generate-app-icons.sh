#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${ROOT}/public/icons/icon-512.png"
OUT="${ROOT}/ios/HomeHub/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing source icon: $SOURCE" >&2
  exit 1
fi

mkdir -p "$OUT"

render() {
  local name="$1"
  local size="$2"
  sips -z "$size" "$size" "$SOURCE" --out "${OUT}/${name}" >/dev/null
}

# iPad + App Store sizes (generated from the PWA icon set).
render "Icon-20.png" 20
render "Icon-20@2x.png" 40
render "Icon-29.png" 29
render "Icon-29@2x.png" 58
render "Icon-40.png" 40
render "Icon-40@2x.png" 80
render "Icon-76.png" 76
render "Icon-76@2x.png" 152
render "Icon-83.5@2x.png" 167
render "Icon-1024.png" 1024

cat > "${OUT}/Contents.json" <<'EOF'
{
  "images" : [
    {
      "filename" : "Icon-20@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-20.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-29@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-29.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-40@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-40.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-76@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-76.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-83.5@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "filename" : "Icon-1024.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "Wrote AppIcon.appiconset from ${SOURCE}"
