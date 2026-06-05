# Phase 10 Runtime Controller Scaffold

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Prepared  
**Studio script:** `scripts/roblox_hierarchy_phase10_runtime_controller_scaffold.lua`

## Goal

Phase 10 creates the future runtime controller structure for driving bootstrap, mobile controls, HUD ownership, VFX ownership, and vehicle access handling.

The current runtime scripts stay live. This phase only prepares a clean ownership target so later work can remove patch-style suppressor layers without breaking working driving.

## What The Script Creates

Under `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime`:

```text
DrivingBootstrapController
DriveCameraController
DriveHudController
MobileDriveControlsController
RuntimeVFXController
VehicleAccessController
```

Under `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.RuntimeState`:

```text
RuntimeSessionState
```

Under `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Runtime`:

```text
RuntimeControllerConfig
RuntimeMigrationMap
```

Under `ReplicatedStorage.NeoTokyoRacers.Compatibility`, the script records references to current active runtime owners where found:

```text
CurrentRuntimeMainClient
CurrentRuntimeMobileControls
CurrentRuntimeMobileHudSuppressor
CurrentRuntimeThrustPreview
CurrentRuntimeCachedThrustScript
CurrentDrivingControllerV47
CurrentMobileDriveInputState
CurrentReentryThrottle
CurrentCachedThrustVisualRuntime
CurrentVehicleVFXController
```

## What It Does Not Change

The script does not:

- Edit, disable, rename, require, or replace active runtime scripts.
- Change `DrivingControllerV47`.
- Change mobile controls.
- Change desktop/mobile HUD behaviour.
- Change cached VFX or thrust preview behaviour.
- Change garage UI, server actions, LOD, lighting, traffic, or assets.

## Future Ownership Map

The created `RuntimeMigrationMap` records this intended ownership:

- `DrivingBootstrapController`: starts/stops `DrivingControllerV47` and owns the garage-to-driving handoff.
- `DriveCameraController`: future owner for in-car camera assist.
- `DriveHudController`: single owner for desktop and mobile drive HUD visibility/values.
- `MobileDriveControlsController`: single owner for mobile pedals, steering, drift, and boost.
- `RuntimeVFXController`: single owner for live driving VFX state, cache, colours, and cleanup.
- `VehicleAccessController`: exit/re-enter handling and future cockpit access prompts.

## Test Checklist

After running the Studio script:

- Vehicle driving still feels the same.
- Desktop driving HUD still appears on desktop.
- Mobile driving HUD and mobile controls still appear on mobile.
- PC HUD does not flicker on mobile.
- VFX still appears during driving.
- Exit and re-enter still work.
- Dealership/customisation still work.
- New runtime modules exist but are not required by live code.

## Codex Safety Notes

- Do not remove `HOVER_RACING_V71_MobilePcHudSuppressor` until `DriveHudController` fully owns desktop/mobile HUD visibility.
- Do not remove `HOVER_RACING_V67_MobileDriveControls` until `MobileDriveControlsController` is tested on real mobile or emulator.
- Do not replace `DrivingControllerV47`; wrap/bootstrap it.
- Keep VFX cached and client-side.
- Do not combine runtime consolidation with server action or garage UI extraction.
