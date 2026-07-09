# Racing Phase 9A - Route Type And Lap Sessions

**Script:** `scripts/roblox_racing_phase9a_route_type_lap_sessions.lua`  
**Status:** Generated for Studio install/testing after Phase 8H was user-confirmed working.

## Purpose

Phase 9A starts the Gran Turismo-style time-trial flow without disturbing the newly stable reset system.

It adds:

- `RouteType = "Circuit" | "PointToPoint"` support on route definitions;
- per-event lap settings: `DefaultLapCount`, `MinLapCount`, `MaxLapCount`, `AllowInfiniteLaps`;
- race entry menu lap choice for time trials: `1-10` or `INFINITE`;
- circuit time trials that loop at the finish line and track best lap;
- one reward/result payout based on the best completed session result, not every lap;
- quit-session results when the player has completed at least one lap.

## Scope Guard

This phase intentionally does not edit:

- `Config.Racing.Rewards`;
- `Config.Racing.RouteGuide`;
- checkpoint guide visuals;
- multiplayer race rewards;
- the register-limited `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`;
- the Phase 8H respawn reset architecture.

## Config

The installer seeds missing attributes only:

```text
RaceRoutes.<RouteId>.RouteType = "Circuit"

TimeTrialCatalog.<EventId>.DefaultLapCount = 1
TimeTrialCatalog.<EventId>.MinLapCount = 1
TimeTrialCatalog.<EventId>.MaxLapCount = 10
TimeTrialCatalog.<EventId>.AllowInfiniteLaps = true
```

For point-to-point routes, set:

```text
RaceRoutes.<RouteId>.RouteType = "PointToPoint"
```

Point-to-point events always finish after one ordered route pass.

## Verification

1. Run `scripts/roblox_racing_phase9a_route_type_lap_sessions.lua` in Studio Command Bar with `MODE = "INSTALL"`.
2. Restart Play.
3. Enter a time-trial start zone and open the race menu.
4. Confirm the lap selector appears in the right-side track details.
5. Choose `2` or more laps, choose a vehicle, and start the time trial.
6. Finish lap one and confirm the timer resets for the next lap instead of ending.
7. Finish the selected lap count and confirm the result panel shows the best lap, medal, and one reward.
8. Repeat with `INFINITE`, complete at least one lap, press `QUIT RACE`, and confirm the best-lap result/prize appears after quitting.
9. Confirm `RESET TO LAST CHECKPOINT` still uses the Phase 8H clean respawn behavior.

## Risks

- The repo mirror visible to Codex before generating this script still showed the older pre-8H time-trial reset helper, while Studio was user-confirmed on 8H. The installer checks for the 8H marker and warns if it is not present, but it does not overwrite reset helpers.
- The entry menu lap selector is a guarded source patch against `RaceEntryMenuClient_Active`. If that client source has drifted, the script should stop and ask for a fresh mirror rather than guessing.
- Infinite time trials intentionally pay only once when the session ends, based on best completed lap, to avoid per-lap farming.

## Rollback

Use Roblox version history, or restore the previous isolated Racing script sources:

- `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Racing.RaceRouteDefinition`;
- `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Racing.RaceConfigReader`;
- `ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active`;
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active`.
