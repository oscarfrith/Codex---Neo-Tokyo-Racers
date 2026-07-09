# Racing Phase 11C - Server Grid Vehicle Spawn

**Created:** 2026-07-09  
**Script:** `scripts/roblox_racing_phase11c_server_grid_vehicle_spawn.lua`

## Purpose

Phase 11B fixed race/time-trial event pairing, but testing showed the player still needed to spawn and sit in a vehicle before racing. The race entry menu could also still trigger the old free-roam garage spawn path, which could place the car near customisation/free-roam instead of the race grid.

Phase 11C changes the ownership of race vehicle spawning:

- the client menu only sends the selected `VehicleId`;
- the racing server validates the selected owned vehicle;
- the garage server builds that selected vehicle using the existing proven vehicle builder;
- the racing server places/seats/freezes the vehicle at the time-trial start or race grid;
- the countdown/release flow remains owned by the racing services.

## What It Patches

- Adds a small `RaceVehicleSpawner` `BindableFunction` under the active garage action script.
- Patches `TimeTrialService_Active` so `StartStagedTimeTrial` spawns the selected vehicle at the start line instead of requiring the player to already be seated.
- Patches `RaceMatchmakingService_Active` so queue join validates the selected vehicle and race start spawns each racer directly on their grid slot.
- Patches `RaceEntryMenuClient_Active` so `START RACE` / `START TIME TRIAL` no longer call free-roam garage spawn actions before staging.

## Deliberate Non-Changes

- Does not edit reward config.
- Does not edit route-guide config.
- Does not edit arrow/barrier folders.
- Does not touch the register-limited main client bootstrap.
- Does not change Phase 8H reset architecture.

## Verification

1. Run the script in Studio Edit mode.
2. Restart Play so the garage binding exists before racing services request it.
3. Walk or drive into a race/time-trial start zone and open the race menu.
4. Select an owned vehicle while **not already sitting in that vehicle**.
5. Press `START TIME TRIAL`.
6. Confirm the selected vehicle appears on the start line/grid only when staging begins.
7. Confirm the old vehicle is cleared and the car does not spawn near customisation/free roam.
8. Confirm countdown, `GO`, driving, checkpoints, reset, finish, rewards, and quit still work.
9. Repeat with a 2-player local server race and confirm each selected vehicle appears on its own grid slot.

## Risks

This script has one guarded patch inside `GarageActionController_Shadow_Disabled` to expose the existing vehicle builder to racing services. That is cleaner than duplicating the vehicle builder, but it still depends on the current garage source shape. If the script reports a missing anchor, refresh the Studio mirror before another repair.

The binding changes `CurrentVehicleId` during validation so the selected race vehicle becomes the server-selected vehicle. That is intentional for now because it keeps garage/runtime profile state consistent with the vehicle being spawned.

## First Repair

If Play reports `TimeTrialService_Active:<line>: attempt to index nil with 'FindFirstChild'` inside `getRaceVehicleSpawner`, run:

```text
scripts/roblox_racing_phase11c_binding_lookup_repair.lua
```

Then restart Play. This replaces the initial helper lookup in the isolated Racing services with a direct guarded `game:GetService("ServerScriptService")` path and clearer missing-binding messages.
