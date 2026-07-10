# PC Free-Roam UI Phase 2G Live Boost Telemetry

Date: 2026-07-10  
Status: Installed and visually approved; superseded by Phase 2H for icon/vertical placement

## Studio script

Run in Edit mode:

`scripts/roblox_ui_freeroam_pc_phase2g_live_boost_telemetry.lua`

## Purpose

Phase 2G canonically replaces only `DesktopFreeRoamHudController_Active`. It preserves confirmed Phase 2F and connects the desktop boost bar to `MobileDriveInputState.BoostPercent`, which the existing V75 driving controller already publishes for keyboard, gamepad, and mobile driving.

It does not patch the register-limited bootstrap, driving controller, server, VFX, or mobile UI.

## Default layout

- Width: `210px`
- Height: `24px` (twice the previous `12px`)
- Position within Telemetry: `X = 90`, `Y = 72`
- Smoothing: `14`

Editable values are under:

`ReplicatedStorage.NeoTokyoRacers.Config.UI.DesktopFreeRoamHud.Layout`

- `BoostBarWidth`
- `BoostBarHeight`
- `BoostBarOffsetX`
- `BoostBarOffsetY`
- `BoostBarSmoothing`

## Verification

1. Stop Play, run Phase 2G, and start a fresh Play session.
2. Enter a vehicle and confirm the bar begins full.
3. Hold Space and confirm it drains smoothly from right to left while the filled portion remains anchored on the left.
4. Release Space and confirm the V75 recharge delay is visible before gradual recharge begins.
5. Confirm the bar is approximately twice as thick and sits lower/left of its previous position without covering MPH or the speed arc.
6. Test a second boost module if available to confirm module duration/recharge differences are represented by the same percentage feed.
7. Briefly test Laptop device emulation and confirm the telemetry remains inside the screen.

## Rollback

Rerun `scripts/roblox_ui_freeroam_pc_phase2f_vehicle_card_content_offset.lua`. No in-game backup objects are created.

## Next UI phases

After Phase 2G is accepted: functional minimap, server dealership teleport handoff, server-authoritative cash products/receipts, functional/persisted settings, controls copy verification, then responsive regression audit and mirror refresh.
