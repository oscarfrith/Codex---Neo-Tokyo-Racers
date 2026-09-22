# Garage and customisation UI

Cleanup Phase 4 installed and agent-verified; user playtest pending. Phases 1–3 are confirmed.

GarageUI starts directly from ClientBase; DriveSessionClient owns vehicle callbacks. Shared renderer, Theme, layout, preview and geometry owners remain canonical. Remotes.Garage and Config.UI are current. GarageProfileProjectionBindings preserves semantics without a second saved-state owner. ReplicatedFirst.Loading owns initial loading. Mobile remains LandscapeSensor.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/04_customisation_ui.md; old installation instructions are historical, not pending tasks.
