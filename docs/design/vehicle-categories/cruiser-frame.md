# Cruiser frame standard (round 2, after the second review)

Status: design exploration, round 2, 2026-10-02. Primitive blockout only. Nothing here is game content or approved.
Spec: [cruiser.json](../../../scripts/vehicle_blockouts/specs/cruiser.json), written by [gen/cruiser.py](../../../scripts/vehicle_blockouts/gen/cruiser.py). Previews: [mix A](../../../scripts/vehicle_blockouts/previews/cruiser/mix_a.png) and [mix B](../../../scripts/vehicle_blockouts/previews/cruiser/mix_b.png) (every slot random), [matrix](../../../scripts/vehicle_blockouts/previews/cruiser/matrix.png), [fundamentals](../../../scripts/vehicle_blockouts/previews/cruiser/fundamentals.png), [sheet](../../../scripts/vehicle_blockouts/previews/cruiser/sheet.png), [exploded](../../../scripts/vehicle_blockouts/previews/cruiser/exploded.png), [standard](../../../scripts/vehicle_blockouts/previews/cruiser/standard.png), and one `row_<cockpit>.png` per cockpit.

Cruiser is a long, low land yacht on jet thrust. Two body halves meet at a shadow gap under the cabin. Between Z -12.6 and 12.6 their tops form one flat deck at the beltline, and every pad lies in that run. The cockpit is the cabin: everything above the beltline, with its own length, height, width and place on the deck. Outside the pad run each half has its own nose or tail, and ahead of the cowl a front half shapes its own fender shoulder. There are no wheels, rotors, rings or discs. Root space: +X right, +Y up, forward is -Z. Units are studs.

## Frame standard

| Slot | Player label | X | Y | Z | Anchor |
|---|---|---|---|---|---|
| Cockpit | Cabin | -4.8..4.8 | 3.0..6.5 | -6.5..9.0 | root; sits on the cabin deck |
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
Built size: 11.0 to 11.9 wide, 6.4 to 9.6 tall, 35.8 to 37.0 long. The target was 34 long; bumpers and the boost add the rest, inside the Z limit. The largest build has 216 parts (limit 220).

## Datums

- Hover plane Y -2.0 (the road). Sill Y 0.2: the flat belly of both halves; only jets go below.
- Bar line Y 1.4: bumper bars stay below, lamps stay above. Beltline Y 3.0: the deck in the pad run and the base of every cabin.
- Flank X 4.7: the painted body side, flat up to the shoulder line Y 2.25. Flank trim starts at 4.8. Seams at Z -16.4 (nose), 0 (mid) and 15.5 (tail). Cowl Z -6.6: ahead of it a front half owns its fender shoulder.

## Hardpoint pads

| Pad | Where | Owner | Lands on it |
|---|---|---|---|
| Cabin deck | Y 3.0, X within 4.7, Z -6.5..9.0 | both halves | every cabin, anywhere in this run |
| Bonnet pad | Y 3.0, X within 3.4, Z -12.6..-7.0 | Front Half | Bonnet Turbine |
| Boot pad | Y 3.0, X within 3.6, Z 10.2..12.6 | Rear Half | Boot Turbine |
| Boot shelf | Y 3.0 behind the boot pad: at least X within 3.0 back to Z 13.7 (Jet Tail is the shortest; Works Tail dips 0.6) | Rear Half | nothing: it sits under the boot turbine overhang |
| Fin pad | Y 3.0, X 3.6..4.6, Z 9.2..12.6 | Rear Half | Fins |
| Flank pad | X 4.7, Y 0.2..2.25, Z -12.6..12.6 | both halves | Flanks |
| Belly pad | Y 0.2, full width, Z -12.6..12.6 | both halves | Sill Jets (to Z 11.0), Tail Burner hanger (Z 11.6..12.6) |
| Bumper pads | dark brackets, X 2.5..3.5, Y 0.4..1.0, out to Z -16.36 and 15.46 | each half | Front Chrome, Rear Chrome |
| Seam face | solid from Y 0.2 to 1.4, out to Z -16.3 and 15.4 | each half | nothing: it closes the body behind every bumper |
| Free zones | nose Z -16.4..-12.6, tail Z 12.6..15.5, fender tops, bonnet shoulder (outboard of X 3.4, above Y 2.25, Z -12.6..-6.6) | each half | nothing: own length, height, width and plan |

## The four fundamentals

