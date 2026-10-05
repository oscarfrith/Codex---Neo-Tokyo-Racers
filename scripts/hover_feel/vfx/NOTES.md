# Hover feel: VFX part

Status: generated on disk. The first version compiled in Studio (coordinator). The review fixes below (round 2) are not yet compiled or played.

## Files

- `after/VehicleVFXClient.lua`: runtime owner. Computes continuous inputs for the local driven vehicle and requests bursts.
- `after/VehiclePreviewVFXClient.lua`: template controller. It had to change, for three reasons found in the before source:
  1. It clamps every input to 0..1, so a boost pulse above 1 was impossible.
  2. For the base templates `EngineJet`, `BoostJet` and `StabiliserJet` (`CustomToggle`) it only switches `Enabled`; a continuous input had no visible effect.
  3. It is the only holder of the cloned BrakeSparks and HoverDust emitters, so the burst belongs there (`Controller:Burst`).
- `config_spec.json`: 26 attributes on `ReplicatedStorage.Config.Vehicles.StabiliserVFX`. No instances.
- `RuntimeVFXClient.lua` is unchanged.

No new owner, remote, script or connection. One runtime instance set is created for the local driving vehicle only (the burst-only spark source, see below). Clean-up on despawn is the same code as before (`destroyCache`, `Controller:Destroy`); the feel memory is a plain table on the cache.

## What changed in VehicleVFXClient

- `FEEL_DEFAULTS` plus `refreshFeelConfig()`, called from the existing 0.5 s scan. A wrong-typed or missing attribute uses the code fallback.
- `runtimeState` adds `Local = true` for the local player's non-preview vehicle.
- The continuous inputs apply to the local driving vehicle of every category (base templates and the `_Exotic` / `_Muscle` variants alike); nothing is keyed on category. This is intended.
- `feelInputs(cache, state, dt)` runs only for a vehicle that is local, `Driving`, has a template controller, and with `FeelVFXEnabled = true`. Otherwise the inputs are exactly today's.
- `updateTemplateController` sends the feel inputs, and also sets `state.Accelerating / Boosting / DriftLeft / DriftRight` from them (threshold 0.05). The by-name toggles in `applyVFXState` write `Enabled` on the same cloned effects as the controller; without this the two writers disagree for one tick during the throttle release and the jets flicker.
- While feel is active it calls `Controller:EnsureImpactSparks()` until it resolves (it waits for the delayed mobile socket attach). Preview and remote vehicles never reach this call.
- `feelBursts` polls `FeelImpactRevision` and `FeelLandRevision` at the existing 30 Hz.
- The 30 Hz visual step, the 0.5 s scan and the race gate are untouched. When the race gate hides the vehicle all inputs are 0 and no burst is emitted.

## What changed in VehiclePreviewVFXClient

- `Update` reads two optional fields of the state table: `JetFloor` (default 1) and `BoostCeiling` (default 1). Callers that do not pass them (garage preview, remote vehicles, missing Feel state) get the old clamp and no scaling.
- Custom-toggle effects record their authored `Rate`, `Width0/1`, `Brightness/Range` at attach. While active they are multiplied by `jetScale`, written only when it moves by more than 0.01. At drive 1 the values equal the authored ones. The scale uses the input before the mobile multiplier, so mobile is unchanged at full drive.
- Variant templates (`EngineJet_Exotic` and so on) are not custom-toggle, so they take the `RateMin/Width0Min/BrightnessMin` path. When `JetFloor` is passed and the group is a jet group (`EngineThrust`, `EngineJet`, `Boost`, `Drift`, `DriftLeft`, `DriftRight`) that is on, the intensity used on that path is `JetFloor + (1 - JetFloor) * drive` (times `MobileScale` on mobile). On/off thresholds are unchanged. Without `JetFloor` the path is byte-for-byte the old behaviour.
- `Burst(kind, count)` and a `BurstKind` on each ParticleEmitter record.
- `EnsureImpactSparks()`: if the vehicle has no spark emitters after socket attach and the `BrakeSparks` template exists, it creates ONE `Attachment` named `VFX_FeelImpactSparks` on the PrimaryPart at local `(0, -0.5 * Size.Y, -0.5 * Size.Z)` (front-bottom; forward is -Z) and runs the existing `attachWholeTemplate` on it. The new records are set to group `Manual` (never driven by the Brake input, so braking looks as today) with `BurstKind = "Sparks"`. The Attachment and the clones are in `CreatedHosts`, so `Controller:Destroy` removes them with everything else. Skipped silently when the template is missing, the PrimaryPart is missing, or the template is disabled on mobile.
- `MaxRecommendedParticlesPerVehicle` is read from `00_GLOBAL_VFX_SETTINGS` (0 or missing = no cap).

