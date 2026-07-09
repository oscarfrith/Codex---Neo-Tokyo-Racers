# Racing Phase 11Q Time Trial Finish/Exit Handoff Repair

**Created:** 2026-07-10  
**Script:** `scripts/roblox_racing_phase11q_time_trial_finish_exit_handoff_repair.lua`  
**Type:** Guarded isolated-client repair

## Purpose

Phase 11Q repairs a time-trial finish/exit regression reported after Phase 11P testing.

The refreshed mirror showed Phase 11P installed, but the important root issue was not the result text. Race/time-trial start uses the main client `FreeRoamVehicleSpawned` handoff to start the driving controller, but time-trial finish/result exit did not fire the matching `FreeRoamVehicleExited` handoff. That can leave the main driving HUD/controller thinking the player is still driving after the server destroys the race vehicle and teleports the character.

## What It Changes

Patches only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active
```

It:

- rolls back the unconfirmed Phase 11P result-copy polish to the previous result UI text;
- adds a tiny local `FreeRoamVehicleExited` handoff helper inside the isolated race entry client;
- fires that handoff when a time trial finishes;
- fires it again when the player exits the result panel;
- fires it when `TimeTrialEnded` is received.

## What It Does Not Change

- Time-trial timing.
- PB recording/storage.
- Rewards or reward config.
- Route-guide config.
- Arrow/session asset visibility or collision.
- VFX/name-tag visibility.
- Matchmaking.
- Driving physics.
- DataStore settings.
- Global/friends leaderboards.
- Main bootstrap.

## How To Run

Run in Studio Command Bar, Edit mode:

```text
scripts/roblox_racing_phase11q_time_trial_finish_exit_handoff_repair.lua
```

Restart Play after installing.

## Verification

1. Finish a time trial and confirm the original result panel appears.
2. Confirm the main vehicle driving HUD/control state clears when the result appears.
3. Press result-panel `EXIT`.
4. Confirm the player returns to the route start/teleport point.
5. Confirm the vehicle HUD is gone.
6. Confirm the Race browser teleport works after exiting.
7. Confirm the player can enter/start another race or time trial.
8. Confirm retry still starts a fresh staged time trial.

## Risk Notes

This is a guarded source patch against the isolated race entry client. If Studio reports a missing source anchor, stop and inspect the live mirror before writing another patch.

Phase 11P should not be treated as a working baseline. Keep it as history only unless result-panel polish is redesigned as an isolated result client or canonical replacement later.

## Rollback

Use Roblox Studio version history, or restore the last confirmed `RaceEntryMenuClient_Active` source before Phase 11P/11Q.

Do not roll back rewards, arrows, VFX, matchmaking, or racing services for this client handoff repair.
