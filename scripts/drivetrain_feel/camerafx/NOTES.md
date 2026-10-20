# camerafx part: notes

The camerafx part covers CONTRACT sections 3.1 and 8. It owns `Vehicles.DrivingCameraClient` and `Vehicles.VehicleVFXClient`.

Status:
- Both after files are generated, revised after the adversarial review (see "Review fixes" below) and compile-checked in the PR98 Edit datamodel: `DrivingCameraClient: OK 46782 | VehicleVFXClient: OK 48963`.
- Nothing is installed, and nothing has been tested in Play.

| File | Before (chars / djb2) | After (chars / djb2) | Diff |
|---|---|---|---|
| `after/DrivingCameraClient.lua` | 38338 / 2387143006 | 46782 / 2821889795 | +151 / -8 lines |
| `after/VehicleVFXClient.lua` | 39741 / 2015947705 | 48963 / 3057451405 | +174 / -1 lines |

## Review fixes (adversarial review, READY WITH FIXES)

| # | Severity | Fix |
|---|---|---|
| 1 | MAJOR | `FeelGearing` reaching the camera and VFX is now an explicit interface requirement on physics (see "Requires from physics"), confirmed against `physics/after/VehicleDynamics.lua` `beginShift`. Comments at both consumers say so. The vent also needs a strength above 0, so dial 0 fires no vent even with `ShiftVentMinStrength` 0. New Play check added. |
| 2 | MINOR | The jets follow `FeelLoad` only in a forward gear (`FeelGear >= 1`). In R and N they keep `FeelThrottle`, so reversing never lights them. Physics does publish `FeelLoad = |throttle|` in R. |
| 3 | MINOR | The drivetrain release is floored at 0.08 s. While `FeelThrottle >= FeelThrottleCutoff` in a forward gear, a cut (or strain) only dims the jets to the cutoff, never to 0, so the limiter cannot toggle `Enabled` or `state.Accelerating`. String reworded. |
| 4 | MINOR | The spin yaw cap is the full `ChaseSpinYawRateMax` for as long as spin mode is active, ease-in included. It relaxes (÷ spin blend) only during the ease-out. |
| 5 | MINOR | The spin ease-out unwraps both the hold and the normal target against the moving camera yaw, so a car stopping near 180° can no longer flip the blend mid-ease. |
| 6 | MINOR | `SpinDustLevel` and `ThrustSlipDustLevel` are marked "no effect on Exotic V2". The count, ease-out, yaw-cap and pop-strength strings now match the code. |
| 7 | MINOR | New switch `DrivetrainThrustLoadEnabled` (1) on `StabiliserVFX`: thrust-follows-load on its own. |
| 8 | MINOR | No ground wash within 0.3 s of a landing burst (`feel.LastLandBurst`), so a wash can no longer cut a landing surge short. The rear over-glow gap stays: the integrator records it as an accepted deviation (risk 1). |
| 9 | MINOR | Not changed in code: `ChaseSpinEnterLevel` and `SpinStutterMinSpin` stay 0.2, as CONTRACT section 8 states. The integrator decides in the Play matrix (risk 5). |

Found while checking items 1 and 2 against the physics after-file: physics publishes `FeelSpinDirection` +1 for a clockwise (rightward) spin. The VFX had assumed +1 = left, so the stutter lead side is now the right side for +1.

## How "unchanged for other classes" is kept

Every new behaviour keys on Feel attributes that `DrivingClient` writes only while a class drivetrain runs. Today that means Exotic only.
- **Camera:** it checks `FeelGear`. A missing `FeelSpin` while `FeelGear` is present counts as 0.
- **VFX:** it checks `FeelLoad`.

For any other car, or with a switch at 0, every new term stays exactly 0 or is multiplied by exactly 1:
- the camera's nod, shift FOV, shimmer and spin weight;
- the VFX spin, slip and strain levels.

The camera and VFX output is therefore numerically the same as before. The only extra cost is one `GetAttribute` per frame in the camera (`FeelGear`) and one per 30 Hz VFX tick (`FeelLoad`).

## DrivingCameraClient (scripted chase only; the V6.1 `update` path is untouched)

**New module local `chaseCuts`.** It counts hard cuts (`resetChase`) after `Start`. Start resets it to 0.

