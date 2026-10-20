# drivetrain_feel synth part: Exotic v2 sounds and the listen pack

CONTRACT section 10. Offline only: nothing here touches Studio, and nothing is uploaded.

- `make_exotic_v2.py` renders the upload candidates: a grungier V10 hybrid set, the reactor whine, the shift one-shots and the grav skid.
- `listen.py` renders WAV demos. It ports the gearbox and the audio client to Python, so Oscar can judge the sound before anything is uploaded.

Both import their DSP helpers from `scripts/hover_feel/synth/make_sounds.py` by file path. That file is not changed.

## How to run

numpy is the only dependency. Run from the repo root:

```
py -3 scripts/drivetrain_feel/synth/make_exotic_v2.py     # about 4 s
py -3 scripts/drivetrain_feel/synth/listen.py             # about 7 s; needs make_exotic_v2.py first
```

Both are deterministic: a rerun gives byte-identical files (checked).

`listen.py` options:

| Option | Effect |
|---|---|
| `--only full_run,spin` | Render some demos only. Names: `full_run`, `lift_off`, `neutral_revs`, `power_brake`, `spin`, `part_throttle`, `overdrive`, `pass_by`, `today_vs_new` |
| `--set Name=value` (repeatable) | Override any `Drivetrain.exotic` attribute, for example `--set FeelGearing=0.5 --set ShiftCutSeconds=0.09` |
| `--tag x` | Add `_x` to the file names. A tagged run skips the today/new pairs and the stems |
| `--reactor core` | Use `reactor_core_alt` instead of `reactor_whine` |
| `--slip-strain stabiliser_strain` | Keep today's drift squeal in SlipStrain instead of `grav_skid` |
| `--no-bus` | `EngineBusEnabled = 0` (the engine sub-bus is bypassed) |

## Output (`output/`, not committed)

| Folder | Contents |
|---|---|
| `output/drivetrain_feel_audio/exotic_v2/` | The 15 upload candidates and `manifest.json` (levels, seam metrics, firing Hz, comparison with today) |
| `output/drivetrain_feel_audio/_today_regen/` | Today's live Exotic sounds, re-synthesised by `make_sounds.py` with the same names and seeds as the uploaded files. Used only for comparison and the listen pack. **Do not upload these**: they are already live |
| `output/drivetrain_feel_audio/listen/` | The demos, `README.txt` (approximations stated) and `timeline.json` (every shift: time, gear, mph, rpm) |

## The v2 sound set

All files are 44.1 kHz, 16-bit mono WAV. Loops are seamless by construction, as in `make_sounds.py`, and sit at -17 dBFS RMS like today's loops, so the existing gains still apply.

### V10 hybrid loops (grungier)

The loops use the same rpm points, load modes and loop lengths as the live rev layers, so each file replaces one `RevLayers` asset with no change to Rev or Pitch. Changes from round 3, all in `V2_MODES`:

- **Uneven firing.** New `cyl_skew`: per-cylinder timing offsets, applied as a cycle-periodic phase wobble on the tonal core. Per-firing level variation is about 3 times higher (`gainvar` 0.16, plus 0.25 at full rev).
- **Exhaust blats.** New `blat`: one noise-plus-pipe burst per firing at the uneven firing times.
- **Saturation and rasp.** Harder, more asymmetric tanh (`bias`, `V2_DRIVE`), then a partial sine wavefolder (`make_sounds.rasp`, `fold`).
- **Low end.** Stronger engine and half orders (`low_orders`), half-firing sub (`half_sub`), rumble and firing-pulsed rasp.
- **Less whine.** The 3.3 kHz presence boost drops from +4 to +1.5 dB.
- **Sci-fi sheen.** The ring-mod sheen drops from -20 to -25 dB, and the idle's energy-core hum from 0.5 to 0.38. The sci-fi line now lives mostly in `reactor_whine`.
- **Upper range gets more grit.** New `*_rev` knobs add grit with rev on the on-load set, because the gearbox holds the engine at 0.6-0.97 of redline.

