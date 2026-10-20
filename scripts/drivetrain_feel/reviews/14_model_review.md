Compile check: not run. `model/` has no `after/*.lua` files, and Studio was not used. I ran five read-only probe scripts that import the model; they are in the scratchpad and nothing in the repo was changed.

1. **BLOCKER: the spin proposal's "holds and U-turns never spin" claim is false for ordinary input.** Files: `scenarios.py:263`, `scenarios.py:275`, `targets.py:106-107`, `RESULTS.md:44`.
   - **Why:** every hold and U-turn starts with `throttle_was=0.0`, so no lift ever happens before W and no gesture window can open. Gamepad is never tested in a hold.
   - **Probe, proposed settings:**
     - A 15 mph U-turn after being on W, with a 0.15 or 0.3 s lift before pressing W again, spins all six cars (89-125°).
     - A gamepad pull-out from rest with full stick and a 0.1-0.2 s trigger squeeze is an analog stab. It spins D to S (91-104°) and E at 0.2 s (75°).
     - Keyboard feathering of W with D held at 15 mph slides E to B 45-56°.
     - With contract values plus the recommended code, none of these spin (13-17°).
   - **Fix:**
     - Add to `targets.evaluate` hold/uturn: lifted U-turn and hold from 15 mph (lift 0.15 / 0.3 s, `throttle_was=1.0`), gamepad trigger ramps 0.1 / 0.2 / 0.3 s at 0 and 15 mph, and keyboard feathering.
     - On keyboard, "stab spins" and "U-turn doesn't spin" are the same input, so state that conflict in RESULTS as a decision for Oscar.
     - Retune and re-run with these cases, for example SpinAnalogRate around 10, or requiring at least 0.3 s at throttle ≥ 0.9 before the lift.
     - Withdraw `RESULTS.md:44` until they pass.

2. **MAJOR: `DriftCapExempt` 2 is ignored by the physics code.** Files: `sim.py:39`, `vehicle.py:111-113`.
   - **Why:** physics reads it as a 0/1 switch: it is in `DRIVETRAIN_SWITCHES`, and `switchOn(2)` gives true, the same as 1. CONTRACT 4 says switches are 0/1. The model reads it as a gain, so the integrator would apply 2 and get the contract-literal drift.
   - **Fix:** keep `DriftCapExempt` at 1. If a gain is still needed after item 5, propose a new attribute (for example `DriftExemptGain`) as a contract change, not a value of 2 on a switch.

3. **MAJOR: the drift pass depends on the entry scenario and on breaking mandatory fixes.** Files: `RESULTS.md:22`, `sim.py:51`, `vehicle.py:395-397`, `scenarios.py:175-183`.
   - **Why:**
     - `DriftHoldDownshift` contradicts mandatory fix 3 (gear held in a drift).
     - `DriftAssistPlateauShare` 0.9 replaces fix 7 (assist from gross DriveThrust) with a hard-coded, untunable constant.
     - The drift test starts steer and drift on the same frame. Probe with steer applied 0.25 s before the drift: proposed radius is +12 to +15% on E to B, which fails ±10%.
     - In that probe, SteerRiseSeconds 0.2 against 0.12 changes the radius by only about 1%. The case for weakening the steer build-up (a contract weight cue) does not hold up.
   - **Fix:**
     - The headline should say: passes only with code that departs from fixes 3 and 7.
     - Add the pre-steered entry to the drift target.
     - Expose the plateau share as an attribute if it is kept.
     - Re-justify or drop `SteerRiseSeconds` 0.12.

4. **MAJOR: the emulation of the physics after-source is inaccurate, and code findings 4, 6, 7 and 8 are already in that code.** Files: `sim.py:378`, `RESULTS.md:102-149`.
   - **Already present in physics after-source:**
     - the sub-stepped yaw spring (`steps = clamp(ceil(step*omega*4),1,16)`);
     - the FeelWeight-scaled return (`soften`);
     - the peaked lateral curve with B = 1/C;
     - Kd and BoostShare limited by traction (`math.min(..., profile.Traction)`);
     - the spin keeping the yaw state dynamic (`SpinBlend`).
   - **Missing from the emulation:**
     - the yaw cap ×(1+1.5·DriftBlend) on forward speed;
     - `NormalGrip` in the capped lateral share;
     - SpinYawAccel × FeelSpin;
     - the spin push stopping at |rate| ≥ the spin cap;
     - the Authority and SpinBlend settle hysteresis;
     - launch revs during the power-brake hold;
     - the tier bonus scaled by the grip term;
     - the `LUG_FRACTION` downshift;
     - full-throttle upshifts not being held by LiftHold.
   - **Fix:** remove findings 4, 6, 7 and 8 (and the "sub-step / scale return" items in the summary). Either align `PHYSICS_AS_WRITTEN` and `vehicle._yaw` with these, or label the physics table "approximate". Rank the minimal yaw change first: the `literal` table shows that turning off the unwind boost while L ≥ 0.1 already spins at FeelWeight 1. The additive state is only needed so spins don't depend on FeelWeight.

5. **MINOR: the contract's yaw-cap drift relaxation is omitted.** File: `vehicle.py:225-231`.
   - **Why:** the default `"exempt"` mode drops CONTRACT 5.3's ×(1+1.5·DriftBlend). It also divides by total speed rather than forward speed.
   - **Effect (probe):** this overstates the contract drift error by about 5-6 points (E +34% against +29%, B +18% against +12%). The FAIL verdict stands.
   - **Fix:** apply `cap*(1+1.5*db)/fwd`, then the lerp, in contract mode.

