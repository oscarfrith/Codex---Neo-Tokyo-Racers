# DRIVE: Highway: engine audio, driving HUD and shift feel (read-only, for inspiration)

**Studio:** DRIVE: Highway DEVELOPMENT, studio_id `37878c5c-c5a4-4d97-89f0-d47334cfdae3`, Edit mode. Nothing was modified. I used only `script_read`, `script_grep`, `script_search` and `search_game_tree`.

**Root:** `ReplicatedStorage.Modules.Game.Racer`, written as `Racer.` below. `ServerStorage.Scratch.*` holds stale copies, which I ignored.

**Coverage:** I read `Audio/EngineAudio` in full (936 lines). `Audio/FXAudio` is 2134 lines; I read lines 1–260, 323–442, 992–1231, 1378–1552, 1677–1711 and 1780–2119. The rest (tips, tunnel, buildShift internals, rocket) I skipped. Everything else was targeted ranges. Anything I inferred rather than read is marked INFERRED.

---

## 1. Engine audio architecture

### API and graph
- It uses Roblox's new Audio API throughout: `AudioPlayer`, `AudioFader`, `AudioEqualizer`, `AudioFilter`, `AudioDistortion`, `AudioTremolo`, `AudioCompressor`, `AudioLimiter`, `AudioReverb`, `AudioEcho`, `Wire`, and AudioEmitter/Listener in `Mixer`.
- Plumbing helper: `Mixer.wire(source, target)` (`Audio/Mixer` L88).
- The graph is laid out in the `EngineAudio` header (L5–14):
  - on-load voices → OnSum → Lope → Drive → Tone → OnGate, with a tap from Tone → IntakeBP → IntakeGate → `bayBus`.
  - Lope → OverrunLP → DerivedGate (synthetic overrun below the real overrun loops).
  - off-load voices → OffSum → OffGate. Idle → IdleIn → IdleLope → IdleSub → IdleGate.
  - All four gates → EngSum → RunGate → CutSum. The startup one-shot → StartGate → CutSum.
  - CutSum → Out → Crunch → Presence → Sub → EngComp → EngLimit → **Cut (AudioTremolo)** → `mix.engineBus`.
- The Cut is deliberately placed after the dynamics, "so nothing refills the gaps" (L12–13).

### Mixer buses (`Audio/Mixer` L10–15)
| Bus | What goes on it |
|---|---|
| `engineBus` | the note, at the exhaust tips |
| `fxBus` | pops, bangs, flat-shift and 2-step cuts |
| `bayBus` | front of car: turbo, BOV flutter, intake |
| `interiorBus` | cabin only: lever, gate, clutch thud |
| `master` | dry, non-positional (wind) |

- Cabin filtering: `EXHAUST_CABIN_CUT = 2500` Hz with gain 0.56 (−5 dB); `BAY_CABIN_CUT = 3800` Hz with gain 0.8; `CABIN_TAU 0.07`.
- `Mixer.CAR_GAIN = 0.5` (L65).
- Master chain, "eleven" style: comp threshold −6, ratio 2, attack 0.025, release 0.25, limit −1; bay bus +3 dB (L57–62).

### Layers: a multi-loop sampler, not one pitched loop
- `Audio/Bank` L19–43, set `weihe`:
  - 7 on-load loops at ref 1000.2, 2010.6, 3017.4, 4041.9, 5364, 6544 and 7343 rpm.
  - 4 real overrun loops at 3330, 4110, 5150 and 5893 rpm.
  - 1 idle loop (ref 757, `at = 850`).
  - 1 startup recording: crank region 0.05–0.38 s, `catchAt 0.40`.
- Each entry carries `ref` (the measured rpm), `loop` (LoopRegion), `gainDb`, `tilt` (EQ tilt at 400/2500 Hz crossovers) and optional `hp`.
- Levels are calibrated to "−19 dB RMS at 1000 rpm WOT, +2.85 dB per rpm doubling; overrun 10.5 dB under; idle −26 dB" (L6–7).
- Per-car sets live in `Racer.Cars.<ID>.Audio`: `{engineSet, set, tune, fx, turboStyle, exhaustLevels}`. Resolution order is dev override > car attribute `EngineBank` > workspace attribute > car section > `Bank.ACTIVE` (EngineAudio L33–44).

