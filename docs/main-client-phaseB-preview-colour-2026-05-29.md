# Main Client Phase B - Preview And Colour Modules

**Created:** 2026-05-29  
**Current status:** Ready to run / module staging  
**Studio script:** `scripts/roblox_client_phaseB_preview_colour_modules.lua`

## Goal

Phase B creates staged preview and colour modules for the future extraction of `HOVER_RACING_V2_Client`.

This phase does **not** change live gameplay. It prepares the next ownership boundaries while the existing main client continues to run the current preview, colour UI, and garage camera logic.

## Requires

Phase A must already be installed and play-tested:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientState
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.GarageApiClient
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.CatalogClient
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientThemeAdapter
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.PaintClient
```

## Modules Created Or Updated

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewCameraController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewVehicleController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.ColourPickerController
```

## Responsibilities

`PreviewCameraController`:

- Preview camera state defaults.
- Module-section yaw targets.
- Smooth preview camera update.
- Reset/focus helpers.

`PreviewVehicleController`:

- Preview root lookup/creation.
- Cockpit template lookup.
- Preview vehicle clone assembly.
- Fixed slot mount lookup.
- Module-to-slot pivoting.
- Module colour fallback via Phase A `PaintClient`.

`ColourPickerController`:

- HSB/HSV conversion helpers.
- Colour state sync.
- Channel title formatting.
- Hue, saturation, and brightness gradient helpers.
- A staged render entry point for the later UI controller migration.

## What It Does Not Do

This phase does not:

- Edit `HOVER_RACING_V2_Client`.
- Disable `HOVER_RACING_V2_Client`.
- Redirect live preview building.
- Redirect live colour picker rendering.
- Redirect live garage camera update.
- Change server actions.
- Change driving mechanics.
- Change VFX runtime, mobile controls, LOD, lighting, or traffic systems.

## Required Test

Run the script in Roblox Studio Command Bar in Edit mode.

Expected report:

```text
Live client edited: false
Live behaviour changed: false
Phase A modules present: true
Passed checks: 3 / 3
```

Then run a normal Play test and confirm:

- dealership opens
- cockpit preview appears
- cockpit paint still works
- module preview still works
- colour sliders still work
- neon and thrust colour previews still behave as before
- vehicle spawn/driving still works

## Rollback

Because this phase does not switch live behaviour, rollback is simply ignoring the staged Phase B modules.

Do not delete the modules unless Studio reports a specific problem with them.

## Codex Safety Notes

- Do not start Phase C unless Phase B checks pass and normal Play testing still works.
- Do not make `HOVER_RACING_V2_Client` require these modules without a dedicated adapter/switch phase.
- Keep preview/colour extraction separate from full screen-controller extraction.
- The staged preview vehicle module contains preview cleanup/build logic, but Phase B does not call it from live gameplay.
