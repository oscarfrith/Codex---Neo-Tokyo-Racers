# Racing Phase 8B Multiplayer Race Drive Handoff Repair

**Script:** `scripts/roblox_racing_phase8b_multiplayer_race_drive_handoff_repair.lua`  
**Status:** Generated after Phase 8 queue worked but race vehicles were not drivable at `GO`  
**Scope:** Multiplayer race release handoff only

## Root Cause

Phase 8's queue and staging flow worked, but multiplayer race release did not yet perform the same client-side handoff that Phase 3E added for time trials.

At `RaceStarted`, the server unanchored/prepared the vehicles, but the client did not re-fire the existing local `FreeRoamVehicleSpawned` bridge or request streaming around the active route. That meant the local driving controller/HUD/VFX path could remain detached, making both cars stop hovering and feel undrivable. The missing stream request also explains why nearby map content could appear to switch off or reload around the race start.

Phase 8B also changes race staging freeze to anchor only the vehicle root while zeroing all part velocity. On release it still unanchors every `BasePart`, but it no longer sets every part anchored during staging. This reduces the chance of a vehicle assembly being left in a dead anchored state if release/handoff timing is imperfect.

## What It Patches

- `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceMatchmakingService_Active`
  - safer root-only staging freeze;
  - full unanchor still happens on release.
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceQueueClient_Active`
  - requires `RaceRouteDefinition`;
  - requests streaming around the next race gate when `RaceStarted` arrives;
  - fires the existing `Controllers.UI.FreeRoamVehicleSpawned` bridge immediately and again after `0.25` seconds.

It does not edit reward config, route-guide config, checkpoints, payout logic, driving physics, VFX assets, or the register-limited main bootstrap.

## Verification

Use local server with 2 players:

1. Run `scripts/roblox_racing_phase8b_multiplayer_race_drive_handoff_repair.lua` in Edit mode.
2. Restart a 2-player local server.
3. Queue both players into the same race.
4. Confirm both vehicles stage and remain frozen during countdown.
5. At `GO`, confirm both vehicles hover and are immediately drivable.
6. Confirm map/route assets stay loaded around the start.
7. Finish or cancel the race, then run a solo time trial to confirm the Phase 3E time-trial handoff still works.

## Rollback

Restore these two scripts from Roblox version history:

- `RaceMatchmakingService_Active`
- `RaceQueueClient_Active`

Or disable/delete Phase 8 matchmaking objects if reverting the whole multiplayer MVP.
