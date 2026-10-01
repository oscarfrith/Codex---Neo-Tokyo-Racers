# Dart frame standard

Status: design exploration, 2026-10-01. Primitive blockout only. Nothing here is game content or approved.
Spec: [dart.json](../../../scripts/vehicle_blockouts/specs/dart.json). Previews: [sheet](../../../scripts/vehicle_blockouts/previews/dart/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/dart/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/dart/standard.png).

Dart is one slender fuselage on the centreline. A prow of prongs bolts to its front and a drive block to its rear. Wings hang off the flanks. Airbrakes, tail fins, tail cone and afterburner hang off the drive. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Envelopes

| Slot | Player label | X | Y | Z | Anchors to |
|---|---|---|---|---|---|
| Cockpit | Fuselage | -3.2..3.2 | -0.5..2.6 | -7..8 | root |
| Engine1 | Prow | -6.5..6.5 | -0.5..2.6 | -16.5..-7 | fuselage prow collar, Z -7 |
| Engine2 | Drive | -3.4..3.4 | -0.5..3.4 | 8..14.5 | fuselage drive collar, Z 8 |
| SidePods | Wings | 3.2..9, mirrored | -1.5..3.6 | -7..8 | fuselage hardpoints, X ±3.2 |
| Stabilisers | Airbrakes | 3.4..7.5, mirrored | -0.5..4 | 8..15 | Drive hardpoints, X ±3.4 |
| Boost | Afterburner | -2.4..2.4 | -0.2..2.8 | 14.5..18.5 | Drive burner collar, Z 14.5 |
| FrontBumper | Nose Tip | -3.5..3.5 | -0.5..2.6 | -19..-16.5 | Prow nose collar, Z -16.5 |
| RearBumper | Tail Cone | -1.6..1.6 | -2..-0.5 | 8..19 | Drive keel pad, Y -0.5 |
| RearSpoiler | Tail Fins | -3.4..3.4 | 3.4..7.4 | 8..17 | Drive fin pad, Y 3.4 |
| Hood | Spine | -1.2..1.2 | 2.6..3.8 | 2.6..8 | fuselage deck, Y 2.6 |
| Roof | Canopy | -1.8..1.8 | 2.6..4.2 | -5..2.6 | fuselage canopy sill, Y 2.6 |

No two envelopes overlap. Accessory is not used. Built size: 14.1 to 17.9 wide, 36.9 to 37.6 long, 4.7 high over the canopy (8.3 to 8.8 from skid to fin tip).

## Datums

| Datum | Value | Meaning |
|---|---|---|
| Hover plane | Y -2.0 | Ground. Nothing built goes below -1.6. |
| Sill | Y 0.0 | Underside of the painted hull. Fuselage, prow and drive hover emitters use the 0.5 below it. |
| Beltline | Y 1.3 | Thrust axis. Prong centrelines, wing planes, drive and burner axes, every collar centre. |
| Deck | Y 2.6 | Top of every fuselage: canopy sill and spine deck. |
| Pilot station | Z -3.8..2.0 | Tub opening, 2 wide. Reclined 5-stud pilot, head at Z 0.8, head top Y 2.55. |

## Pads and collars

| Pad | Owner | Where | Used by |
|---|---|---|---|
| Prow collar | Fuselage | centre, Y 1.3, 2.2 wide, 1.9 high, Z -7 | Prow |
| Drive collar | Fuselage | centre, Y 1.3, 2.6 wide, 2.1 high, Z 8 | Drive |
| Wing hardpoints | Fuselage | X ±3.2, covering Y 1.2..1.3, at Z -2.0 and Z 4.5 | Wings root rib (X 3.2..3.6, Z -3..5.5) |
| Canopy sill | Fuselage | two rails, Y 2.6, 2.0 to 2.2 apart, Z -3.8..2.0 | Canopy |
| Spine deck | Fuselage | flat, Y 2.6, X ±0.8 or wider, Z 2.6..7.4 | Spine |
| Nose collar | Prow | centre, Y 1.3, 1.0 diameter, Z -16.5 | Nose Tip |
| Burner collar | Drive | centre, Y 1.3, 1.2 to 2.0 diameter, Z 14.5 | Afterburner |
| Fin pad | Drive | top at Y 3.3..3.4, X ±0.5, Z 9.2..11.4 | Tail Fins |
| Keel pad | Drive | underside at Y -0.45, X ±0.4, Z 9.4..11.2 | Tail Cone |
| Airbrake hardpoints | Drive | X ±3.4, Y 1.05..1.5, Z 9.8..11.0 | Airbrakes |

## Seam rules

