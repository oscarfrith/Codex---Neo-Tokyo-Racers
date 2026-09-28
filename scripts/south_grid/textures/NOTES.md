# South Grid textures (SG MaterialVariants)

All maps are 1024x1024 PNG, seamless in both directions, in `out/`. Normal maps are tangent space, OpenGL / Roblox convention (+G up), derived from a height map. No metalness maps (every variant is non-metal). `out/preview_sheet.png` shows each colour map tiled 2x2.

Rebuild: `py -3 gen_textures.py` (5 procedural variants), `py -3 gen_graffiti.py` (2 murals from `src/`), `py -3 make_preview.py` (sheet + seam check). Needs numpy and Pillow. `sglib.py` holds the periodic shape, noise, blur and normal helpers.

The style is stylised and slightly painterly: soft baked key light and cavity AO in the colour map, low-frequency tonal variation, soft rain streaks, no photo noise.

| Variant | Slug | Base | studsPerTile | How it was made |
|---|---|---|---|---|
| SG Windows Blocks | sg_windows_blocks | SmoothPlastic | 40 | Procedural. 3 storeys x 3 bays (13.3 studs each). Each storey from top: 1.4-stud slab edge, balcony recess with window or door, 4.6-stud parapet. Piers are 1.5 studs, centred on the bay lines. Mix: sliding windows with pastel curtains, lit (warm) and unlit (sky reflection) glass, open balconies with laundry, one closed shutter, AC units on the parapet tops, and 3 of 9 parapets in faded pastel panels. There are grime streaks under the slabs and parapets. |
| SG Windows Capsule | sg_windows_capsule | SmoothPlastic | 40 | Procedural. 2x2 white capsule panels (20 studs each). Each has a 12.8-stud porthole with a raised rim, corner bolts and light streaks. The four portholes: Nakagin fan blind drawn, blind half drawn, clear glass, lit. |
| SG Weathered Concrete | sg_weathered_concrete | Concrete | 24 | Procedural. Board-marked concrete: 1.5-stud boards with staggered butt joints, tie holes on an 8-stud grid with drip trails, vertical rain streaks and water blotches. |
| SG Capsule Panels | sg_capsule_panels | Concrete | 16 | Procedural. 2x2 white precast panels (8 studs each) with 0.2-stud joints, a pillow bevel, a shallow mid rib, 4 bolt heads per panel with streaks, and grime along each panel's bottom edge. |
| SG Patched Panels | sg_patched_panels | SmoothPlastic | 20 | Procedural. Guillotine patchwork on a 1-stud grid: faded mint, salmon, butter, sky and pink sheets (corrugated, framed or flat), rivets with rust runs, and peeling paint (peeled areas are rougher). |
| SG Graffiti A | sg_graffiti_a | Concrete | 40 | Codex image_gen painted over a generated concrete base (`src/graffiti_base_concrete.png`, prompt `src/promptA.txt`, raw `src/sg_graffiti_a_raw.png`). The piece is wildstyle throw-ups in lime, pink, orange and cyan. `gen_graffiti.py` then crops and cross-fades the plain concrete strips to tile vertically, and quilts the horizontal wrap with a minimum-error seam, so the pieces overlap like real graffiti instead of ghosting. Height is concrete detail from high-passed luminance, so the paint reads flat. Paint roughness is 0.65, concrete 0.9. |
| SG Graffiti B | sg_graffiti_b | Concrete | 40 | Same pipeline as A (`src/promptB.txt`). An original robot-cat mascot face with block letters, bolts, stars and drips in purple, blue, teal, yellow and coral. |

## Placement notes for the integrator

- **Windows Blocks:** the tile's top edge is the top of a slab band, and a storey is exactly 1/3 tile (13.33 studs). To line storeys up with the geometry, start a face on a 40-stud boundary (a Roblox texture tile starts at the part's corner).
- **Graffiti:** the painted band covers roughly 7 to 35 studs down the 40-stud tile; the top and bottom are plain concrete. On a ground-floor wall about 40 studs tall, the mural sits at car-eye height. On taller faces it repeats every 40 studs, so use it on lower storeys only, as the style rule says.
- **Seam check** (`make_preview.py`): the mean colour difference across the wrap edge is at or below the image's own neighbour difference, except at deliberate structural edges. Those are Windows Blocks (slab and parapet meeting on the tile line) and the concrete board lines.
- No change to names or studsPerTile. I added a `slug` field to `variants.json`, which is the file prefix in `out/`.
