# Architecture Phase 5 — measured LOD work and project handoff

**Acceptance update 2026-09-05:** User confirmed this final phase worked well. The five-phase programme is complete. Subsequent legacy cleanup is tracked in [legacy-cleanup.md](legacy-cleanup.md); its mirror supersedes the historical evidence below. Restore that cleanup before older exact-baseline recovery. Published streaming, real persistence and target-device performance remain release gates.

2026-09-05. Phase 4 is user-confirmed. High-Risk lane: existing world visibility/collision lifecycle. Goal: finish the approved architecture programme without changing gameplay.

## Contract

- LODClient remains the sole city detail owner, started by ClientBase through the existing adapter. Extract a testable LODRuntime and pure LODPolicy. Reuse ConnectionScope for root subscriptions. No new UI, vehicle, audio, VFX, server or persistence owners.
- Preserve current live settings (older topic values are historical): update 0.5 seconds; near boundaries 200/800/1300/2450; far band 2450–5000 with 50 hysteresis; foliage 1275–2000. Preserve cumulative near-layer visibility, authored property restoration and existing collision/query/hover semantics. Settings become config attributes; no device-specific behaviour change or asset edits.
- Fix recursive missing-proxy lookup, support whole blocks and late LOD folders/parts entering/leaving the city, release instance references/subscriptions, cache supported objects and skip unchanged visibility writes. Keep far-proxy centers as scalar metadata when previously seen blocks stream out; retain no streamed-out part/model references. Proxy metadata is bounded by available authored templates; at most one clone per block, destroy clones outside their band.
- Missing roots/proxies degrade without hanging startup and retry at the existing update cadence. Destruction restores cached authored properties and releases subscriptions/clones. No remote or saved-schema changes; client presentation does not become server authority.
- One exact-source guarded installer with compile/audit/idempotency and transactional rollback. Canonical LOD implementation is replaced as a whole, rather than layering fragile repairs onto the old loop. Preserve the original source in the repo for reverse migration, not in Studio.
- Measure a deterministic transition trace against isolated clones of current city data, recording CPU and operation counts separately from real frame rate. Test thresholds, collision-property parity, late content, block removal/re-entry, missing/late proxies, cleanup and repeated lifecycle. Inspect fresh Play startup and diagnostics. Capture the final full mirror and write a company-facing architecture/workflow handoff.
- User driving/streaming playthrough remains acceptance. Low-end-device frame time/memory, published streaming traversal and Phase 2 real persistence tests remain release gates if unavailable here. No unsupported FPS claim. Other optimisation candidates require profiling evidence and remain recommendations.

## Scale and verification budget

Current Edit inventory: 84 authored block models and 84 proxy folders; many prototype block placeholders are empty. No physical cleanup is authorised. Steady LOD ticks should perform no hierarchy-wide scans and no writes when bands/content are unchanged. Cached instances must return to zero after destroy; repeated remove/re-add must not grow subscriptions or cached membership. Instrumentation is opt-in, aggregate and low frequency. Benchmark comparisons use the same trace/data and include cold registration separately.

## Installed evidence

Phase 5 is installed in Space Racers v1. Only the canonical LODClient was replaced; LODPolicy and LODRuntime were added, plus WorldLOD config attributes. Existing ClientBase registration/old-path adapter remain unchanged. All 335 other source/class/enabled records match the pre-phase mirror.

Eight isolated tests pass: exact bands/hysteresis, authored-property restoration, unchanged-tick work avoidance, late LOD content, missing/late proxy recovery, whole-block removal, twenty remove/re-add cycles and full destroy cleanup. The test harness awaits deferred hierarchy delivery by bounded predicates; one-frame timing was not reliable enough. Runtime reverse membership survives removed ancestry. No saved data is involved.

Exact-source audit, idempotent install and rollback/reinstall pass. All **338 sources compile**. Fresh sandbox Play showed **26 server entries ready**, **40 client entries ready** and **four development tools skipped**. The normal LOD owner reported 84 blocks, 6,260 cached supported objects and four root/proxy subscriptions. A late test block was hidden at distance, restored on removal and correctly rebound on re-entry; the disposable fixture was destroyed before Stop. A sampled live tick was 0.125 ms with a 2.43 ms observed maximum in that limited session; this is not a representative device-performance distribution.

## Controlled measurements

The benchmark clones the current authored city into isolated unparented fixtures, uses a seven-position trace, warms it once, then measures seven passes. It cleans all fixtures, including detached legacy far clones. Full values are in phase5-benchmark.json.

| Measurement | Prior LOD | Phase 5 |
|---|---:|---:|
| Registration | 13.50 ms | 15.14 ms |
| Seven-position trace median | 27.37 ms | 14.11 ms |
| Thirty unchanged ticks | 0.492 ms | 1.611 ms |
| Per unchanged tick | 0.016 ms | 0.054 ms |

Transition CPU decreased about **48%** in this trace. The additional registry/proxy lifecycle work adds about **1.64 ms at registration** and **0.037 ms per idle tick**, sampled at the unchanged 0.5-second cadence. The new runtime performed no additional scans, member visits or visibility writes across the thirty unchanged ticks. Proxy destruction outside the band releases retained Instances but trades for clone work on later re-entry. These are explicit tradeoffs, not universal performance wins or an FPS claim.

## Mirror and handoff

Full receiver/exporter mirror refreshed **2026-09-05 11:50:30**, 338 sources and 267,177 property values; integrity PASS. Existing 2,918 duplicate non-source path warnings remain. Neither mirror area appears stale. No authored assets/placement, streaming settings, server code, vehicle dynamics, UI, VFX or persistence data changed. Raw paste remained untouched. Build/verifier evidence lives in scripts/architecture_phase5/.

No manual script run is needed. Canonical recovery script: `scripts/roblox_architecture_phase5_world_optimisation.lua`. In Edit, AUDIT is read-only; ROLLBACK restores the exact Phase 4 LOD source and removes only the added helpers/config. Source drift and changed config block migration; restore default tuning or inspect before recovery. Then refresh the mirror. Older Phase 4 recovery will intentionally reject this phase's changed LOD source until Phase 5 is reversed.

The five-phase implementation programme is user-confirmed complete. Low-end phone/tablet frame time/memory, real published streaming traversal and real isolated-place save/rejoin/lease contention remain release gates. A pre-existing drive-in VehicleCamera log issue is recorded separately in current issues and the company handoff; it is not silently repaired in a world-LOD phase.

PASS: scoped ownership, exact migration/recovery, policy/collision-property parity tests, dynamic lifecycle/cleanup, controlled CPU measurement, normal-client smoke and mirror integrity. DEFERRED: user final playthrough and representative device/published release checks. N/A: new remotes, saved schema, rewards, economy, asset authoring and device-specific layouts. See [company-handoff.md](company-handoff.md) for architecture, MCP workflow and prioritised future work.
