# PR98 gearbox, weight, spin-out, sound and HUD: design plan

All figures from the offline Python checks are generated, not measured in Play. Line numbers are from live PR98 Studio (`09a86975…`), read this session.

## 1. Corrections to the lead's leaning

Checked against live `DrivingClient` (1605 lines), `VehicleDynamics` (300 lines), live `Config.Vehicles.*`, `DriveSessionClient`, `MobileDriveInputState`, `HudView` and `Kit.Gauge`.

1. **The yaw line is right, but the heading is only a target.** Line 1493 is `state.YawHeading += -steeringInput*turnRate*dt`. `YawHeading` is not the body's yaw. `getTerrainFrame` (lines 271-298, `flatForward` at 292) turns it into the `Align.CFrame` target at 1559. The `AlignOrientation` (MaxTorque huge, Responsiveness about 22) then drags the body after it with roughly 45 ms of lag. So the new yaw-rate state must integrate `YawHeading`. Spin-out works by driving that state; nothing physical spins the body on its own.
2. **Bank from lateral acceleration would break DRIVE-01.** "Raw left/right input remains the sole bank owner" (`Driving@InputOwnedSteeringTurnBankNotes`) is user-confirmed. Keep the raw-steer bank at 1494-1504 as it is. Add a separate small roll term from lateral acceleration (at most 3°, forward intent only, behind its own switch). Pitch from real acceleration is fine: `AccelBrakeTilt` is not part of DRIVE-01.
3. **Lower drag makes boost run away.** Weight needs much lower drag, and today's unshaped boost would then settle at about 378 mph on an S car (195 mph on E). That is above `AbsoluteTopSpeedSafetyMph` 320, the reward reject at 337 and the RaceIntegrity limit of 400. Boost and mini-boost still bypass the gearbox, but they must fade with speed so the boosted top speed stays where it is today (S about 214 mph). A stronger speed guard is also needed: today's soft limiter is clamped to 0.1, which is far too weak.
4. **Gear speeds cannot be fixed per category.** Top speeds run from about 102 mph (E) to 174 mph (S) and are set by drag. Each car's gear bands must be worked out from its own drag-limited top speed. In effect the final drive is derived per car, not authored.
5. **Traction sets who can spin.** With today's thrust (1.3 g on E, 2.0 g on S), a 1.0 g traction budget would give E cars wheelspin and make them spin. A traction base of about 1.15 g, plus spin authority scaled by PI tier, keeps spins to powerful cars.
6. **Coasting changes completely.** Today a car that lifts at 100 mph loses 34-46 mph in 2 s (aero 24-44 studs/s² plus coast `3.2 + 0.06·v`). The new model replaces this with lower drag, rolling resistance and engine braking. The balance NOTES coast mismatch (measured 34→16 mph against a model 26) means something outside `StepLongitudinal` also slows a coasting car. Measure it in Play before tuning engine braking.
7. **Switches in numbered folders must be numbers.** `numberAttribute` only caches numeric attributes of category folders, and `boolAttribute` reads the `Dynamics` root only (VehicleDynamics 13-39). So switches inside 09-11 must be 0/1 numbers, like `BalanceEnabled`.
8. **Per-category tables cannot sit under `Dynamics`.** The categorised cache maps each attribute name to one folder, so `Ratio1` in two category folders would collide. Put them in a new `Config.Vehicles.Drivetrain/<CategoryId>`.
9. **Most of the HUD needs no Kit change.** `Kit.Gauge.SetSpeed(value, fraction)` (319) already separates the digits from the arc fraction. An rpm arc is just HudView passing an rpm fraction. Only the gear readout, shift light and punch are additions to the Kit API.
10. **The camera cut is not the spin risk.** The cut at DrivingCameraClient 484 needs a heading jump above `max(0.5, 8·dt)` in one frame. With `SpinMaxYawRate` held at 5 rad/s or less, a spin moves at most 5·dt per frame, which is always under 8·dt, so it never cuts at any frame rate. The real problem is the heading-follow whip at 499-506.
11. **Audio switches must be numbers too.** `Catalog.GlobalBool` ignores a configured false, so new audio switches are 0/1 numbers.
12. **Muscle tops out at B tier.** The design brief caps the category at B, so there is no S Muscle.
13. **Keyboard and touch throttle are digital.** "Aggressive throttle" just means W is held. The spin rule therefore needs sustained full lock plus full throttle in first gear below about 20-24 mph. Taps, lifting, and part inputs on a gamepad must not trigger it.

Everything else in the leaning stands: a light virtual drive shaft instead of DRIVE's solver, the ProAuto-inspired auto brain, gear counts per category, Balance kept, the audio sub-bus, the Pulse-only HUD, the camera spin mode and haptics.

## 2. Today's numbers (live equations, PI 200/500/900 Balance, Piercer stock stats)

| Car | 0-60 | 0-100 | Top speed | Brake 100-0 | Speed 2 s after lifting at about 100 mph | Lateral g at 60 / 120 mph |
|---|---|---|---|---|---|---|
| E Forge (PI 200) | 2.50 s | 8.3 s | 102 mph | 2.6-3.1 s (1.13 g) | 54-56 mph | 3.2 / - |
| C Viper (PI 500) | 1.95 s | 4.5 s | 113 mph | 2.25-2.5 s (1.43 g) | 55-56 mph | 3.5 / - |
| S Zenith (PI 900) | 1.47 s | 2.62 s | 174 mph | 1.28-1.37 s (3.1 g) | 66 mph | 4.6 / 6.1 |

The S figure matches the measured Seraph run (0-100 in 2.7 s), so the port is credible. Two things make the driving feel arcadey:
- thrust that stays flat with almost infinite traction, against very heavy drag (so the car loses 17-23 mph per second when you lift);
- cornering grip that never runs out (up to 6 g, because the heading is set directly and grip is a linear damper).

