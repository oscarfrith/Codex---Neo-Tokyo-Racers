# Racing Phase 5C Checkpoint Label/Frame Opacity Repair

**Created:** 2026-07-06  
**Script:** `scripts/roblox_racing_phase5c_checkpoint_label_frame_opacity_repair.lua`  
**Status:** Generated in Git for Studio install/testing.

## Purpose

Phase 5B made the checkpoint world frame configurable, but the visible checkpoint label panel still had its own hardcoded opacity. That made the checkpoint UI look almost unchanged.

Phase 5C separates the two visual controls:

```text
CheckpointLabelTextTransparency = 0.2
CheckpointLabelBackgroundTransparency = 0.2
CheckpointFrameTransparency = 0.8
```

The label text and panel stay readable at 20% transparency, while the world checkpoint/finish frame becomes subtle at 80% transparency.

## What It Changes

The repair patches only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceRouteGuideClient_Active
```

It also sets attributes under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.RouteGuide
```

## Run Order

1. Open Studio in Edit mode.
2. Paste and run:

```text
scripts/roblox_racing_phase5c_checkpoint_label_frame_opacity_repair.lua
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
2. Confirm the checkpoint label text/panel remains readable and dark, around 20% transparent.
3. Confirm the world checkpoint/finish frame is much fainter, around 80% transparent.
4. Confirm chevrons, authored arrows, wrong-way prompt, checkpoint advance, finish, and retry still work.

## Rollback / Tuning

Tune these two attributes:

```text
CheckpointLabelBackgroundTransparency
CheckpointLabelTextTransparency
CheckpointFrameTransparency
```

Lower values are more solid; higher values are more transparent.

## After Confirmation

Because this phase changes Studio script source and config attributes, refresh the Studio mirror after it is installed and tested.
