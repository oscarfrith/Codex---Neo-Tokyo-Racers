# Customisation System

**Created / first designed:** Before 2026-05-26  
**Last updated:** 2026-06-03  
**Current status:** Dealership/cockpit startup flow documented; wider customisation details still need fuller mapping  
**Relevant docs file:** `docs/customisation-system.md`  
**Relevant files to edit:** Customisation UI, customisation configs, vehicle cosmetic scripts only.

## What The System Does

The project has a working dealership/customisation flow for choosing a cockpit, painting it, selecting modules, customising modules, and spawning the final drivable vehicle.

This is part of the core fantasy of Neo Tokyo Racers:

- Build / own a futuristic hover racer.
- Race through a neon city.
- Upgrade or customise the vehicle over time.

## Current Dealership Flow

The current confirmed startup/customisation path is:

- `DealershipIntroClient_Active` shows local objective/path guidance to the dealership desk.
- `OpenGarageFromIntro` opens the active garage UI only when the player reaches `GarageDeskTrigger`.
- The first cockpit-buy menu can be exited. It reopens only after the player leaves and re-enters the desk zone.
- The local preview vehicle is delayed until cockpit purchase/select succeeds.
- Preview placement uses `Workspace.NeoTokyoRacersWorld.Dealership.Intro.Preview.VehiclePreviewPoint`.
- Preview camera startup uses `Workspace.NeoTokyoRacersWorld.Dealership.Intro.Camera.GaragePreviewCameraPoint`, then normal orbit/module focus behavior continues.
- Final drivable vehicle spawn uses `Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint`.

Full details are in `docs/dealership-intro-flow-2026-06-03.md`.

## Current Folder / Script Names

Known current script ownership:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
```

Wider module/customisation internals still need fuller documentation:

```text
ReplicatedStorage
- NeoTokyoRacers.Assets.Vehicles
- NeoTokyoRacers.Shared.Remotes.Garage
```

## Important Attributes / Settings

Current exact attributes TBC.

Design rules:

- Keep customisation prototype-friendly.
- Avoid overbuilding economy/progression too early.
- Avoid real brands or copyrighted references.
- Use fictional brands and original visual identity.
- Separate visual customisation from vehicle physics until the base game is stable.
- Ensure customisation choices are replicated safely.

## Current Known Issues

- Exact implementation needs documenting.
- Wider module/customisation implementation still needs documenting beyond the dealership intro/startup path.
- Need to identify which customisation features are currently functional.
- Need to confirm whether customisation is saved, temporary, or UI-only.
- Need to confirm whether customisation affects performance or physics.

## Confirmed Working

- Customisation exists in the current build.
- Dealership intro/customisation startup Phases 1-7 were confirmed working on 2026-06-03.
- Fictional companies/images are already part of the project direction.
- The feature is considered part of the current prototype identity.

## Still Needs Testing

- Multiplayer replication.
- Save/load behaviour.
- Reset/respawn behaviour.
- Performance with customised vehicles.
- Mobile UI usability.
- Whether custom parts affect collisions or vehicle handling.
- Whether all cosmetics are original and IP-safe.

## Codex Safety Notes

- Do not edit driving physics when changing cosmetic customisation unless explicitly requested.
- Do not assume save/load behaviour exists until it is verified in Studio.
- Avoid real brands, real car names, or copyrighted references.
