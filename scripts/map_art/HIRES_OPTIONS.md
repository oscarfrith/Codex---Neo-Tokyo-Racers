# High-resolution map: options and choice

Oscar asked for a higher-resolution map, upscaled to a 4x4 tile image if needed. A Roblox image is at most 1024x1024, so 4x4 tiles give 4096x4096, twice the linear resolution of the live 2048 map (2x2 tiles).

- **Script.** `hires_map.py`. It takes about 15 s with Pillow on `py -3`.
- **Output.** `hires/R{row}C{col}.png` and `hires/manifest.json`.
- **Review sheets.** `hires/compare/compare_*.png`.

## What the source is

The stitched 2048 map is pure grey, with no colour at all. It has five classes:

| Class | Value |
|---|---|
| Transparent water | alpha 0 |
| Land block | 51 |
| Streets | 128 |
| Secondary and coast roads | 153 |
| Highways | 179 |

Edges are antialiased, and the road edges are already clean. Three problems stand out when the map is enlarged:

1. **The coast (alpha) edge is stair-stepped.** It has 3 to 6 px runs with poor antialiasing, visible in `compare_coast_8x.png`, top left.
2. **Semi-transparent coast pixels carry a light matte.** Their rgb is about 200 to 242. This shows as a dotted light fringe around water holes (`compare_islands_4x.png`, live panel).
3. **Plain upscaling only makes the image bigger and softer.** It adds no detail.

The bottom-right tile is the cleaned one, with no baked icons. The small road-edge imperfection under the old garage icon (about 1160,1135) is carried over, as documented in README.

## Candidates

Every crop is shown with bilinear sampling, as Roblox shows it. The zoom is relative to the 2048 map.

| Id | Method | Verdict |
|---|---|---|
| live | The current 2048 map | Soft at full-map zoom. Stair-stepped coast. Light fringe at water edges. |
| A | Premultiplied Lanczos 2x | Barely different from live: the same softness, jaggies and fringe. It fixes nothing. |
| B | A + unsharp mask | Crisper, but dark and light halos ring every road (roundabout, coast). **Rejected.** |
| C | Class masks: each pixel is split into solid, street, secondary and highway coverage using its grey and the pure classes nearby. Each mask is upscaled bicubic and re-thresholded with an AA ramp, then recoloured. | Very crisp. But pixels where two road tiers mix (junctions, the 1 px gap of the dual carriageways) split ambiguously. That leaves dark notches at street–highway junctions (`compare_junction_8x.png`) and blobs along carriageway gaps (`compare_coast_8x.png`). **Rejected.** D, the same with smoothing, has the same defect. |
| E | Level-set: clean the grey first (partial-alpha pixels recoloured from their class split, transparent pixels given the colour of the nearest land). Then bicubic 2x, then a piecewise AA re-threshold between adjacent palette levels (51/128/153/179) with slope 2. Alpha comes from the solid mask. | Crisp and faithful. Junctions and carriageway gaps are correct and there are no halos. The coast stairs remain, because nothing smooths them. |
| F, G, H, J, K | E + Gaussian smoothing before the threshold: the flatter, stylised option | Curves and coast become smoother. But an edge that jumps two palette levels (block 51 to highway 179, or block to secondary 153) crosses the intermediate thresholds at different places. That leaves a faint 128/153 outline band around the hub ring and along coast roads. J is the steepest; it reduces the band but polygonises circles (`compare_hub_6x.png`). An attempt to threshold only the levels present nearby (P/Q) produced blocky switching artefacts. **Rejected.** |
| **M (chosen)** | E for the grey (unsmoothed, slope 2). The alpha/coast mask alone is smoothed (sigma 2.6 px at 4096, slope 4.5). | Roads are as crisp and faithful as E, with correct junctions and no bands. The coast and island outlines become smooth curves instead of stairs. The light matte fringe is gone. |
| (d) | Vector re-render of roads from `route_guide` centrelines | Not built. The road graph has no widths or tiers, and it doesn't cover coast, land or water. Rebuilding widths per edge would re-derive what the raster already holds exactly. The level-set method gets the same crisp edges at far lower risk and keeps the exact registration. |

### Stylised or faithful?

The flat, smoothed look (F to K) costs more than it gains. The source roads are already clean vector-like strokes, and smoothing them buys little except the band artefact at high-contrast edges.

The things that actually hurt clarity are the coast stairs and the light fringe. M fixes exactly those and leaves the roads crisp and faithful.

The three road greys are kept on purpose, because they encode the road hierarchy (street, secondary, highway). M also flattens the antialias noise into the four exact palette levels, so every road of a tier is one consistent grey.

## Registration

The output is centre-aligned. The 2048 pixel x covers 4096 pixels 2x to 2x+1, with the same extent and origin.

- A check against the Lanczos baseline gives a mean alpha difference of 0.2/255 and a mean grey difference of 0.75/255, so there is no shift.
- The existing `to_world` and calibration stay valid in 2048-space. For 4096-space, halve the studs per pixel: (2850/207)/2 = 6.884.

## Output

- **Tiles.** `hires/R1C1.png` to `hires/R4C4.png` are 1024x1024 RGBA. Rows run 1 to 4 from top to bottom and columns 1 to 4 from left to right.
- **Row 4 is fully transparent.** The source's bottom quarter is empty water. It can be uploaded as-is or skipped, but the frame must keep the 4x4 extent.
- **Transparent pixels** hold the nearest land or road colour, so bilinear sampling never pulls in a light matte.
