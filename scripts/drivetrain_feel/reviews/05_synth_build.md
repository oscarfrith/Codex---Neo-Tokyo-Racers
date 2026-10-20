I've built the synth part (`make_exotic_v2.py`, `listen.py` and `README.md` in `scripts/drivetrain_feel/synth/`), ran both, and confirmed every WAV exists with the durations below. Reruns give byte-identical files. Nobody has listened to any of it yet: the checks cover loop seams, levels, pitch lines and the gearbox timeline, not whether it sounds good. Nothing was uploaded, Studio was not used, there were no git commands, and nothing outside `synth/` and `output/` was edited. I deleted a `__pycache__` my import of `audio/config.py` left in the audio part's folder, and turned off bytecode writes so it can't happen again.

**Upload candidates** (`output/drivetrain_feel_audio/exotic_v2/`): 14 files, or 15 if both reactor options go up, against the 26 limit. The README has the slot map, the ids each file replaces and suggested asset names.
- **Grungier V10 hybrid**, same rpm points and modes as today's slots, so they map one to one:
  - `v10_idle_1000` 3.00 s
  - `v10_on_2000` 3.00 s, `v10_on_3500` 2.98 s, `v10_on_5000` 3.00 s, `v10_on_6500` 2.88 s, `v10_on_8000` 3.00 s
  - `v10_off_3000` 3.00 s, `v10_off_6000` 3.00 s
- **Reactor whine** for the TurboWhistle slot: `reactor_whine` 3.0 s (recommended), or `reactor_core_alt` 3.0 s as the alternative.
- **Grav skid:** `grav_skid` 3.0 s. I recommend the SlipStrain slot, because the contract drives spins through it. That slot also plays in drifts, so drifts would get the new sound too.
- **Shift sounds:** `shift_thunk_1` 0.30 s, `shift_thunk_2` 0.36 s, `shift_vent_1` 0.45 s, `shift_vent_2` 0.60 s.

Compared with today's loops, the mid-range loops are clearly lumpier and have more low end, and the sci-fi sheen is 5 dB lower. The 6500 and 8000 loops, which the gearbox plays most, changed least: about 2-3 dB noisier and less whiny. The README names the settings to push them further. `v10_off_6000` needed a 7.7 dB boost on its 500 Hz pitch line (4.0 dB today), so listen for a whistle when coasting.

**Listen pack** (`output/drivetrain_feel_audio/listen/`), on an S-tier stock Exotic with the contract 4.2 numbers:

| File | Length |
|---|---|
| `new_01_full_throttle_run` (0-60 in 2.1 s, 0-100 in 4.1 s; today 1.4 s and 2.6 s) | 17.0 s |
| `new_02_lift_off_engine_braking_downshifts` | 12.0 s |
| `new_03_neutral_revs_limiter_then_launch`, plus an `_alt` tune | 9.5 s each |
| `new_04_power_brake_launch` | 8.0 s |
| `new_05_spin_out_and_catch` | 8.0 s |
| `new_06_part_throttle_short_shifts_kickdown` | 16.0 s |
| `new_07_overdrive_long_boost` (a 5 s boost, longer than a real tank, so Overdrive is audible) | 9.0 s |
| `new_08_pass_by_remote_car` (with doppler) | 5.5 s |
| `new_01` variants at `FeelGearing` 0 and 2 | 17.0 s each |
| `today_vs_new/full_run_A_today`, `_B_new`, `_C_today_sound_on_new_pace`, `_D_interim_new_gearbox_uploaded_loops` | 17.0 s each |
| `today_vs_new/full_run_A_then_B` | 34.8 s |
| `today_vs_new/pass_by_A_today`, `_B_new` | 5.5 s each |
| `today_vs_new/pass_by_A_then_B` | 11.9 s |
| `stems/` engine-only versions of today's and the new full run | 17.0 s each |

- **Interim version:** the D file is the new gearbox and audio rules with only the sounds already uploaded, i.e. what the game will sound like after the code install and before any upload.
- **What's approximate:** the effects chain (filter, EQ, limiter stutter), the doppler, and the scripted spin and power-brake inputs. This is stated in `listen/README.txt` and the synth README.
- **Where the audio values come from:** read at run time from the live profile and the audio part's files, so the pack follows their tuning.
- **Re-rendering:** `--set Name=value` re-renders with any `Drivetrain.exotic` value changed.

**Findings for the integrator** (from the simulation, not from Play):
- **Neutral limiter:** with the contract numbers it bounces slowly and deeply, at 3.6 Hz between 5810 and 8600 rpm. With `EngineFallScale` 8 and `NeutralRevTarget` 1.12 it's a proper 12.8 Hz stutter between 7920 and 8600 rpm (the `_alt` file).
- **After a boost:** if the boost ends above top-gear redline (184 mph), the car sits on the limiter until drag brings it back under. In the demo that was about 12 bounces in roughly 1 s.
- **`FeelGearing` dial:** it also changes pace. The car reaches 151 mph at 0 and 143 mph at 2, against 167 mph at 1, because the drag calculation depends on it.
- **Power-brake hold:** the demo assumes the engine revs to about 4840 rpm while W and S are held. The physics part should confirm.

Files are in `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\`:
- scripts\drivetrain_feel\synth\make_exotic_v2.py
- scripts\drivetrain_feel\synth\listen.py
- scripts\drivetrain_feel\synth\README.md
- output\drivetrain_feel_audio\