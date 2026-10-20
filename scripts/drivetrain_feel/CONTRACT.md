# drivetrain_feel contract: Exotic gearbox, weight, spin-out, engine voice, rpm HUD

- **Lane:** High-Risk. It touches the driving, audio, HUD, camera and VFX owners.
- **Place:** PR98 (103397770260610) only.
- **Approved by Oscar:** 2026-10-20, the plan in `C:\Users\Oscar\.claude\plans\robust-seeking-comet.md`.
- **Scope changes from Oscar after approval:**
  - Exotic class only for now.
  - Ignore races and time trials.
  - Everything must be easily tunable later: weight, gearing feel, spin and so on.
  - Auto mode: run autonomously.
- **Amended 2026-10-20** by `reviews/15_fix_spec.md` (integrator decisions F1-F9 and new attributes); installed defaults
  are in `physics/config.py`, as proposed by `model/RESULTS.md`.
- **Background:**
  - Survey reports: `design/survey_*.md`.
  - Design draft: `design/design_draft.md`.
  - Critiques: `design/critique_*.md`.

  This contract overrides the draft wherever they differ. Where it is silent, follow the draft as corrected by the critiques. Every critique item listed under "Required fixes" is mandatory.

## 1. Goal and scope

Make an Exotic car (`CategoryId == "exotic"`) drive like a heavy car with a real gearbox:
- an automatic gearbox with rpm, torque curve, shift cuts, rev drops and a bouncing limiter;
- more weight: yaw inertia, a steering build-up on digital input, saturating grip, pitch and roll from real acceleration, momentum and engine braking;
- deliberate low-speed spin-outs;
- grungier, gear-aware engine sound with a sci-fi layer;
- an rpm and gear HUD, camera spin mode, shift nod, and VFX cues.

**Category gating.** Everything new is driven by one per-class config folder, `ReplicatedStorage.Config.Vehicles.Drivetrain.<CategoryId>`.
- When the folder is absent, or its `Enabled` is 0, or the global `Drivetrain@Enabled` is 0, the car drives, sounds and displays **exactly as today**: byte-for-byte the old code path.
- This delivery creates only `Drivetrain.exotic`.
- A later class is added by copying the folder, renaming it to the CategoryId (`bruiser`, `muscle`) and retuning. Code must make that work with no code change.

**Not in scope:**
- races, time trials, medals, PBs, economy;
- Piercer and Muscle tuning or voices;
- a manual gearbox;
- haptics;
- garage and dealership preview audio;
- Classic UI gauge changes;
- any server script, remote, saved data, stat, PerformanceIndex or catalogue value.

## 2. Owners (extend only; no new scripts, remotes or startup paths)

Each part owns specific scripts and writes **full after-files** for them. Exactly one part owns each script.

| Part | Folder | Scripts owned (before/ copies are the base) | Config it creates |
|---|---|---|---|
| physics | `physics/` | `DrivingClient`, `VehicleDynamics` | `Config.Vehicles.Drivetrain` folder and `exotic` subfolder (every attribute in section 4) |
| audio | `audio/` | `VehicleAudioClient`, `VehicleAudioCatalog` | new attributes on `Config.Audio.VehicleProfiles.EXOTIC_V10_AUDIO` (and its children if needed) |
| hud | `hud/` | `DriveSessionClient`, `UIPulse.FreeRoam.HudView`, `UIPulse.Kit.Gauge`, `UIPulse.Dev.Fixtures.Gauge` | none (HUD tuning lives in `Drivetrain.exotic`, section 4.6) |
| camerafx | `camerafx/` | `DrivingCameraClient`, `VehicleVFXClient` | new number attributes on `Config.Vehicles.Camera` and `Config.Vehicles.StabiliserVFX` |
| model | `model/` | none: an offline Python model only | none |
| synth | `synth/` | none: offline sound generation and the listen pack | none |

**Paths**
- Script paths are `ReplicatedStorage.Modules.Game.Vehicles.*`, `…Game.Audio.*`, `…Game.UIPulse.*`.
- `before/<Name>.lua` holds the exact live bytes captured on 2026-10-20. The Fixtures Gauge is `before/Fixtures.Gauge.lua`.

**Each part delivers:**
- `<part>/after/<Name>.lua`: the full new source. It starts from `before/` and changes only what is needed. Keep the code style: tabs, existing naming, comment density.
- `<part>/config.py` (physics, audio, camerafx), defining:
  - `INSTANCES`: a list of `{"parent": [...path], "name": str, "class": "Folder", "attributes": {...}, "children": [...]}`.
  - `ATTRIBUTES`: a list of `(path_list, key, value)` for attributes on existing instances.
