# Vehicle Performance V2 — Phase 8 Atomic Live Launch

Date: 2026-07-13

Status: generated; awaiting Studio Edit and fresh-Play verification.

## Confirmed incoming baseline

The user confirmed the corrected Phase 7 installer and Play shadow test work well. Phase 7 is therefore the stable incoming baseline: V2 calculation, compatibility view, six-point allocation, migration preview, purchase preview, and spawned shadow attributes work while V1 remains authoritative.

The locally received repo mirror still reports `2026-07-13 21:51:45` and does not contain the Phase 6/7 ServerStorage/runtime hierarchy. Phase 8 therefore hard-preflights the live Studio hierarchy and source markers before mutation. Refresh the mirror after the Phase 8 test.

## Scope

Phase 8 is the final planned implementation stage. It is one installer and is not divided into sub-phases. It:

- canonically replaces only the isolated V1 calculator, performance runtime, and module-upgrade runtime with switch-aware compatibility owners;
- makes one guarded exact-source change to the garage module catalogue so V2 paths can be described from their actual module template;
- publishes six Viper-based cockpits and 72 core modules from the validated staging catalogue;
- preserves all unrelated cosmetic module families;
- enables V2 rating, raw driving data, six-point module-instance upgrades, profile migration, and catalogue publication only after validation;
- converts legacy upgrade levels lazily on the live profile, preserves the original levels, and applies overflow refund credit once;
- keeps rollback in the same script through `MODE = "ROLLBACK_SWITCHES"`.

No in-game backup folders or scripts are created. Switch rollback preserves the published catalogue and all legacy/V2 profile fields. A full asset rollback must use Roblox version history.

## Fragile source replacement

The installer contains one fragile exact-source replacement in `GarageActionController_Shadow_Disabled`: it changes `CatalogForModuleType(moduleType)` to `CatalogForModuleType(moduleType, item)`. The installer requires exactly one known old anchor or exactly one already-installed marker before it mutates anything. If the live source differs, it stops and requests a refreshed mirror rather than guessing.

## Studio script

Run in Edit mode:

`scripts/roblox_vehicle_performance_v2_phase8_atomic_live_launch.lua`

Leave `MODE = "PUBLISH"` for installation.

## Verification

After a clean Edit result, stop and restart Play so ModuleScript caches are fresh.

1. Confirm Edit output ends with `FAIL=0` and `LIVE RELEASE CANDIDATE INSTALLED`.
2. Confirm six `LIVE STOCK` lines show Forge E, Vector D, Viper C, Nightline B, Rally A, and Zenith S.
3. Open dealership and confirm exactly six balanced cockpit entries appear with the intended prices.
4. Purchase/select a test cockpit and confirm its included Standard front engine, rear engine, stabilisers, and boost are granted.
5. Equip a higher-tier Lightweight or Power module onto a lower-tier cockpit and confirm the displayed PI rises automatically.
6. Confirm Standard modules show no upgrade cards; Lightweight/Power show three paths and stop at six total points/three per path.
7. Buy at least one point, confirm cash is deducted, PI/raw stats change, and a spawned vehicle receives `PerformanceRuntimeVersion = V2_PHASE8_LIVE`.
8. Drive and verify acceleration, braking, one-second reverse, handling, drift momentum, top speed, and boost remain stable while vehicle differences are noticeable.
9. Start a time trial/race and confirm its tier/index match the spawned V2 vehicle.
10. Save/rejoin and confirm the owned cockpit, equipped module instance, V2 point allocation, cash, and rating persist without a second migration refund.

The existing Phase AO upgrade cards calculate their visible card price from a legacy static base-price contract. The server remains authoritative and reports the exact charged V2 point cost in the purchase result. Treat a card-price mismatch after mixed-path spending as a verification issue to report; do not add another phase or patch without agreeing the scope.

## Rollback

For a rating/physics/upgrade/profile regression:

1. Stop Play.
2. Change the same script's first setting to `MODE = "ROLLBACK_SWITCHES"`.
3. Run the same script in Edit mode.
4. Restart Play and confirm V1 ownership is restored.

This does not erase V2 allocations, legacy levels, or the published Viper-based catalogue. Use Roblox version history only if the asset publication itself must be reverted.