### Pitch formula (EngineAudio L884)
```lua
v.player.PlaybackSpeed = math.clamp(rpm / v.def.ref, T.speedMin, T.speedMax) * speedScale * (1 + ds[i])
```
- `speedMin 0.45`, `speedMax 1.6`. `speedScale` = Mixer doppler × (1 + `lifePitch 0.0025` × slow noise) in "eleven" mode (L820).
- Pitch tracks the sim's rpm with no smoothing (`rpm = math.max(s.rpm, 0)`, L714).

### Crossfade curves (L317–337)
- Equal-power in **log-rpm** between neighbouring anchors: `x = log(rpm/a)/log(b/a)`, then `w1, w2 = cos(xπ/2), sin(xπ/2)`.
- Blending only happens inside a zone around the geometric midpoint: `blendOn 0.4`, `blendOff 0.5` of each interval. Outside it, each loop plays alone.
- While two loops blend they get a tiny opposite detune, `detune 0.006 × 4w1²w2²`, so they can't sit in a phase cancellation.

### Load and throttle timbre (L749–792, L775–823)
- **Load follower:** `Lt = max(throttle, engineLoad)`, smoothed with `loadAttack 0.022` s / `loadRelease 0.085` s, then shaped as `L = self.L ^ 0.8`.
- **On/off swap:** `theta = (1-L)·π/2`, `onW = cos`, `offW = sin`.
- **Tip-in bark:** `bark = max(bark·e^(−dt/0.13), clamp((L−Lprev)·1.6))`, applied as OnGate × (1 + 0.55·bark).
- **Idle hand-over:** `xi = max(clamp((rpm − idle.at)/330), L)`, equal-power.
- **Derived overrun below the real loops:** `smoothstep(2900, 3400, rpm)`. Below that band, the on-load loops go through a 1100 Hz low-pass at −4 dB.
- **Grit, "eleven" mode:**
  - Drive (`AudioDistortion.Level`) = 0.10 + 0.25·L + 0.15·boostN + 0.15·launchArmed.
  - Crunch (whole-note distortion) = 0.12 + 0.28·L + 0.18 while cutting.
  - Presence peak: 2800 Hz, Q 0.7, +2 + 4·L dB.
  - Sub low-shelf: 85 Hz, +2 + 6·L^1.5 dB.
  - Tone EQ: LowGain 2.5·L; HighGain −3 → +1.5 dB with boost.
  - EngComp: −10 threshold, ratio 2, 10 ms / 120 ms. EngLimit −3 dB.
  - Rev rise: `engSum = db(lifeDb·n4 + 6·rise·(0.4+0.6L))`, where `rise` is log-scaled from 2000 to 7000 rpm (L821–822).
- **Lope** (I5 firing warble): `AudioTremolo` at `rpm/120` Hz, depth 0.3, fading out between 1800 and 2300 rpm (L793–802).
- **Idle character:** idle lope 0.3 ± 0.14, hunt 1.2 % pitch, sub +5 dB. It is driven by Ornstein-Uhlenbeck noise (`_noise`, L626–633).
- **Style switch:** `EngineAudio.Style = "eleven" | "stock"` (L934). Stock bypasses every grit node.

### Intake vs exhaust vs mechanical
- **Exhaust:** the note on `engineBus`, at the tips.
- **Intake:**
  - Default: band-pass at `intakeHz 900`, Q 0.8, tapped after Tone into `bayBus`. Gain = engW·onW·run·db(−3)·(0.2+0.8L^1.3)·(0.5+0.5·boostN) (L789).
  - Or a real `set.intake` loop family, own car only (L540–551).
- **Mechanical** (`interiorBus`, own car only): lever click, synchro clunk, clutch-pedal thud (`FXAudio` L2093–2103).

