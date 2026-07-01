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
- If the client parse error is cleared but the garage server reports `Expected 'end' ... got <eof>`, run `scripts/roblox_persistence_phase17_garage_server_final_end_repair.lua`. It restores the final top-level `do` close before `-- V56_CONSOLIDATED_ACTION_CONTROLLER_END` and prints a tail dump if the live source shape differs.
- If the exact final-end repair does not clear the EOF error, run `scripts/roblox_persistence_phase17_garage_server_force_final_end_repair.lua`. It inserts one closing `end` immediately before the final V56 marker unless that marker is already preceded by `end`, in which case it prints a tail dump for targeted follow-up.
- Vehicle Phase AK and its follow-up repairs were reported working by the user. Keep mobile verification open for the centered required-modules popup and small-screen module option scrolling.
- Phase AK recovery scripts remain available for the resolved register-limit, server core-gate, rear-engine catalogue, camera, per-cockpit default colour, and spawned module colour-sync problems. Do not rerun them unless the matching regression returns.
- `V75` boost recharge delay and hover wobble were generated after `V74`, but no later user confirmation is present in this chat history.
- Confirm that `BoostRechargeDelay` is being read from installed Boost modules at runtime.
- Confirm that low-speed wobble is subtle enough and fades out by `20 MPH`.
- Mobile auto-sprint is prepared in `scripts/roblox_character_sprint_controller_install.lua`; verify on a mobile device/emulator that `MobileSprintMoveThreshold` feels right.
- VFX Phase AJ is prepared to repair thrust VFX preview after the dealership preview root moved; run and verify `scripts/roblox_vfx_phaseAJ_thrust_preview_root_repair.lua` if thrust VFX is missing in the customisation menu.

## Studio Export Mirror

- The Studio mirror was refreshed on 2026-06-30 at 17:37:33 from Studio and imported 65 scripts. `roblox/studio_snapshot/hierarchy.md` now reflects the confirmed mobile thumbstick, UI theme, lighting, and VFX delayed attach-once changes.
- The mirror is stale after the Studio-confirmed Persistence Phase 1-16 installs until the full snapshot workflow captures `PlayerProfileSchema`, `Persistence_EditAttributes`, `ProfileService_Active`, `LegacyGarageProfileMapper`, `LegacyGarageProfileBridge_Active`, service/bindings hierarchy, the patched `GarageActionController_Shadow_Disabled` source, the capacity-upgrade action, mapper patch, patched client bootstrap capacity UI, `GaragePropertyCatalog`, the garage property gallery UI patch, register-limit repair, modal/layout repair, cockpit-only Garage Spaces visibility patch, `GaragePropertyMenuController`, the smaller active bootstrap bridge, the `DataStoreEnabled` attribute state, `BuyGarageProperty`, owned garage property profile data, Phase 13 controller/catalog changes, Phase 14 instance inventory fields/actions and mapper preservation logic, Phase 15 duplicate-copy client UI patch, and Phase 16 module source-lock/catalog/sorting patch. If Phase 17 is installed before refreshing, the mirror should also capture the owned/buy module tab repair.
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
