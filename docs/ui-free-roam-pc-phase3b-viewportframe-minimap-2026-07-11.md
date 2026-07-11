# PC Free-Roam UI Phase 3B ViewportFrame Minimap

Date: 2026-07-11  
Status: Generated; awaiting Studio verification

## Studio script

Run in Edit mode:

`scripts/roblox_ui_freeroam_pc_phase3b_viewportframe_minimap.lua`

## Root fixes

### Map overflow

Phase 3A rotated a roughly 2,400px UI canvas inside a 245px clipped frame. Roblox UI clipping is unreliable with rotated descendants, allowing the stitched map to escape across the screen.

Phase 3B replaces that canvas with a `ViewportFrame`. Four flat `1024x1024` Parts with top-face Decals form the `2048x2048` map inside a `WorldModel`. A dedicated top-down Camera moves and rotates over the tiles. The ViewportFrame render is inherently constrained to its own UI rectangle.

### Coordinate alignment

The supplied screenshot showed the current green location vector needed to rotate approximately 90 degrees clockwise around the red origin to reach the expected yellow location. Phase 3B adds:

`Layout.MapCoordinateRotationDegrees = 90`

This calibration is applied to world position and vehicle heading independently of presentation rotation. `MapFlipX` and `MapFlipZ` remain available for mirroring after the initial test.

## Preserved configuration

- Four existing `Assets.MapTile...` IDs.
- `207px = 2850 studs`.
- World origin at the four-tile centre.
- `MapVisibleStuds` changes zoom without resizing the minimap box.
- `Defaults.Minimap = ROTATE` rotates the Viewport camera while the arrow stays upright.
- `Defaults.Minimap = NORTH` keeps the map north-up and rotates the arrow.
- `MapSmoothing` and `MapRotationOffsetDegrees` remain available.
- `MapViewportFieldOfView = 20` controls camera projection; normal zoom tuning should use `MapVisibleStuds`.

## Verification

1. Stop Play, run Phase 3B, and restart Play.
2. Confirm no map pixels render outside the minimap rectangle at any vehicle heading.
3. Verify all four tile Decals appear and their seams join at world origin.
4. Compare the live location against the expected yellow annotation. If it is rotated the opposite way, set `MapCoordinateRotationDegrees = -90`.
5. Use `MapFlipX` or `MapFlipZ` only if an axis is mirrored after rotation is correct.
6. Turn the vehicle through 360 degrees in `ROTATE` mode and confirm the camera rotates smoothly while the player arrow remains upright.
7. Change `MapVisibleStuds`; confirm the map zoom changes while the 245px minimap box does not.
8. Verify cash, car menu, boost telemetry, speed arc, and legacy-UI suppression remain correct.

## Risks and rollback

Roblox Decal UV orientation on a Part's top face may differ from the source-image convention. The coordinate rotation/flip controls should resolve position alignment; if the tile artwork itself is visibly mirrored, the next repair should rotate the four tile Parts consistently rather than altering gameplay coordinates.

Stable rollback: rerun `scripts/roblox_ui_freeroam_pc_phase2i_borderless_boost_icon.lua`. This returns to the approved pre-minimap HUD. No in-game backup objects are created.

Refresh the Studio mirror after Phase 3B is accepted.
