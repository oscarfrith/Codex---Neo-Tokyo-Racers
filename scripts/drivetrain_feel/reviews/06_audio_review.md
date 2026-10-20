1. **MAJOR**: `audio/after/VehicleAudioClient.lua` lines 1186–1194, armed by `playShift` at 1003–1006.
   - **Why it is wrong:** the upshift drop window ends only when `rpmRev(FeelRpm) <= DropRev + 0.02`, which is about 152 rpm. The physics side (`physics/after/VehicleDynamics.lua` 885–891) lowers rpm with a 0.05 s exponential lag, adds `ThrustSlipFlare`, and starts climbing again once the 0.06 s cut and 0.06 s blend end. In a flat-out 1→2 (and borderline 2→3) the gap never gets below about 200 rpm. GearForSpeed also leaves out the slip flare and uses 3D speed, so its predicted landing sits low.
   - **Result:** for the full `ShiftDropMaxSeconds` (0.25 s) the audio pitch is held flat at the predicted landing while the real rpm and the HUD needle climb. The pitch then jumps up by about 0.04 rev (about 5%) on the most-heard shifts.
   - **Fix:** end the window as soon as FeelRpm stops falling. Add `DropLastRpm = math.huge` to `feel.State` and set `f.DropLastRpm = math.huge` in the Up branch of `playShift`. Then:
     ```lua
     if f.DropTimer > 0 then
     	f.DropTimer -= dt
     	local falling = engineRpm <= f.DropLastRpm
     	f.DropLastRpm = engineRpm
     	if f.DropTimer > 0 and falling and revTarget > f.DropRev + 0.02 then
     		revTarget, revSeconds = f.DropRev, tuning.ShiftDropSeconds / 3
     	else
     		f.DropTimer = 0
     	end
     end
     ```

2. **MAJOR**: `gearedVoices` at line 260 and its call at 374–383.
   - **Why it is wrong:** with a gearbox, other players' cars get On3500, On5000 and On8000, so the idle loop is gone. A parked or idling Exotic runs at idle rpm, which maps to rev 0.013. It plays On3500 at the 0.6 PitchMin floor at `RevOffLoadGain` (0.6), so it sounds like a 2100 rpm on-load drone. The old voice set (Idle1000/On5000/On8000) did not do this.
   - **Who hears it:** every parked Exotic in free roam, and the player's **own** Exotic after every exit, because it becomes an External Detailed graph. NOTES risk 4 misses the own-car case. This follows the contract's "0.4 to 1.0" wording, so the integrator should sign off the deviation.
   - **Fix:**
     - In `buildFeel`, take `idle` from GearForSpeed's 5th return value.
     - In `gearedVoices`, when the new number `RemoteIdleVoice` (default 1) is on and `list[1].Rev <= rpmRev(tuning, idle) + 0.05`, reserve `list[1]` and spread `count - 1` voices across Low..High.
     - Store that voice as `rev.IdleAnchor`. On geared remote graphs, scale its weight by `1 - smoothstep(idle*1.2, idle*1.8, engineRpm)` so it does not bleed into the gear range (the problem critique 14 raised).
     - Add `RemoteIdleVoice = { 1, 0, 1 }` to `feelDefaults`, plus a config row with its `_RaisingThisDoes` string.

3. **MINOR**: line 1113.
   - **Why it is wrong:** `f.RemoteGear` starts as nil. GearForSpeed (physics lines 1030–1043) clamps nil to gear 1 and moves at most one gear per call, and remote cars update at 15 Hz. A remote Exotic whose graph is built while moving goes through tier changes, ForceRefresh or a ProfileRevision rebuild. It sits on the limiter (rev 1) and then ripples through up to 6 fake upshifts over about 0.4 s.
   - **Fix:** after the call, settle the gear once:
     ```lua
     if gear and f.RemoteGear == nil then
     	for _ = 1, 8 do
     		local nextGear, nextRpm = gearForSpeed(vehicle, speedMph, true, false, gear)
     		if nextGear == nil or nextGear == gear then break end
     		gear, rpm = nextGear, nextRpm
     	end
     end
     ```

4. **MINOR**: lines 1113–1119 against 376–381.
   - **Why it is wrong:** the graph build sets `RemoteGears` from a finite, positive redline, but the per-tick check compares it with `gear ~= nil`. If GearForSpeed ever returns a gear and rpm with a bad redline, `ForceRefresh` fires every 2 s forever.
   - **Fix:** capture `local gear, rpm, redline = gearForSpeed(...)`. Then set `local geared = gear ~= nil and (finiteNumber(redline) or 0) > 0`, compare `geared ~= graph.RemoteGears`, and set `engineRpm = rpm` only when `graph.RemoteGears and geared`.