## 3. The model

### 3.1 Per-car setup (`VehicleDynamics`, cached)

**New `Model.DrivetrainProfile(vehicle, stats, balance, maxMph, quiet)`.** It is recomputed when the vehicle, its PI or the 0.25 s Balance refresh changes, and makes no per-frame allocations.

- **Vt (top speed to keep):** a 40-step bisection on today's equations, `oldFwd(v) = oldAero(v)`. Today's forward term is `80·ef·wf·launchShape·highFade·bA`. Today's aero term is `0.002·v²·dragF·bD/0.625`. This keeps every stat, clamp and Balance coupling exactly as it works now.
- **Vb (boosted top to keep):** the same bisection with today's boost acceleration `(BoostForce+32)·0.75·bBoost` added.
- **Gear redline speeds:** `V_g = Vt · Over_c · r_top / r_g`, with `Over_c` 1.06 (1.05 for Muscle). At Vt the engine sits at 0.94 of redline in top gear, so top speed stays drag-limited.
- **First-gear thrust:** `A1 = 80·ef·wf·bA`, which is today's plateau.
- **Gear thrust multiplier:** `mult_g = (r_g/r_1)^p`, with `GearTorqueExponent p = 0.85`. 1 would be strictly real, 0.85 gives a bit more mid-range.
- **Derived drag:** `Kd = max(A1·mult_top·τ(1/Over_c) − Rb − Rs·Vt/0.625, 0.5) / Vt²`, in studs/s² per mph².
- **Traction:** `a_trac = TractionBaseG(1.15)·35.1·clamp((LateralGrip/50)^0.15, 0.9, 1.15)·CatTraction_c`. Here 35.1 studs/s² is 1 g.
- **Boost shaping:** `BoostShareHi = clamp((Kd·Vb² + Rb + Rs·Vb/0.625 − a_top(Vb))/BoostToday, 0.15, 1)`, then `share(v) = 1 − (1 − ShareHi)·smoothstep(mph/Vb)`. The model gives a high-speed share of 22-33%. The full kick is kept from a standstill (the Redline-style shock wave); it fades toward the top.

**How Balance flows through:**
- TopSpeed reaches Vt through `maxMph` (line 1116), and so sets the gear bands.
- Acceleration scales A1, so every gear.
- Drag is used only inside the Vt solve, so `BalanceDragCoupling` still makes the real top speed fall by exactly bT.
- Braking scales the new brake. Steering, Grip, Boost, MiniBoost and the drift multipliers are unchanged at their current sites.
- Traction is not balanced (decision D14).

**Remote cars** call the same function with `quiet=true`: no `SetAttribute`, and `ComputeBalance` instead of the single-slot `Model.Balance` cache. `RAW_PERFORMANCE_Runtime` is written by the server, so it replicates.

### 3.2 Gearbox state and per-frame equations

**New `Model.StepDrivetrain`, called from `StepLongitudinal`.** It runs only when `GearboxEnabled = 1`; otherwise lines 231-269 run unchanged.

State lives in a persistent `state.Gearbox` table that is changed in place: `Gear, Rpm, Phase (None/Cut/Blend), PhaseTimer, LastShift, LimiterOn, LimiterCut, ShiftRevision, LastKind, LastStrength`.

**Engine rpm (dt clamped to 0-0.1 s, as today):**
```
x_road   = max(fwdMph,0)/V_g ;  rpm_road = x_road·R
rpm_base = (g==1 and thr>dz) ? max(rpm_road, I + thr·(Launch_c·R − I)) : rpm_road ; ≥ I     -- clutch-slip launch
a_raw    = A1·mult_g·τ_c(Rpm/R)·thr
ws       = max(0, a_raw/a_trac − 1) ;  ws_eff = ws·(1 − TC_c·TractionAssistScale)
rpm_tgt  = min(rpm_base·(1 + 0.6·min(ws_eff,0.5)), 1.01R)                                   -- bounded thrust-slip flare
Rpm     += (rpm_tgt − Rpm)·(1 − e^(−dt/τ)),  τ = Rise_c rising, 1.5·Rise_c falling, ShiftRpmTau_c after engage
```

**Thrust:**
```
a_drive  = a_raw ≤ a_trac ? a_raw : a_trac·(1 − 0.12·smoothstep(ws_eff/0.6))               -- sliding grip ≈ 0.88 of peak
a_drive  ·= k_shift · (1 − SpinThrustLoss·L)
```
- Shift cut: `k_shift = CutTorque_c` during the cut, then rises linearly to 1 over the blend.
- Limiter: when `rpm_road ≥ R` (or `Rpm ≥ R` in neutral), the drive is held for at least 30 ms, then cut to 0 for 45 ms (70 ms on Muscle), with 150 rpm of hysteresis. That gives a bouncing limiter.

**Resistance and braking:**
```
a_res    = Kd·mph² + Rb(0.8) + Rs(0.004)·|v_studs|
a_eb     = (thr ≤ dz, in gear, not cutting) EB_c·(mult_g/mult_top)·(0.35 + 0.65·Rpm/R)
Forward:  acc = a_drive·thr − a_res
Coasting: acc = −a_res − a_eb          (replaces 3.2 + 0.06·v)
Braking:  acc = −BrakeV2·|thr| − a_res − a_eb
BrakeV2  = 70·clamp((BrakingForce/60)^0.35, .75, 1.4)·clamp((118/W)^0.2, .8, 1.2)·bB
Guard:    if mph > min(maxMph, 1.03·Vb): acc −= (mph − lim)/0.625·2.0
```

