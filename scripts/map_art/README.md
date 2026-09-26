# Map art (Agent M)

Offline tooling and outputs for the minimap and full-map art. It uses only the Python stdlib (`py -3`), with its own PNG codec in `png_rgba.py`. No Studio access.

## Pipeline

| Step | Command | Output |
|---|---|---|
| Export source tiles (Studio, Edit mode, read-only) | `export_tiles.lua` + `tile_receiver.py` | `tiles/MapTile*.png/.json` |
| Detect baked icons, clean tiles | `py -3 clean_tiles.py` | `detected_pois.json`, `crops/`, `clean/` |
| Draw icon set + contact sheet | `py -3 make_icons.py` | `icons/*.png`, `icons/contact_sheet.png`, `icons/preview_24px_x4.png` |
| Manifest for the integrator | `py -3 build_manifest.py` | `manifest.json` |

`common.py` stitches the four tiles into the 2048x2048 map. Its `to_world` is the same function as in `scripts/route_guide/build_road_graph.py`: 13.768 studs/px, 90° rotation, with X = (py+0.5-1024)*spp and Z = -(px+0.5-1024)*spp.

## Baked-in icons found

Only three icons are baked in, and all three sit in `MapTileBottomRight`. No dealership glyph exists. The coastline has light grey antialiased strokes, but they are grey rather than saturated, so detection ignores them.

| Icon | Glyph | Pixel centre | World X, Z |
|---|---|---|---|
| Customisation | cyan paint brush inside a small roundabout (the ring is road and is kept) | 1150.5, 1084.5 | 839.9, -1748.6 |
| Garage | cyan house with a garage door | 1154.5, 1133.5 | 1514.5, -1803.6 |
| Race | lime checkered flag on the southern boulevard | 1120.5, 1181.5 | 2175.4, -1335.5 |

Positions are the glyph centres, accurate to about ±40 studs. Where a world part exists (the Dealership, My Garage and Customisation parts, and the race start), prefer it.

## Cleaning

- **Mask.** Each mask is built from three parts: the saturated glyph cluster, its dark outline (grey below 46), and any holes it encloses (the garage slats and the flag checks, which let the road show through). The mask is then dilated by 1 px, giving 407, 447 and 473 px.
- **Inpainting.** Masked pixels are filled by directional inpainting over 72 orientations. For each orientation, both ends must agree in colour (within 20 of each other).
  - First choice is a road-to-road ray whose road carries on for at least 20 px past both ends, where the ray lies within 14° of the local road direction (taken from the structure tensor). This lets straight roads run through the hole.
  - Next are block-to-block rays, then short antialiased road edges.
  - Chords across curved roads are never used, which keeps them from producing streaks.
- **Byte identity.** Every pixel outside the masks is asserted to be byte-identical to the source. `TopLeft`, `TopRight` and `BottomLeft` are pixel-identical to the originals and need no re-upload. Only `clean/MapTileBottomRight.png` changed, by 1,122 px.
- **Review files.** `crops/*_before_after_4x.png` and `crops/city_before_after_3x.png` show each icon before and after cleaning.
- **Known limitation.** Under the garage icon, the curved road's inner antialiased edge is about 1 px thinner for a few pixels. It is not visible at map scale.

## Icon set (`icons/`, 128x128 RGBA)

The icons use the old baked style: flat glyphs, a round PanelDeep `#090C10` badge, a thin ring in the role colour, and a dark outer outline so they read on both block and road.

- **Places** (Customisation, Garage, Dealership): the old cyan glyph `#66F2EE` on a Telemetry `#2BE1DA` ring. The brush and house are redrawn from the baked shapes.
- **Activities** (Race, TimeTrial, Duel): white glyph on a HighSpeed `#F6539F` ring. The race flag keeps the old checkered-flag shape but drops the off-palette lime. Duel shows two chevrons meeting head-on, with a spark between them.
- **Jobs** (Job, TaxiFare, CourierPickup): white glyph on an ElectricBlue `#1974FF` ring. Job is a briefcase, TaxiFare is a hailing person, and CourierPickup is an isometric parcel.
- **Drops** (TaxiDrop, CourierDrop): ElectricBlue map pins holding the same glyph in small form. Waypoint is an Outline-pink `#F42E97` pin with a white dot. Pins anchor at their tip, AnchorPoint (0.5, 0.953).
- **Player**: a white arrow with a cyan outline, pointing up (north). The integrator rotates it to the player's heading. **OtherPlayer**: a blue dot inside a white ring.

`icons/contact_sheet.png` shows every icon at 64 px, 24 px and 20 px, on both block grey and road grey. The icons are built to be read at 20 to 28 px.

## Integrator notes

- **Assets.** Upload the 14 icons and set `ReplicatedStorage.Config.UI.MapIcons.<Key>` to their ids. Upload `clean/MapTileBottomRight.png` and point `Config.UI.DesktopFreeRoamHud.Assets.MapTileBottomRight` at it. Check whether any mobile or full-map config also references tile id `73611385783250`.
- **Map POIs.** Create the `Config.UI.MapPois` entries from `manifest.json` → `detectedPois`, or from the world parts.
