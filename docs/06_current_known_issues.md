# Current Known Issues

This file is intentionally conservative. Items are included only when they were mentioned in the chat or are reasonable verification steps after recent changes.

## Needs Play-Test Confirmation

- Vehicle Phase AL was installed and its audit passed with 5 cockpits, 72 active modules, 23 planned upgrades, and 0 warnings.
- Vehicle Phase AM is confirmed working. The isolated spawned-vehicle writer produced `17/17` raw variables, `17/17` normalized variables, `6/6` headline stats, a `D 407` test rating, and 0 audit warnings. Detailed physics was enabled and reported working well.
- Keep `VehiclePerformanceRuntimeService_Active` as the current runtime owner. The earlier garage-controller write hook did not produce the Phase AM folders on fresh spawn.
- Mobile/gamepad comparison and broader balance testing across Lightweight/Standard/Power builds remain useful follow-up verification.
- Vehicle Phase AN is confirmed working. Fuel Injection level 1 cost `$4000`, advanced the module from level 0 to 1, changed the profile and spawned rating from `D 407` to `D 410`, and reached the spawned engine as EngineOutput `+2` and TopSpeed `+1` with 0 audit warnings.
- Phase AO is prepared for Studio install. Verify that it removes the visible Brakes, Converter, Fuel System, and generic module Upgrade controls without changing the confirmed Phase AN server/data contract.
- Phase AO needs desktop and mobile verification for tier/index display, contextual detailed variables, horizontal upgrade-card scrolling, preview values, purchase refresh, and on-screen popup placement.
- The current garage profile is session-memory only. Phase AN module upgrade ownership has the same lifetime as existing cash, cockpit, and module ownership until a unified garage profile DataStore is introduced.
- Vehicle Phase AK and its follow-up repairs were reported working by the user. Keep mobile verification open for the centered required-modules popup and small-screen module option scrolling.
- Phase AK recovery scripts remain available for the resolved register-limit, server core-gate, rear-engine catalogue, camera, per-cockpit default colour, and spawned module colour-sync problems. Do not rerun them unless the matching regression returns.
- `V75` boost recharge delay and hover wobble were generated after `V74`, but no later user confirmation is present in this chat history.
- Confirm that `BoostRechargeDelay` is being read from installed Boost modules at runtime.
- Confirm that low-speed wobble is subtle enough and fades out by `20 MPH`.
- Mobile auto-sprint is prepared in `scripts/roblox_character_sprint_controller_install.lua`; verify on a mobile device/emulator that `MobileSprintMoveThreshold` feels right.
- VFX Phase AJ is prepared to repair thrust VFX preview after the dealership preview root moved; run and verify `scripts/roblox_vfx_phaseAJ_thrust_preview_root_repair.lua` if thrust VFX is missing in the customisation menu.

## Studio Export Mirror

- The Studio mirror was refreshed and pushed after confirmed Phase AN. It includes the module upgrade runtime helper and the confirmed Phase AN garage hooks.
- Refresh the mirror again after Phase AO is installed and confirmed.

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

- After running `scripts/roblox_lighting_phaseR_fogcolor_property_repair.lua`, confirm the `Lighting Fogcolor` warning no longer appears during Play startup.

## VFX

Known sensitive areas:

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
- Phase AM also uses guarded source replacement against the active garage server controller and `DrivingControllerV47`. The current mirror is stale, so any exact-match failure must be treated as a request for a refreshed Studio export, not bypassed with a broad replacement.
- Buyable modules need valid `Price` attributes.
- Boost modules should have `Boost`, `BoostDuration`, `BoostRecharge`, and `BoostRechargeDelay`.
- Module folder shape should stay simple and not reintroduce redundant colour-channel folders.
