# Phase 7 Shared UI Helpers

**Document status:** Active migration plan  
**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Phase 7 script prepared / no live UI switch yet  

## Goal

Phase 7 promotes the staged UI helper work into final clean module names inside the new `NeoTokyoRacers` architecture.

This phase still does not switch the working garage/dealership/customisation UI. It prepares the shared modules that Phase 8 can use when extracting the current large client script into smaller UI controllers.

## Prepared Script

```text
scripts/roblox_hierarchy_phase7_shared_ui_helpers_promote.lua
```

## What Phase 7 Creates

Shared UI modules:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI
- UITheme
- UIPool
- UIFactory
- ResponsiveLayout
- ArrowScroller
- StatBars
- ColourUtils
```

Editable UI config:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI.Theme
```

The config is mirrored from:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT.UI_THEME_DoNotRename
```

Current live UI still reads the old folder until Phase 8 deliberately switches one UI surface at a time.

## Why This Is Safe

- The script creates or updates only new architecture modules and config mirrors.
- It does not edit `HOVER_RACING_V2_Client`.
- It does not require or run the new modules.
- It does not touch driving, server actions, VFX, LOD, lighting, traffic, or vehicle assets.

## How These Modules Should Be Used Later

Phase 8 should extract one UI surface at a time and use these helpers:

- `UITheme` for theme values.
- `UIFactory` for panels, labels, buttons, and strokes.
- `UIPool` for repeated cards/buttons.
- `ResponsiveLayout` for mobile-safe sizing.
- `ArrowScroller` for left/right or up/down scroll buttons.
- `StatBars` for vehicle stat panels.
- `ColourUtils` for HSB/HSV colour picker logic.

## Codex Safety Notes

- Do not switch all UI at once.
- Do not delete `HOVER_RACING_V2_KIT.UI_THEME_DoNotRename` yet.
- Do not rename the current live garage UI until the extracted UI controllers are tested.
- Keep mobile readability and button size as a first-class requirement.
