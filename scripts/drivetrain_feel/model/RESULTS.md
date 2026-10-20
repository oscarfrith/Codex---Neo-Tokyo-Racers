# drivetrain_feel offline model: results (CONTRACT section 9)

Run `py -3 scripts/drivetrain_feel/model/sim.py --write` (about 20 s). It refreshes every table between the `BEGIN`/`END` markers; the text around them is written by hand. Every number here is **generated** by the offline model. None is measured in Play.

Cars: the six Exotic stock builds (garage stock totals and stock PI 220 / 390 / 540 / 675 / 800 / 938 from `scripts/exotic_category/balance/report.md` section 3), plus the measured as-spawned Seraph (PI 946). Config: `before/config.json` (PR98 live, 2026-10-20), balance on.

## Summary

**Today's model reproduces the measured Seraph.**
- 0-100 mph: 2.85 s in the model against 2.7 s measured.
- Speed at 4.4 s: 132 mph against 131.
- Braking 131-0: 1.83 s against 1.9.
- The pre-balance run matches within 4 mph throughout.
- The only known gap is coasting: the model ends a 1.6 s coast from 34 mph at 25.8 mph, but the car measured 16 (critique 20).

**With the contract defaults, four targets fail:**
- Run-on is 6.8-7.8 deg against a 5 deg limit.
- Drift radius is +16 to +35% against ±10%.
- Nothing spins: the largest gesture slip is 33 deg (power-brake, B).
- The E power-brake does not spin.

**With the proposed defaults plus the recommended code choices, every CONTRACT 9 target passes on all six cars at 60 Hz:**

| Metric | Today | Proposed |
|---|---|---|
| S 0-60 | 1.47 s | 1.92 s |
| S 0-100 (target 3.8-4.8 s) | 2.62 s | 3.93 s |
| S time to 0.9·Vt (target ≤ 12 s) | 5.8 s | 11.3 s |
| E 0-100 | 7.15 s | 14.95 s (E top is 103.6 mph) |
| S speed at 10 s | 171 mph | 152 mph |
| Top speed, every car | unchanged by construction | |
| Braking 100-0, S | 1.37 s (3.3 g) | 2.05 s (2.2 g) |
| Braking 100-0, E | 2.97 s | 3.52 s |
| Speed 2 s after lifting at 100 mph | 55-66 mph | 83-88 mph |
| Endless-boost top | | unchanged (S 217.2 mph) |
| One tank of boost from top speed, S | 216 mph | 190 mph |
| Boost held from rest, S 0-100 | 1.20 s | 1.60 s |
| Yaw run-on after a key release at 60 mph | 0 deg | 3.3-3.7 deg (≤ 4.4 frame-rate-free) |
| Turn-in to 63% of the yaw rate | 0.017 s | 0.20-0.30 s |
| Full-lock lateral g at 60 mph | 3.0-4.5 g | 2.2-3.8 g |
| Drift radius / peak yaw / exit speed | | +5 to +9% / 0 to +7% / -2 to -10% of today |
| Shift count, 10 s tapping W at 40 mph | | 0 on every car |
| Shift count, gamepad holding 60 mph | | at most 1 |
| Spins: holds and U-turns at 0-25 mph | | never; at most 28 deg of slip, a catchable wiggle |
| Spins: lift-and-stab at 0/10/20 mph and power-brake | | spin on all six cars (83-157 deg) |
| Spins: touch power-brake (SpinTouchScale 0.5) | | never |

**The recommended code choices are not attributes.** The attributes alone, on the contract-literal drift code, still fail drift: radius is +5 to +25% and exit speed is -18 to -42%. These choices are in "Findings for the physics part" below.

**Frame rate.** At 20, 60 and 144 Hz every metric agrees within 1-2% except run-on. Run-on is 2.6-2.8 deg at 20 Hz, 3.4-3.7 at 60 Hz and 3.6-4.2 at 144 Hz, because the release ramp is quantised. Each upshift removes 49.5 ms of thrust at every frame rate (fix 5).

**Feel dials.** Each dial at its 0 end reproduces today for its own aspect:
- `FeelWeight` 0: run-on 0 deg, turn-in 0.02 s, braking 1.38 s against 1.37.
- `FeelGearing` 0: no cut, equal thrust in every gear.
- `FeelSpin` 0: no spin.

`FeelSpin` is independent of `FeelWeight`: the S power-brake reaches 86 / 96 / 102 deg at `FeelWeight` 0 / 1 / 2.

## Proposed defaults

Only CONTRACT section 4 attributes; every attribute not listed keeps its contract default. The integrator decides.

<!-- BEGIN:proposal -->
| attribute | contract default | proposed | why |
|---|---|---|---|
| `SteerRiseSeconds` | 0.2 | 0.12 | Drift parity: the keyboard ramp delays drift entry and widens the drift radius (C is the worst car). Turn-in to 63% yaw rate at 60 mph stays 0.20-0.30 s against 0.017 s today; the yaw spring carries most of the weight. |
| `SteerReturnRate` | 14 | 25 | Run-on: the release ramp adds yaw after the key is up. With YawUnwindScale 4 the run-on is under 4 deg at 60 Hz and under 4.5 at 480 Hz (frame-rate-free) on every car; the contract values give 6.8-7.8 deg. |
| `YawUnwindScale` | 2 | 4 | Run-on, together with SteerReturnRate: the yaw stops quickly after a release. The build (YawOmega 9, YawDamping 0.75) is unchanged, so turn-in keeps its weight. |
| `DriftCapExempt` | 1 | 2 | Drift parity: read as a gain, clamp(DriftBlend x DriftCapExempt, 0, 1), so the drift is fully exempt from DriftBlend 0.5 and drift entry no longer runs into the 3.4 g cap while DriftBlend ramps. Needs that mapping in the physics code; as a strict 0/1 switch keep 1 (drift radius then fails). |
| `SpinSlipStart` | 0.12 | 0.04 | Stab gate: first-gear launch slip ws_eff is only 0.14-0.21 on the six stock cars (the tier traction bonus gives S the least), so at 0.12 the slip term stays near 0 and C/S stabs cannot spin. 0.04 counts first-gear full-throttle slip fully; SpinHoldCap still limits holds. |
| `SpinSlipWidth` | 0.25 | 0.08 | With SpinSlipStart 0.04 the slip term is full from ws_eff 0.12, which every car reaches in first gear. Tier separation comes from SpinTierFloor, not from slip. |
| `SpinGripLoss` | 0.7 | 0.85 | Spin physics: the travel direction re-aligns with the nose at about (grip + thrust / v) x sin(slip), 4-5 rad/s at 10 mph with 0.7 loss, above the 3.6 rad/s spin cap, so slip stalls under 75 deg. 0.85 leaves 15% grip at L 1. |
| `SpinThrustLoss` | 0.35 | 0.6 | Same physics: thrust along the nose turns the travel direction at a_drive x sin(slip) / v (about 2.7 rad/s at 10 mph). 0.6 lets a full spin rotate past the travel direction; holds (L 0.35) keep 79% of thrust. |
| `SpinYawAccel` | 7 | 11 | Spin onset: the smallest round value that spins every C-S gesture and the E power-brake with margin (smallest required gesture 85 deg). |
| `SpinTierFloor` | 0.5 | 0.8 | E power-brake must spin: at 0.5 the E car's L tops out at 0.5. At 0.8 it reaches 0.8. E and D then also spin on a lift-and-stab; FeelSpin calms every tier at once. |
| `SpinBuildRate` | 3.5 | 6 | Gestures are short: at 3.5/s L is still building when the window closes, most visibly on stabs at 20 mph. |
| `SpinWindowSeconds` | 0.7 | 0.9 | At 0.7 s the window closes before C-S gestures pass 75 deg; 0.9 s carries them to about 95-175 deg. |
| `SpinWarnLevel` | 0.25 | 0.4 | Every full-lock pull-out now reaches the hold cap (L 0.35: a catchable wiggle by design), so 0.25 would turn the gear readout amber at every junction exit. 0.4 sits above the cap: amber only when a gesture lets a real spin build. |
<!-- END:proposal -->

