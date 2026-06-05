# Open World LOD / Far Proxy System

**Created / first designed:** Before 2026-04-29  
**Last updated:** 2026-05-29  
**Current status:** Implemented / City root migrated / Far LOD5 asset migration prepared  
**Relevant docs file:** `docs/world-streaming-and-lod.md`  
**Relevant files to edit:** LOD scripts, LOD folders, foliage proxy setup only. Do not edit vehicle or lighting files unless specifically requested.

## What The System Does

The LOD system manages world detail based on player/camera distance. It is intended to keep the large open-world city performant, especially on mobile, by reducing distant detail and using far LOD proxies.

The system includes support for:

- City block LODs
- Far LOD5 proxies
- Foliage LOD behaviour
- Distance-based visibility
- Hysteresis to reduce flickering around thresholds

## Current Folder / Script Names

Known folders / objects:

```text
Workspace
- NeoTokyoRacersWorld
  - City
    - Block S#
      - Block_S#_R#_B#

Workspace
- GeneratedCityBlocks (legacy fallback root; do not delete yet)

ReplicatedStorage
- NeoTokyoRacers
  - Assets
    - World
      - FarLOD5Proxies

ReplicatedStorage
- FarLOD5 (legacy fallback only after Phase J)
```

Known script output/name:

```lua
print("LOD Script Running")
```

Current active script:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active
```

The LOD client should resolve `Workspace.NeoTokyoRacersWorld.City` first, with fallback to `Workspace.GeneratedCityBlocks`.

For far proxies, the LOD client should resolve `ReplicatedStorage.NeoTokyoRacers.Assets.World.FarLOD5Proxies` first, with fallback to `ReplicatedStorage.FarLOD5`.

Known config values from the current LOD script as of 2026-04-29:

```lua
local UPDATE_RATE = 0.2
local DEBUG_PRINTS = false

local DIST = {
    LOD1 = 200,
    LOD2 = 500,
    LOD3 = 1000,
    LOD4 = 1950,
    LOD5 = 5000,
}

local HYSTERESIS = 50
local FAR_LOD5_START = 1950
local FAR_LOD5_END = 5000

local LOD4_FOLIAGE_MIN = 975
```

Known special foliage folder:

```text
LOD4_Foliage
```

Previously discussed foliage types:

- Maple trees
- Bamboo trees

## Important Attributes / Settings

Important settings:

```lua
UPDATE_RATE = 0.2
DEBUG_PRINTS = false
LOD1 = 200
LOD2 = 500
LOD3 = 1000
LOD4 = 1950
LOD5 = 5000
HYSTERESIS = 50
FAR_LOD5_START = 1950
FAR_LOD5_END = 5000
LOD4_FOLIAGE_MIN = 975
```

Design rules:

- Distant detail should not be fully rendered if it is not needed.
- LOD transitions should avoid obvious popping where possible.
- Hysteresis helps stop objects constantly toggling at exact distance thresholds.
- Debug prints should stay disabled for normal play.
- Changing distance values has minimal direct performance cost; the main cost is what becomes visible/invisible.

## Current Known Issues

- Previous issue reported on 2026-04-29: `LOD4` trees were going invisible when close but not visible when far away.
- Need to verify that LOD visibility logic is correctly inverted for each LOD band.
- Need to confirm bamboo foliage duplication into `LOD4_Foliage`.
- Need to confirm whether cloned LOD foliage remains correctly organised and does not duplicate repeatedly.
- Need to check whether StreamingEnabled affects access to far objects or folders.

## Confirmed Working

- The project already has an LOD system.
- `GeneratedCityBlocks` is the known root folder for city blocks.
- `FarLOD5` originally existed in `ReplicatedStorage`; Phase J prepares migration to `ReplicatedStorage.NeoTokyoRacers.Assets.World.FarLOD5Proxies`.
- Distance-based LOD logic exists.
- Hysteresis and update-rate settings exist.
- Foliage LOD4 workflow has been designed for multiple tree types.

## Still Needs Testing

- Published client test with StreamingEnabled.
- Mobile performance test.
- First-pass driving through the city versus second-pass cached behaviour.
- MicroProfiler check for streaming/loading spikes.
- Draw call spikes while rotating camera or driving forward.
- Whether LOD4 foliage appears only at intended distances.
- Whether LOD5 far proxies appear and disappear correctly.
- Whether LOD scripts handle missing streamed-out instances safely.
- Whether clones are created once only and not repeatedly.

## Codex Safety Notes

- Do not edit vehicle, lighting, UI, or race files while fixing LOD unless explicitly requested.
- Any repeated clone logic should be checked for duplicate creation over time.
- Keep `DEBUG_PRINTS` disabled for normal play unless diagnosing a specific issue.
