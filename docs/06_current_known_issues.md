# Current Known Issues

This file is intentionally conservative. Items are included only when they were mentioned in the chat or are reasonable verification steps after recent changes.

## Needs Play-Test Confirmation

- The fixed mobile steering thumbstick V1 is installed and visually liked by the user. The current update uses a `1.8x`-radius darker translucent drift ring, light-green idle cues, coordinated red drift cues, full outer-edge pointer travel, and `1.275x` pedals. Installed V2/V2.1 places should run `scripts/roblox_mobile_drive_thumbstick_v2_2_drift_feedback.lua`. Verify exact boundary activation, edge travel, hysteresis, pedal fit, multi-touch, and small-screen overlap.
- Vehicle Phase AL was installed and its audit passed with 5 cockpits, 72 active modules, 23 planned upgrades, and 0 warnings.
- Vehicle Phase AM is confirmed working. The isolated spawned-vehicle writer produced `17/17` raw variables, `17/17` normalized variables, `6/6` headline stats, a `D 407` test rating, and 0 audit warnings. Detailed physics was enabled and reported working well.
- Keep `VehiclePerformanceRuntimeService_Active` as the current runtime owner. The earlier garage-controller write hook did not produce the Phase AM folders on fresh spawn.
- Mobile/gamepad comparison and broader balance testing across Lightweight/Standard/Power builds remain useful follow-up verification.
- Vehicle Phase AN is confirmed working. Fuel Injection level 1 cost `$4000`, advanced the module from level 0 to 1, changed the profile and spawned rating from `D 407` to `D 410`, and reached the spawned engine as EngineOutput `+2` and TopSpeed `+1` with 0 audit warnings.
- Vehicle Phase AO was installed and reported working well. The legacy Brakes, Converter, Fuel System, and generic module Upgrade controls are no longer the current visible UI.
- Broader mobile/device verification remains useful for contextual detailed variables, horizontal upgrade-card scrolling, text fit, and Buy popup placement.
- The current garage profile is session-memory only. Phase AN module upgrade ownership has the same lifetime as existing cash, cockpit, and module ownership until a unified garage profile DataStore is introduced.
- Vehicle Phase AK and its follow-up repairs were reported working by the user. Keep mobile verification open for the centered required-modules popup and small-screen module option scrolling.
- Phase AK recovery scripts remain available for the resolved register-limit, server core-gate, rear-engine catalogue, camera, per-cockpit default colour, and spawned module colour-sync problems. Do not rerun them unless the matching regression returns.
- `V75` boost recharge delay and hover wobble were generated after `V74`, but no later user confirmation is present in this chat history.
- Confirm that `BoostRechargeDelay` is being read from installed Boost modules at runtime.
- Confirm that low-speed wobble is subtle enough and fades out by `20 MPH`.
- Mobile auto-sprint is prepared in `scripts/roblox_character_sprint_controller_install.lua`; verify on a mobile device/emulator that `MobileSprintMoveThreshold` feels right.
- VFX Phase AJ is prepared to repair thrust VFX preview after the dealership preview root moved; run and verify `scripts/roblox_vfx_phaseAJ_thrust_preview_root_repair.lua` if thrust VFX is missing in the customisation menu.

## Studio Export Mirror

- The Studio mirror was refreshed on 2026-06-08 after confirmed Phase AO. `roblox/studio_snapshot/hierarchy.md` is populated and the exported runtime mobile controller/input module were used as the thumbstick installer baseline.
- The current committed mirror still shows the pre-thumbstick arrow controller, so it is stale relative to installed V1. After installing V2, run the full receiver/exporter workflow again and commit the generated `roblox/exported_scripts/` and `roblox/studio_snapshot/` changes. Do not commit `docs/studio-full-export-paste.txt`.

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
- Boost modules should have `Boost`, `BoostDuration`, `BoostRecharge`, and `BoostRechargeDelay`.
- Module folder shape should stay simple and not reintroduce redundant colour-channel folders.