- `<part>/NOTES.md`, covering:
  - what changed and where (function names);
  - every config value with a one-line meaning;
  - what was preserved;
  - test hooks;
  - open risks.

**Rules for parts**
- Agents never write to Studio, never run git, and never touch other parts' folders.
- **Compile check (allowed).** With the bridge running on 127.0.0.1:8797, an agent may run this read-only `execute_luau` in the **Edit** datamodel of PR98 (studio_id `09a86975-c7cc-48a0-9ac7-b891c4e91465`):
  ```lua
  local s = game:GetService("HttpService"):GetAsync("http://127.0.0.1:8797/scripts/drivetrain_feel/<part>/after/<Name>.lua?t=" .. os.clock(), true)
  local f, e = loadstring(s, "<Name>")
  return f and ("OK " .. #s) or ("ERR " .. tostring(e))
  ```
  Nothing else may be executed in Studio. Never `require` a game module, and never write.

## 3. Interfaces between parts (fixed; do not rename)

### 3.1 Feel attributes

Written by `DrivingClient` on the vehicle Model. They are client-local, written only when the value changes, and quantised.

They are present **only** while the drivetrain is active for this car. They are added to the clear list (`FEEL_ATTRIBUTES`), so `Stop` and becoming inactive set them to nil.

| Attribute | Type and units | Meaning |
|---|---|---|
| `FeelRpm` | number, 10 rpm steps | engine rpm (idle..limiter; neutral revs included) |
| `FeelIdleRpm`, `FeelRedlineRpm`, `FeelLimiterRpm` | number | this car's engine; written on activation and when tuning changes |
| `FeelGearCount` | number | forward gears |
| `FeelGear` | number | −1 = R, 0 = N, 1..GearCount |
| `FeelLoad` | number 0..1, 0.02 steps | throttle × shift cut × limiter cut. 0 during a cut and on a lift |
| `FeelShiftRevision` | number counter | +1 per shift event; the first value seen is a baseline, not an event |
| `FeelShiftKind` | string `Up`, `Down`, `Launch` | kind of the latest shift event |
| `FeelShiftStrength` | number 0..1, 0.05 steps | strength of the latest shift event |
| `FeelCut` | number 0..1, 0.1 steps | 1 while the shift or limiter cut is active |
| `FeelLimiterRevision` | number counter | +1 per limiter bounce |
| `FeelThrustSlip` | number 0..1, 0.05 steps | ws_eff shown as 0..1 (launch and wheelspin flare) |
| `FeelSpin` | number 0..1, 0.05 steps | spin amount L |
| `FeelSpinDirection` | number −1, 0, +1 | the latched spin direction; 0 when not spinning |
| `FeelOverdrive` | number 0 or 1 | boosting past top-gear redline: engine pinned at redline, no cut |

Existing Feel attributes keep their meaning:
- `FeelThrottle` stays the raw throttle input.
- `FeelSpeedMph` stays the real speed.
- `FeelSlip`: the spin path must make the slip visible. Lower its 8 mph floor to 2 mph **only when the drivetrain is active**, so other classes are unchanged.

### 3.2 HUD telemetry

`DriveSessionClient.PublishMobile(speedMph, boostPercent, telemetry)` gets an optional third argument.

- `telemetry` is a table **preallocated once** in DrivingClient and reused every frame.
- When present, `PublishMobile` writes these fields onto `MobileDriveInputState`:

  | Field | Type | Meaning |
  |---|---|---|
  | `Gear` | string | `"N"`, `"R"`, or `"1"`..`"7"` |
  | `GearRevision` | number | +1 per shift |
  | `RpmFraction` | number 0..1 | gauge sweep fraction, already mapped. Redline sits at `HudRedlineSweep`; the limiter is slightly beyond it. The needle spring is in HudView. |
  | `ShiftLight` | number | 0 off, 1 warm, 2 shift, 3 limiter, 4 spin warning (amber) |
  | `Spin` | number 0..1 | spin amount |
  | `Overdrive` | boolean | engine pinned at redline while boosting |

- When `telemetry` is nil, or on `SetMobileDriving(false)`, it sets all six fields to nil.
- `MobileDriveInputState` itself is **not edited**: its `Reset()` does not know the new fields, so DriveSessionClient clears them.
- HudView must treat `RpmFraction == nil` as today's behaviour: the speed arc and no gear readout. That is what non-Exotic cars get.

### 3.3 Drivetrain profile function

`VehicleDynamics` gains a pure function for remote cars, used by audio:

```
VehicleDynamics.GearForSpeed(vehicle, speedMph, accelerating, braking, previousGear) -> gear, rpm, redline, limiter, idle
```

