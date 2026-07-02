# Persistence And Garage Profile Plan

**Created:** 2026-06-30  
**Current phase:** Phase 28 final garage MVP audit confirmed; garage MVP stack complete pending mirror refresh/save-rejoin handoff
**Installer:** `scripts/roblox_persistence_phase1_profile_schema.lua`  
**Audit:** `scripts/roblox_persistence_phase1_profile_schema_audit.lua`
**Phase 2 installer:** `scripts/roblox_persistence_phase2_profile_service.lua`  
**Phase 2 audit:** `scripts/roblox_persistence_phase2_profile_service_audit.lua`
**Phase 3 installer:** `scripts/roblox_persistence_phase3_legacy_profile_bridge.lua`  
**Phase 3 audit:** `scripts/roblox_persistence_phase3_legacy_profile_bridge_audit.lua`
**Phase 4 installer:** `scripts/roblox_persistence_phase4_garage_session_mirror.lua`  
**Phase 4 server audit:** `scripts/roblox_persistence_phase4_garage_session_mirror_server_audit.lua`  
**Phase 4 client smoke:** `scripts/roblox_persistence_phase4_garage_session_mirror_client_smoke.lua`
**Phase 5 enable:** `scripts/roblox_persistence_phase5_enable_datastore_mirror_saves.lua`  
**Phase 5 disable:** `scripts/roblox_persistence_phase5_disable_datastore_mirror_saves.lua`  
**Phase 5 import repair:** `scripts/roblox_persistence_phase5_import_snapshot_binding_repair.lua`  
**Phase 5 import audit:** `scripts/roblox_persistence_phase5_import_snapshot_binding_audit.lua`  
**Phase 5 save audit:** `scripts/roblox_persistence_phase5_datastore_save_audit.lua`  
**Phase 5 load audit:** `scripts/roblox_persistence_phase5_datastore_load_audit.lua`
**Phase 6 installer:** `scripts/roblox_persistence_phase6_garage_capacity_gate.lua`  
**Phase 6 audit:** `scripts/roblox_persistence_phase6_garage_capacity_gate_audit.lua`
**Phase 7 installer:** `scripts/roblox_persistence_phase7_garage_capacity_upgrade.lua`  
**Phase 7 server audit:** `scripts/roblox_persistence_phase7_garage_capacity_upgrade_audit.lua`  
**Phase 7 client smoke:** `scripts/roblox_persistence_phase7_garage_capacity_upgrade_client_smoke.lua`
**Phase 8 installer:** `scripts/roblox_persistence_phase8_garage_capacity_upgrade_ui.lua`  
**Phase 8 source audit:** `scripts/roblox_persistence_phase8_garage_capacity_ui_source_audit.lua`  
**Phase 8 client smoke:** `scripts/roblox_persistence_phase8_garage_capacity_ui_client_smoke.lua`
**Phase 9 installer:** `scripts/roblox_persistence_phase9_garage_property_menu.lua`  
**Phase 9 source audit:** `scripts/roblox_persistence_phase9_garage_property_menu_audit.lua`  
**Phase 9 client smoke:** `scripts/roblox_persistence_phase9_garage_property_menu_client_smoke.lua`
**Phase 9 register repair:** `scripts/roblox_persistence_phase9_register_limit_repair.lua`  
**Phase 10 layout/modal installer:** `scripts/roblox_persistence_phase10_garage_ui_layout_modal.lua`  
**Phase 10 layout/modal audit:** `scripts/roblox_persistence_phase10_garage_ui_layout_modal_audit.lua`  
**Phase 10 layout/modal client smoke:** `scripts/roblox_persistence_phase10_garage_ui_layout_modal_client_smoke.lua`
**Phase 11 cockpit-only visibility installer:** `scripts/roblox_persistence_phase11_garage_spaces_cockpit_only.lua`  
**Phase 11 cockpit-only visibility audit:** `scripts/roblox_persistence_phase11_garage_spaces_cockpit_only_audit.lua`  
**Phase 11 cockpit-only visibility client smoke:** `scripts/roblox_persistence_phase11_garage_spaces_cockpit_only_client_smoke.lua`
**Phase 12 menu controller extraction installer:** `scripts/roblox_persistence_phase12_garage_property_menu_controller_extract.lua`  
**Phase 12 menu controller extraction audit:** `scripts/roblox_persistence_phase12_garage_property_menu_controller_audit.lua`  
**Phase 12 menu controller extraction client smoke:** `scripts/roblox_persistence_phase12_garage_property_menu_controller_client_smoke.lua`
**Phase 13 merged garage property ownership installer:** `scripts/roblox_persistence_phase13_garage_property_ownership.lua`  
**Phase 13 partial-install repair:** `scripts/roblox_persistence_phase13_garage_property_ownership_repair.lua`  
**Phase 13 merged garage property ownership client smoke:** `scripts/roblox_persistence_phase13_garage_property_ownership_client_smoke.lua`
**Phase 14 instance inventory bridge installer:** `scripts/roblox_persistence_phase14_instance_inventory_bridge.lua`  
**Phase 14 instance inventory bridge client smoke:** `scripts/roblox_persistence_phase14_instance_inventory_client_smoke.lua`
**Phase 15 duplicate-copy UI installer:** `scripts/roblox_persistence_phase15_duplicate_copy_ui.lua`  
**Phase 15 duplicate-copy UI client smoke:** `scripts/roblox_persistence_phase15_duplicate_copy_ui_client_smoke.lua`
**Phase 16 module family locks/sorting installer:** `scripts/roblox_persistence_phase16_module_family_locks_and_sorting.lua`  
**Phase 16 module family locks/sorting client smoke:** `scripts/roblox_persistence_phase16_module_family_locks_and_sorting_client_smoke.lua`
**Phase 17 owned/buy module tabs installer:** `scripts/roblox_persistence_phase17_module_owned_buy_tabs.lua`  
**Phase 17 owned/buy module tabs client smoke:** `scripts/roblox_persistence_phase17_module_owned_buy_tabs_client_smoke.lua`
**Phase 18 ProfileService source handoff installer/smoke:** `scripts/roblox_persistence_phase18_profile_source_handoff.lua`
**Phase 19 instance compatibility sync installer/smoke:** `scripts/roblox_persistence_phase19_instance_compat_sync.lua`
**Phase 20 garage profile runtime extraction installer/smoke:** `scripts/roblox_persistence_phase20_garage_profile_runtime_extract.lua`
**Phase 21 private garage interior MVP installer/smoke:** `scripts/roblox_persistence_phase21_private_garage_interior_mvp.lua`
**Phase 22 garage display vehicle MVP installer/smoke:** `scripts/roblox_persistence_phase22_garage_display_vehicle_mvp.lua`
**Phase 23 same-server garage visits installer/smoke:** `scripts/roblox_persistence_phase23_same_server_garage_visits.lua`

## Goal

Create the long-term data foundation for:

- persistent player cash, owned cars, owned modules, upgrades, colours, and garage customisation;
- multiple owned copies of the same cockpit or module template;
- two starting garage vehicle spaces as a progression gate;
- same-server visitable apartment-block garage interiors;
- future garage materials, decorations, privacy, invites, and expansion.

## Phase 1 Scope

