# DRIVE: Highway: drivetrain and handling research for PR98 (inspiration only, read-only)

Studio: `DRIVE: Highway DEVELOPMENT` (studio_id 37878c5c-…), Edit mode. Nothing was modified. No execute_luau or edit tools were used. Every module path below is under `ReplicatedStorage.Modules.Game.Racer`. Near-identical copies also exist under `ServerStorage.Scratch.*` and should be ignored.

## 0. Module map (simulation core)

- **`Sim.Vehicle`** binds the sim to Roblox. It reads the Root, does spherecasts, writes `VectorForce`/`Torque`, and handles impacts and contact softening. `Vehicle:update(dt)` runs from `RunService.PreSimulation` on the driver's client, and the client owns the car's physics (header lines 1-5).
- **`Sim.Chassis`** (1748 lines) runs one car per frame through a small `io` interface (lines 2-13). `Chassis:step` is lines 428-1716.
- **`Sim.Engine`**: combustion engine, turbo, limiter, launch control, and pops and bangs. Pure logic.
- **`Sim.Motor`**: electric drive unit. It exposes the same interface as Engine (`Engine.new` hands back `Motor.new` when `tune.electric`, line 51).
- **`Sim.Drivetrain`**: clutch, H-gate gearbox, quick shift, diffs, brakes, and a 6-DOF implicit solver.
- **`Sim.Tire`**: combined-slip, magic-formula-style curve plus load sensitivity.
- **`Sim.Steering`**, **`Sim.Suspension`**, **`Sim.Aero`**.
- **`Sim.Defaults`** holds the shared handling feel. **`Sim.TuneFactory`** builds each car's tune as `derive(Defaults, Cars.<Id>.Tune, Hardpoints)`.
- **`Input.Pilot`** (1668 lines) models the driver's hands and feet, including the "ProAuto" works driver and Manual mode.
- **`CarState`** is the per-frame state every other system reads (HUD, audio, FX).
- **Car folders** `Cars.<ID>.{Tune, Hardpoints, Def, Audio, Targets, Mods, Lights, Cockpit}`. Example tunes read: `Cars.WEIHE.Tune` (AWD turbo 5-cylinder), `Cars.SHOWDOWN.Tune` (RWD V8 muscle), `Cars.ARCLIGHT.Tune` (electric).

## 1. Engine model (`Sim.Engine`, `Sim.Defaults`)

**Torque curve**
- Each car's tune has a table of `{rpm, N·m}` points:
  - `fullLoadTorque` is net crank torque at full throttle.
  - `fullLoadBoost` is the turbo boost (bar) at wide-open throttle.
- Two lookup tables are built every 50 rpm, from 0 to 10000 (Engine lines 12-13 and 37-47).
- Equation: `naLut = (fullLoadTorque + frictionRunning + frictionViscous·ω) / (1 + boost)`, a "naturally aspirated" torque per unit of manifold pressure.
- Weihe: `{2250, 500} … {5600, 500}, {6000, 467}, {7000, 401}, {7200, 350}, {9000, 180}` (WEIHE.Tune lines 20-23).
- Showdown V8: peak `{4900, 567}`, falling to 455 at 7500 (SHOWDOWN.Tune lines 25-29).

**Rev range**
- Weihe: `idleRpm = 850`, `redlineRpm = 7200`, `limiterRpm = 7300`, `launchRpm = 4800`.
- Showdown: 700 / 7500 / 7600.

**How throttle maps to torque**
- `pedalMap = pedal ^ pedalGamma`, with `pedalGamma = 1.12` (Defaults line 16).
- A manifold pressure ratio `charge` eases toward `max(chargeMin, pedalMap·(1+turbo))`. Time constants: `intakeTauUp = 0.045` s, `intakeTauDown = 0.035` s, `chargeMin = 0.15` (Engine lines 343-356).
- Combustion torque is `comb = na(rpm) · charge`, capped at `na·max(1, 1+turbo)`, then multiplied by `torqueScale` (traction control, ESC and corner assist) and by `driveEfficiency = 0.92` (Engine lines 716-740).
- The turbo spools at a rate set by exhaust energy: `exhaust = clamp(rpm/6000) · charge`, `spoolRate = 3.4`, `spoolDownRate = 1.1`. Boost is capped per gear by `boostByGear` (lines 320-340).

