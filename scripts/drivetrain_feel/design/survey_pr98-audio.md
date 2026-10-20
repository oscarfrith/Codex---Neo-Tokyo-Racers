# PR98 vehicle audio and the synth pipeline: research report for the gearbox, weight and grungier-sound plan

Sources: PR98 Studio (`09a86975…`, Edit mode), read only. Repo at `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers`. Nothing was changed.

- `scripts/hover_feel/CONTRACT.md` names the target as "Space Racers v3 (place 93959280828322)". The same code is live in PR98, and I checked it line by line.
- The live code is the round 2–4 version: `HoverFeelInstalled=true`, `ProfileRevision=36`.

---

## 1. Audio API, update rates, layers and category mapping

### API
Only the new audio API is used: `AudioPlayer`, `AudioFader`, `Wire`, `AudioEmitter`, `AudioListener` and `AudioDeviceOutput`. No `Sound` objects are used for vehicles.

- **Local car (Internal route):** `AudioPlayer → AudioFader → AudioDeviceOutput`. This is built by `newRoutedSource` (VehicleAudioClient L149-165).
- **Other cars (External route):** `AudioPlayer → AudioFader → AudioEmitter`, with the emitter parented to the car's root (L344-355).
  - Distance curve: `{0:1, 12:1, 132:0.28, 240:0}`, from Global `ExternalMin/Mid/MaxDistanceStuds` and `ExternalMidDistanceGain=0.28`.
  - `AcousticSimulationEnabled=false`.
- Runtime objects live in `SoundService.AudioRuntime_Local`. A `AudioListener_Runtime` on the camera is wired to the device output (L80-120).
- **Gain:** `AudioBusClient.SetGain(fader, g)` sets `fader.Volume = g * SoundService.Vehicle.Volume`, clamped 0..3 (AudioBusClient L27-33).
  - The `SoundGroup "Vehicle"` is only a volume number here. It is not in the signal path.
- **No effects anywhere:** script grep finds no `AudioDistortion`, `AudioEqualizer`, `AudioCompressor`, `AudioReverb` or `AudioFilter` in any script.
  - The only effect in SoundService is `SoundService.Ambience.ContextAmbienceReverb` (a legacy `ReverbSoundEffect`), which is not connected to vehicle audio.

