# Space Racers — architecture and development handoff

**Current override, 2026-09-22:** Phase 4 installed; user test pending. Use cleanup-phase4-finalisation.md and installer-index.md. Phase 3 is the last confirmed source baseline. September 22 physical edits are accepted and preserved. Earlier status/path notes below are historical where conflicting.

**Current baseline update:** All five original architecture phases and complete cleanup Phases 1–3 are user-confirmed. Cleanup Phase 4 remains. Sources: 160; normal startup: 26 server, 39 client, four opt-in tools skipped. See [Phase 3 handoff](cleanup-phase3-generic-naming.md) and [laptop continuation](laptop-handoff-2026-09-05.md).

Space Racers is a playable Roblox hover-racing prototype. This programme reorganises and hardens its backend while preserving the existing gameplay, UI, vehicles and content. Naming follows the inspected Untitled Experience's vocabulary; it is not presented as a certified company-wide standard or a copy of that game's framework.

## Where code lives

| Responsibility | Canonical location | Contract |
|---|---|---|
| Server composition | ServerScriptService.ServerBase | Explicit startup/dependencies; isolated optional failures |
| Server features | ServerStorage.Modules.Game | Player, Garage, Vehicles, Racing, World, Audio, Development |
| Client composition | StarterPlayer.StarterPlayerScripts.ClientBase | Explicit startup; development tools require Studio + opt-in |
| Client/shared features | ReplicatedStorage.Modules.Game | Existing renderers/controllers grouped by responsibility |
| Core infrastructure | ServerStorage.Modules.Core / ReplicatedStorage.Modules.Core | Small startup and subscription helpers; no gameplay state |
| Early loading | ReplicatedFirst.Loading | Remains independent of normal client startup |
| Designer data/assets | ReplicatedStorage.Config / Assets; ServerStorage.Assets | Stable paths/IDs, configurable tuning; physical content unchanged |
| Mirror and delivery | roblox/exported_scripts, roblox/studio_snapshot, scripts/, docs/ | Reviewed installers, generated evidence, explicit baseline |

The current exact naming map is cleanup-phase3-generic-naming.md and scripts/cleanup_phase3/path-map.json. Earlier phase maps are history. Old forwarding adapters are removed; current implementations and feature Runtime endpoints are canonical. Stable external DataStore/catalogue identifiers remain unchanged.

## State and safety

ProfileServer owns the authoritative session/profile and save lifecycle. Garage and race rewards mutate that same session, avoiding cached balance/profile imports. Runtime compatibility fields are filtered from snapshots/encoding. Save transport has lease ownership, serialised writes and dirty revision tracking; failed loads and Studio sandbox sessions cannot save writable defaults. Existing garage request validation and overlap/rate protection remain.

Client presentation state stays separate from authoritative ownership/rewards. Existing shared UI geometry, preview rendering and the single VehicleVFXClient attachment owner remain. LODClient owns city detail; LODRuntime owns cached memberships, streaming cleanup and far clones; LODPolicy owns pure distance decisions. The native mobile orientation contract remains LandscapeSensor.

## Delivery with Studio MCP

1. Read the compact current baseline/issues, relevant topic and owner map. Check Git changes before editing.
2. Select Space Racers v1 explicitly and inspect Edit/Play mode. Compare live source with the expected mirror; refresh after user-confirmed playthroughs or drift.
3. Prepare one canonical, reviewable installer per approved scope. Compile/preflight before writes, preserve unrelated sources, support an idempotent audit and reversible migration. Do not publish without separate authorisation.
4. Execute the exact repo installer through MCP. Test failures and transitions proportionally; use sandbox fixtures for destructive/failure scenarios. Avoid requiring stateful gameplay modules from elevated diagnostics, which may have a different require cache. Inspect normal runtime status/endpoints instead.
5. Stop Play, run the receiver/exporter, verify mirror integrity, record measured results and limitations, then obtain user gameplay acceptance. Exclude docs/studio-full-export-paste.txt from commits.

The mirror is inspectable source/hierarchy/property evidence, not a complete Roblox place/terrain/mesh backup. Keep actual place backups and version history. Studio remains authoritative; mirror files are not automatically synced back into Studio. Source-sync/Rojo adoption should be a separately approved pilot on isolated modules rather than another simultaneous migration.

## Evidence and remaining work

All five phases are user-confirmed. Phase 5's implementation, exact checks and measurements are recorded in phase5-optimisation.md and phase5-verification.json. The separately authorised cleanup removed retired scripts and migration metadata without changing surviving source or physical objects; see legacy-cleanup.md for remaining adapters, retained development tools and user cleanup-playtest status. No release-readiness or general FPS improvement is claimed from source relocation.

Priority release checks:

- Test real save/rejoin, lease contention and failure recovery in an isolated published place. The current Studio replay/vehicle sandbox suppresses profile writes. Drain older deployed profile writers before rollout or rollback.
- Measure client frame time, memory, streaming stalls, draw calls and network load on target phones/tablets during cold/warm city laps, garage transitions and races. Use the WorldLOD profiler marker/opt-in diagnostics to separate LOD CPU from rendering/physics.
- Reproduce the pre-Phase-5 Output error in PlayerModule.VehicleCamera during drive-in customisation: it referenced an unparented DriverSeat. Inspect camera subject handoff versus despawn ordering before changing owners. The user reported gameplay working; this is an observed log issue, not proof of an ongoing visible failure.
- Review competitive race movement plausibility before expanding rewards. Ordered checkpoint touches alone are not a complete anti-cheat boundary.

Further architecture improvements should be incremental: retire adapters only after caller coverage; extract remaining GarageClient/GarageServer private legacy code around narrow contracts; avoid mechanical rewrites solely to reduce file length. Keep static integrity checks and proportional transition tests close to new features. Optimise map/VFX/audio/preview code only after identifying their cost on representative devices. Prototype placeholders, artwork and map presentation remain an intentional separate content pass.
