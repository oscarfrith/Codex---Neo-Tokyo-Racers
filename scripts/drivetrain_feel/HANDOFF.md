# drivetrain_feel: handoff (2026-10-20, paused for usage limit)

**Nothing is installed in PR98, and there have been no Studio writes.**

What exists:
- the parts are written offline in this folder;
- three of the four code parts are built, reviewed and fixed;
- physics and model still need their fix pass.

Start a new chat with: **"continue the drivetrain_feel delivery: read scripts/drivetrain_feel/HANDOFF.md"**.

## What Oscar asked for and decided

**The request.** Make the cars less arcadey:
- real gears;
- more weight;
- low-speed spin-outs on aggressive steer and throttle;
- grungier sci-fi engine sound;
- an rpm and gear HUD;
- whatever else is affected.

DRIVE: Highway (studio "DRIVE: Highway DEVELOPMENT", place 111000019231429) is inspiration only. The Redline (2009) clip is the reference.

**Plan.** Approved 2026-10-20. A copy is at `C:\Users\Oscar\.claude\plans\robust-seeking-comet.md`, and the plan defaults D1–D8 stand.

**Changes after approval (Oscar):**
- **Exotic class only for now.**
- **Ignore races and time trials:** no medals, PBs or economy work.
- **Everything easily tunable later** (weight, gearing feel, spin and so on).
- Auto mode.
- He saved a backup of the place.

**Contract:** `CONTRACT.md` in this folder is the authority. Everything new hangs off `Config.Vehicles.Drivetrain.exotic`, which has six feel dials (`FeelWeight`, `FeelGearing`, `FeelAcceleration`, `FeelGrip`, `FeelSpin`, `FeelEngineBrake`) plus the detailed values. A class with no folder, or `Enabled` set to 0, drives exactly as before.

## State of each part

| Part | Files | Status |
|---|---|---|
| physics | `physics/after/DrivingClient.lua`, `physics/after/VehicleDynamics.lua`, `physics/config.py`, `physics/NOTES.md` | Built; compiles in Studio Edit. Reviewed: **NOT fixed**. See `reviews/13_physics_review.md`; it includes a MAJOR finding that spins don't work and that `FeelWeight` turns them off. |
| model | `model/*.py`, `model/RESULTS.md` | Built. RESULTS proposes new defaults, and some of them **need physics code changes** (see `reviews/10_model_build.md`). Reviewed: **NOT fixed**. See `reviews/14_model_review.md`; it includes a BLOCKER that the "holds and U-turns never spin" claim is false for ordinary holds. |
| audio | `audio/after/VehicleAudioClient.lua`, `audio/after/VehicleAudioCatalog.lua`, `audio/config.py`, `audio/NOTES.md` | Built, reviewed and fixed (`reviews/02`, `06`, `12`). Compiles. |
| hud | `hud/after/{DriveSessionClient,HudView,Gauge,Fixtures.Gauge}.lua`, `hud/tests/`, `hud/API2_AMENDMENT.md`, `hud/NOTES.md` | Built, reviewed and fixed (`reviews/03`, `07`, `11`). Compiles. The tests have not been run. NOTES lists the ui_restyle bookkeeping the integrator must do. |
| camerafx | `camerafx/after/{DrivingCameraClient,VehicleVFXClient}.lua`, `camerafx/config.py`, `camerafx/NOTES.md` | Built, reviewed and fixed (`reviews/01`, `04`, `08`). Compiles. |
| synth | `synth/make_exotic_v2.py`, `synth/listen.py`, `synth/README.md` | Built and run. WAVs are in `output/drivetrain_feel_audio/` (not committed; regenerate with the README commands). **Nobody has listened to them yet.** The listen pack is in `output/drivetrain_feel_audio/listen/`. Nothing has been uploaded. |

**Other files**
- `design/` holds the survey, the design draft and the critiques.
- `before/` holds the exact live sources and config captured from PR98 on 2026-10-20. The djb2 hashes match live, listed in the session log: for example DrivingClient is 72479 bytes, djb2 1261491730.

**Integrator tooling (written, not yet run end to end)**
- `serve.py`: bridge on port 8797.
- `build.py`: composes the parts' after-files and config into `after/`, then writes `out_audit.lua`, `out_apply_config.lua`, `out_apply.lua` and `out_rollback.lua`.
- `installer_engine.lua`: the guarded installer, marker `DrivetrainFeelInstalled`.
- `classic_declared.py`: re-pins the Classic declared set from `ui_restyle/phase2/install/07_shell/declared.json` and writes `classic/out_verify_classic_after.lua`.
- `play/sampler.lua`: a client sampler of speed, gear, rpm, spin and yaw.