Each proposed attribute put back to its contract default, everything else as proposed (generated, recommended code):

<!-- BEGIN:revert -->
| Change from the proposal | CONTRACT 9 targets that fail | smallest required gesture slip deg (75 = spin) | largest hold / U-turn slip deg | largest run-on deg | drift worst radius % / yaw % / exit % | holds light the spin warning |
|---|---|---|---|---|---|---|
| proposed (nothing reverted) | none | 85 | 28 | 3.7 | +9 / 7 / 10 | no |
| `SteerRiseSeconds` back to 0.2 | drift | 85 | 28 | 3.8 | +13 / 6 / 10 | no |
| `SteerReturnRate` back to 14 | runon | 85 | 28 | 5.2 | +9 / 7 / 10 | no |
| `YawUnwindScale` back to 2 | runon | 85 | 28 | 6.3 | +9 / 7 / 10 | no |
| `DriftCapExempt` back to 1 | drift | 85 | 28 | 3.7 | +18 / 4 / 9 | no |
| `SpinSlipStart` back to 0.12 | gesture | 14 | 25 | 3.7 | +9 / 7 / 10 | no |
| `SpinSlipWidth` back to 0.25 | gesture | 14 | 26 | 3.7 | +9 / 7 / 10 | no |
| `SpinGripLoss` back to 0.7 | gesture, pbE | 73 | 27 | 3.7 | +9 / 7 / 10 | no |
| `SpinThrustLoss` back to 0.35 | gesture | 52 | 28 | 3.7 | +9 / 7 / 10 | no |
| `SpinYawAccel` back to 7 | gesture, pbE | 53 | 20 | 3.7 | +9 / 7 / 10 | no |
| `SpinTierFloor` back to 0.5 | pbE | 30 | 27 | 3.7 | +9 / 7 / 10 | no |
| `SpinBuildRate` back to 3.5 | gesture, pbE | 42 | 28 | 3.7 | +9 / 7 / 10 | no |
| `SpinWindowSeconds` back to 0.7 | gesture, pbE | 62 | 28 | 3.7 | +9 / 7 / 10 | no |
| `SpinWarnLevel` back to 0.25 | none | 85 | 28 | 3.7 | +9 / 7 / 10 | yes |
<!-- END:revert -->

## Findings for the physics part (code, not attributes)

The model's `MODEL_CONSTANTS` in `drivetrain.py` hold each choice as a switch, so every claim below can be re-run. The recommended set is `RECOMMENDED_CODE` in `sim.py`, plus the defaults of `MODEL_CONSTANTS`. Section 11 has the measurements.

1. **Spin yaw as its own additive state.** Use `r = r_steer + r_spin`.
   - `r_steer` is the contract's steering spring: FeelWeight, unwind, kinematic blend below `YawKinematicBelowMph`, drift exemption, and authority `x (1 - 0.85 L)`.
   - `r_spin` is driven by `SpinYawAccel x L x (0.6 + 0.4 min(ws_eff / 0.5, 1)) x dir` while `r x dir > 0`.
   - `r_spin` decays at `k_s = max(YawOmega x weight x (1 - 0.85 L), 1) / (2 YawDamping)`, which gives the single spring's steady offset at FeelWeight 1. While settling after a catch, `k_s >= 3 / SpinSettleSeconds`.
   - The caps `SpinMaxYawRate` and `YawRateMax` apply to the sum.

   Why the single state as drafted fails:
   - `YawUnwindScale` fires whenever the spin pushes r past r_cmd, and fights the spin.
   - The kinematic blend below 15 mph erases the spin, which is exactly where spins happen.
   - Result: no gesture spins (E / S power-brake 16 / 34 deg).
   - With both fixed it spins at FeelWeight 1, but FeelWeight 0 disables spins (S power-brake 44 deg).
   - The additive state gives 86 / 96 / 102 deg at FeelWeight 0 / 1 / 2.
2. **A stab is a lift-and-stab.** Open the window only when the throttle fell from at least 0.3 to below 0.3 and comes back to at least 0.9 within `SpinStabSeconds`. Analog input (gamepad) uses the `SpinAnalogRate` rule instead. Read literally ("any rise from below 0.3"), every steer-then-W pull-out and U-turn becomes a stab and spins: 69-95 deg on E, C and S.
3. **Drift parity needs four choices.** `DriftCapExempt` alone is not enough.
   - **(a) Exemption as a gain.** The exemption weight is `clamp(DriftBlend x DriftCapExempt, 0, 1)`. Use it for the lateral lerp and for the yaw cap.
   - **(b) The yaw spring blends to kinematic by the same weight** (`DriftYawExempt`). The drift owns yaw as it owns lateral grip. This is the largest single radius term: the spring alone widens the radius by about 20%.
   - **(c) Downshift by |v_h| inside the drift hold.** In a drift, step down when the landing rpm is at most `DownshiftBrakeLand` (`DriftHoldDownshift`). Contract fix 3 holds the gear, so a drift from 85% of Vt bogs in 6th: S exit speed is -39%. Upshifts stay blocked, as fix 3 wants.
   - **(d) Drift engine assist reads `lerp(DriveThrust, A1 x thr, 0.9)`** (`DriftAssistPlateauShare` 0.9), not gross DriveThrust alone. Today's assist is 0.7 x the net plateau pull. Mid and high gears deliver about half of that, so exit speed falls 19-31% without this.

   This share is the main remaining drift dial. Consider exposing it as an attribute in a later contract.
