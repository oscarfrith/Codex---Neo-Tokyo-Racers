# Hover feel: audio part

Status: **generated; both modules reported compiling in Studio; not installed, not run, not heard.** The review fixes
(round 2, below) have not been compiled yet. The only local check is a block/bracket balance count in Python.

Files:

- `after/VehicleAudioClient.lua` (67,839 chars) replaces `Modules.Game.Audio.VehicleAudioClient`.
- `after/VehicleAudioCatalog.lua` (11,412 chars) replaces `Modules.Game.Audio.VehicleAudioCatalog`. Install both together: the client reads `profile.RevPitches` and `profile.Feel`, which only the new catalog provides.
- `config_spec.json`: 20 attributes, 19 instances (18 description StringValues and the `EXOTIC_V10_AUDIO` profile folder with 173 attributes).

No server file, remote, contract, bus or startup change.

## Round 2 (review fixes)

1. **Engine stays audible if rev assets do not load.** `makeGraph` no longer drops Idle, EngineLow and EngineHigh for a rev profile. They remain the engine voice until one rev layer AudioPlayer reports `IsReady` (checked every 0.2 s), then swap equal-power to the rev layers over `Global.RevHandoverSeconds` (0.4). When the swap is complete and the standard engine loops have faded, their players are stopped. If no rev layer ever loads, nothing changes and nothing is logged. The handover needs one ready layer only; a rev layer that is still not loaded is silent until it is.
2. **Feel step rate.** `Quality.LocalFeelUpdateHz` (60) on desktop, `Quality.LocalFeelUpdateHzMobile` (30) on small touch devices, chosen with the same `mobileBudget()` test at the 4 Hz priority pass. Only the local driver's feel voices use it; everything else stays on `ParameterUpdateHz` (15). `Bus.SetGain` is skipped for a feel voice unless its gain moved by more than about 0.1 dB (1.2 %, floor 0.002) or reached zero.
3. **Slots match the synthesised files** (table below). `TurbineScream` became `TurbineLow` + `TurbineHigh`; `TurboFlutter` is new; the V10 rev layers are renamed and repositioned for a 1,000 to 8,000 rpm engine (`RevPitchBase = 0.125`).

## What changed and why

**Catalog**

- `ResolveProfileId` gains a category step (see "Profile selection"). Vehicles with no mapping resolve exactly as before.
- `GetProfile` also returns `PitchRanges`, `RevPitches` (both empty for a standard profile) and `Feel` (nil unless the profile has `FeelDriveEnabled=true`). Feel layers use the existing `<Layer>AssetId / Gain / Pitch` attribute contract.

**Client**

- `newRoutedSource` takes an optional `deferPlay` argument so feel voices are created silent and stopped.
- `buildFeel` (called from `makeGraph`) creates every feel AudioPlayer with the graph. Nothing is created per event.
- `updateFeel` drives the feel voices: from the existing Heartbeat connection for the local driver, inside `updateGraph` (15 Hz) for other vehicles.
- `updateGraph` keeps ownership of semantic state, cues, the remote and the standard layers. It hands `updateFeel` a small context (running, held for ignition/first drive, parked, exit-coasting, mix). Edits inside it: the standard engine loops are scaled by the handover, BoostLoop gain is scaled by boost kind, the Acceleration loop is ducked with the engine, and a loop layer with `<Layer>RevPitchMin/Max` follows rev.
- `refreshPriorities` rebuilds a feel graph when `Global.FeelAudioEnabled` flips or the profile's `ProfileRevision` changes (so config edits can be auditioned in Play by bumping `ProfileRevision`).
- `Controller.Counts()` gains `FeelVoices`.

A profile without `FeelDriveEnabled=true` takes none of the new paths: same layers, same pitches, same players.

**How the feel drive works**

