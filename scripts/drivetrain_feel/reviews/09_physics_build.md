I built the physics part: the after-files for DrivingClient and VehicleDynamics, `config.py` and `NOTES.md`, all in `scripts\drivetrain_feel\physics\`. Both files pass the Studio Edit compile check. Nothing was installed and nothing was driven in Play, so none of this is tested in-game.

**Compile check** (CONTRACT §2 loadstring through the 8797 bridge, final bytes):
- `DrivingClient`: `OK 101808`
- `VehicleDynamics`: `OK 69632`

**What changed**
- **Old behaviour when inactive.** With no class folder, or either `Enabled` at 0, every new branch is skipped and the old lines run with the same values. `refreshInput` still returns the old steering sum, the step gets a nil `Drivetrain` field, and the HUD gets the old two-argument `PublishMobile` call.
- **VehicleDynamics**
  - The class comes from `CategoryId`, falling back to the `CockpitId` prefix. I confirmed in Studio that spawned cars carry both (`"exotic"`, `"exotic_01"`) and `PerformanceIndex`.
  - The class folder is re-read about 4 times a second with change detection; the ratio and torque strings are parsed only when their text changes.
  - `DrivetrainProfile` is cached per car and rebuilt only on change.
  - `StepLongitudinal` branches to the new gearbox step only when a drivetrain is passed in. All nine required fixes from §5.2 are in.
  - `StepNeutral` handles neutral revs while anchored; `GearForSpeed` gives remote cars a gear and rpm with no attribute writes and no per-call allocation.
  - `ResolveStats` gained an optional `quiet` flag and `StepHandling` two extra result fields; existing callers are unaffected.
- **DrivingClient**
  - Keyboard and touch steering build up at a rate; the gamepad is untouched, and the bank and counter-steer still use the raw input.
  - The car now turns through a yaw rate with inertia, slows to today's direct steering below 15 mph, and is capped by grip.
  - Grip saturates and builds up after a slide starts, but drifts keep today's grip.
  - Pitch now comes from acceleration, plus a small body roll.
  - Spins come from a quick throttle stab or a W+S power-brake release, with catch, start grace and warning. Spin direction is published as +1 for clockwise.
  - Every reset site listed in §5.5 is covered.
  - The 16 new Feel attributes are written only on change and added to the clear list.
  - The telemetry table is preallocated and passed as `PublishMobile`'s third argument.
- **Config.** One `Drivetrain` folder (`Enabled`, `DrivetrainFeelInstalled`, `Notes`) with an `exotic` child carrying every §4 attribute, each with its `_RaisingThisDoes` string. I checked that the names and defaults match the code's fallbacks exactly and that every §4 name is present. `NOTES.md` has the exact mapping for each Feel dial.

**Quick check of my own.** I ran a throwaway Python port of the step on the six stock Exotics (generated numbers, not measured; the model part is the authority):
- Top speed and boosted top speed come out exactly at today's values.
- The S car does 0-100 in 3.9 s and is 89 mph two seconds after lifting at 100 mph.
- Tapping W to hold 40 mph for 10 s causes 0 shifts.

**Additions not in the contract**
- `SpinYawAuthorityLoss` (0.85, from the draft). Without it, the steering spring cancels the spin push.
- A downshift when lugging below 0.2 of redline under throttle.
- Shift strength is multiplied by `FeelGearing`, so gearing 0 mutes the camera nod, vent flame and crackle.
- The spin yaw-gate constants are fixed in code.

**Things the integrator should know**
- **Spin grace is implemented literally ("whichever is later").** After spawning, pressing R or any input-gate lock, the car won't spin until it has gone faster than 38 mph and 3 s have passed. Setting `SpinStartGraceMph` to 0 makes it time-only.
- **Touch players can't do the power-brake.** `GetMobileInput` only returns the summed throttle, so both pedals read as 0; they get the stab gesture only.
- **Stock Exotics mostly spin from the power-brake.** Traction assist keeps launch wheelspin near the spin threshold, so a plain stab gives at most a small wiggle.
- **High-speed cornering is reduced.** Full-lock yaw on the S car at 120 mph is about 0.73 rad/s (understeer at the limit).
- **The roll sign needs checking in Play.** It leans out of the turn; a negative `RollDegreesPerG` flips it.
- **Dynamics config edits made during Play** don't rebuild the profile until PI, stats or the class tuning change, or the car is re-entered. Class-folder edits do apply live.
- **Debug attributes:** I added about 15 more, written only on change. `Dynamics@DebugAttributes` is on in PR98 and should be switched off before publish.
- **Remote cars:** audio requiring `VehicleDynamics` for `GearForSpeed` is a new dependency. That the stats folders replicate to other clients is assumed, not checked.

Files are in `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\physics\`:
- `after\DrivingClient.lua`
- `after\VehicleDynamics.lua`
- `config.py`
- `NOTES.md`