# World Phase F - City Hierarchy And LOD Root Migration

**Created:** 2026-05-29  
**Current status:** Ready to run / hierarchy migration  
**Studio script:** `scripts/roblox_world_phaseF_city_hierarchy_lod_migration.lua`

## Goal

Move generated city blocks into the new world architecture:

```text
Workspace
└── NeoTokyoRacersWorld
    └── City
        └── Block S1
            └── Block_S1_R1_B1
```

Blocks are grouped by their segment name:

```text
Block_S1_R1_B1 -> Workspace.NeoTokyoRacersWorld.City["Block S1"].Block_S1_R1_B1
Block_S2_R3_B4 -> Workspace.NeoTokyoRacersWorld.City["Block S2"].Block_S2_R3_B4
```

## What The Script Does

- Creates `Workspace.NeoTokyoRacersWorld`.
- Creates `Workspace.NeoTokyoRacersWorld.City`.
- Finds block models named like `Block_S#_R#_B#` under `Workspace.GeneratedCityBlocks`.
- Moves each block into the matching `Block S#` folder.
- Patches the active LOD client so it resolves the City root first:

```lua
Workspace.NeoTokyoRacersWorld.City
```

- Keeps fallback support for:

```lua
Workspace.GeneratedCityBlocks
```

## LOD Scripts Patched

The script attempts to patch:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active
StarterPlayer.StarterPlayerScripts.LOD System
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Shadow
```

Only scripts with the exact old root line are patched:

```lua
local ROOT = workspace:WaitForChild("GeneratedCityBlocks")
```

## What It Does Not Do

The script does not:

- Delete `GeneratedCityBlocks`.
- Delete blocks.
- Clone blocks.
- Rename blocks.
- Touch vehicle, UI, VFX, garage, mobile controls, server actions, lighting, traffic, race, or `Test + WIP Assets`.

## Required Test

After running in Edit mode:

1. Start a fresh Play test.
2. Confirm Output still shows:

```text
LOD Script Running
```

3. Confirm Output shows the expected registered block count.
4. Drive or teleport around the city.
5. Check near blocks, LOD4 foliage, and FarLOD5 proxies.

If registered block count is `0`, check that the hierarchy is:

```text
Workspace.NeoTokyoRacersWorld.City.Block S#.Block_S#_R#_B#
```

## Rollback

Rollback can be done manually if needed:

1. Move block models back under `Workspace.GeneratedCityBlocks`.
2. Re-run the old LOD script or revert the place version in Roblox Studio.

Because the patched LOD client keeps a fallback to `GeneratedCityBlocks`, the hierarchy change should be safe as long as blocks exist under either root.

## Codex Safety Notes

- Do not remove `GeneratedCityBlocks` yet.
- Do not delete disabled LOD rollback scripts.
- Treat future city systems as children of `Workspace.NeoTokyoRacersWorld`.
- Keep LOD root resolution tolerant while the world hierarchy is still evolving.
