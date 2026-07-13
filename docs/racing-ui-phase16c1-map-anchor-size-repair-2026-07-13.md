# Racing UI Phase 16C1 - Map Anchor And Size Repair

Status: Generated; awaiting Studio confirmation.

Run `scripts/roblox_racing_ui_phase16c1_map_anchor_size_repair.lua` in Studio
Edit mode after Phase 16C.

The refreshed mirror exposed that Phase 16C paired the supplied start pixel
with `FinishLine`. `ShiftedCanalSprint` is point-to-point: the server stages
Time Trial vehicles through `RouteDefinition.GetFirstSpawnCFrame`, which uses
`SpawnGrid.Grid_01`, while multiplayer uses the same spawn grid. Pairing the
left-side start pixel with the right-side finish world position offsets the
marker by almost a full route.

This repair is config-only. It:

- sets the canonical world anchor to `SpawnGrid.Grid_01`;
- disables the optional numeric world-anchor override;
- records the uploaded source as `512 x 512` pixels;
- enlarges the visible square map from roughly `194 x 194` to `420 x 420`;
- preserves the user's `StartPixelX/Y`, `StudsPerPixel`, rotation, flips,
  smoothing and marker size.

The image remains `ScaleType.Fit`; Phase 16C already converts original source
pixels through the rendered letterbox bounds. The map stays fixed and the
free-roam player arrow remains independently sized and rotating.

## Test

1. Restart Play and begin a Time Trial.
2. Before moving, confirm the marker sits on the supplied start pixel.
3. Drive toward checkpoint one and verify direction and distance.
4. If start alignment is correct but travel direction is wrong, adjust only
   `MapRotationDegrees`, `FlipX`, or `FlipY`.
5. Confirm the map is twice the previous HUD size at the same PC resolution.

Do not compensate with arbitrary marker offsets. If the marker is still wrong
while stationary at `Grid_01`, capture the configured `StartPixelX/Y` and the
new screenshot; that would isolate an image-space issue rather than a world
anchor issue.
