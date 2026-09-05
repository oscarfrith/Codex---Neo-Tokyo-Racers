# Naming, ownership and migration contract

**2026-09-05 update:** Complete cleanup Phases 1, 2 and 3 are installed and user-confirmed. Phase 4 remains unimplemented. Current mirror: 2026-09-05 16:06:57, 160 sources, 42,285 nodes and 266,840 properties, with exact expected source/hierarchy/property parity. The two lighting-tag renames on 62 enumerated WIP objects are approved and installed. Protected staging/archive disposition remains pending. [Phase 3 naming map](cleanup-phase3-generic-naming.md) supersedes the historical path proposals below. Feature modules remain Modules.Core/Game; runtime owners remain Runtime by feature. No new owners or old-path adapters were added.

Approved direction: use the inspected Untitled Experience's `ServerBase`, `ClientBase`, `Modules/Core`, `Modules/Game`, `FeatureServer`, `FeatureClient`, and `FeatureUI` vocabulary. This is a project convention inspired by that place, not a claim about a company-wide standard.

**Current ownership:** ServerBase/ClientBase own startup; ProfileServer owns authoritative profiles. GarageUI owns current interface startup and DriveSessionClient invokes current DrivingClient. Existing rendering/preview/geometry and LOD owners remain. The old phase-specific destination table below is historical evidence, not a current tree.

## Rules

- Canonical implementation names contain responsibility, not `_Active`, `_Shadow_Disabled`, patch numbers or dates. Do not recreate compatibility path wrappers or retired implementations.
- Server entry: `ServerScriptService.ServerBase`; implementation: `ServerStorage.Modules.Game.<Feature>`; client entry: `StarterPlayer.StarterPlayerScripts.ClientBase`; shared/client implementation: `ReplicatedStorage.Modules`.
- Keep existing Assets/Config/remotes and saved IDs stable. Location changes are not performance optimisations.
- New public methods use lower_snake_case. Do not mechanically rename private locals. Stateful modules use `init`, `start`, `destroy`; pure definitions/calculators need no lifecycle ceremony.
- Explicit startup registration/dependencies; never discover and execute all descendant modules automatically. Critical readiness requires successful dependencies. Optional audio/presentation failure must not block profile readiness.
- One writer per state boundary. Do not add adapters that duplicate balances, inventories or vehicle registries.
- Private helpers live beneath their owner where useful. Avoid generic “Manager”, “Utils” and a giant shared context containing every subsystem.
- Module headers state owner, public operations, dependencies and cleanup. No arbitrary file-size targets.
- Do not copy Untitled's loader, Net or persistence implementation wholesale. Its failure handling and lock renewal are not the target contract.

## Current owner → proposed destination

Prefixes: `RS=ReplicatedStorage.NeoTokyoRacers`; `SSS=ServerScriptService.NeoTokyoRacers.Services`; `CLIENT=StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient`.

| Concern | Current owner(s) | Proposed code destination / responsibility | Phase |
|---|---|---|---|
| Client composition | CLIENT.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled (enabled) | ClientBase; feature behaviour extracted before retiring bridge | 4 |
| Profile lifecycle/save | SSS.Player.ProfileService_Active | ServerStorage.Modules.Game.Player.ProfileServer | 2 harden, 3 migrate |
| Positive Cash commands | ProfileService bindings; legacy garage spending/import projection | Game.Player.EconomyServer delegating to authoritative profile transaction | 3 |
| Garage/vehicle actions | SSS.Garage.GarageActionController_Shadow_Disabled (enabled) | Game.Garage.GarageServer and Game.Vehicles.VehicleServer; split by actual ownership | 3 |
| Module inventory/transactions | SSS.Garage.GarageModuleInventoryRuntime, GarageModuleTransactionRuntime, GarageModuleInstanceCustomizationRuntime | Private GarageServer command/transaction modules | 3 |
| Owned garage management | SSS.Garage.OwnedGarageManagementRuntime, OwnedGarageAuthoritativeCommandRuntime, OwnedGarageProfileRuntime | Game.Garage feature modules; ProfileServer remains saved-data authority | 3 |
| Vehicle attachment/build/despawn | Existing garage action helpers and owned-garage lifecycle bridge | VehicleServer public commands with private VehicleBuilder/VehicleLifecycle | 3 |
| Collision/parking authority | SSS.Vehicle.VehicleCollisionLifecycleService_Active | Game.Vehicles.VehicleCollisionServer | 3 |
| Race/TT sessions | SSS.Racing.RaceMatchmakingService_Active, TimeTrialService_Active | Game.Racing.MatchmakingServer, TimeTrialServer under RacingServer composition | 3 |
| Rewards/PB | SSS.Racing.RaceRewardService_Active, RacePersonalBestService_Active | Game.Racing.RaceRewards / PersonalBestServer; preserve reward eligibility | 3 |
| Driving | RS.Shared.Modules.Client.Controllers.DrivingControllerV47, VehicleDynamicsModel | ReplicatedStorage.Modules.Game.Vehicles.DrivingClient / VehicleDynamics | 4; preserve equations/tuning |
| Input lock | RS.Shared.Modules.Client.Input.GameplayInputGate | Game.Vehicles.GameplayInputGate reused | 4 |
| Shared UI | CLIENT.Controllers.UI.GarageReplacementComponents, GarageWorkspaceController; RS.Shared.Modules.UI.ResponsiveUIFoundation | Game.UI shared components; keep actual renderers | 4 |
| Garage client | CLIENT.Controllers.UI.OwnedGarageWorkspaceController, GarageInteriorModeController, ModuleShopUIController | Game.Garage clients/UI with separate geometry and camera/input boundaries | 4 |
| Preview | CLIENT.Controllers.Preview.PreviewVehicleController, PreviewCameraController | Game.Garage.PreviewClient and PreviewCameraClient | 4 |
| VFX attachment | RS.Shared.Modules.Client.Visuals.CachedThrustVisualRuntime | Game.Vehicles.VehicleVFXClient (same single attachment owner) | 4 |
| Audio | RS.Shared.Modules.Client.Audio.VehicleAudioController + SSS.Audio.VehicleAudioStateService_Active | Game.Audio.VehicleAudioClient / VehicleAudioServer | 4/3 |
| World LOD | CLIENT.Controllers.World.LODClient_Active | Game.World.LODClient; streaming lifecycle repair before optimisation | 5 |

These are proposed mappings, not performed renames. The source baseline lists exact current paths for all scripts. A split requires caller analysis, not textual renaming. New `ServerBase`/`ClientBase` cannot start alongside existing active owners without an explicit handover.

## Extension policy

Vehicles, cosmetics and routes remain catalogue/config driven. Reuse authored attributes for designer tuning. Add a definition and validate it before adding a runtime branch. Keep whole-profile imports only as a temporary compatibility boundary with an explicit retirement owner.
