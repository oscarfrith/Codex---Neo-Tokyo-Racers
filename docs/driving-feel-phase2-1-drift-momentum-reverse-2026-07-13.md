# Driving Feel Phase 2.1 — Drift Momentum And Reverse Repair

**Created:** 2026-07-13  
**Status:** Installed and user-confirmed much better; post-confirmation mirror refresh still required

## Confirmed Cause

Phase 2 handling was reported good overall, but drifting lost too much forward momentum and reverse did not engage.

The post-Phase-2 mirror confirms the main slowdown was not caused by the vehicle's low `Drift 9` stat. The controller applied a fixed forward-drag coefficient of `0.72 + 0.42 * DriftBlend`, reaching `1.14` at full drift. Low Drift stats separately reduce drift grip, authority, and charge rate.

Reverse entered `Reverse` mode after its delay, but `SnapForwardStop` remained true on the same path and removed newly generated reverse velocity every frame.

## Installer

Run in Studio Edit mode:

```text
scripts/roblox_driving_feel_phase2_1_drift_momentum_reverse_repair.lua
```

This is a guarded two-anchor source repair against the refreshed Phase 2 module/controller. It preflights both anchors before either source is written and creates no backups.

## New Baseline

- `DriftForwardDragBase = 0.18`
- `DriftForwardDragBlendExtra = 0.10`
- Full-drift forward drag is `0.28`, down from `1.14`.
- Normal engine drive remains active during drift; long/high-speed drifts still shed momentum.
- DriftGrip, DriftControl, and DriftChargeRate retain their Phase 2 responsibilities.
- `ReverseEngageDelaySeconds = 1.0`.
- Stopped hold remains active during the delay and releases when reverse begins.

## Verification

1. Accelerate to approximately 50–70 MPH, hold acceleration, and enter a drift. Forward speed should remain useful rather than collapsing.
2. Release acceleration during a long drift. The vehicle should still lose momentum, but progressively.
3. Confirm the low-Drift `C 538` build remains looser and less authoritative than a future high-drift build.
4. Drive forward, hold brake continuously to a complete stop, and keep holding. The vehicle should remain stopped for approximately one second and then reverse.
5. Release brake during the delay: the timer should reset and the car should remain held.
6. Confirm acceleration, braking, parking hold, steering, drift recovery, mini-boost, camera, VFX, HUD, gamepad, and mobile remain healthy.

Useful debug attributes are `DynamicsMode`, `DynamicsReverseHoldTimer`, and `DynamicsDriftForwardDragCoefficient`.

## Tuning And Rollback

Tune the two drift values and reverse delay under `VehicleDynamics_EditAttributes`. To restore the old drift slowdown:

```lua
local config = game.ReplicatedStorage.NeoTokyoRacers.Config.Runtime.VehicleDynamics_EditAttributes
config:SetAttribute("DriftForwardDragBase", 0.72)
config:SetAttribute("DriftForwardDragBlendExtra", 0.42)
```

The reverse change is a defect repair rather than a balancing feature. Full dynamics rollback remains `Enabled=false`.

For the complete plain-language attribute map, use `docs/driving-feel-tuning-reference-2026-07-13.md`.