Measured against today's re-synthesised loops (`make_exotic_v2.py` prints this table):

| Loop | Energy below 250 Hz | 2-5 kHz band | Unevenness (dB, higher = lumpier) | Firing anchor added |
|---|---|---|---|---|
| v10_idle_1000 | 81.7 -> 79.7 % | 1.6 -> 3.0 % | -0.3 -> 1.5 | 0 dB |
| v10_on_2000 | 51.4 -> 53.2 % | 2.9 -> 3.7 % | -2.3 -> -0.2 | 0 dB |
| v10_on_3500 | 16.9 -> 31.7 % | 3.5 -> 5.3 % | -5.9 -> -0.2 | 4.5 dB |
| v10_on_5000 | 7.7 -> 22.1 % | 6.9 -> 10.4 % (rasp noise) | -9.4 -> 4.7 | 0 dB |
| v10_on_6500 | 5.8 -> 8.8 % | 10.4 -> 6.8 % | -6.7 -> -2.8 | 0 dB |
| v10_on_8000 | 5.7 -> 5.7 % | 8.6 -> 5.6 % | -8.5 -> -6.6 | 0 dB |
| v10_off_3000 | 45.9 -> 47.7 % | 1.6 -> 1.1 % | 1.0 -> 0.6 | 0 dB |
| v10_off_6000 | 36.7 -> 39.9 % | 3.6 -> 3.3 % | 2.0 -> 3.2 | 7.7 dB (round 3: 4.0) |

- Every loop's strongest line is still its firing frequency (rpm / 12), which the crossfade depends on.
- **v10_on_8000 changed least.** Its noisiness rose about 2 dB and its whine fell. For more grit at the top, raise `gainvar_rev`, `fold_rev` or `V2_DRIVE["on"][1]`.
- **v10_off_6000 needs a 7.7 dB anchor.** That is a pure line at 500 Hz. Listen for a whistle on overrun.

### Other new sounds

| File | Length | What it is |
|---|---|---|
| `reactor_whine` (recommended) | 3.0 s loop | Ion-drive whine on 880 Hz: a motor harmonic stack, inverter-style sidebands, two chorus voices beating at 0.67 and 1 Hz, a sub octave, a 6.67 Hz plasma pulse and a thin 3-7 kHz shimmer. Clean on purpose, against the grungy engine. The game sweeps it 0.7-1.4x with road speed (616 Hz to 1.2 kHz). |
| `reactor_core_alt` | 3.0 s loop | Darker alternative on 660 Hz: root, fifth and octave pairs beating, a 4 Hz containment throb, a ring-mod sheen and a light fold. |
| `grav_skid` | 3.0 s loop | Hover-stabiliser skid, not a tyre: two jets alternating at 9 Hz (matching the VFX `SpinStutterHz`), a strained grav-field buzz on 74/77 Hz, a broad friction scrub with stick-slip roughness, a pulsing sub and sparse static grit. It has no narrow 1-3 kHz tone. |
| `shift_thunk_1`, `_2` | 0.30 / 0.36 s | A dry dual-clutch clack (two engagement clicks 6 / 9 ms apart through short housing modes), a driveline thump (85 / 62 Hz) and a short electric actuator chirp 12-13 dB under the clack (up-sweep on 1, down-sweep on 2). Peak -4 dBFS. |
| `shift_vent_1`, `_2` | 0.45 / 0.60 s | Plasma vent for hard upshifts: a pressurised release sweeping down, spiky arc crackle thinning out, a falling FM arc zap and a low whoomp. It has no gunshot crack, so it never sounds like the exhaust pops. Peak -4 dBFS. |

## Slot map and upload list

`P` = `ReplicatedStorage.Config.Audio.VehicleProfiles.EXOTIC_V10_AUDIO`. There are 14 files to upload, or 15 if both reactor options are uploaded to A/B in Studio. The limit is 26.

