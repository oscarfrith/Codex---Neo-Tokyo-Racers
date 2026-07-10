# PC Free-Roam UI Phase 1 Visual Shell

**Created:** 2026-07-10  
**Status:** Generated after Phase 0 passed `35 pass / 2 expected warnings / 0 fail`  
**Studio state:** Not installed or tested yet

## Script

Run in Roblox Studio Edit mode:

```text
scripts/roblox_ui_freeroam_pc_phase1_visual_shell.lua
```

## What It Installs

- `ReplicatedStorage.NeoTokyoRacers.Config.UI.DesktopFreeRoamHud`
- editable colour, layout, asset, and default-setting values;
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DesktopFreeRoamHudController_Active`;
- `Workspace.NeoTokyoRacersWorld.Dealership.TeleportPoints.FreeRoamHudTeleportPoint`.

The controller is PC-only and leaves touch/mobile clients on the existing UI. It suppresses the old desktop map stack, desktop exit button, and legacy desktop speed panel at runtime without editing their source. Restarting Play without the new controller restores the old runtime-generated UI.

## Included In Phase 1

- approved main PC HUD shell;
- blue cash chip with current profile polling;
- placeholder minimap composition;
- direct physics-based MPH and curved speed segments;
- top-right action row;
- real owned-vehicle car grid with category and sort dropdowns;
- existing `SpawnOwnedVehicleFromFreeRoam`, `DespawnVehicle`, garage, race-browser, and exit actions;
- shared teleport, controls, cash, and settings modal presentation;
- user-editable semantic colours from the locked design system.

## Deliberately Deferred

- moving/rotating calibrated minimap;
- final feather-mask image;
- boost telemetry bridge from the V75 driving callback;
- server-authoritative dealership teleport execution;
- real Developer Product receipts;
- settings effects and persistence;
- mobile layout changes.

The teleport `YES` button and cash pack buttons show an explicit not-yet-installed status rather than performing unsafe client-side actions.

## Required Play Test

1. Stop Play if running, run the installer in Edit mode, and start fresh Play Solo.
2. Confirm the old top-right map stack, old bottom-left speed panel, and old red Exit button are hidden on PC.
3. Confirm the new cash/minimap cluster, action row, faint controls action, and driving-only speed/exit cluster match the approved composition.
4. Enter a vehicle and confirm MPH and speed segments respond smoothly without changing driving feel.
5. Confirm the boost bar is present but remains a Phase 1 visual placeholder.
6. Open the car menu and confirm the minimap/cash cluster hides, the car button shows selected cyan, two-column cards render, and tier/rating badges use the existing E-S colours.
7. Test category and sort dropdowns.
8. Spawn/swap an owned vehicle, exit it, re-enter it, and despawn it.
9. Open Controls, Settings, Cash, and dealership teleport modals. Confirm the background dims and only one modal is active.
10. Confirm Race and Garage still open their existing systems.
11. Verify at `1280x720`, `1366x768`, and `1920x1080` if practical.
12. Confirm a mobile emulator still uses the existing mobile UI and does not create `NTR_DesktopFreeRoamHud`.
13. Check Output for errors or `Out of local registers` messages. The bootstrap is not edited, so any register error would be unexpected.

## Expected Limitations

- The placeholder minimap is decorative only.
- Boost does not yet read the real V75 boost percentage.
- Settings are visual only.
- Cash product buttons are visual only.
- Dealership teleport confirms visually but does not move the player until the server phase.

## Rollback

Use Roblox version history or disable/delete only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DesktopFreeRoamHudController_Active
```

The old PC UI is not deleted or source-patched. Start a fresh Play session after rollback.