**Engine braking** happens at the crank and emerges from three losses:
- Coulomb `frictionRunning`: 16 N·m (Weihe) or 24 N·m (V8). It is handled as a solver row (Drivetrain lines 563-568).
- Viscous `frictionViscous`: about 0.06 N·m per rad/s.
- Pumping loss `pumpingMax · vac`, where `vac = (1 - charge)/(1 - chargeMin)`: 18 N·m (Weihe) or 30 N·m (V8) (Engine lines 701-708).
- An overrun fuel cut applies when `pedal < 0.02` and rpm is above `fuelCutRpm = 1400`, with 250 rpm of hysteresis (lines 304-309).
- These losses are multiplied by the gear ratio at the wheels, so engine braking is naturally stronger in low gears.

**Engine inertia**
- `engineInertia`: Weihe 0.16 kg·m² ("light flywheel, rev-happy"), Showdown V8 0.22, electric motor 0.06-0.07.
- The crank speed is integrated by the Drivetrain solver, not by the Engine (header line 6).

**Idle governor (anti-stall)**
- PI controller: `idleKp = 5`, `idleKi = 30`, `idleIMax = 60` N·m (Defaults lines 24-26).
- It adds torque up to `maxComb` whenever rpm drops toward `govTarget` (Engine lines 722-731 and 754-759).
- `antiStallRpm = 1150` while the clutch bites near a standstill.
- No car ever stalls: the Drivetrain also fades clutch capacity out as rpm falls under idle (Drivetrain lines 547-551, `antiStallUnder = 50`, `antiStallBand = 300`).

**Limiter: a bouncing hard cut** (Engine lines 778-800)
- The cut starts when `rpm >= L` and the engine has been on for at least `limiterMinOn = 0.022` s, or at once when `rpm >= L + limiterOvershoot (60)`.
- The cut ends after `limiterMinCut = 0.040` s once rpm falls below `L - limiterHysteresis (150)`, or after `limiterMaxCut = 0.065` s if rpm is below `L + 30`. The max-cut timer exists because in gear the rpm can't fall, which produces the stutter.
- It emits a `"LimiterHit"` event.
- Other limit modes: `launch` (2-step at `launchRpm`), `flat` (no-lift shift hold), and `rebite` (limiter minus 60 rpm for 0.25 s).

**Event queue drained by Chassis:** `Crank`, `Started`, `LaunchArmed`, `Launch`, `LimiterHit`, `BOV`, `Pop`, `Bang` (with `strength`, `flame`, `huge`, `tip`), and `NitrousOn`/`NitrousOff`. These drive audio and FX. Pops have three styles (`popStyle`: "classic", "chaos", "obnoxious"), each a stochastic point process tied to lift-off after load (Engine lines 358-420 and 422-596).

## 2. Gearbox (`Sim.Drivetrain`, `Sim.TuneFactory`, `Input.Pilot`)

**Ratios and wheel-to-rpm coupling**
- `gearRatios = { [-1]=-3.18, [0]=0, 3.36, 2.09, 1.47, 1.10, 0.87, 0.657 }`, `finalDrive = 3.65`, `topGear = 6`. Up to 8 gears are allowed (WEIHE.Tune lines 53-56; `TuneFactory.MAX_GEARS = 8`).
- Showdown: `3.237, 2.104, 1.422, 1.000, 0.814, 0.622`, final drive 3.73.
- Helper functions on every tune (TuneFactory lines 82-89):
  - `inputRpm(gear, v) = v / wheelRadius · ratio · finalDrive · 30/π`
  - `speedAt(gear, rpm)` is the inverse.
- Wheel radius comes from `Hardpoints.TyreRadius` in studs × `M_PER_STUD = 0.2452`.

**Physical coupling**
- A 6-DOF rotational solver covers crank, input shaft, FL, FR, RL and RR (Drivetrain lines 1-11 and 491-630).
- The gear mesh is a rigid velocity constraint: `w_in = G · (k·front-axle mean + (1-k)·rear-axle mean)` (lines 524-531).
- The clutch, synchro, engine friction, centre coupling, LSDs and brakes are bounded constraints. Each one locks when the torque it needs is within capacity and slips at capacity otherwise. They are solved exactly every substep with a small active-set LCP (lines 397-488).
- So rpm is a real state that the wheels can drag down (lugging) and that wheelspin can drive up.

