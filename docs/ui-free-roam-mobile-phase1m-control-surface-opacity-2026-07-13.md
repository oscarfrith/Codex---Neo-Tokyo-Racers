# Mobile Free-Roam UI Phase 1M - Control Surface Opacity

Date: 2026-07-13

## Scope

Phase 1M is a visual-only refinement of `MobileDriveControlsController_Active`:

- turn/drift arrow cards lose their border/glow;
- arrow cards receive a dark `PanelSoft -> Panel` gradient;
- arrow card and artwork opacity become independently configurable;
- Accelerator/Brake cards default to fully invisible so only their artwork remains;
- pedal artwork opacity becomes configurable.

Input actions, touch hitboxes, control sizes/positions, steering, drift, throttle/brake, boost, Thumbstick, Tilt, mobile popups, racing UI, PC UI, gameplay, server, bootstrap, VFX, and LOD are unchanged.

## Studio Script

Run this whole file in the Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase1m_control_surface_opacity.lua
```

Leave `MODE = "INSTALL"`, restart Play, verify all three mobile control modes, then change to `MODE = "SMOKE"` and run it again in Edit mode.

## Tuning

Attributes live at:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud
```

Defaults:

```text
ArrowCardOpacity = 0.72
ArrowImageOpacity = 0.92
ArrowPressedOpacityBoost = 0.12
ArrowCardGradientRotation = 90
PedalCardOpacity = 0.00
PedalImageOpacity = 0.92
ControlPressedImageOpacityBoost = 0.08
```

Opacity uses the user-facing convention `0 = invisible`, `1 = fully opaque`. `PedalCardOpacity = 0` preserves the requested image-only pedal presentation. Raising it intentionally restores a dark pedal card without restoring a border.

## Verification

1. Drive with Arrows and confirm all four arrow cards have no pink border/glow.
2. Confirm their dark gradient remains visible at the configured card opacity.
3. Press each arrow and confirm the existing input still works and the configured pressed opacity response appears.
4. Confirm Accelerator and Brake show only their images, with no visible card or border.
5. Hold both pedals and confirm throttle/brake behavior and hit areas are unchanged.
6. Temporarily tune each opacity attribute and confirm only the intended card/image changes.
7. Test Thumbstick and Tilt once to confirm their existing visual/input behavior is unchanged.

## Risk And Rollback

This uses one guarded exact source-range replacement in the refreshed Phase 1K control owner. It does not patch the Phase 1L HUD owner. Roll back with Studio version history or restore `MobileDriveControlsController_Active` from the pre-install mirror refreshed at `2026-07-13 20:22:34`. Added config attributes are inert under the previous owner.

Refresh the Studio mirror again after installation and confirmation.
