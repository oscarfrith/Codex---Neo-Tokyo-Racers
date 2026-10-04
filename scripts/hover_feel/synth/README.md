# Exotic category audio synthesis

Procedural game audio for the Exotic hover cars: a V10 engine core plus sci-fi layers
(turbines, energy hum, thruster, supercharger) and one-shots (boost, flutter, impacts).
Everything is synthesised with numpy and the standard library; there are no samples.

```
py -3 scripts/hover_feel/synth/make_sounds.py   # regenerate all WAVs + manifest.json
py -3 scripts/hover_feel/synth/verify.py        # read the WAVs back, check them, write the contact sheet
```

- Output: `output/hover_feel_audio/exotic/*.wav` (44.1 kHz, 16-bit, mono) and `manifest.json`.
- Contact sheet: `output/hover_feel_audio/exotic_contact_sheet.png` (log-frequency spectrograms, 80 dB range).
- Deterministic: every sound has a fixed seed, so a rerun gives byte-identical files.
- `output/` is untracked scratch space. The scripts are the source of truth.

## How loops stay seamless

Every component of a loop is periodic over the loop length N: tones sit on integer FFT bins,
noise is built in the FFT domain (so it is N-periodic), modulators are N-periodic noise,
saturation is memoryless (tanh), and all filtering multiplies the whole-loop FFT. The loop
therefore has no seam by construction; `verify.py` measures it anyway (sample step, spectral flux, and a broadband click detector above 15 kHz at the join).

## Engine loops (V10)

Firing frequency = rpm / 60 x 5. One engine cycle (ten firings) is a wavetable whose harmonics
are firing harmonics (dominant), the 2.5 order of each bank, and engine/half orders from cylinder
differences, shaped by a spectral tilt and exhaust formants. It is read with a jittered phase,
scaled per firing event, mixed with firing-synchronous noise, saturated and EQ'd.

| File | Rev | Firing Hz | Notes |
| --- | --- | --- | --- |
| v10_on_2000 / 3500 / 5000 / 6500 / 8000 | on-throttle | 166.67 / 291.67 / 416.67 / 541.67 / 666.67 | Bright and full; tilt flattens and drive rises with revs. A ring-mod sheen at -14 dB (carrier 2.76 x firing, derived from the engine phase) gives a metallic sci-fi edge that tracks the revs. |
| v10_off_3000 / 6000 | coast | 250 / 500 | Low-passed, 700 Hz scoop, strong per-firing gain variation (burble), dense quiet pops. |
| v10_idle_1000 | idle | 83.33 | Hybrid idle: lumpy V10 burble, a raspy energy-core hum on 125 Hz (a fifth above the firing note) throbbing at 2 Hz, and a faint 2640 Hz turbine whisper. |

The manifest gives `firing_hz`, `engine_cycles` and `firing_periods` per loop. Lengths are chosen
so the loop holds a whole number of engine cycles (2.88 to 3.0 s). If a resonance ever overtakes
the firing line, that one FFT bin is raised and the gain is recorded as `firing_anchor_gain_db`
(currently 0 dB for all eight).

Suggested use: equal-power crossfade between neighbouring `on` loops by rpm, PlaybackSpeed =
live rpm / loop rpm, and crossfade on/off sets by throttle.

## Sci-fi layer loops

| File | Main tone | Synthesis |
| --- | --- | --- |
| turbine_low | 1320 Hz blade pass | 24-blade wavetable (blade-pass harmonics + shaft buzz-saw lines), twin engine 3.3 Hz sharp, inharmonic second spool, shaped hiss, low rumble. Rasp: sawtooth buzz series two octaves down, band-limited fold, 60 to 120 Hz roughness. |
| turbine_high | 2640 Hz | Same model one octave up, different seed. |
| energy_hum | 80 Hz | Four buzzy pulse voices (root, +2.3 Hz, detuned fifth, sub octave) beating, a saw voice an octave up, 50 Hz ring, tanh plus fold, 60 to 120 Hz roughness, formants, arc crackle. |
| thruster_roar | 48 Hz growl | Turbulence-modulated low noise, jittered low growl, expanded-noise crackle, saturation. Use as the lower body layer under boost_loop. |
| boost_loop | 660 Hz | Whole-boost loop (3.5 s): afterburner roar under a raspy saw-voice energy scream (root, twin 4 Hz sharp, fifth) with a 12 Hz overdrive tremor. Pitch 0.9 to 1.15. |
| supercharger_whine | 1002.67 Hz mesh | Mesh orders 1 to 4 phase/amplitude modulated at the 62.67 Hz shaft rate (sidebands), light air noise. Pitch +/- an octave. |
| stabiliser_strain | 2350 Hz | FM-warbled shrieks at 1 : 1.5 : 2 with a saw buzz an octave down, band-limited fold, narrow-band noise on the same pitches, 60 to 120 Hz roughness, jet hiss. |
| drift_charge | 330 Hz | Just-intonation stack (330, 495, 660, 990, 1320, 1650 Hz), each a detuned pair with its own beat rate, 8 Hz pulse, shimmer. Pitch up with charge. |
| wind_rush | none | Shaped broadband noise with mild gusting and two breathy whistles whose centres wander around 2300 and 3900 Hz (no fixed drone). Raise gain and PlaybackSpeed with speed. |
| wind_buffet | none | Low noise plus a mid flap band under an irregular 3 to 14 Hz envelope, for very high speed. |
| scrape_loop | 740 Hz lowest mode | Stick-slip modulated noise through narrow inharmonic plate resonances, sparse grit, saturation. |

