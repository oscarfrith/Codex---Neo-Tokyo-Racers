# Mobile Free-Roam UI Phase 1 Canonical HUD And Controls

**Date:** 2026-07-13  
**Status:** Phase 1 installed and mirrored at 2026-07-13 14:58:02; superseded for the next Studio rerun by Phase 1B PC component parity

Phase 1 screenshot review found map parity, action-bar orientation, telemetry
parity, control sizing, and duplicate bootstrap HUD issues. The same canonical
installer is now upgraded to Phase 1B. Continue from
`docs/ui-free-roam-mobile-phase1b-pc-component-parity-2026-07-13.md` rather than
rerunning the original Phase 1 behavior.

## Purpose

Phase 1 replaces the retired/compatibility mobile UI loaders with two isolated,
touch-only owners. It reuses the confirmed PC Phase 4A colour, map, telemetry,
garage, race-browser, dealership-teleport, spawn, despawn, and exit contracts.

It does not patch driving physics, VFX, LOD, server gameplay, or the
register-limited client bootstrap.

## Studio Run Order

Run in Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase0_audit.lua
```

Proceed only when the final line reports `fail=0`. Then run:

```text
scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua
```

The Phase 1 installer is a canonical source replacement, not a fragile text
replacement. It preflights the confirmed Phase 4A action contracts and shared
mobile input state before writing any source.

## Installed Owners

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.MobileFreeRoamHudController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active
```

The obsolete Phase 16E compatibility loaders for `DriveHudController_Active`,
`FreeRoamNavController_Active`, and `FreeRoamVehicleExitButton_Active` become
explicit no-ops so they cannot require missing legacy modules or construct
duplicate mobile UI.

## Layout

- Top-right: rescaled north-up four-tile Phase 4A map.
- Under the map: cash chip and `+` button.
- Left of the map: Car, Garage, Race, Dealership, and Settings actions.
- Bottom-left in default Arrow mode: drift left/right above normal left/right.
- Bottom-centre: rescaled speed, curved gauge, boost bar, boost button, and Exit.
- Bottom-right: accelerator and brake/reverse pedals.

## Mobile Control Modes

The first row in the touch-only Settings modal is:

```text
ARROWS | THUMBSTICK | TILT
```

- `Arrows` is the default. Upper arrows write steer plus drift; lower arrows
  write normal steering.
- `Thumbstick` uses analog steering and the existing configurable drift
  enter/exit thresholds.
- `Tilt` uses gyroscope roll relative to a neutral calibration, with smoothing,
  deadzone, maximum angle, a held Drift button, and Recenter. Tilt is disabled
  when `UserInputService.GyroscopeEnabled` is false.

The choice is intentionally session-only until the existing settings persistence
design is implemented.

## Image Upload

Upload these four transparent PNGs:

```text
assets/ui/icons/mobile_controls/mobile_turn_left.png
assets/ui/icons/mobile_controls/mobile_drift_left.png
assets/ui/icons/mobile_controls/mobile_accelerator.png
assets/ui/icons/mobile_controls/mobile_brake.png
```

Paste their ids into:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud.Assets
```

Mapping:

- `TurnArrowImage` -> `mobile_turn_left.png`
- `DriftArrowImage` -> `mobile_drift_left.png`
- `AcceleratorImage` -> `mobile_accelerator.png`
- `BrakeImage` -> `mobile_brake.png`

Right-facing arrows reuse the left image with a `180` degree rotation. Text
fallbacks remain available before the images finish moderation.

## Verification

Use Device Emulator at a small phone and a larger tablet/phone landscape size.

1. Confirm map, cash, and five navigation buttons fit without touching Roblox's
   top bar or the pedals.
2. Enter a vehicle and confirm the mobile controls, speed, boost, and Exit appear.
3. Arrow mode: hold each normal arrow, then each upper drift arrow.
4. Thumbstick mode: confirm proportional steering and drift only near the outer
   ring; release outside the hit area and confirm steering resets.
5. Tilt mode on a real device: confirm neutral calibration, left/right steering,
   held Drift, Recenter, and no steering input after exiting the vehicle.
6. Confirm accelerator, brake/reverse, boost, spawn/swap, despawn, exit, race
   browser, garage, and dealership teleport still use their confirmed actions.
7. Open racing/garage presentation and confirm the free-roam mobile HUD yields
   without leaving duplicate UI.
8. Restart Play and check Output for errors, especially missing legacy modules,
   `Out of local registers`, or nil UI/action references.

## Risks And Rollback

- Tilt feel must be tested on real landscape devices; emulator testing cannot
  validate gyroscope orientation or hand jitter.
- The four image ids are intentionally not guessed. Until uploaded, text
  fallbacks appear.
- Cash products and general settings persistence remain visual/non-functional,
  matching the Phase 4A baseline.

Rollback before confirmation:

1. Restore the last confirmed Studio version/history point from immediately
   before Phase 1.
2. Do not rerun the old thumbstick V1-V2.4 patch ladder against the new canonical
   controller.
3. Refresh the Studio mirror so the restored source becomes the next baseline.

## Mirror Handoff

After successful Studio testing, run the local receiver and Studio exporter:

```text
py scripts/receive_studio_full_snapshot_export.py
scripts/roblox_studio_export_full_snapshot_for_github_v2.lua
```

Commit the refreshed `roblox/exported_scripts/` and `roblox/studio_snapshot/`
outputs. Do not commit `docs/studio-full-export-paste.txt`.
