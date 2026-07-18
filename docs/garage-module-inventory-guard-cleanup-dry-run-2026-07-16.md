# Garage Module Inventory Guard And Cleanup Dry Run

Status: guard installation and the locked cleanup dry run passed, but the live migration workflow was retired after repeated ProfileService session replacement. The approved testing workflow is now a targeted offline main-profile reset.

## Files

- `scripts/roblox_ui_garage_module_inventory_guard_install.lua`
- `scripts/roblox_ui_garage_module_inventory_cleanup_dry_run.lua`
- `scripts/roblox_ui_garage_module_inventory_cleanup_apply.lua`
- `scripts/roblox_ui_garage_module_inventory_cleanup_bridge_install.lua`
- `scripts/roblox_player_main_profile_reset_edit_mode.lua`

## Scope

The Edit-mode installer stops new instance inflation before any saved-profile cleanup. It:

- Installs isolated `GarageModuleInventoryRuntime` ownership.
- Replaces the legacy instance-creating ensure function with shape-only validation.
- Removes four normal-flow legacy-to-instance sync calls.
- Removes the default grant/attach block from the start of every garage request.
- Keeps explicit cockpit purchase/default attachment behavior.
- Adds acquisition metadata to newly purchased and cockpit-included module instances.

It does not delete, alter, mark dirty or save a player profile.

The second script runs in a fresh Play session from the Server Command Bar. It classifies cleanup candidates but remains read-only:

- Referenced instances are protected regardless of source.
- Every `BuyModuleInstance` is protected even when unreferenced.
- Only unreferenced `LegacyInstalledModules` records that still claim an equipped vehicle are automatic deletion candidates.
- Available legacy copies, unreferenced cockpit grants, invalid records and unknown sources require manual review.

## Required sequence

1. Stop Play and run the guard installer in Edit mode.
2. Require `[NTR Garage Module Guard] INSTALL PASS`.
3. Start a completely fresh Play session.
4. Run the cleanup dry-run script from the Server Command Bar.
5. Return the full `[NTR Garage Module Cleanup Dry Run]` output to Codex.

## Reviewed dry-run result

- Total module instances: `1428`
- Exact automatic deletion candidates: `1358`
- Protected live instances: `50`
- Legitimate displaced cockpit grants retained as available inventory: `20`
- Missing installed references: `0`

The deletion set contains only unreferenced `LegacyInstalledModules` records that still falsely claim an equipped vehicle. The 20 `IncludedWithCockpit` review records are not deleted.

## Apply and persistence verification

1. Keep the guard installed, stop Play, and run `scripts/roblox_ui_garage_module_inventory_cleanup_bridge_install.lua` once in Edit mode.
2. Require `[NTR Garage Module Cleanup Bridge] INSTALL PASS`.
3. Start a completely fresh Play session.
4. Run `scripts/roblox_ui_garage_module_inventory_cleanup_apply.lua` from the Server Command Bar.
5. The script must print seven `[NTR Garage Module Cleanup Apply] PASS` lines. It refuses to run if DataStore persistence is disabled, the target user is absent, either profile owner changed after the reviewed dry run, the cleanup import lock is unavailable, or any ownership invariant fails.
6. Stop Play and start another fresh Play session.
7. Rerun `scripts/roblox_ui_garage_module_inventory_cleanup_dry_run.lua`.
8. Persistence is confirmed when the fresh result reports `total=70`, `delete=0`, `protect=50`, `review=20`, and `missingRefs=0`.

The apply script keeps an in-memory copy of the original inventory and restores/saves it if validation or persistence fails. It does not create an in-game backup object.

The first apply attempt correctly rolled back after finding a protected purchased lightweight engine with a stale `EquippedVehicleId` but no live slot reference. The apply script now treats the slot-reference index as authoritative for every preserved instance: referenced modules receive the referenced vehicle ID, while unreferenced purchases and cockpit grants are retained as available inventory with no equipped vehicle ID.

The second apply attempt passed mutation validation and `SaveNow`, then correctly rolled back because its final confirmation required the whole live profile session to remain `Dirty=false`. That requirement was too broad: another active profile bridge can mark the session dirty again while the DataStore request yields. The final gate now verifies the direct live inventory count, cleanup migration marker, enabled DataStore state and successful `SaveNow` result. It logs the summary count and dirty state for diagnosis but does not interpret unrelated subsequent dirty work as a cleanup failure.

The third apply attempt proved that the live inventory was replaced from 70 back to exactly 1428 while `SaveNow` yielded. Root cause: `GarageActionController` still owns a separate legacy compatibility profile and its normal `ImportProfileSnapshot` mirror can replace the canonical ProfileService table. The dual-owner bridge installer adds a tiny BindableFunction to that controller and keeps the cleanup implementation in `GarageModuleInventoryRuntime`. The apply script now requires both owners to enter the same transaction, rolls both back on failure, and commits both only after the canonical save and direct 70-instance verification pass.

