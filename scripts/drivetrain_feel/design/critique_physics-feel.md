1. **BLOCKER: the lateral cap breaks drifting.** In §3.4.3 the tanh cap and grip relaxation act on the drift-blended `lateralGrip` with no drift exemption. The only drift allowance is on the yaw cap (×2.5).
   - Evidence: live `03_Drifting` has `BaseDriftLateralGrip` 4, `BaseDriftSideForce` 100 (pushes outward, DrivingClient 1311) and alignment max 25 (1326). The driving_tune corner table (`C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\driving_tune\balance\NOTES.md`) shows S drift radius 78-79 studs at about 120-140 mph. That is 13-18 g, delivered by `side·4` at DrivingClient 1298.
   - With a_cap of about 3.1-4 g, less the 75-90 studs/s² outward side force, the drift radius grows about 3× or more at S and widens at E. The yaw cap also cuts S drift yaw from about 2.7 to 1.7 rad/s. The mini-boost loop collapses.
   - Fix: cap only the normal share, e.g. `a = lerp(cap(a_normal), a_driftUncapped, DriftBlend)`. Alternatively scale a_cap by `(1 + DriftCapExtra·DriftBlend)` with DriftCapExtra of 5 or more. Add the driving_tune corner table (radius, yaw, exit speed) to the Phase 0 parity checks.