- Rules:
  - pure;
  - no `SetAttribute`;
  - no allocation per call: it caches per vehicle in a weak-keyed table, refreshed when the vehicle's PI or the config changes, and at most 4 times a second;
  - returns nil when the vehicle's class has no active drivetrain.
- It uses the same profile build as the local car (`DrivetrainProfile`, section 5.1), with hysteresis:
  - up at `x ≥ 0.92` when accelerating (0.6 otherwise);
  - down at `x < 0.45`;
  - when braking, the local braking-downshift rule (lands at `≤ DownshiftBrakeLand`).
- Audio requiring `VehicleDynamics` is a new dependency. Record it in NOTES.

## 4. Config: `ReplicatedStorage.Config.Vehicles.Drivetrain`

**The `Drivetrain` folder itself**
- `Enabled` = 1
- `DrivetrainFeelInstalled` = true
- `Notes` (string): how to add a class by copying `exotic`.

**Rules for the `exotic` subfolder**
- Every numeric attribute gets a `<Name>_RaisingThisDoes` string next to it. It says in one line what raising it feels like, and what 0 does.
- All switches are **numbers 0 or 1**, never booleans: `Catalog.GlobalBool` and the camera `flag()` ignore a configured false.
- **Live tuning:**
  - DrivingClient re-reads the class folder with `GetAttributes()` at about 4 Hz and on Start, and rebuilds the profile when anything changed.
  - Edits made during Play apply within about 0.25 s with no re-entry.
  - Strings (`GearRatios`, `TorqueCurve`) are parsed only on change, never per frame.

### 4.1 Feel dials (the first thing to tune)

Each dial is 1 for the designed feel. Every dial has a working 0 end (or a lower bound) and an upper bound.

| Dial | Default | Range | What it scales |
|---|---|---|---|
| `Enabled` | 1 | 0/1 | 0 = this class drives exactly as before |
| `FeelWeight` | 1 | 0..2.5 | One "mass" dial. It scales yaw inertia (spring ω / weight), steer build-up time, grip-build lag, pitch and roll amount, and how much braking is reduced from today. 0 is today's light, instant feel; 2 is very heavy. |
| `FeelGearing` | 1 | 0..2 | How much you feel the gears. It scales the gear torque steps (`GearTorqueExponent` × dial), the shift cut length and depth, the rev-drop speed, and the camera shift nod. 0 is CVT-smooth with no cut. |
| `FeelAcceleration` | 1 | 0.5..1.5 | Engine thrust in every gear. Top speed stays drag-limited at today's value. |
| `FeelGrip` | 1 | 0.6..1.6 | Cornering grip limit and traction. |
| `FeelSpin` | 1 | 0..2.5 | How readily and how violently the car spins. 0 means it never spins. |
| `FeelEngineBrake` | 1 | 0..2 | Engine braking when you lift. 0 means coasting is only drag and rolling resistance. |

**Effective value.** For each parameter governed by a dial:
- if the parameter is "amount-like", effective = base × dial;
- if it is "time-like", effective = base × dial;
- if it is a stiffness, effective = base / max(dial, 0.05);
- or it lerps from the "today" value to the designed value.

The physics NOTES must list the exact mapping per parameter. **Dial 0 for weight, gearing and spin must reproduce today's feel for that aspect.**

### 4.2 Engine and gearbox

Defaults are for the Exotic V10 hybrid. The model part may propose adjusted numbers; the integrator decides.

**Engine and gears**
- `GearCount` 7
- `GearRatios` "3.15,2.18,1.66,1.33,1.10,0.93,0.80"
- `IdleRpm` 1100, `RedlineRpm` 8500, `LimiterRpm` 8600
- `TorqueCurve` "0:0.55,0.3:0.80,0.5:0.93,0.7:1,0.85:0.98,1:0.86". The x values are fractions of redline.
- `GearTorqueExponent` 0.8
- `TopGearOverspeed` 1.06
- `LaunchRpmFraction` 0.5

**Rev response and shift timing**
- `EngineRiseSeconds` 0.06, `EngineFallScale` 1.5
- `ShiftRpmSeconds` 0.05, `ThrustSlipFlare` 0.6
- `ShiftCutSeconds` 0.06, `ShiftCutTorque` 0.45, `ShiftBlendSeconds` 0.06
- `DownshiftBlendSeconds` 0.08, `ShiftMinIntervalSeconds` 0.25

**Upshift points**
- `UpshiftFlat` 0.97 (rpm fraction at throttle ≥ 0.9)
- `UpshiftPartLow` 0.62, `UpshiftPartHigh` 0.85
- `UpshiftCruise` 0.45 (throttle between `CruiseThrottleMin` 0.05 and 0.3 only)
- `UpshiftMinLand` 0.33
- `LiftHoldSeconds` 0.8: no upshift for this long after the throttle drops below `CruiseThrottleMin`.

