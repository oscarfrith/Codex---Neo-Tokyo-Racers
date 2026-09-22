# Garage and customisation UI

Phase 5 adds catalogue transport reuse across GarageUI, desktop/mobile vehicle menus and two race-entry consumers. GetInitial always fetches the current profile; only the unchanged public catalogue is reused. Caller-facing catalogue tables remain detached/mutable, and existing busy/error/UI/preview ownership remains unchanged. Authoring edits to templates, paint presets or cosmetics require restarting Play/server to refresh the catalogue snapshot.

Phase 4 redirects GarageUI, desktop/mobile vehicle menus and race image fallback to Assets.VehiclePreviews. Shared preview/paint/VFX/calculation owners stay unchanged. The generated preview omits only upgrade Folder subtrees; all geometry, hooks, other attributes and images are preserved. Upgrade rules still come from VehicleCatalogData on the client and full templates on the server.

Phase 3 preserves GarageUI/preview ownership and the shared calculator. UI image fallback and upgrade-capacity reads now use immutable public definitions; preview cloning uses bounded template lookup. Verify catalogue images, module comparisons, upgrades, paint and return-to-drive visually before acceptance.

Performance Phase 1 sampled five GetInitial calls: each catalogue is 173,361 JSON bytes; total result 177,251 bytes. This is a payload-size proxy, not wire cost. Shared data and template indexing are installed in Phase 3; the existing remote catalogue payload remains unchanged. Phase 5 now omits the catalogue on warm revision-matched reads; see the current handoff. See architecture/performance-phase1-baseline.md.

Current baseline and acceptance: [start here](00_START_HERE.md); outstanding checks: [open issues](06_current_known_issues.md).

GarageUI starts directly from ClientBase; DriveSessionClient owns vehicle callbacks. Shared renderer, Theme, layout, preview and geometry owners remain canonical. Remotes.Garage and Config.UI are current. GarageProfileProjectionBindings preserves semantics without a second saved-state owner. ReplicatedFirst.Loading owns initial loading. Mobile remains LandscapeSensor.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/04_customisation_ui.md; old installation instructions are historical, not pending tasks.
