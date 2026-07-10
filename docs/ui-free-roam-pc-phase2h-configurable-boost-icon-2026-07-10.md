# PC Free-Roam UI Phase 2H Configurable Boost Icon

Date: 2026-07-10  
Status: Installed; superseded by Phase 2I for image-only presentation

## Studio script

Run in Edit mode:

`scripts/roblox_ui_freeroam_pc_phase2h_configurable_boost_icon.lua`

## Changes

- Moves the boost bar/group up exactly five pixels by changing `BoostBarOffsetY` from `72` to `67`.
- Removes the `BOOST >` text label.
- Adds a dark `BoostIconBox` with electric-blue border and matching glow.
- Adds an image fitted inside the box, with a lightning fallback while no image ID is configured.
- Keeps the icon slightly larger than the boost bar and vertically centres it beside the track.

## Editable values

Image asset:

`ReplicatedStorage.NeoTokyoRacers.Config.UI.DesktopFreeRoamHud.Assets.BoostIcon`

Enter either a numeric Roblox image asset ID or a complete `rbxassetid://...` value, then restart Play.

Layout values:

- `BoostIconSize = 32`
- `BoostIconGap = 8`
- `BoostBarOffsetY = 67`

The icon size is clamped to remain at least two pixels larger than the current bar height.

## Verification

1. Stop Play, run Phase 2H, and start a fresh Play session.
2. Confirm the boost group is five pixels higher and no longer too close to the speed number.
3. Confirm the icon box is vertically centred, slightly larger than the bar, and separated by a clean 8px gap.
4. Enter an image ID in `Assets.BoostIcon`, restart Play, and confirm the image replaces the lightning fallback.
5. Hold and release Space to confirm boost drain/recharge remains functional.

## Rollback

Rerun `scripts/roblox_ui_freeroam_pc_phase2g_live_boost_telemetry.lua`. No in-game backup objects are created.

## Mirror

Refresh the Studio mirror after Phase 2H is accepted.
