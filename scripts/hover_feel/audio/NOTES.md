# Hover feel: audio part

Status: round 1 (with its review fixes) is installed and working in Play. **Round 2 below is generated only: not
compiled, not run, not heard.** The only local check is a block/bracket balance count in Python.

Files:

- `after/VehicleAudioClient.lua` (71,249 chars) replaces `Modules.Game.Audio.VehicleAudioClient`.
- `after/VehicleAudioCatalog.lua` (12,905 chars) replaces `Modules.Game.Audio.VehicleAudioCatalog`. Install both together.
- `config_spec.json`: the full config for a fresh install (20 attributes, 19 instances; `EXOTIC_V10_AUDIO` has 220 attributes).
- `config_round2.json`: only what round 2 adds or changes on the already-installed config: 53 attribute writes, 0 removals, 47 new instances (all description StringValues under `EXOTIC_V10_AUDIO.Descriptions`).

No server file, remote, contract, bus or startup change.

## Round 2 (Oscar's feedback after driving)

1. **Old sounds off.** A profile attribute `<Layer>Disabled=true` switches any layer off for that profile and keeps its asset id. A blank `<Layer>AssetId` also means off: `GetProfile` never inherited per attribute from the generic profile (it only uses the generic folder when the profile folder itself is missing). The Exotic now has `AccelerationDisabled`, `CoastDisabled`, `DriftLoopDisabled`, `AccelerationEnterDisabled`, `AccelerationReleaseDisabled`, `DriftEnterDisabled` = true. The generic Acceleration loop was the one old sound that was actually playing over the rev engine. Ignition and Shutdown are kept. Idle, EngineLow and EngineHigh remain only as the loading fallback (handover unchanged).
2. **Idle.** `StandInIdle` (the rotary loop) is switched off (`AssetId=""`, `Enabled=false`; the fresh-install spec no longer has it). `StandInExhaust` is now `Load="Any"` with `PitchMin=0.5`, so idle is the exhaust loop at its lowest pitch, and it is the bottom of the thrust ladder too. `EnergyHum` (empty) plays beside it once filled. `V10Idle1000` takes the synthesised hybrid idle later.
3. **Boost.**
   - `BoostLoop` is the dedicated boost loop (`boost_loop`): pitch follows rev 0.9 to 1.15, full gain for a held boost, 0.7 for a mini-boost, 60 ms fade-in (`BoostFadeInSeconds`).
   - New loop slot `BoostBody` (`thruster_roar`) under it, same gain rule, local driver only.
   - `BoostIgnition` on entry and `BoostRelease` (`boost_release`) as before.
   - The one deliberate inheritance: while the profile's `BoostLoopAssetId` is blank, its blank boost layers (BoostLoop, BoostEnter, BoostRelease, BoostRecharge, BoostEmpty, FullBoostSpent) borrow the fallback profile's values. Once `BoostLoopAssetId` is set, nothing is borrowed, so the generic boost loop and BoostEnter do not play. In the capture of 2026-10-04 every generic boost slot is blank, so today this borrows nothing.
   - The rev layers duck 3 dB while boosting (30 ms in, 250 ms out), only when BoostLoop or BoostBody has an asset.
4. **Pops and bangs.** On each `FeelPopRevision` change: `FeelPopStrength` under 0.8 draws from a shuffled bag of `Pop1..Pop4`; 0.8 and over draws from `Bang1/Bang2` (falls back to a pop if both bang slots are empty). Gain is scaled by strength, pitch jitter is plus or minus 6 %. No rate limit. **Difference from the request:** instead of a pool of 2 + 1 voices that swap assets, each slot has its own persistent voice (6 players). Swapping the asset on a playing AudioPlayer cuts it and a newly assigned asset is not ready on the same frame; the bag never repeats a slot back to back, so a run of pops overlaps.
5. **Wind.** On a feel profile DriverWind gain is `(speed / 200) ^ 2`, faded in between 36 and 60 mph, pitch 0.85 to 1.25 with speed; `DriverWindGain` raised from 0.38 to 0.7. New loop slot `WindBuffet` enters from 160 mph, full at 220. Both local driver only. The toolbox body loop stays in `DriverWindAssetId`.
6. `ProfileRevision` goes to 2, so a running graph rebuilds when the round-2 config is applied in Play.

Four existing description StringValues have new text in `config_spec.json` (`BoostLoopAssetId`, `BoostReleaseAssetId`, `BoostEmptyAssetId`, `FullBoostSpentAssetId`). `config_round2.json` cannot express a value change on an existing instance, so on the installed place those four keep their old wording; nothing reads them at runtime.

## What the code does

**Catalog**

- `ResolveProfileId` has a category step (see "Profile selection"). Vehicles with no mapping resolve as before.
- `GetProfile` also returns `PitchRanges`, `RevPitches` and `Feel` (nil unless `FeelDriveEnabled=true`). `<Layer>Disabled` applies to every profile.

**Client**