Phase 1 only installs data schema/config:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.PlayerProfileSchema
ReplicatedStorage.NeoTokyoRacers.Shared.Config.Persistence_EditAttributes
```

It does not:

- change active garage actions;
- write DataStores;
- alter dealership UI;
- alter vehicle spawning/driving;
- create garage interiors;
- create in-game backup folders.

Phase 1 was installed in Studio and its audit passed on 2026-06-30.

## Phase 2 Scope

Phase 2 prepares a ProfileService owner:

```text
ServerScriptService.NeoTokyoRacers.Services.Player.ProfileService_Active
ServerScriptService.NeoTokyoRacers.Services.Player.ProfileServiceBindings
ServerScriptService.NeoTokyoRacers.State.RuntimeProfiles
```

It exposes server-only BindableFunctions:

- `GetProfile`
- `GetSummary`
- `MarkDirty`
- `SaveNow`
- `IsLoaded`

`DataStoreEnabled` defaults to `false` in:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Config.Persistence_EditAttributes
```

That means Phase 2 can load/normalise session profiles and test dirty/save plumbing without writing persistent data until DataStore testing is deliberately enabled.

Phase 2 was installed in Studio and its server audit passed on 2026-06-30.

## Phase 3 Scope

Phase 3 prepares the conversion bridge from the current V56 session-memory garage profile shape into the new instance-based profile schema:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.LegacyGarageProfileMapper
ServerScriptService.NeoTokyoRacers.Services.Player.LegacyGarageProfileBridge_Active
ServerScriptService.NeoTokyoRacers.Services.Player.LegacyGarageProfileBridgeBindings
```

It does not patch the active `GarageActionController_Shadow_Disabled` yet. This is deliberate: the legacy profile mapper can be audited first, then a later guarded source patch can call it after the conversion behavior is known-good.

Legacy boolean ownership cannot represent duplicate purchased copies. Phase 3 maps:

- each legacy owned cockpit to one cockpit instance and one vehicle instance;
- each installed legacy module to an equipped module instance;
- each remaining owned module template to one unequipped module instance;
- cockpit colours, module colours, neon ownership, thrust colour, and module upgrade levels where the current profile shape contains enough information.

Phase 3 was installed in Studio and its server audit passed on 2026-06-30.

## Phase 4 Scope

Phase 4 is the first guarded live garage bridge. It patches:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
```

The patch mirrors the current V56 session-memory profile into `ProfileService_Active` after:

- `GetInitial`;
- successful mutating garage actions such as cockpit purchase, module purchase/equip, colour changes, neon purchase, and upgrades.

The current V56 profile remains the live source of truth. Dealership UI responses, vehicle spawning, driving, VFX, and purchases still use the existing controller behavior. ProfileService receives converted snapshots only.

This phase uses fragile exact source replacement. If the live garage controller source shape has changed since the current mirror, the installer should abort and a fresh Studio mirror should be captured before another patch is written.

Phase 4 was installed in Studio and all audits passed on 2026-06-30.

## Phase 5 Scope

Phase 5 is the first opt-in real DataStore write test for mirrored ProfileService snapshots.

It toggles:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Config.Persistence_EditAttributes.DataStoreEnabled
```

When enabled, `ProfileService_Active` can write the converted mirrored profile to:

```text
NTR_PlayerProfiles_v1
```

This is still not the live garage source of truth. Current dealership/garage UI and vehicle spawning still use the V56 session-memory profile. Phase 5 only proves the mirrored instance-based profile can save and load through DataStore.

Studio testing needs API services enabled:

```text
Game Settings > Security > Enable Studio Access to API Services
```

Use the disable script to return to dry-run/session-only saves after testing.

If the save audit reports zero mirrored vehicles after the Phase 4 client smoke, run the Phase 5 import repair. The original Phase 4 mirror mutated a profile table returned through `GetProfile`; if that table is copied across the BindableFunction boundary, ProfileService's internal session profile does not change. The repair adds `ImportProfileSnapshot` so ProfileService owns the session profile replacement directly.

Phase 5 was installed/tested in Studio and passed on 2026-06-30 after the import snapshot repair and DataStore/API setup.

## Phase 6 Scope

Phase 6 starts enforcing the first garage progression rule in live gameplay:

```text
StartingGarageCapacity = 2
```

It patches the current `BuyCockpit` path in:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
```

Buying/selecting an already-owned cockpit still works. Buying a new cockpit is blocked when the current V56 `OwnedCockpits` count reaches `Persistence_EditAttributes.StartingGarageCapacity`.

This does not yet introduce duplicate cockpit instances or duplicate module instances in the live UI. It is the capacity/progression gate on the current cockpit purchase model.

Phase 6 was installed in Studio and worked as expected on 2026-06-30.

## Phase 7 Scope

Phase 7 adds the first server-side garage capacity upgrade action:

```text
UpgradeGarageCapacity
```

It adds/editable config attributes under:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Config.Persistence_EditAttributes
```

Attributes:

- `GarageCapacityUpgradeBasePrice`, default `50000`;
- `GarageCapacityUpgradePriceMultiplier`, default `1.65`;
- `MaxGarageCapacity`, default `10`;
- `GarageCapacityUpgradeStep`, default `1`.

The active V56 session profile gains `GarageCapacity`, profile responses expose a `Garage` table with capacity/max/next price/owned count, and `LegacyGarageProfileMapper` mirrors the upgraded capacity into ProfileService snapshots.

This is still not the final garage UI. The Phase 7 client smoke directly invokes the server action and spends current-session cash.

Phase 7 was installed in Studio and worked as expected on 2026-06-30.

## Phase 8 Scope

Phase 8 adds the first visible garage capacity UI to the existing dealership/garage flow:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

It adds a compact `Garage Spaces` panel above the existing bottom-left cash panel. The panel shows current spaces used, current capacity, the next upgrade price, and an `Upgrade` button that calls the Phase 7 `UpgradeGarageCapacity` server action.

This is a guarded exact-source UI patch against the large active client bootstrap. If the live source has drifted, the installer should abort and the Studio mirror should be refreshed before another UI patch is written.

Phase 8 still uses the current V56 response shape for owned cockpit count. Duplicate cockpit/module instance ownership is a later source-of-truth migration phase.

Phase 8 was installed and worked functionally, but the separate capacity panel overlapped the left Categories panel. Phase 9 supersedes the visible Phase 8 panel layout and direction.

## Phase 9 Scope

Phase 9 changes the player-facing expansion model from abstract capacity upgrades to physical garage properties.

It installs:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.GaragePropertyCatalog
```

and patches:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

The visible changes:

- the compact `Garage Spaces` panel moves into the bottom safe area beside the cash panel so it should not overlap Categories;
- the old `Next: $price` line is hidden;
- the button says `Buy More`;
- clicking `Buy More` opens a garage-property gallery with picture/thumbnail cards;
- the first listed garage, `Kanda Lift Bay`, uses the existing Phase 7 `UpgradeGarageCapacity` action as a temporary backend;
- larger garage cards are shown as locked/coming soon until server ownership is moved to real garage property IDs.

This keeps gameplay moving while steering the UI toward the desired long-term design: apartment-block garage locations around the city are owned assets, and each owned property adds car spaces.

The first Phase 9 install caused the active client bootstrap to exceed Roblox's 200 local-register limit near `V75Driving`. The repair script keeps the Phase 9 UI behavior but moves the new helper functions onto one global phase table:

```text
scripts/roblox_persistence_phase9_register_limit_repair.lua
scripts/roblox_persistence_phase9_register_limit_repair_audit.lua
```

## Phase 10 Scope

Phase 10 is a UI-only follow-up to the repaired Phase 9 flow.

It patches the active client bootstrap so:

