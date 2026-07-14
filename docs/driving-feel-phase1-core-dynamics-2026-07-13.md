# Driving Feel Phase 1 — Core Dynamics

**Created:** 2026-07-13  
**Status:** Installed and user-confirmed working well; post-confirmation mirror refreshed at 2026-07-13 12:30:18

The first install reached the controller bridge but Play reported an infinite yield waiting for `VehicleDynamicsModel`, followed by a bootstrap `startDriving` nil call. The canonical installer now recreates/refreshes the module on every run and upgrades the controller require to a non-yielding guarded load with legacy-force fallback. Rerun the same canonical Phase 1 installer rather than applying another source patch.

## Phase 0 Evidence

The Edit-mode audit passed `11/10/0` (`pass/warn/fail`). All warnings were expected findings. The Play run was accidentally executed from the Client Command Bar, so its two server-visibility failures were false negatives; the canonical audit now skips those checks in client context.

The valid spawned-vehicle evidence was:

- Rating: `C 538`
- Legacy Acceleration / detailed EngineOutput: `81 / 81`
- Legacy Handling / detailed SteeringResponse: `45 / 45`
- Legacy Drift / detailed DriftControl: `9 / 9`
- Legacy Braking / detailed BrakingForce: `106 / 106`
- Legacy Boost / detailed BoostForce: `25 / 25`
- TopSpeed: `139 MPH`
- Weight: `137`
- Drag / LateralGrip / Downforce: `50 / 45 / 50`
- Root: `CanCollide=true`, collision group `Default`
- Assembly mass: `241`

This confirmed the detailed data is being written, but the active driving source did not contain the documented Phase AM physics bridge.

## Installer

Run this complete file in the Studio Command Bar while not play-testing:

```text
scripts/roblox_driving_feel_phase1_core_dynamics.lua
```

The installer uses guarded plain-text source replacement. This is intentionally fragile: it requires one exact match for each of four preflight anchors in the refreshed `DrivingControllerV47` and stops before writing if any count differs. It does not patch the register-limited client bootstrap and creates no in-game backup objects.

On rerun after the first partial persistence result, it detects the existing Phase 1 marker, recreates the missing module, and replaces only the original unsafe `WaitForChild` require with a guarded non-yielding fallback.

## Installed Architecture

The installer creates or canonically refreshes:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.VehicleDynamicsModel
ReplicatedStorage.NeoTokyoRacers.Config.Runtime.VehicleDynamics_EditAttributes
```

It makes a small bridge in `DrivingControllerV47` and preserves the existing hover, slope compensation, camera, speed-sensitive steering, drift, pitch tilt, boost, VFX attributes, mobile/gamepad input, reset, and UI telemetry paths.

## First-Pass Behavior

- `EngineOutput`, `TopSpeed`, `Weight`, `BrakingForce`, `Drag`, and the existing boost/handling aliases read from the detailed runtime data with legacy fallbacks.
- Forward acceleration uses a progressive speed curve rather than `Acceleration * 3.1` and an `0.08` force floor.
- Aerodynamic resistance makes top speed an approach rather than an immediate plateau.
- Neutral input uses base plus speed-sensitive coasting resistance.
- Negative throttle while moving forward is braking only.
- Near zero, the car enters a stopped hold.
- Reverse engages after a configurable `0.3 s` stopped hold rather than immediately crossing through zero.
- `BrakingForce` controls braking deceleration.

The current `C 538` audit build should start near the plan's target of roughly `3.5–4.5 s` for 0–60 MPH and roughly `2.2–3.0 s` for 60–0 MPH, but player feel is the confirmation gate.

## Verification

After installation, restart Play and spawn a fresh vehicle. Verify:

1. Output prints the normal V75 active line and no require/parse/runtime errors.
2. Acceleration builds progressively and no longer reaches top speed almost immediately.
3. Releasing acceleration produces a deliberate coast that settles at low speed.
4. Holding brake from forward motion stops the car before reverse begins.
5. Reverse begins only after the stopped hold and remains capped by `ReverseMaxMph`.
6. Low-speed parking is materially easier.
7. Steering, drift, boost, hover, slopes, camera, reset, HUD speed/boost, and VFX still work.
8. Test at least one normal boost and one drift mini-boost for unintended limiter fighting.

Useful spawned-vehicle debug attributes are:

- `DynamicsMode`
- `DynamicsForwardMph`
- `DynamicsLongitudinalAcceleration`
- `DynamicsAccelerationCurve`
- `DynamicsEngineFactor`
- `DynamicsWeightFactor`
- `DynamicsReverseHoldTimer`

## Tuning And Rollback

Tune attributes under `VehicleDynamics_EditAttributes`; do not edit the module source for ordinary balancing.

Immediate rollback:

```text
VehicleDynamics_EditAttributes.Enabled = false
```

Then restart Play. The controller retains the previous force calculation as the disabled-path fallback. This does not remove the module or source bridge.

The user confirmed the Phase 1 feel worked well. Proceed through `docs/driving-feel-phase2-handling-drift-2026-07-13.md`; retain this file as the Phase 1 tuning and rollback reference.
