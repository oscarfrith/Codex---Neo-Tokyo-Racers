# physics part: DrivingClient and VehicleDynamics (drivetrain_feel)

Owner of CONTRACT sections 3 (producer side), 4 (config) and 5. Files:

- `physics/after/DrivingClient.lua` (2132 lines, 101,808 chars) and `physics/after/VehicleDynamics.lua` (1056 lines, 69,632 chars): full sources, started from `before/`.
- `physics/config.py`: `INSTANCES` creates `ReplicatedStorage.Config.Vehicles.Drivetrain` (Enabled 1, DrivetrainFeelInstalled true, Notes) with the child Folder `exotic` (119 numbers, each with a `_RaisingThisDoes` string, plus `GearRatios`, `TorqueCurve` and `Notes`). `ATTRIBUTES` is empty.

**Status:** generated and compile-checked only (Studio Edit `loadstring` via the 8797 bridge: both `OK`). Nothing is installed, and nothing has been driven in Play.

## 1. What changed and where

Line numbers are from the after files.

### VehicleDynamics

| Where | Change |
|---|---|
| `Model.ResolveStats(vehicle, legacy, quiet)` (130) | New optional `quiet`. When true, it skips the two debug `SetAttribute` blocks. Remote cars use it. Existing callers pass nothing, so nothing changes for them. |
| `Model.StepLongitudinal` (204-283) | At 257-262, after every old local is computed: when `params.Drivetrain` is present with `Active`, `Profile` and `Tuning`, it returns `Model.StepDrivetrain(...)`. Without that field the old lines run unchanged. |
| `Model.StepHandling` (286-305) | The result table gains `NormalGrip` and `DownforceFactor`. Existing fields are unchanged. |
| 307-358 | Constants, `DRIVETRAIN_NUMBERS` (attribute, default, min, max) for all 112 numeric settings, `DRIVETRAIN_SWITCHES` (6 switches), caches. |
| `drivetrainRoot`, `switchOn`, `parseRatios`, `parseCurve`, `curveAt`, `profileTorque`, `rebuildTuning` (360-456) | Tuning parse. Strings are parsed only when their text changed. Coupled clamps: `LimiterRpm` within [R, 1.2R], `IdleRpm` ≤ 0.5R, `UpshiftPartHigh` ≥ `UpshiftPartLow`, `TierFullPI` > `TierStartPI`, `BrakeFactorMax` ≥ `BrakeFactorMin`, `YawWeightMax` ≥ `YawWeightMin`, `SpinMaxYawRate` ≤ `YawRateMax` ≤ 5. |
| `Model.DrivetrainCategory(vehicle)` (458) | Lower-case `CategoryId`. Fallback: the `CockpitId` prefix before `_`. Confirmed live: `VehicleBuildService` 270-271 sets `CategoryId = profile.CurrentCategory` ("exotic") and `CockpitId` ("exotic_01"). `VehiclePerformance` 36 sets `PerformanceIndex`. |
| `Model.DrivetrainTuning(categoryId, force)` (469) | One tuning table per class, shared by local and remote cars. Re-read at most every 0.25 s with `GetAttributes()`. Change detection compares every value and the count; only on change does it rebuild and bump `Revision`. `Active` = class folder present, its `Enabled` ≠ 0, and `Drivetrain@Enabled` ≠ 0. A missing switch counts as 1; a boolean is accepted. |
| `profileStale`, `buildProfile` (505-617) | Implements CONTRACT 5.1, detailed in section 2b. |
| `Model.DrivetrainProfile(vehicle, stats, balance, maxMph, quiet)` (619) | Per-vehicle cache with weak keys. Category, tuning and PI are re-checked every 0.25 s. Rebuilt only when the key changes: tuning revision, PI, maxMph, Balance (Acceleration, Drag, Boost, Braking), or stats (EngineOutput, Weight, BoostForce, Drag, BrakingForce, LateralGrip). Quiet (remote) callers have a separate cache. Returns nil when the class is not active. |
| `Model.DrivetrainSelectGear`, `Model.ResetGearbox`, `Model.LaunchGearbox`, `beginShift`, `cutIntegral`, `stepLimiter`, `upshiftPoint` (646-735) | Gearbox helpers. Revision counters are never reset. |
| `Model.StepDrivetrain(...)` (737-957) | The per-frame step (CONTRACT 5.2), detailed in section 2c. Writes into `drive.Result` in place, with no allocation. |
| `Model.StepNeutral(drive, dt, throttle)` (959-988) | Neutral revs while anchored. |
| `Model.GearForSpeed(vehicle, speedMph, accelerating, braking, previousGear)` (990-1054) | For remote cars (CONTRACT 3.3), detailed in section 3. |

### DrivingClient

| Where | Change |
|---|---|
| 88-124 | `Drivetrain` session table, created once and changed in place: `Gearbox`, `Result`, `Chassis`, `Spin`, `FeelCache`, `DebugCache`, the preallocated `Telemetry`, and the step inputs. Also the constants `G_STUDS`, the spin yaw gate (0.15 / 0.35 rad/s), `DRIVETRAIN_FEEL_ATTRIBUTES`, `GEAR_TEXT`, and `approachSteer`. |
| `refreshInput(dt)` (374-430) | Now returns `throttle, steer, rawSteer`. `rawSteer` is the old sum. When active, the keyboard part and the touch part (`GetMobileInput`) are each rate-limited, and the gamepad stick is added untouched. When inactive, `steer = rawSteer`. Records the power-brake input (W+S, or R2+L2 above 0.5), the analog-throttle flag and the touch flag. A gate lock sets `ResetPending`. |
| `updateExistingDriveUi` (889-910) | `PublishMobile(speed, boost, Drivetrain.Telemetry)` only on frames where telemetry was filled. Otherwise it makes the old two-argument call. |
| `FEEL_ATTRIBUTES` (912-913) | The 16 new Feel names are appended, so `Stop` clears them. |
| `publishFeelState` (~940-948, ~993-996) | On an impact event while active, adds the yaw kick (section 2d). The `FeelSlip` floor is 2 mph while active and 8 mph otherwise. |
| Helpers (1032-1409) | `setFeel` and `setDebug` (write on change), `clearDrivetrainFeel`, `resetDrivetrainChassis`, `refreshDrivetrain`, `drivetrainResume`, `drivetrainGestures`, `springStep`, `drivetrainLateral`, `updateSpin`, `drivetrainYaw`, `drivetrainPitch`, `drivetrainRoll`, `publishDrivetrain`, `drivetrainAnchored`. |
| `Controller.Stop` (1411-1440) | Resets the `Drivetrain` session state and clears its caches. The Feel attributes are cleared with the rest. |
| `Controller.Start` (1488-1495) | `refreshDrivetrain(vehicle, true)`, then a chassis and gearbox reset (first gear, idle, grace starts). |
| Heartbeat (1515-2100), every addition guarded | 4 Hz refresh tick. Active-only `TelemetryReady` reset. `refreshInput(dt)`. `drivetrainAnchored` in the anchored branch. Profile fetch and `drivetrainResume` after `maxMph`. Gestures and step inputs before `StepLongitudinal`, which gets `Drivetrain = driveActive and Drivetrain or nil`. Lateral grip. Drift engine assist from `DriveThrust`. Boost and mini-boost multiplied by `BoostShare` (and `BoostAccel` recorded). Yaw via `drivetrainYaw`. Bank on `rawSteer`. Pitch via `drivetrainPitch`. Roll added in the Align CFrame. `publishDrivetrain` after `publishFeelState`. |
| `Controller.ResetVehicle` (2104-2120) | Chassis reset and `ResetPending` (first gear at idle on the next frame). |

