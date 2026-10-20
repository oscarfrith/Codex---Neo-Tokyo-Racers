1. **MAJOR: the `FeelGearing` dial does not reach the camera or the VFX.** `camerafx/after/DrivingCameraClient.lua:524-532`, `camerafx/after/VehicleVFXClient.lua:617-621`, `camerafx/NOTES.md:163`
   - **Why it is wrong:** CONTRACT 4.1 says `FeelGearing` scales the camera shift nod, and that dial 0 must reproduce today's feel for that aspect. The nod, the FOV pulse and the vent flame are sized only by `FeelShiftStrength`. The draft defines strength as 1 flat out and 0.3+0.7·thr otherwise, with no dial in it. So at `FeelGearing` 0 (smooth, no cut) every hard upshift still nods, pulses the FOV and fires the vent. NOTES assumes physics folds the dial into strength, but nothing in the contract or model requires that, so the dependency is unverified. This also undercuts Oscar's "easily tunable gearing feel".
   - **Fix (pick one):**
     - (a) Make it an explicit interface requirement in NOTES under "Requires from physics": `FeelShiftStrength = baseStrength × clamp(FeelGearing, 0, 1)`, so it is 0 when the dial is 0. The integrator confirms this against the physics after-file.
     - (b) camerafx reads the dial itself. On the existing config refresh (camera 0.25 s, VFX 0.5 s), resolve `Config.Vehicles.Drivetrain[vehicle:GetAttribute("CategoryId")]` and read `FeelGearing`. Multiply the nod and FOV velocity kicks (lines 529-531) and the vent strength (line 618) by `math.clamp(dial, 0, 1)`.
   - Either way, add a Play check: `FeelGearing` 0 gives no nod, no FOV pulse and no vent.

2. **MINOR: holding R lights the rear jets in reverse.** `camerafx/after/VehicleVFXClient.lua:700-701`
   - **Why it is wrong:** `loadDrive` is true in R (`FeelGear` −1). If physics publishes load from |throttle| in reverse (audio wants a loaded reverse note), the main jets fire while reversing. Today `FeelThrottle` −1 clamps to 0, so they never do.
   - **Fix:** gate on the gear:
     ```lua
     local gearNow = load ~= nil and feelNumber(model, "FeelGear") or nil
     local neutral = gearNow == 0
     local loadDrive = gearNow ~= nil and gearNow >= 1
     ```

3. **MINOR: a very short thrust release turns the jets fully on and off on every cut.** `camerafx/after/VehicleVFXClient.lua:711`, `camerafx/config.py:61-62`
   - **Why it is wrong:** at `DrivetrainThrustReleaseSeconds` ≤ 0.001, `smoothToward` returns the target. Each cut then drops `feel.Throttle` to 0, below `FeelThrottleCutoff`. V2 sets `EngineThrust` objects `Enabled=false`, and `state.Accelerating` flips the by-name EngineOn/EngineOff objects. On the limiter that is hard on/off flashing at about 13 Hz, which CONTRACT 8 and critique 17 forbid. The config string advertises 0 as a valid setting.
   - The same toggling happens at the default 0.15 when throttle is about 0.15 or less on the limiter (0.15 × 0.64 < 0.1).
   - **Fix:** in code, use `math.max(feelConfig.DrivetrainThrustReleaseSeconds, 0.08)`. After line 713 add `if loadDrive and throttle == 0 and (feelNumber(model, "FeelThrottle") or 0) >= feelConfig.FeelThrottleCutoff then throttle = feelConfig.FeelThrottleCutoff end`. Reword the string so it no longer says "0 dips instantly".

4. **MINOR: the yaw cap does not hold at spin onset.** `camerafx/after/DrivingCameraClient.lua:623`
   - **Why it is wrong:** the limit is `1.5 / max(spinBlend, 0.02)`, and `spinBlend` is near 0 when spin mode starts. The cap is about 44 rad/s at 16 ms, 5.8 at 50 ms and 2.0 at 100 ms. So for about the first 0.1 s the camera keeps turning at the car's rate. The contract caps it at 1.5 rad/s in spin mode, and the builder's summary says only that the cap relaxes on ease-out.
   - **Fix:** `local limit = number("ChaseSpinYawRateMax", 1.5, 0.05, 20) / (chase.SpinActive and 1 or math.max(spinBlend, 0.02))`. Alternatively, keep it and state in NOTES that the cap phases in over `ChaseSpinEaseInSeconds`.

