# Mobile Free-Roam UI Phase 1K: Boost Plate And Exit Alignment

Date: 2026-07-13

## Outcome

Phase 1J was user-confirmed good. Phase 1K refines the mobile driving HUD without changing its input or gameplay contracts:

- keeps the Boost touch target at `44 px` on short screens and `52 px` otherwise for reliable tapping;
- reduces the visible lightning icon from `1.5x` to `1.05x` (`48 px` to roughly `34 px`);
- adds an `84%` circular plate beneath the icon;
- uses the same Electric Blue to Telemetry Cyan gradient as the vertical boost bar;
- computes Exit's Y position from telemetry scale, telemetry bottom margin, and the steering-cluster bottom margin;
- aligns Exit's bottom edge with the bottom edge of the turning buttons at both short (`10 px`) and standard (`16 px`) landscape margins.

The steering buttons, touch areas, boost action, speed/boost telemetry, pedals, three mobile control modes, car menu, gameplay, and physics remain unchanged. Both changes stay inside the canonical isolated mobile control/HUD owners; no bootstrap patch or fragile source replacement is used.

## Studio Install

Run the complete contents of this file in the Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua
```

The installer requires live Phase 1J markers. If preflight fails, stop and inspect/refresh the live Studio source.

## Verification

1. Start driving with mobile control mode set to Arrows.
2. Confirm the lightning icon is smaller but its invisible touch target remains easy to press.
3. Confirm a circular blue-to-cyan gradient plate sits behind the lightning icon.
4. Hold/release Boost and confirm input behavior is unchanged.
5. Confirm the bottom of Exit aligns with the bottom of the lower turning-button row.
6. Repeat on one short landscape viewport and one standard landscape viewport.
7. Recheck speed/boost telemetry, arrows, pedals, Thumbstick, Tilt, car menu suppression, and driving UI restoration.

## Config And Rollback

Editable attributes under `ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud`:

```text
BoostIconScale = 1.05
BoostPlateScale = 0.84
BoostPlateGradientRotation = 45
TelemetryBottomMargin = 2
```

The installer migrates only the known Phase 1J `BoostIconScale = 1.5`; an intentionally customised icon scale is preserved. Clean rollback is Studio version history or the confirmed Phase 1J canonical source.

## Mirror Status

The repository mirror still contains Phase 1C mobile owners from `2026-07-13 15:33:06`, so it is stale for Phases 1D-1K. After confirming Phase 1K, start `py scripts/receive_studio_full_snapshot_export.py`, then run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in Studio. Never commit `docs/studio-full-export-paste.txt`.
