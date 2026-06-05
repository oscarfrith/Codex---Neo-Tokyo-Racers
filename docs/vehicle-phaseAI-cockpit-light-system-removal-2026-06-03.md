# Vehicle Phase AI Cockpit Light System Removal

Run this in Roblox Studio Command Bar, Edit mode:

`scripts/roblox_vehicle_phaseAI_remove_cockpit_light_systems.lua`

Phase AI removes the cockpit/car light experiments from Phases S through AH. The goal is to return the vehicle system to a clean baseline while front/rear driving lights are deprioritised.

## What It Removes

- Known cockpit-light helper LocalScripts under `StarterPlayer.StarterPlayerScripts`.
- Client-only projector/beam/smoother rig folders if they exist in Edit mode.
- `ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles.CockpitLightTemplates`.
- `COCKPIT_LIGHTS_EditHere` folders and generated front/rear spotlight folders on cockpit assets.
- Root-only `NTR_CockpitFrontSpotLight` / `NTR_CockpitRearSpotLight` attachments and lights.
- Phase AH Beam visuals and short-range local light artifacts.
- Phase AB lens welds and `CockpitSpotLightLens` artifacts.
- Obsolete cockpit-light attributes on surviving roots.

It writes a report to:

`ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports.PhaseAI_CockpitLightSystemRemoval`

## What Stays

- Driving, camera, garage, LOD, traffic, lighting presets, and thrust VFX are not changed.
- Ordinary cosmetic neon/paint colour channels remain.
- `Workspace.Test + WIP Assets` is excluded.

## Verification

After running Phase AI, Play mode should not print any cockpit-light helper output such as:

- `[NTR Vehicle Phase U]`
- `[NTR Vehicle Phase Y]`
- `[NTR Vehicle Phase Z]`
- `[NTR Vehicle Phase AG]`
- `[NTR Vehicle Phase AH]`

Front/rear long-range car lights are intentionally paused. Revisit them later from a fresh design rather than rerunning the removed experimental phases.
