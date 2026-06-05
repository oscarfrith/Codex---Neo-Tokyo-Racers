# Script Architecture Review

**Document status:** Current script architecture review  
**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Source:** `roblox/exported_scripts` Studio script mirror  
**Current status:** Review complete / next migration should be staged  

## Summary

The current game is working, but the active logic still contains several compatibility layers from earlier recovery patches. That is the main reason recent command-bar patches became fragile: some systems exist twice, with the newer layer overriding the older one later in the same script.

The safest next direction is not another large rewrite. The better path is:

1. Keep the current live scripts stable.
2. Create clean target folders and service/controller names.
3. Move one small system at a time into the new architecture.
4. Only switch live behaviour after each system is tested in Studio.

## Current Script Size Snapshot

Largest active/current files in the exported mirror:

```text
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client      ~106 KB
ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server ~55 KB
ReplicatedStorage...Controllers.DrivingControllerV47           ~31 KB
ReplicatedStorage...Visuals.CachedThrustVisualRuntime          ~20 KB
ReplicatedStorage...VFX.VehicleVFXController                   ~17 KB
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V67_MobileDriveControls ~15 KB
```

The client and server scripts are the main maintainability risks. The newer driving, VFX, UI pool, and shared config modules are useful foundations and should be preserved.

## Main Findings

### 1. Main Client Script Is Doing Too Much

Current file:

```text
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client
```

It currently handles:

- Garage/dealership UI
- Category and cockpit selection
- Module shop UI
- Customisation UI
- Colour picker
- Preview vehicle building
- Garage camera controls
- Drive HUD
- Mobile control bridge
- Old driving logic
- New `DrivingControllerV47` bootstrapping

This makes iteration slower because a small UI change can accidentally affect driving, camera, or mobile behaviour.

Recommended split later:

```text
StarterPlayerScripts.NeoTokyoRacersClient
- Bootstrap
- Controllers
  - GarageClient
  - DealershipClient
  - CustomisationClient
  - PreviewVehicleClient
  - GarageCameraClient
  - DrivingClient
  - MobileControlsClient
  - HudClient
```

### 2. Main Server Script Has Old and New Action Layers

Current file:

```text
ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server
```

The file contains an older action layer near the top, then a newer `V56_CONSOLIDATED_ACTION_CONTROLLER` layer later in the same script. The later `GarageInvoke.OnServerInvoke` assignment is the one that should win, but keeping both makes future patching risky.

Recommended split later:

```text
ServerScriptService.NeoTokyoRacers.Services
- GarageService
- VehicleSpawnService
- VehicleBuildService
- ProfileService
- EconomyService
- VehicleOwnershipService
```

Near-term safety rule:

- Do not patch the old server layer unless deliberately removing it.
- Treat the `V56_CONSOLIDATED_ACTION_CONTROLLER` block as the current action source of truth.

### 3. Driving Is Now Mostly Modular

Current important module:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.DrivingControllerV47
```

This is the correct direction. It contains the current restored V47-style driving, boost delay, camera assist, and low-speed hover wobble.

Performance notes:

- The driving loop runs every `Heartbeat`, which is appropriate for local vehicle physics.
- It raycasts four corners per frame. That is reasonable for one local vehicle.
- It still reads vehicle stats during the loop via `stat(...)`; long term, cache a full stat snapshot once when driving starts and refresh only when the vehicle changes.
- Keep the old fallback driving controller archived/unused unless deliberately testing recovery.

### 4. VFX Runtime Is Moving In The Right Direction

Current important modules/scripts:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Visuals.CachedThrustVisualRuntime
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.VFX.VehicleVFXController
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V64_CachedThrustVisualRuntime
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V46_ThrustPreviewOnly
```

Good direction:

- Cached thrust VFX avoids constant cloning.
- Vehicle attributes drive VFX state: `DriveReady`, `Accelerating`, `Boosting`, `DriftingLeft`, `DriftingRight`.
- The runtime has cleanup for removed descendants.

Performance recommendations:

- Continue treating VFX as client-side visual-only logic.
- Avoid repeated `GetDescendants()` while driving except during setup or occasional rescan.
- Keep particle rates low on mobile and prefer beams/trails for clean jet visuals.
- Use one cached runtime owner for driving VFX so preview and live driving do not fight over colours.

### 5. Mobile HUD Suppression Is A Patch Layer

Current scripts:

```text
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V67_MobileDriveControls
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V71_MobilePcHudSuppressor
```

These work, but `V71` scans `PlayerGui` repeatedly to hide desktop HUD elements on mobile. That solved flicker, but it is a workaround.

Better long-term approach:

- Put all drive HUD ownership into one `HudClient`.
- The HUD should decide once whether it is in mobile or desktop mode.
- Avoid scanning all `PlayerGui` descendants every frame or every 0.08 seconds.
- Prefer explicit tags/names such as `DriveHudDesktop` and `DriveHudMobile`.

