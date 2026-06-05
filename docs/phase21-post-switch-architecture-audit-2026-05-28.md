# Phase 21 Post-Switch Architecture Audit

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Passed / clean checkpoint  
**Studio script:** `scripts/roblox_hierarchy_phase21_post_switch_audit.lua`

## Goal

Phase 21 is a larger checkpoint audit after Phases 15-20.

It verifies:

- New owner scripts are active.
- Replaced legacy owner scripts are disabled.
- No unexpected active scripts have appeared.
- Nothing active exists inside `Workspace.Test + WIP Assets`.
- The remaining big legacy owner is clearly identified before any future refactor.

## What It Checks

Expected active owners include:

```text
GarageActionController_Shadow_Disabled
DriverSeatPositionService_Active
LightingService_Active
TrafficLightService
LODClient_Active
RuntimeVFXController_Active
MobileDriveControlsController_Active
DriveHudController_Active
ThrustPreviewController_Active
HOVER_RACING_V2_Client
TEMP_LightingPreview
```

Expected disabled owners include replaced legacy scripts such as:

```text
HOVER_RACING_V2_Server
HOVER_RACING_V2_DriverSeatPosition
LightingController
Traffic Lights
LOD System
HOVER_RACING_V46_ThrustPreviewOnly
HOVER_RACING_V64_CachedThrustVisualRuntime
HOVER_RACING_V67_MobileDriveControls
HOVER_RACING_V71_MobilePcHudSuppressor
```

## What It Does

The script writes a report to:

```text
ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports.Phase21_PostSwitchArchitectureAudit
```

## What It Does Not Do

It does not:

- Move anything.
- Rename anything.
- Disable or enable anything.
- Delete anything.
- Edit source code.
- Change gameplay behaviour.

## Required Test

Run in Edit mode or Play mode.

The desired clean result is:

```text
Unexpected active scripts: 0
Expected disabled owners currently enabled: 0
Missing expected active owners: 0
Active scripts inside excluded Test + WIP Assets: 0
```

## Codex Safety Notes

- If this audit is clean, commit the Phase 16-21 checkpoint.
- Do not delete disabled legacy owners yet.
- Do not try to extract `HOVER_RACING_V2_Client` as a quick patch.
- Treat the main client extraction as a separate refactor plan.

## Confirmed Result

Tested by the user on 2026-05-28.

Clean audit result:

```text
Expected active owners enabled: 11 / 11
Missing expected active owners: 0
Expected active owners currently disabled: 0
Expected disabled owners currently enabled: 0
Unexpected active scripts: 0
Active scripts inside excluded Test + WIP Assets: 0
Active legacy-named HOVER_RACING scripts: 1
Disabled legacy-named HOVER_RACING owners: 6
```

Remaining active legacy-named script:

```text
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client
```

This is expected. It should remain active until the separate main client extraction project.

Current recommendation:

```text
Post-switch architecture is clean. Commit this checkpoint before attempting the large main client extraction.
```