**Clutch**
- `capacity = clutchCapacity · clutchEngagement(pedal)`. Weihe 700 N·m; Showdown 800 N·m, about 1.4× peak torque.
- The engagement curve is `x^clutchCurve`, with `clutchCurve = 2.2` between pedal positions `clutchEngaged = 0.15` and `clutchOpen = 0.75`. It blends with `x^12` through `clutchBiteCapacity` (TuneFactory lines 75-81; Defaults lines 156-158).

**H-gate (Manual, and ProAuto when it selects from N or R)** (Drivetrain lines 274-353)
- Lever throw time is the gate path length × `shiftTimePerStud`, from `shiftTimePerMetre = 1.29` s/m, minimum `shiftMinTime = 0.07` s.
- The gear won't come out under load: it waits up to `shiftWait = 0.3` s for torque to fall below `releaseTorque = 40` N·m.
- It engages if the speed mismatch is under `rematchRpm = 250`. Otherwise the synchro (`syncTorque` about 60 N·m, `syncTimeout = 0.35` s) takes over, and failure produces a grind into neutral.

**Quick shift (what ProAuto uses between forward gears)** (Drivetrain lines 210-271 and 497-561; Defaults lines 172-180)
- The ignition is cut for `quickCutUp = 0.033` s or `quickCutDown = 0.03` s with the old gear still engaged. This is the torque cut, timed per substep so it is frame-rate independent.
- Then the dogs swap and `"Shift"` fires.
- A slip phase follows. The clutch carries `qHold = clamp(|inputTorqueAvg|, 0.2·cap, cap)` on upshifts, and a light drag `quickDrag = 0.1·cap` on downshifts. It ends when crank and gearbox are within `quickSyncRpm = 100` rpm, or after `quickSlipMax = 0.25` s.
- Measured shift time: 0.07-0.15 s, against 0.38-0.48 s through the gate (comment at lines 213-216).

**Events:** `GateMove {from, to, quick, cut}` and `Shift {from, to, clutch, grind, flat, quality}`. These feed the cockpit lever, the camera and audio.

**ProAuto: a virtual "works driver"** (Pilot header lines 4-14; constants lines 130-202; logic `_proSchedule` lines 977-1072 and `_pro` lines 1208-1495)
- ProAuto operates the real clutch, throttle and gear requests through the same physics as Manual.
- The rpm constants are written for the Weihe's 7200 redline and scale by `redlineRpm/7200` for other cars (lines 245-258).

*Upshifts*
- **Flat out:** `proUpFlat = 7000` rpm, predicted `proUpLead = 0.05` s ahead, minus a "flare" allowance of `(engineTorque-600)·0.25`, capped at 450 rpm.
- **Feathering** (throttle 0.3-0.85): a lift-shift at `proUpPart = {4000, 6000}`.
- **Cruising** (throttle 0.05-0.3): a short-shift at `proUpCruise = {2500, 3000}`.
- It never upshifts into fewer than `proUpMinLand = 1500` rpm, and not while rear slip is above `proSpinSlip = 1.3` (lines 994-1027).

*Downshifts* (never below 2nd from the schedule; 1st is for stopping)
- **On the brakes:** the next gear down as soon as it lands at or below `proDownLand = 6500`. This is a heel-toe shift with a rev-match blip.
- **Kickdown:** floored below `proKickRpm = 5500`, it drops straight to the lowest gear (2nd or higher) that lands at or below `proKickLand = 6000`.
- **Coasting:** below `proCoastRpm = 1900` (or 2600 when fully off the gas), one gear down if it lands at or below 4000.
- **Analog part-throttle kickdown:** `_partKick`, lines 1081-1092.

*Timing*
- At least `proInterval = 0.35` s between shifts; a quick kick may follow 0.1 s after a shift.
- Under `proStopSpeed = 2.8` m/s, the clutch goes in and 1st is selected.

