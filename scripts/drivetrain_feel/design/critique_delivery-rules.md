1. **BLOCKER: the Classic verify plan, as written, fails AUDIT.**
   - Evidence: `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\ui_restyle\classic\README.md` ("Declared changes") accepts an edited script only if live equals the baseline or the one declared after-hash. Anything undeclared fails.
   - Declared files are cumulative. The newest is `...\scripts\ui_restyle\phase2\install\07_shell\declared.json`: 8 scripts and 102 addedScripts.
   - It pins Pulse scripts by hash: Kit.Gauge (14702 / djb2 2502745895), FreeRoam.HudView (19189 / 3772154053), Dev.Fixtures.Gauge (5423) and FreeRoam.HudClient. DrivingClient is already a declared edit (after-hash 72479 / 1261491730).
   - The design's declared.json lists only 7 scripts. That gives three failures:
     - (a) every earlier Pulse declaration is lost;
     - (b) the HudView, Kit.Gauge and fixture edits fail as pinned-hash mismatches;
     - (c) a pre-APPLY AUDIT using the new DrivingClient after-hash reports "changed", because live is neither the baseline nor the new after.
   - Fix:
     - Start from 07_shell's declared.json. Override the 7 Classic-recorded scripts and re-pin HudView, Kit.Gauge, Fixtures.Gauge, Fixtures.FreeRoam and Gallery (if touched).
     - Emit two verify builds (the current set for AUDIT and ROLLBACK, the new set after APPLY), or extend `build_verify.py` to accept a list of after-hashes per script.
     - Keep the 190,000-character cap in mind.

2. **MAJOR: the HUD part must go through the ui_restyle chain, not `scripts/drivetrain_feel`.**
   - Evidence: `...\scripts\ui_restyle\phase2\install\state.json` tracks Kit.Gauge (unit 00_kit, fp 2502745895-1498110527-14702), HudView (unit 02_free_roam) and DrivingClient (kind "source", fp …-72479).
   - Both precedents kept the canonical sources current:
     - the radio (commit 35e83bd4) built through `scripts/ui_restyle/radio` with `engine/build.py` (PR98_PLACE_ID) and updated `phase2/families/free_roam/after/...HudView.lua`;
     - the phone pass (3f5d90b3) updated `kit/k3/after`, `install/00_kit/after`, `install/02_free_roam/after`, state.json, applied_hashes and the tests.
   - The per-frame lint (CONTRACT 5.1 rule 4: no GetAttribute or FindFirstChild in code bound through Kit.Perf) runs only in that build.
   - Risk: the next ui_restyle install, Phase 9 hardening or the Phase 10 retirement would BLOCK on "unknown" hashes for HudView, Kit.Gauge and DrivingClient. Or a rebuild from the stale canonical `after/` would silently revert the gear HUD.
   - Fix:
     - Build part D as a ui_restyle engine phase (spec `placeId` 103397770260610, `classicVerify` pointing at the new declared set).
     - Update the canonical after files, state.json, test_manifest and the k3 tests in the same commit.
     - Record in state.json that DrivingClient's recovery point has moved to the new delivery (the 02_free_roam rollback for it is superseded).

3. **MAJOR: the radio precedent does not apply, so AGENTS.md line 29 is triggered.**
   - Evidence: radio `spec.json` `_note` says "No Classic script, payload or config that Classic reads is touched, so no Classic verify."
   - Here 7 Classic-recorded scripts change, and the shared `MobileDriveInputState` payload gains fields. That payload is read by Classic `DesktopFreeRoamHudUI` (1277-1293) and `MobileFreeRoamHudUI` (493).
   - HudView's own comments ("D1275-1293 and M493") show that gauge parity with Classic is the existing rule.
   - AGENTS line 29 says such a delivery "lands in both sets", with a review "at each such delivery".
   - Fix:
     - Add decision 17: Oscar records an explicit Pulse-only exception (Classic gets the new physics with a speed-only gauge), or a gear readout is added to Classic after re-taking the record.
     - Run the Classic smoke check with `UIStyle=Classic` while driving.

