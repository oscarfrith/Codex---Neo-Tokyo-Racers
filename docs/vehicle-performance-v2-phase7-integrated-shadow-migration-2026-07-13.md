# Vehicle Performance V2 — Phase 7 Integrated Shadow Migration

Date: 2026-07-13

Status: first Edit-mode run installed the isolated owners and passed 15 checks, with two validation-only false failures. The canonical installer is corrected and awaits one rerun, one Play-mode shadow test, complete Output, and refreshed Studio mirror.

## Purpose

Phase 7 is the single consolidated pre-live integration phase. It covers compatibility, V2 calculation, six-point module-instance upgrades, persistence migration, purchase/PI previews, and live-vehicle shadow comparison without publishing the staged catalogue or replacing any current gameplay owner.

The installer uses no fragile source text replacement. It does not edit the register-limited client bootstrap, the 2,700-line garage controller, `VehicleDynamicsModel`, V1 performance/upgrade modules, UI, VFX, racing, or live category assets.

## Installed owners

- `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common.Performance.VehiclePerformanceV2Runtime`
- `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common.Performance.VehiclePerformanceV2UpgradeRuntime`
- `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common.Performance.VehiclePerformanceV2DynamicsAdapter`
- `ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehiclePerformanceV2ShadowService_Active`
- `VehiclePerformanceV2_EditAttributes.Integration` policy attributes

The staging root and all staged models receive `V2IntegrationReady = true` while retaining `CatalogPublishReady = false`.

## Upgrade and persistence contract

- Standard modules accept zero points.
- Lightweight and Power modules accept six total points, with three maximum in one path.
- Allocations live on the owned module instance as `V2UpgradePoints = { [PathId] = points }`.
- Point price depends on total points already spent and uses the Phase 5 `Point1CostGuide` through `Point6CostGuide` attributes.
- Preview returns the next cost, changed raw values, and unrounded PI impact.
- Phase 7 migrates only a cloned profile during validation; it never changes a real session or saved profile.
- Legacy upgrade levels remain preserved in `V2LegacyUpgradeLevels`.
- Up to six purchased legacy levels become V2 points. Overflow that cannot fit the six-point/three-per-path rules becomes `V2MigrationRefundCredit`, calculated from the original purchase-cost curve.
- Actual profile mutation, refund payment, and V2 purchase routing remain disabled until Phase 8.

## Shadow runtime boundary

`VehiclePerformanceV2ShadowService_Active` waits for the existing V1 `RAW_PERFORMANCE_Runtime` folder on a spawned vehicle, debounces its initial value writes, calculates V2 once, and writes only:

- `V2ShadowPerformanceIndex`
- `V2ShadowInternalPerformanceIndex`
- `V2ShadowPerformanceTier`
- `V2_SHADOW_RAW_PERFORMANCE_Runtime`
- `V2_SHADOW_HEADLINE_STATS_Runtime`

The dynamics adapter derives physics factors from the same per-stat V2 curves used by rating, but it remains unwired in Phase 7. The shadow service never writes `PerformanceIndex`, `PerformanceTier`, `Performance_*`, driving forces, or input state. V1 remains authoritative.

## Studio script

Run in Studio Edit mode while not playing:

`scripts/roblox_vehicle_performance_v2_phase7_integrated_shadow_migration.lua`

The installer first requires the exact Phase 6 staging marker, schema, six cockpits, 72 modules, and unpublished state. Missing or mismatched staging stops before mutation.

## Edit-mode verification

1. Confirm `SUMMARY - PASS=17 WARN=0 FAIL=0`.
2. Confirm six `SHADOW STOCK` lines reproduce approximately E200, D375, C525, B662, A787, and S925.
3. Confirm Standard lockout and six-total/three-per-path allocation checks pass.
4. Confirm legacy conversion, overflow refund credit, DataStore safety, purchase preview, and positive unrounded PI preview pass.
5. Confirm live V1 sources and live category hierarchy remain unchanged.
6. Confirm rating, physics, purchases, real profile migration, and catalogue publication switches remain false.

The first run reported `PASS=15 WARN=0 FAIL=2`. Neither failure indicated a live integration problem:

- upgrade preview was tested against an otherwise empty zero-stat build, so the interaction layer could legitimately mask the PI gain; the corrected check uses a complete Viper build with the Power front engine;
- the shadow guard searched the service caller for a write marker owned by `VehiclePerformanceV2Runtime`; the corrected check audits both the real write owner and service source.

Rerun this same canonical Phase 7 installer. It accepts the Phase 7 schema and safely refreshes the same isolated owners; do not create or run a separate repair phase.

## Play-mode verification

Stop and restart Play after installation so ModuleScript require caches are fresh.

1. Spawn and drive the current vehicle normally.
2. Select its root model in Workspace.
3. Confirm `V2ShadowPerformanceIndex` and `V2ShadowPerformanceTier` appear after the V1 raw runtime folder is written.
4. Confirm the existing `PerformanceIndex` and `PerformanceTier` remain present and are not replaced by the V2 values.
5. Confirm acceleration, braking, handling, drifting, reverse delay, parking, boost, UI, customisation, spawning, and racing are unchanged.
6. Confirm Output contains the Phase 7 shadow-service startup line and no V2 errors.
7. Copy the complete Edit and Play Output into chat.
8. Refresh the Studio mirror using the receiver/full snapshot exporter.

## Rollback

Before Phase 8, rollback is isolated:

- delete `VehiclePerformanceV2Runtime`, `VehiclePerformanceV2UpgradeRuntime`, and `VehiclePerformanceV2DynamicsAdapter`;
- delete `VehiclePerformanceV2ShadowService_Active`;
- delete `VehiclePerformanceV2_EditAttributes.Integration`;
- restore config schema/source revision to Phase 5 and remove the Phase 7-only switches/notes;
- remove `V2IntegrationReady`/integration schema markers from staging while leaving the valid Phase 6 assets intact.

No live catalogue, profile, cash, upgrade, rating, physics, driving, UI, or player-data rollback is required because none is switched in Phase 7.

## Next and final phase

Phase 8 remains one atomic live launch. Do not create additional phases or sub-phases without the user's explicit approval. If Phase 7 needs a repair, update this same canonical installer.
