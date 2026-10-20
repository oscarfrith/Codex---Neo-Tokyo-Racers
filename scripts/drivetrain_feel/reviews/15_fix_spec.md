# 15. Physics and model fix pass: spec (integrator, 2026-10-20)

This spec is the authority for the physics fix pass. It amends CONTRACT.md where it says so; everything else in
CONTRACT.md still holds. Inputs: `reviews/13_physics_review.md` (R13), `reviews/14_model_review.md` (R14),
`reviews/10_model_build.md`, `model/RESULTS.md`.

Rules for agents: CONTRACT section 2 still applies (no Studio writes, no git, own folder only; the compile check
through the 8797 bridge is allowed and the bridge is running). Physics owns `physics/`; model owns `model/`.
Both implement the **same** mechanisms below, so name every new attribute exactly as written here.

## A. Decisions (integrator; recorded for Oscar)

| # | Decision | Default chosen | Why |
|---|---|---|---|
| F1 | Spin yaw | Additive state `r = r_steer + r_spin` (R13 #1, full fix, not the minimal one) | FeelSpin must not depend on FeelWeight |
| F2 | What counts as a stab | **Lift, then steer-flick and stab together.** Keyboard "lift-and-stab with a held wheel" is no longer a stab | On keyboard a lifted U-turn and a lift-and-stab are the same input (R14 #1). Requiring a flick of the wheel at the moment of the stab separates them. `SpinStabNeedsFlick` 0 restores the plain lift-and-stab |
| F3 | Stab slip | A stab dumps `SpinStabDumpSlip` into the spin slip, like the power-brake | Gestures spin without lowering `SpinSlipStart` so far that every hold slides |
| F4 | Start grace | Speed clause only after an anchored start or a DriveReady restart (R13 #5) | Spawn or R, then power-brake must work |
| F5 | Drift parity | Exemption weight `w = clamp(DriftBlend * DriftExemptGain, 0, 1)`; yaw spring exempt by `w * DriftYawExempt`; one downshift at a time inside the drift hold; drift assist from `DriftAssistPlateauShare` | R13 #3, R14 #2/#3. Deviates from contract fixes 3 and 7; recorded |
| F6 | FeelGearing | Steps around a fixed thrust envelope (R13 #4); Kd and boost share from delivered thrust | A feel dial must not change pace |
| F7 | FeelSpin above 1 | Hold cap scales: `holdCap = min(SpinHoldCap * FeelSpin, 1)` | R14 #7: the upper half of the dial did nothing. At FeelSpin > 1 holds may spin; that is what the dial is for |
| F8 | Keyboard cruise | Digital-input cruise upshift (section C9) | R14 #8: tapping W at 40 mph droned at 0.9 of redline |
| F9 | Overdrive exit | Hold Overdrive while still above top-gear redline (R13 #10) | Avoids a limiter bounce after every top-speed boost |

## B. New attributes on `Drivetrain.exotic`

Each needs a `_RaisingThisDoes` string in `physics/config.py`, a matching code fallback, an entry in the NOTES
mapping table and a model mirror. Switches are numbers 0/1.

| Attribute | Default (model may retune) | Meaning |
|---|---|---|
| `SpinStabNeedsFlick` | 1 | switch: a stab also needs a steering flick within `SpinFlickSeconds` of the throttle stab |
| `SpinFlickSeconds` | 0.15 | how close together (either order) the flick and the stab must be |
| `SpinStabDumpSlip` | 0.3 | extra thrust slip dumped on a stab, decaying over the window like `PowerBrakeDumpSlip` |
| `DriftExemptGain` | 2 | exemption weight gain on DriftBlend (replaces reading `DriftCapExempt` as a gain; `DriftCapExempt` stays a 0/1 switch) |
| `DriftYawExempt` | 1 | 0..1: share of the drift exemption applied to the yaw spring (1 = drift yaw is today's; lower gives drifts some weight) |
| `DriftHoldDownshift` | 1 | switch: inside the drift gear hold, allow one downshift at a time when the lower gear lands at or below `DownshiftBrakeLand` |
| `DriftAssistPlateauShare` | 0.9 | drift engine assist reads `DriveThrust + (A1 * thr - DriveThrust) * share` |
| `DigitalCruiseEnabled` | 1 | switch: the keyboard/touch cruise upshift (C9) |
| `DigitalDutySeconds` | 1.5 | time constant of the throttle duty and steady-speed averages |
| `DigitalCruiseDutyMax` | 0.7 | duty at or below which digital input counts as cruising |
| `DigitalCruiseSteadyMph` | 3 | how far speed may stray from its average and still count as steady |
| `DigitalCruiseUpshift` | 0.6 | rpm fraction above which a cruising car short-shifts |
| `DigitalCruiseLand` | 0.5 | a cruise upshift must land at or above this fraction (keeps it above `KickdownBelowFraction`) |

`TopGearOverspeed` minimum becomes 1.02 (R13 #11).

## C. Mechanisms (both physics and model)

1. **Spin yaw (F1, R13 #1).** `r_steer` is the existing spring toward `r_cmd` (ω / FeelWeight, unwind scale,
   authority, kinematic blend, drift exemption). `r_spin` integrates in the same sub-steps:
   `r_spin += (pushActive and push or 0) * h - k_s * r_spin * h`, with
   `pushActive = (r_steer + r_spin) * Dir > 0 and |r_steer + r_spin| < min(SpinMaxYawRate, YawRateMax)`,
   `push = Dir * SpinYawAccel * FeelSpin * L * (0.6 + 0.4 * min(slip / 0.5, 1))`,
   `k_s = max(profile.YawOmega * (1 - SpinYawAuthorityLoss * L), 1) / (2 * YawDamping)` (no FeelWeight, no unwind
   scale); while L is falling after a catch, `k_s >= 3 / SpinSettleSeconds`. The kinematic blend applies to
   `r_steer` only; drop the `dynamic = max(dynamic, SpinBlend)` line. Clamp the sum to `YawRateMax`. Reset
   `r_spin` everywhere `YawRate` is reset.
2. **Stab (F2, F3, R13 #2).** Arm on the transition from throttle >= 0.3 to < 0.3 only (`spin.WasOn`). Throttle
   event: keyboard/touch, throttle back to >= 0.9 within `SpinStabSeconds` of that lift; analog, the rise from
   below 0.3 to >= 0.9 is faster than `SpinAnalogRate`/s **and** started from an armed lift. Flick event:
   |raw steer| rises from < 0.5 to >= `SpinStabSteer`, or the raw steer reverses sign while |raw steer| >=
   `SpinStabSteer`. Keep two clocks (time since each event, large when none). The stab fires when both clocks are
   <= `SpinFlickSeconds`, throttle >= 0.9, |raw steer| >= `SpinStabSteer` and speed < `SpinBelowMph`; then both
   clocks reset to large. With `SpinStabNeedsFlick` 0 the flick clock is ignored (plain lift-and-stab). On fire:
   open the window and set `DumpSlip = max(DumpSlip, SpinStabDumpSlip)`, `DumpClock = 0`. Power-brake unchanged.
3. **Grace (F4, R13 #5).** `spin.GraceNeedsSpeed`: true only in the `WasAnchored` resume branch and on the
   DriveReady false-to-true edge; false for every other reset. Grace over when
   `GraceClock >= SpinStartGraceSeconds and (SpinStartGraceMph <= 0 or not GraceNeedsSpeed or GraceSpeedReached)`.
4. **Hold cap and warning (F7, R14 #14).** `holdCap = min(SpinHoldCap * FeelSpin, 1)` outside a window.
   `Warn = L > max(SpinWarnLevel, holdCap + 0.05) and rising`.
5. **Drift (F5, R13 #3).** `w = DriftCapExempt and clamp(DriftBlend * DriftExemptGain, 0, 1) or 0`. Use `w` for the
   lateral lerp and the yaw-cap lerp (keep the `(1 + 1.5 * DriftBlend)` cap relaxation and divide by forward
   speed). `dynamic *= 1 - w * DriftYawExempt` before the kinematic blend of `r_steer`. Drift hold: upshifts stay
   blocked (except on the limiter); with `DriftHoldDownshift` 1 one downshift is allowed when the lower gear's rpm
   from |v_h| lands at or below `DownshiftBrakeLand`, obeying `ShiftMinIntervalSeconds`, no cut. Drift assist, only
   while `DriveThrust > 0` (as before): `DriveThrust + (A1 * thr - DriveThrust) * DriftAssistPlateauShare`.
   (Parity audit: the flick latch is cleared at every chassis reset, so a wheel held through a reset is not a flick.)
6. **FeelGearing envelope (F6, R13 #4, R14 #6).** `MultBase[g] = (r_g / r_1) ^ GearTorqueExponent`. Precompute
   gear mid-band speeds; `env(v)` = `MultBase` linearly interpolated over speed between them (clamped at the ends).
   Per frame `mult = env + (MultBase[g] - env) * FeelGearing`. Kd and the BoostShare engine term come from the
   delivered top-gear thrust: `min(raw, trac) * (1 - (1 - SlideGripFraction) * smoothstep(s / 0.6))`,
   `s = max(raw / trac - 1, 0) * (1 - TractionAssist)`. Keep `CurveDepth = min(FeelGearing, 1)` and
   `ShiftRpmSeconds / max(FeelGearing, 0.05)`; the model must match these.
7. **Minor physics fixes R13 #6-#13**, as written there: yaw ω cap 60; heading from the frame-average yaw rate;
   clear input flags on the locked gate path; reset on the lock edge only; Overdrive hysteresis (F9);
   `TopGearOverspeed` min 1.02; launch only when throttle > 0.05; FeelWeight <= 0 bypasses `approachSteer`.
8. **Steer limiter over the frame (R14 #10).** The steer returned by `refreshInput` for the frame is the average of
   the limiter's start and end values for that frame (trapezoid), so run-on does not depend on frame rate.
9. **Digital cruise upshift (F8).** Every frame while active: `Duty += (thr - Duty) * (1 - exp(-dt / DigitalDutySeconds))`
   and `SteadyMph += (fwdMph - SteadyMph) * (same factor)`; both reset with the gearbox (Duty 0, SteadyMph = speed).
   When `DigitalCruiseEnabled` and the input is not analog and gear in 1..count-1 and
   `CruiseThrottleMin < Duty <= DigitalCruiseDutyMax` and `|fwdMph - SteadyMph| <= DigitalCruiseSteadyMph` and
   x >= `DigitalCruiseUpshift` and the landing fraction >= max(`DigitalCruiseLand`, `UpshiftMinLand`) and the
   normal shift guards pass (interval, drift/spin hold): upshift as a normal Up event. `LiftHoldSeconds` does not
   block a cruise upshift. Full-throttle shift points must not change.

## D. Model work (model part)

- Implement section C exactly as physics does; then align every item in R14 #4, #5, #6, #11, #12, #13, #15.
  `DriftCapExempt` stays a 0/1 switch (R14 #2).
- **Scenarios** (all six stock cars plus the as-spawned Seraph, keyboard unless stated):
  - must not spin: hold W + lock 0-25 mph; U-turn 0/15 mph (steer first, W after 0.3 s); **lifted** U-turn and
    hold at 15 mph (on W, steer held, lift 0.15 / 0.3 s, W again); pull-out with A and W pressed together from rest;
    junction turn-in at 20 mph (lift 0.3 s, D, W 0.25 s later); keyboard feathering of W with D held at 15 mph;
    gamepad trigger ramps 0.1 / 0.2 / 0.3 s at 0 and 15 mph with the stick held first; touch power-brake.
  - must spin: flick-stab at 0 (W 0.35 s straight, lift 0.2 s, D and W together), 10 and 20 mph; gamepad
    flick-stab; keyboard power-brake (C to S), E power-brake.
  - drift with a pre-steered entry (steer 0.25 s before the drift) as well as the simultaneous one.
  - tap at 40 mph: shift count **and** mean rpm fraction over the last 5 s.
- **Targets** (all at 60 Hz; run-on, tap, spin and drift also at 30 and 144 Hz): CONTRACT 9 as written, plus:
  every must-not-spin case under 75 deg; every must-spin case over 75 deg on C-S (E power-brake too); drift
  radius within 10% for both entries; tap mean rpm fraction <= 0.65; boost endless top within -3%..+3%;
  run-on on YawHeading <= 5 deg (report the body run-on next to it).
- **Tune**: change as few attributes as possible from CONTRACT section 4 (prefer the new section B ones and the
  spin ones). Write a proposal table, a revert table and the dial table (FeelSpin 0.5 / 1.5 / 2.5 rows for E, C, S;
  FeelWeight 0 corner g and drift). Mark every number generated.

## E. Done means

- physics: after-files implement section C; `config.py` has every section B attribute; NOTES updated (mapping,
  decisions F1-F9 with the contract deviations, test hooks); both files pass the compile check.
- model: every target in D passes on all six cars, or RESULTS says exactly which fails and why; RESULTS lists the
  proposed defaults.
- A parity audit finds no behavioural difference between model and Lua for section C.
