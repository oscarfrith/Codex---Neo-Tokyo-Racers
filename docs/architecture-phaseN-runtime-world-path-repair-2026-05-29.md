# Architecture Phase N Runtime World Path Repair

Generated: 2026-05-29

## Purpose

Phase N repairs the remaining source references to the removed `Workspace.HOVER_RACING_V2_WORLD` root after the Phase M runtime probe found live code still reading old runtime paths.

It retargets runtime systems to:

```text
Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles
Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad
Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint
```

## Script

Run in Roblox Studio Command Bar, Edit mode:

```text
scripts/roblox_architecture_phaseN_runtime_world_path_repair.lua
```

## What It Changes

- Patches source objects that still contain `HOVER_RACING_V2_WORLD` or `PLAYER_VEHICLES_Runtime`.
- Rewrites `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Core.PathResolver` to expose the new runtime, garage preview pad, and vehicle spawn point paths.
- Creates `Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint` if it is missing, using the garage preview pad as a placement reference.
- Repairs stale `ObjectValue` references for live kit, vehicle categories, runtime vehicles, city root, remotes, theme, and spawn/preview references.
- Writes a report to `ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports.PhaseN_RuntimeWorldPathRepair`.

## Guard Rails

- Preflights all source changes first.
- Stops before changing anything if any source would still contain old runtime-world tokens after the planned patch.
- Does not delete gameplay objects.
- Does not touch `Workspace.Test + WIP Assets`.

## After Running

Paste the Phase N output back into Codex.

If the final source audit shows `0` old runtime hits, rerun:

```text
scripts/roblox_cleanup_phaseM_post_kit_migration_audit.lua
```

The updated Phase M audit now expects the new `NeoTokyoRacersWorld` runtime paths instead of the removed `HOVER_RACING_V2_WORLD` root.

## Confirmed Studio Run

Phase N completed successfully on 2026-05-29 at 18:36:09:

- Preflight patchable source objects: `10`
- Source objects patched: `10`
- Text replacements applied: `24`
- `VehicleSpawnPoint` created: `true`
- ObjectValues repaired: `8`
- Final old runtime source hits: `0`

The repaired ObjectValues now point at the `NeoTokyoRacers` / `NeoTokyoRacersWorld` targets instead of old kit/world names.
