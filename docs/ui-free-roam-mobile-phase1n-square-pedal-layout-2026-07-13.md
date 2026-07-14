# Mobile Free-Roam UI Phase 1N - Square Pedal Layout

Date: 2026-07-13

Phase 1N changes only Accelerator/Brake geometry in `MobileDriveControlsController_Active`. Both controls become equal square image slots, aligned along the same bottom edge. Accelerator remains rightmost and Brake sits to its left.

Run in the Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase1n_square_pedal_layout.lua
```

Leave `MODE = "INSTALL"`, restart Play, verify, then switch to `MODE = "SMOKE"` and rerun in Edit mode.

Image values remain at:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud.Assets.AcceleratorImage
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud.Assets.BrakeImage
```

Layout attributes live on `Config.UI.MobileFreeRoamHud`:

```text
PedalSize = 104
PedalBottomOffset = 10
PedalRightOffset = 10
PedalGap = 10
```

All values are pixels in the existing `IgnoreGuiInset` mobile reference. `PedalRightOffset` measures from the right screen edge to Accelerator. `PedalGap` is the horizontal space between Brake and Accelerator. Both squares share `PedalBottomOffset`.

Phase 1M presentation remains:

```text
PedalCardOpacity = 0
PedalImageOpacity = 0.92
```

Verify both images are square and equal, bottom-aligned, separated by the configured gap, and preserve their full touch targets. Test accelerate, hold brake, and reverse. Also check a short landscape viewport for overlap with the speed/boost cluster.

This is one exact guarded geometry replacement. Roll back with Studio version history or restore `MobileDriveControlsController_Active` from the pre-install mirror refreshed at `2026-07-13 21:09:59`. Refresh the mirror again after confirmation.