## Formulas

`smooth(cur, target, dt, attack, release) = cur + (target - cur) * (1 - exp(-dt / tau))`, tau = attack when rising, else release.

| Input | Formula | Missing attribute |
|---|---|---|
| Throttle | `t = smooth(t, clamp(FeelThrottle, 0, 1), dt, 0.06, 0.28)`; output `t` if `t >= FeelThrottleCutoff (0.1)`, else 0 | `Accelerating` 0/1 |
| Boost | `on = Boosting or FeelBoostKind ~= ""`; output 1 while on; for the first `FeelBoostPulseSeconds (0.15)` after off -> on: `1 + (FeelBoostPulsePeak (1.35) - 1) * (1 - age / 0.15)` | `Boosting` 0/1, no pulse |
| DriftLeft / DriftRight | `bool * (FeelDriftFloor (0.45) + 0.55 * clamp(abs(FeelSlip) / FeelDriftSlipFull (0.5), 0, 1))`; `Drift = max(left, right)` | bool 0/1 |
| HoverDust | grounded: `clamp(FeelDustFloor (0.45) + FeelDustSpeedGain (0.5) * clamp(FeelSpeedMph / 140, 0, 1) + FeelDustSquashGain (0.45) * clamp(FeelHover, 0, 1), 0, 1)`; airborne: 0; then `smooth(..., 0.05, FeelDustReleaseSeconds (0.2))`, below 0.02 = 0 | fixed 0.45 (keyed on `FeelGrounded`) |
| Brake | `Braking == true`, not airborne, mph > `FeelBrakeMinMph (25)`: `FeelBrakeFloor (0.35) + 0.65 * clamp((mph - 25) / (FeelBrakeFullMph (110) - 25), 0, 1)`. mph = `FeelSpeedMph`, else root speed * 0.625 | `Braking` absent or false: 0 |
| Jet scale (controller): custom-toggle templates scale authored values; variant templates use it as the intensity on the RateMin/RateMax path | `drive >= 1`: `drive`; else `FeelJetFloor (0.4) + 0.6 * drive` | 1 / raw intensity |
| Boost clamp (controller) | group `Boost` clamps to `0..clamp(BoostCeiling, 1, 2)`; all other groups 0..1 | 0..1 |

Bursts:

- Impact: on `FeelImpactRevision` increase. Count by `FeelImpactStrength`: >= 9 -> 6, >= 25 -> 14, >= 55 -> 26, >= 110 -> 40 (the four `FeelImpactSparks*` attributes). Minimum gap `max(FeelImpactMinInterval, 0.12)` s.
- Landing: on `FeelLandRevision` increase and `FeelLandStrength >= FeelLandMinStuds (12)`: `count = 6 + (28 - 6) * clamp((strength - 12) / (70 - 12), 0, 1)`. Same minimum gap, separate timer.
- `Burst`: nothing when the vehicle is beyond `CullDistanceStuds`. `total = count * (MobileParticleScale or DesktopParticleScale)`, capped by `MaxRecommendedParticlesPerVehicle` when that is > 0, split evenly over the matching emitters, each share multiplied by the template `MobileScale` on mobile, rounded; `Emit` is skipped below 1.
- Matching emitters: "Sparks" = ParticleEmitters whose group is `Brake` or whose template name contains `brakespark`; "Dust" = group `HoverDust` or template name contains `hoverdust`.
- The revision seen when the feel memory is created is the baseline, so re-entering a car does not replay an old impact.

Behaviour differences to know about:

- Brake sparks now run for the local car even with `FeelStateEnabled = false`, because `Braking` already exists. `FeelVFXEnabled = false` turns everything in this delivery off.
- With analogue throttle below 0.1 the engine shows the idle effect, where today any throttle shows the thrust effect.
- The by-name `EngineOn` effects stay on for the release tail (about 0.3 s after letting go).
- Hover dust at rest is 0.45, the same as today; speed and squash add on top (clamped to 1). Airborne is 0.
- Drift has two floors on a moving slide: `FeelDriftFloor` then `FeelJetFloor` (minimum 0.4 + 0.6 * 0.45 = 0.67 of full).
- Sustained brake sparks still do nothing on vehicles without an authored BrakeSparks socket (none in the live place); only impact bursts use the runtime source.
- Remote vehicles: unchanged. The optional speed scaling was left out.

