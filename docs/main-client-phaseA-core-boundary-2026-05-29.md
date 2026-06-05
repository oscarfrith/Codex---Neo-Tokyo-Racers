# Main Client Phase A - Core Boundary Modules

**Created:** 2026-05-29  
**Current status:** Ready to run / module staging  
**Studio script:** `scripts/roblox_client_phaseA_core_boundary_modules.lua`

## Goal

Phase A creates the shared Core client modules needed before extracting screens and preview logic from `HOVER_RACING_V2_Client`.

This phase does **not** change live gameplay. It stages modules and runs basic require/parity checks.

## Modules Created

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientState
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.GarageApiClient
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.CatalogClient
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientThemeAdapter
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.PaintClient
```

## Responsibilities

`ClientState`:

- Default `State` shape.
- Safe state creation.
- Preview selection reset.

`GarageApiClient`:

- Wraps `GarageInvoke:InvokeServer`.
- Preserves current response shape.
- Updates `State.Profile` when a profile comes back.

`CatalogClient`:

- Category lookup.
- Slot sorting.
- Cockpit lookup.
- Module lookup.
- Slot-specific module list.
- Slot display names such as `Front Engine` and `Rear Engine`.

`ClientThemeAdapter`:

- Reads `UI_THEME_DoNotRename`.
- Falls back to current default theme values.

`PaintClient`:

- Paint channel detection.
- Module colour fallback logic.
- Colour application for primary, secondary, detail, neon, thrust colour, front lights, and rear lights.

## What It Does Not Do

This phase does not:

- Edit `HOVER_RACING_V2_Client`.
- Disable `HOVER_RACING_V2_Client`.
- Redirect live UI rendering.
- Redirect preview building.
- Redirect driving handoff.
- Change server actions.
- Change vehicle mechanics.

## Required Test

Run the script in Roblox Studio Command Bar in Edit mode.

Expected report:

```text
Live client edited: false
Live behaviour changed: false
Passed checks: all / all
```

Then run a normal Play test and confirm:

- dealership opens
- cash/profile loads
- cockpit cards render
- stats render
- customisation still works
- vehicle spawn/driving still works

## Rollback

Because this phase does not change live behaviour, rollback is simply removing or ignoring the staged Core modules.

Do not delete them unless Phase A caused a Studio issue.

## Codex Safety Notes

- Do not start Phase B unless Phase A checks pass and normal Play testing still works.
- Do not make `HOVER_RACING_V2_Client` require these modules until a dedicated adapter patch is planned.
- Keep UI screen extraction separate from this state/API/catalog boundary.