### Turbo, whistle and blow-off
- **Whistle** (FXAudio L1859–1878):
  - Speed `(0.62 + 1.25·ts)`. Gain `smoothstep(0.08, 0.65, ts)·(0.35+0.65·thr)`.
  - `whistleHi` is octave-locked (`2·hz/hzHi`) and fades in over `smoothstep(0.55, 0.95, ts)·thr`.
  - Whoosh = `boostN·thr·0.8 + spoolUp·0.7`.
- **BOV event:** `Sim/Engine` L347–351 fires when `boost > bovThreshold` and `chargeTarget < charge − 0.5` (latched).
- **`FXAudio:bov`** (L1122–1174):
  - Boost below 0.45: "chatter" grain, length 0.28 + 0.5b.
  - Otherwise: flutter of length 0.55 + 1.25b (about 1.8 s at full boost), plus an air swell when b > 0.57.
- **Hybrid style:** a vent ("PSSH"), then a delayed surge, then a falling shaft whine (L1178–1217).
- Flutter is cut 0.12 s after the throttle goes back above 0.55, but only once 0.18 s has passed (L1842–1857).

### Backfire and crackle on lift-off (`Sim/Engine` L358–396)
- `loadMemory` rises while the pedal is above 0.6 and rpm is above `popRpm`; it decays with tau 0.4 s while loaded and 2.5 s after.
- **On lift:** if rpm > `bangLiftRpm`, boost > `bangLiftBoost` and the pedal was high within the last 0.25 s, a Bang fires after a 30–80 ms delay with strength 0.75–1.
- **Overrun pops:** a Poisson process at `(popRateLow..High by rpm) × popEnergy`.
- **`FXAudio:pop`** (L1066–1085):
  - Minimum 22 ms between pops.
  - Sharp vs round grain: P(sharp) = 0.25 + 0.6·strength.
  - Pitch is jittered and scaled by rpmNorm.
  - 18 % chance of a "pa-pap" double when strength > 0.55.
- Bangs get a flame "whoomp" layer when strength > 0.55.
- Space: a dark reverb (decay 0.9 s, wet −13 dB) plus an 85 ms slap-back echo (L360–374).

### Upshift (FXAudio header L6–12, `SHIFT` L89–113, functions L1451–1545)
- The flat-shift / quick-shift cut emits Bang events.
- With `SHIFT_SOUND = "gearbox"`, any Bang within `window 0.4` s of a GateMove/Shift is swallowed and replaced by one **"brap"**:
  - 1–3 round pops, `brapGap 0.028–0.045` s apart.
  - Each pop steps down `{0, −3, −6}` dB.
  - Pitch 0.86–0.96.
  - Each pop is cut short at 50 ms plus a 40 ms fade.
  - At most one brap per 0.45 s.
- **Outside sound:** a synchro clunk, `gearExt`, sized by `20·log10(k)·0.7` dB.
  - Box types: manual 0 dB / 1.0×; dct −1 dB / 1.12×; auto −5 dB / 0.9×.
  - Other players' cars sit a further −3 dB.
- **Cabin sound:** just two sounds, the lever click and the clunk (`cabin.simple = true`, clunkDb +7, speed 0.93, fade at 0.16 s).
- **Shift strength:** `minUp + (1−minUp)·pull/accelFull` with `minUp 0.3`, `accelFull 9` m/s², and `pull` held over 1.2 s. A flat-out shift (throttle ≥ 0.9) counts as 1; downshifts 0.5; out of N or into R 0.25. The camera uses the same rule.

### Downshift blip
- There is **no dedicated blip sample**. The blip is physics: `Input/Pilot:_assistBlip` (L829–891) raises the throttle while the clutch is in.
  - Constants: `revMax 0.85` ("a blip never floors it"), `revRelease 0.45`, `blipTap 0.14`, `blipRise 0.2`, `blipOut 0.12`, `proThrottleIn 0.08`.
- The sampler follows the rpm rise and adds the tip-in bark. The downshift clunk is `Bank.CLUNK_DOWN[1]`.

