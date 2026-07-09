# Racing Phase 11O Time Trial PB Board V2

**Created:** 2026-07-10  
**Script:** `scripts/roblox_racing_phase11o_time_trial_pb_board.lua`  
**Type:** Isolated Studio Command Bar feature phase

## Purpose

Phase 11O adds a small local-player "My Time Trial Bests" board beside the race entry flow. V2 keeps that board synced to the entry menu lifecycle, so pressing `EXIT` without starting a race/time trial also hides the PB board.

This follows the confirmed Phase 11N PB readout work. It is still prototype-safe and does not add global/friends leaderboards yet.

## What It Changes

- Creates/replaces one isolated LocalScript:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RacePersonalBestBoardClient_Active
```

- Listens for `OpenRaceEntry`.
- Resolves the paired time-trial event for the route.
- Calls Phase 11N's existing server action:

```text
GetTimeTrialPersonalBest
```

- Shows local PB rows for tiers `E`, `D`, `C`, `B`, `A`, and `S`.
- Caches lookups per event+tier.
- Updates the cache from `TimeTrialFinished` payloads so newly set PBs appear without restarting.
- Hides automatically when the race/time-trial session starts or ends.
- Hides automatically when the race entry menu is closed without starting.
- Includes a small close button for manual hiding.

## What It Does Not Change

- Global OrderedDataStore leaderboards.
- Friends leaderboards.
- Ghosts or replay data.
- Rewards or reward config.
- Route-guide config.
- Arrow/session asset visibility or collision.
- Matchmaking.
- VFX/name-tag visibility.
- Driving physics.
- Main bootstrap.
- Existing race entry menu source.

## How To Run

Run in Studio Command Bar, Edit mode:

```text
scripts/roblox_racing_phase11o_time_trial_pb_board.lua
```

Restart Play after installing.

## Verification

1. Open the race entry menu from a race or time-trial start zone.
2. Confirm a small `MY TIME TRIAL BESTS` board appears beside the entry menu.
3. Confirm tier rows show `PB --` before any time exists, or `PB <time> / <medal>` for saved/session PBs.
4. Press `EXIT` without starting and confirm the PB board closes with the entry menu.
5. Reopen the entry menu, start a time trial, and confirm the board hides when staging begins.
6. Finish a time trial, reopen the entry menu, and confirm the updated PB appears.
7. Confirm the Phase 11N vehicle-card PB readouts still work.
8. Confirm arrows, rewards, VFX hiding, race queue, and normal time-trial flow still behave as before.

## Notes

This is intentionally not a public leaderboard. It gives players useful competitive context while avoiding DataStore/global ranking scope until saved PBs are tested across rejoin.

## Rollback

Disable or delete:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RacePersonalBestBoardClient_Active
```

No other scripts or config need to be restored.
