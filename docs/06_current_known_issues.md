# Current Known Issues

This file is intentionally conservative. Items are included only when they were mentioned in the chat or are reasonable verification steps after recent changes.

## Needs Play-Test Confirmation

- Mobile thumbstick V2.4 is installed and user-confirmed working well. Keep broader device checks open for small-screen fit, boost/thumb overlap, touch jitter, and multi-touch behavior.
- Vehicle Phase AL was installed and its audit passed with 5 cockpits, 72 active modules, 23 planned upgrades, and 0 warnings.
- Vehicle Phase AM is confirmed working. The isolated spawned-vehicle writer produced `17/17` raw variables, `17/17` normalized variables, `6/6` headline stats, a `D 407` test rating, and 0 audit warnings. Detailed physics was enabled and reported working well.
- Keep `VehiclePerformanceRuntimeService_Active` as the current runtime owner. The earlier garage-controller write hook did not produce the Phase AM folders on fresh spawn.
- Mobile/gamepad comparison and broader balance testing across Lightweight/Standard/Power builds remain useful follow-up verification.
- Vehicle Phase AN is confirmed working. Fuel Injection level 1 cost `$4000`, advanced the module from level 0 to 1, changed the profile and spawned rating from `D 407` to `D 410`, and reached the spawned engine as EngineOutput `+2` and TopSpeed `+1` with 0 audit warnings.
- Vehicle Phase AO was installed and reported working well. The legacy Brakes, Converter, Fuel System, and generic module Upgrade controls are no longer the current visible UI.
- Broader mobile/device verification remains useful for contextual detailed variables, horizontal upgrade-card scrolling, text fit, and Buy popup placement.
- The current garage profile is session-memory only. Phase AN module upgrade ownership has the same lifetime as existing cash, cockpit, and module ownership until a unified garage profile DataStore is introduced.
- Persistence Phases 1-8 were installed/tested in Studio. Phase 8 worked functionally but its capacity panel overlapped the Categories panel, and the design direction changed from generic capacity upgrades to physical garage-property purchases. Persistence Phase 9 was installed but caused the active client bootstrap to exceed Roblox's 200 local-register limit near `V75Driving`; run `scripts/roblox_persistence_phase9_register_limit_repair.lua` before retesting Phase 9. The active garage profile remains the V56 session-memory profile until a later source-of-truth bridge phase.
- Studio API services or a published/API-enabled experience are required for Phase 5 DataStore save/load audits. If save fails with an API/DataStore access message, disable saves again with `scripts/roblox_persistence_phase5_disable_datastore_mirror_saves.lua` and enable Studio API access before retesting.
- If the Phase 5 save audit reports that the mirrored profile has no vehicles after the Phase 4 client smoke, run `scripts/roblox_persistence_phase5_import_snapshot_binding_repair.lua`. The likely cause is that mutating the table returned by `GetProfile` does not update ProfileService's internal session table across BindableFunction boundaries; the repair adds `ImportProfileSnapshot` so ProfileService owns the replacement.
- After Phase 6, verify the cockpit purchase UX manually: owning/selecting existing cockpits should still work, buying a second cockpit should work if capacity is 2 and only one cockpit is owned, and buying a third cockpit should show `Garage full. Upgrade your garage to store more vehicles.`
- Phase 7 client smoke spends current-session test cash and increases `GarageCapacity` once. If rerun in the same session, capacity and price will already be higher.
- Phase 9 is a guarded exact-source follow-up against the large active client bootstrap after Phase 8. If it aborts, refresh the Studio mirror before writing a new UI patch. After install, verify the `Garage Spaces` panel on desktop and mobile sizes and confirm it does not overlap Categories, cash, cockpit grid, or bottom navigation.
- Phase 9 uses the Phase 7 `UpgradeGarageCapacity` action as a temporary backend for the first `Kanda Lift Bay` card. The proper next server phase should add `BuyGarageProperty`, owned garage property IDs, and capacity calculated from those owned properties.
- The Phase 9 register-limit repair keeps the same UI behavior but moves the new helper functions onto one `NTRPersistencePhase9` table so the large client bootstrap has fewer top-level locals.
- Persistence Phase 10 was installed and worked as expected. Keep broader desktop/mobile checks open for the stacked Categories, Garage Spaces, and Available Cash left column.
- Persistence Phase 11 was installed and worked as expected. `Garage Spaces` should appear only during `CockpitShop` and hide in cockpit paint, module shop, and customisation stages.
- Persistence Phase 12 was installed and worked as expected. The garage property card renderer now lives in `GaragePropertyMenuController`, keeping the active client bootstrap lighter before richer garage UI work.
- Persistence Phase 13 was installed through the repair path and the client smoke confirmed the core `BuyGarageProperty`, owned-property profile/mirror, and controller path on 2026-07-01. The original smoke had an over-strict visual UI wait and could fail before the player reached the dealership desk; the smoke now skips that visual check if `HOVER_RACING_V2_GarageUI` is not loaded yet. Manually verify after reaching the dealership desk that `Buy More` opens the garage property gallery, owned properties show as owned, and the two-space cockpit gate expands only after buying properties.
- If the first Phase 13 installer stops with `Could not find source anchor for garage mirror mutating action`, run `scripts/roblox_persistence_phase13_garage_property_ownership_repair.lua`. The first installer may already have updated catalogue/schema/mapper data before stopping; the repair completes the missing server action, mirror mutating action, profile response, bootstrap context, and controller backend switch.
- Persistence Phase 14 was installed and reported working well by the user on 2026-07-01. The active profile now has duplicate-capable instance fields/actions while preserving legacy UI fields.
- Persistence Phase 15 was installed and reported working well by the user on 2026-07-01. It exposes duplicate-copy controls for owned cockpits/modules without adding a full vehicle-instance picker.
- Persistence Phase 16 was installed and scripts worked well, but follow-up UI fixes were requested: front/rear engines must be split by slot, owned and buy module views should be separate bottom-menu layers, owned modules should appear as separate instance cards, and the `Buy Copy` / `Equip Copy` / `No Free Copy` wording should be removed.
- Persistence Phase 17 is prepared but not yet Studio-tested. It repairs the Phase 16 module picker with `OWNED MODULES` / `BUY MODULES` menu buttons, per-instance owned module cards, BUY/EQUIP actions, preview-on-click for locked modules, and client/server front-rear engine slot guards. Verify desktop and mobile layout carefully around the tab menu, wider owned module cards, and popup.
- The first Phase 17 installer caused a client bootstrap parse error near line 408, and the v2 repair may still leave the bootstrap unparsable on some Studio sources. Use `scripts/roblox_persistence_phase17_owned_buy_tabs_repair_v3.lua`, then restart Play before running the updated smoke. The Phase 17 smoke now warns, rather than fails, when the catalog cannot classify front/rear engine templates by metadata.
- If the Phase 17 smoke reports `Front=0, Rear=30`, run `scripts/roblox_persistence_phase17_front_rear_engine_metadata_repair.lua` in Edit mode. The repair adds explicit `EnginePosition` metadata to front/rear engine assets, exposes it in the garage catalog, and refreshes the Phase 17 client/server slot checks to prefer that field.
- If the Phase 17 smoke passes but Play still reports `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled:408: Incomplete statement`, run `scripts/roblox_persistence_phase17_client_parse_line408_cleanup.lua` in Edit mode. It only touches the client bootstrap if it finds stale dangling `or` / `and` continuation lines near line 408; otherwise it stores the exact source window at `ReplicatedStorage.NTR_DEBUG.COPY_THIS_LINE408_SOURCE_DUMP.Value` and prints a large Output copy block for targeted follow-up.
- A confirmed Phase 17 line-408 source dump showed a single stray `l` immediately before `-- NTR_PERSISTENCE_PHASE17_MODULE_TABS_V4`. Run `scripts/roblox_persistence_phase17_remove_orphan_l_line408.lua` to remove that exact orphan line.
- After the server `GetInitial` repairs, entering the dealership can expose a client nil-call at `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled:3475` on `sortedSlots()[1]`. Run `scripts/roblox_persistence_phase17_client_slot_helpers_and_engine_metadata_repair.lua`; it restores the missing slot/category/module lookup helper block and reapplies explicit front/rear engine metadata.
- Cockpit paint/customisation can expose `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled:1928: attempt to call a nil value` inside `renderColourPicker` if persisted colour data reaches the picker as table-shaped data instead of raw `Color3`. Run `scripts/roblox_persistence_phase17_colour_picker_color3_repair.lua` to normalize colour values before HSV conversion.
- If the colour picker error shifts to `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled:1962`, run `scripts/roblox_persistence_phase17_colour_picker_slider_signal_repair.lua`. The shifted line maps to the compact slider input connection after the Color3 repair, so the follow-up guards slider signal hookups instead of changing the visual picker layout.
- If the same line-1962 colour picker failure persists, use `scripts/roblox_persistence_phase17_colour_picker_root_repair.lua` instead of another line-number patch. It replaces the fragile compact drag-slider path with a swatch plus RGB-step picker and keeps the existing paint/customisation server callbacks.
- The root colour picker repair can push the already-large client bootstrap back over Roblox's 200 local-register limit, surfacing as `Out of local registers when trying to allocate mobileInputState`. Run `scripts/roblox_persistence_phase17_colour_picker_register_limit_repair.lua` to remove bulky colour helper locals and reinstall the picker through `NTRPersistencePhase15` table methods.
- The RGB-step picker from the register-limit recovery is only a stability fallback. Once startup works, run `scripts/roblox_persistence_phase17_colour_picker_hsb_slider_restore.lua` to restore draggable H/S/B gradient sliders without adding new top-level helper locals.
- If Front Engine only exposes the old flat `Engine V1` through `Engine V4` options, run `scripts/roblox_persistence_phase17_front_engine_family_and_module_card_text.lua`. It keeps the old templates in place for rollback but retires/hides them from the catalogue, makes the Phase AK family front engines visible like rear engines, and changes module card text to `Cockpit / Variant`, green price, and `Owned xN`.
- If Start Driving spawns the car but it is not hover/drivable and the client stack points to `closeGarage`, run `scripts/roblox_persistence_phase17_close_garage_drive_handoff_repair.lua`. The likely cause is an optional colour-picker cleanup helper being absent after the Phase 17 recovery sequence; the repair makes garage closing tolerant and lets `startDriving` continue after successful `SpawnVehicle`.
- If module option cards clip their bottom text, or the `OWNED MODULES` / `BUY MODULES` tabs feel too tall/text-heavy, run `scripts/roblox_persistence_phase17_module_button_layout_polish.lua`. It enlarges the module-card scroll height, uses one centred label on the tab buttons, and changes locked buy cards to show `Locked` in muted text while keeping locked cards dark.
- If buy-module colours still show locked cards as lighter than available cards, or BUY/LOCKED popups are off-centre after horizontal scrolling, run `scripts/roblox_persistence_phase17_module_card_colour_popup_sprint_guard.lua`. It uses rendered card positions for popup centring, hides popups when the carousel scrolls, mutes locked card title/price, and also blocks sprint FOV changes while garage/customisation UI is open.
- If module popups are still offset after scrolling, run `scripts/roblox_persistence_phase17_module_popup_position_and_cockpit_back_lock.lua`. It repeats popup centring after the next rendered frame, moves the popup above the bottom module frame with an 8px gap, and hides the Paint Cockpit Back button so players cannot return to the dealership list after buying/selecting a cockpit.
- If the Paint Cockpit Back lock works but module popups still have the same offset, use `scripts/roblox_persistence_phase17_module_popup_screen_layer_repair.lua`. The fresh mirror confirmed the popup can still be distorted by being parented inside the padded ModuleOptions panel; this repair creates a full-screen popup layer and positions from the selected card's screen coordinates instead.
- If that screen-layer repair creates too much vertical space or the popup still feels detached, use `scripts/roblox_persistence_phase17_module_popup_card_anchor_repair.lua`. It creates an invisible top-centre anchor on the selected module card, places the popup 6px above that anchor, and hides the popup on Next, Back, and stage changes.
- If selecting/buying a cockpit no longer advances to Paint Cockpit after the card-anchor popup patch, run `scripts/roblox_persistence_phase17_cockpit_paint_stage_scope_repair.lua`. The likely cause is `showStage()` calling `NTR_hideModulePopup()` before that helper is in lexical scope; the repair changes `showStage()` to hide `UI.ModulePopup` inline.
- If Build Modules opens but BUY/LOCKED/EQUIP popups still appear high or off-centre, run `scripts/roblox_persistence_phase17_module_popup_card_child_repair.lua`. It avoids overlay/screen-coordinate drift by parenting the visible popup directly to the selected module card, then parks it safely before rerenders, scrolling, Next, and Back.
- If the card-child repair centres the popup but module cards spill outside the bottom frame, run `scripts/roblox_persistence_phase17_module_carousel_clip_popup_overlay_repair.lua`. It restores `ClipsDescendants` on the module carousel and positions only the popup on an overlay from the selected card's rendered centre.
- If carousel clipping is fixed but the popup is offset again, run `scripts/roblox_persistence_phase17_module_popup_tracker_layer_repair.lua`. It is the preferred root fix for both problems together: clipped carousel cards plus a popup on a `UI.ModuleShop` overlay that tracks the selected card's rendered centre every frame while visible.
- If the tracker-layer repair triggers `Out of local registers when trying to allocate V75Driving`, run `scripts/roblox_persistence_phase17_module_popup_tracker_register_repair.lua`. It preserves the same UI behavior but converts the popup tracker helpers from top-level locals into `NTRPersistencePhase15` table methods to reduce register pressure.
- If moving from Paint Cockpit into Build Modules reports `The Parent property of ModulePopup is locked, current parent: NULL`, run `scripts/roblox_persistence_phase17_module_popup_destroyed_instance_repair.lua`. It handles the stale destroyed `UI.ModulePopup` reference left by earlier card-parented popup attempts by rebuilding the popup on the overlay before hide/park/position operations.
- The Phase 17 card-tracked overlay repair fixed carousel clipping but BUY/LOCKED/EQUIP can still appear horizontally off-centre and too high above the clicked module card. The alignment diagnostic showed `dx=-47.3` and `gap=57.5`, confirming the popup is not using the intended selected-card anchor. Use `scripts/roblox_persistence_phase17_module_popup_anchor_target_repair.lua` next. It marks the current rendered selected card, creates an invisible top-centre `ModulePopupAnchor`, positions the overlay from that anchor, removes misleading X clamping, and hides the popup when the card is not sufficiently visible.
- If the diagnostic still reports `gap=57.5` after attempting the anchor-target repair, run the read-only `scripts/roblox_persistence_phase17_module_popup_source_marker_audit.lua` in Edit mode. If it reports the old card-tracked overlay helper is still installed, rerun the anchor-target repair, restart Play, and rerun the diagnostic.
- If the source-marker audit confirms `NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ANCHOR_TARGET = true` but the diagnostic still reports `gap=57.5`, run `scripts/roblox_persistence_phase17_module_popup_pool_target_reset_repair.lua` in Edit mode. This clears stale popup target attributes and old `ModulePopupAnchor` children from reused pooled buttons before each render, preventing the overlay from following a recycled non-selected card.
- If the runtime anchor diagnostic shows exactly one target card and a correct `ModulePopupAnchor`, but the visible popup centre/bottom still does not match that anchor, run `scripts/roblox_persistence_phase17_module_popup_absolute_correction_repair.lua` in Edit mode. This keeps the selected-card anchor system and corrects the popup's actual `AbsolutePosition` after placement, covering UI scale or overlay transform offsets. The updated repair is safe to rerun after the earlier bad `Installer source text leaked into bootstrap unexpectedly` assert and now measures parent/UI scale before applying the correction.
- If the client parse error is cleared but the garage server reports `Expected 'end' ... got <eof>`, run `scripts/roblox_persistence_phase17_garage_server_final_end_repair.lua`. It restores the final top-level `do` close before `-- V56_CONSOLIDATED_ACTION_CONTROLLER_END` and prints a tail dump if the live source shape differs.
- If the exact final-end repair does not clear the EOF error, run `scripts/roblox_persistence_phase17_garage_server_force_final_end_repair.lua`. It inserts one closing `end` immediately before the final V56 marker unless that marker is already preceded by `end`, in which case it prints a tail dump for targeted follow-up.
- The refreshed mirror confirmed the garage server EOF error is caused by a duplicated `V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)` header near the Phase 17 slot guard. Run `scripts/roblox_persistence_phase17_garage_server_duplicate_attach_header_repair.lua`; it replaces only that exact duplicated header with a single header.
- After that repair, the Phase 17 client smoke can expose `GarageActionController_Shadow_Disabled:927: attempt to call a nil value`. The refreshed mirror shows `V56_totalStats(profile)` is still called by the profile/performance summary, but the helper block is missing. Run `scripts/roblox_persistence_phase17_garage_server_total_stats_repair.lua` in Edit mode, then restart Play and rerun the Phase 17 client smoke.
- If the next Phase 17 smoke exposes another garage server nil helper call around the `GetInitial` path, run `scripts/roblox_persistence_phase17_garage_server_foundation_repair_and_audit.lua` instead of continuing one-off fixes. It handles the Luau scoping issue where `V85_attachDefaultModuleInstancesToCurrentVehicle` can be defined before the Phase 14 `V84_*` helpers it calls, restores `V56_totalStats` if needed, and audits the expected server helper set afterward.
- If a later shifted line such as `GarageActionController_Shadow_Disabled:1445` still reports `attempt to call a nil value`, run `scripts/roblox_persistence_phase17_garage_server_line1445_audit.lua` and paste the Output dump. It is read-only and prints the live Studio source around the reported line plus helper-definition locations, avoiding another guessed patch against stale mirror line numbers.
- The line-1445 audit has shown `V56_catalog` missing while `GetInitial` still calls `Catalog = V56_catalog()`. Run `scripts/roblox_persistence_phase17_garage_server_catalog_repair.lua` to restore the catalog helper family and then rerun the Phase 17 client smoke in a fresh Play session.
- A later Phase 17 smoke reported another shifted `GetInitial` nil call at `GarageActionController_Shadow_Disabled:1639`. Use `scripts/roblox_persistence_phase17_garage_server_startup_dependency_repair.lua` before more one-off repairs; it checks declaration order as well as presence for the module-type helpers, Phase AK default/core module helpers, Phase 14 instance helpers, catalog helpers, total stats, and profile response helpers.
- Vehicle Phase AK and its follow-up repairs were reported working by the user. Keep mobile verification open for the centered required-modules popup and small-screen module option scrolling.
- Phase AK recovery scripts remain available for the resolved register-limit, server core-gate, rear-engine catalogue, camera, per-cockpit default colour, and spawned module colour-sync problems. Do not rerun them unless the matching regression returns.
- `V75` boost recharge delay and hover wobble were generated after `V74`, but no later user confirmation is present in this chat history.
- Confirm that `BoostRechargeDelay` is being read from installed Boost modules at runtime.
- Confirm that low-speed wobble is subtle enough and fades out by `20 MPH`.
- Mobile auto-sprint is prepared in `scripts/roblox_character_sprint_controller_install.lua`; verify on a mobile device/emulator that `MobileSprintMoveThreshold` feels right.
- VFX Phase AJ is prepared to repair thrust VFX preview after the dealership preview root moved; run and verify `scripts/roblox_vfx_phaseAJ_thrust_preview_root_repair.lua` if thrust VFX is missing in the customisation menu.

