# Lighting Phase AS: Stage Visual Configuration

**Created:** 2026-07-13
**Status:** Installed and mirrored through 2026-07-14 00:15:37; runtime verification still recommended

## Purpose

Phase AS gives window materials and managed lamppost settings explicit per-stage
configuration ownership, separate from captured Lighting, effects, and Sky.

## Studio Script

After Phase AR, run in Edit mode:

```text
scripts/roblox_lighting_phaseAS_stage_visual_config.lua
```

It creates:

```text
ReplicatedStorage.Shared.LightingCycleConfig.StageVisuals
```

Each stage has its own Folder with these editable attributes:

```text
WindowMode = "Day" or "Night"
StreetLightsEnabled = true or false
StreetLightBrightness = number, minimum 0
```

The installer initializes window/enabled values from the schedule and brightness
from `LightingCycleConfig.DefaultStreetLightBrightness`, default `1`. It does
not read the current live windows or lampposts when creating config.

## Editing Workflow

Current Edit view to selected preset:

```text
scripts/roblox_lighting_capture_current_to_selected_stages.lua
```

The capture stores only Lighting, atmosphere, effects, and Sky. It intentionally
does not overwrite StageVisuals attributes.

Selected preset to Edit view:

```text
scripts/roblox_lighting_preview_selected_stage_edit_mode.lua
```

The preview restores the environmental preset, then applies window mode,
lamppost enabled state, and brightness from the preset's StageVisuals folder.

## Runtime

The isolated window and lamppost client controllers read the current preset's
StageVisuals folder. Attribute edits are event-driven and streamed/tagged
instances receive the current configuration when they appear. There is no frame
loop or whole-world repeated scan.

## Verification

1. Run Phase AS in Edit mode.
2. Run `scripts/roblox_lighting_phaseAQ_audit.lua`; expect `fail=0`.
3. Edit one stage folder's WindowMode, StreetLightsEnabled, and brightness.
4. Capture new environmental Lighting to that stage; confirm its visual config
   attributes are unchanged.
5. Preview a different stage, then preview the edited stage again.
6. Confirm its window mode, enabled state, and brightness match the config.
7. Start Play and use keys 1-8 to confirm runtime stages use their folders.

## Rollback And Scope

Use Roblox place version history. Phase AS creates no in-game backups. It
canonically replaces only the two isolated lighting visual controllers and adds
the StageVisuals config folders. It does not touch driving, UI, racing, VFX, LOD,
or server gameplay and uses no fragile source-text replacement.