**`resetChase`** adds these chase fields:
- `ShiftRevision` and `LimiterRevision`: baselines read like `ImpactRevision`.
- `SpinActive`, `SpinWeight`, `SpinHold`, `SpeedStuds`.
- `Nod` and `NodVelocity`: the new small critical spring.
- `ShiftFov` and `ShiftFovVelocity`: the FOV pulse spring.
- `LimiterTimer`, `Shimmer`.

**New `drivetrainFeel(vehicle, enabled, spin, gear, dt, horizontal, speedStuds)`**, called right after `chaseEvents`.

*Spin mode*
- It enters when `FeelSpin > ChaseSpinEnterLevel` (0.2) and leaves when `FeelSpin <= ChaseSpinExitLevel` (0.1). The hysteresis stops flicker on the 0.05 quantisation.
- On entry, `SpinHold` = the camera's current yaw, so the heading held is the one at spin onset.
- `SpinWeight` ramps up over `ChaseSpinEaseInSeconds` and down over `ChaseSpinEaseOutSeconds` (linear). It is blended through smoothstep as `spinBlend`.
- While the weight is above 0, the hold turns toward the travel direction only above `ChaseSpinTravelMinStuds` (12 studs/s), fading in over `ChaseSpinTravelFadeStuds`, at `ChaseSpinTravelResponse`.

*Shift events (baseline-first)*
- `FeelShiftStrength` already carries the class `FeelGearing` dial (see "Requires from physics"), so the camera does not read the dial itself.
- `Up` with `FeelThrottle >= ChaseShiftMinThrottle` kicks both new springs, sized so each peaks at its configured value (velocity = peak × ω × e):
  - a nod of −`ChaseShiftNodDegrees` × strength × `ChaseShakeScale`, as a pitch down;
  - an FOV pulse of `ChaseShiftFovDegrees` × strength.
- `Down` does nothing, so braking and coasting downshifts never nod.
- `Launch` adds `ChaseLaunchKickStudsPerSecond` × strength to the existing Lag spring. This follows the draft: "Launch kicks the lag spring".

*Limiter (baseline-first on `FeelLimiterRevision`)*
- Each bounce in a gear other than N arms `LimiterTimer` = `ChaseLimiterHoldSeconds`. The shimmer level eases toward 1 while the timer runs.
- A shift cut does not move `FeelLimiterRevision`, so the shimmer is on the limiter only. Neutral (the countdown revs) has no shimmer, per critique_experience item 17.

`ChaseDrivetrainEnabled` 0 zeroes every term at once and clears the baselines.

**Changes in `updateChase`**
- **Cut test.** `rawDt` is kept before the dt clamp. While spinning (`FeelSpin > 0` or the spin weight is above 0), the heading-jump test uses `8·max(rawDt, dt)`:
  - A spin turns the car at most `YawRateMax` ≤ 5 rad/s, which is under the 8 rad/s cut rate. So a hitch mid-spin can no longer read as a teleport.
  - The 60-stud distance cut is unchanged.
  - Each cut does `chaseCuts += 1`, and so does the non-finite recovery reset.
- **Yaw.** In spin mode the target blends from the normal target to `SpinHold` by `spinBlend`. Both ends are first unwrapped against the current camera yaw, so the blend cannot flip sides when the car ends near 180° from the hold. The camera's per-frame yaw step and `YawVelocity` are capped:
  - at `ChaseSpinYawRateMax` (1.5 rad/s) while spin mode is active, from the first spin frame;
  - at `ChaseSpinYawRateMax / max(spinBlend, 0.02)` during the ease-out, so the cap relaxes as the view returns behind the car.
- **Turn terms.** Look-ahead, turn and slip roll, and the drift side shift are multiplied by `turnFollow = 1 − spinBlend`, so the held view does not lean or swing with the rotating car. This is exactly 1 outside spin mode.
- **Lag.** In spin mode the raw acceleration blends to the derivative of speed magnitude (`chase.SpeedStuds`) by `spinBlend` (critique_physics item 19).
- **FOV.** `fov = clamp(currentFov + chase.Punch + chase.ShiftFov, 40, 120)`, then `CameraService.SetFieldOfView("DrivingCamera", fov, 100)` as before. FOV goes only through CameraService.
- **Pose.** `CFrame.Angles(chase.KickPitch + chase.Nod, 0, chase.KickRoll + buffetRoll + chase.Roll + shimmer)`. The shimmer is `Shimmer · rad(ChaseLimiterShimmerDegrees) · ChaseShakeScale · sin(2π·ChaseLimiterShimmerHz·t)`.