*Throttle and clutch behaviour*
- **Rev-match blip on downshifts:** `_revHold` (lines 541-545): `want = inputRpm(target) + 60`, `throttle = clamp(0.30·want/7000 + (want - pred)/700, 0, 0.85)`.
- **Lift through non-flat upshifts:** the throttle goes to 0 (line 1425).
- **Rev cap:** it feathers at `proRevCap = 7250` so it never bounces off the cut (line 1435).

*Launch and pull-away*
- **Launch:** S+W at a standstill arms the 2-step; releasing S dumps the clutch over `proLaunchBite = 0.20` s.
- **Pull-away:** a PI loop on clutch slip toward `proPullRpm = 3900` for `proPullTime = 0.35` s (`_proPull`, lines 1096-1123).

*Sliding*
- While the car slides or drifts, ProAuto holds its gear and upshifts only at the cut.
- With the steering at or above `proCornerSteer = 0.5`, an upshift goes through the clutch (not the quick path), so a car at the limit gets a drive gap (lines 935-937).

*HUD output*
- `controls.upshiftRpm` publishes the planned upshift point for the HUD shift light (lines 1452-1464, 1660).
- HUD (`HUD.Hud` lines 107-113): the light leads the shift by `AUTO_LEAD = 0.28` s, clamped between 120 and 1200 rpm, and does not flash below 4500 rpm. The fallback `autoUpshift` (lines 228-235) uses `redline - 150` when flat and `4000-6000 × r/7200` at part throttle.

**Manual mode** (`Pilot:_manual`, lines 845-894)
- Ctrl is the clutch, and E/Q/1-6/R/0 select gears.
- A clutch assist is optional, and always on for gamepad and touch.
- Throttle taps become blips (`_tapBlip`, lines 897-927).
- Limb motion has bounded speed and acceleration (`throttleIn = 0.12` s, `clutchIn = 0.09` s, bite zone 0.25-0.65, `biteMove = 0.36` s, …, lines 43-72).
- The gearbox is selected by `settings.gearbox` ("ProAuto" by default, or "Manual"), at line 1554.

**Electric single-gear mode** (`Sim.Motor`; ARCLIGHT.Tune lines 29-47)
- `electric = { torque = 800, power = 393 kW, powerFade = {fromKmh=100, toKmh=250, power=240}, reduction = 9.0, topKmh = 217, regenTorque = 160, regenPower = 75, regenKmh = {4,10}, inertia = 0.07 }`.
- `Motor.expand` writes the engine and gearbox terms:
  - `gearRatios = {[-1]=-1, [1]=1}`, `topGear = 1`.
  - A clutch that never opens: `clutchEngaged = 2`, `clutchOpen = 3`.
  - `idleRpm = 0` and `popStyle = "none"`.
- The torque curve is flat to base rpm, then constant power, then fades.
- The limiter is soft: drive fades across `capBand = 100` rpm. Lift-off regen eases in over 0.18 s (Motor lines 66-121 and 252-291).
- Pilot drives it through `_direct`: D, R and N only.

## 3. Tyre and handling model

**Tyre curve** (`Sim.Tire`)
- Normalised combined slip: `sx = κ/κpeak`, `sy = tanα/tanαpeak`, `s = |(sx, sy)|`.
- `F = μN·f(s)`, applied along the slip direction as a friction ellipse.
- `f(s) = sin(C·atan(B·s))`, with `C = 1.40` and `B = tan(π/(2C))`. The peak is exactly at s = 1, then f falls gently to about 0.81 when fully sliding, "so a slide is controllable on a keyboard" (lines 3-17).

**Shared tyre values** (Defaults lines 198-213)
- `muX = 1.25`, `muY = 1.22`, `kappaPeak = 0.10`, `alphaPeakDeg = 6.5`, `loadNominal = 4000` N, `loadSensitivity = 0.10`.
- Load scale `k = 1 - 0.10·(N/4000 - 1)`, clamped to 0.72-1.12 (Tire lines 43-48).
- Relaxation lengths: `relaxX = 0.20` m, `relaxY = 0.50` m (tread deflection states `u`/`dw`, Chassis lines 984-1005).
- Per-material grip: `surfaceGrip`, e.g. Grass 0.55, Ice 0.15.

