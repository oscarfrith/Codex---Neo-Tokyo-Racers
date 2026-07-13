# Racing UI Phase 16B2 - HUD Visual Alignment

Status: Generated; awaiting Studio confirmation.

Run `scripts/roblox_racing_ui_phase16b2_hud_visual_alignment.lua` after Phase
16B. This visual-only correction explicitly centres the Exit modal and matches
the confirmed dealership `650 x 270` composition, message offsets and button
geometry. Its `NO` and cyan `YES` actions retain the existing exit owner.

The bottom Reset/Exit controls now copy the free-roam `360 x 38` container and
`150 x 32` / `170 x 32` button geometry, transparency and neutral styling.

Race and Time Trial share one gradient metric-card component and one borderless
gradient data-row component. The lap and centre cards align identically; the
lap-times heading is removed; completed times are white; PB remains pink; Race
positions use gold, silver, bronze then white, while the local name stays cyan.
All new measurements live under `Config.UI.Racing.InRace`.