**`publishDebug` and `clearDebug`** also write and clear `CameraChaseCuts` and `CameraSpinWeight`. This happens only while `Camera@DebugEnabled` is true; live it is currently true.

## VehicleVFXClient (the local driving car only; previews and remote cars untouched)

**`FEEL_DEFAULTS`** gains the 26 numbers below. They are read by the existing `refreshFeelConfig` (every 0.5 s, type-checked). One new module constant, `DRIVETRAIN_WASH_LAND_GAP` (0.3 s).

**New local `smoothstep`.**

**New `drivetrainInputs(model, feel, load, neutral, dt)`**, called from `feelInputs` after the throttle block. It updates these levels on the existing per-vehicle feel memory:
- `SpinLevel`: smoothstep of `FeelSpin`, released over `SpinFadeSeconds`.
- `SlipLevel`: from `FeelThrustSlip`.
- `StrainLevel`: from `FeelRpm/FeelRedlineRpm` above `StrainRpmStart`, or `StrainOverdriveLevel` while `FeelOverdrive`. There is no strain in neutral.
- `SpinPhase` and `SpinLead`. `FeelSpinDirection` is read once at onset: +1 (a clockwise, rightward spin, as physics publishes it) makes the right side lead.
- `WashTimer`.
- `VentPending`: on a `FeelShiftRevision` increase (baseline-first) with kind `Up`, `FeelShiftStrength > 0` and `FeelShiftStrength >= ShiftVentMinStrength`.

Without a drivetrain every level stays exactly 0.

**Changes in `feelInputs`**
- **Thrust.** In a forward gear (`FeelGear >= 1`) it follows `FeelLoad` when present (`DrivetrainVFXEnabled` 1 and `DrivetrainThrustLoadEnabled` 1), with its own release `max(DrivetrainThrustReleaseSeconds, 0.08)`, so cuts dip the jets. Otherwise `FeelThrottle` is used as before.
  - In gear N it keeps `FeelThrottle`, so the neutral limiter does not flicker the jets.
  - In gear R it keeps `FeelThrottle` (negative, so clamped to 0), so reversing never lights the jets, although physics publishes `FeelLoad = |throttle|` there.
- **Strain.** It scales the thrust by `1 − StrainJitter·StrainLevel·noise`: dimmer only.
- **Cut floor.** In a forward gear on load, while `FeelThrottle >= FeelThrottleCutoff`, the output is at least `FeelThrottleCutoff` (0.1). A shift cut, the limiter or strain therefore dims the jets but never switches them off: no `Enabled` toggling of the V2 `EngineThrust` objects (on at > 0.05) and no `state.Accelerating` flip of the by-name EngineOn/EngineOff objects.
- **Spin stutter.** Both stabiliser (drift) jet sides pulse in antiphase at `SpinStutterHz`. Each side moves between `SpinStutterFloor` and 1 of `SpinJetLevel × SpinLevel`. The depth fades in between spin levels 0.15 and 0.4, and a side never drops under 0.06 mid-spin.
  - This keeps it a brightness pulse: no on/off flashing, no repeated `DriftStart` bursts, and no `Enabled` toggling of the by-name stabiliser objects.
  - It uses `max` with the drift-button value, so a real drift is never reduced.
- **Dust.** Hover dust is raised to `SpinDustLevel·SpinLevel` and `ThrustSlipDustLevel·SlipLevel` while grounded. This only affects templates driven by the `HoverDust` group. It has **no effect on Exotic V2 cars**: live `VehiclePreviewVFXClient.updateV2` (lines 1474-1483) computes their ground dust from `ExoticV2Dust*` whenever a Feel table is passed. On Exotic V2 the spin and slip dust comes only from the wash bursts below. `feel.OnGround` is stored for the bursts.

**New `drivetrainBursts(cache, feel, hiddenByRace)`**, called right after `feelBursts`. It respects the race-hidden rule and creates nothing.
- **Vent flame.**
  - Call: `controller:Backfire(ShiftVentCount·strength, ShiftVentFlashSeconds, ShiftVentFlashGain, ShiftVentPopStrength·strength)`, made directly through `pcall`, never through `FeelPopRevision`.
  - Exotic V2 result: Backfire puffs, plus a `V2BoostLight` pop flash. The BackfireBang tongue needs `ShiftVentPopStrength × strength >= 0.8`, so there is none at the default 0.6.