- `Garage Spaces` sits above `Available Cash` in the left column;
- `Categories` dynamically shrinks so it does not overlap `Garage Spaces`;
- the garage property menu opens as a true modal above a full-screen black backdrop with `BackgroundTransparency = 0.3`;
- clicking the `X` or the black backdrop closes the modal.

This still leaves the current property menu inside the large client bootstrap. The next recommended UI architecture step is to move garage-property menu rendering into a dedicated ModuleScript or existing UI controller path before adding richer cards, filters, or map previews.

## Phase 11 Scope

Phase 11 is a small UI visibility rule:

- `Garage Spaces` is shown only while `State.Stage == "CockpitShop"`;
- it hides during cockpit paint, module building, and customisation;
- if the garage property modal is open and the stage changes away from cockpit selection, the modal closes.

Phase 11 was installed in Studio and worked as expected on 2026-07-01.

## Phase 12 Scope

Phase 12 is an architecture cleanup before the garage UI gets richer.

It installs:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GaragePropertyMenuController
```

and replaces the large Phase 9 garage-property render block inside:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

with a small bridge that requires the controller and passes the existing UI helpers/context into it.

This keeps the player-facing behavior the same:

- `Buy More` still opens the dimmed modal gallery;
- garage cards still come from `GaragePropertyCatalog`;
- `Kanda Lift Bay` still uses the temporary Phase 7 `UpgradeGarageCapacity` backend until Phase 13 adds real `BuyGarageProperty` ownership;
- `Garage Spaces` still only appears during cockpit selection.

This phase uses guarded marker replacement rather than broad text replacement. If the expected Phase 9-11 markers are missing, stop and refresh the Studio mirror before writing another client UI patch.

Phase 12 was installed in Studio and worked as expected on 2026-07-01.

## Phase 13 Scope

Phase 13 deliberately merges the safe parts of the next garage-property steps so Studio command-bar work is less repetitive.

It patches/updates:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.GaragePropertyCatalog
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.PlayerProfileSchema
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.LegacyGarageProfileMapper
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GaragePropertyMenuController
```

Merged behavior:

- `GaragePropertyCatalog` now has real prices for the first apartment-block garage properties;
- current V56 session profiles gain `OwnedGarageProperties`;
- profile responses expose `Garage.OwnedGarageProperties` and `NextGaragePropertyPrice`;
- `BuyGarageProperty` validates property ID, availability, duplicate ownership, cash, and capacity;
- garage capacity is calculated from the starter two spaces plus owned garage-property spaces;
- old Phase 7 generic capacity gains are preserved by backfilling the first available properties as legacy-converted ownership;
- the extracted garage property menu calls `BuyGarageProperty` instead of the temporary `UpgradeGarageCapacity` backend;
- `LegacyGarageProfileMapper` mirrors owned garage properties into ProfileService snapshots.

This phase does not convert cockpit/module ownership into duplicate-capable instances yet. That remains separate because it changes the core vehicle/module source of truth and should have its own focused verification.

If the first Phase 13 installer stops at `Could not find source anchor for garage mirror mutating action`, use the Phase 13 repair script. The initial run may already have updated the catalogue/schema/mapper before stopping, so the repair script completes missing server/client pieces independently rather than assuming a clean starting state.

## Phase 14 Scope

Phase 14 merges the safe data/server parts of duplicate ownership without switching the visible dealership UI yet.

It patches/updates:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.LegacyGarageProfileMapper
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
```

Merged behavior:

- current V56 session profiles gain `Vehicles`, `CurrentVehicleId`, `OwnedCockpitInstances`, and `OwnedModuleInstances`;
- `GetInitial` still returns the legacy `OwnedCockpits`, `OwnedModules`, and `InstalledModules` fields for the existing UI;
- `GetInitial` also returns the new instance inventory fields for future UI work;
- `BuyCockpitInstance` can buy another copy of the same cockpit template and creates a separate vehicle/cockpit instance if capacity and cash allow;
- `BuyModuleInstance` can buy another copy of the same module template and starts it unequipped;
- `EquipModuleInstance` installs one specific module copy on one specific vehicle and rejects using that same copy on a different vehicle;
- the legacy mapper preserves live instance fields before mirroring to ProfileService, so duplicate instances are not collapsed back into boolean ownership.

This phase intentionally does not add the visible duplicate-copy UI yet. That should be a later UI phase after the server/data bridge is confirmed, because the client bootstrap is sensitive to register pressure and mobile layout overlap.

Phase 14 was installed and reported working well by the user on 2026-07-01.

## Phase 15 Scope

Phase 15 is the first visible duplicate-copy UI pass.

It patches:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

Merged behavior:

- owned cockpit cards still have the existing `Select` behavior;
- the selected owned cockpit panel shows an owned-copy count;
- owned cockpit panels also get `Buy Another $price`, which calls `BuyCockpitInstance`;
- module option cards show copy counts when instance data exists;
- selecting an owned but not-currently-installed module shows `Equip Copy` when a free copy exists;
- the same module popup also offers `Buy Copy $price`, which calls `BuyModuleInstance` and then equips the newly bought copy to the selected slot;
- unowned modules keep the existing first-time `Buy` flow.

This phase intentionally does not add a full vehicle-instance picker or module-copy picker yet. It is a narrow UI bridge so the player can start buying duplicate copies without a larger garage collection screen rewrite.

Phase 15 was installed and reported working well by the user on 2026-07-01.

## Phase 16 Scope

Phase 16 is a merged module-economy and module-option ordering pass before garage teleporting/interiors.

It patches:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

Merged behavior:

- module catalog responses expose `SourceCockpitId`, `SourceCockpitDisplayName`, `VariantName`, `VariantOrder`, and paid copy `Price`;
- buying module copies is server-locked until the player owns the source cockpit family;
- already-owned compatible module copies remain equippable across the Bruiser category;
- each bought cockpit instance receives one included Standard starter module set attached to that vehicle instance;
- extra Standard module copies cost money, using explicit module price attributes where present and a server fallback only as a safety net;
- Build Modules option cards sort owned/free copies first, unlocked purchasable modules next, and locked source-cockpit families last on the right.

This phase keeps the current broad Bruiser compatibility rule: source cockpit family controls buying, not where an already-owned compatible module can be equipped.

Phase 16 was installed and its scripts worked well, but the first UI pass still grouped owned module copies under one template card and did not split front/rear engines correctly.

## Phase 17 Scope

Phase 17 is a focused module picker repair on top of Phase 16.

It patches:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

Merged behavior:

- front engine slots show only front engines;
- rear engine slots show only rear engines;
- the server also rejects front/rear engine slot mismatches;
- selecting a module slot first shows two bottom buttons: `OWNED MODULES` and `BUY MODULES`;
- both buttons display `owned xN`;
- `OWNED MODULES` shows each owned module instance/copy as a separate card;
- owned module cards use a BUY-coloured `EQUIP` popup action;
- `BUY MODULES` shows buyable/locked module templates and uses a simple `BUY` action that buys a new instance and auto-equips it;
- `Buy Copy`, `Equip Copy`, and `No Free Copy` are removed from the current module picker;
- selecting any card, including locked buy-module cards, previews that template on the vehicle.

Phase 17 was installed and stabilised on 2026-07-02 after follow-up repairs for client parse recovery, engine metadata, colour picker stability, garage-server startup helpers, module-card layout, and the clipped-carousel popup. The final popup baseline keeps the carousel clipped, uses a selected-card `ModulePopupAnchor`, and applies a scale-aware absolute correction so BUY/LOCKED/EQUIP stays centred above the clicked card across screen sizes.

## Phase 18 Scope

Phase 18 is the source-of-truth handoff before building garage interiors.

It patches:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
```

