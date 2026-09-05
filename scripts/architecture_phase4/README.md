# Phase 4 maintenance

Canonical Studio entry: `../roblox_architecture_phase4_client_organisation.lua`. Default INSTALL, or set MODE to AUDIT/ROLLBACK. Edit mode and Space Racers v1 only. Already installed through MCP; no user run needed.

`build_installer.py` reconstructs original source from either the frozen Phase 3 mirror or the installed Phase 4 mirror plus `migration.json`, reverses exact edits and checks fingerprints before rebuilding. It uses the Phase 3 transactional installer template with explicit adaptations for client classes, literal-dot names and development config. `ClientLifecycle.lua`, `ConnectionScope.lua`, `PreviewInputClient.lua` are authored helper inputs. Generated `projected/` is ignored; installed source is reviewed in the refreshed mirror. Do not edit generated mirror source and expect Studio to update.

`baseline.json` freezes pre-phase source identities for verifying all unrelated sources. `verify_migration.py` checks source/class/enabled parity outside scope and canonical source/adapter parity within scope. `test_helpers.lua` builds the isolated Studio safety tests. Run tests through MCP; they do not access DataStores or mutate the game hierarchy.

ClientBase owns 44 explicit startup registrations: 40 normal entries and 4 opt-in development tools. Existing feature helpers retain their public APIs. PlayerScripts compatibility paths resolve the current player's runtime tree. Modules are single client-session owners; do not require/start stateful features from elevated diagnostic execution to infer the normal script cache. Inspect StartupState and existing Bindable endpoints instead.

Development attributes: `ReplicatedStorage.NeoTokyoRacers.Config.Development.ClientTools` → TrailerVehicleCameraEnabled, TrailerModeEnabled, TrailerShotEnabled, LightingPreviewEnabled. All default false. Change in Edit and start a fresh Play. They also hard-check Studio. Avoid enabling overlapping camera tools together. Missing authored trailer markers fail before changing the camera. Existing Studio cash/telemetry settings remain independent.

Rollback requires unchanged generated sources and default tool config. Set tool flags false before rollback. It restores Phase 3 source/classes and prunes only empty Phase 4 folders. It does not promise runtime hot reload, arbitrary property restoration, or recovery over subsequent code changes. Refresh the mirror after any migration.
