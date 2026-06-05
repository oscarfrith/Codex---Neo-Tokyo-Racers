# Race Events / First Race Prototype

**Created / first designed:** 2026-05-26  
**Last updated:** 2026-05-26  
**Current status:** Planned / not confirmed implemented  
**Relevant docs file:** `docs/race-events.md`  
**Relevant files to edit:** Race route folders, checkpoint scripts, race server/client scripts only.

## What The System Does

The first race event is intended to prove the core gameplay loop:

1. Enter vehicle.
2. Drive to or start a race.
3. Follow a route/checkpoints.
4. Finish the race.
5. Receive feedback/reward/progression later.

This is the most important prototype feature still needing focus because it turns the open world and vehicle controller into an actual game loop.

## Current Folder / Script Names

Exact folder/script names TBC.

Recommended future structure:

```text
Workspace
- RaceRoutes
  - FirstRace
    - Checkpoints

ReplicatedStorage
- Shared
  - RaceConfig

ServerScriptService
- RaceService.server.lua

StarterPlayer
- StarterPlayerScripts
  - RaceClient.client.lua
```

## Important Attributes / Settings

Suggested attributes for checkpoints:

```text
CheckpointIndex
RaceId
IsFinish
```

Suggested race config values:

```text
RaceId
DisplayName
Laps
CheckpointCount
RewardAmount
TargetTime
```

## Current Known Issues

- Race event system is not confirmed as implemented.
- Needs to be prioritised over extra world/detail features.
- Should stay simple for the funding prototype.

## Confirmed Working

- Core loop direction is defined.
- Vehicle driving and open world exist, so race events can build on existing systems.

## Still Needs Testing

- Checkpoint detection.
- Lap counting.
- Wrong-way handling.
- Race start/finish reliability.
- Multiplayer race behaviour.
- UI countdown/timer.
- Mobile clarity.
- Rewards/progression, if included in prototype.

## Codex Safety Notes

- Do not rewrite vehicle driving or city systems to add the first race prototype.
- Keep the first race small and testable.
- Treat recommended future paths as provisional until the Roblox hierarchy is confirmed.
