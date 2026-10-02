# Cruiser frame standard (round 2)

Status: design exploration, round 2, 2026-10-01. Primitive blockout only. Nothing here is game content or approved.
Spec: [cruiser.json](../../../scripts/vehicle_blockouts/specs/cruiser.json), written by [gen/cruiser.py](../../../scripts/vehicle_blockouts/gen/cruiser.py). Previews: [matrix](../../../scripts/vehicle_blockouts/previews/cruiser/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/cruiser/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/cruiser/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/cruiser/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/cruiser/standard.png).

Cruiser is a long, low land yacht on jet thrust. Two slab-sided body halves meet at a shadow gap under the cabin. Their tops form one flat deck at the beltline. The cockpit is the cabin only: everything above the beltline. It sits on that deck, so any roofline fits any pair of halves. There are no wheels, rotors, rings or discs. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Frame standard

| Slot | Player label | X | Y | Z | Anchor |
|---|---|---|---|---|---|
| Cockpit | Cabin | -4.8..4.8 | 3.0..5.8 | -6.5..9.0 | root; sits on the cabin deck |
| `FrontBody` | Front Half | -4.8..4.8 | 0..3.0 | -16.4..0 | cockpit, deck at Y 3.0 |
| `RearBody` | Rear Half | -4.8..4.8 | 0..3.0 | 0..15.5 | cockpit, deck at Y 3.0; Front Half at Z 0 |
| `Engine1` | Bonnet Turbine | -3.4..3.4 | 3.0..5.0 | -15.6..-6.5 | Front Half, bonnet pad |
| `Engine2` | Boot Turbine | -3.6..3.6 | 3.0..5.4 | 9.0..17.0 | Rear Half, boot pad |
| `Stabilisers` | Sill Jets | -6.0..6.0 | -2.0..0 | -16.4..11.5 | both halves, belly pad |
| `Boost` | Tail Burner | -5.6..5.6 | -2.0..0 | 11.5..19.0 | Rear Half, belly pad |
| `SidePods` | Flanks | 4.8..5.6, mirrored | 0..3.0 | -12.6..12.6 | both halves, flank pad |
| `FrontBumper` | Front Chrome | -5.6..5.6 | -1.6..3.0 | -18.4..-16.4 | Front Half, nose seam |
| `RearBumper` | Rear Chrome | -5.6..5.6 | 0..3.0 | 15.5..17.0 | Rear Half, tail seam |
| `RearSpoiler` | Fins | 3.6..5.6, mirrored | 3.0..8.4 | 9.0..15.5 | Rear Half, fin pad |

Extra boxes. Front Half: fender tops (X 3.4..4.8 mirrored, Y 3.0..4.0, Z -15.6..-6.5), nose top (full width, Y 3.0..4.0, Z -16.4..-15.6), nose corners (X 4.8..5.6 mirrored, Y 0..3.0, Z -16.4..-12.6). Rear Half: tail corners (X 4.8..5.6 mirrored, Y 0..3.0, Z 12.6..15.5). Tail Burner: stack zone (Y 0..9.8, Z 17.0..19.0). Fins: wing zone (X -3.6..3.6, Y 5.4..8.4, Z 9.0..15.5). No two envelopes overlap.
Built size: 10.8 to 11.7 wide, 6.4 to 10.8 tall, 35.8 to 37.0 long. The target was 34 long; bumpers and the boost add the rest, inside the Z limit.

## Datums

- Hover plane Y -2.0 (the road). Sill Y 0.2: the flat belly of both halves; only jets go below.
- Bar line Y 1.4: bumper bars stay below, lamps stay above. Beltline Y 3.0: the flat deck and the base of every cabin.
- Flank X 4.7: the painted body side. Flank trim starts at 4.8. Seams at Z -16.4 (nose), 0 (mid) and 15.5 (tail).
- Pad run Z -12.6..12.6: every pad lies in this run, and here all halves are the same slab.

## Hardpoint pads

| Pad | Where | Owner | Lands on it |
|---|---|---|---|
| Cabin deck | Y 3.0, X within 4.7, Z -6.5..9.0 | both halves | every cabin |
| Bonnet pad | Y 3.0, X within 3.4, Z -12.6..-7.0 | Front Half | Bonnet Turbine |
| Boot pad | Y 3.0, X within 3.6, Z 9.3..12.6 | Rear Half | Boot Turbine |
| Fin pad | Y 3.0, X 3.6..4.6, Z 9.2..12.6 | Rear Half | Fins |
| Flank pad | X 4.7, Y 0.2..3.0, Z -12.6..12.6 | both halves | Flanks |
| Belly pad | Y 0.2, full width, Z -12.6..12.6 | both halves | Sill Jets (to Z 11.0), Tail Burner hanger (Z 11.6..12.6) |
| Bumper pads | dark brackets, X 2.5..3.5, Y 0.4..1.0, out to Z -16.36 and 15.46 | each half | Front Chrome, Rear Chrome |
| Free zones | nose Z -16.4..-12.6, tail Z 12.6..15.5 | each half | nothing: own length, height, width and plan |

## The four fundamentals

