# Dealership Intro Flow

**Created:** 2026-06-03  
**Status:** Phases 1-7 installed and user-confirmed working; Phase 8 generated for Studio install/testing  
**Setup script:** `scripts/roblox_dealership_intro_phase1_setup_markers.lua`
**Client install script:** `scripts/roblox_dealership_intro_phase2_install_client.lua`
**Garage gate script:** `scripts/roblox_dealership_intro_phase3_gate_garage_startup.lua`
**Preview-after-purchase script:** `scripts/roblox_dealership_intro_phase4_preview_after_purchase.lua`
**Preview orbit camera fix:** `scripts/roblox_dealership_intro_phase5_restore_preview_orbit_camera.lua`
**Vehicle exit spawn marker:** `scripts/roblox_dealership_intro_phase6_vehicle_exit_spawn_marker.lua`
**Dealership exit/reopen gate:** `scripts/roblox_dealership_intro_phase7_exit_button_reopen_gate.lua`
**Dynamic arrow tether once:** `scripts/roblox_dealership_intro_phase8_dynamic_arrow_tether_once.lua`

## Purpose

Phase 1 creates editable Studio markers for the dealership intro/startup flow. Phase 2 installs an isolated local intro client under `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro`. Phase 3 gates the active bootstrap so the full garage menu no longer auto-opens on spawn. Phase 4 delays local preview creation until cockpit purchase succeeds. Phase 5 restores orbit camera behavior after preview creation. Phase 6 adds a dedicated editable final vehicle exit spawn marker. Phase 7 adds an Exit button to the first cockpit-buy menu and lets the menu reopen only after the player leaves and re-enters the desk zone. Phase 8 replaces the static path arrows with a client-only dynamic arrow tether from the player to the desk, and persists the first desk-objective completion so returning players do not see the objective or tether again.

The user confirmed the full Phase 1-7 sequence working on 2026-06-03. These phases do not spawn vehicle preview early and do not change server purchase/profile/cash validation, driving, VFX, LOD, lighting, traffic, or mobile controls.

## Hierarchy

```text
Workspace
- NeoTokyoRacersWorld
  - Dealership
    - Spawn
      - VehicleExitSpawnPoint
    - Intro
      - Spawn
        - IntroSpawnPoint
      - Desk
        - GarageDeskTrigger
      - Camera
        - DealershipLookCameraPoint
        - GaragePreviewCameraPoint
      - Preview
        - VehiclePreviewPoint
      - Path
        - PathNode_01
        - PathNode_02
        - PathNode_03
        - PathNode_04
```

All marker parts are visible, anchored, non-colliding, non-touching, queryable, translucent, and safe to move by hand in Studio.

## Attributes

`Intro` stores the planned runtime tuning:

```text
Enabled = true
DeskActivationDistance = 5
AutoOpenGarageAtDesk = true
ShowPathArrows = true
ShowObjectiveText = true
IntroObjectiveText = "Go to the dealership desk"
DeskPromptText = "Open Garage"
OnlyRunForNewPlayers = false
CameraIntroEnabled = true
CameraIntroDuration = 1.25
PathArrowSpacing = 12
PathArrowHeightOffset = 2
Debug = false
```

Phase 8 adds these editable `Intro` attributes if missing:

```text
DynamicArrowTetherEnabled = true
DynamicArrowTetherSpacing = 9
DynamicArrowTetherMaxArrows = 18
DynamicArrowTetherMinDistance = 4
DynamicArrowTetherStartOffset = 4
DynamicArrowTetherEndOffset = 3
DynamicArrowTetherHeightOffset = 1.8
DynamicArrowTetherArrowScale = 1
DynamicArrowTetherShaftEnabled = true
DynamicArrowTetherShaftLength = 2.6
DynamicArrowTetherShaftWidth = 0.42
DynamicArrowTetherHeadLength = 1.05
DynamicArrowTetherHeadWidth = 0.36
DynamicArrowTetherArrowTransparency = 0.12
DynamicArrowTetherPulseSpeed = 2
DynamicArrowTetherColor = Color3.fromRGB(172, 255, 197)
DynamicArrowTetherHeadColor = Color3.fromRGB(255, 120, 210)
DynamicArrowTetherBeamEnabled = true
DynamicArrowTetherBeamColor = Color3.fromRGB(102, 255, 214)
DynamicArrowTetherBeamWidth = 3.5
DynamicArrowTetherBeamTransparency = 0.58
DynamicArrowTetherBeamCoreWidth = 0.8
DynamicArrowTetherBeamCoreTransparency = 0.25
PersistIntroObjectiveCompletion = true
CompletionServerMaxDistance = 20
DataStoreName = "NTR_DealershipIntro_v1"
```

