# Agent F: P11 "Kasei Frame" + bridges X2, X3

Generators: `P11.py`, `X2.py`, `X3.py`. Run each with `py -3 <file>`; each writes its JSON next to itself.

## Budgets (sgspec)

| spec | tris | parts | kit | bounds (min to max) | warnings |
|---|---|---|---|---|---|
| P11 | 19432 / 20000 | 188 / 320 | 91 / 160 | (606,200,4789) to (1054,852,5203) | none |
| X2 | 744 | 5 | 3 | (524,384,5046) to (632,418,5074) | none |
| X3 | 972 | 4 | 2 | (1030,464,4947) to (1148,490,4973) | none |

## P11 design (lean: metabolist, poor and lived-in)

- **Massing.** The podium is Y200–240 across the blockout footprint (x630–1030, z4800–5200). Above it stand two slab towers, both z4820–5180:
  - W tower: x630–750, top Y680.
  - E tower: x910–1030, top Y760.
  - Masts reach Y852.
- **Fuji TV frame.** The 160-stud gap between the towers is spanned by:
  - sky tray A at Y360–400;
  - sky tray B at Y480–520;
  - a top beam at Y640–680.

  Each tray has a 14-stud-deep "lip" beam that runs across both towers' street faces. The lips and the projecting service piers at the gap edges form the grid frame. A 110-stud steel sphere with an equator belt sits in the top cell. It stands 27 studs proud of the street face, rests on a cradle on tray B, and has a hanger under the top beam. The void from Y240 to Y360 is open. Behind the sphere, the cell at z5000–5180 is filled.
- **Metabolist.** Four round service cores (40 dia, SG Capsule Panels) stand on the outer faces and rise above the roofs. Capsule clusters (`capsule_unit` at scale 1.5, so about 39 studs wide) are stacked irregularly on both sides of the north cores: 14 on the W face and 9 on the E face. Three capsule pods hang in the open frame cell under tray B, and four more sit on the E tower's north face above the top beam. The street faces carry the SG Windows Capsule porthole grid; the side faces carry SG Windows Blocks. Tray bands every 40 studs wrap each tower (Tange trays). Each sky tray has `tray_edge_40` on its north face.
- **Poor and lived-in.**
  - The podium has shutter/shop bays on a 40-stud rhythm with piers, a graffiti band at Y220–240 (SG Graffiti A on N/E, B on S/W) and a few lit shops with small neon signs.
  - A market sits on the podium deck under the frame: 3 stalls, vending machines, a bench, shacks and chain-link.
  - An exterior stair runs from the street to the deck, and a 4-flight fire stair climbs the W tower south face.
  - Patched cells (SG Patched Panels) and boarded cells (Wood + Plywood) sit on the side and south faces.
  - There are 15 laundry lines, 8 AC clusters, chunky downpipes, and two faded vertical banners (blue and red, Fuji-TV broadcaster style) on the street face.
  - Rooftops carry water tanks, dishes, shacks, lift overruns and masts.
- **Grid and scale.** Everything is on the 20/40 grid. The smallest non-glass/neon element is 3 studs. Windows come from variants on big faces.

## Bridges

- **X2 (truss).**
  - Deck top Y400, centre line z5060, no flex.
  - Two `bridge_truss_40` at x540–620 sit between solid concrete heads.
  - The west head runs x524–540: it enters 6 studs into P10, past its x=530 face, and needs E's recess there.
  - The east head runs x620–632 and sits inside the P11 portal collar: a U collar with jambs, lintel and sill plus a dark recess panel on the W tower west face at z5060.
  - Clearance over the x=568 road is about 198.
- **X3 (glazed tube).**
  - Deck top about Y470 (tube underside Y468.5), centre line z4960, no flex.
  - Two `bridge_tube_40` at x1046–1126, with round cylinder collar heads and a mid-span ring.
  - The west head sits in the P11 portal on the E tower east face.
  - The east head ends at x1148 and butts C's existing landing: in P12.json, "X3 landing deck" x1146–1170 with top Y470, and "X3 landing head" x1150–1170, Y470–496. I checked this against C's current spec.
- **P10 side of X2.** E has not delivered P10 yet, so in previews the X2 west head floats. E needs a landing or recess at (530, 400, 5060).

## Variant base materials used

| Variants | Base material |
|---|---|
| SG Windows Blocks, SG Windows Capsule, SG Patched Panels | SmoothPlastic (per variants.json) |
| SG Weathered Concrete, SG Capsule Panels, SG Graffiti A/B | Concrete |
| Metal Shutters | Metal (assumed) |
| Plywood | Wood (the garage finishes use Wood + Plywood) |

I avoided `Windows Day`/`Windows Night` because their BaseMaterial is not recorded in the repo. If any variant's base differs in MaterialService, the integrator should adjust `mat`.

## Previews (`preview/`)

- `it1/`: first pass. The gap was too narrow (120), the sphere was hidden behind tray B from the street, and the building read as a plain office slab.
- `it2/`: gap widened to 160, sphere enlarged and pushed forward, tray lips and projecting piers added. The frame now reads.
- `it3/` and `final/`: street-face life added (pods in the frame, banners, north laundry/AC). South-side tray-edge kits were swapped for a floor lip to stay in budget, and the X3 east head was fitted to C's landing.
- Useful cams:
  - `final/street_760_215_4700_840_520_5000.png`: from the step road, looking up at the frame.
  - `final/street_1450_950_4450_830_450_5000.png`: aerial with neighbours.
  - `final/drone.png`
  - `final/parcel_P11.png`
- Kit items render as box proxies because `kit/out/obj` is empty.

## Tooling notes for the integrator

- In `common/preview.py`, `street:P11` is parsed as a custom camera (`startswith("street:")`) and crashes. I used the equivalent explicit camera `street:1098,208,4678,838,360,5008`.
- A relative `--out` resolves against C:\ when Blender runs, so use absolute out paths. My first attempt left a stray `C:\buildings\F\preview\it1\` folder of PNGs. The safety check blocked me from deleting it; it is safe to delete by hand.
