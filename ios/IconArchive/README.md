# App icon history

Each folder is one era of the app icon: the ten Icon Composer bundles (one per theme color, as they were
named then), plus a 1024 px preview of the default (Moss) icon. Nothing here is built into the app; the
current icons live in `ios/Beacon*.icon` (the folder names stay for stored-identifier reasons, see AGENTS.md).

| Folder | Icon | Notes |
|---|---|---|
| `01-beacon-sun` | A house with a gold sun behind the chimney | The first themed set, from before the porch light. Extracted from git commit 76577fe. |
| `02-porchlight-house` | The same house with a warm glow in the doorway | Includes the preview PNGs the Appearance picker used and `apply-porchlight-glow.py`, the script that wrote the glow into the bundles. |

Current (03): a two-window tugboat, hull in the theme color, deep teal wave. Source of truth is
`ios/Beacon*.icon`; the drawing script and notes are in `demo/tugboat-icon/`.

To bring an old icon back: copy its bundles over `ios/Beacon*.icon`, re-render the picker previews
(`ictool ... --width 256`, see AGENTS.md) and run `npm run icons:generate`.