**Downshifts and kickdown**
- `DownshiftBrakeLand` 0.82
- `DownshiftCoastFraction` 0.30, `DownshiftCoastLand` 0.65
- `KickdownThrottle` 0.95, `KickdownBelowFraction` 0.45, `KickdownLand` 0.88, `KickdownHoldSeconds` 0.12

**Limiter and neutral revs**
- `StopGearMph` 3
- `LimiterOnSeconds` 0.03, `LimiterCutSeconds` 0.045, `LimiterHysteresisRpm` 150
- `NeutralRevEnabled` 1, `NeutralRevTarget` 1.02 (fraction of redline at full throttle in N, so the countdown bounces the limiter)

### 4.3 Traction, resistance and brakes

**Traction**
- `TractionG` 1.15
- `TractionGripExponent` 0.15
- `TractionTierBonusG` 0.25: extra traction g at full tier (PI ≥ `TierFullPI`), so upgrades are felt off the line.
- `TierStartPI` 250, `TierFullPI` 750
- `TractionAssist` 0.35 (0..1, a share of thrust slip removed)
- `SlideGripFraction` 0.88

**Resistance**
- `RollingDecel` 0.8, `RollingDecelPerStud` 0.004
- `EngineBrakeDecel` 1.5

**Brakes**
- `BrakeDecel` 70, `BrakeForceExponent` 0.35, `BrakeFactorMin` 0.75, `BrakeFactorMax` 1.4

**Boost**
- `BoostShapeEnabled` 1, `BoostShareMin` 0.15
- `SpeedGuardStrength` 2.0, `SpeedGuardOverBoostTop` 1.03
- `OverdriveEnabled` 1

### 4.4 Chassis and weight

**Steering build-up**
- `SteerRiseSeconds` 0.2 (time to full lock on keyboard)
- `SteerReturnRate` 14
- `TouchSteerRate` 10

**Yaw**
- `YawOmega` 9, `YawDamping` 0.75 (second order; a slight overshoot reads as mass)
- `YawWeightExponent` 0.5, `YawWeightMin` 0.75, `YawWeightMax` 1.3
- `YawKinematicBelowMph` 15
- `YawUnwindScale` 2
- `YawRateMax` 5

**Lateral grip**
- `LateralCapG` 3.4, `LateralCapGripExponent` 0.25
- `LateralCurveShape` 1.4
- `YawCapMargin` 0.9
- `GripRelaxStuds` 2.0
- `DriftCapExempt` 1

**Body motion**
- `PitchDegreesPerG` 2.4, `PitchMaxDegrees` 5
- `PitchOmega` 9, `PitchDamping` 0.6
- `RollDegreesPerG` 0.9, `RollMaxDegrees` 3

**Impact yaw**
- `ImpactYawKick` 0.6 (rad/s per 100 studs/s of impact; 0 means off). On a `FeelImpact` event, the car is turned by the side that was hit, through the yaw-rate state.

### 4.5 Spin-out

**Gestures and the spin window**
- `SpinEnabled` 1
- `SpinStabSeconds` 0.4, `SpinStabSteer` 0.8
- `SpinAnalogRate` 4
- `SpinWindowSeconds` 0.7
- `PowerBrakeEnabled` 1, `PowerBrakeMinHold` 0.3, `PowerBrakeDumpSlip` 0.5

**When it can build**
- `SpinBelowMph` 25, `SpinFadeMph` 12
- `SpinSteerStart` 0.6, `SpinSteerWidth` 0.35
- `SpinSlipStart` 0.12, `SpinSlipWidth` 0.25

**Rates**
- `SpinBuildRate` 3.5
- `SpinDecayRate` 2.5
- `SpinCatchRate` 8
- `SpinSettleSeconds` 0.3

**Effect on the car**
- `SpinYawAccel` 7, `SpinMaxYawRate` 3.6 (hard cap; must stay ≤ `YawRateMax`)
- `SpinGripLoss` 0.7, `SpinThrustLoss` 0.35
- `SpinHoldCap` 0.35: the largest spin amount without a gesture window, which gives a catchable wiggle.

**Who and when**
- `SpinTierFloor` 0.5
- `SpinTouchScale` 0.5
- `SpinStartGraceSeconds` 3, `SpinStartGraceMph` 38
- `SpinWarnLevel` 0.25

### 4.6 HUD (read by DrivingClient when filling telemetry)