### Rev limiter bounce
- `Sim/Engine` L778–800: hard cut with `limiterMinOn`, `limiterMinCut`, `limiterHysteresis` and `limiterOvershoot`. It emits `LimiterHit` only in "main" mode.
- **Audio** (EngineAudio L836–868): the Cut `AudioTremolo` switches on.
  - "eleven" limiter: `freq 12, depth 1.0, duty 0.55, square 1`, held `limiterHold 0.12` s after each hit, depth smoothed with tau 12 ms.
  - The same node is reused with other settings for the launch (10 Hz), flat-shift (17 Hz, depth 0.9) and stall (7 Hz, sine).
  - Crunch gets +0.18 during the cut.
- `FXAudio:limiterHit` adds a 15 % chance of a 0.3-strength pop, at most one per 0.12 s (L1677–1684).

### Gear whine
- None. `script_grep "straight%-cut"` returns no hits, and there is no gearbox-whine layer (INFERRED from the reads).
- The nearest whine sources are:
  - the nitrous "scream" (a supercharger whine locked to revs, L1917–1919);
  - the hybrid turbo shaft wind-down;
  - the electric ARCLIGHT motor whine.

### How the note stays clean when rpm drops on a shift
- (a) Audio follows the real crank rpm (`Sim/Drivetrain` is a full LCP solver). PRO AUTO uses a "quick" path: ignition cut → dog swap → clutch slip, never passing through gear 0 (Drivetrain L17–18, L57–59).
- (b) The load follower's 85 ms release swaps the on-load loops for the overrun loops as the throttle drops, so the cut reads as a lift.
- (c) The Cut gate sits after the compressor and limiter.
- (d) Short blend zones, with each loop playing alone over most of its range, prevent phasey overlap.
- (e) Voices sleep after 2 s at zero weight and wake at the loop start.
- (f) Gunshot-like bangs are converted into the soft "brap".
- (g) The HUD ghosts the target gear rather than flashing N.

### Electric and sci-fi precedent (`Racer.Cars.ARCLIGHT.Audio` L1–70)
- The same sampler plays four motor-whine loops. They are pitched on one tone line (0.2453 Hz per motor rpm), and their refs are 2117, 3140, 5494 and 9000.
- Every petrol node is zeroed through `tune` (`ELEVEN_crunch* = 0`, `lopeDepth = 0`, `intakeDb = −80`, …). The idle voice is at −80 dB because "EngineAudio needs one".
- The comments state the set was "NOT LISTENED TO", built offline by an agent.

### Remote cars
- `Net/RemoteState` L1–3 and L143–161 re-fire Pop / Bang / BOV / Shift / LimiterHit, spread across the packet gap. For Shift it synthesises `{from = prevGear, to = packet.gear, quality = "clean"}`.
- Remote cars always use the classic pop map. Budget: "remote ≤ 49 AudioPlayers per car" (EngineAudio L539).

---

## 2. HUD (`Racer.HUD.Hud`)

### Constants (L75–120)
- Smoothing: `BAR_TAU 0.04`, `BOOST_TAU 0.08`, `PEDAL_TAU 0.025`.
- Shift light: `SHIFT_BELOW_REDLINE 300`, `PRE_SHIFT 900`, `SHIFT_HZ 5`, `LED_SPAN 1500`.
- Limiter: `LIMITER_HZ 10`, `LIMITER_HOLD 0.2`, `LIMIT_FLICKER 2.4` degrees.
- Entry sweep: `SWEEP_UP/HOLD/DOWN 0.42/0.12/0.46` (a cluster self-test on entry).
- PRO AUTO lead: `AUTO_LEAD 0.28` s, clamped to 120–1200 rpm. `AUTO_FLASH_MIN 4500`.
- Nitrous: `NOS_SHIFT_HOLD 0.5`.

### Tach
- Base gauge: `Gauges.Tach = {vmin 0, vmax 8000, a0 −130, sweep 260}` (`HUD/Gauges` L20). Angle = `a0 + clamp(t, −0.02, 1.02)·sweep`.
- Rev max: the cluster def's `rev.max` (7000–14000 per car in `HUD/GUI/*`), otherwise `ceil((limiterRpm+500)/1000)·1000` (Hud L791).
- `Theme.REDLINE 7200`, `REV_MAX 8000`. Live redline comes from `s.redlineRpm`.
- Redline band styling per theme: `plate` uses yellow hazard hatching and no red (Theme L21–56). Other looks are `sodium`, `motorsport` and `carbon`.
- `HUD/VecArt` draws the cluster faces as vector GUI primitives for legibility.