- Load: throttle (`FeelThrottle`, or the `Accelerating`/reversing state when the attribute is missing) followed with 22 ms attack and 85 ms release, raised to 0.8. Thrust set gain is `sin(load * 90 deg)`, coast set gain is `cos`. Tip-in bark: `BarkGain * (load - load followed over BarkSeconds)` added to the thrust set.
- Rev: `clamp(0.25 * load + 0.75 * speed / RevReferenceMph + 0.08 * boost)`, 0.12 s up, 0.28 s down. Speed is the root part's velocity (the same number as `FeelSpeedMph`, without the 0.5 mph steps).
- Rev layers: engine frequency = `RevPitchBase + (1 - RevPitchBase) * rev`. Each loop plays at `frequency / frequency at its own Rev`, limited to its `PitchMin..PitchMax`. The two loops either side of the current frequency crossfade with cos/sin gains on the log of frequency. Neighbours are detuned 0.3 % in opposite directions. A layer with `Load="Any"` (the idle) sits at the bottom of both the thrust and the coast ladder.
- Twin engine: a second copy of each on-load loop, 1.2 % sharp, at 0.6 of the main gain, started 37 % into the loop. Local driver only; off on small touch devices unless `Quality.TwinEngineOnMobile=true`.
- Life: two slow random drifts on the local engine, about 0.25 % pitch and 0.6 dB level.
- Turbo: spool rises toward `load * (0.35 + 0.65 * rev)` (or 1 while boosting), falls on lift. Whistle pitch `0.5 + 1.35 * spool`. A vent fires on a lift after 0.6 s of sustained load, or when a boost ends, if spool is at least 0.35; gain scales with spool. Spool below 0.7 plays `TurboFlutter`, otherwise `BlowOff`; if one slot is empty the other is used.
- Supercharger whine follows rev. Turbine: pitch = `2 ^ (TurbineOctaveStart + TurbineOctaves * rev)` relative to the `TurbineLow` recording (-0.5 to +1.5 octaves); `TurbineHigh` plays one octave below that figure, and the pair crossfades equal-power between octave 0 and 1. Gain enters from rev 0.3. Energy hum is steady while driving and rises with `FeelHover`.
- Slip strain: `smoothstep(0.12, 0.6, |FeelSlip|)`, with a floor of 0.35 while drifting. Pitch 0.92 to 1.06. The rev layers and the Acceleration loop duck up to 6 dB under it (60 ms in, 350 ms out). No duck when the SlipStrain slot is empty.
- Boost: BoostLoop at 0.7 gain for a mini-boost, and its pitch follows rev (0.9 to 1.15). `BoostIgnition` fires when `FeelBoostKind` goes from `""` to `"Boost"`/`"Mini"`; the existing `BoostEnter`, `BoostRelease`, `BoostEmpty` and `FullBoostSpent` one-shots play as before.
- Drift charge: tone gain fades in from charge 0.04 to 0.3, pitch climbs to charge 1. `DriftChargeRelease` fires when the kind becomes `"Mini"`, scaled by the peak charge.
- Impacts: on a `FeelImpactRevision` change, tier by `FeelImpactStrength` (9 / 25 / 55 / 110). An empty tier borrows the nearest populated one, lighter first. At most one per 0.12 s. Landing: on a `FeelLandRevision` change, gain from 0.25 at 6 studs/s to 1 at 60 studs/s.
- Sleep: a feel loop at zero gain for 2 s stops its player; it restarts when needed. An asset that is not loaded (`IsReady` false) is skipped until it is.
- Not used: `FeelSpeedMph`, `FeelBoostCharge` (the existing `MobileDriveInputState.BoostPercent` path is untouched), `FeelGrounded`.

**Other vehicles (no Feel attributes)**

