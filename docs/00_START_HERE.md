# Space Racers / Neo Tokyo Racers — current baseline

Updated 2026-09-05. Active place: **Space Racers v1**, `121304917315753`.

## Current task

**Laptop continuation:** Read [the transfer handoff](architecture/laptop-handoff-2026-09-05.md). Phase 3 is confirmed; next is complete-cleanup Phase 4. Verify the laptop checkout and live place before writes.

**Current programme:** Complete cleanup Phases 1, 2 and 3 are installed and user-confirmed. Phase 4 remains unimplemented. Current mirror: 2026-09-05 16:06:57, 160 sources, 42,285 nodes and 266,840 properties, with exact expected source/hierarchy/property parity. The two lighting-tag renames on 62 enumerated WIP objects are approved and installed. Protected staging/archive disposition remains pending. See docs/architecture/cleanup-phase3-generic-naming.md.

The user confirmed all five original architecture phases and complete-cleanup Phases 1, 2 and 3. The [Phase 3 handoff](architecture/cleanup-phase3-generic-naming.md) describes the installed baseline; Phase 3 is the confirmed baseline for laptop continuation. Opt-in tools stay. Target-device and published persistence release gates remain distinct from phase acceptance.

Read [Phase 1 contract](architecture/phase1-foundation.md), [naming and owners](architecture/naming-and-owners.md), [MCP workflow](architecture/mcp-workflow.md) and [canonical tool index](architecture/installer-index.md). Verification results are in [Phase 1 evidence](architecture/phase1-verification.json).

## Baseline by subsystem

| Subsystem | Installed evidence / confirmation |
|---|---|
| Whole source mirror | Phase 3: 160 sources, refreshed 2026-09-05 16:06:57; all expected source/hierarchy/property records match. Physical properties preserved; only approved WIP lighting tags changed. Startup: 26 server/39 client ready, four development tools skipped. |
| Driving | Steering V1.2 is present in live source. Exact user runtime acceptance still needs reconciliation; preserve it for testing. V74/V75 are historical, not the current complete baseline. |
| Paint Shop | Icon/price-text V1 user-approved in the 2026-08-02 handoff. |
| Free-roam map | V1.1 user-confirmed, including shared player markers and subpixel pan. |
| Showroom Loop | V1.1 user-confirmed: 17 checkpoints plus finish, six grid positions. |
| Owned-garage touch | V2.2 user-confirmed; preserve the existing geometry/input owners. |
| Garage/customisation/audio | Latest July handoffs remain behavioural reference. Canonical implementations live in ReplicatedStorage.Modules.Game; forwarding adapters are removed. GarageUI starts directly; DriveSessionClient owns vehicle session callbacks. |
| Studio iteration | Replay=true and VehicleSandbox=true. The sandbox suppresses saves; this is not a persistence verification session. |
| Device contract | StarterGui.ScreenOrientation=LandscapeSensor; no portrait layouts/runtime orientation writers. |

Generated, installed, runtime verified and user confirmed are distinct states. Source parity does not prove gameplay acceptance. Old Services/client adapter trees and GarageClient are removed. GarageServer, GarageUI and DriveSessionClient are current owners; use the Phase 2 maps and actual exported manifest.

## Startup route

1. Read AGENTS.md, this page and the current issues page.
2. Read the relevant topic and naming/owner map; inspect recent patch history when needed.
3. Inspect Git status, the mirror and the affected live Studio datamodel through MCP.
4. Follow the approved phase scope and canonical implementation. Run the exact repo script through MCP and retain verification evidence.

Historical context is preserved in [prior startup notes](history/start-here-through-2026-08-02.md) and docs/07_patch_history.md. Older “run this next” wording is historical, not an instruction to reinstall.

Phase 5 was applied through MCP using `scripts/roblox_architecture_phase5_world_optimisation.lua`; no manual installation is needed. Test a fresh city drive, return over the same route, distant buildings/foliage, owned-garage entry/exit and a race/TT; repeat on landscape touch where available. Eight isolated checks, normal-client dynamic block lifecycle, 338-source compilation and reversible migration passed. All 335 out-of-scope sources retain exact source/class/enabled parity. The controlled LOD transition benchmark improved, but low-end-device FPS/streaming and real isolated-place save/rejoin remain release checks.