### Needle springs (L90, L594–606)
- Second-order spring, substepped at 240 Hz:
  `w += (ω²(target−a) − 2ζω·w)·h`
- Tach `{28, 0.55}`, Speed `{12, 0.8}`, Boost `{18, 0.6}`. Cluster defs may override.
- On the limiter, the tach adds `sin(now·2π·17)·2.4° + random` after the spring (L2168–2171).

### Shift light (L1968–2018, L2175–2192)
- `flashAt = redline − 300` in MANUAL.
- In PRO AUTO: `flashAt = upshiftRpm − clamp(rate·0.28, 120, 1200)`. `upshiftRpm` comes from `ctx.controls.upshiftRpm` (the Pilot), otherwise `autoUpshift`:
  - throttle ≥ 0.85 → redline − 150;
  - throttle 0.3–0.85 → (4000 + 2000·(thr−0.3)/0.55)·redline/7200;
  - otherwise none.
  - It never flashes when the shift point is below 4500.
- `canUp = gear ≥ 1 and gear < topGear`, with `topGear` from `tune.topGear` or `#tune.gearRatios` (clamped to 1–8; `ClusterSignals` L51–58). **It never fires in top gear.**
- Phases:
  - `"limiter"` when the last hit was < 0.2 s ago or rpm ≥ limiter − 20.
  - `"shift"` when rpm ≥ flashAt.
  - The flash is phase-locked to the moment the phase starts (the first frame is on). Duty: shift 0.6, limiter 0.5.
- The bar warms from `flashAt − 900` (colour ink→warm, squared).
- 9 progressive LEDs fill over `ledSpan 1500` rpm below flashAt, using `ledColors` yellow → orange → red (Theme L51–52).

### Gear readout and BigGear punch (L2020–2056, L1407–1416, L673–681)
- `gearChar`: −1 → R, 0/nil → N, an electric car → D, otherwise the number.
- While the lever is between gates, the HUD shows `s.gateTarget` at 0.55 transparency instead of N.
- **Punch:** the Shift event sets `self.punch = 1`, which decays with `approach(…, 0, dt, 0.09)`. It is applied as `UIScale = 1 + 0.12·punch` on `BigGear.Punch`, the tach readout and the glyph.
- **Grind:** the plate turns grind colours for 0.35 s; the readout shakes `sin(t·90)·7·(1−t/0.3)` px; a "GRIND" tag shows for 0.9 s.
- Plate inversion: on a shift flash the plate inverts; on the limiter it strobes between `gearStrobe*` and `gearInv*`. When stalled, the plate dims.

### Units, boost and nitrous
- Units: `ClientSettings.units` is set by region (the `MPH_REGIONS` list). Speed display uses 0.6 hysteresis.
- Boost bar runs −0.8 to `boostMax + 0.2` and fills from the zero mark.
- Nitrous is a light-pipe strip on the tach arc (`Gauges.Nos e 211 → f 140`) plus a lamp. The glow has tau 0.05. The lamp holds through PRO AUTO shift cuts (`NitrousOff reason "shift"`, 0.5 s).

### Electric variant
- The gear shows D. The gearbox and clutch rows are hidden (`ROWS` `onlyIf`).
- On mobile, the 24-cell bar becomes a power meter: power to the right of a zero mark, regen to the left, and a limiter lamp (`Builders/Mobile` L15–20).
- `ClusterSignals` adds `motorPower` / `motorRegen` / `driveP/R/N/D`.

### Phone layout
- `settings.hudMode` is `"Full"` or `"Mobile"`. When nil it defaults to Mobile on touch-only devices or screens under 450 px tall (L27–33, L100–105).
- `Builders/Mobile` (240×96 design px, 24 cells) is one cluster for every car, styled by that car's def.
  - It is see-through: plate 0.6, windows 0.5.
  - It docks top-right in `Input.Touch`'s "cluster" slot, scale-capped at `DOCK_MAX_K {Mobile 2, Full 1.25}` and re-fit every 0.5 s.
  - It reads `d.revPos`, `phase`, `flashOn`, `led`, `gear`, `punch` and `shake`.

