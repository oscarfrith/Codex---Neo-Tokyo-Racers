# Racing UI Phase 16B2A - `endlocal` Parse Repair

The first Phase 16B2 installer joined two valid generated source blocks as
`endlocal`, causing the active Racing presentation controller to fail compilation.
Run `scripts/roblox_racing_ui_phase16b2a_endlocal_parse_repair.lua` once in Edit
mode. It requires the 16B2 marker, replaces only `endlocal ` token boundaries
with `end\nlocal `, adds a repair marker and refuses unrelated source.

The original Phase 16B2 installer is also updated so future clean installs apply
the same parse-safe normalization before assigning source.
