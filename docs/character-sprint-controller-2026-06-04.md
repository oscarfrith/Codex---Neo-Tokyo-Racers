# Character Sprint Controller Handoff

**Created:** 2026-06-04  
**Status:** Installed and working for on-foot sprint; mobile auto-sprint prepared / needs mobile verification  
**Script:** `scripts/roblox_character_sprint_controller_install.lua`

## Purpose

Adds a dedicated on-foot sprint controller without touching the hovercar driving controller, vehicle drift, boost, UI, VFX, or server action layer.

## Runtime Location

```text
StarterPlayer
  StarterPlayerScripts
    NeoTokyoRacersClient
      Controllers
        Runtime
          CharacterSprintController_Active
```

The user moved/renamed the runtime hierarchy into the clean controller structure:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.CharacterSprintController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.DriveHudController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController_Active
```

## Config Location

```text
ReplicatedStorage
  NeoTokyoRacers
    Shared
      Config
        CharacterMovement_EditAttributes
```

Known attributes:

- `Enabled`
- `AnimationId`
- `NormalWalkSpeed`
- `SprintWalkSpeed`
- `SprintFovEnabled`
- `SprintFieldOfView`
- `FovTweenSeconds`
- `SprintKey`
- `MinimumMoveSpeedForAnimation`
- `MobileAutoSprintEnabled`
- `MobileSprintMoveThreshold`
- `Debug`

## Confirmed Behaviour

- On-foot sprint works.
- Shift sprint does not consume the key with `ContextActionService`.
- Sprint suspends itself when the humanoid is seated in a `VehicleSeat`, so Shift drift remains available to the vehicle driving system.
- The earlier failed `StarterPlayer.StarterCharacterScripts.NTR_CharacterSprintDefaults` script is removed by the installer if present.
- A blocked third-party animation asset produced an access error. Setting `AnimationId` to `rbxassetid://0` or to a permitted project/group-owned animation avoids the warning. With custom sprint animation disabled, Roblox's normal character animations still look acceptable.

## Mobile Auto-Sprint

The installer now adds mobile auto-sprint support:

- Enabled by `MobileAutoSprintEnabled`, default `true`.
- Uses `MobileSprintMoveThreshold`, default `0.85`.
- Reads Roblox's standard `PlayerModule` move vector first, then falls back to `Humanoid.MoveDirection`.
- Does not inspect private thumbstick UI objects.
- Still ignores sprint while seated in a `VehicleSeat`.

Mobile auto-sprint needs real mobile/emulator verification. Tune `MobileSprintMoveThreshold` if sprint triggers too early or too late.

## Run Order

Run in Studio Edit mode:

```text
scripts/roblox_character_sprint_controller_install.lua
```

The script is rerunnable and preserves existing config attribute values.

## Rollback

In `scripts/roblox_character_sprint_controller_install.lua`, change:

```lua
local MODE = "INSTALL"
```

to:

```lua
local MODE = "ROLLBACK"
```

Then run it in Studio Command Bar. This removes `CharacterSprintController_Active` and restores `StarterPlayer.CharacterWalkSpeed` to `16`.

## Verification

After running the installer:

1. Play on desktop.
2. Confirm on-foot Shift sprint works.
3. Enter a hovercar and confirm Shift drift still works.
4. Exit the hovercar and confirm on-foot sprint still works.
5. Set `AnimationId = rbxassetid://0` unless using a permitted sprint animation asset.
6. Test on mobile or emulator:
   - light thumbstick push should walk,
   - full or near-full thumbstick push should sprint,
   - entering a vehicle should stop character sprint behaviour.

## Known Risks

- Third-party animation assets can fail with "experience doesn't have access permission." Use `rbxassetid://0` or publish/share a project-owned sprint animation.
- Mobile thumbstick threshold feel may differ between devices.
- Sprint FOV should be rechecked after respawn, death, vehicle entry, and vehicle exit.
- `roblox/exported_scripts` may be stale until the Studio export/import workflow is rerun after this sprint work.
