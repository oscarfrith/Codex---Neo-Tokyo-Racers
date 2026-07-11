# PC Free-Roam UI Phase 3C North-Up 2D Minimap

Date: 2026-07-11  
Status: Generated baseline; superseded by Phase 3D for image-only player/north markers

## Studio script

Run in Edit mode:

`scripts/roblox_ui_freeroam_pc_phase3c_north_up_2d_minimap.lua`

## Design

Phase 3C returns to direct 2D `ImageLabel` rendering so the four map assets retain their original colours, sharpness, and transparency. The stitched canvas translates beneath a centred marker but never rotates, allowing `ClipsDescendants` to constrain it to the minimap box.

The map remains north-up. The centred player icon optionally rotates with vehicle/player heading.

## Player icon

Set the image under:

`Config.UI.DesktopFreeRoamHud.Assets.MapPlayerIcon`

It accepts a numeric asset ID or complete `rbxassetid://...` value. With no image, a small cyan square is shown.

Editable values:

- `Layout.MapPlayerIconSize = 22`
- `Defaults.MapPlayerIconRotates = true`

The icon remains centred and does not alter the minimap box or stitched-map scale.

## Map alignment and zoom

- `Layout.MapCoordinateRotationDegrees = 90` applies the correction indicated by the green/red/yellow screenshot.
- `Defaults.MapFlipX` and `MapFlipZ` remain available after rotation is verified.
- `Layout.MapVisibleStuds` changes map zoom without changing the minimap box.
- The original four tile asset slots, `207px = 2850 studs`, and world origin centre are preserved.

## Verification

1. Stop Play, run Phase 3C, and restart Play.
2. Confirm no map pixels appear outside the minimap rectangle.
3. Confirm the artwork matches the original 2D uploaded images rather than the washed-out ViewportFrame result.
4. Compare the player location with the expected yellow annotation. Try `MapCoordinateRotationDegrees = -90` only if the correction goes in the opposite direction.
5. Add `MapPlayerIcon`, restart Play, and verify the image is centred and square.
6. Change `MapPlayerIconSize` and confirm only the player icon changes size.
7. Turn through 360 degrees and confirm the icon rotates while the map remains north-up.
8. Change `MapVisibleStuds` and confirm only map zoom changes.

## Performance

Phase 3C uses four ordinary ImageLabels plus small transforms. It does not create a second 3D render pass and is cheaper than Phase 3B's ViewportFrame.

## Rollback

Rerun `scripts/roblox_ui_freeroam_pc_phase2i_borderless_boost_icon.lua` for the approved pre-minimap HUD. No in-game backup objects are created.

Refresh the Studio mirror after Phase 3C is accepted.
