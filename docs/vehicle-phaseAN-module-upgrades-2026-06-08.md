# Vehicle Phase AN Module Upgrades

Status: installed and confirmed working on 2026-06-08.

Confirmed:

- Read-only profile rating: `D 407`.
- Fuel Injection level 1 price: `$4000`.
- Purchase success: `true`.
- Module level changed from `0` to `1`.
- Profile rating changed from `D 407` to `D 410`.
- Spawned engine received `AppliedUpgrade_FuelInjection = 1`.
- Spawned engine deltas: EngineOutput `+2`, TopSpeed `+1`.
- Spawned runtime rating: `D 410`.
- Spawned-effect audit warnings: `0`.

## Purpose

Phase AN replaces the old vehicle-wide upgrade data model with upgrades owned by a specific module.

Examples:

```text
Bruiser 01 Standard Front Engine
  Fuel Injection: Level 2
  Lightweight Internals: Level 1

Bruiser 02 Power Front Engine
  Fuel Injection: Level 0
```

An upgraded module keeps its levels when moved between compatible Bruiser cockpits or slots. Another module has separate progression.

## Scope

Phase AN adds:

- `ModuleUpgradeLevels[moduleId][upgradeId]` profile storage.
- Server-authoritative upgrade validation and pricing.
- The `UpgradeModule` garage action.
- Upgrade definitions on each module’s catalogue response.
- Complete Phase AM performance results in the profile response.
- Purchased effects on spawned module clones before Phase AM calculation.

Phase AN deliberately does not replace the visible customisation UI. The old Brakes, Converter, Fuel System, and generic Upgrade controls remain until Phase AO.

## Fragile Patch Warning

The installer uses guarded source replacement against the refreshed Phase AM garage controller:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
```

It preflights all required matches before changing source. Do not bypass an exact-match failure. Refresh the Studio mirror and update the installer against the new source instead.

## Install

Run while not play-testing:

```text
scripts/roblox_vehicle_phaseAN_module_upgrades.lua
```

Then run:

```text
scripts/roblox_vehicle_phaseAN_module_upgrades_audit.lua
```

Expected:

- Planned upgrades: `23`.
- Active modules: `72`.
- Active modules without definitions: `0`.
- Purchase definitions enabled: `true`.
- Warnings: `0`.

### Studio Multi-Write Repair

Studio may retain only the final `Script.Source` assignment when several garage edits occur in one Command Bar execution. If the audit reports the helper, catalogue hook, or clone-effect hook missing after the surgical repair, run these as three separate Command Bar actions in this order:

```text
scripts/roblox_vehicle_phaseAN_helper_finalize.lua
scripts/roblox_vehicle_phaseAN_catalogue_hook_repair.lua
scripts/roblox_vehicle_phaseAN_clone_effect_hook_repair.lua
```

Then rerun the audit as a fourth separate action.

If a purchase fails with `attempt to index nil with 'Find'` and the smoke-test rating is `nil nil`, run these separately:

```text
scripts/roblox_vehicle_phaseAN_purchase_action_nil_repair.lua
scripts/roblox_vehicle_phaseAN_helper_performance_repair.lua
scripts/roblox_vehicle_phaseAN_profile_performance_hook_repair.lua
```

The first removes a stale partial branch from the superseded large installer. The latter two restore the complete Phase AM profile performance response required by Phase AO.

## Read-Only Play Test

Start Play, open the dealership once, and run from the client Command Bar:

```text
scripts/roblox_vehicle_phaseAN_purchase_smoke_test.lua
```

Its default:

```text
PURCHASE_ONE_LEVEL = false
```

The output should show:

- Installed slot and module.
- First module-specific upgrade.
- Current level and maximum level.
- Next price.
- Current tier and performance index.

## Purchase Test

After the read-only output passes:

1. Stop Play.
2. Set `PURCHASE_ONE_LEVEL = true`.
3. Start a fresh Play session.
4. Open the dealership.
5. Run the smoke test from the client Command Bar.

Expected:

- Purchase success `true`.
- Upgrade level increases by exactly one.
- Cash decreases by the calculated next-level price.
- Updated performance result is returned.
- Spawning the vehicle writes the purchased effect into its raw/headline/rating data.

## Spawned Effect Audit

During the same Play session as the purchase:

1. Finish customisation and spawn the drivable vehicle.
2. Run from the client Command Bar:

```text
scripts/roblox_vehicle_phaseAN_spawned_upgrade_audit.lua
```

Expected:

- Fuel Injection level: `1`.
- EngineOutput delta includes at least `+2`.
- TopSpeed delta includes at least `+1`.
- Runtime tier/index are present.
- Warnings: `0`.

The current garage profile is session-memory only. Upgrade ownership therefore follows the same persistence lifetime as the existing cockpit/module/cash profile. Durable cross-session storage should be added through a future unified garage profile DataStore, not a Phase AN-only save path.

## Pricing

For next level `n`:

```text
price = BasePrice * PriceMultiplier ^ (n - 1)
```

With the current multiplier of `2`:

```text
Level 1: BasePrice
Level 2: BasePrice x 2
Level 3: BasePrice x 4
```

## Performance Effects

At spawn, each installed module clone receives:

```text
AppliedUpgrade_<UpgradeId>
PerformanceDelta_<RawVariable>
```

Phase AM then calculates the complete vehicle from cockpit, installed module base deltas, and purchased upgrade deltas.

## Phase AO Contract

Phase AO can read:

```text
Catalog.Categories[].Modules[moduleType][].Upgrades
Profile.ModuleUpgradeLevels
Profile.Performance
```

It should call:

```text
GarageInvoke:InvokeServer("UpgradeModule", {
    SlotId = slotId,
    ModuleId = moduleId,
    UpgradeId = upgradeId,
})
```

Phase AO will remove:

- The generic module `UPGRADE (LVL 1)` control.
- Brakes.
- Converter.
- Fuel System.
- The old vehicle-wide `Upgrade` action from visible use.

## Rollback

Use Roblox version history from immediately before Phase AN to fully revert the garage source.

Leaving `ModuleUpgradeLevels` in a profile is harmless if the server action/effect code is rolled back. Do not delete the Phase AM runtime service or performance modules.

## Mirror Refresh

After Phase AN Studio testing:

1. Run `py scripts/receive_studio_full_snapshot_export.py`.
2. Run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in Studio.
3. Commit `roblox/exported_scripts/` and `roblox/studio_snapshot/`.
4. Do not commit `docs/studio-full-export-paste.txt`.
