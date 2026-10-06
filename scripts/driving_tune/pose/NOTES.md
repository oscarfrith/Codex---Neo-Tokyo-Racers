# Driving tune, pose part: notes

Status: generated and anchor-checked (`py -3 scripts/driving_tune/build.py --part pose` passes). Not installed, not
run in Studio, not compiled (no local Luau compiler; block and bracket balance was checked by script and the Luau
was read back). Numbers below marked "sim" come from `sim.py`, not from Play.

## What was built

Ride height is now `rideHeight = HOVER_HEIGHT * settle + bankLift + bob`, owned by one new function in
`DrivingClient` (`updateHoverPose`, called once per frame just before the corner-spring loop) and mirrored in
`FreeRoamParkedHoverClient` (`updatePose`). Only the spring *target* moves. The four corner springs, their
stiffness and damping, and the raycasts are unchanged. Nothing reads the measured height after the first frame, so
the target cannot feed back into the springs.

### Settle (sinks at a stop, rises as you go)
- Target scale = `SettleRestScale` at a standstill, 1 at `SettleFullHeightMph`, smoothstep in between (a pure
  function of speed, no hysteresis).
- Throttle intent: pressing the throttle (or reverse from a near standstill) lifts the target straight to
  `SettleThrottleLift` of the way up, so the car powers up as you press, before it has moved. Braking does not
  lift.
- The target is followed by an under-damped spring (`SettleFrequencyHz` 1.3, `SettleDamping` 0.3), stepped
  semi-implicitly in sub-steps of at most 1/60 s with dt clamped to 0.1 s. That gives the sink a single soft
  bounce: sim shows the car going 0.09 studs below rest (14% of the 0.69 stud drop) and coming back, and a 2%
  overshoot on the way up.
- Rest height with the defaults: 2.3 x 0.7 = 1.61 studs (drop of 0.69).

### Bank lift (rise into the lean)
- At `Controller.Start` the visible parts (Transparency < 0.99) are walked once. Each part's box gives one
  candidate point (outer |x|, bottom y) in root space; the list is reduced to the points that are the lowest for
  some roll of 0, 4, ... 28 degrees (at most 8 points, usually 2 or 3). A high wide wing never enters the list.
  The result is written once to the vehicle as `HoverPoseProfile` ("x,y;x,y") and `HoverPoseHalfLength`.
- Per frame: `loss` = how far the lowest of those points drops at the current lean (bank + wobble roll) compared
  with level. Lift target = `loss * BankLiftAmount` (0.7), raised if needed so the lowest point keeps
  `MinEdgeClearanceStuds` above the ground (this term also counts pitch times the measured half-length and the
  lowered rest height, so steering at a standstill is covered), capped at `BankLiftMaxStuds`.
- The lean used looks `BankLiftLeadSeconds` ahead along the lean's own rate, so the car starts rising as you turn
  in rather than after. The target then goes through a critically damped spring that is quick going up
  (`BankLiftRiseHz` 4) and slow coming down (`BankLiftFallHz` 1.4): it rises into the lean and floats back. No
  overshoot in either direction, no pop.
- Bank angle is untouched.

### Corner springs against the bank (decision)
Today each corner target is the same, so when the car leans the low corners read short and push up while the high
corners read long. The AlignOrientation (infinite torque) wins, so the lean is reached, but the springs fight it
the whole time, and at 17 degrees the high-side springs clamp at zero force, which raises the car a little in an
uncontrolled way (the coordinator measured root height 2.0 to 2.3 in a drift: no useful lift).

Chosen: each corner's target is offset by where that corner *should* be for the commanded pose:
`target += offset.X * sin(lean) * cos(pitch) - offset.Z * sin(pitch)`, scaled by `LeanSpringCompensation`. At the
commanded lean all four springs are at rest, so they hold the same pose the align asks for and height is set only
by the ride-height target. The springs still resist any departure from the commanded pose, so terrain following
and landing behaviour keep today's stiffness. The alternative (compensating from the car's actual orientation)
was rejected because it removes all roll and pitch stiffness from the springs. No raycasts added. The four
offsets sum to zero, so `Feel.HoverSum` is still the mean compression against the current target.

