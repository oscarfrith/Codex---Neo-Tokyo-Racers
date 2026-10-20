# drivetrain_feel: audio part

**Status: generated, review fixes applied, compile-checked only.** Both after-files pass the CONTRACT section 2 `loadstring` check in PR98 Edit after the fixes (`VehicleAudioClient OK 92919`, `VehicleAudioCatalog OK 16022`). They have not been run in Play and not heard. `config.py` is validated offline:
- 136 rows, no duplicate keys, no collision with an existing profile attribute;
- every value equals the code default and is inside the code bounds (ReactorEnabled is the one deliberate exception);
- `ShiftVentMinStrength` is deliberately not a profile row (see "Review fixes", item 9).

## Review fixes (adversarial review, verdict READY WITH FIXES)

| # | Severity | What changed |
|---|---|---|
| 1 | MAJOR | The upshift drop window now ends as soon as `FeelRpm` stops falling (new `feel.State.DropLastRpm`, reset to `math.huge` on each upshift), as well as on reaching the landing or after `ShiftDropMaxSeconds`. The pitch no longer sits flat at a low predicted landing while the real rpm and the HUD needle climb. |
| 2 | MAJOR | Remote idle anchor, as the review asked, with one change. `buildFeel` takes the idle rpm (5th return of `GearForSpeed`). With `RemoteIdleVoice` 1, `gearedVoices` keeps the lowest loop when it is within 0.05 rev of idle and spreads the other voices over Low..High. The kept voice is `rev.IdleAnchor`; on geared remote graphs its weight is scaled by `1 − smoothstep(1.2·idle, 1.8·idle, rpm)` so it never stretches into the gear range. This covers the player's own Exotic after exit (an External graph). **The change:** with the anchor, the lowest in-gear voice is the highest loop that can still pitch down to the Low point at its `PitchMin`, not the loop nearest to Low. The review's nearest-loop rule gives On3500 + On8000 (a 2.3× gap). An offline sweep shows that leaves a voice stuck at its 0.6/1.7 pitch limit, 9–13% off pitch, at 3950–5100 and 6400–8150 rpm, which is the main gear range. The changed rule gives On5000 + On8000: no stuck voice from about 3200 rpm to the limiter. The cost is in slow rolling in first (about 2000–3150 rpm): On5000 sits at its pitch floor and the level dips up to 4.5 dB. Exotic remote voices are now V10Idle1000, V10On5000 and V10On8000. This deviates from the contract's "3 voices across 0.4 to 1.0 of redline": one of the three now sits at idle. **The integrator should sign this off.** `RemoteIdleVoice` 0 restores the contract's choice exactly (On3500, On5000, On8000). |
| 3 | MINOR | A remote graph built while the car is moving (`f.RemoteGear == nil`) settles its gear in up to 8 extra `GearForSpeed` calls on its first tick. It no longer starts on the limiter in first and ripples up through fake upshifts. The settle uses the real accelerating flag and `braking = false`, not the review's `true`, so a cruising car settles at the cruise gear (up at 0.6) and not the lowest gear below 0.92. |
| 4 | MINOR | The per-tick check is `geared = gear ~= nil and redline > 0` (finite), the same test the graph build uses. A bad redline can no longer force a rebuild every 2 s. `engineRpm` is taken only when `graph.RemoteGears and geared`. |
| 5 | MINOR | New `RevRpmMaxFromCar` (default 1). The top of the rev range is the car's own limiter: `FeelLimiterRpm` for the local car, `GearForSpeed`'s 4th return for other cars, or `RevRpmMax` as the fallback. It applies everywhere `rpmRev` is used: the rev, the drop landing, remote voice choice and the idle-anchor test. At today's defaults (limiter 8600 = `RevRpmMax`) the output is identical. The limiter tremolo test reuses the same `FeelLimiterRpm` read. |
| 6 | MINOR | New `SpinDuckScale` (default 1, which equals the previous behaviour). The duck target is `max(slip term, spinIntensity·SpinDuckScale)`, taken before the spin is merged into the strain intensity. Without a spin it is identical to before. |
| 7 | MINOR | Documentation only, in the `ReactorEnabled`, `ReactorGain` and `ReactorPitchMin/Max` texts and the table below. While `ReactorEnabled` is 1, `TurboWhistleGain` and `TurboWhistlePitchMin/Max` are ignored (`TurboWhistlePitch` still scales the pitch). Setting `ReactorEnabled` to 0 does **not** silence the slot: it plays turbine_high as the old spool whistle. To silence it, use `ReactorGain` 0. The review's alternative (have 0 skip the voice) was not taken: no profile flag says the slot was "repurposed", and skipping it would make the no-gearbox path differ from the old code for other profiles. |
| 8 | MINOR | The upshift window now always opens (`DropRev` −1 when there is no landing prediction). Without a prediction, the rev follows `FeelRpm` down with `ShiftDropSeconds/3` while it is falling, so `ShiftDropSeconds` is never a dead knob while `ShiftDropMaxSeconds` > 0. `ShiftDropMaxSeconds` 0 turns all drop shaping off, and its text now says so. |
| 9 | MINOR | One knob. The profile row `ShiftVentMinStrength` was removed from `config.py`. When the profile has no such attribute, `Catalog.readFeel` reads `ReplicatedStorage.Config.Vehicles.StabiliserVFX@ShiftVentMinStrength` (the camerafx vent-flame threshold), so the crackle and the flame stay together. A profile that sets its own value still overrides it. The audio reads it when the graph is built (raise `ProfileRevision` to pick up a Play edit), while the VFX reads it live. |
| 10 | MINOR | Added open risk 12 and an integrator note. `build.py` should emit `allowed` for the `ProfileRevision` row (any number of 37 or more) and the `TurboWhistleAssetId` row (any non-empty id). Until it does, tune audio in Play only, or restore 37 and the turbine_high id before a ROLLBACK or re-APPLY. `config.py` stays in the contract's 3-tuple format because `build.py` unpacks 3-tuples. |

