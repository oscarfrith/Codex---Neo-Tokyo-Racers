# Targeted Studio capture

Workflow Phase 2 implementation and evidence. Current task/next step: [start here](../00_START_HERE.md).

## Contract

Standard repository-tooling change; gameplay state, geometry, owners, saved data, economy and device behaviour are not changed. Studio remains authoritative. The tool reads Edit state, sends it only to a bounded loopback receiver and publishes versioned evidence. No instances, backups, runtime owners or remotes are installed.
Schema 1 owns capture records under roblox/captures; source text is stored once per SHA256 under roblox/source_store. The existing exporter owns typed value/property serialization; the existing importer owns source decoding/integrity checks and compact JSON formatting. No automatic source-store-to-Studio writes.
Done when live source/config/vehicle captures, repeat comparison, projection/naming compatibility and failure tests pass. Authority/persistence/device gameplay tests are N/A for this read-only tool; their game release gates stay open.

## Routine capture

The assistant runs these internally after confirming the target Studio instance and Edit mode. Rediscover Python on each machine; py below is illustrative.

1. Choose a unique capture name for each before/after record, such as task-before/task-after. Choose identical root paths and property coverage for both.
2. Run: py scripts/studio_capture.py receive --name task-before --preset sources
3. In the confirmed Space Racers Edit instance execute:
   return loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8766/script"))()
4. Run: py scripts/studio_capture.py verify roblox/captures/task-before/capture.json
5. After the scoped change, capture task-after with the same coverage and compare:
   py scripts/studio_capture.py compare roblox/captures/task-before/capture.json roblox/captures/task-after/capture.json
   Add --details to inspect exact removed/added/changed node records, including attributes/properties/tags.
6. Review expected versus unexpected deltas and commit the new capture records plus new source blobs. The tool never commits or applies gameplay changes automatically.

Presets:
- sources: complete source inventory/text for the nine inventoried services; source attributes, properties and tags; no physical subtree export.
- config: both Config trees, plus the same source inventory.
- vehicles: ServerStorage.Assets.Vehicles and ReplicatedStorage.Assets.VehiclePreviews, plus the same source inventory.
- --roots accepts a JSON array of path-part arrays instead of a preset. Include every affected subtree/dependency and both old/new roots for moves. Ancestors may replace multiple nested roots; overlapping roots are rejected.
- --properties accepts additional coverage as a JSON object mapping class names to property-name arrays, for example Folder to Archivable or BasePart to Reflectance. Select the actual changed properties; unsupported reads fail capture instead of silently omitting them.

Requested roots are recursive. Missing roots are recorded explicitly, useful for creation/deletion checks; this is not permission to ignore an unexpectedly missing dependency. Ambiguous selected paths and source paths fail. Duplicate non-source siblings within a uniquely selected subtree are preserved and compared as multisets, never used as mutation addresses.
Source inventory covers ReplicatedFirst, ReplicatedStorage, ServerScriptService, ServerStorage, StarterPlayer, StarterGui, Workspace, Lighting and SoundService, including disabled scripts. It does not silently exclude WIP sources. Other services require explicit additional investigation/full-tool coverage work before claiming completeness.

## What is kept in Git

capture.json contains timestamp/place/mode, requested and missing roots, exact property coverage, selected hierarchy/tags, source inventory and an integrity digest. Each manifest row maps the readable Roblox path to its class, enabled state, attributes/properties/tags and source SHA256/file. Follow that row to inspect the readable .lua source blob.
Identical source text is stored once even across different paths/captures. A rename appears as remove/add; the tool does not infer identity or approve the move. No mutable latest pointer or automatic merging of snapshots from different times.
Captures are dated evidence, not a complete live mirror. The assistant names the evidence used in the handoff/startup record. Changed source outside scope is detected by inventory comparison and investigated, not overwritten.
Full source text is read/transmitted each time to compute exact SHA256 locally. The approximately 100 KB source-only record is the stored manifest, not the network transfer size or a measured wall-clock saving.

