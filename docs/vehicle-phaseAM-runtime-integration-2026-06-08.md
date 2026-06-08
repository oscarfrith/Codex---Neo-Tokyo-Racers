# Vehicle Phase AM Runtime Integration

Status: installed and confirmed working on 2026-06-08.

Confirmed result:

- Runtime writer active.
- Raw variables: `17/17`.
- Normalized variables: `17/17`.
- Headline stats: `6/6`.
- Test build rating: `D 407`.
- Audit warnings: `0`.
- Detailed physics enabled and reported working well.

## Purpose

Phase AM connects the Phase AL performance calculator to complete spawned vehicle builds.

It adds:

- Full-build raw variables.
- Normalized variables.
- Six headline stats.
- Overall performance score, `100-999` index, and `E-S` tier.
- Cockpit performance overrides and installed-module performance deltas.
- Detailed-variable support in the V75 driving controller.

It does not change garage UI, profile storage, purchases, or module upgrades.

## Fragile Patch Warning

The installer uses guarded source-text replacement against:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.DrivingControllerV47
```

It preflights all required matches before changing either source. If a live source shape differs, it stops with an exact-match error instead of partly applying.

## Gate 1: Runtime Data

Run while not play-testing:

```text
scripts/roblox_vehicle_phaseAM_runtime_integration.lua
```

The installer deliberately leaves:

```text
VehiclePerformance_EditAttributes.RuntimeIntegration.PhysicsEnabled = false
```

Start Play, buy/select a cockpit, equip the required modules, and spawn the drivable vehicle. Then run:

```text
scripts/roblox_vehicle_phaseAM_runtime_audit.lua
```

Good output:

- Raw variables `17/17`.
- Normalized variables `17/17`.
- Headline stats `6/6`.
- A valid tier and performance index.
- Physics enabled `false`.
- Warnings `0`.

### Runtime Writer Repair

If a freshly spawned vehicle still reports all three runtime folders missing, run:

```text
scripts/roblox_vehicle_phaseAM_runtime_writer_repair.lua
```

This installs:

```text
ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehiclePerformanceRuntimeService_Active
```

The service watches `Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles` and writes performance data after the legacy total-stat folder appears. It avoids further source patching inside the garage controller.

This isolated service is the confirmed live Phase AM runtime owner. The earlier garage-controller runtime hook did not write the folders on a fresh spawn, while the service passed the complete audit and driving test.

## Gate 2: Physics

After the runtime audit passes, stop Play and run:

```text
scripts/roblox_vehicle_phaseAM_enable_runtime_physics.lua
```

Spawn a fresh vehicle and compare:

- Acceleration and top speed.
- Normal and drift grip.
- Steering response.
- Hover stability over slopes and bumps.
- Drift charge and mini boost.
- Braking and reversing.
- Boost force, duration, recharge delay, and recharge.
- Keyboard, gamepad, and mobile controls.

Compatibility-derived values are calibrated against the matching legacy Handling and Drift values. The initial multiplier is therefore `1` until a detailed value is deliberately changed.

## Editable Runtime Tuning

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Config.VehiclePerformance_EditAttributes.RuntimeIntegration
```

Attributes:

- `PhysicsEnabled`
- `LateralGripInfluence`
- `HoverStabilityInfluence`
- `DriftGripInfluence`
- `DriftChargeInfluence`
- `DragInfluence`
- `DownforceInfluence`
- `BoostEfficiencyInfluence`

## Asset Tuning Attributes

Cockpit absolute override:

```text
PerformanceOverride_LateralGrip
PerformanceOverride_Drag
```

Cockpit or installed-module additive delta:

```text
PerformanceDelta_LateralGrip
PerformanceDelta_Drag
```

The same prefixes work for every Phase AL raw variable. Missing attributes preserve compatibility-derived values.

The installer adds zero-value deltas for the detailed cockpit variables and only the context-relevant variables on each active module type. Existing values are preserved on rerun.

## Spawned Runtime Data

Each spawned vehicle receives:

```text
RAW_PERFORMANCE_Runtime
NORMALIZED_PERFORMANCE_Runtime
HEADLINE_STATS_Runtime
```

It also receives:

```text
PerformanceIndex
PerformanceTier
PerformanceScore
PerformanceRuntimeVersion
Performance_<RawVariableName>
```

## Rollback

Immediate physics rollback:

1. Open `scripts/roblox_vehicle_phaseAM_enable_runtime_physics.lua`.
2. Set `ENABLE = false`.
3. Run it and spawn a fresh vehicle.

This restores V75 legacy driving reads while leaving diagnostic runtime data available.

Full source rollback should use Roblox version history from immediately before Phase AM. Do not rerun V75 wholesale because that could overwrite newer path and architecture repairs.

## Mirror Refresh

After Studio installation and testing, refresh:

```text
roblox/exported_scripts/
roblox/studio_snapshot/
```

Start `py scripts/receive_studio_full_snapshot_export.py`, then run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in Studio. Do not commit `docs/studio-full-export-paste.txt`.
