# Racing UI Phase 16C - Config-Driven HUD Map

Status: Generated; awaiting Studio confirmation.

Run `scripts/roblox_racing_ui_phase16c_config_driven_hud_map.lua` in Studio
Edit mode after the confirmed Phase 16B2A parse repair. It adds a fixed race
map with a locally moving and rotating player arrow. It does not change racing
state, lap ownership, reset, finish cleanup, rewards, matchmaking or the
register-limited bootstrap.

## Configuration

The installer creates:

`ReplicatedStorage.NeoTokyoRacers.Config.Racing.HudMapCatalog.<RouteId>`

Set these values for each route:

- `Image`: simplified transparent in-race map asset. The installer initially
  copies the existing event `RaceHudMapImage` when available.
- `ImageWidthPixels` and `ImageHeightPixels`: original uploaded map dimensions.
- `StartPixelX` and `StartPixelY`: pixel occupied by the player at the start/finish anchor.
- `StudsPerPixel`: world studs represented by one source-image pixel.
- `MapRotationDegrees`: world X/Z rotation into image X/Y axes.
- `FlipX` / `FlipY`: optional independent mirroring corrections.
- `Enabled`: set true only after the calibration values are entered.

`AnchorPartName` defaults to `Grid_01` under
`Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>`. For a route without that
part, either change the name or enable `UseConfiguredWorldAnchor` and enter
`WorldAnchorX` / `WorldAnchorZ`.

The canonical map image now lives beside its calibration. An empty `Image`
falls back to the event's existing `RaceHudMapImage`. The marker reuses
`Config.UI.DesktopFreeRoamHud.Assets.MapPlayerIcon` and
`Layout.MapPlayerIconSize`, keeping the confirmed free-roam arrow asset and
size authoritative. `PlayerMarkerScale`, `Smoothing`,
`MarkerRotationOffsetDegrees`, and `ClampMarkersToMap` remain route-local tuning
controls.

The coordinate conversion occurs in original image-pixel space and then
accounts for `ScaleType.Fit` letterboxing. It therefore remains aligned when
the HUD scales to different PC resolutions.

`ShowOtherPlayers` and `OtherPlayerMarkerScale` are reserved now but other
players are deliberately not rendered until the local calibration is confirmed.

## Test gate

1. Install in Edit mode and enter the route measurements.
2. Set `Enabled=true`, restart Play and begin a Time Trial.
3. At the start line, confirm the arrow matches `StartPixelX/Y`.
4. Drive to a distant checkpoint and confirm direction and distance.
5. If mirrored, change only `FlipX` or `FlipY`; if rotated, tune only
   `MapRotationDegrees`.
6. Confirm the fixed map never translates or rotates, while the arrow does both.
7. Repeat in Race mode and at a smaller PC viewport.

After confirmation, a small follow-up can enable same-session other-player
markers through the identical mapper without changing the local calibration.