## Studio Export Mirror

- The Studio mirror was refreshed on 2026-06-30 at 17:37:33 from Studio and imported 65 scripts. `roblox/studio_snapshot/hierarchy.md` now reflects the confirmed mobile thumbstick, UI theme, lighting, and VFX delayed attach-once changes.
- The Studio mirror was refreshed on 2026-07-02 and includes the rejected action-rail state. Refresh it again after installing and verifying `scripts/roblox_persistence_phase17_module_popup_card_tracked_overlay_repair.lua`.
- `docs/studio-full-export-paste.txt` is generated by the receiver as a fallback paste file and should not be committed.
- The fresh mirror shows active loose `StarterPlayerScripts` helpers for trailer/camera capture, including `LocalScript`, `TrailerMode.client.lua`, and `TrailerShot01Camera`. Review whether these are intentional filming tools before publishing a normal gameplay build.

## Camera

Resolved direction:

- Avoid fully scriptable chase camera every frame. It caused jitter and did not feel like the desired pre-V72 camera.
- Keep Roblox default vehicle camera as the base.
- Use a light assist for FOV and soft recentering.

Watch for:

- Camera assist fighting any older camera script.
- On-foot sprint FOV fighting vehicle camera assist if the player enters a vehicle while sprinting.
- Mobile touch camera input overlapping driving controls.
- FOV not restoring after exit.

