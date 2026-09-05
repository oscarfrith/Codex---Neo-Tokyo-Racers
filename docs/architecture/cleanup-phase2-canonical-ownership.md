# Complete cleanup Phase 2 — canonical code ownership

2026-09-05. **User-confirmed working by continuation to complete cleanup Phase 3.** Phase 1 is also user-confirmed. Phase 3 is authorised; read its naming handoff for pending scope decisions. Two phases remain unfinished in the approved plan. The phase-completion tests below retain their original agent evidence and device/persistence limits.

## Acceptance and ownership

High-Risk connected migration: remove forwarding adapters, old code hosts and unused execution branches while preserving gameplay, UI geometry/renderers, preview, input, camera, racing, VFX/audio, persistence authority/schema and tuning. ServerBase and ClientBase remain the only startup owners. No new remotes, saved IDs, economic rules, device layouts or physical assets. LandscapeSensor remains the device contract. Entire Workspace, including excluded WIP, is unchanged.

| Concern | Current owner/location |
|---|---|
| Server implementations | ServerStorage.Modules.Core / Modules.Game.<Feature> |
| Shared/client implementations | ReplicatedStorage.Modules.Core / Modules.Game.<Feature> |
| Server instance state and Bindables | ServerStorage.Runtime.<Feature> |
| Per-player instance state and Bindables | PlayerScripts.Runtime.<Feature>, authored in StarterPlayerScripts.Runtime |
| Garage interface | Game.Garage.GarageUI, started directly by ClientBase; existing renderer/layout/preview owners preserved |
| Vehicle session callbacks | Game.Vehicles.DriveSessionClient; invokes existing DrivingClient and handles spawn/exit and mobile telemetry |
| Profile authority | Existing ProfileServer and garage projection APIs; saved conversion semantics retained |
| Garage root tuning | ReplicatedStorage.Config.Garage: StartingCash, SpawnX/Y/Z, PreviewX/Y/Z, exact prior values |

## Changes

Sources reduced from **323 to 160**. Removed 133 forwarding adapters, the unused GarageClient legacy closure, no-op startup entries and unused helper/fallback modules. Remaining shared implementations moved to canonical modules; callers migrated together. Removed old ServerScriptService.NeoTokyoRacers, StarterPlayerScripts.NeoTokyoRacersClient and ReplicatedStorage.NeoTokyoRacers.Shared.Modules trees after migrating their live endpoints. Required VehicleDynamics, UI Theme and garage property catalog now resolve their canonical implementations directly.

Runtime endpoints are real moved instances, not duplicate owners or compatibility wrappers. Countdown readiness producer/consumer share Runtime.Racing; LOD reporting uses Runtime.World while its policy/runtime algorithms remain unchanged. Kept four explicitly opt-in development tools. No in-game backups, historical source dumps or alternate legacy renderers were created.

Remaining branded asset/config/remote roots, technical attributes/tags/private names, Loading and World naming are Phase 3 scope. Physical staging/archive dispositions remain unresolved protected-asset decisions. This phase does not declare the entire cleanup programme complete.

## Installer and recovery

Canonical script: `scripts/roblox_cleanup_phase2_canonical_ownership.lua`, already executed through MCP in Edit. No manual installation is needed. INSTALL checks exact source/class/enabled baselines, compiles projected sources, checks metadata/references and applies the coordinated migration. Repeated INSTALL and AUDIT check the installed source/compile baseline; the separate mirror verifier checks the complete expected exported hierarchy/properties.

Source projection uses guarded edits of frozen local source, including exact text anchors. The live installer writes complete precompiled source after exact full-source preflight; it does not repair arbitrary live source with text replacement. Support/maps/frozen recovery evidence are in `scripts/cleanup_phase2/`; only projection-index.json lists current projected sources. Files under before/ are repository recovery history, never installed alongside current code.

ROLLBACK mode in the same installer restores the exact pre-phase source/metadata and moves endpoints back. Stop Play first; do not force it over later source edits. Automatic transaction failure reverses its journal. Explicit recovery and reinstall were exercised, including ObjectValue target restoration. The external whole-game backup is also available. Older installers require dependent cleanup rollback first. No publish or production data migration occurred.

## Verification and remaining checkpoint

- All 160 sources compile; normal startup: 26 server ready, 39 client ready, four development tools skipped. No gameplay-module require through MCP was used to simulate startup.
- Sandbox checks passed: initial profile/catalog request, dealership opening and renderer geometry ownership, vehicle purchase, paint, spawn/DriveReady, exit/re-entry, owned-garage state, authoritative race vehicle validation, time-trial staging/countdown/start/cancel and removal of its 47 temporary proxies. A migrated countdown readiness reader was repaired within this same installer and repeated successfully. Final startup, initial garage request and Runtime.World running status pass after final source corrections.
- Local checks cover path parsing/alias shadowing, required owner routes, countdown producer/consumer, unchanged driving numeric tokens, unchanged LOD policy/runtime source and persistence schema/transport invariants. Full mirror verification checks each source hash and every captured hierarchy/property record against the migration map.
- Final receiver/exporter refresh: **2026-09-05 15:14:10**, 160 sources, 266,996 property values, 42,491 hierarchy nodes. Expected source/hierarchy parity passes with zero unexplained additions/removals; entire Workspace digest equals the frozen Phase 1 baseline. Evidence: `scripts/cleanup_phase2/verification.json`. Export property coverage is an allowlist, not a full place backup.
- User checkpoint: dealership, buy/equip/customise/paint/preview, spawn and drive, boost/drift/reverse/braking, exit/re-entry, owned-garage interior, complete race/time trial and return to free roam; landscape touch where available. Full driving was not established by agent input probes because onboarding gated control. Multi-client, actual mobile, published streaming and real save/rejoin remain separate release checks. Studio sandbox suppresses saves.

Lesson: old script containers can own live Bindables/readiness attributes even after their code becomes an adapter. Migrate those objects and both sides of every readiness contract before removing the host; normal startup and transition checks are essential beyond compilation.
