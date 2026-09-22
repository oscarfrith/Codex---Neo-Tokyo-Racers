# Garage and customisation UI

Phase 3 preserves GarageUI/preview ownership and the shared calculator. UI image fallback and upgrade-capacity reads now use immutable public definitions; preview cloning uses bounded template lookup. Verify catalogue images, module comparisons, upgrades, paint and return-to-drive visually before acceptance.

Performance Phase 1 sampled five GetInitial calls: each catalogue is 173,361 JSON bytes; total result 177,251 bytes. This is a payload-size proxy, not wire cost. Shared data and template indexing are installed in Phase 3; the existing remote catalogue payload remains unchanged. Network reuse remains future work. See architecture/performance-phase1-baseline.md.

All four cleanup phases are user-confirmed. Performance Phase 3 is installed and agent-verified; user playthrough pending. Mirror 2026-09-22 12:31:08 passes exact 164-source/42,359-node/267,539-property parity. See architecture/performance-phase3-catalogue.md. Gameplay, tuning and physical assets are preserved.

GarageUI starts directly from ClientBase; DriveSessionClient owns vehicle callbacks. Shared renderer, Theme, layout, preview and geometry owners remain canonical. Remotes.Garage and Config.UI are current. GarageProfileProjectionBindings preserves semantics without a second saved-state owner. ReplicatedFirst.Loading owns initial loading. Mobile remains LandscapeSensor.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/04_customisation_ui.md; old installation instructions are historical, not pending tasks.
