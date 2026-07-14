# Mobile Driving Control Images

Transparent `512 x 512` PNGs for the Neo Tokyo Racers mobile free-roam HUD:

- `mobile_turn_left.png` - normal steering; rotate `180` degrees for right.
- `mobile_drift_left.png` - drift steering; rotate `180` degrees for right.
- `mobile_accelerator.png` - accelerator pedal.
- `mobile_brake.png` - brake/reverse pedal.

Upload the four PNGs through Roblox Creator Hub/Asset Manager. After running the
Phase 1 installer, paste the resulting `rbxassetid://...` values into:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud.Assets
  TurnArrowImage
  DriftArrowImage
  AcceleratorImage
  BrakeImage
```

The runtime has text fallbacks, so the UI can be tested before image moderation
finishes. Source artwork is generated deterministically by
`scripts/render_mobile_control_assets.py`.
