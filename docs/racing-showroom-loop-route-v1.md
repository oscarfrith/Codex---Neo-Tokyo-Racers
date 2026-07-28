# Showroom Loop Route V1.1

## Status

V1.1 is installed and user-confirmed working well. The complete Studio mirror at `2026-07-28 13:06:05` contains 192 mutually matching exported-source, source-manifest and checksum records with zero mismatches. It locks the authored 17-checkpoint route, finish index 18, six grid positions, 18 circuit arrow folders, enabled paired entrances and all three live Showroom Loop config folders.

Canonical installer:

```text
scripts/roblox_racing_showroom_loop_route_v1.lua
```

## Acceptance Contract

**Delivery lane:** Standard. This adds a second official route through the existing configuration-driven racing system. It touches race/session inputs and rewards, but creates no new runtime, persistence, remote, economy or UI owner.

**Goal:** Add an easily authored downtown/dealership circuit named `Showroom Loop`, initially centred near `(1400, 101, -1250)`, with 17 checkpoints and paired Race/Time Trial events.

**Stable IDs:**

```text
RouteId = ShowroomLoop
Race EventId = showroom_loop_race
Time Trial EventId = showroom_loop_tt
```

**Required changes:**

- clone the confirmed `ShiftedCanalSprint` route hierarchy and event contract;
- expand the route from 14 to 17 checkpoints;
- create 18 circuit arrow-segment folders from `Checkpoint0-1` through `Checkpoint17-0`;
- provide one movable/rotatable `Authoring.StartPivot`;
- keep the route unavailable until authoring validation passes;
- publish one Race and one Time Trial definition only during activation.

**Must preserve:**

- `ShiftedCanalSprint`, its two events and all current placement;
- the existing `RaceRouteDefinition`, `RaceConfigReader`, race/TT services, remotes, UI, rewards, PB/leaderboard and session owners;
- six-player race staging, selectable TT laps and current server authority;
- current driving, dealership, garage, VFX and world systems.

**Explicit exclusions:**

- no new racing service/controller or bootstrap hook;
- no script-source patch;
- no Studio backup folder;
- no new minimap artwork or calibrated HUD map;
- no final medal-time balancing before runtime laps;
- no automatic road/path generation.

## Ownership And Readiness

- **Route geometry:** `Workspace.NeoTokyoRacersWorld.RaceRoutes.ShowroomLoop`.
- **Authoring start layout:** `ShowroomLoop.Authoring.StartPivot`, consumed only by the installer in Edit mode.
- **Runtime route state:** unchanged existing racing services.
- **Race/TT content definitions:** existing `Config.Racing.RaceCatalog` and `TimeTrialCatalog`.
- **Persistence:** unchanged; unique EventIds give Showroom Loop separate PB and leaderboard keys.
- **Rewards:** copied from the current Shifted Canal definitions and remain server-authoritative.
- **Streaming:** unchanged existing streaming-safe race presentation. Runtime testing remains required in the downtown area.
- **Scale:** 17 checkpoint gates, six grid points and 18 bounded arrow-segment folders. No new loop or whole-Workspace scan is added.
- **Rollback:** remove the Race, Time Trial and HUD-map Showroom Loop config folders and disable its entrances while preserving authored geometry.

## Why Draft Events Are Not Put In The Live Catalog

The current Race Browser enumerates every Folder/Configuration directly inside `RaceCatalog` and `TimeTrialCatalog`; it has no draft/Enabled filter. `PREPARE` therefore creates only the inactive world route. `ACTIVATE` publishes both event folders together after the authoring audit passes.

This prevents an unfinished route from appearing in the browser.

## Authoring Workflow

### 1. Prepare

Leave:

```lua
local MODE = "PREPARE"
```

Run the complete installer once in the Studio Command Bar in Edit mode.

Expected result:

```text
Workspace.NeoTokyoRacersWorld.RaceRoutes.ShowroomLoop
```