None declined outright. Items 2, 3 and 7 differ from the review's exact suggestion, for the reasons given.

## Files

| File | What it is |
|---|---|
| `after/VehicleAudioClient.lua` | 1875 lines, up from 1465; 431 lines added, 21 changed. Replaces `ReplicatedStorage.Modules.Game.Audio.VehicleAudioClient`. |
| `after/VehicleAudioCatalog.lua` | Replaces `…Audio.VehicleAudioCatalog`. Install both together. |
| `config.py` | `ATTRIBUTES` only, all on `ReplicatedStorage.Config.Audio.VehicleProfiles.EXOTIC_V10_AUDIO`. `INSTANCES` is empty. |

There are no server, remote, contract, bus or startup changes.

**New dependency.** `VehicleAudioClient` now requires `ReplicatedStorage.Modules.Game.Vehicles.VehicleDynamics`.
- The require is lazy, happens on first use, and is guarded by `pcall`.
- Only `VehicleDynamics.GearForSpeed` (CONTRACT 3.3) is called. Each call is also wrapped in `pcall`.
- If the module or the function is missing, other players' cars keep the speed-shaped rev and the local upshift lead is skipped. Nothing errors.
- Record this dependency in the owner list.

## What changed, and where

### Catalog (`VehicleAudioCatalog`)

