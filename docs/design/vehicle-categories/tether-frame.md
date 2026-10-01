# Tether frame standard (blockout)

Status: design exploration, 2026-10-01. Not game content. Spec: [tether.json](../../../scripts/vehicle_blockouts/specs/tether.json). Previews: `scripts/vehicle_blockouts/previews/tether/`. Brief: [CONTRACT.md](../../../scripts/vehicle_blockouts/CONTRACT.md).

Tether is the pod racer class. A small pilot pod sits at the rear. Two large tow engines fly far ahead and wide apart. A glowing binder joins the engines. Cables or a boom join the engines to the pod.

Root space: +X right, +Y up, forward is -Z. Units are studs. Mirrored slots list the +X box only.

## Frame standard

| Slot | Player label | Envelope X | Y | Z | Anchors to (seam) |
|---|---|---|---|---|---|
| Cockpit | Pod: fore deck | -3..3 | -0.4..3.0 | 8..10.5 | root |
| Cockpit | Pod: cabin | -3..3 | -0.4..5.2 | 10.5..14.5 | root |
| Cockpit | Pod: tail deck | -3..3 | -0.4..3.0 | 14.5..16 | root |
| SidePods | Binder and Cables | -4..4 | -0.6..5.4 | -16.5..8 | cockpit, plane Z 8 |
| Engine1 | Tow Engines | 4..10 (mirrored) | -1.0..5.4 | -16.5..-5 | SidePods, plane X 4 |
| FrontBumper | Intake Cowls | 4..10 (mirrored) | -1.0..5.4 | -19..-16.5 | Engine1, plane Z -16.5 |
| Boost | Afterburners | 4..10 (mirrored) | -1.0..5.4 | -5..-1 | Engine1, plane Z -5 |
| Stabilisers | Engine Vanes | 10..12 (mirrored) | -2..7.2 | -16.5..-5 | Engine1, plane X 10 |
| Stabilisers | Engine Vanes (belly) | 4..10 (mirrored) | -2..-1.0 | -16.5..-5 | Engine1 belly at Y -1 (the spec names one face, X 10) |
| Hood | Engine Shrouds | 4..10 (mirrored) | 5.4..7.2 | -16.5..-5 | Engine1, plane Y 5.4 |
| Engine2 | Pod Thruster | -4.5..4.5 | -0.4..3.0 | 16..19 | cockpit, plane Z 16 |
| RearBumper | Pod Tail | -3..3 | -2.2..-0.4 | 8..19 | cockpit, plane Y -0.4 |
| RearSpoiler | Pod Fins | -4.5..4.5 | 3.0..9 | 14.5..19 | cockpit, plane Y 3.0 |
| Roof | Windshield | -3..3 | 3.0..5.4 | 8..10.5 | cockpit, plane Y 3.0 |

No two envelopes overlap. The whole vehicle uses the full global limit: X -12..12, Z -19..19.

Anchor chain: pod, then cables, then engines, then cowls, vanes, shrouds and afterburners. The thruster, tail, fins and windshield hang off the pod.

## Datums

- Beltline Y 2.4. This is the engine axis, the binder, the cable run, the hitch bar and the pod stripe.
- Sill Y -0.4 (pod belly). Hover plane Y -2.0. Nothing goes below it.
- Engine axis X 7.0 (and -7.0), Y 2.4.
- Hitch bar on every pod: X -2.2..2.2, Y 2.4, Z 8.05..8.55.
- Inner rail on every engine: X 4.05..4.55, Y 2.4, Z -13.2..-5.8. Binder station Z -12. Cable station Z -7.
- Outer rail on every engine: X 9.55..9.95, Y 2.4, Z -12.5..-7.5.
- Top rail on every engine: Y 4.95..5.35 on the axis, Z -14..-7.
- Front flange Z -16.45..-15.95 and rear flange Z -5.55..-5.05, both on the axis, about 3.4 across.
- Pod fore deck and tail deck: flat pads with their tops at Y 2.9..3.0.
- Pod transom Z 15.55..15.95. Pod belly pad flat at Y -0.4, at least X -1.5..1.5.