The fourth apply attempt showed that cleaning both known owners was necessary but not sufficient: while `SaveNow` yielded, another asynchronous full-profile import again replaced the canonical 70-instance table with the exact 1428-instance snapshot. The bridge installer now adds a narrowly scoped cleanup transaction to `ProfileService_Active`. During the cleanup and its DataStore commit, `ImportProfileSnapshot` rejects all external full-profile replacements and records their count and last reason. The lock is released after either the saved cleanup commits or the original inventory is restored and saved. Normal profile imports are unchanged outside this one-time transaction.

The fifth apply attempt still changed the live session from 70 back to 1428 without passing through `ImportProfileSnapshot`. The refreshed mirror identified the direct writer: `ProfileService_Active.loadProfile` assigns `sessions[player.UserId]` after a yielding DataStore read, and startup can invoke that loader from both `PlayerAdded` and the existing-player loop before either call has registered a session. The later read can therefore replace a fully active session directly. `scripts/roblox_profile_service_single_flight_load_guard_install.lua` adds an idempotent per-user in-flight gate and reuses an existing session, making player profile loading single-owner. The cleanup apply verification now also requires the live profile table identity to remain unchanged across `SaveNow`.

The sixth apply attempt reported `sameProfile=false`, proving a pending load completion still crossed the transaction despite the entry guard. `scripts/roblox_profile_service_session_ownership_hardening_install.lua` therefore protects the actual ownership boundary: a load completion discards its result whenever a session is already active, and the cleanup transaction pins its exact session until commit or rollback. The transaction reports whether the raw session map was replaced while pinned and restores the pinned owner before releasing the lock.

## Approved replacement workflow

The user approved discarding the corrupt testing profile instead of continuing the migration loop. `scripts/roblox_ui_garage_module_inventory_cleanup_apply.lua` is now retired and stops immediately if run.

1. Stop Play completely.
2. Run `scripts/roblox_player_main_profile_reset_edit_mode.lua` from Studio's Edit-mode Command Bar.
3. Require its `PASS main profile permanently removed and read-back returned nil` result.
4. Start a fresh Play session and confirm an empty default garage.
5. Buy one cockpit and confirm one vehicle, one cockpit instance, and four included module instances.
6. Reopen the garage menus and rejoin once; counts must remain stable before more module UI work continues.

The reset targets only `player_7915427645` in the configured main profile DataStore. It does not touch dealership intro progress, personal bests, or global leaderboard entries. It refuses to run while Play is active and refuses to delete if the inventory-creation guard markers are absent.

Studio can expose a local `Player` object in Edit mode, so `Players:GetPlayers()` is not a reliable offline-session gate. The reset uses `RunService:IsRunning()` as the authoritative Play/Run check and logs any Edit-mode Player objects without treating them as active server sessions.

The targeted reset was user-confirmed on 2026-07-16. The first fresh session loaded without server errors; the dealership browser, preview pad, canonical Paint Cockpit and canonical Build Modules pages all passed their runtime ownership/geometry checks. `scripts/roblox_player_fresh_profile_baseline_audit.lua` then passed after one cockpit purchase and one complete rejoin: cash `125000`, one vehicle, one cockpit instance, four installed references, four `IncludedWithCockpit` module instances, zero purchased instances, zero legacy records, zero garage properties, zero missing/multiple references and zero stale equipped claims. This is the new canonical module-inventory baseline.

The next recommended gate is a controlled one-copy lifecycle test: purchase exactly one module, rejoin and verify the total increases from four to five without any legacy records; then equip that same instance and verify the total remains five, installed references remain four, the displaced included module becomes available, and no instance is cloned or multiply referenced. UI card/equip-flow work should start only after this contract passes.

`scripts/roblox_player_module_instance_lifecycle_audit.lua` implements that gate as one read-only, auto-detecting audit. Its valid stages are `BASELINE`, `PURCHASED_AVAILABLE`, and `PURCHASED_EQUIPPED`. Run it after each complete rejoin; the final stage permits the shared module-instance view model/card work to begin.

The lifecycle audit passed `PURCHASED_EQUIPPED` on 2026-07-16 after the current Buy flow automatically equipped the new copy: cash `1095200`, one vehicle, one cockpit, five total module instances, four installed references, four preserved `IncludedWithCockpit` instances, one `BuyModuleInstance`, one displaced included module available and zero legacy records. The inventory contract is confirmed. Automatic equip is current UI/action behavior to replace with the approved separate Buy then Equip flow; it is not an inventory duplication failure. Unreferenced `IncludedWithCockpit` instances are legitimate available inventory after a swap and must not be presented as corrupt/review-only records by the new view model.
