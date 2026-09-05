# Architecture Phase 3 — server composition and authoritative state

2026-09-05. The user confirmed the Phase 2 playthrough worked well and authorised this phase. High-Risk lane: server startup, saved-state ownership and economy integration. **Subsequent acceptance:** the user confirmed Phase 3 worked well and authorised Phase 4. The former acceptance-pending language below records the original handoff; the Phase 4 handoff is current.

## Contract

- Introduce ServerScriptService.ServerBase, ServerStorage.Modules.Core and Modules.Game feature folders with explicit startup dependencies and named FeatureServer modules. Do not auto-run descendant modules. Existing disabled experiments remain disabled.
- Preserve remotes, runtime binding paths, assets, config, saved schema/IDs, prices, rewards, controls, presentation and native LandscapeSensor. Old module paths become stateless forwarding adapters where needed; there must be only one executable implementation and one startup owner.
- ProfileServer retains the Phase 2 session/lease/save owner. Garage operations use that exact authoritative session table, with compatibility fields kept only in memory and excluded from persistence. Remove the garage-owned profile cache and recurring whole-profile import. Racing writes its own authoritative fields rather than importing detached profiles over Cash/inventory. Retain binding APIs for callers, but reject obsolete whole-profile replacement.
- Preserve existing command validation and runtime lifecycle cleanup. ServerBase records pending/starting/ready/failed/blocked states; failed dependencies cannot report ready. Existing long-lived service loops remain server-session scoped; hot reload/destruction of individual running services is unsupported in this migration.
- Geometry, preview, vehicle physics, collision, racing eligibility and saved IDs keep their current feature owners. Splitting code is not a performance claim. No physical asset changes or production publish.
- One canonical installer with exact live fingerprints, all-source precompilation, idempotent audit, transactional rollback and explicit reverse migration. Source transformations use exact anchors and must reject source drift. No in-game backup scripts/folders.
- Verify startup dependency failures with isolated doubles, shared-state/snapshot filtering invariants, all source compilation, repeat install and rollback, a fresh sandbox Play and live command transitions. Refresh the full Studio mirror and document actual results. User full gameplay/device checks remain the acceptance boundary. Real isolated-place persistence testing remains a production-release gate from Phase 2.

## Installed result

Phase 3 is installed in Space Racers v1. ServerBase starts 26 explicit services. Forty-one implementations moved to ServerStorage.Modules.Game; their former Services paths are stateless ModuleScript adapters. Added Core.ServerLifecycle, Player.ProfileCompatibility and Player.EconomyServer. The two disabled old garage scripts remain disabled/unmoved. See phase3-path-map.md for exact destinations.

ProfileServer is the single session/profile owner. Garage commands now use that same profile object; one-time compatibility fields are attached in memory and excluded before snapshot/encoding. Removed the persistent garage cache and recurring conversion/import path. RaceRewardsServer updates its authoritative Racing fields directly. Whole-profile replacement is rejected. EconomyServer contains the existing grant validation/deduplication logic, with unchanged prices/rewards/limits. The existing private vehicle builder remains inside GarageServer; no new competing vehicle registry was introduced.

Compatibility namespaces retain old runtime Bindable paths. They contain forwarding paths and endpoints, not duplicate balances or inventories. ServerBase.StartupState is the current runtime startup registry; the older LiveSystemRegistry descriptions remain historical. Individual service hot reload is unsupported: existing service cleanup and server-session lifetimes are preserved. Optional failures do not block unrelated startup, and dependency failures cannot become ready.

## Verification

- Nine isolated tests passed: valid/missing/cyclic/duplicate dependencies, failure isolation, shared profile identity, reward visibility, transient filtering and preservation of Cash/Racing/Onboarding during garage commit.
- Fresh sandbox Play: all 26 services ready; profile loaded. Purchase reduced Cash 1,000,000 → 650,000, a 123 Cash test grant produced 650,123, then painting retained that balance and vehicle ID. This data was sandbox-only and discarded on Stop.
- A second fresh Play passed purchase, vehicle spawn, exit and re-entry. SaveNow returned “Save suppressed”. Obsolete snapshot import was rejected without changing Cash. The actual schema encoded the filtered profile successfully (10,677 bytes in the fixture), excluding runtime fields.
- Fixed the initial garage-load wait and detached the existing lighting loop from startup completion in this same installer. Final Play had neither new startup issue. Existing TrailerShots wait/Hello-world/player-before-character messages remain outside this phase.
- Exact audit, idempotent install and rollback/reinstall passed; all 240 live sources compile. The installer also rebuilds reproducibly from the refreshed installed mirror plus migration.json.
- Full mirror refreshed at **2026-09-05 11:16:45**: 240 sources, 267,263 captured property values, integrity PASS. The property count decreases because 26 active Scripts became ModuleScript adapters and ServerBase adds one Script; gameplay properties were not intentionally changed. Existing 2,918 duplicate non-source path warnings remain. Raw paste untouched.

## Handoff and rollback

No manual installer run is needed. Start fresh Play and check onboarding, vehicle/module buying, upgrades, painting, Drive, exit/re-entry, garage entry/exit and a Race or Time Trial including reward/return. Watch for new Output errors; repeat landscape touch where available. Full gameplay/device acceptance remains the user's next boundary before Phase 4.

Canonical script: `scripts/roblox_architecture_phase3_server_organisation.lua`. Default INSTALL is idempotent; AUDIT is read-only; ROLLBACK restores the precise Phase 2 source/class layout, removes generated implementations and prunes empty generated folders. Run in Edit and refresh the mirror afterward. Source drift blocks rollback. Old Phase 1/2 recovery installers must not be forced over this new layout.

PASS: scoped ownership, explicit startup/dependency failure handling, source migration/recovery, existing request safeguards, local serialization and focused sandbox runtime, compile/mirror checks. DEFERRED: user's full gameplay/device matrix; real isolated-place save/rejoin and cross-server contention before production release; further extraction of remaining large private feature helpers when their contracts justify it. N/A: new client UI/input, physical asset edits and new streaming behaviour. No full security audit, performance improvement, crash-proof durability or production publish is claimed.

Lesson: moving source alone does not resolve competing state. Preserve callable adapters while replacing the underlying cached-state/import boundary, and distinguish a service registering its handlers from each player's profile finishing its load.
