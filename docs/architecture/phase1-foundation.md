# Architecture Phase 1 — baseline and development foundation

Date: 2026-09-05. Scope approved in the current conversation. The user has a game backup and authorised direct work in Space Racers v1, place `121304917315753`.

## Contract

- Lane: High-Risk tooling/architecture foundation because the importer replaces the shared mirror. No gameplay implementation changes in this phase.
- Goal: trustworthy baseline, company-familiar naming plan, owner map and repeatable MCP delivery.
- Preserve: all live script sources/enabled states, gameplay, prices, rewards, saved IDs/schema, camera/input/UI, native LandscapeSensor, asset/config paths and placement.
- Current baseline: 193 live scripts match the pre-phase mirror. All compile in Edit mode. This establishes installation shape, not runtime confirmation.
- Required changes: compact current docs; explicit status vocabulary; source/owner migration map; installer index; property-aware export; validated staged import with rollback; local integrity verifier and failure tests.
- Excluded: renaming/moving runtime owners, persistence repairs, asset cleanup, balance changes, publishing, entering Play, and any DataStore access.
- State/geometry/preview/runtime/persistence owners remain the existing game owners. Snapshot tools own only repo mirror output; the audit owns no Studio objects.
- Inputs: selected Studio Edit datamodel and complete exporter payload. Outputs: hierarchy, sources, fingerprints and audit evidence.
- Lifecycle: receiver handles one loopback export and exits; exporter/audit finish without adding a runtime owner. Instance fallback is explicitly opt-in and off by default.
- Data/API: retain export format V2 with additive `schema_revision=3`; maintain legacy checksums, add local SHA-256. Source/path collisions and incomplete data block import. Duplicate non-source paths are warnings requiring scoped resolution.
- Scale: one bounded full snapshot per handoff; no gameplay loops. Explicit property allowlist. HTTP bodies capped at 1 MiB; exporter chunks use 180 KB before escaping. No performance claim from Edit-mode counts.
- Failure/rollback: validate before writing; stage both directories; restore previous outputs on ordinary promotion failure. Process/power interruption across the two directory swaps is not atomic; recover retained `.mirror-stage-*` directories before retrying.
- Shared reuse: existing receiver, exporter, importer and mirror manifests. No new runtime framework or owner.
- Tests: Unicode/integrity/property roundtrip, wrong-place/incomplete service rejection, duplicate source rejection, missing end marker, hierarchy mismatch, output containment and injected promotion failure; all live sources compile; post-export source fingerprints equal pre-phase.
- Devices: no device/runtime change. User smoke test remains pending on PC and landscape touch as available.
- Done when: tooling checks pass, new snapshot is verified, current status and handoff are recorded. Gameplay approval remains a separate user result.

## Approved five-phase programme

1. Baseline, naming/ownership, MCP and verification foundation (this phase).
2. Persistence/load/save/session ownership and request safety.
3. Server feature organisation and single authoritative command owners.
4. Client bootstrap extraction, lifecycle and development-tool isolation.
5. Measured optimisation, streaming cleanup and company-facing handoff.

Phase 1 was broadly user-confirmed on 2026-09-05 (“everything worked well”). Phase 2 is now installed; see phase2-persistence-safety.md. This confirmation does not establish a device-by-device matrix or saved-data testing. Use one canonical implementation per phase; do not resurrect the May architecture phase numbering.

## Canonical tools

- Studio read-only audit: `scripts/roblox_architecture_phase1_foundation_audit.lua`.
- Snapshot: `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` through the existing receiver.
- Local verification: `scripts/verify_studio_mirror.py --baseline docs/architecture/phase1-source-baseline.json`.
- Tooling tests: `scripts/test_studio_snapshot_pipeline.py`.

No gameplay installer is needed for a tooling-only phase. These are agent-run checks in one scope, not extra user setup phases.

## Baseline reconciliation

The current live driving module contains steering V1.2. Earlier documentation saying “generated” is stale installation status; user confirmation of that exact revision has not been established here. Preserve it and request reverse/forward transition checks. Do not automatically roll back to V74 or call V75 latest.

Both `StudioReplayEveryPlay` and `StudioVehicleSandboxEveryPlay` are true in the inspected source mirror/live configuration. This is an iteration baseline. Sandbox prevents profile saves through the existing Studio-only guard; do not interpret a sandbox rejoin as persistence verification. No setting is changed by Phase 1.

The misleading `_Shadow_Disabled` bootstrap and garage action scripts are enabled. Several `_Active` scripts are actually disabled. The frozen source baseline records real state; names are not authority.

## User smoke test

Start a fresh Play session and check loading/onboarding; dealership/customisation and Drive; acceleration, braking, reverse, three-point turns, drift/boost and camera; exit/re-entry; garage entry/exit; one Race or Time Trial including finish/exit. Check landscape touch if available. Report any Output errors and the exact transition. No visual or gameplay difference is expected.

Persistence failure tests belong to Phase 2 in isolated data. No save/rejoin claim is made here.

## Readiness

Ownership, source identity and tooling tests: recorded by the audit evidence. Networking/persistence gameplay mutation: N/A in Phase 1. Tooling output safety: staged rollback tested. Performance and gameplay runtime: deferred to user testing and later targeted work. The mirror is inspectable metadata, not a restorable place backup.

## Completion evidence

Phase 1 tooling is complete. The Edit export at `2026-09-05 10:43:47` contains 193 unchanged sources and 267,313 property values, with zero property-read failures. The eight failure/roundtrip tests pass. All 193 live sources compile before and after export; their byte counts, checksums and enabled states agree, and local SHA-256 matches the frozen source baseline. See `phase1-verification.json`.

The 2,918 duplicate non-source paths are a recorded authoring warning, not permission for cleanup. No gameplay source changed in Phase 1. The user subsequently confirmed the smoke test worked well and approved Phase 2.