and uses one dual-mode Studio script:

```text
scripts/roblox_persistence_phase18_profile_source_handoff.lua
```

Run it in Edit mode to install. After restarting Play, run the same file from the CLIENT Command Bar to smoke-check.

Merged behavior:

- on first garage profile access, the active garage session asks `ProfileService_Active` for the loaded saved profile;
- if the saved profile contains instance data such as `Vehicles`, `OwnedCockpitInstances`, `OwnedModuleInstances`, or owned garage properties, it hydrates the active V56-compatible session from that saved profile;
- if no saved instance profile exists, the current default legacy session path remains unchanged;
- saved instance fields are copied through to the live session so current UI paths still see `Vehicles`, `CurrentVehicleId`, `OwnedCockpitInstances`, and `OwnedModuleInstances`;
- legacy compatibility fields such as `OwnedCockpits`, `OwnedModules`, `InstalledModules`, module colours, neon flags, and garage capacity are rebuilt from the saved instance profile;
- mutating garage actions still mirror back into `ProfileService` through the existing Phase 4/5 import path.

This phase intentionally does not add garage interiors, visits, decoration ownership, or a new garage UI. The purpose is to stop treating saved persistence as a passive mirror before future systems depend on it.

Phase 18 was installed and smoke-tested on 2026-07-02. The client smoke reported `Hydrated=true`, `source=ProfileService`, `savedVehicles=1`, `CurrentVehicleId=vehicle_4b9422b7a5cb`, `vehicles=1`, and `moduleInstances=4`.

## Phase 19 Scope

Phase 19 consolidates legacy UI/customisation writes back into instance data before saving.

It patches:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
```

and uses one dual-mode Studio script:

```text
scripts/roblox_persistence_phase19_instance_compat_sync.lua
```

Run it in Edit mode to install. After restarting Play, run the same file from the CLIENT Command Bar to smoke-check.

Merged behavior:

- keeps Phase 18 hydration as the active baseline;
- before `GetInitial` mirrors to `ProfileService`, the current vehicle instance is synced from the active legacy compatibility fields;
- before successful mutating actions mirror to `ProfileService`, the same sync runs again;
- current vehicle `CockpitColors` and `ThrustColor` are updated from the active profile fields;
- installed legacy slot entries are matched to real owned module instances on the current vehicle;
- module instance `Colors`, `NeonOwned`, `UpgradeLevels`, and `EquippedVehicleId` are updated from the current UI/action fields;
- `OwnedCockpits` and `OwnedModules` compatibility tables are replenished from owned instance data so old UI paths keep working.

This phase does not remove the legacy fields yet. It makes them compatibility fields rather than the only place where edits live, which prepares the garage display/interior work to read from instance data safely.

Phase 19 was installed and smoke-tested on 2026-07-02. The client smoke reported `CurrentVehicleId=vehicle_4b9422b7a5cb`, `installedInstanceSlots=4`, `missingInstances=0`, `Phase19Synced=true`, and `syncCount=4`.

## Phase 20 Scope

Phase 20 is the first server-helper extraction before garage interiors.

It installs:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageProfileRuntime
```

and patches:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
```

with one dual-mode Studio script:

```text
scripts/roblox_persistence_phase20_garage_profile_runtime_extract.lua
```

Run it in Edit mode to install. After restarting Play, run the same file from the CLIENT Command Bar to smoke-check.

Merged behavior:

- moves the stable Phase 19 instance compatibility sync into a dedicated `GarageProfileRuntime` ModuleScript;
- keeps the big garage action controller behavior the same by replacing the inline sync helper with a small delegation wrapper;
- preserves Phase 19 smoke attributes and adds Phase 20 attributes so the client smoke can confirm `RuntimeModule=GarageProfileRuntime`;
- keeps the same current-vehicle/module-instance validation, expecting `missingInstances=0`.

This phase deliberately extracts only the proven profile sync helper. Purchases, UI, spawning, garage properties, and future interiors still run through the existing controller until later phases move them behind modules one piece at a time.

Phase 20 was installed and smoke-tested on 2026-07-02. The client smoke reported `CurrentVehicleId=vehicle_4b9422b7a5cb`, `installedInstanceSlots=4`, `missingInstances=0`, `RuntimeModule=GarageProfileRuntime`, and `syncCount=4`.

## Phase 21 Scope

Phase 21 is the first private garage interior MVP. It stays intentionally small and owner-only so the teleport/streaming shell can be proved before adding display vehicles, decorations, visits, or access modes.

It installs:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageInteriorService_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.GarageInteriorClient_Active
Workspace.NeoTokyoRacersWorld.Interiors.GarageInstances
Workspace.NeoTokyoRacersWorld.Interactives.GarageInteriorElevatorMVP
ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage.GarageInteriorInvoke
ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage.GarageInteriorTransition
```

with one dual-mode Studio script:

```text
scripts/roblox_persistence_phase21_private_garage_interior_mvp.lua
```

Merged behavior:

- creates/reuses one private runtime garage interior per owner under `GarageInstances`;
- adds a temporary dealership-adjacent elevator prompt that calls the new interior runtime without patching the main garage action controller;
- moves the character to a simple private garage room, asks the client helper to stream around the garage spawn, then fades back in;
- adds a return pad/prompt inside the garage and a remote `ReturnToCity` action;
- keeps visits, garage display cars, decorations, and public access modes deferred to later phases.

Phase 21 was installed and smoke-tested on 2026-07-02. The client smoke reported `EnterOwnGarage OK`, `State InGarage=true`, and `ReturnToCity OK`. It also reported `streamOk=false`; Phase 22 adds stream error diagnostics so this can be identified as a Studio/streaming availability issue or a real streaming call problem.

## Phase 22 Scope

Phase 22 adds the first lightweight garage display vehicle.

It installs:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageDisplayRuntime
```

and patches:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageInteriorService_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.GarageInteriorClient_Active
```

with one dual-mode Studio script:

```text
scripts/roblox_persistence_phase22_garage_display_vehicle_mvp.lua
```

Merged behavior:

- entering the private garage refreshes `DisplayVehicle_Runtime` inside the player's private interior;
- the display clone is built from the current saved cockpit and installed modules, then anchored and made non-drivable;
- scripts/seats are stripped from the display clone and all parts are non-colliding;
- cockpit/module colours are applied from saved profile compatibility fields;
- Phase 21 stream handling records `NTR_Phase21LastStreamError` when `RequestStreamAroundAsync` fails.

Phase 22 was installed and smoke-tested on 2026-07-02. The client smoke reported `Garage GetInitial OK before display smoke`, `displayOk=true`, `displayExists=true`, `displaySource=ProfileServiceCurrentVehicle`, and `ReturnToCity OK`.

## Phase 23 Scope

Phase 23 adds the first same-server garage access and visit shell.

