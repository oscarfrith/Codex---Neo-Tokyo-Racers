# Hauler: frame standard (blockout result)

Status: design exploration, 2026-10-01. Not approved, not game content. Spec: `scripts/vehicle_blockouts/specs/hauler.json`. Previews: `scripts/vehicle_blockouts/previews/hauler/`. Class sheet: [hauler.md](hauler.md). Rules: [exploration contract](../../../scripts/vehicle_blockouts/CONTRACT.md).

Root space: +X right, +Y up, forward is -Z, studs. "X ±4.4" means -4.4 to 4.4. "Both sides" means the box is mirrored across X.

## Frame standard

| Slot id | Player label | Envelope | Anchor (parent, seam) |
|---|---|---|---|
| Cockpit | Cab | Cab: X ±4.2, Y 0.4..7.6, Z -6..3. Overhang: X ±4.2, Y 3.6..7.6, Z -10..-6. Ladder frame: X ±3.4, Y -0.8..0.4, Z -14..14 | Root |
| Engine1 | Front Clip | Core: X ±4.4, Y 0.4..3.6, Z -14..-6. Arches, both sides: X 4.4..6.8, Y 2.0..3.6, Z -14..-6 | Cab, Z -6 |
| Engine2 | Bed | Body: X ±4.4, Y 0.4..7.8, Z 3..14. Shoulders, both sides: X 4.4..6.8, Y 2.0..3.0, Z 4.8..14 | Cab, Z 3 |
| Stabilisers | Hover Pods | Four corners. Low: X 3.4..7.0, Y -1.7..0.4. High: X 4.4..7.0, Y 0.4..2.0. Front Z -13.6..-7.4, rear Z 6.4..12.6 | Cab (axle beams), X 3.4 |
| SidePods | Side Gear | Both sides: X 4.2..6.6, Y -1.4..2.0, Z -5.8..2.8 | Cab, X 4.2 |
| Boost | Stacks | Stack bay, both sides: X 4.4..6.6, Y -1.4..9.8, Z 3..4.8. Dump bay, both sides: X 4.4..6.6, Y -1.4..2.0, Z 4.8..6.2. Tail port: X ±2.6, Y 1.8..3.8, Z 14..16.2 | Cab, Z 3. Tail port sits on the bed tail board, Z 14 |
| FrontBumper | Front Bar | X ±6.8, Y -1.4..4.8, Z -16..-14 | Front Clip, Z -14 |
| RearBumper | Rear Bar | X ±6.8, Y -1.4..1.8, Z 14..16 | Bed, Z 14 |
| RearSpoiler | Bed Rig | Legs, both sides: X 4.4..5.4, Y 3.0..9.8, Z 4.8..14. Overhead: X ±4.4, Y 7.8..9.8, Z 4.8..14 | Bed shoulders, Y 3.0 |
| Hood | Hood | Hood pad: X ±3.0, Y 3.6..5.2, Z -12.6..-10. Snorkel, right side only: X 4.4..5.6, Y 3.6..8.4, Z -9.4..-6.2 | Front Clip, Y 3.6 |
| Roof | Roof Rig | X ±4.2, Y 7.6..9.6, Z -6..3 | Cab roof, Y 7.6 |
| Accessory | Extras | Both sides: X 4.2..5.8, Y 2.0..9.8, Z -5.8..2.8 | Cab, X 4.2 |

No two envelopes overlap. Whole vehicle: 14 W, 32.2 L, Y -1.7..9.8. Body width is 8.8. The pods set the 14.

## Datums

| Datum | Value | What lines up on it |
|---|---|---|
| Hover plane | Y -2.0 | Ground. Nothing goes below Y -1.7 |
| Sill | Y 0.4 | Frame top. Body undersides start at Y 0.5 |
| Deck line | Y 2.0 | Running gear below, body above. Pod envelope top, arch underside, Side Gear top |
| Beltline | Y 3.6 | Hood top, bed rail top, cab stripe, floor of an overhanging cab |
| Roof | Y 7.4 | Top of every cab roof. Roof pad: X ±2.4, Z -3.0..-0.8 |
| Pod centres | X ±5.2, Z -10.5 and 9.5 | Axle beams, arches and bed flares |

## Seam rules