**Inactive path.** With no class folder, `Enabled` 0, or `Drivetrain@Enabled` 0, every new branch is skipped and each old line runs with the same values. The additions on that path are:
- the 4 Hz attribute read in `refreshDrivetrain`, which has no side effects;
- the extra nil `Drivetrain` key in the `StepLongitudinal` params;
- the `rawSteer` local;
- 16 more `SetAttribute(name, nil)` calls in `Stop`, which do nothing on attributes that don't exist.

## 2. The model as built

### 2a. Feel dials (CONTRACT 4.1): exact mapping

W = `FeelWeight`, Gr = `FeelGearing`, A = `FeelAcceleration`, Gp = `FeelGrip`, S = `FeelSpin`, E = `FeelEngineBrake`.

| Dial | Parameter | Exact mapping | Dial at 0 |
|---|---|---|---|
| W (0..2.5) | Keyboard steer build time | `SteerRiseSeconds × W` (time) | instant (today) |
| W | Keyboard steer return rate | `SteerReturnRate / clamp(W, 0.05, 1)`: unchanged at W ≥ 1, sharper below | instant (today) |
| W | Touch steer rate | `TouchSteerRate / clamp(W, 0.05, 1)` | instant (today) |
| W | Yaw spring ω | `YawOmega × clamp((WeightRef/Weight)^YawWeightExponent, YawWeightMin, YawWeightMax) / max(W, 0.05)` (stiffness), × `YawUnwindScale` while unwinding, × spin authority, floored at 1 rad/s | spring bypassed outside a spin: r = today's command exactly |
| W | Grip build distance | `GripRelaxStuds × W` studs (time-like) | instant |
| W | Pitch target | `PitchDegreesPerG × W × g_long` (amount), clamped to ±`PitchMaxDegrees` | the old throttle-driven `AccelBrakeTilt` block runs instead (today) |
| W | Roll target | `RollDegreesPerG × W × g_lat × (1 − DriftBlend)` (amount), clamped to ±`RollMaxDegrees` | 0 (today has none) |
| W | Brake deceleration | `today + (BrakeV2 − today) × W`, clamped to [0.35 × min(today, BrakeV2), max(today, BrakeV2)] | today's brake |
| Gr (0..2) | Gear torque steps | `mult_g = (r_g / r_1)^(GearTorqueExponent × Gr)` | the same thrust in every gear |
| Gr | Torque curve depth | `τ_eff(x) = 1 + (τ(x) − 1) × min(Gr, 1)` | flat at the peak (CVT) |
| Gr | Upshift cut length and blend | `ShiftCutSeconds × Gr`, `ShiftBlendSeconds × Gr` (time) | no cut |
| Gr | Upshift cut depth | kept torque = `clamp(1 − (1 − ShiftCutTorque) × Gr, 0, 1)` | 1 (no cut) |
| Gr | Rev-drop time after an upshift | `clamp(ShiftRpmSeconds / max(Gr, 0.05), 0.005, 1)` s (stiffness) | 1 s glide |
| Gr | Published shift strength (camera nod, VFX vent, audio crackle) | `strength × min(Gr, 1)` for Up and Down (Launch unscaled) | 0 |
| A (0.5..1.5) | Engine thrust, all gears | `A1 × A`. Kd is re-derived from the dialled thrust, so the top speed stays Vt. | n/a (lower bound 0.5) |
| Gp (0.6..1.6) | Traction and grip limit | `Traction × Gp`, `LateralCapBase × Gp` (the grip-limited yaw cap follows the lateral cap) | n/a (lower bound 0.6) |
| S (0..2.5) | Spin readiness and violence | target `L_t × S` (then clamped 0..1), `SpinYawAccel × S` | never spins (L_t = 0) |
| E (0..2) | Engine braking | `EngineBrakeDecel × E × (mult_g / mult_top) × (0.35 + 0.65 × min(rpm/R, 1))` | coasting is drag and rolling only |

At 0, the weight, gearing and spin dials each reproduce today's behaviour for their own aspect. The lateral grip cap and the yaw cap belong to `FeelGrip`, which has no 0 end, so they stay active at W = 0.

### 2b. Profile (`buildProfile`, CONTRACT 5.1)

- **Vt and Vb.** A 40-step bisection of today's `StepLongitudinal` forward-minus-aero (plus the soft limiter above maxMph) at full throttle. It reads the same `Dynamics` config and clamps, and is solved without boost (Vt) and with today's boost `(BoostForce + 32) × 0.75 × bBoost` (Vb).
- **Gear redline speeds.** `V_g = Vt × TopGearOverspeed × r_top / r_g`.
- **Thrust.** `A1 = BaseForward × engineFactor × weightFactor × bAccel × FeelAcceleration`, today's plateau.
- **Traction.** `(TractionG + TractionTierBonusG × tier) × 35.1 × clamp((LG/50)^TractionGripExponent, 0.9, 1.15) × FeelGrip`, where `tier = smoothstep((PI − TierStartPI) / (TierFullPI − TierStartPI))`.
- **Drag.** `Kd = max(min(A1 × mult_top × τ_eff(1/Over), traction) − Rb − Rs × Vt/0.625, 0.5) / Vt²`.
- **Boost share.** `BoostShareHigh = clamp((Kd × Vb² + Rb + Rs × Vb/0.625 − topEngine(Vb)) / boostToday, BoostShareMin, 1)`. With Overdrive, `topEngine(Vb)` is held at `A1 × mult_top × τ_eff(1)` past top-gear redline; without it, it is scaled by the limiter duty. `share(v) = 1 − (1 − BoostShareHigh) × smoothstep(mph / Vb)`. `BoostShapeEnabled` 0 gives a share of 1.
- **BrakeV2.** `BrakeDecel × clamp((BrakingForce/60)^BrakeForceExponent, BrakeFactorMin, BrakeFactorMax) × clamp((118/W)^0.2, 0.8, 1.2) × bBraking`.
- **Lateral cap base.** `LateralCapG × 35.1 × clamp((LG/50)^LateralCapGripExponent, 0.85, 1.2) × FeelGrip`. Each frame it is multiplied by StepHandling's `DownforceFactor` and `balance.Grip`.
- **Spin tier scale.** `SpinTierFloor + (1 − SpinTierFloor) × tier`.
- **Debug attributes on rebuild** (only when `Dynamics@DebugAttributes` is on and the caller is not quiet): `DynamicsDesignTopMph`, `DynamicsBoostTopMph`, `DynamicsGearRedlineMph` (e.g. "47/68/89/..."), `DynamicsTraction`, `DynamicsDrivetrainDrag`, `DynamicsBoostShareHigh`, `DynamicsBrakeV2`, `DynamicsLateralCapBase`.

### 2c. Per-frame step (`StepDrivetrain`, CONTRACT 5.2 with every critique fix)

