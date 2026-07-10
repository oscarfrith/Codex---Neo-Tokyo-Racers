# Driving Mechanics

## Current Baseline

The current driving system is based on the V47/V62-style hover controller, restored and extended in later scripts.

Confirmed by chat:

- `V74` restored the pre-V72/default Roblox camera feel and worked well.
- `V75` adds boost delay and hover wobble but needs play-test confirmation unless confirmed later.
- `scripts/roblox_driving_speed_sensitive_steering_curve.lua` was reported working nicely by the user. It adds configurable low-speed/high-speed steering multipliers, reverse steering, and boost steering to `DrivingControllerV47`.
- `scripts/roblox_driving_accel_brake_pitch_tilt.lua` was reported looking great by the user. It adds configurable front/back pitch tilt on acceleration, braking, reverse acceleration, and boost.
- `scripts/roblox_driving_drift_boost_accel_gate_reverse_speed.lua` was reported working and looking good by the user. It makes drift-exit mini-boost require acceleration by default and raises/tunes reverse speed to `40 MPH`.
- `scripts/roblox_driving_slope_hover_height_compensation.lua` was reported working well by the user. It fixes speed-dependent hover height drift on uphill/downhill slopes by damping vertical hover motion relative to expected slope-following movement.
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
- The confirmed slope hover compensation fixes a known issue where uphill travel makes the vehicle sink close to the ground and downhill travel makes it float too high. Root cause: the old spring damped raw world-Y velocity, so expected vertical movement from following a slope was misread as unwanted bounce/fall.
- Steering applies banking/tilt.
- Reverse speed is currently being raised/tuned by `scripts/roblox_driving_drift_boost_accel_gate_reverse_speed.lua`, default `40 MPH`.
- Jump is disabled while driving.

Prepared installer for slope hover height compensation:

- `scripts/roblox_driving_slope_hover_height_compensation.lua`

Editable config attributes:

- `SlopeHoverCompensationEnabled = true`
- `SlopeHoverVelocityCompensation = 1.0`
- `SlopeHoverHeightStiffness = 54`
- `SlopeHoverNormalVelocityDamping = 7`
- `SlopeHoverMaxLiftMultiplier = 4.5`
- `SlopeHoverMissLiftMultiplier = 0.05`
- `SlopeHoverForceAlongGroundNormal = false`
- `SlopeHoverDebugAttributes = true`

Tuning guidance:

- Keep `SlopeHoverVelocityCompensation` near `1.0` for full slope-following correction.
- Lower `SlopeHoverVelocityCompensation` if the car starts bobbing or over-correcting on uneven terrain.
- Raise `SlopeHoverHeightStiffness` if it still gets too close/far from the ground on slopes.
- Raise `SlopeHoverNormalVelocityDamping` if it bounces vertically after slope transitions.
- Lower `SlopeHoverNormalVelocityDamping` if it feels too stiff or sticky.
- Keep `SlopeHoverForceAlongGroundNormal = false` initially. Turning it on may improve steep-slope hugging, but it adds horizontal force components and should be tested carefully.

## Drift

Current drift design:

- `SHIFT` activates drift on keyboard.
- Mobile steering uses a fixed horizontal thumbstick after running `scripts/roblox_mobile_drive_thumbstick_install.lua`. Moving beyond the configured drift threshold requests drift; hysteresis uses a lower exit threshold to prevent rapid toggling.
- Character sprint may also use `LeftShift` while on foot, but `scripts/roblox_character_sprint_controller_install.lua` installs it as an on-foot-only controller. It does not bind/sink the key with `ContextActionService`, and it suspends itself when the humanoid is seated in a `VehicleSeat`, so vehicle drift can continue reading Shift directly.
- Drift does not activate while reversing.
- Drift slows the vehicle more than normal driving.
- Drift improves turning while held.
- Longer drift charges a stronger/longer post-drift mini boost.
- The prepared drift boost gate requires the player to be accelerating as drift ends before the mini-boost is awarded.

Prepared installer for drift-exit mini-boost gating and reverse speed:

- `scripts/roblox_driving_drift_boost_accel_gate_reverse_speed.lua`

Editable config attributes:

- `ReverseMaxMph = 40`
- `DriftMiniBoostRequiresAcceleration = true`
- `DriftMiniBoostAccelerationThreshold = 0.05`
- `DriftMiniBoostDebugAttributes = true`

Tuning guidance:

- Raise `ReverseMaxMph` if reversing still feels too constrained.
- Lower `ReverseMaxMph` if 40 MPH feels too fast for garage/parking areas.
- Keep `DriftMiniBoostRequiresAcceleration = true` for intentional drift exits.
- Lower `DriftMiniBoostAccelerationThreshold` if light trigger/pedal pressure should count.
- Set `DriftMiniBoostRequiresAcceleration = false` to restore the older always-award drift mini-boost behavior.

## Speed-Sensitive Steering Curve

Prepared installer:

- `scripts/roblox_driving_speed_sensitive_steering_curve.lua`