- Suggested asset names follow the hover_feel convention, with the place and version in the prefix.
- After the ids are filled, bump `P.ProfileRevision` so a live graph rebuilds.
- Fill the eight V10 slots together. Mixing round 3 and v2 loops gives a timbre jump inside the crossfade.

| # | File | Slot | Kind | Replaces (keep for rollback) | Suggested asset name |
|---|---|---|---|---|---|
| 1 | `v10_idle_1000.wav` | `P.RevLayers.V10Idle1000@AssetId` | loop | 125173679945815 | PR98 exotic v2 v10_idle_1000 |
| 2 | `v10_on_2000.wav` | `P.RevLayers.V10On2000@AssetId` | loop | 133374322889641 | PR98 exotic v2 v10_on_2000 |
| 3 | `v10_on_3500.wav` | `P.RevLayers.V10On3500@AssetId` | loop | 97619184312663 | PR98 exotic v2 v10_on_3500 |
| 4 | `v10_on_5000.wav` | `P.RevLayers.V10On5000@AssetId` | loop | 123674696611624 | PR98 exotic v2 v10_on_5000 |
| 5 | `v10_on_6500.wav` | `P.RevLayers.V10On6500@AssetId` | loop | 125631981636647 | PR98 exotic v2 v10_on_6500 |
| 6 | `v10_on_8000.wav` | `P.RevLayers.V10On8000@AssetId` | loop | 74002081218662 | PR98 exotic v2 v10_on_8000 |
| 7 | `v10_off_3000.wav` | `P.RevLayers.V10Off3000@AssetId` | loop | 123944711985104 | PR98 exotic v2 v10_off_3000 |
| 8 | `v10_off_6000.wav` | `P.RevLayers.V10Off6000@AssetId` | loop | 88775295273501 | PR98 exotic v2 v10_off_6000 |
| 9 | `reactor_whine.wav` | `P@TurboWhistleAssetId` (reactor line, `ReactorEnabled` 1) | loop | interim turbine_high 126900976760387 | PR98 exotic v2 reactor_whine |
| 10 | `grav_skid.wav` | `P@SlipStrainAssetId` (recommended; see below) | loop | stabiliser_strain 80719035328360 | PR98 exotic v2 grav_skid |
| 11 | `shift_thunk_1.wav` | `P@ShiftThunk1AssetId` (new slot, blank today) | one-shot | none | PR98 exotic v2 shift_thunk_1 |
| 12 | `shift_thunk_2.wav` | `P@ShiftThunk2AssetId` | one-shot | none | PR98 exotic v2 shift_thunk_2 |
| 13 | `shift_vent_1.wav` | `P@ShiftVent1AssetId` | one-shot | none | PR98 exotic v2 shift_vent_1 |
| 14 | `shift_vent_2.wav` | `P@ShiftVent2AssetId` | one-shot | none | PR98 exotic v2 shift_vent_2 |
| (15) | `reactor_core_alt.wav` | `P@TurboWhistleAssetId`, only instead of #9 | loop | | PR98 exotic v2 reactor_core_alt |

**Notes**

- **grav_skid** goes in SlipStrain because CONTRACT 6 drives the spin through SlipStrain (`max(slip, FeelSpin x SpinStrainGain)`).
  - SlipStrain also plays in drifts, so drifts would get the grav skid too.
  - If Oscar prefers today's drift squeal, leave SlipStrain as it is and keep `grav_skid` for a later dedicated slot. That costs one more local voice.
  - The recommended mapping adds no loop voice. The four shift slots are the audio part's voices (see audio/NOTES.md).
- **Gains** need no change to start: `ShiftThunk1/2Gain` 0.5, `ShiftVent1/2Gain` 0.55, `ReactorGain` 0.16, and `SlipStrainGain` 0.24 (grav_skid has the same RMS as stabiliser_strain).
- **Uploading** is Oscar's step, through the Creator Hub or by adapting `scripts/hover_feel/synth/upload_assets.py`.
  - That script hard-codes the v3 owner's `USER_ID`, and PR98 is in its own universe, so confirm the creator and the experience's audio permission first.
  - Record the ids next to the file names, as `scripts/hover_feel/audio/asset_ids.json` does.