## Not verified (templates and Studio not visible to this agent)

- Reviewer finding: no live vehicle template has a BrakeSparks socket, so impact sparks come from the runtime `VFX_FeelImpactSparks` source. Whether HoverDust sockets exist is not known to this agent; without one, landing dust does nothing.
- Whether the front-bottom offset of the PrimaryPart is a sensible place on each car (the PrimaryPart may be much smaller than the body), and whether the BrakeSparks template reads well there.
- Reviewer finding: Exotic sockets use `VFXTemplate = "EngineJet_Exotic"` and similar. `FeelJetFloor` now reaches them through the intensity floor; how the variant effects look at 40 % is unseen. A variant BrakeSparks or HoverDust template whose effect names do not contain "brake", "spark" or "dust" falls in group `Manual` and gets no sustained drive (as today); bursts still reach it by template name.
- Whether BrakeSparks emitters have a sensible `Rate`, `Lifetime` and `Speed` for a burst, and where the sockets sit. Sparks come from the brake sockets, not from the contact point (the Feel state has no impact position). They are `LockedToPart`, as every template emitter already is.
- Whether scaling Beam width and light brightness reads well as thrust on the base templates. Fire, Smoke, Sparkles and Trail objects are only toggled.
- The value of `MaxRecommendedParticlesPerVehicle`; a low value caps heavy and severe bursts.
- Template `MobileScale` below about 0.5 would leave a short gap on mobile where neither idle nor thrust shows during the throttle release.
- That `DrivingClient` writes `FeelImpactRevision` and `FeelImpactStrength` in the same Heartbeat.
- Syntax of the round 2 edits: only a keyword-balance script was run.

## Manual test list

1. Both scripts compile; `[RuntimeVFXClient] Cached thrust visual runtime active.` prints; no console errors.
2. Garage and dealership preview: Idle and ThrustColour modes look exactly as before.
3. Drive an Exotic on keyboard: tap W. Jets grow quickly and fade over about 0.3 s rather than snapping; the idle effect returns after the fade.
4. Gamepad or mobile: half throttle gives visibly smaller jets than full; at 10-30 % throttle the Exotic jets stay clearly visible (floor 0.4). Repeat on a Muscle and a base-category car.
5. Boost (held) and drift mini-boost: a brief brighter flash at ignition, then steady.
6. Drift left and right: the correct side fires; a shallow slide is weaker than a deep slide.
7. Hover dust: same as before at rest, stronger at speed and on compression, gone in the air, a puff on landing from a jump.
8. Brake from above 25 mph: sparks while braking, none below 25 mph.
9. Hit a wall lightly and hard: spark burst scales; scraping along a wall does not spam (0.12 s gap).
10. Exit and re-enter: no burst on entry; effects off after exit; no leftover `_Runtime` hosts or `VFX_FeelImpactSparks` after despawn. Exactly one `VFX_FeelImpactSparks` under the local car's PrimaryPart while driving; none on previews or other players' cars.
11. Set `FeelVFXEnabled = false` on `Config.Vehicles.StabiliserVFX`: within 0.5 s behaviour is the old binary one. Set `Config.Vehicles.Driving.FeelStateEnabled = false`: old behaviour plus brake sparks.
12. Second player: their car looks as before from this client. In a race: hidden vehicles show no jets and no bursts.
13. Mobile (or touch emulation): effects present, fewer particles, no errors.

## Round 2: backfire (pops, bangs, fireballs)

Status: generated on disk; not compiled, not played. Round 1 is installed and working in Play (coordinator).

