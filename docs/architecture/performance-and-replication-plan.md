# Performance and replication plan

2026-09-22. **Phase 4 installed and agent-verified; user playthrough pending.** See [Phase 4 handoff](performance-phase4-vehicle-previews.md). Phase 3 accepted for continuation. Selected the static generated-preview option: 333 fewer replicated folders and 1,479 fewer folder attributes; originals preserved server-side. Mesh/texture cost unchanged. Join/memory/FPS benefit and device/load acceptance remain unmeasured. Phases 5-6 unimplemented; selective delivery is not installed. iPhone 7 selected. The design below is the original programme; this paragraph is current execution status.

## Evidence and recommendation

Read-only MCP inspection of Space Racers v1 (121304917315753), current sources, configs, startup manifests, loading, garage preview/performance consumers and LOD documentation informed this plan. The post-confirmation mirror refreshed at **2026-09-22 11:00:13**: 160 sources, 42,351 nodes, 267,539 properties; exact Phase 4 source and expected whole hierarchy/property parity pass. Neither mirror appears stale against this inspection. No Studio mutation or performance implementation occurred.

| ReplicatedStorage subtree | Descendants | Relevant detail |
|---|---:|---|
| Entire service | 4,323 | 735 BaseParts; 109 sources, 1,275,342 source bytes |
| Assets.Vehicles | 2,437 | 729 BaseParts; 452 MeshPart/SpecialMesh instances; 1,149 folders |
| Config | 1,480 | Audio 467; Vehicles 450; UI 425 |
| Modules | 121 | 109 source containers; remaining descendants are folders |
| Assets.VFX | 152 | Client runtime and preview consumers |
| Assets.World | 98 | Includes client-used skies |
| Remotes | 26 | Seven feature folders and their endpoints |

Counts exclude each named root, overlap between parent/child rows, and do not measure asset-download bytes, Lua heap, texture memory or FPS. Mesh counts overlap BaseParts. Evidence: performance-inventory-2026-09-22.json. StreamingEnabled is true. Radius properties were not readable through this MCP execution context; inspect Studio Properties before any settings proposal.

