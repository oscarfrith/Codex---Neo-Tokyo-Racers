# Racing UI Phase 16B - GT HUD, Controls and Suppression

Status: Generated from the refreshed mirror; awaiting Studio confirmation.

Run `scripts/roblox_racing_ui_phase16b_gt_hud_controls_suppression.lua` in Edit
mode after Phase 16A. It adds a small BindableEvent presentation bridge to the
isolated desktop free-roam HUD. During racing, navigation, cash/minimap, drawers,
modals and free-roam actions hide while the original speed/boost telemetry stays
visible. Exact visibility is restored only when the session exits.

The lap counter moves below the Roblox top bar and becomes borderless. The upper
right Race standings/Time Trial lap list becomes a larger Gran Turismo-style
transparent composition with individual row strips and no outer frame. The
simplified `RaceHudMapImage` becomes completely borderless.

Phase 16B also replaces the old Phase 8D panel with shared `RESET` / `EXIT`
buttons and a dealership-sized confirmation modal. Actions still call the
confirmed Phase 8H reset and existing Race/Time Trial exit owners through the
existing transition bridge. No reset, cleanup, reward, placement or PB authority
moves into UI.
