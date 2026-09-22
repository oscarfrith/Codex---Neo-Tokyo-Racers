# Garage and customisation UI

Performance Phase 1 sampled five GetInitial calls: each catalogue is 173,361 JSON bytes; total result 177,251 bytes. This is a payload-size proxy, not wire cost. Versioned catalogue reuse and shared lookup indexing are proposed; no UI/API change installed. See architecture/performance-phase1-baseline.md.

All four cleanup phases are user-confirmed. Performance Phase 2 is installed/agent-verified; user playthrough pending. Mirror 2026-09-22 12:07:02 passes exact expected parity. See architecture/performance-phase2-server-storage.md. This storage migration preserves this system's gameplay/presentation and tuning.

GarageUI starts directly from ClientBase; DriveSessionClient owns vehicle callbacks. Shared renderer, Theme, layout, preview and geometry owners remain canonical. Remotes.Garage and Config.UI are current. GarageProfileProjectionBindings preserves semantics without a second saved-state owner. ReplicatedFirst.Loading owns initial loading. Mobile remains LandscapeSensor.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/04_customisation_ui.md; old installation instructions are historical, not pending tasks.