It patches:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageInteriorService_Active
```

with one dual-mode Studio script:

```text
scripts/roblox_persistence_phase23_same_server_garage_visits.lua
```

Merged behavior:

- adds `SetAccessMode`, `InviteVisitor`, and `VisitGarage` actions to `GarageInteriorInvoke`;
- supports the initial `Private`, `FriendsOnly`, `InviteOnly`, and `Public` modes on the runtime interior model;
- keeps visits same-server only, by owner `UserId`;
- refreshes the owner's display vehicle before a visitor enters;
- records `NTR_Phase23VisitingGarageOwnerUserId` and `NTR_Phase23VisitAccessMode` on the visiting player for smoke/debug;
- keeps cross-server discovery, UI, persistent invite lists, and decorative ownership deferred.

## Profile Direction

Ownership should be instance-based, not boolean unlock-based.

Players can buy multiple copies of the same cockpit or module. Each copy has its own instance id, and a module copy can be equipped to only one vehicle at a time.

Example:

```lua
OwnedModuleInstances = {
	module_001 = {
		TemplateId = "MODULE_BOOST_BRUISER_01_STANDARD",
		EquippedVehicleId = "vehicle_001",
		UpgradeLevels = {},
		Colors = {},
		NeonOwned = false,
	},
	module_002 = {
		TemplateId = "MODULE_BOOST_BRUISER_01_STANDARD",
		EquippedVehicleId = nil,
		UpgradeLevels = {},
		Colors = {},
		NeonOwned = false,
	},
}
```

## Garage Capacity

Players start with:

```lua
Garage.Capacity = 2
```

Buying a cockpit creates a vehicle instance and consumes one garage space. A third cockpit purchase should be blocked until the player buys another garage property.

Long term, capacity should be calculated from owned garage properties, not from a generic upgrade counter:

```lua
OwnedGarageProperties = {
	property_001 = {
		TemplateId = "APT_BLOCK_A_SLOT_01",
		DisplayName = "Kanda Lift Bay",
		Spaces = 1,
		AccessMode = "Private",
		SurfaceMaterials = {},
		Decorations = {},
	},
}
```

The current Phase 7 `GarageCapacity` value remains a temporary bridge until a `BuyGarageProperty` server action and property ownership table replace it.

## Garage Visiting Direction

Apartment blocks are public entrance fiction. The actual garage rooms should be instanced interiors under a future root such as:

```text
Workspace.NeoTokyoRacersWorld.Interiors.GarageInstances
```

Multiple players can share the same city entrance, but each active owner receives a separate hidden garage instance. Visitors teleport to the owner's active instance if access rules allow it.

Initial access modes:

- `Private`
- `FriendsOnly`
- `InviteOnly`
- `Public`

## Streaming And LOD Direction

Garage teleport should use a loading/elevator transition:

1. Server assigns or reuses a garage instance.
2. Server loads garage surfaces, decorations, and display cars.
3. Character is moved to the garage spawn.
4. Client calls `Workspace:RequestStreamAroundAsync` near the garage spawn.
5. Client waits for required garage objects before fading in.

The custom LOD client should eventually use a simple mode:

```lua
WorldMode = "City" -- or "Garage"
```

Garage mode should pause city far-LOD work and use lightweight anchored display vehicles instead of full drivable vehicles.

## Next Phases

Recommended order:

1. Install and audit Phase 1 schema. Done on 2026-06-30.
2. Add ProfileService save/load foundation around the schema. Done on 2026-06-30.
3. Prepare legacy profile conversion bridge. Done on 2026-06-30.
4. Mirror current garage session profile into ProfileService after current garage actions. Done on 2026-06-30.
5. Opt into real DataStore saves for mirrored ProfileService snapshots. Done on 2026-06-30.
6. Add first two-space garage capacity gate to current cockpit purchases. Done on 2026-06-30.
7. Add server-side garage capacity upgrade action and mirrored capacity support. Done on 2026-06-30.
8. Add first visible garage capacity upgrade UI. Done on 2026-06-30, but superseded visually by Phase 9 because of left-panel overlap and the property-purchase direction.
9. Add garage property gallery UI and shared seed catalogue. Done on 2026-06-30 after register-limit repair.
10. Repair Phase 9 register pressure and left-column/modal layout. Done on 2026-07-01.
11. Hide Garage Spaces outside cockpit selection. Done on 2026-07-01.
12. Extract garage property menu rendering into a dedicated client ModuleScript/controller before expanding UI complexity. Done on 2026-07-01.
13. Add server-side `BuyGarageProperty` action, owned-property profile data, capacity calculated from owned properties, and the UI backend switch. Done on 2026-07-01.
14. Convert cockpit/module ownership to instances while preserving current UI response shape. Done on 2026-07-01.
15. Add visible duplicate-copy UI for cockpit/module instances. Done on 2026-07-01.
16. Add module source-cockpit purchase locks, paid extra Standard copies, included starter module instances, and owned-first module sorting. Done on 2026-07-01, with Phase 17 UI repairs prepared afterward.
17. Split the module picker into owned/buy tabs, per-instance owned module cards, front/rear engine slot filtering, and robust selected-card popup alignment. Done/stabilised on 2026-07-02.
18. Make `ProfileService_Active` hydrate the active garage session from saved instance data on first use, while retaining legacy compatibility fields. Done on 2026-07-02.
19. Sync legacy UI/customisation writes back into current vehicle/module instance data before mirroring/saving. Done on 2026-07-02.
20. Extract the stable garage profile instance-sync helper into `GarageProfileRuntime` and delegate from the big garage action controller. Done on 2026-07-02.
21. Add a private owner-only garage interior MVP as one bundled phase: instance pool, elevator/loading teleport, streaming request, and simple return-to-city path. Done on 2026-07-02; stream diagnostic follow-up prepared in Phase 22.
22. Add lightweight garage display vehicles using saved display spaces. Done on 2026-07-02.
23. Add same-server access modes and visits. Done on 2026-07-02 through the canonical `GarageInteriorService_Active` repair path after incremental anchor patches proved too brittle.
24. Add garage surface colours/materials and decoration anchors/ownership. Done on 2026-07-02 as an isolated customization remote/service so Phase 23's confirmed interior service does not need another source-text patch.
25. Add an owner-only in-garage customization UI MVP that calls the Phase 24 remote without patching the main dealership bootstrap. Done on 2026-07-02 after a timing repair.
26. Validate the Phase 24 backend and Phase 25 UI summary stay in sync after applying owner customization presets. Done on 2026-07-02.
27. Add same-server visitor/access UI so players can open their garage, set access, and visit a same-server public garage without Command Bar calls. Done on 2026-07-02.
28. Final garage MVP hardening: runtime stack audit, owner path smoke, save/rejoin note, mirror refresh, cleanup of temporary known-issue notes, and rollback notes. Prepared on 2026-07-02.

At this point the original persistence/garage plan is complete through its listed Phase 24 goal, and the owner-facing UI extension is complete through Phase 27. Phase 28 is the final hardening/audit step for this garage MVP run.

## Verification

After running the installer in Studio, run:

```text
scripts/roblox_persistence_phase1_profile_schema_audit.lua
```

Expected result:

- PlayerProfileSchema requires successfully.
- default garage capacity is 2;
- duplicate module instances remain separate;
- two vehicles block a third vehicle;
- Color3 values encode/decode safely;
- no live gameplay scripts changed.

After running the Phase 2 installer, enter Play mode and run this from the **SERVER** Command Bar:

```text
scripts/roblox_persistence_phase2_profile_service_audit.lua
```

If you accidentally run it from the client Command Bar, Roblox cannot read `ServerScriptService` and the audit will fail with a clear context message. As a lighter client-side check, run:

```text
scripts/roblox_persistence_phase2_client_probe.lua
```

Expected result:

- ProfileService is enabled and loads the player;
- BindableFunctions exist;
- default profile has two garage spaces and zero vehicles;
- `MarkDirty` works;
- `SaveNow` completes as a dry-run while `DataStoreEnabled` is false.

After running the Phase 3 installer, enter Play mode and run this from the **SERVER** Command Bar:

```text
scripts/roblox_persistence_phase3_legacy_profile_bridge_audit.lua
```

Expected result:

- legacy cockpit ownership converts into vehicle/cockpit instances;
- installed modules become equipped module instances;
- extra owned modules remain unequipped;
- colours, neon ownership, and module upgrade levels migrate where possible;
- converted profile is DataStore-safe;
- server bridge BindableFunctions work.

After running the Phase 4 installer, enter Play mode and run this from the **SERVER** Command Bar:

```text
scripts/roblox_persistence_phase4_garage_session_mirror_server_audit.lua
```

Then run this from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase4_garage_session_mirror_client_smoke.lua
```