5. **MINOR: the ease-out can flip sides when the car ends near 180°.** `camerafx/after/DrivingCameraClient.lua:616` (NOTES risk 6)
   - **Why it is wrong:** the blend is wrapped around the fixed `SpinHold`. When the heading relative to `SpinHold` crosses ±π, the target jumps by 2π(1−b) and the camera reverses direction mid-ease.
   - **Fix:** unwrap both ends against the moving camera yaw:
     ```lua
     local normal = chase.Yaw + wrapAngle(yawTarget - chase.Yaw)
     local hold = chase.Yaw + wrapAngle(chase.SpinHold - chase.Yaw)
     yawTarget = hold + (normal - hold) * (1 - spinBlend)
     ```

6. **MINOR: two knobs do nothing on Exotic V2 cars, and several config strings are wrong.** `camerafx/config.py:26-27, 67-68, 85-86, 89-90, 95-96, 99-100`
   - **`SpinDustLevel` and `ThrustSlipDustLevel` have no effect on Exotic V2.** They raise `state.HoverDust`. Live `VehiclePreviewVFXClient.updateV2` (lines 1474-1483) computes `V2GroundDust` from `ExoticV2Dust*` whenever a Feel table is passed, and the V2 hover emitters carry `VFXGroup` channels such as `V2HoverPad` on PadDisc. Exotic is the only class in scope.
   - **The surge size cannot be tuned through the burst counts.** `Burst("Dust")` sets `LandPulse = clamp(count/28, 0.3, 1)`, so any count from 1 to 8 gives the same 0.3 surge. The ring starts at about 6.
   - **`ChaseSpinEaseOutSeconds`** says the camera is "still capped by ChaseSpinYawRateMax". It is not: the cap block only runs while `spinBlend > 0`.
   - **`ShiftVentPopStrength`:** the flame tongue needs `PopStrength × shift strength ≥ 0.8`, not `PopStrength ≥ 0.8`.
   - **Fix:** mark the two dust rows "no effect on Exotic V2 cars", or drop them. Reword the count, ease-out and pop-strength strings to match the code.

7. **MINOR: thrust-follows-`FeelLoad` has no switch of its own.** `camerafx/after/VehicleVFXClient.lua:699`, `camerafx/config.py`
   - **Why it is wrong:** critique_delivery item 10 lists it as its own switch. Today only `DrivetrainVFXEnabled` turns it off, and that also kills the vent, stutter, wash and strain.
   - **Fix:** add `DrivetrainThrustLoadEnabled = 1` to `FEEL_DEFAULTS` and to config.py (with its `_RaisingThisDoes` string). Use `local loadDrive = load ~= nil and not neutral and feelConfig.DrivetrainThrustLoadEnabled >= 0.5`.

8. **MINOR: the rear over-glow is not delivered on Exotic V2, and the wash can cut a landing surge short.** `camerafx/after/VehicleVFXClient.lua:931-937`, `camerafx/NOTES.md:201-204`
   - **Why it is wrong:**
     - CONTRACT 8 asks for a rear over-glow on `FeelThrustSlip`. What ships is a hover-jet surge under every engine plus dust.
     - `Burst("Dust")` assigns `LandPulse` rather than taking the max. A wash burst within about 0.25 s of a real landing cuts that landing's surge from up to 1 down to 0.3.
   - **Fix:** the integrator records the over-glow gap as an accepted deviation in `verification.json` or the contract. Space wash bursts away from landings, for example skip the wash for 0.3 s after a `FeelLandRevision` change, using the existing `feel.LastLandBurst`.

9. **MINOR: spin mode and the stabiliser stutter also trigger on the catchable wiggle.** `camerafx/config.py:20-21, 75-76` (NOTES risk 5)
   - **Why it is wrong:** both enter at `FeelSpin` 0.2, but held cases reach `SpinHoldCap` 0.35. So an ordinary low-speed full-lock turn can freeze the camera heading and pulse the jets. That conflicts with the "U-turn without a spin" target.
   - **Fix:** the integrator decides this in the Play matrix. If the wiggle shows, set `ChaseSpinEnterLevel` and `SpinStutterMinSpin` just above `SpinHoldCap` (0.4). Keep 0.2 only if the physics model shows held turns stay under 0.2.

Verdict: READY WITH FIXES

The compile check in PR98 Edit passed for both after files (`DrivingCameraClient: OK 46274 | VehicleVFXClient: OK 47621`), and the after-file hashes in NOTES match. The physics part's files were not in the delivery folder yet, so items 1 and 2 could not be checked against what physics actually writes. Files reviewed: `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\camerafx\after\DrivingCameraClient.lua`, `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\camerafx\after\VehicleVFXClient.lua`, `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\camerafx\config.py`, `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\camerafx\NOTES.md`.