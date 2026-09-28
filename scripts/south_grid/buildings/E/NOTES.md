# Agent E: the South Grid Gate (P09, P10, X1)

To regenerate, run `python P09.py`, `python P10.py` and `python X1.py` in this folder. Each writes its JSON next to itself. The shared helpers are in `elib.py`: bounds-based boxes, face-relative kit placement, the Blocks balcony grid and roof clutter.

| spec | tris | parts | kit | bounds (min..max) | warnings |
|---|---|---|---|---|---|
| P09 | 19810 | 270 | 138 | (-566,200,4779)..(-124,880,5217) | none |
| P10 | 19726 | 156 | 87 | (125,200,4779)..(530,866,5216) | none |
| X1 | 9076 | 60 | 44 | (-125,388,4964)..(125,682,5036) | none (bridge, no footprint check) |

## Concept

Driving south up the boulevard, the two towers act as gate posts and X1 is the lintel. The towers mirror each other but are built differently:

- **P09, west gate (Blocks-leaning):**
  - A square board-marked concrete core stands on the boulevard corner (x -176..-125, to crown Y820 + mast). It has a glazed slot, stair vents every 80 studs and an amber blade sign.
  - Behind it is a U of mass-housing slabs round a light well:
    - S1 runs along the boulevard (Y240-640), with a setback upper tower to Y763.
    - S2 is on the north (to Y480).
    - S3 is on the south (to Y520).
  - A cantilevered arm (Y520-600) reaches west from S1 over S2. It rests on a leg and an external stair.
  - Deep balcony grids (a slab + parapet Part per storey, full-height fins every 40), random enclosed patched bays, laundry and AC.
  - A graffiti mural on the north gable plus a column of kit balconies. Graffiti on the podium, the lower storeys and the core base. A garage-shutter ground floor, vending machines and rooftop tanks, shacks, dishes and masts.
  - A "sky-street" concrete band at Y440-453 on S1's boulevard face lines up with the X1 deck.
- **P10, east gate (Metabolist-leaning):**
  - Twin round white cores (d40) stand on the boulevard edge, from the ground to Y806, with ring bands and masts.
  - The cores are joined by a Fuji-TV-style frame:
    - F1 (Y386.7-523) takes X1.
    - An open bay above it.
    - F2 (Y573-640).
    - A top beam with a thin cyan neon line.
  - Glazed tube links run from the cores to T1.
  - T1 is a stacked-tray tower to Y725. It has 12 tiers of 3 storeys, and the white trays shift north and south to make cantilevered eaves. The deep north terraces carry planters, and a glazed roof pavilion sits on top.
  - T2 is a Nakagin capsule tower on the north-east corner, with 31 `capsule_unit` kits staggered on its north and west faces.
  - T3 is a Blocks balcony wing on the east road (to Y440).
  - Low Blocks blocks sit north and south of the cores.
  - The podium has a white piloti colonnade and glass shopfronts on the boulevard, with graffiti and neon strips on the fascia.
- **X1, the gate:**
  - A 6-storey Blocks housing slab spans x -125..125 (deck top Y440, roof Y520).
  - Both faces carry balcony grids with patched and concrete rows, laundry, AC and enclosed bays.
  - The deck fascia has graffiti and a thin pink/cyan neon line.
  - Two Metabolist glazed tubes (`bridge_tube_40` x6 each, Y391-409) hang under the slab on concrete hangers, with white collars at the landings.
  - On the roof, a Fuji-style white frame holds a 72-stud steel sphere over the road centre (frame top Y622, mast to Y682). This is the silhouette you see from the whole boulevard. Shacks, a tank and dishes make it lived-in.
  - Underside clearance over the Y200 road: 191 studs at the tubes, 226 at the slab.

Detail scale:

- Everything sits on the 20/40 grid, and a storey is 40/3 studs.
- Windows come from the `SG Windows Blocks` and `SG Windows Capsule` variants on the big mass faces. There are no modelled frames.
- Nothing is thinner than 1 stud or smaller than about 3 studs across, except glass and neon.
- Detail is chunky layers only: balcony rows, fins, trays and bands.

