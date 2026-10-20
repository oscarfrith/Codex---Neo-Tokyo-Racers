The camerafx part is built, and both after files pass the CONTRACT section 2 compile check in PR98 Edit: `DrivingCameraClient: OK 46274 | VehicleVFXClient: OK 47621`. Nothing was written to Studio and nothing has been run in Play.

For any car without a class drivetrain, or with either switch at 0, every new term is exactly 0 or ×1, so the camera and VFX output is numerically the same as before. The camera detects a drivetrain car by `FeelGear`; the VFX detects it by `FeelLoad`.

**DrivingCameraClient**
- **Spin mode:**
  - It turns on when `FeelSpin > 0.2` and off at `≤ 0.1`.
  - It holds the camera direction from the moment the spin starts, and follows the travel direction only above 12 studs/s.
  - The camera's turn rate is capped at 1.5 rad/s, and the cap relaxes as the spin eases out over 0.8 s.
  - The Lag spring uses the change in speed magnitude instead of forward speed.
  - Look-ahead, roll and side shift fade out while the view is held.
- **No hard cut during a spin:** while spinning, the heading-jump test uses the real frame time, so a slow or hitching frame cannot read as a teleport. The distance cut is unchanged.
- **Shift nod:** a new small critical spring. It fires only on `Up` shifts with `FeelThrottle ≥ 0.5`, scaled by shift strength, and never on downshifts.
- **FOV pulse:** added into the existing fov term before `CameraService.SetFieldOfView`. A positive value widens the view.
- **Launch kick:** a `Launch` shift pushes the Lag spring (this comes from the design draft, not the contract).
- **Limiter shimmer:** keyed on `FeelLimiterRevision` bounces only, so it never fires on a shift cut, and it is off in neutral.
- **Test hooks:** `CameraChaseCuts` and `CameraSpinWeight` are written on the camera while `DebugEnabled` is on (it is on live). The first one counts hard cuts and is how the integrator checks "zero `resetChase`" during a spin.

**VehicleVFXClient**
- **Thrust:** follows `FeelLoad` when present, with its own fade time so cuts show. In neutral it keeps `FeelThrottle`, so the countdown limiter doesn't flicker the jets.
- **Vent flame:** on an `Up` shift with strength ≥ 0.7, `controller:Backfire` is called directly, never through `FeelPopRevision`.
- **Spin stutter:** the stabiliser jets alternate at 9 Hz as a brightness pulse. Neither side drops below the on-threshold mid-spin, so there is no on/off flashing. It adds hover dust plus a small ground-wash burst at intervals.
- **Strain shake:** a small thrust flutter near redline or with `FeelOverdrive`.

**Config:** `config.py` has 90 rows, all new: 45 numbers, each with a `_RaisingThisDoes` string. 20 go on `Config.Vehicles.Camera`, including `ChaseDrivetrainEnabled`, and 25 on `Config.Vehicles.StabiliserVFX`, including `DrivetrainVFXEnabled`. Switches are numbers. A script confirmed every default equals the code fallback and no name clashes with a live attribute.

**Risks the integrator should know (all in NOTES.md):**
- **Rear over-glow is only approximate on Exotic V2 cars.** `VehiclePreviewVFXClient` caps the engine channel at 1, and no part owns that file. So the over-glow is a surge of the hover jets under every engine plus the ground wash. A true over-glow needs a later change to that file.
- **Dust burst size:** V2 dust bursts above about 6 particles also fire the landing ring. Defaults are 5.
- **Spin mode also catches small wiggles:** at the 0.2 entry level it triggers on the catchable wiggle (up to 0.35 without a deliberate spin input). If that feels laggy in tight turns, raise `ChaseSpinEnterLevel` to 0.4.
- **Assumptions about physics:** the code expects `FeelGear` and `FeelLoad` to be written as soon as the drivetrain activates, and `FeelSpinDirection` +1 to mean a left spin. The direction only decides which stabiliser side leads, so a wrong sign is cosmetic.
- **Classic:** both scripts are in the Classic manifest, so their after-hashes (in NOTES.md) must be added to the declared set.

Files are in C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\camerafx\:
- after\DrivingCameraClient.lua
- after\VehicleVFXClient.lua
- config.py
- NOTES.md