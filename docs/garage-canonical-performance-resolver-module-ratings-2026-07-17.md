# Canonical garage performance resolver and module ratings

Date: 2026-07-17

Status: installed and user-confirmed working in Studio and Play on 2026-07-17. This is the canonical garage calculation and module-rating baseline.

## Purpose

`scripts/roblox_vehicle_performance_canonical_resolver_and_module_ratings.lua` removes the active garage's seven-stat dealership calculation and makes factory vehicles, owned builds, selected-module previews and module cards use the same V2 calculation contract as spawned driving.

## Contained changes

- Creates the isolated pure `VehiclePerformanceResolver` module beneath the existing shared performance modules.
- Routes the canonical garage application and read-only module preview adapter through that resolver.
- Reuses `GarageModuleCardViewModel` and adds only an optional derived-rating callback.
- Calculates module ratings by placing a module into the fixed Viper stock reference build. Physical copies include their saved V2 upgrade points. Ratings are derived and are not separately persisted.
- Materialises the 12 active Level 1-3 Front Bumper, Rear Bumper, Side Pods and Rear Spoiler templates into explicit V2 raw variables.
- Preserves those accessories' existing upgrade choices by creating 33 V2 paths and adding flat-delta support to the isolated V2 upgrade runtime.
- Runs one idempotent instance migration pass so legacy accessory upgrade levels can become physical-instance V2 points without changing ownership, colours or neon data.
- Corrects the ambiguous client engine fallback from `ENGINE_B` to `MODULE_ENGINE_B_`.

The installer does not add code to the register-limited bootstrap and does not replace the confirmed spawned-vehicle runtime adapter. Dormant bootstrap compatibility code remains for the later legacy-removal audit.

## Install

Run the installer once from the Studio Command Bar in Edit mode. A successful run ends with:

`[NTR Canonical Performance Resolver] INSTALL COMPLETE`

The installer compiles all five affected module sources before assignment, records changed attributes in memory, and restores sources/attributes plus removes newly-created objects if its post-install audit fails. It creates no in-game backup hierarchy.

## Play verification

1. Restart Play so all ModuleScript caches are fresh.
2. Open the dealership and confirm Forge through Zenith show approximately E202, D374, C525, B662, A787 and S925.
3. Buy/select one vehicle and confirm its unchanged stock build shows the same tier, PI and six headline stats on later pages.
4. Open Front Engine owned/shop cards and confirm each card has a numeric rating; upgraded physical copies should sort using their upgraded rating.
5. Select a different module and confirm the stats delta matches the previewed vehicle.
6. Equip and spawn, then confirm the menu tier/PI agrees with the spawned vehicle attributes.
7. Open one bumper/side-pod/spoiler Performance page, buy one upgrade point, and confirm the physical instance retains it after changing menus and rejoining.

Return the complete Studio Output and note any visual or numeric mismatch. Do not run a second repair script against a failed anchor; refresh the mirror first.