## Character Movement

Recently confirmed:

- Character sprint install worked after running `scripts/roblox_character_sprint_controller_install.lua`.
- The user moved/renamed the live runtime hierarchy to include `CharacterSprintController_Active`, `DriveHudController_Active`, `MobileDriveControlsController_Active`, and `RuntimeVFXController_Active` under `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime`.
- A blocked third-party sprint animation asset warning was resolved by disabling/replacing the custom `AnimationId`; Roblox's normal character animation still looked fine.

Watch for:

- The previous placeholder animation attempt may have left `StarterPlayer.StarterCharacterScripts.NTR_CharacterSprintDefaults` in Studio. The sprint installer removes it automatically.
- A custom sprint animation must be an uploaded Roblox `Animation` asset usable by the place owner/group. KeyframeSequences, Animator object IDs, and unshared third-party assets will not work directly.
- If `AnimationId` fails to load, set it to `rbxassetid://0` or a permitted animation asset. Sprint speed should still work even without a custom sprint animation.
- Mobile auto-sprint uses Roblox's standard `PlayerModule` move vector first, then falls back to `Humanoid.MoveDirection`. Verify on an actual mobile device/emulator that the threshold feels like "full push" rather than triggering too early.
- After future edits, confirm the sprint controller does not leave the humanoid at sprint speed after death, respawn, sitting, or exiting a vehicle.

