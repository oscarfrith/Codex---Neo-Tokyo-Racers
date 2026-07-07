# Racing Phase 7 Free-Roam Race Browser

**Script:** `scripts/roblox_racing_phase7_free_roam_race_browser.lua`  
**Status:** Installed/tested by user visually, then superseded by Phase 7B teleport-to-start behavior  
**Scope:** Free-roam Race tile browse panel and local start-zone waypoint  

## Purpose

Phase 7 turns the free-roam `RACE` tile from a placeholder into a browse surface before multiplayer matchmaking. It keeps physical start-zone entry as the real race/time-trial entry method, but lets the player:

- browse current time trials and races;
- see route name, checkpoints, arrow count, recommended tier/open race category, and event `BaseReward`;
- view recommended-tier time-trial medal targets;
- set a local waypoint above the correct start zone;
- clear that waypoint.

After Phase 7 was tested, the menu was reported looking good, but waypointing was superseded by Phase 7B. The preferred current behavior is `TELEPORT TO START` via `scripts/roblox_racing_phase7b_race_browser_teleport.lua`.

The player still drives to the start zone and presses `E` / taps the prompt to open the Phase 3 race entry menu. This avoids a second direct-start path and keeps server validation concentrated in the existing racing service.

## What It Installs

- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceBrowserClient_Active`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OpenRaceBrowser`
- a tiny Race tile bridge inside `FreeRoamNavController_Active`
- `ReplicatedStorage.NeoTokyoRacers.Config.UI.RaceBrowser` visual waypoint tuning values

Important: this phase does **not** edit `Config.Racing.Rewards`, `Config.Racing.RouteGuide`, event reward multipliers, checkpoint visuals, timing, or payout logic. It only reads event `BaseReward` for display.

## Verification

1. Run the script in Edit mode with `MODE = "INSTALL"`.
2. Restart Play.
3. Click/tap the free-roam `RACE` tile.
4. Confirm the Race browser opens with `TIME TRIALS` and `RACES` tabs.
5. Select `Shifted Canal Sprint` or another event and press `TRACK START`.
6. Confirm a local waypoint appears above the event start zone and updates distance.
7. Drive to the start zone, press `E` / tap, and confirm the existing Phase 3 entry menu still opens.
8. Start a time trial and confirm countdown, route guide, results, and rewards still work.
9. Confirm `Config.Racing.Rewards.TimeTrial` and `Config.Racing.Rewards.Race` values did not change.

## Risks

The installer uses one exact-source patch against the isolated free-roam nav controller to redirect only the `RACE` tile click handler. If that source shape differs in live Studio, the script stops with a clear anchor error and should be followed by a fresh Studio mirror export before another patch.

The waypoint is local-only and intentionally non-collidable. It does not replace the ProximityPrompt start-zone entry flow.

## Rollback

To roll back Phase 7:

1. Delete or disable `RaceBrowserClient_Active`.
2. Delete `Controllers.UI.OpenRaceBrowser`.
3. Restore the `RACE` tile click handler in `FreeRoamNavController_Active` to `showActionPanel("Race")`, or revert to the previous Roblox version.

No reward config rollback should be needed because the phase does not touch reward folders.