4. **MAJOR: the effect on Cash earnings is missing, and deferring medals and PBs opens a live window.**
   - Evidence:
     - `TimeTrialServer` 750-776: the medal comes from `medalForElapsed`, and the Cash comes from `grantTimeTrialReward(player, run, elapsed, medal, isPersonalBest)`. Onboarding Q8 (`OnboardingClient` 58) says "earn medals and cash".
     - `JobRules` 683-691: job pay is multiplied by a speed factor measured against `ReferenceMph` 85.
     - Drive rewards pay per stud, so Cash per minute falls when pace falls.
     - The design puts medals and the PB bump in Phase 4, after the listen pack and the uploads. AGENTS line 14 keeps economy safeguards regardless of diff size.
   - Fix:
     - Model Cash per hour before and after (`JobRules.HourlyEstimate` plus drive rewards at measured E/C/S route averages) and get Oscar's sign-off.
     - Ship the medal retune and the PB decision in install 1, as a separate guarded server-config transaction. Otherwise Oscar must hold the publish of install 1.
   - PB store details:
     - The live value is the StringValue `ServerStorage.Config.Racing.PersonalBests.DataStoreName` = `NTR_TimeTrialPersonalBests_StudioTest_v1`. The code fallback in `PersonalBestServer` line 69 is `..._v1`. "_v2" is ambiguous, so name the exact new value.
     - Bump `Leaderboards.OrderedStorePrefix` and `MetadataStoreName` together.
     - This changes a saved-data key (old PBs are abandoned, not migrated), so the persistence check applies.

5. **MAJOR: there is no PB-01-safe way to re-measure medals.**
   - Evidence: docs/06 PB-01 and ui_restyle CONTRACT line 502 say agents never finish a time trial. There are 2 events × 6 tiers × 4 medals = 48 values, and the design gives no method.
   - Fix: first ship a small PB-01 fix (gate PB writes on `StudioVehicleSandboxEveryPlay`). Otherwise time laps with a split probe that stops before the last gate, or use an offline route simulation calibrated against measured segments. Oscar's finishes confirm.

6. **MAJOR: the spin rule overlaps the user-confirmed DRIVE-01 low-speed manoeuvres.**
   - Evidence: DRIVE-01 is user-confirmed (three-point turns; forward throttle takes yaw at once).
   - At a standstill, full lock gives about 0.53 rad/s of yaw, which passes the spin yaw gate (0.15 + 0.35).
   - The design's envelope spins C/B Muscle at 0-20 mph in 1.38-1.57 s, and S Piercer at 0-10 mph in about 1.9 s.
   - A full-lock U-turn from rest takes about 3-6 s. So W+A U-turns, garage drive-ins, job pickups (pickup needs ≤18 mph) and parking turns will spin these cars. "DRIVE-01 code untouched" does not mean the behaviour is unchanged.
   - Fix:
     - Make this an explicit decision for Oscar.
     - Arm the spin only on launch-type slip (thrust slip rising within about 1 s of applying throttle) or above about 5 mph.
     - Add standstill U-turns and three-point turns with C Muscle and S Piercer to verification row 7.

7. **MAJOR: reset and teleport paths do not clear the new state.**
   - Evidence: `DrivingClient` 1581-1594 `Controller.ResetVehicle` zeroes velocities, bank and steering intent, then re-orients the car from `YawHeading`. R / ButtonY (`handleResetAction` 1596) is the player's natural way out of a spin.
   - The design resets only in `Stop` and the anchored branch. Teleports (`FreeRoamTeleportServer` 71, `RaceTeleportServer` 129) are not covered.
   - A leftover yaw rate of up to 3.6-5 rad/s or a leftover spin amount would keep spinning the car after a reset.
   - Fix:
     - In `ResetVehicle`, and wherever `YawHeading` re-syncs from the body (the "after an anchored spell" path near line 678), zero the yaw rate, spin amount, lateral acceleration, pitch spring and steer limiter.
     - Return the gearbox to 1 or N at idle with no shift or limiter in progress, and start the spin grace timer.
     - Add verification rows for a reset mid-spin and a teleport mid-spin.

8. **MAJOR: switch staging and rollback clash with the installer's rules.**
   - Evidence: the driving_tune `installer_engine` requires an existing attribute to equal its before or after value. DRIVE-02 notes that "ROLLBACK removes live-tuned config values".
   - The design applies with switches at 0, flips them on live, and says ROLLBACK "removes only marked config".
   - But several new attributes sit on instances that already exist, so they are not marked:
     - `Config.Vehicles.Camera@HapticsEnabled` and `@HapticsMobileEnabled`;
     - `Config.Audio.VehicleProfiles@CategoryProfile_muscle` and `@CategoryProfile_bruiser`;
     - `EXOTIC_V10_AUDIO@RevRpm*` and `@ShiftDropSeconds`;
     - the new 0/1 switches on `Audio.Global`.
   - Fix:
     - List each of those in ATTRIBUTES with before = nil, so ROLLBACK clears them.
     - Accept the staged switch values as allowed prior states, so re-APPLY and ROLLBACK do not BLOCK after a flip. Do each flip with a tiny guarded script that asserts the previous value.
     - Roll back sources before config. Code fallbacks equal the defaults (1), so removing config first under the new sources would turn features on.

