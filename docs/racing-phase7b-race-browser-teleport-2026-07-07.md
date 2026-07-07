# Racing Phase 7B Race Browser Teleport

**Script:** `scripts/roblox_racing_phase7b_race_browser_teleport.lua`  
**Status:** Generated for Studio install/testing  
**Scope:** Free-roam Race browser teleport-to-start flow

## Purpose

Phase 7B replaces the Phase 7 `TRACK START` waypoint button with `TELEPORT TO START`.

The Race browser remains a browse surface, not a direct race starter. After teleporting, the player still enters the physical race/time-trial start zone and presses `E` / taps the prompt to open the existing Phase 3 race entry menu.

## What It Installs

- `ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Racing.RaceBrowserTeleportInvoke`
- `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceBrowserTeleportService_Active`
- `Config.Racing.BrowserTeleport` tuning values
- `RaceRoutes.<RouteId>.TeleportPoints.RaceBrowserTeleportPoint`
- a patch to the isolated `RaceBrowserClient_Active` so the detail button says `TELEPORT TO START` and closes the browser after a successful teleport

Important: this phase does **not** edit `Config.Racing.Rewards`, reward multipliers, `Config.Racing.RouteGuide`, timing, checkpoints, or payouts.

## Teleport Point Authoring

Each route gets:

```text
Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>.TeleportPoints.RaceBrowserTeleportPoint
```

Move this part in Studio to control where players arrive when they press `TELEPORT TO START`. The script initially places it near the route's time-trial or race start zone.

The server looks for these names in order:

- `<Mode>TeleportPoint`, for example `TimeTrialTeleportPoint`
- `<Mode>StartTeleport`
- `RaceBrowserTeleportPoint`
- `StartTeleportPoint`
- otherwise the first `BasePart` in `TeleportPoints`

This means future tracks can have separate race/time-trial arrival parts if needed, but one shared `RaceBrowserTeleportPoint` is enough for now.

## Despawn / Teleport Safety

The server owns the move:

1. validates the selected event and route;
2. finds the route teleport point;
3. unseats the player;
4. briefly anchors the character root;
5. pivots the character to the teleport point plus configured height offset;
6. waits a short configurable delay;
7. destroys the player's current spawned vehicle;
8. unfreezes the character.

This sequence avoids using the normal free-roam `DespawnVehicle` action, because that action may move seated players relative to their vehicle. Phase 7B moves the character first, then removes the vehicle after the character is clear.

## Verification

1. Run `scripts/roblox_racing_phase7b_race_browser_teleport.lua` in Edit mode.
2. Confirm `RaceBrowserTeleportPoint` exists under the route's `TeleportPoints` folder.
3. Move the part to the desired arrival spot.
4. Restart Play.
5. Spawn or drive a vehicle.
6. Open the free-roam Race browser.
7. Select an event and press `TELEPORT TO START`.
8. Confirm the Race browser closes automatically.
9. Confirm the player appears at the teleport point and the old spawned vehicle disappears.
10. Confirm driving HUD/controls stop after teleport.
11. Walk or drive into the nearby start zone and press `E` / tap to confirm the race entry menu still opens.

## Rollback

Disable or delete:

- `RaceBrowserTeleportService_Active`
- `RaceBrowserTeleportInvoke`

Then rerun Phase 7 if you want the old waypoint button back, or restore from Roblox version history.
