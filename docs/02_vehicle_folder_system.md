# Vehicle assets and configuration

Performance Phase 2 moved PlayerProfileSchema/GarageProfileProjection and the vehicle performance writer to ServerStorage.Modules, plus Persistence/PersonalBests/Leaderboards to ServerStorage.Config. Shared calculators remain replicated. No vehicle templates moved; physical categories remain required by preview/performance consumers. See architecture/performance-phase2-server-storage.md.

All four cleanup phases are user-confirmed. Performance Phase 2 is installed/agent-verified; user playthrough pending. Mirror 2026-09-22 12:07:02 passes exact expected parity. See architecture/performance-phase2-server-storage.md. This storage migration preserves this system's gameplay/presentation and tuning.

ReplicatedStorage.Assets.Vehicles holds active categories/templates. ServerStorage.Assets.Garage and Racing hold server templates. Config.Vehicles groups Driving, Dynamics, Camera, Performance, Spawn, MobileControls, DriveRewards, Authoring, DriverSeat and StabiliserVFX. ModuleSlots/VFXAttachments are folder hooks; physical hooks are unchanged. Staging/Archive remain protected pending decision.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/02_vehicle_folder_system.md; old installation instructions are historical, not pending tasks.