- `HudRedlineSweep` 0.87
- `HudShiftLeadSeconds` 0.25
- `HudShiftMinFraction` 0.85 (the light only shows for upshifts planned at ≥ this fraction of redline)
- `HudWarmBandFraction` 0.12

## 5. Physics (physics part)

### 5.1 Profile (VehicleDynamics)

- `Model.DrivetrainProfile(vehicle, stats, balance, maxMph, quiet)` builds the per-car profile the way design_draft section 3.1 does:
  - the Vt and Vb bisection on **today's** equations;
  - gear redline speeds;
  - A1;
  - gear thrust multipliers;
  - derived drag Kd;
  - traction;
  - boost share.
- With these overrides:
  - Traction gets the tier bonus.
  - All dials are applied.
  - **Overdrive is in the Vb solve:** at top-gear redline while boosting, engine thrust is held at `τ(1)·mult_top`, not cut.
- It is cached and rebuilt only on change.

### 5.2 Per-frame step

`Model.StepDrivetrain` runs inside `StepLongitudinal` only when the profile is active. Otherwise the old lines run unchanged.

It follows design_draft sections 3.2 to 3.6, with these mandatory fixes from the critiques:

1. **Linear throttle:** `a_raw` includes throttle once; `a_drive` is not multiplied by throttle again.
2. **Every resistive term is signed** against velocity: `−v/max(|v|, 0.8)·mag`.
   - Engine braking only applies with gear ≥ 1 and fwdMph > 0.
   - `ws_eff` is 0 unless the mode is Forward, fwdMph ≥ −1, and `SteeringProfileIntent == 1`.
   - The auto-hold `SnapForwardStop` does not fire while spin > 0.05 or while horizontal speed is above 4 studs/s.
3. **No shifting mid-drift or mid-spin:**
   - The gear is held while `DriftBlend > 0.3` or spin > 0.1, except an upshift on the limiter.
   - `rpm_road` uses `|v_horizontal|` blended by DriftBlend.
   - During a spin, rpm aims at a free-rev target of `0.85·R·thr`.
4. **Shift churn fixes:**
   - no cruise upshift at throttle ≤ `CruiseThrottleMin`;
   - `LiftHoldSeconds`;
   - kickdown needs `KickdownHoldSeconds` and `x < KickdownBelowFraction`;
   - **no torque cut on downshifts**: they get a rev-matched blend only, and the audio gets a blip.
5. **Frame-rate independence:** cuts and the limiter are time-weighted across each frame (the fraction of the frame spent in the cut), not booleans.
6. **Overdrive:** while boost thrust is applied and `rpm_road ≥ R` in top gear, rpm is pinned at R, there is no limiter cut, and `FeelOverdrive` = 1.
   - Boost and mini-boost are multiplied by `BoostShare(v)`.
   - The speed guard holds the boosted top at ≤ `SpeedGuardOverBoostTop`·Vb.
7. **Drift engine assist** uses `DriveThrust` (gross), not net acceleration.
8. **Pitch source** includes boost and mini-boost acceleration.
9. **Neutral revs while anchored:**
   - no forces (CAM-02);
   - gear N;
   - rpm follows `I + thr·(NeutralRevTarget·R − I)` with the limiter bouncing;
   - publishes `FeelRpm`, `FeelLoad` and telemetry;
   - does **not** set the `Accelerating` attribute (it would send remote audio state).
   - On unanchor: gear 1, launch slip, and the start grace begins. The grace starts on the change from anchored to unanchored **or** when `DriveReady` becomes true, whichever is later.

### 5.3 Chassis (DrivingClient)

**Steering rate limit** (in `refreshInput`, after the inputs are summed)
- Keyboard: build to full lock in `SteerRiseSeconds × FeelWeight` and return at `SteerReturnRate`.
- Touch: at `TouchSteerRate`.
- Gamepad analog is untouched.
- Bank still uses the **raw** steer (DRIVE-01).
- Counter-steer detection uses the raw steer.

**Yaw**
- Replace `YawHeading += −steeringInput·turnRate·dt` with a yaw-rate state `r`:
  - Target: `r_cmd = −steeringInput·turnRate`, using today's full formula.
  - Grip-limited yaw cap on forward intent above 8 studs/s: `|r_cmd| ≤ YawCapMargin·a_cap/v`. It is relaxed while drifting by the drift extra in the draft.
  - The spring is second order (ω, ζ, weight scaling).
  - Unwinding (|r_cmd| < |r|, or sign change) uses ω·`YawUnwindScale`.
- **Kinematic blend:** below `YawKinematicBelowMph` it blends to kinematic (`r = r_cmd`) via `smoothstep`. Parking, three-point turns and standstill steering stay exactly as today.
- Target: at most 5° of run-on after a key release at 60 mph. Verify it in the model.

