# Complete cleanup Phase 1 — scaffolding retirement

2026-09-05. **User-confirmed working by the continuation to complete cleanup Phase 2.** This is Phase 1 of the new four-phase plan. Current installed source baseline is in [the Phase 2 handoff](cleanup-phase2-canonical-ownership.md).

## Scope and result

High-Risk retirement lane. The approved goal was to remove proven-unused scaffolding, freeze migration evidence and classify physical staging/archive content. Existing gameplay, rendering, input, preview, networking, persistence and asset owners remain unchanged. No new runtime owner or API, no data-schema/ID changes and no physical asset deletion. Entire Workspace was preserved, including the authorised World subtree and excluded WIP.

Removed **91 objects across 16 selected roots**, plus **15 obsolete root migration attributes**. No gameplay Script/LocalScript/ModuleScript was removed or edited in this phase; all **323 source hashes remain unchanged**.

| Removed root | Reason |
|---|---|
| `ServerStorage.HOVER_RACING_SAVED_CARS_Runtime` | Empty unused historical container; no saved player records stored here |
| `StarterGui.NeoTokyoRacersUI` | Empty UI scaffold: ScreenGui and 21 placeholder folders, no actual visual components |
| `ReplicatedStorage.NTR_STUDIO_FULL_EXPORT_V2` | Historical instruction value and container; current exporter no longer has an instance-writing branch |
| `ReplicatedStorage.NTR_DEBUG` | Historical garage source-dump value and container |
| `ReplicatedStorage.NeoTokyoRacers.LiveReferences` | 45 unused historical ObjectValue shortcuts, including null/detached targets |
| `ReplicatedStorage.NeoTokyoRacers.MigrationNotes` | Seven historical implementation-note values and container |
| `ReplicatedStorage.NeoTokyoRacers.README_Phase1`, `README_Phase2`, `DO_NOT_TOUCH_Test_WIP_Assets` | Obsolete in-game instructions; current scope is explicitly recorded in AGENTS/docs |
| `ReplicatedStorage.NeoTokyoRacers.Remotes` | Empty alternate remote scaffold; active Shared.Remotes remains |
| `ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Vehicles`, `.Economy` | Empty original scaffolds, no current callers found |
| `ServerScriptService.NeoTokyoRacers.Services.Economy` | Empty old service scaffold; current EconomyServer remains |
| `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Garage`, `.State`, `.RuntimeState` | Empty unused scaffolds; active feature state and adapter paths remain |

The 15 removed attributes were exact obsolete status/history keys on the ReplicatedStorage/server/client roots, including `LiveEnabled=false`, `Phase1PlaceholderOnly`, `CurrentLiveClient`, `CurrentLiveServer`, `RuntimeScaffoldStatus`, `MigrationStatus` and old Phase K status. No Workspace attributes, current tuning or operational state were changed. Exact paths/values are in `scripts/cleanup_phase1/baseline.json`.

The exporter is now receiver-only. An unavailable receiver/import failure stops with a clear error and cannot create fallback folders, chunk StringValues or source dumps. The wire format and local endpoint stay compatible with the current importer; wider generic tool naming remains later scope. The importer can still read an existing historical export file on disk; that does not create in-game fallbacks.

## Safeguards and evidence

- Started from verified live source parity and refreshed the pre-phase mirror at **12:30:05**. Frozen source fingerprints, owner maps and available config/remote/Bindable contracts are under `scripts/cleanup_phase1/`.
- Installer validates exact classes, contents, attributes, tags, selected subtree membership, target uniqueness, external ObjectValue references, source set and source compilation before mutation. Sources/metadata are rechecked after mutation. All deletions are restricted to non-Workspace Folder/ScreenGui/StringValue/ObjectValue records; no broad empty-folder sweep.
- AUDIT, INSTALL, repeat INSTALL, ROLLBACK and reinstall passed. Transaction failures reparent the original detached objects. Explicit later rollback rebuilds only the recorded scaffolding from repository data; no backup instances persist in Studio.
- **Recovery limit:** `LiveReferences.LightingPreview` and `LiveReferences.TrafficLightService` pointed to objects no longer parented in the game. Their names/classes are recorded. Explicit rollback restores those two unusable shortcuts as nil rather than resurrecting retired scripts; all other selected metadata/reference/property records are checked. The user's whole-game backup remains the broader recovery option.
- An actual unavailable-receiver test passed: expected error, identical instance identities/count, parents, names and attributes afterward; no export folder recreated. Eight local snapshot-pipeline tests also pass.
- Normal baseline and post-install Play both reached **26 server ready, 40 client ready, four opt-in tools skipped**. Actual Play-button input exited loading. Existing dealership event opened the canonical browser. Normal server commands in the confirmed no-save vehicle sandbox purchased `bruiser_01` (Cash 1,000,000 to 650,000), spawned it, and the existing client handoff reached DriverSeat/DriveReady. Exit/park passed after cleanup.
- **A continuous UI-driven short drive is not claimed:** tutorial interception remained during this scoped smoke. No tutorial gates were disabled to force a passing test. The user's short-drive checkpoint remains required. No published persistence test or gameplay acceptance is inferred from startup/source parity.

