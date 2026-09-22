# Complete architecture cleanup plan

**2026-09-22 execution update:** Phase 4 installed and agent-verified; user test pending. Earlier status paragraphs are historical. See cleanup-phase4-finalisation.md. Protected staging/archive decision remains open; no physical deletion authorised. No additional subdivision.

Original plan below; current delivery status is the September 22 execution update above.

## Acceptance contract

High-Risk lane: connected architecture, dependency retirement, instance paths, metadata and runtime lifecycle. Goal: only current implementations and meaningful, generically named content remain within scope, with the same gameplay. This is organisational work, not a redesign or a new gameplay system.

- Workspace scope is exactly the current `Workspace.NeoTokyoRacersWorld` instance and its descendants. Rename that root to `World`. Everything else in Workspace is WIP and excluded from edits, renames, tag/attribute changes, moves and deletion, except the explicitly approved two lighting-tag membership renames on the exact 62 objects in scripts/cleanup_phase3/wip-lighting-tags.json. Do not move WIP into World to bring it into scope.
- Other game-owned services remain in scope for code, folders, configuration, remotes, UI, audio groups and development tools. Engine-owned objects/debuggers are not authored cleanup targets.
- Preserve physical models, meshes, parts, identity, geometry, placement, appearance, physics and asset IDs. Folder moves must not destroy descendants. Technical tag/attribute renames on protected objects require explicit enumeration as part of the approved migration, with values/membership preserved; they do not authorise geometry or content changes. Any physical deletion or asset export/removal needs a specific user decision.
- No NTR, NeoTokyoRacers or HOVER_RACING branding in current in-scope technical instance names, runtime-generated names, tag/attribute keys or current code-facing identifiers. Remove obsolete patch/version/status names; meaningful data/schema versions remain.
- No in-game backup folders/scripts, retired implementations, alternate legacy renderers, old-path fallback lookups or historical export dumps. Keep recovery source/metadata only in the repository; the user already has a whole-place backup. No new transitional adapters; existing adapters remain only until their owner is migrated, then disappear in that same delivery.
- Keep explicitly requested opt-in development tools, organised under Development and off by default. Keep current operational safeguards: validation, authority, failed-load/save protection, missing-streamed-content handling, cancellation and lifecycle cleanup. These must not be mistaken for old implementations.
- Preserve gameplay equations, tuning, prices/rewards, catalogue IDs, owned items, saved schema, remote payload meaning, authority/rate limits, UI appearance/transitions, input, camera, preview, VFX, audio, races and LOD behaviour. Mobile remains LandscapeSensor. Do not fix unrelated known gameplay issues or change balance under this scope.
- Preserve existing external DataStore identifiers, saved IDs and historical repository records. These are documented identity/history exceptions, not backup implementations. If eliminating their old strings is required, propose a separate data migration; never silently point at empty stores.

## Evidence and baseline

The initial cleanup mirror is `2026-09-05 12:07:40`: 323 mutually verified sources, 267,069 captured property values. The preceding live audit found all 323 source/class/enabled fingerprints matching. The original five-phase programme is user-confirmed; acceptance of the initial retirement playtest is not separately recorded. Capture current normal gameplay observations before further mutation instead of inventing confirmation.

Audit findings: 133 short forwarding modules; 132 source bodies bind `local script` to old paths; 60 scripts remain under the old shared module tree; 41 source files mention the branded World path. These are inventory observations, not automatic deletion counts or proof that every occurrence is executable. The place contains 3,433 empty folders, including intentional runtime containers and asset structure. There are 2,918 ambiguous non-source paths; never mutate by a dotted name without disambiguation.

## End-state layout

| Location | Responsibility |
|---|---|
| `Workspace.World` | Existing in-scope authored world; preserve its child content and physical properties |
| `ReplicatedFirst.Loading` | Current early loading implementation |
| `ReplicatedStorage.Modules.Core` | Small genuinely shared infrastructure |
| `ReplicatedStorage.Modules.Game.<Feature>` | Canonical shared/client implementations and definitions |
| `ReplicatedStorage.Config.<Feature>` | One authoritative designer configuration tree, with generic responsibility names |
| `ReplicatedStorage.Assets.<Feature>` | Existing assets needed by clients |
| `ReplicatedStorage.Remotes.<Feature>` | Existing network boundaries with unchanged authority/payload semantics |
| `ServerScriptService.ServerBase` | Explicit server startup |
| `ServerStorage.Modules.Core` / `Modules.Game.<Feature>` | Canonical server implementation |
| `ServerStorage.Assets.<Feature>` | Server-only templates/assets |
| `ServerStorage.Runtime.<Feature>` | Existing server runtime instance state/endpoints where needed |
| `StarterPlayer.StarterPlayerScripts.ClientBase` | Explicit client startup |
| `PlayerScripts.Runtime.<Feature>` | Client-created state/events where needed; no duplicate code tree |
| `SoundService` | Current generically named audio groups |

