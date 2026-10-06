# Driving tune: balance part

Evidence label for everything here: **generated** (source edits and an offline model). Nothing is installed and
nothing was measured in Play by this part. `py -3 scripts/driving_tune/build.py --part balance` passes (anchors
apply once each); the Luau was read back by eye, there is no local compiler.

Files: `edits.py` (the delivery), `model.py` (the evidence), `after/*.lua` (build output, for reading).

## What was built

`VehicleDynamics` gains `Model.Balance(vehicle)` and `Model.ComputeBalance(config, index)`.

- `Balance` reads the vehicle attribute `PerformanceIndex`, and returns a frozen table of multipliers, 1 = unchanged:
  `TopSpeed, Acceleration, Braking, Reverse, Drag, Boost, MiniBoost, Steering, Grip, DriftSideForce, DriftTurn,
  DriftEngineAssist, DriftAlignment, DriftCharge` (plus `Enabled, PerformanceIndex, BaseNerf`).
- Cost: one attribute read and one `os.clock()` per call. The table is reused until the vehicle, its
  PerformanceIndex or `BalanceRefreshSeconds` (0.25 s) changes, so the 34 config reads happen four times a second,
  not per frame, and a config edit in Play reaches the car within a quarter of a second.
- Curve: `alpha = clamp((PI - 200) / (900 - 200), 0, 1)`, blended half way to a smoothstep, then
  `base = 0.10 + 0.15 * alpha`. Continuous, never decreasing, flat below 200 and above 900. No tier steps. The
  largest change of any multiplier for +1 PI is 0.00034.
- Each channel is `(1 - base * BaseShare) * (1 - extra * ExtraShare)`, clamped 0.1 to 1.5.
- `BalanceEnabled` 0 returns a constant table of ones. Every use is a plain `* multiplier`, and `x * 1` is exact,
  so that is a behavioural rollback without a script change.

Where the multipliers are applied:

| Multiplier | Applied in | To |
|---|---|---|
| Acceleration, Braking, Reverse, Drag | `VehicleDynamics.StepLongitudinal` | forwardAcceleration, brakeAcceleration, reverseAcceleration, aeroAcceleration |
| Grip, DriftSideForce, DriftTurn, DriftCharge, DriftEngineAssist, DriftAlignment | `VehicleDynamics.StepHandling` | normalGrip (not drift grip) and the result fields of the same names (alignment: rate and max) |
| TopSpeed | `DrivingClient` line 824 | `maxMph` (the cap passed to StepLongitudinal) |
| Boost | `DrivingClient` line 1094 | held boost push |
| MiniBoost | `DrivingClient` line 1101 | drift mini-boost push (both the stat-scaled and the legacy branch) |
| Steering | `DrivingClient` line 1122 | `turnRate` (so drifting and reversing too) |
| Acceleration, Reverse | `DrivingClient` after line 843 | the legacy locals `acceleration` and `braking`, used only when `Dynamics.Enabled` is false |

