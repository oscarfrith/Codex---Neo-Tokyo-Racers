# Garage performance and module-rating alignment audit

Date: 2026-07-17

Status: Studio audit completed. Canonical stock/rating logic passed; accessory V2 materialisation is the one implementation prerequisite.

## Studio result

The Edit-mode run completed with `PASS=27 WARN=13 FAIL=1`. The important findings are:

- all six stock builds reproduce their intended E200, D375, C525, B662, A787 and S925 targets within rounding tolerance;
- the current dealership fallback understates those builds by 102 to 276 PI and can be removed from the active garage once the shared resolver is installed;
- spawned driving already consumes the complete V2 raw contract;
- the fixed-reference module ladders are monotonic after correcting the audit's front/rear engine identifier test;
- a saved V2 upgrade point increased the sampled module rating from 529 to 530;
- the catalogue contains 84 active modules: 72 materialised core modules plus 12 active Level 1-3 Front Bumper, Rear Bumper, Side Pods and Rear Spoiler modules;
- those 12 accessories still use legacy seven-stat values and must be translated into explicit V2 raw attributes before the active fallback can be retired.

The first audit classified every core engine as rear-mounted because the plain `ENGINE_B` substring also matches `ENGINE_BRUISER`. The canonical audit now checks explicit engine metadata and the unambiguous `MODULE_ENGINE_B_` prefix. This was an audit-only defect; no live asset or slot identity is duplicated.

## Why this audit exists

The live V2 performance switches are enabled and spawned/owned vehicles generally use the materialised 17-variable V2 component calculation. The canonical dealership still has a separate factory-preview fallback that totals only seven legacy fields and calls `CalculateLegacy`. This can make an unowned factory vehicle show different headline stats, PI and tier from the same build after purchase.

Module cards already accept an optional numeric rating, but no canonical rating is currently calculated. Saving a second manually-authored rating on every module would become stale when raw balance or instance upgrades change.

## Approved direction

- Preserve the confirmed driving mechanics and their V2 raw input contract.
- Replace active garage compatibility calculations once the audit proves all active assets are V2 materialised.
- Calculate factory, owned, selected-module preview and spawned-vehicle performance from one shared resolver.
- Derive module ratings rather than persist them. A module is evaluated by replacing its slot in a fixed Viper stock reference build; a physical owned copy includes its saved `V2UpgradePoints`. The displayed module rating has no tier.
- Keep E200, D375, C525, B662, A787 and S925 as the calibrated stock targets unless the audit proves that the live materialised assets no longer reproduce them.

## Audit script

Run `scripts/roblox_vehicle_module_rating_menu_alignment_audit.lua` once from the Studio Command Bar in Edit mode.

The script is read-only. It requires the existing pure performance modules, reads assets/config/source, calculates temporary Lua tables, and prints:

- canonical and current dealership-fallback PI/tier for all six stock vehicles;
- six headline stats and the complete raw driving contract per stock vehicle;
- target and menu divergence;
- twelve fixed-reference module ladders covering four core slots and three variants;
- an upgrade-aware module-rating sample;
- active non-V2 asset blockers;
- remaining source dependencies on the compatibility calculator.

It creates, edits, clones, reparents, destroys, saves and purchases nothing.

## Next gate

Generate one guarded installer that:

1. materialises the 12 active accessory modules into the V2 raw contract while preserving their models, prices, ownership IDs and catalogue visibility;
2. adds one isolated shared performance resolver for stock, owned and selected-instance builds;
3. moves the active garage controller and read-only preview adapter to that resolver;
4. publishes derived, upgrade-aware module ratings through the existing shared card view model;
5. leaves the confirmed spawned-vehicle runtime adapter in place until menu/spawn parity is verified;
6. does not add anything to the register-limited legacy bootstrap.
