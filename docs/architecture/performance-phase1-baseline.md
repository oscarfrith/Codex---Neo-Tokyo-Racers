# Performance Phase 1 — dependency audit and initial baseline

2026-09-22. **Available local audit delivered; representative benchmark coverage remains partial.** Phase 1 was approved; Phase 2 has not been installed. The user selected **iPhone 7** as the baseline phone. No tablet target selected. The authored game remains the user-confirmed cleanup Phase 4 baseline.

## Contract and boundaries

This is read-only investigation within the High-Risk architecture programme. Outputs are repository reports and non-installed diagnostic scripts. Preserve every gameplay owner, path, setting, physical object, saved schema and runtime implementation. No migration, asset deletion, camera fix, production publish or saved-data mutation. Studio Play uses the existing vehicle sandbox; ProfileServer's no-save branch was inspected before starting. Normal public GetInitial requests can reconcile transient sandbox state; no arbitrary gameplay module was required through MCP.

Done locally: verified source integrity, inventoried 160 sources and 50 immediate feature config groups, reviewed six exact move candidates and their dependencies, captured bounded client/server runtime windows and five public catalogue response samples, then stopped Play and refreshed/verified the Edit mirror. No claim of full device/load/route acceptance. These gaps do not prevent preparing the small server-only move, but block claims of performance improvement and the larger template-delivery decision.

## Exact proposed Phase 2 manifest

All paths below currently start in ReplicatedStorage. Their destination keeps the same suffix under ServerStorage. No old-path copy or forwarding adapter is proposed.

| Suffix | Instances including root | Current callers to update |
|---|---:|---|
| Modules.Game.Player.PlayerProfileSchema | 1 | ProfileServer, ProfileCompatibilityServer |
| Modules.Game.Player.GarageProfileProjection | 1 | ProfileCompatibilityServer |
| Modules.Game.Vehicles.Performance.VehiclePerformance | 1 | VehiclePerformanceServer |
| Config.Player.Persistence | 1 | ProfileServer, GarageServer |
| Config.Racing.PersonalBests | 4 | PersonalBestServer |
| Config.Racing.Leaderboards | 6 | GlobalLeaderboardServer |

Total: **14 existing instances and 20,805 source bytes** removed from ReplicatedStorage if Phase 2 is approved and its live preflight passes. Source bytes are not download bytes or measured memory savings. Destination container folders may need creation on the server. Do not remove otherwise empty parents until their separate contracts are checked.

All six named callers are already ServerStorage modules. PlayerProfileSchema still requires the shared VehicleCosmeticCatalog, which depends on client-used cosmetic definitions; keep that dependency replicated. GarageProfileProjection receives the schema through its existing API; it does not become a profile owner. VehiclePerformance depends on shared PerformanceRuntime, whose Definitions/Calculator/UpgradeRuntime/Dynamics dependencies remain shared with preview consumers. Move the writer, not the entire performance package. Profile schema, prices, upgrade math, saved IDs and settings values must remain byte/semantically identical.

The report follows resolved navigation and absolute startup literals, including long-bracket ClientBase paths, and provides conservative module edges and transitive client reachability. This is not a complete Luau compiler: dynamic aliases/reflection need manual review. Candidate callers, module requires, ClientBase/ClientLifecycle and PathResolver were inspected. Current cleanup audits do not hardcode these six old paths. Historical exact-baseline installers remain historical and must not be automatically rerun after a future move.

## Keep / split / investigate

- **Keep replicated:** client modules, shared performance maths, remotes, client UI/audio/VFX/sky definitions and current preview templates until their consumers change.
- **Split only after field review:** DriveRewards is read by development telemetry; VehicleInteractions by parked hover; race catalogues by client presentation. Server-related names do not establish server-only usage.
- **Catalogue separation:** GarageUI.cockpitImage, GarageModuleInstancePreviewAdapter.FindTemplate and VehiclePerformanceResolver.findTemplate walk category descendants. Indexing is a concrete opportunity; frequency/cost still needs profiler attribution. PreviewVehicleClient also needs physical models and attachment hooks.
- **Stale authoring notes:** Config.Vehicles.Performance has IntegrationNote/TuningNote text referring to deferred/legacy rollback despite live flags; Config.Player.Persistence.EditNote describes a pre-live foundation despite enabled persistence. Treat these as documentation metadata to reconcile in an approved cleanup, never delete active flags on the strength of a stale note.
- **Protected:** staging/Archive and WIP remain unchanged. Physical archive deletion would not reduce current direct client replication. Development tools remain opt-in and retained.

## Observed local baseline

Hardware: Intel Core i7-13700K, NVIDIA GeForce RTX 3080. Studio engine 0.739.259.7390001; one local player; viewport approximately 2107 × 1152. Graphics quality and foreground/focus were not controlled. The first windows are settled startup presentation, not measured cold join. The dealership sample used the normal OpenGarageFromIntro bindable; it is not an end-to-end player-input benchmark.

| Eight-second observation | Samples | Interval p50 / p95 / p99 (ms) | Maximum (ms) |
|---|---:|---|---:|
| Client settled startup 1 | 481 | 16.70 / 17.83 / 18.23 | 18.82 |
| Client settled startup 2 | 481 | 16.71 / 17.51 / 17.87 | 18.13 |
| Server settled idle | 482 | 16.97 / 17.96 / 18.06 | 25.96 |
| Client dealership open | 481 | 16.68 / 19.26 / 20.38 | 20.63 |