**What the step returns:** existing fields, plus `DriveThrust` (gross), `Gear, Rpm, Load, ThrustSlip, WheelspinExcess (ws_eff), Cut, LimiterActive, ShiftEvent (kind/strength or nil), BoostShare`. The return table is reused, not rebuilt.

**Auto shift brain (inspired by ProAuto, not copied):**
- **Upshift:** when `rpm_road ≥ U(thr)·R`, the gear is below top, the minimum interval has passed, spin `L < 0.3` and `DriftBlend < 0.3` (while drifting it only upshifts on the limiter).
  - U = 0.97 at throttle ≥ 0.9 (0.95 on Muscle).
  - U = lerp(0.62, 0.85) at throttle 0.3-0.9.
  - U = 0.45 at throttle below 0.3, but only if the landing rpm is at least 0.33R.
- **Braking downshift:** one gear down when the landing rpm is 0.82R or less (0.2 s gap). The audio gets a rev-match blip.
- **Coasting downshift:** at x < 0.30, if it lands at 0.65R or less.
- **Kickdown:** throttle ≥ 0.95 and x < 0.55 drops to the lowest gear that lands at 0.88R or less.
- **Other gears:** below 3 mph it selects 1st. Reverse mode (unchanged path) shows R, with rpm from `I + (0.55R − I)·|mph|/40`. While anchored it is N.
- **Shift strength:** 1 when flat out, 0.3 + 0.7·thr otherwise, 0.5 on downshifts.

**Per category:** `Config.Vehicles.Drivetrain/<CategoryId>`, parsed at Start. Strings are never parsed per frame.

| | Exotic (`exotic`) | Piercer (`bruiser`, default) | Muscle (`muscle`) |
|---|---|---|---|
| Gears and ratios | 7: 3.15/2.18/1.66/1.33/1.10/0.93/0.80 (DCT) | 6: 3.30/2.12/1.53/1.18/0.95/0.79 | 4: 2.60/1.80/1.34/1.00 |
| Redline / limiter / idle | 8500 / 8600 / 1100 | 7400 / 7500 / 900 | 6200 / 6300 / 750 |
| Torque shape τ(x), peak 1 | 0:.55 .3:.80 .5:.93 .7:1 .85:.98 1:.86 (peaky hybrid V10) | 0:.5 .25:.78 .35:1 .75:1 .9:.91 1:.80 (turbo plateau) | 0:.75 .3:.95 .5:1 .7:.96 .85:.86 1:.74 (fat crossplane V8) |
| Launch rpm / Over_c | 0.50R / 1.06 | 0.45R / 1.06 | 0.40R / 1.05 |
| Cut / cut torque / blend / min gap | 60 ms / 0.45 / 60 ms / 0.25 s | 110 ms / 0.10 / 100 ms / 0.35 s | 200 ms / 0.0 / 160 ms / 0.50 s |
| Engine rise / shift rpm τ | 0.06 / 0.05 s | 0.08 / 0.08 s | 0.11 / 0.12 s |
| CatTraction / traction assist / engine brake / SpinGain | 1.0 / 0.7 / 1.5 / 0.8 | 1.0 / 0.35 / 1.8 / 1.0 | 0.92 / 0 / 2.4 / 1.25 |

Ratios are listed per gear, highest first. Category ids are inferred from garage fixtures; confirm them live.

### 3.3 Generated results (targets in brackets)

Targets: top speed within 3%; S 0-100 3.8-4.8 s; braking about 2 g on S; a car that lifts keeps more than 75 mph after 2 s.

| Car (stock stats × category multipliers) | Gear redline mph | 0-60 old→new | 0-100 old→new | 60-130 old→new | Brake old→new | 2 s after lifting old→new |
|---|---|---|---|---|---|---|
| E Piercer | 26/40/56/72/90/108 | 2.50→4.43 | 8.3→20.4 (top 102) | - | 2.63→3.33 | 54→78 |
| E Exotic | 28/40/53/66/80/94/109 | 2.43→3.73 | 7.4→16.7 | - | 2.62→3.37 | 55→79 |
| E Muscle | 42/60/81/109 | 2.42→4.22 | 7.3→14.3 | - | 2.72→3.52 | 55→77 |
| C Piercer | 29/45/62/80/100/120 | 1.95→3.42 | 4.52→10.8 (top 113) | - | 2.25→3.22 | 55→85 |
| C Exotic | 31/45/58/73/88/104/121 | 1.90→3.08 | 4.32→8.67 | - | 2.22→3.15 | 55→84 |
| C Muscle | 46/67/90/120 | 1.90→3.72 | 4.30→9.10 | - | 2.45→3.32 | 55→81 |
| B Muscle | 53/77/104/139 | 1.68→3.57 | 3.33→7.35 | 6.15→12.7 | 2.08→2.95 | 59→84 |
| S Piercer | 44/69/95/123/153/184 | 1.47→2.43 | 2.62→**4.97** | 2.38→5.58 | 1.28→2.08 | 66→90 |
| S Exotic | 47/68/89/111/134/158/184 | 1.47→2.25 | 2.62→**4.37** | 2.38→4.88 | 1.28→2.08 | 66→89 |

- **Top speed** matches today exactly, by construction.
- **Faster "Sport" setting:** p = 0.7 gives S Exotic 0-100 4.17 s and 60-130 4.32 s.
- **Launch wheelspin** (`ws_eff`; spin starts above about 0.12): E Piercer 0.17, E Muscle 0.40, C Piercer 0.30, C Exotic 0.13, C Muscle 0.71, B Muscle 0.78, S Piercer 0.34, S Exotic 0.13.
- **Muscle** is limited by traction at launch, so it is about 8% slower to 60 than a Piercer of the same tier (decision D7).

### 3.4 Chassis and weight (`DrivingClient`; outputs added to `StepHandling`)

