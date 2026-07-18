# Manual Script Copy Map

**Created:** 2026-05-28  
**Status:** Current script mirror folders created  
**Current mirror root:** `roblox/exported_scripts`

## Current Best Option

The Studio export has already been imported into:

```text
roblox/exported_scripts
```

So you do not need to manually copy the scripts for this round. The exact Studio-to-file mapping is here:

```text
roblox/exported_scripts/MANIFEST.md
roblox/exported_scripts/manifest.json
```

Use those files as the source of truth for where each script lives in GitHub.

## If You Ever Copy Manually

Copy each Roblox Studio script source into the matching file under `roblox/exported_scripts`, keeping this convention:

```text
ModuleScript -> .module.lua
LocalScript  -> .client.lua
Script       -> .server.lua
```

Example:

```text
Studio:
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.DrivingControllerV47

GitHub:
roblox/exported_scripts/ReplicatedStorage/HOVER_RACING_V2_KIT/CLIENT_MODULES/Controllers/DrivingControllerV47.module.lua
```

## Main Live Scripts To Keep Fresh

These are the most important active gameplay scripts to refresh after major Studio changes:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageSessionService_Active (after canonical garage install)
ServerScriptService.NeoTokyoRacers.Services.Vehicle.DriverSeatPositionKeeper_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.GarageEntranceController_Active (after canonical garage install)
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageExperienceController_Active (after canonical garage install)
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.CharacterSprintController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.DriveHudController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.ThrustPreviewController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DesktopFreeRoamHudController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.MobileFreeRoamHudController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceCountdownPresentationController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceQueueClient_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceRouteGuideClient_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionPresentationController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTimeTrialResultCoachClient_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active
ServerScriptService.NeoTokyoRacers.Services.UI.FreeRoamHudTeleportService_Active
StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview
```

The desktop/mobile free-roam UI entries and their relevant server bridge are the current isolated presentation owners. Refresh them together after any later free-roam HUD or dealership-teleport change. The listed Racing owners are the critical latest mobile/race-flow sources; refresh all scripts under `Controllers.Racing` and `Services.Racing` together with their remotes/config hierarchy. Use `docs/mobile-ui-racing-flow-handoff-2026-07-14.md` and the generated manifest for exact current paths.

After the corrected canonical dealership/customisation rerun, refresh the active client bootstrap, garage action/session services, dealership intro, canonical entrance/presentation owners, config hierarchy and preview owners together. The `2026-07-14 20:05:44` mirror contains initial V1; the next refresh must capture the bottom-carousel, early-camera, ascending-rating and leftmost-preview markers.

Important active module roots:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Core
ReplicatedStorage.NeoTokyoRacers.Assets.VFX.VehicleTemplates
ReplicatedStorage.Shared.LightingPresets
ReplicatedStorage.NeoTokyoRacers
```

## Safety Notes

- `roblox/exported_scripts` is a GitHub-readable mirror, not automatic live sync.
- Studio is still the live source of truth until a Rojo/source-sync migration is explicitly planned.
- If Codex edits files under `roblox/exported_scripts`, those edits still need a Studio command-bar patch or manual paste back into Roblox Studio.
- Do not copy assets from `Workspace.Test + WIP Assets` into the main mirror unless you intentionally decide to include WIP/test assets.