- **Ground wash and over-glow.**
  - While the spin or slip level is up, it fires `controller:Burst("Dust", count)` at most every `SpinDustBurstSeconds` or `ThrustSlipWashSeconds`. The count is `SpinDustBurstCount·SpinLevel` or `ThrustSlipWashCount·SlipLevel`.
  - On Exotic V2 that emits the ground mist and sets the controller's `LandPulse` to `clamp(count/28, 0.3, 1)`, which surges the hover jets under the engines. For counts up to about 8 that is a fixed 0.3, so the burst counts tune the particles, not the surge size. That surge stands in for the thrust-slip over-glow (see risk 1).
  - `Burst` assigns `LandPulse` rather than raising it, so no wash fires within `DRIVETRAIN_WASH_LAND_GAP` (0.3 s) of a landing burst (`feel.LastLandBurst`). A full landing surge (τ 0.25 s) has decayed to 0.3 by then, so a wash can no longer cut it short.

## Config (`config.py`)

There are no new instances. There are 92 attribute rows: 46 numbers, each with a `<Name>_RaisingThisDoes` string. Every default equals the code fallback, which a script verified, so a removed row behaves the same. No key collides with a live attribute; this was checked against `before/config.json`.

**`Config.Vehicles.Camera`**

| Attribute | Default | Meaning |
|---|---|---|
| `ChaseDrivetrainEnabled` | 1 | Master switch for all camera drivetrain cues. 0 gives exactly the old camera. |
| `ChaseSpinModeEnabled` | 1 | Spin hold on (1) or off (0). |
| `ChaseSpinEnterLevel` | 0.2 | `FeelSpin` above which spin mode starts. |
| `ChaseSpinExitLevel` | 0.1 | `FeelSpin` at or below which spin mode ends (hysteresis). |
| `ChaseSpinEaseInSeconds` | 0.15 | Blend time into the held view. |
| `ChaseSpinEaseOutSeconds` | 0.8 | Blend time back to behind the car after a spin. The yaw-rate cap relaxes over this time. |
| `ChaseSpinTravelMinStuds` | 12 | Speed (studs/s) above which the held view follows travel. |
| `ChaseSpinTravelFadeStuds` | 6 | Speed band over which travel-following fades in. |
| `ChaseSpinTravelResponse` | 3 | Rate (1/s) at which the hold turns toward travel. |
| `ChaseSpinYawRateMax` | 1.5 | Camera yaw-rate cap (rad/s) from the first spin frame until the ease-out begins. |
| `ChaseShiftMinThrottle` | 0.5 | Throttle needed for an upshift to nod and pulse ("under load"). |
| `ChaseShiftNodDegrees` | 1.0 | Peak nod (pitch down) at shift strength 1. |
| `ChaseShiftNodOmega` | 9 | Nod spring speed. |
| `ChaseShiftFovDegrees` | 1.2 | Peak FOV pulse at strength 1. + widens, − narrows. |
| `ChaseShiftFovOmega` | 10 | FOV pulse spring speed. |
| `ChaseLaunchKickStudsPerSecond` | 6 | Lag-spring pull-back on a `Launch` shift. |
| `ChaseLimiterShimmerDegrees` | 0.08 | Limiter roll-buzz amplitude. |
| `ChaseLimiterShimmerHz` | 12 | Limiter buzz frequency. |
| `ChaseLimiterHoldSeconds` | 0.15 | Buzz time after each limiter bounce. |
| `ChaseLimiterShimmerResponse` | 20 | Buzz fade-in and fade-out rate. |

**`Config.Vehicles.StabiliserVFX`**

