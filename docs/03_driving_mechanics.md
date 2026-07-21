# Driving Mechanics

## Loading Transition Input Boundary (Phases 1-5)

Loading/start-screen Phase 1 adds one guarded read seam to `DrivingControllerV47`. `GameplayInputGate` is the sole transition lock owner; while locked, the controller consumes neutral throttle, braking/reverse, steering, drift, boost and reset intent, clears drift charge/mini-boost and publishes non-accelerating/non-boosting/non-drifting attributes. It does not anchor the vehicle, zero velocity, apply a parking force, alter hover forces or replace server teleport/vehicle lifecycle authority.

The gate also clears mobile input and disables default on-foot controls. After the loading cover's `0.3` second fade, held keyboard/gamepad input must return to neutral before controls restore, with a bounded safety timeout. Phase 2 extends the gate to dealership/customisation entry and Drive; Phase 3 extends it to owned-garage driven entry and drive-out; Phase 4 extends it to race/time-trial staging and exit-to-start. It still does not stop vehicle momentum or become a vehicle-spawn owner; race/TT reset and ordinary free-roam vehicle spawning/replacement remain explicit exclusions.

Phases 1-5, the readiness-gated countdown and Phase 6 closure are installed/user-confirmed. The refreshed `2026-07-21 10:48:31` mirror contains the configured V1.3 start client and V1.4 Grid3x2 view. These presentation changes retain the same input token while initial loading and PLAY/SHOP are present. They never anchor, brake, spawn or move a vehicle. PLAY/accepted SHOP release through the existing neutral-input rule; rejected SHOP keeps the token and start screen active. The user reports the closure behaviour working as expected, including input recovery; preserve `GameplayInputGate` as the sole transition lock owner.

## Owned Garage Drive-In/Drive-Out Boundary

The approved owned-garage replacement must not introduce another driving or vehicle-spawn owner. Garage entry will ask the existing lifecycle owner to hand off the current saved `VehicleId`, then place that vehicle in an empty display space or a confirmed replacement space. Phase 2 display vehicles are intentionally anchored and seatless. Phase 3 stages an unowned `OwnedGarageVehicleLifecycleBridge` contract for `GetDrivenVehicle`, `DespawnForGarage` and `SpawnFromGarage`; its management module performs assignment rollback if the lifecycle handoff fails. The bridge has no callback and the module is not started yet, so this checkpoint adds no driving connection or Workspace vehicle.

Phase 5 adds a server-authoritative guard to the existing vehicle action owner: while `NTR_OwnedGarageInside` is true, free-roam select/spawn/despawn/exit/re-entry actions return a safe message rather than creating a second vehicle or bypassing the garage display/door flow. The owned garage still does not spawn vehicles itself; Phase 6 will bind its staged lifecycle contract to the existing local vehicle helpers in one atomic activation.

Phase 6 binds that contract inside the existing action owner. Drive-in reads the currently seated saved `VehicleId`, validates speed, and invokes the existing despawn helper only after the display-assignment transaction can commit. Drive-out selects the referenced saved vehicle, invokes the existing builder at the configured city exit, seats the player and mirrors the selected vehicle through the existing persistence adapter. Failed lifecycle calls roll back the display transaction rather than creating a duplicate.

## Stat-scaled post-drift reward (generated 2026-07-14; awaiting Studio test)

`scripts/roblox_driving_drift_mini_boost_stat_scaling.lua` replaces the universal hard-coded reward with bounded charge quality, `BoostForce` acceleration scaling, and mapped `BoostDuration` duration scaling. Normal boost retains priority but no longer pauses/queues the reward timer. Defaults reduce the full reference reward to `72` acceleration before a bounded boost-module multiplier/final `0.85` application multiplier, and cap duration at `0.90 s`.

All new tuning values and descriptions live in `VehicleDynamics_EditAttributes.03_Drifting`. Existing config values are snapshotted and verified unchanged. See `docs/driving-drift-mini-boost-stat-scaling-2026-07-14.md`.

## Roblox-owned default vehicle camera (V6.1 confirmed and mirrored)

Camera V4 and the attempted V5 attachment approach did not improve the reported hitch. The mirrored V4 source also moved the camera position forward by planar velocity prediction; at speed this cancelled much of the requested trailing distance and made the camera move closer while accelerating.

`scripts/roblox_driving_camera_default_vehicle_system.lua` is the canonical replacement. It changes only the isolated `DrivingCameraController` and retains the existing V47 start/stop bridge. During driving it selects `CameraType.Custom` with `DriverSeat` as `CameraSubject`, then Roblox owns all continuous `Camera.CFrame`, collision, orbit, and platform-input work. The NTR controller changes only the player's locked zoom bounds and `FieldOfView`; it writes `Camera.CFrame` once on entry to establish the configured starting angle.

Tune the replacement in `ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DrivingCamera_Default_EditAttributes`. It contains normal/acceleration/high-speed/boost distances and FOVs, speed thresholds, response speeds, initial pitch/yaw/height/look target, zoom lock, trailer-key compatibility, and optional simple diagnostics. Every value has a paired description. The old `DrivingCamera_EditAttributes` folder remains untouched for rollback history and is not read by V6.