4. **Derive `Kd` and `BoostShareHi` from delivered thrust.** Use the traction-limited, slide-factored top-gear thrust, not `A1 x mult_top x tau`. At `FeelGearing` 0 the top-gear request exceeds traction, and the S car topped out at 159.6 mph instead of 173.6 before this fix.
5. **Integrate `YawHeading` with the frame-average yaw rate** (or inside the spring sub-steps). With the end-of-frame r, run-on at 20 Hz is about half the frame-rate-free value.
6. **Sub-step the yaw spring.** The unwind spring reaches 9 x 1.3 x 4 = 47 rad/s, and one explicit step at 20 Hz is unstable. The model uses `ceil(dt x omega / 0.2)` semi-implicit sub-steps.
7. **Scale the keyboard return with FeelWeight:** `SteerReturnRate / FeelWeight`. Otherwise FeelWeight 0 keeps 1.9 deg of run-on from the return ramp, and does not reproduce today.
8. **Peaked lateral curve.** Use `a_cap x sin(C x atan(u / C))` with `u = a_lin / a_cap` (B = 1/C). Its slope at small slip equals today's linear damper, so gentle corners are unchanged. It peaks at a request of 2.9 x the cap and slides at sin(C π/2) = 0.81 of the cap.

**Against the physics part as written.** This is a read-only emulation of `physics/after/DrivingClient.lua` as read on 2026-10-20. That code has:
- one yaw state, with `YawUnwindScale` also applied mid-spin;
- spin blend `smoothstep(L / 0.25)`;
- the stab as a rise time (no lift needed);
- contract-literal drift.

With the proposed spin attributes that code gives the worst combination:
- No gesture spins.
- Every steer-then-W pull-out opens a spin window and slides up to 66 deg.

So the spin rows of the proposal need findings 1 and 2. Without them, keep the contract spin values: no spins, calm holds.

<!-- BEGIN:physics -->
| Physics part as written, emulated | CONTRACT 9 targets that fail | largest hold / U-turn slip deg | C-S gesture slip deg (75 = spin) |
|---|---|---|---|
| contract attributes | runon, drift, gesture, pbE | 17 | 13 to 22 |
| proposed attributes | drift, gesture, pbE | 66 | 38 to 59 |
<!-- END:physics -->

## Decisions and side effects for Oscar (not changed here)

- **Touch players cannot spin** with `SpinTouchScale` 0.5: the touch power-brake reaches 17-25 deg. At 0.9, C-S cars spin on a touch power-brake; at 1.0, E does too.
- **Boost at top speed is much weaker.** The endless-boost top is unchanged. But one tank from top speed gains 17 mph on S (today 43), because `BoostShareHi` is 0.17-0.31. The boost kick from low speed is kept: boost held from rest gives S 0-100 in 1.60 s.
- **The post-drift mini-boost exit is 14-21% slower.** This is the speed 1.5 s after release. Mini-boost is multiplied by `BoostShare` (fix 6), and mid-gear thrust is lower. Critique 21's ±10% for mini-boost distance is not met.
- **Every full-lock pull-out shows a wiggle.** Holds reach the hold cap L 0.35, giving 15-28 deg of slip against 10-14 today. This is by design. `SpinHoldCap` lower or `FeelSpin` lower calms it.
- **E and D also spin on a lift-and-stab** with `SpinTierFloor` 0.8. That floor is what lets an E power-brake spin.
- **Measured coasting is lossier than the model.** The 2 s lift numbers (83-88 mph) will read lower in Play. Probe `unexplained / dt` while coasting, as critique 20 says, before tuning `EngineBrakeDecel` and the `RollingDecel` values.
- **The as-spawned Seraph is heavier (VEH-01).** Its weight is 84 against 60 stock, and its stab at 20 mph does not spin (31 deg). Stock totals spin. On-road PI and stats differ from the garage values the profile tiers use.

## Regression targets (CONTRACT 9), six stock Exotic cars, 60 Hz

<!-- BEGIN:targets -->
| CONTRACT 9 target | contract defaults | proposed attributes, contract-literal drift code | proposed (attributes + recommended code) |
|---|---|---|---|
| top speed within 3% of today (every car) | PASS | PASS | PASS |
| S 0-100 mph 3.8 to 4.8 s | PASS | PASS | PASS |
| S time to 0.9 x Vt at most 12 s | PASS | PASS | PASS |
| yaw run-on after a release at 60 mph at most 5 deg (every car) | FAIL | PASS | PASS |
| at most 2 shifts in 10 s of tapping W at 40 mph (every car) | PASS | PASS | PASS |
| drift radius within 10% of today (every car) | FAIL | FAIL | PASS |
| U-turn at 0 and 15 mph without a spin (every car) | PASS | PASS | PASS |
| stab and power-brake spin on C to S cars | FAIL | PASS | PASS |
| power-brake can spin an E car | FAIL | PASS | PASS |
| W + full lock held from 0-25 mph never spins (every car) | PASS | PASS | PASS |
| endless-boost top within today's +3% (every car) | PASS | PASS | PASS |
<!-- END:targets -->

## 1. Today's model against the measured Seraph

<!-- BEGIN:validation -->
| Seraph as spawned (PI 946) | measured / model, mph | largest difference |
|---|---|---|
| balance off, 60 Hz | 0.50 s 34/30, 1.05 s 65/64, 1.80 s 107/105, 2.60 s 142/141, 3.60 s 174/173, 4.40 s 191/190, 5.70 s 207/207 | 4.0 mph |
| balance off, 120 Hz | 0.50 s 34/30, 1.05 s 65/64, 1.80 s 107/105, 2.60 s 142/141, 3.60 s 174/173, 4.40 s 191/190, 5.70 s 207/207 | 3.9 mph |