## Checks using targeted input

- Source naming: py scripts/audit_cleanup.py --capture roblox/captures/task-after/capture.json
- Vehicle freshness: py scripts/performance_phase4/check_projection.py --capture roblox/captures/vehicle-after/capture.json
  Requires both complete vehicle roots. Uses the same catalogue generator and preview projection comparison as full export; generated source comes from the capture's verified source store.
- Read-only live hierarchy/ownership audit remains scripts/studio_cleanup_audit.lua where needed.
- Historical full-mirror mode for the two adapted local checkers requires --legacy-mirror explicitly. There is no silent default to stale full data.
- Old exact migration verifiers remain tied to their historical full baselines. Use them only with a matching full checkpoint; they are not generic current-state checks.

## Scope limits and checkpoint policy

Do not claim whole-World physical parity from selected roots or infer an unselected property's value. Tags are now captured for selected nodes and inventoried scripts; full historical mirrors did not capture tags.
Broaden selected roots/properties when dependencies demand it. Use deliberate full checkpoints for broad hierarchy migrations, unexplained broad drift or recovery requirements exceeding selected coverage. Full capture is still an allowlisted export, not a complete place/terrain/asset backup. Keep a saved Roblox place for machine handoffs or physical recovery.
No full export for documentation-only tasks or merely because Play was tested and stopped. Cross-machine work requires repository evidence plus the actual saved place and newly discovered MCP/runtime settings.

## Failure/recovery

The receiver binds only 127.0.0.1:8766, accepts one request nonce/scope, limits body/chunk/total size, times out after ten minutes and bounds request reads to ten seconds. A nonce prevents accidental mixing; this is not authentication against a hostile local process.
Wrong place/mode/schema, incomplete services/sources/roots, corrupt payload/source, missing tags, property read failures, duplicate/conflicting chunks and invalid output names stop publication. Sources are checked before writes; immutable blobs precede atomic single-file publication. Existing capture names cannot be reused.
A failed publication can leave unreferenced source blobs or temporary empty directories; no prior capture/full mirror is replaced. A failed OS/disk write is not a guaranteed power-loss durability promise. Never promote an incomplete capture. Restart with a new name after fixing the cause; no in-game dump fallback.
The producer reuses the existing exporter prefix through exact checked repository anchors. If that serializer changes, generation stops until reviewed; this is not fragile replacement of live gameplay source.
Rollback of this phase is repository tooling/documentation only. Full-export files/tools remain intact. Do not delete historical sources or deploy old gameplay implementations.

## Verification

Live Edit captures: two identical vehicle captures, one source-only capture and one config capture with explicit Folder.Archivable coverage. Each inventories 165 sources matching the retained Phase 5 source hashes. Vehicle captures include 4,543 nodes and exactly match prior captured vehicle properties; tag-aware preview projection and catalogue source freshness pass. Repeated comparison reports zero differences; source naming audit passes.
Stored file sizes: source-only record 100,529 bytes; vehicle record 8,322,612 bytes versus the retained full hierarchy's 73,579,367 bytes. Source store is 2,117,576 bytes shared by all captures. These are artifact sizes, not wire/time/FPS savings.
Twenty-one scoped-capture tests pass, including source text/metadata add/remove, detailed attribute/tag/property differences, multiset duplicates, incompatible coverage, corruption, request bounds and preservation after failed publication. Injected stale authoring/preview data is rejected by the adapted checker.
Eleven retained full-pipeline tests pass on rerun. The initial transient-lock test observed an extra rename attempt (six instead of five); no full-export code was changed. Record this as environmental test sensitivity, not an unqualified first-run pass.
Evidence: scripts/workflow_phase2/verification.json and roblox/captures/workflow-phase2-*.
No gameplay code, source baseline, physical asset, config or full-mirror file changed. Studio remained in Edit; no gameplay acceptance is inferred.
