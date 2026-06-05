# Main Client Phase E - Post-Switch Audit

**Created:** 2026-05-29  
**Current status:** Passed / clean checkpoint  
**Studio script:** `scripts/roblox_client_phaseE_post_switch_audit.lua`

## Goal

Phase E audits the project after the Phase D main client owner switch.

It confirms:

- The new architecture-owned client is active.
- The legacy `HOVER_RACING_V2_Client` is disabled.
- No unexpected active scripts appeared.
- No active scripts exist inside `Workspace.Test + WIP Assets`.
- Staged Phase A-C modules still exist.

## Expected Active Main Client Owner

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

The name still includes `_Shadow_Disabled` because it was originally created as a switch candidate. After Phase D `SWITCH`, it is intentionally enabled and acting as the current main client owner.

## Expected Disabled Legacy Main Client

```text
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client
```

Do not delete this script yet. It remains the rollback path.

## What It Checks

Expected active owners include:

```text
NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
GarageActionController_Shadow_Disabled
DriverSeatPositionService_Active
LightingService_Active
TrafficLightService
LODClient_Active
RuntimeVFXController_Active
MobileDriveControlsController_Active
DriveHudController_Active
ThrustPreviewController_Active
TEMP_LightingPreview
```

Expected disabled owners include:

```text
HOVER_RACING_V2_Client
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

It also checks that staged Phase A-C modules exist.

## What It Does Not Do

The script does not:

- Move anything.
- Rename anything.
- Disable or enable anything.
- Delete anything.
- Edit source code.
- Change gameplay behaviour.

## Required Test

Run the script in Edit mode or Play mode after Phase D `SWITCH` has been play-tested.

The desired clean result is:

```text
Expected active owners enabled: 11 / 11
Missing expected active owners: 0
Expected active owners currently disabled: 0
Expected disabled owners currently enabled: 0
Unexpected active scripts: 0
Active scripts inside excluded Test + WIP Assets: 0
Active legacy-named HOVER_RACING scripts: 0
Missing staged Phase A-C modules: 0
```

## After A Clean Audit

1. Export Studio scripts to `roblox/exported_scripts` using the established source sync workflow.
2. Commit the Phase A-E main client migration checkpoint.
3. Keep disabled legacy owners for rollback until a later stable milestone.

## Confirmed Result

Tested by the user on 2026-05-29.

Clean audit result:

```text
Expected active owners enabled: 11 / 11
Missing expected active owners: 0
Expected active owners currently disabled: 0
Expected disabled owners currently enabled: 0
Unexpected active scripts: 0
Active scripts inside excluded Test + WIP Assets: 0
Active legacy-named HOVER_RACING scripts: 0
Disabled legacy-named HOVER_RACING owners: 7
Missing staged Phase A-C modules: 0
Staged module type issues: 0
```

Confirmed active main client owner:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

Confirmed disabled rollback client:

```text
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client
```

Suggested commit message:

```text
chore: switch main client owner into NeoTokyoRacers architecture
```

Suggested commit body:

```text
- Add staged main client extraction modules for core, preview, colour, and garage screen boundaries
- Add controlled main client owner switch with shadow, switch, and rollback modes
- Record post-switch audit expectations for the new architecture-owned client
- Keep legacy client disabled as rollback instead of deleting it
```

## Codex Safety Notes

- Do not treat this as permission to delete `HOVER_RACING_V2_Client`.
- Do not rename the active shadow client until the audit is clean and committed.
- Future work can gradually make the active bootstrap require Phase A-C modules, but that should be a separate refactor.
- Do not mix gameplay changes into this checkpoint.
