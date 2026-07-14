# Vehicle Performance V2 — Phase 5 Upgrade Paths

Date: 2026-07-13

Status: corrected rerun user-confirmed passing; refreshed mirror at `2026-07-13 21:51:45` contains all 48 upgrade-path folders and corrected Efficiency definitions.

## Purpose

Phase 5 defines the individual six-point progression for every Lightweight and Power front engine, rear engine, stabiliser, and boost donor. It remains shadow-only: no live module, upgrade, price, rating, physics, UI, or asset changes are made.

## Point structure

- Lightweight and Power modules each have three paths.
- Each path accepts `0-3` points.
- Each module can spend at most six points total.
- Each point changes primary path-owned raw values by `3%` of that variant's base value; Efficiency's supporting EngineOutput change is half-strength at `1.5%`.
- Standard modules remain non-upgradable.

This creates an actual build choice: a completed module can max two paths or spread points across all three. Because changes are percentage-based on the donor variant, higher-tier modules retain stronger raw upgrades while the V2 curves naturally reduce their PI gain at the top end.

## Paths

| Component | Path | Per-point effect |
| --- | --- | --- |
| Front/Rear Engine | Velocity | TopSpeed `+3%` |
| Front/Rear Engine | Output | EngineOutput `+3%` |
| Front/Rear Engine | Efficiency | Weight `-3%`; EngineOutput `+1.5%` |
| Stabilisers | Grip | LateralGrip, BrakingForce, Downforce `+3%` |
| Stabilisers | Response | SteeringResponse, HoverStability `+3%` |
| Stabilisers | Drift | DriftControl, DriftGrip, DriftChargeRate `+3%`; Drag `-3%` |
| Boost | Burst | BoostForce `+3%` |
| Boost | Endurance | BoostDuration, BoostEfficiency `+3%` |
| Boost | Recovery | BoostRecharge, BoostRechargeDelay, Drag `-3%` |

## Cost guide

Point price is based on total points already spent on the module, independent of path: `8%`, `10%`, `12%`, `15%`, `18%`, then `22%` of module guide price. Costs round to the nearest `$100`; all six points total roughly `85%` of the module guide price. These remain economy guides, not live garage prices.

## Studio script

Run in Studio Edit mode:

`scripts/roblox_vehicle_performance_v2_phase5_upgrade_paths.lua`

The script creates only folders/attributes under the existing shadow V2 config. It performs no source text replacement and creates no backups.

## Verification

1. Confirm `FAIL=0`.
2. Confirm `UPGRADE` lines cover six donors × four components × two variants.
3. Each path's point 1, 2, and 3 gain must be positive and increasing versus the prior point.
4. Every full six-point two-path pairing must improve PI.
5. Confirm the same first point gains less native-build PI at S than at E.
6. Confirm six `COST` lines rise by point and remain below the module guide price cumulatively.
7. Confirm Standard modules remain non-upgradable.
8. Confirm live V1 sources and the live asset hierarchy remain unchanged.
9. Confirm V2 rating and physics switches remain false.
10. Refresh the Studio mirror and paste the full Output into chat.

## First-run calibration lesson

The first Studio run passed every preservation, cost, full-six-point, and diminishing-return gate but finished `PASS=9 WARN=0 FAIL=12`. All failures were isolated to the engine Lightweighting path at A/S: those complete builds had already reached the Weight curve's technical minimum, so further raw Weight reduction could not increase PI.

The canonical script now uses an Efficiency path instead. It retains Weight `-3%` per point for vehicle feel and adds half-strength EngineOutput `+1.5%` per point so the path remains rating-visible after Weight reaches its technical floor. Changing the global Weight curve would have disturbed all six confirmed stock profiles, so it was deliberately avoided.

The user confirmed the corrected rerun passed all gates. The refreshed mirror contains 48 `UpgradePaths` folders and the expected Efficiency definitions; V2 rating and physics remain disabled.

## Rollback

Delete `UpgradePaths` beneath each Lightweight/Power variant, remove their `Point1CostGuide` through `Point6CostGuide` and `MaxPointsPerPath` attributes, restore `VariantPolicy.UpgradePathsDefined = false`, and restore the Phase 4 schema/source revision. No live runtime or asset rollback is required.