1. **Keyboard steer rate limit** (in `refreshInput`, 336-371). The keyboard part moves toward ±1 at 5/s and returns at 8/s, so full lock takes 0.2 s. Touch steering, which arrives mixed through `GetMobileInput`, is limited at 10/s. Gamepad and analog inputs are untouched. Bank still uses the raw steer.
2. **Yaw-rate state** (replaces 1493):
   - `r_cmd = −steeringInput·turnRate`, with today's full formula at 1428-1491: intent, reverse ×3, speed curve, boost 0.7, drift multipliers.
   - Grip cap on forward intent above 8 studs/s: `|r_cmd| ≤ a_cap·1.15·(1 + 1.5·DriftBlend)/v`.
   - `k = 8·clamp((118/W)^0.5, .75, 1.3)·(1 − 0.85L)`, which gives 6/s at W 220 and 10.4/s at W 60.
   - `r += (r_cmd − r)(1 − e^(−k·dt)) + sgn(r)·SpinYawAccel·L·(0.6 + 0.4·min(ws_eff/0.5,1))·dt`, then `|r| ≤ 5`, then `YawHeading += r·dt`.
   - Standstill steering is kept: `r_cmd` at 0 mph is unchanged, with only 0.1-0.17 s of lag. DRIVE-01 logic at 1255-1285 is untouched.
3. **Lateral grip that saturates** (replaces 1298):
   - `a_tgt = −side·lateralGrip·(1 − 0.7L)`, then `a_tgt = a_cap·tanh(a_tgt/a_cap)`.
   - `a_cap = 3.4·35.1·clamp((LG/50)^0.25, .85, 1.2)·downforceFactor·bG`.
   - **Grip relaxation:** `a_lat += (a_tgt − a_lat)(1 − e^(−dt·max(|v|,8)/2.0 studs))`, then `driveForce += right·mass·a_lat`.
   - Generated effect: S Exotic at 120 mph goes from 6.1 g to 5.1 g; C Piercer at 90 mph from 4.1 g to 3.3 g; nothing changes at 30 mph. A 3.0 g cap would cut S at 120 mph to 4.5 g.
4. **Pitch from real acceleration** (1514-1552, new source switch).
   - Target is `+2.4°·(DriveThrust − a_res − brake)/35.1`, clamped to ±5°. It follows a spring with ω 9 and ζ 0.6, so a shift cut produces a visible nose nod for free.
   - Add the extra lateral-acceleration roll (0.9°/g, at most 3°, forward intent only). Check signs in Play, as `AccelBrakeTiltNotes` warns.
5. **Drift and boost hooks.**
   - Drift engine assist (1317-1318) uses `DriveThrust`, not the net acceleration, so lower drag does not weaken drifts.
   - Boost (1401) and mini-boost (1408) are multiplied by `BoostShare`.
   - The spin target is forced to 0 while `DriftBlend > 0.12`: the drift owns the slide.

### 3.5 Spin-out

```
L_t = ss((ws_eff − 0.12)/0.25)·ss((|steer_eff| − 0.6)/0.35)·(1 − ss((mph − 24)/14))·ss((|r| − 0.15)/0.35)
      ·SpinGain_c·TierScale·(drifting ? 0 : 1)·(graceTimer > 0 ? 0 : 1)
TierScale = 0.35 + 0.65·ss((PI − 250)/300)
L += (L_t − L)(1 − e^(−rate·dt));  rate = 3 rising, 8 if thr < 0.3 or counter-steering, else 2.5
```
- L reduces lateral grip by 70%, thrust by 35% and yaw authority by 85%, and adds yaw acceleration of 7 rad/s².
- A grace timer of 1.5 s starts on the change from anchored to unanchored (race and duel starts).
- When the car ends up rolling backwards with throttle held, today's Braking mode takes over and the car recovers naturally.

**Generated envelope.** Keyboard, full throttle and full lock held for 2.5 s. Each cell is max slip / time to spin (slip above 75°).

| Car | 0 mph | 5 | 10 | 15 | 20 | 25+ |
|---|---|---|---|---|---|---|
| E Piercer, E Muscle, C Exotic, S Exotic (traction assist on) | 10-18° | | | | | none |
| D Muscle | 63° | 68° | 72° | 57° | 17° | none (slides and recovers) |
| C Piercer | 50° | 21° | 13° | | | none |
| C Muscle, B Muscle | 1.52 s | 1.47 s | 1.43 s | 1.38 s | 1.57 s | none |
| S Piercer | 1.97 s | 1.87 s | 1.98 s | 23° | | none |
| S Exotic, traction assist off | 39° | 40° | 38° | | | none |

Guard cases (C Muscle and S Piercer at 10 mph):
- Steer tapped for 0.25 s or 0.6 s, or throttle lifted at 0.6 s: no spin.
- Gamepad at 60% steer with full throttle: never spins.
- 85% steer with full throttle: spins Muscle only. Full lock at 60% throttle: no spin; at 80%: Muscle spins.
- Steering at a standstill with no throttle: never spins.

**Tuning dial:** `SpinBuildRate` 3 → 4.5 brings time-to-spin down to about 1.0-1.2 s and makes S Piercer spin up to about 15 mph.

### 3.6 Neutral revs during the countdown (anchored branch, 1068-1085)

- No forces; the CAM-02 invariant holds.
- Gear N; `Rpm` follows `I + thr·(0.9R − I)` with τ 0.12 s and a bouncing limiter.
- Publishes `FeelRpm`, `FeelLoad = thr`, `FeelGear 0` and the HUD telemetry (instead of zeroing `FeelThrottle`).
- On unanchor: gear 1 at the revved rpm, launch slip, and the spin grace timer starts.
- The countdown does not take `GameplayInputGate` (it only anchors), so throttle is live.

