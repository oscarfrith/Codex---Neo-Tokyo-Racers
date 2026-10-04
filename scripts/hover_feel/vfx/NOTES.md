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