`GarageDeskTrigger` stores:

```text
TriggerType = "GarageDesk"
ActivationDistance = 5
```

The setup script only adds missing expected attributes, so manual tuning survives reruns.

## Positioning

- `IntroSpawnPoint`: where a player should begin the dealership intro.
- `GarageDeskTrigger`: place at the dealership desk interaction zone.
- `DealershipLookCameraPoint`: camera view for showing the dealership space.
- `GaragePreviewCameraPoint`: camera view for the vehicle preview area.
- `VehiclePreviewPoint`: where the preview vehicle should appear.
- `PathNode_01` through `PathNode_04`: ordered guidance path from spawn to desk.
- `VehicleExitSpawnPoint`: final drivable vehicle spawn after the player finishes customisation and starts driving. Rotate the part so its forward direction faces the desired exit direction.

If `Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint` exists, new markers are placed near it. Otherwise they are placed near world origin and the script prints a warning to move them.

## Multiplayer Flow

The runtime is local-player driven. Each player reads the shared markers and attributes, sees their own objective/path/camera intro, and opens their own garage UI at the desk. The marker hierarchy is shared world data; UI, camera, prompt state, and any intro completion state should be per player.

`OnlyRunForNewPlayers = false` keeps the first implementation easy to test for every player. It can be changed later when player profile state is ready.

## Phase 2 Client Behavior

`DealershipIntroClient_Active` waits for the local player, character, and `Workspace.NeoTokyoRacersWorld.Dealership.Intro`. It reads the `Intro` attributes, shows a compact objective UI, creates local-only neon path arrows under `Workspace._NTR_ClientOnly.IntroPath`, optionally plays a short local camera intro from `DealershipLookCameraPoint`, and checks distance to `GarageDeskTrigger` every `0.15` seconds.

When the player reaches the desk, it hides its own objective UI and removes its local path arrows. With Phase 3 installed, it fires the local `OpenGarageFromIntro` BindableEvent. If Phase 3 is missing, it prints a clear warning instead of faking a garage open call.

After Phase 8, the same target client script is replaced with the dynamic tether/persistence version. It keeps the Phase 7 desk reopen loop but no longer relies on the fixed `Intro.Path.PathNode_##` markers for runtime guidance.

## Phase 3 Garage Gate

`roblox_dealership_intro_phase3_gate_garage_startup.lua` replaces the active bootstrap's startup `task.defer(init)` call with a local `OpenGarageFromIntro` `BindableEvent` under `Controllers.Intro`. It also patches `DealershipIntroClient_Active` so reaching the desk fires that event.

Expected result: the full dealership menu should not open immediately on spawn. The small intro objective/path appears first, then the full garage menu opens once when the player reaches `GarageDeskTrigger`.

## Phase 4 Preview After Purchase

`roblox_dealership_intro_phase4_preview_after_purchase.lua` is a guarded but fragile source-text patch against the active client bootstrap. It adds a `NoPreviewYet` startup state, changes the local preview root to `Workspace._NTR_ClientOnly.VehiclePreview`, and keeps `buildPreview()` as a no-op until `BuyCockpit` succeeds.

After a successful cockpit purchase/select action, the client creates the preview vehicle locally at `Intro.Preview.VehiclePreviewPoint` and drives the garage camera from `Intro.Camera.GaragePreviewCameraPoint`. The server still validates `BuyCockpit`, profile, and cash through `GarageInvoke`; Phase 4 does not touch server action logic or final drivable vehicle spawning.

## Phase 5 Preview Orbit Camera

`roblox_dealership_intro_phase5_restore_preview_orbit_camera.lua` fixes Phase 4's fixed camera behavior. `GaragePreviewCameraPoint` now initializes the first orbit view only once; after that, the existing garage camera loop should allow player rotation around the centre of the preview vehicle and slot/module selection should rotate toward the relevant area as before.