## UI

Recently confirmed:

- Dealership Intro Phases 1-7 were installed and reported working on 2026-06-03.
- The full dealership menu opens from `GarageDeskTrigger` instead of immediately on spawn.
- The first-menu Exit button closes the menu and the menu reopens after leaving and re-entering the desk zone.
- Dealership Intro Phase 8 is generated for Studio install/testing. It adds a dynamic client-only arrow tether to the desk and DataStore-backed first-objective completion persistence.

Known sensitive areas:

- Shared theme back/exit colours and dealership intro objective theming were installed and reported working. `scripts/roblox_ui_shared_theme_back_exit_and_intro.lua` remains the recovery script for that sequence.
- After the shared theme patch, check older isolated HUDs such as mobile driving controls for any remaining hardcoded colours. The patch covers the active dealership bootstrap, shared UI theme helpers, and dealership intro objective, not a full visual audit of every historical UI script.
- Dealership selected-cockpit module-slot count text was removed and reported working. `scripts/roblox_dealership_remove_cockpit_module_slots_text.lua` remains the recovery script for that sequence.
- Phase Q appeared to restore garage/UI startup; confirm it still loads after a fresh Studio restart.
- The dealership intro markers are editable Studio placement controls; keep `Workspace.NeoTokyoRacersWorld.Dealership.Intro` and `Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint` positioned after world/layout changes.
- Dealership Intro Phases 3-7 are guarded source-text patches; if the active bootstrap or intro client is regenerated, rerun audits before applying new dealership patches.
- Phase 8 replaces only the isolated intro client and adds `IntroProgressService_Active`; confirm it keeps the Phase 7 desk reopen behavior and does not show the objective/tether after rejoin.
- Studio DataStore API access is needed to verify Phase 8 persistence across leave/rejoin. If API access is off, completion may be session-only and warnings are expected.
- In multiplayer/local server testing, confirm `Workspace._NTR_ClientOnly.VehiclePreview` is visible only on the owning client.
- Mobile dealership scaling.
- PC drive HUD hiding on mobile.
- Customisation colour sliders on mobile.
- Left customisation bar overlapping bottom UI on small screens.