See `docs/driving-camera-system-2026-07-14.md` for installation, verification and rollback.

The user confirmed V6 removed the driving hitch. Initial Framing V6.1 then repaired the ineffective one-time angle setup by applying configured framing immediately before Roblox's camera step for only `InitialLookApplyFrames` frames, default `3`. Editing pitch, yaw, height, look-ahead, or look-target height during Play queues the same bounded one-shot operation. The user confirmed the final result looks good, and the `2026-07-17 10:13:20` mirror contains exact V6.1. Preserve this baseline.

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

## 2026-07-13 Driving Feel Rework Audit

The fresh Studio mirror generated on 2026-07-13 at 10:59:59 does not contain the documented `NTR_VEHICLE_PHASE_AM_PHYSICS_BRIDGE` in the active `DrivingControllerV47`, even though `RuntimeIntegration.PhysicsEnabled` remains true and `VehiclePerformanceRuntimeService_Active` still exists. Treat the detailed-physics connection as a live verification issue rather than assuming the June confirmation still matches the current source.

The current source also confirms the reported feel has mechanical causes: initial force uses `Acceleration * 3.1`, the top-speed limiter falls linearly to an `0.08` force floor, brake and reverse share one negative-throttle branch, neutral drag is low, parked hover has no explicit planar settling, the vehicle root remains character-collidable, and exit uses a fixed offset.

The Phase 0 Edit audit passed `11/10/0` (`pass/warn/fail`) and confirmed the mirror findings. The valid client runtime evidence showed a `C 538` vehicle with `EngineOutput 81`, `TopSpeed 139`, `BrakingForce 106`, `Weight 137`, and a collidable `Default` root. The two client Play failures were server-visibility false negatives and the audit now skips those checks in client context.

The condensed rework plan is `docs/driving-feel-rework-plan-2026-07-13.md`. Phase 1 is generated as `scripts/roblox_driving_feel_phase1_core_dynamics.lua`; it installs an isolated dynamics model plus a small guarded controller bridge for detailed stats, progressive acceleration/top-speed approach, coasting, braking, stopped hold, and delayed reverse. Do not rerun the older Phase AM integration installer unchanged against the current controller source.

Phase 1 was installed and user-confirmed working well. The post-confirmation Studio mirror was refreshed at 2026-07-13 12:30:18 and includes the new dynamics module/config plus guarded controller bridge. Phase 2 is generated as `scripts/roblox_driving_feel_phase2_handling_drift_calibration.lua`; it keeps Phase 1 longitudinal behavior and connects detailed grip, drift, downforce, charge, and hover-stability variables through an independently switchable handling model.

Phase 2 was installed and its handling was reported good overall. Its post-install mirror confirmed that poor drift momentum came mainly from the fixed full-blend forward-drag coefficient `1.14`, not the low vehicle Drift stat, and that reverse force was cancelled because stopped velocity snapping continued after Reverse mode began. Phase 2.1 is generated as `scripts/roblox_driving_feel_phase2_1_drift_momentum_reverse_repair.lua`: configurable full-drift forward drag defaults to `0.28`, and stopped hold releases into reverse after a `1.0 s` continuous brake hold.

Vehicle Performance V2 Phase 0 audited the later live config at 2026-07-13 20:11:53. Drift remains at the intended `0.18 + 0.10 = 0.28`, but `ReverseEngageDelaySeconds` is currently `0.3`. The source repair remains installed, so restoring the preferred one-second behaviour is a config-only change; do not stack another source patch for this discrepancy.

Vehicle Performance V2 Phase 1 performs that config-only restoration to `ReverseEngageDelaySeconds = 1.0`. Its new V2 curve/calculator modules remain shadow-only and do not change `VehicleDynamicsModel`, `DrivingControllerV47`, or any live physics factor during this phase.

## Driving Feel Phase 3 tier-safe physical curves

After Vehicle Performance V2 went live, Forge E and Zenith S exposed that the rating curve's diminishing returns were not mirrored by every physics consumer. Raw SteeringResponse (`15–210`) and boost timing (`0.55–6` duration, `14–4` recharge) produced unusably wide feel differences. Acceleration still began at maximum force and only declined, while drift reduced grip heavily and pushed sideways without rotating momentum through the corner.

`scripts/roblox_driving_feel_phase3_tier_curve_drift_drive.lua` is the single consolidated correction. It keeps raw stats and PI unchanged, maps them into bounded physical steering/boost ranges, creates a soft-launch then mid-speed power-band acceleration curve with tier-dependent high-speed pull and quadratic aero resistance, and adds throttle-only force-based drift engine/velocity alignment. Important tuning remains flat attributes under `VehicleDynamics_EditAttributes`; the plain-language map is `docs/driving-feel-phase3-tier-curves-drift-drive-2026-07-14.md`.