### 3.7 What is kept

- DRIVE-01 at 1255-1285 and the raw-steer bank.
- `SteeringCoastAssumeForward`, the 8 mph reverse latch and reverse ×3.
- Auto-hold snap at 3 mph or less, and the Reverse/Stopped branches.
- `FeelSpeedMph` stays the real speed. The display curve (0.86-1.08) stays display-only; gears use real speed.
- The Feel contract: missing attribute means fall back, values cleared in `Stop`, client-local.
- Mini-boost throttle rule, the four hover rays, no per-frame allocation or new connections.
- Every feature has a 0/1 switch. With all switches at 0, the result must match today exactly.

## 4. Config

**`Dynamics.09_Gearbox`** (numbers; each has a `_RaisingThisDoes` string):

| Group | Attributes (default) |
|---|---|
| Switches | GearboxEnabled 1, GearboxAutoShift 1, NeutralRevEnabled 1, BoostSpeedShapeEnabled 1 |
| Thrust and traction | GearTorqueExponent .85, TractionBaseG 1.15, TractionGripExponent .15, TractionAssistScale 1, ThrustSlipFlareGain .6, SlideGripFraction .88 |
| Shift points | UpshiftFlatFraction .97, UpshiftPartLow .62, UpshiftPartHigh .85, UpshiftCruise .45, UpshiftMinLand .33, DownshiftBrakeLand .82, DownshiftCoast .30, KickdownThrottle .95, KickdownLand .88 |
| Timing and limiter | ShiftMinIntervalScale 1, StopGearMph 3, LimiterOnSeconds .03, LimiterHysteresisRpm 150 |
| Resistance | RollingDecelBase .8, RollingDecelPerStud .004 |
| Boost and guard | BoostShareMin .15, SpeedGuardStrength 2.0, SpeedGuardOverVb 1.03 |
| Braking | BrakeV2Enabled 1, BaseBrakeDecelerationV2 70, BrakingForceExponentV2 .35, BrakeFactorMinV2 .75, BrakeFactorMaxV2 1.4 |

**`Dynamics.10_Chassis`:**

| Group | Attributes (default) |
|---|---|
| Switches | ChassisEnabled 1, YawInertiaEnabled 1, LateralCapEnabled 1, GripRelaxEnabled 1, AccelPitchEnabled 1, LateralRollEnabled 1, EngineBrakeEnabled 1 |
| Yaw | YawResponseBase 8, YawResponseWeightExponent .5, YawResponseMin .75, YawResponseMax 1.3, YawRateHardMax 5 (clamp at 5 or less for the camera invariant) |
| Steer limit | KeyboardSteerRise 5, KeyboardSteerReturn 8, TouchSteerRate 10 |
| Lateral | LateralCapG 3.4, LateralCapGripExponent .25, YawCapMargin 1.15, YawCapDriftExtra 1.5, GripRelaxStuds 2.0 |
| Pitch and roll | PitchDegreesPerG 2.4, PitchMaxDegrees 5, PitchSpringOmega 9, PitchSpringDamping .6, RollDegreesPerG .9, RollMaxDegrees 3 |

**`Dynamics.11_SpinOut`:** SpinOutEnabled 1, SpinSlipStart .12, SpinSlipFull .25, SpinSteerStart .6, SpinSteerWidth .35, SpinFullBelowMph 24, SpinFadeMph 14, SpinYawGate .15, SpinYawGateWidth .35, SpinBuildRate 3, SpinDecayRate 2.5, SpinCatchRate 8, SpinYawAccel 7, SpinMaxYawRate 3.6, SpinGripLoss .7, SpinThrustLoss .35, SpinTierFloor .35, SpinTierStartPI 250, SpinTierFullPI 550, SpinStartGraceSeconds 1.5.

**`Config.Vehicles.Drivetrain/{exotic, bruiser, muscle, default}`:** GearCount, Ratios (string), RedlineRpm, LimiterRpm, IdleRpm, LaunchRpmFraction, TopGearOverspeed, TorqueCurve (string "x:y,..."), ShiftCutSeconds, ShiftCutTorque, ShiftBlendSeconds, ShiftRpmTau, ShiftMinIntervalSeconds, EngineRiseSeconds, CategoryTraction, TractionAssist, EngineBrake, SpinGain, LimiterCutSeconds, HudShiftLeadSeconds 0.15. Unknown category ids fall back to `default`.

**Debug attributes** (only when `DebugAttributes` is on): DynamicsGear, DynamicsRpm, DynamicsDesignTopMph, DynamicsBoostTopMph, DynamicsTraction, DynamicsWheelspin, DynamicsSpin, DynamicsBoostShare, DynamicsVirtualFinalDrive (cosmetic).

**New Feel attributes** (written only when changed, quantised, added to `FEEL_ATTRIBUTES` at 848):

| Attribute | Value |
|---|---|
| `FeelRpm` | 25 rpm steps |
| `FeelRedlineRpm`, `FeelIdleRpm`, `FeelGearCount` | per car |
| `FeelGear` | −1 R, 0 N, 1-7 |
| `FeelLoad` | 0.02 steps (throttle × shift cut × limiter) |
| `FeelShiftRevision`, `FeelShiftKind`, `FeelShiftStrength` | Up / Down / Launch; strength 0.05 steps |
| `FeelCut` | 0.1 steps (shift or limiter) |
| `FeelLimiterRevision` | counter |
| `FeelThrustSlip` | 0.05 steps |
| `FeelSpin`, `FeelSpinDirection` | 0.05 steps; ±1 |

