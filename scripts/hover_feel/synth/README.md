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

Round 3 (depth and grunge): the orders under the firing line are 2.2x stronger; the firing
sub-octave, first and half orders, a 35 to 220 Hz rumble bed and firing-pulsed exhaust rasp
(300 to 1200 Hz) are added before a harder, more asymmetric saturator so they intermodulate
into a growl; the exhaust formants moved down (450 / 900 / 1500 Hz); the 2 to 5 kHz band sits
4 to 7 dB below round 2 and the ring-mod sheen dropped from -14 to -20 dB. `verify.py` prints
the band shares against `baseline_round2.json`.

| File | Rev | Firing Hz | Notes |
| --- | --- | --- | --- |
| v10_on_2000 / 3500 / 5000 / 6500 / 8000 | on-throttle | 166.67 / 291.67 / 416.67 / 541.67 / 666.67 | Muscular and snarling; drive rises with revs. A soft ring-mod sheen at -20 dB (carrier 2.76 x firing, derived from the engine phase) keeps a sci-fi edge that tracks the revs. |
| v10_off_3000 / 6000 | coast | 250 / 500 | Low-passed, 700 Hz scoop, strong per-firing gain variation (burble), dense quiet pops. |
| v10_idle_1000 | idle | 83.33 | Hybrid idle: lumpy V10 burble, a raspy energy-core hum on 125 Hz (a fifth above the firing note) throbbing at 2 Hz, and a faint 2640 Hz turbine whisper. |

The manifest gives `firing_hz`, `engine_cycles` and `firing_periods` per loop. Lengths are chosen
so the loop holds a whole number of engine cycles (2.88 to 3.0 s). If a resonance ever overtakes
the firing line, that one FFT bin is raised and the gain is recorded as `firing_anchor_gain_db`
(round 3: 0 to 1.4 dB on the on-throttle loops, 4.0 dB on v10_off_6000, 4.4 dB on the idle, where the new low orders and the core hum compete with it).

Suggested use: equal-power crossfade between neighbouring `on` loops by rpm, PlaybackSpeed =
live rpm / loop rpm, and crossfade on/off sets by throttle.

## Sci-fi layer loops

| File | Main tone | Synthesis |
| --- | --- | --- |
| turbine_low | 1320 Hz blade pass | 24-blade wavetable (blade-pass harmonics + shaft buzz-saw lines), twin engine 3.3 Hz sharp, inharmonic second spool, shaped hiss. Rasp: sawtooth buzz series two octaves down, band-limited fold, 60 to 120 Hz roughness. Round 3: blade-pass tone about 4.6 dB lower and a 60 to 500 Hz roar bed. |
| turbine_high | 2640 Hz | Same model one octave up, different seed. |
| energy_hum | 80 Hz | Four buzzy pulse voices (root, +2.3 Hz, detuned fifth, sub octave) beating, a saw voice an octave up, 50 Hz ring, tanh plus fold, 60 to 120 Hz roughness, formants, arc crackle. |
| thruster_roar | 48 Hz growl | Body layer under boost_loop: turbulence-modulated rumble, low growl and low fire texture, low-passed at 300 Hz (98 % of its energy is below 250 Hz). |
| boost_loop | 110 Hz chord root | Whole-boost loop (3.5 s), a different family from the engines: broadband fire with an 80 to 400 Hz body and crackle, a pulse-jet train of 42 to 67 Hz sub thumps at 10 per second (each with a detonation noise burst), and a modest saturated power chord (110 / 165 / 220 Hz). Pitch 0.9 to 1.15. |
| supercharger_whine | 501.33 Hz mesh | Gear-drive growl-whine, an octave lower than round 2: eight mesh orders with heavy 62.67 Hz shaft sidebands, a sawtooth shaft growl underneath, fold rasp, 60 to 120 Hz roughness, pulsing air noise. |
| stabiliser_strain | 2350 Hz | FM-warbled shrieks at 1 : 1.5 : 2 with a saw buzz an octave down, band-limited fold, narrow-band noise on the same pitches, 60 to 120 Hz roughness, jet hiss. |
| drift_charge | 330 Hz | Just-intonation stack (330, 495, 660, 990, 1320, 1650 Hz), each a detuned pair with its own beat rate, 8 Hz pulse, shimmer. Pitch up with charge. |
| wind_rush | none | Shaped broadband noise with mild gusting and two breathy whistles whose centres wander around 2300 and 3900 Hz (no fixed drone). Raise gain and PlaybackSpeed with speed. |
| wind_buffet | none | Low noise plus a mid flap band under an irregular 3 to 14 Hz envelope, for very high speed. |
| scrape_loop | 740 Hz lowest mode | Stick-slip modulated noise through narrow inharmonic plate resonances, sparse grit, saturation. |

## One-shots

