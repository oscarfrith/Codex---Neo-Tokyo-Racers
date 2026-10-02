# Tether frame standard (blockout, round 2)

Status: design exploration, round 2, 2026-10-01. Not game content. Spec: [tether.json](../../../scripts/vehicle_blockouts/specs/tether.json). Generator: [gen/tether.py](../../../scripts/vehicle_blockouts/gen/tether.py). Previews: `scripts/vehicle_blockouts/previews/tether/` (`matrix.png` is the interchange proof). Brief: [CONTRACT.md](../../../scripts/vehicle_blockouts/CONTRACT.md).

Tether is the pod racer class. A small pilot pod sits at the rear. Two big tow engines fly far ahead and wide apart. A glowing binder joins the engines. Cables or a boom join the engines to the pod. There are no wheels and no wheel-like parts. Every round part lies along the direction of travel or stands upright as a lift-jet barrel.

Root space: +X right, +Y up, forward is -Z. Units are studs. Mirrored slots list the +X box only.

## Frame standard

| Slot | Player label | X | Y | Z | Anchors to (seam) |
|---|---|---|---|---|---|
| Cockpit | Pod: cabin | -3..3 | -0.4..5.6 | 6..12.6 | root |
| Cockpit | Pod: tail deck | -3..3 | -0.4..3.0 | 12.6..14.5 | root |
| `SidePods` | Binder and Cables | -3.6..3.6 | -0.6..5.4 | -16..6 | cockpit, plane Z 6 |
| `Engine1` | Tow Engines | 3.6..9.4 (mirrored) | -1.0..5.4 | -16..-2 | SidePods, plane X 3.6 |
| `FrontBumper` | Nose Pieces | 3.6..9.4 (mirrored) | -1.0..5.4 | -19..-16 | Engine1, plane Z -16 |
| `Boost` | Afterburners | 3.6..9.4 (mirrored) | 5.4..7.8 | -14..-1.5 | Engine1, plane Y 5.4 |
| `Stabilisers` | Engine Vanes | 9.4..12 (mirrored) | -2.0..7.8 | -16..-2 | Engine1, plane X 9.4 |
| `Engine2` | Pod Thruster | -4.5..4.5 | -0.4..3.0 | 14.5..19 | cockpit, plane Z 14.5 |
| `RearBumper` | Pod Tail | -3..3 | -2.0..-0.4 | 6..19 | cockpit, plane Y -0.4 |
| `RearSpoiler` | Pod Fins | -4.5..4.5 | 3.0..9 | 12.6..19 | cockpit, plane Y 3.0 |

No two envelopes overlap. Builds measure 22.6 to 23.9 wide, 8.8 to 10.5 high and 37.1 to 37.9 long. That is inside X -12..12 and Z -19..19.

## The four fundamentals

| Slot | Where it sits | Why |
|---|---|---|
| `Engine1` Tow Engines | A mirrored pair on the axis X 6.5, Y 2.4, from Z -16 to -2. | They are the vehicle. They are the biggest shapes and set the outline from every camera. |
| `Engine2` Pod Thruster | On the pod transom, Z 14.5 to 19. | It is the nearest jet to the chase camera. It gives the pod its own push and its own glow. |
| `Stabilisers` Engine Vanes | On the outer flank of each tow engine, X 9.4 to 12. | They are the widest points, so they read from the front and from above. Each has control jets or lift jets. |
| `Boost` Afterburners | Piggyback on the top pad of each tow engine, Y 5.4 to 7.8. | They sit above the engines in clear air. The chase camera sees their nozzles over the pod. |

## Datums and hardpoint pads

- Beltline Y 2.4: engine axis, binder, cable run and hitch bar. Sill Y -0.4 (pod belly). Hover plane Y -2.0. Tail deck top Y 3.0.
- Binder station Z -12. Cable station Z -9. Hitch plane Z 6. Transom plane Z 14.5.

Every tow engine carries these four pads at these numbers (+X side):

| Pad | X | Y | Z | Carries |
|---|---|---|---|---|
| Inner rail | 3.65..4.15 | 1.95..2.85 | -12.8..-8.2 | binder emitter and cable shackle |
| Outer rail | 8.95..9.35 | 1.95..2.85 | -12.5..-8.5 | vanes |
| Top pad | 5.6..7.4 | 5.0..5.35 | -11.2..-9.2 | afterburner saddle |
| Front hub | 1.2 across on the axis | | -15.95..-14.4 | nose piece |

Every pod carries these four pads:

