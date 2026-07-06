# Drive-In Customisation Phase 2

Prepared: 2026-07-06

Script:

- `scripts/roblox_drive_in_customisation_phase2_garage_entry_world_prompt.lua`

## Goal

Repair the first drive-in customisation flow so it behaves like normal garage customisation:

- entering the bay despawns the live driven vehicle;
- the camera moves to the normal garage preview camera instead of staying on the player;
- the local preview vehicle appears in the customisation garage;
- the player is hidden/frozen at a hold point while the garage UI is open;
- the countdown is a world-space prompt on `DriveInCustomisationTrigger`, similar to the enter-vehicle prompt;
- VFX attached under `DriveInCustomisationTrigger` are shown/hidden locally while driving instead of changing the trigger part transparency.

## Installed Objects

- `ServerScriptService.NeoTokyoRacers.Services.Garage.DriveInCustomisationSessionService_Active`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DriveInCustomisationZoneClient_Active`
- `Workspace.NeoTokyoRacersWorld.Dealership.Customisation.DriveInCustomisationPlayerHoldPoint`

The existing `DriveInCustomisationTrigger` remains the zone/prompt/VFX anchor.

## Behaviour

The trigger part should stay invisible and non-colliding. Add your visible bay VFX as descendants of:

```text
Workspace.NeoTokyoRacersWorld.Dealership.Customisation.DriveInCustomisationTrigger
```

The Phase 2 client toggles descendant `ParticleEmitter`, `Beam`, `Trail`, `PointLight`, `SpotLight`, and `SurfaceLight` objects locally. This means the bay can appear only for the player who is currently driving.

The countdown prompt is a local `BillboardGui` adorned to the trigger, so it can count down live without creating server UI objects.

## Config

Existing config remains under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DriveInCustomisation
ReplicatedStorage.NeoTokyoRacers.Config.UI.DriveInCustomisation
```

Phase 2 adds:

- `UseWorldPrompt`
- `TriggerVfxOnlyWhileDriving`
- `PromptMaxDistance`
- `PromptHeightOffset`
- `IdleTitle`
- `IdleAction`
- `CountdownTitle`

## Verification

1. Run the script in Edit mode.
2. Confirm `DriveInCustomisationPlayerHoldPoint` exists and is invisible under the customisation folder.
3. Keep your VFX under `DriveInCustomisationTrigger`.
4. Start Play, spawn/drive a vehicle, and approach the drive-in trigger.
5. Confirm the VFX and world prompt appear only while driving.
6. Drive into the trigger and confirm the prompt counts down in-world.
7. On completion, confirm the live vehicle despawns.
8. Confirm the player is hidden/frozen and cannot run around.
9. Confirm the camera is in the garage preview/customisation view and Build Modules opens for the driven vehicle.
10. Exit/spawn from the garage UI and confirm player movement returns.

## Risks

The world prompt and VFX client are isolated and safely replaced. The only fragile part is a small register-safe replacement of the existing drive-in bootstrap handoff. If the bootstrap anchor is missing, refresh the Studio mirror before making another patch.
