# Free Roam Vehicle Spawn Phase 4B - Remote And Drive Handoff Repair

Prepared: 2026-07-05

Script:

- `scripts/roblox_freeroam_vehicle_spawn_phase4b_remote_handoff_repair.lua`

## Root Cause

The Phase 4 exit-button LocalScript waited for the obsolete remote:

- `ReplicatedStorage.HOVER_RACING_V2_GarageAction`

The live garage action remote is:

- `ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage.GarageInvoke`

That wait caused the exit-button client to hang during startup, so the bottom-centre `EXIT VEHICLE` button never appeared.

The first-spawn `spawned but not hovering/driving` symptom also exposed an older design issue: the main bootstrap still had an automatic walk-up re-entry loop that could start driving after a later proximity/respawn path. Free-roam cockpit-card spawning needed its own explicit drive handoff instead of relying on that fallback.

## What The Repair Does

- Canonically replaces `FreeRoamVehicleExitButton_Active` with the correct `GarageInvoke` remote path.
- Updates the exit button owner lookup so it can find the top-level spawned vehicle even if the driver seat is inside a cockpit sub-model.
- Canonically replaces `VehicleAccessPromptService_Active` with the same robust owner lookup.
- Adds a `FreeRoamVehicleSpawned` `BindableEvent` under `StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI`.
- Makes the free-roam cockpit-card spawn success fire that event.
- Makes the main bootstrap listen for that event and call the existing `startDriving()` path.
- Disables the old automatic distance-based `ReEnterVehicle` loop so entry is prompt-only.

## Verification

Restart Play after running the repair:

1. Click an owned cockpit card in the free-roam car menu.
2. The first spawn should immediately hover and drive without needing a despawn/respawn.
3. The bottom-centre `EXIT VEHICLE` button should appear while seated.
4. Clicking `EXIT VEHICLE` should leave the car spawned and park the player beside it.
5. Walking into the hidden seat should not auto-enter.
6. The `E` / touch prompt should re-enter the parked vehicle.
