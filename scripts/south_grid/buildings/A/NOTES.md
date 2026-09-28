# Agent A: P01, P02, X4 (+ XA1)

Build: `cd scripts/south_grid/buildings/A && python P01.py && python P02.py && python X4.py && python XA1.py`.
All four save with no sgspec warnings.

| Spec | Tris | Parts | Kit | Bounds (min..max) |
|---|---|---|---|---|
| P01 | 16,544 | 255 | 94 | (-1212,100,4104)..(-846,694,4552) |
| P02 | 19,750 | 212 | 98 | (-732,100,4118)..(-308,696,4577) |
| X4 | 2,580 | 11 | 7 | (-414,200,4576)..(-342,362,4780) |
| XA1 | 252 | 11 | 2 | (-860,267,4254)..(-720,324,4298) |

## Files

- `abuild.py` is the shared helper.
  - `Mass` builds one Blocks residential mass: an SG Windows core, 40-stud floor plates (the first one is the canopy over the ground storey), fins, gables with SG Graffiti feet and a slot of stair windows, patched parapets (SG Patched Panels), and a ground storey with Metal Shutters garages and small neon signs.
  - Kit helpers: balconies, laundry, AC units, exterior stairs and roof items.
  - `lift_tower` builds a lift/stair shaft; `walkway` builds an access deck; `cyl_v` makes a vertical cylinder core.