**HUD telemetry.** `DriveSessionClient.PublishMobile(speed, boost, telemetry)` takes an optional third argument: a table preallocated in DrivingClient and reused. It writes these `MobileDriveInputState` fields: `Gear` ("N"/"R"/"1".."7"), `GearRevision`, `RpmFraction` (rpm/(R/0.8)), `ShiftLight` (0 off, 1 warm, 2 flash, 3 limiter), `Spin`. `SetMobileDriving(false)` clears them.
- No edit to `MobileDriveInputState` is needed.
- This does not touch the parity of the `TouchControlsClient` fork, which concerns the touch writes.

## 5. Areas

### Audio (`VehicleAudioClient`, `VehicleAudioCatalog`, `Config.Audio.VehicleProfiles`)

- **Rev source (line 882):** when `FeelRpm` is present, `revTarget = clamp((FeelRpm·RevRpmScale − RevRpmMin)/(RevRpmMax − RevRpmMin), 0, 1)`. These are new profile attributes; V10 uses 1000/8000. Otherwise the current formula runs. Load target becomes `FeelLoad` when present.
- **Shift event:** on `FeelShiftRevision` (baseline-first, like pops), `f.Rev` jumps through a 35 ms `ShiftDropSeconds` instead of `follow`. Downshift adds a rev blip (+0.08 rev for 0.12 s) plus a load spike for bark. Upshift lets the existing bark fire on re-engage.
- **Engine sub-bus per graph:** rev voices → `EngineBus` fader → `AudioDistortion` → `AudioEqualizer` → `AudioCompressor` → `AudioTremolo "Cut"` → the existing route. Parented to `graph.Root`, so `destroyGraph` cleans it up.
  - Distortion level: Exotic 0.08 + 0.22·L, Piercer 0.10 + 0.25·L, Muscle 0.15 + 0.30·L, plus 0.15 while cutting.
  - EQ: Low +2 + 4·L^1.5 dB, Mid +1.5·L, High −2 dB.
  - Compressor: −12 dB, ratio 3.
  - Tremolo: bypassed except while `FeelCut`; 14 Hz square, duty 0.55 for the limiter, one 60-200 ms dip per shift.
  - Local car and detailed remotes get it; remotes skip the tremolo. That is 4 extra instances per graph, not per voice.
- **Two pitch lines** (an answer to the clip, not a copy):
  - The grungy engine family follows rpm, so it saw-tooths through the gears.
  - A new `ReactorWhine` loop, plus TurbineLow/High and EnergyHum, follows speed: smooth, like an EV motor. On each shift it dips 3% in pitch for 80 ms as a "capacitor chirp". Gain is 0.25 + 0.75·load.
- **New one-shot slots:**
  - `ShiftThunk` ×4: a dry clack-thump with a short chirp, gain by strength.
  - `ShiftVent` ×3: plasma crackle on hard upshifts; louder on Muscle.
  - `LimiterStutter`: a field grain at 12 Hz.
  - `GravSkid` loop: the already-uploaded `scrape_loop`, gain = FeelSpin × speed.
  - `ThrustSlip`: whirr at launch.
  - `SlipStrain` is also driven by `FeelSpin`.
  - Shift crackle must never go through `FeelPopRevision`, or the VFX would fire twice.
- **Voices:**
  - Exotic: V10 hybrid re-synthesised grungier (on-load `gainvar` 0.12-0.2, `drive` +0.2, `half/eng` up, presence −1 dB, sheen −18 dB).
  - New `MUSCLE_V8_AUDIO`: crossplane V8, cylinder count made a parameter in `make_sounds.py` (firing rpm/15, uneven bank pulses). On-load layers at 1500/2500/3500/4500/5500/6500, plus off-load 2500/4500, plus idle 800 with lope.
  - New `PIERCER_I6T_AUDIO` (D10): turbo inline-6 with an ion turbine, layers up to 7500.
  - Mapped with `CategoryProfile_muscle` / `_bruiser`. Bump `ProfileRevision`.
- **Remote cars:**
  - `GearProfile(vehicle, quiet)` is cached on the graph at the 4 Hz refresh.
  - Gear comes from replicated speed with hysteresis: up at x ≥ 0.92 if `AudioDrive == Accelerating` (0.6 otherwise), down at x < 0.45.
  - Shift events are made up on the receiving client.
  - No network or contract change; still 3 remote rev voices.
- **Listen pack** (`scripts/<delivery>/audio/listen/`): WAVs per category, rendered offline from the synthesised loops plus a Python port of the crossfade and the gearbox simulation:
  - a full-throttle run through every gear to top speed;
  - lift-off with engine braking and downshifts to a stop;
  - neutral revs with limiter bounce;
  - a launch with thrust slip;
  - a spin with grav-skid;
  - part-throttle short shifting.
  Oscar judges the pack before anything is uploaded.

### HUD (Pulse only; Classic frozen, following the radio precedent)

- **`HudView` 399-405:** if `drive.RpmFraction ~= nil`, call `gauge.SetSpeed(speed, RpmFraction)`; otherwise keep the speed fraction. Redline sits at 0.8 of the sweep, so the existing "pink last fifth" ticks become the redline zone with no new art.
  - `gauge.SetGear(drive.Gear)` runs on change; a `GearRevision` change triggers the punch; `gauge.SetShiftLight(drive.ShiftLight)` runs every frame.
- **`Kit.Gauge` additions** (Kit API extension; needs the reviewer, gallery fixtures and k3 tests):
  - **Gear readout:** in the bottom gap at y +0.40. Digits use BigNumber; N and R use the Text role, since there are no sprites for them (D9).
  - **Punch:** UIScale 1.15 → 1 with τ 0.12 s.
  - **Shift light:** the tip glow and tick tint. Warm from 0.12R below the flash point; flash at 8 Hz, duty 0.6, starting on the frame it begins; limiter strobe at 12 Hz.
  - **Flash point:** the upshift rpm minus (rpm rate × 0.15 s), clamped to 0.05-0.15R. It only lights below top gear and moving forward.
  - **Phone (92 dp compact):** the gear takes the place of the unit line.
