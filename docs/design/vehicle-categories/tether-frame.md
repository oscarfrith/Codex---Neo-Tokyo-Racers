# Tether frame standard (blockout, round 2, after the second review)

Status: design exploration, round 2, revised 2026-10-02 after the second (per-module swap) review. Not game content. Spec: [tether.json](../../../scripts/vehicle_blockouts/specs/tether.json). Generator: [gen/tether.py](../../../scripts/vehicle_blockouts/gen/tether.py). Previews: `scripts/vehicle_blockouts/previews/tether/` (`matrix.png` is the interchange proof; `mix_a.png` and `mix_b.png` are the per-module swap test). Brief: [CONTRACT.md](../../../scripts/vehicle_blockouts/CONTRACT.md).

Tether is the pod racer class. A pilot pod sits at the rear. Two tow engines fly ahead of it, one each side. A glowing binder joins the engines. Cables or a boom join the engines to the pod. There are no wheels and no wheel-like parts. Every round part lies along the direction of travel or stands upright as a lift-jet barrel, and is longer than it is wide.

Root space: +X right, +Y up, forward is -Z. Units are studs. Mirrored slots list the +X box only.

## Frame standard

| Slot | Player label | X | Y | Z | Anchors to (seam) |
|---|---|---|---|---|---|
| Cockpit | Pod: cabin | -4..4 | -0.4..6.6 | 5..12.6 | root |
| Cockpit | Pod: tail deck | -4..4 | -0.4..3.0 | 12.6..14.5 | root |
| `SidePods` | Binder and Cables | -2.6..2.6 | -0.6..5.4 | -16..5 | cockpit, plane Z 5 |
| `Engine1` | Tow Engines | 2.6..7.2 (mirrored) | -0.2..4.8 | -16..-2 | SidePods, plane X 2.6 |
| `FrontBumper` | Nose Pieces | 2.6..7.2 (mirrored) | -0.2..4.8 | -18.5..-16 | Engine1, plane Z -16 |
| `Boost` | Afterburners | 2.6..7.2 (mirrored) | 4.8..6.8 | -14..-1.5 | Engine1, plane Y 4.8 |
| `Stabilisers` | Engine Vanes | 7.2..9.6 (mirrored) | -1.6..6.8 | -16..-2 | Engine1, plane X 7.2 |
| `Engine2` | Pod Thruster | -4.5..4.5 | -0.4..3.0 | 14.5..18.5 | cockpit, plane Z 14.5 |
| `RearBumper` | Pod Tail | -3..3 | -1.6..-0.4 | 5..18.5 | cockpit, plane Y -0.4 |
| `RearSpoiler` | Pod Fins | -4.5..4.5 | 3.0..6.8 | 12.6..18.5 | cockpit, plane Y 3.0 |

No two envelopes overlap. Builds measure 18.6 to 19.1 wide, 7.9 to 8.4 high and 36.7 to 36.9 long. The brief asks for about 18 by 7 by 36. Round 2 before the review was 24 wide and up to 10.5 high.

## The four fundamentals

| Slot | Where it sits | Why |
|---|---|---|
| `Engine1` Tow Engines | A mirrored pair on the axis X 4.9, Y 2.4, from Z -16 to -2. At most 4.6 across. | They set the outline from every camera. Every option is at least 2.2 times longer than wide. |
| `Engine2` Pod Thruster | On the pod transom, Z 14.5 to 18.5. | It is the nearest jet to the chase camera. It gives the pod its own push and glow. |
| `Stabilisers` Engine Vanes | On the outer flank of each tow engine, X 7.2 to 9.6. | They are the widest points, so they read from the front and from above. Every option has jets 1.0 or more across and one that points down. |
| `Boost` Afterburners | Piggyback on the top pad of each tow engine, Y 4.8 to 6.8. | They sit above the engines in clear air. The chase camera sees their nozzles over the pod. Every engine brings its body to within 1.0 stud of the pad. |

## Datums and hardpoint pads

Beltline Y 2.4: engine axis, binder, cable run and hitch bar. Sill Y -0.4 (pod belly). Hover plane Y -2.0. Tail deck top Y 3.0. Binder station Z -12. Cable station Z -9. Hitch plane Z 5. Transom plane Z 14.5.

