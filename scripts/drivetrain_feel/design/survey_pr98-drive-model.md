# PR98 driving model: read-only research report

**Scope.** I read DrivingClient (1605 lines), VehicleDynamics (300), DriveTuning, DriveSessionClient, MobileDriveInputState and GameplayInputGate in full from live Studio PR98 (studio_id 09a86975…). I read every attribute in `Config.Vehicles.{Driving, Dynamics, 01–08, HoverPose, HoverWobble, Camera, DriveRewards}`. I grepped the server for ownership and speed checks. I made no changes.

**Note: the repo export is stale.** `roblox/exported_scripts/ReplicatedStorage/Modules/Game/Vehicles/DrivingClient.module.lua` has 1147 lines against 1605 live. Line numbers in `scripts/driving_tune/CONTRACT.md` refer to an older file. All line numbers below are from live Studio.

---

## 0. Architecture in one paragraph

- `DriveSessionClient.start()` starts `DrivingClient.Start(context)` when the `PlayerScripts.Runtime.UI.FreeRoamVehicleSpawned` BindableEvent fires.
  - Free roam, garage, race queue and race entry all fire that event, so races use the same driver (RaceQueueClient:26, RaceEntryMenuClient:59).
- The context only supplies `GetCamera`, `GetMobileInput`, `PublishMobile` and `SetMobileDriving`.
- `ShowDriveUi` and `UpdateDriveUi` are never supplied. Those calls (DrivingClient:822, 840) are dead, so the HUD only gets data through `PublishMobile`.
- Physics runs entirely on the client:
  - one `RunService.Heartbeat` connection (DrivingClient:1053);
  - the client owns the vehicle (`SetNetworkOwner(player)` in VehicleBuildService:242, VehicleAccessServer:76, VehicleLifecycleService:85/171, MatchmakingServer:190, TimeTrialServer:400, DuelService:298);
  - there is no server-side vehicle physics.

**Instances created in `setupControls` (DrivingClient:222-269):**
- `Drive_ForwardForce`: a VectorForce, `ApplyAtCenterOfMass = true`, `RelativeTo = World`. It carries every planar force.
- `Drive_TerrainYawAlign`: an AlignOrientation, OneAttachment, `MaxTorque = math.huge`, `MaxAngularVelocity = math.huge`, `Responsiveness = 22`, `RigidityEnabled = false`. It owns all orientation.
- `Drive_HoverCornerForce1..4`: VectorForces at ±halfX (≥4) and ±halfZ (≥6) on the root.

**Units.** `MPH_PER_STUD = 0.625` is hard-coded in DrivingClient:21 and VehicleDynamics:4 (also `Config.Vehicles.Spawn.StudsPerSecondToMph`).

---

## 1. How each force is produced (all per Heartbeat, `dt` from Heartbeat)

All planar forces are written as `mass * acceleration`, where `mass = max(root.AssemblyMass, 1)` (line 1086). Mass therefore cancels out, and the physical mass of the assembly has no effect on handling.

When the root is anchored or its mass is infinite or NaN (1067-1085), all forces are zeroed, the Feel state is reset, the HUD shows 0, and the function returns. This is the race-countdown freeze: MatchmakingServer:164 and TimeTrialServer:373 set `root.Anchored = frozen == true`.

