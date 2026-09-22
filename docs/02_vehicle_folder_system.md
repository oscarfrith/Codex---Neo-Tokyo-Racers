# Vehicle assets and configuration

Public data ownership: VehicleCatalogData is generated from the authoring attributes/upgrade folders; VehicleCatalog resolves stable IDs, VehicleDefinition shares Instance/record reads, and VehicleTemplateIndex resolves preview models by bounded paths. After content edits, refresh the mirror and run scripts/performance_phase3/check_catalogue.py; regenerate through the content change installer and restart Play. Physical templates remain replicated until Phase 4.

Performance Phase 2 moved PlayerProfileSchema/GarageProfileProjection and the vehicle performance writer to ServerStorage.Modules, plus Persistence/PersonalBests/Leaderboards to ServerStorage.Config. Shared calculators remain replicated. No vehicle templates moved; physical categories remain required by previews and server authoring. Client calculations now use generated catalogue records. See architecture/performance-phase2-server-storage.md.

All four cleanup phases are user-confirmed. Performance Phase 3 is installed and agent-verified; user playthrough pending. Mirror 2026-09-22 12:31:08 passes exact 164-source/42,359-node/267,539-property parity. See architecture/performance-phase3-catalogue.md. Gameplay, tuning and physical assets are preserved.

ReplicatedStorage.Assets.Vehicles holds active categories/templates. ServerStorage.Assets.Garage and Racing hold server templates. Config.Vehicles groups Driving, Dynamics, Camera, Performance, Spawn, MobileControls, DriveRewards, Authoring, DriverSeat and StabiliserVFX. ModuleSlots/VFXAttachments are folder hooks; physical hooks are unchanged. Staging/Archive remain protected pending decision.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/02_vehicle_folder_system.md; old installation instructions are historical, not pending tasks.