## Physical staging and archive decisions

**No physical contents were removed, renamed or moved.** These are tracked decisions for the later asset portion, not hidden cleanup leftovers.

`ServerStorage.NeoTokyoRacers.VehiclePerformanceV2_Staging` has 1,675 descendants: 84 models, 498 parts/meshparts and associated folders/lights/attachments. Its 78 catalogue-ID models all have live counterparts. The other six models are nested cockpit visual containers, not six missing catalogue entries.

Of those 78, **76 match a limited part-shape signature** (class/name, size, colour, material, transparency, anchoring/collision/query/touch and mesh/texture IDs). This is not a full duplicate proof: transforms, attachments, all light settings, arbitrary properties and all attributes are not compared by that signature.

- `bruiser_01`: live copy has three additional underglow parts.
- `bruiser_02`: live copy has additional underglow/front-spotlight parts and different lens composition.
- Recommendation: prefer the current live catalogue, never replace it from staging. Retiring the staging asset tree needs explicit physical-deletion/archival authorisation; the existing whole-place backup can serve as recovery if the user chooses deletion. See `asset-audit.json` and `asset-differences.json` for exact paths and comparison rows. Negative signed multiset counts denote more copies in live, not missing staging objects.

`ServerStorage.Archive` contains:

| Child | Observed contents / disposition |
|---|---|
| `ZZZ` | 1,437 descendants including garage structure/decoration assets and StarterTwoBay; purpose/unique-content decision required |
| `z icons etc` | 41 decals and three folders; retain only if an intentional authoring library is wanted |
| Two identically named `FBx - Test Base Vehicle v3` models | Each contains 35 MeshParts; identical names/counts do not prove duplication; disambiguate before any action |
| `audio` | Twelve sounds; determine which are useful prototypes before retaining in a named asset library or removing |

Do not relabel historical backups as Development just to satisfy a name check. Do not recursively delete Archive or staging without the concrete physical-asset decision. Phase 1's classification is delivered; asset disposition remains open for the full programme.

## Mirror, recovery and user check

Final full mirror: **2026-09-05 12:36:11**, schema 3, **323 verified sources**, 267,009 captured property values. Both mirror areas are current. The 42,656 remaining exported nodes match the expected pre-phase projection exactly, including all Workspace properties/attributes. There are 89 exported removals; the other two were the deliberately excluded historical export folder/instruction. Existing 2,918 duplicate non-source path warnings remain. Raw paste untouched.

Run local read-only checks with `scripts/cleanup_phase1/verify_phase.py` and `scripts/verify_studio_mirror.py`. Runtime/test evidence is in `scripts/cleanup_phase1/runtime-verification.json`.

Canonical Studio script: **`scripts/roblox_cleanup_phase1_scaffolding.lua`**, already applied via MCP. No manual install is needed. For intentional Edit recovery choose `MODE = "ROLLBACK"`; for a read-only check choose `AUDIT`. Restore this phase before earlier exact-baseline cleanup/architecture recovery. Do not restore the old exporter's instance-writing fallback. Refresh the mirror after recovery.

User checkpoint: fresh Play, normal loading/dealership entry, spawn a vehicle, short drive with steering/braking, exit and re-enter. Report the first changed behaviour or new error. Three further cleanup phases remain after this checkpoint; no automatic Phase 2 execution or publishing was performed. No Git commit was made. Include the two mirror areas, installer/support records and docs in the commit; exclude `docs/studio-full-export-paste.txt`.
