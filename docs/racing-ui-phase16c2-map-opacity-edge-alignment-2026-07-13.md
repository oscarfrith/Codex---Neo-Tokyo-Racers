# Racing UI Phase 16C2 - Map Opacity And Edge Alignment

Status: Generated; awaiting Studio confirmation.

Run `scripts/roblox_racing_ui_phase16c2_map_opacity_edge_alignment.lua` in
Studio Edit mode after Phase 16C1.

The `512 x 512` source was displayed in a `560 x 420` frame. Roblox
`ScaleType.Fit` correctly preserved the source aspect ratio, but centred the
square image inside the wider frame, creating about 70 logical pixels of empty
space on each side. Adding `MapOffsetX` made the visible artwork appear much
farther from the screen edge than configured.

Phase 16C2 keeps the approximately doubled visible map size while making its
frame square:

- `MapWidth = 420`
- `MapHeight = 420`
- `MapOffsetX = 16`
- `MapOffsetY = 16`
- `MapInnerPadding = 0`
- `MapOpacity = 0.78` by default

`MapOpacity` is intuitive: `0` is invisible and `1` is fully opaque. It changes
only the map artwork; the player marker remains fully readable. The controller
reads opacity continuously, so it can be tuned during Play testing.

The map remains under the established `1920 x 1080` racing reference canvas
and shared `UIScale`. Its size and 16-pixel safe buffer therefore scale with
the rest of the HUD at different PC resolutions. Coordinate calibration stays
in the original `512 x 512` source space and is not changed.

## Test

1. Restart Play and begin a Time Trial.
2. Confirm the visible map sits in the lower-left safe area without the former
   horizontal letterbox gap.
3. Confirm the marker still aligns with the start pixel and moves correctly.
4. Change `Config.UI.Racing.InRace.MapOpacity` during Play between `0.4`, `0.78`
   and `1` and confirm only the map artwork changes.
5. Test at 1920x1080 and a smaller PC viewport; the complete map and buffer
   should scale proportionally with the racing HUD.
