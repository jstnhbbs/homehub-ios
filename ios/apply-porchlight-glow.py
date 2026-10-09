#!/usr/bin/env python3
"""Gives each Beacon*.icon bundle its porch light: a warm glow behind the doorway and a warm door.

The glow is its own layer (glow.svg, a radial gradient clipped to the house) between the house and the
doorway, so each theme's house color keeps coming from icon.json. Safe to run again: it rewrites the
glow and the door color and leaves the layer list alone once the glow layer is there.

Sunflower's house is already the color of the light, so its glow is a deeper amber instead.
A *light* glow (white or cream) must not be used: Icon Composer's dark rendition turns it into an
opaque house-shaped fill.

    python3 ios/apply-porchlight-glow.py
"""
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
GLOWS = {"BeaconOchre": ("#e8962b", 0.55)}   # everything else: ("#ffd36b", 0.6)
DEFAULT_GLOW = ("#ffd36b", 0.6)
WARM_DOOR = "#fff4d6"
# icon.json draws the house at scale 1.24, nudged down 53.78; the clip path has to match exactly.
HOUSE_TRANSFORM = "translate(512.02 565.78) scale(1.24) translate(-512 -512)"
CENTER_X, CENTER_Y, RADIUS = 512, 650, 430   # the middle of the doorway

for bundle in sorted(ROOT.glob("Beacon*.icon")):
    assets = bundle / "Assets"
    color, opacity = GLOWS.get(bundle.stem, DEFAULT_GLOW)
    house_path = re.search(r'<path\s+d="([^"]+)"', (assets / "house.svg").read_text()).group(1)
    (assets / "glow.svg").write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <clipPath id="glow-clip"><path transform="{HOUSE_TRANSFORM}" d="{house_path}"/></clipPath>
    <radialGradient id="glow-fill" gradientUnits="userSpaceOnUse" cx="{CENTER_X}" cy="{CENTER_Y}" r="{RADIUS}">
      <stop offset="0" stop-color="{color}" stop-opacity="{opacity}"/>
      <stop offset=".55" stop-color="{color}" stop-opacity="{opacity * 0.45:.3f}"/>
      <stop offset="1" stop-color="{color}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <g clip-path="url(#glow-clip)"><circle cx="{CENTER_X}" cy="{CENTER_Y}" r="{RADIUS}" fill="url(#glow-fill)"/></g>
</svg>
''')
    door = assets / "doorway-panel.svg"
    door.write_text(re.sub(r'fill="#[0-9a-fA-F]{6}"', f'fill="{WARM_DOOR}"', door.read_text()))

    icon_json = bundle / "icon.json"
    data = json.loads(icon_json.read_text())
    layers = data["groups"][0]["layers"]
    layers[:] = [layer for layer in layers if layer["name"] != "sun"]
    if not any(layer["name"] == "glow" for layer in layers):
        at = next(i for i, layer in enumerate(layers) if layer["name"] == "house")
        layers.insert(at, {"image-name": "glow.svg", "name": "glow"})
    # Icon Composer writes "key" : value, so match it to keep diffs small.
    icon_json.write_text(json.dumps(data, indent=2, separators=(",", " : ")))
    (assets / "sun.svg").unlink(missing_ok=True)
    print(f"{bundle.name}: glow {color} {opacity}")