### Settings rows (L175–191)
- `gearbox {ProAuto, Manual}`, displayed as "PRO AUTO" / "MANUAL"; hidden on electric cars. Default `"ProAuto"`: "a virtual pro driver works clutch/lever/blips" (ClientSettings L9).
- `clutchAssist` (MANUAL only), `units`, `camera {Chase, FarChase, Cockpit}`, `kicksIn`, `hudMode`, and TC / ABS. TC and ABS are greyed out ("NOT FITTED") on cars without the system.
- P toggles the panel.

---

## 3. Shift feedback beyond sound

### Camera "Choom" (`Camera/Solvers` L371–398 tune, L597–695 code; wired in `CameraRig` L15–16, L205, L305–308, L943–946)
- **GateMove** (the lever leaves its slot): the head nods forward 1.5° (`nodOmega 9`, `nodTau 0.12`) and is braced on the pre-cut pull. This only happens for driven upshifts with pull ≥ 2 m/s², and **not** for PRO AUTO quick shifts.
- **Shift:**
  - Pitch thump 3.0°, roll 0.6° toward the shift hand.
  - The lens pulses **in**: `fov = −5°`, `fovOmega 8`, peak around 0.12 s.
  - The drive decays with `driveTau 0.14` on a critical spring (`omega 9`). It peaks around 0.25 s and is gone by about 0.8 s, with no rebound.
- Strength: upshift 0.3–1.15 by pull, downshift 0.5, select 0.25.
- Mode shares: `{Cockpit = 1, Chase = 0.3}`. The chase view gets pitch and lens only.

### Other shift and engine feedback
- **Cockpit body:** `Cockpit/Driver` L124 `FT_KICK = 1.1` studs/s jolt "when the gear goes in". `Cockpit/Lever` animates the lever or paddle.
- **Camera shake** (Solvers L418–425, L533–557):
  - Bang → kick.
  - LimiterHit → buzz at 19 Hz, amplitude 0.0035 rad, decay 0.1 s.
  - Idle shiver: 13 Hz, 0.0012 rad.
  - Started → jolt.
- **Exhaust flames** (`FX/Exhaust` L1–34, L44–62): every Bang makes a flame of `0.4 + 1.5·I` studs (attack 12 ms, flash brightness 2.0, range 9). Huge bangs get a fireball. During PRO AUTO cuts the nitrous jet dips.
  - INFERRED: Exhaust has no shift-window filter, so a shift's Bangs still flame even though FXAudio turns their sound into a brap.
- **Controller rumble:** none. `script_grep` for "Haptic" and "SetMotor" returns no matches.
- **Nitrous camera:** FOV +7, punch 5.5°, chase trail 1.6 studs.

---

## 4. Controls (`Input/Controls` L8–49, `Flow.PAD` L52–82)

### Keyboard
- W/S/A/D or arrows; Space = handbrake.
- **E / Q = shift** (INFERRED: E is up).
- 1–8 / R / 0 = direct gears in MANUAL.
- **Ctrl = clutch**, only in MANUAL with the clutch assist off.
- **Left Shift = nitrous** (needs the Nitrous pass).
- C = camera, P = settings, J = rocket, B = garage, Backspace = reset, F held = exit.

### Gamepad
- RT throttle / LT brake (analogue). Left stick steers: deadzone 0.12, rescaled, `|x|^1.4`.
- **RB / LB = shift up / down.** **A = nitrous.** B = handbrake. X = rocket. Y = exit. DPad Down = camera. DPad Up = garage.
- No clutch on a pad; the assist does it. Select is reserved for the virtual cursor.

### First-drive hints (Hud L193–215, L1810–1847)
| Mode | Keyboard hint | Pad hint |
|---|---|---|
| PRO AUTO | "LSHIFT nitrous · J rocket" | uses `Flow.padName` |
| MANUAL | "E / Q gears · CTRL clutch · LSHIFT nitrous" | "RB / LB gears · A nitrous" |
| MANUAL + assist | "E / Q gears · LSHIFT nitrous" | — |