| Seraph as spawned, balance on (PI 946) | measured in Play (v3, 2026-10-06) | today's model |
|---|---|---|
| 0-100 mph | 2.70 s | 2.85 s |
| speed at 4.4 s | 131 mph | 132 mph |
| brake 131-0 | 1.9 s | 1.83 s |
| coast 34 mph for 1.6 s | 16 mph | 25.8 mph (known gap, critique 20) |
<!-- END:validation -->

## 2. Per-car drivetrain profile (proposed settings)

<!-- BEGIN:profiles -->
| Car | Vt mph | Vb mph | maxMph | gear redline mph 1..7 | A1 studs/s2 | traction g | launch a_raw/a_trac - 1 (before assist) | Kd | BoostShareHi | brake g today / new | spin tier scale |
|---|---|---|---|---|---|---|---|---|---|---|---|
| E exotic_01 Stinger 220 | 103.6 | 126.8 | 231 | 28 / 40 / 53 / 66 / 80 / 94 / 110 | 47.2 | 1.04 | 0.21 | 0.001192 | 0.31 | 1.15 / 1.06 | 0.80 |
| D exotic_02 Zephyr 390 | 106.4 | 130.6 | 235 | 29 / 41 / 54 / 68 / 82 / 97 / 113 | 51.6 | 1.10 | 0.24 | 0.001246 | 0.31 | 1.24 / 1.13 | 0.84 |
| C exotic_03 Aurora 540 | 114.4 | 140.4 | 233 | 31 / 45 / 58 / 73 / 88 / 104 / 121 | 57.9 | 1.26 | 0.22 | 0.001220 | 0.31 | 1.47 / 1.23 | 0.92 |
| B exotic_04 Endura 675 | 137.2 | 167.0 | 231 | 37 / 53 / 70 / 87 / 106 / 125 / 145 | 67.8 | 1.40 | 0.28 | 0.001000 | 0.31 | 1.89 / 1.44 | 0.99 |
| A exotic_05 Rosso 800 | 162.2 | 200.0 | 232 | 44 / 63 / 83 / 103 / 125 / 148 / 172 | 72.4 | 1.49 | 0.29 | 0.000763 | 0.30 | 2.49 / 1.69 | 1.00 |
| S exotic_06 Seraph 938 | 173.6 | 217.2 | 235 | 47 / 68 / 89 / 111 / 134 / 158 / 184 | 71.0 | 1.57 | 0.20 | 0.000649 | 0.17 | 3.09 / 2.04 | 1.00 |
| S exotic_06 Seraph (as spawned) 946 | 167.3 | 219.8 | 240 | 45 / 65 / 85 / 107 / 129 / 153 / 177 | 66.0 | 1.57 | 0.11 | 0.000646 | 0.20 | 2.89 / 1.91 | 1.00 |
<!-- END:profiles -->

## 3. Straight line, from rest, keyboard W (today / proposed)

<!-- BEGIN:straight -->
| Car | 0-60 s today / new | 0-100 s | to 0.9 Vt s | mph at 10 s | mph at 15 s | top mph (60 s) | contract 0-100 if different |
|---|---|---|---|---|---|---|---|
| E exotic_01 Stinger 220 | 2.40 / 3.62 | 7.15 / 14.95 | 5.2 / 10.3 | 103 / 93 | 104 / 100 | 103.6 / 103.6 (-0%) | same |
| D exotic_02 Zephyr 390 | 2.18 / 3.30 | 5.78 / 11.78 | 4.9 / 9.7 | 106 / 97 | 106 / 104 | 106.4 / 106.4 (-0%) | same |
| C exotic_03 Aurora 540 | 1.90 / 2.82 | 4.32 / 8.13 | 4.7 / 9.3 | 114 / 105 | 114 / 112 | 114.4 / 114.4 (-0%) | same |
| B exotic_04 Endura 675 | 1.57 / 2.28 | 3.05 / 5.22 | 4.8 / 9.5 | 137 / 125 | 137 / 134 | 137.2 / 137.2 (-0%) | same |
| A exotic_05 Rosso 800 | 1.45 / 2.02 | 2.63 / 4.17 | 5.3 / 10.5 | 161 / 144 | 162 / 156 | 162.2 / 162.2 (-0%) | same |
| S exotic_06 Seraph 938 | 1.47 / 1.92 | 2.62 / 3.93 | 5.8 / 11.3 | 171 / 152 | 173 / 166 | 173.6 / 173.6 (-0%) | same |
<!-- END:straight -->

<!-- BEGIN:shifts -->
| Car (full throttle from rest) | upshifts: time @ mph | deepest frame-average cut | limiter bounces |
|---|---|---|---|
| E exotic_01 Stinger 220 | 1.28s@27 1.93s@39 2.82s@51 4.05s@64 5.92s@78 9.45s@92 | 0.45 | 0 |
| D exotic_02 Zephyr 390 | 1.25s@28 1.87s@40 2.68s@53 3.85s@66 5.60s@80 8.90s@94 | 0.45 | 0 |
| C exotic_03 Aurora 540 | 1.17s@30 1.75s@43 2.55s@57 3.65s@71 5.32s@86 8.48s@101 | 0.45 | 0 |
| B exotic_04 Endura 675 | 1.27s@36 1.88s@52 2.68s@68 3.82s@85 5.52s@103 8.73s@121 | 0.45 | 0 |
| A exotic_05 Rosso 800 | 1.40s@42 2.08s@62 2.97s@81 4.20s@100 6.08s@121 9.65s@144 | 0.45 | 0 |
| S exotic_06 Seraph 938 | 1.40s@46 2.12s@66 3.08s@86 4.43s@107 6.48s@130 10.37s@154 | 0.45 | 0 |
<!-- END:shifts -->

## 4. Braking, lift-off and boost (today / proposed)