Expected result:

- server audit confirms the garage controller has the Phase 4 mirror patch and required bindables;
- client smoke confirms `GetInitial` still succeeds;
- player attributes show the server mirrored at least one vehicle instance and default module instances into persistence.

Phase 5 test order:

1. Run:

```text
scripts/roblox_persistence_phase5_enable_datastore_mirror_saves.lua
```

2. Enter Play mode and run the Phase 4 client smoke from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase4_garage_session_mirror_client_smoke.lua
```

3. Run the Phase 5 save audit from the **SERVER** Command Bar:

```text
scripts/roblox_persistence_phase5_datastore_save_audit.lua
```

If it reports no mirrored vehicles, run:

```text
scripts/roblox_persistence_phase5_import_snapshot_binding_repair.lua
```

Then in Play mode run from the **SERVER** Command Bar:

```text
scripts/roblox_persistence_phase5_import_snapshot_binding_audit.lua
```

Then rerun the Phase 4 client smoke and Phase 5 save audit.

4. Optional load check: stop Play, start a fresh Play/rejoin, then run from the **SERVER** Command Bar:

```text
scripts/roblox_persistence_phase5_datastore_load_audit.lua
```

5. To return to dry-run saves:

```text
scripts/roblox_persistence_phase5_disable_datastore_mirror_saves.lua
```

Expected result:

- save audit confirms `DataStoreEnabled=true`;
- mirrored profile has at least one vehicle and module instance;
- `SaveNow` writes successfully;
- optional fresh-session load audit finds saved vehicle/module instance counts.

Phase 6 test order:

1. Run:

```text
scripts/roblox_persistence_phase6_garage_capacity_gate.lua
```

2. Enter Play mode and run from the **SERVER** Command Bar:

```text
scripts/roblox_persistence_phase6_garage_capacity_gate_audit.lua
```

3. Manual gameplay verification:

- selecting an already-owned cockpit still works;
- buying a second cockpit works when only one cockpit is owned and capacity is 2;
- buying a third cockpit shows `Garage full. Upgrade your garage to store more vehicles.`;
- `GetInitial` and the normal dealership/customisation flow still open.

Phase 7 test order:

1. Run:

```text
scripts/roblox_persistence_phase7_garage_capacity_upgrade.lua
```

2. Enter Play mode and run from the **SERVER** Command Bar:

```text
scripts/roblox_persistence_phase7_garage_capacity_upgrade_audit.lua
```

3. Run from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase7_garage_capacity_upgrade_client_smoke.lua
```

Expected result:

- `UpgradeGarageCapacity` action exists;
- profile response includes Garage capacity data;
- client smoke increases capacity by 1;
- cash decreases by the upgrade price;
- persistence mirror records `UpgradeGarageCapacity`.

Phase 8 test order:

1. Run:

```text
scripts/roblox_persistence_phase8_garage_capacity_upgrade_ui.lua
```

2. Run:

```text
scripts/roblox_persistence_phase8_garage_capacity_ui_source_audit.lua
```

3. Enter Play mode and run from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase8_garage_capacity_ui_client_smoke.lua
```

4. Manual gameplay verification:

- the `Garage Spaces` panel appears above the cash panel;
- the panel shows the current used/capacity count and next price;
- clicking `Upgrade` once increases capacity and decreases cash;
- after upgrading, the cockpit purchase gate allows one more new cockpit than before;
- if capacity reaches the configured max, the button changes to `MAXED`.

Phase 9 test order:

1. Run:

```text
scripts/roblox_persistence_phase9_garage_property_menu.lua
```

2. Run:

```text
scripts/roblox_persistence_phase9_garage_property_menu_audit.lua
```

3. Enter Play mode and run from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase9_garage_property_menu_client_smoke.lua
```

4. Manual gameplay verification:

- the `Garage Spaces` panel no longer overlaps the Categories panel;
- the old `Next: $price` text is gone;
- the button says `Buy More`;
- clicking `Buy More` opens the garage property gallery;
- garage cards show thumbnail/picture areas, district text, and space counts;
- buying `Kanda Lift Bay` increases capacity through the temporary Phase 7 backend;
- locked future garage cards do not spend cash.

If Play fails before the dealership UI loads with `Out of local registers ... V75Driving`, run:

```text
scripts/roblox_persistence_phase9_register_limit_repair.lua
```

Then run:

```text
scripts/roblox_persistence_phase9_register_limit_repair_audit.lua
```

Restart Play after the repair, then rerun the Phase 9 client smoke.

Phase 10 test order:

1. Run:

```text
scripts/roblox_persistence_phase10_garage_ui_layout_modal.lua
```

2. Run:

```text
scripts/roblox_persistence_phase10_garage_ui_layout_modal_audit.lua
```

3. Enter Play mode and run from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase10_garage_ui_layout_modal_client_smoke.lua
```

4. Manual gameplay verification:

- `Categories` is at the top of the left column;
- `Garage Spaces` sits above `Available Cash`;
- none of the three left-column panels overlap;
- clicking `Buy More` opens the garage property menu above a 30% black screen overlay;
- clicking `X` or the black overlay closes the menu;
- mobile/small viewport still leaves Categories scrollable.

Phase 11 test order:

1. Run:

```text
scripts/roblox_persistence_phase11_garage_spaces_cockpit_only.lua
```

2. Run:

```text
scripts/roblox_persistence_phase11_garage_spaces_cockpit_only_audit.lua
```

3. Enter Play mode and run from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase11_garage_spaces_cockpit_only_client_smoke.lua
```

4. Manual gameplay verification:

- `Garage Spaces` appears on the cockpit-selection screen;
- it hides on cockpit paint;
- it hides on module building;
- it hides during customisation;
- backing to cockpit selection makes it reappear.

Phase 12 test order:

1. Run:

```text
scripts/roblox_persistence_phase12_garage_property_menu_controller_extract.lua
```

2. Run:

```text
scripts/roblox_persistence_phase12_garage_property_menu_controller_audit.lua
```

3. Enter Play mode and run from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase12_garage_property_menu_controller_client_smoke.lua
```

4. Manual gameplay verification:

- the dealership UI loads without the `Out of local registers` error;
- `Garage Spaces` appears only on cockpit selection;
- clicking `Buy More` opens the same garage-property cards over the dim backdrop;
- `Kanda Lift Bay` still buys one more space through the temporary backend if you choose to test purchase behavior.

Phase 13 merged test order:

1. Run in Studio Edit mode:

```text
scripts/roblox_persistence_phase13_garage_property_ownership.lua
```

2. Enter Play mode and run from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase13_garage_property_ownership_client_smoke.lua
```