## Lighting

- A repair script is prepared for the regression where Play-mode `N`/`M` lighting changes no longer switch windows or lamppost lights: run `scripts/roblox_lighting_night_mode_signal_repair.lua`. Root cause from the fresh mirror: `TEMP_LightingPreview` and `LightingService_Active` apply presets but do not reliably publish the `Lighting.NTR_LightingPreset` attribute that the Phase AP window/lamppost controllers watch.
- After running `scripts/roblox_lighting_phaseR_fogcolor_property_repair.lua`, confirm the `Lighting Fogcolor` warning no longer appears during Play startup.
- Lighting Phase AP was installed and user-confirmed working. Tagged windows
  switch between `Windows Day` and `Windows Night` with the lighting mode.
- Edit-mode day/night preview scripts were user-confirmed working.
- Edit-mode capture-to-Day and capture-to-Night scripts were added. Verify each
  in a fresh Play session after capture, and refresh the Studio mirror because
  these scripts change the live LightingPresets ModuleScript and stored Sky.
- The night lamppost SurfaceLight installer is generated and needs Studio
  verification. Confirm it finds the intended single template, copies it to all
  `lamppost neon` MeshParts, enables the lights at night, and disables them in
  day mode.
- The first lamppost installer run found four duplicate template lights under
  the same source MeshPart and aborted without changes. The installer now keeps
  the first light as the template and removes duplicate siblings during install.
