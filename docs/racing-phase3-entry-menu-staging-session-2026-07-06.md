# Racing Phase 3 Entry Menu, Vehicle Select, Staging, And Session Layer

**Created:** 2026-07-06  
**Script:** `scripts/roblox_racing_phase3_entry_menu_staging_session.lua`  
**Status:** Generated in Git. Phase 3B-3E repairs added during entry-menu/staging stabilization.  

## Purpose

Phase 3 replaces Phase 2's instant time-trial start with the intended entry flow:

```text
Start zone prompt
  -> themed race menu
  -> owned vehicle selection
  -> selected vehicle spawn
  -> start-line staging/freeze
  -> countdown
  -> server-authoritative time trial
```

It still defers medals, cash rewards, personal best persistence, and multiplayer matchmaking.

## What It Installs

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
  RaceEntryMenuClient_Active
```

It disables the older Phase 2 `RaceClient_Active` if present, because the Phase 3 client owns the race entry menu, vehicle picker, HUD, next-gate marker, and visibility filter.

Phase 3B adds:

```text
scripts/roblox_racing_phase3b_prompt_connection_repair.lua
```

This repairs a silent prompt wiring issue where an existing `NTR_RaceEntryPrompt` can be present but not have a live `Triggered` connection after the isolated racing service source changes. The repair patches only `TimeTrialService_Active`, recreates race-entry prompts once on server startup, and prints an Output line when `E` / touch is received.

Phase 3C adds:

```text
scripts/roblox_racing_phase3c_client_event_repair.lua
```

This handles the next failure mode: the server prompt fires, but the client menu still does not appear. It patches only `RaceEntryMenuClient_Active` so the client logs startup/event receipt and no longer waits on garage profile remotes before it can listen for `OpenRaceEntry`. It also installs a tiny `StarterPlayerScripts.RaceEntrySignalProbe_Active` client probe that confirms whether the `RaceEvent` reaches the player at all.

Phase 3D adds:

```text
scripts/roblox_racing_phase3d_time_trial_event_pairing_repair.lua
```

This fixes the next confirmed failure mode: opening from `RaceStartZone`, choosing `START TIME TRIAL`, and selecting a vehicle spawned the car through the garage path but did not stage it at the start line. Root cause: the menu opened with the race event id, then `START TIME TRIAL` sent that race id to `StartStagedTimeTrial`. The repair resolves the paired time-trial event before spawning and makes the server tolerant if a race event id is accidentally sent for a solo time trial.

Phase 3E adds:

```text
scripts/roblox_racing_phase3e_release_drive_handoff_repair.lua
```

This fixes the next confirmed failure mode: the countdown completes, but the vehicle is not drivable and nearby map assets stream in/out. Root cause: the client fired the existing `FreeRoamVehicleSpawned` driving handoff immediately after the garage spawn, before Racing teleported/froze/released the vehicle. On `GO`, Racing now explicitly prepares the vehicle for driving, gives the root network ownership to the player where Roblox allows it, asks the client to stream around the active route, and re-fires the existing driving handoff after release.

It also creates or confirms:

```text
Workspace.NeoTokyoRacersWorld.RaceInstances
Workspace.NeoTokyoRacersWorld.RaceRoutes.ShiftedCanalSprint.Media
Workspace.NeoTokyoRacersWorld.RaceRoutes.ShiftedCanalSprint.SessionAssetTemplates
```

`Media.TrackImage` and `Media.MapImage` are empty `StringValue`s for now. Paste uploaded `rbxassetid://...` image IDs there later.

## How Vehicle Selection Works

The race client reads owned vehicles through the existing `GarageInvoke.GetInitial` response and renders cards using the same broad visual language as dealership/customisation cards:

- cockpit image or themed placeholder;
- name;
- cockpit id;
- tier/rating badge;
- selected state.

When the player starts a time trial, the client first tries the existing `SpawnOwnedVehicleFromFreeRoam` garage action. If an older place copy does not have that action, it falls back to:

```text
SelectVehicleInstance
SpawnVehicle
```

The Racing service then validates the currently seated runtime vehicle on the server before staging. This avoids another fragile patch against `GarageActionController_Shadow_Disabled`.

## What It Does

- Replaces the start-zone prompt action with `Open Race Menu`.
- Opens a themed menu with track image, map image, route details, recommended performance/time-trial medal preview, and bottom `START RACE`, `START TIME TRIAL`, `EXIT` buttons.
- Keeps `START RACE` as a visible but deferred button with a clear matchmaking-coming message.
- Shows owned vehicle cards after choosing `START TIME TRIAL`.
- Spawns/selects the chosen vehicle through existing garage actions.
- Teleports the selected runtime vehicle to the first `SpawnGrid` point.
- Seats the player, freezes the vehicle, counts down, then releases at `GO`.
- Starts server timing only after release.
- Keeps ordered checkpoint/final-gate validation server-authoritative.
- Creates a lightweight `RaceInstances.<RunId>` folder for the active run.
- Locally hides non-participant players/vehicles from the participant and hides the participant from non-participants where practical.

