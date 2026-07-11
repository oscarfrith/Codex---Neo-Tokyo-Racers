# PC Free-Roam UI Phase 4A Dealership Teleport

Date: 2026-07-11  
Status: Installed and confirmed working; current PC free-roam UI baseline

## Studio script

Run in Edit mode:

`scripts/roblox_ui_freeroam_pc_phase4a_dealership_teleport.lua`

## Architecture

Phase 4A preserves the confirmed Phase 3D HUD and installs an isolated server-authoritative teleport path:

- `ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.UI.FreeRoamHudTeleportInvoke`
- `ServerScriptService.NeoTokyoRacers.Services.UI.FreeRoamHudTeleportService_Active`
- `ReplicatedStorage.NeoTokyoRacers.Config.Runtime.FreeRoamHudTeleport`

It does not patch the register-limited bootstrap, large garage controller, driving controller, racing services, VFX, or payment systems.

## Behaviour

- `NO` closes the existing modal without changing player state.
- `YES` calls `TeleportToDealership` on the isolated service.
- The server validates the editable `Workspace.NeoTokyoRacersWorld.Dealership.TeleportPoints.FreeRoamHudTeleportPoint`.
- Active race/race-frozen vehicles are rejected.
- The player is unseated and their velocity is cleared.
- Only the requesting player's owned runtime vehicle is marked inactive and destroyed.
- The character is moved to the configured marker with a height/forward offset.
- The existing `FreeRoamVehicleExited` client handoff clears driving UI/camera state after server success.
- A cooldown and structured toast feedback cover repeated requests and failures.

## Editable configuration

Under `Config.Runtime.FreeRoamHudTeleport`:

- `CooldownSeconds = 2`
- `HeightOffset = 4`
- `ForwardOffset = 0`
- `UnseatSettleSeconds = 0.08`
- `VehicleDespawnDelaySeconds = 0.12`
- `CharacterUnfreezeDelaySeconds = 0.18`

Move `FreeRoamHudTeleportPoint` in Studio to change the arrival position and facing direction.

## Confirmed verification

The user confirmed Phase 4A working on 2026-07-11, refreshed the full Studio mirror, and pushed Git. The mirror contains the Phase 4A client marker, remote, config hierarchy, and enabled isolated server service.

Future regression checks:

1. Stop Play, run Phase 4A, and restart Play.
2. Open the dealership modal and press `NO`; confirm nothing else happens.
3. On foot, press `YES`; confirm the player arrives above the marker and receives a success toast.
4. While driving, press `YES`; confirm the vehicle is destroyed, driving HUD/camera state clears, and the player arrives safely.
5. Trigger twice rapidly and confirm the second request reports cooldown rather than moving again.
6. During an active race/time trial, confirm the service rejects the request.
7. Temporarily move the marker and confirm the new position/orientation is used.
8. Confirm Buy More uses the same modal/action and normal car-menu spawn/despawn remains unchanged.

## Risks and rollback

The server intentionally destroys the current runtime vehicle on success. It does not change owned profile data. Roll back the client by rerunning `scripts/roblox_ui_freeroam_pc_phase3d_image_only_map_markers.lua`; disable `FreeRoamHudTeleportService_Active` if a complete Phase 4A rollback is required.

The Studio mirror was refreshed after acceptance. Later free-roam phases are intentionally deferred while race/time-trial UI work proceeds.
