# PC Free-Roam UI Phase 3D Image-Only Map Markers

Date: 2026-07-11  
Status: Generated; awaiting Studio verification

Run in Edit mode:

`scripts/roblox_ui_freeroam_pc_phase3d_image_only_map_markers.lua`

Phase 3D preserves the Phase 3C north-up 2D minimap and adds two image-only overlays. Both are fully transparent ImageLabels with no frame, background, border, glow, padding, or fallback graphic.

## Player marker

- Asset: `Config.UI.DesktopFreeRoamHud.Assets.MapPlayerIcon`
- Size: `Layout.MapPlayerIconSize = 22`
- Heading rotation: `Defaults.MapPlayerIconRotates = true`
- Position: fixed at the exact minimap centre

## North arrow

- Asset: `Config.UI.DesktopFreeRoamHud.Assets.MapNorthArrow`
- Size: `Layout.MapNorthArrowSize = 28`
- Bottom/right inset: `Layout.MapNorthArrowMargin = 10`
- Position: bottom-right corner inside the minimap

Asset values accept a numeric image ID or complete `rbxassetid://...` value. Restart Play after changing an asset value.

Verify that only the supplied images appear, both backgrounds remain transparent, the north arrow stays inside the lower-right corner, player heading rotates correctly, and map clipping/zoom remains unchanged.

Rollback by rerunning `scripts/roblox_ui_freeroam_pc_phase3c_north_up_2d_minimap.lua`. Refresh the Studio mirror after Phase 3D is accepted.
