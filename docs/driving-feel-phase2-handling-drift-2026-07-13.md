# Driving Feel Phase 2 — Handling And Drift Calibration

**Created:** 2026-07-13  
**Status:** Installed; handling reported good overall, with drift-momentum and reverse follow-up moved to Phase 2.1

## Confirmed Starting Point

The user confirmed Phase 1 worked well. The post-confirmation mirror was generated at `2026-07-13 12:30:18`, exported `113` scripts, and contains:

- the guarded `NTR_DRIVING_FEEL_PHASE1_DYNAMICS_BRIDGE`;
- `VehicleDynamicsModel` with 202 source lines;
- `VehicleDynamics_EditAttributes` with 26 attributes;
- the non-yielding module require fallback.

Phase 2 does not change the approved acceleration, coasting, braking, stopped hold, or delayed reverse formulas.

The user subsequently reported that general handling feels good. Excessive drift speed loss and failed reverse movement were traced separately in the refreshed live source; use `docs/driving-feel-phase2-1-drift-momentum-reverse-2026-07-13.md` rather than retuning the detailed handling variables to compensate.

## Installer

Run in Studio Edit mode:

```text
scripts/roblox_driving_feel_phase2_handling_drift_calibration.lua
```

This is a guarded source-shape-dependent installer. It preflights two isolated-module anchors and five small controller anchors before changing either source. If any anchor fails, stop and inspect the refreshed live source rather than attempting another patch.

## Detailed Variable Ownership

- `SteeringResponse`: remains the base yaw/turn-rate character before the confirmed speed-sensitive steering curve.
- `LateralGrip`: ordinary sideways-velocity resistance.
- `Downforce`: additional ordinary grip that grows with speed rather than affecting parking heavily.
- `HoverStability`: alignment responsiveness to terrain and disturbances.
- `DriftGrip`: sideways resistance while drifting.
- `DriftControl`: drift side force and extra drift turn authority.
- `DriftChargeRate`: mini-boost charge speed.
- `Weight`: retains the existing restrained steering/drift modifier until wider multi-build balance testing.

## Verification

Restart Play and spawn a fresh vehicle. Check:

1. Phase 1 acceleration, coasting, braking, stopped hold, and reverse delay remain unchanged.
2. Ordinary steering still feels good at parking, medium, high, and boost speeds.
3. The current low-Drift `C 538` build can still initiate and control a drift, but should not behave like a high-drift build.
4. Drift entry remains intentional, sideways slip is recoverable, and releasing drift returns cleanly to normal grip.
5. Drift mini-boost still requires acceleration and charges at a believable rate.
6. Slopes and uneven terrain remain stable without becoming rigid or sluggish.
7. Camera, banking, pitch tilt, reset, VFX, HUD, keyboard, gamepad, and mobile paths remain functional.

Useful debug attributes:

- `DynamicsLateralGrip`
- `DynamicsNormalGrip`
- `DynamicsDriftGrip`
- `DynamicsDriftControlFactor`
- `DynamicsDriftChargeFactor`
- `DynamicsDownforceFactor`
- `DynamicsHoverStabilityFactor`

## Rollback

To disable only Phase 2 while retaining Phase 1:

```text
game.ReplicatedStorage.NeoTokyoRacers.Config.Runtime.VehicleDynamics_EditAttributes:SetAttribute("HandlingEnabled", false)
```

Restart Play after changing it. Full Phase 1 rollback remains `Enabled=false`.

Do not rebalance module economy, performance-index normalization, or every vehicle template from the first test. Confirm the current build's qualitative behavior first, then compare Standard, Lightweight, and Power builds before changing stat ranges.
