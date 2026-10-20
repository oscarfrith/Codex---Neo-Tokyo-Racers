# physics part: DrivingClient and VehicleDynamics (drivetrain_feel)

Owner of CONTRACT sections 3 (producer side), 4 (config) and 5, as amended by `reviews/15_fix_spec.md` (the fix spec). Files:

- `physics/after/DrivingClient.lua` (2254 lines, 109,659 bytes; limit 199,999) and `physics/after/VehicleDynamics.lua` (1134 lines, 74,761 bytes): full sources, started from `before/`.
- `physics/config.py`: `INSTANCES` creates `ReplicatedStorage.Config.Vehicles.Drivetrain` (Enabled 1, DrivetrainFeelInstalled true, Notes) with the child Folder `exotic`: 131 numbers (122 tuning numbers, 9 switches) plus `Enabled`, each with a `_RaisingThisDoes` string, plus `GearRatios`, `TorqueCurve` and `Notes`. `ATTRIBUTES` is empty.

**Status:** generated, then fixed per the fix spec (C1-C9, R13 #1-#13, section B). Compile-checked in Studio Edit through the 8797 bridge: `DrivingClient` OK 109659, `VehicleDynamics` OK 74761. Nothing is installed and nothing has been driven in Play. Defaults, clamps and texts in `config.py` were cross-checked against `DRIVETRAIN_NUMBERS` and `DRIVETRAIN_SWITCHES` by script.

## 1. What changed and where

### VehicleDynamics

| Function | Change |
|---|---|
| `Model.ResolveStats(vehicle, legacy, quiet)` | Optional `quiet` skips the debug `SetAttribute` blocks (remote cars). Existing callers pass nothing. |
| `Model.StepLongitudinal` | When `params.Drivetrain` is present and active, returns `Model.StepDrivetrain(...)` after every old local is computed. Otherwise the old lines run unchanged. |
| `Model.StepHandling` | Result gains `NormalGrip` and `DownforceFactor`. |
| `DRIVETRAIN_NUMBERS`, `DRIVETRAIN_SWITCHES` | {attribute, default, min, max} for 122 numbers; 9 switches (missing = 1). Fix pass: section B added; `TopGearOverspeed` minimum 1.02. |
| `drivetrainRoot`, `switchOn`, `parseRatios`, `parseCurve`, `curveAt`, `profileTorque`, `rebuildTuning` | Tuning parse; strings only re-parsed when their text changes. Coupled clamps: `LimiterRpm` in [R, 1.2R], `IdleRpm` ≤ 0.5R, `UpshiftPartHigh` ≥ `UpshiftPartLow`, `TierFullPI` > `TierStartPI`, `BrakeFactorMax` ≥ `BrakeFactorMin`, `YawWeightMax` ≥ `YawWeightMin`, `SpinMaxYawRate` ≤ `YawRateMax` ≤ 5. |
| `profileMult` (new) | Gear thrust multiplier at a road speed: FeelGearing steps around a fixed envelope (C6). |
| `deliveredThrust` (new) | Traction limit plus slide loss of a raw thrust, as the step applies it (C6). |
| `Model.DrivetrainCategory`, `Model.DrivetrainTuning` | Class from `CategoryId` (fallback `CockpitId` prefix). One tuning table per class, re-read at most every 0.25 s with `GetAttributes()`, rebuilt only on change. |
| `profileStale`, `buildProfile`, `Model.DrivetrainProfile` | CONTRACT 5.1 profile, cached per vehicle (weak keys). Fix pass: `MultBase`, `MidMph`; Kd and the boost share from the delivered top-gear thrust. |
| `Model.DrivetrainSelectGear`, `Model.ResetGearbox`, `Model.LaunchGearbox`, `beginShift`, `cutIntegral`, `stepLimiter`, `upshiftPoint` | Gearbox helpers. `ResetGearbox` now also resets `Duty` 0 and `SteadyMph` = speed. |
| `Model.StepDrivetrain` | The per-frame step. Fix pass: duty and steady-speed averages, digital cruise upshift (C9), drift-hold downshift (C5), Overdrive hysteresis (F9), enveloped thrust and engine braking (C6). |
| `Model.StepNeutral` | Neutral revs while anchored; now also runs the duty averages. |
| `Model.GearForSpeed` | Remote cars (CONTRACT 3.3). Unchanged by the fix pass. |

### DrivingClient

| Function | Change |
|---|---|
| `Drivetrain` session table | Fix pass adds `GateLocked`, `AnalogInput`; `Chassis.SteerYawRate`, `Chassis.SpinYawRate` (`SpinBlend` removed); `Spin.WasOn`, `LiftClock`, `ThrottleClock`, `FlickClock`, `SteerLow`, `LastSteer`, `Caught`, `Settling`, `GraceNeedsSpeed`; `Gearbox.Duty`, `SteadyMph`, `Overdrive`. Constant `STAB_NONE`. |
| `refreshInput(dt)` | Returns `throttle, steer, rawSteer`. Fix pass: locked path clears the gesture flags and requests one reset on the lock edge (R13 #8, #9); FeelWeight ≤ 0 bypasses the limiter (R13 #13); the limited steer is the trapezoid average over the frame (C8); sticky `AnalogInput` (C9). |
| `updateExistingDriveUi`, `FEEL_ATTRIBUTES`, `publishFeelState` | Telemetry third argument; 16 Feel names in the clear list; impact yaw kick; `FeelSlip` floor 2 mph while active. |
| `resetDrivetrainChassis` | Clears both yaw parts, stab clocks and latches (`SteerLow` false, `LastSteer` 0), and sets `GraceNeedsSpeed` false. |
| `refreshDrivetrain` | DriveReady false→true edge restarts the grace with its speed clause; switching the class on takes the current DriveReady as baseline. |
| `drivetrainResume` | Anchored resume sets `GraceNeedsSpeed`; launch only when throttle > 0.05, else `ResetGearbox` at road speed (R13 #12). |
| `drivetrainGestures` | Lift-then-flick-and-stab rule and the stab dump (C2). Power-brake unchanged. |
| `driftExemptWeight` (new), `drivetrainLateral` | Drift exemption weight w (C5). |
| `updateSpin` | Grace speed clause (C3); hold cap × FeelSpin and the warning level (C4); `Caught` / `Settling` for the r_spin settle. |
| `drivetrainYaw` | r = r_steer + r_spin (C1); ω cap 60 (R13 #6); returns the frame-average rate (R13 #7); drift yaw exemption (C5). |
| Heartbeat drift assist | Plateau share (C5). |
| `publishDrivetrain` | New debug: `DynamicsSpinYawRate`, `DynamicsSpinGraceNeedsSpeed`, `DynamicsThrottleDuty`. |
| `Controller.Stop`, `Controller.Start`, `Controller.ResetVehicle` | Session reset (now also `GateLocked`, `AnalogInput`); Start resets chassis and gearbox; R resets the chassis and the gearbox next frame. |

**Inactive path** (no class folder, `Enabled` 0, or `Drivetrain@Enabled` 0). Every new branch is skipped and each old line runs with the same values. Additions on that path, none with an observable effect:
- the 4 Hz class read in `refreshDrivetrain`;
- the nil `Drivetrain` key in the `StepLongitudinal` params and the `rawSteer` local;
- table writes to `Drivetrain.GateLocked` and the three gesture flags in `refreshInput`;
- 16 more `SetAttribute(name, nil)` calls in `Stop`.

## 2. The model as built

### 2a. Feel dials: exact mapping

W = `FeelWeight`, Gr = `FeelGearing`, A = `FeelAcceleration`, Gp = `FeelGrip`, S = `FeelSpin`, E = `FeelEngineBrake`.

| Dial | Parameter | Exact mapping | Dial at 0 |
|---|---|---|---|
| W (0..2.5) | Keyboard steer build | rise time `SteerRiseSeconds × W`; return `SteerReturnRate / clamp(W, 0.05, 1)`; the frame's steer is the trapezoid of the limiter's start and end values | no limiter: the raw sum, today |
| W | Touch steer rate | `TouchSteerRate / clamp(W, 0.05, 1)`, trapezoid as above | no limiter |
| W | Yaw spring r_steer | ω = `YawOmega × clamp((118/Weight)^YawWeightExponent, YawWeightMin, YawWeightMax) / max(W, 0.05)`, × `YawUnwindScale` while unwinding, × authority, clamped to [1, 60]; ζ = `YawDamping` | r_steer = today's command |
| W | Spin yaw r_spin | **not scaled by W** (F1) | spins unchanged |
| W | Grip build distance | `GripRelaxStuds × W` studs | instant |
| W | Pitch | `PitchDegreesPerG × W × g_long`, ±`PitchMaxDegrees` | the old tilt block runs |
| W | Roll | `RollDegreesPerG × W × g_lat × (1 − DriftBlend)`, ±`RollMaxDegrees` | 0 (today has none) |
| W | Brake | `today + (BrakeV2 − today) × W`, clamped to [0.35 × min(today, BrakeV2), max(today, BrakeV2)] | today's brake |
| Gr (0..2) | Gear thrust | `mult = env(v) + (MultBase[g] − env(v)) × Gr`, `MultBase[g] = (r_g / r_1)^GearTorqueExponent`, floored at 0 (section 2b) | the smooth envelope: no steps, same pace |
| Gr | Torque curve depth | `1 + (τ(x) − 1) × min(Gr, 1)` | flat (CVT) |
| Gr | Upshift cut length and blend | `ShiftCutSeconds × Gr`, `ShiftBlendSeconds × Gr` | no cut |
| Gr | Upshift cut depth | kept torque `clamp(1 − (1 − ShiftCutTorque) × Gr, 0, 1)` | 1 |
| Gr | Rev drop after an upshift | `clamp(ShiftRpmSeconds / max(Gr, 0.05), 0.005, 1)` s | 1 s glide |
| Gr | Published shift strength | × `min(Gr, 1)` for Up and Down (Launch unscaled) | 0 |
| Gr | Engine braking per gear | × `mult / MultBase[count]` | smooth with speed |
| Gr | Kd and boost share | from the delivered top-gear thrust with the same `mult` at Vt and Vb | top and boosted top unchanged at any Gr |
| A (0.5..1.5) | Thrust | `A1 × A`; Kd re-derived, so top speed stays Vt | n/a |
| Gp (0.6..1.6) | Traction and grip cap | `Traction × Gp`, `LateralCapBase × Gp` (the yaw cap follows) | n/a |
| S (0..2.5) | Spin target | `L_t × S`, clamped 0..1 | never spins |
| S | Spin push | `SpinYawAccel × S × L × (0.6 + 0.4 × min(slip / 0.5, 1))` | 0 |
| S | No-gesture hold cap | `min(SpinHoldCap × S, 1)` (F7) | 0 |
| S | Warning level | `max(SpinWarnLevel, holdCap + 0.05)` | — |
| E (0..2) | Engine braking | `EngineBrakeDecel × E × mult / MultBase[count] × (0.35 + 0.65 × min(rpm/R, 1))` | drag and rolling only |

W 0, Gr 0 and S 0 each reproduce today's feel for their own aspect. The lateral grip cap and the yaw cap belong to `FeelGrip`, which has no 0 end, so they stay on at W 0 (R14 #15).

### 2b. Profile (`buildProfile`, CONTRACT 5.1)

- **Vt and Vb.** A 40-step bisection of today's forward-minus-aero (plus the soft limiter) at full throttle, without boost (Vt) and with today's boost `(BoostForce + 32) × 0.75 × bBoost` (Vb).
- **Gear redline speeds.** `S[g] = Vt × TopGearOverspeed × r_top / r_g`.
- **Gear envelope (C6).** `MultBase[g] = (r_g / r_1)^GearTorqueExponent`. `MidMph[g] = (S[g−1] + S[g]) / 2` with `S[0] = 0`. `env(v)` is `MultBase` interpolated linearly between the `MidMph` points, `MultBase[1]` below the first and `MultBase[count]` above the last.
- **Thrust.** `A1 = BaseForward × engineFactor × weightFactor × bAccel × FeelAcceleration`.
- **Traction.** `(TractionG + TractionTierBonusG × tier) × 35.1 × clamp((LG/50)^TractionGripExponent, 0.9, 1.15) × FeelGrip`, `tier = smoothstep((PI − TierStartPI) / (TierFullPI − TierStartPI))`.
- **Delivered thrust** `D(raw) = min(raw, trac) × (1 − (1 − SlideGripFraction) × smoothstep(s / 0.6))`, `s = max(raw / trac − 1, 0) × (1 − TractionAssist)`.
- **Drag.** `Kd = max(D(A1 × mult(count, Vt) × τ_eff(1 / TopGearOverspeed)) − RollingDecel − RollingDecelPerStud × Vt / 0.625, 0.5) / Vt²`.
- **Boost share.** `engine = D(A1 × mult(count, Vb) × τ_eff(min(x, 1)))`, × the limiter duty when x ≥ 1 and Overdrive is off; `BoostShareHigh = clamp((Kd × Vb² + Rb + Rs × Vb / 0.625 − engine) / boostToday, BoostShareMin, 1)`; `share(v) = 1 − (1 − BoostShareHigh) × smoothstep(mph / Vb)`.
- **BrakeV2, LateralCapBase, YawOmega, SpinTierScale** as before. Rebuild debug attributes only with `Dynamics@DebugAttributes` and a non-quiet caller.

### 2c. Per-frame step (`StepDrivetrain`)

- **Mode** follows today's rules; auto-hold does not snap while spin > 0.05 or horizontal speed > 4 studs/s.
- **Averages (C9).** Every active frame: `Duty += (thr − Duty) × (1 − exp(−dt / DigitalDutySeconds))`, `SteadyMph += (fwdMph − SteadyMph) × (same)`; `StepNeutral` too (SteadyMph toward 0). Reset with the gearbox.
- **Gear:** R while reversing, first below `StopGearMph`, else the brain. Road speed = forward speed blended to |v_h| by DriftBlend.
- **Brain** (only after `ShiftMinIntervalSeconds`):
  - Hold: no shifting while DriftBlend > 0.3 (drift hold) or spin > 0.1 (spin hold), except an upshift at x ≥ 1.
  - Upshifts: flat x ≥ `UpshiftFlat`; part x ≥ lerp(`UpshiftPartLow`, `UpshiftPartHigh`); cruise x ≥ `UpshiftCruise` landing ≥ `UpshiftMinLand`; part and cruise wait `LiftHoldSeconds`.
  - **Digital cruise (C9):** when no rule above upshifted, not held, `DigitalCruiseEnabled`, the last throttle device was not a gamepad trigger, `CruiseThrottleMin < Duty ≤ DigitalCruiseDutyMax`, `|fwdMph − SteadyMph| ≤ DigitalCruiseSteadyMph`, x ≥ `DigitalCruiseUpshift` and the landing ≥ max(`DigitalCruiseLand`, `UpshiftMinLand`): an Up shift, strength `0.3 + 0.7 × Duty`. `LiftHoldSeconds` does not block it. A held W has duty 1, so full-throttle points are unchanged.
  - Downshifts when not held: braking (lands ≤ `DownshiftBrakeLand`), coasting, kickdown, lug (x < 0.2). No torque cut on any downshift.
  - **Drift-hold downshift (C5):** in the drift hold (not the spin hold) with `DriftHoldDownshift`, one gear down when `|v_h| mph / S[g−1] ≤ DownshiftBrakeLand`. No cut; the shift interval applies, so one step at a time.
- **Overdrive (F9):** `OverdriveEnabled`, top gear, (boost applied last frame **or** already in Overdrive), x ≥ 1 (0.98 once on). It holds after the boost ends until the car drops below 0.98 of top-gear redline.
- **Rpm, cuts, limiter, resistance, brake, guard, load** as in the first build. Thrust `raw = A1 × mult(g, roadMph) × τ_eff × thr`.

### 2d. Chassis and spin (DrivingClient)

**Steering limit** (`refreshInput`): keyboard builds at 1/(`SteerRiseSeconds` × W), returns at the return rate; touch at the touch rate; gamepad unlimited. The frame's steer is the trapezoid of each limiter's start and end values (C8). FeelWeight ≤ 0: the raw sum, no limiter. `rawSteer` drives the bank, the stab flick and counter-steer detection.

**Lateral** (`drivetrainLateral`): peaked curve `cap × sin(C × atan(u / C))`, × (1 − `SpinGripLoss` × L), built over `GripRelaxStuds × W`. Then `applied += (−side × lateralGrip − applied) × w`, with **w = `driftExemptWeight` = clamp(DriftBlend × `DriftExemptGain`, 0, 1)** when `DriftCapExempt`, else 0.

**Yaw** (`drivetrainYaw`, C1):
1. Command = today's full turn rate. Grip cap on forward intent above 8 studs/s: `limit = YawCapMargin × cap × (1 + 1.5 × DriftBlend) / v_fwd`; `command = capped + (command − capped) × w`.
2. **r_steer:** spring toward command, ω and ζ from 2a, unwind tested on r_steer, ω × authority clamped to [1, 60]. Authority `1 − SpinYawAuthorityLoss × L` drops at once and recovers over `SpinSettleSeconds`.
3. **r_spin**, in the same sub-steps: `r_spin += (pushActive ? push : 0) × h − k_s × r_spin × h`; `pushActive = (r_steer + r_spin) × Dir > 0 and |r_steer + r_spin| < min(SpinMaxYawRate, YawRateMax)`; `k_s = max(YawOmega_profile × (1 − SpinYawAuthorityLoss × L), 1) / (2 × YawDamping)`, at least `3 / SpinSettleSeconds` while `Settling`.
4. Kinematic blend on r_steer only: `dynamic = smoothstep(mph / YawKinematicBelowMph)` (0 at W ≤ 0), × `(1 − w × DriftYawExempt)`; `r_steer = command + (r_steer − command) × dynamic`. r_steer clamped to ±`YawRateMax`.
5. Stored `YawRate = clamp(r_steer + r_spin, ±YawRateMax)`. Returned: the frame average, `command + (Σ r_steer·h / step − command) × dynamic + Σ r_spin·h / step`, clamped. `YawHeading += average × dt` (R13 #7).

**Spin** (`drivetrainGestures`, then `updateSpin`):
- **Stab (C2).** Throttle event: armed only by a lift (throttle from ≥ 0.3 to < 0.3). Keyboard and touch: back to ≥ 0.9 within `SpinStabSeconds` of the lift. Gamepad (the trigger is the throttle at that frame): the rise from < 0.3 to ≥ 0.9 within 0.6 / `SpinAnalogRate` s, from an armed lift. Flick event: |rawSteer| rises from < 0.5 to ≥ `SpinStabSteer`, or rawSteer reverses sign at ≥ `SpinStabSteer`; a wheel already held at a chassis reset is not a flick until it has been centred (section 7, item 5). The stab fires when both event clocks are ≤ `SpinFlickSeconds` (either order), throttle ≥ 0.9, |rawSteer| ≥ `SpinStabSteer` and speed < `SpinBelowMph`; then both clocks clear. `SpinStabNeedsFlick` 0 ignores the flick clock. On fire: window `SpinWindowSeconds`, dump `max(current dump, SpinStabDumpSlip)` fading over the window.
- **Power-brake** unchanged: W+S (or R2+L2) at < `StopGearMph` for ≥ `PowerBrakeMinHold`, then S released with throttle > 0.5: window, `PowerBrakeDumpSlip`, Launch event.
- **Target** `L_t` = slip × steer × speed × yaw-gate smoothsteps × S × tier scale × touch scale; 0 in the grace, while DriftBlend > 0.12 or with `SpinEnabled` 0; capped at `min(SpinHoldCap × S, 1)` outside a window (C4).
- **Grace (C3):** over when `GraceClock ≥ SpinStartGraceSeconds and (SpinStartGraceMph ≤ 0 or not GraceNeedsSpeed or GraceSpeedReached)`. `GraceNeedsSpeed` is true only after the anchored resume and the DriveReady false→true edge.
- **Rates:** build `SpinBuildRate`, decay `SpinDecayRate`, catch (throttle < 0.3 or counter-steer > 0.3) `SpinCatchRate`. `Caught` latches on a catch and clears when L rises; `Settling = Caught and L fell this frame`.
- **Direction** latches at L > 0.05 from the sign of the total yaw rate; clears below 0.02.
- **Warning (C4):** ShiftLight 4 while `L > max(SpinWarnLevel, holdCap + 0.05)` and rising.

**Drift engine assist (C5):** `DriveThrust + (A1 × thr − DriveThrust) × DriftAssistPlateauShare`, applied only while `DriveThrust > 0` as before; the gate reads DriveThrust before the blend (section 7, item 11).

**Pitch and roll** unchanged from the first build.

### 2e. State reset (CONTRACT 5.5)

`resetDrivetrainChassis` clears r_steer, r_spin, the yaw acceleration and command, authority, the lateral filter, pitch and roll, L, direction, window, the stab clocks and latches (flick latch `SteerLow` false, `LastSteer` 0), the power-brake clock, the dump slip, the steer limiter, the impact kick and boost flags, and restarts the grace with `GraceNeedsSpeed` false. `ResetGearbox` sets first gear (or the matching gear when moving, or N when anchored), no cut, `Duty` 0, `SteadyMph` = speed.

| Site | What happens |
|---|---|
| Start | both resets (grace: time only) |
| Stop | chassis reset, session state, caches |
| `ResetVehicle` (R) | chassis reset now, gearbox next frame (grace: time only) |
| Anchored branch | chassis reset every frame; N on the first anchored frame. On unanchor: grace with the speed clause; Launch only with throttle > 0.05 |
| `GameplayInputGate` locked | one reset on the lock edge (R13 #9) |
| DriveReady false→true | grace restarts with the speed clause |
| Switching the class on or off | both resets; off also clears the Feel attributes |

## 3. Decisions F1-F9 and contract deviations

| # | Decision (fix spec) | Contract text it departs from |
|---|---|---|
| F1 | Spin yaw is an additive state, `r = r_steer + r_spin`; r_spin ignores FeelWeight and the unwind scale. The old "spin keeps the yaw dynamic" blend is gone. | 5.3/5.4: one yaw state with the spin push in it; "after a catch, r eases to r_cmd over SpinSettleSeconds". Now r_spin settles at ≥ 3 / `SpinSettleSeconds` after a catch, and the authority still recovers over `SpinSettleSeconds`. |
| F2 | A stab is a lift, then a throttle stab and a steering flick together (`SpinStabNeedsFlick` 1). A held wheel plus W is never a stab. | 5.4 "Stab: throttle from below 0.3 to ≥ 0.9 within SpinStabSeconds while \|raw steer\| ≥ SpinStabSteer". Now it needs a lift to arm, and the flick (switchable). |
| F3 | A stab dumps `SpinStabDumpSlip` into the thrust slip. | 5.4 gives a dump to the power-brake only. Addition. |
| F4 | Grace speed clause only after an anchored start or a DriveReady restart. Spawn and R: time only. | 5.4 "whichever is later" for every grace start. |
| F5 | Drift: w = clamp(DriftBlend × `DriftExemptGain`, 0, 1) for the lateral lerp and the yaw-cap lerp; the yaw spring is exempted by `w × DriftYawExempt`; one downshift at a time inside the drift hold; assist from the plateau share. | 5.3 lerps by DriftBlend and keeps the yaw spring in drifts; fix 3 holds the gear for the whole drift; fix 7 takes the assist from gross DriveThrust only. |
| F6 | FeelGearing steps around a fixed envelope; Kd and the boost share from the delivered thrust. | 4.1 "scales the gear torque steps (GearTorqueExponent × dial)". Gr 0 is now the smooth envelope, not equal thrust in every gear. |
| F7 | Hold cap `min(SpinHoldCap × FeelSpin, 1)`. | 4.5 "SpinHoldCap: the largest spin amount without a gesture window". Above FeelSpin about 1.5 a held lock may spin; that is the dial's purpose. |
| F8 | Digital cruise upshift from the averaged throttle duty. | 5.2 fix 4: no cruise upshift at throttle ≤ `CruiseThrottleMin`, and `LiftHoldSeconds`. The digital cruise reads the duty, not the 0/1 throttle, and ignores the lift hold. |
| F9 | Overdrive holds while still above 0.98 of top-gear redline after the boost ends. | 5.2 fix 6 "while boost thrust is applied". |

Minor deviations from R13 #6-#13: the gate reset now runs on the lock edge only (5.5 said "whenever locked"); an unanchor with no throttle gives no Launch event and no launch slip (5.2 fix 9 said gear 1 and launch slip on every unanchor); `TopGearOverspeed` minimum 1.02.

## 4. Interfaces produced (unchanged by the fix pass)

**Feel attributes** (CONTRACT 3.1), written on change only, only while active and `Driving@FeelStateEnabled`, cleared by `Stop` and on deactivation: `FeelRpm` (10 rpm), `FeelIdleRpm`, `FeelRedlineRpm`, `FeelLimiterRpm`, `FeelGearCount`, `FeelGear` (−1/0/1..n), `FeelLoad` (0.02), `FeelShiftKind` and `FeelShiftStrength` (written before the revision), `FeelShiftRevision`, `FeelCut` (0.1), `FeelLimiterRevision`, `FeelThrustSlip` (clamp(ws/0.5) in 0.05), `FeelSpin` (0.05), `FeelSpinDirection` (+1 clockwise), `FeelOverdrive`. `FeelSlip` floor 2 mph while active.

**Telemetry** (3.2): the preallocated `Drivetrain.Telemetry` with `Gear`, `GearRevision`, `RpmFraction` (= clamp(rpm/R × `HudRedlineSweep`, 0, 1)), `ShiftLight` (4 spin warning, 3 limiter, 2 shift, 1 warm), `Spin`, `Overdrive`; passed as `PublishMobile`'s third argument on frames where it was filled.

**`VehicleDynamics.GearForSpeed`** (3.3): as in the first build (weak-keyed cache, 4 Hz re-check, one gear per call, nil when inactive). Audio requiring VehicleDynamics is a new dependency.

## 5. Preserved behaviour (CONTRACT 5.6)

DRIVE-01, the raw-steer bank, reverse rules, hover, mini-boost rules, Balance sites and `FeelSpeedMph` are untouched. Driving rules hold for the new code: no per-frame allocation, no new connections, no extra raycasts, no `GetDescendants`; every smoothing step is `1 − exp` or sub-stepped; dt clamped to 0..0.1; NaN guards on every new state (r_steer, r_spin, frame average, duty, steady speed, steer limiter start values); zero force while anchored. No existing attribute, function or state field from `before/` is renamed or removed, and the `Controller` signatures are unchanged.

## 6. Test hooks (Play, Client datamodel, read-only)

Debug attributes need `Dynamics@DebugAttributes` (true in PR98): `DynamicsGear`, `DynamicsRpm`, `DynamicsWheelspin`, `DynamicsDriveThrust`, `DynamicsEngineLoad`, `DynamicsBoostShare`, `DynamicsOverdrive`, rebuild values (`DynamicsDesignTopMph`, `DynamicsBoostTopMph`, `DynamicsGearRedlineMph`, `DynamicsTraction`, `DynamicsDrivetrainDrag`, `DynamicsBoostShareHigh`, `DynamicsBrakeV2`, `DynamicsLateralCapBase`), `DynamicsDrivetrainClass`, `DynamicsYawRate` (total), `DynamicsYawRateCommand`, `DynamicsSpin`, `DynamicsSpinTarget`, `DynamicsSpinWindow`, `DynamicsSpinGraceSeconds`, `DynamicsSpinGraceSpeedReached`, `DynamicsPowerBrakeHeld`, `DynamicsExtraSlip`, `DynamicsLateralAccel`, `DynamicsLateralCap`, `DynamicsSteerKeyboard`, `DynamicsShiftLight`. **New:** `DynamicsSpinYawRate` (r_spin), `DynamicsSpinGraceNeedsSpeed`, `DynamicsThrottleDuty`.

Checks:
- **Parity:** `Drivetrain.exotic@Enabled` 0 → within 0.25 s the 16 Feel attributes are nil, telemetry clears, driving matches before-install.
- **Grace after spawn or R:** `DynamicsSpinGraceNeedsSpeed` false; after 3 s a power-brake (W+S ≥ 0.3 s, hold D, release S) gives `DynamicsSpinWindow` 0.7, `DynamicsExtraSlip` 0.5 fading, `FeelSpin` rising.
- **Flick-stab:** at 0-20 mph, W 0.35 s, lift 0.2 s, then D and W together → window 0.7, `DynamicsExtraSlip` 0.3 fading.
- **Must not open a window:** D held, lift 0.15-0.3 s, W again; A and W together from rest; lift 0.3 s, D, W 0.25 s later. With `SpinStabNeedsFlick` 0 the first case opens one.
- **FeelWeight independence:** in a power-brake donut, `DynamicsYawRate` peaks near `SpinMaxYawRate` (3.6) at FeelWeight 0, 1 and 2.5; `DynamicsSpinYawRate` carries the spin's share.
- **Drift:** a long drift steps `DynamicsGear` down one at a time with `DriftHoldDownshift` 1; held with 0.
- **Tap W at 40 mph:** `DynamicsThrottleDuty` settles near the tap share, one upshift, then `DynamicsRpm` ≤ about 0.65 R.
- **Overdrive:** boost to the top, release boost with W held: `DynamicsOverdrive` stays true until below 0.98 top-gear redline and `FeelLimiterRevision` does not count.
- **Gate lock while moving:** `DynamicsLateralAccel` does not collapse each locked frame (one reset only).
- **Teleport with no throttle:** `FeelShiftRevision` does not change.
- **FeelGearing 0 vs 1:** `DynamicsDrivetrainDrag` and the top speed are the same; 0-100 within a few percent (the model part measures it).

## 7. Interpretations for the model parity audit

Where the fix spec leaves a detail open, the Lua does this:
1. **Sub-steps:** `steps = clamp(ceil(step × max(ω, k_s) × 4), 1, 16)`. In each sub-step the push gate reads the start values; then r_steer (velocity, then position), then `r_spin += push·h − r_spin × min(k_s·h, 1)`. The sums for the frame average are taken after each sub-step's update. The `min(k_s·h, 1)` guard only differs from the spec form when k_s·h > 1.
2. **Clamps:** r_steer is stored clamped to ±`YawRateMax` (as the first build did); the stored total and the frame average are clamped again. The impact kick goes into r_steer.
3. **"L falling after a catch":** `Caught` is set on any frame where the catch condition holds, cleared on a frame where L rises by more than 1e-4; `Settling = Caught and L < previous L`.
4. **Stab clocks:** both clocks gain `step` at the top of `drivetrainGestures`, an event sets its clock to 0, and the fire test runs after both events are updated (`STAB_NONE` = infinity). The lift clock is 0 on the lift frame and gains `step` on each later frame, including the re-press frame. The `+ step` frame tolerance on `SpinStabSeconds` and `0.6 / SpinAnalogRate` is kept from the first build. The arm is used up on the first frame at ≥ 0.9.
5. **Flick "rises from < 0.5":** a latch, set while |rawSteer| < min(0.5, `SpinStabSteer`) and cleared at ≥ `SpinStabSteer`; a sweep over several frames counts. The sign test compares with the previous frame's rawSteer. **Initial state:** every chassis reset (Start, R, the anchored branch, the gate lock edge, class switch) sets `SteerLow` false and `LastSteer` 0. A wheel already held at ≥ `SpinStabSteer` through a reset is therefore not a flick (neither the rise nor the sign test can fire) until it has passed back under min(0.5, `SpinStabSteer`). In the game a car always has centred frames after spawn, so a harness that starts its runs with the latch set ("wheel centred before t = 0") matches the game only when its first steered frame follows a centred one; such a harness should say so.
6. **Stab dump:** `DumpSlip = max(current effective dump, SpinStabDumpSlip)`, where the effective dump is `DumpSlip × max(1 − DumpClock / max(SpinWindowSeconds, 0.05), 0)`. This avoids reusing a stale stored dump.
7. **Envelope:** `MidMph[g] = (S[g−1] + S[g]) / 2`, `S[0] = 0`; evaluated at the drift-blended road speed; `mult` floored at 0. Kd uses `mult(count, Vt)` and the boost share `mult(count, Vb)`; for the stock configs both equal `MultBase[count]`, because Vt lies above the top gear's mid-band. The limiter duty (Overdrive off) multiplies after the traction and slide terms.
8. **Drift-hold downshift:** only in the drift hold, not while the spin hold also applies.
9. **Digital cruise:** "not analog" means the last throttle device was not a gamepad trigger (sticky `Drivetrain.AnalogInput`). There is no condition on the current frame's throttle. The averages update before the brain. It is evaluated only when the normal rules did not upshift.
10. **Grace baseline:** switching the class on takes the current DriveReady as baseline, so it is not counted as an edge.
11. **Drift assist gate:** the test is `DriveThrust > 0` on the step's DriveThrust, before the plateau blend (`if DriveThrust > 0 then assist from DriveThrust + (A1 × thr − DriveThrust) × share`). A drift frame with DriveThrust 0 and throttle above `DriftThrottleMinimum` (a full limiter cut) adds no assist, even though the blended value would be positive. Gating on the blended value instead would add `share × A1 × thr × assist` on those frames.

## 8. Generated checks (first build, before the fix pass; not re-run)

These are a scratch Python port of the first build at 60 Hz, kept for orientation only. The fix pass changes Kd (the slide loss is now included) and gear thrust at FeelGearing ≠ 1, so the numbers may shift a little. `model/RESULTS.md` is the authority.

| Car | Vt / Vb mph | Gear redline mph | 0-60 | 0-100 | t(0.9 Vt) | Top after 30 s | Boosted top | BrakeV2 / today |
|---|---|---|---|---|---|---|---|---|
| E Stinger 220 | 103.6 / 126.8 | 28/40/53/66/80/94/110 | 3.63 | 14.97 | 10.3 | 103.5 | 126.8 | 37.3 / 40.4 |
| C Aurora 540 | 114.4 / 140.4 | 31/45/58/73/88/104/121 | 2.83 | 8.15 | 9.3 | 114.4 | 140.4 | 43.1 / 51.6 |
| A Rosso 800 | 162.2 / 200.0 | 44/63/83/103/125/148/172 | 2.00 | 4.15 | 10.5 | 162.0 | 200.0 | 59.5 / 87.3 |
| S Seraph 938 | 173.6 / 217.2 | 47/68/89/111/134/158/184 | 1.88 | 3.92 | 11.3 | 173.2 | 217.2 | 71.5 / 108.4 |

**Fix-pass sanity check (scratch port of the new `drivetrainYaw`, generated):**
- Peak yaw rate in a full spin at standstill: 3.63-3.66 rad/s at FeelWeight 0, 0.5, 1 and 2.5.
- Heading run-on after a step release from 1 rad/s at 60 mph: 4.1-4.4° across 20-144 Hz (keyboard limiter not included).

## 9. Risks and open items

1. **Not driven.** Everything is generated and compile-checked only. The feel, the stab timing and the drift parity need the model results and Play.
2. **Spin defaults.** `SpinFlickSeconds` 0.15 is tight on a gamepad, and the stick must cross 0.5 to count as a flick. `SpinStabNeedsFlick` 0 is the fallback.
3. **FeelSpin above about 1.5** lets a held lock spin (F7, by design). The CONTRACT 9 hold targets apply at FeelSpin 1.
4. **Digital cruise right after a gearbox reset at speed:** the duty starts at 0. A steady full-throttle hold in a gear below top could short-shift once within about 1.8 s. Acceleration normally fails the steady test.
5. **Extreme FeelGearing:** at Gr 2 with `GearTorqueExponent` above about 1.6, the bottom of a gear's band can reach the 0 floor (no thrust there).
6. **r_spin overshoot:** the push gate works per sub-step, so r_spin can pass `SpinMaxYawRate` by a few hundredths. The total is clamped to `YawRateMax` ≤ 5, so the camera invariant holds.
7. **Touch power-brake not detected:** `GetMobileInput` sums the pedals, so both pedals read 0. Touch has the stab only.
8. **Roll sign** leans out of the turn (at most 3°). Use a negative `RollDegreesPerG` if it reads wrong.
9. **`Dynamics` config edits are not live** until the profile key changes. Class-folder edits are live.
10. **Debug attributes are on in PR98.** About 18 extra on-change debug writes per frame. Switch them off before publish.
11. **E-tier pace** changes a lot by design (0-100 about 15 s against 8.3 s today). Free-roam job pacing and `DuelService` timeouts may notice.
12. **Not verified in Play:** enter and exit cycles, the camera invariant, and remote `GearForSpeed` on a published server.

### Defaults from the model (integrator, 2026-10-20)

The section 10 table now carries the model's proposed defaults (`model/RESULTS.md`, generated, not measured), which pass
every CONTRACT 9 and fix-spec D target on all six stock cars and the as-spawned Seraph. Changed from CONTRACT section 4
or spec section B: `SteerRiseSeconds` 0.2 to 0.12, `SteerReturnRate` 14 to 25, `YawOmega` 9 to 20, `DriftExemptGain` 2 to 4,
`SpinSlipStart` 0.12 to 0.04, `SpinSlipWidth` 0.25 to 0.08, `SpinGripLoss` 0.7 to 0.85, `SpinYawAccel` 7 to 25,
`SpinTierFloor` 0.5 to 0.8, `SpinBuildRate` 3.5 to 6, `SpinWindowSeconds` 0.7 to 0.9, `SpinBelowMph` 25 to 30.
Why, per value: `model/RESULTS.md` "Proposed defaults". Spin strength is tied to `YawOmega` (the spin yaw decays at
YawOmega x weight / (2 YawDamping)): lower `YawOmega` later and retune `SpinYawAccel` with it (25 at 20, about 15 at 12).
Agent Play check with these values on the as-spawned Seraph: power-brake and flick-stab spin, holds and a lifted U-turn
stay at the 0.35 hold cap.

## 10. Config values: `ReplicatedStorage.Config.Vehicles.Drivetrain.exotic`

The `Drivetrain` folder carries `Enabled` 1 (0 = every class drives as before), `DrivetrainFeelInstalled` true and `Notes`. The table is generated from `physics/config.py`; each row's text is the attribute's `_RaisingThisDoes` string. Numbers are clamped in code to the ranges in `DRIVETRAIN_NUMBERS`; switches (0/1) are in `DRIVETRAIN_SWITCHES`.

| Attribute | Default | Range | Raising it (and what 0 does) |
|---|---|---|---|
| `Enabled` | 1 | 0/1 | 1 = this class uses the drivetrain (gearbox, weight, spin-out, rpm HUD); 0 = it drives, sounds and displays exactly as before. |
| `FeelWeight` | 1 | 0..2.5 | Heavier car: more yaw inertia, slower steering build-up on keys and touch, slower grip build, more pitch and roll, longer braking. 0 = today's light, instant feel (range 0-2.5). |
| `FeelGearing` | 1 | 0..2 | Gears felt more: bigger torque steps around the same average pull (pace unchanged), longer and deeper shift cuts, snappier rev drops, stronger shift cues. 0 = CVT-smooth with no cut (range 0-2). |
| `FeelAcceleration` | 1 | 0.5..1.5 | More engine thrust in every gear (quicker 0-60 and mid-range); top speed stays today's. Range 0.5-1.5. |
| `FeelGrip` | 1 | 0.6..1.6 | Higher cornering grip limit and more traction off the line (less wheelspin). Range 0.6-1.6. |
| `FeelSpin` | 1 | 0..2.5 | Spins more readily and more violently: scales the spin target, the spin push and the no-gesture hold cap (above 1 a held lock can wiggle harder or spin). 0 = it never spins (range 0-2.5). |
| `FeelEngineBrake` | 1 | 0..2 | Stronger slowing when you lift off, more in low gears. 0 = coasting is only drag and rolling resistance (range 0-2). |
| `GearCount` | 7 | 1..9 | More forward gears are used (up to the number of GearRatios, at most 9); fewer gears give longer, bigger steps. |
| `IdleRpm` | 1100 | 300..4000 | Higher idle and lowest rpm (gauge, sound); 0 is not allowed (minimum 300). |
| `RedlineRpm` | 8500 | 2000..20000 | Higher redline: the rpm scale stretches (gauge, sound, shift points scale with it); gear speeds do not change. |
| `LimiterRpm` | 8600 | 2000..24000 | Limiter sits further above redline (flare and limiter peak); clamped to 1-1.2 x RedlineRpm. |
| `GearTorqueExponent` | 0.8 | 0..2 | Bigger drop in thrust in each higher gear (more real, slower top-end pull). 0 = the same thrust in every gear. |
| `TopGearOverspeed` | 1.06 | 1.02..1.5 | Top gear runs out further above the top speed, so the engine sits lower in its rev range at top speed. Minimum 1.02: nearer 1 the car would sit on the limiter at top speed. |
| `LaunchRpmFraction` | 0.5 | 0..1 | Higher launch and power-brake revs in first gear (clutch slip, fraction of redline). 0 = first gear follows road speed from idle. |
| `EngineRiseSeconds` | 0.06 | 0.01..1 | Revs rise more lazily (heavier flywheel feel); falls scale with it through EngineFallScale. Minimum 0.01. |
| `EngineFallScale` | 1.5 | 0.2..5 | Revs fall more slowly than they rise (x EngineRiseSeconds). 1 = same speed up and down. |
| `ShiftRpmSeconds` | 0.05 | 0.005..1 | Slower rev drop after an upshift (divided by FeelGearing). Minimum 0.005. |
| `ThrustSlipFlare` | 0.6 | 0..2 | Revs flare higher when the thrust slips (launch, burnout). 0 = no flare. |
| `ShiftCutSeconds` | 0.06 | 0..0.5 | Longer torque cut on each upshift (x FeelGearing). 0 = no cut. |
| `ShiftCutTorque` | 0.45 | 0..1 | Share of thrust kept during the upshift cut: higher = gentler cut, 1 = no cut, 0 = full cut. |
| `ShiftBlendSeconds` | 0.06 | 0..0.5 | Slower thrust return after the upshift cut (x FeelGearing). 0 = thrust returns at once. |
| `DownshiftBlendSeconds` | 0.08 | 0.01..0.5 | Slower rev-matched rise after a downshift (no torque cut on downshifts). Minimum 0.01. |
| `ShiftMinIntervalSeconds` | 0.25 | 0.05..2 | Longer minimum time between shifts (less hunting, slower gear changes). Minimum 0.05. |
| `UpshiftFlat` | 0.97 | 0.5..1 | Holds each gear closer to redline at full throttle (fraction of redline). Above 1 is not allowed. |
| `UpshiftPartLow` | 0.62 | 0.3..1 | Later upshifts at light part throttle (0.3 throttle), fraction of redline. |
| `UpshiftPartHigh` | 0.85 | 0.3..1 | Later upshifts at heavy part throttle (0.9 throttle), fraction of redline. |
| `UpshiftCruise` | 0.45 | 0.2..1 | Later short-shifts when cruising (throttle between CruiseThrottleMin and 0.3), fraction of redline. |
| `CruiseThrottleMin` | 0.05 | 0..0.3 | More throttle needed before any cruise upshift; below it no upshift at all (except off the limiter). |
| `UpshiftMinLand` | 0.33 | 0..0.9 | A cruise upshift must land at a higher rpm (fraction of redline), so it short-shifts less. 0 = no limit. |
| `LiftHoldSeconds` | 0.8 | 0..3 | Holds the gear longer after a lift before a part-throttle upshift (less churn when tapping). 0 = no hold. Does not block the digital cruise upshift. |
| `DigitalCruiseEnabled` | 1 | 0/1 | 1 = with keyboard or touch, tapping the throttle at a steady speed short-shifts up a gear, so the engine does not drone near redline; 0 = only the instant 0/1 throttle picks the gear. |
| `DigitalDutySeconds` | 1.5 | 0.05..10 | The averaged throttle duty and the steady-speed average follow more slowly (seconds), so a cruise needs a longer steady spell before it short-shifts. Minimum 0.05. |
| `DigitalCruiseDutyMax` | 0.7 | 0..1 | Heavier tapping still counts as cruising (averaged throttle duty at or below this short-shifts; a held throttle is 1). 0 = never. |
| `DigitalCruiseSteadyMph` | 3 | 0..50 | Speed may wander further from its average (mph) and still count as steady for a cruise short-shift. 0 = only a perfectly steady speed. |
| `DigitalCruiseUpshift` | 0.6 | 0.2..1 | A cruising car on keyboard or touch holds its gear to higher revs before it short-shifts (fraction of redline). |
| `DigitalCruiseLand` | 0.5 | 0..0.95 | A cruise short-shift must land at higher revs (fraction of redline; UpshiftMinLand also applies). Keep it above KickdownBelowFraction so the next tap does not kick back down. 0 = UpshiftMinLand only. |
| `DownshiftBrakeLand` | 0.82 | 0.3..1 | Braking downshifts happen earlier, landing at up to this fraction of redline (more engine braking, more blips). |
| `DownshiftCoastFraction` | 0.3 | 0..0.9 | Coasting downshifts happen at higher rpm (fraction of redline). 0 = no coasting downshifts. |
| `DownshiftCoastLand` | 0.65 | 0.3..1 | Coasting and lugging downshifts may land at a higher rpm (fraction of redline). |
| `KickdownThrottle` | 0.95 | 0.5..1 | More throttle needed for a kickdown (several gears at once). |
| `KickdownBelowFraction` | 0.45 | 0..1 | Kickdown also fires at higher rpm (fraction of redline). 0 = no kickdown. |
| `KickdownLand` | 0.88 | 0.3..1 | Kickdown may drop to a lower gear, landing at up to this fraction of redline (harder kick). |
| `KickdownHoldSeconds` | 0.12 | 0..1 | Full throttle must be held longer before a kickdown (fewer accidental kickdowns). 0 = instant. |
| `StopGearMph` | 3 | 0..20 | First gear is selected below a higher speed (mph); also the standstill speed for the power-brake. |
| `LimiterOnSeconds` | 0.03 | 0.005..0.5 | Longer drive bursts between limiter cuts (slower bounce). Minimum 0.005. |
| `LimiterCutSeconds` | 0.045 | 0..0.5 | Longer limiter cuts (harder, slower bounce). 0 = the limiter holds without cutting. |
| `LimiterHysteresisRpm` | 150 | 0..2000 | Deeper limiter bounce: the rpm drops further below redline in each cut. 0 = minimal bounce. |
| `NeutralRevEnabled` | 1 | 0/1 | 1 = the engine revs in neutral with the throttle during a countdown (no force); 0 = idles until GO. |
| `NeutralRevTarget` | 1.02 | 0..1.2 | Higher neutral revs at full throttle (fraction of redline); above 1 bounces the limiter. 0 = stays at idle. |
| `TractionG` | 1.15 | 0.3..4 | More traction off the line (g): less wheelspin and fewer spins, quicker launches up to the thrust. |
| `TractionGripExponent` | 0.15 | 0..1 | LateralGrip stat matters more for traction. 0 = every car gets the same traction. |
| `TractionTierBonusG` | 0.25 | 0..2 | Upgraded cars (PI toward TierFullPI) get more extra traction, felt off the line. 0 = no tier bonus. |
| `TierStartPI` | 250 | 0..2000 | PI where the tier traction bonus and spin authority start rising; higher = only stronger cars get them. |
| `TierFullPI` | 750 | 0..2000 | PI where the tier traction bonus and spin authority are full; higher = slower build across tiers. |
| `TractionAssist` | 0.35 | 0..1 | Removes more of the thrust slip (fewer launch flares and spins). 0 = no assist, 1 = never slips. |
| `SlideGripFraction` | 0.88 | 0.3..1 | Less thrust lost while the thrust slips (1 = slipping costs nothing; lower = burnouts are slower). |
| `RollingDecel` | 0.8 | 0..10 | More constant rolling resistance (studs/s^2): coasts down sooner. 0 = none (top speed is kept by re-deriving drag). |
| `RollingDecelPerStud` | 0.004 | 0..0.1 | More speed-proportional resistance: coasts down sooner at speed. 0 = none (top speed is kept). |
| `EngineBrakeDecel` | 1.5 | 0..20 | Stronger engine braking on a lift (studs/s^2 in top gear, more in low gears; x FeelEngineBrake). 0 = none. |
| `BrakeDecel` | 70 | 5..200 | Stronger brakes at FeelWeight 1 (studs/s^2 at the reference brake stat). FeelWeight 0 uses today's brakes instead. |
| `BrakeForceExponent` | 0.35 | 0..2 | Braking stat matters more for brake strength. 0 = every car brakes the same. |
| `BrakeFactorMin` | 0.75 | 0.1..3 | Weakest cars brake harder (lower clamp of the braking stat factor). |
| `BrakeFactorMax` | 1.4 | 0.1..3 | Strongest cars may brake harder (upper clamp of the braking stat factor). |
| `BoostShapeEnabled` | 1 | 0/1 | 1 = boost fades with speed so the boosted top speed stays today's; 0 = full boost at every speed (the speed guard still holds the top). |
| `BoostShareMin` | 0.15 | 0..1 | Keeps more boost near the boosted top speed (lower bound of the fade); 1 = no fade. |
| `SpeedGuardStrength` | 2 | 0..20 | Holds the boosted top speed harder above SpeedGuardOverBoostTop x boosted top. 0 = no guard. |
| `SpeedGuardOverBoostTop` | 1.03 | 1..1.5 | Lets the car go further past today's boosted top speed before the guard bites (1 = exactly today's). |
| `OverdriveEnabled` | 1 | 0/1 | 1 = boosting past top-gear redline pins the engine at redline with no limiter cut (Overdrive); 0 = it hits the limiter. |
| `SteerRiseSeconds` | 0.12 | 0..1 | Slower keyboard steering build-up to full lock (x FeelWeight). 0 = instant like today. |
| `SteerReturnRate` | 25 | 1..100 | Keyboard steering returns to centre faster (per second, at FeelWeight 1 or more). |
| `TouchSteerRate` | 10 | 1..100 | Touch steering follows the finger faster (per second, at FeelWeight 1 or more); gamepad is never limited. |
| `YawOmega` | 20 | 1..60 | Quicker, stiffer turn-in (rad/s; divided by FeelWeight); lower = more yaw inertia and lag. |
| `YawDamping` | 0.75 | 0.1..2 | Less overshoot and settle after turn-in; lower = more wobble that reads as mass. |
| `YawWeightExponent` | 0.5 | 0..2 | Weight stat matters more for yaw inertia. 0 = every car turns in the same. |
| `YawWeightMin` | 0.75 | 0.2..2 | Heaviest cars turn in quicker (lower clamp of the weight factor). |
| `YawWeightMax` | 1.3 | 0.2..3 | Lightest cars may turn in quicker (upper clamp of the weight factor). |
| `YawKinematicBelowMph` | 15 | 0..80 | Turning stays exactly like today up to a higher speed (parking, U-turns); inertia blends in above it. 0 = inertia at every speed. |
| `YawUnwindScale` | 2 | 0.5..5 | Car stops turning faster after you release the steering (less run-on). 1 = same as turn-in. |
| `YawRateMax` | 5 | 0.5..5 | Highest yaw rate allowed (rad/s, at most 5 so the camera never cuts). |
| `LateralCapG` | 3.4 | 0.5..20 | Higher cornering grip limit (g): tighter fast corners, later understeer. Lower = heavier, wider lines. |
| `LateralCapGripExponent` | 0.25 | 0..1 | LateralGrip stat matters more for the grip limit. 0 = every car has the same limit. |
| `LateralCurveShape` | 1.4 | 1..1.9 | Grip falls away more once past the limit (sharper peak). 1 = grip never drops past the limit (1-1.9). |
| `YawCapMargin` | 0.9 | 0.3..3 | Car may turn faster than its grip carries it at the limit (more slide, less understeer). Lower = more understeer. |
| `GripRelaxStuds` | 2 | 0..20 | Grip builds over more travel when the car starts to slide (looser, heavier feel; x FeelWeight). 0 = instant. |
| `DriftCapExempt` | 1 | 0/1 | 1 = drifts keep today's uncapped grip and yaw (drift lines unchanged), weighted by DriftExemptGain and DriftYawExempt; 0 = the grip limit and the yaw inertia also apply in drifts. |
| `DriftExemptGain` | 4 | 0..10 | The drift's own grip and yaw take over sooner as a drift builds (exemption weight = drift blend x this, at most 1), so a drift entry does not run into the grip limit. 0 = no exemption; 1 = it follows the drift blend. |
| `DriftYawExempt` | 1 | 0..1 | Share of the drift exemption taken off the yaw inertia (0-1): 1 = drift yaw responds exactly as today; lower gives drifts some yaw weight. 0 = drifts keep the full yaw inertia. |
| `DriftHoldDownshift` | 1 | 0/1 | 1 = inside a drift the gearbox may step down one gear at a time (when the lower gear lands at or below DownshiftBrakeLand), so a drift does not bog in a high gear; 0 = the gear is held for the whole drift. |
| `DriftAssistPlateauShare` | 0.9 | 0..1 | Drift engine push follows the engine's full first-gear pull more than the current gear's thrust (0-1), so drifts in high gears keep today's push. 0 = the push follows the current gear's thrust only. |
| `PitchDegreesPerG` | 2.4 | 0..10 | More nose-up under acceleration and nose-down under braking and shift cuts (degrees per g, x FeelWeight). 0 = level. |
| `PitchMaxDegrees` | 5 | 0..15 | Allows a larger pitch angle (degrees). 0 = no pitch. |
| `PitchOmega` | 9 | 1..40 | Pitch and roll follow quicker and snappier (rad/s); lower = slower, floatier body motion. |
| `PitchDamping` | 0.6 | 0.1..2 | Less bounce on pitch and roll; lower = more overshoot. |
| `RollDegreesPerG` | 0.9 | -5..5 | More body roll away from the turn from cornering g (degrees per g, x FeelWeight). 0 = off; negative leans into the turn instead. The steering bank is separate and unchanged. |
| `RollMaxDegrees` | 3 | 0..10 | Allows a larger body roll angle (degrees). 0 = no roll. |
| `ImpactYawKick` | 0.6 | 0..5 | Hits off the car's centre line turn it more (rad/s per 100 studs/s of impact). 0 = impacts never turn the car. |
| `SpinEnabled` | 1 | 0/1 | 1 = low-speed spin-outs are possible; 0 = the car never spins. |
| `SpinStabSeconds` | 0.4 | 0..2 | Keyboard and touch: the throttle may come back (to 0.9 or more) longer after a lift and still count as a stab (seconds from the lift). 0 = only an instant re-press. |
| `SpinStabSteer` | 0.8 | 0..1 | More steering lock needed for a stab and for the steering flick that goes with it (0-1). |
| `SpinAnalogRate` | 4 | 0.5..50 | Gamepad throttle must rise faster after a lift (per second, from under 0.3 to 0.9) to count as a stab; lower = easier stabs on a trigger. |
| `SpinStabNeedsFlick` | 1 | 0/1 | 1 = a stab also needs a steering flick (lock applied or reversed within SpinFlickSeconds of the throttle stab), so a lifted U-turn or pull-out with the wheel held never spins; 0 = a plain lift-and-stab with the lock held is enough. |
| `SpinFlickSeconds` | 0.15 | 0..2 | The steering flick and the throttle stab may be further apart (either order) and still count as a stab: easier stabs. 0 = they must land on the same frame. |
| `SpinStabDumpSlip` | 0.3 | 0..2 | Harder wheelspin and a bigger spin from a stab (extra thrust slip, fading over the spin window like the power-brake). 0 = a stab adds no slip. |
| `SpinWindowSeconds` | 0.9 | 0..5 | Spin window after a stab or power-brake lasts longer: a bigger spin can build. 0 = gestures do nothing. |
| `PowerBrakeEnabled` | 1 | 0/1 | 1 = holding forward and brake at a standstill, then releasing brake, dumps the revs (burnout start); 0 = off. |
| `PowerBrakeMinHold` | 0.3 | 0..5 | Forward and brake must be held together longer before the release counts (seconds). |
| `PowerBrakeDumpSlip` | 0.5 | 0..2 | Harder burnout and more spin on a power-brake release (extra thrust slip, fading over the window). 0 = no dump. |
| `SpinBelowMph` | 30 | 0..100 | Spins can start at higher speed (mph; full authority below it, then fading over SpinFadeMph). |
| `SpinFadeMph` | 12 | 0.5..100 | Spin authority fades out over a wider speed band above SpinBelowMph. |
| `SpinSteerStart` | 0.6 | 0..1 | More steering needed before a spin can build (0-1). |
| `SpinSteerWidth` | 0.35 | 0.01..1 | Spin authority reaches full only at more steering past SpinSteerStart. |
| `SpinSlipStart` | 0.04 | 0..2 | More thrust slip needed before a spin can build (fewer spins). |
| `SpinSlipWidth` | 0.08 | 0.01..2 | Spin authority reaches full only at more thrust slip past SpinSlipStart. |
| `SpinBuildRate` | 6 | 0..30 | Spins build faster (per second). 0 = never builds. |
| `SpinDecayRate` | 2.5 | 0..30 | Spins die down faster on their own (per second). |
| `SpinCatchRate` | 8 | 0..60 | Lifting (under 0.3 throttle) or counter-steering catches the spin faster (per second). |
| `SpinSettleSeconds` | 0.3 | 0..3 | Car eases back to normal steering more slowly after a catch (seconds; the spin's own yaw dies at least as fast as 3 / this). 0 = snaps back. |
| `SpinYawAccel` | 25 | 0..40 | Spins rotate the car harder (rad/s^2 at full spin, x FeelSpin). 0 = no rotation push. |
| `SpinMaxYawRate` | 3.6 | 0..5 | Faster spin rotation allowed (rad/s; never above YawRateMax). |
| `SpinGripLoss` | 0.85 | 0..1 | More sideways grip lost in a spin (0-1): the car slides further. |
| `SpinThrustLoss` | 0.35 | 0..1 | More thrust lost in a spin (0-1). |
| `SpinYawAuthorityLoss` | 0.85 | 0..1 | Steering loses more of its hold on the yaw in a spin (0-1): the spin carries on more freely. |
| `SpinHoldCap` | 0.35 | 0..1 | A bigger wiggle is allowed without a gesture (largest spin amount outside a stab or power-brake window, x FeelSpin, at most 1). 0 = only gestures spin. |
| `SpinTierFloor` | 0.8 | 0..1 | Low-PI cars get more spin authority (share at TierStartPI; full at TierFullPI). |
| `SpinTouchScale` | 0.5 | 0..2 | Touch players spin more readily (x spin target). 0 = no spins on touch. |
| `SpinStartGraceSeconds` | 3 | 0..30 | Longer no-spin grace after a start, reset or unanchor (seconds). |
| `SpinStartGraceMph` | 38 | 0..200 | After an anchored start or a DriveReady restart the grace also lasts until the car has gone faster than this (mph), whichever is later; spawning and R use the time only. 0 = time only. |
| `SpinWarnLevel` | 0.25 | 0..1 | The amber spin warning (HUD shift light 4) comes later, at a bigger spin amount (never below the hold cap + 0.05). |
| `HudRedlineSweep` | 0.87 | 0.5..1 | Redline sits further round the gauge arc (fraction of the sweep); the limiter is just past it. |
| `HudShiftLeadSeconds` | 0.25 | 0..2 | Shift light comes on earlier before a planned upshift (seconds of rpm climb). 0 = only at the shift point. |
| `HudShiftMinFraction` | 0.85 | 0..1 | Shift light only for upshifts planned nearer redline (fraction); 0 = also for cruise short-shifts. |
| `HudWarmBandFraction` | 0.12 | 0..0.5 | Warm light starts further below the flash point (fraction of redline). 0 = no warm stage. |
| `GearRatios` | `3.15,2.18,1.66,1.33,1.10,0.93,0.80` | text | Gear ratios, first to top, comma separated. Wider gaps = bigger rev drops and torque steps; the gear speeds come from each car's own top speed, so only the ratios between gears matter. |
| `TorqueCurve` | `0:0.55,0.3:0.80,0.5:0.93,0.7:1,0.85:0.98,1:0.86` | text | Engine torque shape as rpm/redline:torque pairs (peak 1). Raising a point gives more pull at that rpm; a flatter curve feels like a big lazy engine, a peaky one like a screamer. |