**Mode** follows today's rules. Auto-hold `SnapForwardStop` is gated: it does not fire while spin > 0.05 or horizontal speed > 4 studs/s; the car coasts on the signed resistances instead. Reverse and Stopped modes use today's equations, including today's aero and reverse limiter.

**Gear selection**
- R while reversing, or while still rolling back after reversing.
- First gear below `StopGearMph`.
- Otherwise the gear that suits the speed, then the brain.
- Road speed = forward speed blended to |v_horizontal| by DriftBlend (fix 3).

**Brain.** Shifts need `ShiftMinIntervalSeconds` since the last one.
- **Hold.** No shifting while DriftBlend > 0.3 or spin > 0.1, except an upshift at x ≥ 1, which is also allowed with no throttle (fix 3).
- **Upshift points**
  - Flat (≥ 0.9): x ≥ `UpshiftFlat`.
  - Part (0.3-0.9): x ≥ lerp(`UpshiftPartLow`, `UpshiftPartHigh`).
  - Cruise (`CruiseThrottleMin` < thr < 0.3): x ≥ `UpshiftCruise` and it must land ≥ `UpshiftMinLand`.
  - None at thr ≤ `CruiseThrottleMin`.
  - Part and cruise upshifts also wait `LiftHoldSeconds` after the throttle was last below `CruiseThrottleMin` (fix 4).
- **Downshifts**
  - Braking: one gear when it lands ≤ `DownshiftBrakeLand`.
  - Coasting: one gear at x < `DownshiftCoastFraction` when it lands ≤ `DownshiftCoastLand`.
  - Kickdown: throttle ≥ `KickdownThrottle` held `KickdownHoldSeconds`, at x < `KickdownBelowFraction`. It drops to the lowest gear that lands ≤ `KickdownLand`.
  - Lug (my addition): throttle held at x < 0.2 drops one gear when it lands ≤ `DownshiftCoastLand`.
  - No torque cut on any downshift: rev-matched rise over `DownshiftBlendSeconds` (fix 4).
- **Strength.** 1 flat out, 0.3 + 0.7 × thr on a part-throttle upshift, 0.5 on a downshift. Then × min(Gr, 1).

**Rpm**
- Target = road rpm.
- Launch: in first gear, `max(·, I + thr × (LaunchRpmFraction × R − I))`. During the power-brake hold thr is taken as 1.
- In a spin, it blends to the free-rev target `max(0.85 × R × thr, I)` by smoothstep(L/0.3) (fix 3).
- Then × (1 + `ThrustSlipFlare` × min(ws_eff, 0.5)), capped at `LimiterRpm`.
- The engine follows the target through `1 − exp(−dt/τ)`:
  - rise τ = `EngineRiseSeconds`;
  - fall τ = × `EngineFallScale`;
  - after an upshift, τ = the rev-drop time;
  - after a downshift, the rise τ = `DownshiftBlendSeconds`.

**Thrust** (throttle applied once, linear; fix 1)
- `raw = A1 × mult_g × τ_eff(rpm/R) × thr`.
- `ws = max(raw/traction − 1, 0) × (1 − TractionAssist) + extraSlip`. ws is 0 unless the mode is Forward, fwdMph ≥ −1 and the steering intent is 1 (fix 2).
- `thrust = min(raw, traction) × (1 − (1 − SlideGripFraction) × smoothstep(ws/0.6))`.
- Then × shift factor × (1 − limiter cut) × (1 − `SpinThrustLoss` × L).

**Cuts** (time-weighted across the frame; fix 5)
- **Upshift cut.** The multiplier is `ShiftCutTorque'` for `ShiftCutSeconds'`, then a linear ramp over `ShiftBlendSeconds'`. Each frame applies its exact average over [t, t + dt], computed from the closed-form integral. Load uses the same timeline with 0 during the cut.
- **Limiter.** While road rpm ≥ R (R − hysteresis once engaged) with throttle: drive for `LimiterOnSeconds`, then cut for `LimiterCutSeconds`, repeating. The cut share of each frame is exact at any frame rate. During a cut the rpm target drops to R − 2 × hysteresis, so the needle bounces. `LimiterRevision` +1 per cut.

**Overdrive** (fix 6). When boost or mini-boost was applied last frame, in top gear, at x ≥ 1 (0.98 once engaged): rpm pinned at R, torque τ_eff(1), no limiter. `Result.Overdrive` is true.

**Resistance** (signed; fix 2)
- `acc = −sgn × (Kd × mph² + RollingDecel + RollingDecelPerStud × |v|) − engineBrake`, with sgn = v / max(|v|, 0.8).
- Engine braking applies only when not in Forward mode, gear ≥ 1 and fwdMph > 0, × (1 − shift cut).
- Forward adds thrust.
- Braking subtracts sgn × brake × |thr|, using the W-blended brake.

**Guard.** Above min(maxMph, `SpeedGuardOverBoostTop` × Vb): `acc −= (mph − guard)/0.625 × SpeedGuardStrength`. The reverse limiter is today's.

**Boost.** `Result.BoostShare` is used in DrivingClient on both the boost and mini-boost lines (fix 6).

**Outputs.** The old fields plus `Drivetrain`, `DriveThrust` (gross), `Gear`, `Rpm`, `Load`, `ThrustSlip`/`WheelspinExcess` (ws_eff), `Cut`, `LimiterActive`, `Overdrive`, `BoostShare`, `PlannedUpshift`, `RoadRatio`. NaN guards apply on acceleration, rpm and the inputs.

**Neutral** (`StepNeutral`; fix 9)
- Gear 0. Rpm follows `I + thr × (NeutralRevTarget × R − I)`, with the same bouncing limiter on engine rpm. `NeutralRevEnabled` 0 holds idle.
- Load = thr × (1 − cut). No forces.
- DrivingClient does not set `Accelerating` there.
- On unanchor (`drivetrainResume`):
  - `LaunchGearbox`: first gear, a "Launch" event with strength = throttle, rpm kept;
  - a launch slip of `PowerBrakeDumpSlip × smoothstep((rpm/R − 0.5)/0.4)`, fading over `SpinWindowSeconds`;
  - the chassis reset, which restarts the grace.
- The grace also restarts when `DriveReady` goes from false to true (checked at 4 Hz), so it runs from whichever comes later.

### 2d. Chassis and spin (DrivingClient)

**Steering limit** (in `refreshInput`)
- Keyboard: `approachSteer` builds toward ±1 at 1/(`SteerRiseSeconds` × W) and returns or crosses centre at the return rate.
- Touch: at `TouchSteerRate`.
- Gamepad: summed unlimited.
- `rawSteer` (the old sum) drives the bank (DRIVE-01), the stab gesture and counter-steer detection.

**Lateral** (`drivetrainLateral`, replacing the old line when active)
- `target = cap × sin(C × atan(−side × normalGrip / (cap × C)))` with C = `LateralCurveShape`. The slope at 0 equals today's damper, it peaks at the cap at a finite slip, and it slides at sin(Cπ/2) × cap.
- × (1 − `SpinGripLoss` × L).
- Filtered over `GripRelaxStuds × W` of travel (`1 − exp(−dt × max(|v|, 8)/relax)`).
- With `DriftCapExempt`: `applied = lerp(filtered, −side × lateralGrip(today, drift-blended), DriftBlend)`, so at full drift it is exactly today's drift grip. With `DriftCapExempt` 0, the cap also shapes the drift-blended grip.