The smoke verifies the real `BuyGarageProperty` server route, owned-property profile data, persistence mirror action, and `GaragePropertyMenuController`. If the player has not reached the dealership desk yet, the smoke now skips the visual `HOVER_RACING_V2_GarageUI` check instead of failing, because that UI may load only after the intro opens the garage.

If step 1 stopped at the garage mirror mutating action anchor, run this in Edit mode before entering Play:

```text
scripts/roblox_persistence_phase13_garage_property_ownership_repair.lua
```

3. Manual gameplay verification:

- `Buy More` still opens the garage property gallery;
- buyable cards show real prices;
- owned garage properties show as owned;
- buying a property spends cash and records `Garage.OwnedGarageProperties`;
- the `Garage Spaces` count reflects starter spaces plus owned property spaces;
- buying a new cockpit still respects the updated garage capacity.

Phase 14 merged test order:

1. Run in Studio Edit mode:

```text
scripts/roblox_persistence_phase14_instance_inventory_bridge.lua
```

2. Enter Play mode and run from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase14_instance_inventory_client_smoke.lua
```

3. Manual verification:

- the dealership UI still opens normally;
- existing owned/installed cockpit and module UI still looks unchanged;
- the smoke reports that instance fields exist beside the legacy fields;
- if cash/capacity allow, buying another cockpit copy creates one new vehicle/cockpit instance;
- if cash allows, buying another module copy creates a separate unequipped module instance, then equips that specific copy to the current vehicle.

Phase 15 merged test order:

1. Run in Studio Edit mode:

```text
scripts/roblox_persistence_phase15_duplicate_copy_ui.lua
```

2. Enter Play mode and run from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase15_duplicate_copy_ui_client_smoke.lua
```

3. Manual verification:

- on cockpit selection, an owned cockpit still has `Select`;
- the same selected owned cockpit shows `Owned copies: N`;
- clicking `Buy Another` buys a separate cockpit/vehicle copy when cash and garage space allow;
- in Build Modules, selecting an owned compatible module option shows copy-count language;
- if a free copy exists, `Equip Copy` installs that copy;
- `Buy Copy` buys another module copy and equips it to the selected slot;
- unowned modules still use the original first-time `Buy` path.

Phase 16 merged test order:

1. Run in Studio Edit mode:

```text
scripts/roblox_persistence_phase16_module_family_locks_and_sorting.lua
```

2. Enter Play mode and run from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase16_module_family_locks_and_sorting_client_smoke.lua
```

3. Manual verification:

- fresh owned cockpit starter modules are present as one included set;
- extra Standard module copies show a non-zero price;
- module families from cockpits the player does not own appear locked on the far right;
- owned compatible module copies from other cockpit families appear on the left of the option carousel;
- locked module cards show a cockpit requirement and cannot be bought;
- desktop and mobile layouts remain readable with the slightly wider module cards.

Phase 17 merged test order:

1. Run in Studio Edit mode:

```text
scripts/roblox_persistence_phase17_module_owned_buy_tabs.lua
```

2. Enter Play mode and run from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase17_module_owned_buy_tabs_client_smoke.lua
```

3. Manual verification:

- selecting Front Engine shows the `OWNED MODULES` / `BUY MODULES` layer, and neither owned nor buy lists show rear engines;
- selecting Rear Engine shows only rear engines;
- owned module copies appear as separate cards;
- owned-card popup says `EQUIP` and uses the buy colour;
- buy-card popup says `BUY` and auto-equips the newly bought copy;
- locked buy cards still preview the module but cannot buy;
- `Buy Copy`, `Equip Copy`, and `No Free Copy` no longer appear.

Phase 18 merged test order:

1. Run the dual-mode script in Studio Edit mode:

```text
scripts/roblox_persistence_phase18_profile_source_handoff.lua
```

2. Restart Play and run the same file from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase18_profile_source_handoff.lua
```

3. For a true persistence handoff test:

- enable DataStore saves if they are currently disabled;
- enter the garage and make a persistent change such as buying a garage property, cockpit copy, or module copy;
- force/save through the existing Phase 5 save path or leave/restart cleanly;
- start a fresh Play session and run the Phase 18 smoke from the CLIENT Command Bar;
- the smoke should report `Hydrated=true`, `source=ProfileService`, and a saved vehicle/module/property count matching the saved profile.

4. Manual verification:

- the dealership UI still opens normally;
- owned cockpits/modules/properties return after the fresh Play session;
- Build Modules still shows owned/buy tabs and correct front/rear engine filtering;
- BUY/LOCKED/EQUIP popups remain centred across desktop and small screen sizes;
- new garage actions still mirror back into ProfileService after the handoff.

Phase 19 merged test order:

1. Run the dual-mode script in Studio Edit mode:

```text
scripts/roblox_persistence_phase19_instance_compat_sync.lua
```

2. Restart Play and run the same file from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase19_instance_compat_sync.lua
```

3. Manual persistence verification:

- change a cockpit colour, module colour, thrust colour, module neon, or module upgrade;
- save/restart through the current ProfileService/DataStore path;
- confirm the same edit returns after hydration;
- confirm Build Modules still shows owned/buy tabs, correct installed modules, and centred BUY/LOCKED/EQUIP popups.

Phase 20 merged test order:

1. Run the dual-mode script in Studio Edit mode:

```text
scripts/roblox_persistence_phase20_garage_profile_runtime_extract.lua
```

2. Restart Play and run the same file from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase20_garage_profile_runtime_extract.lua
```

3. Expected smoke:

- `Smoke GetInitial OK`;
- `missingInstances=0`;
- `RuntimeModule=GarageProfileRuntime`;
- a non-zero sync count if the current vehicle has installed modules.

4. Manual verification:

- dealership/customisation still opens normally;
- Build Modules still shows owned/buy tabs and installed module copies;
- colour/thrust/neon/upgrade edits still persist through save/restart;
- no visible UI, driving, or VFX behavior changes.

Phase 21 merged test order:

1. Run the dual-mode script in Studio Edit mode:

```text
scripts/roblox_persistence_phase21_private_garage_interior_mvp.lua
```

2. Restart Play and run the same file from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase21_private_garage_interior_mvp.lua
```

3. Expected smoke:

- `EnterOwnGarage OK`;
- `State InGarage=true`;
- `streamOk=true` where available;
- `ReturnToCity OK`.

4. Manual verification:

- the temporary `Private Garage` elevator prompt appears near the dealership/city exit marker;
- using the prompt moves the character into a simple private garage room;
- the room is under `Workspace.NeoTokyoRacersWorld.Interiors.GarageInstances`;
- the interior `Return` prompt brings the character back to the city/dealership fallback;
- dealership/customisation, driving, UI, and VFX still behave normally after returning.

Phase 22 merged test order:

1. Run the dual-mode script in Studio Edit mode:

```text
scripts/roblox_persistence_phase22_garage_display_vehicle_mvp.lua
```

2. Restart Play and run the same file from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase22_garage_display_vehicle_mvp.lua
```

3. Expected smoke:

- `EnterOwnGarage OK`;
- `Garage GetInitial OK before display smoke`;
- `displayOk=true`;
- `displayExists=true`;
- `ReturnToCity OK`.

4. Manual verification:

- the private garage contains one visible vehicle on `VehicleDisplayPad`;
- the display vehicle uses the current saved cockpit/module setup;
- it is anchored, non-colliding, and not drivable;
- the `streamError=` text explains the Phase 21 `streamOk=false` result if Studio rejects the streaming request;
- returning to the city still leaves dealership/customisation/driving behavior unchanged.

Phase 23 merged test order:

1. Preferred current install/repair path: run the canonical dual-mode script in Studio Edit mode:

```text
scripts/roblox_persistence_phase23_garage_interior_service_canonical_repair.lua
```

2. Restart Play and run the same file from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase23_garage_interior_service_canonical_repair.lua
```