## Next steps (in order)

1. **Physics fix pass.**
   - Apply `reviews/13_physics_review.md`: every BLOCKER and MAJOR, plus the cheap MINORs.
   - Fold in the model's proposed defaults and code changes from `model/RESULTS.md` and `reviews/10`.
   - Resolve the model review's BLOCKER (`reviews/14`): ordinary holds and U-turns must **not** spin; stab and power-brake gestures must.
   - Re-run the model against the physics equations until every CONTRACT 9 target passes.
   - Compile-check: the CONTRACT section 2 snippet, with `serve.py` running.
2. **Cross-part interface check.**
   - Feel attribute names (CONTRACT 3.1) and telemetry fields (3.2) must match between physics (the producer) and audio, hud and camerafx (the consumers).
   - `VehicleDynamics.GearForSpeed` (3.3) must match what audio calls.
3. **Build.**
   - `py -3 scripts/drivetrain_feel/build.py --diff`
   - `py -3 scripts/drivetrain_feel/classic_declared.py`
4. **Review.**
   - Run the `delivery-reviewer` subagent on CONTRACT.md plus the diff (High-Risk).
   - Fix what it finds.
5. **Install in PR98 Edit** (`list_roblox_studios`, then pick "PR98", then `get_studio_state`; run `serve.py`).
   1. Run the 07_shell Classic verify (`scripts/ui_restyle/phase2/install/07_shell/out_verify_classic_07_shell.lua`). It must pass.
   2. `out_audit.lua`, then `out_apply_config.lua`, then `out_apply.lua`, then `out_rollback.lua`, then `out_apply.lua`.
   3. Run `classic/out_verify_classic_after.lua`. Only declared differences are allowed.
   4. Ask Oscar to save the place, or note that it needs saving.
6. **Play tests.**
   - **Sandbox window.** Open it with `scripts/ui_restyle/probes/sandbox_window.lua`, mode "open". Then raise `Config.Player.Onboarding@StudioVehicleSandboxCash` to 20,000,000 so the S-tier Seraph (12.5M) can be bought. Restore it afterwards.
   - **Buying and spawning.** Pass the start screen through the visible Play button. Then call `GarageInvoke:InvokeServer("BuyCockpitInstance", {CategoryId="exotic", CockpitId="exotic_01".."exotic_06"})`, then `GarageInvoke:InvokeServer("SpawnVehicle")`.
   - **Prices:** Stinger 50k, Zephyr 150k, Aurora 440k, Endura 1.4M, Rosso 4.4M, Seraph 12.5M.
   - **Driving:** use `user_keyboard_input` (W, A/D, S, Space for drift, Shift for boost). Use `play/sampler.lua` to record.
   - **Parity:** `Drivetrain.exotic@Enabled` 0 must behave as before.
   - **With it on**, check:
     - shifts;
     - Overdrive;
     - spin gestures;
     - holds and U-turns that must not spin;
     - DRIVE-01;
     - drift radius;
     - the HUD on desktop, on phone emulation, and on a non-Exotic car;
     - the camera with zero `resetChase` during a spin;
     - audio voice counts;
     - enter and exit cycles;
     - a clean console.
   - Close the window afterwards.
7. **ui_restyle bookkeeping** (hud/NOTES.md), the `verification.json` record, and docs:
   - 00, 03, 05 and 16;
   - 06: a new DRIVE-03 row, plus updates to DRIVE-02, FEEL-01 and UI-01;
   - 07;
   - a 12 lesson if one is earned.

   Then commit and push.
8. **Oscar:** listens to `output/drivetrain_feel_audio/listen/`, judges the feel in Play, and uploads the approved sounds (`synth/README.md` has the upload list). After that, a small follow-up installs the new asset ids on `EXOTIC_V10_AUDIO`.

## Risks to keep in mind

- **Spins on digital input.** Holding W with full lock must stay a wiggle. Only a stab or a power-brake launch should spin the car.
- **Pace.** Acceleration and top-end pace drop a lot by design (D1, Grounded). `FeelAcceleration` and `GearTorqueExponent` are the live dials.
- **Coast loss.** The unexplained coast loss (driving_tune balance NOTES) could stack on top of the new engine braking.
- **Sizes.** `DrivingClient` grows to about 100 KB, which is still under the 200 KB source limit. `VehicleDynamics` grows to about 70 KB.
- **HUD.** The Kit API is frozen, and the gauge budget goes from 26 to 28. `hud/API2_AMENDMENT.md` records that, as Oscar approved under D6.
