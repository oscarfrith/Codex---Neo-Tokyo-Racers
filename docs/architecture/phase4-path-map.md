# Phase 4 client path map

Old paths forward to these canonical implementations. Disabled scripts stay disabled. ReplicatedFirst retains early loading.

| Compatibility path | Canonical implementation | Startup |
|---|---|---|
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.AcousticsController` | `ReplicatedStorage.Modules.Game.Audio.AcousticsClient` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.AudioBusController` | `ReplicatedStorage.Modules.Game.Audio.AudioBusClient` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.AudioMixController` | `ReplicatedStorage.Modules.Game.Audio.AudioMixClient` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.ContextAudioCatalog` | `ReplicatedStorage.Modules.Game.Audio.ContextAudioCatalog` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.ContextAudioController` | `ReplicatedStorage.Modules.Game.Audio.ContextAudioClient` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.PresentationAudioBridge` | `ReplicatedStorage.Modules.Game.Audio.PresentationAudioBridge` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.PresentationAudioCatalog` | `ReplicatedStorage.Modules.Game.Audio.PresentationAudioCatalog` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.PresentationAudioController` | `ReplicatedStorage.Modules.Game.Audio.PresentationAudioClient` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.VehicleAudioCatalog` | `ReplicatedStorage.Modules.Game.Audio.VehicleAudioCatalog` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.VehicleAudioController` | `ReplicatedStorage.Modules.Game.Audio.VehicleAudioClient` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.DrivingCameraController` | `ReplicatedStorage.Modules.Game.Vehicles.DrivingCameraClient` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.DrivingControllerV47` | `ReplicatedStorage.Modules.Game.Vehicles.DrivingClient` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.DrivingFallbackController` | `ReplicatedStorage.Modules.Game.Vehicles.DrivingFallbackClient` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.MobileDriveInputState` | `ReplicatedStorage.Modules.Game.Vehicles.MobileDriveInputState` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.ReentryThrottle` | `ReplicatedStorage.Modules.Game.Vehicles.ReentryThrottle` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.VehicleDynamicsModel` | `ReplicatedStorage.Modules.Game.Vehicles.VehicleDynamics` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Input.GameplayInputGate` | `ReplicatedStorage.Modules.Game.Vehicles.GameplayInputGate` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.UI.UIFactory` | `ReplicatedStorage.Modules.Game.UI.UIFactory` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.UI.UIPool` | `ReplicatedStorage.Modules.Game.UI.UIPool` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.VFX.VehicleVFXController` | `ReplicatedStorage.Modules.Game.Vehicles.LegacyVehicleVFXClient` | Existing require contract |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Visuals.CachedThrustVisualRuntime` | `ReplicatedStorage.Modules.Game.Vehicles.VehicleVFXClient` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio.AcousticsRuntimeController_Active` | `ReplicatedStorage.Modules.Game.Audio.AcousticsRuntimeClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio.AudioRuntimeController_Active` | `ReplicatedStorage.Modules.Game.Audio.AudioRuntimeClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio.ContextAudioRuntimeController_Active` | `ReplicatedStorage.Modules.Game.Audio.ContextAudioRuntimeClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio.PresentationAudioRuntimeController_Active` | `ReplicatedStorage.Modules.Game.Audio.PresentationAudioRuntimeClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.CatalogClient` | `ReplicatedStorage.Modules.Game.Garage.CatalogClient` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientState` | `ReplicatedStorage.Modules.Game.Garage.GarageState` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientThemeAdapter` | `ReplicatedStorage.Modules.Core.ClientThemeAdapter` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.GarageApiClient` | `ReplicatedStorage.Modules.Game.Garage.GarageApiClient` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.PaintClient` | `ReplicatedStorage.Modules.Game.Garage.PaintClient` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Debug.DriveToEarnCashTelemetry_StudioOnly` | `ReplicatedStorage.Modules.Game.Development.DriveToEarnCashTelemetryClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Debug.StudioCashGrantClient_Active` | `ReplicatedStorage.Modules.Game.Development.StudioCashGrantClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active` | `ReplicatedStorage.Modules.Game.Dealership.DealershipIntroClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.GarageEntranceController_Active` | `ReplicatedStorage.Modules.Game.Dealership.GarageEntranceClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.GaragePreviewPresentationController_Active` | `ReplicatedStorage.Modules.Game.Garage.GaragePreviewPresentationClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.ThrustPreviewController_Active` | `ReplicatedStorage.Modules.Game.Garage.ThrustPreviewClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.GarageModuleInstancePreviewAdapter` | `ReplicatedStorage.Modules.Game.Garage.GarageModuleInstancePreviewAdapter` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.GarageVehiclePreviewProfile` | `ReplicatedStorage.Modules.Game.Garage.GarageVehiclePreviewProfile` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewCameraController` | `ReplicatedStorage.Modules.Game.Garage.PreviewCameraClient` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewVehicleController` | `ReplicatedStorage.Modules.Game.Garage.PreviewVehicleClient` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceBrowserClient_Active` | `ReplicatedStorage.Modules.Game.Racing.RaceBrowserClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceCountdownPresentationController_Active` | `ReplicatedStorage.Modules.Game.Racing.RaceCountdownPresentationClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active` | `ReplicatedStorage.Modules.Game.Racing.RaceEntryMenuClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryPresentationController_Active` | `ReplicatedStorage.Modules.Game.Racing.RaceEntryPresentationClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceLifecyclePresentationController_Active` | `ReplicatedStorage.Modules.Game.Racing.RaceLifecyclePresentationClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceParticipantVisibilityClient_Active` | `ReplicatedStorage.Modules.Game.Racing.RaceParticipantVisibilityClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceQueueClient_Active` | `ReplicatedStorage.Modules.Game.Racing.RaceQueueClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceRouteGuideClient_Active` | `ReplicatedStorage.Modules.Game.Racing.RaceRouteGuideClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionAssetsClient_Active` | `ReplicatedStorage.Modules.Game.Racing.RaceSessionAssetsClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionPresentationController_Active` | `ReplicatedStorage.Modules.Game.Racing.RaceSessionPresentationClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTimeTrialResultCoachClient_Active` | `ReplicatedStorage.Modules.Game.Racing.RaceTimeTrialResultCoachClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTransitionClient_Active` | `ReplicatedStorage.Modules.Game.Racing.RaceTransitionClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.CharacterSprintController_Active` | `ReplicatedStorage.Modules.Game.Vehicles.CharacterSprintClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.DriveHudController_Active` | `ReplicatedStorage.Modules.Game.Vehicles.DriveHudClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.FreeRoamParkedHoverController_Active` | `ReplicatedStorage.Modules.Game.Vehicles.FreeRoamParkedHoverClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active` | `ReplicatedStorage.Modules.Game.Vehicles.MobileDriveControlsClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController_Active` | `ReplicatedStorage.Modules.Game.Vehicles.RuntimeVFXClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DesktopFreeRoamHudController_Active` | `ReplicatedStorage.Modules.Game.UI.DesktopFreeRoamHudUI` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.FreeRoamNavController_Active` | `ReplicatedStorage.Modules.Game.UI.FreeRoamNavUI` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.FreeRoamVehicleExitButton_Active` | `ReplicatedStorage.Modules.Game.UI.FreeRoamVehicleExitButtonClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.LoadingTransitionController_Active` | `ReplicatedStorage.Modules.Game.UI.LoadingTransitionUI` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.MobileFreeRoamHudController_Active` | `ReplicatedStorage.Modules.Game.UI.MobileFreeRoamHudUI` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OnboardingClient_Active` | `ReplicatedStorage.Modules.Game.UI.OnboardingClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OwnedGarageClient_Active` | `ReplicatedStorage.Modules.Game.UI.OwnedGarageClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.SharedTopNotificationController_Active` | `ReplicatedStorage.Modules.Game.UI.SharedTopNotificationUI` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.CockpitPaintUIController` | `ReplicatedStorage.Modules.Game.UI.CockpitPaintUIUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.ColourPickerController` | `ReplicatedStorage.Modules.Game.UI.ColourPickerUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.CustomisationUIController` | `ReplicatedStorage.Modules.Game.UI.CustomisationUIUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DealershipUIController` | `ReplicatedStorage.Modules.Game.UI.DealershipUIUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.FreeRoamMapPlayerMarkers` | `ReplicatedStorage.Modules.Game.UI.FreeRoamMapPlayerMarkers` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageBrowserController` | `ReplicatedStorage.Modules.Game.UI.GarageBrowserUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageInteriorModeController` | `ReplicatedStorage.Modules.Game.UI.GarageInteriorModeUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageInteriorTransitionController` | `ReplicatedStorage.Modules.Game.UI.GarageInteriorTransitionUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageModuleCardViewModel` | `ReplicatedStorage.Modules.Game.UI.GarageModuleCardViewModel` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GaragePropertyMenuController` | `ReplicatedStorage.Modules.Game.UI.GaragePropertyMenuUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageReplacementComponents` | `ReplicatedStorage.Modules.Game.UI.GarageComponents` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageWorkspaceController` | `ReplicatedStorage.Modules.Game.UI.GarageWorkspaceUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.ModuleShopUIController` | `ReplicatedStorage.Modules.Game.Garage.GarageUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.NavigationController` | `ReplicatedStorage.Modules.Game.UI.NavigationUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OnboardingGuideTrailRenderer` | `ReplicatedStorage.Modules.Game.UI.OnboardingGuideTrailRenderer` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OwnedGarageBrowserController` | `ReplicatedStorage.Modules.Game.UI.OwnedGarageBrowserUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OwnedGarageWorkspaceController` | `ReplicatedStorage.Modules.Game.UI.OwnedGarageWorkspaceUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.StatsPanelController` | `ReplicatedStorage.Modules.Game.UI.StatsPanelUI` | Existing require contract |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active` | `ReplicatedStorage.Modules.Game.World.LODClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.NightLamppostLightController_Active` | `ReplicatedStorage.Modules.Game.World.NightLamppostLightClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.OwnedGarageEnvironmentLightingController_Active` | `ReplicatedStorage.Modules.Game.World.OwnedGarageEnvironmentLightingClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.WindowMaterialController_Active` | `ReplicatedStorage.Modules.Game.World.WindowMaterialClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled` | `ReplicatedStorage.Modules.Game.Garage.GarageClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.LocalScript` | `ReplicatedStorage.Modules.Game.Development.TrailerVehicleCameraClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview` | `ReplicatedStorage.Modules.Game.Development.LightingPreviewClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.TrailerMode.client.lua` | `ReplicatedStorage.Modules.Game.Development.TrailerModeClient` | ClientBase |
| `StarterPlayer.StarterPlayerScripts.TrailerShot01Camera` | `ReplicatedStorage.Modules.Game.Development.TrailerShotClient` | ClientBase |