1. Every cab carries the same ladder frame: two rails, two axle beams that end at X ±3.35, two cab crossmembers. Pods hang off the axle beams. No module carries another slot.
2. Cab bodies end at Z -5.8 and Z 2.8. Clips end at Z -6.2 and beds start at Z 3.3. Each side puts a dark `detail` plate in the gap.
3. Every Front Clip reaches Z -13.8. Its hood top is at Y 3.0..3.6 on the hood pad. Its cowl deck is at Y 3.3..3.6 from Z -10 to -6.2. It has a shoulder at X 4.4..5.6 by the cab for the snorkel. It has an arch over each front pod.
4. Every Bed has a front face at Z 3.3..3.5 and a tail face at Z 13.9 that covers X ±2.6 between Y 1.8 and 2.8. It has a shoulder on each side, X 4.4..5.4, top at Y 2.6..3.0, from Z 4.9 to 13.9.
5. Every cab reaches X 3.2 or more at sill height and at window-sill height. Narrow cabs add a step plinth and stand-offs.
6. Roof Rig feet land only on the roof pad. Bed Rig feet land on the bed shoulders at Y 3.0. A Bed Rig crosses the bed only above Y 7.8.
7. Shadow gaps are 0.2 to 0.5 studs. Stripes sit just under the beltline so they flow across the gaps.

## Authoring rules for real meshes

- Model the ladder frame once. Reuse it in every cab. Do not move the axle beams.
- A cab may overhang the Front Clip only above the beltline and only back from Z -10. A cab-over driver sits on a floor at Y 4.0, head under Y 7.1. Other cabs seat the driver at Y 2.9.
- Keep cab roofs at Y 7.4 with a flat pad. A low or domed roof leaves rigs floating.
- Finish the rear face of every clip and the front face of every bed. A narrow cab (Kei Cab is 6.8 wide) shows 0.9 studs of them each side.
- Headlights live on the clip and tail lights on the bed. Cabs carry marker lights only.
- Beds stay inside X ±4.4 above the shoulder. A Bed Rig is a portal: legs outside the bed walls, bars over the top. This is what lets a Chase Rack fit a Box Van.
- Pods are flat, horizontal discs or drums with the glow underneath. An upright disc reads as a wheel. Stance comes from the pod only: Slammed tucks a thin dish under the arch, Long Travel hangs a disc on long coil-overs, Monster stacks a drum and a tower. The body never moves.
- Stacks stand in the stack bay at X 4.45..5.55, tight to the cab corner. Dumps stay below the deck line. Burner cans exit through the tail port.
- Chrome is the `secondary` channel. Lamps and marker rows are `neon`. Linkages, frame and treads are `detail`.
- Keep a build at 150 parts or fewer. Here a cab is 27 to 36 parts including 7 for the frame, a clip 13 to 23, a bed 14 to 16, a pod set 20.

## What the blockout shows

- 5 cabs, 35 modules, 8 builds. That is 3,732,480 possible combinations with no clipping by construction.
- Builds 1 to 3: the Prerunner kit and paint on Single Cab, Cab-Over and Kei Cab.
- Builds 4 to 6: Crew Cab as Minitruck, Show Truck and Courier.
- Builds 7 and 8: a Checker Cab taxi with a show nose and slammed pods; a Kei Cab on monster pods with a flatbed and plough.

## Validator output

`SPEC hauler: 0 error(s), 3 warning(s) {'cockpits': 5, 'modules': 35, 'builds': 8, 'parts_in_builds': 1143}`

The three warnings say Single Cab, Cab-Over and Checker Cab each appear in one build. That is arithmetic: eight builds with the required pattern cannot show five cabs twice. Each of those cabs is still checked against every seam.

## Open risks

- **Cab-Over still shows a nose.** The Scoop needs a hood pad ahead of the cab, so 4 studs of clip show in front of the cab face. A true flat face needs the Hood slot moved or dropped for this class.
- **Slammed is a look, not a ride height.** The sill stays 2.4 studs above the hover plane. A real drop must move the whole vehicle, not the pods.
- **Roof pad is central.** Light bars sit mid-roof on forward cabs (Cab-Over, Kei Cab).
- **Two seams are rules only.** The tool checks one anchor per slot. The tail port and the rear pods rely on seam rules 1 and 4.
- **Size.** 14 W and 32 L against a pitch of 13 and 30. Stack and whip tips reach Y 9.8, 11.8 studs above the ground. Check camera, tunnels and the garage.
- **Bed Rigs are tall.** They must clear a Box Van, so every rig bar sits above the cab roof.
- **Checker band.** Built from separate parts here. The live game needs a decal or texture route.
- **Snorkel is one-sided.** It is the only asymmetric envelope. Confirm that mirroring rules allow it.