- Phase AP removes matching SurfaceAppearance objects and clears MeshPart texture
  content. Use Roblox place version history for rollback; no in-game backups are
  created.
- After Phase AP is installed, refresh the Studio mirror so the new controller,
  tags, material assignments, and hierarchy are captured.

## VFX

Known sensitive areas:

- Current VFX baseline is confirmed working after `scripts/roblox_vfx_restore_mirror_known_good_baseline.lua` followed by `scripts/roblox_vfx_mobile_delayed_attach_once.lua`. Engine, boost, and drift VFX toggle correctly again, with no observed cut-out or RuntimeVFXController growth.
- Keep watching mobile/emulator VFX across fresh spawn, respawn/re-enter, and customisation preview. The delayed attach-once fix should keep total instances and unparented Beam counts stable over 60-120 seconds.
- Do not rerun the previous late-socket/rescan/rebuild repair ladder unless deliberately reproducing the failed experiment. Testing showed it can reintroduce RuntimeVFXController growth, 3-5 second cut-outs, all-on VFX, or unparented Beam buildup.
- Dealership Phase 4 moved the local preview vehicle to `Workspace._NTR_ClientOnly.VehiclePreview`; thrust VFX preview helpers must resolve this root before the old `Workspace.HOVER_RACING_V2_LOCAL_PREVIEW` fallback.
- Thrust colour should not flicker back to default after editing.
- Cosmetic neon and thrust-colour neon must remain separate.
- Front bumper optional neon previously did not update correctly.
- Stabiliser left/right VFX had breakage in earlier patches; verify directional drift VFX after any VFX runtime change.

