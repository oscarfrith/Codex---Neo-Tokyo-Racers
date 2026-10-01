# Apex frame standard (blockout result)

Status: design exploration, 2026-10-01. Not game content. Spec: [apex.json](../../../scripts/vehicle_blockouts/specs/apex.json). Previews: [sheet](../../../scripts/vehicle_blockouts/previews/apex/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/apex/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/apex/standard.png).

Root space: +X right, +Y up, forward is -Z, studs. "±" means centred. "Both sides" means mirrored. Built: 4 cockpits (Formula, Cigar, Prototype, Sprint), 34 modules, 8 builds of 145 to 150 parts.

## Datums

| Datum | Value | What lines up on it |
|---|---|---|
| Hover plane | Y -2.0 | Ground. The lowest part is a pod hover pad at Y -1.6. Skirts stop at Y -1.3. |
| Sill | Y 0 | Tub underside. Seam plane for Floor and Diffuser. |
| Beltline | Y 1.4 | Tub waist crease, nose root top, Power Unit deck. |
| Rim | Y 2.2 | Cockpit rim. Seam plane for Halo or Canopy. Top limit for Sidepods. |
| Pod axle | Y 0.5, X ±5.9 | Centre of every hover pod. Front station Z -6.5, rear station Z 8.0. |
| Overall | 14.9 W x 28 L | Height 5.5 with a normal wing. Top at Y 7.3 with the Sprint Top Wing. |

## Envelopes

| Slot ID | Player label | Envelope boxes (X, Y, Z) | Anchor |
|---|---|---|---|
| Cockpit | Tub | Tub ±1.75, 0..2.2, -8..3. Head box ±1.05, 2.2..3.5, -1.3..0.6 (driver only) | Root |
| | | Side rails 1.4..1.75 both sides, 2.2..4.0, -3.5..0.6. Top slab ±1.75, 4.0..4.6, -3.5..0.6 | |
| | | Hoop column ±1.75, 2.2..4.6, 0.6..3 | |
| Engine1 | Front Pods | Pod box 4.0..7.5 both sides, -1.6..2.6, -10..-3.5. Wishbone corridor 1.75..4.0 both sides, 0.2..1.9, -7.7..-5.3 | Cockpit, tub side X 1.75 |
| Engine2 | Power Unit | Neck ±1.75, 0..2.8, 3..4.5. Deck ±4.0, 0..2.8, 4.5..12. Pod box 4.0..7.5 both sides, -1.6..2.6, 4.5..11.5 | Cockpit, rear bulkhead Z 3 |
| Stabilisers | Floor | ±1.75, -1.3..0, -8..-3.5. ±5.9, -1.3..0, -3.5..4.5. ±4.0, -1.3..0, 4.5..8. Bargeboard zone 1.75..4.0 both sides, -1.3..2.0, -5.2..-3.5 | Cockpit, tub underside Y 0 |
| SidePods | Sidepods | 1.75..6.4 both sides, 0..2.2, -3.5..4.5. Skirt strip 5.9..6.4 both sides, -1.3..0, -3.5..4.5 | Cockpit, tub side X 1.75 |
| FrontBumper | Nose and Wing | Neck ±3.6, -1.4..2.2, -10.4..-8. Wing zone ±7.3, -1.4..2.2, -14..-10.4 | Cockpit, front bulkhead Z -8 |
| RearBumper | Diffuser | ±4.0, -1.3..0, 8..12. ±4.0, -1.3..0.6, 12..14 | Engine2, underside Y 0 |
| Boost | Exhaust | ±3.2, 0.6..2.6, 12..14 | Engine2, rear face Z 12 |
| RearSpoiler | Rear Wing | Rear ±6.6, 2.8..7.6, 9..14. Top ±6.6, 4.8..7.6, -3.5..9. Endplate drops 4.2..6.6 both sides, -1.0..2.8, 11.7..14 | Engine2, deck top Y 2.8 |
| Hood | Airbox | ±1.2, 2.8..4.7, 3..8.5 | Engine2, spine top Y 2.8 |
| Roof | Halo or Canopy | Front ±1.75, -5..-3.5. Mid ±1.4, -3.5..-1.3. Sides 1.05..1.4 both sides, -1.3..0.6. All three Y 2.2..4.0. Top ±1.05, 3.5..4.0, -1.3..0.6 | Cockpit, rim Y 2.2 |

No two envelopes overlap. The Roof envelope is a shell round the head box. The cockpit side rails, top slab and hoop column wrap that shell.