**Yaw** (`drivetrainYaw`, replacing `YawHeading += −steer × turnRate × dt`)
1. r_cmd = today's full turn rate.
2. Grip cap on forward intent above 8 studs/s: `|r_cmd| ≤ YawCapMargin × cap × (1 + 1.5 × DriftBlend) / v`. With `DriftCapExempt` it is lerped back to uncapped by DriftBlend, so drift yaw is unchanged.
3. Second-order spring, sub-stepped. ω is from section 2a; ζ = `YawDamping`.
4. The spin push is added to dr/dt only while r × dir > 0 and |r| < `SpinMaxYawRate`.
5. Kinematic blend: `r = r_cmd + (r − r_cmd) × max(smoothstep(mph / YawKinematicBelowMph), spinBlend)`, where spinBlend = smoothstep(L/0.25) and falls with τ = `SpinSettleSeconds`. Parking, U-turns and standstill steering stay exactly today's, and after a catch the car eases back over `SpinSettleSeconds`.
6. Clamp |r| ≤ `YawRateMax` (≤ 5), so the camera never hard-cuts. `YawHeading += r × dt` (raw dt, as today).

**Impact kick.** On a FeelImpact event: `Δr = ImpactYawKick × push.X(car space) × toward.Z / 100`, clamped to ±3, applied next frame. A push on the nose turns the car the way it was pushed; a push on the tail turns it the other way.

**Spin** (`drivetrainGestures`, then `updateSpin`)
- **Gestures**
  - Stab: throttle from < 0.3 to ≥ 0.9 within `SpinStabSeconds` (0.6/`SpinAnalogRate` s when the gamepad trigger is the throttle), |rawSteer| ≥ `SpinStabSteer`, speed < `SpinBelowMph`.
  - Power-brake: W+S (or R2+L2) at < `StopGearMph` for ≥ `PowerBrakeMinHold`, then S released with throttle > 0.5. The force stays cancelled exactly as before. The release adds `PowerBrakeDumpSlip` to ws_eff, fading linearly over `SpinWindowSeconds`, plus a "Launch" event.
  - Either gesture opens a `SpinWindowSeconds` window.
- **Target L_t** = smoothstep((ws − `SpinSlipStart`)/`SpinSlipWidth`) × smoothstep((|steer| − `SpinSteerStart`)/`SpinSteerWidth`) × (1 − smoothstep((mph − `SpinBelowMph`)/`SpinFadeMph`)) × smoothstep((|r| − 0.15)/0.35) × S × tierScale × (`SpinTouchScale` on touch).
  - It is 0 during the grace, while DriftBlend > 0.12, or when `SpinEnabled` is 0.
  - Capped at `SpinHoldCap` outside a window. Clamped to [0, 1].
- **Rate**
  - `SpinBuildRate` rising, `SpinDecayRate` falling.
  - Catch (throttle < 0.3, or rawSteer × dir > 0 with |rawSteer| > 0.3, which is a counter-steer): toward 0 at `SpinCatchRate`.
- **Direction** latches at L > 0.05 from the sign of r and clears below 0.02.
- **Push** = dir × `SpinYawAccel` × S × L × (0.6 + 0.4 × min(ws/0.5, 1)).
- **Yaw authority** = 1 − `SpinYawAuthorityLoss` × L. It drops instantly and recovers with τ = `SpinSettleSeconds`.
- **Grace**: L_t = 0 until `SpinStartGraceSeconds` have passed **and** the car has exceeded `SpinStartGraceMph` since the grace began (whichever is later, as written in 5.4). `SpinStartGraceMph` 0 makes it time-only.
- **Warning**: ShiftLight 4 while L > `SpinWarnLevel` and rising.