- `Engine1` Bonnet Turbine sits on the bonnet pad. Every nozzle turns out or up, so nothing fires at the windscreen. Every glow is 0.8 or more across. Options: Quad Stacks (four upright intake stacks, fat side nozzles), Torpedo (one long turbine, split nozzle), Twin Bullets (two slim nacelles), Slot Plenum (tall chrome box, vaned intake 5 wide, side-exit slots), Works Turbo (offset turbine, flared megaphone one side, screamer pipe the other, cooler hung ahead to Z -14.55), Scoop and Zoomies (ram scoop, six fat zoomie pipes).
- `Engine2` Boot Turbine sits on the boot pad from Z 10.2, clear of the longest cabin, with nozzles past the tail. Options: Tri-Power (three cans), Deck Ramp (chrome ramp, twin scoops, tall nozzle box), Fin Rockets (two long nacelles), Boot Turbine (one big turbine with side scoops), Quad Megaphones (four raked pipes), Fishtail (snorkel intake, fan-out nozzle).
- `Stabilisers` Sill Jets hang from the belly pad. Options: Hop Jets (one chrome lift trough per corner, 3.2 long, glow skirt), Sill Cascade (full-length vane rail), Rocket Sponsons (one long pod a side), Curtain Skirt (plenum tray, three deep skirt segments, 0.45-tall glow), Splay Jets (four toed-out pods on cross arms), Tri-Foil (a nose span foil and two anhedral foils with tip jets).
- `Boost` Tail Burner hangs under the tail and fires past the rear chrome. Options: Twin Cans, Lake Burners (side-swept pipes), Atomic (single rocket), Slot Burner (flat and wide), Bamboo Stacks (two fat cans under the tail corners at X 4.2, two stacks to Y 7.6, each tied to the bumper line by a stay), Outboards (twin jet outboards on a transom arm).

## Cockpits and kits

| Kit | Native cockpit (X half width, Z run, top Y) | `Engine1` | `Engine2` | `Stabilisers` | `Boost` |
|---|---|---|---|---|---|
| Lowrider | Hardtop: pillarless, thin flat roof (4.65, -5.6..7.2, 5.3) | Quad Stacks | Tri-Power | Hop Jets | Twin Cans |
| Lead Sled | Sled: chopped, slit glass, turtle back to the boot (3.95, -3.9..9.0, 4.95) | Torpedo | Deck Ramp | Sill Cascade | Lake Burners |
| Fin Era | Finliner: one-arc bubble top, chrome hoops and spine (4.1, -6.4..7.6, 6.2) | Twin Bullets | Fin Rockets | Rocket Sponsons | Atomic |
| VIP | VIP: tall boxy saloon, set back (4.6, -3.4..8.2, 6.4) | Slot Plenum | Boot Turbine | Curtain Skirt | Slot Burner |
| Kaido | Kaido: louvred fastback, ducktail (3.75, -6.3..8.9, 5.6) | Works Turbo | Quad Megaphones | Splay Jets | Bamboo Stacks |
| Surf Wagon | Longroof: wagon roof to the tailgate, vista deck (4.6, -5.6..9.0, 5.85) | Scoop and Zoomies | Fishtail | Tri-Foil | Outboards |

| Kit | Front Half | Rear Half | Flanks | Front Chrome | Rear Chrome | Fins |
|---|---|---|---|---|---|---|
| Lowrider | Boulevard: longest square nose, fender blades | Long Deck: longest, flat, lip over a lamp cove | Fender Skirts | Blade and Guards | Chrome Blade | Antenna Rails |
| Lead Sled | Pontoon: drooping nose, fat fender rolls from nose to cowl | Turtle Tail: deck flat to Z 14.4 then rolls over; fat fenders droop either side | Lake Pipes | Ripple Bar | Roll Pan | Hump Fins |
| Fin Era | Jetliner: nacelle fenders lead, full-width fender peaks to Y 3.9 | Jet Tail: jet-tube fenders, centre set back to Z 13.7 | Side Spears | Bullet Bumper | Jet Pods: two pods a side, open centre | Tall Fins |
| VIP | Formal: short, grille shell to Y 3.8, blisters | Formal Trunk: boot hump, shoulders at Y 2.4, sloped face | Long Vents | Lip Kit | Diffuser Valance | Trunk Wing: blade at Y 6.2 |
| Kaido | Shark Nose: bonnet rakes from Z -13 to a point at Y 2.2, undercut face, chamfered bonnet edges | Works Tail: bobbed at Z 14.6, ducktail, diffuser tunnel, boxed flares to X 5.4 | Overfenders | Chin Spoiler: flat shelf 0.3 thick, stay rods | Tube Bar | Works Wing |
| Surf Wagon | Bullnose: tall centre prow, low round fenders | Barrel Back: tucks in to X 4.1, rolls over | Wood Panels: pale planks in a dark frame, top at Y 2.35 | Push Bar | Step Bumper | Board Rack |