- **`FeelOneShotLayers`:** adds `ShiftThunk1`, `ShiftThunk2`, `ShiftVent1` and `ShiftVent2`. Their `defaultGains` are 0.5, 0.5, 0.55 and 0.55. Blank slots stay silent and create no player.
- **`feelDefaults`:** 56 new profile numbers (listed below). Like every feel value, they are read once when the vehicle's graph is built.
- **`readFeel`:** when the profile has no `ShiftVentMinStrength`, it takes `Config.Vehicles.StabiliserVFX@ShiftVentMinStrength` (bounded 0..1, fallback 0.7).
- **Code defaults:**
  - Every switch defaults to 1, except `ReactorEnabled`, which defaults to 0 because it repurposes the TurboWhistle slot.
  - Every new path is also gated on `FeelRpm` (or on `GearForSpeed` for other players' cars). So a car without a gearbox takes none of it.

### Client (`VehicleAudioClient`)

**New helpers** (placed after `thinned`)
- `finiteNumber`: drops a NaN or infinite value, used for every new Feel attribute read.
- `gearForSpeed`: the lazy, `pcall`-guarded call into `VehicleDynamics.GearForSpeed`.
- `revTopRpm`: the rpm at the top of the rev range, which is the car's limiter when `RevRpmMaxFromCar` is 1, else `RevRpmMax`.
- `rpmRev`: maps rpm to rev as `clamp((rpm − RevRpmMin) / (top − RevRpmMin))`.
- `gearedVoices`: chooses the 3 voices for another player's car, and returns the idle anchor as a second value.
- `buildEngineBus`: builds the engine sub-bus.

**Signatures extended** (backwards compatible)
- `newRoutedSource(…, deferPlay, target)` and `newFeelVoice(…, looped, target)` take an optional output target.

**`buildFeel(graph, vehicle)`** (`makeGraph` now passes the vehicle)
- **Local car:** when `RpmRevEnabled` and `EngineBusEnabled` are both 1, it builds the engine sub-bus. Every rev voice and twin then routes to `EngineBus` instead of the device output.
- **Another player's car:** when its class has a gearbox (`GearForSpeed` returns a redline), it picks voices with `gearedVoices`:
  - With `RemoteIdleVoice` 1, the lowest loop is kept when it sits at idle. It is stored as `rev.IdleAnchor`.
  - The remaining voices spread across `RemoteVoiceLowFraction` to `RemoteVoiceHighFraction` of redline, with the car's limiter at the top.
  - With the anchor, the lowest in-gear voice is the highest loop that still reaches the Low point at its `PitchMin`.
  - For Exotic that gives Idle1000, On5000 and On8000. With `RemoteIdleVoice` 0 it gives On3500, On5000 and On8000.
  - Without a gearbox it uses the old `thinned` choice.
  - Whether a gearbox was found is stored in `graph.RemoteGears`.
- New `feel.State` fields: `LineRev`, `DropTimer`, `DropRev`, `DropLastRpm`, `BlipTimer`, `DipTimer`, `DipEnv`, `DipDb`, `ChirpTimer`, `LimiterAge`, `ThunkIndex` and `VentIndex`. `RemoteGear` is added on the first remote tick.

**New functions after `playPop`**
- `playShiftPair`: alternates between the two slots of a pair.
- `playShift(graph, vehicle, speedMph, topRpm)`: handles one shift event.
- `updateEngineBus`: per-tick bus writes, made only when a value changes.

**`updateFeel`**

1. **Inputs.**
   - **Local car:** reads `FeelRpm` (only when `RpmRevEnabled` is 1). If `FeelRpm` is present it also reads `FeelLoad`, `FeelCut`, `FeelSpin`, `FeelOverdrive` and `FeelLimiterRpm` (the rev-range top and the limiter test).
   - **Other players' cars:** call `GearForSpeed(vehicle, speedMph, Drive=="Accelerating", Drive=="Braking", previousGear)` at 15 Hz.
     - On the first tick of a graph (no previous gear), the gear is settled at once, in up to 8 calls.
     - The car counts as geared when a gear and a finite redline above 0 come back.
     - If that differs from the graph's `RemoteGears`, `ForceRefresh` rebuilds the graph once (at most every 2 s) so the voice choice matches.
2. **Shift events** (local car only, baseline-first).
   - `FeelShiftRevision` calls `playShift`.
   - `FeelLimiterRevision` resets `LimiterAge`.
   - Losing `FeelRpm` clears every shift and limiter state.
3. **Load.**
   - Moving forward, the load target is `FeelLoad`. Reverse keeps the old `|throttle|·ReverseLoad`.
   - A downshift blip raises the target to `DownshiftBlipLoad·blip`, so the existing tip-in bark fires.
   - `liftTarget` keeps the driver's own throttle, so the blow-off still follows a real lift and not every shift cut.
4. **Rev.**
   - With engine rpm, the target is `rpmRev(FeelRpm)`, smoothed by `RevRpmSmoothingSeconds` (local) or `RemoteRevSmoothingSeconds` (remote).
   - **Upshift drop:** `playShift` opens a window of up to `ShiftDropMaxSeconds` and predicts the landing rpm with `GearForSpeed(…, newGear)`.
     - With a prediction, the rev falls to that landing with time constant `ShiftDropSeconds/3`, which is ahead of the reported rpm.
     - Without one (`DropRev` −1), the rev follows `FeelRpm` down at that time constant.
     - The window ends as soon as `FeelRpm` stops falling (it rises above its previous tick), or comes within 0.02 rev of the landing.
   - **Remote idle anchor:** on another car's geared graph, the anchor voice's weight is scaled by `1 − smoothstep(1.2·idle, 1.8·idle, rpm)`.
   - **Downshift blip:** adds `DownshiftBlipRev·sin(π·t/T)` for `DownshiftBlipSeconds`.
   - The old speed-shaped rev keeps running as `f.LineRev`, the sci-fi line.
   - Without engine rpm, `f.Rev` uses the old formula and smoothing exactly, and `LineRev = Rev`.
5. **Spin.** `spinIntensity = clamp(FeelSpin·SpinStrainGain)`.
   - The SlipStrain loop follows `max(slip term, spinIntensity)`.
   - The existing engine duck follows `max(slip term, spinIntensity·SpinDuckScale)`.
   - Without a spin, both are the old slip term.
6. **Upshift dip.** An envelope of `ShiftDipDb·strength` dB.
   - It is held while `FeelCut` is on, and always for at least `ShiftDipMinSeconds` (2 ticks at 30 Hz) and at most `ShiftDipMaxSeconds`.
   - It applies to the `EngineBus` fader. With no bus, it multiplies the rev voices' `engineGain`.
7. **Engine bus** (`updateEngineBus`). On only while `FeelRpm` is present.
   - The Peak filter sweeps from `EngineSweepLowHz` to `EngineSweepHighHz`. The sweep position is load blended with rpm by `EngineSweepRevShare`, and the peak height is `EngineSweepDb·load`.
   - The EQ moves from the `…OffDb` values to the `…OnDb` values with load.
   - The tremolo is un-bypassed only when the limiter is active. That means:
     - `FeelCut` is on, or a limiter bounce happened within `LimiterHoldSeconds`; **and**
     - `FeelRpm ≥ FeelLimiterRpm − LimiterNearRpm`.
   - When off, everything is bypassed and the fader is at 1.
8. **TurboWhistle slot as the reactor** (when `ReactorEnabled` is 1).
   - Gain: `ReactorGain·(ReactorLoadFloor + (1 − floor)·load)·(1 + ReactorOverdriveGain·FeelOverdrive)·driveMix`.
   - Pitch: `TurboWhistlePitch·lerp(ReactorPitchMin, ReactorPitchMax, speed/ReactorFullMph)·chirp`.
   - Chirp: `1 − ReactorChirpDepth·sin(π·t/T)` for `ReactorChirpSeconds` after any shift.
   - Without `FeelRpm` the gain is 0, so the voice is silent.
   - While it is on, `TurboWhistleGain` and `TurboWhistlePitchMin/Max` are ignored. `TurboWhistlePitch` still multiplies the pitch.
   - With `ReactorEnabled` at 0, the old spool-driven turbo whistle code runs. Because `TurboWhistleAssetId` is now turbine_high, it is audible as a whistle at `TurboWhistleGain`, not silent. Use `ReactorGain` 0 to silence the reactor.
9. **Sci-fi line.** The turbine pair (gain and octave), the BoostBody pitch and the `BoostLoop` rev pitch (in `updateGraph`) use `lineRev = lerp(LineRev, Rev, SciFiRpmShare)`.
   - Without a gearbox `lineRev` equals the rev exactly.
   - The supercharger and turbo spool stay on the rpm rev, because they are mechanical.

**Other changes**
- `playShift` for every shift: a ShiftThunk (pair, gain × strength) and the reactor chirp.
  - **Up:** the dip and drop. If strength ≥ `ShiftVentMinStrength` (by default `StabiliserVFX@ShiftVentMinStrength`, the vent flame's threshold), a ShiftVent sound; if no ShiftVent slot is filled, `playPop(ShiftCracklePop·strength)` is called directly. It never goes through `FeelPopRevision`, so the VFX vent is not doubled.
  - **Down:** the blip.
  - **Launch:** the thunk and chirp only.
- `Controller.Counts()` also returns `EngineBuses`.

**Our own values, not DRIVE's**
- There is no distortion or compressor. The grit belongs in the synthesised loops (synth part).
- The runtime chain is a modest load tilt, a resonant sweep, the shift dip and the limiter gate.
- Borrowed techniques:
  - a tremolo as the limiter gate;
  - a load-driven EQ tilt.
- The values are derived here:
  - 13.3 Hz is 1/(0.03 + 0.045 s), the contract's limiter cycle;
  - duty 0.4 is the limiter's on-time share;
  - the tilt and sweep numbers were chosen for overrun-dark / load-forward.
- The tremolo `Square` is 0.6. DRIVE uses 1 (full square). The hold is 0.1 s; DRIVE uses 0.12 s.

## Config (all on `EXOTIC_V10_AUDIO`; each has a `<Name>_RaisingThisDoes` string)

**How tuning applies.** Audio values are read when the graph is built. After any edit during Play, raise `ProfileRevision` by 1. That rebuilds the running graph, with a 0.4 s rev handover. Tune in Play, then copy the values you keep into Edit **without** saving a new `ProfileRevision` (see open risk 12).

| Group | Attribute (value) | Meaning |
|---|---|---|
| Existing, changed | `TurboWhistleAssetId` ("" → `rbxassetid://126900976760387`, turbine_high) | Fills the empty slot with the reactor whine |
| | `ProfileRevision` (36 → 37) | Rebuilds a live graph |
| Rev source | `RpmRevEnabled` 1 | Master switch for every gearbox sound path |
| | `RevRpmMin` 1000, `RevRpmMax` 8600 | rpm placed at rev 0 and rev 1 (`RevRpmMax` only when `RevRpmMaxFromCar` is 0 or the car gives no limiter) |
| | `RevRpmMaxFromCar` 1 | The top of the rev range is the car's own limiter (`Drivetrain.<class>@LimiterRpm`), so retuning the limiter keeps redline on the top loop |
| | `RevRpmSmoothingSeconds` 0.02 | Local pitch follow |
| | `RemoteRevSmoothingSeconds` 0.06 | Remote pitch follow (15 Hz) |
| Shifts | `ShiftAudioEnabled` 1 | Drop, dip, blip, clunk, vent |
| | `ShiftDropSeconds` 0.035 | Upshift fall time (with or without the landing prediction; needs `ShiftDropMaxSeconds` > 0) |
| | `ShiftDropMaxSeconds` 0.25 | Longest drop window; it also ends when the rpm stops falling. 0 turns all drop shaping off |
| | `ShiftDipDb` 5 | Upshift volume dip at strength 1 |
| | `ShiftDipMinSeconds` 0.07, `ShiftDipMaxSeconds` 0.25 | Dip hold limits |
| | `ShiftDipAttackSeconds` 0.008, `ShiftDipReleaseSeconds` 0.05 | Dip edges |
| | `DownshiftBlipRev` 0.08 | Blip size in rev |
| | `DownshiftBlipSeconds` 0.12 | Blip length |
| | `DownshiftBlipLoad` 1 | Load spike for the bark |
| | (`ShiftVentMinStrength`, not set) | Upshift strength needed to vent. With no profile attribute it is `Config.Vehicles.StabiliserVFX@ShiftVentMinStrength` (0.7), one knob with the vent flame. Add it on the profile only to split the two |
| | `ShiftCrackleEnabled` 1 | Pop crackle when no ShiftVent sound exists |
| | `ShiftCracklePop` 0.55 | Its pop strength (0.8 or more is a bang) |
| | `ShiftPitchJitter` 0.03 | Clunk and vent pitch spread |
| Engine bus | `EngineBusEnabled` 1 | 0 means no bus is built (the old direct wiring) |
| | `EngineSweepLowHz` 350, `EngineSweepHighHz` 2600 | Peak centre at no load and at full load |
| | `EngineSweepRevShare` 0.4 | How much of the sweep position comes from rpm |
| | `EngineSweepDb` 3 | Peak height at full load |
| | `EngineSweepQ` 1.6 | Peak sharpness |
| | `EngineTiltLowOffDb` −1, `EngineTiltLowOnDb` 2 | EQ low band, overrun → full load |
| | `EngineTiltMidOffDb` −0.5, `EngineTiltMidOnDb` 1.5 | EQ mid band |
| | `EngineTiltHighOffDb` −4, `EngineTiltHighOnDb` 0 | EQ high band |
| Limiter | `LimiterTremoloEnabled` 1 | Limiter stutter switch |
| | `LimiterNearRpm` 200 | How close to the limiter the stutter may start |
| | `LimiterHoldSeconds` 0.1 | Keeps the stutter steady between bounces |
| | `LimiterTremoloHz` 13.3, `LimiterTremoloDepth` 0.7, `LimiterTremoloDuty` 0.4, `LimiterTremoloSquare` 0.6 | Stutter shape |
| Reactor | `ReactorEnabled` 1 | Turns the TurboWhistle slot into the reactor (code default 0). While 1, `TurboWhistleGain` (0.08) and `TurboWhistlePitchMin/Max` (0.5/1.85) are ignored. **0 does not silence it**: it plays turbine_high as the old spool whistle |
| | `ReactorGain` 0.16 | Level at full load; replaces `TurboWhistleGain`. 0 is the way to silence the reactor |
| | `ReactorLoadFloor` 0.25 | Share of the level kept off throttle |
| | `ReactorFullMph` 200 | Speed where the top pitch is reached |
| | `ReactorPitchMin` 0.7, `ReactorPitchMax` 1.4 | Pitch at a standstill and at full speed; they replace `TurboWhistlePitchMin/Max` |
| | `ReactorChirpDepth` 0.03, `ReactorChirpSeconds` 0.08 | Shift chirp |
| | `ReactorOverdriveGain` 0.4 | Extra level in Overdrive |
| Spin and sci-fi | `SpinStrainGain` 1 | How strongly `FeelSpin` drives the strain sound |
| | `SpinDuckScale` 1 | Share of the spin strain that also ducks the engine (by up to `SlipDuckDb`); 0 means a spin never ducks it |
| | `SciFiRpmShare` 0 | 0: turbine and boost loops follow speed; 1: they follow rpm |
| Remote | `RemoteGearsEnabled` 1 | Other players' cars step through their gears |
| | `RemoteVoiceLowFraction` 0.4, `RemoteVoiceHighFraction` 1 | Where their in-gear voices sit, as a fraction of redline |
| | `RemoteIdleVoice` 1 | Keeps their idle loop as one of the 3 voices, fading out between 1.2× and 1.8× idle rpm, so parked and idling cars (your own after exit too) sound like idle. 0 restores the contract's 3 voices across 0.4 to 1.0 |
| Shift slots | `ShiftThunk1/2AssetId` "", `ShiftVent1/2AssetId` "" | Blank means silent and no player |
| | `ShiftThunk1/2Gain` 0.5, `ShiftVent1/2Gain` 0.55 | Levels |
| | `…Pitch` 1 | Playback speed |

**Quick feel dials**
- "Shifts hit harder": `ShiftDipDb`, `ShiftDropSeconds`, `DownshiftBlipRev`.
- "More or less sci-fi": `ReactorGain`, `SciFiRpmShare`.
- "Heavier or grittier engine": `EngineTilt*OnDb`, `EngineSweepDb`.
- "Spin louder": `SpinStrainGain`. "Hear the engine scream through a spin": lower `SpinDuckScale`.
- "Different redline or limiter in the class": nothing to do while `RevRpmMaxFromCar` is 1.

## Voice count (persistent AudioPlayers per vehicle, from the captured config)

| Case | Standard loops | Rev (+ twins) | Feel loops | Feel one-shots | Total |
|---|---|---|---|---|---|
| Exotic, desktop, before this delivery | 4 | 13 (8 + 5) | 6 | 14 | 37 |
| **Exotic, desktop, after (as configured)** | 4 | 13 | 7 (+ reactor) | 14 | **38** |
| Exotic, desktop, shift slots filled | 4 | 13 | 7 | 18 | 42 |
| Exotic, desktop, every slot filled | 4 | 13 | 9 | 19 | **45** (budget 46) |
| **Exotic, small touch device, after** (rev budget 8, no twin, 30 Hz) | 4 | 8 | 7 | 14 | **33** |
| Exotic, small touch device, every slot filled | 4 | 8 | 9 | 19 | **40** (budget 40) |
| Another player's Exotic, Detailed | 2 (Idle, EngineLow; handover only) | 3 (Idle1000, On5000, On8000) | 0 | 0 | 5 (unchanged; 3 playing after handover) |
| Another player's car, Simple | 1 | 0 | 0 | 0 | 1 (unchanged) |
| Standard profile (Piercer, Muscle) | unchanged | – | – | – | unchanged |

Notes on the table:
- The four standard loops are Idle, EngineLow, BoostLoop and DriverWind. Idle and EngineLow stop after the rev handover.
- The engine sub-bus adds 4 processing instances and 4 Wires to the local graph only, and no players.
- Remote limits are unchanged: at most 6 Detailed and 6 Simple other cars.
- Transient players are unchanged: the reliable ignition plus up to `MaxConcurrentOneShotsPerVehicle` (8).
- The code's theoretical ceiling for a profile with every standard loop and every slot filled rises from 48 to 52 (8 + 16 + 9 + 19). Only the Exotic has feel slots, and it stays within 46 on desktop and 40 on mobile.

## Preserved behaviour

- **No `FeelRpm`, so the old path.** This covers Drivetrain `exotic@Enabled` 0, the global `Drivetrain@Enabled` 0, other classes and the parked or exited car.
  - Load, rev, smoothing, pitch, gains, duck, blow-off, turbine and boost loops evaluate exactly as before: `dipGain` is 1, `liftTarget` equals `loadTarget`, `lineRev` equals `Rev`.
  - The Exotic's one difference here is the reactor voice, which exists but is held at gain 0 and never plays.
  - The engine bus, when built, is bypassed at unity.
- Profiles without `FeelDriveEnabled` (`GENERIC_STANDARD_AUDIO`) take none of the new paths. Nothing new is built for them.
- These are untouched:
  - the `VehicleAudioState` remote, its contract and rate limit;
  - `publishLocalState`;
  - reliable ignition;
  - the rev handover and stopping of the standard loops;
  - voice sleep and the gain-epsilon write skip;
  - mobile budgets (rev 8, no twin, 30 Hz);
  - the `ProfileRevision` rebuild;
  - `<Layer>Disabled` and the blank-asset-means-off rule;
  - pop and impact behaviour.
- `FeelPopRevision` stays the only route for overrun pops. The shift crackle calls `playPop` directly.
- **Per-frame behaviour.**
  - No allocation per frame: `pcall(step, …)` passes a function reference, and no tables are created per tick.
  - No new connections.
  - Every new Feel read guards against NaN.
  - `dt` is clamped as before.
- Other players' cars get no new network traffic. Their shifts are pitch only, and there are still 3 rev voices.

## Test hooks (integrator)

**Counts and the instance tree**
- `Controller.Counts()` returns `FeelVoices` and the new `EngineBuses`. Expect 34 feel voices (13 rev + 7 loops + 14 one-shots, up from 33) and 1 bus in an Exotic on desktop, and 0 buses after 5 enter/exit cycles while on foot.
- The graph folder `SoundService.AudioRuntime_Local.Vehicle_<OwnerUserId>` should contain `EngineBus`, `EngineBusSweep`, `EngineBusTilt`, `EngineBusLimiter`, the 4 `Wire_EngineBus_*` wires, and `Wire_Rev_*_FaderToOutput` wires whose `TargetInstance` is `EngineBus`.

**Watch in Play while driving an Exotic**
- `Player_Rev_*` `PlaybackSpeed` saw-tooths through the gears.
- `EngineBus.Volume` dips on each upshift.
- `EngineBusSweep.Frequency` and `EngineBusTilt.*Gain` move with throttle.
- `EngineBusLimiter.Bypass` is false only on the limiter, including neutral revs on the countdown.
- `Player_TurboWhistle` `PlaybackSpeed` follows speed and dips about 3% on shifts.

**Parity**
- Set `Drivetrain.exotic@Enabled` to 0. Expect `EngineBusSweep`, `EngineBusTilt` and `EngineBusLimiter` with `Bypass` true, `EngineBus.Volume` at 1 and `Fader_TurboWhistle` at volume 0. The rev should follow speed as before.

**Switches**
- Set `RpmRevEnabled` (or `EngineBusEnabled`) to 0 and raise `ProfileRevision`. Expect no bus, and voices wired to the output as before.

**Other players' cars** (two-client local test)
- Their graph has `Player_Rev_V10Idle1000`, `V10On5000` and `V10On8000` (with `RemoteIdleVoice` 0: `V10On3500`, `V10On5000`, `V10On8000`), and the pitch steps at gear changes.
- A parked or idling Exotic (another player's, or your own after you get out) sounds like idle, not a low drone. `Fader_Rev_V10Idle1000` falls to 0 once it pulls away.
- Walk up to, or stream in, an Exotic that is already moving fast. It should start in a sensible gear, with no burst of upshifts from first.
- Run this only after the physics part's `GearForSpeed` exists. Before that, expect the old thinned set and a smooth rev.

**Upshift drop** (local Exotic, flat out 1→2 and 2→3): `Player_Rev_*` `PlaybackSpeed` falls, then follows the climbing rpm straight away. It must not sit flat for about 0.25 s and then jump.

## Open risks

1. **Not heard.** Every value is a starting point chosen on paper. Gains, sweep, tilt, dip depth, reactor level and the pop crackle all need Oscar's ear.
2. **Effects API.**
   - Property names were checked against the Roblox API pages:
     - AudioTremolo: Bypass, Depth, Duty, Frequency, Shape, Skew, Square;
     - AudioFilter: Bypass, FilterType, Frequency, Gain, Q;
     - AudioEqualizer: Bypass, Low/Mid/High Gain, MidRange.
   - Ranges and defaults were not checked.
   - The properties written every frame are set once inside the build `pcall`. If any of them fails, no bus is built and the engine stays on the direct route.
   - The tremolo shape properties are set one by one inside `pcall`.
   - Parity with the drivetrain switched off assumes that a bypassed effect is transparent. If it is not, set `EngineBusEnabled` to 0 and raise `ProfileRevision`.
3. **`GearForSpeed` dependency.**
   - It is used for other players' cars and for the local upshift landing prediction.
   - The predicted landing leaves out the thrust-slip flare and uses 3D speed, so it can sit a little low. The drop window now ends when the rpm stops falling, so this shows as a short dip and catch-up at the bottom of the shift (about 0.02 s), not a 0.25 s flat hold. `ShiftDropMaxSeconds` 0 removes all drop shaping.
   - That `RAW_PERFORMANCE_Runtime`, PI and `CategoryId` are present on streamed-in remote cars is still inferred, not checked.
4. **Other players' voices (fixed, needs sign-off).**
   - With `RemoteIdleVoice` 1, one of the three remote voices is the idle loop, so the in-gear range has two voices, On5000 and On8000. They stay within their 0.6 to 1.7 pitch limits from about 3200 rpm to the limiter, which covers every gear above first (downshift at 0.45 of redline, about 3800 rpm).
   - That is a deliberate deviation from the contract's "0.4 to 1.0". Set `RemoteIdleVoice` 0 to return to it; idling cars then drone.
   - Below that, from about 2000 to 3150 rpm (slow rolling in first only), On5000 sits at its pitch floor and the level dips by up to 4.5 dB as the anchor fades.
5. **Rev mapping.** With `RevRpmMaxFromCar` 1, the class limiter (8600) maps to the top loop, which was recorded at 8000. The pitch is about 7% flatter than native, and stays so when the limiter is retuned. Set `RevRpmMaxFromCar` 0 and `RevRpmMax` 8000 for native pitch (the last 600 rpm and the limiter bounce then hold the top loop's pitch).
6. **Spin duck.** A spin also ducks the engine by up to `SlipDuckDb` (6 dB) through `SpinDuckScale` (default 1, the full strain). Lower `SpinDuckScale` if the free-revving spin gets buried; `SpinStrainGain` now only sets the groan.
7. **Shift crackle.** It reuses the overrun pop assets on every flat-out upshift, about 6 per full run. Set `ShiftCrackleEnabled` to 0 if it sounds wrong. The ShiftVent uploads replace it.
8. **The tremolo runs freely.** It is not phase-locked to the limiter bounces. Only its rate matches the default cut timing.
9. **Stale description.** The existing `Descriptions.TurboWhistleAssetId` StringValue still says "turbo whistle … spool", and `ATTRIBUTES` cannot change it. `ReactorEnabled_RaisingThisDoes` documents the new use. The integrator may update the StringValue text.
10. **Rollback order.** If the sources are rolled back but the config is left in place, the old code would play `TurboWhistleAssetId` (turbine_high) as a spool-driven whistle. ROLLBACK restores the asset id to `""` in the same run. Never leave the config applied under the before-sources.
11. **Live tuning needs a `ProfileRevision` bump**, which is the existing audio rule. Edits without a bump apply at the next graph build (re-entry). This also applies to `StabiliserVFX@ShiftVentMinStrength` as the audio reads it; the vent flame reads it live.
12. **Installer BLOCK after tuning in Edit.**
    - `installer_engine.lua` BLOCKs ROLLBACK and re-APPLY when an existing attribute is neither its before nor its after value. `build.py` emits no `allowed` list.
    - So saving a new `ProfileRevision` (anything but 36 or 37) or a new `TurboWhistleAssetId` (for example a later reactor_whine upload) in Edit makes the contract's ROLLBACK recovery BLOCK.
    - **Integrator:** have `build.py` emit `allowed` for these two rows: `ProfileRevision` any number of 37 or more, and `TurboWhistleAssetId` any non-empty id. The engine's `allowed` is an exact-value list, so this needs a range or "non-empty" rule in the engine, or a generous explicit list.
    - Until then, tune audio in Play only. Otherwise restore `ProfileRevision` 37 and `TurboWhistleAssetId` `rbxassetid://126900976760387` before any ROLLBACK or re-APPLY.
    - New attributes (every other row) are not affected: a tuned value is reported, not blocked.
13. **Shared vent threshold.** If the camerafx part's `StabiliserVFX@ShiftVentMinStrength` row is renamed or dropped, the audio falls back to 0.7. The camerafx text for that row could mention that it also sets the audio crackle threshold. That is the integrator's call; this part does not edit camerafx.