Every tow engine carries these pads at these numbers (+X side):

| Pad | X | Y | Z | Carries |
|---|---|---|---|---|
| Inner rail | 2.65..3.1 | 1.95..2.85 | -12.8..-8.2 | binder emitter and cable shackle |
| Outer rail | 6.7..7.15 | 1.95..2.85 | -12.5..-8.5 | vanes |
| Top pad | 4.1..5.7 | 4.4..4.75 | -11.2..-9.2 | afterburner saddle |
| Nose collar | 3.8..6.0 (2.2 square) | 1.3..3.5 | -15.95..-15.6 | nose piece |

Every pod carries these four pads:

| Pad | X | Y | Z | Carries |
|---|---|---|---|---|
| Hitch bar | -1.6..1.6 | 2.4 (0.5 thick) | 5.05..5.55 | cables or boom |
| Transom | -1.8..1.8 | 0.4..2.6 | 14.05..14.45 | pod thruster |
| Tail deck | -1.7..1.7 | 2.7..3.0 | 12.65..14.4 | fins |
| Belly | -1.4..1.4 | -0.4..-0.1 | 9.4..13.4 | pod tail |

## Cockpits and signature kits

Six pods, each with a different length, height and outline (width by height in brackets).

| Kit (culture) | Native pod | Engine1 | Engine2 | Stabilisers | Boost |
|---|---|---|---|---|---|
| Scrapyard | Bucket (6.6 by 7.0): square tub behind an open drawbar, full-height roll cage | Quad Cluster: four slim staggered jets (the only tube bundle) | Skid Jet: box duct, top scoop, tall slot | Outrigger Jets: two upright lift barrels | Bottle Rack: three tilted rocket bottles |
| Desert | Sled (8.0 by 3.8): the lowest, a long enclosed dart, pointed prow, delta sponsons, solid tail under the deck | Fat Turbines: one nacelle 4.4 by 12, flat flanks, eyelid nozzle | Twin Nacelles on a stub wing | Petal Brakes: splayed petals, lift jet | Can Burner: one can, saddle tanks |
| Works | Capsule (7.0 by 6.8): slim round hull 3.6 across, half-barrel canopy, tall fin, side tanks | Long Barrels: bell, turbine, long thin tailpipe, dorsal fairing | Mono Turbine | Blade Vanes: tall plate, top jet, vectoring jet | Staged Burner: telescoping |
| Showboat | Chariot (7.0 by 7.0): tall wide shield with a visor, narrow open platform | Bell Jets: slim snout, square four-petal horn | Organ Pipes: four in a row | Canard Jets: thick canards, lift jet, tip pod | Twin Trumpets: two long pipes |
| Harbour | Skiff (3.6 by 6.9): the narrowest, a boat with a stem post, stepped screen and hard top | Twin Hulls: two flat-sided boat hulls with pointed bows, a bridge deck and a wheelhouse | Outboard: powerhead, low torpedo | Hydro Strakes: drooped strake, float jet, lift slot | Slot Burner: flat, 3.8 wide over its end plates, stepped pedestal |
| Atomic | Bubble (5.2 by 6.1): clear dome at the nose, pilot in view, short tapering tail | Stack Jets: one tall over-and-under nacelle, flat sides, two nozzles in one oval tail | Swallow Tail: two splayed pipes | Sky Fins: upswept fin, tip rocket, lift jet | Fin Rocket: one pointed rocket |

Each kit also has a binder set, a nose piece, a pod tail and pod fins: 8 slots, 6 options each, 48 modules. Any pod takes any kit. The 36 cells of `matrix.png`, the six `row_<cockpit>.png` sheets and six mixed builds show it. `mix_a.png` and `mix_b.png` add twelve builds with a random option in every slot (listed in `mix.txt`). The Scrapyard pod tail is a chute pack with a drogue canister and a short hook that ends at Z 16.4.

## Authoring rules for real meshes

