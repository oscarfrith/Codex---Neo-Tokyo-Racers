# Racing Phase 8 Open-Category Multiplayer Race MVP

**Script:** `scripts/roblox_racing_phase8_open_category_multiplayer_race_mvp.lua`  
**Status:** Generated for Studio install/testing  
**Scope:** First multiplayer race queue, staging, countdown, placement, and race HUD

## Purpose

Phase 8 adds the first multiplayer race loop while keeping the launch matchmaking model simple:

- one open queue per race `EventId`;
- no tier-bracketed multiplayer queues;
- selected owned vehicle spawns before queue join;
- queued racers stage on the route `SpawnGrid`;
- server-owned countdown and race timing;
- ordered checkpoints and finish placement;
- lightweight race queue/result UI.

This phase intentionally does **not** edit `Config.Racing.Rewards`, reward multipliers, time-trial rewards, route-guide tuning values, checkpoint timing, or driving/VFX systems.

## What It Installs

- `ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Racing.RaceQueueRequest`
- `ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Racing.RaceQueueEvent`
- `ReplicatedStorage.NeoTokyoRacers.Config.Racing.Matchmaking`
- `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceMatchmakingService_Active`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.StartRaceQueueRequest`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceQueueClient_Active`
- a guarded patch to `RaceEntryMenuClient_Active` so `START RACE` opens owned vehicle selection and joins the queue
- an optional guarded patch to `RaceRouteGuideClient_Active` so route guidance also listens to race events

If the optional route-guide patch cannot find its exact source anchor, the installer warns and continues. The queue/race MVP can still be tested, but race route guidance may remain time-trial-only until the mirror is refreshed and the guide patch is repaired.

## Config

Editable values live under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.Matchmaking
```

Defaults:

- `DefaultMinPlayers = 2`
- `DefaultMaxPlayers = 6`
- `QueueTimeoutSeconds = 25`
- `CountdownSeconds = 3`
- `RaceFinishTimeoutSeconds = 300`
- `AllowSoloRaceDebug = false`

For solo Studio smoke testing, temporarily set `AllowSoloRaceDebug` to `true`, then set it back to `false` before normal testing.

Race event `MinPlayers` / `MaxPlayers` attributes can override the defaults if they are set above `1`. This avoids old placeholder `1` values accidentally turning public multiplayer races into solo races.

## Verification

Use a local server test with at least two players:

1. Run `scripts/roblox_racing_phase8_open_category_multiplayer_race_mvp.lua` in Edit mode.
2. Restart Play as a local server with 2 players.
3. On both players, use the free-roam Race browser or the physical race zone to open the race entry menu.
4. Press `START RACE`.
5. Choose an owned vehicle.
6. Confirm each player joins the open-category queue.
7. Confirm the race starts when enough players are queued or the queue timeout completes.
8. Confirm both vehicles stage on separate `SpawnGrid` points and remain frozen during countdown.
9. Confirm `GO` releases both vehicles.
10. Drive through checkpoints and finish.
11. Confirm placement appears and route guidance still points to the next gate.

Also verify time trials still work:

1. Start a normal time trial from the same entry menu.
2. Confirm vehicle selection, staging, countdown, checkpoints, results, and payout still work.

## Known Limits

- If the queue works but cars stop hovering or are not drivable at `GO`, run `scripts/roblox_racing_phase8b_multiplayer_race_drive_handoff_repair.lua`. That repair adds the missing multiplayer race-start driving/streaming handoff and safer root-only staging freeze.
- Phase 8 does not grant race cash rewards yet. Placement reward grants should come after this queue/race loop is tested and after idempotent race-run reward records are added.
- Same-server physical isolation is still the MVP layered approach: race participants get visibility filtering and shared `RaceInstances` state, but fully separated route pockets/collision groups are still a later hardening phase.
- Queue state is per-server memory only.
- If the exact source patches fail, refresh the Studio mirror before another repair. The patch targets isolated Racing scripts, not the register-limited bootstrap.

## Rollback

Disable or delete:

- `RaceMatchmakingService_Active`
- `RaceQueueClient_Active`
- `RaceQueueRequest`
- `RaceQueueEvent`
- `StartRaceQueueRequest`

Then restore `RaceEntryMenuClient_Active` from Roblox version history or rerun the last confirmed pre-Phase-8 racing installer.
