# Racing UI Phase 14 - Vehicle Grid Edge Padding

Status: Generated; awaiting Studio confirmation.

Run `scripts/roblox_racing_ui_phase14_vehicle_grid_edge_padding.lua` in Studio
Edit mode, restart Play, and open both the Time Trial and Race vehicle pickers.

The scrolling frame must continue clipping vertically so cards cannot cover the
filters or footer. Phase 14 therefore adds responsive internal padding inside
`VehicleGrid`, moving the first row and first column far enough inward for the
button stroke and glow to render completely. It does not disable clipping or
change vehicle selection, filtering, sorting, responsive column count, or start
actions.