<!-- BEGIN:longitudinal -->
| Car | braking s today / new | speed 2 s after a lift | endless-boost top mph | one tank from Vt mph | Overdrive share, limiter bounces (boosted top) | boost-held 0-100 s |
|---|---|---|---|---|---|---|
| E exotic_01 Stinger 220 | 98-0: 2.97 / 3.52 (1.51 / 1.28 g, 6 downshifts) | 98 -> 55 / 83 | 126.8 / 126.8 (-0%) | 117 / 109 | 1.00, 0 | 6.42 / 14.10 |
| D exotic_02 Zephyr 390 | 100-0: 2.82 / 3.37 (1.62 / 1.35 g, 6 downshifts) | 100 -> 55 / 84 | 130.6 / 130.6 (-0%) | 123 / 114 | 1.00, 0 | 4.70 / 10.55 |
| C exotic_03 Aurora 540 | 100-0: 2.45 / 3.15 (1.86 / 1.45 g, 5 downshifts) | 100 -> 56 / 84 | 140.4 / 140.4 (-0%) | 134 / 124 | 1.00, 0 | 2.88 / 6.58 |
| B exotic_04 Endura 675 | 100-0: 2.05 / 2.77 (2.22 / 1.65 g, 4 downshifts) | 100 -> 59 / 85 | 167.0 / 167.0 (-0%) | 160 / 148 | 1.00, 0 | 1.87 / 3.75 |
| A exotic_05 Rosso 800 | 100-0: 1.65 / 2.42 (2.76 / 1.89 g, 3 downshifts) | 100 -> 64 / 87 | 200.0 / 200.0 (-0%) | 191 / 176 | 1.00, 0 | 1.60 / 2.55 |
| S exotic_06 Seraph 938 | 100-0: 1.37 / 2.05 (3.34 / 2.22 g, 3 downshifts) | 100 -> 66 / 88 | 217.2 / 217.2 (-0%) | 216 / 190 | 1.00, 0 | 1.20 / 1.60 |
<!-- END:longitudinal -->

## 5. Yaw run-on and cornering

<!-- BEGIN:runon -->
| Car | run-on deg at 60 Hz: today / contract / proposed | proposed at 480 Hz | body (with Align lag) today / proposed | turn-in to 63% yaw s today / proposed | steady yaw at 60 mph rad/s today / proposed |
|---|---|---|---|---|---|
| E exotic_01 Stinger 220 | 0.0 / 7.1 / 3.4 | 3.9 | 2.9 / 5.7 | 0.017 / 0.30 | 1.16 / 0.89 |
| D exotic_02 Zephyr 390 | 0.0 / 7.2 / 3.5 | 3.9 | 3.0 / 5.7 | 0.017 / 0.30 | 1.21 / 0.90 |
| C exotic_03 Aurora 540 | 0.0 / 7.4 / 3.6 | 4.1 | 3.2 / 6.1 | 0.017 / 0.28 | 1.27 / 1.01 |
| B exotic_04 Endura 675 | 0.0 / 6.8 / 3.3 | 3.8 | 3.1 / 5.8 | 0.017 / 0.22 | 1.40 / 1.14 |
| A exotic_05 Rosso 800 | 0.0 / 7.1 / 3.4 | 4.0 | 2.8 / 5.9 | 0.017 / 0.20 | 1.54 / 1.36 |
| S exotic_06 Seraph 938 | 0.0 / 7.8 / 3.7 | 4.4 | 3.1 / 6.5 | 0.017 / 0.20 | 1.69 / 1.49 |
<!-- END:runon -->

<!-- BEGIN:corner -->
| Car | full lock holding 60 mph: lateral g, slip, speed (today / proposed) | full lock from 120 mph |
|---|---|---|
| E exotic_01 Stinger 220 | 3.0 / 2.2 g, slip 13 / 16 deg, 57 / 47 mph | 3.8 / 2.1 g, slip 12 / 9 deg, 83 / 96 mph |
| D exotic_02 Zephyr 390 | 3.1 / 2.3 g, slip 14 / 16 deg, 57 / 47 mph | 3.9 / 2.2 g, slip 12 / 9 deg, 85 / 98 mph |
| C exotic_03 Aurora 540 | 3.3 / 2.5 g, slip 13 / 16 deg, 58 / 47 mph | 4.2 / 2.5 g, slip 10 / 8 deg, 93 / 102 mph |
| B exotic_04 Endura 675 | 3.7 / 2.9 g, slip 12 / 15 deg, 59 / 54 mph | 4.9 / 3.0 g, slip 8 / 8 deg, 112 / 109 mph |
| A exotic_05 Rosso 800 | 4.2 / 3.5 g, slip 11 / 14 deg, 59 / 56 mph | 5.5 / 3.7 g, slip 7 / 7 deg, 117 / 112 mph |
| S exotic_06 Seraph 938 | 4.5 / 3.8 g, slip 11 / 15 deg, 59 / 51 mph | 6.1 / 3.9 g, slip 7 / 8 deg, 117 / 111 mph |
<!-- END:corner -->

## 6. Drift (the driving_tune corner table)

<!-- BEGIN:drift -->
| Car (2 s full lock + drift from 85% of Vt) | radius studs: today / contract / proposed attrs only / proposed | peak yaw deg/s today / proposed | exit mph: today / contract / attrs only / proposed | 1.5 s after release (mini-boost) mph |
|---|---|---|---|---|
| E exotic_01 Stinger 220 | 142 / 190 / 177 / 152 (+7%) | 73 / 73 (-0%) | 61 / 52 / 50 / 57 (-7%) | 79 / 64 |
| D exotic_02 Zephyr 390 | 138 / 181 / 167 / 149 (+8%) | 77 / 77 (-0%) | 65 / 54 / 53 / 62 (-5%) | 83 / 69 |
| C exotic_03 Aurora 540 | 144 / 181 / 167 / 157 (+9%) | 80 / 81 (+1%) | 73 / 60 / 58 / 71 (-2%) | 92 / 79 |
| B exotic_04 Endura 675 | 159 / 187 / 172 / 172 (+8%) | 82 / 83 (+1%) | 87 / 70 / 67 / 85 (-2%) | 111 / 96 |
| A exotic_05 Rosso 800 | 129 / 150 / 136 / 135 (+5%) | 112 / 119 (+7%) | 82 / 57 / 53 / 74 (-10%) | 116 / 92 |
| S exotic_06 Seraph 938 | 78 / 105 / 94 / 83 (+6%) | 159 / 159 (-0%) | 52 / 32 / 30 / 47 (-10%) | 98 / 79 |
<!-- END:drift -->

## 7. Shift churn

<!-- BEGIN:churn -->
| Car | shifts in 10 s tapping W at 40 mph: contract / proposed | shifts in 10 s gamepad holding 60 mph |
|---|---|---|
| E exotic_01 Stinger 220 | 0 / 0 (13 taps, gear 3) | 0 (gear 7) |
| D exotic_02 Zephyr 390 | 0 / 0 (12 taps, gear 3) | 1 (gear 7) |
| C exotic_03 Aurora 540 | 0 / 0 (11 taps, gear 2) | 0 (gear 7) |
| B exotic_04 Endura 675 | 0 / 0 (8 taps, gear 2) | 0 (gear 7) |
| A exotic_05 Rosso 800 | 0 / 0 (7 taps, gear 2) | 0 (gear 6) |
| S exotic_06 Seraph 938 | 0 / 0 (8 taps, gear 1) | 0 (gear 6) |
<!-- END:churn -->