`StepLongitudinal` and `StepHandling` call `Model.Balance(vehicle)` themselves (their call sites in DrivingClient
are outside this part's regions); the cache makes that free. DrivingClient calls it once after `ResolveStats`, as
the contract says. No `typeof` guard on that call: both scripts are installed and rolled back together.

Debug attributes, behind the existing `Dynamics.DebugAttributes`, written only when the value changes:
`DynamicsBalanceBaseNerf, DynamicsBalanceTopSpeed, DynamicsBalanceAcceleration, DynamicsBalanceBraking,
DynamicsBalanceDrag, DynamicsBalanceSteering, DynamicsBalanceDriftTurn, DynamicsBalanceMiniBoost`.

Existing debug attributes keep their meaning as "the value applied": `DynamicsLongitudinalAcceleration`,
`DynamicsAeroAcceleration`, `DynamicsLateralGrip`, `DynamicsNormalGrip`, `DynamicsDriftEngineAssist` and
`DynamicsDriftVelocityAlignmentRate` now show the nerfed value. `DynamicsMappedTopSpeedMph` still shows the mapped
cap before balance (320 on the Seraph); the balanced cap is that times `DynamicsBalanceTopSpeed`.
`DriftMiniBoostAcceleration` is still the reward before `DriftMiniBoostForceApplicationMultiplier` and before balance.

## Three findings that shaped it

1. **Top speed is set by air drag, not by the mapped cap.** `AerodynamicDragPerMphSquared` is 0.2 in config but
   clamps to 0.002, `BaseForwardAcceleration` 90 clamps to 80, and the result is that every car stops accelerating
   far below its cap (Seraph: cap 320, real about 223; Forge: cap 254, real 113). Scaling the cap alone would
   have done nothing for E to C. So `Drag = Acceleration / TopSpeed^2` (`BalanceDragCoupling` 1): drag-limited
   speed goes as sqrt(acceleration / drag), so real top speed falls by exactly the top speed multiplier and the
   acceleration curve keeps its shape, just scaled. With coupling 0 the acceleration nerf alone would take top
   speed down 12.5% (E) to 20% (S) and the two could not be tuned apart. Side effect: drag is 0.94x at E (a
   little less) and 1.13x at S; it also acts when coasting and braking, a small effect.
2. **Boost ignores the cap.** Giving boost the same multiplier as acceleration (base and the 15% extra) keeps
   the boosted top speed falling by the same share as the normal one (table below). With the extra share at 0,
   boost would be relatively stronger after the nerf than before.
3. **The drift side force pushes the car outwards** (`right * -steeringInput`): it makes the slide, it does not
   make the corner. Nerfing it 20% extra would have tightened drifts. What makes drifting strong is the yaw
   bonus (1.6x to 2.3x the normal turn rate), the 0.7 engine assist, the velocity alignment, and the mini-boost.
   So the 20% goes on those, and the side force only follows the base nerf (keeps the slide angle as speeds drop).

## Config: `ReplicatedStorage.Config.Vehicles.Dynamics.08_Balance`

All numbers, each with a `_RaisingThisDoes` string. Clamps in brackets.

| Attribute | Value | Why |
|---|---|---|
| BalanceEnabled [0, 1] | 1 | Switch. 0 = all ones. |
| BalanceLowPerformanceIndex [0, 2000] | 200 | Slowest real cars (stock E is 200 to 220). |
| BalanceHighPerformanceIndex [0, 2000] | 900 | Stock S is 925 to 946, so all S stock cars get the full 25%. |
| BalanceLowNerf [0, 0.6] | 0.10 | Oscar: E 10%. |
| BalanceHighNerf [0, 0.6] | 0.25 | Oscar: S 25%. |
| BalanceCurveEase [0, 1] | 0.5 | 0 straight line, 1 smoothstep. Half: no kink at the ends, still gradual in the middle. |
| BalanceFallbackPerformanceIndex [0, 2000] | 525 | Used when the attribute is missing: mid C, 16.8%. |
| BalanceRefreshSeconds [0, 5] | 0.25 | How often the multipliers are recomputed. |
| BalanceAccelBrakeExtraNerf [0, 0.6] | 0.15 | Oscar: acceleration and braking 15% more. |
| BalanceDriftExtraNerf [0, 0.6] | 0.20 | Oscar: drifting 20% more. |
| BalanceDragCoupling [0, 1] | 1 | Finding 1. |
| BalanceTopSpeedBaseShare | 1 | Full base nerf. |
| BalanceAccelerationBaseShare / ExtraShare | 1 / 1 | Full base, full 15%. |
| BalanceBrakingBaseShare / ExtraShare | 1 / 1 | Full base, full 15%. |
| BalanceReverseBaseShare / ExtraShare | 1 / 0 | Base only: reverse is already weak (12 against 80 forward). |
| BalanceBoostBaseShare / ExtraShare | 1 / 1 | Finding 2. |
| BalanceSteeringBaseShare | 0.4 | 4% at E, 10% at S. Lower speeds already tighten every corner; a full share made S feel dead in the model (grip-turn radius is still 16% tighter after, because speed fell more than yaw). |
| BalanceGripBaseShare | 0.25 | 2.5% at E, 6% at S on normal grip only. Drift grip is left alone (lowering it is what makes a boat). |
| BalanceDriftSideForceBaseShare / ExtraShare | 1 / 0 | Finding 3. |
| BalanceDriftTurnBaseShare / ExtraShare | 0 / 1 | The drift yaw bonus takes the full 20% (on top of the steering share). Drift radius +16% at E, +20% at S. |
| BalanceDriftEngineAssistBaseShare / ExtraShare | 0 / 1 | 0.7 becomes 0.56. It multiplies the already nerfed acceleration, so no base share. |
| BalanceDriftAlignmentBaseShare / ExtraShare | 0.5 / 1 | Rate and max. The max is an absolute acceleration, so it takes half the base as well. |
| BalanceDriftChargeBaseShare / ExtraShare | 0 / 0.5 | 10% slower charge. The reward itself is already cut; a full share on both would double count. |
| BalanceMiniBoostBaseShare / ExtraShare | 1 / 1 | Mini-boost push 0.72x at E, 0.60x at S. Duration unchanged. |

All shares clamp to [0, 2].

Multipliers that result:

| PI | base | TopSpeed | Accel, Brake, Boost | Reverse, DriftSideForce | Drag | MiniBoost | Steering | Grip | DriftTurn | DriftEngineAssist | DriftAlignment | DriftCharge |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 200 (E) | 0.100 | 0.900 | 0.765 | 0.900 | 0.944 | 0.720 | 0.960 | 0.975 | 0.800 | 0.800 | 0.760 | 0.900 |
| 375 (D) | 0.130 | 0.870 | 0.739 | 0.870 | 0.978 | 0.696 | 0.948 | 0.967 | 0.800 | 0.800 | 0.748 | 0.900 |
| 525 (C) | 0.168 | 0.832 | 0.707 | 0.832 | 1.022 | 0.665 | 0.933 | 0.958 | 0.800 | 0.800 | 0.733 | 0.900 |
| 662 (B) | 0.204 | 0.796 | 0.676 | 0.796 | 1.068 | 0.636 | 0.918 | 0.949 | 0.800 | 0.800 | 0.718 | 0.900 |
| 787 (A) | 0.233 | 0.767 | 0.652 | 0.767 | 1.108 | 0.614 | 0.907 | 0.942 | 0.800 | 0.800 | 0.707 | 0.900 |
| 900+ (S) | 0.250 | 0.750 | 0.637 | 0.750 | 1.133 | 0.600 | 0.900 | 0.938 | 0.800 | 0.800 | 0.700 | 0.900 |

## Model and validation

`model.py` ports `ResolveStats`, `StepLongitudinal`, `StepHandling` and the heartbeat force sum (grip, drift,
mini-boost, boost, turn rate) with the live config through the same clamps. Flat ground, 2D, yaw applied directly.

Validation against the integrator's measured Seraph run (S, PI 946, balance off, 60 Hz): the port gives 14, 30,
49, 64, 79, 92, 105, 120, 129, 141, 150, 159, 166, 173, 180, 186, 190, 194, 198, 202, 205, 207 mph against the
measured 17, 34, 50, 65, 80, 94, 107, 120, 131, 142, 151, 160, 167, 174, 181, 186, 191, 195, 199, 202, 205, 207.
Largest difference 4 mph, in the first half second (the real car launches slightly harder); from 0.8 s on it is
within 2 mph. Mapped cap 320, as the live attribute says.

**Not reproduced: coasting.** Measured 34 to 16 mph in 1.6 s; the port gives 34 to 26. The code's coast
deceleration (3.2 + 0.06 x speed, plus drag) is about 4 mph/s at that speed and the car lost 11 mph/s. Something
outside `StepLongitudinal` slows a coasting car (not found in the drive loop; a slope, hover contact or the
physics engine are candidates). The balance does not touch coasting, but the braking distances below may be a
little long for the same reason.

Stock stats are the six `BalancedStockProfiles` (Piercer) from `roblox/captures/exotic-before/capture.json`, plus
the live Seraph. That capture is Backup v2 from 2026-10-02.

### Straight line, before / after

| Car | Real top mph | 0-60 s | 0-100 s | To 98% of top s | Brake 100-0 s | Brake 100-0 studs | Top after one boost mph |
|---|---|---|---|---|---|---|---|
| E 200 Forge | 113 / 102 (-10%) | 1.85 / 2.49 | 4.27 / 8.32 | 7.0 / 8.3 | 2.43 / 3.06 | 176 / 217 | 131 / 116 (-11%) |
| D 375 Vector | 121 / 105 (-13%) | 1.61 / 2.25 | 3.42 / 6.31 | 6.6 / 7.8 | 2.26 / 2.90 | 164 / 206 | 143 / 123 (-14%) |
| C 525 Viper | 135 / 112 (-17%) | 1.34 / 1.97 | 2.63 / 4.62 | 6.3 / 7.4 | 1.89 / 2.52 | 141 / 183 | 161 / 132 (-18%) |
| B 662 Nightline | 170 / 135 (-20%) | 1.06 / 1.61 | 1.92 / 3.16 | 6.4 / 7.5 | 1.50 / 2.11 | 115 / 157 | 200 / 158 (-21%) |
| A 787 Rally | 210 / 161 (-23%) | 0.92 / 1.44 | 1.60 / 2.63 | 7.0 / 8.2 | 1.14 / 1.69 | 89 / 130 | 248 / 188 (-24%) |
| S 925 Zenith | 231 / 174 (-25%) | 0.92 / 1.46 | 1.57 / 2.62 | 7.6 / 9.0 | 0.89 / 1.37 | 70 / 106 | 283 / 212 (-25%) |
| S 946 Seraph (live) | 223 / 167 (-25%) | 0.98 / 1.57 | 1.70 / 2.85 | 7.9 / 9.4 | 0.96 / 1.45 | 75 / 113 | 292 / 217 (-25%) |

- The E and D 0-100 times nearly double because 100 mph is now almost their top speed (102 and 105). 0-60 is the
  fair comparison there: +35% at E, +59% at S. That is the request taken literally (base x 0.85 on acceleration).
- Braking time from 100 mph: +26% at E to +53% at S.
- Order kept: tops after are 102, 105, 112, 135, 161, 174 (E to S). 0-60 never gets slower going up a tier
  (A 1.44, S 1.46: these two were level before, 0.92 each).
- Sweep every 5 PI from 150 to 1000 with stats interpolated between the stock cars: largest top speed step
  1.9 mph per 5 PI (2.7 before), no jump anywhere. One stretch (PI about 800 to 880, where the stock A and S
  stats are close) loses at most 0.17 mph per 5 PI. Not noticeable, but it is not zero: any curve on PI means
  a car that gains PI without gaining speed or engine (drift parts, say) gets up to 0.03% slower per point.

### Corner: 2 s of full steer on throttle, entered at 85% of own top speed (before -> after)

| Car | Grip radius studs | Drift radius studs | Drift path turned deg | Drift peak yaw deg/s (grip yaw after) | Peak slip deg | Speed 1.5 s after release, as a share of entry |
|---|---|---|---|---|---|---|
| E 200 | 186 -> 157 | 120 -> 138 (+16%) | 127 -> 101 | 89 -> 71 (57) | 35 -> 31 | 1.05 -> 1.00 |
| D 375 | 198 -> 160 | 123 -> 134 (+9%) | 134 -> 108 | 96 -> 75 (58) | 34 -> 29 | 1.06 -> 1.02 |
| C 525 | 223 -> 172 | 135 -> 138 (+3%) | 139 -> 114 | 95 -> 79 (57) | 30 -> 27 | 1.11 -> 1.06 |
| B 662 | 262 -> 213 | 134 -> 147 (+10%) | 166 -> 126 | 104 -> 86 (54) | 31 -> 26 | 1.10 -> 1.06 |
| A 787 | 282 -> 239 | 102 -> 119 (+16%) | 229 -> 167 | 158 -> 119 (56) | 42 -> 33 | 0.96 -> 0.96 |
| S 925 | 278 -> 233 | 65 -> 79 (+20%) | 305 -> 227 | 195 -> 155 (61) | 49 -> 40 | 0.85 -> 0.80 |
| S 946 Seraph | 272 -> 227 | 65 -> 78 (+20%) | 298 -> 223 | 193 -> 152 (60) | 48 -> 39 | 0.84 -> 0.80 |

- Drifts are wider by up to 20% while every car is 10 to 25% slower, so a drift corner costs the base nerf plus
  up to 20% more. Drift is still clearly tighter than grip at every tier (E 138 against 157, S 79 against 233),
  so it stays worth using. Slip angle goes down slightly, not up: no extra boat feel in the model.
- With `BalanceDriftTurnExtraShare` 0.5 the drift radius did not grow at all at E and S (lower speed cancelled
  the yaw cut), which is why it is 1.
- A 2 s S-tier drift still turns the path through 227 degrees. Drifting at S stays very strong after this; the
  20% is a guideline hit, not a redesign. `BalanceDriftTurnExtraShare` is the knob (clamp allows up to 2).

## What to check in Play

1. Vehicle attributes on an S car: `DynamicsBalanceBaseNerf` 0.25, `DynamicsBalanceTopSpeed` 0.75,
   `DynamicsBalanceAcceleration` 0.6375, `DynamicsBalanceDrag` 1.133. On an E car 0.10, 0.90, 0.765, 0.944.
2. Seraph full throttle: expect about 60 mph at 1.6 s, 100 at 2.85 s, about 167 mph real top (was heading for
   about 223; the 207 measured before was not yet the top). Boost from there: about 217.
3. Set `BalanceEnabled` to 0 during Play: within a quarter second the car is the old car. Back to 1.
4. Drift both ways at E and at S: still turns in clearly tighter than steering, slide angle looks the same,
   exit mini-boost is weaker. If E drift feels pointless, lower `BalanceDriftTurnExtraShare` first.
5. S steering at speed: if it feels dead, lower `BalanceSteeringBaseShare` (0 = steering untouched).
6. Reverse, brake to a stop, steer at a standstill: unchanged logic, only weaker reverse and brake push.
7. Camera, FOV, speed lines, engine audio: anything that scales by speed over top speed. This part does not
   change `dynamicsStats.TopSpeed` (only `maxMph`), so those keep their old reference and will read "slower".
   `DynamicsMappedTopSpeedMph` is also unchanged. Decide whether that is wanted.

## Unsure, and risks

- **No Luau compiler.** Read back by eye. `Model.Balance` uses `table.freeze`, `os.clock`, `+=`; all standard Luau.
- **Config cache.** `08_Balance` must exist with all its numeric attributes before the first drive frame, or the
  readers' one-time name cache misses them and the code defaults apply (same values as this config, so the nerf
  would still be on, but live edits would do nothing until the next session). `BalanceEnabled` set to 0 in a
  folder created after the cache was built would also be ignored.
- **Coast mismatch** above: unexplained.
- **Harshness.** 0-60 on S cars goes from 0.9 s to 1.5 s and top speed from about 230 to 174. That is what the
  percentages say; `BalanceHighNerf` and `BalanceAccelBrakeExtraNerf` are the two knobs if it is too much.
- **Garage ratings and the HUD** are untouched by design, so a car's rating now overstates what it does on the road.
- **Other clients.** The multipliers run on the driving client only (as all driving forces do). Nothing replicated
  changes except the new debug attributes, and those are set from the client, so they do not replicate.
- Reverse top speed (`Driving.ReverseMaxMph` 40) is not scaled.
- Boost duration, recharge and mini-boost duration are not scaled.
- The legacy path (`Dynamics.Enabled` false) gets top speed, acceleration, reverse, boost, mini-boost and steering
  only; not modelled.
- Exotic and Muscle stock stats were not modelled apart from the Seraph; they share the same code path.
