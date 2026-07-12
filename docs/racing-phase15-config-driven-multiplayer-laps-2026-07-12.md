# Racing Phase 15 - Config-Driven Multiplayer Laps

Status: Generated; awaiting Studio confirmation.

Run `scripts/roblox_racing_phase15_config_driven_multiplayer_laps.lua` in Studio
Edit mode. The authoritative value is the numeric `Laps` attribute on each event
folder under `ReplicatedStorage.NeoTokyoRacers.Config.Racing.RaceCatalog`.

Circuit races now complete the configured number of laps before the existing
finish boundary runs. Point-to-point routes are forced to one pass. Per-player
lap state, lap times, best lap, live position progress and the `RaceLapCompleted`
payload are server-owned. Menus, the planned HUD and results consume `LapTarget`
rather than maintaining separate values.

The patch preserves Phase 8H reset, Phase 11D finish cleanup, Phase 11A reward
calculation/idempotency, Phase 12 result presentation, matchmaking, session
assets and the register-limited bootstrap.

Verify sequentially with `Laps` set to 1, 2 and 3. With two racers, confirm a
racer on a later lap remains ahead of one at a later checkpoint on an earlier
lap. Reset before and immediately after the finish line, exit mid-race, finish
normally, verify one payout only, and verify Race Again uses the current catalog
lap value.