**Slip computation**
- Slip comes from the tread-deflection states advanced every substep (Chassis lines 1357-1391), using rolled distance against contact-patch travel.
- Each wheel's ω comes from the Drivetrain solver, where tyre force is linearised as `Fx = A + B·ω` (lines 1317-1351).
- Total force is capped by the friction ellipse `(Fx/limX)² + (Fy/limY)² ≤ 1` (lines 1367-1374). Wheelspin (large κ) therefore uses up lateral grip on that tyre.

**Weight transfer**
- Not scripted; it emerges from the geometry. The car is a 4-corner spring/damper spherecast model (Chassis lines 876-954).
- Tyre forces are applied at the contact patches: `Tsum += (contact - com) × f` (lines 1396-1409). Squat, dive, roll and per-wheel `N` therefore come out of the physics.
- Anti-roll bars: `arbRollFront`/`arbRollRear` in N·m/rad (lines 931-939).
- Springs are sized by natural frequency: `frequencyFront = 2.0` Hz and `frequencyRear = 1.85` Hz (Weihe). Damping ratios are `dampingBump = 0.35` and `dampingRebound = 0.6`, digressive above 0.15 m/s (Suspension lines 8-30; Defaults lines 229-240).
- Load sensitivity then turns load transfer into a grip balance shift.

**How oversteer and spins arise**
- Physically: driven rear wheelspin plus the friction ellipse plus a forward load shift reduce rear lateral grip.
- On top of that sit explicit arcade layers, mostly catches:
  - **Low-speed layer** (Defaults lines 300-326; Chassis lines 496-548 and 1495-1514).
    - "Straight hold": throttle 0.25-0.7 with the wheel centred and rear spin between 0.1 and 0.4 slip ratio. The yaw is damped to the steering path (`straightYawDamp = 8` /s) and sideways slip is bled off (`straightSlipDamp = 5` /s). It is full below 35 km/h and gone by 60.
    - "Donut": steer 0.2-0.75, throttle 0.5-0.9, rear slip ratio 0.9-2.0, below 20-40 km/h, mostly-RWD cars only. Yaw is driven toward `donutYawDeg = 170` °/s with `donutYawGain = 4` /s, and the rears lose up to `donutRearGrip = 0.3` of their grip.
    - This is the closest existing analogue to "aggressive steer plus throttle at low speed spins the car". It is opt-in through real rear wheelspin.
  - **Handbrake drift latch** (Defaults lines 339-415): the nose angle is capped at `maxDeg = 45`, and the latch lets go past `spunDeg = 110`.
- Corner power assist (`cornerAssist`, floor 0.2 of torque at full steer between 28 and 65 km/h) prevents low-speed understeer under throttle (Chassis lines 1279-1297).

**Stability and traction assists, and their strength**
- **`stability`** (RWD and most cars): `{ fromKmh = 20, slipStartDeg = 8, slipFullDeg = 22, yawDamp = 140, slipDamp = 45, escTrimNm = 900 }` (SHOWDOWN.Tune line 91).
  - It acts only while the rear axle slides beyond `slipStartDeg`.
  - It damps yaw toward the velocity vector's own turn rate, bleeds body slip (capped at `slipCapG = 1` g), and trims torque (Chassis lines 808-820, 1267-1272, 1465-1494).
  - Weihe has none.
- **`traction` hook** (Defaults lines 463-470): an integrating torque trim on driven-wheel slip over `hookSlip = 0.08`. It cuts at `hookCut = 0.6`/s per m/s over target, with a floor of 0.3, and releases at 4.0/s (Chassis lines 1206-1257).
- **ABS:** `absSlip = 0.12`. **TC** is off by default: `tcSlip = 0.2`, `want = clamp(1 - 0.3·(excess - target), 0.4, 1)`.
- **Launch control** holds 12% slip or `launchHoldRpm`.
- Torque trims are smoothed into `eng.torqueScale` (cut tau 0.03 s, release tau 0.05 s).

**Speed-sensitive steering range** (`Sim.Steering` lines 44-66)
- `range = min(maxLock, gripMargin + atan(L · gripAccel · gripScale / v²))`, with `gripAccel = 11.5` m/s² and `gripMarginDeg = 1.5`. Full input at speed therefore asks for about a 1.1-1.2 g path.
- Rack rate limit `rateDeg = 250` °/s, Ackermann 0.6-0.7, wheel ratio 13-15.5:1.