## Authoring rules for real meshes

1. Author every part in cockpit-root space. Stay inside the slot envelope and set a paint channel on every part.
2. A cabin starts at Y 3.0 and owns the cowl, all glass, the roofline and the rear shelf. A roof chop is a new cockpit, not a module.
3. Inside the pad run a body half is the standard slab: deck at 3.0, flank at 4.7 up to Y 2.25, belly at 0.2. Close the mid seam with a dark collar. Ahead of the cowl a front half may reshape the shoulder outboard of X 3.4 and above Y 2.25.
4. Give each half its own length, height and plan in the free zones. Always end it in a solid seam face from the sill to the bar line, and carry the bumper brackets to the seam.
5. A rear half holds the deck at Y 3.0 behind the boot pad, at least X within 3.0 back to Z 13.7 (Turtle Tail: X within 3.5 to Z 14.4). Put any droop in the fenders outboard and in the tail end.
6. A module touches a pad, never a body shape. Leave a 0 to 0.3 shadow gap and bridge it with dark linkage. Anything past a pad must carry itself.
7. Bonnet nozzles turn out or up, with a glow 0.8 or more across. Boot intakes start at Z 10.2 or later. A Tail Burner part that rises above the belly stays outboard of X 3.6. A wing blade over the boot stays at Y 6.2 or higher (the tallest boot turbine is 5.35; the Board Rack bars sit at 5.65).
8. Flank trim never copies the cabin glass: no dark panel in a pale frame. Front Chrome is a bar, a dam or a thin flat shelf, never a ramp.
9. Fins live in the Fins slot only. Arches are blanked or vented; lift jets hang below them. No wheel, ring, disc or rotor shapes: jets only, each with an intake, a body and a glowing `thrust` nozzle, longer than it is wide.

## Validator result

```
SPEC cruiser: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 60, 'builds': 15, 'worst_gap': 0.2, 'min_distinctness': {'FrontBody': 0.55, 'RearBody': 0.43, 'Engine1': 0.41, 'Engine2': 0.42, 'Stabilisers': 0.51, 'Boost': 0.48, 'SidePods': 0.48, 'FrontBumper': 0.48, 'RearBumper': 0.4, 'RearSpoiler': 0.57, 'Cockpit': 0.47}, 'min_distinctness_whole': {'FrontBody': 0.03, 'RearBody': 0.01, 'Engine1': 0.29, 'Engine2': 0.33, 'Stabilisers': 0.5, 'Boost': 0.43, 'SidePods': 0.47, 'FrontBumper': 0.35, 'RearBumper': 0.28, 'RearSpoiler': 0.57, 'Cockpit': 0.23}, ...build sizes...}
```

`min_distinctness` scores the free outline: the area every option shares is removed first. `min_distinctness_whole` is the whole-outline score. Every slot and the cockpits meet their targets on the free outline (0.35 or 0.25).

## Open risks

- **The halves still share one slab in the pad run** (whole-outline 0.03 and 0.01). The second review asked for a different shoulder and flank over the full length. Front halves now differ from the nose to the cowl. Rear halves cannot: the boot pad, fin pad, flank pad and cabin deck cover every surface between Z 0 and 12.6, and the rear fender tops belong to the Fins slot. A real fix means a shorter pad run, which moves the Flanks, Sill Jets and Tail Burner envelopes. Owner call.
- **Bamboo Stacks stand behind the fin zone.** They now clear every boot nozzle, but from dead astern each stack covers the Tall Fins lamps. From the chase angle the lamps show.
- **Bonnet Turbine and Rear Chrome are under target on the whole outline** (0.29 and 0.28). Both pass on the free outline.
- **Known compromises.** The Works Tail seam face is two solid keels either side of a diffuser tunnel, not full width. Hop Jets are square chrome troughs, but they sit where a wheel was. Sled, Kaido and Finliner cabins are narrower than the deck, which reads as a wide shoulder. Tall Fins, boot engines, the Works Turbo cooler, the Torpedo nose and the Outboards hang past drooping or short noses and tails on their own structure.
