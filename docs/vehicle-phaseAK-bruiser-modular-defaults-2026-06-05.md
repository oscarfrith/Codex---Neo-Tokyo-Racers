# Vehicle Phase AK Bruiser Modular Defaults

Status: installed and confirmed working through follow-up repairs on 2026-06-08.

Command-bar script:

```text
scripts/roblox_vehicle_phaseAK_bruiser_modular_defaults.lua
```

Register-limit repair if needed:

```text
scripts/roblox_vehicle_phaseAK_register_limit_repair.lua
```

Server core-gate repair if needed:

```text
scripts/roblox_vehicle_phaseAK_server_core_gate_repair.lua
```

Rear engine catalogue repair if `Engines_B` does not mirror `Engines`:

```text
scripts/roblox_vehicle_phaseAK_rear_engine_catalogue_repair.lua
```

Module entry camera repair if Build Modules starts too close/tilted down:

```text
scripts/roblox_vehicle_phaseAK_module_entry_camera_repair.lua
```

Per-cockpit paint camera and editable default colours:

```text
scripts/roblox_vehicle_phaseAK_per_cockpit_default_colours.lua
```

Spawned module colour sync if preview and driving colours differ:

```text
scripts/roblox_vehicle_phaseAK_spawn_module_colour_sync.lua
```

## What It Changes

Phase AK reshapes the Bruiser module catalogue around the requested balance pattern:

- Engines: each Bruiser cockpit family gets Standard, Lightweight, and Power engine modules.
- Stabilisers: each Bruiser cockpit family gets Standard, Lightweight, and Power stabiliser modules.
- Boost: each Bruiser cockpit family gets Standard, Lightweight, and Power boost modules.
- Front bumpers, rear bumpers, rear spoilers, and side pods become simple Lvl 1, Lvl 2, and Lvl 3 options.

All modules remain category-level Bruiser modules, so Bruiser cockpits can use modules from other Bruiser cockpit families.

The script adds editable balancing attributes to every generated/current Phase AK module:

- `Price`
- `Power`
- `TopSpeed`
- `Acceleration`
- `Handling`
- `Drift`
- `Braking`
- `Weight`
- `Boost`
- `BoostDuration`
- `BoostRecharge`
- `BoostRechargeDelay`
- `NeonPrice`
- `Tier` or `Level`
- `BalanceEditable`
- `BalanceNote`

The values are rough starter estimates, not final balance.

## Default Ownership Rule

Each cockpit gets:

- `DefaultEngineModuleId`
- `DefaultStabilisersModuleId`
- `DefaultBoostModuleId`

When a player buys or selects a cockpit, the server grants those standard modules. If the player has empty core slots, the server equips:

- `Engine1` and `Engine2` to the cockpit's standard engine module.
- `Stabilisers` to the cockpit's standard stabiliser module.
- `Boost` to the cockpit's standard boost module.

The modules are then owned permanently inside the session profile and can be equipped on other Bruiser cockpits.

## UI Changes

The dealership stats panel now previews a selected cockpit with its included standard engine pair, standard stabilisers, and standard boost added to the cockpit stats.

The Customise Modules button is gated. If a player tries to continue from module selection without at least one engine, stabilisers, and boost equipped, a centered popup appears using the existing dark panel, light green accent, and compact responsive sizing.

## Fragility

This phase uses guarded source text replacement against:

```text
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

If those scripts were regenerated or manually reshaped, the installer should stop with a preflight error instead of partially patching source. Refresh the Studio mirror and review the current source before editing the installer.

If Studio reports `Out of local registers when trying to allocate V75OriginalStopDriving`, run the register-limit repair script above. This can happen because the active bootstrap is already very close to Roblox's 200 local register limit.

If `SpawnVehicle` reports `attempt to call a nil value` in the garage server controller, run the server core-gate repair. The first Phase AK server helper referenced a later local function, which Lua does not forward-declare automatically.

If rear engines do not show the same `Bruiser_01` through `Bruiser_05` Standard/Lightweight/Power structure as front engines, run the rear engine catalogue repair. It keeps rear engines as a separate `Engines_B` folder and points `SLOT_Engine2` at that folder.

If the camera feels wrong immediately after entering Build Modules, run the module entry camera repair. It uses the same section camera as `Engine1` before any slot is selected.

If the camera feels wrong while picking cockpit colours, run the per-cockpit defaults repair. That script also adds editable `Default*Color` attributes to each cockpit model; edit those Color3 attributes to change each cockpit's starting colours.

If installed modules look correct in the preview but spawn grey/old-coloured when driving, run the spawned module colour sync repair. It copies cockpit paint changes onto installed module colour records so server-spawned vehicles match the preview.

The earlier shared-config cockpit-default approach failed against the live server source and was removed. Use the per-cockpit `Default*Color` attributes instead.

## Verification

After running the script in Studio:

1. Confirm `ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles.Categories.BRUISER.MODULES_InterchangeableWithinCategory` contains the new Engine, Stabiliser, Boost, and Lvl 1-3 body module structure.
2. Click each Bruiser cockpit in the dealership and confirm the stats bars include its standard modules.
3. Buy a cockpit and confirm the standard engine, stabiliser, and boost modules appear owned and equipped.
4. Confirm those owned standard modules can be equipped on another Bruiser cockpit.
5. Clear a required core slot temporarily, press Customise Modules, and confirm the centered popup appears on desktop and mobile view sizes.
6. Spawn the vehicle and confirm the server refuses to spawn only if one engine, stabilisers, or boost is missing.

## Rollback

Use Roblox version history if Studio testing finds a major catalogue or source issue. The installer does not create in-game backup folders.