Intervals are RenderStepped/Heartbeat intervals, not script CPU cost. All sampled windows had zero intervals over 33.33 ms; this does not establish phone FPS, race performance, tail stability across sessions or headroom at 15 players. Client startup: 39 ready, four tools skipped. Server startup: 26 ready. Sandbox active.

Client ReplicatedStorage had 4,325 descendants in Play versus 4,323 authored; runtime object creation must be considered separately. PlayerGui grew 1,140 → 1,340 and Workspace 25,077 → 25,390 after dealership entry. That is a state difference, not proof of a leak. Repeated exit/re-entry growth has not been measured.

Studio reported roughly 2,983–2,990 MB total memory across the captures. These readings include Studio/editor/process effects and cannot be treated as isolated client memory or an iPhone budget. Per-tag readings are retained raw; do not sum overlapping categories. gcinfo describes the diagnostic VM, not all game Lua ownership. Stats receive/send endpoints are instantaneous and do not measure join transfer or per-remote traffic.

Five sequential normal GetInitial requests succeeded, with round trips **49.81–67.66 ms**, median **51.41 ms**. Each JSON-encoded result was **177,251 bytes**, comprising **173,361 catalogue bytes** and **3,852 profile bytes**, plus envelope. The catalogue is about **97.8%** of the encoded response. These are JSON proxies, not Roblox wire encoding or pure server computation time. No profile contents were written to evidence. Candidate optimisation: cache a versioned immutable catalogue and send profile/state updates separately, after reviewing actual refresh frequency and invalidation requirements. Preserve one server authority.

## Ordered opportunities, not invented bottleneck attribution

1. Low-risk organisational win: the six server-only moves above. Savings are modest and unmeasured.
2. Measured repeated data volume: catalogue reuse/separation. Check public response frequency and server catalogue construction cost before narrowing APIs.
3. Structural replication opportunity: 2,437 authored vehicle asset descendants. Public definitions and previews must be separated before moving templates.
4. Potential CPU allocation cost: repeated catalogue scans and preview reconstruction. Profile before introducing caching/pooling changes.
5. World/VFX/audio/physics costs remain unranked without representative driving/race traces. Do not infer the dominant bottleneck from idle frame intervals.

## Outstanding measurement matrix

| Scenario/evidence | Status / next action |
|---|---|
| Authored inventory, static candidate callers and normal startup | Captured locally |
| Settled startup/server/dealership windows | Captured, limited Studio evidence |
| Catalogue response size/round trip | Captured; real wire cost still pending |
| Cold/warm join to interactive | Pending controlled client launches and cache-state log |
| Rapid browsing, paint/module changes, spawn/exit/re-entry cycles | Pending timed normal-input route; earlier gameplay acceptance is not profiling |
| Fast World lap and race start/finish/cancel | Pending representative route plus MicroProfiler/network capture |
| iPhone 7 | Selected, not measured; record installed iOS/Roblox, quality, thermal state and network |
| Tablet | No target selected; no fabricated result |
| 15-player isolated test place | Pending environment and representative players; single Studio player is not equivalent |
| Resource/connection growth and 30-minute soak | Pending; no read-only API enumerates all game RBXScriptConnections |

Use the same route/build/settings, at least three comparable cold/warm runs, and frame-time distributions rather than average FPS alone. Target stable 30 FPS on iPhone 7; memory cap and join-time budget remain unset until actual device evidence. Record disconnect/crash, pop-in, input and camera failures alongside timing. The current [Roblox mobile requirements](https://en.help.roblox.com/hc/en-us/articles/203625474-Roblox-Mobile-System-Requirements) list iOS 14+ and devices starting at iPhone 6s; OS eligibility does not prove this game runs well on iPhone 7.

## Reproduction, verification and handoff

- Local report: run `py scripts/performance_phase1/inventory.py` (or a discovered Python 3). It reads the mirror and writes dependency-report.json only. It validates all source SHA-256 values before analysis.
- Studio observation: `scripts/performance_phase1/runtime_sample.lua` in Play Client or Server, eight seconds per call. No installation; bounded waits, no persistent hooks or game module requires. Snapshot scans run outside the timed interval.
- Optional payload reproduction: `scripts/performance_phase1/payload_sample.lua` in Studio Client with the existing vehicle sandbox active. It makes five normal GetInitial requests; no source edits. Do not paste these scripts into permanent game objects.
- MCP already ran the observations; **no manual Studio script is required now**. No new gameplay test is claimed or necessary to accept an unchanged authored game.
- Final Edit export **2026-09-22 11:13:49**: 160 sources, 42,351 nodes, 267,539 captured properties. Mirror integrity and exact cleanup Phase 4 parity pass, zero unexplained changes. Duplicate non-source paths remain a known audit warning. Raw export paste untouched.
- Evidence: scripts/performance_phase1/dependency-report.json and runtime-baseline.json. Sampler results are descriptive, not pass/fail performance acceptance. Authored source/hierarchy unchanged; rollback requires no Studio action. Revert repository diagnostics/docs if unwanted, keeping the confirmed game baseline.

Next decision: approve Phase 2's six exact moves. Phase 1's unavailable real-device/load measurements stay open; do not silently mark them passed when advancing small server-only organisation work.
