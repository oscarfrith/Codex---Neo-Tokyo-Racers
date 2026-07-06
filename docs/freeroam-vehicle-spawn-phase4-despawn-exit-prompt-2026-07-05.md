# Free Roam Vehicle Spawn Phase 4 - Despawn, Parked Exit, Enter Prompt

Prepared: 2026-07-05

Script:

- `scripts/roblox_freeroam_vehicle_spawn_phase4_despawn_exit_prompt.lua`

## Goal

Separate the free-roam vehicle actions into clear behaviours:

- `DESPAWN` in the free-roam car menu destroys the current spawned vehicle and unseats/moves the player first.
- `EXIT VEHICLE` is a small bottom-centre driving-only button that parks the player 10 studs left of the driver seat and leaves the car in the world.
- Parked cars can be re-entered through an owner-only `ProximityPrompt` (`E` on keyboard, touch prompt on mobile).
- Clicking a free-roam cockpit card still auto-spawns and auto-seats the player through Phase 3.

## Implementation Shape

This phase intentionally keeps most new behaviour isolated:

- It patches the active garage server only for the `ExitVehicle` semantics and a new `DespawnVehicle` action.
- It disables driver-seat touch auto-entry (`CanTouch=false`) so parked vehicles are entered through the prompt instead of by bumping into the hidden seat.
- It patches the free-roam car-panel `DESPAWN` callback to call `DespawnVehicle`.
- It installs `ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehicleAccessPromptService_Active` as an isolated prompt watcher for spawned player vehicles.
- It installs `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.FreeRoamVehicleExitButton_Active` as an isolated driving-only exit button.

## Verification

In Play mode:

1. Open the free-roam car menu and click an owned cockpit card. It should spawn the vehicle and seat the player.
2. While driving, confirm the small bottom-centre `EXIT VEHICLE` button appears.
3. Click `EXIT VEHICLE`. The player should leave the seat and appear about 10 studs left of the driver seat; the car should remain spawned.
4. Walk back to the car and use the `E` / touch enter prompt. The player should re-enter the same vehicle.
5. Open the free-roam car menu and click `DESPAWN`. The player should be unseated/moved if needed and the car should be destroyed.

## Risks

The parked car sets `DriveReady=true`, `DriverUserId=nil`, `ParkedShowcase=true`, and `EngineVFXActive=true`. Existing thrust VFX reads `DriveReady`, so engine visuals should continue. If hover physics still winds down while unoccupied, add a small parked-hover keeper as the next isolated vehicle service rather than changing the spawn/click system again.

The garage server/free-roam UI parts are guarded text patches, so if either source anchor has drifted the script will stop and ask for a fresh mirror/inspection instead of guessing.
