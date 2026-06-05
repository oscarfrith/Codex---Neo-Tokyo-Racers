# Phase 18 LOD Client Owner Switch

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Switched and tested  
**Studio script:** `scripts/roblox_hierarchy_phase18_lod_client_owner_switch.lua`

## Goal

Phase 18 moves the live LOD client into the new world controller architecture without changing its source logic.

This is a conservative owner-location switch for the existing LOD system.

## Script Included

Old owner:

```text
StarterPlayer.StarterPlayerScripts.LOD System
```

New owner:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active
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

Copies the exact current source from the old LOD script into the new world controller owner, then:

```text
Old LOD System disabled
New LODClient_Active enabled
```

## What ROLLBACK Does

```text
Old LOD System enabled
New LODClient_Active disabled
```

## Required Test After SWITCH

After running with `MODE = "SWITCH"`:

1. Stop any current Play test.
2. Start a fresh Play test.
3. Confirm Output shows:

```text
LOD Script Running
Registered blocks: 84
```

or the current expected block count.

4. Drive around and confirm nearby city blocks do not disappear incorrectly.
5. Confirm far LOD visibility still works as before.
6. Confirm dealership, vehicle spawn, driving, VFX, mobile controls, exit, and re-entry still work.
7. If anything fails, run the same script again with `MODE = "ROLLBACK"`.

## Codex Safety Notes

- Do not edit LOD thresholds in this phase.
- Do not edit city assets or `FarLOD5` in this phase.
- Do not remove the old `LOD System` script until this switch has passed repeated tests.
- This phase is a location/ownership switch only.

## Confirmed Result

Tested by the user on 2026-05-28 after running `MODE = "SWITCH"`.

Confirmed working:

- LOD client ownership switch completed successfully.
- LOD output and city visibility were not reported as broken.
- Vehicle, dealership, runtime helpers, driving, VFX, mobile controls, exit, and re-entry still work.