### 6. UI Pool Exists But The Main Client Still Builds A Lot

Current modules:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.UI.UIPool
ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.UI.UIFactory
```

This is good. Future UI work should use these instead of destroying/recreating buttons.

Recommended pattern:

- Create panels once.
- Use `UIPool:Begin()`, `UIPool:Acquire()`, `UIPool:Connect()`, `UIPool:End()` for lists.
- Avoid `clear(container)` for panels that update frequently.
- Keep colour/theme values in `UI_THEME_DoNotRename` or future mirrored config folders.

### 7. LOD System Is Working But Should Be Server/World Organized

Current script:

```text
StarterPlayer.StarterPlayerScripts.LOD System
```

The script is local, which is good for client visual performance. It updates at `0.5` seconds, which is reasonable for mobile. It caches original properties and uses LOD/far proxy folders.

Recommended later:

```text
StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient
ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.LODConfig
```

Do not rewrite this until the city/LOD is retested after hierarchy staging.

### 8. Traffic Lights Are A Good First Live Migration Candidate

Current script:

```text
ServerScriptService.Traffic Lights
```

This is small and self-contained. It uses one central loop and `CollectionService` tag `TrafficLight`, which is the right performance pattern.

Recommended first real migration:

```text
ServerScriptService.NeoTokyoRacers.Services.World.TrafficLightService
```

Migration should be staged:

1. Copy the script into the new folder as disabled.
2. Test source parity.
3. Disable the old script and enable the new one in a separate step.
4. Play-test duplicated traffic lights.

### 9. Lighting Is Small But Has Known Gameplay Visibility Issues

Current script:

```text
ServerScriptService.Lighting.LightingController
```

It already supports `Sky` swapping, which was a known issue in earlier notes. Keep `TEMP_LightingPreview` for visual tuning.

Recommended later:

```text
ServerScriptService.NeoTokyoRacers.Services.World.LightingService
ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.Lighting
```

Do this after traffic lights because lighting has more visual side effects.

## Mobile Performance Priorities

Highest value improvements for Roblox mobile:

1. Reduce broad `GetDescendants()` scans during active driving/UI moments.
2. Consolidate mobile/desktop HUD ownership so suppression scripts are not constantly fighting visibility.
3. Cache vehicle stats at drive start and refresh only on spawn/equip/upgrade.
4. Keep VFX cached and client-side.
5. Keep hover raycasts fixed and predictable.
6. Avoid enabling lots of particle emitters at once on mobile.
7. Keep LOD update intervals at `0.2-0.5` seconds, not every frame.
8. Use simple collision roots for vehicles; decorative parts should stay massless/non-colliding.

## Recommended Migration Order

### Phase 4A: Architecture Staging Scaffold

Create clean future folders and ObjectValue references without changing live behaviour.

Status: prepared by `scripts/roblox_hierarchy_phase4_architecture_staging_scaffold.lua`.

### Phase 4B: Traffic Light Service Shadow Copy

Copy current `ServerScriptService.Traffic Lights` into the new service folder as a disabled script. Do not switch live behaviour yet.

Status: prepared by `scripts/roblox_hierarchy_phase4b_prepare_traffic_service_shadow.lua`.

### Phase 4C: Traffic Light Live Switch

After a Studio play-test, disable old `Traffic Lights` and enable the new `TrafficLightService`.

Status: included in `scripts/roblox_hierarchy_phase6_world_services_migration.lua`.

### Phase 4D: Lighting Service Shadow Copy

Repeat the same process for lighting.

Status: included as a disabled shadow copy in `scripts/roblox_hierarchy_phase6_world_services_migration.lua`.

### Phase 5: Client UI Extraction

Extract only UI/theme/pooling helpers first. Avoid touching driving while doing this.

Status: Phase 5A prepared by `scripts/roblox_hierarchy_phase5_ui_module_shadow_extract.lua`.

Phase 7 promotes the shared UI helper layer into final module names using `scripts/roblox_hierarchy_phase7_shared_ui_helpers_promote.lua`, still without switching live UI behaviour.

### Phase 6: Server Action Extraction

Move the current `V56` action controller into server services. Remove the older unused layer only after the new service version is tested.

### Phase 7: Mobile HUD Consolidation

Replace the mobile HUD suppressor workaround with a single HUD owner that explicitly chooses mobile or desktop UI.

## Codex Safety Notes

- Do not apply broad patches to `HOVER_RACING_V2_Client` or `HOVER_RACING_V2_Server` unless the user explicitly asks for a live code change.
- Do not remove old logic from live scripts until a replacement has been created, enabled, and tested.
- Prefer disabled shadow copies for migrations before switching live scripts.
- Treat `Workspace.Test + WIP Assets` as excluded.
- Treat `TEMP_LightingPreview` as intentionally kept.
- Do not create in-game backup scripts unless the user asks; rely on Roblox version history and GitHub docs/source mirror.