- `P01.py`, `P02.py`, `X4.py`, `XA1.py` are the generators; each writes its `.json`.
- `render.sh` is a preview wrapper. It uses absolute paths, because Blender resolves relative `--out` against `C:\`.
- `preview_a.py` is the same as common/preview.py, except the SG Windows variants render dark blue.
- `zcheck.py` looks for coplanar, same-facing, overlapping faces between Block parts. The only remaining hit is the X4 pier foot, whose face is on the ground.
- `preview/it1` is iteration 1 and `preview/final` is the delivered state. Both render with `--all-specs` neighbours.

## Detail scale

- Every facade sits on the 40-stud grid:
  - plates 3 thick, every 40 studs (3 storeys);
  - fins 3 wide, every 40 (20 on some faces, 80 on the south slab, or none for horizontal-balcony faces);
  - plates project 8–10 studs past the window core, which gives the dealership-style coffers.
- Windows come only from SG Windows Blocks / SG Windows Capsule on big faces.
- The smallest pieces are parapets and rails 1.5 thick and neon strips 1 tall. There is no greebling.
- Faces are kept apart so they never z-fight:
  - plates project at least 1.5 past the core;
  - fins stand 0.5 proud of the plates;
  - gables swallow the plate ends;
  - parapets sit 0.5 behind the plate edge;
  - corner fins of two faces are offset by 0.5 in height;
  - stacked masses butt together, never overlapping coplanar faces.
- Window part colour is a light cool tint, (178,186,200), so the variant texture reads nearly true.

## P01 Kaigan Blocks (lean: blocks)

A perimeter block of mass housing around an open courtyard. The ground storey is Y100–120, inset under a canopy plate, with garages and neon.

| Element | Footprint | Top | Notes |
|---|---|---|---|
| Harbour Slab | x-1180..-900, z4120..4160 | 360 | 40-grid balcony wall to the water; access decks on the courtyard side; W gable mural 140 high; lift shaft on the N face to 412 splits the long front |
| West Tower | x-1200..-1080, z4200..4320 | 460 | Roof terrace with tanks and a shack. Crown x-1200..-1120, z4200..4360, rises to 660 with 20-stud fins and cantilevers 40 south over the yard; tank tops at 694 |
| East Tower | x-980..-860, z4220..4380 | 520 | On the P01/P02 road. Deep horizontal balcony plates with no fins; mast |
| Sky Block | x-1060..-980, z4260..4340 | Y420–500 | Cantilevered 80 studs west off the East Tower over the yard |
| South Slab | x-1180..-900, z4470..4540 | 360 | West 120 studs rise to 440; wide 80-stud cells on the step-road face |
| Lift Shaft | x-1044..-1020, z4176..4200 | 576 | Free-standing in the yard; access decks to the Harbour Slab (241.5, 321.5), West Tower (401.5) and Sky Block (461.5) |
| Yard galleries | West Tower ↔ East Tower | 241.5, 361.5 | Two access galleries crossing the yard |

- Sky gaps: the yard is open to the sky between all the masses. The crown overhang and the sky block frame the view from the west lot.

## P02 Twin Core Yard (lean: hybrid)

- **Blocks side:**
  - **Canal Slab** (x-720..-664, z4140..4500, top 400): faces the P01/P02 road with 20-stud fins and has graffiti gables N and S. It receives XA1.
  - **South Bar** (x-652..-464, z4460..4530, top 320): horizontal balcony plates with lots of patched parapets.
  - **South Tower** (x-460..-330, z4420..4540, top 480): carries the X4 bridge head.
- **Metabolist side:**
  - **Twin cores:** white SG Capsule Panels cylinders, Ø48, with rings every 80.
    - Core A at (-600, 4200) rises to 630, with a mast to 696.
    - Core B at (-480, 4200) rises to 580, with a tank.
  - **Frame:** a Fuji-TV frame of three window trays between the cores (Y280–320, 400–440, 520–560) and a Ø52 metal sphere sitting on the middle tray (centre Y470).
  - **Capsules:** 18 capsule_unit kits plug into the cores (NW and W of A, E of B), with their backs buried 5 studs.
- **Hybrid tower:** the NE Tower (x-420..-320, z4130..4290) is a Blocks shaft to 440 with a Metabolist capsule-window crown to 560.
- **Yard:** two market stalls under the cores.

## Bridges

### X4 (shared, owner A)

- **Route:** P02 south face (z=4576) → P09 north face (z=4780) over the step.
- **Deck:** centre line x=-400, width 24 (x-412..-388). The deck slab spans Y326–330, so the deck top is **Y330** as in the contract. There is no flex.
- **Truss:** 4 × bridge_truss_40 at scale 1.2 (48 long, 24 wide) sit on the deck at Y330–349.
- **P02 end:** concrete bridge head, x-426..-374, Y296–356, z4536..4576. Its solid face at z=4576 has a dark door panel.
- **P09 end (agent E):** a portal collar, x-414..-386, Y324–352, z4774..4780. **P09 needs a solid face at z=4780 covering at least x-414..-386, Y324–352.**
- **Pier:** x-408..-392, z4672..4694, Y200–326, on the Y200 terrace strip (z4661–4705).
- **Stair tower:** core x-380..-352, z4668..4698, Y200–362, with 3 ext_stair_40 kits on its east face (out to x-342). It is linked to the deck by a landing at Y330.
- **Clearance:** underside Y326 is 225 above the Y101 step road and 125 above the Y201 terrace road. Neither the pier nor the tower touches a road.
- **Streetscape:** it has trees and planters in that terrace strip. The integrator should check they keep clear of x-414..-340, z4666..4700.

### XA1 (extra, inside the P01↔P02 pair)

- **Route:** an inhabited Blocks slab bridge over the x=-790 road, from the P01 East Tower east face (x=-860) to the P02 Canal Slab west face (x=-720). Both ends butt onto the building cores.
- **Size:** z4256..4296 (centre 4276), floor Y274–283, windows 283–317, roof to 322, fins to 324.
- **Clearance:** 173 above the road.
- **Assembly:** it has its own spec id `XA1` (kind building), so the assembler places each element in the nearest block.

## Notes for the integrator

- **preview.py:** the `street:P01` camera form in the contract does not work. preview.py reads every `street:` camera as coordinates. Use `parcel:` / `top:` or explicit `street:x,y,z,tx,ty,tz`.
- **Stray file:** an early preview run with a relative `--out` wrote a stray `C:\buildings\A\preview\it1\parcel_P01.png` outside the repo. The agent could not delete it (the safety check blocked the removal). Please delete `C:\buildings` by hand.
- **Budget:** P02 is close to the triangle budget (19,750 of 20,000). If the real kit tri counts come in higher, cut capsules or AC clusters first.