The cloned route is translated so its Race start is initially around `(1400, 101, -1250)`. Both entrances have `Enabled=false`, and no Showroom Loop event exists in the live catalogs.

For the current mirrored draft, do not rerun `PREPARE`; use the V1.1 `REPAIR` mode described below.

### 2. Position The Start Layout

Select:

```text
Workspace.NeoTokyoRacersWorld.RaceRoutes.ShowroomLoop.Authoring.StartPivot
```

Move and rotate that one visible yellow marker to the intended start position and direction.

Change the same installer to:

```lua
local MODE = "COMPILE"
```

Run it again. It moves only:

- `RaceStartZone`;
- `TimeTrialStartZone`;
- `Grid_01` through `Grid_06`;
- `RaceBrowserTeleportPoint`;
- `FinishLine`.

It never moves checkpoints or arrows.

If individual start-layout offsets need fine adjustment, run `COMPILE` first, then make those adjustments manually and do not compile again.

### 3. Position The Route

Move and rotate each visible checkpoint:

```text
Checkpoint_001
...
Checkpoint_017
```

Every checkpoint must be moved at least once from its generated position. This is an activation safeguard: the translated Shifted Canal positions and three additional checkpoints are drafting aids, not an approved downtown route.

Checkpoint guidance:

- keep indices in driving order;
- use position and rotation to define the crossing plane;
- resize a checkpoint to cover the intended road without reaching a parallel street;
- keep consecutive checkpoints at least 12 studs apart;
- avoid placing a later checkpoint where it can be crossed early from another road;
- keep `FinishLine` at the start/finish area for the circuit.

### 4. Position Arrows

The installer prepares:

```text
Checkpoint0-1
Checkpoint1-2
...
Checkpoint16-17
Checkpoint17-0
```

The translated Shifted Canal groups remain available as starting assets. New segments may be empty and produce an audit warning, not an activation blocker. Move complete arrow models wherever practical instead of individual MeshParts.

The draft `10:44:47` mirror had 11 empty segments. The confirmed `13:06:05` mirror has only two remaining empty segments: `Checkpoint11-12` and `Checkpoint13-14`. Checkpoints remain authoritative; add arrows there later only if those turns are not sufficiently readable at speed.

### 5. Audit

Set:

```lua
local MODE = "AUDIT"
```

The audit is read-only. Resolve every `BLOCKER`. Empty arrow segments are `WARN` because checkpoints remain the authoritative route path.

### 6. Activate

Set:

```lua
local MODE = "ACTIVATE"
```

Activation requires:

- the installer-owned route and unique IDs;
- exactly 17 contiguous checkpoints;
- every checkpoint moved from its generated position;
- finish index `18`;
- six valid grid positions;
- both entrance definitions;
- all 18 arrow folders;
- no conflicting Race/TT EventId.

It then copies the confirmed Shifted Canal Race and Time Trial attributes plus the complete HUD-map config schema, overrides the Showroom Loop identifiers, retains the inherited 3 Race laps and one default TT lap, clears route-specific media, publishes the three config folders together and enables both entrances.

### V1.1 Recovery/Audit

Leave the canonical installer at:

```lua
local MODE = "REPAIR"
```

No ordinary run is pending. If the exact Showroom Loop contract later needs repair, `REPAIR` preflights the 17-checkpoint route, preserves every checkpoint/start/arrow transform, normalises finish/segment/config attributes and runs the activation audit. Use `AUDIT` for a read-only Edit-mode check.

## Media And Balance

The installer deliberately leaves `TrackImage`, `MapImage`, `RaceHudMapImage` and the cloned HUD-map `Image` empty. `HudMapCatalog.ShowroomLoop` otherwise inherits the Shifted Canal schema/tuning, but `Enabled=false`, `UseConfiguredWorldAnchor=false` and `AnchorPartName="FinishLine"` prevent uncalibrated Waterfront coordinates from moving the marker incorrectly.