**Counter-steer help**
- `counterSteer = 0.85` × front-axle travel angle, capped at 30°. It fades in over 4-8 m/s, and only when rear-axle travel is between 6.5° (`slideStartDeg`) and 12° (`slideFullDeg`) (Defaults lines 243-252).
- The low-speed donut layer removes it: `counterSteer·(1-lsDonut)`, Chassis line 872.
- Pilot's hands also catch yaw when off-centre at speed (`steerCatch = 0.4`, max 0.25, 50-100 km/h, lines 88-90 and 1593-1601).

**"Agility": one arcade dial at speed** (Defaults lines 267-292; Chassis lines 781-798 and 1431-1464)
- `agility = 1` is the default. The comment says "0 = the real car".
- From 72 km/h, full by 160 km/h, it adds:
  - extra downforce of `0.65 × weight` (40% of it on the front),
  - a bigger steering range,
  - a stiffer tyre (`alphaPeak` drops to 4.5°, relaxation lengths shrink 50%),
  - yaw damping `agilityYawDamp = 250` /s when hands are off,
  - slip damping 80 /s.
- **This is the main "arcade" knob.** Lowering it is how DRIVE moves toward a real car.

## 4. How forces reach Roblox physics

- **Wheels:** four spherecast "wheels" from above full bump, cast downward over bump + droop + 0.17 m margin. The collision group `RacerCast` ignores traffic (Chassis lines 876-904; Vehicle lines 113-118 and 157-163).
- **Force application:** all forces and torques are summed in SI and applied as one `VectorForce.Force` plus one `Torque.Torque` on the Root (`io.apply`, Vehicle lines 164-168; Chassis lines 1596-1632).
  - Conversion: `toF = 1/(kgPerRmu·MPS)`, `toT = 1/(kgPerRmu·MPS²)`.
  - There are no wheel constraints and no direct velocity writes, except contact softening after collisions (Vehicle `postStep` lines 338-370).
- **Gravity feel:**
  - Tyres and springs work at 1 g = 40 studs/s² (`Units.G_STUDS`).
  - Roblox's `workspace.Gravity` is about 5 g at this scale, so a lift force `mass·(workspace.Gravity - gFeel)` cancels the excess.
  - In the air, gravity ramps to `airGravity = 1.5` g over 0.15 s (lines 1598-1625).
- **Mass:**
  - `root.AssemblyMass` converts to kg through `hp.MASS_KG / hp.RootMassRMU` (Chassis line 127). Weihe is 1550 kg; the roster spans 1050-2083 kg.
  - Per-corner effective tyre mass is `w.mass = clamp((N - aero)/G, 0.3, 2.5 × static)` (line 1010).
  - The rotational state is `wheelInertia` 1.2-1.45 kg·m², `engineInertia` 0.16-0.22 kg·m², and `inputInertia = 0.025` kg·m².
- **Yaw inertia for the assists:** the arcade yaw terms compute `iYaw = massKg/12 · (RootSize.X² + RootSize.Z²)` and use an implicit, overshoot-free form: `Tsum += up · (-iYaw · (r1 - target) · k / (1 + k·dt))`, where `r1` is the predicted end-of-frame yaw rate (lines 1451-1462).
- **Step rate:**
  - Frame `dt` is clamped to 1/400 … 1/20 s.
  - Drivetrain and tyres substep at `substepHz = 720`, with at most 36 substeps (Defaults lines 473-476; Chassis lines 1311-1316).
  - Suspension is substepped the same way per corner (lines 905-930).

## 5. What makes DRIVE feel heavy and real (techniques with typical values)

