# Driving Mechanics

## Current Baseline

The current driving system is based on the V47/V62-style hover controller, restored and extended in later scripts.

Confirmed by chat:

- `V74` restored the pre-V72/default Roblox camera feel and worked well.
- `V75` adds boost delay and hover wobble but needs play-test confirmation unless confirmed later.

## Hover System

The vehicle hovers using four corner raycasts from the cockpit/root area.

Known behaviour:

- Target hover height is about `3` studs.
- Four corner hover forces keep the car aligned to terrain.
- The vehicle aligns to ground slope using raycast hit positions/normals.
- Steering applies banking/tilt.
- Reverse speed is limited.
- Jump is disabled while driving.

## Drift

Current drift design:

- `SHIFT` activates drift on keyboard.
- Character sprint may also use `LeftShift` while on foot, but `scripts/roblox_character_sprint_controller_install.lua` installs it as an on-foot-only controller. It does not bind/sink the key with `ContextActionService`, and it suspends itself when the humanoid is seated in a `VehicleSeat`, so vehicle drift can continue reading Shift directly.
- Drift does not activate while reversing.
- Drift slows the vehicle more than normal driving.
- Drift improves turning while held.
- Longer drift charges a stronger/longer post-drift mini boost.

## Character Sprint

Confirmed sprint controller:

- `scripts/roblox_character_sprint_controller_install.lua`

Runtime install path:

```text
StarterPlayer
  StarterPlayerScripts
    NeoTokyoRacersClient
      Controllers
        Runtime
          CharacterSprintController_Active
```

Editable sprint config folder:

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

Important behaviour:

- Sprint is for on-foot movement only.
- Sprint stops when the player sits in a `VehicleSeat`.
- Mobile auto-sprint can start sprinting when the standard Roblox left thumbstick/move vector is pushed beyond `MobileSprintMoveThreshold`, default `0.85`.
- The installer removes the earlier broken `StarterPlayer.StarterCharacterScripts.NTR_CharacterSprintDefaults` script if present.
- The sprint installer was reported working on 2026-06-04 after the user moved/renamed the runtime hierarchy into the clean `NeoTokyoRacersClient.Controllers.Runtime` structure.

## Boost

Current boost design:

- `SPACE` activates boost on keyboard.
- Boost uses a rechargeable boost meter.
- `V75` adds a `0.5s` default delay before recharge starts.
- Boost module templates can override with `BoostRechargeDelay`.

Boost-related attributes:

- `Boost`
- `BoostDuration`
- `BoostRecharge`
- `BoostRechargeDelay`

## Camera

`V74` camera approach:

- Keeps Roblox's normal vehicle camera as the base.
- Adds a light camera assist rather than fully replacing the camera.
- Applies driving FOV multiplier while in car.
- Allows player camera movement.
- Softly recentres camera angle/height after a short delay if the car is moving.
- Does not forcibly reset player zoom distance.

Editable camera config folder:

```text
ReplicatedStorage
  HOVER_RACING_V2_KIT
    CONFIG
      DRIVING_CAMERA_ASSIST_EditAttributes
```

Known attributes:

- `BaseDrivingFovMultiplier`
- `CameraHeight`
- `CameraDistance`
- `AccelerationFovMultiplier`
- `BoostFovMultiplier`
- `AccelerationZoomOutStuds`
- `BoostZoomOutStuds`
- `RecenterDelaySeconds`
- `RecenterSpeed`

## Hover Wobble

`V75` adds a subtle low-speed wobble through the existing alignment system.

Intent:

- Most visible at `0 MPH`.
- Fades out to no wobble by `20 MPH`.
- Adds motion without extra runtime constraints or parts.

Editable wobble config folder:

```text
ReplicatedStorage
  HOVER_RACING_V2_KIT
    CONFIG
      HOVER_WOBBLE_EditAttributes
```

Known attributes:

- `WobbleEnabled`
- `WobbleAmountDegrees`
- `WobbleSpeed`
- `WobbleRandomiseAmount`
- `WobbleFadeOutMph`
- `WobblePitchMultiplier`
- `WobbleRollMultiplier`
- `WobbleSmoothing`

## Current Diagrams

- `diagrams/driving_runtime_system.svg`