Initial rewards and TT medal times are inherited as provisional values. Tune medal thresholds only after representative clean laps in several tiers. Confirm reward pacing before release.

## Verification Matrix

### Edit Mode

- `AUDIT` reports `0 BLOCKER`.
- `ShiftedCanalSprint` and its catalog events are unchanged.
- Showroom Loop has 17 checkpoints, six grid points and 18 circuit arrow folders.
- `FinishLine.CheckpointIndex=18`.
- `RaceCatalog.ShowroomLoop`, `TimeTrialCatalog.ShowroomLoop` and `HudMapCatalog.ShowroomLoop` exist.
- Shared non-route-specific config values match Shifted Canal; Showroom Loop media remains blank and its HUD-map marker remains disabled.

### Solo Play

- Race Browser shows Waterfront Sprint and Showroom Loop.
- Showroom Loop teleport arrives at its own start.
- both physical prompts open Showroom Loop;
- the selected vehicle stages facing the intended direction;
- countdown, release, checkpoint order, lap and finish work;
- Time Trial results and PB use `showroom_loop_tt`;
- reset, exit and return-to-free-roam restore the correct state.

### Multiplayer

- run a two-client race;
- both players join `showroom_loop_race`;
- both use distinct valid grid slots;
- checkpoint/lap/placement order remains authoritative;
- finish, DNF/timeout and exit cleanup work.

### Device, Streaming And Regression

- landscape phone/tablet and controller can browse, enter, race and exit;
- drive away until downtown content streams out, return, and repeat entry;
- dealership/garage prompts near the route do not conflict;
- Shifted Canal Race and TT still complete;
- no new collision, VFX, camera, driving or free-roam regression appears.

## Rollback

Set:

```lua
local MODE = "ROLLBACK"
```

Run in Edit mode. It:

- removes only `RaceCatalog.ShowroomLoop`;
- removes only `TimeTrialCatalog.ShowroomLoop`;
- removes only `HudMapCatalog.ShowroomLoop`;
- disables both Showroom Loop entrances;
- removes generated live prompts if present;
- reveals the authoring labels and pivot;
- preserves every checkpoint, arrow and start-layout placement.

The route can then be repaired and reactivated without rebuilding it.

## Mirror And Handoff

The complete `2026-07-28 13:06:05` post-activation mirror is current and internally consistent. No refresh is pending for this handoff.

After any later Studio route, config, media, map-calibration or tuning change, refresh the complete mirror:

1. locally run `py scripts/receive_studio_full_snapshot_export.py`;
2. run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in the Studio Command Bar;
3. verify exported manifest, source manifest and checksums agree;
4. commit `roblox/exported_scripts/` and `roblox/studio_snapshot/`;
5. do not commit `docs/studio-full-export-paste.txt`.

## Confirmed Handoff Lock

- Route: `ShowroomLoop`, 17 ordered checkpoints plus finish gate 18.
- Events: `showroom_loop_race` and `showroom_loop_tt`.
- Live config: Race, Time Trial and HUD Map folders present; Race uses 3 laps and TT defaults to one selectable lap.
- Detection: existing ordered `Touched` handling against each checkpoint/finish BasePart. Part size and rotation define the trigger volume; `RadiusStuds` is unused legacy metadata.
- User result: working well.
- Mirror: complete `13:06:05` snapshot, 192 matching source records, zero checksum mismatches.
- Pending content rather than a defect: route artwork/HUD-map calibration and route-specific reward/medal tuning.
- Optional route-guidance polish: `Checkpoint11-12` and `Checkpoint13-14` are the two remaining empty arrow folders.
- Retained release regression: two-client Race, landscape phone/tablet, controller, streaming out/back, nearby dealership/garage prompts, reset/exit and Shifted Canal completion.
- Recovery: keep `scripts/roblox_racing_showroom_loop_route_v1.lua`; do not rerun it during ordinary use.
