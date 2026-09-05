# Phase 3 installed server path map

Old paths are stateless adapters; implementation and startup ownership are at the new paths. Two previously disabled server scripts remain disabled and unmoved.

| Compatibility path | Canonical implementation | Startup |
|---|---|---|
| `ServerScriptService.NeoTokyoRacers.Services.Audio.VehicleAudioStateService_Active` | `ServerStorage.Modules.Game.Audio.VehicleAudioServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Dealership.IntroProgressService_Active` | `ServerStorage.Modules.Game.Dealership.IntroProgressServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Debug.StudioCashGrantService_Active` | `ServerStorage.Modules.Game.Development.StudioCashGrantServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled` | `ServerStorage.Modules.Game.Garage.GarageServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageDisplayRuntime` | `ServerStorage.Modules.Game.Garage.GarageDisplay` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageModuleInstanceCustomizationRuntime` | `ServerStorage.Modules.Game.Garage.GarageModuleInstanceCustomization` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageModuleInventoryRuntime` | `ServerStorage.Modules.Game.Garage.GarageModuleInventory` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageModuleTransactionRuntime` | `ServerStorage.Modules.Game.Garage.GarageModuleTransaction` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageProfileRuntime` | `ServerStorage.Modules.Game.Garage.GarageProfile` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageRequestGuard` | `ServerStorage.Modules.Game.Garage.GarageRequestGuard` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageSessionService_Active` | `ServerStorage.Modules.Game.Garage.GarageSessionServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageAuthoritativeCommandRuntime` | `ServerStorage.Modules.Game.Garage.OwnedGarageAuthoritativeCommand` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageDisplayAssignmentRuntime` | `ServerStorage.Modules.Game.Garage.OwnedGarageDisplayAssignment` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageDisplayRuntime` | `ServerStorage.Modules.Game.Garage.OwnedGarageDisplay` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageFinishRuntime` | `ServerStorage.Modules.Game.Garage.OwnedGarageFinish` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageInteriorRuntime` | `ServerStorage.Modules.Game.Garage.OwnedGarageInterior` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageManagementRuntime` | `ServerStorage.Modules.Game.Garage.OwnedGarageManagement` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageProfileRuntime` | `ServerStorage.Modules.Game.Garage.OwnedGarageProfile` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageService_Active` | `ServerStorage.Modules.Game.Garage.OwnedGarageServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Garage.VehicleCosmeticServerRuntime` | `ServerStorage.Modules.Game.Garage.VehicleCosmeticServer` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Player.LegacyGarageProfileBridge_Active` | `ServerStorage.Modules.Game.Player.ProfileCompatibilityServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Player.OnboardingService_Active` | `ServerStorage.Modules.Game.Player.OnboardingServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Player.ProfileService_Active` | `ServerStorage.Modules.Game.Player.ProfileServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Player.ProfileStore` | `ServerStorage.Modules.Game.Player.ProfileStore` | Required helper |
| `ServerScriptService.NeoTokyoRacers.Services.Racing.GlobalTimeTrialLeaderboardService_Active` | `ServerStorage.Modules.Game.Racing.GlobalLeaderboardServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceBrowserTeleportService_Active` | `ServerStorage.Modules.Game.Racing.RaceTeleportServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceDisplayNameService_Active` | `ServerStorage.Modules.Game.Racing.RaceDisplayNameServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceMatchmakingService_Active` | `ServerStorage.Modules.Game.Racing.MatchmakingServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Racing.RacePersonalBestService_Active` | `ServerStorage.Modules.Game.Racing.PersonalBestServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceRewardService_Active` | `ServerStorage.Modules.Game.Racing.RaceRewardsServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceSessionAssetService_Active` | `ServerStorage.Modules.Game.Racing.RaceAssetsServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active` | `ServerStorage.Modules.Game.Racing.TimeTrialServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.UI.FreeRoamHudTeleportService_Active` | `ServerStorage.Modules.Game.World.FreeRoamTeleportServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Vehicle.DriveToEarnCashService_Active` | `ServerStorage.Modules.Game.Vehicles.DriveRewardsServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Vehicle.DriverSeatPositionService_Active` | `ServerStorage.Modules.Game.Vehicles.DriverSeatServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehicleAccessPromptService_Active` | `ServerStorage.Modules.Game.Vehicles.VehicleAccessServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehicleCollisionLifecycleService_Active` | `ServerStorage.Modules.Game.Vehicles.VehicleCollisionServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehiclePerformanceRuntimeService_Active` | `ServerStorage.Modules.Game.Vehicles.VehiclePerformanceServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehiclePerformanceV2ShadowService_Active` | `ServerStorage.Modules.Game.Development.VehiclePerformanceComparisonServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Active` | `ServerStorage.Modules.Game.World.LightingServer` | ServerBase |
| `ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService` | `ServerStorage.Modules.Game.World.TrafficLightServer` | ServerBase |