Intent:

- Low speeds turn more sharply for parking, tight corners, and recovery.
- High speeds turn less sharply so racing speed feels heavier and less twitchy.
- The transition is curved rather than linear, so the low-speed assist can ramp in progressively.
- Reverse steering has its own multiplier and can optionally also use the speed curve.
- Boost steering has its own multiplier that stacks on top of the speed curve during normal boost and drift mini-boost.

The patch keeps the existing vehicle build/stat system as the base. `Handling` / `SteeringResponse` still decides the vehicle's character, then the speed curve applies an extra multiplier to the final turn rate.

Editable config folder:

```text
ReplicatedStorage
  NeoTokyoRacers
    Config
      Runtime
        DRIVING_MECHANICS_EditAttributes
```

Suggested starting attributes:

- `SpeedSteeringEnabled = true`
- `SpeedSteeringLowSpeedMph = 0`
- `SpeedSteeringHighSpeedMph = 115`
- `SpeedSteeringLowMultiplier = 1.45`
- `SpeedSteeringHighMultiplier = 0.72`
- `SpeedSteeringCurveExponent = 1.85`
- `SpeedSteeringSmoothing = 7`
- `SpeedSteeringDriftMinimumMultiplier = 0.92`
- `ReverseSteeringMultiplier = 1.18`
- `ReverseSteeringUsesSpeedCurve = true`
- `BoostSteeringMultiplier = 0.8`
- `SpeedSteeringDebugAttributes = true`

How the curve works:

```text
speedAlpha = clamp((speedMph - LowSpeedMph) / (HighSpeedMph - LowSpeedMph), 0, 1)
lowSpeedInfluence = (1 - speedAlpha) ^ CurveExponent
multiplier = HighMultiplier + (LowMultiplier - HighMultiplier) * lowSpeedInfluence
```

Tuning guidance:

- Raise `SpeedSteeringLowMultiplier` if the car still feels too wide at slow speeds.
- Lower `SpeedSteeringHighMultiplier` if high-speed steering still feels twitchy.
- Raise `SpeedSteeringCurveExponent` if you want the car to keep high-speed heaviness until speed drops lower.
- Lower `SpeedSteeringCurveExponent` if you want the assist to arrive earlier through medium speed.
- Raise `ReverseSteeringMultiplier` if backing up feels sluggish.
- Disable `ReverseSteeringUsesSpeedCurve` if reverse should use only the fixed reverse multiplier.
- Lower `BoostSteeringMultiplier` below `1` if boost should feel more committed/heavy.
- Raise `BoostSteeringMultiplier` toward `1` if boost steering feels too restricted.

## Acceleration / Braking Pitch Tilt

Prepared installer:

- `scripts/roblox_driving_accel_brake_pitch_tilt.lua`

Intent:

- Acceleration gives the vehicle a small front/back pitch response.
- Braking pitches the vehicle the opposite way, with a separate stronger value.
- Reversing has its own pitch value so backing up can feel distinct from forward braking.
- Boost can add extra pitch during normal boost and drift mini-boost, even if throttle is not currently held.
- Existing hover wobble and banking remain active; this adds to wobble pitch rather than replacing it.

Editable config folder:

```text
ReplicatedStorage
  NeoTokyoRacers
    Config
      Runtime
        DRIVING_MECHANICS_EditAttributes
```

Suggested starting attributes:

- `AccelBrakeTiltEnabled = true`
- `AccelerationTiltDegrees = 2.5`
- `BrakeTiltDegrees = -3.5`
- `ReverseAccelerationTiltDegrees = -1.5`
- `BoostExtraTiltDegrees = 1.0`
- `AccelBrakeTiltMaxDegrees = 5.0`
- `AccelBrakeTiltSmoothing = 7.0`
- `AccelBrakeTiltThrottleDeadzone = 0.05`
- `BrakeTiltForwardSpeedMph = 4.0`
- `AccelBrakeTiltDebugAttributes = true`

Tuning guidance:

- If acceleration/braking tilts the wrong direction, flip the sign of the matching degrees value.
- Raise `AccelerationTiltDegrees` for more nose-up launch feel.
- Make `BrakeTiltDegrees` more negative for stronger braking dive.
- Adjust `ReverseAccelerationTiltDegrees` separately if reversing looks odd.
- Raise `AccelBrakeTiltSmoothing` for quicker pitch response; lower it for heavier, floatier motion.
- Lower `AccelBrakeTiltMaxDegrees` if the vehicle feels too animated or toy-like.

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

PC Free-Roam UI Phase 2G connects the isolated desktop boost bar to the existing `MobileDriveInputState.BoostPercent` publication made by `DrivingControllerV47`. Despite the module's historical mobile-oriented name, `PublishMobile` is called from the shared V75 update path for keyboard/gamepad driving as well, so the desktop HUD can consume the same percentage without patching the driving controller or register-limited bootstrap. Phase 2G adds only presentation smoothing; boost drain/recharge authority remains in `DrivingControllerV47`.

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
