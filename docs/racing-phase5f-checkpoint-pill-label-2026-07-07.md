# Racing Phase 5F Checkpoint Pill Label

**Created:** 2026-07-07  
**Script:** `scripts/roblox_racing_phase5f_checkpoint_pill_label.lua`  
**Status:** Generated in Git for Studio install/testing.

## Purpose

Phase 5E restored checkpoint text above the physical checkpoint with no backing panel. Phase 5F keeps the text in world space but adds a much smaller, configurable black pill behind the text for readability.

This avoids the earlier large dark panel while still giving the text contrast against bright sky/water/buildings.

## What It Changes

The repair patches only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceRouteGuideClient_Active
```

It replaces the checkpoint BillboardGui renderer with:

- a small rounded black label behind only the text;
- configurable width/height;
- configurable transparency;
- configurable height above checkpoint;
- generated checkpoint frames still off by default.

## Config

Editable attributes live under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.RouteGuide
```

Main values:

```text
CheckpointPillWidth = 168
CheckpointPillHeight = 28
CheckpointPillYOffset = 7
CheckpointPillBackgroundTransparency = 0.8
CheckpointPillCornerRadius = 8
CheckpointPillStrokeTransparency = 0.7
CheckpointPillStrokeThickness = 1
CheckpointWorldTextSize = 15
CheckpointWorldTextStrokeTransparency = 0.35
CheckpointWorldTextAlwaysOnTop = true
ShowWorldCheckpointLabel = true
ShowCheckpointHudBadge = false
ShowCheckpointFrames = false
CheckpointFrameStyle = "Off"
```

Roblox transparency is inverted:

- `0` = fully solid;
- `1` = fully invisible;
- `0.8` = 20% opacity.

Suggested tuning:

- Too dark: set `CheckpointPillBackgroundTransparency` to `0.86` or `0.9`.
- Too faint: set it to `0.7`.
- Too wide: lower `CheckpointPillWidth`.
- Too high/low: tune `CheckpointPillYOffset`.
- Text too small/large: tune `CheckpointWorldTextSize`.

## Run Order

1. Open Studio in Edit mode.
2. Paste and run:

```text
scripts/roblox_racing_phase5f_checkpoint_pill_label.lua
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
2. Confirm checkpoint text appears above the physical checkpoint.
3. Confirm the black backing is only a small pill around the text, not a large panel.
4. Confirm the pill is lightly transparent at the default `0.8` transparency.
5. Confirm generated checkpoint frames/corner ticks are still hidden.
6. Confirm dynamic arrows and wrong-way delay still work.

## After Confirmation

Because this phase changes Studio script source and config attributes, refresh the Studio mirror after it is installed and tested.
