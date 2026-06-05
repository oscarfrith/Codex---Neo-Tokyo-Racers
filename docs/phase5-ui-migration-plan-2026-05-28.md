# Phase 5 UI Migration Plan

**Document status:** Active migration plan  
**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Phase 5A script prepared / no live UI switch yet  

## Goal

Phase 5 moves the UI system toward a cleaner architecture without risking the currently working dealership, customisation, mobile controls, or driving systems.

The current live UI still runs mainly through:

```text
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client
```

That script is large and still owns too many jobs, so Phase 5 should not attempt a full split in one patch.

## Phase 5A: UI Helper Shadow Extraction

Prepared script:

```text
scripts/roblox_hierarchy_phase5_ui_module_shadow_extract.lua
```

This script creates/refines:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI
StarterGui.NeoTokyoRacersUI.Components
StarterGui.NeoTokyoRacersUI.Templates
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI
```

It copies the current live helper modules into the new architecture as shadow modules:

```text
UITheme_Shadow
UIPool_Shadow
UIFactory_Shadow
```

These are not live yet. They are safe reference copies so future UI migration can happen from a known structure.

## Why Shadow Extraction First

The main client script currently handles UI, preview vehicles, garage camera, drive HUD, mobile input bridge, and driving bootstrap code. Directly moving UI functions out of that file would be risky because many local functions share state.

Shadow extraction lets future work happen in smaller steps:

1. Stage helper modules.
2. Confirm the game still works.
3. Move one UI surface at a time into a controller.
4. Switch only that surface after testing.

## Future Target Structure

Recommended long-term client structure:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient
- Bootstrap
- Controllers
  - UI
  - Garage
  - Dealership
  - Customisation
  - Preview
  - Camera
  - Driving
  - Mobile
  - HUD
  - VFX
  - World
```

Recommended shared UI structure:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI
- UITheme
- UIFactory
- UIPool
- ResponsiveLayout
- ColourPicker
- ArrowScroller
- StatBars
```

## Recommended Extraction Order

1. `UITheme`, `UIFactory`, and `UIPool`.
2. Shared low-risk widgets: panels, buttons, labels, stat bars, and arrow scrollers.
3. Colour picker.
4. Dealership grid.
5. Module shop bottom bar.
6. Customisation panel.
7. Drive HUD and mobile/desktop HUD ownership.

## Mobile Performance Rules

- Create UI panels once, then reuse.
- Use `UIPool` for lists and grids.
- Avoid scanning all of `PlayerGui` during driving.
- Avoid destroying/recreating buttons during rapid menu changes.
- Keep mobile and desktop HUDs explicitly separated.
- Keep text readable before adding dense information.

## Codex Safety Notes

- Do not rewrite `HOVER_RACING_V2_Client` just to make the folder structure look cleaner.
- Do not switch live UI to shadow modules until the shadow modules have been tested.
- Do not touch driving or VFX when working only on UI.
- Do not touch `Workspace.Test + WIP Assets`.
- Prefer one menu surface per migration step.