9. **MAJOR: VEH-01 and MUS-01 create an untested worst case.**
   - Evidence: docs/06 MUS-01: the Modern Muscle can read A on the road, and `MatchmakingServer` and `TimeTrialServer` use the on-road tier. So "Muscle tops out at B" does not hold for gameplay.
   - An A Muscle combines spin gain 1.25, traction 0.92, full tier scaling and A Balance. This is the most spin-prone setup and is missing from sections 3.3 and 3.5.
   - VEH-01 double-counts module `Weight` on spawned cars. The new yaw response uses exponent 0.5 (today's weight effects use 0.22), so heavy builds become disproportionately sluggish, and braking is affected too.
   - MUS-02: every E and D car sits on the `LateralGrip` floor (0.82), so traction and the lateral cap are identical across those cars.
   - Fix: add an A Muscle (on-road PI 727-749) to the simulation and the Play matrix, and calibrate using on-road stats as spawned. Ask Oscar whether to fix VEH-01 first.

10. **MINOR: some features have no switch.**
    - Section 3.7 promises a 0/1 switch per feature, but section 4 defines only 09/10/11 and haptics. Missing:
      - camera: spin mode, shift nod and FOV pulse, limiter shimmer;
      - VFX: vent flame, spin stutter and dust, thrust-slip glow, thrust from `FeelLoad` (`FeelVFXEnabled` at `VehicleVFXClient` 46/566 is too coarse);
      - audio: sub-bus, the second pitch line, shift one-shots, remote gear derivation;
      - HUD: rpm arc, gear readout, shift light.
    - A HUD switch under `Config.UI` must be declared under `configAttrs`, because `Config.UI` is in the Classic config record.
    - `DrivingCameraClient` line 56 `flag()` ignores a configured false, so camera switches must be numbers too.

11. **MINOR: the FeatureFlags exception is not recorded.** AGENTS line 25 says live-tunable behaviour reads FeatureFlags. Cite hover_feel CONTRACT line 87 in the contract.

12. **MINOR: install hygiene.**
    - Add "save and reopen, then AUDIT must still report after" (ui_restyle CONTRACT 496).
    - Both config caches are built once per client session (`VehicleDynamics` 12-27, keyed on the folder; `DrivingClient` 396-413), so a Play test needs a fresh session after APPLY.
    - Attribute-name collisions across `Dynamics` 01-11 resolve in `GetChildren` order, which is not deterministic. Add a build-time uniqueness lint. Live 01-08 currently have no clash with the proposed names.

13. **MINOR: verification gaps against `scripts/validation_checks.json`.**
    - Missing:
      - `startup` (real Play button);
      - `streaming`;
      - `race`: a driven matchmaking race finish is allowed (PB-01 applies only to time trials);
      - duel start (two-client);
      - the reset and teleport rows;
      - the RenderStepped check before camera, UI and audio checks.
    - Design item 14's "published two-player test" would run on the live PR98 place. The multiplayer check requires an isolated published test place.
    - Add `verification.json`, `validation_record.py` and the docs updates:
      - docs/00, whose header is stale;
      - docs/06: a new DRIVE-03 row, plus updates to DRIVE-02, FEEL-01, UI-01 and PB-01;
      - docs/07;
      - topic docs 03, 05 and 16;
      - docs/02, for the new `Config.Vehicles.Drivetrain` group;
      - the Kit API doc.

14. **MINOR: two style sheet conflicts.**
    - The shift light's "tick tint" breaks `docs/design/pulse-racers-ui-style-sheet.md` line 144: baked gauge images are never tinted. Use the Tip glow (GlowSoft) or a transparency pulse instead.
    - Line 209 says "The outer arc is speed". Changing it to rpm needs Oscar's approval and a style sheet edit.
    - The Kit API is "frozen after the free-roam HUD" (CONTRACT 261/581), so the extension needs Oscar's OK, not only a reviewer. Replacing the unit line on the 92 dp phone gauge reworks the phone layout pass.

15. **MINOR: audio upload and listen-pack logistics.**
    - `scripts/hover_feel/synth/upload_assets.py` line 27 hard-codes `USER_ID 7915427645` ("owner of Space Racers v3"). PR98 is in its own universe, so confirm the creator and asset permissions before the 35-40 uploads.
    - Line 11 notes Roblox limits audio uploads per month, and 33 were uploaded recently.
    - Render the listen pack to `output/` (as `make_sounds.py` line 31 does), not under `scripts/`, where the WAVs would bloat git.

16. **MINOR: debug attributes are on in the published place.** Live `Config.Vehicles.Dynamics@DebugAttributes = true`, and the design adds 9 more per-frame writes. Switch it off before publish.

17. **MINOR: side effects of revving in neutral.**
    - If `Accelerating` toggles while the car is anchored, `VehicleAudioClient` (579-587) sends Drive changes over `VehicleAudioState`, which is limited to 20 per second. Keep it false while anchored.
    - `VehicleVFXClient` 327-331 shows no driving VFX while `DriveReady` is false, which is the case during staging. So no start-line VFX.
    - `GameplayInputGate.Release` (107-117) waits up to 5 s for neutral input if W is held when a loading transition ends.
    - Duels anchor (`DuelService` 271-300), so the grace timer does trigger there. But network ownership is set after unanchoring, so start the grace timer on `DriveReady` returning true.

18. **MINOR: haptics are outside the request.** No HapticService code exists in PR98, so this adds a new responsibility to the camera owner. It also needs a player opt-out: a session-only Settings row (MINIMAP precedent) or a saved profile field (saved data). Defer it or default it to 0.

19. **MINOR: config and anchor ownership between parts.**
    - `EngineBrakeEnabled` sits in `10_Chassis` (part B), but engine braking is computed in the drivetrain step (part A). Move it to `09_Gearbox`.
    - Parts A and B both edit `VehicleDynamics` (the longitudinal step and the handling outputs), not only `DrivingClient`. Give them separate anchors there too.

20. **MINOR: category ids confirmed live, so drop risk 8.**
    - The ids are lowercase `bruiser`, `exotic` and `muscle` (`VehicleCatalogData` PIERCER_1, EXOTIC_1, MUSCLE_1). The vehicle's `CategoryId` is set from `profile.CurrentCategory` (`VehicleBuildService` 270).
    - Fall back to the `CockpitId` prefix, as `VehiclePreviewVFXClient` 873 does.

21. **MINOR: remote gears add a new dependency.**
    - Today only `DrivingClient` requires `VehicleDynamics` (line 15). Remote gear derivation adds a `VehicleAudioClient` → `VehicleDynamics` require. Record it in the contract's owner list.
    - That `RAW_PERFORMANCE_Runtime`, PI and `CategoryId` are present on streamed-in remote cars is inferred, not checked.

22. **MINOR: timeouts against slower low-tier pace.** E-tier 0-100 goes from 8.3 s to 20.4 s. Check `DuelService` `TimeoutSeconds` 150 (line 85) and the job abandon time (`AbandonFactor` 4) on the longest routes.

23. **MINOR: AGENTS line 21 forbids fallback implementations unless requested.** Keeping the old and new longitudinal, yaw, grip, brake and rev paths side by side needs Oscar's explicit OK and a planned removal after he accepts the feel.

**Improvements worth adding**
- Turn spin-out on for Muscle only at first (spin gain 0 elsewhere), and widen it after Oscar's feel pass.
- Land the PB-01 fix as a small prerequisite, so medals can be measured in the sandbox.
- Pre-publish checklist: switch states, DebugAttributes off, medals and PB store in step, Classic smoke done, save and reopen done, ui_restyle state.json current.
- Offer a session-only Settings row for traction assist and haptics (MINIMAP precedent). This avoids new saved data.
- Category audio in garage and dealership previews. `PresentationAudioClient` 205-221 ignores `CategoryProfile_*`, so every preview plays the generic idle and "engine choice you can hear" doesn't reach the shop.
- An economy probe script built on `JobRules.HourlyEstimate`, kept with the delivery as evidence.
- Build-time lints: unique `Dynamics` attribute names, a source-size guard, and the ui_restyle per-frame lint on HudView and Kit.Gauge.