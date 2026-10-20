# drivetrain_feel: handoff (2026-10-20, installed)

**Installed in PR98 Edit and agent-verified in one desktop Play session. Not user-confirmed. The agent did not save
the place: Oscar saves it, then a save-and-reopen AUDIT (`out_audit.lua`) should report every script `after`.**

## What Oscar asked for and decided

- Make the cars less arcadey: real gears, more weight, low-speed spin-outs on aggressive steer and throttle, a grungier
  sci-fi engine sound, an rpm and gear HUD. Plan approved 2026-10-20 (`C:\Users\Oscar\.claude\plans\robust-seeking-comet.md`,
  defaults D1-D8).
- Then narrowed: Exotic class only; ignore races and time trials; everything easily tunable later; auto mode.

## Where things are

| Piece | Where |
|---|---|
| Contract | `CONTRACT.md`, amended by `reviews/15_fix_spec.md` (decisions F1-F9, new attributes) |
| Evidence | `verification.json` |
| Physics (gearbox, weight, spin) | `physics/after/`, `physics/config.py`, `physics/NOTES.md` (dial mapping, every value) |
| Offline model | `model/` (`py -3 scripts/drivetrain_feel/model/sim.py --write`), `model/RESULTS.md` |
| Audio, HUD, camera/VFX | `audio/`, `hud/`, `camerafx/` (each with NOTES) |
| Sounds | `synth/README.md`; WAVs regenerate into `output/drivetrain_feel_audio/` (not committed) |
| Installer | `serve.py` (bridge 8797), `build.py`, `out_audit/apply_config/apply/rollback.lua`, `classic/out_verify_classic_after.lua` |

## Tuning (live in Play, no re-entry needed)

`ReplicatedStorage.Config.Vehicles.Drivetrain.exotic`: start with the six dials `FeelWeight`, `FeelGearing`,
`FeelAcceleration`, `FeelGrip`, `FeelSpin`, `FeelEngineBrake` (1 = designed feel). Every value has a
`<Name>_RaisingThisDoes` string. Off switch: `exotic@Enabled` 0 (or `Drivetrain@Enabled` 0). Spin strength is tied to
`YawOmega`: lower it and retune `SpinYawAccel` with it.

How to spin on keyboard: hold W and S at a standstill with A or D held, then release S (power-brake launch); or, below
30 mph, lift W briefly and then press A/D and W together (flick-stab). Holding W with full lock, U-turns and junction
pull-outs only wiggle.

## Review and accepted risks

The delivery-reviewer ran in parallel with the install (Oscar asked to hurry). Its accepted risks are listed in
`verification.json` "review". Two matter for follow-ups: APPLY never refreshes an existing `Drivetrain` folder (new
defaults need ROLLBACK then APPLY, which drops Edit-time tuning), and the asset-id follow-up must add `allowed` rows in
`build.py` for the audio profile values it changes. Switch `Dynamics@DebugAttributes` off before publishing.

## Next

1. **Oscar:** save the place; drive an Exotic (the as-spawned Seraph was tested) and judge the feel, dials first.
2. **Oscar:** listen to `output/drivetrain_feel_audio/listen/` and upload the approved sounds (`synth/README.md`);
   then a small follow-up installs the asset ids on `EXOTIC_V10_AUDIO`.
3. Open checks (see `verification.json` "not_verified"): phone HUD, gamepad and touch, drift and Overdrive in Play,
   the anchored (teleport/countdown) path, two clients.
4. Later: other classes by copying the `exotic` folder under their CategoryId (Muscle 4 gears, Piercer 6, plan D5).
