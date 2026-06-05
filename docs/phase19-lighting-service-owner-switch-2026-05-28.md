# Phase 19 Lighting Service Owner Switch

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Switched and tested  
**Studio script:** `scripts/roblox_hierarchy_phase19_lighting_service_owner_switch.lua`

## Goal

Phase 19 moves the server lighting preset owner into the new world lighting service architecture without changing its source logic.

This only moves the startup/default lighting owner. It does not change lighting values.

## Script Included

Old owner:

```text
ServerScriptService.Lighting.LightingController
```

New owner:

```text
ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Active
```

## Intentionally Not Moved

`TEMP_LightingPreview` remains in place as the intentional client-side day/night preview tool.

Known preview keys:

```text
N = ClearNight
M = Day
```

## Modes

At the top of the script:

```lua
local MODE = "SWITCH"
```

Available modes:

```text
STAGE_ONLY
SWITCH
ROLLBACK
```

## What SWITCH Does

Copies the exact current source from the old lighting controller into the new world lighting service owner, then:

```text
Old LightingController disabled
New LightingService_Active enabled
```

## What ROLLBACK Does

```text
Old LightingController enabled
New LightingService_Active disabled
```

## Required Test After SWITCH

After running with `MODE = "SWITCH"`:

1. Stop any current Play test.
2. Start a fresh Play test.
3. Confirm Output shows:

```text
Applied lighting preset: Day
```

from `LightingService_Active`.

4. Confirm day lighting applies normally on startup.
5. Press `N` and `M` to confirm `TEMP_LightingPreview` still switches ClearNight/Day.
6. Confirm dealership, vehicle spawn, driving, LOD, traffic, VFX, mobile controls, exit, and re-entry still work.
7. If anything fails, run the same script again with `MODE = "ROLLBACK"`.

## Codex Safety Notes

- Do not edit lighting preset values in this phase.
- Do not edit `SkyPresets` in this phase.
- Do not move or remove `TEMP_LightingPreview` in this phase.
- Do not remove the old `LightingController` until this switch has passed repeated tests.
- This phase is a location/ownership switch only.

## Confirmed Result

Tested by the user on 2026-05-28 after running `MODE = "SWITCH"`.

Confirmed working:

- Server lighting owner switch completed successfully.
- Day lighting applies on startup.
- `TEMP_LightingPreview` remains available for `N` / `M` day-night testing.
- Dealership, spawn, driving, LOD, traffic, VFX, mobile controls, exit, and re-entry were not reported as broken.