| Attribute | Default | Meaning |
|---|---|---|
| `DrivetrainVFXEnabled` | 1 | Master switch for all drivetrain VFX. 0 gives exactly the old effects. |
| `DrivetrainThrustLoadEnabled` | 1 | Thrust jets follow `FeelLoad` in a forward gear (1), or the raw throttle as before (0). The other drivetrain effects stay on. |
| `DrivetrainThrustReleaseSeconds` | 0.15 | Jet fade time when `FeelLoad` drops (cuts, lifts). Floored at 0.08 s. |
| `ShiftVentMinStrength` | 0.7 | Upshift strength needed for a vent flame. The strength already includes `FeelGearing`, and it must be above 0. |
| `ShiftVentCount` | 10 | Vent burst particles at strength 1. 0 turns the vent off. |
| `ShiftVentPopStrength` | 0.6 | Backfire strength at shift strength 1; it is multiplied by the strength. The flame tongue needs `PopStrength × strength >= 0.8`. |
| `ShiftVentFlashSeconds` | 0.08 | Vent flash length. |
| `ShiftVentFlashGain` | 1.4 | Vent flash brightness on non-V2 cars. |
| `SpinStutterHz` | 9 | Stabiliser alternation rate in a spin. |
| `SpinStutterMinSpin` | 0.2 | `FeelSpin` where spin effects start. |
| `SpinStutterFullSpin` | 0.6 | `FeelSpin` where they reach full strength. |
| `SpinStutterFloor` | 0.45 | Dim phase of each jet (1 = no pulse). |
| `SpinJetLevel` | 1 | Stabiliser jet strength in a full spin. |
| `SpinFadeSeconds` | 0.25 | Linger of the spin effects after the spin. |
| `SpinDustLevel` | 0.6 | Extra hover dust in a full spin (HoverDust templates). No effect on Exotic V2 cars. |
| `SpinDustBurstSeconds` | 0.25 | Interval between spin ground-wash bursts. |
| `SpinDustBurstCount` | 5 | Ground-wash burst particles in a full spin. The V2 hover-jet surge is the same for any count up to about 8. |
| `ThrustSlipMin` | 0.1 | `FeelThrustSlip` where the launch effects start. |
| `ThrustSlipFull` | 0.6 | `FeelThrustSlip` where they reach full strength. |
| `ThrustSlipDustLevel` | 0.5 | Extra hover dust at full slip (HoverDust templates). No effect on Exotic V2 cars. |
| `ThrustSlipWashSeconds` | 0.2 | Interval between slip ground-wash bursts. |
| `ThrustSlipWashCount` | 5 | Slip ground-wash particles at full slip. The V2 hover-jet surge is the same for any count up to about 8. |
| `StrainRpmStart` | 0.96 | Fraction of redline rpm where jet strain starts. |
| `StrainOverdriveLevel` | 0.6 | Strain level while `FeelOverdrive`. |
| `StrainJitter` | 0.12 | Thrust share removed at full strain (capped at 0.5). |
| `StrainHz` | 16 | Strain flutter speed. |

**Feel tuning that lives elsewhere.** The "weight / gearing / spin" dials are in `Drivetrain.exotic` (physics). The camera and VFX read `FeelShiftStrength`, not `FeelGearing` (contract section 8). Physics owns the dial and the class lookup (`CategoryId`, else the `CockpitId` prefix), so camerafx does not repeat that lookup.
- `FeelGearing` 0..1 scales the nod, the FOV pulse and the vent through the published strength.
- Above 1 the dial does not grow these cues, because the strength is capped at 1. For bigger cues raise `ChaseShiftNodDegrees`, `ChaseShiftFovDegrees` or `ShiftVentCount`.
- A `Launch` kick (`ChaseLaunchKickStudsPerSecond`) is not scaled by the dial. Physics leaves Launch strengths unscaled, and the kick is a launch cue, not a gear cue.

## Requires from physics (interface requirements)

The integrator re-confirms these against the final physics after-files. Each one was confirmed against `physics/after/*.lua` as they stood on 2026-10-20, at the time of this fix.

| Requirement | Why camerafx depends on it | Confirmed at |
|---|---|---|
| `FeelShiftStrength = baseStrength × clamp(FeelGearing, 0, 1)` for `Up` and `Down`, so it is 0 when the dial is 0. | CONTRACT 4.1: dial 0 must give no camera nod, no FOV pulse and no vent. | `VehicleDynamics.lua` `beginShift`: `strength *= math.min(tuning.FeelGearing, 1)` for kinds other than Launch. The dial is clamped to 0..2 at its config read. |
| `FeelShiftKind` and `FeelShiftStrength` are written before `FeelShiftRevision` in the same frame. | Both consumers read kind and strength when they see the new revision. | `DrivingClient.lua`, publish block ("Kind and strength first"). |
| `FeelGear` is −1 in R, 0 in N, and 1 or more forward. `FeelLoad` is `|throttle|` in R. | The jets follow load only in a forward gear (review item 2). | `VehicleDynamics.lua` `StepDrivetrain`: `gear = -1` in Reverse, and `load = math.abs(throttle)` in Reverse. |
| `FeelSpinDirection` is +1 for a clockwise (rightward) spin. | Sets which stabiliser side leads the stutter. This is cosmetic only. | `DrivingClient.lua`: `-spin.Dir`, with the comment "+1 = a clockwise (rightward) spin". |
| `FeelGear` and `FeelLoad` exist only while the drivetrain is active, and are cleared on Stop. | Drivetrain detection; other classes stay byte-for-byte as before. | `DrivingClient.lua` `DRIVETRAIN_FEEL_ATTRIBUTES` and the clear list. |

