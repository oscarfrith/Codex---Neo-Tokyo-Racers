# Hover feel: contract

Port of DRIVE: Highway camera, audio and vehicle-FX techniques to the hover cars. Approved by Oscar on 2026-10-04.
Target: Space Racers v3 (place 93959280828322). Lane: High-Risk (driving owner, camera owner, VFX attachment owner).
Current status lives in `docs/00_START_HERE.md`; this file is the build contract.

## Goal

Driving feels and sounds alive: a scripted chase camera, an Exotic engine voice that tracks thrust and speed,
effects that scale with what the car is doing, and impacts that can be heard, seen and felt.

## Decisions fixed by Oscar

- Scripted (Scriptable) chase camera, copied from how DRIVE: Highway does it. This replaces the earlier
  instruction not to return to a Scriptable camera.
- No near-miss kick. No cockpit view. No banked-track camera (world-up only).
- Sounds: use what is usable from the toolbox RX-7 (turbo whistle, blow-off, supercharger whine), synthesise
  the rest. Exotic first, voiced like a high-revving V10 with sci-fi layers.
- The RX-7 model in Workspace is deleted when the work is done.

## Owners (extend these; add no new owner, remote or startup path)

| Concern | Owner | Change |
|---|---|---|
| Driving physics and per-frame state | `ReplicatedStorage.Modules.Game.Vehicles.DrivingClient` | Publishes the Feel state below. Equations, forces and input are untouched. |
| Driving camera | `...Vehicles.DrivingCameraClient` (FOV through `Core.CameraService`) | Scripted chase mode; the V6.1 mode stays in the file behind a config switch. |
| Vehicle audio | `...Game.Audio.VehicleAudioClient`, `VehicleAudioCatalog`, `Config.Audio.VehicleProfiles` | Continuous drive of layers; new Exotic profile; impact sounds. |
| Vehicle VFX | `...Vehicles.VehicleVFXClient`, `VehiclePreviewVFXClient` | Continuous inputs; impact sparks. |
| Remote transport | `Remotes.Audio.VehicleAudioState` and the `Audio*` attributes | Unchanged. Remote cars derive continuous values from replicated velocity. |
| Persistence, economy | none | Nothing saved, nothing spent. |

## Feel state (the shared interface)

`DrivingClient` writes these attributes on the local player's vehicle Model every Heartbeat while driving, and
clears them (nil) in `Controller.Stop`. They are client-local: the server and other clients never see them.
Consumers must treat a missing attribute as "not available" and fall back to the existing boolean attributes
(`Accelerating`, `Braking`, `Boosting`, `DriftingLeft`, `DriftingRight`) and to `AssemblyLinearVelocity`.

| Attribute | Type | Meaning |
|---|---|---|
| `FeelThrottle` | number, -1..1 | Throttle input after the input gate (analogue on gamepad and mobile). Quantised to 0.02. |
| `FeelSpeedMph` | number | `AssemblyLinearVelocity.Magnitude * 0.625`. Quantised to 0.5. |
| `FeelSlip` | number, -1..1 | Sideways speed divided by total speed (positive = sliding to the car's right); 0 below 8 mph. Quantised to 0.02. |
| `FeelBoostCharge` | number, 0..100 | Boost tank. Whole numbers. |
| `FeelBoostKind` | string | `""`, `"Boost"` (held boost) or `"Mini"` (drift mini-boost). |
| `FeelDriftCharge` | number, 0..1 | Drift charge divided by its 3.25 maximum. Quantised to 0.02. |
| `FeelGrounded` | boolean | Two or more hover sensors hit. |
| `FeelHover` | number, -1..1 | Mean hover compression over the sensors that hit: (target distance - measured) / hover height. Positive = squashed. Quantised to 0.02. |
| `FeelImpactRevision` | integer | Incremented once per impact. |
| `FeelImpactStrength` | number | Unexplained horizontal speed change of that impact, studs/s. Tiers: 9 light, 25 medium, 55 heavy, 110 severe. |
| `FeelLandRevision` | integer | Incremented when the car goes from airborne (0.15 s or more) to grounded. |
| `FeelLandStrength` | number | Downward speed at touchdown, studs/s. |
| `FeelImpactX`, `FeelImpactZ` | number, -1..1 | Car-local direction from the car toward what it hit (+X right, -Z forward), written just before `FeelImpactRevision` changes, and kept pointing at the wall while `FeelScrape` is above 0.1 (VFX rework). |
| `FeelScrape` | number, 0..1 | Sustained contact: a solid surface within 2 studs of the left, right or front of the root while an unexplained force keeps acting. 0 when free. Wall probes run at 10 Hz. |
| `FeelPopRevision` | integer | Incremented once per exhaust pop or bang (round 2). Audio and VFX both react to it, so the sound and the fireball coincide. |
| `FeelPopStrength` | number, 0..1 | Size of that pop. 0.3 to 0.7 is a crackle; 0.8 and over is a bang. Pops come in a short run after a throttle lift that follows a second or more of hard thrust above 40 mph; a boost that ends fires one bang then a short run. |

Config (attributes on `ReplicatedStorage.Config.Vehicles.Driving`): `FeelStateEnabled` (boolean, true),
`FeelImpactMinStuds` (number, 9).

Impact detection: horizontal velocity change since the last frame, minus what last frame's drive force explains
(`driveForce / mass * dt`). Frames after a reset, a snap-stop, a teleport or with `dt > 0.1` are skipped.

## Preserved behaviour

- Every driving equation, force, input path and existing attribute.
- `Controller.Start/Stop` signatures of all four owners; trailer-tool suspend (P, C, V) and resume (B).
- The audio remote, its rate limit and the 6 + 6 remote-vehicle budget.
- Mobile: `MobileParticleScale`, central controllers, no per-object scripts.

## Camera

`Config.Vehicles.Camera` attribute `ScriptedChaseEnabled` (boolean). True: Scriptable chase. False: V6.1 as today.
Existing distance and FOV attributes keep their meaning and values. New geometry and feel attributes are prefixed
`Chase`. FOV goes through `CameraService.SetFieldOfView("DrivingCamera", fov, 100)`.

## Done when

- Edit: every changed script compiles; installer AUDIT clean; APPLY, ROLLBACK, APPLY clean.
- Play (rendered viewport, normal UI flow): spawn an Exotic, drive, boost, drift, hit a wall, exit, re-enter;
  no console errors; camera returns to the on-foot camera on exit; garage and dealership cameras still work.
- Oscar judges feel, look and sound. Agent checks are not acceptance of taste.

## Review outcome and accepted exceptions

- Two `delivery-reviewer` passes (state and camera; audio and VFX), both READY WITH FIXES; every fix was applied before APPLY.
- The four switches are client config attributes, not FeatureFlags, because FeatureFlags is server-side.
- The audio client plays `EXOTIC_V10_AUDIO` while the server stamp still says `GENERIC_STANDARD_AUDIO`; vehicle templates are frozen, so the mapping lives in config.
- Continuous VFX inputs apply to the local driving car of every category, not only Exotic.
- Impact and landing sounds are silent until the synthesised files are uploaded.

## Not in this delivery

Cockpit view, near-miss effects, banked tracks, Muscle and Piercer voices, remote-car Doppler and low-pass,
any server or saved-data change.