- The hint shows once per session and fades after 6 s of driving above 2 m/s. In MANUAL it also clears on the first clean shift. Touch devices never see it.

---

## 5. Inspiration list for PR98

### What PR98 does today (for contrast)
From the repo export `roblox/exported_scripts/ReplicatedStorage/Modules/Game/Audio/VehicleAudioClient.module.lua` L640–690 (an export, so it may lag live Studio):
- Two engine loops (EngineLow, EngineHigh) plus Idle and Coast.
- Pitch is driven by **speed in mph** (`EngineLowPitchMin 0.82` → `Max 1.2`, `rangeAlpha(speedMph, …)`).
- There is no rpm and no load swap.

### Worth building on (ideas, not code)
1. **An rpm-driven sampler with equal-power log-rpm crossfades and short blend zones.** This is the prerequisite for gears: when the rpm drops on an upshift you hear it.
2. **A load follower (fast attack, slower release) driving an equal-power swap between on-load and off-load loops.** This is the single biggest "engine-like" cue on a lift or shift, and it hides the rpm drop.
3. **Grit that scales with load:** distortion, a 2–3 kHz presence peak, an 85 Hz sub shelf, and a log-rpm loudness rise. This is the "grungy" knob, per category.
4. **A cut as a gate after the dynamics** (`AudioTremolo` square): one node covers the limiter bounce and the shift cut.
5. **Low-rpm AM "lope" at an rpm-locked rate.** On a hover car this could be a "reactor pulse" or stabiliser throb instead of a firing warble.
6. **One event bus feeding audio, HUD, camera and FX, with remote cars re-firing the same events.** One shift-strength rule is shared by camera and sound.
7. **HUD logic:** the shift light only when `canUp`; a lead time in auto mode; ghosting the target gear; a 1.12× punch; needle springs at about ω 28, ζ 0.55; a limiter strobe; the entry self-test sweep.
8. **The ARCLIGHT pattern:** the same sampler with petrol nodes zeroed, playing a whine family. PR98 could run **both** at once: a grungy mechanical family plus a sci-fi whine family on a different pitch line. That covers "engine-like but still sci-fi".

### Do differently so it isn't a copy
- **Thruster vents instead of exhaust pops and bangs.** Use ion or plasma vent crackle on lift-off. Replace the "brap" with a short capacitor-discharge "thunk-chirp" on a shift, and the limiter with a field-stutter.
- **Layer the sound by module, matching PR98's own anatomy.**
  - Engine module = grungy loops (drive, crunch, sub).
  - Stabiliser = a hum tied to ride-height and lateral load, which also cues the spin-out ("stabiliser strain" whine plus a grav-skid scrape instead of tyre squeal).
  - Boost module = the whine and whoosh in place of the turbo.
- **Sci-fi colour from different nodes.** INFERRED from the Roblox API, not from DRIVE: Highway's code: `AudioPitchShifter` for a sub-octave, `AudioFlanger`/`AudioChorus` with low depth on the whine family, and a resonant band-pass sweep with boost.
- **Keep it small.** FXAudio alone is 2134 lines. PR98 should use a few data-driven layers per category (Piercer/bruiser, Exotic, Muscle), not per car.
- **A lightweight virtual gearbox, not a physical drivetrain.** DRIVE: Highway simulates a full clutch and H-pattern drivetrain. PR98 needs a ratio table, `rpm = f(speed, gear)`, a 60–150 ms shift cut, and an rpm drop.
  - INFERRED recommendation: an auto default with a manual option, mirroring the ProAuto/Manual setting row.
- **Add controller and phone haptics** (HapticService) on shift, limiter and spin-out. DRIVE: Highway has none, so this is a differentiator.
- **Give the HUD its own sci-fi language.** A segmented reactor arc or hex gear plate, with the shift cue as module glow. Reuse the logic, not the "plate" or "carbon" looks. Keep PR98's existing phone pass, and add gear and rpm to the compact cluster the way `Builders/Mobile` folds them into 240×96.