## Seam rules

1. Every seam is a 0.1 to 0.5 stud shadow gap with a dark `detail` part on each side. No surfaces are shared.
2. Cable sets end on the hitch bar and on the inner rail stations. They never touch a pod body or an engine skin.
3. An engine is free inside its box but must carry the five hardpoints: inner rail, outer rail, top rail, front flange, rear flange. A slim engine reaches them with pylons. A fat engine carries them on its skin.
4. Cowls and afterburners start with a collar on the flange. A cowl may be as large as the whole envelope face.
5. Vanes mount on the outer rail. Shrouds stand on the top rail. Windshields and fins stand on the pod decks.
6. Hover units are part of the parent. Each engine has a hover strip at Y -1.0..-0.4. Each pod has a hover pad at Y -0.4.

## Authoring rules for real meshes

- Model one side and mirror it. Engines, cowls, vanes, shrouds and afterburners are always pairs.
- Put the datum hardpoints at the exact numbers above before shaping anything else. They are the whole interchange.
- Keep rotated parts inside the box by their swept bounds. Stop cables 0.25 short of the X 4 and Z 8 planes.
- A seam needs a flat pad, not a point. A wedge nose passed the validator but left the windshield floating. The Sled now has a flat tow head.
- Nothing wraps round an engine. Vanes live outboard and below. Shrouds live above. Design "wrap" shapes as separate petals.
- Shrouds and vanes sit up to 1.7 studs off a slim engine. The rails and pylons must look deliberate, so give them real detail.
- Cables and linkages use the `detail` channel. The binder, lamps and trims use `neon`. Hover and exhaust use `thrust`.
- The pod seats one avatar. Keep the head below Y 5.2 and the body inside Z 10.5..14.5.
- The engine choice sets the silhouette: Long Barrels are slim, Fat Turbines are drums, Quad Cluster is four tubes, Split Scoops are a forked wedge.
- Culture tags never limit fitting. Builds 7 and 8 mix four cultures and still read as one vehicle through paint.

## What the blockout proves

- 4 cockpits: Bucket, Sled, Capsule, Chariot. 27 modules across 10 slots. 8 builds, 138 to 148 parts each.
- Builds 1 to 3: the Desert kit on three pods with one paint. Builds 4 to 6: the Chariot with Works, Scrapyard and Showboat kits. Builds 7 and 8: mixed wildcards. Every build stays inside the global limit and above the hover plane.

## Validator result

```
SPEC tether: 0 error(s), 1 warning(s) {'cockpits': 4, 'modules': 27, 'builds': 8, 'parts_in_builds': 1163}
  warn   cockpit sled appears in fewer than 2 builds
```

The warning is left on purpose. The brief fixes eight builds: three pods share one kit, one pod takes three kits, and two are wildcards. With four cockpits one of them can appear only once.

## Open risks

- Width. The engine pair spans 20 studs and 24 with vanes. Check road lanes, gates and garage bays before approval.
- Length. The vehicle is 38 studs, the full limit. The chase camera needs more distance, and the pod is small on screen.
- Collision. One box round the whole vehicle is too greedy. Three boxes (pod and two engines) let traffic pass through the cable gap. Decide which.
- Cables are 0.3 studs thick. They may vanish at distance. A Beam or a thicker mesh may be needed, and the binder could be a Beam.
- The whole vehicle is rigid in the blockout. Real sway between pod and engines needs constraints and is a separate design.
- Engine1 anchors to SidePods, so the cable slot can never be empty. It needs a default module.
- Seat and camera sit 8 to 16 studs behind the root origin. Check the drive rig, seat weld and garage turntable assume this.
- The validator checks bounding boxes only. Seams still need an eye check on the previews.
