"""Gives each Beacon*.icon bundle its porch light: a warm glow behind the doorway and a warm door.

The glow is its own layer (glow.svg) between the house and the doorway, so each theme's house color keeps
coming from icon.json. It is a soft ellipse around the doorway that fades to nothing *inside* the house.
It must never be clipped to the house shape or reach the house's edge: Icon Composer's glass effect treats
a clipped layer as an object of its own and draws a second outline over the house (contour lines near the
roof, and a ghost outline outside it if the layer is scaled), and it draws a ring even around an unclipped,
fading glow, so the layer also has "glass": false (Icon Composer's per-layer Specular off). Safe to run again: it rewrites the glow and the
door color, keeps the layer list, and clears any scale or offset the glow layer was given.

Sunflower's house is already the color of the light, so its glow is a deeper amber instead.
A *light* glow (white or cream) must not be used: Icon Composer's dark rendition turns it into an
opaque house-shaped fill.

    python3 ios/apply-porchlight-glow.py
"""
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
GLOWS = {"BeaconOchre": ("#e8962b", 0.75)}   # everything else: ("#ffd36b", 0.95)
DEFAULT_GLOW = ("#ffd36b", 0.95)
WARM_DOOR = "#fff4d6"
# The middle of the doorway, and how far the glow reaches. The walls are about 360 away sideways and the
# floor 270 below, so these stay inside the house.
CENTER_X, CENTER_Y, REACH_X, REACH_Y = 512, 650, 335, 262

for bundle in sorted(ROOT.glob("Beacon*.icon")):
    assets = bundle / "Assets"
    color, opacity = GLOWS.get(bundle.stem, DEFAULT_GLOW)
    (assets / "glow.svg").write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="glow-fill">
      <stop offset="0" stop-color="{color}" stop-opacity="{opacity}"/>
      <stop offset=".5" stop-color="{color}" stop-opacity="{opacity * 0.5:.3f}"/>
      <stop offset="1" stop-color="{color}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <ellipse cx="{CENTER_X}" cy="{CENTER_Y}" rx="{REACH_X}" ry="{REACH_Y}" fill="url(#glow-fill)"/>
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
    for layer in layers:
        if layer["name"] == "glow":
            layer.pop("position", None)
            layer["glass"] = False
    # Icon Composer writes "key" : value, so match it to keep diffs small.
    icon_json.write_text(json.dumps(data, indent=2, separators=(",", " : ")))
    (assets / "sun.svg").unlink(missing_ok=True)
    print(f"{bundle.name}: glow {color} {opacity}")