**Hover (1145-1196).**
- Four downward raycasts start 2 studs above each corner and run 24 studs (`SENSOR_LENGTH` is hard-coded; DriveTuning's `GroundSensorLengthStuds` is unused).
- Per corner:
  ```
  forceAmount = liftPerCorner + mass*(heightError*heightStiffness - relativeYVelocity*normalVelocityDamping)
  ```
  - `liftPerCorner = mass*g/4`
  - `heightStiffness` is `SlopeHoverHeightStiffness` = 54
  - `normalVelocityDamping` is `SlopeHoverNormalVelocityDamping` = 7
  - the result is clamped to `[0, liftPerCorner*4.5]`
  - a corner whose ray misses gets `liftPerCorner*0.05`
- The target distance is `PoseRideHeight + 2 + Offset.X*PoseRollTerm - Offset.Z*PosePitchTerm` (1179).
- `PoseRideHeight = HOVER_HEIGHT*settle + bankLift + bob` (`updateHoverPose`, 654-758). `HOVER_HEIGHT = Authoring.Driving.HoverHeightStuds` = 2.3.
- `grounded = hits >= 2`.

**Longitudinal (1211-1254).**
- `VehicleDynamics.StepLongitudinal` returns `LongitudinalAcceleration` in studs/s², and the client applies `driveForce += forward * mass * LongitudinalAcceleration` (1224).
- When the step returns `SnapForwardStop`, the client writes velocity directly: `root.AssemblyLinearVelocity = velocity - forward*forwardSpeed` (1228).
- If `Dynamics.Enabled = false`, a legacy fallback runs instead (1233-1253). It is inactive today.

**`StepLongitudinal` equations (VehicleDynamics:203-277).** Values below are effective after the code's clamps.
- `engineFactor = clamp((EngineOutput/40)^0.4, 0.8, 1.2)`
- `weightFactor = clamp((118/Weight)^0.22, 0.82, 1.18)`
- `launchShape = 0.7 + 0.3*smoothstep(fwdMph/10)`
- `engineInfluence`: config `LaunchEngineInfluence` is 1.5, clamped to 1, so the engine factor applies in full from 0 mph.
- `bandStart = 0.48 + 0.37*engineAlpha`, where `engineAlpha = (engineFactor - 0.8)/0.4`
- `highFade = 0.1 + 0.9*(1 - smoothstep((fwdMph/maxMph - bandStart)/(1 - bandStart)))^1`
- `forwardAccel = 80*engineFactor*weightFactor*launchShape*highFade*balance.Acceleration`
  - config `BaseForwardAcceleration` is 90, but the clamp range is 5..80, so it is 80.
- `brakeAccel = 90*clamp((BrakingForce/60)^0.7, .65, 1.65)*clamp((118/W)^0.2, .8, 1.2)*balance.Braking`
  - config `BaseBrakeDeceleration` is 110, clamped to 90.
- `aero (studs/s²) = 0.002*mph*|mph|*clamp((Drag/40)^0.5, .65, 1.45)*balance.Drag / 0.625`
  - config `AerodynamicDragPerMphSquared` is 0.2, but the clamp maximum is 0.002.
- `reverseAccel = 12*engineFactor*weightFactor*balance.Reverse*(1 - |revMph|/40)^0.8`
- Coasting (no input): `-(3.2 + |v_studs|*0.06)`.
- Auto-hold: at ≤3 mph with no input it returns `SnapForwardStop`. With S held at ≤1.5 mph it returns `Stopped`/`Reverse`; `ReverseEngageDelaySeconds = 0`, so reverse engages immediately.
- Soft limiter above `maxMph`: `-(mph - maxMph)/0.625*0.1` (`SoftLimiterStrength` 0 is clamped to 0.1).
- Mode strings are `Forward`, `Braking`, `Reverse`, `Stopped`, `Coasting`.

**Lateral grip (1291-1301).**
- `driveForce += -right * sideSpeed * mass * lateralGrip`. This is a linear damper with **no saturation**: sideways velocity decays at rate `lateralGrip` per second.
- From `StepHandling` (VehicleDynamics:279-298):
  ```
  normalGrip = 6.6*clamp((LG/50)^0.4, .82, 1.22)*downforceFactor*balance.Grip
  ```
  - `downforceFactor = clamp(1 + (DF-50)/50*0.22*min(mph/140, 1), .88, 1.15)`
- `driftGrip = 4*clamp((DriftGrip/50)^0.15, .85, 1.25)`.
- `lateralGrip = lerp(normalGrip, driftGrip, DriftBlend)`.

**Steering and yaw (1255-1559). Yaw is kinematic.**
- The turn rate is:
  ```
  turnRate = (handling/58)*1.08*speedFactor*balance.Steering*speedSteeringMultiplier*(drift ? (1.34 + driftControl/170)*DriftTurnMultiplier : 1)
  ```
  - `handling = BasePhysicalSteeringResponse(44)*clamp((raw/50)^0.1, .78, 1.3)*steeringWeightFactor`, with `steeringWeightFactor = clamp((118/W)^0.12, .88, 1.12)`.
  - `speedFactor = clamp(|fwdMph|/45, 0.35, 1.35)`.
  - `speedSteeringMultiplier = 0.85 + (2 - 0.85)*(1 - clamp((mph-20)/120, 0, 1))^2`. In reverse it is a flat ×3 (`ReverseSteeringUsesSpeedCurve = false`). Boosting multiplies it by 0.7. While drifting it is at least 0.92. `SpeedSteeringSmoothing = 0`.
- Heading update: `state.YawHeading += -steeringInput*turnRate*dt` (1493). There is **no yaw-rate state and no yaw inertia**.
- `Align.CFrame = CFrame.lookAt(pos, pos + terrainForward, groundNormal) * CFrame.Angles(wobblePitch + accelBrakePitch, WobbleYaw, CurrentBank + wobbleRoll)` (1559).
  - `Align.Responsiveness = 22*clamp((HoverStability/50)^0.35, .88, 1.15)`.

**Boost (1392-1423).**
- Applies when Shift (or the gamepad/mobile boost) is held, `Boost > 1`, `forwardSpeed > -4` and `boostPower > 0`:
  ```
  driveForce += forward*mass*(boostPower + 32)*0.75*balance.Boost
  ```
- It does not need throttle and bypasses `StepLongitudinal`.
- The tank drains at `100/boostDuration` per second (duration clamped 0.5..2 s by `04_Boost`). After the delay (0.4–1.0 s) it recharges at `100/boostRecharge` per second (6.5–10.5 s).
- Mini-boost: `driveForce += forward*mass*MiniBoostPower*0.85*balance.MiniBoost`.

---

## 2. Acceleration curve, top speed and HUD curve

**Curve shape.**
- At 0 mph the car has 70% of full pull, ramping to 100% by 10 mph.
- Pull then stays flat until `speed/maxMph` passes `bandStart` (0.48–0.85 of `maxMph`), then fades smoothly to a 10% floor.
- Aero drag grows with speed squared.

**Mapped cap.**
```
TopSpeed = 170*(raw/1)^0.1, clamped to [150, 320]
```
- `TopSpeedRawReference` is set to 0 and clamped to 1, so the exponent of 0.1 collapses every car to roughly 250–310 mph.
- Then `maxMph = clamp(TopSpeed*balance.TopSpeed, 40, 320)` (DrivingClient:1116).

**The real top speed is set by aero drag, not the cap.**
- At equilibrium, `v² ≈ 25000*E*W*highFade*bA/(dF*bD)` mph².
- `balance.Drag = bA/bT²` (`BalanceDragCoupling = 1`, VehicleDynamics:125), which gives `v ≈ 158*bT*sqrt(E*W/dF)`, i.e. about **120–170 mph** across tiers (INFERRED).
- Measured in v3 (`scripts/driving_tune/verification.json`, S-tier Seraph):
  - 0–100 mph in 2.7 s
  - 131 mph after 4.4 s
  - braking 131→0 in 1.9 s
  - modelled top speed 167 mph, 217 with boost
- These numbers are what makes it arcadey: 0–100 in under 3 s, and roughly 56 mph/s of braking.

**Balance (08_Balance).**
- `base = 0.1 + 0.15*ease((PI - 200)/700)`
- `TopSpeed = 1 - base`
- `Acceleration = Braking = Boost = (1 - base)*0.85`
- `Reverse = 1 - base`
- `Steering = 1 - 0.4*base`
- `Grip = 1 - 0.25*base`
- `DriftTurn = DriftEngineAssist = MiniBoost = 0.8` (MiniBoost is also multiplied by `1 - base`); `DriftAlignment = (1 - 0.5*base)*0.8`; `DriftCharge = 0.9`.
- Tier bands are E100, D300, C450, B600, A725, S850 (driving_tune contract).

**HUD speed curve (`updateExistingDriveUi`, 830-846).**
```
display = real*(0.86 + 0.22*smoothstep(real/160))
```
- From `SpeedDisplayLow` 0.86, `High` 1.08, `FullMph` 160. It is display-only.
- It reaches the HUD through `PublishMobile → MobileDriveInputState.SpeedMph/BoostPercent`.
- Readers:
  - `UIPulse.FreeRoam.HudView:399-405` (`gauge.SetSpeed` / `SetBoost` in `UIPulse.Kit.Gauge:319/438`, `SpeedGaugeMaxMph` default 260)
  - `DesktopFreeRoamHudUI:1284-1286`
  - `MobileFreeRoamHudUI:493`
- `FeelSpeedMph` stays the real speed.

---

## 3. How stats map to forces

- **Stat source (`stat()`, 165-174):** a vehicle attribute, or else `TOTAL_STATS_Runtime/<name>`.
- **Detailed raw values:** `RAW_PERFORMANCE_Runtime/<name>` or the `Performance_<name>` attribute (VehicleDynamics:40-46).
- **`ResolveStats`** (129-196) maps TopSpeed, SteeringResponse, DriftControl and the boost timings.

| Stat | Where it ends up |
|---|---|
| EngineOutput | accel 0.8–1.2×, power-band start, reverse, drift engine assist 0.85–1.22× |
| Weight | accel 0.82–1.18×, brake 0.8–1.2×, steering/drift turn 0.88–1.12×. No inertia anywhere. |
| LateralGrip | `normalGrip` 0.82–1.22× |
| Downforce | grip ±, scaled by mph/140 |
| SteeringResponse | 0.78–1.3×, but with exponent 0.1 every car is about the same |
| HoverStability | Align responsiveness 0.88–1.15× |
| DriftGrip, DriftControl, DriftChargeRate | drift grip, side force, turn and charge |
| BrakingForce, Drag, Boost* | as in section 1 |

**What does not exist today.** A grep found no RPM, gear, yaw inertia, weight transfer, oversteer or spin. The only "weight transfer" is visual:
- `AccelBrakeTilt` (accel +2.5°, brake −3.5°, reverse −1.5°, boost +1°, max 5°, smoothing 7) is driven by **throttle input**, not real acceleration (1514-1552).
- The bank (12°, plus 5° when drifting, response 2.2) is driven by **raw steer input** (1494-1504).

**Dead config.**
- `07_Advanced.AerodynamicDragCoefficient` and `AccelerationCurveExponent` are read by nothing.
- Of DriveTuning, only `HoverHeightStuds` is used.
- `cameraConfig()` looks for `Config.Vehicles.CameraAssist`, which does not exist.
- Several `01_Acceleration` and `05` values sit above their clamp limits: `BaseForwardAcceleration` 90 (max 80), `BaseBrakeDeceleration` 110 (max 90), `AerodynamicDragPerMphSquared` 0.2 (max 0.002), `LaunchEngineInfluence` 1.5 (max 1). Raising them further does nothing.

---

## 4. The drift model, and full lock plus full throttle from rest

**Drift entry** (1206):
```
canDrift = DriftHeld and forwardSpeed > 8 and speedMph > 10 and |steer| > 0 and grounded
```
- `DriftBlend` moves toward 1 at rate 5.2.
- `drifting = DriftBlend > 0.12`.

**While drifting:**
- grip blends toward `driftGrip` (about 4);
- forward drag `(0.08 + 0.06*blend)*blend*v`;
- an outward slide force `right*(-steerInput)*mass*DriftSideForce*blend`, where `DriftSideForce = 100*driftControlFactor*balance`;
- with throttle: engine assist `0.7*engineDriftFactor*bal*LongitudinalAcceleration`, plus velocity alignment `(terrainForward*|v| - v)*2*factor`, capped at 25×;
- turn rate ×(1.34 + driftControl/170);
- charge builds to 3.25.
- On release with throttle above 0.05 and charge above 0.72, a mini-boost fires (1334-1390).

**Full lock and full throttle from rest (no drift button).**
- Forward accel is about 56·E·W·bA studs/s² at launch.
- The heading turns even at 0 mph: `speedFactor` floor 0.35 × low-speed multiplier 2 gives ≈ 0.819×0.7×bS ≈ **0.53 rad/s (about 30°/s)**. That rises to about 0.9 rad/s at 30 mph.
- Linear grip keeps the velocity aligned to the heading: side slip is about `v·ω/6.6`, roughly 8° at 30 mph.
- So the car traces a widening circle (radius about 30 studs at 10 mph, about 52 at 30 mph) and **never loses grip or spins**.
- There is no axle concept at all: grip acts at the centre of mass and the heading is commanded directly.

---

## 5. Inputs bound today (`refreshInput`, 336-371)

| Source | Throttle / brake | Steer | Drift | Boost | Reset |
|---|---|---|---|---|---|
| Keyboard | W/Up = +1, S/Down = −1 | A/Left, D/Right | Space (also blocks jump, priority 4000) | LeftShift/RightShift | R (priority 6000) |
| Gamepad | R2 analog, L2 analog | Thumbstick1 X (deadzone 0.12) | ButtonB | ButtonA | ButtonY |
| Touch | Accelerator / Brake buttons | TurnLeft/TurnRight, thumbstick, or tilt (smoothing 10) | DriftLeft/DriftRight, or thumb ring (enter 0.95, exit 0.88) | Boost button | — |

- All sources are summed and clamped: `throttle = clamp(kb + R2 - L2 + mobile, -1, 1)`. Holding R2 and L2 together cancels out.
- Touch controls are defined in `MobileDriveControlsClient:82-105` and duplicated in `UIPulse.FreeRoam.TouchControlsClient:66`.
- **Smoothing:** none on throttle or steer (keyboard is instant ±1). Only DriftBlend, bank, tilt and Align responsiveness are smoothed.

**Keys already taken.**
- Camera: P, C, V suspend, B resumes (DrivingCameraClient:659-661); right mouse orbits; Thumbstick2.
- Map: M and ButtonSelect toggle it; E, Q, F, C act only while the map is open.
- Prompts: E / ButtonX (vehicle access, garage, jobs, time trial); F (passenger).

**Free while driving (INFERRED from greps):** Q, Z, X, G, T, LeftCtrl; gamepad ButtonL1/ButtonR1 (only used inside map and UI menus) and DPad.
- New shift keys must be added to `GameplayInputGate.watchedKeys` / `watchedGamepad` (lines 13-24) and gated by `GameplayInputGate.IsLocked()`.

---

## 6. Feel attributes (publishFeelState, 848-958)

- Written every Heartbeat on the vehicle Model, client-local, quantised. Switched by `Driving.FeelStateEnabled`; cleared in `Stop`.
- Names: `FeelThrottle`, `FeelSpeedMph`, `FeelSlip`, `FeelBoostCharge`, `FeelBoostKind`, `FeelDriftCharge`, `FeelGrounded`, `FeelHover`, `FeelImpactRevision/Strength/X/Z`, `FeelLandRevision/Strength`, `FeelPopRevision/Strength`, `FeelScrape`. Meanings are in `scripts/hover_feel/CONTRACT.md`.
- `FeelSlip = sideSpeed/|v|` and is **0 below 8 mph**, so a low-speed spin would currently be invisible to audio and VFX.
- Pops: one bang plus 3–6 crackles when throttle drops to ≤0.1 after at least 0.8 s at throttle >0.6 above 40 mph.

**Who reads them:**
- **VehicleAudioClient**:
  - reads throttle, slip, drift charge, hover and boost kind (848-853), and pop/impact/land (1037-1056);
  - engine rev is `RevThrottleWeight*load + RevSpeedWeight*speed/RevReferenceMph + boost` (882), with no RPM concept.
- **VehicleVFXClient**: 579-771.
- **DrivingCameraClient**: impact and land, 232/433-448.
- **Remote cars:**
  - they only get the discrete `VehicleAudioStateContract` (`Drive = Idle/Accelerating/Braking/Reversing`, cues), with no gear or RPM;
  - adding gear or RPM there would mean a contract and server change, or a shared pure function of replicated speed.

---

## 7. Server-side checks (none are physics authority)

- `DriveRewardsServer:342`: rejects segments faster than `MaximumAcceptedSpeedStudsPerSecond` 540 (about 337 mph) plus 12 studs of tolerance.
- `RaceIntegrity:49-51`: limit is `max(400, 1.25*max(AbsoluteTopSpeedSafetyMph, PhysicalTopSpeedMaxMph))` mph. Mode is Off/Log/Enforce. Also used by DuelService:643.
- `VehicleSpawnService:190` (`MaxSpawnSpeedMph`) and `OwnedGarageManagement:272` (`DriveInMaxSpeedMph`).
- `VehicleCollisionServer:130-141`: pass-through collision group above 20 mph, back below 16 mph.
- `VehicleLifecycleService:104-122`: exit-coast hands velocity over.
- There is no anti-cheat module.

---

## 8. Where each change would hook in, and what must be preserved

**A. Virtual gearbox (rpm, ratios, shift timing with torque cut).**
- **Engine curve.** Replace `launchShape*highFade` in `VehicleDynamics.StepLongitudinal` (lines 231-244) with:
  - `gearTorque(rpm)*ratio[gear]`;
  - `rpm = clamp(fwdMph/gearTopMph[gear], idle, redline)`;
  - a torque cut multiplier while `ShiftTimer > 0`.
- **Gear state.** Pass and return it the way `ReverseHoldTimer` already is (params at 1211-1220, write-back at 1223). Add `state.Gear/Rpm/ShiftTimer` to the state table (24-86) and reset them in Start (1003-1033), Stop (962-984), ResetVehicle (1581-1594) and the anchored branch (1068-1085).
  - The anchored branch is the natural place for neutral revving during the race countdown.
- **Knock-on effects to decide:**
  - A torque cut also reduces drift engine assist (1317-1318).
  - Boost (1401) and mini-boost (1408) bypass the gearbox. That is a design decision.
  - Reverse should map to R through the existing Reverse path (`ReverseMaxMph` 40).
  - The Balance drag coupling (VehicleDynamics:122-125) assumes the top speed is drag-limited with a consistent shape, so a top gear must keep that true.
- **Config.** Put new tuning in a new category such as `Dynamics.09_Gearbox` using the existing `numberAttribute` clamps.
  - The categorised caches (VehicleDynamics:12-27; DrivingClient:396-413) are built once per folder, so new categories need a Play restart (INFERRED).
- **Publishing.** Add `FeelRpm`, `FeelGear` and `FeelShiftRevision` (next to 923-930). Extend `PublishMobile` and `MobileDriveInputState` with Gear/Rpm for HudView and Kit.Gauge.
- **Manual shifting inputs.** `refreshInput`, plus a mobile `State` entry and button.

**B. Heavier feel.**
1. Add steer smoothing (rate-limit keyboard steer) after `refreshInput` (1062).
2. Add a yaw-rate state with inertia scaled by Weight, replacing the direct integration at line 1493.
3. Make grip saturating: cap lateral acceleration at about μ·g, scaled by Weight and Downforce, at line 1298, and lower `BaseNormalLateralGrip` (6.6).
4. Drive the pitch and roll targets from actual acceleration (`dynamicsStep.LongitudinalAcceleration` and `v·ω`) instead of throttle and steer input (1496, 1520-1528).
5. Lower the launch and brake rates. This needs the clamp ranges in VehicleDynamics raised or lowered, because several configs already exceed them.
- Changing Align responsiveness (22) also affects hover pitch and roll; treat it with care.

**C. Low-speed spin-out.**
- Insert a block between `StepHandling` (1291-1298) and the yaw integration (1428-1493).
- When `|fwdMph|` is below a threshold, `|steer|` is above s₀ and throttle is above t₀ (optionally also on throttle rising quickly, scaled by the engine-to-weight ratio):
  - drop rear grip, i.e. the multiplier on `lateralGrip`;
  - add an oversteer yaw rate in the direction of the steer, with decay;
  - recover on throttle lift or counter-steer.
- Keep it out of the drift path: drift requires more than 10 mph and DriftHeld, so it does not overlap below 10 mph.
- Add a `FeelSpin` attribute or lower the 8 mph `FeelSlip` floor.
- The camera follows body heading, with slip-follow only when `forwardSpeed > 0` and capped at ±60° (DrivingCameraClient:482-506). It cuts when the heading changes by more than `max(0.5 rad, 8·dt)` per frame (484). A spin will whip the camera, so it may need a spin mode.
- Auto-hold snap at ≤3 mph only zeroes forward velocity (1227-1231).

**Behaviour that must be preserved:**
- **DRIVE-01 steering intent (1255-1285).** User-confirmed on 2026-09-26:
  - forward throttle takes yaw immediately during a three-point turn;
  - braking keeps the forward profile;
  - `SteeringCoastAssumeForward` with 8 mph reverse latch;
  - reverse steering ×3 with inverted input;
  - bank uses raw steer.
- **Standstill steering** (`speedFactor` floor 0.35), which was verified in driving_tune.
- **Balance nerf** at every place it is applied:
  - TopSpeed: DrivingClient:1116
  - Acceleration, Braking, Drag, Reverse: inside `StepLongitudinal`
  - Steering: 1429
  - Grip and Drift*: inside `StepHandling`
  - Boost: 1401
  - MiniBoost: 1408
- **HoverPose, HoverWobble and `FeelHover` semantics.**
- **The Feel contract**, including `FeelSpeedMph` as real speed.
- **The mini-boost throttle rule.**
- **driving_tune rules:**
  - no per-frame allocation, raycasts or GetDescendants;
  - every new behaviour has a switch;
  - frame-rate-independent smoothing and NaN guards.
- **Speed headroom:** rewards reject above 337 mph and races above 400 mph.