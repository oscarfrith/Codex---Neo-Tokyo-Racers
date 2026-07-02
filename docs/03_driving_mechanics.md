# Driving Mechanics

## Current Baseline

The current driving system is based on the V47/V62-style hover controller, restored and extended in later scripts.

Confirmed by chat:

- `V74` restored the pre-V72/default Roblox camera feel and worked well.
- `V75` adds boost delay and hover wobble but needs play-test confirmation unless confirmed later.
- Persistence Phase 17 garage/customisation recovery can expose a client `closeGarage` error when pressing Start Driving. If the server spawns the vehicle but driving does not start, use `scripts/roblox_persistence_phase17_close_garage_drive_handoff_repair.lua`; it repairs the UI-to-driving handoff without changing driving physics.

Vehicle Phase AM is the confirmed bridge from legacy totals into the detailed Phase AL performance variables. Its spawned-vehicle audit passed, detailed physics was enabled, and the user reported the driving behavior working well.

## Phase AM Detailed Variables

When enabled, Phase AM maps:

- `EngineOutput` to acceleration force.
- `SteeringResponse` to turn rate.
- `BrakingForce` to braking/reverse force.
- `BoostForce` to boost thrust.
- `LateralGrip` to normal lateral grip.
- `DriftGrip` to lateral grip while drifting.
- `HoverStability` to terrain alignment responsiveness.
- `DriftControl` to drift turning.
- `DriftChargeRate` to mini-boost charge speed.
- `Drag` to velocity damping.
- `Downforce` to high-speed grip contribution.
- `BoostEfficiency` to boost drain and recharge efficiency.

Initial compatibility values are compared with the matching legacy Handling or Drift value, producing a neutral multiplier until detailed attributes are intentionally tuned.

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
- Mobile steering uses a fixed horizontal thumbstick after running `scripts/roblox_mobile_drive_thumbstick_install.lua`. Moving beyond the configured drift threshold requests drift; hysteresis uses a lower exit threshold to prevent rapid toggling.
- Character sprint may also use `LeftShift` while on foot, but `scripts/roblox_character_sprint_controller_install.lua` installs it as an on-foot-only controller. It does not bind/sink the key with `ContextActionService`, and it suspends itself when the humanoid is seated in a `VehicleSeat`, so vehicle drift can continue reading Shift directly.
- Drift does not activate while reversing.
- Drift slows the vehicle more than normal driving.
- Drift improves turning while held.
- Longer drift charges a stronger/longer post-drift mini boost.

## Mobile Steering Thumbstick

Prepared installer:

- `scripts/roblox_mobile_drive_thumbstick_install.lua`

The V1 installer replaces the four left steering/drift arrow buttons with one fixed horizontal thumbstick. A touch must begin on the visible thumbstick or its forgiving invisible hit area. Once captured, that touch remains responsible for steering until release, even if it moves outside the hit area.

The V2 visual refinement is installed afterward with:

- `scripts/roblox_mobile_drive_thumbstick_v2_visual_refinement.lua`

The current installed V2.2 design keeps the existing green ring as the normal-turn zone and adds an outer drift ring with `1.8x` the inner radius. The outer band has a darker translucent fill. At rest, its border and `DRIFT` text use the light-green HUD accent. The pointer travels to the usable outer edge; crossing the inner-ring boundary activates drift and changes the pointer, text, and outer border to red together.

The V2.3 follow-up was:

- `scripts/roblox_mobile_drive_thumbstick_v2_3_snappy_steering.lua`

V2.3 removes the steering deadzone by default, changes the default steering
response exponent to linear `1`, shrinks the outer drift ring to `1.25x` the
inner ring, reduces the invisible touch hit area, and lowers the boost button so
it sits just above the visible outer ring with a small buffer. It needs
mobile/emulator play-testing before treating it as the confirmed baseline.

The next generated follow-up is:

- `scripts/roblox_mobile_drive_thumbstick_v2_4_large_edge_drift.lua`

V2.4 targets the user feedback that V2.3 is much better but still not quite
large/direct enough. It keeps zero deadzone and linear steering, enlarges the
inner circle to `1.4x`, makes the outer ring `1.35x` the enlarged inner circle,
and moves drift entry out near the usable edge with a default enter threshold of
`0.95` and exit threshold of `0.88`. It needs mobile/emulator play-testing for
small-screen fit, boost overlap, touch jitter, and whether drift feels too late.

The thumbstick writes analog `Steer` and threshold-based `Drift` through the existing `MobileDriveInputState` contract. It does not change driving physics or the keyboard/gamepad input paths.

Editable config folder:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Config.MobileDriveControls_EditAttributes
```

Attributes:

- `ThumbstickSizePixels`
- `ThumbstickInnerScale`
- `ThumbstickOuterRingScale`
- `TouchHitAreaMultiplier`
- `ThumbstickTravelRatio`
- `SteeringDeadzone`
- `SteeringResponseExponent`
- `DriftEnterThreshold`
- `DriftExitThreshold`
- `PedalScale`
- `HudLiftPixels`
- `BoostToOuterRingBufferPixels`

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
- Persistence Phase 17 UI polish adds a guard so sprint/FOV changes do not trigger while `HOVER_RACING_V2_GarageUI` is open. Shift should still be available for vehicle drift while seated and for normal sprinting outside menus.

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
