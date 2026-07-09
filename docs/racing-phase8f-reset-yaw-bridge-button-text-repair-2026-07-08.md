# Racing Phase 8F Reset Yaw Bridge And Button Text Repair

**Script:** `scripts/roblox_racing_phase8f_reset_yaw_bridge_and_button_text_repair.lua`  
**Status:** Generated after Phase 8E reset testing regressed vehicle/camera/streaming state  
**Scope:** Reset-to-checkpoint driving yaw sync and session-control button text rendering

## Why This Phase Exists

Phase 8E correctly identified that reset orientation was being fought by the driving controller's local `yawHeading`, but the repair reused the full `FreeRoamVehicleSpawned` / `startDriving` handoff after reset.

That was too broad. During an active race reset, restarting the whole driving stack can disturb the existing vehicle controls, camera subject, VFX attachment, and streaming focus. The user reported the car became disabled, the camera broke, and the world went low-res/weird after reset.

Phase 8F keeps the root idea but narrows the handoff:

- server reset remains authoritative;
- the transition client no longer restarts driving;
- the register-limited bootstrap gets a tiny bridge that only syncs `yawHeading` from the current vehicle root;
- normal free-roam/race start vehicle-spawn handoffs still use the existing full `startDriving` path.

## What It Changes

- Canonically replaces the isolated `RaceTransitionClient_Active` with a Phase 8F version.
- Changes the reset yaw request from a full `FreeRoamVehicleSpawned:Fire()` to:

```lua
FreeRoamVehicleSpawned:Fire({
    Action = "SyncDrivingYaw",
    Reason = "RaceReset",
})
```

- Adds the smallest practical bridge to `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`:
  - if payload action is `SyncDrivingYaw`, update local `yawHeading` from the current vehicle root `CFrame.LookVector`;
  - zero linear/angular velocity;
  - update the active `AlignOrientation` once;
  - return without calling `startDriving`;
  - otherwise preserve the normal `task.defer(startDriving)` behavior.
- Cleans the session control button text:
  - removes the tiny Michroma button font path;
  - uses fixed `GothamBold`;
  - disables wrapping/scaling;
  - clears text stroke.

## Why The Button Text Looked Uneven

The `RESET TO LAST CHECKPOINT` button used the Michroma font at a small size with wrapping enabled. Roblox rasterises some custom-font capital letters unevenly at small sizes, especially with bright neon colours and tight button bounds. It makes letters look like they are different heights even when the `TextSize` value is the same.

Phase 8F keeps the button themed but makes the text renderer simpler and more legible.

## Install

Run this in Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_racing_phase8f_reset_yaw_bridge_and_button_text_repair.lua
```

The script supports:

```lua
local MODE = "INSTALL" -- INSTALL or SMOKE
```

## Verification

1. Restart Play after install.
2. Start a time trial.
3. Pass a checkpoint, turn away from the route, then press `RESET TO LAST CHECKPOINT`.
4. Confirm the car stays drivable, the camera stays attached to the vehicle, and the world does not drop into low-res streaming.
5. Confirm the vehicle is stationary and faces the checkpoint/reset pose direction.
6. Confirm Output includes:

```text
[NTR Racing Phase 8F] Synced driving yaw only after reset.
```

7. Check the reset button text: it should look even and should not have mixed-size-looking characters.

## Risks

- This phase touches the register-limited bootstrap, but only by replacing the existing `FreeRoamVehicleSpawned` event connection with a tiny payload branch. It does not add new top-level helpers or large feature blocks.
- The reset yaw bridge is a practical stopgap while the driving controller still lives inside the bootstrap. A later clean driving-controller extraction should expose an explicit `SyncYawFromRoot` API instead.
- If the reset still does not face the authored checkpoint direction after this phase, the next check should be whether the checkpoint part orientation itself matches the expected vehicle nose direction or whether a dedicated `ResetPose` part is needed.

## Rollback

Use Roblox version history to restore:

- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTransitionClient_Active`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionControlsClient_Active`

Then return to the prior Phase 8D/8E state as needed.
