# Racing Phase 5E World Text-Only Checkpoint Guide

**Created:** 2026-07-07  
**Script:** `scripts/roblox_racing_phase5e_world_text_only_checkpoint_guide.lua`  
**Status:** Generated in Git for Studio install/testing.

## Purpose

Phase 5D moved checkpoint text into a fixed screen badge, but that removed the spatial cue. The preferred behavior is now:

- checkpoint text appears above the physical checkpoint;
- there is no dark panel/frame behind the text;
- generated checkpoint frames/corner ticks are off by default;
- dynamic arrows and authored arrows remain available;
- the `WRONG WAY` prompt still waits for sustained wrong-way driving.

## What It Changes

The repair patches only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceRouteGuideClient_Active
```

It replaces the checkpoint label renderer with a transparent BillboardGui text label above the checkpoint. It also keeps the Phase 5D wrong-way delay if it is already present, or adds it if the active route guide has the earlier immediate wrong-way behavior.

## Config

Editable attributes live under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.RouteGuide
```

Key values:

```text
ShowWorldCheckpointLabel = true
ShowCheckpointHudBadge = false
ShowCheckpointFrames = false
CheckpointFrameStyle = "Off"
CheckpointWorldTextSize = 15
CheckpointWorldTextYOffset = 7
CheckpointWorldTextStrokeTransparency = 0.35
CheckpointWorldTextAlwaysOnTop = true
WrongWayDelaySeconds = 3
WrongWayCheckInterval = 0.12
```

## Run Order

1. Open Studio in Edit mode.
2. Paste and run:

```text
scripts/roblox_racing_phase5e_world_text_only_checkpoint_guide.lua
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
2. Confirm `CHECKPOINT <n>` appears above the physical checkpoint in the world.
3. Confirm there is no dark rectangular frame/panel behind that text.
4. Confirm there is no generated checkpoint frame/corner tick unless `ShowCheckpointFrames` is intentionally turned back on.
5. Confirm dynamic route arrows still point to the checkpoint.
6. Drive wrong way for less than `3` seconds and confirm the warning does not appear.
7. Keep driving wrong way for more than `3` seconds and confirm `WRONG WAY` appears.

## Rollback / Tuning

If the text is too small or too close/far from the checkpoint, tune:

```text
CheckpointWorldTextSize
CheckpointWorldTextYOffset
CheckpointWorldTextStrokeTransparency
```

If you want the faint corner ticks back later:

```text
ShowCheckpointFrames = true
CheckpointFrameStyle = "CornerTicks"
```

## After Confirmation

Because this phase changes Studio script source and config attributes, refresh the Studio mirror after it is installed and tested.
