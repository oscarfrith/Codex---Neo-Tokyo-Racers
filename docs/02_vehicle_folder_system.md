# Vehicle assets and configuration

Public data ownership: VehicleCatalogData is generated from the authoring attributes/upgrade folders; VehicleCatalog resolves stable IDs, VehicleDefinition shares Instance/record reads, and VehicleTemplateIndex resolves preview models by bounded paths. After content edits, refresh the mirror and run scripts/performance_phase4/check_projection.py; regenerate through the content change installer and restart Play. Canonical templates now live in ServerStorage.Assets.Vehicles. Generated VehiclePreviews and VehicleCatalogData must be regenerated together after authoring changes.

Performance Phase 2 moved PlayerProfileSchema/GarageProfileProjection and the vehicle performance writer to ServerStorage.Modules, plus Persistence/PersonalBests/Leaderboards to ServerStorage.Config. Shared calculators remain replicated. Phase 4 moves full categories server-side and gives preview/HUD clients generated VehiclePreviews categories. Client calculations now use generated catalogue records. See architecture/performance-phase2-server-storage.md.

Current baseline and acceptance: [start here](00_START_HERE.md); outstanding checks: [open issues](06_current_known_issues.md).

ServerStorage.Assets.Vehicles holds active authoring/spawn categories; ReplicatedStorage.Assets.VehiclePreviews holds generated preview geometry. ServerStorage.Assets.Garage and Racing hold server templates. Config.Vehicles groups Driving, Dynamics, Camera, Performance, Spawn, MobileControls, DriveRewards, Authoring, DriverSeat and StabiliserVFX. ModuleSlots/VFXAttachments are folder hooks; physical hooks are unchanged. Staging/Archive remain protected pending decision.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/02_vehicle_folder_system.md; old installation instructions are historical, not pending tasks.