- Standard profile: unchanged.
- Feel profile with rev layers, Detailed tier: at most 3 rev loops chosen evenly from the on-load ladder, driven by `AssemblyLinearVelocity` and `AudioDrive`/`AudioBoost`, plus the standard engine loops for the handover. No Acceleration, Coast, DriftLoop or BoostLoop loop, no twin, no forced induction, no slip, no impacts. Existing one-shots (Ignition, DriftEnter, BoostEnter and so on) still play. This also covers the player's own parked car.
- Simple tier: `EngineLow` only, as today.

## Profile selection

The server stamps every runtime vehicle with `ResolvedAudioProfileId` = the template's `StandardAudioProfileId` or the fallback, and `AudioProfileSource="Standard"`. The server is not changed, so an Exotic arrives stamped `GENERIC_STANDARD_AUDIO`.

`Catalog.ResolveProfileId` now checks first: if the vehicle has no stamp yet, or carries the default stamp (`AudioProfileSource == "Standard"` and the resolved id is the fallback id), and its `StandardAudioProfileId` is blank or the fallback, it reads the vehicle Model's `CategoryId` attribute and looks up `Config.Audio.VehicleProfiles` attribute `CategoryProfile_<CategoryId>`. If that names an existing profile folder, it wins. Otherwise the old order applies (resolved, standard, fallback). A package resolved by a future authoritative owner, or a template with its own profile id, still wins.

Where `CategoryId` comes from: in the repo mirror, `ServerStorage.Modules.Game.Garage.GarageServer` `buildVehicle` sets `vehicle:SetAttribute("CategoryId", profile.CurrentCategory)` before parenting the clone into `Workspace.World.Runtime.PlayerVehicles`, so it replicates with the model. The mirror is older than live. **Check on a spawned Exotic that the Model has `CategoryId = "exotic"`.** If it does not, the car keeps the generic voice and nothing errors.

The client already re-resolves the profile id every priority pass (4 Hz) and rebuilds on change, so a stamp that arrives late is picked up.

## Synthesised file to config slot

`P` = `ReplicatedStorage.Config.Audio.VehicleProfiles.EXOTIC_V10_AUDIO`. Every id below is `""` today. Filling them is config only; bump `P.ProfileRevision` to rebuild a live graph.

Engine loops (rev position = `(rpm / 8000 - 0.125) / 0.875`; already set in the spec):

| File | Instance | Attribute | Load | Rev |
|---|---|---|---|---|
| `v10_idle_1000` | `P.RevLayers.V10Idle1000` | `AssetId` | Any | 0 |
| `v10_on_2000` | `P.RevLayers.V10On2000` | `AssetId` | On | 0.1429 |
| `v10_on_3500` | `P.RevLayers.V10On3500` | `AssetId` | On | 0.3571 |
| `v10_on_5000` | `P.RevLayers.V10On5000` | `AssetId` | On | 0.5714 |
| `v10_on_6500` | `P.RevLayers.V10On6500` | `AssetId` | On | 0.7857 |
| `v10_on_8000` | `P.RevLayers.V10On8000` | `AssetId` | On | 1 |
| `v10_off_3000` | `P.RevLayers.V10Off3000` | `AssetId` | Off | 0.2857 |
| `v10_off_6000` | `P.RevLayers.V10Off6000` | `AssetId` | Off | 0.7143 |

Fill the eight together: as soon as one of them has an id, the three toolbox stand-ins (`StandInIdle`, `StandInExhaust`, `StandInRev`) are dropped.

Other loops and one-shots (attributes on `P` itself):

