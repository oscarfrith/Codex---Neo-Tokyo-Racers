# Driving camera handoff - 2026-07-17

## Confirmed baseline

The user confirmed Roblox-owned default vehicle camera V6.1 looks good. It is smooth, its bounded initial framing works, and the Studio mirror was refreshed at `2026-07-17 10:13:20`.

Canonical installer:

- `scripts/roblox_driving_camera_default_vehicle_system.lua`

Live module:

- `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.DrivingCameraController`
- Markers: `NTR_DRIVING_CAMERA_DEFAULT_VEHICLE_V6` and `NTR_DRIVING_CAMERA_INITIAL_FRAMING_V6_1`
- Mirrored fingerprint: `12611/581983456`

Active config:

- `ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DrivingCamera_Default_EditAttributes`
- `ConfigVersion = DRIVING_CAMERA_DEFAULT_VEHICLE_V6_1`

Roblox owns continuous `Camera.CFrame`, collision, desktop/mobile/controller orbit and interpolation. NTR only owns locked state distance, state FOV, restoration, and a bounded pre-camera framing setup. Do not return to the Scriptable V4/V5 design; it caused persistent hitching and reversed speed-distance behavior.

## Current mirrored tuning

- Distance default/acceleration/high-speed/boost: `22 / 24 / 23 / 26` studs.
- FOV default/acceleration/high-speed/boost: `85 / 95 / 100 / 110`.
- Framing: pitch `0`, saved height `100`, look-target height `20`, look-ahead `4`, apply frames `3`.
- Zoom lock: enabled.

The controller clamps height to `50`, so saved height `100` currently behaves as `50`. The acceleration distance being one stud greater than high-speed distance is also intentional current user tuning. Preserve both unless the user requests retuning.

## Verification if changed later

1. Confirm launch, high-speed, drifting and scenery contact remain smooth.
2. Confirm right-mouse, touch and controller orbit remain native.
3. Confirm wheel/pinch zoom remains locked.
4. Confirm distance and FOV respond through acceleration, high speed and boost.
5. Confirm framing edits trigger a short reframe and then release control back to Roblox.
6. Confirm exit/despawn restores the previous camera and zoom bounds.
7. Refresh the full Studio mirror after any camera source/config/hierarchy change.

## Repo state warning

The working tree contains extensive unrelated garage, racing, mobile UI, profile and mirror changes. Do not discard, reset, stage or rewrite them as part of future camera work. `docs/studio-full-export-paste.txt` must not be committed.