| File | Synthesis |
| --- | --- |
| boost_ignite | Afterburner lighting (2.2 s): 100 ms reverse suck-in (hard gate), cannon crack (click, snap, saturated body, low boom), 50 to 30 Hz sub drop held about 300 ms, thick fire-blast whoosh, then a power-up chord sweep that dives from 330 to 80 Hz and rises onto the boost_loop root (110 Hz) while 10 Hz pulse-jet thumps fade in. |
| boost_release | Decisive ending (1.3 s): 30 ms roar cut-off, pressure-release pshh, thunk at 90 ms, short chord tone falling from 220 to 70 Hz, four flutter chuffs from 280 ms. |
| pop_1 .. pop_4 | Overrun / anti-lag backfires, gunshot-like (0.22 to 0.30 s): sub-millisecond noise crack with energy to 6.5 to 9 kHz, a hard 90 to 150 Hz thump, a tight two-resonance exhaust-pipe tail (240/410, 310/480, 205/350, 270/455 Hz, noise-excited) and a very slight metallic pipe ring; hard-clipped, almost no reverb. No electric zap (removed in round 4). Peaks -3.2 dBFS. |
| bang_1, bang_2 | Shotgun backfire (0.55 / 0.68 s): two cracks 55 / 75 ms apart, each with a heavier 80 / 65 Hz thump and pipe tail, then a short flame whoosh with crackle. |
| turbo_flutter | Eight chuffs slowing from 24 to 13 Hz, each a downward-swept noise burst plus pitched thup. |
| drift_release | Pop, three-octave saturated upward zap with a fifth, pings at 2640/3960/5280 Hz, noise sparkle. |
| impact_light / medium / heavy / severe | Real-car hits built only from shaped noise (no sine, sweep or ring): dead low thud, crumpling sheet metal (dense irregular 400 Hz to 3 kHz noise-band bursts of 20 to 60 ms), plastic/carbon crack clicks; heavy and severe add a low whump, sparse debris and glass ticks over 0.3 to 0.8 s, and a faint electrical fizz 18 dB under the crumple. 0.22 / 0.45 / 0.90 / 1.30 s; peaks -8 / -6 / -4 / -3.2 dBFS. |
| land_thump | Suspension-bottoming thud (0.6 s): dead low noise thud, mechanical clunk, brief fixed-band air-compression huff. No tone. |

The raspy loops (turbines, energy_hum, stabiliser_strain) are low-passed at 7.8 kHz (8th order)
and boost_loop at 8 kHz; `verify.py` checks that energy above 9 kHz is at least 25 dB below the total.

## Boost versus engine (family separation)

`verify.py` prints, and `manifest.json` stores under `spectral_distance`, the cosine distance
between octave-band energy distributions. boost_loop against v10_on_6500 is 0.66, against the
turbine 0.60 and the supercharger 0.62, while neighbouring engine loops are 0.01 to 0.03 apart.
71 % of boost_loop's energy is below 250 Hz, against 6 % for v10_on_6500. The stricter
third-octave contour figure (1 - correlation of dB levels) is also listed.

## Visual hooks

All of these are in `manifest.json` (`transient_peak_ms`, `modulation_hz`, and the boost_ignite keys).

| Sound | Hook |
| --- | --- |
| boost_ignite | Suck-in starts 0 ms (pull light/particles inward), crack at 100 ms (flash; loudest sample at 125 ms), sweep bottoms out at 280 ms, first pulse-jet thump at 350 ms then every 100 ms, hand-over at 700 ms (boost_loop should be at full gain; the one-shot has faded by about 1.8 s). |
| boost_loop | 10 Hz pulse-jet thump train (`modulation_hz`): pulse flame length, shock diamonds or glow at 10 Hz x PlaybackSpeed. |
| boost_release | Roar cuts at 0 ms with the pshh (vent puff), thunk at 90 ms (nozzle snaps shut), four chuffs from 280 ms. |
| v10_idle_1000 | 2 Hz energy-core throb: slow glow pulse on a parked car. |
| energy_hum | 2.33 Hz beat (x PlaybackSpeed). |
| turbine_low / turbine_high | 3.33 Hz twin-engine beat. |
| drift_charge | 8 Hz tension pulse (x PlaybackSpeed, so it speeds up as charge builds). |
| wind_buffet | Irregular 3 to 14 Hz buffet: camera shake rather than a steady pulse. |
| pop_1 .. pop_4 | Crack at 0 ms (attack under 0.3 ms): fire the fireball on play. |
| bang_1 / bang_2 | First crack at 0 ms, second at 55 / 75 ms (`second_crack_ms`), flame whoosh peaks about 60 ms after the second (`whoosh_peak_ms`): two flashes, then the fireball. |
| drift_release | Pop at 0 ms, zap tops out and pings start at about 146 ms. |
| turbo_flutter | Eight chuffs, first at 0 ms, slowing from 24 to 13 Hz. |
| impact_* | Hit at 0 ms; crumple and debris scatter follow (heavy/severe debris lasts 0.3 to 0.8 s: sparks or shards). |
| land_thump | Thud at 0 ms (peak about 12 ms); huff swells over the next 40 ms: dust or jet-wash puff. |

Round 4 changed only the impacts, land_thump, pops and bangs; every other WAV is byte-identical to
round 3. `verify.py` compares attack time, crest factor, loudest 50 ms and a tonality figure for
those files against `baseline_round3.json`.

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
