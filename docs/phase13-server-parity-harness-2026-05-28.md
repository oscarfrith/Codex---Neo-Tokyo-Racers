# Phase 13 Server Parity Harness

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Prepared  
**Studio script:** `scripts/roblox_hierarchy_phase13_server_parity_harness.lua`

## Goal

Phase 13 verifies that the live V56 server action layer still matches the Phase 12 snapshot before any real server service extraction.

This phase is still non-destructive. It is a safety gate.

## What The Script Checks

The server script checks:

- The current `HOVER_RACING_V2_Server` still contains the V56 begin/end markers.
- The current V56 block hash matches the Phase 12 snapshot hash.
- The Phase 12 snapshot module can be required.

Roblox does not allow a server command-bar script to read/call `RemoteFunction.OnServerInvoke`, so the `GetInitial` response-shape check is handled by a separate client command-bar script.

## What The Script Writes

The script writes a report to:

```text
ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports.Phase13_ServerParityHarnessReport
```

The optional client shape checker writes:

```text
ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports.Phase13B_ClientGetInitialShapeReport
```

## What It Does Not Change

The script does not:

- Edit or disable `HOVER_RACING_V2_Server`.
- Replace `GarageInvoke.OnServerInvoke`.
- Call purchase, upgrade, colour, spawn, exit, or re-enter actions.
- Change cash, vehicle ownership, spawned vehicles, UI, driving, VFX, mobile controls, LOD, lighting, traffic, or assets.

## How To Interpret The Report

Proceed only if:

```text
Hash matches snapshot: true
```

Then run `scripts/roblox_hierarchy_phase13b_client_getinitial_shape_check.lua` in Play mode, Client context, and proceed only if:

```text
Response shape passed: true
```

Stop if:

- The hash does not match.
- The V56 markers are missing.
- Phase 13B `GetInitial` fails or returns the wrong shape.

## Next Safe Step

If Phase 13 passes, the next server phase can create a shadow service implementation using the Phase 12 snapshot and extraction plan as the parity target.

Do not switch live `GarageInvoke` until the shadow service has matched current behaviour.

## Run Order

1. Rerun Phase 12 if the snapshot was generated before the comma fix.
2. Run Phase 13 in Play mode, Server context.
3. Run Phase 13B in Play mode, Client context.
4. Continue only if the hash matches and the client shape check passes.