## 8. Spin envelope

Contract defaults:

<!-- BEGIN:spin_contract -->
| Car | hold W + lock from mph: max slip deg (never spins) | U-turn from 0 / 15 mph | lift-and-stab at 0 / 10 / 20 mph | power-brake (keyboard) | power-brake (touch) | gamepad slam at 10 mph | catch: yaw rate 0.3 s after a lift |
|---|---|---|---|---|---|---|---|
| E exotic_01 Stinger 220 | 0:13, 5:14, 10:15, 15:15, 20:16, 25:16 | 0:grip 16 deg L0.06, 15:grip 16 deg L0.05 | 0:grip 14 deg L0.06, 10:grip 15 deg L0.06, 20:grip 16 deg L0.02 | grip 14 deg L0.41 | grip 12 deg L0.21 | grip 15 deg L0.06 | 0.06 rad/s, L 0.00 |
| D exotic_02 Zephyr 390 | 0:14, 5:15, 10:16, 15:16, 20:17, 25:17 | 0:grip 16 deg L0.13, 15:grip 17 deg L0.11 | 0:grip 15 deg L0.13, 10:grip 17 deg L0.12, 20:grip 17 deg L0.05 | grip 18 deg L0.50 | grip 13 deg L0.25 | grip 17 deg L0.12 | 0.06 rad/s, L 0.00 |
| C exotic_03 Aurora 540 | 0:15, 5:16, 10:16, 15:16, 20:16, 25:16 | 0:grip 16 deg L0.11, 15:grip 16 deg L0.10 | 0:grip 16 deg L0.10, 10:grip 16 deg L0.10, 20:grip 16 deg L0.07 | grip 24 deg L0.67 | grip 14 deg L0.34 | grip 16 deg L0.10 | 0.09 rad/s, L 0.00 |
| B exotic_04 Endura 675 | 0:15, 5:15, 10:15, 15:15, 20:15, 25:15 | 0:grip 15 deg L0.33, 15:grip 15 deg L0.27 | 0:grip 15 deg L0.34, 10:grip 15 deg L0.33, 20:grip 15 deg L0.26 | grip 33 deg L0.84 | grip 15 deg L0.42 | grip 15 deg L0.33 | 0.11 rad/s, L 0.00 |
| A exotic_05 Rosso 800 | 0:13, 5:13, 10:13, 15:13, 20:13, 25:13 | 0:grip 13 deg L0.33, 15:grip 13 deg L0.26 | 0:grip 13 deg L0.36, 10:grip 13 deg L0.35, 20:grip 13 deg L0.25 | grip 30 deg L0.86 | grip 13 deg L0.43 | grip 13 deg L0.35 | 0.06 rad/s, L 0.00 |
| S exotic_06 Seraph 938 | 0:14, 5:14, 10:14, 15:14, 20:14, 25:14 | 0:grip 14 deg L0.04, 15:grip 14 deg L0.04 | 0:grip 14 deg L0.04, 10:grip 14 deg L0.04, 20:grip 14 deg L0.03 | grip 24 deg L0.82 | grip 14 deg L0.41 | grip 14 deg L0.04 | 0.06 rad/s, L 0.00 |
<!-- END:spin_contract -->

Proposed:

<!-- BEGIN:spin_proposed -->
| Car | hold W + lock from mph: max slip deg (never spins) | U-turn from 0 / 15 mph | lift-and-stab at 0 / 10 / 20 mph | power-brake (keyboard) | power-brake (touch) | gamepad slam at 10 mph | catch: yaw rate 0.3 s after a lift |
|---|---|---|---|---|---|---|---|
| E exotic_01 Stinger 220 | 0:26, 5:26, 10:26, 15:23, 20:17, 25:16 | 0:grip 25 deg L0.35, 15:grip 23 deg L0.35 | 0:**SPIN** 83 deg L0.80, 10:**SPIN** 95 deg L0.80, 20:**SPIN** 95 deg L0.76 | **SPIN** 85 deg L0.80 | grip 24 deg L0.40 | **SPIN** 95 deg L0.80 | 0.41 rad/s, L 0.00 |
| D exotic_02 Zephyr 390 | 0:27, 5:27, 10:27, 15:28, 20:18, 25:17 | 0:grip 26 deg L0.35, 15:grip 28 deg L0.35 | 0:**SPIN** 106 deg L0.83, 10:**SPIN** 106 deg L0.83, 20:**SPIN** 119 deg L0.81 | **SPIN** 92 deg L0.83 | grip 25 deg L0.42 | **SPIN** 106 deg L0.83 | 0.43 rad/s, L 0.00 |
| C exotic_03 Aurora 540 | 0:24, 5:24, 10:22, 15:21, 20:17, 25:16 | 0:grip 24 deg L0.35, 15:grip 21 deg L0.35 | 0:**SPIN** 107 deg L0.92, 10:**SPIN** 113 deg L0.92, 20:**SPIN** 157 deg L0.89 | **SPIN** 98 deg L0.92 | grip 24 deg L0.46 | **SPIN** 113 deg L0.92 | 0.50 rad/s, L 0.00 |
| B exotic_04 Endura 675 | 0:20, 5:20, 10:20, 15:19, 20:17, 25:16 | 0:grip 20 deg L0.35, 15:grip 19 deg L0.35 | 0:**SPIN** 106 deg L0.98, 10:**SPIN** 109 deg L0.98, 20:**SPIN** 150 deg L0.97 | **SPIN** 102 deg L0.98 | grip 21 deg L0.49 | **SPIN** 109 deg L0.98 | 0.42 rad/s, L 0.00 |
| A exotic_05 Rosso 800 | 0:16, 5:16, 10:16, 15:16, 20:15, 25:13 | 0:grip 16 deg L0.35, 15:grip 16 deg L0.35 | 0:**SPIN** 101 deg L1.00, 10:**SPIN** 102 deg L0.99, 20:**SPIN** 115 deg L0.98 | **SPIN** 99 deg L1.00 | grip 18 deg L0.50 | **SPIN** 102 deg L0.99 | 0.36 rad/s, L 0.00 |
| S exotic_06 Seraph 938 | 0:15, 5:15, 10:15, 15:14, 20:14, 25:14 | 0:grip 15 deg L0.35, 15:grip 14 deg L0.34 | 0:**SPIN** 102 deg L0.99, 10:**SPIN** 100 deg L0.99, 20:**SPIN** 101 deg L0.97 | **SPIN** 96 deg L1.00 | grip 17 deg L0.50 | **SPIN** 100 deg L0.99 | 0.36 rad/s, L 0.00 |
<!-- END:spin_proposed -->