## Phase 6 Vehicle Exit Spawn

`roblox_dealership_intro_phase6_vehicle_exit_spawn_marker.lua` creates or reuses `Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint` and patches the active garage server controller so the final drivable vehicle spawns at that marker after `SpawnVehicle`.

Fallback order is:

```text
Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint
Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint
Old V56 coordinate fallback
```

The marker controls the final server-created drivable vehicle only. It does not affect the client-only preview vehicle under `Workspace._NTR_ClientOnly.VehiclePreview`.

## Phase 7 Exit and Reopen

`roblox_dealership_intro_phase7_exit_button_reopen_gate.lua` adds a styled Exit button to the first dealership cockpit-buy menu. It sits in the bottom-right right column, aligned with the right edge of the vehicle stats panel and the bottom edge of the Available Cash frame. The stats panel is shortened on the cockpit shop stage so the new control does not overlap it.

When Exit is clicked, the garage UI closes, preview/camera cleanup runs through the existing `closeGarage()` path, and the intro client arms a local reopen gate. The menu should not immediately reopen while the player is still standing inside `GarageDeskTrigger`. The player must walk out past the reset distance and then back into the desk zone.

## Phase 8 Dynamic Arrow Tether Once

`roblox_dealership_intro_phase8_dynamic_arrow_tether_once.lua` replaces the isolated `DealershipIntroClient_Active` with a Phase 8 version and adds `ServerScriptService.NeoTokyoRacers.Services.Dealership.IntroProgressService_Active`.

The client creates local-only neon arrow models under `Workspace._NTR_ClientOnly.IntroPath`. Instead of using fixed `PathNode_##` markers, those arrows are updated on `RenderStepped` between the local player's `HumanoidRootPart` and `Workspace.NeoTokyoRacersWorld.Dealership.Intro.Desk.GarageDeskTrigger`, so the line behaves like a moving tether to the desk. The arrow shape can be tuned with shaft/head length and width attributes, or `DynamicArrowTetherShaftEnabled` can be set to false for chevron-only arrows. Phase 8 can also draw a wide translucent `Beam` aura plus a thinner core beam through the arrow line.

On the first desk entry, the client clears the objective/tether, fires the existing local `OpenGarageFromIntro` hook, and tells the Phase 8 server service to mark the objective complete. The server validates that the player is near `GarageDeskTrigger`, stores completion in `DataStoreName`, and also sets a session attribute. After completion, the player can still open the dealership menu by entering the desk zone, but the objective and tether stay hidden.

In Studio, DataStore persistence needs Studio API access enabled. If DataStore calls fail, the service still hides the objective for the current session and prints a warning.

## Current Baseline

- The player starts with the lightweight intro objective/path rather than the full garage menu.
- After Phase 8, new players see a dynamic arrow tether from their character to the desk instead of fixed marker-node arrows.
- The full cockpit-buy menu opens when the local player enters `GarageDeskTrigger`.
- The first menu has an Exit button aligned to the stats/cash UI; exiting closes the menu and requires leaving/re-entering the desk zone before reopening.
- Once the desk objective is completed and persisted, the objective/tether do not appear again after rejoining, but the desk zone still opens the menu.
- The preview vehicle is client-only under `Workspace._NTR_ClientOnly.VehiclePreview`.
- The preview is delayed until cockpit purchase/select succeeds.
- `GaragePreviewCameraPoint` initializes the first preview view; normal orbit and module focus behavior continue after that.
- The final server-created drivable vehicle spawns from `Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint`.

## Known Risks