5. **MINOR**: `rpmRev` at line 254, and config.py line 25 (`RevRpmMax` 8600).
   - **Why it is wrong:** this duplicates the physics limiter. If Oscar tunes `Drivetrain.exotic@LimiterRpm`, which is the gearing tuning he asked for, the audio mapping does not follow: the top of the range flattens or never reaches the top loop. A later class needs the same matching edit by hand.
   - **Fix:** add a `RevRpmMaxFromCar = { 1, 0, 1 }` switch. When it is on, use `FeelLimiterRpm` for the local car or GearForSpeed's 4th return for other cars as the top, falling back to `RevRpmMax`. The output is the same at today's defaults.

6. **MINOR**: lines 1215–1216.
   - **Why it is wrong:** `FeelSpin` raises `slipIntensity`, and that also drives the existing 6 dB engine duck. `SpinStrainGain` is the only knob for both, so making the spin groan louder also buries the free-revving engine (NOTES risk 6). That goes against the request for separate, easy-to-tune values.
   - **Fix:** compute `spinIntensity = math.clamp((spin or 0) * tuning.SpinStrainGain, 0, 1)`. Use `max(slipIntensity, spinIntensity * tuning.SpinDuckScale)` for `duckTarget` before merging into `slipIntensity`, and add `SpinDuckScale = { 1, 0, 1 }` with its `_RaisingThisDoes` string.

7. **MINOR**: line 1338, and config.py line 109 (`ReactorGain`).
   - **Why it is wrong:**
     - While `ReactorEnabled` is 1, the live `TurboWhistleGain` (0.08) and `TurboWhistlePitchMin/Max` (0.5/1.85) are silently ignored.
     - `ReactorEnabled` 0 does not silence the slot: it turns it into a spool whistle playing turbine_high.
   - **Fix:** state both in `ReactorGain_RaisingThisDoes`, `ReactorEnabled_RaisingThisDoes` and the NOTES config table. Alternatively, have `ReactorEnabled` 0 skip the TurboWhistle voice when the profile's slot was repurposed.

8. **MINOR**: lines 1186–1194 and 1003–1007, and config.py line 35 (`ShiftDropSeconds`).
   - **Why it is wrong:** `ShiftDropSeconds` only does anything when the landing prediction succeeds. With GearForSpeed missing, `landingGear ~= gear`, or `ShiftDropMaxSeconds` 0, it is a dead knob, but its text promises that it sets the upshift fall time.
   - **Fix:** either say "only with the landing prediction" in the text, or, when there is no prediction, still open the window with `f.DropRev = -1` and use `revSeconds = tuning.ShiftDropSeconds / 3` while `revTarget < f.Rev`.

9. **MINOR**: line 1009, and config.py `ShiftVentMinStrength`.
   - **Why it is wrong:** the audio crackle threshold and camerafx's `StabiliserVFX@ShiftVentMinStrength` are two separate knobs with the same name. Tuning one makes the vent flame and the crackle drift apart.
   - **Fix:** add a NOTES line saying to keep them equal. Better, read the StabiliserVFX value when the profile attribute is absent.

10. **MINOR**: config.py lines 151 and 153 (rows for existing attributes), together with `installer_engine.lua` lines 76–83.
    - **Why it is wrong:** the engine BLOCKs ROLLBACK and re-APPLY when an existing attribute is neither its before nor its after value, and `build.py` emits no `allowed` list. Two of the part's own instructions break this:
      - NOTES tells Oscar to "raise ProfileRevision" after tuning.
      - NOTES expects a later reactor_whine upload to replace `TurboWhistleAssetId`.
    - Saving either change in Edit makes the contract's ROLLBACK recovery BLOCK.
    - **Fix:** add a NOTES risk and integrator note: `build.py` should emit `allowed` for these two rows (any ProfileRevision of 37 or more, and any non-empty asset id). Until then, tune audio in Play only, or restore 37 and the turbine_high id before ROLLBACK.

Both after files compile in PR98 Edit (`VehicleAudioClient OK 89223`, `VehicleAudioCatalog OK 15304`). Live `EXOTIC_V10_AUDIO` confirms `ProfileRevision` is 36 and `TurboWhistleAssetId` is "", and no new key collides with an existing attribute.

Verdict: READY WITH FIXES