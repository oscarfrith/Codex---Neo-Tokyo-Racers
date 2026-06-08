# Vehicle Phase AL Performance Foundation

Status: installed and audit passed on 2026-06-08.

Confirmed audit:

- Cockpits: `5`
- Active modules: `72`
- Planned module upgrades: `23`
- Warnings: `0`

## Purpose

Phase AL installs the shared data/calculation foundation for:

- Detailed raw performance variables.
- Six player-facing headline stats.
- Overall `100-999` performance index.
- `E`, `D`, `C`, `B`, `A`, and `S` tiers.
- Contextual module stat mappings.
- Planned module-specific upgrade definitions.

It does not switch active driving, garage UI, purchases, profiles, or spawned vehicle stats.

## Run In Studio

Run:

```text
scripts/roblox_vehicle_phaseAL_performance_foundation.lua
```

Then run the read-only audit:

```text
scripts/roblox_vehicle_phaseAL_performance_audit.lua
```

## Installed Paths

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common.Performance
  VehiclePerformanceDefinitions
  VehiclePerformanceCalculator
  VehicleUpgradeDefinitions

ReplicatedStorage.NeoTokyoRacers.Shared.Config.VehiclePerformance_EditAttributes
  Normalization
  HeadlineWeights
  OverallRating
  TierBands
  CompatibilityDefaults
  ModuleContexts
```

## Headline Stats

The calculator returns:

```text
Speed
Acceleration
Handling
Drift
Braking
Boost
```

Raw variables are normalized to `0-100` before weighted averaging. Lower-is-better variables such as Weight, Drag, BoostRecharge, and BoostRechargeDelay are inverted automatically.

## Performance Rating

Overall weights:

```text
Speed         22%
Acceleration  20%
Handling      20%
Drift         14%
Braking       10%
Boost         14%
```

The weighted base score contributes `85%`. The average of the three lowest headline stats contributes `15%`, preventing one extreme stat from inflating an otherwise weak build.

Tier defaults:

```text
E 100
D 300
C 450
B 600
A 725
S 850
```

The maximum index is `999`.

## Compatibility

Phase AL derives new raw variables from existing Phase AK attributes for auditing:

- `Acceleration` becomes `EngineOutput`.
- `Handling` seeds LateralGrip, SteeringResponse, and HoverStability.
- `Drift` seeds DriftControl, DriftGrip, and DriftChargeRate.
- `Braking` becomes BrakingForce.
- `Boost` becomes BoostForce.
- Drag, Downforce, and BoostEfficiency start at neutral compatibility values.

This derivation does not change the actual vehicle.

## Upgrade Definitions

`VehicleUpgradeDefinitions` contains the planned module-specific upgrade catalogue but has:

```text
EnabledForPurchases = false
```

Phase AN will connect these definitions to profile storage, purchasing, previews, and final stat calculation.

## Verification

Good installer output:

- Shared performance modules installed.
- Catalogue models audited.
- No active gameplay or UI changed.

Good audit output:

- Headline weights total `1.000`.
- Overall weights total `1.000`.
- Tier bands increase in the correct order.
- Normalization ranges are valid.
- Warnings print `0`.

Standalone module ratings are diagnostic only. Meaningful vehicle ratings require cockpit plus installed modules and will be introduced during Phase AM.

## Rollback

Phase AL is isolated. To roll it back before Phase AM:

- Remove `Shared.Modules.Common.Performance`.
- Remove `Shared.Config.VehiclePerformance_EditAttributes`.

No active source owner needs reverting because Phase AL does not patch one.
