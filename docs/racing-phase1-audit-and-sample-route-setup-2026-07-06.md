# Racing Phase 1 Audit And Sample Route Setup

**Created:** 2026-07-06  
**Script:** `scripts/roblox_racing_phase1_audit_and_sample_route_setup.lua`  
**Status:** Run by user; first race zones/checkpoints moved in Studio. Mirror refresh pending.  

## Purpose

This compresses the safe part of the first two racing phases:

- `AUDIT` mode is read-only and checks the current route/config/script/profile state.
- `SETUP_SAMPLE` mode creates the first editable sample route and config scaffold, but installs no gameplay services, no reward logic, no checkpoint runtime, and no race UI.

The script does not patch source text. It does not touch driving, VFX, garage customisation, dealership UI, or the register-limited main client bootstrap.

## Recommended Run Order

1. Open Roblox Studio in Edit mode.
2. Paste and run:

```text
scripts/roblox_racing_phase1_audit_and_sample_route_setup.lua
```

3. Leave `MODE = "AUDIT"` for the first run.
4. Review the Output.
5. If the audit looks sensible, change:

```lua
local MODE = "AUDIT"
```

to:

```lua
local MODE = "SETUP_SAMPLE"
```

6. Rerun the same script.

## What AUDIT Checks

- `Workspace.NeoTokyoRacersWorld.RaceRoutes`
- existing route folders, start zones, spawn grids, checkpoints, and finish lines
- `ReplicatedStorage.NeoTokyoRacers.Config.Racing`
- future Racing remotes
- future server/client Racing folders
- the existing free-roam Race button/placeholder in `FreeRoamNavController_Active`
- road spawn markers
- profile/reward integration hooks
- spawned vehicle `PerformanceTier` / `PerformanceIndex` in Play mode

## What SETUP_SAMPLE Creates

```text
Workspace.NeoTokyoRacersWorld.RaceRoutes.ShiftedCanalSprint
  StartZones
    TimeTrialStartZone
    RaceStartZone
  SpawnGrid
    Grid_01 ... Grid_06
  Checkpoints
    Checkpoint_001 ... Checkpoint_004
  FinishLine
```

It also creates:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing
  TimeTrialCatalog.ShiftedCanalSprint
  RaceCatalog.ShiftedCanalSprint
  Rewards
  TierRules
```

The time trial config includes bronze, silver, gold, and platinum times for each vehicle tier from E through S.

## Future-Proofing Notes

The generated Studio route is an official authored route scaffold. Future player-created races should not be built by permanently cloning this exact folder shape into Workspace. Instead, the gameplay services should read a normalized route definition so both official and player-created routes share the same checkpoint, timer, HUD, arrow, matchmaking, and reward code.

Planned route sources:

```text
Official route: Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>
Player draft: Profile.Racing.CreatedRoutes.<DraftId>
Runtime player route: Workspace.NeoTokyoRacersWorld.RaceRoutes.RuntimePlayerRoutes.<RunId>
```

The next runtime phase should introduce a small `RaceConfigReader` / `RaceRouteDefinition` layer before checkpoint gameplay so this abstraction is in place early.

## Arrow Guidance

The sample route did not create arrow markers yet, but arrows should be treated as first-class route guidance. Add them as an optional route child in the next authoring/runtime phase:

```text
Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>.ArrowMarkers
  Arrow_001
  Arrow_002
```

Recommended attributes:

```text
ArrowIndex
RouteId
TargetCheckpointIndex
DisplayMode
ArrowStyle
ArrowAssetId
Scale
ColorRole
```

The client route guide should render arrow assets locally, using them to clarify corners, forks, and verticality while the server continues to care only about checkpoint order and finish validation.

## After Setup

Move and resize the route parts in Studio so they sit on the intended road. Treat the generated route as a visible authoring scaffold, not final gameplay placement.

After running `SETUP_SAMPLE`, refresh the Studio mirror before final handoff:

1. Run `python scripts/receive_studio_full_snapshot_export.py` or the bundled Python equivalent locally.
2. Run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in the Roblox Studio Command Bar.
3. Commit the generated `roblox/exported_scripts/` and `roblox/studio_snapshot/` changes, but do not commit `docs/studio-full-export-paste.txt`.

## Verification

After `AUDIT`:

- Output should find `RaceRoutes`.
- It should report the free-roam Race button integration point.
- If in Play with a spawned vehicle, it should print that vehicle's `PerformanceTier` and `PerformanceIndex`.

After `SETUP_SAMPLE`:

- Confirm the `ShiftedCanalSprint` route exists in Explorer.
- Confirm checkpoints have numeric `CheckpointIndex` attributes.
- Confirm `Config.Racing.TimeTrialCatalog.ShiftedCanalSprint` has tiered medal time attributes.
- Confirm no new server/client Racing gameplay scripts were installed yet.

## Rollback

Because no gameplay source is patched, rollback is just deleting:

```text
Workspace.NeoTokyoRacersWorld.RaceRoutes.ShiftedCanalSprint
ReplicatedStorage.NeoTokyoRacers.Config.Racing
```

Only delete `Config.Racing` if no later racing work has been added under it.
