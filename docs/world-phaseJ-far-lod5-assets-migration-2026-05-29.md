# World Phase J Far LOD5 Assets Migration

**Created / first designed:** 2026-05-29  
**Last updated:** 2026-05-29  
**Current status:** Script ready / needs Studio run and play-test  
**Relevant script:** `scripts/roblox_world_phaseJ_far_lod5_assets_migration.lua`

## What This Phase Does

World Phase J moves the old far proxy folder:

```text
ReplicatedStorage.FarLOD5
```

into the new world asset hierarchy:

```text
ReplicatedStorage
+-- NeoTokyoRacers
    +-- Assets
        +-- World
            +-- FarLOD5Proxies
```

The new name is `FarLOD5Proxies` because the folder is intended to store distant world proxy assets, not live city blocks.

## LOD Script Change

The active LOD client should resolve the new path first:

```text
ReplicatedStorage.NeoTokyoRacers.Assets.World.FarLOD5Proxies
```

It keeps a fallback to:

```text
ReplicatedStorage.FarLOD5
```

This fallback is only for compatibility during migration. Future scripts should use the new path.

## Protected Systems

This phase does not touch:

- `Workspace.NeoTokyoRacersWorld.City`
- city block models
- `ReplicatedStorage.HOVER_RACING_V2_KIT`
- vehicle systems
- UI systems
- VFX systems
- server garage/action systems
- mobile controls
- lighting
- traffic
- `Workspace.Test + WIP Assets`

## Required Test

After running the script:

1. Start a fresh Play test.
2. Confirm Output still shows `LOD Script Running`.
3. Confirm Output still shows the expected registered block count.
4. Drive through the city and watch near/mid/far LOD behaviour.
5. Confirm there are no errors from `LODClient_Active`.

## Codex Safety Notes

Do not delete `FarLOD5Proxies` even if it currently contains placeholder or empty proxy folders. It is the intended future location for far world proxy assets.

Do not move city block models into `ReplicatedStorage`. Live city blocks belong under `Workspace.NeoTokyoRacersWorld.City`.
