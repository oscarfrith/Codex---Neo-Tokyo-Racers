# Canonical V2 runtime ownership and active legacy retirement

Date: 2026-07-17

Status: installer generated after the canonical resolver/rating phase passed Studio and Play testing.

## Purpose

The garage and module cards now calculate through `VehiclePerformanceResolver`, but the spawned writer and profile-upgrade facade still contain disabled legacy branches. This phase removes those active branches without changing the public APIs used by the garage server or vehicle service.

## Changes

- `VehiclePerformanceRuntime` becomes an unconditional V2 facade and retains `CalculateBuild` plus `WriteToVehicle` for its existing caller.
- `VehicleModuleUpgradeRuntime` keeps its existing public functions while making physical module instances, V2 allocations, V2 catalogs, V2 purchases and V2 profile calculation unconditional.
- The spawned-vehicle writer waits for the materialised cockpit and installed module root, then calculates directly from those components. It no longer waits for or reads `TOTAL_STATS_Runtime`.
- The installer does not delete the compatibility calculator/definitions because the dormant bootstrap still requires them during setup. Their deletion is gated on extracting those bootstrap references safely.

## Safety

The installer is a full canonical replacement of three isolated sources rather than a text-anchor patch. It compiles all replacement sources before assignment, retains the public call signatures, restores all three sources if the post-install audit fails, and creates no backup hierarchy.

## Verification

After the Edit-mode install succeeds, restart Play and verify:

1. dealership and owned vehicle PI/tier remain unchanged;
2. owned/shop module ratings and selected-module stat previews remain unchanged;
3. a performance upgrade purchase persists and affects the preview;
4. spawning the same vehicle produces the same tier/PI shown in the garage;
5. Studio Output contains `[NTR Canonical V2 Runtime] Wrote ...` and no legacy fallback or materialisation errors.
