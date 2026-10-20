**PR98 gearbox, weight, spin-out, sound and HUD plan: review for player experience, audio and HUD feasibility**

Everything was read-only: live PR98 Studio, the repo and the six survey reports. Line numbers are from live Studio unless a repo path is given.

## Issues

1. **BLOCKER: the speed gauge has no room for new parts.**
   - Evidence: `Kit.Gauge` lines 192-241 build exactly the budgeted set. `scripts\ui_restyle\phase2\kit\k3\NOTES.md` line 38 says "Total is exactly 26", and `API2.md` line 287 says "Budget 26". Live it is 27, because `Kit.Text.RawLabel` (lines 404-410) adds a `SizeLock` under `BoostText` (role Value).
   - The plan's gear readout adds about 5 parts: a BigNumber gear (root plus 1 cell), a Text label for N/R (plus its `SizeLock`) and a `UIScale`. That makes about 32. The plan's "well under the 26-instance limit" is wrong.
   - `API2.md` line 289 also says the gauge has no frame binding, so the punch and the flashing light have no clock.
   - Fix:
     - Add an `API2_AMENDMENTS` entry that raises the budget to 28 and lists the exact new parts.
     - Use one gear TextLabel, and do the punch by writing `TextSize`, so no `UIScale` is needed.
     - Add `Gauge.Step(dt)`, called from `HudView.Step`.
     - Add new states to `Dev.Fixtures.Gauge` and the k3 tests, and get reviewer sign-off.

2. **MAJOR: the shift light has nowhere legal or visible to show.**
   - Tinting the ticks breaks the rules. `API2.md` line 19 says the gauge images are "baked colour, never tinted", and the style sheet line 144 says `ImageColor3` stays white.
   - The tip is the only part that may be tinted, and it is 0.09 × 92 ≈ 8 dp on a phone, so nobody will see it there.
   - A 0.15 s lead with an 8 Hz flash gives about one blink before the shift.
   - Nothing stops it flashing before relaxed upshifts at 0.45 of redline (DRIVE never flashes below about 0.62 of redline).
   - Fix:
     - Show the shift light on the gear readout's colour (cyan to pink, 1 write per toggle) plus the tip.
     - Use a lead of 0.25-0.3 s, and flash only when the planned upshift is at 0.85 of redline or higher.
     - Never change the BigNumber colour: `Set({Colour})` calls `renderAll`, which rewrites every cell (BigNumber lines 364-386 and 422-449).

3. **MAJOR: a long boost at speed bounces the engine off the limiter in top gear.**
   - Top gear runs out at 1.06 × the drag-limited top speed (184 mph on an S car), but the boosted top speed is kept at about 214 mph. That is 1.16 × redline in top gear.
   - Through every long boost the limiter cut sets off the audio stutter, the HUD limiter strobe, the camera shimmer and the thruster dip.
   - The boost-share fade is worked out from top-gear thrust at 214 mph, which ignores that the limiter is cutting drive there. So the real boosted top speed would come out below the target.
   - Fix: while boost thrust is on, hold engine speed at 1.0-1.02 × redline with no cut. Make that an "OVERDRIVE" state: the arc goes into the red, a reactor scream plays, and the HUD shows boost colour. This fits the nitro moment in the Redline clip. Then redo the boost-share fade with that rule.

4. **MAJOR: the plan goes over the audio voice budget.**
   - Evidence: `scripts\hover_feel\audio\NOTES.md` lines 115-119 give a 48-voice hard limit (8+16+9+15), a 46-voice desktop budget, 40 on a phone, and 41 for an Exotic with every slot filled. The slot lists are fixed (`VehicleAudioCatalog` lines 14-15), and `buildFeel` creates one permanent player per filled slot (`VehicleAudioClient` lines 311-314).
   - The plan adds 3 new loops (ReactorWhine, GravSkid, ThrustSlip), fills the empty TurbineHigh slot, and adds 8 one-shots.
   - Result: Exotic desktop about 4+13+11+21 = 49. Muscle about 50 (9 layers plus 6 twins, capped at 14 voices). Phone about 44.
   - Fix:
     - ShiftThunk ×2 and ShiftVent ×2 are enough, because shifts are at least 0.25 s apart.
     - LimiterStutter can be the cut tremolo alone, with no player.
     - ThrustSlip can reuse the SlipStrain or TurbineHigh voice.
     - ReactorWhine can take the empty TurboWhistle slot.
     - On phones, skip GravSkid.
     - Put a voice-count table per profile in the contract.