Keep the established FeatureServer / FeatureClient / FeatureUI vocabulary, PascalCase instance/module names and small explicit owner APIs. No required folder merely to fill this table; create only containers with an actual owner/use. Do not replace old roots with a new generic catch-all Game folder. No artificial renaming of stable authored catalogue identities.

## Phase 1 — Retire obsolete scaffolding and establish exact migration records

Freeze the dependency/path map, physical/out-of-scope invariants, baseline tuning/data contracts, and normal gameplay observations. Resolve staging asset decisions early. Inventory all game-owned non-Workspace containers plus World descendants, including generated-name producers, tags, attributes, ObjectValues, string paths and runtime endpoints.

Remove individually verified unused items: `HOVER_RACING_SAVED_CARS_Runtime`, empty `NeoTokyoRacersUI`, the old `NTR_STUDIO_FULL_EXPORT_V2` instruction folder, `NTR_DEBUG` source dump, unused migration notes/readmes and obsolete LiveReferences. Preserve intentional runtime containers and useful designer controls. Historical source absence is supporting evidence; validate dynamic readers and external references before removal.

Remove the exporter's in-game fallback-writing branch as part of retiring its output folder; an unavailable receiver must fail without writing Studio objects. Store recovery evidence locally. Classify remaining empty scaffolds and misleading migration stamps for removal, not a blanket empty-folder sweep.

`VehiclePerformanceV2_Staging` contains 1,675 descendants, including 84 models and 498 parts/meshparts; it is marked published and historical installation code cloned from it. Compare identity/content against the current catalogue and distinguish duplicates from unique prototypes. Likewise classify existing ServerStorage.Archive content. Present a concrete asset list for any proposed physical export/deletion. Preserve unique authorised development assets under meaningful asset-library categories; do not relabel a backup folder as Development and call it resolved. If a decision is outstanding, track it as an open completion blocker for the applicable asset portion.

**Exit check:** retired scaffolding absent, physical/out-of-scope parity, exporter cannot recreate dumps, current startup and loading/dealership/drive smoke unchanged. User checkpoint: normal entry, vehicle spawn and short drive.

## Phase 2 — Finish canonical code ownership and remove legacy execution paths

Migrate server, shared and client dependencies to their final canonical modules. Move remaining shared implementations, rewrite callers together, and remove forwarding modules only after their callers and runtime children have migrated. Eliminate `local script = oldPath` rebinding; use the real module for private dependencies and explicit feature-owned runtime state/events for player-local or server-local objects. Do not replace this with a giant global context table or a second startup owner.

Preserve ServerBase/ClientBase explicit startup and dependency readiness. Move actual Bindable endpoints/state before destroying their old hosts. Remove old Services and client controller namespaces once genuinely empty/unreferenced. Resolve root attributes still consumed by code into current feature configuration rather than dropping values.

Extract still-used behaviour from GarageClient's legacy closure into current owners without changing the shared UI renderer, geometry, camera or preview contracts. Remove unreachable/retired UI and performance execution branches only with callgraph and normal-runtime evidence. Required current dependencies should report clear errors, not silently activate a retired renderer. Remove old theme fallback lookups once current Theme is guaranteed and value parity verified. Preserve active profile projection behaviour through the current authoritative owner; names containing Compatibility do not permit deleting needed data semantics. Saved-data conversion/validation is distinct from a legacy runtime fallback.

**Exit check:** migrated features have one implementation; no surviving old-path adapter dependencies or legacy execution routes; public behaviour, profile changes and lifecycle invariants hold. User checkpoint: dealership, buy/customise/paint, preview, vehicle spawn/despawn, owned garage, race/TT and return to free roam.

## Phase 3 — Complete generic hierarchy, configuration and technical naming

Rename World and migrate all its direct/string-path consumers together. Flatten branded ReplicatedStorage roots into Assets/Config/Remotes and final module locations; move server template folders into Assets and remove emptied branded shells. Rename Loading, audio groups, root/runtime scripts and generated interfaces/events to final responsibility names. Do not retain branded alias folders.

Consolidate Config and Shared.Config into one feature-based tree, copying effective values exactly and updating readers/writers together. Resolve collisions explicitly: a live theme and fallback theme are not interchangeable, and driving camera defaults may have a legitimate separate role. Remove redundant copies only after proving equivalence or preserving their current role in one owner. Replace names such as `_EditAttributes`, `_DoNotRename` and patch-labelled staging with meaningful names and repo documentation.

Migrate active tag/attribute keys, CollectionService membership, producer/consumer lookups, sound references, generated names, diagnostic labels and embedded technical revision strings in one coordinated map. Delete unused historical metadata instead of renaming it. Preserve stable IDs/schema versions and external storage keys. Check collisions and references to excluded Workspace WIP before mutation; never broaden the boundary to satisfy a naming scan. Any unavoidable old external contract must be reported explicitly, not hidden behind a fallback.

