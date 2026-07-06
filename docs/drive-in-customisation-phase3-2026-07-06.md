# Drive-In Customisation Phase 3

Prepared: 2026-07-06

Script:

- `scripts/roblox_drive_in_customisation_phase3_countdown_unlock_repair.lua`

## Goal

Repair the Phase 2 follow-up issues without adding more weight to the register-limited main client bootstrap:

- the world prompt should appear only while the driven vehicle is inside the drive-in zone;
- the prompt should only show the live countdown text, not an idle title/action;
- countdown text should be mixed case and stay inside the prompt frame;
- leaving the garage via `Start Driving` after drive-in customisation should restore a normal drivable vehicle and stop the world from reloading around the hidden hold point.

## Root Cause

Phase 2 correctly hid/froze the player at `DriveInCustomisationPlayerHoldPoint` while the garage UI was open. The normal garage `Start Driving` button still called `SpawnVehicle` while the player attribute `NTR_DriveInCustomisationActive` could still be true.

That meant the server-side hold lock could keep the character anchored/frozen while the spawn/seat handoff tried to create and enter the new vehicle. The result was a non-drivable car and streaming/focus weirdness around the hold point.

Phase 3 releases the drive-in hold immediately before the existing `SpawnVehicle` call, then waits briefly so the isolated drive-in client/server lock can restore the player before the vehicle spawns.

## Behaviour

The drive-in client remains isolated at:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DriveInCustomisationZoneClient_Active
```

The prompt remains a local `BillboardGui` adorned to:

```text
Workspace.NeoTokyoRacersWorld.Dealership.Customisation.DriveInCustomisationTrigger
```

VFX under the trigger are still toggled locally while the player is driving. The prompt itself is hidden until the player's currently driven vehicle is inside the trigger bounds and the countdown has started.

## Config

Phase 3 keeps the existing config roots:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DriveInCustomisation
ReplicatedStorage.NeoTokyoRacers.Config.UI.DriveInCustomisation
```

Added/normalised UI values:

- `PromptPrefix = "Entering customisation in"`
- `CountdownPromptWidth`
- `CountdownPromptHeight`
- `CountdownTextMaxSize`
- `CountdownTextMinSize`

## Verification

1. Run the script in Edit mode.
2. Restart Play.
3. Spawn/drive a vehicle and approach the drive-in bay.
4. Confirm the trigger VFX show while driving, but no prompt appears until the vehicle enters the zone.
5. Enter the zone and confirm the prompt says `Entering customisation in 3`, then `2`, then `1`, inside the frame.
6. Confirm Build Modules opens with the garage preview camera and the live car despawned.
7. Click through to `Start Driving`.
8. Confirm the new spawned car is immediately drivable, the camera/HUD are normal, the player is no longer hidden/frozen, and the world does not keep reloading around the old hold point.
9. Confirm the normal on-foot customisation entry path still works.

## Risks

The prompt repair is an isolated client replacement. The only fragile part is one guarded exact-source patch in the large bootstrap around the existing `State.Stage == "Customise"` / `SpawnVehicle` block. It adds only an inline attribute unlock and short wait, with no new top-level locals or helpers.

If the bootstrap source anchor is missing, refresh the Studio mirror before creating another repair.
