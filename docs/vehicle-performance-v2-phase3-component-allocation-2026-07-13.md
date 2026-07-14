# Vehicle Performance V2 — Phase 3 Component Allocation

Date: 2026-07-13

Status: user reported completed; refreshed mirror generated at `2026-07-13 21:01:42` contains the Phase 3 schema, allocation policy, and all six five-component hierarchies.

## Purpose

Phase 3 converts each complete-stock V2 profile into five replaceable pieces:

- cockpit;
- front engine;
- rear engine;
- stabilisers;
- boost.

This is required before live module work. If all raw performance stayed on the cockpit, installing an A/S-tier module on an E-tier cockpit would not carry meaningful A/S-tier strength.

## Allocation policy

- TopSpeed and EngineOutput: cockpit `35%`, front engine `32.5%`, rear engine `32.5%`.
- Weight: cockpit `70%`, each engine `10%`, stabilisers `5%`, boost `5%`.
- Handling, drift, braking, and downforce variables: cockpit `35%`, stabilisers `65%`.
- Boost variables: cockpit `35%`, boost module `65%`.
- Drag: cockpit `70%`, stabilisers `15%`, boost `15%`.

Lower-is-better values are split as positive portions of the complete-stock target. Replacing an E-tier module with a higher-tier module therefore reduces its Weight/Drag/recharge contribution while improving its higher-is-better stats.

Standard components have `Upgradable = false` and `UpgradePointCapacity = 0`. Lightweight/Power variants and their six-point paths remain a later phase.

## Sheet

Each `Vehicle - ...` dossier now has a tall `V2 STOCK COMPONENT ALLOCATION` section. The new `Vehicle - Zenith` dossier copies the Viper page structure with reserved `bruiser_06` / `BRUISER_06` identities and remains planned/shadow-only.

All six pages report `17/17 MATCH`, so all `102` raw-stat allocations recombine exactly.

## Studio script

Run in Studio Edit mode:

`scripts/roblox_vehicle_performance_v2_phase3_component_allocation.lua`

The script adds config folders only beneath the six `BalancedStockProfiles` entries. It performs no source replacement and does not create or alter cockpit/module assets.

## Verification

1. Confirm `FAIL=0`.
2. Confirm six recombined `STOCK` lines remain approximately E202, D374, C525, B662, A787, and S925.
3. Confirm the script reports all `102` sums matching.
4. Confirm four `SWAP` lines—front engine, rear engine, stabilisers, and boost—rise monotonically through the E–S donor ladder when installed on Forge.
5. Confirm live assets remain `5 cockpits / 72 active modules`.
6. Confirm both V2 runtime switches remain false.
7. Refresh the full Studio mirror and paste the complete Output into chat.

## Rollback

Delete `ComponentAllocationPolicy` and each profile's `ComponentAllocation` folder, then restore schema/source revision attributes to the confirmed Phase 2 values. Live assets and V1 runtime need no rollback because Phase 3 does not touch them.