Finish approved staging/archive dispositions from Phase 1 without modifying physical content outside its specific approval. Keep authored WIP outside World untouched. No asset/model name sweep or blanket FindFirstChild replacement. Source transformations must be reviewed against exact frozen source, syntax checked and occurrence-count guarded; disclose any fragile anchor dependency before writing the installer.

**Exit check:** all in-scope technical names use the new map in Edit and normal Play; no old roots are recreated; remotes, tags, sound routing, config values and object references still resolve. User checkpoint: city traversal/LOD, garage transitions, complete race, audio/VFX, respawn and landscape touch.

## Phase 4 — Tooling, final regression and closure

Update the current installer/export/receiver/audit workflow and current AI documentation to use the final paths and name contracts. Keep historical recovery evidence clearly separated and unchanged; obsolete installers are not current entry points. No export, install or debug tool may create persistent in-game backups, source dumps or alternate implementations. Tests use disposable isolated fixtures with guaranteed cleanup, not persistent backup instances.

Add a repeatable read-only audit over in-scope Edit hierarchy, sources and normal runtime snapshots. Check branded/patch technical names, old paths, forwarding-only code, unused metadata, dangling references, config duplication, missing dependency ownership and backup/fallback creation routes. Report actual errors and exact documented exceptions; keyword hits alone do not justify deletion. Validate final source/hierarchy parity and run the full regression matrix below. Address discovered in-scope cleanup failures within this phase, not an unapproved patch ladder.

Resolve all retained-item decisions before declaring completion. Every item is current and purposefully organised, removed, or an explicit approved external/history/WIP exception. Do not declare completion with an unclassified legacy pile or a deferred general cleanup pass.

**Exit check:** full acceptance ledger, no unresolved in-scope legacy cleanup, user final gameplay confirmation, current mirror and company-facing handoff. No publishing automatically.

## Verification and delivery protocol for every phase

- One canonical installer per phase under scripts/, applied via MCP to verified Space Racers v1 in Edit. No source edits or runtime migrations until the phase is authorised. Recheck the mirror/live state before each phase; stop on unexplained drift.
- Preflight every rename, deletion, class, source fingerprint, target collision and reference before mutation. Exact repo-backed recovery and transactional failure handling; no persistent in-game backups. Test audit, repeat installation and rollback/reinstall where appropriate. No blind global search-and-replace.
- Compile affected/all sources as appropriate; verify explicit startup, required feature health and readiness. Current reference after cleanup Phase 2 is 26 server ready, 39 client ready, four opt-in tools skipped; any changed composition needs an explained owner map, not a magic count assertion.
- Freeze and compare saved schema/IDs, authoritative command results, effective config values and representative driving/performance outputs. Preserve remote type, validation, permissions, rate limits and reward conditions. Test profile load failure, transactions and clean exit with isolated data fixtures if affected; never treat sandbox no-save Play as real persistence proof.
- Test repeated transitions: loading, dealership, purchase/equip/paint, preview, spawn/drive/boost/drift/reverse/brake, exit/re-entry, garage enter/exit, race queue/start/finish/cancel/results, respawn and reconnect where available. Confirm camera/input release and no extra connections, loops, UI layers, vehicles or VFX owners.
- Use ordinary runtime owners, not elevated MCP require-cache copies. Multi-client checks for shared remotes/vehicle/race boundaries where available; explicitly report unavailable evidence. Preserve landscape phone/tablet controls and controller behaviour where supported. No new portrait/UI redesign.
- Preserve LOD thresholds, dynamic registration and streamed-out/late-content handling. Compare repeated-transition resource counts and representative performance with the captured baseline; no new whole-world scans, duplicated startup or persistent regression without resolution. Real low-end-device and published streaming testing remain separate from Studio fixtures.
- Compare physical object identity and covered properties under approved path mappings; renaming a parent changes descendant paths, not object identity or geometry. Verify excluded Workspace roots are untouched. Account for duplicate names and exporter-local IDs. Supplement the exporter's property allowlist for any touched technical properties/tags; mirror equality alone cannot prove unexported properties stayed unchanged.
- Refresh both mirrors through the receiver/exporter, verify integrity, update current baseline/issues/topic docs/history and report agent-tested versus user-confirmed status. Never stage docs/studio-full-export-paste.txt. No automatic production publish or DataStore namespace migration.

## Completion ledger

Phases 1–3 are user-confirmed. Phase 4 is installed and agent-verified; user playthrough and protected staging/archive disposition remain open. See cleanup-phase4-finalisation.md for the exact retained-item ledger. No additional phase was created.

Known pre-existing concerns (including drive-in VehicleCamera output and published persistence/device gates) remain separately tracked. Preserving current behaviour does not certify that every old bug is fixed. A restore to the whole-game backup is recovery, not a substitute for preserving player data or proving the migration works.
