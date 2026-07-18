# Roblox-owned default vehicle camera V6.1

Status: V6.1 installed, user-confirmed looking good, and mirrored at `2026-07-17 10:13:20`.

## Why this replacement is smaller

V4 and the attempted V5 attachment change left the visible driving hitch unchanged. The old controller continuously calculated and wrote `Camera.CFrame` from vehicle physics data, implemented its own orbit and collision, and layered several smoothing systems over Roblox rendering.

The mirrored V4 code also used the velocity-predicted position as the camera position anchor. With `VelocityLookAheadSeconds=0.12`, `100 MPH` advances that anchor by about `19.2` studs. That almost cancels a `29`-stud default trailing distance and explains why the camera moved closer while accelerating.

V6 returns continuous motion to Roblox. `CameraType.Custom` follows `DriverSeat`; Roblox owns CFrame, collision and orbit on PC, touch and controller. NTR only locks a smoothly changing distance, changes FOV by state, and writes one initial CFrame to establish starting pitch/yaw framing.

## Install and location

Stop Play and run `scripts/roblox_driving_camera_default_vehicle_system.lua` once in the Studio Command Bar.

The installer:

- accepts only the exact mirrored V4 source or exact generated V5 source;
- compile-checks V6 before mutation;
- replaces only `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.DrivingCameraController`;
- leaves the V47 bridge, register-limited bootstrap, driving physics, UI and VFX unchanged;
- creates `ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DrivingCamera_Default_EditAttributes`;
- copies compatible current camera values into that new folder only when missing;
- leaves the old `DrivingCamera_EditAttributes` folder and every one of its values untouched.

## Active tuning values

- Distance: `DefaultDistanceStuds`, `AccelerationDistanceStuds`, `HighSpeedDistanceStuds`, `BoostDistanceStuds`, and `DistanceSmoothing`.
- FOV: `DefaultFieldOfView`, `AccelerationFieldOfView`, `HighSpeedFieldOfView`, `BoostFieldOfView`, and `FieldOfViewSmoothing`.
- State timing: `HighSpeedStartMph`, `HighSpeedFullMph`, `AccelerationBlendSmoothing`, and `BoostBlendSmoothing`.
- Initial framing: `DefaultPitchDegrees`, `DefaultYawDegrees`, `DefaultHeightStuds`, `LookAheadStuds`, `LookTargetHeightStuds`, and `ApplyInitialLookAngle`.
- Behavior: `LockPlayerZoom`, `RespectTrailerCameraKeys`, `Enabled`, `ConfigRefreshSeconds`, and `DebugEnabled`.

V6's single framing write occurred after Roblox's camera step and did not update Roblox's retained orbit state. V6.1 applies framing immediately before Roblox's camera calculation for `InitialLookApplyFrames`, default `3`, then stops writing it. Editing any framing Attribute queues the same bounded operation, making live tuning visible without returning to continuous vehicle-follow CFrame ownership. The user confirmed the final result looks good; this is now the baseline.

## Verification

1. Stop Play, run the installer, and confirm all PASS lines.
2. Start Play and spawn a vehicle. Drive a launch, high-speed straight, drift route, uneven road and scenery contact. Smoothness is the first acceptance check.
3. Confirm the camera moves farther away—not closer—through acceleration, high speed and boost.
4. Confirm right-mouse PC orbit, touch orbit and controller orbit use Roblox's normal behavior.
5. Try mouse wheel and pinch zoom. With `LockPlayerZoom=true`, neither should change distance.
6. Drive beside and reverse toward walls. Confirm Roblox collision moves the camera inward without invisible custom-ray hits.
7. Compare normal, acceleration, high-speed and boost FOV/distance states. Edit the V6 config values during Play and confirm they update smoothly.
8. Change `DefaultPitchDegrees`, `DefaultHeightStuds`, and `LookTargetHeightStuds` one at a time during Play. Confirm each triggers an immediate short reframe and then releases control back to native orbit.
9. Exit/despawn and confirm the previous camera subject, type, FOV and player zoom bounds return.
10. If trailer views are used, confirm P/C/V release the controller and B restores the default vehicle camera.

## Rollback and mirror

Clean rollback is the preceding Studio history point containing the isolated V4/V5 module. No in-game backup object is created. Setting V6 `Enabled=false` stops it on the next update, but Studio history is the full source rollback.

The mirror is current through `2026-07-17 10:13:20` and contains V6.1 plus its config hierarchy. Future Studio-side camera changes require another full refresh. Do not commit `docs/studio-full-export-paste.txt`.