3. Expected smoke:

- `Garage GetInitial OK before visit smoke`;
- `SetAccessMode OK. mode=Public`;
- `VisitGarage OK`;
- `visitingOwner=<your user id>`;
- `ReturnToCity OK`;
- cleanup `SetAccessMode OK. mode=Private`.

4. Manual verification:

- in a two-player local/server test, player A sets access to `Public` and player B can `VisitGarage` with player A's `UserId`;
- `Private` blocks non-owner visitors;
- `FriendsOnly` and `InviteOnly` can be checked later with the relevant account setup;
- visitor return path works through the remote and return prompt;
- display vehicle remains visible in the visited garage.

Phase 24 merged test order:

1. Run the dual-mode script in Studio Edit mode:

```text
scripts/roblox_persistence_phase24_garage_surfaces_decor_mvp.lua
```

2. Restart Play and run the same file from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase24_garage_surfaces_decor_mvp.lua
```

3. Expected smoke:

- `Garage GetInitial OK before customization smoke`;
- `VisitGarage OK`;
- `SetSurfaceStyle` succeeds for floor and walls;
- `SetDecorationAnchor` succeeds for `BackWallCenter` / `NeonSign`;
- `Customization state OK` with at least two surfaces and one decoration;
- `ReturnToCity OK`;
- cleanup `SetAccessMode OK. mode=Private`.

4. Manual verification:

- the private garage floor/walls visibly use the smoke-test material colours;
- a simple neon sign appears on the back-wall anchor;
- the new `GarageInteriorCustomizationService_Active` exists beside the interior service rather than replacing it;
- dealership/customisation, driving, UI, VFX, and same-server visiting still behave normally.

Phase 24 was installed and smoke-tested on 2026-07-02. The first smoke applied the surface/decor changes but failed the state readback because it counted only profile table entries. After repairing `GetCustomization` to count live model attributes as well, the follow-up smoke reported `Applied surfaces/decor. surfaces=4`, `Customization state OK. surfaces=2 decorations=1 persisted=true`, and `ReturnToCity OK`.

Phase 25 merged test order:

1. Run the dual-mode script in Studio Edit mode:

```text
scripts/roblox_persistence_phase25_garage_customization_ui_mvp.lua
```

2. Restart Play and run the same file from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase25_garage_customization_ui_mvp.lua
```

3. Expected smoke:

- `Garage GetInitial OK before UI smoke`;
- `VisitGarage OK`;
- `UI panel visible`;
- `Customization backend OK`;
- `ReturnToCity OK`;
- cleanup `SetAccessMode OK. mode=Private`.

4. Manual verification:

- the owner sees a compact `GARAGE CUSTOMISE` panel only while inside their own garage;
- floor/wall preset buttons visibly update the garage surfaces;
- decor buttons place/clear the simple MVP props through the Phase 24 backend;
- visitors do not get owner customization controls;
- dealership/customisation, driving, UI, VFX, and same-server visiting still behave normally.

Phase 25 was installed and smoke-tested on 2026-07-02. The first smoke found the UI ScreenGui but failed because the owner panel had not become visible yet; after the timing repair, the follow-up smoke reported `UI panel visible`, `Customization backend OK`, and `ReturnToCity OK`.

Phase 26 merged test order:

1. Run the dual-mode preflight in Studio Edit mode:

```text
scripts/roblox_persistence_phase26_garage_customization_validation.lua
```

2. Restart Play and run the same file from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase26_garage_customization_validation.lua
```

3. Expected smoke:

- `Garage GetInitial OK before customization validation`;
- `VisitGarage OK`;
- `UI panel visible before applying validation presets`;
- `Applied validation presets`;
- `UI summary reflected backend state`;
- `ReturnToCity OK`;
- cleanup `SetAccessMode OK. mode=Private`.

4. Manual verification:

- the panel's floor/wall/decor buttons also work when clicked manually;
- the floor, walls, and simple prop remain visible while inside the garage;
- after a save/rejoin test, the same selected surface/decor state returns or the next phase captures what still needs persistence repair.

Phase 26 was installed and smoke-tested on 2026-07-02. The client smoke reported `Applied validation presets. floor=true walls=true decor=true`, `UI summary reflected backend state. summary=SURFACES 2  DECOR 1 persisted=true`, and `ReturnToCity OK`.

Phase 27 merged test order:

1. Run the dual-mode script in Studio Edit mode:

```text
scripts/roblox_persistence_phase27_garage_access_ui_mvp.lua
```

2. Restart Play and run the same file from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase27_garage_access_ui_mvp.lua
```

3. Expected smoke:

- `Garage GetInitial OK before access UI smoke`;
- `Access UI shell visible`;
- `SetAccessMode OK. mode=Public`;
- `VisitGarage OK`;
- `State OK`;
- `ReturnToCity OK`;
- cleanup `SetAccessMode OK. mode=Private`.

4. Manual verification:

- click the `GARAGE` toggle to open the compact access panel;
- `ENTER MINE` opens your own garage;
- `SET PUBLIC` and `SET PRIVATE` update access mode;
- with two players in a local/server test, set player A to `Public`, enter player A's user ID on player B, and click `VISIT USER ID`;
- `RETURN CITY` brings the player back without breaking dealership/customisation/driving behavior.

Phase 27 was installed and smoke-tested on 2026-07-02. The client smoke reported `Access UI shell visible`, `SetAccessMode OK. mode=Public`, `VisitGarage OK`, `State OK. inGarage=true`, and `ReturnToCity OK`.

Phase 28 merged test order:

1. Run the dual-mode audit in Studio Edit mode:

```text
scripts/roblox_persistence_phase28_garage_mvp_final_audit.lua
```

2. Restart Play and run the same file from the **CLIENT** Command Bar:

```text
scripts/roblox_persistence_phase28_garage_mvp_final_audit.lua
```

3. Expected smoke:

- `Garage GetInitial OK before final audit`;
- `Access UI present`;
- `VisitGarage OK`;
- `Customization UI visible`;
- `Customization persisted and UI reflected state`;
- `Interior state OK`;
- `ReturnToCity OK`;
- cleanup `SetAccessMode OK. mode=Private`.

Phase 28 was smoke-tested on 2026-07-02. The client smoke reported `Access UI present`, `VisitGarage OK`, `Customization UI visible`, `Customization persisted and UI reflected state. summary=SURFACES 2  DECOR 1`, `Interior state OK. accessMode=Public displayExists=true`, and `ReturnToCity OK`.

4. Final manual handoff:

- if DataStore is enabled in Studio/published test, save/rejoin and verify the selected floor/wall/decor state returns;
- refresh the Studio mirror after Phase 28 passes;
- do not commit `docs/studio-full-export-paste.txt`;
- rollback for the garage MVP UI extension is to disable/remove `GarageAccessClient_Active` and `GarageInteriorCustomizationClient_Active`; backend rollback is to disable/remove `GarageInteriorCustomizationService_Active` and `GarageInteriorCustomizationInvoke`, leaving Phase 23's canonical interior service intact.