- `config_spec.json` now has 34 attributes; `config_round2.json` holds only the 8 new ones. No instances.
- `VehicleVFXClient.feelBursts` also watches `FeelPopRevision` (baseline taken when the feel memory is created, as for impacts). On an increase, in the same visual update, it calls `Controller:Backfire(count, flashSeconds, flashGain)`. Local driving vehicle only; nothing when hidden by the race gate or with `FeelBackfireEnabled = false`. There is no extra rate limit; the 30 Hz visual step is the limit (two pops inside one step give one fireball).
- `VehiclePreviewVFXClient:Backfire`:
  - Emitters: ParticleEmitters in group `Boost`; if the vehicle has none, those in `EngineThrust` / `EngineJet`. `Emit` with the same scaling as `Burst` (particle scale, cull distance, `MaxRecommendedParticlesPerVehicle`, template `MobileScale`, shared evenly).
  - Flash: lights and Beams in group `Boost`; if there are none, those in the engine groups. Brightness (lights) or Width0/Width1 (Beams) is set to the authored value times the gain and `Enabled = true`. The pre-flash `Enabled` and values are saved on the record.
  - `Update` skips a flashing record until the flash time has passed, then restores the saved values and resumes the normal drive on that tick. `Destroy` restores first. Restore happens on the 30 Hz update, so a flash lasts up to 0.033 s longer than configured.
  - Creates no instances. With no matching emitter, light or Beam it does nothing.

Formulas (`s = clamp(FeelPopStrength, 0, 1)`):

| | Crackle (`s < 0.8`) | Bang (`s >= 0.8`) |
|---|---|---|
| Particles | `FeelBackfireCrackleMin (4) + (FeelBackfireCrackleMax (8) - 4) * clamp((s - 0.3) / 0.4, 0, 1)` | `FeelBackfireBangMin (14) + (FeelBackfireBangMax (24) - 14) * clamp((s - 0.8) / 0.2, 0, 1)` |
| Flash seconds | `FeelBackfireCrackleFlashSeconds (0.08)` | `FeelBackfireBangFlashSeconds (0.16)` |
| Flash gain | `1 + (FeelBackfireFlashGain (1.6) - 1) * max(s, 0.3)` | same |

Not verified:

- Which classes the live boost and engine effects are. If they are only Fire, Smoke, Sparkles or Trail objects, there is nothing to emit or flash and the backfire is invisible.
- The fireball uses the boost emitter's own texture, lifetime and speed; whether 4 to 24 particles of it reads as a fireball is unseen. Emitters are `LockedToPart`, so it travels with the car.
- Boost effects with a `VFXGroup` attribute other than `Boost`, or names without "boost", are not found.
- On mobile, small crackle shares can round to 0 particles per emitter (count x 0.55 x MobileScale, split over the emitters); the flash still shows.

Manual tests:

14. Hold full throttle above 40 mph for over a second, then lift: a run of small fireballs at the rear, each with its pop sound, and a short flash. End a boost: one larger fireball with the bang.
15. After the run the boost lights and beams are off and at their normal size; boost again and they look as before.
16. Pop while boosting: the flash brightens the boost effect and returns to the steady boost look.
17. Exit the car during a pop run: no effect left on or enlarged. `FeelBackfireEnabled = false`: sound only, no fireball.

## VFX rework (Exotic V2)

Status: generated on disk; not compiled, not installed, not seen. Only a keyword/bracket balance script was run on the three Lua files. Everything visual below is a first pass for Oscar to judge.

### Files

- `templates_exotic.lua`: returns `function(textures)`; builds eight unparented template Folders.
- `after/VehiclePreviewVFXClient.lua`: template resolution, V2 channels, boost sequence, ground placement, tint, bursts.
- `after/VehicleVFXClient.lua`: passes the extra state (below) and the remote/preview flags. Nothing else changed.
- `config_round_v2.json`: the 27 new attributes. `config_spec.json`: all 61.

### Templates

| Template | Attached to | Effects (emitters / beams / lights / trails) | Of which "Full" tier | Desktop only |
|---|---|---|---|---|
| `EngineJet_ExoticV2` | each `EngineJet_Exotic` socket (4 per car) | 9 (4 / 4 / 1 / 0) | 3 | 1 |
| `BoostJet_ExoticV2` | each `BoostJet_Exotic` socket (2 or 3 per car) | 15 (11 / 3 / 1 / 0) | 10 | 1 |
| `StabiliserJet_ExoticLeftV2`, `...RightV2` | each stabiliser socket (4 per car) | 8 (6 / 2 / 0 / 0) | 5 | 0 |
| `HoverDust_ExoticV2` | each `HoverDust` socket (5 per car) | 4 (3 / 1 / 0 / 0) | 1 | 0 |
| `GroundFX_ExoticV2` | one runtime socket at the root, every V2 vehicle | 6 (5 / 0 / 1 / 0) | 2 | 1 |
| `BrakeSparks_ExoticV2` | one runtime socket, local driving car only | 6 (6 / 0 / 0 / 0) | 0 | 0 |
| `SpeedTrails_ExoticV2` | one runtime socket, local driving car only | 3 (0 / 0 / 0 / 3) | 0 | 0 |

