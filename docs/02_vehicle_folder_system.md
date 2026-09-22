# Vehicle assets and configuration

Performance Phase 1 reviewed server-only schema/projection/writer moves; no templates moved. Physical categories remain required by preview and performance consumers. See architecture/performance-phase1-baseline.md for exact proposed destinations and dependencies.

All four cleanup phases are user-confirmed. Post-confirmation mirror 2026-09-22 11:00:13 passes exact Phase 4 parity. The separate performance/replication programme is proposed only; see architecture/performance-and-replication-plan.md.

ReplicatedStorage.Assets.Vehicles holds active categories/templates. ServerStorage.Assets.Garage and Racing hold server templates. Config.Vehicles groups Driving, Dynamics, Camera, Performance, Spawn, MobileControls, DriveRewards, Authoring, DriverSeat and StabiliserVFX. ModuleSlots/VFXAttachments are folder hooks; physical hooks are unchanged. Staging/Archive remain protected pending decision.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/02_vehicle_folder_system.md; old installation instructions are historical, not pending tasks.
