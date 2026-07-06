# Drive-In Customisation Phase 1

Prepared: 2026-07-06

Script:

- `scripts/roblox_drive_in_customisation_phase1.lua`
- Register-limit repair, if needed: `scripts/roblox_drive_in_customisation_phase1_register_limit_repair.lua`

## Goal

Add a driving-only customisation entry zone:

- the zone appears locally only while the player is driving their own vehicle;
- entering the zone starts a `3` second countdown;
- leaving the zone, exiting/despawning, or opening another menu cancels the countdown;
- completing the countdown opens the garage/customisation UI directly to `Build Modules` for the vehicle instance being driven.

## Installed Objects

World marker:

- `Workspace.NeoTokyoRacersWorld.Dealership.Customisation.DriveInCustomisationTrigger`
- Tagged with `NTR_DriveCustomisationZone`
- Invisible, anchored, non-colliding, non-touching, non-querying
- Move/resize this part in Studio to place the drive-in bay.

Client:

- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DriveInCustomisationZoneClient_Active`

Bootstrap patch:

- Adds `OpenDrivingVehicleCustomisation` bindable event under `Controllers.Intro`
- Refreshes the active garage profile
- Despawns the currently driven live vehicle
- Stops driving/camera/HUD state
- Opens customisation mode directly into `ModuleShop`

Config:

- `ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DriveInCustomisation`
- `ReplicatedStorage.NeoTokyoRacers.Config.UI.DriveInCustomisation`

## Important Behaviour

The live driven vehicle is despawned before the Build Modules UI opens. This avoids editing a vehicle instance while a matching live car continues outside the garage. The normal Start Driving / free-roam spawn path should create the updated vehicle after customisation.

The countdown UI is a local ScreenGui so it stays readable on mobile. The visible zone is also client-only, so the drive-in area only appears for a player who is currently driving.

The active client bootstrap is register-limited. Any future drive-in/customisation patch should avoid adding top-level local helpers to `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`; use isolated controllers/modules plus the smallest possible table-backed event bridge.

## Verification

1. Move `DriveInCustomisationTrigger` to the desired bay location in Studio.
2. Start Play and spawn/enter a vehicle.
3. Confirm the local zone visual appears only while driving.
4. Drive into the zone and confirm text counts down: `ENTERING CUSTOMISATION IN 3`, `2`, `1`.
5. Drive out before the countdown finishes; it should cancel.
6. Drive in and stay for the full countdown.
7. The live vehicle should despawn, driving HUD/controls should stop, and Build Modules should open for the driven vehicle.
8. Test on mobile/emulator that the countdown is readable and does not block drive controls.

## Risks

The only fragile source patch is the bootstrap handoff that opens `ModuleShop` directly. If it fails to find its source anchors, refresh the Studio mirror before another patch. The isolated zone client and marker setup are canonical replacements and safe to rerun.

If the first install causes `Out of local registers when trying to allocate okController`, run the register-limit repair script above. It replaces the first local-helper handoff with a table-backed bridge.
