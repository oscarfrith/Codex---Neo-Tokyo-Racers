All 10 review items are applied in `audio/` and both after files compile in PR98 Edit. Items 2, 3 and 7 differ from the review's exact wording, for the reasons below; none were declined. Nothing has been played or heard.

**Fixed**
1. **MAJOR, upshift drop hold.** The drop window now ends as soon as `FeelRpm` stops falling. I added `feel.State.DropLastRpm`, reset to `math.huge` on each upshift, and used the review's falling-rpm check.
2. **MAJOR, remote idle drone.** Implemented as asked: `RemoteIdleVoice {1,0,1}` in the defaults and config, the 5th `GearForSpeed` return used in `buildFeel`, `rev.IdleAnchor`, and the `1 − smoothstep(1.2·idle, 1.8·idle, rpm)` weight fade. One change: with the idle voice kept, the lowest in-gear voice is the highest loop that can still pitch down to the low point within its pitch floor. The review's nearest-loop rule picks On3500 and On8000. An offline sweep showed one voice stuck at its 0.6/1.7 pitch limit, 9–13% off pitch, at 3950–5100 and 6400–8150 rpm, which is the main gear range. The new rule picks Idle1000, On5000 and On8000: no stuck voice from about 3200 rpm to the limiter. The cost is that slow rolling in first (about 2000–3150 rpm) holds On5000's pitch floor and dips up to 4.5 dB. This departs from the contract's "0.4 to 1.0", so the integrator needs to sign it off. `RemoteIdleVoice` 0 restores the contract's On3500, On5000 and On8000.
3. **MINOR, gear settle.** A remote graph built while the car is moving settles its gear on its first tick, in up to 8 calls. I passed the real accelerating flag and `braking = false` instead of the review's `true`, so a cruising car settles in its cruise gear, not the lowest gear below 92% of redline.
4. **MINOR, rebuild check.** The per-tick check is now `geared = gear ~= nil and finite redline > 0`. `engineRpm` is used only when `graph.RemoteGears and geared`.
5. **MINOR, limiter mapping.** Added `RevRpmMaxFromCar {1,0,1}` and a `revTopRpm` helper. The top of the rev range is `FeelLimiterRpm` for your car, `GearForSpeed`'s limiter for other cars, or `RevRpmMax` as the fallback. It is used everywhere rpm is mapped to rev, and the output is unchanged at today's defaults.
6. **MINOR, spin duck.** Added `SpinDuckScale {1,0,1}`. The duck target is taken before the spin is merged in, so it is identical to before when there is no spin.
7. **MINOR, reactor slot.** Text only, in the config strings and NOTES. While `ReactorEnabled` is 1, `TurboWhistleGain` and `TurboWhistlePitchMin/Max` are ignored. Setting it to 0 does not silence the slot: it plays turbine_high as the old spool whistle, so `ReactorGain` 0 is how to turn the reactor off. I didn't take the review's alternative (make 0 skip the voice): no flag marks the slot as repurposed, and skipping it would change the no-gearbox code path.
8. **MINOR, dead `ShiftDropSeconds`.** The window now always opens. With no landing prediction (`DropRev` −1), the rev follows `FeelRpm` down at `ShiftDropSeconds/3`. `ShiftDropMaxSeconds` 0 turns all drop shaping off, and its text says so.
9. **MINOR, two vent thresholds.** Took the review's "better" option. I removed the profile row, so `Catalog.readFeel` reads `Config.Vehicles.StabiliserVFX@ShiftVentMinStrength` when the profile doesn't set its own. One knob now drives the crackle and the vent flame.
10. **MINOR, installer block after tuning in Edit.** Added open risk 12 and an integrator note. `build.py` needs `allowed` entries for `ProfileRevision` (37 or more) and `TurboWhistleAssetId` (any non-empty id). Because the engine's `allowed` is an exact-value list, that needs a range or non-empty rule. Until then, tune audio in Play only. `config.py` keeps the 3-value row format because `build.py` expects it.

**Final compile results** (CONTRACT section 2 check, PR98 Edit):
- `VehicleAudioClient OK 92919`
- `VehicleAudioCatalog OK 16022`

An offline check of `config.py` found no problems: 136 rows, no duplicate keys, no clash with existing attributes, and every value matches its code default and bounds (except `ReactorEnabled`, deliberately).

Files are in C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\audio:
- after\VehicleAudioClient.lua
- after\VehicleAudioCatalog.lua
- config.py
- NOTES.md (new "Review fixes" table; risks 3–6 and 11 updated; risks 12–13 added)