The measured as-spawned Seraph (VEH-01 stats, PI 946), proposed:

<!-- BEGIN:seraph -->
| Car | 0-60 s today / new | 0-100 s | to 0.9 Vt s | mph at 10 s | mph at 15 s | top mph (60 s) | contract 0-100 if different |
|---|---|---|---|---|---|---|---|
| S exotic_06 Seraph (as spawned) 946 | 1.58 / 1.95 | 2.85 / 4.22 | 6.0 / 11.6 | 165 / 145 | 167 / 159 | 167.3 / 167.3 (-0%) | same |

| Car | hold W + lock from mph: max slip deg (never spins) | U-turn from 0 / 15 mph | lift-and-stab at 0 / 10 / 20 mph | power-brake (keyboard) | power-brake (touch) | gamepad slam at 10 mph | catch: yaw rate 0.3 s after a lift |
|---|---|---|---|---|---|---|---|
| S exotic_06 Seraph (as spawned) 946 | 0:14, 5:14, 10:14, 15:14, 20:14, 25:14 | 0:grip 14 deg L0.35, 15:grip 13 deg L0.34 | 0:**SPIN** 86 deg L0.96, 10:**SPIN** 78 deg L0.95, 20:grip 31 deg L0.70 | **SPIN** 95 deg L1.00 | grip 17 deg L0.50 | **SPIN** 78 deg L0.95 | 0.40 rad/s, L 0.00 |
<!-- END:seraph -->

## 9. Frame-rate spot check (proposed)

<!-- BEGIN:framerate -->
| Car | Hz | 0-100 s | to 0.9 Vt s | deepest frame cut / thrust-ms lost per upshift | run-on deg | tap shifts | drift radius | endless boost mph | max slip: hold 10 / stab 10 / power-brake |
|---|---|---|---|---|---|---|---|---|---|
| E exotic_01 Stinger 220 | 20 | 14.90 | 10.3 | 0.45 / 49.5 | 2.6 | 0 | 151 | 126.8 | 27 / 90 / 87 |
|  | 60 | 14.95 | 10.3 | 0.45 / 49.5 | 3.4 | 0 | 152 | 126.8 | 26 / 95 / 85 |
|  | 144 | 14.97 | 10.3 | 0.45 / 49.5 | 3.6 | 0 | 153 | 126.8 | 26 / 97 / 85 |
| C exotic_03 Aurora 540 | 20 | 8.10 | 9.2 | 0.45 / 49.5 | 2.7 | 0 | 157 | 140.4 | 22 / 112 / 101 |
|  | 60 | 8.13 | 9.3 | 0.45 / 49.5 | 3.6 | 0 | 157 | 140.4 | 22 / 113 / 98 |
|  | 144 | 8.13 | 9.3 | 0.45 / 49.5 | 3.9 | 0 | 157 | 140.4 | 23 / 114 / 98 |
| S exotic_06 Seraph 938 | 20 | 3.95 | 11.3 | 0.45 / 49.5 | 2.8 | 0 | 83 | 217.2 | 15 / 100 / 99 |
|  | 60 | 3.93 | 11.3 | 0.45 / 49.5 | 3.7 | 0 | 83 | 217.2 | 15 / 100 / 96 |
|  | 144 | 3.93 | 11.3 | 0.45 / 49.5 | 4.2 | 0 | 83 | 217.2 | 15 / 101 / 95 |
<!-- END:framerate -->

## 10. Feel dials (S Seraph)

<!-- BEGIN:dials -->
| S Seraph, proposed with one dial changed | 0-100 s | top mph (30 s) | deepest cut | run-on deg / turn-in s | brake 100-0 s | 2 s after lift mph | power-brake max slip | hold@10 max slip |
|---|---|---|---|---|---|---|---|---|
| today (no drivetrain) | 2.62 | 173.6 | - | 0.0 / 0.017 | 1.37 | 66 | 11 | 11 |
| FeelWeight 0 | 3.93 | 173.2 | 0.45 | 0.0 / 0.02 | 1.38 | 88 | 86 | 15 |
| FeelWeight 1 | 3.93 | 173.2 | 0.45 | 3.7 / 0.20 | 2.05 | 88 | 96 | 15 |
| FeelWeight 2 | 3.93 | 173.2 | 0.45 | 8.1 / 0.42 | 3.90 | 88 | 102 | 14 |
| FeelGearing 0 | 3.43 | 174.0 | 1.00 | 3.7 / 0.20 | 2.00 | 79 | 96 | 15 |
| FeelGearing 1 | 3.93 | 173.2 | 0.45 | 3.7 / 0.20 | 2.05 | 88 | 96 | 15 |
| FeelGearing 2 | 5.85 | 161.7 | 0.00 | 3.8 / 0.20 | 2.00 | 92 | 96 | 15 |
| FeelAcceleration 0.5 | 7.35 | 165.4 | 0.45 | 3.9 / 0.22 | 2.08 | 92 | 75 | 12 |
| FeelAcceleration 1.5 | 3.58 | 173.6 | 0.45 | 3.8 / 0.20 | 2.02 | 85 | 101 | 18 |
| FeelGrip 0.6 | 5.98 | 173.0 | 0.45 | 2.6 / 0.18 | 2.05 | 88 | 107 | 19 |
| FeelGrip 1.6 | 3.67 | 173.2 | 0.45 | 4.0 / 0.20 | 2.05 | 88 | 69 | 13 |
| FeelSpin 0 | 3.93 | 173.2 | 0.45 | 3.7 / 0.20 | 2.05 | 88 | 14 | 14 |
| FeelSpin 2.5 | 3.93 | 173.2 | 0.45 | 3.7 / 0.20 | 2.05 | 88 | 96 | 16 |
| FeelEngineBrake 0 | 3.93 | 173.2 | 0.45 | 3.7 / 0.20 | 2.12 | 91 | 96 | 15 |
| FeelEngineBrake 2 | 3.93 | 173.2 | 0.45 | 3.7 / 0.20 | 1.98 | 86 | 96 | 15 |
<!-- END:dials -->

## 11. Spin rule readings and FeelWeight independence

