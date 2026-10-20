camerafx fixes are done: all 1 MAJOR and 8 MINOR review items are handled (7 in code, 2 left to the integrator by design), and both after files pass the compile check in PR98 Edit. Nothing is installed and nothing has been tested in Play.

**Items fixed**
1. **MAJOR, `FeelGearing` reaching the camera and VFX.** I used option (a). The physics after files exist now, so I checked them: `physics/after/VehicleDynamics.lua` `beginShift` does `strength *= math.min(tuning.FeelGearing, 1)` for Up and Down shifts. So dial 0 gives strength 0, which means no nod and no FOV pulse. In NOTES:
   - a new "Requires from physics" table records this as an interface requirement, with where each line was confirmed;
   - the integrator must re-confirm it against the final physics files.

   In code:
   - comments at both consumers say the strength already carries the dial;
   - the vent now also needs `strength > 0`, so dial 0 fires no vent even if `ShiftVentMinStrength` is 0;
   - a "Gearing dial 0" Play check is added.

   I chose (a) over (b) for two reasons. With (b) the dial would be applied twice (the effect at 0.5 would be 0.25). It would also copy physics' class lookup (CategoryId, with a CockpitId-prefix fallback) into a second place.
2. **Reverse lights the jets.** Physics does publish `FeelLoad = |throttle|` in reverse. The jets now follow load only when `FeelGear >= 1`, using the gate the review gave.
3. **Jets toggling on cuts.**
   - The release time now has a floor: `math.max(DrivetrainThrustReleaseSeconds, 0.08)`.
   - While the throttle is held at or above `FeelThrottleCutoff` in a forward gear, the jet output never drops below the cutoff. I apply this after the strain shake rather than where the review placed it, so strain cannot push the jets under the on-threshold either.
   - The config string is reworded.
4. **Yaw cap at spin onset.** The cap is the full `ChaseSpinYawRateMax` while spin mode is active, using the review's line. It relaxes only during the ease-out.
5. **Ease-out flip near 180°.** Both ends of the blend are now unwrapped against the moving camera yaw, as the review suggested.
6. **Config strings.**
   - `SpinDustLevel` and `ThrustSlipDustLevel` are marked "no effect on Exotic V2". I checked live `VehiclePreviewVFXClient` lines 1474-1483 to confirm.
   - The burst-count strings now say the V2 hover-jet surge is the same whatever the count (code sets `LandPulse = clamp(count/28, 0.3, 1)`).
   - The `ChaseSpinEaseOutSeconds`, `ChaseSpinYawRateMax` and `ShiftVentPopStrength` strings now match the code.
7. **Separate switch for thrust-follows-load.** New `DrivetrainThrustLoadEnabled = 1` is in `FEEL_DEFAULTS` and in `config.py` with its `_RaisingThisDoes` string, and it gates the load-follow path.
8. **Wash cutting a landing surge short.** No ground wash fires within 0.3 s of a landing burst (new constant `DRIVETRAIN_WASH_LAND_GAP`, using `feel.LastLandBurst`). A full landing surge (decay time 0.25 s, from the live module) has fallen to 0.3 by then. The over-glow gap is in NOTES risk 1 for the integrator to record as an accepted deviation.

**Extra fix, not in the review:** physics publishes `FeelSpinDirection` +1 for a clockwise (rightward) spin, but the VFX assumed +1 meant left. The stutter's lead side now matches physics. This only changes which stabiliser side pulses first.

**Items not changed in code**
- **Item 8, over-glow gap:** the remaining fix is a recording task for the integrator (`verification.json` or the contract), which is outside my folder.
- **Item 9, spin mode catching the wiggle:** CONTRACT section 8 fixes the spin-mode level at 0.2, and the review leaves the choice to the integrator's Play matrix. NOTES risk 5 now gives the rule: set `ChaseSpinEnterLevel` and `SpinStutterMinSpin` to 0.4 if the wiggle shows in Play. That is a config change only.

**Final state**
- `config.py` has 92 attribute rows (46 numbers, each with its string). A script confirmed every default matches its code fallback. The new key does not collide with anything in `before/config.json`.
- Compile check in PR98 Edit: `DrivingCameraClient: OK 46782 | VehicleVFXClient: OK 48963`.

| File | Chars | djb2 | Diff vs before |
|---|---|---|---|
| `DrivingCameraClient` | 46782 | 2821889795 | +151 / -8 lines |
| `VehicleVFXClient` | 48963 | 3057451405 | +174 / -1 lines |

Files changed:
- C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\camerafx\after\DrivingCameraClient.lua
- C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\camerafx\after\VehicleVFXClient.lua
- C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\camerafx\config.py
- C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\camerafx\NOTES.md