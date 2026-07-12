# Racing UI Phase 16A - Shared In-Race HUD

Status: Generated; awaiting Studio confirmation.

Run `scripts/roblox_racing_ui_phase16a_shared_in_race_hud.lua` in Studio Edit
mode after confirming Phase 15 laps. The installer creates one isolated shared
HUD controller and `Config.UI.Racing.InRace` geometry values.

Time Trial shows authoritative lap progress, a local smooth display timer,
persistent PB readout and completed session laps. Race shows authoritative lap
progress, position and the live ordered player list with cached headshots. Both
modes use the same panels, offsets, typography and semantic theme. Existing
free-roam speed/boost telemetry remains its owner and the bottom-right is left
clear for it.

Each Race and Time Trial catalog event receives a separate empty
`RaceHudMapImage` attribute. Set this to the simplified transparent HUD map;
`MapImage`/menu artwork is intentionally not reused. Phase 16B will add authored
normalized map-path points, the moving player arrow, shared Reset/Exit buttons
and the dealership-format confirmation modal.

Phase 16A does not change reset, exit, finish, rewards, PB persistence,
matchmaking, route guidance or bootstrap registration.
