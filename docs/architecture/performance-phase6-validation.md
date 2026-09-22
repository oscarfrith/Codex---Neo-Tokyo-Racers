# Performance Phase 6 — validation in progress

Status: Studio API checks completed; overall acceptance remains OPEN. Phase 5 is accepted for continuation, not a claim of a particular user/device playtest. No gameplay source, asset, configuration, physical placement or persistence schema was changed.

## Evidence collected on 2026-09-22

Space Racers v1 (121304917315753), engine 0.739.259.7390001, one Studio player, no-save vehicle sandbox. Source audit matched installed Phase 5 before Play. Normal startup: 26 server features and 39 client features ready; four opt-in development features skipped.

Bought one sandbox bruiser, then ran four bounded batches of five API cycles: GetInitial → SpawnVehicle → ExitVehicle → ReEnterVehicle → StartTimeTrial → CancelTimeTrial → DespawnVehicle. All 140 responses succeeded. These were short staging/cancellation tests, not driven races, race finishes or complete garage UI cycles. No live vehicles remained at the server endpoint afterward.

Important limitation: StartScreenActive remained true in all four batch snapshots, even after an attempted Play-button click. The harness exercised existing APIs behind the start-screen state. This must NOT count as the plan's 20 normal player-flow cycles, streaming traversal, camera/visual acceptance or driving input coverage. The helper does not require gameplay modules or install game instances.

At the end of each five-cycle batch, client Workspace descendants were 25,290 and PlayerGui descendants 1,141, unchanged across those four checkpoints. PlayerScripts stayed 75 and ReplicatedStorage 3,983 across idle/settled samples. Flat parented counts do not prove that connections or detached resources are bounded.

| Eight-second sample | Frame interval p50 | p95 | p99 | Intervals >33.3 ms |
|---|---:|---:|---:|---:|
| Initial idle | 16.66 ms | 17.56 ms | 17.98 ms | 0 |
| Settled after API cycles | 16.67 ms | 17.59 ms | 18.35 ms | 0 |

These are Studio render intervals, not script CPU measurements, controlled benchmarks, driven-route FPS, wire savings or phone memory. Total Stats memory includes Studio overhead and is unsuitable for an iPhone budget. No 30-minute soak was completed.

One initial viewpoint reported 417 draws / 414,281 triangles including shadows; 393 draws / 386,674 triangles excluding shadows. This is neither a World-only attribution nor a worst-case route measurement. No visual quality or geometry changes are justified by this single sample.

## Findings requiring follow-up

1. **CAM-02 reproduced:** PlayerModule BaseCamera:594 and ZoomController:88 report invalid clamp bounds during transitions. A successful remote response does not establish correct presentation. Root cause remains unproven; do not change the native camera or driving tuning speculatively. Isolate the game's camera handoff/zoom writers in a normal player flow before another meaningful performance comparison.
2. **PERF-06-A, detached UI references:** SceneAnalysisService reported 12 unparented instances initially (native/freecam/character owners), then 123 after cycles. The added 111 TextButtons are attributed to PresentationAudioClient. Its reported script heap rose from 114,844 to 197,340 bytes. The source already uses weak keys and a Destroying cleanup handler; this observation alone does not prove a persistent leak or establish which UI producer detached the buttons. Reproduce in a fresh normal UI session, sample after quiescence and across multiple equal batches, trace the producer/removal path and garbage-collection timing. If retention persists, repair the existing binding/producer lifecycle; do not introduce another audio or UI owner.
3. The user confirms neither an iPhone 7 nor an isolated published multiplayer test place is currently available. Real-device, 15-player and persistence release evidence remains unavailable.

## Remaining acceptance matrix

| Gate | Current status / required evidence |
|---|---|
| Source, hierarchy, catalogue freshness | PASS; full refreshed mirror matches Phase 5 exactly |
| Normal startup / API lifecycle | PASS with the scope limits above |
| Camera stability | OPEN; CAM-02 reproduced |
| Resource plateau | OPEN; investigate 111 detached buttons; no connection-bound claim |
| 20 normal garage/spawn/race cycles | Pending; start through the actual Play UI, enter/exit garage, browse/paint/modules, drive, stage/cancel and finish races |
| High-speed World streaming | Pending; drive fixed route, stream out/re-enter, teleport to race, respawn, check missing visuals/collisions/attachments |
| Desktop/controller/touch | Pending actual input and visual checks; simulator is layout evidence only |
| iPhone 7 | Unavailable; record OS, Roblox build, graphics, thermal/battery state, route and cold/warm cache |
| 15-player / 30-minute soak | Unavailable; isolated test place, representative active players, same repeated route and transitions |
| Published save/rejoin/contention | Separate release gate; Studio no-save testing cannot validate this |

Retain provisional targets from the approved plan: 60 FPS desktop and stable 30 FPS baseline mobile. Do not lock memory/join/network budgets until matched real-device/load measurements exist. For each run record build, hardware, graphics, route, sample count, latency, frame p50/p95/p99, startup/first-garage latency, memory settled/peak, instance/preview/vehicle counts and console errors. Compare identical checkpoints after warm-up and at five-cycle intervals; investigate continued per-cycle growth rather than attributing cache warm-up to a leak.

## Files and handoff

Evidence: scripts/performance_phase6/*.json (raw MCP results), api_cycles.lua (five-cycle Studio Client smoke helper). It requires the current place and an active no-save sandbox with an already owned vehicle; stop on any failed action. It is not an installer or the full acceptance test. Existing read-only sampler: scripts/performance_phase1/runtime_sample.lua.

No Studio installer to run. Do not rerun Phases 1–5. The refreshed Edit mirror at **2026-09-22 13:14:39** has **165 sources, 44,465 nodes and 276,087 properties**, zero source/hierarchy/property differences from expected Phase 5, and fresh public catalogue/preview projections. Play is stopped. Raw paste export was untouched. No production publish, physical edit, save migration or in-game backup. No gameplay rollback is needed.

Next work within the acceptance effort: establish the normal start/UI reproduction, investigate camera and detached-button lifecycle, then repeat the affected acceptance checks. Keep fixes narrowly scoped and independently evidenced; do not declare Phase 6 complete or add another architecture migration while these gates remain open.

Workflow lesson: always establish a normal interactive start state before counting player-flow cycles; successful remote calls and flat parented instance counts are insufficient for visual or resource-lifecycle acceptance. Scene memory queries complement, rather than replace, live route/device testing.