## Preserved

- The V6.1 camera mode (`update`), entry blend, occlusion, free look, speed lines and boost punch are unchanged.
- The heading cut keeps its old threshold whenever the car is not spinning, and the distance cut is unchanged.
- FOV goes only through `CameraService.SetFieldOfView("DrivingCamera", fov, 100)`.
- `Controller.Start/Stop` signatures, suspend and resume, and trailer keys are unchanged.
- The VFX template controller API is used as is: `Update`, `Burst`, `Backfire`. `VehiclePreviewVFXClient` is not edited.
- The pop and backfire path (`FeelPopRevision`) is untouched; the vent flame is independent of it.
- Remote cars, previews and race visibility are unchanged:
  - `feelInputs` still returns nil for them;
  - drivetrain bursts honour `hiddenByRace`.
- **No new connections, remotes, instances or startup paths.** No per-frame allocation either: no tables or closures per frame, and event calls use `pcall(method, controller, ...)`.
- **Attribute reads per frame:**
  - camera: 1 for other cars, 4 for drivetrain cars;
  - VFX, per 30 Hz tick: 1 for other cars (`FeelLoad`), 8 for drivetrain cars, on the existing `feelNumber` pattern.
- The switches are numbers. The camera `flag()` and the VFX type check would ignore a configured false.

## Test hooks

- **Camera.** With `Camera@DebugEnabled` true (live), `Workspace.CurrentCamera` carries:
  - `CameraChaseCuts`: hard cuts since Start. Expect no change across a spin; this is the "zero `resetChase`" check.
  - `CameraSpinWeight`: 0..1. It rises above 0 within about 0.15 s of `FeelSpin > 0.2`, and returns to 0 about 0.8 s after the spin ends.
- **Per-frame heading check.** Log the camera yaw against the car heading during a spin. The camera yaw rate should stay at or below about 1.5 rad/s while `CameraSpinWeight` is 1.
- **Injection in the Client datamodel** (Play, read-mostly; the integrator decides). `DrivingClient` writes Feel attributes only on change, so a value set by hand on the local Exotic persists until the physics value changes. With a drivetrain car parked:
  - set `FeelSpin` to 0.8 to see the camera hold and the stabiliser stutter;
  - set `FeelThrustSlip` to 0.8 to see the ground wash and hover-jet surge;
  - set `FeelShiftKind` to "Up", `FeelShiftStrength` to 1 and `FeelThrottle` to 1, then increment `FeelShiftRevision`, to see the nod, FOV pulse and vent flame;
  - increment `FeelLimiterRevision` with `FeelGear` at 3 to see the shimmer;
  - set `FeelOverdrive` to 1 to see the jet strain.
- **Play checks added by the review fixes** (local Exotic, drivetrain on):
  - **Gearing dial 0.** Set `Drivetrain.exotic@FeelGearing` to 0 and drive flat out through the gears. Expect no camera nod, no FOV pulse (`CameraCurrentFov` flat at each shift) and no vent flame. Physics should publish `FeelShiftStrength` 0 for every `Up`.
  - **Reverse.** Hold S until R engages and keep reversing. The rear thrust jets stay off, as before install.
  - **Limiter.** Hold W in 2nd on the limiter. The jets dim and pulse but never switch off: the V2 `EngineThrust` objects stay `Enabled`, and the EngineOn/EngineOff by-name objects do not swap. Repeat with `DrivetrainThrustReleaseSeconds` 0, which acts as 0.08.
  - **Thrust-load switch.** With `DrivetrainThrustLoadEnabled` 0 the jets follow the raw throttle, with no dip on cuts. The vent, stutter, wash and strain still work.
  - **Spin onset.** The per-frame camera yaw rate is at or below `ChaseSpinYawRateMax` from the first frame where `CameraSpinWeight > 0` while `FeelSpin > ChaseSpinEnterLevel`.