## Current Separation Limit

This is the first session-separation layer, not full physical instancing yet.

Phase 3:

- creates `RaceInstances.<RunId>`;
- marks the active vehicle with race attributes;
- locally filters player/vehicle visibility;
- prepares `SessionAssetTemplates`.

It does not yet clone the whole route into a far-away race pocket. Collidable race-only jumps/barriers should wait for the next session-asset phase so they can be spawned into an isolated runtime area rather than placed collidable in free roam.

## Run Order

1. Open Studio in Edit mode.
2. Paste and run:

```text
scripts/roblox_racing_phase3_entry_menu_staging_session.lua
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

1. Spawn/enter a vehicle.
2. Drive into `TimeTrialStartZone`.
3. Press `E` or tap the prompt.
4. Confirm the menu opens instead of instantly starting.
5. Confirm the menu shows route details plus `START RACE`, `START TIME TRIAL`, and `EXIT`.
6. Choose `START TIME TRIAL`.
7. Pick an owned vehicle card.
8. Confirm the selected vehicle spawns/teleports to the start line.
9. Confirm the vehicle is fixed during countdown.
10. Confirm it releases on `GO`.
11. Drive through checkpoints and finish.
12. Confirm the HUD shows finish time.

If pressing `E` does nothing but there are no Output errors, run:

```text
scripts/roblox_racing_phase3b_prompt_connection_repair.lua
```

Then restart Play. When the prompt receives input, Output should include:

```text
[NTR Racing Phase 3] Race entry prompt triggered by <player> at <zone path>
```

If that line appears but the menu still does not open, the next issue is likely client-side event/UI startup rather than the prompt.

If the server prints that line and the menu still does not open, run:

```text
scripts/roblox_racing_phase3c_client_event_repair.lua
```

Then restart Play. Useful client Output lines are:

```text
[NTR Racing Phase 3 Client] booted ...
[NTR Racing Phase 3 Client] received event OpenRaceEntry
[NTR Racing Phase 3C Probe] OpenRaceEntry received for ...
```

If `Phase 3C Probe` receives the event but the main menu stays hidden, the probe shows a temporary on-screen diagnostic panel and the `Phase 3 Client` warning should explain the UI error. If neither client line appears, inspect whether `StarterPlayerScripts` copied the racing LocalScripts into the player's `PlayerScripts` at runtime.

If the menu opens but `START TIME TRIAL` spawns the vehicle somewhere in free roam/customisation instead of staging it at the start grid, run:

```text
scripts/roblox_racing_phase3d_time_trial_event_pairing_repair.lua
```

Then restart Play and test from both `RaceStartZone` and `TimeTrialStartZone`. The vehicle may briefly spawn through the existing garage action, but it should then stage at the route `SpawnGrid` and show the countdown. Repeated clicks should not keep spawning cars at random world spawn points.

If the countdown completes but the car is not drivable or the world streams/flickers around the start line, run:

```text
scripts/roblox_racing_phase3e_release_drive_handoff_repair.lua
```

Then restart Play and verify that after `GO`, the normal speed/boost HUD/control handoff is active and nearby map assets stay loaded.

For multiplayer/local-server smoke:

- a non-participant should not see the participant during the active run where the local visibility filter applies;
- the participant should not see unrelated free-roam players/vehicles during the active run;
- visibility should restore after finish.

## Known Non-Goals

- no medal calculation yet;
- no cash rewards yet;
- no personal best persistence yet;
- no multiplayer matchmaking yet;
- future multiplayer races should use one open queue/category per race event at launch, not tier brackets;
- no cloned route pocket yet;
- no collidable race-only jumps/barriers yet;
- no uploaded track/map artwork yet.

## Rollback

Delete or disable:

```text
ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active
```

Then re-enable or rerun Phase 2 if you want the old instant-start solo time trial:

```text
scripts/roblox_racing_phase2_solo_time_trial_mvp.lua
```

Leave route folders/config unless intentionally removing the race system.

## After Confirmation

Refresh the Studio mirror because this phase changes scripts, remotes, folders, prompts, config values, and runtime hierarchy:

```text
py scripts/receive_studio_full_snapshot_export.py
```

Then run this in the Roblox Studio Command Bar:

```text
scripts/roblox_studio_export_full_snapshot_for_github_v2.lua
```

Do not commit `docs/studio-full-export-paste.txt`.
