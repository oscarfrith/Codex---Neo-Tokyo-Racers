# Phase 17 Driver Seat Owner Switch

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Switched and tested  
**Studio script:** `scripts/roblox_hierarchy_phase17_driver_seat_owner_switch.lua`

## Goal

Phase 17 moves the driver seat position keeper into the new vehicle service architecture without changing its source logic.

This is another conservative ownership/location switch.

## Script Included

Old owner:

```text
ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_DriverSeatPosition
```

New owner:

```text
ServerScriptService.NeoTokyoRacers.Services.Vehicle.DriverSeatPositionService_Active
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

Copies the exact current source from the old driver seat script into the new vehicle service owner, then:

```text
Old driver seat script disabled
New driver seat service enabled
```

## What ROLLBACK Does

```text
Old driver seat script enabled
New driver seat service disabled
```

## Required Test After SWITCH

After running with `MODE = "SWITCH"`:

1. Stop any current Play test.
2. Start a fresh Play test.
3. Confirm Output shows:

```text
Hover Racing driver seat position keeper running.
```

from `DriverSeatPositionService_Active`.

4. Spawn a vehicle.
5. Confirm the player is seated in the expected position.
6. Confirm driving, exit, and re-entry still work.
7. If anything fails, run the same script again with `MODE = "ROLLBACK"`.

## Codex Safety Notes

- Do not edit driving physics in this phase.
- Do not edit vehicle spawn/build logic in this phase.
- Do not remove the old driver seat script until this switch has passed repeated tests.
- This phase is a location/ownership switch only.

## Confirmed Result

Tested by the user on 2026-05-28 after running `MODE = "SWITCH"`.

Confirmed working:

- Driver seat position keeper ownership switch completed successfully.
- Vehicle spawn still works.
- The player is seated correctly.
- Driving, exit, and re-entry still work.