| Pad | X | Y | Z | Carries |
|---|---|---|---|---|
| Hitch bar | -2.2..2.2 | 2.4 (0.5 thick) | 6.05..6.55 | cables or boom |
| Transom | -1.8..1.8 | 0.4..2.6 | 14.05..14.45 | pod thruster |
| Tail deck | -1.7..1.7 | 2.7..3.0 | 12.65..14.4 | fins |
| Belly | -1.4..1.4 | -0.4..-0.1 | 9.4..13.4 | pod tail |

## Signature kits

| Kit (culture) | Native cockpit | Engine1 | Engine2 | Stabilisers | Boost |
|---|---|---|---|---|---|
| Scrapyard | Bucket: open scoop, roll bar | Quad Cluster: four small jets | Skid Jet: flat slot | Outrigger Jets: two upright lift barrels | Bottle Rack: four rockets across |
| Desert | Sled: low arrowhead, raked screen | Fat Turbines: one short fat drum | Twin Nacelles | Petal Brakes: splayed petals, lift jet | Drum Burner: one fat can |
| Works | Capsule: round hull, glass barrel | Long Barrels: one slim long turbine | Mono Turbine | Blade Vanes: tall plate, tip jets | Staged Burner: telescoping |
| Showboat | Chariot: tall shield, open platform | Bell Jets: slim snout, flared bell | Organ Pipes: four in a row | Canard Jets: flat canards, tip pods | Twin Trumpets: two long pipes |
| Harbour | Skiff: narrow boat hull | Twin Hulls: two torpedoes under a deck | Outboard: powerhead and low torpedo | Hydro Strakes: drooped strake, float jet | Slot Burner: flat, end plates |

Each kit also has a binder set, a nose piece, a pod tail and pod fins: 8 slots, 5 options each, 40 modules. Any pod takes any kit. The 25 cells of `matrix.png` and three mixed builds show it.

## Authoring rules for real meshes

1. Model the pads first, at the exact numbers above. They are the whole interchange. Shape the body round them.
2. A module lands on a pad, never on a body shape. Start every module with a dark `detail` foot, collar or shackle 0.05 from the pad.
3. Stay inside the slot envelope, measured by swept bounds. Model one side and mirror it.
4. An engine is free inside its box. A slim engine reaches its pads with struts and a pylon. A fat one carries them on its skin.
5. Nothing wraps round an engine. Vanes live outboard. Afterburners live above. Nose pieces live ahead.
6. No wheels, rings, hoops or discs. A tube runs along Z, or stands upright as a lift barrel, and is longer than it is wide.
7. Every engine, vane set and afterburner shows an intake, a body and a `thrust` nozzle from outside.
8. Two options for a slot must differ in outline: count, length, girth or stance. Paint and detail do not count.
9. The pod owns all glass and the roofline. Keep the head below Y 5.6 and the cabin inside Z 6..12.6.
10. Cables and linkage use `detail`. Binder, lamps and trim use `neon`. Jets use `thrust`.

## Validator result

```
SPEC tether: 0 error(s), 0 warning(s) {'cockpits': 5, 'kits': 5, 'modules': 40, 'builds': 13, 'worst_gap': 0.15, 'min_distinctness': {'Engine1': 0.38, 'Engine2': 0.41, 'Stabilisers': 0.63, 'Boost': 0.37, 'SidePods': 0.49, 'FrontBumper': 0.4, 'RearBumper': 0.65, 'RearSpoiler': 0.6, 'Cockpit': 0.27}}
```

Every slot beats its target (0.35 for engines, stabilisers, boost and spoiler; 0.25 for the rest and for cockpits). The closest pairs are Bottle Rack and Slot Burner (0.37), Fat Turbines and Bell Jets (0.38), Long Barrels and Bell Jets (0.38), and Capsule and Chariot (0.27).

## Open risks

- Five cockpits, not six. The brief also names Bubble. It needs a sixth kit, and the engine box is already tight for five clearly different engines. Harbour is a fifth culture that the brief does not list.
- Width and length. Builds are 24 wide and 38 long, the full limit. Check lanes, gates, garage bays and the chase camera. The pod is small on screen next to the engines.
- Collision. One box round the whole vehicle is too greedy. Three boxes let traffic through the cable gap. Decide which.
- Cables are 0.3 studs thick and may vanish at distance. A Beam may suit them. The blockout is rigid; sway between pod and engines is a separate design.
- `Engine1` anchors to `SidePods`, so the binder slot can never be empty. It needs a default module.
- The seat sits 9 to 11 studs behind the root origin. Check the drive rig, seat weld and garage turntable.
- Fat Turbines and Bell Jets are about as wide as they are long. They read as turbines because they lie along Z, but keep real meshes clearly longer.
