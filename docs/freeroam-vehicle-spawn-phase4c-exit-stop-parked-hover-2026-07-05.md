# Free Roam Vehicle Spawn Phase 4C - Exit Stops Driving, Parked Hover Continues

Prepared: 2026-07-05

Script:

- `scripts/roblox_freeroam_vehicle_spawn_phase4c_exit_stop_parked_hover.lua`

## Root Cause

Phase 4/4B made `EXIT VEHICLE` unseat the player and fixed the remote path, but the active client driving loop was still running after the exit. That left the camera on the vehicle, kept the driving HUD/controls visible, and allowed the player to keep steering/throttling the car while outside it.

Calling the existing `stopDriving()` directly fixes HUD/input/camera state, but it also removes the client hover forces. Phase 4C therefore separates the behaviours:

- `stopDriving()` handles player control shutdown.
- A new isolated parked-hover client keeps the owned parked vehicle floating without accepting driving input.

## What The Repair Does

- Replaces `FreeRoamVehicleExitButton_Active` so clicking exit fires a local `FreeRoamVehicleExited` bindable event before/after the server `ExitVehicle` call.
- Patches the main bootstrap to listen for `FreeRoamVehicleExited`, call `stopDriving()`, hide the driving HUD/controls, unseat the player, and return the camera subject to the humanoid.
- Installs `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.FreeRoamParkedHoverController_Active`.
- The parked-hover controller watches the owned spawned vehicle when `ParkedShowcase=true` and `DriverUserId=nil`, then applies hover/alignment forces only. It does not apply throttle, steering, drift, boost, or braking.
- The parked-hover controller also detects prompt seating and fires the existing `FreeRoamVehicleSpawned` handoff so prompt re-entry starts the local driving loop again.
- Hides the free-roam car pop-out automatically after a successful cockpit-card spawn.

## Verification

Restart Play after running the repair:

1. Open the free-roam car menu and click an owned cockpit card.
2. The car menu should close automatically after the successful spawn.
3. Drive forward, then click `EXIT VEHICLE`.
4. The driving HUD and mobile/keyboard drive controls should disappear.
5. The camera should return to the player.
6. The player should be stationary beside the car.
7. The car should keep hovering and keep its existing movement, but should no longer respond to player steering/throttle until re-entered.
8. Re-enter with the `E` / touch prompt and confirm driving resumes.

## Risk

The parked-hover controller is intentionally client-side and owner-scoped for this first pass. It keeps the owner's parked showcase vehicle stable without adding broad server physics. If multiplayer meet-up observers need identical parked-hover fidelity later, promote this into a small server/ownership-aware parked vehicle service.