- **Parity.**
  - With `ChaseDrivetrainEnabled` 0 and `DrivetrainVFXEnabled` 0, or on a non-Exotic car, the outputs must match before-install.
  - Compare `CameraCurrentFov` and the camera CFrame over a scripted straight run.
- **VFX inspection.** Inspect the local Exotic V2 drift thruster beams (groups `DriftLeft` and `DriftRight`) in Play: `Enabled` stays true through a spin while the widths and brightness pulse.

## Open risks

1. **The thrust-slip "rear over-glow" is approximate on Exotic V2: an accepted deviation for the integrator to record.**
   - `VehiclePreviewVFXClient.updateV2` clamps the engine channel to throttle ≤ 1. That file belongs to no part in this delivery.
   - So CONTRACT 8's "rear over-glow on `FeelThrustSlip`" ships as the hover-jet surge (`LandPulse` 0.3, under every engine) plus the ground wash from small Dust bursts.
   - **Integrator:** record this as an accepted deviation in `verification.json` or the contract.
   - A true engine over-glow above 1 needs a `VehiclePreviewVFXClient` change in a later delivery.
2. **Dust-burst size.**
   - V2 Dust bursts above a count of about 6 also emit the landing shock ring (`BurstShare` 0.08). The exact threshold depends on `DesktopParticleScale`.
   - Defaults are 5. Raise `SpinDustBurstCount` or `ThrustSlipWashCount` with care. On V2 the counts change the particles only; the surge stays 0.3.
3. **Drivetrain detection and the shift-strength dial depend on physics.**
   - The camera needs `FeelGear`, and the VFX needs `FeelLoad`, written when the drivetrain activates and cleared in `Stop`. Contract 3.1 says they are.
   - If physics wrote `FeelSpin` before `FeelGear`, the spin camera would wait for `FeelGear`.
   - Each line of "Requires from physics" must still hold in the final physics after-files. If the physics fixer drops the `FeelGearing` factor from `beginShift`, `FeelGearing` 0 would again nod, pulse and vent. The Play check "Gearing dial 0" catches that.
4. **Spin direction sign.** `FeelSpinDirection` +1 is a clockwise (rightward) spin, as the physics after-file publishes it; the right side then leads the stutter. If physics flips the convention, only the lead side changes, so the risk is cosmetic.
5. **Spin mode also catches wiggles (review item 9: the integrator decides in the Play matrix).**
   - Spin mode at `FeelSpin > 0.2` (the contract value) also catches the no-gesture wiggle, which can reach `SpinHoldCap` 0.35. The camera then holds briefly during a catchable wiggle, for example a W+lock U-turn. The stabiliser stutter starts at the same level.
   - **Decision rule:** if the wiggle shows in Play, set `ChaseSpinEnterLevel` and `SpinStutterMinSpin` to 0.4, just above `SpinHoldCap`, to reserve both for gesture spins. Keep 0.2 only if held turns stay under 0.2. These are config values only, with no code change.
6. **Ease-out near 180° (fixed).** The blend now unwraps the hold and the normal target against the moving camera yaw. Once the camera starts turning one way, the wrap point moves away from it, so a car stopping near 180° can no longer flip the side mid-ease. A residual flip is possible only in the first frame of an ease-out that starts exactly 180° away. That is a one-frame direction choice, not a reversal.
7. **Cut floor on mobile.** The cut floor holds the jet input at `FeelThrottleCutoff` (0.1). On mobile, a template's `MobileScale` of 0.5 or less puts that level at the 0.05 enable threshold, the same as today's steady throttle at the cutoff. Desktop is clear: 0.1, or 0.06 during the V2 boost intake, is above 0.05.
8. **Relaxed heading cut while spinning.** While spinning, the heading cut is relaxed to the real frame time. A pure rotation with no position change during a spin would blend instead of cutting. `ResetVehicle` re-orients from `YawHeading`, and teleports move far more than 60 studs, so neither is expected.
9. **Neutral jets follow `FeelThrottle`.** In N the jets follow `FeelThrottle`. Whatever `DrivingClient` publishes there while anchored decides whether the grid shows jet flare. Today it is zeroed, which means no flare.
10. **Live `Camera@DebugEnabled` is true.** That adds 2 more debug attribute writes per frame. Switch it off before publish (critique_delivery item 16).
11. **Classic declared set.** Both scripts are in the Classic manifest. The integrator must declare the after-hashes above in the Classic declared set.