- **Budgets:** about 5 writes per frame for the arc and tip (same as today), plus at most 1 gear write per shift, plus about 0.3 per frame for the flashing light. Well under the 16-write median and the 26-instance limit.

### Camera (`DrivingCameraClient`)

- **Spin mode:** `w = smoothstep(0.2, 0.6, FeelSpin)`. The yaw target blends toward the travel direction (`yawOf(horizontal)` above 4 studs/s), `ChaseYawResponse` is multiplied by (1 − 0.5w), and the slip roll is replaced by a travel-based roll.
- **Shift:** on `FeelShiftRevision`, pitch nod of 1.2° × strength through the punch spring, and an FOV pulse of −1.5° × strength through `CameraService.SetFieldOfView("DrivingCamera")` only. Downshift 0.5°. Launch kicks the lag spring.
- **Limiter shimmer:** 0.1° roll at 12 Hz while `FeelCut` is on.

### VFX (`VehicleVFXClient`)

- Thrust intensity uses `FeelLoad`, so it dips and flickers during cuts and on the limiter.
- Vent flame on `FeelShiftRevision` (Up, strength 0.7 or more), not through pops.
- `FeelSpin`: stabiliser jets alternate at 9 Hz, plus dust and sparks.
- `FeelThrustSlip`: rear thrusters over-glow and throw a ground wash at launch.

### Haptics (DrivingCameraClient, `chaseEvents`)

- Through `HapticService:SetMotor` on Gamepad1. Exact API support is inferred: use pcall and `IsMotorSupported`.
- Shift: small motor 0.35 for 80 ms. Limiter: 0.2 buzz. Spin: large motor = FeelSpin × 0.6. Impact and landing are mapped too.
- Mobile stays behind its own switch, off until a device test.
- Switches: `Camera@HapticsEnabled` 1 and `HapticsMobileEnabled` 0. Haptics stop if `ScriptedChaseEnabled` is 0; record that.

### Races and other systems

- **Countdown:** revs in neutral, HUD shows N, launch on GO, 1.5 s spin grace (time trials, matchmaking, duels).
- **Medals:** every per-tier medal in `TimeTrialCatalog` (both events) needs re-measuring. Laps will lengthen because of lower top-end acceleration and longer braking.
- **Personal bests:** bump the store suffix to `_v2` (D12).
- **RaceIntegrity and rewards:** stay safe because of the boost shaping and the guard. Verify that boosted top speed is today's +3% at most.
- **Job crash rule** (a 35 mph drop within 0.25 s): a spin below 30 mph cannot trip it.
- **Collisions:** low-speed spins in traffic will hit other cars (collision is on below 16 mph). Accepted.
- **PI and stat bars:** unchanged. VEH-01 double-counting makes `TierScale` slightly generous.

## 6. Delivery

**Lane and folder.** High-Risk, one full docs/15 contract, folder `scripts/drivetrain_feel/`.
- `build.py` with `PLACE_ID = 103397770260610`, `serve.py` on port 8797.
- Installer marker `DrivetrainFeelInstalled`.
- Fresh `before/` taken through `POST /put`: the old driving_tune and hover_feel rollbacks are dead.
- Two transactions: config and hierarchy first, then sources.
- Classic `declared.json` covers DrivingClient, VehicleDynamics, DriveSessionClient, DrivingCameraClient, VehicleAudioClient, VehicleAudioCatalog and VehicleVFXClient, plus the Classic verify and a smoke check.

**Phase 0 (integrator):**
- Fix the interface in the contract (section 4) so the parts can run in parallel.
- Take `before/`.
- Measure the baseline in Play in the sandbox window: 0-60, 0-100, top, boosted top, braking and coast-down from 34 mph for E/C/S, plus the coast-mismatch probe.
- Port this simulation to `gearbox/model.py` and `chassis/sim.py`, checked against the measured Seraph run.

**Phase 1 (parallel parts; `edits.py` and `NOTES.md` only, no Studio or git):**

| Part | Owns |
|---|---|
| A gearbox | VehicleDynamics drivetrain profile and step; StepLongitudinal branches; DrivingClient longitudinal, anchored, Feel and telemetry anchors; config 09 and Drivetrain |
| B chassis | DrivingClient input rate limit, yaw, lateral, pitch, roll, spin; StepHandling outputs; config 10 and 11; uses A's `WheelspinExcess` (stubbed until A lands) |
| C audio | Client and catalog edits, sub-bus, remote gear, slots, profile config spec, `make_sounds.py` V8/I6, listen-pack renderer |
| D HUD | DriveSessionClient, HudView, Kit.Gauge, tests and gallery |
| E camera, VFX, haptics | DrivingCameraClient, VehicleVFXClient |

A and B use separate anchors in DrivingClient.

**Phase 2 (integrator):**
- Compose, compile (`loadstring`), AUDIT with the Classic verify, then delivery-reviewer.
- APPLY with every new switch at 0, prove parity, ROLLBACK, APPLY again.
- Turn switches on in order: Gearbox → Chassis → SpinOut → audio code (existing V10 layers) → HUD, camera, VFX.

**Phase 3:** the Play matrix below; Oscar's feel pass.

**Phase 4 (second, smaller install after Oscar approves the listen pack and uploads):** new voice and one-shot asset ids, profile mapping, re-measured medals, personal-best suffix.

**What Oscar has to do:**
- Answer the decisions.
- Approve the listen pack.
- Upload about 35-40 audio files: about 27 loops across three categories plus about 10 one-shots.
- Judge the feel in Play.
- Test on a real phone.
- Run the published two-player test.
- Approve the medal values and the personal-best reset.
- Publish.

