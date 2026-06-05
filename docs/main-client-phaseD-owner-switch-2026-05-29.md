# Main Client Phase D - Owner Switch

**Created:** 2026-05-29  
**Current status:** Switched and tested  
**Studio script:** `scripts/roblox_client_phaseD_main_client_owner_switch.lua`

## Goal

Phase D moves the remaining active legacy-named main client owner into the new `NeoTokyoRacersClient` architecture.

This phase intentionally does **not** rewrite the main client internals yet. It copies the tested `HOVER_RACING_V2_Client` source into a new architecture location, then allows a controlled owner switch.

This is safer than trying to replace all live garage UI/rendering with the staged Phase A-C modules in one step.

## Why This Phase Is Different

Phases A-C staged clean boundaries:

- Core state/API/catalog/theme/paint modules
- Preview and colour modules
- Garage screen controller modules

Those staged modules are not complete live replacements for every UI line inside `HOVER_RACING_V2_Client`.

Therefore Phase D uses a conservative owner switch:

```text
Old live owner:
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client

New live owner after SWITCH:
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

The new script name still includes `_Shadow_Disabled` because it is a switch candidate and rollback target. When enabled by the script, it becomes the active owner despite the conservative name.

## Modes

At the top of the script:

```lua
local MODE = "SHADOW"
```

Use:

```lua
local MODE = "SWITCH"
```

to switch ownership.

Use:

```lua
local MODE = "ROLLBACK"
```

to undo the switch.

## What SHADOW Does

```text
Reads HOVER_RACING_V2_Client.Source
Creates/updates NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
Keeps the shadow client disabled
Stores a source hash for switch safety
```

## What SWITCH Does

```text
NeoTokyoRacersClient_Bootstrap_Shadow_Disabled.Disabled = false
HOVER_RACING_V2_Client.Disabled = true
```

It also checks that the shadow source hash still matches the legacy source.

## What ROLLBACK Does

```text
HOVER_RACING_V2_Client.Disabled = false
NeoTokyoRacersClient_Bootstrap_Shadow_Disabled.Disabled = true
```

## What It Does Not Change

The script does not:

- Rewrite the main client internals.
- Delete, move, or rename the legacy client.
- Switch to the staged Phase A-C modules yet.
- Change server actions.
- Change driving internals.
- Change VFX runtime.
- Change mobile controls.
- Change LOD, lighting, traffic, assets, or `Workspace.Test + WIP Assets`.

## Required Test Order

1. Run the script in Edit mode with:

```lua
local MODE = "SHADOW"
```

2. Confirm the report says:

```text
Status: Shadow client created/updated and remains disabled.
Internal client logic rewritten: false
Phase A-C module switch performed: false
```

3. Change the script to:

```lua
local MODE = "SWITCH"
```

4. Run it again in Edit mode.

5. Start a fresh Play test.

6. Confirm:

- dealership opens
- cockpit paint works
- module shop works
- customisation works
- spawn works
- driving works
- exit/re-enter works
- mobile controls work if available
- Output still shows the V75 driving controller active

7. If anything fails, run:

```lua
local MODE = "ROLLBACK"
```

## Expected Output After SWITCH

```text
Legacy disabled after: true
Shadow disabled after: false
Internal client logic rewritten: false
Phase A-C module switch performed: false
```

## Confirmed Result

Tested by the user on 2026-05-29 after running `MODE = "SWITCH"`.

Confirmed state from the Phase E audit:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled -> enabled
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client -> disabled
```

Gameplay was tested successfully after the switch.

## Rollback

Rollback is built into the script.

Do not manually delete or move either client script.

## Codex Safety Notes

- Do not combine Phase D with gameplay changes.
- Do not delete the disabled legacy client after a successful switch.
- Do not rename the active shadow client until Phase E audit passes.
- Future internal extraction can gradually make the active bootstrap require Phase A-C modules, but that should happen after this owner-location switch is stable.
