# Main Client Phase C - Garage Screen Controllers

**Created:** 2026-05-29  
**Current status:** Ready to run / module staging  
**Studio script:** `scripts/roblox_client_phaseC_garage_screen_controllers.lua`

## Goal

Phase C creates staged garage screen controller modules for the future extraction of `HOVER_RACING_V2_Client`.

This phase keeps the existing live client in control, but prepares dedicated controller boundaries for dealership, cockpit paint, module shop, customisation, navigation, and stats-panel logic.

## Requires

Phase A and Phase B must already be installed and play-tested.

Required Phase A modules:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientState
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.GarageApiClient
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.CatalogClient
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientThemeAdapter
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.PaintClient
```

Required Phase B modules:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewCameraController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewVehicleController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.ColourPickerController
```

## Modules Created Or Updated

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DealershipUIController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.CockpitPaintUIController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.ModuleShopUIController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.CustomisationUIController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.NavigationController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.StatsPanelController
```

## Responsibilities

`DealershipUIController`:

- Category list view data.
- Cockpit card view data.
- Selected cockpit stats/slots/cash data.

`CockpitPaintUIController`:

- Cockpit paint channel list.
- Local cockpit colour update helper.
- Staged colour picker integration point.

`ModuleShopUIController`:

- Fixed slot view data.
- Module option view data.
- Buy/equip action label logic.
- Preview-module selection state.
- Camera section request via `PreviewCameraController`.

`CustomisationUIController`:

- Customisation target list.
- Cockpit/module/all/thrust colour channel decisions.
- Colour/cosmetics/upgrade action data.
- Local colour update helper.

`NavigationController`:

- Next/back route mapping.
- Button text mapping.

`StatsPanelController`:

- Stat row ordering.
- Bar normalisation.
- Positive/negative stat delta view data.

## What It Does Not Do

This phase does not:

- Edit `HOVER_RACING_V2_Client`.
- Disable `HOVER_RACING_V2_Client`.
- Redirect live dealership rendering.
- Redirect live cockpit paint rendering.
- Redirect live module shop rendering.
- Redirect live customisation rendering.
- Redirect live navigation or stats rendering.
- Change server actions.
- Change preview, camera, driving, VFX runtime, mobile controls, LOD, lighting, or traffic systems.

## Required Test

Run the script in Roblox Studio Command Bar in Edit mode.

Expected report:

```text
Live client edited: false
Live behaviour changed: false
Phase A modules present: true
Phase B modules present: true
Passed checks: 6 / 6
```

Then run a normal Play test and confirm:

- dealership opens
- categories and cockpit cards still appear
- cockpit paint still works
- module shop still works
- customisation still works
- next/back still works
- stats panels still appear
- vehicle spawn/driving still works

## Rollback

Because this phase does not switch live behaviour, rollback is simply ignoring the staged Phase C modules.

Do not delete the modules unless Studio reports a specific problem with them.

## Codex Safety Notes

- Phase D is the risky phase because it starts replacing the live main client owner.
- Do not start Phase D unless Phase C checks pass and the full garage flow is play-tested.
- Do not rewrite driving mechanics during Phase D.
- Keep `DrivingControllerV47`, mobile controls, VFX runtime, LOD, lighting, and server actions separate from the main client extraction.