## Seam rules

Every cockpit provides these hardpoints. The validator does not check them yet.

1. Front bulkhead: a flat plate at Z -7.9, at least X ±1.3, Y 0.3..1.3. Nose collars stay inside it.
2. Rear bulkhead: the tub ends at Z 2.85, at least X ±1.4, Y 0.2..1.9.
3. Tub sides at X 1.5 to 1.6, solid from Y 0.25 to 1.4, at Z -7.5..-5.5 (wishbones) and Z -3..2.85 (sidepods).
4. Underside at Y 0.15 at Z -5.6 and Z 0.5. The floor pylons meet it there.
5. Rim between Y 1.9 and 2.2 from Z -4.3 to 0.6. Open-sided tubs carry a rim rail.
6. Back of the head box closed: a plate at Z 0.6..0.9, X ±1.05, Y 2.2..3.5. Without it a canopy has a hole behind the helmet.

Every Power Unit provides these for its child slots.

1. Spine top (or intake stacks) at Y 2.5..2.8 between Z 3.3 and 7.6. The airbox sits on it.
2. Wing plinth on the centreline, top at Y 2.6..2.8, Z 10.2..11.4. Every rear wing stands on it.
3. Rear face at Z 11.7..12, Y 0.6..1.4 (exhaust). Underside at Y 0.2 from Z 8.5 to 10 (diffuser).

Shadow gap: painted bodywork stops 0.15 short of its seam face. The module carries a dark `detail` collar, link or pylon, 0.2 to 0.4 thick, that reaches the seam face. The visible gap is 0.3 to 0.5.

## Authoring rules for artists

1. Keep the tub slim. Culture lives in the kit. A cockpit shows its identity through its tub section and the three superstructure zones only.
2. Nothing but the driver goes in the head box. Roof modules pass round it. This is why a bubble canopy fits inside the sprint cage and under the prototype roof.
3. A closed cabin is a frame with an open windscreen aperture. The Roof module supplies the glass.
4. Wishbones belong to the pod module. They are the linkage across the gap. Start them on a plate at X 1.75..1.95. Keep them inside the corridor until X 4.0.
5. Rear wishbones attach to the Power Unit's own body. There is no cross-module seam at the rear axle.
6. Enclosed bodywork is modules only: arches inside the pod boxes, a full-width deck, skirted sidepods, a wide nose. Leave 0.2 to 0.5 between arch, sidepod and nose.
7. Pods: ring diameter 4.0 at most, centred on the pod axle. Every pod has a `thrust` core and a `thrust` pad below it. Nothing touches the ground.
8. The Sprint Top Wing mounts on the wing plinth with forward arms. Its front stays stop at Y 4.85, just above the cage top.
9. Keep cockpit bodywork in the hoop column below Y 3.5 or narrower than 0.6. Wider and taller hides the airbox intake.
10. Seat a 2-wide torso with the helmet top at Y 3.45. Reclined and upright poses both fit the head box.
11. Paint: tub, nose, deck and arches `primary`; wing planes, collars and stripes `secondary`; every link `detail`.

## Validator result

`SPEC apex: 0 error(s), 1 warning(s) {'cockpits': 4, 'modules': 34, 'builds': 8, 'parts_in_builds': 1181}`

Warning left: `cockpit formula appears in fewer than 2 builds`. The brief fixes eight builds: three cockpits for one kit, a fourth cockpit for three kits, two wildcards. Four cockpits cannot all appear twice in that layout.

Two extra checks ran outside the shared tool. Every module was tested against every cockpit or Power Unit it can meet: 136 pairs, largest bounding-box gap 0.30 studs. Points sampled inside every part all stayed in the part's envelope.

## Open risks

- Cockpits look alike under one kit. Formula and Cigar differ by collar, hoop and tub section only. That is the cost of a 3.5-wide tub.
- A halo inside the Prototype cabin and a canopy inside the cage fit, but look busy. A shop hint may help. Do not restrict fitting.
- On cockpits without a cage the Sprint Top Wing front stays hang free (stubs 0.75 long).
- Upright ring pods read as wheels in side view. Real meshes need a large glowing core and no tread.
- A Roblox avatar with arms out is 4 wide. The tub opening is 2.2. The seat pose must bring the arms forward.
- The hardpoints are convention. The validator passes "reach" on any box of a union and tests vertices only.
- The car is 15 wide with open pods and skirts 0.7 above the ground. Collision and kerb clearance need a play test.
