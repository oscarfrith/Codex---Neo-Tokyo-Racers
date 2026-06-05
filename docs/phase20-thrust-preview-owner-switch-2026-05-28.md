# Phase 20 Thrust Preview Owner Switch

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Switched and tested  
**Studio script:** `scripts/roblox_hierarchy_phase20_thrust_preview_owner_switch.lua`

## Goal

Phase 20 moves the thrust preview / mobile touch visibility helper into the new preview controller architecture without changing its source logic.

This is an owner-location switch, not a behavioural rewrite.

## Script Included

Old owner:

```text
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V46_ThrustPreviewOnly
```

New owner:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.ThrustPreviewController_Active
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

Copies the exact current source from the old thrust preview script into the new preview controller owner, then:

```text
Old HOVER_RACING_V46_ThrustPreviewOnly disabled
New ThrustPreviewController_Active enabled
```

## What ROLLBACK Does

```text
Old HOVER_RACING_V46_ThrustPreviewOnly enabled
New ThrustPreviewController_Active disabled
```

## Required Test After SWITCH

After running with `MODE = "SWITCH"`:

1. Stop any current Play test.
2. Start a fresh Play test.
3. Open dealership/customisation and confirm preview behaviour is unchanged.
4. Confirm thrust colour preview still shows selected colours during customisation.
5. Confirm Roblox mobile touch controls still hide while in menus.
6. Spawn and drive a vehicle.
7. Confirm drive camera handoff still works.
8. Confirm VFX, mobile controls, LOD, lighting, traffic, exit, and re-entry still work.
9. If anything fails, run the same script again with `MODE = "ROLLBACK"`.

## Codex Safety Notes

- Do not edit VFX logic in this phase.
- Do not edit camera logic in this phase.
- Do not edit mobile control behaviour in this phase.
- Do not edit `HOVER_RACING_V2_Client` in this phase.
- Do not remove the old thrust preview script until this switch has passed repeated tests.
- This phase is a location/ownership switch only.

## Confirmed Result

Tested by the user on 2026-05-28 after running `MODE = "SWITCH"`.

Confirmed working:

- Thrust preview owner switch completed successfully.
- Dealership/customisation preview behaviour still works.
- Thrust colour preview still works.
- Mobile touch control visibility and drive camera handoff were not reported as broken.
- Driving, VFX, mobile controls, LOD, lighting, traffic, exit, and re-entry still work.