Backfire emitters live in `BoostJet_ExoticV2` (the boost sockets are the rear jets), so there is no separate backfire template. The old templates are untouched.

### Template selection and category detection

At socket attach the controller collects the vehicle's sockets, then decides once per vehicle:

- Exotic = the model's `CategoryId` or `CockpitId` attribute contains "exotic" (case-insensitive), **or** any socket's `VFXTemplate` contains `_Exotic`. The second test is what I rely on: every Exotic module socket in the dump has it, and preview models are built from the same module templates. The first covers a cockpit with no modules (the dump's cockpit templates carry `CategoryId = "exotic"`; the repository export shows the garage preview is a clone of that template named `LOCAL_PREVIEW_<cockpitId>`).
- With `ExoticVFXV2Enabled` true, `X_Exotic...` resolves to `X_Exotic...V2`, `HoverDust` to `HoverDust_ExoticV2` and `BrakeSparks` to `BrakeSparks_ExoticV2`, each only if that template exists. Otherwise the name is unchanged, which is today's behaviour. The switch is read at attach, so toggling it affects vehicles spawned afterwards.
- No socket or vehicle template is edited.

### State the controller now accepts

Existing fields are unchanged. New optional fields, ignored by vehicles without V2 templates: `Powered`, `Hidden`, `Preview`, `NoLights`, `ThrustColor`, and `Feel = { Local, Hover, SpeedMph, Slip, DriftCharge, BoostKind, Scrape, Grounded, ImpactX, ImpactZ }` (local driving car only). `Attach` takes a fourth argument `{ Reduced = true }` for a remote player's vehicle. `Backfire` takes a fourth argument, the pop strength. New method `SetImpactSide(x, z)`.

Feel attributes used: `FeelThrottle`, `FeelBoostKind`, `FeelSlip`, `FeelGrounded`, `FeelHover`, `FeelSpeedMph`, `FeelDriftCharge`, `FeelScrape`, `FeelImpactX`, `FeelImpactZ`, `FeelImpactRevision/Strength`, `FeelLandRevision/Strength`, `FeelPopRevision/Strength`.

### How an effect is driven

Each effect names a channel in `VFXGroup`. Per update the controller computes the channels, then for each effect: `Enabled = value > 0.05`; Rate, Beam width, light brightness and range interpolate between their `...Min` and `...Max` attributes (the existing convention). V2 adds, per effect and all optional: `Flicker`/`FlickerHz` (noise removes up to that fraction), `SpeedScaleMin/Max` (flame length through particle speed), `GlowMin/Max` (emitter or beam Brightness), `ZMin/ZMax` on a beam-end Attachment (jet length), `TintStart/TintEnd`, `WorldSpace`, `VFXBurst`/`BurstCount`/`BurstShare`, `VFXTier`, `DesktopOnly`, `GroundTint`. V2 channels may reach 2 (flashes); beam ends stop at 1.5.

Thrust colour: read from the state (`thrustColour(cache)`, the same model or preview-root `ThrustColor` attribute the old path uses), else the vehicle attribute, else white. Each effect's authored colour sequence is blended toward it by `TintStart` at the start of the sequence and `TintEnd` at the end: 1/1 for energy (ion rim, pads, arcs, charge glow, ground glow and light, tail ribbon), about 0.45/0 for fire (tinted core, fire-coloured body), nothing for sparks, smoke and dust. Applied only when the colour changes. The old path (name-matched `EngineOn_Fire` and so on, recoloured wholesale) is not used by V2 effects, which is why their names avoid those fragments. Note the default thrust colour is white, so energy effects are white until a colour is chosen.

### Effects, drivers and formulas

`T` = throttle input (already smoothed, cut off and floored by `FeelJetFloor` for the local car), `squash = clamp(FeelHover, 0, 1)`, `speed = clamp(FeelSpeedMph / ExoticV2DustSpeedFullMph, 0, 1)`.

1. **Engine jets.** Channel `EngineThrust = T` (x 0.6 during the boost intake). Core and shock-diamond beams, heat sheath and ion rim widen, brighten and lengthen with it (core 1.4 to 4.6 studs, flame 2.0 to 5.4); the flipbook flame body goes from rate 10 to 36 and 45 % to 100 % speed; embers 0 to 8/s; the light 0.3 to 2.2 brightness with a slow 15 % breathing flicker. `V2Idle = 1` while powered drives the idle flicker (50 % flicker at 9 Hz) and the nozzle ion glow, which stay on under thrust.
2. **Boost.** A state machine on the Boost input's rising and falling edge (see the timing table). A mini-boost (`FeelBoostKind == "Mini"` at the rising edge) uses scale `ExoticV2MiniBoostScale` (0.7) for the ignition burst and flash, and 0.88 for the sustained plume.
3. **Pops and bangs.** `Backfire` on a V2 car fires the `Backfire` burst (fireball puffs, spark streaks) at `scale = clamp(count / 12, 0.25, 2)` where `count` is the existing configured count (crackle 4..8, bang 14..24), adds the `BackfireBang` flame tongue when strength >= 0.8, and adds `0.5 + 1.2 * strength` to the boost light with decay time `0.6 * flashSeconds`.
4. **Under the car.**
   - Pads (`V2HoverPad`): parked `ExoticV2PadStandby` (0.25); airborne `ExoticV2PadAirborne` (0.3); grounded `clamp(ExoticV2PadBase (0.55) + ExoticV2PadSquashGain (0.35) * squash + ExoticV2PadSpeedGain (0.1) * speed)`; then `x (1 - 0.15 * speed * noise)`, and x 0.6 on remote cars. `V2HoverTight = squash` brings in the smaller, brighter pad. Discs are particles moving 0.05 studs/s straight down with `VelocityPerpendicular`, so they lie flat.
   - Ground point: local driving car, one `Workspace:Raycast` straight down from the root per visual update (30 Hz), `ExoticV2GroundRayStuds` (12) long, excluding the vehicle and all player characters (filter list rebuilt once a second). Hit: 0.12 above the surface, aligned to its normal. Miss: `ExoticV2GroundFallbackStuds` (3) below the root, and hidden when `FeelGrounded` is false. `presence` fades the ground effects from 1 to 0 as the gap grows from 1.6 x fallback to the ray length. Every other vehicle: the mean hover-socket position minus `ExoticV2GroundPadGapStuds` (1.6), set once, no raycast.
   - Dust ring (`V2GroundDust`): local `clamp(ExoticV2DustBase (0.15) + ExoticV2DustSpeedGain (0.6) * speed + ExoticV2DustSquashGain (0.5) * squash) * presence`; preview `ExoticV2PreviewDust` (0.2); other driving cars `ExoticV2RemoteDust` (0.3); 0 when parked or airborne.
   - Glow pool (`V2GroundGlow`) and the single light (`V2GroundLight`) = pad level x presence. The light is off with `ExoticV2GroundLightEnabled = false`.
   - Dust tint: the hit part's `Color`, or `Terrain:GetMaterialColor`, blended `ExoticV2GroundTintMix` (0.55) into the authored dust colours, rewritten only when the colour changes.
   - Landing: the existing `Burst("Dust", count)` now reaches `LandDust` (share 1) and `LandRing` (share 0.08) at the ground point.
5. **Drift.** Stabiliser jets use the existing `DriftLeft/DriftRight` inputs. Slide sparks: `clamp((|FeelSlip| - ExoticV2SlipSparkMin (0.12)) / 0.4)` while drifting and grounded, on the side the car slides toward (`FeelSlip > 0` = right; `ExoticV2SlipSparkSign = -1` swaps). Charge glow `V2DriftCharge = FeelDriftCharge`; arcs from 0.35 charge up. When `FeelBoostKind` becomes "Mini" the `DriftRelease` burst fires at the recent peak charge (minimum 0.4).
6. **Impacts.** `SetImpactSide(FeelImpactX, FeelImpactZ)` moves the spark source to where that direction leaves the car's bounds, half-way down, pointing away from the obstacle and slightly up; then the existing `Burst("Sparks", count)` is split sparks 1 : embers 0.45 : smoke 0.12 : flash 0.05. Without the attributes it sits front-bottom as before. `V2Scrape = FeelScrape` when above `ExoticV2ScrapeMin` (0.1) runs the scrape stream and keeps the source on that side.
7. **Speed.** Two vapour trails at the rear upper corners when `FeelSpeedMph >= ExoticV2VapourMinMph` (150); a tail ribbon in the thrust colour while the boost is ignited. Bounds come from `Model:GetBoundingBox()` when the root is the PrimaryPart (measured once), else from the hover-socket spread.

Sustained brake sparks are unchanged (still nothing on cars without an authored BrakeSparks socket); `BrakeSparks_ExoticV2` has no `Brake` channel.

### Boost timing

Times are from the rising edge of the Boost input, which the 30 Hz visual step sees up to 33 ms late.

| Time | What happens |
|---|---|
| 0 to `ExoticV2BoostIntakeSeconds` (0.1 s) | `V2BoostIntake = 1`: streaks rush into the nozzle. Engine jets at 60 %. Plume and light off. |
| 0.1 s | `BoostIgnite` burst (3 fireballs, 1 shock ring, 14 embers per boost socket, x scale). Light flash +2 x scale, decaying with a 0.07 s time constant. |
| 0.1 to `ExoticV2BoostHandoverSeconds` (0.6 s) | `settle` runs 0 to 1. Plume `= sustain * (1 + 0.3 * (1 - settle)^2)`. Arcs and the pulsing light fade in with `settle`. |
| 0.6 s onward | Plume = sustain. Light `= sustain * (0.7 + 0.3 * sin(2 pi * ExoticV2BoostPulseHz (10) * t))`. Arcs on. Tail ribbon on. |
| Boost ends | No burst. For `ExoticV2BoostFadeSeconds` (0.6 s): plume `= last * (1 - fade) * sputter`, sputter a 14 Hz noise between 0.55 and 1; smoke `= sin(pi * fade)`; light = half the plume. |

`sustain = 0.6 + 0.4 * scale`. At 30 Hz a 10 Hz pulse is sampled three times per cycle, so it reads as a flicker rather than a smooth sine.

### Budgets (per vehicle, two boost sockets; add 15 effects for a third)

Particle figures are my arithmetic from rate x lifetime, not measurements.

| | Effect instances | Lights | Raycast | Particles alive, cruising / worst case |
|---|---|---|---|---|
| Local, desktop | 133 (was 58) | 7 | 1 per update | about 110 / 270 |
| Local, mobile | 126 | 0 | 1 per update | about 60 / 145 |
| Remote, desktop | 65 | 0 | none | about 70 / 100 |
| Preview | 124 (no sparks, no trails) | 7, or 0 when more than `ExoticV2PreviewLightMax` (2) previews are tracked | none | about 45 idle / 180 in thrust-colour mode |

- Plus 18 host parts and 3 runtime sockets on a local car. All created at attach; nothing is created per frame. Per-update work is property writes, and a `NumberRange` only when a speed scale moves by more than 0.03.
- Worst case = full throttle, sustained boost, drifting with sparks and full charge, scraping, full dust: about 1000 particles/s emitted. `MaxRecommendedParticlesPerVehicle` (1000 live) caps each burst; sustained rates sit well under it.
- Mobile: rates x `MobileParticleScale` (0.8) x template `MobileScale` (0.7 jets, 0.6 hover and sparks); widths and brightness x `MobileScale`; all lights dropped at attach.
- Remote: the "Full" tier is dropped at attach (heat sheaths, embers, arcs, smoke, all lights, pad columns, mist, intake, slide sparks, charge and backfire emitters), pads at 60 %, no sparks source, no trails.
- Culling: beyond `CullDistanceStuds` every channel reads 0, bursts are skipped and the raycast is skipped.

### Preview rule

Previews get the same controller with no `Feel` table: no raycast, no trails, no impact source, ground effects at the fixed offset, pads at the base level, dust at 0.2. Idle mode shows the idle flicker, nozzle glow, pads and glow pool; thrust-colour mode adds the engine jets, plays the boost ignition once and then the sustained plume, fires both stabiliser sides and shows the charge glow at 0.6. Lights (engine, boost, ground) are on only while at most two preview models are tracked.

### Not verified (needs Studio)

- No property name or enum has been compiled. The ones to watch: `FlipbookLayout/Mode/Framerate/StartRandom`, `Enum.ParticleFlipbookMode.Random`, `Orientation`, `Trail.Brightness`, `Beam.Brightness`, `RaycastParams.FilterType = Enum.RaycastFilterType.Exclude`.
- **Dust ring direction**: `EmissionDirection = Right` with `SpreadAngle = (4, 180)` is meant to give a flat ring in the ground plane. If it comes out as a vertical fan, swap the two SpreadAngle components (`RING_SPREAD`).
- **Flame direction**: `VelocityParallel` is assumed to put the top of the fire_loop frame downstream. If the tongues point into the nozzle, add `Rotation = NumberRange.new(180, 180)` to the flame emitters.
- **Pad discs**: flat under the car as intended, and not clipping into the body (0.1 below the socket).
- **Stabiliser socket orientation**: I assumed +Z leaves the car sideways (rotation 90, -90, 0 in the dump). Sparks rely on world gravity, so they fall whichever way it points.
- Sizes: all tuned from the old templates' numbers (jet 5 studs by 1.3, boost 7 by 1.8, stabiliser 1.5 by 1), not from seeing the nozzles.
- Whether a runtime vehicle's root is its `PrimaryPart`, and whether `GetBoundingBox` gives sensible bounds (it includes everything in the model). Spark side placement and trail corners depend on it.
- Whether a parked local vehicle should show standby pads (set `ExoticV2PadStandby = 0` if not).
- What should count as ground: the VFX ray uses default params, like the driving rays.
- The textures; with a missing id the effect uses the old fire, beam, smoke or sparkle texture and no flipbook.
- Preview modules: the controller attaches sockets once. If a preview swaps modules in place rather than rebuilding the model, the new module gets no effects; that is how it already works.
- A V2 error is caught and warned once as `[VehicleVFX] Exotic V2 update failed: ...`; look for it in the console.

### Please check live

1. A spawned Exotic and a garage preview both resolve to V2: `VFX_EngineJet_Left_TemplateHost_Invisible_Runtime` should contain `JetCore`, and `VFX_FeelGroundFX` should exist under the root.
2. The dealership preview model (`Workspace.ClientOnly.VehiclePreview`): confirm it keeps the module sockets with `VFXTemplate = "..._Exotic..."`, or has `CategoryId` or `CockpitId` on the model that `VehicleVFXClient` tracks. If it is a nested Model, tell me which Model carries the attributes.
3. `vehicle.PrimaryPart` on a spawned Exotic, and the size `GetBoundingBox` returns.

### Manual test list

1. Compile all three; install templates; no console errors or `[VehicleVFX]` warnings.
2. `ExoticVFXV2Enabled = false`, respawn: exactly the previous look. True, respawn: V2.
3. Parked: dim pads, no jets. Enter: idle flicker and nozzle glow, pads brighten, glow pool on the ground.
4. Throttle: jets lengthen and brighten smoothly, shock diamonds visible, light breathes; ion rim in the thrust colour. Change the thrust colour in the garage: rim, pads, arcs and glow follow; fire keeps its colours with a tinted core.
5. Boost: intake, flash with ring and fireball on the ignition sound, long plume with arcs and a pulsing light, tail ribbon. Release: shrink and sputter with smoke, no bang. Mini-boost: the same, smaller.
6. Lift after hard thrust: puffs and sparks with each pop; bangs clearly bigger with a flame tongue.
7. Drive over different surfaces and a ramp: dust ring sits on the ground, takes the surface colour, grows with speed, disappears in the air, bursts on landing. Compress the hover (landing, dips): pads tighten and brighten.
8. Drift: side jets on the correct side, sparks from the side the car slides toward, charge glow and arcs build, burst when the mini-boost fires.
9. Hit a wall on the left, right and front: sparks and smoke from that side. Scrape along a wall: continuous stream that stops when clear.
10. Above 150 mph: two vapour trails; below: none.
11. Garage and dealership previews in idle and thrust-colour modes; open several previews and confirm lights drop out.
12. Second player: their Exotic shows jets, pads, glow pool and boost ignition, without arcs, lights or trails. Non-Exotic cars are unchanged.
13. Mobile or touch emulation: no lights, fewer particles, no errors. Race gate: hidden vehicles show nothing.
14. Exit and despawn: no `_Runtime` hosts or `VFX_Feel*` sockets left.

### Ideas for a later pass

- Heat-haze distortion behind the jets.
- A short scorch streak on the ground behind a boost launch.
- Wet-surface variant: spray instead of dust on water or wet materials, chosen from the same raycast.
- A quick ripple through the five pads on boost ignition and on landing.
- Nozzle glow that lingers and cools (orange to dull red) for a second after a long boost.
- A camera-facing lens streak on the ignition flash and on bangs.
- Wingtip vortices that curl and thicken in drifts.
- Drive the engine-jet light from the audio RPM so sound and glow breathe together.
- The same V2 attributes for Muscle and the other categories; only templates are needed.