1. Model the pads first, at the exact numbers above. They are the whole interchange. Shape the body round them.
2. A module lands on a pad, never on a body shape. Start every module with a dark `detail` foot, collar or shackle 0.05 from the pad.
3. Stay inside the slot envelope, measured by swept bounds. Model one side and mirror it.
4. An engine is free inside its box. A slim engine reaches its rails with struts. A fat one carries them on its skin. Under the top pad an engine has a solid fairing at least 1.3 wide (dorsal fairing, scoop, wheelhouse or cowl top), never a thin mast. Quad Cluster is the one exception: its pad sits between the two upper tubes.
5. Nothing wraps round an engine. Vanes live outboard. Afterburners live above. Nose pieces live ahead, sized to the 2.2 collar.
6. No wheels, rings, hoops, discs or drums. An engine is at least 2.2 times longer than wide. Break any round tail face with petals, vanes or flat eyelids.
7. Every engine, vane set and afterburner shows an intake, a body and a `thrust` nozzle from outside.
8. Two options for a slot must differ in body shape and outline: count, length, girth, section or stance. Only one engine may be a bundle of tubes. Paint and detail do not count.
9. The pod owns all glass and the roofline. Keep it inside the cabin box and keep the pilot visible.
10. Cables and linkage use `detail`. Binder, lamps and trim use `neon`. Jets use `thrust`.

## Validator result

```
SPEC tether: 0 error(s), 0 warning(s) {'cockpits': 6, 'kits': 6, 'modules': 48, 'builds': 18, 'worst_gap': 0.15, 'min_distinctness': {'Engine1': 0.42, 'Engine2': 0.38, 'Stabilisers': 0.48, 'Boost': 0.54, 'SidePods': 0.7, 'FrontBumper': 0.37, 'RearBumper': 0.56, 'RearSpoiler': 0.57, 'Cockpit': 0.49}, 'min_distinctness_whole': {'Engine1': 0.23, 'Engine2': 0.29, 'Stabilisers': 0.44, 'Boost': 0.37, 'SidePods': 0.44, 'FrontBumper': 0.29, 'RearBumper': 0.55, 'RearSpoiler': 0.56, 'Cockpit': 0.31}, 'build_sizes_WHL': {...}}
```

`min_distinctness` is the free outline: the area every option shares (pads, collars, chassis) is removed first. `min_distinctness_whole` is the whole outline. Every slot beats its free-outline target (0.35 for the big slots, 0.25 for the rest and for cockpits). The closest pairs, free then whole: Fat Turbines and Bell Jets (0.42, 0.23), Mono Turbine and Outboard (0.38, 0.29), Ram Cage and Sand Filter (0.37, 0.29), Chariot and Bubble (0.49, 0.31). `py -3 scripts/vehicle_blockouts/gen/tether.py --report --all` lists every pair.

## Open risks

- The pod is still small on screen. Two pods on the same kit differ by 0.06 to 0.16 in whole-vehicle outline; two kits on the same pod differ by 0.31 to 0.43. Pod-only whole scores are 0.31 to 0.50, short of the critic's 0.45 target for 12 of 15 pairs, because all pods share four pads and one tail deck.
- Engines share one axis and one collar, so whole-outline scores for `Engine1` are low (0.23 to 0.44); free-outline scores are 0.42 to 0.79. They differ in body shape: a slim barrel, a fat nacelle, a tube bundle, a square horn, a catamaran and a tall oval cowl. Quad Cluster with Twin Trumpets is still the busiest pairing.
- Harbour and Atomic are cultures the brief does not list. They exist so Skiff and Bubble have signature kits.
- Collision: one box round the whole vehicle is too greedy, and three boxes let traffic through the cable gap. Cables are 0.3 studs thick and may vanish at distance. A Beam may suit them. The blockout is rigid; sway is a separate design.
- `Engine1` anchors to `SidePods`, so the binder slot can never be empty. It needs a default module. The seat sits 8.5 to 12 studs behind the root origin. Check the drive rig, seat weld and garage turntable.
- Preview tool: `preview.py` drops the two pole faces of every `ball`. The Bubble dome carries a second shell turned on its side to close it. Real meshes need one dome.