- `buildFeel` (from `makeGraph`) creates every feel AudioPlayer with the graph. Nothing is created per event.
- `updateFeel` drives the feel voices: from the existing Heartbeat for the local driver (60 Hz desktop, 30 Hz small touch devices), inside `updateGraph` (15 Hz) for other vehicles. `Bus.SetGain` is skipped unless the gain moved by about 0.1 dB.
- `updateGraph` keeps semantic state, cues, the remote and the standard layers, and hands `updateFeel` a small context.
- Standard engine loops stay the voice until one rev layer is `IsReady`, then swap over `Global.RevHandoverSeconds`; if none loads they stay.
- A profile without `FeelDriveEnabled=true` takes none of the new paths.

**Feel drive**

- Load: throttle followed with 22 ms attack and 85 ms release, raised to 0.8; thrust set `sin`, coast set `cos`; tip-in bark.
- Rev: `clamp(0.25 * load + 0.75 * speed / RevReferenceMph + 0.08 * boost)`.
- Rev layers: frequency = `RevPitchBase + (1 - RevPitchBase) * rev`; each loop plays at `frequency / frequency at its own Rev`; neighbours crossfade cos/sin on log frequency, detuned 0.3 % opposite ways. `Load="Any"` sits in both ladders.
- Twin engine copy (1.2 % sharp, local, not on small touch devices). Life noise (0.25 % pitch, 0.6 dB).
- Turbo spool, whistle, blow-off or flutter on lift and at boost end. Supercharger whine. Turbine pair an octave apart. Energy hum.
- Slip strain with a 6 dB engine duck. Drift charge tone and release.
- Impacts by tier (9 / 25 / 55 / 110), at most one per 0.12 s. Landing thump.
- A feel loop at zero gain for 2 s stops its player. An asset that is not loaded is skipped.
- Not read: `FeelSpeedMph`, `FeelBoostCharge`, `FeelGrounded`.

**Other vehicles:** standard profile unchanged. Feel profile, Detailed tier: up to 3 on-load rev loops plus the standard engine loops for the handover; no other loop. Simple tier: `EngineLow` only.

## Profile selection

The server stamps every runtime vehicle `ResolvedAudioProfileId` = the template's `StandardAudioProfileId` or the fallback, with `AudioProfileSource="Standard"`. `Catalog.ResolveProfileId` checks first: default stamp (or none yet) and no template-specific id, then the Model's `CategoryId` attribute, then `Config.Audio.VehicleProfiles` attribute `CategoryProfile_<CategoryId>`. Otherwise the old order applies. `CategoryId` is set by `GarageServer.buildVehicle` before the model is parented.

## Synthesised file to config slot

`P` = `ReplicatedStorage.Config.Audio.VehicleProfiles.EXOTIC_V10_AUDIO`. Every id below is `""` today. Filling them is config only; bump `P.ProfileRevision` to rebuild a live graph.

Engine loops (rev position = `(rpm / 8000 - 0.125) / 0.875`, already set):

| File | Instance | Attribute | Load | Rev |
|---|---|---|---|---|
| `v10_idle_1000` (hybrid sci-fi idle) | `P.RevLayers.V10Idle1000` | `AssetId` | Any | 0 |
| `v10_on_2000` | `P.RevLayers.V10On2000` | `AssetId` | On | 0.1429 |
| `v10_on_3500` | `P.RevLayers.V10On3500` | `AssetId` | On | 0.3571 |
| `v10_on_5000` | `P.RevLayers.V10On5000` | `AssetId` | On | 0.5714 |
| `v10_on_6500` | `P.RevLayers.V10On6500` | `AssetId` | On | 0.7857 |
| `v10_on_8000` | `P.RevLayers.V10On8000` | `AssetId` | On | 1 |
| `v10_off_3000` | `P.RevLayers.V10Off3000` | `AssetId` | Off | 0.2857 |
| `v10_off_6000` | `P.RevLayers.V10Off6000` | `AssetId` | Off | 0.7143 |

Fill the eight together: as soon as one has an id, the toolbox stand-ins (`StandInExhaust`, `StandInRev`) are dropped.

Other files (attributes on `P` itself):

