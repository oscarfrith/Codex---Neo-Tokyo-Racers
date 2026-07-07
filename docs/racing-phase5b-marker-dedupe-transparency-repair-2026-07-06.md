# Racing Phase 5B Marker Dedupe And Transparency Repair

**Created:** 2026-07-06  
**Script:** `scripts/roblox_racing_phase5b_marker_dedupe_transparency_repair.lua`  
**Status:** Generated in Git for Studio install/testing.

## Purpose

After Phase 5, the player reported two checkpoint markers stacked on top of each other and the current checkpoint frame feeling too opaque.

Root cause: the older Phase 3/4 race entry HUD marker still draws a `SelectionBox` plus `BillboardGui` while the new Phase 5 `RaceRouteGuideClient_Active` draws its local checkpoint/finish frame.

Phase 5B keeps the Phase 5 route guide as the single visual owner.

## What It Changes

The repair patches only isolated Racing client scripts:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceRouteGuideClient_Active
```

It:

- disables the older `RaceNextGateSelection` / `RaceNextGateBillboard` marker path by turning `ensureMarker` into a cleanup-only function;
- keeps the older marker cleanup hook so any already-created marker is destroyed;
- makes Phase 5 checkpoint/finish frames read `CheckpointFrameTransparency`;
- sets `ReplicatedStorage.NeoTokyoRacers.Config.Racing.RouteGuide.CheckpointFrameTransparency = 0.8`.

## Fragility Note

This is a guarded text-anchor repair against isolated Racing client scripts. If the exact source blocks are not found, the script stops and asks for a mirror/source refresh instead of guessing.

## Run Order

1. Open Studio in Edit mode.
2. Paste and run:

```text
scripts/roblox_racing_phase5b_marker_dedupe_transparency_repair.lua
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
2. Confirm there is only one checkpoint/finish guide instead of two stacked markers.
3. Confirm the frame is much lighter, using about 80% transparency.
4. Confirm the label, dynamic next-gate chevron, authored arrows, and wrong-way prompt still work.
5. Drive through checkpoints and finish; confirm the Phase 4 result panel and `RETRY` still work.

## Rollback

Preferred rollback is to rerun the last known working Racing Phase 5/Phase 4 scripts, then retest.

For visual tuning only, change:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.RouteGuide.CheckpointFrameTransparency
```

Lower values are more solid; higher values are more transparent.

## After Confirmation

Because this phase changes Studio scripts and config attributes, refresh the Studio mirror after it is installed and tested:

```text
py scripts/receive_studio_full_snapshot_export.py
```

Then run this in the Roblox Studio Command Bar:

```text
scripts/roblox_studio_export_full_snapshot_for_github_v2.lua
```

Do not commit `docs/studio-full-export-paste.txt`.