| File | Attribute on `P` | Kind | Notes |
|---|---|---|---|
| `turbine_low` | `TurbineLowAssetId` | loop | new slot |
| `turbine_high` | `TurbineHighAssetId` | loop | new slot, one octave above `turbine_low` |
| `energy_hum` | `EnergyHumAssetId` | loop | |
| `thruster_roar` | `BoostLoopAssetId` | loop | existing slot: plays while boosting, 0.7 gain for a mini-boost, pitch follows rev. No new slot was added because this one already is "the loop under boost". Not heard on other players' Exotics (their rev graph has no BoostLoop). |
| `supercharger_whine` | `SuperchargerWhineAssetId` | loop | replaces toolbox 404779487 |
| `stabiliser_strain` | `SlipStrainAssetId` | loop | replaces the toolbox tyre squeal 435752381; then set `SlipStrainPitch` to 1 and retune `SlipStrainGain` (now 0.8 and 0.2 for the squeal) |
| `drift_charge` | `DriftChargeAssetId` | loop | plays at 0.8x to 1.7x |
| `wind_rush` | `DriverWindAssetId` | loop | existing slot; replaces toolbox 4471836491 |
| `scrape_loop` | none | loop | **unused.** The Feel state has impact events but no sustained-contact signal, so nothing can drive it yet. |
| `boost_ignite` | `BoostIgnitionAssetId` | one-shot | |
| `boost_release` | `BoostReleaseAssetId`, and the same id in `BoostEmptyAssetId` and `FullBoostSpentAssetId` | one-shot | existing slots. Release covers an early release (and the end of a mini-boost); Empty and FullBoostSpent cover a drained tank. Leave the last two blank if a drained tank should stay silent. |
| `turbo_flutter` | `TurboFlutterAssetId` | one-shot | new slot; plays instead of the blow-off when spool is under 0.7 |
| `drift_release` | `DriftChargeReleaseAssetId` | one-shot | |
| `impact_light` | `ImpactLightAssetId` | one-shot | |
| `impact_medium` | `ImpactMediumAssetId` | one-shot | |
| `impact_heavy` | `ImpactHeavyAssetId` | one-shot | |
| `impact_severe` | `ImpactSevereAssetId` | one-shot | |
| `land_thump` | `LandingThumpAssetId` | one-shot | |

Still from the toolbox with no synthesised replacement: `TurboWhistleAssetId` (241458901), `BlowOffAssetId` (4940167544). `EngineLowAssetId` (1323976194) and the generic `IdleAssetId`, `AccelerationAssetId` and `IgnitionAssetId` are kept.

## AudioPlayer count

Persistent players per vehicle (created with the graph; feel voices sleep at zero gain, the standard engine loops stop after the handover):

| Case | Created |
|---|---|
| Local driver, hard limit in code | 40 = 8 standard loops + 16 rev + 7 feel loops + 9 feel one-shot voices |
| Local driver, default desktop budget | 38 (rev budget 14) |
| Local driver, small touch device | 32 (rev budget 8, no twin) |
| Exotic, every slot filled, desktop | 34 = 5 standard (Idle, EngineLow, Acceleration, BoostLoop, DriverWind) + 13 rev (1 idle + 5 on + 2 off + 5 twin) + 7 + 9 |
| Exotic, every slot filled, small touch device | 29 (8 rev, no twin) |
| Exotic as specified today | 12 = Idle, EngineLow, Acceleration, DriverWind + 3 stand-ins + 1 twin + TurboWhistle, SuperchargerWhine, SlipStrain + BlowOff |
| Other vehicle, feel profile, Detailed | up to 6 created (3 rev + up to 3 standard engine loops; Exotic: 5). At most 3 are playing except during the 0.4 s handover. |
| Other vehicle, Simple | 1 |
| Standard profile | unchanged (up to 8 loops local, 7 remote) |

Transient, as today: the reliable ignition player (1) and up to `MaxConcurrentOneShotsPerVehicle` (8) existing one-shots.

## Not verified

