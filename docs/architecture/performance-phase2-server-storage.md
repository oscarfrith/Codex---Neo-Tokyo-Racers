# Performance Phase 2 — server-only storage

2026-09-22. **Installed and agent-verified; user playthrough pending.** Canonical script: scripts/roblox_performance_phase2_server_storage.lua, with INSTALL/AUDIT/ROLLBACK modes. Installed through MCP; no manual run needed.

## Acceptance contract

High-Risk architecture lane, narrow storage relocation. Move the six reviewed Phase 1 roots, update their six server callers, preserve all original instances/values/source semantics and every other system. Baseline is the confirmed cleanup Phase 4, freshly exported 2026-09-22 12:00:52 with exact full parity. No physical/world/asset/UI/client-code change; development tools and excluded WIP/staging/Archive preserved.

Owners stay unchanged: ProfileServer/EconomyServer own authoritative state, GarageUI/shared renderers own presentation/geometry, PreviewVehicleClient owns previews, VehicleVFXClient owns runtime VFX and existing session/LOD owners retain lifecycle. ServerBase/ClientBase startup entries are unchanged. No new endpoints, remote payloads, authority, saved schema/key migration, physics or tuning changes. Native LandscapeSensor remains. No new system lifecycle/version is needed for folder relocation. Failure handling, lease ownership, save gating and request validation must remain byte-identical apart from service paths.

## Exact changes

Move each suffix from ReplicatedStorage to ServerStorage:

- Modules.Game.Player.PlayerProfileSchema
- Modules.Game.Player.GarageProfileProjection
- Modules.Game.Vehicles.Performance.VehiclePerformance
- Config.Player.Persistence
- Config.Racing.PersonalBests
- Config.Racing.Leaderboards

14 instances move; four empty destination folders are created. No existing folder is deleted. Six callers change nine service-name string literals in proven navigation expressions: GarageServer (2), ProfileCompatibilityServer (2), ProfileServer (2), GlobalLeaderboardServer (1), PersonalBestServer (1), VehiclePerformanceServer (1). Token comparison rejects any other executable change. Moved module bodies, attributes and config Values remain identical. Shared VehicleCosmeticCatalog and PerformanceRuntime dependencies remain replicated.

## Delivery and recovery

The builder freezes the prior full mirror/source evidence in the repository. The canonical installer uses exact before/after source equality for changed callers, source fingerprints/class/enabled checks for all 160 sources, unique path resolution, metadata/value preflight, compile checks, old-path absence and destination collision checks. It reparents original instances. Mutation has an in-memory undo transaction, with no backup objects or alternate implementations left in game. Unchanged parent/name identities are checked during the transaction; full captured properties and SHA-256 values are verified independently after export.

INSTALL reruns audit an already-installed state. ROLLBACK restores sources and parents and removes only the four newly created folders if empty/unmodified; unexpected content stops it and restores the installed state. Run rollback before any older cleanup recovery. After future dependent migrations, undo those first. Do not force this exact-baseline installer over intentional source/config edits.

## Verification gate

Before handoff: AUDIT → INSTALL → repeat INSTALL → ROLLBACK → baseline AUDIT → INSTALL → installed AUDIT; all projected sources compile. Run normal Play without directly requiring gameplay modules through MCP: 26 server owners/39 client owners ready, four optional tools skipped, sandbox no-save retained, GetInitial and purchase/spawn/despawn/re-entry/performance state available. Personal-best/leaderboard config must resolve at new paths. No production writes or publish. Confirm 14 fewer replicated descendants and absent client access to moved roots. Device FPS/memory gains are not claimed; phone/load/route measurement gaps remain from Phase 1.

Export the Edit place afterward using the current receiver/exporter and run scripts/verify_studio_mirror.py plus scripts/performance_phase2/verify_migration.py. The older cleanup Phase 4 verifier is a pre-migration baseline check only after this phase installs. Done when exact expected source/hierarchy/property parity and normal runtime smoke pass, then request user playthrough. Persistence failure/lease semantics are preserved by token/source parity; real save/rejoin/contention remains a separate published-place release gate.

## Results and user handoff

All install/audit/repeat/rollback/reinstall checks passed. Injecting a failure after rollback mutation restored the installed sources/hierarchy and passed the installed audit. The first fault-injection harness stopped before execution due to CRLF matching; normalising its temporary buffer fixed the harness, with no canonical-installer or game-source repair.

Normal startup: 26 server ready, 39 client ready, four tools skipped; sandbox true. GetInitial, purchase, paint, spawn, exit, re-entry and despawn returned success. The moved writer produced RAW/NORMALIZED/HEADLINE folders, DriveReady=true, PerformanceIndex=551 and Tier C on the tested bruiser_01. Both leaderboard/personal-best settings resolved server-side; no leaderboard DataStore operation was invoked. Catalogue JSON size remains 173,361 bytes, as expected: this phase does not change catalogue payloads. Runtime client ReplicatedStorage count is 4,311 versus the prior 4,325, and moved schema/persistence paths are absent from the client.

Known CAM-02 BaseCamera/ZoomController clamp errors appeared during rapid transitions. Repeated errors truncated the console result, so this is not claimed as an error-free playthrough. Camera code is unchanged and previously reproduced on old baselines; fix separately. User should test normal garage browsing/purchase/customisation, drive/spawn/exit/re-entry, and time-trial entry/results. Stop and report new hangs/missing settings or changed stats. User confirmation remains pending; actual iPhone 7, multiplayer and save/rejoin coverage remains deferred.

Final mirror **2026-09-22 12:07:02**: 160 sources, **42,355 nodes**, 267,539 properties. Exact projected SHA-256 source and complete captured hierarchy/property parity pass with zero unexplained changes, including unchanged Workspace/physical content. Four added server folders explain the node increase. Authored ReplicatedStorage **4,323 → 4,309 descendants**; three moved module sources total 20,805 bytes. These are structural reductions, not measured memory/FPS/download gains. Evidence is scripts/performance_phase2/verification.json, runtime-verification.json and source-changes.json. Raw paste remains untouched. Studio is left in Edit; no publish performed.
