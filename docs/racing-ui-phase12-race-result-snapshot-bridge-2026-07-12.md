# Racing UI Phase 12 - Race Result Snapshot Bridge

Status: Generated; awaiting Studio confirmation.

Phase 12 fixes the empty unified Race Results screen by relaying values that the
confirmed matchmaking and reward owners already calculate. The previous service
sent the complete finish payload to the legacy queue event but only route fields
to the shared `RaceEvent` consumed by the new results controller.

Run `scripts/roblox_racing_ui_phase12_race_result_snapshot_bridge.lua` in Studio
Edit mode, restart Play, and complete a multiplayer race.

The bridge adds no new authority. It exposes server-owned placement, local finish
elapsed, medal/reward, selected vehicle id, and each participant's finish elapsed
through the existing result/position events. It does not change Phase 8H reset,
Phase 11Y finish cleanup, finish ordering, matchmaking, reward calculation,
reward idempotency, PB ownership, or the register-limited bootstrap.

Verify that the left result card shows place, prize, and finish time; the table
shows players, completed finish times, and selected vehicles; Exit To Start and
Race Again still work; and cash is granted once only.

Fastest lap and highest speed remain explicit `--` values. The current race owner
does not authoritatively capture per-lap or maximum-speed telemetry, so those
fields require a separate bounded telemetry phase rather than client inference.