## One-shots

| File | Synthesis |
| --- | --- |
| boost_ignite | 100 ms reverse suck-in (hard gate), crack (click, snap, saturated body), 110 to 32 Hz sub drop, short whoosh, then a raspy shimmer that rises an octave onto the boost_loop root (660 Hz) with the same 12 Hz tremor and fades under the loop. |
| boost_release | The scream falls from 1320 to 250 Hz with a slowing tremor, vent hiss, four flutter chuffs. |
| pop_1 .. pop_4 | Overrun crackles (0.35 to 0.4 s): click, noise burst, saturated pitched body at 180 / 260 / 130 / 320 Hz; pop_2 and pop_4 add a ring-modulated electric zap edge. |
| bang_1, bang_2 | Backfires (0.75 / 0.85 s): crack, saturated body (95 / 70 Hz), sub, a low whump swelling about 40 ms later, light sizzle. |
| turbo_flutter | Eight chuffs slowing from 24 to 13 Hz, each a downward-swept noise burst plus pitched thup. |
| drift_release | Pop, three-octave saturated upward zap with a fifth, pings at 2640/3960/5280 Hz, noise sparkle. |
| impact_light / medium / heavy / severe | Click, pitched thud, low noise body, inharmonic ring with beating doublets, debris grains; heavier hits are lower, longer, add crunch and a bounce. Peaks step -8 / -6 / -4 / -3.2 dBFS. |
| land_thump | Saturated sub thump (85 to 40 Hz), low body noise, compression hiss whose centre rises then relaxes. |

The raspy loops (turbines, energy_hum, stabiliser_strain, boost_loop) are low-passed at 7.8 kHz
(8th order); `verify.py` checks that energy above 9 kHz is at least 25 dB below the total.

## Visual hooks

All of these are in `manifest.json` (`transient_peak_ms`, `modulation_hz`, and the boost_ignite keys).

| Sound | Hook |
| --- | --- |
| boost_ignite | Suck-in starts 0 ms (pull light/particles inward), crack at 100 ms (flash; loudest sample at 126 ms), shimmer hand-over at 600 ms (boost_loop should be at full gain; shimmer has faded by about 1.6 s). |
| boost_loop | 12 Hz tremor: pulse flame length or glow at 12 Hz x PlaybackSpeed. |
| boost_release | Starts at 0 ms with the vent; flutter chuffs from 160 ms (peak at 164 ms): puff the vents. |
| v10_idle_1000 | 2 Hz energy-core throb: slow glow pulse on a parked car. |
| energy_hum | 2.33 Hz beat (x PlaybackSpeed). |
| turbine_low / turbine_high | 3.33 Hz twin-engine beat. |
| drift_charge | 8 Hz tension pulse (x PlaybackSpeed, so it speeds up as charge builds). |
| wind_buffet | Irregular 3 to 14 Hz buffet: camera shake rather than a steady pulse. |
| pop_1 .. pop_4 | Peak at 2 to 6 ms: fire the fireball on play. |
| bang_1 / bang_2 | Crack peak at 9 / 14 ms, whump swell around 40 ms: flash first, fireball bloom just after. |
| drift_release | Pop at 0 ms, zap tops out and pings start at about 146 ms. |
| turbo_flutter | Eight chuffs, first at 0 ms, slowing from 24 to 13 Hz. |
| impact_* | Hit at 0 ms. Heavy and severe have a second bounce (their loudest sample, 62 / 82 ms). |
| land_thump | Thump peak at 15 ms; compression hiss swells over the next 100 ms. |

## Levels

- Loops: -17 dBFS RMS (all 19 matched), soft-limited under -3.2 dBFS, DC removed. Balance layers with Sound.Volume in game.
- One-shots: peak normalised (see above), 0.3 ms de-click ramp, cosine fade to digital silence.

## Upload notes (Roblox)

- All files are under 7 s and mono; position them in 3D with the Sound's parent part.
- Roblox transcodes uploads to a lossy format. Gapless looping of the WAV is exact, but check each
  loop in Studio after upload with `Sound.Looped = true`; if a tick appears it comes from the
  transcode, not the source. Uploading as WAV (not MP3) avoids encoder padding.
- Set `Sound.Looped = true` for `kind: loop` in the manifest; one-shots play once.
- Audio assets need the uploader's permission for the experience; record the asset ids next to
  the file names from `manifest.json` when they exist.
- Nothing here has been listened to by a person yet. The numbers in `verify.py` prove loop
  integrity and levels, not that a sound is pleasing.