**Lateral grip** (replaces line 1298 when active)
- `a_tgt = −side·lateralGrip·(1 − SpinGripLoss·L)`.
- Shaped by the peaked curve `sin(C·atan(B·s))`, which peaks at the cap and has finite slip.
- Grip-build lag over `GripRelaxStuds × FeelWeight`.
- **Drift exempt:** the result is `lerp(capped_normal, uncapped_drift, DriftBlend)`. Today's drift radius, yaw and exit speed must hold within ±10%.

**Pitch and roll**
- Pitch comes from real acceleration through a spring.
- Plus a small roll from lateral g, on forward intent only, behind its own sub-switch value.
- The raw-steer bank is unchanged.

### 5.4 Spin (DrivingClient + VehicleDynamics helpers)

**Gestures** (each opens a window of `SpinWindowSeconds`)
- **Stab:** throttle goes from below 0.3 to ≥ 0.9 within `SpinStabSeconds` while |raw steer| ≥ `SpinStabSteer` and speed < `SpinBelowMph`.
- **Analog stab:** the throttle rises faster than `SpinAnalogRate`/s from below 0.3.
- **Power-brake:** S and W held together at a standstill for ≥ `PowerBrakeMinHold`, then S released.
  - Today they cancel to 0. Keep that cancel for the force, but record the gesture.
  - The release adds `PowerBrakeDumpSlip` to ws_eff, decaying over the window. This is a burnout start.

**Spin amount L**
- Target L uses the draft's L_t formula (slip, steer, speed and yaw gates), multiplied by `FeelSpin`, the tier scale (floor `SpinTierFloor`) and the touch scale.
- L_t is capped at `SpinHoldCap` outside a gesture window.
- **L is clamped to [0, 1].**
- The yaw response k is floored (≥ 1/s).

**Direction and effect**
- The direction is latched at onset. The spin yaw acceleration applies only while `r·dir > 0`.
- The spin cap `SpinMaxYawRate` ≤ `YawRateMax` ≤ 5 keeps the camera hard-cut invariant.

**Catch and settle**
- Lifting (throttle < 0.3) or counter-steering (raw steer sign opposite to dir, |steer| > 0.3) moves L toward 0 at `SpinCatchRate`.
- After a catch, r eases to r_cmd over `SpinSettleSeconds`, not with a snap.

**Grace and warning**
- Start grace: no spin until speed > `SpinStartGraceMph` or `SpinStartGraceSeconds` has passed, whichever is later.
- The warning level is published as ShiftLight 4 when L > `SpinWarnLevel` and rising.

### 5.5 State reset

Clear r, L, the spin window, the steer limiter state, the lateral filter, the pitch and roll springs and the gearbox. The gearbox returns to gear 1 (or N while anchored) at idle with no cut, and the start grace begins. This happens in:
- Start;
- Stop;
- ResetVehicle;
- the anchored branch;
- every place `YawHeading` re-syncs from the body;
- whenever `GameplayInputGate` is locked.

### 5.6 Preserved behaviour (unchanged when active unless stated, and always unchanged when inactive)

- DRIVE-01 logic at lines 1255 to 1285 and the raw-steer bank.
- `SteeringCoastAssumeForward`, the reverse latch and reverse ×3.
- Reverse and Stopped modes; auto-hold (with the spin gate above).
- Hover rays, pose, wobble and `FeelHover`.
- Mini-boost rules, the Balance multipliers at their current sites, and the Feel contract.
- `FeelSpeedMph` stays the real speed; the HUD display curve stays display-only.
- Driving rules:
  - no per-frame allocation or new connections per frame;
  - no extra raycasts;
  - no per-frame `GetDescendants`;
  - frame-rate-independent smoothing (`1 − exp(−rate·dt)` or sub-stepped springs);
  - NaN guards;
  - dt clamped;
  - zero force while anchored.
- Do not rename or remove existing attributes, functions or state fields. Do not change the `Controller` signatures.
- Debug attributes (`DynamicsGear` and similar) are written only when `Dynamics@DebugAttributes` is on.

## 6. Audio (audio part)

**Rev source**
- When `FeelRpm` is present: `revTarget = clamp((FeelRpm − RevRpmMin)/(RevRpmMax − RevRpmMin), 0, 1)`.
  - Profile attributes, with the limiter mapping to the top: `RevRpmMin` 1000, `RevRpmMax` 8600.
  - The rev follows with `RevRpmSmoothingSeconds` 0.02.
  - Load comes from `FeelLoad`.
- Otherwise today's formula runs unchanged.