## Landings (solid faces at the contract points)

| bridge | my landing | contract point | checked against the owner's current spec |
|---|---|---|---|
| X1 (mine) | P09 core east face x=-125 (z 4955..5045, Y240..820); P10 F1 west face x=125 (z 4921..5079, Y386.7..523) | z=5000, deck Y440 | slab z 4961..5039 and tubes z 4975..5025 sit inside both faces |
| X4 (A) | P09 `X4Lobby` x -418..-382, z 4780..4822, Y322..362 (roof to 365), shutter door at Y330-346 | x=-400, z=4780, Y330 | A's Portal x -414..-386, Y324..352 fits inside |
| X5 (B) | P10 `X5Lobby` x 384..416, z 4780..4800, Y330..373, shutter door at Y350-366, at the foot of the capsule tower | x=400, z=4780, Y350 | B's Collar x 386..414, Y341..371 fits inside |
| X2 (F) | P10 `X2Lobby` x 506..530, z 5044..5076, Y390..424, on the T3 balcony face (balconies skipped there) | x=530, z=5060, Y400 | F's west head x 524..540, Y392..418 enters 6 studs into the lobby. There are no coplanar faces, so there is no z-fighting |

Flex used on X1:

- The deck top stays at Y440 on the z=5000 centre line.
- The slab is 60 deep (z 4970..5030) including balconies, against the 40 width in the contract. The walkable deck is the inner 44 (z 4978..5022).

## Variant and material assumptions for the assembler

- `SG Windows Blocks`, `SG Windows Capsule` and `SG Patched Panels` go on SmoothPlastic, the base in variants.json.
- `SG Weathered Concrete`, `SG Capsule Panels`, `SG Graffiti A` and `SG Graffiti B` go on Concrete.
- `Metal Shutters` goes on Metal.
- Graffiti and window skins are 1-1.5 studs proud of the mass faces.
- I did not use `Windows Day` or `Windows Night`, because their base material is not recorded in the repo.

## Notes for the integrator

- **Spheres are repeated.** Other agents also use spheres (P11 Kasei Frame, and at least one on the west side). The X1 sphere is the only one over the boulevard axis. If the district reads as sphere-heavy, consider dropping the others, not this one.
- **Trees clash with P10.** Streetscape tree proxies near the P10 boulevard colonnade look close to the pilotis (x≈160) in the preview. Check that the trees stay on the pavement outside x≈150.
- **Blocked view in the key shot.** In the key boulevard shot, a large context box behind the gate (south of z≈5236, on the axis) blocks the sky through the gate. It is not from these specs.
- **Studio capture skipped.** I skipped the optional read-only Studio capture. Previews are Blender only.

## Iterations (preview/)

- **it1:** first massing. The gate slab was 3 storeys and too thin. P10 had a sphere between its cores, but the frame is seen edge-on from the boulevard, so the sphere was hidden behind core C1.
- **it2:**
  - The sphere moved onto X1 in a roof frame on the road axis, where it reads head-on.
  - The slab became 6 storeys, and F1 was raised to receive it.
  - Laundry and AC densities were cut to fit the budgets.
- **it3/final:**
  - A sky-street band on P09 aligns with the X1 deck.
  - A kit-balcony stack went on the P09 north gable.
  - I trimmed AC and tanks to pay for it, and added planter terraces on T1.
  - Neighbours were checked with `--all-specs`: the X2, X4 and X5 heads meet the landings.
- **Key views:**
  - `final/street_0_212_4650_0_380_5100.png` (boulevard)
  - `final/street_0_260_4450_0_470_5000.png` (approach)
  - `final/street_-60_520_4640_330_450_5000.png` (P10 + gate from the north-west)
  - `final/street_-700_420_4700_-420_340_4790.png` / `final/street_700_460_4700_420_360_4790.png` (X4 / X5 sides)
  - `final/street_568_470_5300_520_400_5060.png` (X2)