5. **MAJOR: the engine effects chain copies DRIVE's numbers, and Oscar said not to copy.**
   - Evidence, from the DRIVE audio survey section 1:
     - Piercer distortion 0.10 + 0.25·L is DRIVE's "Drive" formula exactly.
     - +0.15 while cutting, against DRIVE's +0.18.
     - Low shelf +2 + 4·L^1.5 dB, against DRIVE's +2 + 6·L^1.5.
     - A square tremolo at duty 0.55 (14 Hz against DRIVE's 12 Hz).
     - Compressor −12/3, against DRIVE's −10/2.
   - Fix:
     - Put the grit in PR98's own synth: the asymmetric tanh, the `rasp()` wavefolder, `gainvar`/`jit`, and uneven V8 firing.
     - Keep the runtime chain small: a load-driven EQ tilt and the cut gate.
     - Give the sci-fi side effects DRIVE does not use: an `AudioPitchShifter` sub-octave on boost, a light `AudioFlanger`/`AudioChorus` on the reactor sounds, and a resonant `AudioFilter` sweep with load.
     - Pick the values by listening. List the borrowed techniques in the contract.

6. **MAJOR: in a donut, the spin camera swings round with the car.**
   - The rule follows the travel direction only above 4 studs/s (about 2.5 mph). The plan's own spin table has Muscle cars spinning from 0-10 mph.
   - In a donut the travel direction itself rotates, and below 4 studs/s the camera falls back to following the car's nose. With yaw response 3.75 the camera circles the car.
   - Fix: while spinning, hold the camera direction at the angle where the spin started. Follow the travel direction only above about 12 studs/s. Cap camera turn speed during a spin (about 1.5 rad/s), and ease back as the spin ends.

7. **MAJOR: controller rumble can get stuck on.**
   - Nothing uses `HapticService` today. A motor value stays on until it is set again.
   - The plan drives the motors from `chaseEvents`, which only runs inside `updateChase` (`DrivingCameraClient` lines 462-497). It does not run when the camera is suspended (618-629), on `Stop` (757-784) or in the older camera mode. Leaving the car mid-spin would leave the controller buzzing.
   - Fix: one haptics helper that sets every motor to zero on `Stop`, on suspend, on a camera mode switch, on `WindowFocusReleased`, when `GameplayInputGate` locks, and on any frame when not driving. Use the gamepad last used rather than always Gamepad1.

8. **MAJOR: ordinary keyboard and touch driving will spin Muscle and S-tier cars.**
   - A full-lock U-turn or hairpin from 20 mph or less with W held takes 3-6 s (turn rate 0.53-0.9 rad/s). Muscle and S Piercer spin after about 1.4-2.0 s.
   - That covers taxi and courier pickups (18 mph or less), three-point turns and garage drive-ins. Touch players cannot feather the throttle.
   - None of this is in the decisions list.
   - Fix:
     - Tell Oscar plainly what this means for everyday driving.
     - Turn traction assist on by default for touch (DRIVE always keeps assists on for gamepad and touch).
     - Add a warning just before a spin builds: the stabiliser strain sound rising and the gear readout turning amber.
     - Consider spinning keyboard and touch only on a "stab": throttle going from under 0.3 to full within about 0.4 s while at 0.8 lock or more.

9. **MAJOR: medals and personal bests are installed too late.**
   - The re-measured medals and the personal-best reset sit in Phase 4, after the listen-pack approval.
   - If Oscar publishes after Phase 3, the old medal times (for example ShowroomLoop S Gold 54 s) and old personal bests go live against much slower physics (S 60-130 goes from 2.4 s to 4.9 s).
   - Fix: ship the medal retune and the personal-best reset in the physics install. Keep Phase 4 for audio ids only.

10. **MINOR: the grav-skid sound is not uploaded.**
    - `scripts\hover_feel\synth\upload_assets.py` line 29 has `SKIP={"scrape_loop"}`, and the sound has no id in `scripts\hover_feel\audio\asset_ids.json`.
    - `synth\README.md` line 66 describes it as a metal-plate stick-slip scrape, which suits wall scrapes (`FeelScrape`, which plays no sound today) rather than a spin.
    - Fix: drive spins through SlipStrain (`stabiliser_strain`, id 80719035328360) in Phase 2, and add a purpose-made skid loop to the upload batch.

11. **MINOR: the engine sound flattens near the redline.**
    - The rev value is clamped to 0..1 and maps to `rpm/8000` (lines 882 and 917). With "V10 uses 1000/8000", the Exotic's 8000-8600 rpm (shift point 8245, limiter 8600) all play at 8000.
    - The audio also smooths the rev again (0.12 s rising, 0.28 s falling; Catalog lines 84-85) on top of the gearbox's own engine inertia. That blurs the launch flare and the downshift blips.
    - At idle, `FeelRpm` in 25 rpm steps means 2.5% pitch steps, which can be heard.
    - Fix: map the limiter rpm to the top of the rev range. Use about 0.02 s smoothing when `FeelRpm` is present. Publish rpm in finer steps.

12. **MINOR: the tremolo cannot make "one dip per shift".**
    - Roblox's `AudioTremolo` runs freely and cannot be restarted at a set point. Switching it on for 60-200 ms gives 1-3 dips at random points.
    - Fix:
      - Make the shift dip a volume envelope on the engine fader. That is at least 2 frames on mobile's 30 Hz audio update.
      - Keep the tremolo for the limiter only.
      - Do not register the engine fader with the Vehicle bus (line 162), or the Vehicle volume is applied twice.
      - With the switch at 0, set the effects to bypass so the sound matches today.

13. **MINOR: distortion on the engine bus will add beating.**
    - `ladderWeights` (lines 752-767) blends the two neighbouring loops across the whole gap between them, so two slightly detuned loops nearly always play together. Distortion after the mix turns that into beating.
    - Fix: narrow the blend zone (about 0.4 of the gap) when the bus is on. Leave the bus off for other players' cars on mobile (6 detailed cars × 3 effects).

14. **MINOR: other players' cars can only show a shift as a pitch drop.**
    - Other cars' audio has no feel loops or one-shots (`buildFeel` lines 311-314; `updateFeel` returns at line 962) and at most 3 engine voices (line 249). Those thin to Idle1000/On5000/On8000, and the idle loop is held at 1.7× pitch while still audible in the gear range.
    - `VehicleVFXClient` reads only the local car's feel attributes (line 598), so opponents show no shift flames.
    - Fix:
      - State plainly that other cars' shifts are pitch-only.
      - For other cars, choose three engine loops spread over 0.4-1.0 of redline.
      - When the replicated state says Braking, use the local braking-downshift rule (lands at 0.82 of redline) instead of "down below 0.45".
      - Cache each other car's gear setup by vehicle and PI rather than working it out 4 times a second.

15. **MINOR: the rpm arc never goes into the red.**
    - Showing rpm as `rpm/(R/0.8)` puts the redline exactly where the pink last fifth starts. Flat-out upshifts land at 0.776 and the limiter at about 0.81, so the "gauge slamming into the red" from the clip never shows.
    - Fix: place the redline at about 0.86-0.88 of the sweep.

16. **MINOR: the gear readout mixes two typefaces, and is small on phones.**
    - BigNumber errors at build on characters it has no sprite for (lines 233-236). So sprite digits plus a Barlow N/R label means two typefaces and two parts.
    - On phones the unit line uses the Label role, 9.7 dp (Tokens line 192), against 24 dp speed digits.
    - Fix: one Text label for every gear state, or add N and R sprites in the Phase 4 upload. Check it is readable at 844×390 and at the 0.85 minimum scale.

17. **MINOR: too much flashing and shimmer.**
    - The plan has an 8-12 Hz HUD strobe, a 12 Hz camera roll shimmer and thruster flicker, all keyed on `FeelCut`.
    - `FeelCut` also fires on every shift, and during neutral revs on the countdown (W held for seconds).
    - The thruster VFX is already smoothed (0.06/0.28 s, `VehicleVFXClient` lines 47-48 and 598-607), so a short cut barely shows anyway.
    - Fix:
      - Shimmer only on the limiter.
      - Keep visual flashes at 3 Hz or less, or vary brightness instead of switching on and off.
      - Use a soft limiter with no bounce effects in neutral.
      - Add a session-only "Reduce flashing & shake" row in Settings.

18. **MINOR: smaller camera fixes.**
    - "Pitch nod through the punch spring" will not work: `chase.Punch` is the FOV punch (lines 552-553), and `KickPitch` is a fast rattle (ω 55, ζ 0.3).
    - The car body's pitch, the Lag spring (538-543) and the pitch follow (527) already nod on a torque cut.
    - Fix: add a new critical spring (ω about 9), small by default, for upshifts under load only. No nod on automatic braking downshifts, which come 0.2 s apart. Add the FOV pulse into `fov` at line 553.

19. **MINOR: the stand-in sound for Muscle and Piercer makes all three classes sound the same (decision 11).**
    - Mapping them to `EXOTIC_V10_AUDIO` gives them the whole Exotic sound set, so every class sounds like the V10 until Phase 4.
    - Fix: two stand-in profiles made in config only, using the same V10 sound ids with different settings. Muscle pitched down to about 0.8 for a V8-like firing rate, heavier load EQ, sheen off.

20. **MINOR: the listen pack and the uploads.**
    - Offline WAVs cannot reproduce Roblox's distortion, EQ and compressor.
    - The plan asks Oscar to upload 35-40 files; the hover_feel round needed 33, and the uploader notes a monthly limit.
    - Fix:
      - Approximate the effects chain in Python and label it as approximate.
      - Add an in-Studio listen of the existing V10 sounds through the new chain in Phase 3.
      - Cut uploads to about 22-26 (fewer shift slots, no limiter one-shot, Exotic re-synth optional).

21. **MINOR: stale HUD values.**
    - `SetMobileDriving(false)` calls `Reset()`, which clears only the controls fields (`MobileDriveInputState` lines 55-65). `HudView.Step` skips the gauge when not driving (lines 399-408).
    - So gear, shift light, or the rpm arc after the gearbox switch is turned off mid-session, can stay wrong.
    - Fix: clear the new fields in `PublishMobile` when no telemetry is passed and in `SetMobileDriving(false)`. Reset the gauge's gear and light when driving stops.

22. **MINOR: the decisions list mixes real choices with defaults, and misses some.**
    - It mixes real choices with defaults that need no answer (items 12, 13, 15 and 16).
    - Missing:
      - how mechanical versus sci-fi each class should sound;
      - spin help for touch;
      - what happens when boosting at top speed;
      - reduce flashing/motion;
      - garage and dealership previews (`PresentationAudioClient` lines 205-221 ignore the class mapping, so nobody hears the new voice when buying);
      - whether opponents' shifts should be seen and heard.
    - Fix: about 6-7 "please choose" items, and the rest as "doing this unless you object".

## Improvements worth adding

1. **Boost "OVERDRIVE" zone** (from issue 3): the arc pushes into the red with a reactor scream, as the Redline nitro scenes do.
2. **A mechanical-versus-sci-fi mix per class:** Muscle about 0.15, Piercer 0.5, Exotic 0.8. That way a race grid sounds like the clip's retro car among sci-fi machines.
3. **Boost shock-wave from low speed:** a VFX ring, a sub-bass thump and the existing boost FOV punch.
4. **Warning before a spin** (from issue 8).
5. **Needle overshoot on the rpm arc** (spring ω about 25, ζ about 0.5), smoothed in HudView, so it "slams" with no new parts.
6. **"About to shake apart" strain:** scale `HoverWobble` by load × rpm near the limiter and with speed near the boosted top.
7. **Grid revs others can hear:** set `Accelerating` from throttle while anchored. Today `DrivingClient` lines 1068-1084 return before line 1225 sets it. Other cars would then rev in neutral on the grid with no network change. This is inferred; check the remote's rate limit.
8. **A rev blip in the class voice** in garage and dealership previews.
9. **Add an opponent pass-by and a 4-car grid** to the listen pack.
10. **Gauge start-up sweep:** the rpm arc sweeps 0, then 1, then idle, about 0.5 s on getting in, like DRIVE's cluster self-test.