# Architecture Phase 4 — client composition and lifecycle

2026-09-05. The user confirmed Phase 3 gameplay and authorised this phase. High-Risk lane because client startup, input and camera ownership are connected. **Subsequently user-confirmed (“all worked well”); Phase 5 is now current.** The acceptance-pending wording below records this phase's original handoff, not the current queue.

## Acceptance contract

- ClientBase is the sole startup owner for the current StarterPlayerScripts gameplay controllers. Implementations move to ReplicatedStorage.Modules.Core and Modules.Game feature folders. Old paths forward to the same modules and retain runtime Bindable paths/attributes. Disabled experiments stay disabled. ReplicatedFirst keeps its early-loading responsibility.
- Preserve UI geometry, shared renderers, native LandscapeSensor, input sensitivity, driving equations/tuning, preview construction, the sole CachedThrustVisualRuntime attachment owner, networking and saved data. ProfileServer remains authoritative. No assets or production publishing.
- Extract preview-input subscriptions behind a small explicit contract with idempotent bind/destroy; reuse ClientThemeAdapter instead of duplicated theme readers; remove the provably disabled proximity-reentry polling. Keep prompt-only re-entry. Existing feature lifetimes/cleanup remain; no claim of general hot reload.
- Explicit startup registrations/dependencies report pending/starting/ready/failed/blocked/skipped. Development trailer cameras, HUD hiding and lighting preview require Studio plus an explicit config attribute, default off. Existing Studio cash/telemetry safeguards remain. Optional tool failure must not block gameplay.
- Exact source/class fingerprints and source-anchor checks precede all writes. Compile originals, targets and adapters. One installer supports INSTALL/AUDIT/ROLLBACK and restores the prior state on installation failure without in-game backups. Old paths with literal dots are resolved using manifest path parts.
- Done when isolated lifecycle/gating tests, all-source compilation, install/audit/idempotency/reverse migration and fresh sandbox client/server startup pass, focused garage/drive transitions are exercised, mirror refreshed and docs updated. User full gameplay/device playthrough is the final acceptance boundary. Real published-place persistence testing remains Phase 2's release gate.

## Ownership and boundaries

ClientBase owns startup only. GarageClient keeps the existing bridge state; GarageUI and the existing shared UI modules retain presentation/geometry. PreviewInputClient owns its four input/frame subscriptions and mutates only the passed preview state. DrivingClient retains vehicle forces/input/camera assist and Stop cleanup. VehicleVFXClient retains live attachments. No new balance, preview vehicle registry or competing camera renderer is introduced. Compatibility helpers in PlayerScripts resolve the local player's runtime tree, never StarterPlayer templates.

Rollback is an Edit-mode source/layout migration, not live hot reload. Source drift blocks it; inspect/refresh instead of forcing older installers.

## Installed result

92 implementations moved: 44 former LocalScripts and 48 required helpers. Their old paths are stateless ModuleScript adapters. ClientBase owns 44 explicit registrations, including four default-off development tools. Added Core.ClientLifecycle, Core.ConnectionScope and Garage.PreviewInputClient. Existing disabled scripts and ReplicatedFirst remain unchanged. Exact destinations are in [phase4-path-map.md](phase4-path-map.md).

The original large bootstrap now forwards to GarageClient; it no longer independently executes. ClientBase contains startup only. GarageClient retains a substantial legacy bridge/UI/fallback closure; this migration is not a claim that every private legacy function has been removed. Shared theme reading is reused, the disabled proximity poll removed, and legacy preview subscriptions extracted. The normal GarageUI continues using the existing session-scoped PreviewCameraClient. No universal context, duplicate UI renderer or alternate VFX attachment path was introduced.

Developer controls live at `ReplicatedStorage.NeoTokyoRacers.Config.Development.ClientTools`: `TrailerVehicleCameraEnabled`, `TrailerModeEnabled`, `TrailerShotEnabled`, `LightingPreviewEnabled`. All false by default; change in Edit and start fresh Play. They also hard-check Studio. The shot tool validates all authored markers before camera mutation. Ordinary Studio cash/telemetry configuration is preserved. Do not enable overlapping camera tools together.

## Verification and limits

- Four isolated helper test groups pass: dependency validation, Studio/config gating, startup failure isolation/skip-before-require, and repeat-safe subscription cleanup/reuse rejection.
- Exact baseline audit, installation, idempotent repeat installation, rollback to Phase 3, reinstall and installed audit pass. The final font fallback repair is in this same installer. All 336 sources compile.
- Fresh sandbox Play: all 26 server entries ready; 40 client entries completed startup and four development tools skipped. Optional legacy controllers may internally return when their own feature/device config is disabled; “ready” means startup completed, not that every presentation is visible.
- Start-screen input worked. Buying bruiser_01 reduced Cash from 1,000,000 to 650,000. Existing customisation Bindable opened the browser/preview; normal vehicle-card and action clicks opened the workshop. The tutorial intercepted the UI Drive click and advanced to J2, so a complete UI Drive journey is **not** claimed. Existing GarageInvoke commands and client Bindables separately passed spawn, exit and re-entry, including DriverSeat, DriveReady and force creation.
- No new startup errors observed; old Hello-world and player-before-character messages remain. No missing TrailerShots wait. No published saves: Studio sandbox suppresses profile writes.
- Full receiver/exporter mirror refreshed **2026-09-05 11:34:22**: 336 sources, 267,177 property values, integrity PASS. All **148 out-of-scope sources** retain exact source/class/enabled parity with the pre-phase mirror. The installer rebuilds from the refreshed installed mirror and migration manifest; canonical sources/adapters match. Existing 2,918 duplicate non-source path warnings remain. Raw paste untouched.

PASS: source/ownership migration, registration/gating, narrow cleanup helper, compile/recovery and focused sandbox evidence. DEFERRED: user's guided UI/full gameplay/device matrix; Phase 5 profiling and streaming/LOD repair; deeper private legacy extraction when justified; Phase 2 real isolated-place persistence release gates. N/A: saved-schema changes, new remotes, economy changes and physical asset changes. No frame-rate improvement or production readiness claim from moving source.

## User handoff

No manual script run is required: installed directly in Space Racers v1 through MCP. Start fresh Play; check onboarding, buying/equipping/upgrading/painting, garage preview orbit/zoom, Drive/boost/drift/reverse/exit/re-entry, owned-garage entry/exit and race/TT results/return. Repeat landscape touch on phone/tablet where available. Watch Output for new errors. Phase 5 is the one remaining phase after this acceptance.

Canonical script: `scripts/roblox_architecture_phase4_client_organisation.lua`. Default INSTALL is idempotent, AUDIT is read-only, ROLLBACK restores exact Phase 3 source/classes and removes generated implementations/config plus empty generated folders. Set all four tool flags false before recovery. Subsequent source drift deliberately blocks rollback. Run only in Edit and refresh the mirror afterward; do not force older installers over this layout.

Lesson carried forward: separate startup from feature ownership, preserve runtime relative-path context when moving modules, and report actual input-driven UI coverage separately from command/event smoke tests. A relocated legacy closure is still maintenance debt, even when the composition root is clean.