1. **Rpm is a real integrated shaft** (inertia 0.16-0.22 kg·m²) coupled through clutch slip, so revs flare, sag, and get dragged by the wheels rather than being computed from speed.
2. **Torque cut on shifts** (33 ms) plus a 0.25 s clutch slip phase: there is a visible and audible momentary drive gap on every shift, and a 0.38-0.48 s gap through the H-gate.
3. **Real ratio steps** (1st→2nd at ×0.62, rising toward ×0.75-0.79 higher up), so each upshift drops the revs and torque at the wheels.
4. **Engine braking from three losses** (Coulomb 16-24 N·m, viscous 0.06, pumping 18-30 N·m), multiplied by the gear ratio, plus the fuel cut. Lifting in 2nd decelerates much harder than in 6th.
5. **Throttle lag:** limb travel `throttleIn = 0.12` s / `throttleOut = 0.07` s, intake `tau 0.035-0.045` s, turbo spool rate 3.4 /s.
6. **Load transfer emerges from contact-point forces and springs** at 1.85-2.0 Hz with ζ 0.35/0.6. The body visibly squats, dives and rolls, and load sensitivity (0.10) turns that into grip shift.
7. **Tyre relaxation lengths** of 0.2 m longitudinal and 0.5 m lateral delay grip build-up, so turn-in has a short lag.
8. **A friction ellipse with about 0.81 sliding grip**, so slides are lossy but catchable.
9. **Aero drag** `0.5·ρ·cdA·v²` (cdA 0.74-1.02 m²) and modest real downforce (130-1000 N at 200 km/h) (`Sim.Aero`).
10. **Speed-sensitive steering** capped near 1.1 g plus a 250 °/s rack-rate limit, so a keyboard can't over-rotate the car at speed.
11. **Rolling resistance** 0.012·N·r per wheel, and `wheelDrag = 0.12` N·m per rad/s.
12. **The arcade layers are explicit and dialled**, including `agility` (default 1; "0 = the real car"). The arcade feel comes from these, not from the base physics.

## 6. Ideas that transfer to a hover car with no wheels (an inspiration list, not code)

- **Virtual drive shaft.** Treat forward speed as a virtual wheel: `wheelRate = vFwd / virtualRadius`. Keep a separately integrated engine rpm with inertia, coupled to `wheelRate · gearRatio · finalDrive` through a clutch-like slip limit. Rpm can then flare above road speed (launch, low-speed wheelspin) and be dragged down by the road (lugging, engine braking).
- **Data-driven torque curve per car:** a `{rpm, N·m}` table plus idle, redline and limiter, with a bouncing hard-cut limiter (on at least 22 ms, cut 40-65 ms, 150 rpm hysteresis). Map PR98's Piercer/Bruiser, Exotic and Muscle categories to curve shapes. INFERRED example: Muscle gets a fat low end and an early redline; Exotic is peaky with a high redline; Piercer is a mid plateau.
- **Thrust is torque at the virtual wheel:** `thrust = engineTorque · ratio · finalDrive · efficiency / virtualRadius`, capped by a longitudinal grip limit `μx · m · g`. Gearing then changes acceleration per gear for free, and top speed comes from the drag/power balance rather than a speed cap.
- **A ProAuto-style shift brain as a separate pure module:** throttle-dependent upshift points (flat about redline − 200, part throttle 55-85% of redline, cruise 35-40%), heel-toe downshift on braking when the next gear lands at or below about 90% of redline, kickdown on floor, minimum 0.35 s between shifts, and publication of `upshiftRpm` and `shiftPending` for the HUD shift light. A 30-50 ms torque cut plus a 0.1-0.25 s slip/blend is the most important part of the "real shift" feel. Sci-fi option: the electric single-gear path as a variant (flat torque to base rpm, then constant power, a soft limiter and regen) for any "pure electric" class.
- **Gear-dependent engine braking:** apply the closed-throttle loss torque (friction + pumping) through the current ratio as decel thrust. This gives real "weight" on lift.
- **Virtual rear-axle grip that saturates (for spins):**
  - Model two virtual axles, front and rear, each with a lateral slip angle from the local velocity at that axle (DRIVE computes `frontTravel` and `rearTravel` exactly this way, Chassis lines 800-807).
  - Use a saturating force curve, e.g. `sin(1.4·atan(B·s))`, with a friction ellipse on the rear axle shared with longitudinal "drive slip".
  - At low speed, heavy throttle in a low gear drives virtual rear slip κ above peak. The ellipse then takes away rear lateral grip and the yaw runs away: a spin.
  - DRIVE's donut thresholds are a good reference band: steer > 0.2-0.75, throttle > 0.5-0.9, below 20-40 km/h, rear slip ratio 0.9-2.0.