| File | Attribute on `P` | Kind | Notes |
|---|---|---|---|
| `boost_loop` | `BoostLoopAssetId` | loop | existing slot. Setting it also stops the borrowed generic boost layers. |
| `thruster_roar` | `BoostBodyAssetId` | loop | new slot (round 1 notes pointed this file at `BoostLoopAssetId`; that is superseded) |
| `boost_ignite` | `BoostIgnitionAssetId` | one-shot | |
| `boost_release` | `BoostReleaseAssetId` | one-shot | existing slot; early release and the end of a mini-boost. Put the same id in `BoostEmptyAssetId` / `FullBoostSpentAssetId` if a drained tank should sound too. |
| `turbine_low` | `TurbineLowAssetId` | loop | |
| `turbine_high` | `TurbineHighAssetId` | loop | one octave above `turbine_low` |
| `energy_hum` | `EnergyHumAssetId` | loop | also part of the idle |
| `supercharger_whine` | `SuperchargerWhineAssetId` | loop | replaces toolbox 404779487 |
| `stabiliser_strain` | `SlipStrainAssetId` | loop | replaces the toolbox tyre squeal; then set `SlipStrainPitch` to 1 and retune `SlipStrainGain` |
| `drift_charge` | `DriftChargeAssetId` | loop | |
| `wind_rush` | `DriverWindAssetId` | loop | existing slot; replaces toolbox 4471836491 |
| `wind_buffet` | `WindBuffetAssetId` | loop | new slot |
| `scrape_loop` | none | loop | **unused**: the Feel state has no sustained-contact signal |
| `turbo_flutter` | `TurboFlutterAssetId` | one-shot | |
| `drift_release` | `DriftChargeReleaseAssetId` | one-shot | |
| `pop_1` .. `pop_4` | `Pop1AssetId` .. `Pop4AssetId` | one-shot | new slots |
| `bang_1`, `bang_2` | `Bang1AssetId`, `Bang2AssetId` | one-shot | new slots |
| `impact_light` / `_medium` / `_heavy` / `_severe` | `ImpactLightAssetId` / `ImpactMediumAssetId` / `ImpactHeavyAssetId` / `ImpactSevereAssetId` | one-shot | |
| `land_thump` | `LandingThumpAssetId` | one-shot | |

Still from the toolbox with no synthesised replacement: `TurboWhistleAssetId` (241458901), `BlowOffAssetId` (4940167544), `EngineLowAssetId` (1323976194, fallback and Simple tier only).

## AudioPlayer count

Persistent players per vehicle (feel voices sleep at zero gain; the standard engine loops stop after the handover):

| Case | Created |
|---|---|
| Local driver, hard limit in code | 48 = 8 standard loops + 16 rev + 9 feel loops + 15 feel one-shot voices |
| Local driver, default desktop budget | 46 (rev budget 14) |
| Local driver, small touch device | 40 (rev budget 8, no twin) |
| Exotic, every slot filled, desktop | 41 = 4 standard (Idle, EngineLow, BoostLoop, DriverWind) + 13 rev + 9 + 15 |
| Exotic, every slot filled, small touch device | 36 |
| Exotic as configured today | 10 = Idle, EngineLow, DriverWind + StandInExhaust, StandInRev, its twin + TurboWhistle, SuperchargerWhine, SlipStrain + BlowOff |
| Other vehicle, feel profile, Detailed | up to 6 (3 rev + up to 3 standard engine loops; Exotic: 5 filled, 4 today). At most 3 playing outside the 0.4 s handover. |
| Other vehicle, Simple | 1 |
| Standard profile | unchanged |

Transient, as today: the reliable ignition player and up to 8 existing one-shots.

## Not verified

- Round 2 has not been compiled or run. I have not heard any asset; gains and curves are guesses.
- With the rotary idle gone, today's idle is the toolbox exhaust loop at 0.5x speed. It may sound thin or rough until `v10_idle_1000` and `energy_hum` are in.
- "Old sounds" for boost: the captured generic profile has no boost assets, so I could not tell which boost sound Oscar heard. If the live generic profile has boost assets, they play on the Exotic until `BoostLoopAssetId` is set.
- `FeelPopRevision` / `FeelPopStrength` are read as the contract describes; the producer side was not available to test against.
- What `AudioPlayer.IsReady` reports for an unauthorised asset; `TimePosition` rewind on retrigger.
- `RevReferenceMph = 170` and the 200 mph wind figure are guesses at Exotic speeds.
- Pre-existing, not changed: `Catalog.GlobalBool(name, true)` returns true when the attribute is false.

## Manual test list

1. Both modules compile. Apply `config_round2.json` (or `config_spec.json` on a place without the profile).
2. Piercer: unchanged; `Counts().FeelVoices` is 0.
3. Exotic: `Counts().FeelVoices` is 7 on desktop. No `Player_Acceleration` under the graph folder; no `Player_Rev_StandInIdle`.
4. Idle in the seat: exhaust stand-in at low pitch only, nothing rotary. Generic idle is heard for at most the first half second.
5. Throttle, lift, coast: as round 1, minus the old acceleration loop. Set `AccelerationDisabled=false` and bump `ProfileRevision`: the old loop returns (proves the switch).
6. Boost: no error with the slots blank. With temporary ids in `BoostLoopAssetId` and `BoostIgnitionAssetId`: ignition and loop land together, loop pitch follows rev, engine steps back slightly and recovers; mini-boost is quieter.
7. Pops: with temporary ids in `Pop1..Pop4` and `Bang1`, lift after hard thrust above 40 mph: a run of crackles, no slot twice in a row; end a boost: one bang then crackles. Blank slots: silent, no error.
8. Wind: silent below about 40 mph, clearly audible by 120, rising to 200, pitch rising with speed. Not heard from another player's car.
9. Drift, wall hit, landing, exit, parked, re-enter, two clients, `FeelAudioEnabled=false`, mobile emulation: as round 1.