| Slot | Where it sits | Why there |
|---|---|---|
| `Engine1` Bonnet Turbine | On the bonnet pad, ahead of the windscreen | The long bonnet is the class's stage. It reads from the front three-quarter view. |
| `Engine2` Boot Turbine | On the boot pad between the fins, nozzles past the tail | Jet-age boot. It fills the chase camera. |
| `Stabilisers` Sill Jets | Under both sills, Y -2.0..0, in and between the blanked arches | Lift where the wheels were. It reads from the front and from below, and the car looks slammed. |
| `Boost` Tail Burner | Under the tail, hung from the belly pad, firing past the rear chrome | Where the exhausts were. The longest glow in the chase view. |

## Kits

| Kit | Culture | Native cockpit | `Engine1` | `Engine2` | `Stabilisers` | `Boost` |
|---|---|---|---|---|---|---|
| Lowrider | Lowrider | Hardtop (pillarless, thin flat roof) | Quad Stacks | Tri-Power | Hop Jets | Twin Cans |
| Lead Sled | Lead Sled | Sled (chopped, slit glass) | Torpedo | Deck Slot | Sill Cascade | Lake Burners |
| Fin Era | Fin Era | Finliner (bubble top) | Twin Bullets | Fin Rockets | Rocket Sponsons | Atomic |
| VIP | VIP | VIP (tall boxy saloon) | Slot Plenum | Boot Turbine | Curtain Skirt | Slot Burner |
| Kaido | Kaido Racer | Kaido (louvred fastback) | Works Turbo | Quad Megaphones | Splay Jets | Bamboo Stacks |

| Kit | Front Half | Rear Half | Flanks | Front Chrome | Rear Chrome | Fins |
|---|---|---|---|---|---|---|
| Lowrider | Boulevard: long square nose, quad lamps | Long Deck: square, six round lamps | Fender Skirts | Blade and Guards | Chrome Blade | Antenna Rails |
| Lead Sled | Pontoon: drooping round fenders | Turtle Tail: drooping, bullet lamps | Lake Pipes | Ripple Bar | Roll Pan | Hump Fins |
| Fin Era | Jetliner: nacelle fenders, gunsight blades | Jet Tail: jet-tube fenders, cut-up | Side Spears | Bullet Bumper | Jet Pods | Tall Fins |
| VIP | Formal: upright grille shell, blisters | Formal Trunk: light bar, blisters | Long Vents | Lip Kit | Diffuser Valance | Trunk Wing |
| Kaido | Shark Nose: undercut prow | Works Tail: bobbed, cut-up | Overfenders | Chin Spoiler | Tube Bar | Works Wing |

## Authoring rules for real meshes

1. Author every part in cockpit-root space. Stay inside the slot envelope and set a paint channel on every part.
2. A cabin starts at Y 3.0 and owns all glass and the roofline. A roof chop is a new cockpit, not a module.
3. Inside the pad run a body half is the standard slab: deck at 3.0, flank at 4.7, belly at 0.2. Style it only in the shoulder, crease and arch panel. Close the mid seam with a dark collar.
4. Give each half its character in the nose or tail, the fender tops and the corners. Always carry the bumper brackets to the seam.
5. A module touches a pad, never a body shape. Leave a 0 to 0.3 shadow gap and bridge it with dark linkage.
6. Anything past a pad must carry itself. Engines, fins and wings overhang the tail on their own structure.
7. Fins live in the Fins slot only. Arches are blanked or vented; lift jets hang below them.
8. No wheel, ring, disc or rotor shapes. Jets only, each with an intake, a body and a glowing `thrust` nozzle, longer than it is wide.

## Validator result

```
SPEC cruiser: 0 error(s), 20 warning(s) {'cockpits': 5, 'kits': 5, 'modules': 50, 'builds': 13, 'worst_gap': 0.2, 'min_distinctness': {'FrontBody': 0.04, 'RearBody': 0.02, 'Engine1': 0.43, 'Engine2': 0.44, 'Stabilisers': 0.53, 'Boost': 0.47, 'SidePods': 0.44, 'FrontBumper': 0.29, 'RearBumper': 0.28, 'RearSpoiler': 0.64, 'Cockpit': 0.27}, ...build sizes...}
```

All 20 warnings are look-alike warnings for the two body halves. Pair scores run 0.04 to 0.10 for Front Half and 0.02 to 0.05 for Rear Half. Every other slot and the cockpits meet their targets.

## Open risks

- **Body halves cannot reach 0.35.** The pad run is 77% of a front half and 81% of a rear half, and it is the same slab by design. The noses and tails differ in outline, but the score measures the whole half. Reaching the target needs halves of different length or height, which breaks the pads. Owner call.
- **Five cockpits, not six.** Longroof is not built. It needs a sixth kit.
- **Bamboo Stacks stand behind the tail.** The stack zone starts at Z 17.0, so the pipes rise about 2 studs behind a short tail.
- **Overhangs on drooping tails.** Tall Fins and boot turbines hang over the Turtle Tail with up to 1.6 studs of air beneath.
- **Narrow or dark cabins.** Sled and Kaido are narrower than the deck, which reads as a wide shoulder. Glass renders dark, so the Finliner bubble reads by outline only.