6. **MAJOR: the FeelGearing mapping contradicts the contract and physics.** File: `drivetrain.py:109-113,365`.
   - **Why:**
     - The torque curve is not flattened at FeelGearing < 1. Physics uses `CurveDepth=min(fg,1)`. So FeelGearing 0 keeps a saw-tooth of about 12% per upshift and is not "CVT-smooth".
     - `shift_rpm_seconds = ShiftRpmSeconds*fg` scales the rev-drop time with the dial, so the rev-drop speed is inverted (physics uses `ShiftRpmSeconds/max(fg,0.05)`).
   - **Fix:** use `torque = 1+(τ-1)*min(fg,1)` and `shift_rpm_seconds = ShiftRpmSeconds/max(fg,0.05)`, then re-run the dials table.

7. **MAJOR: the upper half of the FeelSpin dial does nothing.** Files: `vehicle.py:197-200,305`, `RESULTS.md:368-369`.
   - **Why:** holds are capped by `SpinHoldCap` whatever FeelSpin is, and gestures already reach L ≈ 1. Probe: S at FeelSpin 2.5 gives hold 16°, stab 101°, power-brake 96°, the same as at 1. The model also leaves out the FeelSpin factor that physics puts on SpinYawAccel. Oscar asked for spin to be easy to tune.
   - **Fix:**
     - Put FeelSpin on SpinYawAccel as physics does.
     - Propose a "readiness" mapping, for example a hold cap of `min(SpinHoldCap×FeelSpin, 1)`, or thresholds scaled by FeelSpin, as critique 4 suggests.
     - Add FeelSpin 0.5 / 1.5 / 2.5 rows for E, C and S, and say in RESULTS that above 1 there is currently no effect.

8. **MAJOR: "0 shifts" in the tap test hides a keyboard cruise near redline.** Files: `drivetrain.py:315-325`, `sim.py:218-224`.
   - **Why:** keyboard and touch throttle is 0 or 1, so the cruise band (0.05-0.3) is never reached. Probe at 40 mph: S stays in 1st at 0.90 of redline, C in 2nd at 0.92, the rest at 0.66-0.78. The engine drones near redline indefinitely.
   - **Fix:** add the mean rpm fraction to the churn table, add a cruise target (for example ≤ 0.65 of redline after 3 s), and raise a decision for Oscar on a digital-input cruise upshift (for example averaged duty-cycle throttle).

9. **MINOR: the run-on target is measured on YawHeading, but Play sees the body.** File: `scenarios.py:153-154`.
   - **Why:** body run-on with the proposal is 5.7-6.5°, above 5°. Today's body run-on is already 2.9-3.1° from the Align lag.
   - **Fix:** define the target as run-on added over today's body run-on, or report the body value next to it, so the Play check isn't misread.

10. **MINOR: run-on depends on frame rate (2.6-4.2° from 20 to 144 Hz), and "within 1-2%" is overstated.** File: `vehicle.py:137-138`.
    - **Why:** `_limit_steer` applies the stepped value for the whole frame, which breaks CONTRACT 5.6. Separately, E stab slip is 90/95/97° across frame rates, so other metrics vary by up to about 7%, not 1-2%.
    - **Fix:** recommend averaging the limited steer over the frame, and correct the frame-rate line in RESULTS.

11. **MINOR: the boost target only has an upper bound.** File: `targets.py:129`.
    - **Fix:** add `>= boost0*0.97`.

12. **MINOR: the brake mapping differs from physics.** File: `drivetrain.py:156`.
    - **Why:** the model uses `max(lerp, 0.2·V2)`. Physics clamps to `[0.35·min(today,V2), max(today,V2)]`, so the FeelWeight 2-2.5 rows differ.
    - **Fix:** use the physics form.

13. **MINOR: the tier traction bonus is not scaled by the grip term.** File: `drivetrain.py:139`.
    - **Why:** physics scales it. S traction is 1.57 g in the model against 1.61 g in physics. SpinSlipStart 0.04 is tuned against launch slip, so this matters.
    - **Fix:** align with physics, or flag the difference.

14. **MINOR: SpinWarnLevel 0.4 only works while it stays above SpinHoldCap 0.35, and that link is undocumented.** File: `sim.py:415`.
    - **Fix:** state the rule `SpinWarnLevel > SpinHoldCap` in the "why" text, or have physics compare against `max(SpinWarnLevel, SpinHoldCap+0.05)`.

15. **MINOR: FeelWeight 0 does not fully reproduce today.** File: `RESULTS.md:53`.
    - **Why:** the lateral cap stays on at FeelWeight 0 (full-lock 60 mph is 2.2-3.8 g against 3.0-4.5 today), and saturating grip is listed under "weight" in CONTRACT 1. Also missing from the decisions list: `DriftYawExempt` makes drift yaw fully kinematic, so drifts carry no weight.
    - **Fix:** report corner g and drift at FeelWeight 0, and add the drift-yaw point to the decisions list.

16. **MINOR: process.** The builder ran `git status`, which breaks the CONTRACT 2 "agents never run git" rule. It was read-only and was disclosed.

NOT READY