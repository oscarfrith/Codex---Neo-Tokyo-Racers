# Architecture Phase 2 — persistence and request safety

2026-09-05. Approved after the user confirmed Phase 1 worked well. High-Risk lane: saved player data and authoritative requests.

## Acceptance contract

ProfileService remains the sole profile owner. New transport helpers own no gameplay state. Existing garage handlers, schema, IDs, prices, rewards, onboarding and table identities remain. No asset, UI, driving, orientation or client bootstrap change. Company-style naming applies to new modules; existing owners move in later phases.

Acquire a renewable per-key lease before exposing a writable profile. Failed or locked production loads must never become writable defaults. Studio sandbox and disabled-store sessions stay permanently no-save for that lifecycle. Preserve existing DataStore values, user IDs and metadata. Serialise saves per session and retain dirty changes made during a yielding write. Renew clean sessions too. Release only the current token; late loads and stale servers cannot overwrite a newer owner. Leave/shutdown share a bounded close operation. No production DataStore fault injection.

Bound generic garage actions and their payload before profile work; retain current server-side ownership and price validation. Reject non-finite colours, excessive payloads and floods. Never hydrate garage defaults merely because authoritative loading is delayed. Valid players still use the same controls and response shape on all devices.

One canonical installer: `scripts/roblox_architecture_phase2_persistence_safety.lua`, with INSTALL/AUDIT/ROLLBACK modes, exact baseline checks, precompiled proposed source, idempotency and rollback on application failure. Source anchors are fragile to other edits; full-source fingerprints must agree before replacements. No in-game backups. The repo stores reversible edits.

Verification: actual helper source with an in-memory DataStore double tests failures, contention, expiry, stale writers, renewal, release, mutation during save, no-save sessions, cancellation and request limits. Compile all live sources; audit installed identity and refresh the full mirror. Gameplay smoke remains user acceptance. Sandbox does not prove real save/rejoin; isolated published test-place persistence verification remains required before production rollout.

Operational risk: old deployed servers do not understand the new lease metadata. Before publishing this revision, drain/shut down old servers; do not mix old and new profile writers. Rollback likewise requires all new sessions to close first. Lease expiry bounds abandoned ownership; it cannot guarantee recovery of unsaved changes after a server crash. The existing legacy snapshot bridge remains until Phase 3.

## Installation and evidence

Installed directly through MCP in Space Racers v1. The installer changes ProfileService_Active and GarageActionController_Shadow_Disabled, adds Player.ProfileStore and Garage.GarageRequestGuard, and changes no existing enabled states or settings. All 195 scripts compile. Exact audit, repeat install, rollback and reinstall passed. Nineteen in-memory helper tests passed without real DataStore access.

Fresh Play verified authoritative profile loaded, Studio sandbox active, Cash=1,000,000, SaveNow returning “Save suppressed”, successful client GetInitial, malformed payload rejection, then another successful GetInitial. No purchase, race or account data was edited for testing. Existing PB/intro services run normally and may read their separate stores; no claim that the entire game performs zero DataStore access. A comparison of tables returned by separate BindableFunction calls was not used as an identity test because that boundary copies tables; the existing in-place reconciliation implementation is unchanged.

Studio is back in Edit mode. Full mirror refreshed at **2026-09-05 10:58:29**, 195 sources, 267,313 property values; integrity passes. Other than the two intended script edits and two new modules, source fingerprints and enabled states must agree with the Phase 1 baseline. Raw paste was untouched. The existing 2,918 duplicate non-source path warnings remain.

## User gameplay check

No script needs running: Phase 2 is already installed. Start fresh Play and test loading/onboarding, buying a cockpit/modules, upgrading, painting (including continuous dragging), Drive, exit/re-entry, garage entry/exit, and a Race or Time Trial. Check Output for new errors. If possible repeat on landscape touch. Saved profile writes remain suppressed in the current sandbox, so leaving/rejoining is not a persistence test.

Canonical rerun/rollback: `scripts/roblox_architecture_phase2_persistence_safety.lua`. Default INSTALL is idempotent; change MODE to AUDIT for read-only verification or ROLLBACK to restore the precise pre-phase sources and remove the two helpers. Run in Edit, then refresh the mirror. Rollback refuses source drift. It restores the former persistence risks and is not appropriate while newer production sessions are active.

## Readiness and next boundary

PASS: scoped ownership preserved; exact install/rollback; bounded request payload/rate/concurrency; isolated lease/failure/dirty-revision tests; sandbox runtime and remote smoke; source compilation/mirror integrity; documentation. N/A: new geometry, asset placement, preview, streaming or input owners. DEFERRED to user acceptance: full gameplay/device transition matrix and paint responsiveness. DEFERRED before production release: real isolated-place DataStore save/rejoin, API outage and multi-server contention; old-server drain procedure. Do not claim crash-proof durability or a full security audit of all remotes.

Phase 2 was user-confirmed on 2026-09-05: “everything seemed to work well on playthrough”. The user authorised Phase 3. This is broad gameplay acceptance, not a device-specific or real DataStore test. No publish performed. Phase 3 now supersedes the old server source layout; do not rerun the Phase 2 installer over it.

Lesson: test storage transport with injected dependencies and retain exact reproducible source edits. A sandbox smoke proves integration, not persistence durability. Maintenance instructions are in scripts/architecture_phase2/README.md.