<!-- BEGIN:literal -->
| Spin reading | FeelWeight 1: max slip deg (75 = spin) | FeelWeight 0 | FeelWeight 2 |
|---|---|---|---|
| single yaw state as drafted: YawUnwindScale always on, kinematic blend below 15 mph also applied to the spin | E hold@0 14, U-turn@0 14, stab@10 41, pb 16; C hold@0 14, U-turn@0 14, stab@10 75, pb 23; S hold@0 14, U-turn@0 13, stab@10 82, pb 34 | E pb 11, S pb 22 | E pb 23, S pb 43 |
| single yaw state with two fixes: no unwind boost while L >= 0.1, spin keeps the state dynamic | E hold@0 25, U-turn@0 24, stab@10 109, pb 90; C hold@0 24, U-turn@0 24, stab@10 122, pb 100; S hold@0 15, U-turn@0 15, stab@10 102, pb 98 | E pb 15, S pb 44 | E pb 103, S pb 105 |
| recommended: additive r = r_steer + r_spin | E hold@0 26, U-turn@0 25, stab@10 95, pb 85; C hold@0 24, U-turn@0 24, stab@10 113, pb 98; S hold@0 15, U-turn@0 15, stab@10 100, pb 96 | E pb 72, S pb 86 | E pb 96, S pb 102 |
| recommended, but a stab is any rise from below 0.3 (no lift needed) | E hold@0 69, U-turn@0 69, stab@10 95, pb 85; C hold@0 95, U-turn@0 94, stab@10 113, pb 98; S hold@0 89, U-turn@0 89, stab@10 100, pb 96 | E pb 72, S pb 86 | E pb 96, S pb 102 |
<!-- END:literal -->

## Model notes

**Files** (all in `scripts/drivetrain_feel/model/`)

| File | What it holds |
|---|---|
| `today.py` | Today's equations, ported from `before/VehicleDynamics.lua` and `before/DrivingClient.lua` with every clamp. Config comes from `before/config.json`. |
| `drivetrain.py` | `CONTRACT_DEFAULTS` (section 4 verbatim), `MODEL_CONSTANTS`, `Settings` (dial mappings), `Profile` (`Model.DrivetrainProfile`), `Gearbox` (`Model.StepDrivetrain`, all nine section 5.2 fixes). |
| `vehicle.py` | The 2D heartbeat: DRIVE-01 intent, steer limiter, lateral grip, drift block, mini-boost, boost x share, yaw state, spin gestures and L. |
| `cars.py` | The six stock cars, the as-spawned Seraph, and the measured runs. |
| `scenarios.py` | Every run behind the tables. |
| `targets.py` | The CONTRACT 9 targets. |
| `sim.py` | Runs everything; `PROPOSED` and `RECOMMENDED_CODE` live here. |

**What is modelled**
- Flat ground, 2D.
- Forces are applied as accelerations, so mass cancels, as in DrivingClient:1086.
- Velocity is integrated per frame.
- The body follows `YawHeading` through the AlignOrientation, modelled as a first-order lag at `AlignResponsiveness` (22 x stability, about 40-45 ms).
- Lateral grip uses the body axes; drift alignment uses `YawHeading`, as `getTerrainFrame` does.

**What is not modelled**
- Hover, pose, wobble, slopes and collisions.
- Pitch and roll (visual only).
- Neutral revs, the countdown and the start grace. Runs assume the grace is over.
- `ImpactYawKick`, HUD, audio, and remote `GearForSpeed`.
- The unexplained coast loss.

**Dial mappings used** (the physics NOTES are authoritative)

| Dial | Effect in the model |
|---|---|
| `FeelWeight` (w) | Yaw `omega = YawOmega x clamp((118/W)^0.5, .75, 1.3) / max(w, 0.05)`; w < 0.05 gives kinematic yaw. Steer rise = `SteerRiseSeconds x w`; steer return = `SteerReturnRate / w` (finding 7). Grip lag = `GripRelaxStuds x w`. Brake = `lerp(today's brake, BrakeV2, w)`, with a floor of 0.2 BrakeV2. |
| `FeelGearing` (g) | Torque steps `p = GearTorqueExponent x g`. Cut time and blend time x g. Cut depth `1 - (1 - ShiftCutTorque) x g`, clamped 0..1. Rev-drop time `ShiftRpmSeconds x g`. |
| `FeelAcceleration` | x A1. `Kd` is re-derived, so Vt holds. |
| `FeelGrip` | x traction and x lateral cap. |
| `FeelSpin` | x L_t. |
| `FeelEngineBrake` | x `EngineBrakeDecel`. |

**Constants the contract does not name** (`MODEL_CONSTANTS`)
- Slide factor reaches `SlideGripFraction` at ws_eff 0.6.
- Braking downshift gap 0.2 s.
- Spin yaw gate `ss((|r| - 0.15) / 0.35)`.
- Yaw authority loss 0.85 L.
- Lateral curve B = 1/C.

**Profile build**
- Vt and Vb come from a 60-step bisection on today's forward-minus-aero equations.
- Upshifts on the limiter are always allowed.
- Engine braking applies only in gear ≥ 1 with fwdMph > 0 and no cut.
- Every resistive term is `-v / max(|v|, 0.8) x magnitude`.
- Auto-hold snap is blocked while L > 0.05 or horizontal speed > 4 studs/s.

**Scenarios** (keyboard unless stated)

| Scenario | Definition |
|---|---|
| Straight | W from rest for 60 s. |
| Braking | S held from min(100, 0.95 Vt) in the auto gear, until 1.5 mph. |
| Lift | 2 s with no input from the same speed. |
| Endless boost | Boost held for 60 s from Vt with the tank refilled every frame. |
| One tank | Boost from Vt until the tank empties. |
| Run-on | Hold 60 mph with an analog throttle. Hold D for 1.2 s, release, and measure the `YawHeading` change in the next 1.5 s. |
| Drift | Entry at 0.85 Vt; W + D + drift for 2 s; then 1.5 s straight on throttle. This is the driving_tune corner table. |
| Tap | W pressed below 39 mph (at least 0.15 s) and released above 41 mph. Shifts are counted over the last 10 s of 12 s. |
| Hold | D first, then W after 0.3 s, held 3 s from 0-25 mph. |
| U-turn | The same, until the heading has turned 180 deg. |
| Lift-and-stab | On throttle at the start speed, lift 0.2 s with D held, then W. From rest: W 0.35 s, lift 0.2 s, W. |
| Power-brake | W + S + D at a standstill for 0.6 s, then S released. |

A run **spins** when the slip angle (body heading against travel direction, above 3 mph) passes 75 deg.