**Verification matrix** (agent-verified unless marked):

| # | Check | How |
|---|---|---|
| 1 | Parity with switches off | Every row of the baseline within ±2% |
| 2 | Straight line per tier and category | Log Feel/Dynamics attributes every 0.25 s; top ±3%; 0-60/0-100 within ±12% of section 3.3 |
| 3 | Boost safety | Endless boost: top within today's +3%, under 320 mph |
| 4 | Shifts | Count and times, cut lengths, no hunting at steady 60 mph with throttle 0.5 injected through `MobileDriveInputState` |
| 5 | Spin, keyboard | Hold W+A/W+D at 0/10/20/30 mph on C Muscle, S Piercer, S Exotic and E Piercer, against the section 3.5 envelope |
| 6 | Spin, guards | Taps, lifting, counter-steer catch; injected analog for gamepad; digital `State` for touch at a touch viewport |
| 7 | DRIVE-01 | Three-point turn, brake to reverse, coast-reverse latch, reverse steering, bank direction |
| 8 | Countdown | Time-trial start in the sandbox (never finish): N, revs, launch, grace |
| 9 | Camera | Count `resetChase` calls during a spin (expect 0); maximum per-frame heading change |
| 10 | HUD | Kit.Perf write median ≤ 16; screenshots at gear N/1/top/R, shift light, limiter; phone and tablet emulation; race HUD overlap |
| 11 | Audio | Rev follows `FeelRpm`, voice counts within budget (desktop 46, mobile), Studio two-client local test of remote gears (labelled local, not published multiplayer) |
| 12 | Cleanup | 5 enter/exit cycles: attributes cleared, telemetry cleared, no leaked effect nodes |
| 13 | Console | Clean before and after |
| 14 | Oscar only | Feel, sound by ear, phone device, published multiplayer |

**Recovery:**
- Each feature can be switched off instantly with its 0/1 switch, no rollback needed.
- ROLLBACK restores the sources and removes only marked config.
- The audio mapping goes back by resetting the `CategoryProfile_*` values.

**Risks:**
1. Pacing changes a lot (S 60-130 goes from 2.4 to 4.9 s, braking is about 60% longer), so medals and possibly track flow need work.
2. Boost runaway if the shaping is off. The guard is required.
3. The unexplained coast loss.
4. Keyboard players getting frustrated by spins (mitigated by tier scaling, the grace timer and Exotic traction assist).
5. Muscle loses drag starts.
6. Kit API is frozen, so the HUD needs reviewer sign-off.
7. Audio instances on mobile.
8. Category ids are inferred.
9. Toolbox audio ids may not load on a published server.
10. Yaw lag stacks with the Align lag, so tune them together.
11. Many debug attribute writes per frame (an existing pattern).

## 7. Decisions for Oscar (recommended default first)

1. **How much weight:** "Grounded" (p 0.85; S 0-100 4.4-5.0 s) or "Sport" (p 0.7; about 4.2 s). Default Grounded: it best matches "less arcadey", and p can be changed live.
2. **Auto now, Manual later.** Manual keys Z/X plus LB/RB, because E belongs to world prompts. No manual on touch. Default yes: it keeps prompts and the touch fork untouched.
3. **Gear counts 7/6/4** as in section 3.2. Default yes: they give each class its own character.
4. **Spin authority scaled by tier** (E/D at 0.35) and traction assist on Exotic. Default yes, to protect new players while Muscle and high-power cars still spin.
5. **1.5 s spin grace after race and duel starts.** Default yes: a spin on the start line feels unfair.
6. **Braking cut to about 2.1 g on S** (from 3.1 g). Default yes: it is a large part of the "weight".
7. **Muscle launch limited by traction** (slower to 60, more character). Default yes. The alternative is Muscle traction 1.0, at the cost of fewer spins.
8. **Lateral cap 3.4 g.** Default yes. 3.0 g would feel heavier but widen high-speed corners by up to 47%.
9. **rpm arc instead of the speed arc, speed digits kept, N/R as text.** Default yes: no uploads needed.
10. **Piercer voice:** turbo inline-6 with an ion turbine. Default yes: it stands apart from the V10 and the V8.
11. **Sound before new voices are approved:** Muscle and Piercer temporarily use the V10 layers driven by rpm. Default yes: otherwise two classes have no audible gears.
12. **Personal bests:** bump the store to `_v2` and keep the old data. Default yes: physics changed.
13. **Haptics:** gamepad on, mobile off until a device test. Default yes.
14. **Traction not reduced by Balance.** Default yes: Balance still acts through thrust, top speed and braking.
15. **Remote cars derive their gears locally** with no network change. Default yes: no change to the remote rules.
16. **One contract, two installs** (physics, HUD, camera, VFX and audio code first; new voices after your approval). Default yes: the voices depend on your listening and uploads.

### Critical Files for Implementation
- PR98 live `ReplicatedStorage.Modules.Game.Vehicles.DrivingClient` (repo export is stale; capture fresh into `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\before\`)
- PR98 live `ReplicatedStorage.Modules.Game.Vehicles.VehicleDynamics`
- PR98 live `ReplicatedStorage.Modules.Game.Audio.VehicleAudioClient` (and `VehicleAudioCatalog`)
- PR98 live `ReplicatedStorage.Modules.Game.UIPulse.Kit.Gauge` and `UIPulse.FreeRoam.HudView` (plus `Vehicles.DriveSessionClient`, `Vehicles.DrivingCameraClient`)
- `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\driving_tune\balance\model.py` and `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\hover_feel\synth\make_sounds.py` (offline model and synth to extend)