# PC Free-Roam UI Phase 3A Four-Tile Live Minimap

Date: 2026-07-10  
Status: Updated after first-run startup failure; rerun the repaired installer before tile alignment verification

## Studio script

Run in Edit mode:

`scripts/roblox_ui_freeroam_pc_phase3a_four_tile_live_minimap.lua`

Phase 3A canonically replaces only `DesktopFreeRoamHudController_Active`. It preserves the confirmed Phase 2I HUD and does not patch driving, the register-limited bootstrap, server, VFX, or mobile UI.

The first generated Phase 3A source retained one stale `arrow.ZIndex = 16` line after the minimap arrow variable was renamed to `playerArrow`. This caused a nil error during HUD construction, before responsive layout and legacy-UI suppression could start. The canonical installer now removes that line. Rerun the same Phase 3A script in Edit mode; no separate repair ladder is required.

## Confirmed calibration

- Four `1024x1024` images form one `2048x2048` square.
- `207` source-image pixels represent `2850` Roblox studs.
- One source pixel represents approximately `13.7681` studs.
- The full map represents approximately `28,197.1` studs per side.
- World `0,0,0` is the centre point where all four images meet.

## Tile asset slots

Set these StringValues under `Config.UI.DesktopFreeRoamHud.Assets`:

- `MapTileTopLeft`
- `MapTileTopRight`
- `MapTileBottomLeft`
- `MapTileBottomRight`

Each accepts a numeric asset ID or a complete `rbxassetid://...` value. Tiles use `Stretch` inside exact equal quadrants so they stitch into one canvas.

## Map configuration

Under `Layout`:

- `MapPixels = 2048`
- `MapCalibrationPixels = 207`
- `MapCalibrationStuds = 2850`
- `MapWorldCenterX = 0`
- `MapWorldCenterZ = 0`
- `MapVisibleStuds = 2850`
- `MapRotationOffsetDegrees = 0`
- `MapSmoothing = 10`

Under `Defaults`:

- `Minimap = ROTATE`: player arrow remains upright and the stitched map rotates around it.
- `Minimap = NORTH`: stitched map remains north-up and the arrow rotates with the player.
- `MapFlipX`
- `MapFlipZ`

Use the flip values and rotation offset only if the uploaded artwork axes differ from the default mapping of world X across the image and world Z down the image.

## Verification

1. Run Phase 3A, add all four tile IDs, and restart Play.
2. At or near world origin, verify the join between all four tiles is beneath the centred player arrow.
3. Drive in positive X and confirm the map moves left beneath the fixed arrow. If reversed, enable `MapFlipX`.
4. Drive in positive Z and confirm the expected north/south artwork direction. If reversed, enable `MapFlipZ`.
5. Drive a known distance and compare movement against `207px = 2850 studs`.
6. In `ROTATE` mode, turn the vehicle and confirm its forward direction remains toward the top of the minimap.
7. Check tile seams. The source images must have matching edge pixels and no transparent padding.
8. Confirm cash UI, edge fades, boost telemetry, and car-menu visibility remain unchanged.

## Rollback

Rerun `scripts/roblox_ui_freeroam_pc_phase2i_borderless_boost_icon.lua`. No in-game backup objects are created.

## Mirror

The pre-Phase-3A mirror was refreshed and contains the installed Phase 2I controller. Refresh it again after Phase 3A is installed and aligned.