1. Every seam is one fixed pad or collar on the centreline, or the two fixed wing stations. A seam never follows the shape of a module.
2. Paint stops 0.4 short of the Z -7 and Z 8 seam planes on both sides. Dark `detail` collars fill the rest. Fuselage paint stops at X 3.1, the dark wing root rib runs X 3.2 to 3.6, wing paint starts at 3.6.
3. The owner must fill its pad. The user must sit on it, may overhang it, and touches its parent nowhere else.
4. Reach: the validator allows 1 stud. The blockout holds 0.1 on all 137 parent-child pairs (bounding-box check).

## Authoring rules for real meshes

- Author every mesh in cockpit root space. Keep every vertex inside the slot envelope. Check the corners of rotated parts: a fin canted 35 degrees and 3.6 tall uses 2.4 of width, an open brake flap rises 1.2. Keep every pad and collar at its datum. Sculpt everything else.
- A module with two or three bodies still carries the single centre collar. Twin Prong carries the nose collar on a dark sensor boom. Twin Drive and Tri Cluster carry the burner collar on a centre core. Twin Fins and V-Tail grow from one centre pylon.
- Every fuselage keeps the deck flat at Y 2.6 from the pilot station to Z 7.4. No sloping tail decks.
- The fuselage owns the tub, the pilot and the side glazing band (Y 1.8..2.4). The Canopy owns all glass above Y 2.6.
- A fuselage is recognised by its plan and flank, not its glass: tube, delta, hexagon, twin booms, barbs. Put the accent colour on that feature.
- Slim fuselages (Needle, the Arrowhead shaft) reach the wing stations with dark struts. Open fuselages (Twinboom) still carry a deck rail and a rear yoke with the drive collar.
- Wings hang from the root rib alone. Outboard of X 3.6 the shape is free: delta, forward sweep, floats on struts, stubs.
- Round drive barrels are 3.6 across at most on the thrust axis (the envelope floor is 1.8 below it). Every Drive needs the fin pad, the keel pad and both airbrake hardpoints, even a bare hoop.
- Airbrakes are authored open. The closed pose must fit the same envelope. Line the main crease up with Y 1.3. Each module carries its own lights and hover glow.

## What the blockout showed

- 5 fuselages: Needle (tube), Delta (stepped lifting body), Manta (flat hexagon), Twinboom (pod and high booms), Arrowhead (barbs and shaft).
- 30 modules: 4 Prow, 4 Drive, 4 Wings, 3 Airbrakes, 2 Afterburner, 3 Nose Tip, 2 Tail Cone, 3 Tail Fins, 2 Spine, 3 Canopy.
- 8 builds of 128 to 145 parts. Builds 1 to 3: Works kit on Needle, Manta and Twinboom. Builds 4 to 6: Delta with Prototype, Salvage and Privateer kits. Builds 7 and 8: mixed.
- 207,360 combinations exist. Every part stays in its own envelope and the envelopes are disjoint, so none can clip. The prow does change the whole silhouette: twin prong, spear, trident and hammerhead on one fuselage.
- Most important lesson: prongs, drives and fins come in ones, twos and threes, so their bodies cannot be seams. A Nose Tip on the prong tips or fins on the nacelles would float on half the parts. One centreline collar per seam covers every case.

Validator: `SPEC dart: 0 error(s), 3 warning(s) {'cockpits': 5, 'modules': 30, 'builds': 8, 'parts_in_builds': 1107}`
Warnings left: `cockpit needle`, `cockpit manta` and `cockpit arrowhead` each `appears in fewer than 2 builds`. Eight builds in the 3 + 3 + 2 pattern cannot show five cockpits twice each. Four cockpits would still leave one warning.

## Open risks

- Size: 37 to 37.6 long is about 3.5 over the brief and uses the whole Z limit. Wings reach X ±9 (17.9 wide), 2 over the brief. Fix if needed: shorten the Prow by 2 and the Afterburner by 1.5, pull the wing limit in to X ±8.
- The validator does not know about pads. A module can pass and still float. Add pads to the spec schema.
- The Canopy slot takes the glass away from the fuselage, and there is one pilot station. Bubble could not be built as a cockpit (make it a Canopy module). A rear-pilot layout needs a second sill.
- The fuselage is small in a 3/4 view. With one kit, three fuselages read most clearly from above.
- A Nose Tip on Twin Prong hangs on a thin boom. Ram Scoop looks heavy there.
- Needle leaves 1.9 studs of open strut between hull and wing root. It is attached, but may look fragile on real meshes.
- Hitbox width varies from 14 to 18 between kits. Airbrake animation needs a hinge convention. Neither is tested. All parts are mirrored, so one-sided modules are untested too.