Optimise unnecessary replication, not the number of folders moved. ServerStorage content is not replicated until placed in a replicated location. Shared code, remotes and preview content still need a client-accessible boundary. Moving a template and immediately cloning its entire catalogue into ReplicatedStorage would provide little benefit. Workspace streaming does not stream ReplicatedStorage. See [Roblox storage guidance](https://create.roblox.com/docs/scripting/locations) and [streaming scope](https://create.roblox.com/docs/workspace/streaming).

## What still needs cleanup

- Protected ServerStorage.NeoTokyoRacers.VehiclePerformanceV2_Staging and ServerStorage.Archive need an explicit physical-asset disposition. They contain 1,676 descendants under the branded host and 1,568 under Archive. They already impose no direct client replication cost. Do not delete based on overlapping IDs/partial shape matches, or recreate runtime backups.
- Empty asset/config folders may hold attributes, required slots or authoring contracts. Classify by consumers and contract, not emptiness. Remove only proven unused nonphysical scaffolding.
- External DataStore/session identifiers and stable catalogue IDs remain intentional. Renaming them is a data migration, not cosmetic cleanup. Defensive old GUI suppression keys remain intentional too.
- Audit remaining meaningful V2/schema terms separately from obsolete private names. Do not erase version semantics or change saved field names to achieve a zero-string count.
- CAM-02 camera NaN/clamp and CAM-01 despawn handoff are separate correctness follow-ups. Isolate them if they contaminate benchmarks; no camera behaviour rewrite hidden inside a storage migration.
- Historical installers belong in repository history, never in the game or the current run queue. No automatic bulk deletion of historical recovery evidence.

## Target ownership and storage

| Location | Intended responsibility |
|---|---|
| ServerStorage.Modules.Core/Game | Authoritative services, profile/schema helpers and vehicle writers |
| ServerStorage.Config.<Feature> | Server-only persistence, validation, reward and scheduling settings |
| ServerStorage.Assets.Vehicles | Canonical spawn/authoring templates, after consumer separation |
| ServerStorage.Assets.Garage/Racing | Existing server templates, preserved |
| ReplicatedStorage.Modules.Core/Game | Actual client implementations and shared pure calculations |
| ReplicatedStorage.Config.<Feature> | Client-needed tuning/presentation and compact public definitions |
| ReplicatedStorage.Assets | Small universally needed UI/VFX/sky assets; measured preview working set only |
| ReplicatedStorage.Remotes | Existing feature APIs; any delivery boundary explicitly versioned/validated |
| ServerStorage.Runtime / PlayerScripts.Runtime | Existing feature-owned lifecycle endpoints |
| Workspace.World | Scoped world; existing world/LOD owners retained |

Keep current feature names and Client/Server suffixes. Do not introduce a framework, parallel owner tree or generic service locator. Public definitions are generated projections of one authoritative authoring source, never a second manually edited catalogue. Server decisions use the authoritative definition, never a client-returned price/rating.

## Six proposed deliveries

### 1. Establish measurements and the exact move manifest

Read-only first: resolve every candidate's direct, transitive, dynamic-path, config, startup and tool consumers. String search alone misses ClientBase's long-bracket paths and cannot establish unused code. Capture authoring and runtime trees separately, including runtime clone counts and public payloads. Enumerate protected exceptions without deleting them.

Benchmark cold/warm join, first garage open, rapid catalogue browsing, paint/module changes, spawn/exit/re-entry, fast city lap, race start/finish/cancel and repeated transitions. Capture client/server frame times, join-to-interactive time, peak/settled memory, network traffic, instance/preview/VFX/connection counts and garbage-collection spikes. Use MicroProfiler and Developer Console; distinguish HTTP asset downloads from instance replication and remote traffic. Studio device emulation is not real phone memory evidence ([Roblox guidance](https://create.roblox.com/docs/performance-optimization/design), [network profiling](https://create.roblox.com/docs/performance-optimization/microprofiler/network)).

Select a real baseline phone, tablet and desktop; measure 1-player and representative 15-player load in an isolated test place. Record hardware, graphics, build, route, cache state, latency and sample count. Proposed targets: 60 FPS desktop and stable 30 FPS baseline mobile (16.7/33.3 ms frame budgets), subject to actual device selection. Set memory/join/network budgets from measured limits, not invented savings. Report medians and tail timings over repeated comparable runs. Done when the dependency ledger, baseline and ordered bottlenecks are reviewable; unavailable device evidence stays explicitly deferred.

### 2. Move proven server-only code and configuration

Strong inspected candidates: Modules.Game.Player.PlayerProfileSchema (9,745 source bytes), GarageProfileProjection (9,007), and Modules.Game.Vehicles.Performance.VehiclePerformance (2,053). Inspected callers are server-owned; verify complete reachability before moving to the same feature paths under ServerStorage.Modules. Total 20,805 source bytes is modest, not a claimed wire or memory saving. Keep PerformanceRuntime/Calculator/Resolver shared where clients actually calculate previews.

Review Config.Player.Persistence, Config.Racing.PersonalBests and Leaderboards as server-only candidates. Move only confirmed server-only records to ServerStorage.Config. Split mixed settings at field ownership, not by moving the whole Vehicles or Racing tree: DriveRewards has a telemetry client consumer, VehicleInteractions has FreeRoamParkedHoverClient, and race catalogues feed presentation. Keep author-friendly attributes for tuning. Retain opt-in development tools; Studio-only delivery can be considered only if bootstrap ordering is explicit and it removes a measured cost.

One installer updates all callers and the source of future objects, validates missing paths and startup, and removes old paths in the same delivery. No old-path fallback copies. Test profile startup/failure modes, spawn/performance equality, races, settings and dev-tool gates. Saved schema/keys and calculation outputs remain identical. Done when dependency/compile/runtime checks pass and the measured replication reduction is recorded.

### 3. Decouple public catalogue data from model hierarchy

GarageUI.cockpitImage, GarageModuleInstancePreviewAdapter.FindTemplate and VehiclePerformanceResolver.findTemplate currently scan category descendants. The resolver also reads attributes/upgrade children from templates; moving those models first would break ratings and previews.

Build a validated stable-ID index once per catalogue revision and reuse it across existing consumers. Project required names, image IDs, slots, defaults, public stats, materials and upgrade definitions into a compact read model. Keep full authoritative definitions server-side. Make existing pure performance calculation accept the same data on both sides, preserving exact outputs; do not fork a second calculator. Invalidate on deliberate authoring revisions, not each render. Reject duplicate IDs deterministically. Keep UI geometry/renderers and saved IDs unchanged.

Generate public data from canonical attributes so designers retain one edit location. Prefer a build/install projection when edits are static; runtime authoring refresh only if actually needed. Test every active cockpit/module/default combination, owned upgrades, costs, images, retired entries and preview transitions. Done when browsing/calculation no longer depends on the full physical catalogue and parity is proved. This phase can reduce repeated CPU work even before asset delivery changes.

### 4. Reduce vehicle-template replication

Use Phase 1 measurements and Phase 3 dependency separation to choose the least complex sufficient delivery. Recommended first option: canonical full templates in ServerStorage.Assets.Vehicles, with a generated, visually identical preview representation containing only documented client-needed geometry/hooks/metadata. No manual duplicate authoring and no mesh/part/art change. Compare its actual instance/asset cost: identical mesh IDs can still require the same graphics memory, and a near-identical copy may offer little gain.

If the catalogue still dominates memory/join cost, deliver only the currently needed preview bundles with a bounded cache. A globally shared ReplicatedStorage cache replicates to everyone, so it is not per-player delivery. Use a verified player-specific replication container suitable for the client preview consumer; prove isolation with two clients before activation. Do not use ServerStorage Instance references in remote replies: send stable IDs/status and wait for the corresponding authorised delivery. Do not serialize arbitrary Instance trees or allow arbitrary path requests.

Requirements for selective delivery: catalogue ID allowlist, entitlement where appropriate, rate/payload/concurrency limits, request generation and cancellation, bounded timeout, deduplicated in-flight work, bounded prefetch/eviction, removal on player leave and no stale selection promotion. Preserve the existing preview while its replacement loads; existing loading presentation handles first entry. No extra gameplay steps, new purchase authority, or legacy fallback implementation. PreviewVehicleClient remains preview owner; delivery owns only temporary template resources. Exact transport and cache caps must be designed from the measured bundle sizes before implementation.

Test rapid selection, back/close mid-load, packet delay, invalid/spammed IDs, respawn, player departure, two-client isolation and repeated browsing. Prove spawn output, attachments, paint and VFX remain identical. Revert the delivery if it merely trades join time for unacceptable first-open/selection delay. Done when join/memory improve meaningfully with bounded resource use and no observable gameplay regression. Physical template relocation needs explicit approval of its enumerated scope; current preservation rules do not authorise asset deletion.

### 5. Optimise measured runtime and network costs

Keep work inside existing owners. Profile GarageUI refresh/GetInitial payloads and repeated preview rebuilds; coalesce redundant renders and only rebuild when the relevant selection/profile fingerprint changes. Introduce narrower updates only if payload measurements justify them; preserve revision/authoritative state semantics.

Inspect active VehicleVFXClient/audio work, parked hover, driving raycasts, race presentation and LOD by profiler cost. Cache stable membership, skip inactive work and unchanged property writes, and release destroyed/streamed-out resources. GetDescendants at registration is not automatically a hotspot; RenderStepped driving/camera work may be necessary. Do not lower driving physics cadence or alter responsiveness as an optimisation shortcut.

Measure broadcast audience, message frequency and payload size. Target race/session updates to intended participants where semantics allow; coalesce cosmetic updates, not purchases/rewards. Keep rate limits, server authority, reliable critical transitions and profile ownership. Consider pooling only for measured frequent allocations with a strict reset contract; do not retain an unbounded pool. Done when the identified hotspot improves beyond measurement noise without shifting cost into another phase or leaking resources.

### 6. Validate world, devices and long sessions; lock budgets

Streaming is already enabled and LOD ownership was already improved. Verify high-speed traversal, race teleports, respawn, stream-out/re-entry and garage transitions before proposing radius/model changes. Workspace settings are global and may affect excluded WIP: any change beyond World requires explicit scope approval. Do not hide expensive content by moving WIP or authoring assets around without approval.

Within World, review measured lights/shadows, transparency, particles, acoustics, draw calls and distant presentation. First optimise scheduling/culling at identical output. Quality reductions, collision changes, art changes or new streaming pauses are separate proposals because they can change experience. Low-end visual budgets may be worthwhile later, but are not silently included in gameplay-preserving cleanup.

Run 20 repeated garage/spawn/race cycles and a 30-minute soak on representative devices with a 15-player target scenario. Warm caches may grow to a documented ceiling; live owners/instances/memory must then settle rather than grow per cycle. Verify touch/controller/desktop and camera stability, finish/cancel flows and streamed visuals. Persistence release still needs isolated published save/rejoin/contention tests; sandbox success is insufficient. Publish no production changes as part of this plan. Done when measurements, acceptance, remaining risks and current source/mirror baseline are handed off together.

## Delivery contract and workflow

High-Risk lane applies to this cross-system architecture programme, with proportional checks per delivery. Existing state owners remain: ProfileServer/EconomyServer for saved mutations, GarageUI and shared renderers for UI/geometry, PreviewVehicleClient for previews, DriveSessionClient for vehicle transitions, VehicleVFXClient for runtime attachment and LODClient/LODRuntime/LODPolicy for world presentation. ClientBase/ServerBase remain composition roots only.

Preserve driving equations, input/landscape orientation, visual appearance, audio/VFX, prices/rewards, saved IDs/schema, server authority and current World placement. Protected staging/Archive and WIP remain excluded. Public catalogue/delivery boundaries need explicit versions when introduced; private helpers do not. No persistence migration is planned. New delivery lifecycle: request → validated/deduplicated load → matching-generation ready → release/evict; cancellation/error must never activate an obsolete selection or mutate ownership.

For each approved delivery: complete exact manifest and relevant contract details, refresh/verify Edit baseline, one canonical installer with projected-source compile, transactional audit, repeat-install safety and repository-backed rollback. No in-game backups. Source replacement must be exact-baseline or structured; announce any fragile text-anchor dependency before writing it. Test static dependencies, normal startup and affected gameplay, refresh the full mirror, record measured results and request one user playthrough. Do not stack the next migration before confirmation or split an approved phase into extra user-run patches.

Add a small repeatable dependency/performance report to the repo when implementation begins: forbidden client→server paths, unresolved stable IDs, catalogue drift, active resource counts and measured budgets. CI can check local source/contracts; it cannot prove Roblox device performance. Keep one current runbook, a compact issue ledger and historical recovery outside the live game. Avoid a new framework, parallel Luau/ECS conversion, data-store renaming, bulk minification or blanket pooling without evidence.

**Recommended next action:** user gameplay confirmation of installed Phase 2, then approve delivery 3. Carry forward the explicit real-device/route/load measurement gaps; no FPS/memory gain has been established. Deliveries 3–4 hold the larger storage opportunity; their complexity is justified only by measured client cost. Delivery 5 targets frame-time/network bottlenecks, and delivery 6 is the acceptance gate. No manual installer run is needed.