- Nothing has been run. Round 2 has not been compiled.
- I have not heard any asset. Every gain, the stand-in `Rev` positions, the turbine sweep and the pitch limits are guesses. The tyre squeal as stabiliser strain may read as tyres; blank `SlipStrainAssetId` if so (the engine duck goes with it).
- What `AudioPlayer.IsReady` reports for an asset the place is not authorised to use. The handover assumes it stays false.
- `CategoryId` on the live runtime Model (mirror evidence only). Time-trial or other spawn paths may not set it.
- `RevReferenceMph = 170` is a guess at Exotic top speed. The Feel state does not publish top speed.
- `TimeLength` and writable `TimePosition` are used inside `pcall`. Restarting a one-shot is `Stop`, `TimePosition = 0`, `Play`; untested.
- Twin copies start 37 % into the loop; with a 1.2 % detune the offset between the copies sweeps continuously. Whether that sounds like a beat or a flanger depends on the loops.
- The Feel attributes are not written by the before `DrivingClient`; the Feel paths were written against `CONTRACT.md` only. If `FeelImpactRevision` is absent while `FeelThrottle` is present it is read as 0, so the first impact still plays.
- Pre-existing, not changed: `Catalog.GlobalBool(name, true)` returns true when the attribute is false, so `VehicleAudioCueExpansionEnabled=false`, `ParkedVehicleAudioEnabled=false` (client side), `ExitCoastAudioEnabled=false`, `BoostRechargeStopAtFull=false`, `FullBoostReplacesEmpty=false` and `ExitCoastSuppressEngineHigh=false` have no effect in the client. The new switches do not use it.

## Manual test list

1. Edit: both modules compile. Apply `config_spec.json`. `Config.Audio.VehicleProfiles` has `EXOTIC_V10_AUDIO` with `RevLayers` (11 layer folders) and attribute `CategoryProfile_exotic`.
2. Piercer (standard profile): sounds and behaves as before. `VehicleAudioClient.Counts().FeelVoices` is 0 while driving it.
3. Spawn an Exotic. Model has `CategoryId="exotic"`; with `Global.DebugAudio=true` the log shows `graph Internal Detailed EXOTIC_V10_AUDIO`; `Counts().FeelVoices` is 8 on desktop.
4. Ignition plays once, then the engine comes in after the usual lead: the generic idle first, swapping to the stand-in rev layers within about half a second of their loading. No engine during the first-drive Controls page.
5. Fallback: set the three stand-in `AssetId`s to an id that cannot load (or run where the toolbox ids are not authorised) and bump `ProfileRevision`: the car keeps the generic Idle and EngineLow voice indefinitely, with no warnings in the console.
6. Hold throttle from rest: engine pitch rises continuously with speed, with a short bark at tip-in; turbo whistle and supercharger whine rise. Lift after a second of throttle: one blow-off, exhaust stand-in while coasting. Tap the throttle quickly: no blow-off machine-gun.
7. Drift: strain loop fades in, engine ducks and recovers. Hold the drift to a mini-boost: no error (BoostLoop, ignition and release slots are blank today).
8. Boost to empty and release early: existing cues as before; blow-off at boost end.
9. Hit a wall, land a jump: no error (slots blank). With a temporary id in `ImpactMediumAssetId`, one hit = one sound, repeated scraping no faster than 0.12 s.
10. Exit while moving, then parked: the car is heard in 3D; under `SoundService.AudioRuntime_Local.Vehicle_<id>` at most 3 `Player_Rev_*` loops exist and, after the handover, `Player_Idle`/`Player_EngineLow` are not playing. Re-enter: no second ignition, feel voices return.
11. Two clients: the other player's Exotic pitch follows its speed. Twelve cars: the 6 + 6 budget holds.
12. `Global.FeelAudioEnabled=false` in Play: the Exotic rebuilds within 0.25 s to the standard layers only. True again: feel returns.
13. Edit a gain on the profile and bump `ProfileRevision` in Play: the graph rebuilds with the new value.
14. Sit idle for 5 s, inspect the graph folder: of the `Player_Rev*` and feel loop players only the idle stand-in reports `IsPlaying`.
15. Mobile emulation (small touch viewport): no `Player_RevTwin_*` instances; no console errors.
16. Exit and re-enter ten times, switch cars: one `Vehicle_<id>` folder per tracked vehicle, `Counts().VehicleFaders` returns to the same number.
