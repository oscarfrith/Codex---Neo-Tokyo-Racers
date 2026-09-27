# Map art (Agent M)

Offline tooling and outputs for the minimap and full-map art. It uses only the Python stdlib (`py -3`), with its own PNG codec in `png_rgba.py`. No Studio access.

## Pipeline

| Step | Command | Output |
|---|---|---|
| Export source tiles (Studio, Edit mode, read-only) | `export_tiles.lua` + `tile_receiver.py` | `tiles/MapTile*.png/.json` |
| Detect baked icons, clean tiles | `py -3 clean_tiles.py` | `detected_pois.json`, `crops/`, `clean/` |
| Draw icon set + contact sheet | `py -3 make_icons.py` | `icons/*.png`, `icons/contact_sheet.png`, `icons/preview_24px_x4.png` |
| Manifest for the integrator | `py -3 build_manifest.py` | `manifest.json` (keeps the `icons_glyph` and `hiresMap` sections) |
| High-resolution 4x4 map (Pillow) | `py -3 hires_map.py [--work DIR]` | `hires/R{row}C{col}.png`, `hires/manifest.json`, `hires/compare/*.png` |
| Glyph-only icon set (Pillow for the sheet) | `py -3 make_icons_glyph.py` | `icons_glyph/*.png`, `icons_glyph/contact_sheet.png`, `manifest.json` → `icons_glyph` |

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

## High-resolution map (`hires/`, 4x4 tiles of 1024, 4096x4096)

- **Method.** Candidate M in [HIRES_OPTIONS.md](HIRES_OPTIONS.md). It is a level-set re-render: the grey is cleaned, upscaled 2x with bicubic, and re-thresholded between the palette levels 51, 128, 153 and 179. Only the coast (alpha) mask is smoothed.
- **Result.** Roads come out crisp, with correct junctions and no halos. Coast and island outlines are smooth where they used to be stair-stepped, and the old light matte fringe at water edges is gone.
- **Source.** The build uses the cleaned bottom-right tile, so no icons are baked in.
- **Registration.** 2048 pixel x maps to 4096 pixels 2x to 2x+1, centre-aligned, over the same extent. Calibration is unchanged in 2048-space. In 4096-space there are 6.884 studs per pixel.
- **Row 4 (`R4C1` to `R4C4`) is fully transparent.**
- **Review sheets.** The comparison sheets are in `hires/compare/`. The candidate full images go to `--work` and are not committed.

## Glyph-only icons (`icons_glyph/`, 128x128 RGBA)

Oscar asked for "just the icons", so this set has no badge circle, ring or square. Each icon is the glyph in its role colour, with a dark `#06080B` outline of about 6.5/128 and a soft dark halo. The icons are sized for 28 to 56 px on screen. `icons_glyph/contact_sheet.png` shows them at 28, 40 and 56 px on block 51, road 128 and highway 179.

- **Place (cyan `#66F2EE`):** Customisation.
- **Activities (HighSpeed pink `#F6539F`):** Race (the checks are cut in dark), TimeTrial and Duel.
- **Jobs (ElectricBlue, lifted to `#2F88FF` for contrast on block dark):** Job, TaxiFare and CourierPickup.
- **Pins:** TaxiDrop and CourierDrop are blue pins with a white glyph, and Waypoint is a pink pin with a white dot. **All three anchor at the tip, AnchorPoint (0.5, 0.9219)**, which differs from the old 0.953.
- **Player and OtherPlayer:** unchanged in style. Player is the white arrow with cyan and dark edges, pointing north; OtherPlayer is the blue dot in a white ring.
- **Not drawn:** Dealership and Garage. The map uses the HUD's own icons for those.
