# Dealership / Customisation Split Phase 2

**Date:** 2026-07-04  
**Status:** Prepared in Git for Studio install/testing  
**Script:** `scripts/roblox_dealership_customisation_split_phase2_owned_customisation_zone.lua`

## Goal

Add the separate owned-cockpit customisation entry point requested after Phase 1 made the dealership buy-only.

Phase 2:

- creates `Workspace.NeoTokyoRacersWorld.Dealership.Customisation.CustomisationDeskTrigger`;
- installs `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.CockpitCustomisationZoneClient_Active`;
- adds a `SelectVehicleInstance` server action;
- reuses the existing dealership-looking cockpit grid in a new customisation mode;
- filters that grid to owned cockpits only;
- opens the existing `Customise` stage after the player chooses an owned cockpit.

## Implementation Notes

This is intentionally condensed, but still limited to one feature area.

The new zone client is isolated. The only fragile parts are the guarded patches to:

- `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled`;
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`.

The customisation menu uses the same cockpit grid surface as the dealership. It switches the screen into `Customisation` mode, changes the title/subtitle, hides unowned cockpits from the grid, changes card bottom text to `Owned xN`, and swaps the right-panel action to `Customise`.

The new server action selects the first owned vehicle instance matching the chosen cockpit template. If multiple copies of the same cockpit exist, this phase does not expose per-copy selection yet.

## Studio Steps

1. Confirm Phase 1 has already been run and tested.
2. In Studio Edit mode, run:

```text
scripts/roblox_dealership_customisation_split_phase2_owned_customisation_zone.lua
```

3. Move `Workspace.NeoTokyoRacersWorld.Dealership.Customisation.CustomisationDeskTrigger` in Studio if the generated position is not where you want it. The installer places it near the existing dealership desk trigger as a starting point.
4. Restart Play.
5. Buy/own at least one cockpit.
6. Walk into the new customisation trigger zone.

## Manual Verification

- Dealership desk still opens in buy-only mode.
- Dealership still shows `Buy` / `Buy Another`, not `Select`.
- Customisation zone opens a menu with the same dealership visual style.
- Customisation grid shows only owned cockpits.
- Owned cockpit cards show `Owned xN`.
- The right panel shows `Customise`.
- Pressing `Customise` opens the existing customisation screen for the selected owned vehicle.
- Start Driving still spawns the selected/customised vehicle.
- If the player owns no cockpits, the customisation zone should not show unowned cockpits as selectable.

## Rollback

Use Roblox version history for the Studio-side source and hierarchy changes.

Manual rollback points:

- remove or disable `CockpitCustomisationZoneClient_Active`;
- remove or move aside `Workspace.NeoTokyoRacersWorld.Dealership.Customisation.CustomisationDeskTrigger`;
- restore the previous active bootstrap and garage action controller sources.

Do not rerun Phase 1 rollback unless you intentionally want the dealership to become a combined buy/select menu again.