Phase 1 subsequently passed `12/0/0` and the refreshed `2026-07-13 20:22:34` mirror confirms the one-second config value. Phase 2 remains shadow-only: its TopSpeed reference, performance origin, rating scale, and six stock profiles affect only `VehiclePerformanceV2Calculator`; detailed live driving factors still use the confirmed V1/Driving Feel path.

Mobile Free-Roam UI Phase 1G is a presentation-only refinement of the isolated mobile car menu. It retains the established `NTRMobileFreeRoamCarMenuOpen` handoff, which clears and hides touch driving inputs while the menu is open and restores them on close. It does not change `MobileDriveInputState`, steering, pedals, boost, drift, Tilt, Thumbstick, or driving physics.

Mobile Free-Roam UI Phase 1K changes only touch-driving presentation: the Boost hit target remains `44/52 px` while its smaller icon sits on a circular boost-bar-colour gradient plate, and Exit is vertically aligned to the steering-cluster bottom through responsive layout math. The Boost action, `MobileDriveInputState`, steering, drift, pedals, Tilt, Thumbstick, speed/boost telemetry values, and physics are unchanged.

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

Mobile Free-Roam UI Phase 1 now supersedes the old thumbstick-only patch ladder
as the next installation path. It canonically supports default digital arrows,
the existing analog thumbstick concept, and gyroscope Tilt through the shared
`MobileDriveInputState` contract without changing physics. Do not rerun the old
V1-V2.4 thumbstick patch scripts after installing Phase 1; use
`docs/ui-free-roam-mobile-phase1-canonical-hud-controls-2026-07-13.md`.

Phase 1B keeps the same input contract and control modes, enlarges the touch
targets, constrains text fallbacks, and turns the shared PC boost icon into the
mobile boost touch target. It changes presentation and exact legacy-HUD
suppression only; steering, drift, throttle, boost, and vehicle physics remain
owned by the same shared input/dynamics paths. See
`docs/ui-free-roam-mobile-phase1b-pc-component-parity-2026-07-13.md`.

Phase 1C leaves the input contract and vehicle dynamics unchanged. It widens the
four arrow touch targets without changing their digital steering/drift actions
and moves the existing boost action to the PC lightning icon centred above the
arrow cluster. Thumbstick and Tilt continue to use the same shared state. See
`docs/ui-free-roam-mobile-phase1c-layout-refinement-2026-07-13.md`.

Phase 1D adds no driving-physics changes. While the mobile car menu is open it
sets `NTRMobileFreeRoamCarMenuOpen`; the existing isolated controls owner clears
held throttle, brake, steering, drift, and boost state and hides its root. Closing
the menu restores controls only if `MobileDriveInputState.IsDriving` remains
true. See `docs/ui-free-roam-mobile-phase1d-pc-parity-car-menu-2026-07-13.md`.

Phase 1E changes car-menu sizing and styling only. The Phase 1D menu-open input
clear/hide/restore contract is unchanged.

Phase 1F also changes car-menu layout and dropdown interaction only; the driving
input clear/hide/restore contract remains unchanged.

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

## 2026-07-14 Organised Driving Tuning

`scripts/roblox_driving_feel_phase3_organized_tuning_values.lua` is the one-stage post-Phase-3 tuning-layout migration. It reads and preserves current live numeric values, creates ordered Acceleration, Handling, Drifting, Boost, Braking/Reverse/Parking, Grip/Hover, and Advanced folders, and places all settings directly on their category as Attributes. Every numeric setting has an adjacent `<Name>_RaisingThisDoes` string explanation. The dynamics module and controller read these category Attributes directly with legacy flat-attribute fallback. The installer accepts the original Phase 3 layout or the superseded per-setting-folder layout, preflights both related exact-source anchors before hierarchy mutation, and removes obsolete layouts only after verification. Boolean switches and metadata remain at the root.

The organiser now also owns the physical TopSpeed mapping. Raw V2 TopSpeed remains the rating/module input; physics uses a configurable reference/exponent curve plus editable minimum, maximum, and absolute safety values. This replaces the raw-stat-as-MPH behavior and the hidden `260 MPH` controller/module clamps. Existing acceleration attributes are never reset: the `2026-07-14 10:29:30` pre-patch mirror records the user's live values and installer reruns prefer those category attributes over defaults.

## Owned Garage Vehicle Transition Boundary

`scripts/roblox_owned_garage_phase8_transition_completion.lua` does not replace normal free-roam despawning or driving physics. It adds options used only by `DespawnForGarage`: keep the character at the current position, destroy the owned live vehicle, wait up to the configured detachment timeout for `Humanoid.SeatPart` to clear, and return explicit `VehicleRemoved`/`Detached` evidence. Management teleports only after that handshake and verifies the character is within `GarageTeleportVerifyDistanceStuds`, retrying up to `GarageTeleportAttempts` before activating the interior.

On failure, the transition restores the authoritative display assignment before respawning the captured vehicle whenever necessary. If assignment restoration itself fails, it leaves the vehicle stored rather than creating a live/display duplicate. Normal `V92_despawnVehicle(player)` callers keep their existing move-beside-vehicle behaviour because they pass no garage options.

## Current Diagrams

- `diagrams/driving_runtime_system.svg`
