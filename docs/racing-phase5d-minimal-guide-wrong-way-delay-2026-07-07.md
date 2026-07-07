# Racing Phase 5D Minimal Route Guide And Wrong-Way Delay

**Created:** 2026-07-07  
**Script:** `scripts/roblox_racing_phase5d_minimal_guide_wrong_way_delay.lua`  
**Status:** Generated in Git for Studio install/testing.

**Update:** After the first Studio run stopped with `Could not find known makeBillboard block`, the installer was hardened to replace whole route-guide function windows by function name instead of requiring exact old function bodies.

## Purpose

The Phase 5/5C checkpoint guide still blocked too much of the driving view. The screenshot showed the main obstruction was the large camera-facing checkpoint label panel, not only the world frame transparency.

Phase 5D changes the design rather than only tuning opacity.

## What It Changes

The repair patches only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceRouteGuideClient_Active
```

It:

- disables the large in-world checkpoint label by default;
- adds a small top-screen checkpoint badge for `CHECKPOINT 1`, `FINISH`, etc.;
- replaces the old full checkpoint frame with faint corner tick markers;
- keeps the dynamic chevron and authored arrows;
- makes `WRONG WAY` appear only after sustained wrong-way driving for `3` seconds;
- throttles wrong-way checks to `0.12` seconds inside the existing heartbeat, instead of adding another loop.

## Config

Editable attributes live under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.RouteGuide
```

New/updated values:

```text
ShowCheckpointHudBadge = true
ShowWorldCheckpointLabel = false
CheckpointFrameStyle = "CornerTicks"
CheckpointFrameTransparency = 0.94
CheckpointCornerTickLength = 5
CheckpointCornerTickThickness = 0.16
CheckpointHudBackgroundTransparency = 0.38
CheckpointHudTextTransparency = 0
WrongWayDelaySeconds = 3
WrongWayCheckInterval = 0.12
```

Set `CheckpointFrameStyle = "Off"` if the corner ticks are still too visible and you want only arrows plus the HUD badge.

## Run Order

1. Open Studio in Edit mode.
2. Paste and run:

```text
scripts/roblox_racing_phase5d_minimal_guide_wrong_way_delay.lua
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

1. Start a time trial.
2. Confirm the large in-world checkpoint label no longer blocks the road.
3. Confirm the small checkpoint badge appears near the top of the screen.
4. Confirm the world checkpoint marker is now subtle corner ticks, not a solid-looking full frame.
5. Drive briefly the wrong way for less than `3` seconds and confirm no warning appears.
6. Keep driving the wrong way for more than `3` seconds and confirm `WRONG WAY` appears.
7. Turn back toward the next checkpoint and confirm the warning clears.
8. Confirm checkpoints, chevrons, authored arrows, finish, and retry still work.

## Rollback / Tuning

Preferred visual tuning is config-first:

```text
CheckpointFrameStyle = "Off" | "CornerTicks"
CheckpointFrameTransparency
ShowWorldCheckpointLabel
ShowCheckpointHudBadge
WrongWayDelaySeconds
WrongWayCheckInterval
```

If the whole Phase 5D guide feels worse, rerun the previous Phase 5/5B/5C scripts, then retest.

## After Confirmation

Because this phase changes Studio script source and config attributes, refresh the Studio mirror after it is installed and tested.
