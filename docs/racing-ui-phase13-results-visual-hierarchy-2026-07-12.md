# Racing UI Phase 13 - Results Visual Hierarchy

Status: Generated; awaiting Studio confirmation.

Run `scripts/roblox_racing_ui_phase13_results_visual_hierarchy.lua` in Studio
Edit mode after Phase 12, restart Play, and test both result modes.

This client-only refinement enlarges Time Trial session rows and typography,
gives the Race `YOUR RESULT` card stronger placement/prize/time hierarchy, adds
Gold/Silver/Bronze atlas medals for the top three, and adds cached Roblox player
headshots beside names in the Race Results table. Thumbnail failures retain a
neutral placeholder and never block results rendering.

The Race Highlights layout is prepared with avatar-sized slots but retains `--`
until a server-authoritative fastest-lap/highest-speed contract exists. This
phase does not change reset, finish order, matchmaking, rewards, PBs, cleanup,
or bootstrap registration.
