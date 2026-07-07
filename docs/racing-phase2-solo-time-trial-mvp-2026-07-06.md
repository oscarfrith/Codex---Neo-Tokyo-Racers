# Racing Phase 2 Solo Time Trial MVP

**Created:** 2026-07-06  
**Script:** `scripts/roblox_racing_phase2_solo_time_trial_mvp.lua`  
**Status:** Installed/tested by user and reported working well. Superseded as the next baseline by the planned Phase 3 entry menu/session flow.  

## Purpose

Phase 2 installs the first playable solo time-trial loop on top of the placed `ShiftedCanalSprint` route. It is intentionally isolated and does not add rewards, multiplayer matchmaking, leaderboard persistence, or free-roam Race panel browsing yet.

The user confirmed the Phase 2 loop is working well. The next racing phase should replace the instant-start prompt with a themed race entry menu, owned-vehicle selection, staged start-line teleport, countdown, and first same-server race-session separation.

It installs:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Racing
  RaceRequest
  RaceEvent

ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Racing
  RaceRouteDefinition
  RaceConfigReader

ServerScriptService.NeoTokyoRacers.Services.Racing
  TimeTrialService_Active

StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing
  RaceClient_Active
```

It also creates an empty route `ArrowMarkers` folder if one is missing, so route arrow assets have a future home without changing gameplay yet.

## What It Does

- Adds a `ProximityPrompt` to `TimeTrialStartZone`.
- Requires the player to be driving their own runtime vehicle.
- Requires the vehicle to have a server-written `PerformanceTier`.
- Starts a server-owned countdown.
- Tracks ordered checkpoint touches on the server.
- Treats `FinishLine` as the final route gate even if its scaffold `CheckpointIndex` is stale.
- Shows a local HUD timer, checkpoint progress, and visible next-gate marker.
- Prints/sends a finish result with elapsed time.
- Does not grant cash or store personal bests yet.

## Why This Is Future-Proofed

The runtime reads routes through `RaceRouteDefinition` and `RaceConfigReader`, not hardcoded Workspace traversal in each service. That keeps the route source flexible:

```text
Official Studio route now
Serialized player-created route later
Runtime materialized route during a private/friends/public race later
```

Future player-created races should feed the same route definition shape into the checkpoint and HUD code.

## Run Order

1. Open Studio in Edit mode.
2. Paste and run:

```text
scripts/roblox_racing_phase2_solo_time_trial_mvp.lua
```

3. Leave:

```lua
local MODE = "INSTALL"
```

4. Restart Play after install.

Optional read-only check:

```lua
local MODE = "AUDIT"
```

## Verification

In Play:

1. Spawn/enter your vehicle.
2. Drive the vehicle into `TimeTrialStartZone`.
3. Press `E` or tap the mobile prompt.
4. Confirm the HUD shows countdown, then timer.
5. Drive through checkpoints in order.
6. Confirm the next checkpoint/finish marker advances.
7. Cross the finish line.
8. Confirm the HUD shows `FINISHED` and an elapsed time.

Expected non-goals:

- no rewards;
- no personal best persistence;
- no race matchmaking;
- no bronze/silver/gold/platinum medal result yet;
- no polished arrow assets yet.
- no themed track image/map menu yet;
- no owned vehicle selection yet;
- no separated race instance/participant visibility layer yet.

## Rollback

Delete:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Racing
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Racing
ServerScriptService.NeoTokyoRacers.Services.Racing
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing
```

Leave `Workspace.NeoTokyoRacersWorld.RaceRoutes.ShiftedCanalSprint` and `ReplicatedStorage.NeoTokyoRacers.Config.Racing` unless you are intentionally removing the Phase 1 route/config scaffold too.

## After Confirmation

Refresh the Studio mirror after this works in Play because the install changes scripts, remotes, hierarchy, and route attributes.

Next phase should add:

- themed entry menu from the start-zone prompt;
- track image/map display and `START RACE` / `START TIME TRIAL` / `EXIT` buttons;
- owned vehicle selection using the dealership/customisation card style;
- teleport/spawn selected vehicle to the start line, freeze, countdown, then release;
- participant-only route arrows/assets and first same-server visibility/collision separation;
- defer medals/rewards/personal bests until after this entry/session flow is stable.