### Wobble
Same owner (`updateHoverWobble`), same attribute names, new layers:
- a second, faster noise layer on pitch and roll (`WobbleDetailAmount`) so it never reads as a loop;
- vertical bob through the ride-height target (`WobbleBobStuds`, sine plus noise), never a CFrame write;
- a small slow yaw drift at idle only (`WobbleYawDegrees`), zero at speed;
- 30% more at a full stop (`WobbleRestBoost`);
- a trace kept at speed (`WobbleAtSpeedAmount` 0.15 of the idle size, running up to twice as fast), instead of
  fading to nothing. At the defaults that is about +-0.1 degree and under 0.01 stud, chosen to be felt rather
  than seen so the locked chase camera does not shake.
- Idle amount raised from 1.15 to 1.5 degrees (math.noise rarely exceeds +-0.5, so the real peak is about 1
  degree at rest).

### Parked hand-over
- The parked keeper uses the same settle function of speed and the same config, so both controllers agree on the
  rest height. An exit while coasting stays at full height and sinks as the coast drag slows it.
- At parked start it takes one reading of the four corners (once, not per frame) and seeds its settle state from
  the measured height, so there is no step at exit even when the car was mid-sink or raised by a lean. It then
  gets a small dip (`ParkedExitDipStuds`) as the power-down.
- It has the same wobble family at `ParkedWobbleScale` 0.7 and `ParkedWobbleSpeedScale` 0.85, including bob and
  yaw. No bank lift when parked: only the minimum-clearance term, using the car's real lean (still the driving
  bank for a moment after exiting mid-turn).
- Re-entry: `Controller.Start` clears the settle state and the first driving frame seeds it from the measured
  height. Wobble angles and bob start from zero and ease in through the existing smoothing.
- The anchored / `ParkedFixed` path is untouched apart from clearing pose state so it reseeds when unanchored.