### Update rates (Config.Audio.Quality)
- **Local driver feel drive (`updateFeel`):** `LocalFeelUpdateHz=60` on desktop and `LocalFeelUpdateHzMobile=30` on small touch screens (`mobileBudget()`: TouchEnabled and shorter screen side under 800). Heartbeat L1415-1421.
- **`updateGraph`** (semantic state, the standard speed-based layers, other cars' feel): `ParameterUpdateHz=15`.
- **`refreshPriorities`** (route, tier, rebuilds): `PriorityUpdateHz=4`.
- **Limits:**
  - `MaxRevLayerPlayers=14`, `MaxRevLayerPlayersMobile=8`, `MaxRemoteRevLayerPlayers=3`.
  - `TwinEngineEnabled=true`, `TwinEngineOnMobile=false`.
  - `MaxConcurrentOneShotsPerVehicle=8`.
  - `MaxDetailedRemoteVehicles=6`, `MaxSimpleRemoteVehicles=6`.

### Profiles and category mapping
- `ReplicatedStorage.Config.Audio.VehicleProfiles` has exactly two profiles, `GENERIC_STANDARD_AUDIO` and `EXOTIC_V10_AUDIO`.
- Its only mapping attribute is `CategoryProfile_exotic = "EXOTIC_V10_AUDIO"`.
- How the profile is chosen: the server stamps `ResolvedAudioProfileId` with the fallback, `AudioProfileSource="Standard"` (VehicleAudioServer L35-44). `Catalog.ResolveProfileId` (Catalog L188-201) then maps `vehicle.CategoryId` to `CategoryProfile_<id>`.
- `CategoryId` is set by `ServerStorage.Modules.Game.Garage.VehicleBuildService` L270 from `profile.CurrentCategory`. The default category is `"bruiser"` (GarageProfileView L11/40).
- **Result: Exotic plays `EXOTIC_V10_AUDIO`. Muscle and Piercer/bruiser play `GENERIC_STANDARD_AUDIO`.**
  - INFERRED: the category id strings are lowercase `muscle` / `bruiser` (Garage fixtures use `C:exotic`, `C:muscle`).
  - There is no Muscle or Piercer profile.

**GENERIC_STANDARD_AUDIO** (Piercer/bruiser and Muscle):
- Only three assets are set:
  - `IdleAssetId=131569008759588` (gain 0.34)
  - `AccelerationAssetId=96470627739499` (`AccelerationGain=0.8`)
  - `IgnitionAssetId=90037258119926` (`IgnitionGain=0`, muted on 2026-10-10 by `scripts/audio/pr98_mute_vehicle_ignition.lua`)
- EngineLow, EngineHigh, Coast, DriftLoop, BoostLoop, DriverWind and every boost one-shot are `""`.
- No `FeelDriveEnabled`, so no rev engine at all. These cars have a flat-pitch idle plus an acceleration loop gated on the `Accelerating` boolean. **They have no rpm sound today.**

**EXOTIC_V10_AUDIO** (`FeelDriveEnabled=true`, `ProfileRevision=36`):

| Group | Layer | Asset / setting |
|---|---|---|
| Standard loops (`Catalog.LoopLayers`) | Idle | 131569008759588 |
| | EngineLow | toolbox 1323976194, gain 0.45 |
| | EngineHigh | `""` |
| | Acceleration | `AccelerationDisabled=true` |
| | Coast | `CoastDisabled=true` |
| | DriftLoop | `DriftLoopDisabled=true` |
| | BoostLoop | 139035470369920, gain 0.9, follows rev via `BoostLoopRevPitchMin/Max` 0.9/1.15 |
| | DriverWind | 108504824284655, gain 0.7 |
| Rev layers (`…EXOTIC_V10_AUDIO.RevLayers.*`) | V10Idle1000 | Rev 0, Any, gain 0.5, Twin false |
| | V10On2000 / 3500 / 5000 / 6500 / 8000 | Rev 0.1429 / 0.3571 / 0.5714 / 0.7857 / 1, On, gain 0.6, Twin true |
| | V10Off3000 / V10Off6000 | Rev 0.2857 / 0.7143, Off, gain 0.45 |
| | All rev layers | PitchMin 0.6, PitchMax 1.7 |
| Stand-ins | StandInExhaust (1324100995), StandInRev (1323976194) | dropped automatically because real layers exist (Catalog L233-237) |
| | StandInIdle | `Enabled=false` |
| Feel loops (`Catalog.FeelLoopLayers`) present | SuperchargerWhine | 100501951454120, gain 0.12, pitch 0.6-1.3 |
| | TurbineLow | 135190532376172, gain 0.16, `TurbineOctaves=1.2` |
| | EnergyHum | 85533750541229, gain 0.18 |
| | SlipStrain | 80719035328360, gain 0.24 |
| | BoostBody | 75069414348224, gain 0.7 |
| | WindBuffet | 125530678234677, gain 0.4 |
| Feel loops absent (blank id) | TurboWhistle, TurbineHigh, DriftCharge | — |
| Feel one-shots present | BlowOff | toolbox 4940167544, gain 0.25 |
| | TurboFlutter | 101811408400161, gain 0.3 |
| | BoostIgnition | 133020167141632 |
| | ImpactLight / Medium / Heavy / Severe, LandingThump | set |
| | Pop1-4 | gain 0.95 |
| | Bang1-2 | gain 1 |
| Feel one-shots absent | DriftChargeRelease | — |
| | BoostReleaseAssetId | `""`, so the boost end is a plain fade |

---

## 2. How rev is derived today, and the mappings

Everything below is in `updateFeel` (VehicleAudioClient L830-1062). Tunables are in `Catalog.feelDefaults` (L79-146), overridable by profile attributes.

### Load
- `loadTarget = max(0, FeelThrottle)`. In reverse it is `|throttle| * ReverseLoad(0.6)`. With no Feel attributes it is 1 if `Drive=="Accelerating"`.
- `f.Load = follow(f.Load, target, dt, rising ? LoadAttackSeconds 0.022 : LoadReleaseSeconds 0.085)`.
- `load = f.Load ^ LoadExponent(0.8)`.
- Bark (tip-in) = `BarkGain 0.55 * max(0, f.Load - f.LoadSlow)`, where `LoadSlow` follows over `BarkSeconds 0.13`.
- `onWeight = sin(load·π/2)`, `offWeight = cos(load·π/2)`.

### Rev: a function of speed (L880-885)
```lua
revTarget = clamp(RevThrottleWeight(0.25)*load + RevSpeedWeight(0.75)*speedMph/RevReferenceMph(170) + RevBoostWeight(0.08)*boostAmount, 0, 1)
f.Rev = follow(f.Rev, revTarget, dt, rising ? RevRiseSeconds 0.12 : RevFallSeconds 0.28)
```
- `speedMph = root.AssemblyLinearVelocity.Magnitude * 0.625` (L857). `FeelSpeedMph` is not read.
- `boostAmount` is 1 for `"Boost"` and `BoostLoopMiniGain 0.7` for `"Mini"`.
- Mapping to rpm: `frequency = RevPitchBase(0.125) + 0.875*rev`, so frequency = rpm/8000. Rev 0 = 1000 rpm, rev 1 = 8000 rpm.
- Examples:
  - Full throttle at 0 mph: rev 0.25, about 2750 rpm.
  - Full throttle at 85 mph: rev 0.625, about 5375 rpm.
  - 170 mph: about 8000 rpm.
- It is one continuous "CVT-like" sweep. **There are no gears.**

### Rev-layer crossfade (L915-961)
- `ladderWeights` (L752-767) gives an equal-power cos/sin crossfade between the two neighbours either side of the current frequency, in log frequency.
- There are two ladders:
  - OnLadder: Load ≠ "Off"
  - OffLadder: Load ≠ "On"
- Per-voice weight:
  - On voice: `on*onWeight*(1+bark)`
  - Off voice: `off*offWeight`
  - Any voice: `on*onW²*(1+bark) + off*offW²*RevOffLoadGain(0.6)`
- Pitch: `clamp(layer.Pitch * frequency/voice.Frequency, PitchMin, PitchMax) * Detune`.
  - Detune: neighbours ±`RevNeighbourDetune 0.003`.
  - "Life" noise: ±0.25% pitch, ±0.6 dB, `LifeSeconds 1.4`.
- Gain: `layer.Gain * weight * EngineMix * RevMasterGain * EngineDuck * lifeLevel * sin(RevBlend·π/2)`.
  - Gain follows over `RevLayerSmoothingSeconds 0.025`.
  - **Pitch is written directly each tick, with no extra smoothing beyond `f.Rev`.**
- Twin engine (local only, on-ladder voices with `Twin=true`): a second player 1.2% sharp (`TwinEngineDetune 0.012`), `TwinEngineGain 0.45` (profile), starting at `StartFraction 0.37`.
- Handover:
  - The standard Idle and EngineLow loops play until a rev voice reports `IsReady`.
  - They then crossfade over `RevHandoverSeconds 0.4` and stop (`LegacyStopped`, L1271-1285).
  - Before the handover, EngineLow pitch follows speed (0.82→1.2 up to `EngineLowPeakMph 42`, L1239-1242).

### Boost ducking
- `BoostDuckDb` = 6 on the profile (the default is 3).
- In 0.03 s, out 0.25 s. It applies only if `BoostLoop` or `BoostBody` exists (L902-904).
- Combined: `EngineDuck = 10^(-(SlipDuckDb*Duck + BoostDuckDb*BoostDuck)/20)`.

### Boost loops
- BoostLoop gain is `0.9 * BoostScale`. It fades in over `BoostFadeInSeconds 0.06` and out over Global `BoostFadeOutSeconds 0.14`.
- Global `BoostLoopFadeOutSeconds=2.2` is never read: grep finds no reader.
- BoostBody pitch follows rev, 0.9-1.1.

### Pops and bangs
- Producer: `DrivingClient.publishFeelState` L931-956.
  - After at least 0.8 s of `throttle>0.6` above 40 mph, then `throttle<=0.1` and no boost:
  - one pop at strength 0.9-1.0 (a bang), then `math.random(3,6)` more at 0.5-0.79, spaced 0.05-0.17 s.
- Consumer: `playPop` (L804-826) draws from shuffled bags (Pop1-4, or Bang1-2 when strength ≥ `PopBangStrength 0.8`).
  - Gain is `gain*strength`, pitch jitter ±6%. Each slot has its own persistent voice.
- VehicleVFXClient L581/717/724 also reacts to `FeelPopRevision`.

### Turbo, supercharger and turbine (local only)
- Spool target: `load*(0.35 + 0.65*rev)`, or boost. Up 0.9 s, down 0.35 s.
- Blow-off or flutter fires on a lift (`loadTarget<=0.1`) when all of these hold:
  - load was ≥0.6 for at least 0.6 s
  - spool ≥0.35
  - at least 0.7 s since the last vent
- It vents as flutter below spool 0.7, then keeps 25% of the spool.
- `BoostEndVent=0`, so nothing vents at boost end.
- The TurboWhistle loop is blank.
- Supercharger: gain `rev^1.5 * (0.35 + 0.65*load)`, pitch 0.6→1.3 with rev.
- Turbine: gain `smoothstep(0.3,1,rev) * (0.3 + 0.7*load)`, pitch `2^(-0.5 + 1.2*rev)`.
- EnergyHum: pitch follows **speed**/170; gain follows `FeelHover`.

### Slip strain
- `|FeelSlip|`, with a floor of 0.35 while drifting.
- `smoothstep(SlipStart 0.12, SlipFull 0.6)` drives SlipStrain and a 6 dB engine duck (in 0.06 s, out 0.35 s).

### Other
- Wind is speed-only: `(speed/200)^2`, gated 36-60 mph.
- Impacts come in tiers 9/25/55/110 studs/s, at most one per 0.12 s.

---

## 3. Inputs, consuming a new gear signal, and what breaks

### Attributes read
Local driver only (L846-854, L1037-1060):
- `FeelThrottle`, `FeelSlip`, `FeelDriftCharge`, `FeelHover`, `FeelBoostKind`
- `FeelPopRevision` / `FeelPopStrength`
- `FeelImpactRevision` / `FeelImpactStrength`
- `FeelLandRevision` / `FeelLandStrength`

Booleans used by `semanticState` (L577-598): `Accelerating`, `Braking`, `Boosting`, `DriftingLeft`, `DriftingRight`.

Boost percentage comes from `MobileDriveState.BoostPercent`.

- **Producer:** `DrivingClient` L848 (`FEEL_ATTRIBUTES`, which `clearFeelState` clears), L860-958 `publishFeelState`, called at L1570 when `Config.Vehicles.Driving.FeelStateEnabled`.
  - Pattern: revision counters, where the first value seen is a baseline and not an event (VehicleAudioClient L1033-1043).
- **Other players' cars:** they never see Feel attributes.
  - They see the replicated `AudioIgnition`, `AudioDrive`, `AudioDrift`, `AudioBoost` and `AudioCue` (VehicleAudioServer L128-135).
  - `VehicleAudioStateContract` only allows Drive ∈ {Idle, Accelerating, Braking, Reversing} and Cue ∈ {AccelerationEnter, AccelerationRelease, BoostEmpty, FullBoostSpent}.
  - The rate limit is `StateRateLimitPerSecond=20`; Net uses capacity 120, refill 60.
  - So other cars' rev = `0.25*(Accelerating?1:0) + 0.75*speed/170`, updated at 15 Hz with at most 3 rev voices. Thinned by `thinned()` this resolves to Idle1000, On5000 and On8000 (my calculation), all treated as Load "Any".

### How a gear/rpm signal would be consumed
- Add `FeelRpm` (0..1, or raw rpm), `FeelGear`, `FeelShiftRevision`, `FeelShiftKind` ("Up"/"Down") and, optionally, `FeelTorqueCut` / `FeelLimiter` in `publishFeelState`, and add them to `FEEL_ATTRIBUTES`.
- In `updateFeel`, replace the `revTarget` formula (L880-883) with `FeelRpm` when present, and keep the current formula as the fallback (contract rule: a missing attribute means fall back).
- Shift events would use the same baseline-and-revision pattern as pops.

### What changes or breaks if rpm is no longer a function of speed
- **Everything keyed off `f.Rev` would saw-tooth on shifts:**
  - rev-layer pitch and crossfade
  - BoostLoop rev pitch
  - BoostBody pitch
  - supercharger gain and pitch
  - turbine gain and pitch
  - turbo spool target

  That is realistic for the supercharger. The sci-fi turbine and BoostBody may be better left on speed (a design choice).
- **Speed-based by design, so unaffected:** EnergyHum pitch (speed/RevReferenceMph), DriverWind, WindBuffet, the pre-handover EngineLow pitch, and the generic idle fade.
- **Smoothing:** `RevFallSeconds 0.28` would smear an upshift rpm drop into a glide. A shift needs to bypass `follow` (set `f.Rev` directly, or use a short `ShiftDropSeconds`).
- **Pitch limits:** with gearing, a loop can be pushed further from its recorded rpm.
  - Per-layer PitchMin 0.6 / PitchMax 1.7 and the AudioPlayer `PlaybackSpeed` clamp of 0.5..2 cap this.
  - With six on-layers spaced 1.3-2× apart, this is fine.
- **Other cars:** with no gear signal they keep the speed formula, so they would sound gearless unless:
  - (a) each client derives the gear from replicated speed and the gear table, deterministically (INFERRED approach, no network change); or
  - (b) the contract and remote change, which `CONTRACT.md` "Preserved behaviour" currently forbids ("The audio remote, its rate limit…").
- **Pops:** the producer uses throttle and speed only, so it is unaffected. Shift crackle could reuse it.
- **Existing bug, untouched:** `Catalog.GlobalBool(name, true)` returns true even when the attribute is false (Catalog L166-169; also noted in NOTES.md).

---

## 4. Synthesised versus toolbox sounds, asset ids, and how the engine is built

### Synthesised
33 files from `scripts/hover_feel/synth/make_sounds.py`, all uploaded. Ids are in `scripts/hover_feel/audio/asset_ids.json`, with the round 4 pops, bangs, impacts and landing replacing round 3. The live Exotic profile matches that file, **except these uploaded files are not wired in** (blank slots):
- turbine_high 126900976760387
- drift_charge 95673746186179
- drift_release 73608557420209
- boost_release 106613257862306
- scrape_loop (never had a slot)

### Toolbox or unrecorded origin
- BlowOff 4940167544 (toolbox)
- EngineLow 1323976194 (toolbox; handover fallback and the remote Simple tier)
- StandIn 1324100995 / 1323976194 (inactive)
- Generic Idle 131569008759588, Acceleration 96470627739499 and Ignition 90037258119926: origin not recorded in the repo (INFERRED: toolbox or earlier uploads).
- **Garage and dealership previews** (`PresentationAudioClient` L205-221) read `ResolvedAudioProfileId` and **do not** apply the category mapping. So every preview plays GENERIC `Idle` (Preview.IdleLoop `ProfileLayer="Idle"`, gain 0.72).

### Synth basics
- 44.1 kHz, 16-bit, mono, numpy only, fixed seeds.
- Loops are made seamless by construction: integer FFT bins, FFT-domain noise, memoryless tanh, circular FFT filtering.
- Loops are normalised to -17 dBFS RMS with a soft limit at -3.2 dBFS.
- One-shots are peak-normalised.

### `engine_loop(rpm, mode, seed)` (L251-404)
- **Firing:** V10 firing frequency = rpm/12 (10 firings per 2 revolutions, `f_fire = 10*f_cyc`).
- **Wavetable:** one engine cycle as a wavetable (`TABLE=65536`).
  - Every 10th harmonic is a firing harmonic (1.0).
  - Every 5th is the bank 2.5 order (`bank`).
  - Even harmonics are engine orders (`eng`); odd ones are half orders (`half`).
  - Orders under the firing line are ×2.2.
  - Spectral tilt `(f/f_fire)^-tilt`, then exhaust formants.
- **Movement:**
  - Phase jitter `jit`.
  - Two tables morphed slowly.
  - Per-firing gain variation `gainvar` (per-cylinder offsets plus random).
- **Grunge stage:**
  - Firing-synchronous band noise (`noise`, `nband`).
  - Then `0.35*sub` (firing sub-octave, first and half orders), `0.25*rumble` (35-220 Hz) and `0.30*exhaust rasp` (300-1200 Hz, firing-pulsed).
  - Then **asymmetric tanh**: `tanh(drive*x + bias)`, with `drive = 0.6+0.3*rev` (on) and 0.7 (off/idle), `bias 0.5` (0.45 idle).
- **EQ:**
  - On: HP 28 Hz, LP 11 kHz, +4 dB at 3.3 kHz (`PRESENCE_ON_DB`), +3 dB at 700 Hz, +3 dB at 110 Hz.
  - Off: LP at `1800+0.3*rpm`.
- **Sci-fi layer (on loops):** a ring-mod "sheen" with carrier 2.76× firing, band-passed 1.2-5 kHz, mixed at `SHEEN_DB=-20`.
- **Idle:** an energy-core hum on 125 Hz throbbing at 2 Hz, plus a 2640 Hz turbine whisper.
- **Firing anchor:** the firing FFT bin is raised so it is always the strongest line.
- **Mode settings (`ENGINE_MODES`, L215-227):**
  - on: `bank .24, eng .11, half .05, tilt 1.30, jit .0015, gainvar .05, noise .14`
  - off: `gainvar .45, pops .12, tilt 1.6`
  - idle: `bank .5, eng .28, half .2, gainvar .2`
- **Loop rpm points:** 1000 (idle), 2000, 3500, 5000, 6500, 8000 (on), 3000, 6000 (off). See the `SOUNDS` list at L1144-1180.
- The number of cylinders is hard-coded (`h % 10`, `h % 5`, `10.0*ph`, `standard_normal(10)`). A Muscle V8 (rpm/15, crossplane lumpiness) needs that parameterised.

### Settings that would make the engine grungier while keeping a sci-fi layer
These are suggestions, not tested.
- **On-throttle roughness:** raise on-mode `gainvar` (0.05 → 0.12-0.2) and `jit` for uneven firing.
- **Lumpy texture:** raise `half` and `eng` for uneven-order lumpiness.
- **Saturation:** increase `drive` and `bias` for more even-harmonic asymmetric clipping. Feeding `rasp()` (tanh plus sine wavefolder, L117-123) into the engine bus is another route.
- **Low end:** lower `PRESENCE_ON_DB` and raise the 110 Hz and 700 Hz bumps; raise `sub`, `rumble` and `exrasp` weights.
- **Body and burble:** add intake/induction noise; add per-firing pops on on-load (`pops`).
- **Sci-fi element:** keep `SHEEN_DB` at about -20 to -16, or move the sci-fi layer to a separate rev-tracked loop that can be mixed live rather than baked in.

### OST synth
`scripts/audio/pulse_ost_synth.py` is the music synth only: numpy, 44.1 kHz, a polyBLEP saw and a natural-minor scale. It is not related to vehicle sounds.

---

## 5. Effects that could add grit, and performance limits

- **No effects exist today.** Runtime options (INFERRED; not present):
  - Insert `AudioDistortion` (Level), `AudioEqualizer` (Low/Mid/High gain) and `AudioCompressor` between the faders and the output.
  - Best as one shared engine sub-bus per graph: rev voices wire into a single `AudioFader "EngineBus"`, then Distortion, EQ, Compressor, then the output or emitter. That is 3-4 extra instances per graph, not per voice.
  - Distortion level and EQ could be driven by load and rev in `updateFeel` at 60 Hz.
  - All wiring lives in `newRoutedSource` (L149-165) and `newFeelVoice` (L198-206). `destroyGraph` (L167-178) destroys `graph.Root`, so instances parented there are cleaned up automatically.
  - The local route currently wires each fader straight to `deviceOutput`.
- **Player counts** (NOTES.md "AudioPlayer count"):
  - Hard limit 48 per local car: 8 standard + 16 rev + 9 feel loops + 15 feel one-shots.
  - Exotic, desktop as configured: about 4 standard + 13 rev (8 + 5 twins) + 7 feel loops + 13 feel one-shots.
  - Mobile: rev budget 8, no twin.
  - Other cars: Detailed up to 6 players, Simple 1, budget 6+6.
- **Cost of new shift sounds:** each new one-shot slot is one persistent `AudioPlayer` per local graph, created at graph build (`buildFeel` L311-314).
  - Feel voices sleep after `FeelVoiceSleepSeconds 2` at zero gain.
  - `Bus.SetGain` is skipped for changes under about 0.1 dB.

---

## 6. Where changes would hook in

| Need | Hook |
|---|---|
| rpm from a gearbox (local) | `DrivingClient.publishFeelState` L860-958 plus `FEEL_ATTRIBUTES` L848: publish `FeelRpm`, `FeelGear`. `VehicleAudioClient.updateFeel` L880-885: `revTarget = FeelRpm` when present, else the current formula. Add tunables (e.g. `RevSource`, `ShiftDropSeconds`, `LimiterHz`, `IdleRpm`, `RedlineRpm`) to `Catalog.feelDefaults` L79-146 so they are profile attributes. |
| rpm for other cars | INFERRED: compute the same gear/rpm in the client from replicated velocity plus `AudioDrive`, in the `not localDriver` branch. Or extend the Contract/remote, which `CONTRACT.md` currently forbids. |
| Upshift rpm drop | Bypass `follow` for `f.Rev` on a shift event (detect `FeelShiftRevision` like pops, L1037-1043). Pitch is set directly each 60 Hz tick, so the drop is immediate. |
| Torque cut | Briefly force `loadTarget` to 0 (about 80-150 ms). The on/off ladders swap naturally, BarkGain gives the re-engage bark, and the existing blow-off/flutter logic (L970-987) may fire if spool ≥0.35. |
| Upshift crackle | Reuse `playPop(graph, 0.4-0.6)` (L804), or add a `FeelOneShotLayers` slot (Catalog L15, e.g. `ShiftCrackle`) and config attributes. |
| Downshift blip | Add a short positive rev offset (rev-match blip) and a load spike so `bark` fires. A pop on overrun could follow. |
| Rev limiter | Modulate `revTarget` near 1 at `LimiterHz` while in top gear or at redline. |
| Load-dependent timbre | Today: the on/off ladders, `RevOffLoadGain`, `BarkGain`. Add a load-driven distortion/EQ on an engine sub-bus, or re-synthesise distinct on/off sets with different saturation. |
| Grungier mix | Re-run `make_sounds.py` with the settings in section 4 and re-upload. Slots are config only (`RevLayers.*.AssetId`); bump `ProfileRevision` to rebuild a live graph (L1377-1386). Optional effects bus as in section 5. |
| Piercer and Muscle gears | Need new profile folders with `FeelDriveEnabled=true` plus `RevLayers` and `CategoryProfile_muscle` / `CategoryProfile_bruiser` (id strings INFERRED). The V8 synth needs the cylinder count parameterised. |
| HUD gear/rpm | `DrivingClient` calls `context.UpdateDriveUi(speedMph, boost, drifting, driftCharge, miniBoostTimer)` at L840-842. A gear/rpm HUD needs extra arguments or must read the new Feel attributes (outside my audio scope). |
| Previews | `PresentationAudioClient` L205-221 ignores category mapping; it does not need changing unless previews should sound like the car. |

### Behaviour to preserve (CONTRACT.md "Preserved behaviour" plus code)
- Every driving equation, force and input path, and the existing booleans.
- `Controller.Start/Stop/Counts` signatures.
- The `VehicleAudioState` remote, its contract values, rate limit 20/s, and the 6 + 6 other-car budget.
- Missing Feel attributes fall back to booleans and velocity.
- Generic and other non-feel profiles take none of the feel paths.
- Reliable-ignition sequencing (`IgnitionGain=0` must keep the cue playing silently).
- The rev-to-standard-loop handover.
- The voice sleep and gain-epsilon optimisations.
- Mobile budgets (no twin, rev budget 8, 30 Hz).
- `ProfileRevision` rebuild semantics.
- `<Layer>Disabled` and blank-asset-means-off rules.
- Feel attributes stay client-local.
- Global `LocalDriverGain` is 1.15 live, but the repo's mix script shows 1.05. Something else changed it, so do not assume either value.