**Pitch and roll**
- **Pitch.** g_long = (`dynamicsStep.LongitudinalAcceleration` + this frame's boost or mini-boost acceleration × share) / 35.1, so the shift cut nods the nose (fix 8). It drives a second-order spring (`PitchOmega`, `PitchDamping`), and `state.AccelBrakePitchDegrees` mirrors it. Runs only when `Driving@AccelBrakeTiltEnabled` and W > 0; otherwise the old block runs.
- **Roll.** From the applied lateral acceleration on forward intent, added to the Align CFrame's roll on top of the unchanged raw-steer bank. The positive sign leans out of the turn; a negative `RollDegreesPerG` leans in. The sign needs checking in Play.

### 2e. State reset (CONTRACT 5.5)

`resetDrivetrainChassis` clears:
- yaw rate and yaw acceleration;
- authority and spin blend;
- the lateral filter;
- the pitch and roll springs;
- spin L, direction, window, gesture clocks and dump slip;
- the steer limiter;
- the impact kick and boost flags.

It also restarts the grace. `ResetGearbox` sets first gear at idle, or the matching gear and road rpm when moving, or N while anchored, with no cut or limiter.

| Site | What happens |
|---|---|
| Start | both resets |
| Stop | chassis reset, plus session state and caches |
| `ResetVehicle` | chassis reset now, gearbox on the next frame |
| Anchored branch | chassis reset every frame; gearbox to N on the first anchored frame |
| `YawHeading` re-sync | only in Start in this file, already covered |
| `GameplayInputGate` locked | `ResetPending` every locked frame |
| Switching active or inactive | both resets, plus clearing the Feel attributes |

## 3. Interfaces produced

### 3.1 Feel attributes

Written on the vehicle Model only while active, only on change through `FeelCache`, and only while `Driving@FeelStateEnabled` is on (as for the existing Feel set). They are in `FEEL_ATTRIBUTES`, so `Stop` clears them, and becoming inactive also clears them.

| Attribute | Notes |
|---|---|
| `FeelRpm` | 10 rpm steps |
| `FeelIdleRpm`, `FeelRedlineRpm`, `FeelLimiterRpm`, `FeelGearCount` | written at activation and on change |
| `FeelGear` | −1 R, 0 N, 1..n |
| `FeelLoad` | 0.02 steps |
| `FeelShiftKind`, `FeelShiftStrength` | `Up`/`Down`/`Launch`; strength in 0.05 steps, × min(FeelGearing, 1) for Up and Down. Written before the revision. |
| `FeelShiftRevision` | counter, never reset within a session |
| `FeelCut` | 0.1 steps: the larger of the shift-cut and limiter-cut shares of the frame |
| `FeelLimiterRevision` | counter |
| `FeelThrustSlip` | clamp(ws_eff/0.5, 0, 1) in 0.05 steps |
| `FeelSpin` | L in 0.05 steps |
| `FeelSpinDirection` | +1 = clockwise (rightward) spin, −1 = anticlockwise, 0 when not spinning. It equals the sign of the steering that caused the spin. |
| `FeelOverdrive` | 0 or 1 |

`FeelSlip` uses a 2 mph floor while active and 8 mph otherwise.

### 3.2 Telemetry

`Drivetrain.Telemetry` is preallocated with `Gear` (string from `GEAR_TEXT`, no allocation), `GearRevision`, `RpmFraction` (= clamp(rpm/R × `HudRedlineSweep`, 0, 1); the limiter sits at 8600/8500 × 0.87 = 0.880), `ShiftLight`, `Spin` (raw L) and `Overdrive`. It is passed as `PublishMobile`'s third argument on frames where it was filled, anchored frames included.

On any other frame the old two-argument call runs, so the HUD part's nil handling clears the fields. The HUD part owns `DriveSessionClient`; DrivingClient only calls `context.PublishMobile`.

**ShiftLight**
- 4: spin warning.
- 3: limiter engaged (in gear or neutral).
- 2: the rpm is within the lead of a planned upshift. The planned point must be ≥ `HudShiftMinFraction`, in a gear below top, under throttle. Lead = clamp(rpmRate × `HudShiftLeadSeconds`, 0.05R, 0.15R), where rpmRate is smoothed at 10/s.
- 1: within `HudWarmBandFraction` × R below that.
- 0: otherwise.

### 3.3 `VehicleDynamics.GearForSpeed(vehicle, speedMph, accelerating, braking, previousGear)`

Returns `gear, rpm, redline, limiter, idle`, or nil when the class has no active drivetrain.
- No `SetAttribute`. No allocation per call: the cache entry and its legacy-stats table are reused.
- The weak-keyed cache is re-checked at most every 0.25 s and rebuilt only when PI or the tuning revision changes. A rebuild uses `ComputeBalance`, `ResolveStats(..., quiet = true)`, and the same `DrivetrainProfile` build in the quiet cache.
- At most one gear changes per call (hysteresis):
  - up when accelerating at x ≥ 0.92, or at x ≥ 0.6 when neither accelerating nor braking, only if the next gear lands ≥ 0.5 (prevents hunting);
  - braking: down when it lands ≤ `DownshiftBrakeLand`;
  - otherwise down at x < 0.45;
  - first gear below `StopGearMph`.
- Rpm = mph/V_g × R. In first gear when accelerating, it is raised to the launch rpm, then clamped to [idle, limiter].
- **New dependency.** Audio requiring `VehicleDynamics` for this is new (today only DrivingClient requires it). The audio part records it as well.
- **Inferred, not checked.** Remote stats come from `RAW_PERFORMANCE_Runtime`, the `Performance_*` attributes, or the vehicle attributes and `TOTAL_STATS_Runtime`, in the same way as the local car. That these replicate to other clients is not verified.

## 4. Preserved behaviour (CONTRACT 5.6)

Everything below is unchanged when inactive, and unchanged when active unless noted.

- **DRIVE-01 logic** (the steering intent block) is untouched.
- **Bank** uses `rawSteer`. When inactive it is the same value as before.
- **Reverse:** the reverse ×3 and the reverse latch are untouched. Reverse and Stopped modes use today's equations.
- **Auto-hold** is today's, except it is gated while spinning or sliding when active.
- **Hover:** the rays, pose, wobble and `FeelHover` are untouched.
- **Mini-boost** rules are untouched. Its force is × `BoostShare` when active.
- **Balance** multipliers stay at their sites. The profile's Vt/Vb solve uses them exactly as today's step does.
- **`FeelSpeedMph`** stays the real speed. The display curve is untouched.
- **Driving rules**
  - no per-frame allocation in the new code (the old per-frame tables are untouched);
  - no new connections;
  - no extra raycasts;
  - no `GetDescendants`;
  - every smoothing step is `1 − exp` or a sub-stepped spring;
  - NaN guards on every new state;
  - dt clamped to 0..0.1 in every new function;
  - zero force while anchored (the anchored branch only adds neutral revs).
- **Names and signatures:** no existing attribute, function or state field is renamed or removed, and the `Controller` signatures are unchanged.
- **Debug attributes:** the new ones are written only when `Dynamics@DebugAttributes` is on.

## 5. Test hooks (Play, Client datamodel, read-only)

**Feel attributes** on the driven car: see section 3.1.

**Debug attributes** (need `Dynamics@DebugAttributes`, which is true live)

| Attribute | Value |
|---|---|
| `DynamicsGear`, `DynamicsRpm` | gear and rpm (10 rpm steps) |
| `DynamicsWheelspin` | ws_eff |
| `DynamicsDriveThrust` | gross thrust |
| `DynamicsEngineLoad` | engine load |
| `DynamicsBoostShare`, `DynamicsOverdrive` | boost share and the Overdrive flag |
| `DynamicsMode`, `DynamicsForwardMph`, `DynamicsLongitudinalAcceleration`, `DynamicsReverseHoldTimer` | same names as today |
| `DynamicsDesignTopMph`, `DynamicsBoostTopMph` | Vt and Vb |
| `DynamicsGearRedlineMph` | gear redline speeds |
| `DynamicsTraction`, `DynamicsDrivetrainDrag` | traction and Kd |
| `DynamicsBoostShareHigh`, `DynamicsBrakeV2`, `DynamicsLateralCapBase` | profile values |
| `DynamicsDrivetrainClass` | the class in use |
| `DynamicsYawRate`, `DynamicsYawRateCommand` | yaw rate and command |
| `DynamicsSpin`, `DynamicsSpinTarget`, `DynamicsSpinWindow` | spin amount, target and window |
| `DynamicsSpinGraceSeconds`, `DynamicsSpinGraceSpeedReached` | grace progress |
| `DynamicsPowerBrakeHeld`, `DynamicsExtraSlip` | power-brake state |
| `DynamicsLateralAccel`, `DynamicsLateralCap` | applied lateral acceleration and cap |
| `DynamicsSteerKeyboard` | rate-limited keyboard steer |
| `DynamicsShiftLight` | shift light level |

**Checks**
- **Parity.** Set `Drivetrain.exotic@Enabled` 0 (or `Drivetrain@Enabled` 0). Within 0.25 s:
  - all 16 drivetrain Feel attributes are nil;
  - the HUD telemetry is cleared;
  - `DynamicsDrivetrainClass` stops updating;
  - driving matches before-install.
- **Live tuning.** Change any `exotic` attribute in Play. `DynamicsGearRedlineMph` and the other rebuild debug values update within 0.25 s.
- **Spin.**
  - Wait out the grace: `DynamicsSpinGraceSeconds` ≥ 3 and `DynamicsSpinGraceSpeedReached` true (drive above 38 mph once).
  - Then, at a standstill, hold W+S for ≥ 0.3 s, hold A, and release S. Expect `DynamicsSpinWindow` 0.7, `DynamicsExtraSlip` 0.5 fading, then `FeelSpin` rising and `FeelSpinDirection` −1.
  - Hold cases (W + full lock without a gesture) must stay at `DynamicsSpin` ≤ 0.35.
- **Countdown.** Anchored: `FeelGear` 0, `FeelRpm` follows W, and the limiter bounces (`FeelLimiterRevision` counts). `Accelerating` stays false.

## 6. Generated checks (scratch Python port of the step; not measured, not the model part's results)

These numbers come from the six stock Exotic cars, with today's equations used for Vt and Vb, full throttle and a 60 Hz step. They are a sanity check of the Lua only; the model part's `model/RESULTS.md` is the authority.

| Car | Vt / Vb mph | Gear redline mph | 0-60 | 0-100 | t(0.9 Vt) | Top after 30 s | Boosted top | BrakeV2 / today |
|---|---|---|---|---|---|---|---|---|
| E Stinger 220 | 103.6 / 126.8 | 28/40/53/66/80/94/110 | 3.63 | 14.97 | 10.3 | 103.5 | 126.8 | 37.3 / 40.4 |
| C Aurora 540 | 114.4 / 140.4 | 31/45/58/73/88/104/121 | 2.83 | 8.15 | 9.3 | 114.4 | 140.4 | 43.1 / 51.6 |
| A Rosso 800 | 162.2 / 200.0 | 44/63/83/103/125/148/172 | 2.00 | 4.15 | 10.5 | 162.0 | 200.0 | 59.5 / 87.3 |
| S Seraph 938 | 173.6 / 217.2 | 47/68/89/111/134/158/184 | 1.88 | 3.92 | 11.3 | 173.2 | 217.2 | 71.5 / 108.4 |

Also:
- S lifting at 100 mph: 89 mph after 2 s.
- S braking 100-0: 2.07 s.
- C car bang-bang holding 40 mph with W for 10 s: 0 shifts.

Top speed equals today's Vt and the boosted top equals Vb, by construction.

## 7. Risks and open items

1. **Spin grace "whichever is later" is literal.** After Start, `ResetVehicle`, any gate lock or an unanchor, spins stay off until the car has gone faster than 38 mph and 3 s have passed. Power-brake donuts straight after spawning or after R are therefore unavailable. If that feels wrong, set `SpinStartGraceMph` to 0 (time-only grace).
2. **Touch power-brake not detected.** `GetMobileInput` returns the summed throttle, so both touch pedals look like 0. Touch has the stab gesture only, scaled by `SpinTouchScale`.
3. **Exotic spins mostly come from the power-brake.** `TractionAssist` 0.35 keeps the launch ws_eff of stock Exotics near or below `SpinSlipStart` 0.12, so a plain stab gives at most a small wiggle. The model part's envelope decides the defaults.
4. **Grip-limited yaw cap at speed.** With `YawCapMargin` 0.9, full-lock yaw at 120 mph on S drops to about 0.73 rad/s, about 4 g. This is understeer at the limit, as the critique asked; check it against the corner feel.
5. **Pitch source.** Pitch uses the commanded net longitudinal acceleration, not measured velocity change, so collisions and slopes don't pitch the body.
6. **Roll sign** is physically outward and opposes the raw-steer bank a little (at most 3°). Flip it with a negative `RollDegreesPerG` if it reads wrong.
7. **Low-speed lateral filter.** At W ≥ 1 below 8 studs/s it is slightly under-damped (ζ ≈ 0.4). It could look like a small sway at walking pace. Lower `GripRelaxStuds` if seen.
8. **Additions beyond the contract's list**
   - `SpinYawAuthorityLoss` (0.85, from the draft): without it the spring cancels the spin push.
   - The lug downshift (x < 0.2).
   - `FeelShiftStrength` × min(FeelGearing, 1).
   - The spin yaw gate constants (0.15 / 0.35 rad/s) are hard-coded.
9. **`Dynamics` config edits are not live.** Edits to `Config.Vehicles.Dynamics.*` during Play (for example `BaseForwardAcceleration`) do not rebuild the profile until the PI, tuning revision, stats or Balance change, or the car is re-entered. Edits to the class folder do apply live.
10. **Impact kick dependency.** The kick is detected inside `publishFeelState`, so it needs `Driving@FeelStateEnabled`.
11. **Debug attributes are on in PR98.** `Dynamics@DebugAttributes` is true live, and this delivery adds about 15 more per-frame debug writes, written only on change. Switch it off before publish (critique 16).
12. **E-tier pace changes a lot** (0-100 from 8.3 s today to about 15 s). Races and time trials are out of scope by Oscar's instruction, but free-roam job pacing and `DuelService` timeouts may notice.
13. **Not verified in Play**
    - enter and exit cycles;
    - the camera hard-cut invariant (`YawRateMax` ≤ 5 is enforced in code);
    - remote `GearForSpeed` on a published server.

## 8. Config values: `ReplicatedStorage.Config.Vehicles.Drivetrain.exotic`

The `Drivetrain` folder itself carries `Enabled` 1 (0 = every class drives as before), `DrivetrainFeelInstalled` true and `Notes` (how to add a class by copying `exotic`). The table below is generated from `physics/config.py`. Each row's text is also the attribute's `_RaisingThisDoes` string in Studio. Numbers are clamped in code to the ranges in `DRIVETRAIN_NUMBERS` (VehicleDynamics 316-353).

| Attribute | Default | Raising it (and what 0 does) |
|---|---|---|
| `Enabled` | 1 | 1 = this class uses the drivetrain (gearbox, weight, spin-out, rpm HUD); 0 = it drives, sounds and displays exactly as before. |
| `FeelWeight` | 1 | Heavier car: more yaw inertia, slower steering build-up on keys and touch, slower grip build, more pitch and roll, longer braking. 0 = today's light, instant feel (range 0-2.5). |
| `FeelGearing` | 1 | Gears felt more: bigger torque steps between gears, longer and deeper shift cuts, snappier rev drops, stronger shift cues. 0 = CVT-smooth with no cut (range 0-2). |
| `FeelAcceleration` | 1 | More engine thrust in every gear (quicker 0-60 and mid-range); top speed stays today's. Range 0.5-1.5. |
| `FeelGrip` | 1 | Higher cornering grip limit and more traction off the line (less wheelspin). Range 0.6-1.6. |
| `FeelSpin` | 1 | Spins more readily and more violently. 0 = it never spins (range 0-2.5). |
| `FeelEngineBrake` | 1 | Stronger slowing when you lift off, more in low gears. 0 = coasting is only drag and rolling resistance (range 0-2). |
| `GearCount` | 7 | More forward gears are used (up to the number of GearRatios, at most 9); fewer gears give longer, bigger steps. |
| `IdleRpm` | 1100 | Higher idle and lowest rpm (gauge, sound); 0 is not allowed (minimum 300). |
| `RedlineRpm` | 8500 | Higher redline: the rpm scale stretches (gauge, sound, shift points scale with it); gear speeds do not change. |
| `LimiterRpm` | 8600 | Limiter sits further above redline (flare and limiter peak); clamped to 1-1.2 x RedlineRpm. |
| `GearTorqueExponent` | 0.8 | Bigger drop in thrust in each higher gear (more real, slower top-end pull). 0 = the same thrust in every gear. |
| `TopGearOverspeed` | 1.06 | Top gear runs out further above the top speed, so the engine sits lower in its rev range at top speed. 1 = top speed exactly at redline. |
| `LaunchRpmFraction` | 0.5 | Higher launch and power-brake revs in first gear (clutch slip, fraction of redline). 0 = first gear follows road speed from idle. |
| `EngineRiseSeconds` | 0.06 | Revs rise more lazily (heavier flywheel feel); falls scale with it through EngineFallScale. Minimum 0.01. |
| `EngineFallScale` | 1.5 | Revs fall more slowly than they rise (x EngineRiseSeconds). 1 = same speed up and down. |
| `ShiftRpmSeconds` | 0.05 | Slower rev drop after an upshift (divided by FeelGearing). Minimum 0.005. |
| `ThrustSlipFlare` | 0.6 | Revs flare higher when the thrust slips (launch, burnout). 0 = no flare. |
| `ShiftCutSeconds` | 0.06 | Longer torque cut on each upshift (x FeelGearing). 0 = no cut. |
| `ShiftCutTorque` | 0.45 | Share of thrust kept during the upshift cut: higher = gentler cut, 1 = no cut, 0 = full cut. |
| `ShiftBlendSeconds` | 0.06 | Slower thrust return after the upshift cut (x FeelGearing). 0 = thrust returns at once. |
| `DownshiftBlendSeconds` | 0.08 | Slower rev-matched rise after a downshift (no torque cut on downshifts). Minimum 0.01. |
| `ShiftMinIntervalSeconds` | 0.25 | Longer minimum time between shifts (less hunting, slower gear changes). Minimum 0.05. |
| `UpshiftFlat` | 0.97 | Holds each gear closer to redline at full throttle (fraction of redline). Above 1 is not allowed. |
| `UpshiftPartLow` | 0.62 | Later upshifts at light part throttle (0.3 throttle), fraction of redline. |
| `UpshiftPartHigh` | 0.85 | Later upshifts at heavy part throttle (0.9 throttle), fraction of redline. |
| `UpshiftCruise` | 0.45 | Later short-shifts when cruising (throttle between CruiseThrottleMin and 0.3), fraction of redline. |
| `CruiseThrottleMin` | 0.05 | More throttle needed before any cruise upshift; below it no upshift at all (except off the limiter). |
| `UpshiftMinLand` | 0.33 | A cruise upshift must land at a higher rpm (fraction of redline), so it short-shifts less. 0 = no limit. |
| `LiftHoldSeconds` | 0.8 | Holds the gear longer after a lift before a part-throttle upshift (less churn when tapping). 0 = no hold. |
| `DownshiftBrakeLand` | 0.82 | Braking downshifts happen earlier, landing at up to this fraction of redline (more engine braking, more blips). |
| `DownshiftCoastFraction` | 0.3 | Coasting downshifts happen at higher rpm (fraction of redline). 0 = no coasting downshifts. |
| `DownshiftCoastLand` | 0.65 | Coasting and lugging downshifts may land at a higher rpm (fraction of redline). |
| `KickdownThrottle` | 0.95 | More throttle needed for a kickdown (several gears at once). |
| `KickdownBelowFraction` | 0.45 | Kickdown also fires at higher rpm (fraction of redline). 0 = no kickdown. |
| `KickdownLand` | 0.88 | Kickdown may drop to a lower gear, landing at up to this fraction of redline (harder kick). |
| `KickdownHoldSeconds` | 0.12 | Full throttle must be held longer before a kickdown (fewer accidental kickdowns). 0 = instant. |
| `StopGearMph` | 3 | First gear is selected below a higher speed (mph); also the standstill speed for the power-brake. |
| `LimiterOnSeconds` | 0.03 | Longer drive bursts between limiter cuts (slower bounce). Minimum 0.005. |
| `LimiterCutSeconds` | 0.045 | Longer limiter cuts (harder, slower bounce). 0 = the limiter holds without cutting. |
| `LimiterHysteresisRpm` | 150 | Deeper limiter bounce: the rpm drops further below redline in each cut. 0 = minimal bounce. |
| `NeutralRevEnabled` | 1 | 1 = the engine revs in neutral with the throttle during a countdown (no force); 0 = idles until GO. |
| `NeutralRevTarget` | 1.02 | Higher neutral revs at full throttle (fraction of redline); above 1 bounces the limiter. 0 = stays at idle. |
| `TractionG` | 1.15 | More traction off the line (g): less wheelspin and fewer spins, quicker launches up to the thrust. |
| `TractionGripExponent` | 0.15 | LateralGrip stat matters more for traction. 0 = every car gets the same traction. |
| `TractionTierBonusG` | 0.25 | Upgraded cars (PI toward TierFullPI) get more extra traction, felt off the line. 0 = no tier bonus. |
| `TierStartPI` | 250 | PI where the tier traction bonus and spin authority start rising; higher = only stronger cars get them. |
| `TierFullPI` | 750 | PI where the tier traction bonus and spin authority are full; higher = slower build across tiers. |
| `TractionAssist` | 0.35 | Removes more of the thrust slip (fewer launch flares and spins). 0 = no assist, 1 = never slips. |
| `SlideGripFraction` | 0.88 | Less thrust lost while the thrust slips (1 = slipping costs nothing; lower = burnouts are slower). |
| `RollingDecel` | 0.8 | More constant rolling resistance (studs/s^2): coasts down sooner. 0 = none (top speed is kept by re-deriving drag). |
| `RollingDecelPerStud` | 0.004 | More speed-proportional resistance: coasts down sooner at speed. 0 = none (top speed is kept). |
| `EngineBrakeDecel` | 1.5 | Stronger engine braking on a lift (studs/s^2 in top gear, more in low gears; x FeelEngineBrake). 0 = none. |
| `BrakeDecel` | 70 | Stronger brakes at FeelWeight 1 (studs/s^2 at the reference brake stat). FeelWeight 0 uses today's brakes instead. |
| `BrakeForceExponent` | 0.35 | Braking stat matters more for brake strength. 0 = every car brakes the same. |
| `BrakeFactorMin` | 0.75 | Weakest cars brake harder (lower clamp of the braking stat factor). |
| `BrakeFactorMax` | 1.4 | Strongest cars may brake harder (upper clamp of the braking stat factor). |
| `BoostShapeEnabled` | 1 | 1 = boost fades with speed so the boosted top speed stays today's; 0 = full boost at every speed (the speed guard still holds the top). |
| `BoostShareMin` | 0.15 | Keeps more boost near the boosted top speed (lower bound of the fade); 1 = no fade. |
| `SpeedGuardStrength` | 2 | Holds the boosted top speed harder above SpeedGuardOverBoostTop x boosted top. 0 = no guard. |
| `SpeedGuardOverBoostTop` | 1.03 | Lets the car go further past today's boosted top speed before the guard bites (1 = exactly today's). |
| `OverdriveEnabled` | 1 | 1 = boosting past top-gear redline pins the engine at redline with no limiter cut (Overdrive); 0 = it hits the limiter. |
| `SteerRiseSeconds` | 0.2 | Slower keyboard steering build-up to full lock (x FeelWeight). 0 = instant like today. |
| `SteerReturnRate` | 14 | Keyboard steering returns to centre faster (per second, at FeelWeight 1 or more). |
| `TouchSteerRate` | 10 | Touch steering follows the finger faster (per second, at FeelWeight 1 or more); gamepad is never limited. |
| `YawOmega` | 9 | Quicker, stiffer turn-in (rad/s; divided by FeelWeight); lower = more yaw inertia and lag. |
| `YawDamping` | 0.75 | Less overshoot and settle after turn-in; lower = more wobble that reads as mass. |
| `YawWeightExponent` | 0.5 | Weight stat matters more for yaw inertia. 0 = every car turns in the same. |
| `YawWeightMin` | 0.75 | Heaviest cars turn in quicker (lower clamp of the weight factor). |
| `YawWeightMax` | 1.3 | Lightest cars may turn in quicker (upper clamp of the weight factor). |
| `YawKinematicBelowMph` | 15 | Turning stays exactly like today up to a higher speed (parking, U-turns); inertia blends in above it. 0 = inertia at every speed. |
| `YawUnwindScale` | 2 | Car stops turning faster after you release the steering (less run-on). 1 = same as turn-in. |
| `YawRateMax` | 5 | Highest yaw rate allowed (rad/s, at most 5 so the camera never cuts). |
| `LateralCapG` | 3.4 | Higher cornering grip limit (g): tighter fast corners, later understeer. Lower = heavier, wider lines. |
| `LateralCapGripExponent` | 0.25 | LateralGrip stat matters more for the grip limit. 0 = every car has the same limit. |
| `LateralCurveShape` | 1.4 | Grip falls away more once past the limit (sharper peak). 1 = grip never drops past the limit (1-1.9). |
| `YawCapMargin` | 0.9 | Car may turn faster than its grip carries it at the limit (more slide, less understeer). Lower = more understeer. |
| `GripRelaxStuds` | 2 | Grip builds over more travel when the car starts to slide (looser, heavier feel; x FeelWeight). 0 = instant. |
| `DriftCapExempt` | 1 | 1 = drifts keep today's uncapped grip and yaw (drift lines unchanged); 0 = the grip limit also applies in drifts. |
| `PitchDegreesPerG` | 2.4 | More nose-up under acceleration and nose-down under braking and shift cuts (degrees per g, x FeelWeight). 0 = level. |
| `PitchMaxDegrees` | 5 | Allows a larger pitch angle (degrees). 0 = no pitch. |
| `PitchOmega` | 9 | Pitch and roll follow quicker and snappier (rad/s); lower = slower, floatier body motion. |
| `PitchDamping` | 0.6 | Less bounce on pitch and roll; lower = more overshoot. |
| `RollDegreesPerG` | 0.9 | More body roll away from the turn from cornering g (degrees per g, x FeelWeight). 0 = off; negative leans into the turn instead. The steering bank is separate and unchanged. |
| `RollMaxDegrees` | 3 | Allows a larger body roll angle (degrees). 0 = no roll. |
| `ImpactYawKick` | 0.6 | Hits off the car's centre line turn it more (rad/s per 100 studs/s of impact). 0 = impacts never turn the car. |
| `SpinEnabled` | 1 | 1 = low-speed spin-outs are possible; 0 = the car never spins. |
| `SpinStabSeconds` | 0.4 | A slower throttle stab (seconds from under 0.3 to 0.9 throttle) still opens a spin window. 0 = only an instant stab. |
| `SpinStabSteer` | 0.8 | More steering lock needed for a stab to open a spin window (0-1). |
| `SpinAnalogRate` | 4 | Gamepad throttle must rise faster (per second) to count as a stab; lower = easier stabs on a trigger. |
| `SpinWindowSeconds` | 0.7 | Spin window after a stab or power-brake lasts longer: a bigger spin can build. 0 = gestures do nothing. |
| `PowerBrakeEnabled` | 1 | 1 = holding forward and brake at a standstill, then releasing brake, dumps the revs (burnout start); 0 = off. |
| `PowerBrakeMinHold` | 0.3 | Forward and brake must be held together longer before the release counts (seconds). |
| `PowerBrakeDumpSlip` | 0.5 | Harder burnout and more spin on a power-brake release (extra thrust slip, fading over the window). 0 = no dump. |
| `SpinBelowMph` | 25 | Spins can start at higher speed (mph; full authority below it, then fading over SpinFadeMph). |
| `SpinFadeMph` | 12 | Spin authority fades out over a wider speed band above SpinBelowMph. |
| `SpinSteerStart` | 0.6 | More steering needed before a spin can build (0-1). |
| `SpinSteerWidth` | 0.35 | Spin authority reaches full only at more steering past SpinSteerStart. |
| `SpinSlipStart` | 0.12 | More thrust slip needed before a spin can build (fewer spins). |
| `SpinSlipWidth` | 0.25 | Spin authority reaches full only at more thrust slip past SpinSlipStart. |
| `SpinBuildRate` | 3.5 | Spins build faster (per second). 0 = never builds. |
| `SpinDecayRate` | 2.5 | Spins die down faster on their own (per second). |
| `SpinCatchRate` | 8 | Lifting (under 0.3 throttle) or counter-steering catches the spin faster (per second). |
| `SpinSettleSeconds` | 0.3 | Car eases back to normal steering more slowly after a catch (seconds). 0 = snaps back. |
| `SpinYawAccel` | 7 | Spins rotate the car harder (rad/s^2 at full spin, x FeelSpin). 0 = no rotation push. |
| `SpinMaxYawRate` | 3.6 | Faster spin rotation allowed (rad/s; never above YawRateMax). |
| `SpinGripLoss` | 0.7 | More sideways grip lost in a spin (0-1): the car slides further. |
| `SpinThrustLoss` | 0.35 | More thrust lost in a spin (0-1). |
| `SpinYawAuthorityLoss` | 0.85 | Steering loses more of its hold on the yaw in a spin (0-1): the spin carries on more freely. |
| `SpinHoldCap` | 0.35 | A bigger wiggle is allowed without a gesture (largest spin amount outside a stab or power-brake window). 0 = only gestures spin. |
| `SpinTierFloor` | 0.5 | Low-PI cars get more spin authority (share at TierStartPI; full at TierFullPI). |
| `SpinTouchScale` | 0.5 | Touch players spin more readily (x spin target). 0 = no spins on touch. |
| `SpinStartGraceSeconds` | 3 | Longer no-spin grace after a start, reset or unanchor (seconds). |
| `SpinStartGraceMph` | 38 | The grace also lasts until the car has gone faster than this (mph), whichever is later. 0 = time only. |
| `SpinWarnLevel` | 0.25 | The amber spin warning (HUD shift light 4) comes later, at a bigger spin amount. |
| `HudRedlineSweep` | 0.87 | Redline sits further round the gauge arc (fraction of the sweep); the limiter is just past it. |
| `HudShiftLeadSeconds` | 0.25 | Shift light comes on earlier before a planned upshift (seconds of rpm climb). 0 = only at the shift point. |
| `HudShiftMinFraction` | 0.85 | Shift light only for upshifts planned nearer redline (fraction); 0 = also for cruise short-shifts. |
| `HudWarmBandFraction` | 0.12 | Warm light starts further below the flash point (fraction of redline). 0 = no warm stage. |
| `GearRatios` | `3.15,2.18,1.66,1.33,1.10,0.93,0.80` | Gear ratios, first to top, comma separated. Wider gaps = bigger rev drops and torque steps; the gear speeds come from each car's own top speed, so only the ratios between gears matter. |
| `TorqueCurve` | `0:0.55,0.3:0.80,0.5:0.93,0.7:1,0.85:0.98,1:0.86` | Engine torque shape as rpm/redline:torque pairs (peak 1). Raising a point gives more pull at that rpm; a flatter curve feels like a big lazy engine, a peaky one like a screamer. |