- **Load transfer without wheels:** compute a virtual longitudinal and lateral load shift from measured acceleration × CoM height / wheelbase or track, and feed it into the axles' grip with load sensitivity (about 0.1). Braking or lifting while turning then loosens the rear (lift-off oversteer), and throttle on exit plants it.
- **Grip relaxation lag:** low-pass the lateral force toward its target with a time constant of roughly `relaxLength / speed` (0.5 m in DRIVE) for a turn-in delay that reads as mass.
- **Speed-sensitive steering range** `min(maxLock, margin + atan(L·aLat/v²))` with `aLat` around 11.5 m/s², plus a rack-rate limit of about 250 °/s.
- **Counter-steer assist as a dial:** DRIVE uses 0.85, active from 6.5-12° of rear slide. PR98 would want it weaker, or only above a speed, so low-speed spins can actually happen. It could be a per-category value (INFERRED).
- **Treat the arcade helpers as explicit, named, fading layers**, like `agility`, `lowSpeed`, `stability` and `cornerAssist`, each with its own smoothstep speed band. "Less arcadey" then becomes turning dials down rather than rewriting physics.
- **Use DRIVE's implicit damping form for any yaw or slip helper:** `k/(1 + k·dt)` applied to the predicted end-of-frame rate, so the helpers stay stable at 20-144 fps.
- **Sim-to-presentation interface:** a CarState-like struct (`rpm`, `rpmNorm`, `gear`, `gateTarget`, `shifting`, `shiftProgress`, `limiter`, `engineLoad`, `boost`, `throttle`, `slipRatio`/`slipAngle` per axle) plus discrete events (`Shift`, `GateMove`, `LimiterHit`, `Pop`/`Bang`, `BOV`, `Launch`). HUD gear/rpm/shift-light, engine audio pitch and load crossfades, and FX all read this one source.
- **Feel targets:** two derived numbers per car, a 0-100 time and a lift-off yaw-rate change in a 150 km/h corner. DRIVE tunes these with offline harnesses (`ServerStorage.Dev.Racer.Input.Harness`) and keeps per-car `Targets` modules. The ARCLIGHT tune comments cite a roster limit of 12% on lift-off yaw change.

## Where a change would hook in

**On the DRIVE side** (inspiration only; do not copy code):
- The structure worth mirroring is: pure modules Engine / Drivetrain / Tire / Steering / Pilot → one Chassis `step(dt, controls, settings)` → `io.apply(force, torque)` → a state struct plus an event queue.
- Their seams:
  - `Engine:frame` (once per frame) and `Engine:torque(ω)` (every substep).
  - `Drivetrain:frame` (lever/clutch) and `Drivetrain:substep`.
  - `Pilot:step` writes `controls.{throttle, brake, clutchPedal, steer, shiftRequest, quickShift, upshiftRpm, shiftPending, gasIntent}`.
  - Chassis writes the `st.*` fields (lines 1660-1709) and fires events (lines 1712-1715).

**On the PR98 side** (INFERRED; not read in this task):
- The hover-car controller is the hook point. It probably sits in a client driving script; `scripts/cam02/DrivingClient.after.lua` in the repo has many gear/rpm/force matches. This needs confirming by the PR98 research pass.
- Changes would hook in at these points, all INFERRED:
  - (a) Insert a virtual drivetrain step (rpm state, gear, shift brain) between input and thrust computation.
  - (b) Replace any direct speed-to-thrust mapping with torque-curve thrust through the gear ratio.
  - (c) Add a virtual front/rear lateral grip model with a friction ellipse ahead of the existing stabiliser force/torque, and reduce stabiliser yaw damping at low speed.
  - (d) Publish `rpm`, `gear`, `shifting`, `upshiftRpm` and limiter state for the HUD and for the engine audio (pitch from rpm, load from throttle/torque, shift and limiter events for the grungy sci-fi one-shots).
  - (e) Network-replicate gear and rpm if other players' cars should sound right. DRIVE sends state through `Net.StateCodec` / `Net.RemoteState`, which were not read in this task.