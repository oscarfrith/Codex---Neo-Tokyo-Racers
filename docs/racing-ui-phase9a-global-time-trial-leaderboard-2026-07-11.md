# Racing UI Phase 9A - Global Time Trial Leaderboard

Adds an isolated OrderedDataStore-backed leaderboard owner for each event/class
pair. A small bridge runs only after the confirmed PB service reports a genuine
personal best. Writes are asynchronous and do not alter finish, reward or PB
ownership. Reads are server-cached, rate-limited and capped at 20 entries.

Install `scripts/roblox_racing_ui_phase9a_global_time_trial_leaderboard.lua`
after rerunning the current Phase 2 UI installer. `DataStoreEnabled` defaults to
false. Keep it false for ordinary Studio work; enable it only in a published
place with Studio API access intentionally enabled for production verification.

The UI keeps its unavailable state when the service is disabled or inaccessible.
Ordered values are integer milliseconds; optional vehicle metadata is stored in
a separate normal DataStore. No fabricated records are returned.
