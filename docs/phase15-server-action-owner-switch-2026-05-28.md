# Phase 15 Server Action Owner Switch

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Switched and tested  
**Studio script:** `scripts/roblox_hierarchy_phase15_server_action_owner_switch.lua`

## Goal

Phase 15 performs the first live server architecture switch: the server action owner moves from the legacy `HOVER_RACING_V2_Server` script to the Phase 14 shadow action controller.

This is still a conservative switch. It does not rewrite the server logic; it moves ownership to the same verified V56 block in the new architecture.

## Modes

At the top of the script:

```lua
local MODE = "SWITCH"
```

Use:

```lua
local MODE = "ROLLBACK"
```

to undo the switch.

## What SWITCH Does

```text
HOVER_RACING_V2_Server.Disabled = true
GarageActionController_Shadow_Disabled.Disabled = false
```

It also sets attributes to show which script currently owns server actions.

## What ROLLBACK Does

```text
HOVER_RACING_V2_Server.Disabled = false
GarageActionController_Shadow_Disabled.Disabled = true
```

## What It Does Not Change

The script does not:

- Edit script source.
- Delete, clone, move, or rename anything.
- Change client UI, driving, VFX, mobile controls, LOD, lighting, traffic, assets, or `Workspace.Test + WIP Assets`.

## Required Test After SWITCH

After running with `MODE = "SWITCH"`:

1. Stop any running Play test.
2. Start a fresh Play test.
3. Confirm Output shows the V56 controller active from `GarageActionController_Shadow_Disabled`.
4. Run Phase 13 in Server context.
5. Run Phase 13B in Client context.
6. Test cash, dealership, purchases, customisation, vehicle spawn, driving, exit/re-enter.
7. If anything fails, run Phase 15 again with `MODE = "ROLLBACK"`.

## Confirmed Result

Tested by the user on 2026-05-28 after running `MODE = "SWITCH"`.

Confirmed output:

```text
[V56] Consolidated server action controller is active. - Server - GarageActionController_Shadow_Disabled:812
```

Phase 13 after the switch:

```text
Snapshot hash: 3be69270
Current hash: 3be69270
Hash matches snapshot: true
V56 markers found: true
```

Phase 13B after the switch:

```text
InvokeServer call succeeded: true
Response shape passed: true
Cash field type: number
Catalog field type: table
TotalStats field type: table
```

Gameplay tested successfully:

- Cash loads.
- Dealership works.
- Purchases work.
- Customisation works.
- Vehicle spawn works.
- Driving works.
- Exit/re-enter works.

Rollback remains available by changing `MODE` to `ROLLBACK`, but is not currently needed.

## Codex Safety Notes

- Do not combine this switch with runtime or UI extraction.
- Do not delete the legacy server script after the switch. Keep it until multiple tests pass.
- If rollback is needed, use the built-in mode instead of manually changing several scripts.
