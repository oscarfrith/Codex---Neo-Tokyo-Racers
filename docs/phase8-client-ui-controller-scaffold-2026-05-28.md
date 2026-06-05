# Phase 8 Client UI Controller Scaffold

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Prepared  
**Studio script:** `scripts/roblox_hierarchy_phase8_client_ui_controller_scaffold.lua`

## Goal

Phase 8 creates the target client UI controller structure without switching the live UI away from `HOVER_RACING_V2_Client`.

This is a staging phase. It gives future Codex sessions a clean place to move dealership, paint, module shop, customisation, preview, navigation, cash, and stats logic one menu at a time.

## What The Script Creates

Under `StarterPlayer.StarterPlayerScripts`:

```text
NeoTokyoRacersClient
+-- NeoTokyoRacersClient_Bootstrap_Disabled
+-- Controllers
|   +-- Garage
|   |   +-- GarageCameraController
|   +-- Preview
|   |   +-- PreviewVehicleController
|   +-- Runtime
|   |   +-- DrivingClientBridge
|   +-- UI
|       +-- CashPanelController
|       +-- CockpitPaintUIController
|       +-- ColourPickerController
|       +-- CustomisationUIController
|       +-- DealershipUIController
|       +-- ModuleShopUIController
|       +-- NavigationController
|       +-- StatsPanelController
+-- State
    +-- ClientSessionState
```

Under `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI`:

```text
GarageUIMigrationMap
GarageUIRouter
GarageUIState
```

Under `ReplicatedStorage.NeoTokyoRacers.Compatibility`:

```text
CurrentLiveClient
FutureClientRoot
```

## What It Does Not Change

The script does not:

- Edit `HOVER_RACING_V2_Client`.
- Enable the future bootstrap.
- Require the new controller modules from live code.
- Change dealership, paint, module shop, customisation, preview, driving, VFX, mobile controls, server actions, LOD, lighting, traffic, or city assets.

## Future Migration Map

The created `GarageUIMigrationMap` records the intended split:

- `DealershipUIController`: cockpit category/grid UI.
- `CockpitPaintUIController`: cockpit paint UI.
- `ModuleShopUIController`: fixed slot module shop UI.
- `CustomisationUIController`: upgrade, cosmetics, and module colour editing UI.
- `ColourPickerController`: shared default colours and HSB picker.
- `StatsPanelController`: stat bars and preview deltas.
- `NavigationController`: top title, next/back, and stage routing.
- `CashPanelController`: available cash and Get More panel.
- `PreviewVehicleController`: garage preview vehicle assembly.
- `GarageCameraController`: garage orbit/section camera.
- `DrivingClientBridge`: future handoff into the existing driving controller, not a replacement for `DrivingControllerV47`.

## Test Checklist

After running the Studio script:

- Menus still open normally.
- Dealership cockpit selection still works.
- Cockpit paint still works.
- Module shop still works.
- Customisation still works.
- Vehicle preview still appears.
- Driving still works.
- Mobile controls and mobile HUD still work.
- New scaffold folders exist but the future bootstrap remains disabled.

## Codex Safety Notes

- Do not switch the full live UI in one pass.
- Move one UI surface at a time from `HOVER_RACING_V2_Client`.
- Do not combine UI extraction with driving or server service rewrites.
- Keep `DrivingControllerV47` as the driving source of truth.
- Keep `Workspace.Test + WIP Assets` excluded.