## Vehicle Cockpit Lights

- Front/rear long-range car lights are intentionally deferred after the Phase S-AH experiments did not produce an acceptable result.
- Run `scripts/roblox_vehicle_phaseAI_remove_cockpit_light_systems.lua` in Studio if any cockpit-light helper output or objects remain.
- After Phase AI, Play output should not show any `[NTR Vehicle Phase U/Y/Z/AG/AH]` cockpit-light runtime messages.
- Do not rerun the removed cockpit light phases unless deliberately restoring an old experiment from Git history.

## Data/Folders

Known sensitive areas:

- Default cockpit colours are edited on each cockpit model with `DefaultPrimaryColor`, `DefaultSecondaryColor`, `DefaultDetailColor`, `DefaultNeonColor`, `DefaultFrontLightsColor`, and `DefaultRearLightsColor`.
- Phase AK uses guarded source text replacement against the active garage server controller and client bootstrap. If either source changed since the current mirror, refresh the Studio export before running or editing the installer.
- Phase AM, Phase AO, and the mobile thumbstick installer use guarded source replacement against live scripts. The post-AO mirror was refreshed on 2026-06-08; after later Studio changes, any exact-match failure must be treated as a request for another fresh export, not bypassed with a broad replacement.
- Buyable modules need valid `Price` attributes.
- Phase 16 gives extra Standard module copies a server fallback price if their template `Price` is zero. For better balancing, add explicit `ExtraCopyPrice`, `ModuleCopyPrice`, `PurchasePrice`, or `Price` attributes to Standard modules instead of relying on the fallback.
- Boost modules should have `Boost`, `BoostDuration`, `BoostRecharge`, and `BoostRechargeDelay`.
- Module folder shape should stay simple and not reintroduce redundant colour-channel folders.
