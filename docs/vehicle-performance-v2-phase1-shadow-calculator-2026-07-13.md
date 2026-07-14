# Vehicle Performance V2 — Phase 1 Shadow Calculator

Date: 2026-07-13

Status: installed and audit-confirmed; Studio output passed `12 PASS / 0 WARN / 0 FAIL`. The refreshed `2026-07-13 20:22:34` mirror contains the V2 config, definitions, calculator, and restored `ReverseEngageDelaySeconds = 1.0`.

## Purpose

Phase 1 installs the V2 mathematical contract beside V1 without switching any player-facing rating or driving behaviour to V2. This allows the five current standard builds and later specialist/cross-tier builds to be calibrated before runtime risk is introduced.

It also restores `ReverseEngageDelaySeconds` from the live-audited `0.3` to the user-approved `1.0`. This is a config-only restoration; it does not patch `VehicleDynamicsModel` or `DrivingControllerV47` source.

## Studio script

Run in Studio Edit mode:

`scripts/roblox_vehicle_performance_v2_phase1_shadow_calculator.lua`

The installer creates:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Config.VehiclePerformanceV2_EditAttributes
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common.Performance.VehiclePerformanceV2Definitions
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common.Performance.VehiclePerformanceV2Calculator
```

The config contains the 17 Sheet-derived curve definitions, six headline-weight folders, overall/asymptotic PI settings, and tier bands. Both runtime switches are explicitly false:

- `RuntimeRatingEnabled = false`
- `RuntimePhysicsEnabled = false`

## Calculation contract

The shadow calculator implements:

1. uncapped cockpit + module + upgrade raw values;
2. stat-specific higher/lower-is-better power curves with technical minimums;
3. weighted arithmetic/multiplicative headline blending;
4. Speed, Acceleration, Handling, Drift, Braking, and Boost;
5. `7.5%` weakest-three balance contribution;
6. an initial asymptotic internal PI with `RatingScale = 150`, superseded for calibration by Phase 2's editable performance origin and calibrated scale;
7. decimal internal PI plus separately rounded display PI;
8. the existing E-S tier thresholds during calibration.

`EffectiveFactor(variableName, rawValue)` is the future shared curve entry point for physics. Phase 1 deliberately does not connect it to `VehicleDynamicsModel` yet.

## Built-in smoke tests

The installer verifies:

- V1 definitions/calculator/runtime source remains byte-for-byte unchanged;
- all 17 reference values produce factor `1.0`;
- EngineOutput is no longer balance-capped at factor `1.6`;
- the same raw EngineOutput addition has diminishing but still positive effect at high values;
- inverse curves stay finite at technical minimums;
- neutral reference stats produce a finite PI between 100 and 999;
- the same `+20 EngineOutput` produces a larger PI change on a low-power build than a high-power build;
- all five current standard builds calculate in shadow without writing vehicle attributes;
- both V2 runtime switches remain disabled.

## Verification

Confirmed installation result:

- all 12 built-in checks passed;
- V1 definitions/calculator/runtime source remained byte-for-byte unchanged;
- all 17 reference factors, uncapped EngineOutput, diminishing returns, technical minimum, and cross-tier PI checks passed;
- the five live stock builds were calculated in shadow only;
- both V2 runtime switches remained false.

For a fresh/recovery installation:

1. confirm the installer ends with `FAIL=0`;
2. copy the full `SHADOW` catalogue lines into chat;
3. briefly Play-test Viper braking to a complete stop, then hold brake continuously;
4. confirm reverse begins after roughly one second;
5. confirm ordinary acceleration, handling, drifting, braking, boost, UI rating, garage, and spawning remain otherwise unchanged;
6. stop Play and refresh the full Studio mirror.

## Mirror refresh

Because Phase 1 creates modules/config folders and changes a live config attribute:

1. run `py scripts/receive_studio_full_snapshot_export.py` locally;
2. run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in the Studio Command Bar;
3. allow the receiver to import the export;
4. do not commit `docs/studio-full-export-paste.txt`.

## Rollback

Before a runtime switch, rollback is small:

- delete `VehiclePerformanceV2_EditAttributes`;
- delete `VehiclePerformanceV2Definitions` and `VehiclePerformanceV2Calculator`;
- set `ReverseEngageDelaySeconds` back to `0.3` only if deliberately restoring the pre-Phase-1 live value.

V1 source is never edited, so no place-version revert should be necessary for Phase 1.