## The listen pack

### What it models

**The car.** An S-tier stock Exotic calibrated to design_draft 3.3: top 174 mph, boosted 214. Gear redlines are 47 / 68 / 89 / 111 / 134 / 159 / 184 mph. The gearbox uses the CONTRACT 4.2 numbers, with physics at 240 Hz and the Feel attributes published at 60 Hz and quantised as in CONTRACT 3.1.

**The rules implemented.**
- Launch clutch slip and thrust-slip flare.
- Upshift cut and blend, and downshifts with no cut.
- Flat, part and cruise upshift points, LiftHold and kickdown.
- Braking and coast downshifts.
- The time-weighted limiter.
- Neutral revs while anchored.
- Overdrive with BoostShare and the speed guard.
- Engine braking, rolling resistance and the derived drag.

**The audio port.** A line-for-line Python port of `updateFeel` for the local car:
- load follower and bark;
- rev follower;
- the log-frequency equal-power `ladderWeights` crossfade, neighbour detune, twin engines and life noise;
- ducks, the feel loops and pops.

It also ports the remote path: three Load "Any" voices at 15 Hz. The new rules follow the audio part's after-files:
- `FeelRpm` to rev, with RevRpmMax 8600 mapped to the top;
- the upshift drop and the dip envelope;
- the downshift blip and load spike;
- ShiftThunk and ShiftVent pairs, with a crackle pop when the vents are blank;
- the reactor with chirp and Overdrive gain;
- spin strain;
- remote voices picked by `gearedVoices` (V10On3500 / On5000 / On8000).

**Where the tuning comes from.** Read at run time from `before/config.json`, `audio/after/VehicleAudioCatalog.lua` and `audio/config.py`, so the pack follows the audio part's values.

**Approximate (also stated in `listen/README.txt`):**
- The sub-bus effects (Peak sweep, 3-band tilt, limiter tremolo) are an STFT and LFO approximation of Roblox's AudioFilter, AudioEqualizer and AudioTremolo.
- Pitch is interpolated between update ticks.
- Spin, the power-brake hold and launch slip are scripted inputs.
- The pass-by adds doppler, which Roblox may not apply.
- Toolbox sounds (blow-off, generic idle) are left out.

Every file shares one master gain (`MASTER_DB`), so level differences are real. The pass-by is quiet because it is played at the in-game distance curve.

### Files (`output/drivetrain_feel_audio/listen/`)

