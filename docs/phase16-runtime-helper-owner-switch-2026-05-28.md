# Phase 16 Runtime Helper Owner Switch

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Switched and tested  
**Studio script:** `scripts/roblox_hierarchy_phase16_runtime_helper_owner_switch.lua`

## Goal

Phase 16 moves the small runtime helper `LocalScript` owners into the new `NeoTokyoRacersClient.Controllers.Runtime` architecture without changing their source logic.

This is intentionally similar to Phase 15: it switches ownership locations, not behaviour.

## Runtime Helpers Included

```text
HOVER_RACING_V64_CachedThrustVisualRuntime
HOVER_RACING_V67_MobileDriveControls
HOVER_RACING_V71_MobilePcHudSuppressor
```

Target scripts:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.DriveHudController_Active
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

Copies exact source from the old helper scripts into the new runtime owner scripts, then:

```text
Old root helper scripts disabled
New runtime owner scripts enabled
```

No driving, UI, VFX, mobile, server, lighting, LOD, traffic, or asset source logic is rewritten.

## What ROLLBACK Does

```text
Old root helper scripts enabled
New runtime owner scripts disabled
```

## Required Test After SWITCH

After running with `MODE = "SWITCH"`:

1. Stop any current Play test.
2. Start a fresh Play test.
3. Confirm mobile controls still appear only on mobile/touch emulation.
4. Confirm the desktop HUD does not flicker on mobile.
5. Confirm VFX still appear while driving.
6. Confirm dealership, customisation, vehicle spawn, driving, exit, and re-entry still work.
7. If anything fails, run the same script again with `MODE = "ROLLBACK"`.

## Codex Safety Notes

- Do not combine this with edits to `HOVER_RACING_V2_Client`.
- Do not rewrite `DrivingControllerV47` in this phase.
- Do not remove the old root helper scripts until this switch has passed repeated tests.
- This phase is a location/ownership switch only.

## Confirmed Result

Tested by the user on 2026-05-28 after running `MODE = "SWITCH"`.

Confirmed working:

- Runtime helper ownership switch completed successfully.
- Mobile controls still work.
- Mobile/desktop HUD suppression still works.
- Cached thrust VFX runtime still works.
- Dealership, customisation, vehicle spawn, driving, exit, and re-entry were not reported as broken.
