1. **MAJOR. `physics/after/DrivingClient.lua` 1256–1257, 1265 and 1283–1285 (`drivetrainYaw`): spins don't work, and FeelWeight silently turns them off.**
   - **Why it's wrong.**
     - The spin push makes |r| larger than |r_cmd|. That trips the unwind test on line 1257, so the spring pulls back at `YawUnwindScale` × ω during every spin.
     - ω is also divided by FeelWeight.
     - The steady extra yaw from the spin is push/ω². With L = 1:
       - S car, W = 1: ω = 11.7 × 2 × 0.15 = 3.5, giving about 0.57 rad/s of extra yaw.
       - W = 0: ω ≥ 35, giving about 0.006 rad/s.
       - W = 2.5: about 3.5 rad/s.
     - So spin strength scales with about W², and FeelWeight 0 removes spins entirely. FeelSpin is supposed to be an independent dial (CONTRACT 4.1, and the user's tunability request).
     - `model/RESULTS.md` (generated numbers) emulates this code: with the contract defaults, C–S gestures reach only 13–22° of slip, where 75° counts as a spin. That fails the CONTRACT 9 targets "stab and power-brake spin on C to S cars" and "power-brake can spin an E car".
   - **Fix.** Split the yaw into two additive states, `r = r_steer + r_spin`.
     - `r_steer` is the current spring toward `r_cmd`: ω/W, unwind, kinematic blend, authority.
     - Integrate `r_spin` in the same sub-steps: `r_spin += (pushActive and push or 0) * h - k_s * r_spin * h`, where:
       - `pushActive` = `(r_steer + r_spin) * spin.Dir > 0 and |r| < SpinMaxYawRate`;
       - `k_s = math.max(profile.YawOmega * (1 - tuning.SpinYawAuthorityLoss * spin.L), 1) / (2 * tuning.YawDamping)`. Do not divide by FeelWeight, and do not apply the unwind scale.
       - While L is falling after a catch, `k_s >= 3 / SpinSettleSeconds`.
     - Apply the kinematic blend to `r_steer` only. Clamp the sum to `YawRateMax`.
     - Minimum alternative: skip line 1257 while `spin.L >= 0.1`, and use `profile.YawOmega` without the `/weight` while `spin.L > 0`.

2. **MAJOR. `physics/after/DrivingClient.lua` 1130–1139 (stab gesture): any press of W while the wheel is held counts as a stab.**
   - **Why it's wrong.**
     - `Armed` is set whenever throttle < 0.3, which includes sitting still. On keyboard, holding A or D, pressing W and being under 25 mph therefore opens a full `SpinWindowSeconds` window and lifts `SpinHoldCap`.
     - Every junction pull-out and U-turn becomes a "gesture". This is the case critique 2 (a BLOCKER) exists to prevent.
     - The model emulation shows that once spins work (issue 1, or the proposed values), pull-outs slide up to 66°. That fails CONTRACT 9 "U-turn at 0 and 15 mph without a spin".
   - **Fix (lift-and-stab).**
     - Track `spin.WasOn` (throttle ≥ 0.3 seen).
     - Arm only on the transition from ≥ 0.3 to < 0.3: `if forwardThrottle < 0.3 then if spin.WasOn then spin.Armed, spin.RiseClock = true, 0 end; spin.WasOn = false else spin.WasOn = true ... end`.
     - Measure `RiseClock` from that lift, and keep the `SpinStabSeconds` limit.
     - Keep the `SpinAnalogRate` rule for analog throttle.
     - Ship this together with fix 1. The contract text allows the literal reading, so the integrator should note this decision.

3. **MAJOR. Drift parity fails CONTRACT 5.3 ("drift radius, yaw and exit speed within ±10%").** The causes, by location:
   - **`physics/after/DrivingClient.lua` 1283–1285.** The yaw spring stays fully active in drifts. The ×1.6–2.2 drift turn multiplier then arrives through a lagging spring.
   - **`physics/after/DrivingClient.lua` 1196 and 1249.** The exemption lerps on the raw `DriftBlend`, which ramps at 5.2/s, so drift entry runs into the 3.4 g cap.
   - **`physics/after/VehicleDynamics.lua` 791.** The gear hold makes the car bog in a high gear.
   - **`physics/after/DrivingClient.lua` 1810.** Gross `DriveThrust` in a high gear is about half of today's net plateau.
   - **Measured effect.** The model's emulation gives radius +16 to +35% and exit speed −18 to −42% (generated).
   - **Fix.**
     - Let `w = math.clamp(state.DriftBlend * 2, 0, 1)` when `DriftCapExempt`. Use `w` for the lateral lerp (line 1196) and the yaw-cap lerp (line 1249).
     - Add `dynamic *= (1 - w)` before line 1285, so the drift owns yaw as it owns grip.
     - **Integrator decision, since these change contract fixes 3 and 7:**
       - Allow one downshift inside the drift hold when `|v_h|` lands at or below `DownshiftBrakeLand`.
       - Compute the drift assist from `DriveThrust + (A1*thr - DriveThrust)*0.9`.

4. **MAJOR. `physics/after/VehicleDynamics.lua` 570–578, 584, 590 and 849–857: FeelGearing changes the car's pace, not just how the gears feel.**
   - **Why it's wrong.**
     - `Mult[g] = (r_g/r_1)^(GearTorqueExponent*Gr)`. At Gr 0, every gear gets first-gear thrust A1: 71 against a top-gear 21.5 studs/s² on S. The car is then traction-limited (about 1.5 g) almost all the way to Vt. Gr 2 roughly halves mid-gear thrust.
     - At Gr 0, raw thrust exceeds traction in every gear (S: 71 > ~54), so ws_eff is about 0.2 at full throttle at any speed. That causes:
       - permanent rpm flare to `LimiterRpm`;
       - `FeelThrustSlip` about 0.4, so the VFX over-glows at 170 mph;
       - the spin slip gate passing on any W plus lock;
       - a top speed below Vt, because Kd at line 584 ignores the slide factor.
     - A feel dial should not change 0–100 by a factor of 2 (user request; CONTRACT 4.1 "0 reproduces today's feel for that aspect").
   - **Fix.**
     - Build `MultBase[g]` with `GearTorqueExponent` only.
     - Each frame use `mult = env + (MultBase[g] - env) * Gr`, where `env` is `MultBase` linearly interpolated over speed between gear mid-band speeds (precompute the mid speeds in the profile). Gr then scales only the step around a fixed envelope.
     - Derive Kd (line 584) and the BoostShare engine term (line 590) from `MultBase[count]` with the same slide factor the step uses: `min(raw,trac)*(1-(1-SlideGripFraction)*smoothstep(s/0.6))`, where `s = max(raw/trac-1,0)*(1-TractionAssist)`.

5. **MAJOR. `physics/after/DrivingClient.lua` 1206 and 1066, called at 394, 1405 and 2117 (spin start grace): the deliberate spin-outs can't be tried after spawning or resetting.**
   - **Why it's wrong.**
     - Every Start, R reset, gate lock, unanchor and `DriveReady` restart requires both 3 s and more than 38 mph before any spin.
     - So a power-brake donut after spawning or pressing R is impossible until the player has driven at 38 mph. R is also the natural way out of a spin.
     - The mph clause exists only for race and duel starts, which the user put out of scope. Oscar's first test (spawn, then power-brake) will look broken.
   - **Fix.** Add a flag `spin.GraceNeedsSpeed`:
     - set it to true only in `drivetrainResume`'s WasAnchored branch and on the DriveReady false→true edge;
     - set it to false in `resetDrivetrainChassis` for every other caller;
     - change line 1206 to `... and (tuning.SpinStartGraceMph <= 0 or not spin.GraceNeedsSpeed or spin.GraceSpeedReached)`.

6. **MINOR. `physics/after/DrivingClient.lua` 1269 (with 1256–1257): the yaw spring goes unstable at low FeelWeight during frame hitches.**
   - **Why it's wrong.** The sub-step cap of 16 lets ω·h exceed the semi-implicit Euler stability limit, which is about 1 at ζ 0.75 and about 0.47 at the allowed ζ 2. Example: W = 0.1 while unwinding gives ω = 234; at dt 0.1, ω·h = 1.46, so the yaw rate oscillates between the ±5 clamps.
   - **Fix.** Use `omega = math.min(math.max(omega * chassis.Authority, 1), 60)`; it is effectively kinematic above that.

7. **MINOR. `physics/after/DrivingClient.lua` 2005: run-on depends on frame rate.**
   - **Why it's wrong.** `YawHeading` is integrated with the end-of-frame rate × dt, so run-on is roughly halved at 20 Hz (model finding 5).
   - **Fix.** Accumulate `sum += rate*h` inside the sub-step loop. Return `command + (sum/step - command)*dynamic` as the frame-average rate (step > 0).

8. **MINOR. `physics/after/DrivingClient.lua` 394–395: the input flags go stale while the gate is locked.**
   - **Why it's wrong.** The locked branch returns before updating `PowerBrakeInput`, `AnalogThrottle` and `TouchInput`. If W+S were held when the gate locked, `drivetrainGestures` keeps `PowerBrakeHeld` true every locked frame at a standstill. The engine then revs to launch rpm with `FeelLoad` 1 throughout the lock.
   - **Fix.** Add `Drivetrain.PowerBrakeInput, Drivetrain.AnalogThrottle, Drivetrain.TouchInput = false, false, false` before `return 0, 0, 0`.

9. **MINOR. `physics/after/DrivingClient.lua` 394 (with `resetDrivetrainChassis` from `drivetrainResume`): the full reset runs on every locked frame, even while moving.**
   - **Why it's wrong.** The lateral filter restarts from 0 each frame, so only about 56% of lateral grip applies at 100 studs/s. Pitch also snaps to 0 for the whole lock.
   - **Fix.** Reset on the lock edge only: `if Drivetrain.Active and not Drivetrain.GateLocked then Drivetrain.ResetPending = true end; Drivetrain.GateLocked = true`. Clear `GateLocked` on the unlocked path.

10. **MINOR. `physics/after/VehicleDynamics.lua` 833: Overdrive drops out while the car is still above top-gear redline.**
    - **Why it's wrong.** Overdrive ends the frame boost or mini-boost stops, even though the car is still over top-gear redline. With W held, the limiter then bounces (ShiftLight 3, FeelCut, audio tremolo, about 60% thrust cut) for roughly 1.5–3 s on S after every top-speed boost. Critique 6 wanted this avoided.
    - **Fix.** `local overdrive = tuning.OverdriveEnabled and gear == count and (drive.BoostApplied == true or box.Overdrive) and ratio >= (box.Overdrive and 0.98 or 1)`. This is a deviation from "while boost thrust is applied", so record it in NOTES.

11. **MINOR. `physics/after/VehicleDynamics.lua` 320, with 861: `TopGearOverspeed` minimum 1 parks the car on the limiter at top speed.**
    - **Why it's wrong.** At 1.0, `rpmRoad >= redline` at Vt, so the limiter bounces permanently and the top speed ends 1–2% below Vt. The config text even advertises "1 = top speed exactly at redline".
    - **Fix.** Raise the minimum to 1.02 in `DRIVETRAIN_NUMBERS`, and update the `_RaisingThisDoes` text.

12. **MINOR. `physics/after/DrivingClient.lua` 1107: every unanchor fires a Launch event.**
    - **Why it's wrong.** Teleports with throttle 0 also emit `LaunchGearbox`, which bumps `FeelShiftRevision` and `GearRevision` with strength 0. The HUD gear punch and the audio and camera shift handlers fire on every teleport.
    - **Fix.** `if throttle > 0.05 then LaunchGearbox(...) else VehicleDynamicsModel.ResetGearbox(box, tuning, Drivetrain.Profile, forwardMph, false) end`.

13. **MINOR. `physics/after/DrivingClient.lua` 417–418: FeelWeight 0 is not exactly today's steering.**
    - **Why it's wrong.** `approachSteer` snaps to 0 on a direct A→D reversal, then builds on the next frame. That adds a 1-frame delay against today.
    - **Fix.** When `tuning.FeelWeight <= 0`, set `Drivetrain.SteerKeyboard, Drivetrain.SteerTouch = steer, mobileSteer` and skip `approachSteer`.

What checked clean:
- **Compile check (re-run):** `DrivingClient` OK 101808, `VehicleDynamics` OK 69632.
- **Inactive path:** every new branch is guarded, and a heuristic scan found no undeclared globals.
- **Interfaces:** the 16 Feel names and 6 telemetry fields match CONTRACT 3. The `GearForSpeed` signature matches.
- **Config:** every CONTRACT 4 attribute is in `physics/config.py` with a `_RaisingThisDoes` string, the defaults equal the code fallbacks, and the switches are numbers.
- **Live re-read:** happens at about 4 Hz with no per-frame `GetAttributes`.

Verdict: READY WITH FIXES (1–5 before APPLY with `exotic@Enabled` 1; 6–13 can follow).