| File | Length | Scenario |
|---|---|---|
| `new_01_full_throttle_run` | 17.0 s | Idle, then flat out through all 7 gears. Upshifts at 45 / 66 / 86 / 108 / 130 / 154 mph, about 0.97 of redline. 0-60 in 2.1 s, 0-100 in 4.1 s, 167 mph at 16 s (today: 1.4 s, 2.6 s, 174 mph). |
| `new_02_lift_off_engine_braking_downshifts` | 12.0 s | Flat at 165 mph in 7th, then a lift: bang and pops, engine braking, 167 to 117 mph in 5 s. Then braking to a stop with six downshift blips (7 to 1). |
| `new_03_neutral_revs_limiter_then_launch` | 9.5 s | Countdown in N: two blips, then held on the limiter. GO at 6.0 s launches in 1st. |
| `new_03_..._alt_fall8_target112` | 9.5 s | The same with `EngineFallScale` 8 and `NeutralRevTarget` 1.12 (see findings). |
| `new_04_power_brake_launch` | 8.0 s | W+S held for 1.6 s (rev held at about 4840 rpm; an assumption), then S released: dump slip, flare, and a launch through 4 shifts. |
| `new_05_spin_out_and_catch` | 8.0 s | 14 mph, lift, then stab full throttle with full lock. The spin builds, the engine free-revs at 0.85 of redline, and grav skid and strain rise. A lift catches it, then the car drives away. |
| `new_06_part_throttle_short_shifts_kickdown` | 16.0 s | Short shifts at 45 % throttle (about 0.68 of redline), two cruise upshifts at 20 %, a lift, then a kickdown from 7th to 3rd after 0.12 s. |
| `new_07_overdrive_long_boost` | 9.0 s | Flat in 7th from 160 mph, then a **long 5 s boost** (a real tank lasts at most 2 s). Overdrive pins the engine at redline for 2.3 s, up to 195 mph. Then the in-gear limiter until the speed falls under 184 mph. |
| `new_08_pass_by_remote_car` | 5.5 s | Another player's car passing 10 studs away while accelerating. Three voices, GearForSpeed shifts, doppler and the distance curve. |
| `new_01_full_throttle_run_gearing0` / `_gearing2` | 17.0 s | The `FeelGearing` dial at 0 (no cut, CVT-like 1 s rev glide) and at 2. |
| `today_vs_new/full_run_A_today` | 17.0 s | Today's physics, today's speed-based rev formula, today's loops. |
| `today_vs_new/full_run_B_new` | 17.0 s | Same as new_01. |
| `today_vs_new/full_run_C_today_sound_on_new_pace` | 17.0 s | Today's sound on the new speed trace. B against C isolates the sound change. |
| `today_vs_new/full_run_D_interim_new_gearbox_uploaded_loops` | 17.0 s | The new rules with only the sounds already uploaded: today's V10 loops, turbine_high as the reactor, blank shift slots. This is what plays after the code install and before any upload. |
| `today_vs_new/full_run_A_then_B` | 34.8 s | A, 0.8 s of silence, then B. |
| `today_vs_new/pass_by_A_today`, `_B_new`, `_A_then_B` | 5.5 / 5.5 / 11.9 s | The same pairs for the pass-by. |
| `stems/new_01_..._engine_only`, `stems/today_01_..._engine_only` | 17.0 s | The rev voices alone (after the bus for new), for judging the loops. |

### Findings for the integrator

These come from the sim, not from Play.

1. **The neutral limiter bounces slowly with the contract numbers.**
   - It bounces at 3.6 Hz, between 5810 and 8600 rpm: a deep "braap-braap" rather than a limiter stutter.
   - The cause: the 45 ms minimum cut meets a fast free-rev fall (0.06 s x `EngineFallScale` 1.5), and the target is only 1.02 of redline, so the climb back is slow.
   - With `EngineFallScale` 8 and `NeutralRevTarget` 1.12 it bounces at 12.8 Hz between 7920 and 8600 rpm (the `_alt` file).
   - The physics part may want a separate neutral fall rate.
2. **After a boost the car can sit on the limiter.**
   - When a boost ends above top-gear redline (184 mph), the car rides the in-gear limiter until drag brings it back under. In the demo that is 12 bounces in about 1 s, with the stutter and the matching HUD and VFX cues.
   - Option: keep Overdrive (no cut) while `rpm_road >= R` in top gear until the speed falls back under.
3. **`FeelGearing` also changes pace.**
   - At 16 s the car reaches 151 mph at gearing 0 and 143 mph at gearing 2, against 167 mph at 1.
   - The dial scales `GearTorqueExponent`, and the derived drag depends on it. The physics and model parts should confirm this is intended.
4. **Other cars sound different.** They use On3500 / On5000 / On8000 with no idle loop, against Idle1000 / On5000 / On8000 today. They shift about 0.92 of the way to redline, a little before the local car.

## Not verified

- Nobody has heard any of these files yet. The numbers above prove loop integrity, levels, pitch anchors and the gearbox timeline, not that a sound is pleasing.
- The effects chain and the doppler are approximations, as listed above.
- The demo car's thrust, brake and traction are calibrated estimates (CAR in `listen.py`), not the model part's per-car numbers.