**Shifts and limiter**
- Detect `FeelShiftRevision` with the baseline-first pattern.
- **Upshift:** the rev drops quickly over `ShiftDropSeconds` 0.035. The engine fader takes a volume dip (an envelope, not the tremolo) for the cut length. Optionally a vent crackle comes from the existing pop voices on hard upshifts (strength ≥ 0.7), called directly so it never goes through `FeelPopRevision`.
- **Downshift:** a blip of `DownshiftBlipRev` 0.08 rev for 0.12 s, plus a load spike so the bark fires.
- **Limiter:** an `AudioTremolo` on the engine bus while `FeelCut` and the rpm is near the limiter. It is bypassed otherwise.

**Engine sub-bus** (local car only)
- Rev voices go to `EngineBus` (an `AudioFader`), then to `AudioFilter` and `AudioEqualizer` (load-driven tilt), then to `AudioTremolo` (limiter only), then to the existing route.
  - All parented to the graph root.
  - The EngineBus fader is **not** registered with the Vehicle bus gain, so the gain is not applied twice.
  - Effects are bypassed and transparent when `EngineBusEnabled` = 0.
- Use our own values, **not DRIVE's**: no distortion/EQ formula copied from the DRIVE survey. The grit belongs in the synthesised loops. The runtime chain adds only a modest load tilt and a resonant filter sweep with load.

**Sci-fi line**
- A reactor or ion whine follows **road speed**, not rpm. It goes in the empty `TurboWhistle` feel slot.
- Until new uploads arrive it uses the already-uploaded `turbine_high` asset 126900976760387.
- Gain is `ReactorGain·(0.25 + 0.75·load)`. On each shift it chirps: a 3% pitch dip for 80 ms.

**Spin**
- `FeelSpin` drives `SlipStrain` too: `max(slip term, FeelSpin·SpinStrainGain)`.

**Remote Exotic cars**
- They use `VehicleDynamics.GearForSpeed` to derive gear and rpm from replicated speed and the `AudioDrive` state, so their rev saw-tooths.
- Shifts are pitch only; there is no new network traffic.
- Choose the 3 remote voices across 0.4 to 1.0 of redline.

**Budgets and config**
- Voice budget: at most 46 on desktop, and within the existing mobile budgets. NOTES must include a voice-count table.
- New one-shot slots exist but stay blank, so they are silent until assets exist: `ShiftThunk` ×2, `ShiftVent` ×2.
- All new switches are numbers, for example `EngineBusEnabled`, `RpmRevEnabled`, `ShiftAudioEnabled`, `RemoteGearsEnabled`, `ReactorEnabled`. They are profile attributes on `EXOTIC_V10_AUDIO` with `_RaisingThisDoes` strings.
- Bump `ProfileRevision`.

## 7. HUD (hud part, Pulse only)

**`HudView`**
- If `drive.RpmFraction ~= nil`:
  - the arc shows rpm: `gauge.SetSpeed(speed, rpmFractionSprung)` with a needle spring in HudView (ω about 25, ζ about 0.5, a slight overshoot);
  - the gear readout and shift light are set;
  - the arc does a start-up sweep for about 0.5 s on first telemetry.
- Otherwise today's behaviour.

**`Kit.Gauge`**
- New `SetGear(text)`, `PunchGear()`, `SetShiftLight(level)` and `Step(dt)` (used for the punch and flash clocks).
- **One** gear `TextLabel` (Barlow, via the existing Text role helpers), placed in the bottom gap of the ring. The punch is done by writing `TextSize`; there is no UIScale.
- The shift light is shown on the gear text colour (cyan → pink; amber for the spin warning) plus the existing Tip.
  - Never tint the baked gauge images.
  - Never change a BigNumber colour.
  - Flashing is at most 3 Hz, or a brightness pulse.
- **Phone (compact, 92 dp):** the gear text replaces the unit line while telemetry is present.
- **Budget:** the gauge goes from 26 to ≤ 28 instances. Steady-drive writes stay at a median of ≤ 16 per frame. No per-frame `GetAttribute` or `FindFirstChild`.
- Add fixture states to `Dev.Fixtures.Gauge`:
  - gear N, 1 and 7;
  - R;
  - shift light;
  - limiter;
  - spin warning;
  - Overdrive.
- Update the k3 tests in `scripts/ui_restyle/phase2/kit/k3/tests/` as copies under `hud/tests/`.
- Note the ui_restyle bookkeeping needed (canonical after files, `state.json`, the Classic declared set) in NOTES. The integrator applies it.

## 8. Camera and VFX (camerafx part)