### Anchored parked car (added after the first Play test)
The first Play test showed that a normal exit anchors the car on the server (`ParkedFixed`), so the spring keeper
never runs after the short `ExitCoasting` window: the car jumped from 1.63 to the server's 2.44 and sat still.
`FreeRoamParkedHoverClient` now also poses the local player's own anchored parked car:
- Runs from one `RunService.PreRender` connection for the module (second Play test: written on Heartbeat, the
  server's stale CFrame was drawn for one frame, a 1.28 stud hop). Heartbeat only hands over the own vehicle
  and keeps the remembered height current after physics. Springs advance once per rendered frame. While the car is anchored, `ParkedShowcase` is
  true, `DriverUserId` is nil and the seat is empty, it writes `root.CFrame` once per frame. Client-local only.
- Base = the server's anchored CFrame, captured at start. One ground ray at start and one per second after.
  Pose = base X/Z, Y = ground + the same `updatePose` ride height the keeper uses (settle to the rest height,
  exit dip, bob, minimum clearance), rotation = base rotation with wobble pitch, yaw and roll.
- No hop on exit: while the car is not anchored-parked, its world Y is remembered every frame (one property
  read). The height spring starts from that Y (if under 0.5 s old and within 4 studs of the base), not from the
  server's. If the spring keeper was running (moving exit), its pose table is taken over, so settle and wobble
  phase continue. Wobble starts at zero and eases in through the existing smoothing (about half a second).
- Stops writing in the same frame the car is no longer anchored-parked, the seat is occupied, the vehicle or
  root changes, or the config switch goes off (only then, and when it gives up, is the server's CFrame put back).
- If the root's CFrame is not the one written last frame, the server moved the car: that becomes the new base and
  the ground is re-read at once.
- Safety: Y is clamped to base - 2 .. base + 1.5, tilt to 0.05 rad and yaw to 0.03 rad, NaN is never written, a
  ground miss at start or a base outside 0.3 .. 2 x HoverHeightStuds above the ground leaves the car alone
  (retry every 0.5 to 1 s).
- `Controller.Stop` now clears the three debug attributes; `HoverPoseProfile` and `HoverPoseHalfLength` stay.

- Parked rest height (second Play test: parked sat at 1.77 to 1.80 against 1.64 driving). Cause: the parked
  minimum-clearance term used the car's real tilt against a single-ray ground normal times the box half-width
  and half-length (13 studs), so under a degree of base tilt added about 0.15. It now uses the commanded wobble
  roll and pitch, the same sum as the driving controller, and counts real tilt only beyond 2 degrees. Not
  re-run in Play.

## Config

Created by `INSTANCES`; each number has a `_RaisingThisDoes` string and each boolean a `_Description`. Both
scripts re-read the values four times a second into one reused table (cheaper than per frame, still live).

`Config.Vehicles.HoverPose`

| Attribute | Default | Raising it |
|---|---|---|
| SettleEnabled | true | Off: ride height stays at HoverHeightStuds. |
| SettleRestScale | 0.7 | Stopped car sits higher (1 = no lowering). |
| SettleStartMph | 1 | Car stays down for longer as it pulls away. |
| SettleFullHeightMph | 22 | Sink starts earlier when slowing, rise finishes later. |
| SettleFrequencyHz | 1.3 | Faster, tighter drop and bounce. |
| SettleDamping | 0.3 | Less bounce (1 = none). |
| SettleThrottleLift | 0.6 | More rise the moment the throttle is pressed (0 = speed only). |
| SettleThrottleDeadzone | 0.05 | Ignores light trigger presses. |
| BankLiftEnabled | true | Off: no lift and no minimum clearance. |
| BankLiftAmount | 0.7 | More lift in turns and drifts (0 = only the minimum clearance). |
| BankLiftMaxStuds | 2.4 | Allows more lift on very wide cars. |
| BankLiftLeadSeconds | 0.2 | Rise starts earlier on turn-in. |
| BankLiftRiseHz | 4 | Snappier rise. |
| BankLiftFallHz | 1.4 | Drops back sooner (lower = floats down). |
| MinEdgeClearanceStuds | 0.25 | Lifts sooner near the ground (0 = off). |
| LeanSpringCompensation | 1 | Springs hold the leaned pose (0 = as before). |
| ParkedExitDipStuds | 0.1 | Bigger dip on getting out (0 = none). |
| ParkedAnchoredPresentationEnabled | true | Off: the anchored parked car is left exactly where the server placed it. |
| DebugAttributes | false | Writes HoverPoseRideHeight / Settle / Lift on the vehicle each frame. |

`Config.Vehicles.HoverWobble`

| Attribute | Default | Raising it |
|---|---|---|
| WobbleEnabled | true | Off: no wobble, driving or parked. |
| WobbleAmountDegrees | 1.5 (was 1.15) | Rocks further. |
| WobbleSpeed | 1.15 | Quicker sway and bob. |
| WobbleFadeOutMph | 20 | Keeps the idle sway for longer when pulling away. |
| WobbleRandomiseAmount | 0.65 | More quick flutter. |
| WobblePitchMultiplier | 0.75 | Nods more. |
| WobbleRollMultiplier | 1 | Rocks side to side more. |
| WobbleSmoothing | 4.5 | Crisper motion. |
| WobbleDetailAmount | 0.6 | Stronger second layer (0 = old single layer). |
| WobbleBobStuds | 0.06 | Bobs further (0 = none). |
| WobbleYawDegrees | 0.35 | Nose wanders more at idle (0 = none). |
| WobbleRestBoost | 0.3 | More life when fully stopped (0 = none). |
| WobbleRestMph | 4 | Keeps the standstill boost while creeping. |
| WobbleAtSpeedAmount | 0.15 | More movement at speed (0 = fades out fully, as before). |
| WobbleAtSpeedSpeedBoost | 1 | Faster, finer at-speed trace. |
| ParkedWobbleEnabled | true | Off: parked cars hold still. |
| ParkedWobbleScale | 0.7 | Parked car moves more. |
| ParkedWobbleSpeedScale | 0.85 | Parked car moves quicker. |

Today's motion: `SettleEnabled` false, `BankLiftEnabled` false, `LeanSpringCompensation` 0, and in HoverWobble
`WobbleAmountDegrees` 1.15 with `WobbleDetailAmount`, `WobbleBobStuds`, `WobbleYawDegrees`, `WobbleRestBoost`,
`WobbleAtSpeedAmount` 0 and `ParkedWobbleEnabled` false. One small difference remains: the wobble smoothing is now
`1 - exp(-rate * dt)` instead of `clamp(rate * dt)` (0.072 against 0.075 per frame at 60 fps). Note that the code
fallbacks equal the new defaults, so deleting the folders does not turn the features off.

## Simulated numbers (`py -3 scripts/driving_tune/pose/sim.py`)

Body in the sim is the worst case measured on the Seraph: box corner 7.07 out and 1.15 below the root centre,
half-length 13.15. Real meshes are smaller than their boxes, so real clearance is larger.

| Case | 60 Hz | 30 Hz | 10 Hz |
|---|---|---|---|
| Brake 80 to 0: lowest height (rest 1.61) | 1.515 | 1.516 | 1.526 |
| Bounce below rest | 0.095 (14%) | 0.094 | 0.084 |
| Ripple 3 s after stopping | 0.0000 | 0.0000 | 0.0000 |
| Pull away: peak height (target 2.30) | 2.349 | 2.347 | 2.335 |
| Min clearance, brake and pull away (tail under 2.5 deg accel tilt) | 0.156 | 0.168 | 0.232 |
| 12 deg lean at rest: min clearance / peak lift | 0.237 / 1.23 | 0.222 | 0.167 |
| 17 deg lean at 80 mph with a flick to the other side: min clearance / peak lift | 0.546 / 1.41 | 0.546 | 0.546 |
| Peak root height in the drift | 3.71 | 3.71 | 3.71 |

Without lift the same box corner is 0.87 below ground at 17 degrees and 0.30 below at 12 degrees at a 2.3 ride
height (the coordinator's probe read 1.5 and 0.9 below; the difference is spring sag and where the probe sat).
Parked exit at rest: first-frame target step 0.019 studs at 60 Hz, dip to 1.53, back to 1.61. All runs finite and
settled; the settle and lift springs are stable at dt = 0.1 because of the sub-stepping.

## What to look at in Play

1. Brake from speed to a stop on flat ground: the car should sink about 0.7 studs over roughly half a second
   with one soft bounce. Too much bounce: raise `SettleDamping` (0.45). Too little: lower it (0.22). Sits too
   low or too high: `SettleRestScale`. Sink starts too late: raise `SettleFullHeightMph`.
2. Tap the throttle from rest: the car should rise at once. If that reads as twitchy on a gamepad trigger, lower
   `SettleThrottleLift` or set it to 0.
3. Full steer at a standstill and a full drift at speed, both sides, on the Seraph and on the widest Piercer and
   the Muscle: nothing should go underground, and the rise should read as part of the lean. First number:
   `BankLiftAmount` (0.7; lower if the car climbs too high, raise towards 1 if the low side still touches).
   Then `BankLiftLeadSeconds` (earlier or later rise) and `BankLiftFallHz` (how it comes back down).
4. Lean sign check, once: hold full steer at a standstill and flip `LeanSpringCompensation` between 0 and 1. The
   lean angle should not change and the car should be at least as steady at 1. If it shudders or leans less at
   1, the roll sign assumption is wrong and the two signs in the `targetDistance` lines need swapping.
5. Read `HoverPoseProfile` on a spawned car of each category. If a point is clearly not bodywork (an effect
   plane, a glow part), the lift will be too large for that car: say which part and it can be excluded.
6. Idle in the seat, then get out: sway and bob should carry on, a little calmer, with a small dip and no jump.
   Get out while still rolling: the car should stay up, then sink as it slows. Get back in: no jump.
7. Chase camera at idle and at speed: if the camera drifts or shimmers, set `WobbleYawDegrees` to 0 first, then
   `WobbleAtSpeedAmount` to 0.
8. Kerbs, ramps, jumps and landings with the lift active: the ride target is clamped to 2 x HoverHeightStuds
   (4.6) and the drift peak is about 3.7, so there is headroom, but this is where to look for anything odd.
   `DebugAttributes` true gives the live ride height, settle and lift for `verification.json`.

## Play results so far (coordinator, S-tier Seraph, first build)

Compiles, no errors. Rest: settle 0.70, root 1.59 to 1.76, roll +-1 degree. Pull away 0.83, 1.02, 1.0. Brake to a
stop dips to 0.63, then 0.73, 0.70. Standstill full steer: bank 12.0, real roll 12.3, lift 1.35, lowest point
0.32 to 0.46 above ground. At 80 to 90 mph: bank 10.9, roll 10.2, lift 1.05, clearance 0.95 to 1.3. The corner
compensation sign is confirmed. Those were with `BankLiftAmount` 0.8; the default is now 0.7. The anchored
presentation has not been run.

### To check for the anchored presentation
1. Stop, get out: no hop, a small dip, then calm sway and bob at about 1.6 studs. Before this the root jumped to
   2.44 and froze.
2. Get out while rolling: the keeper carries the car until the server anchors it; watch for a step in height or
   position at that moment (a sideways snap would be the server's stale position, not this code).
3. Get back in: no jump, driving starts from the pose on screen. Then drive off at once.
4. Leave it parked for a minute and watch from another client: the other client should see the car still (the
   pose is local). Check the owner's prompt, seat entry and any parked VFX still line up with a car that sits
   0.8 lower than the server thinks.
5. Flip `ParkedAnchoredPresentationEnabled` off while parked: the car should return to the server's placement.
6. Respawn or re-spawn the vehicle while parked, and park on a slope and on a kerb.

## Unsure

- Anchored presentation: it assumes a client write to a server-anchored part stays local and is not overwritten
  until the server changes the part, and that reading `root.CFrame` back returns what was written to within 0.02
  studs (otherwise it would re-capture the base every frame and the car would creep). Watch for creep.
- Anchored presentation: the car is drawn up to 0.8 studs lower on the owner's client than on the server, so
  anything the server positions against the car (prompts, collisions with other players) uses the higher pose.
- Anchored presentation: on re-entry it relies on the client keeping its local CFrame when the server unanchors
  and hands over ownership. If the car pops to the server's height at that moment, that is the cause.

- The roll sign in the corner compensation follows `CFrame.Angles` = Rx * Ry * Rz with +X as the car's right
  (item 4 checks it in a minute).
- The body profile is built from part boxes. MeshPart boxes overestimate, which is why `BankLiftAmount` is 0.7
  and not 1. Limits on the measurement: outer x at most root half-width + 6, bottom at most 1.5 below the root's
  underside, half-length at most root half-length + 12.
- A rise of about 1.4 studs on a 2.3 ride height in a full drift is large. It is what the measured body needs;
  whether it looks right is the owner's call, and `BankLiftAmount` is the dial.
- The minimum-clearance term uses the box tail (13 studs back, 1.15 down), so pulling away from rest adds a
  little lift under the acceleration tilt. If that looks like too much rise on launch, lower
  `MinEdgeClearanceStuds`.
- `HoverPoseProfile` and `HoverPoseHalfLength` are set by the client on the vehicle (same practice as the
  existing SlopeHover debug attributes).
- The parked keeper's minimum clearance reads the car's real orientation against last frame's ground normal. It
  only acts when the car is low, and goes through the same lift spring, but watch a parked car on rough ground.
