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
therefore has no seam by construction; `verify.py` measures it anyway.

## Engine loops (V10)

Firing frequency = rpm / 60 x 5. One engine cycle (ten firings) is a wavetable whose harmonics
are firing harmonics (dominant), the 2.5 order of each bank, and engine/half orders from cylinder
differences, shaped by a spectral tilt and exhaust formants. It is read with a jittered phase,
scaled per firing event, mixed with firing-synchronous noise, saturated and EQ'd.

| File | Rev | Firing Hz | Notes |
| --- | --- | --- | --- |
| v10_on_2000 / 3500 / 5000 / 6500 / 8000 | on-throttle | 166.67 / 291.67 / 416.67 / 541.67 / 666.67 | Bright and full; tilt flattens and drive rises with revs. |
| v10_off_3000 / 6000 | coast | 250 / 500 | Low-passed, 700 Hz scoop, strong per-firing gain variation (burble), dense quiet pops. |
| v10_idle_1000 | idle | 83.33 | Lumpy: strong bank and half orders, more jitter. |

The manifest gives `firing_hz`, `engine_cycles` and `firing_periods` per loop. Lengths are chosen
so the loop holds a whole number of engine cycles (2.88 to 3.0 s). If a resonance ever overtakes
the firing line, that one FFT bin is raised and the gain is recorded as `firing_anchor_gain_db`
(currently 0 dB for all eight).

Suggested use: equal-power crossfade between neighbouring `on` loops by rpm, PlaybackSpeed =
live rpm / loop rpm, and crossfade on/off sets by throttle.

## Sci-fi layer loops

| File | Main tone | Synthesis |
| --- | --- | --- |
| turbine_low | 1320 Hz blade pass | 24-blade wavetable (blade-pass harmonics + shaft buzz-saw lines), twin engine 3.3 Hz sharp, inharmonic second spool, shaped hiss, low rumble. |
| turbine_high | 2640 Hz | Same model one octave up, different seed. |
| energy_hum | 80 Hz | Four buzzy pulse voices (root, +2.3 Hz, detuned fifth, sub octave) beating, 50 Hz ring, hard tanh, formants, arc crackle. |
| thruster_roar | 48 Hz growl | Turbulence-modulated low noise, jittered low growl, expanded-noise crackle, saturation. |
| supercharger_whine | 1002.67 Hz mesh | Mesh orders 1 to 4 phase/amplitude modulated at the 62.67 Hz shaft rate (sidebands), light air noise. Pitch +/- an octave. |
| stabiliser_strain | 2350 Hz | FM-warbled shrieks at 1 : 1.5 : 2, narrow-band noise on the same pitches, 50 to 110 Hz roughness, jet hiss. |
| drift_charge | 330 Hz | Just-intonation stack (330, 495, 660, 990, 1320, 1650 Hz), each a detuned pair with its own beat rate, 8 Hz pulse, shimmer. Pitch up with charge. |
| wind_rush | none | Shaped broadband noise with mild gusting (0.8 to 7 Hz). |
| scrape_loop | 740 Hz lowest mode | Stick-slip modulated noise through narrow inharmonic plate resonances, sparse grit, saturation. |

## One-shots

| File | Synthesis |
| --- | --- |
| boost_ignite | 0.26 s suck-in (rising swept noise and tone, hard gate), crack (click, snap, saturated body), 100 to 30 Hz sub drop, falling whoosh, twin turbine scream, short reverb. Crack lands at 0.26 s. |
| boost_release | Vent hiss, falling swept hiss, spool-down tone, six flutter chuffs. |
| turbo_flutter | Eight chuffs slowing from 24 to 13 Hz, each a downward-swept noise burst plus pitched thup. |
| drift_release | Pop, three-octave saturated upward zap with a fifth, pings at 2640/3960/5280 Hz, noise sparkle. |
| impact_light / medium / heavy / severe | Click, pitched thud, low noise body, inharmonic ring with beating doublets, debris grains; heavier hits are lower, longer, add crunch and a bounce. Peaks step -8 / -6 / -4 / -3.2 dBFS. |
| land_thump | Saturated sub thump (85 to 40 Hz), low body noise, compression hiss whose centre rises then relaxes. |

## Levels

- Loops: -17 dBFS RMS, soft-limited under -3.2 dBFS, DC removed. Balance layers with Sound.Volume in game.
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
