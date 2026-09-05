# MCP delivery and verification

2026-09-05 cleanup Phase 3 is installed and user-confirmed. Canonical paths now use Workspace.World, ReplicatedStorage.Assets/Remotes/Config and feature configuration folders. Physical content is preserved. Mirror 16:06:57 passes exact expected source/hierarchy/property parity. See docs/architecture/cleanup-phase3-generic-naming.md.

**Current cleanup Phase 3:** 160 canonical sources; Runtime endpoints remain feature-owned. Inspect ServerBase/ClientBase normal readiness, never require stateful gameplay modules through MCP as a startup probe. Apply only the approved next installer in Edit; export after changes and run verify_studio_mirror.py plus the applicable migration verifier. The confirmed Phase 3 verifier is cleanup_phase3/verify_migration.py. Exporter/receiver filenames and wire route remain current until Phase 4 tooling migration. See [laptop handoff](laptop-handoff-2026-09-05.md).

1. Read current baseline/issues and the relevant topic/owner map. Check Git status. Inspect the recent history entry only when needed; historical notes are not current instructions.
2. List connected studios on every new session. Resolve **Space Racers v1**, place `121304917315753`, and inspect datamodel mode. Never reuse another place's ID or assume Edit while Play is running.
3. Inspect affected live sources, properties and callers. For phase work, compare the mirror against the expected baseline. `Source` markers prove installation, not runtime success.
4. Prepare one reviewable repo change/installer with preflight and rollback. Use current session authorisation; do not ask repeatedly for approved scope. Preserve the user test boundary and do not publish.
5. Execute the exact checked-in script through MCP. Read-only audits must not `require` gameplay modules (require can start loops or mutate state). Compile with `loadstring` without invoking compiled functions.
6. Inspect a separate committed-state read after mutation. Run only relevant runtime tests with explicit isolation for saved data. Keep user-confirmed results distinct from static evidence.
7. Start `scripts/receive_studio_full_snapshot_export.py` locally, then execute the exact `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in Edit through MCP. Receiver is loopback-only and handles one export. If Python/py is missing, discover the bundled Python using the app's workspace dependencies tool. Do not hardcode one machine's runtime in project scripts.
8. Run `scripts/verify_studio_mirror.py`; for Phase 1 add `--baseline docs/architecture/phase1-source-baseline.json`. Read every warning. Refresh docs, review the diff and provide the requested commit text. Do not stage the raw paste blob.

## Snapshot semantics

V2 format is retained with additive schema revision 3. It captures sources, enabled states, hierarchy, attributes, and an explicit property allowlist: BasePart placement/size/collision/appearance, ValueBase.Value, model primary part/streaming mode, GUI geometry/state, lights, prompts and selected services. The allowlist is exported as `property_schema`; read failures are in `diagnostics.property_read_errors`.

This is not all Roblox properties, mesh data, terrain data, an asset download or a complete place backup. Zero property-read errors means captured properties were readable, not that unlisted properties were captured. Instance references include paths/segments; duplicate names remain ambiguous and must be resolved by scoped inspection, not guessed.

Hierarchy JSON retains a readable tree with typed attributes/properties compacted per node and stable object-key ordering. The Phase 1 snapshot is about 71 MB instead of 145 MB with fully expanded scalar indentation; no captured values are removed. This is a one-time formatting/coverage diff. It remains below 100 MB, but further content growth may warrant service shards in a separately scoped tooling change.

Exporter source/attribute read failures abort. Import checks source checksum/bytes/lines, complete services, matching hierarchy/source identity, wrong place, duplicate source/file identities and source encoding before replacing files. SHA-256 fingerprints supplement the legacy checksum locally.

Both outputs are staged before promotion. Ordinary I/O failure restores the old pair. The swap is not power-loss atomic; after interrupted import inspect `.mirror-stage-*` under roblox and recover before retrying. Never run concurrent receiver/import jobs.

Export does not create/delete/change any Studio object. Complete cleanup Phase 1 removed the instance-writing fallback entirely; HTTP/import failure stops with an actionable error. There is no opt-in StringValue dump path. The receiver leaves `docs/studio-full-export-paste.txt` untouched unless `--write-paste` is deliberately supplied. That file is already tracked historically: `.gitignore` does not untrack it. Leave the user's existing diff alone.

## Evidence levels

Generated = exists in repo. Installed = fresh source/property evidence. Runtime verified = observed relevant behaviour in a named test environment. User confirmed = explicit user acceptance. Never promote between these automatically.

## Source authoring direction

Phase 1 keeps Studio authoritative. Later extracted modules can be authored as normal source files and packaged into the single installer. Choose one authoritative direction per module; mirror files are not auto-sync inputs. A future source-sync pilot must be separately scoped, not silently introduced now.