**Camera**
- **Spin mode** when `FeelSpin` > 0.2:
  - hold the heading from spin onset;
  - follow the travel direction only above `ChaseSpinTravelMinStuds` 12;
  - cap the camera yaw rate at `ChaseSpinYawRateMax` 1.5 rad/s;
  - ease out as the spin ends;
  - in spin mode the Lag spring uses the derivative of speed magnitude.
- **Shift:**
  - a new small critical spring for upshifts under load (`ChaseShiftNodDegrees` 1.0 × strength × the gearing dial is not available here, so use strength);
  - an FOV pulse of `ChaseShiftFovDegrees` 1.2, added into the existing fov term before `CameraService.SetFieldOfView`;
  - no nod on braking downshifts.
- **Limiter shimmer** `ChaseLimiterShimmerDegrees` 0.08, on the limiter only.
- Switches `ChaseDrivetrainEnabled` 1 and the per-effect amounts are numbers on `Config.Vehicles.Camera`.

**VFX**
- Thrust intensity uses `FeelLoad` when present, otherwise `FeelThrottle`.
- Vent flame on `FeelShiftRevision` (Up, strength ≥ `ShiftVentMinStrength` 0.7). This is independent of pops: never through `FeelPopRevision`.
- On `FeelSpin`: the stabiliser jets alternate at `SpinStutterHz` 9 (brightness pulse, no hard flashing), plus dust.
- On `FeelThrustSlip`: rear over-glow.
- "Strain": near the limiter, or with `FeelOverdrive`, the existing wobble or jets get a small extra shake.
- Switch `DrivetrainVFXEnabled` 1 on `Config.Vehicles.StabiliserVFX`.

## 9. Offline model (model part)

`model/sim.py` (numpy optional) implements:
- today's equations (to reproduce today);
- this contract's equations, for the six Exotic stock cars (stats from the repo's Exotic category data) and the stock PI.

It prints:
- per gear: redline mph;
- 0-60, 0-100, time to 0.9·Vt, speed at 10 and 15 s;
- braking 100-0;
- speed 2 s after a lift;
- boosted top;
- yaw run-on after a release at 60 mph;
- drift radius against today;
- shift count over 10 s of tapping W at 40 mph;
- spin envelope: hold cases must not spin, gestures must spin.

Regression targets:
- top speed ±3%;
- S 0-100 3.8 to 4.8 s;
- S time to 0.9·Vt ≤ 12 s;
- run-on ≤ 5°;
- ≤ 2 shifts per 10 s of tapping;
- drift radius ±10%;
- U-turn at 0 and 15 mph without a spin;
- stab and power-brake spin on C to S cars;
- power-brake can spin an E car.

It proposes default changes as a table and writes `model/RESULTS.md`.

## 10. Synth and listen pack (synth part)

- `synth/make_exotic_v2.py` imports `scripts/hover_feel/synth/make_sounds.py` functions by path and renders:
  - a grungier V10 hybrid set, using the same rpm points so the slots map one to one;
  - `reactor_whine` loops;
  - `shift_thunk` ×2 and `shift_vent` ×2;
  - a `grav_skid` loop.
- Output goes to `output/drivetrain_feel_audio/` (not committed).
- `synth/listen.py` renders WAV demos with a Python port of the gearbox and crossfade, and an approximate effects chain labelled as approximate:
  - a full-throttle run through all gears to top speed;
  - lift-off with engine braking and downshifts to a stop;
  - neutral revs on the limiter;
  - a power-brake launch;
  - a spin;
  - part-throttle short shifts;
  - Overdrive;
  - a pass-by.
- A side-by-side "today vs new" version of the full run.
- No uploads.

## 11. Verification (integrator)

**Install**
- Compile in Edit.
- AUDIT, with the Classic verify using the declared set built from `scripts/ui_restyle/phase2/install/07_shell/declared.json` plus this delivery's after-hashes.
- `delivery-reviewer` on this contract and the diff.
- Config transaction first, then sources.
- APPLY, ROLLBACK, APPLY.
- Save and reopen, then AUDIT.

**Play (sandbox window, Exotic cars)**
- Exotic `Enabled` 0 must match before-install behaviour.
- With it on, check:
  - shifts, Overdrive, spin gestures and hold cases;
  - DRIVE-01;
  - drift;
  - HUD (desktop and phone emulation), plus a non-Exotic car showing today's speed arc;
  - camera spin (zero `resetChase`);
  - audio (rev follows rpm; voice counts);
  - enter/exit cycles;
  - a clean console.
- Evidence goes in `verification.json`. The feel is Oscar's to judge.

**Recovery**
- Set `Drivetrain.exotic@Enabled` to 0 (instant), or `Drivetrain@Enabled` to 0.
- ROLLBACK restores the sources and removes the marked config and the new attributes on existing instances.