2. **BLOCKER: ordinary keyboard and touch manoeuvres will spin.** A held key is the only "aggressive" signal, and normal driving holds W plus full lock.
   - Generated (my rough port of §3.5 for a B Muscle: ws_eff 0.59, k 6.5): holding W+D from 0, 5, 10, 15 and 20 mph spins (slip above 75°) at 1.23, 1.20, 1.18, 1.15 and 1.47 s. A normal 90° turn at full lock at about 10 mph takes about 2.6 s. L reaches 0.5 in 0.17 s.
   - So these all spin a C/B Muscle and also S Piercer (design: 1.9-2.0 s): every junction pull-out, a parking or garage exit (reverse, then W with lock held), a taxi pull-away after the 18 mph pickup, and every U-turn.
   - Fix: make full spins need a deliberate gesture, not a held key:
     - (a) A power-brake launch: S+W at a standstill. Today they cancel to 0 at DrivingClient 358-359; R2+L2 cancel at 366; on touch, both pedals. This arms high rpm, and releasing S dumps it.
     - (b) A lift-and-stab: throttle under 0.3 for 0.1-0.4 s, then 0.9 or more with |steer| ≥ 0.6. On analog, dthr/dt above about 4/s from under 0.3 counts as a stab.
     - Each opens a spin window of about 0.7 s.
     - Outside the window, decay ws_eff with a hook-up time constant of about 0.5 s while throttle is held (DRIVE's traction hook does this), and cap L at about 0.35. Sustained W+lock then gives a catchable 10-25° wiggle on Muscle, not a spin.
     - Halve SpinGain on touch by default.
   - Add these to the Play matrix: junction pull-out, parking exit, taxi pickup then turn, and a 15 mph U-turn, all per category.

3. **MAJOR: the yaw cap margin of 1.15 plus a tanh that never reaches the cap gives a slide-and-scrub in every sustained full-lock corner at speed.**
   - With today's turn curve, need/cap is above 1.15 from about 55 mph (E), 75 mph (C) and 110 mph (S).
   - The heading is allowed to turn at 1.15·a_cap/v, but the path can turn at less than a_cap/v.
   - Generated (constant full lock, gear thrust on), shown as slip, speed:

     | Car, entry speed | Margin 1.15, after 1 / 2 / 3 s | Margin 0.9, after 1 / 2 / 3 s |
     |---|---|---|
     | E, 90 mph | 13°, 86 / 22°, 71 / 28°, 48 mph | 8°, 89 / 10°, 84 / 11°, 78 mph |
     | S, 120 mph | 11°, 119 / 18°, 106 / 24°, 84 mph | 7°, 123 / 8°, 121 / 8°, 118 mph |

   - That is an oversteer look and heavy scrub that keyboard players get in every fast corner. It contradicts "spins only below about 38 mph" and the steady 5.1 g claim.
   - Fix: set YawCapMargin to 0.9 or less (understeer at the limit). Better, cap r against the grip actually delivered, and use a peaked curve such as `sin(1.4·atan(B·s))` instead of tanh so the peak is reached at a finite slip.

4. **MAJOR: L can go above 1, which makes yaw damping negative.**
   - L_t = …·SpinGain_c·TierScale reaches 1.25 on B Muscle. Then `k = 8·…·(1 − 0.85L)` is −0.06·k, and `r` is pushed away from `r_cmd` until the clamp holds it at the limit.
   - Fix: clamp L to [0,1], clamp k ≥ 1/s, and move SpinGain into the trigger thresholds or build rate instead of the magnitude.

5. **MAJOR: `sgn(r)` in the spin yaw term snaps the car the other way on a catch.**
   - When the player counter-steers, r crosses 0 while L is still about 0.5 (catch rate 8 means about 125 ms). The 7 rad/s²·L term then flips and drives the car into the opposite direction.
   - Fix: latch SpinDirection at onset, which `FeelSpinDirection` already implies. Apply the term only while r·dir > 0. Detect counter-steer on raw steer, not the rate-limited steer, which adds 0.125-0.3 s of delay.

6. **MAJOR: boost runs every car past its top-gear redline.**
   - S Piercer top-gear redline is 184 mph against Vb of about 214 (x = 1.16). E is 108 against about 116.
   - Above that speed `rpm_road ≥ R`, so the limiter cuts continuously. Every boosted top-speed run then has limiter stutter in the audio and HUD and loses about 60% of engine thrust.
   - The BoostShareHi solve evaluates a_top(Vb) with τ clamped at x = 1, so Vb will not be met.
   - Fix (pick one):
     - Set the top gear from Vb (an overdrive: Over_top = 1.03·Vb/Vt, about 1.27 at S, so the engine sits at about 0.79R at Vt).
     - Declare an "ion-drive" state: while boosting above V_top the engine free-wheels at R, with no cut and no limiter cues.

7. **MAJOR: sign handling for backward motion and spins.**
   - `a_res` and `a_eb` are written unsigned, and "Braking: acc = −BrakeV2…" assumes forward motion.
   - Live code takes signs via `oppositeSignAcceleration` (VehicleDynamics 198, 266). It also enters Braking with W when `forwardMph < −1.5` (259), which happens every half-turn of a donut and on three-point turns.
   - Unsigned terms push a backward-sliding car further backwards. A constant Rb of 0.8 also chatters around 0.
   - ws_eff and L_t are not gated by mode.
   - Fix:
     - Every resistive term should be `−v/max(|v|, 0.8)·mag`.
     - Apply engine braking only when gear ≥ 1 and fwdMph > 0.
     - Set ws_eff to 0 unless Mode is Forward, fwdMph ≥ −1 and SteeringProfileIntent is 1.
     - Gate auto-hold (VehicleDynamics 209/266, which uses |forwardMph| only) on horizontal speed or L < 0.05, so the snap at DrivingClient 1227 cannot fire while the car is sideways mid-spin.

8. **MAJOR: keyboard shift churn and dead throttle at corner exits.**
   - U = 0.45 "at throttle below 0.3" includes throttle 0, so lifting W at 50 mph in 2nd on S Piercer causes two cruise upshifts in 0.7 s.
   - Pressing W again with x < 0.55 then kicks down two gears.
   - So every W tap goes up, up, down. On Muscle each kickdown costs 200 ms of zero torque plus a 160 ms blend, which is about 0.36 s of dead throttle at each corner exit.
   - Fix:
     - No cruise upshift at throttle ≤ deadzone; the cruise band is 0.05-0.3, as in ProAuto.
     - Hold the gear for about 0.8 s after a lift.
     - Kickdown only when x < 0.45 and throttle has been held for 0.12 s.
     - No torque cut on downshifts (a rev-matched blend only).
     - Add a Play check: count shifts while tapping W to hold 40 mph.

9. **MAJOR: rpm and gear go wrong in drifts and spins.** `rpm_road` comes from body-forward speed (`velocity:Dot(forward)`, DrivingClient 1091).
   - In a 40° drift the forward component drops 23%, so kickdown and coast-downshift fire mid-drift. Only upshifts are blocked.
   - In a donut, rpm falls to about 0.6R even though the "rear" is spinning.
   - In 2nd-gear drifts the limiter bounces, so the drift engine assist flickers at about 14 Hz.
   - Fix: hold the gear completely while DriftBlend > 0.3 or L > 0.1 (upshift only on the limiter). Use `rpm_road` from |v_horizontal| blended by DriftBlend. During a spin, aim rpm at a free-rev target of about 0.85R·thr.

10. **MAJOR: top speed matches only in the limit; the speed actually reached on a straight drops a lot.** Drag is about 4.4× lower (Kd 0.00055 against 0.00238 on S Piercer).
    - Generated, new against today, from a standstill: 150 mph at 12.3 s against 5.1 s; 160 at 15.4 against 6.2; 170 at 21.8 against 8.6; speed at 10 s is 141 against 172 mph.
    - Players will rarely see top speed. The pacing hit is much larger than the 60-130 row suggests, and any ramp or jump tuned to today's speeds may fail.
    - Fix: add a target for time to 0.9·Vt (for example 12 s or less at S) and tune p per gear or category (p 0.7 raises top-gear thrust by 24%). Report speed at 10 and 15 s per tier alongside the table.

11. **MAJOR: the yaw lag reads as latency and run-on, not weight.**
    - Keyboard ramp (0.2 s) plus yaw τ (0.10-0.17 s) plus Align (about 0.045 s) puts 63% of yaw response at about 0.3-0.37 s, against about 0.05 s today.
    - After releasing the key, first-order run-on is r/k: 1.2/6.5 at 60 mph is about 11°, plus about 5° from the 8/s steer return. Keyboard drivers will weave.
    - Fix:
      - Unwind faster than build (k_unwind ≈ 2·k).
      - Steer return 12-15/s.
      - Make k speed-blended: k_eff = k + 30·(1 − ss(mph/15)), so parking speeds stay kinematic. This also removes the 0.11-0.15 s, 2-3° wrong-way rotation on DRIVE-01 three-point turns, where reverse ×3 flips to forward.
      - Target 5° or less of run-on at 60 mph.

12. **MAJOR (spec bug): throttle is applied twice.** `a_raw` already includes thr, and Forward then uses `a_drive·thr`, so gamepad thrust goes as thr². At 0.5 throttle that is 25% thrust. The generated guard cases ("60% throttle: no spin; 80% spins Muscle") and verification row 4 depend on which form the code uses. Pin it as linear, or pedalGamma about 1.1.

13. **MINOR: shift and limiter cuts depend on frame rate.** Cuts of 30-70 ms with boolean per-frame state become 50/100 ms at 20 fps, and limiter duty moves from about 40% to 50%. Use the time-weighted cut fraction over each frame for `k_shift` and the limiter.

14. **MINOR: launches feel the same at every tier.**
    - 1st-gear thrust exceeds a_trac (about 40 studs/s²) for every tier E-S: E is about 55, S about 72.
    - So every car launches at about 1.0-1.15 g, and tier and engine differences only appear after the 1-2 shift.
    - Fix: let traction rise a little with Downforce or tier (S about 1.4 g) so upgrades are felt off the line.

15. **MINOR: pitch ignores boost.** The pitch source (DriveThrust − a_res − brake) leaves out boost and mini-boost (DrivingClient 1401, 1408), so the Redline nitro squat never happens. Include them, weighted by BoostShare.

16. **MINOR: the spin catch stops the car too abruptly.** When L decays, k recovers and r snaps to r_cmd in about 0.1 s. Decay toward r_cmd with τ of about 0.3 s instead. SpinMaxYawRate 3.6 and the equation's `|r| ≤ 5` conflict; pick one.

17. **MINOR: neutral revs never reach the limiter.** The target `I + thr·(0.9R − I)` stays below it. Use about 1.02R so the countdown bounces the limiter, as in the clip.

18. **MINOR: the spin grace is too short.** Anchoring covers races and duels (TimeTrialServer 373, MatchmakingServer 164, DuelService 282/295), and teleports also anchor (FreeRoamTeleportServer 101-108, RaceTeleportServer 111-117), which is harmless. But 1.5 s after GO, a B Muscle is still under 25 mph. End the grace at 38 mph or 3 s, whichever is later. Also reset the rate-limited steer, r, L, a_lat and the gearbox in Start, Stop, ResetVehicle (1581), the anchored branch (1068) and when the input gate is locked (337).

19. **MINOR: the camera acceleration spikes during a spin.** DrivingCameraClient 538 differentiates forward speed along the rotating heading, so the Lag spring jumps to its ±3 stud limit. In spin mode, use the derivative of speed magnitude.

20. **MINOR: track down the coast loss before tuning engine braking.**
    - The unexplained loss is about 7-8 studs/s² (0.2 g) at 20-34 mph. That is the same size as the new low-speed resistance plus 1st-gear engine braking (3.6-5 studs/s²).
    - Candidates:
      - Body contact once settle lowers below 22 mph (`HoverPose` SettleFullHeightMph 22, RestScale 0.7). The 34→16 mph probe crosses that speed.
      - The lateral damper against `WobbleYaw` at low speed.
    - Fluid forces are unlikely, because the Seraph launch matched within 2 mph up to 207.
    - Probe for free: log `publishFeelState`'s `unexplained/dt` (DrivingClient 868) while coasting on flat ground at a steady 30 and 18 mph.

21. **MINOR: drift balance shifts.** Drag that is 4× lower means more exit speed. Mini-boost multiplied by BoostShare is cut at speed but kept longer. Re-run the driving_tune corner table and hold "distance gained over 3 s from a full mini-boost" within ±10%.

**Improvements worth adding**
- **Second-order yaw.** Use ω about 9, ζ about 0.75, blended to kinematic below about 15 mph, instead of a first-order lag. A slight overshoot and settle reads as mass; a lag reads as input delay.
- **Combined grip.** Braking and lateral share an ellipse (trail-braking gives understeer), plus a small lift-off oversteer at speed. These are the strongest "weight" cues in the 30-80 mph range, which the 3.4 g cap leaves untouched (need/cap is 0.6-0.8 at 45 mph).
- **Let impacts rotate the car.** On a `FeelImpact` revision, add a yaw impulse to r or move YawHeading partly toward the body heading. Today the infinite-torque Align hides all collision rotation.
- **DRIVE-style regression targets in the Python model and the Play matrix.**
  - Per tier and category: time to 0.9·Vt and post-release yaw run-on at 60 mph.
  - Keyboard: a 15 mph U-turn must not spin; keyboard tap churn of 2 shifts or fewer per 10 s; drift radius within ±10% of today.
  - Limiter top speed at 20 fps against 144 fps.
- **Teach the power-brake launch.** Show N, the revs and a "LAUNCH" cue during the countdown and on S+W at a standstill. That gives keyboard and touch players a learnable "aggressive" input for donuts and spins, and fits the Redline start-line moment.