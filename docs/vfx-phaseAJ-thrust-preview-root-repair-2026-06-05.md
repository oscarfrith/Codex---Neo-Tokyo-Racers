# VFX Phase AJ Thrust Preview Root Repair

**Created:** 2026-06-05  
**Status:** Prepared for Studio install/test  
**Studio script:** `scripts/roblox_vfx_phaseAJ_thrust_preview_root_repair.lua`

## Problem

After Dealership Intro Phase 4, the customisation preview vehicle moved from:

```text
Workspace.HOVER_RACING_V2_LOCAL_PREVIEW
```

to the client-only dealership root:

```text
Workspace._NTR_ClientOnly.VehiclePreview
```

The thrust preview/VFX runtime still searched only the old root. The garage could set `ThrustColor` and `ForceThrustPreview` on the new preview root, but the VFX helper was watching the old/missing folder, so thrust VFX no longer previewed in the customisation menu.

## Fix

Run this Studio command-bar script:

```text
scripts/roblox_vfx_phaseAJ_thrust_preview_root_repair.lua
```

It patches the active cached thrust VFX runtime module:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Visuals.CachedThrustVisualRuntime
```

and, if present, the active thrust preview fallback:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.ThrustPreviewController_Active
```

Both now resolve preview VFX from `Workspace._NTR_ClientOnly.VehiclePreview` first and keep `Workspace.HOVER_RACING_V2_LOCAL_PREVIEW` as a fallback.

## Git-Side Alignment

The staged Phase B preview vehicle generator was also updated so future reruns use:

```text
Workspace._NTR_ClientOnly.VehiclePreview
```

instead of recreating the old global preview folder.

## Verification

1. Run Phase AJ in Studio Edit mode.
2. Stop Play and start a fresh Play session.
3. Open the dealership/garage from the desk.
4. Buy or select a cockpit so the client-only preview appears.
5. Go to `Customise > Thrust colour`.
6. Confirm engine/boost/stabiliser thrust VFX turns on in the preview.
7. Change the thrust colour and confirm the VFX recolours.
8. Spawn and drive, then confirm runtime engine, boost, and stabiliser VFX still respond.

## Notes

- This does not restore or change the deferred cockpit car-light systems.
- This does not touch driving physics, garage server actions, LOD, lighting, traffic, or world layout.
- If this still does not show preview VFX, run the Studio script export/import workflow and inspect the current active `CachedThrustVisualRuntime` source against this doc.
