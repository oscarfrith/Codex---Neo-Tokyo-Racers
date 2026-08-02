# Open World LOD / Far Proxy System

**Created / first designed:** Before 2026-04-29  
**Last updated:** 2026-07-02
**Current status:** Implemented / City root migrated / Far LOD5 asset migration prepared / private garage interior/display/visit MVP confirmed / garage surface-decor service confirmed
**Relevant docs file:** `docs/world-streaming-and-lod.md`  
**Relevant files to edit:** LOD scripts, LOD folders, foliage proxy setup only. Do not edit vehicle or lighting files unless specifically requested.

## 2026-08-02 Gamefam Submission Playable District

The approved prototype presentation uses the approximately 20 completed city blocks as an intentional accessible district. Clean distant blockouts may remain as skyline and scale context, while visibly unfinished or messy regions are closed with readable authored barriers rather than unexplained invisible walls. Wider-city source geometry is preserved for post-submission production.

This decision does not change the current streaming or LOD owners. During the manual Studio presentation pass, verify that inaccessible WIP content does not impose material low-end-mobile cost, that boundary approaches stream reliably at driving speed, and that both current integrated routes and the complete new-player loop remain inside the controlled district. Refresh the full mirror after any boundary, asset, prompt, marker, hierarchy or placement change. The complete contract is in `docs/gamefam-submission-map-scope-handoff-2026-08-02.md`.

## 2026-07-19 Owned Garage Replacement Planning

The current Phase 21-27 physical garage MVP is approved for clean replacement. Phases 0-5 passed and are mirrored at `2026-07-19 12:14:59`. `StarterTwoBay` stays in ServerStorage and the explicit-pool interior runtime creates nothing in Workspace until Phase 6 starts its single lifecycle owner. Phase 4 adds persistent catalogue styles only to parts carrying a template `SurfaceGroup`. Phase 5 makes the existing desktop/mobile HUD owners skip minimap visibility and map-coordinate work while `NTR_OwnedGarageInside` is true; it adds no map or frame-loop owner. Phase 6 is prepared to retire the old physical-garage services/prompt, clone only occupied canonical interiors into `OwnedGarageInstances`, and unload after exit, death/reset or disconnect. The configurable grid begins at `Y=3200`, safely away from the city and below-map destruction boundaries. Display vehicles remain anchored, non-drivable, collision/query/shadow-free and VFX-free.

## 2026-07-22 Owned Garage Streaming Stabilisation

The Phase 13 V1.2 submission stabilisation replaces the unsafe reliance on automatic character streaming. Before any foot/vehicle entry or exit mutation, the current server owner issues a same-player GUID token and authoritative destination; the current browser owner calls `LocalPlayer:RequestStreamAroundAsync`, waits for the named runtime interior/exterior marker and acknowledges readiness over the existing owned-garage event. The current shared loading presentation remains visible until the server operation returns. Timeout is bounded and fails before teleport, vehicle despawn, display clear or vehicle spawn.

`Templates.StarterTwoBay.CollisionShell` is separate from streamed cosmetic structure. Visual structure remains collision-free; the protected invisible shell owns stable navigation collision and cannot be hidden by a finish/decoration swap. City LOD pause remains profiling-gated for submission: measure on a low-memory phone during repeated garage transitions and add a pause only if the current 0.2-second city LOD work is materially active/costly while `NTR_OwnedGarageInside=true`.

The 2026-07-23 ClearNight V1 Play fault did not invalidate this handshake. A client-side Lighting/Sky event feedback loop saturated the same client that must acknowledge `OwnedGarageStreamRequest`, so the server correctly timed out before exterior mutation. V1.1 removes that loop. Drive-out now adds a second bounded completion gate after streaming and spawn: exterior seating and position must verify before the session is released. If that gate fails, the server compensates back into the already-streamed interior rather than leaving a sessionless player or duplicate vehicle.

The later immediate re-entry failure was also not a streaming or distance fault. `OwnedGarageInteriorRuntime.Create` intentionally reused the still-cached interior, but session setup disconnected its prompt callbacks and display rendering only connected newly created prompts. V1.2 keeps caching and the 20-second unload delay, then rebinds all existing physical prompts through a keyed exactly-once registry on configuration/rerender. Both cached and freshly cloned interiors therefore use the same callback lifecycle.

## 2026-07-22 Owned Garage V1.4 Interior District

The submission district uses the existing config-owned placement calculation with base `(7000,3200,0)`, four columns and `512` studs on both grid axes. This replaces the tightly-packed `160 x 120` cells and avoids the proposed 20,000-stud far-origin position, where hover-vehicle physics, raycasts, cameras and effects would carry greater precision risk. The 512-stud cells exceed current 180-stud audio and 36-stud garage-light ranges, reducing cross-interior bleed while keeping the 24-slot district around the established world scale.

Interiors remain server Workspace models and distance is not an access/privacy boundary. Server session/ownership validation remains authoritative. Verify two simultaneous garages for visibility, audio, interaction and streaming; a separate garage place or per-player visibility architecture remains a post-submission option, not part of V1.4.

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
  - Interiors
    - GarageInstances

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

Persistence Phase 21 prepares the first private garage interior shell:

```text
Workspace.NeoTokyoRacersWorld.Interiors.GarageInstances
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.GarageInteriorClient_Active
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageInteriorService_Active
```

The Phase 21 client helper only handles the loading fade and `Workspace:RequestStreamAroundAsync` around the private garage spawn. It does not replace the city LOD client yet. A later garage mode should explicitly pause city far-LOD work while inside interiors.

Persistence Phase 22 prepares the first garage display vehicle runtime:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageDisplayRuntime
Workspace.NeoTokyoRacersWorld.Interiors.GarageInstances.<owner>.DisplayVehicle_Runtime
```

Display vehicles are intended to be anchored/non-drivable interior props, not full runtime vehicles. They should stay separate from `Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles`.

Persistence Phase 23 is confirmed through the canonical `GarageInteriorService_Active` repair path. Same-server self-visits, public access mode, display refresh, and return-to-city passed in Studio on 2026-07-02.

Persistence Phase 24 confirms the first garage surface/decor customization runtime as a separate service instead of another patch to the interior service:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage.GarageInteriorCustomizationInvoke
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageInteriorCustomizationService_Active
Workspace.NeoTokyoRacersWorld.Interiors.GarageInstances.<owner>.DecorationAnchors_Runtime
Workspace.NeoTokyoRacersWorld.Interiors.GarageInstances.<owner>.Decorations_Runtime
```

It applies simple floor/wall material colours and one MVP decoration prop from profile-backed `Garage.Customisation` data. The client smoke passed on 2026-07-02 with `surfaces=2`, `decorations=1`, and `persisted=true`. It does not change city LOD behavior yet.

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