- StreamingEnabled may delay distant marker availability unless the runtime waits safely.
- Camera intro logic could fight driving camera assist if it is not gated carefully.
- Phase 3 patches a specific bootstrap startup shape. If the active bootstrap changes and the patch script cannot find `task.defer(init)`, paste the script output back before attempting manual edits.
- Phase 4 is also a fragile source-text patch. It should abort if the active bootstrap no longer has the expected preview, camera, init, or cockpit purchase source shapes.
- Phase 5 expects the Phase 4 fixed-camera helper shape. If Phase 4 changes, rerun only after reviewing the patch output.
- Phase 6 is a guarded source-text patch against `GarageActionController_Shadow_Disabled`. If the active server spawn shape changes, it should abort before changing Studio.
- Phase 7 is a guarded source-text patch against the active bootstrap and intro client. It relies on the Phase 3 `OpenGarageFromIntro` hook and Phase 2/3 intro client run-loop shape.
- Phase 8 replaces the isolated intro client source instead of patching the active bootstrap. It still depends on the Phase 3/7 local `OpenGarageFromIntro` hook being present.
- DataStore persistence requires published experience/API access during Studio testing; otherwise completion may be session-only.
- The server completion remote validates desk proximity, but the objective is low-stakes client guidance rather than purchase/profile security.
- Marker parts are placeholders and need manual Studio positioning before runtime behavior is patched.
- Desk interaction must not globally open the garage for every player in multiplayer.
- The Phase 3 hook is local-player only because both scripts run inside the player's cloned client scripts.
- Preview visibility should be local-only. In multiplayer testing, each client should see only their own `Workspace._NTR_ClientOnly.VehiclePreview`.
- Final drivable vehicle spawn is server-created and visible to other players as normal.

## Testing Checklist

1. Run `scripts/roblox_dealership_intro_phase1_setup_markers.lua` in Studio Edit mode.
2. Confirm `Workspace.NeoTokyoRacersWorld.Dealership.Intro` exists.
3. Confirm all nine marker parts exist and are visible.
4. Move markers into final dealership positions.
5. Rerun the setup script and confirm positions are preserved.
6. Rerun `scripts/roblox_dealership_intro_phase0_audit.lua`.
7. Confirm Phase 0 reports the intro path and planned marker objects as present.
8. Do a short Play test and confirm no garage/UI/driving behavior changed yet.
9. Run `scripts/roblox_dealership_intro_phase2_install_client.lua`.
10. In Play Solo, confirm the objective UI and local path arrows appear.
11. Walk to the desk trigger and confirm the objective/path visuals clear.
12. Paste any `[NTR Dealership Intro Client]` warnings back into Codex.
13. Run `scripts/roblox_dealership_intro_phase3_gate_garage_startup.lua`.
14. In a fresh Play Solo session, confirm the full garage menu does not open on spawn.
15. Walk to the desk trigger and confirm the full garage menu opens once.
16. Run `scripts/roblox_dealership_intro_phase4_preview_after_purchase.lua`.
17. In Play Solo, confirm no preview vehicle appears when the garage first opens.
18. Buy/select a cockpit and confirm the preview appears at `VehiclePreviewPoint`.
19. Confirm the camera moves to `GaragePreviewCameraPoint`.
20. In a two-player local server test, confirm preview vehicles stay client-local.
21. Run `scripts/roblox_dealership_intro_phase5_restore_preview_orbit_camera.lua`.
22. Confirm the preview camera can rotate around the vehicle centre and module selection still rotates toward selected areas.
23. Run `scripts/roblox_dealership_intro_phase6_vehicle_exit_spawn_marker.lua`.
24. Move and rotate `Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint`.
25. Complete customisation and press Start Driving.
26. Confirm the final drivable vehicle spawns at `VehicleExitSpawnPoint` and faces its forward direction.
27. Run `scripts/roblox_dealership_intro_phase7_exit_button_reopen_gate.lua`.
28. Open the first dealership cockpit menu at the desk.
29. Confirm the Exit button is bottom-right, aligned with the stats right edge and cash bottom edge, with no overlap on PC or mobile sizes.
30. Click Exit and confirm the menu closes and does not immediately reopen.
31. Walk away from the desk trigger, then walk back in and confirm the first dealership menu reopens.
32. Run `scripts/roblox_dealership_intro_phase8_dynamic_arrow_tether_once.lua`.
33. In a fresh Play Solo session with an incomplete player, confirm the objective appears and the dynamic arrow tether follows the player to `GarageDeskTrigger`.
34. Reach the desk and confirm the objective/tether disappear and the dealership menu opens.
35. Exit, walk away, and re-enter the desk zone; confirm the menu still opens but the objective/tether do not return.
36. Rejoin with DataStore persistence available and confirm the objective/tether stay hidden while desk entry still opens the menu.
