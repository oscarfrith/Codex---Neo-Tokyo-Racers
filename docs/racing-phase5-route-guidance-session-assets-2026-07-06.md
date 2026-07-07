# Racing Phase 5 Route Guidance And Session Visuals

**Created:** 2026-07-06  
**Script:** `scripts/roblox_racing_phase5_route_guidance_session_assets.lua`  
**Status:** Generated in Git for Studio install/testing.

## Purpose

Phase 5 adds the first route-guidance layer without touching the working Phase 4 timer/results flow.

It installs a new isolated client:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceRouteGuideClient_Active
```

The client listens to the existing `RaceEvent` stream and renders local-only visuals while a time trial is active:

- checkpoint/finish neon frames;
- a dynamic next-gate chevron;
- authored `ArrowMarkers` when route designers add them;
- a wrong-way prompt based on vehicle movement direction.

## What It Changes

The installer creates or confirms:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.RouteGuide
Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>.ArrowMarkers
Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>.SessionAssetTemplates
```

The visuals are parented locally under:

```text
Workspace._NTR_ClientOnly.RaceRouteGuide
```

That means free-roam players should not see these guidance objects, and the objects do not collide or replicate as physical race content.

## Config

Editable attributes live under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.RouteGuide
```

Useful values:

```text
EnableRouteGuide
ShowCheckpointFrames
CheckpointFrameTransparency
CheckpointLabelBackgroundTransparency
CheckpointLabelTextTransparency
ShowDynamicNextArrow
ShowAuthoringArrows
ShowWrongWayPrompt
DynamicArrowBackStuds
DynamicArrowHeightStuds
DynamicArrowScale
WrongWayMinSpeed
WrongWayIgnoreNearGateStuds
WrongWayDotThreshold
CheckpointColor
FinishColor
ArrowColor
WarningColor
```

Default `CheckpointFrameTransparency` is now `0.8` after the Phase 5B/5C visual repairs. Default `CheckpointLabelBackgroundTransparency` and `CheckpointLabelTextTransparency` are `0.2`, so the label remains readable while the world frame is subtle. Lower values make a surface more solid; higher values make it fainter.

Phase 5D supersedes the earlier label/frame tuning as the preferred visual design. It disables the large in-world label by default, shows checkpoint text in a small top-screen badge, changes the world marker to faint corner ticks, and delays the wrong-way prompt:

```text
scripts/roblox_racing_phase5d_minimal_guide_wrong_way_delay.lua
```

Phase 5E supersedes Phase 5D's fixed screen badge after testing showed it lost the spatial checkpoint cue. Preferred current visual:

```text
scripts/roblox_racing_phase5e_world_text_only_checkpoint_guide.lua
```

It restores text above the physical checkpoint, removes the backing panel/frame, and leaves generated checkpoint frames off by default.

Phase 5F supersedes Phase 5E as the preferred visual if readability needs a backing element:

```text
scripts/roblox_racing_phase5f_checkpoint_pill_label.lua
```

It keeps the text above the physical checkpoint and adds a small configurable transparent black pill behind only the text. Default `CheckpointPillBackgroundTransparency = 0.8`, which means 20% opacity.

## Phase 5B Follow-Up

If two checkpoint markers appear after Phase 5, run:

```text
scripts/roblox_racing_phase5b_marker_dedupe_transparency_repair.lua
```

That follow-up disables the older Phase 3/4 `RaceNextGateSelection` / `RaceNextGateBillboard` marker path so `RaceRouteGuideClient_Active` is the only active checkpoint-guide visual owner.

If the duplicate marker is gone but the checkpoint UI still looks too opaque, run:

```text
scripts/roblox_racing_phase5c_checkpoint_label_frame_opacity_repair.lua
```

That follow-up separates label opacity from frame opacity: label text/panel `0.2`, world frame `0.8`.

## Authored Arrows

Route designers can add arrow hint parts under:

```text
Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>.ArrowMarkers
```

Each part can use:

```text
ArrowIndex = 1
TargetCheckpointIndex = 2
DisplayMode = "Always" | "WhenNext" | "WrongWayAssist"
ArrowStyle = "Chevron"
Scale = 1.0
ColorRole = "Accent" | "Warning" | "Checkpoint"
```

Phase 5 renders these as local neon chevrons. Uploaded arrow image/mesh assets can replace or supplement this in a later art pass.

## Deliberate Deferral

This phase does **not** spawn collidable ramps, jump pads, boost strips, gates, or barriers yet.

Those should wait until the race instance/pocket and collision-group layer is stronger. Otherwise there is a real risk of race-only physical objects interfering with free roam.

## Run Order

1. Open Studio in Edit mode.
2. Paste and run:

```text
scripts/roblox_racing_phase5_route_guidance_session_assets.lua
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

1. Start a time trial normally.
2. Confirm a neon checkpoint/finish frame appears for the next gate.
3. Confirm a dynamic chevron appears near the next gate and advances after each checkpoint.
4. Drive briefly away from the next gate at speed and confirm the `WRONG WAY` prompt appears, then disappears when you turn back.
5. Finish the time trial and confirm the guide visuals disappear while the Phase 4 result panel still works.
6. Click `RETRY` and confirm the guide visuals come back for the restaged run.

Optional authoring check:

1. Add a simple anchored part under `ShiftedCanalSprint.ArrowMarkers`.
2. Set `ArrowIndex`, `TargetCheckpointIndex`, and `DisplayMode = "WhenNext"`.
3. Restart Play and confirm the authored chevron appears only for its target checkpoint.

## Rollback

Disable or delete only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceRouteGuideClient_Active
ReplicatedStorage.NeoTokyoRacers.Config.Racing.RouteGuide
```

Leave `ArrowMarkers` and `SessionAssetTemplates` folders unless intentionally removing race-authoring scaffolds.

## After Confirmation

Because this phase changes Studio scripts, config attributes, and route folders, refresh the Studio mirror after the phase is installed and tested:

```text
py scripts/receive_studio_full_snapshot_export.py
```

Then run this in the Roblox Studio Command Bar:

```text
scripts/roblox_studio_export_full_snapshot_for_github_v2.lua
```

Do not commit `docs/studio-full-export-paste.txt`.
