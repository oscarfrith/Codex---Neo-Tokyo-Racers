# Project 12 comparison (2026-09-26)

Read-only review of the team's game "Project 12 DEVELOPMENT" (place 108625157065286, open in Studio as a second instance) against Space Racers. No changes were made to Project 12. The resulting programme is recorded in [architecture programme](architecture-programme.md).

## Project 12 at a glance (~6/10)

Same top-level layout as Space Racers (ServerBase/ClientBase, Modules.Core/Game on both sides), ~964 scripts, 41 authored ScreenGuis.

Strengths worth copying (and what Space Racers adopted):
- Name-multiplexed networking (`Core.Net`) with declarative per-hook rate limits, a connect handshake and a client bandwidth profiler -> Space Racers Core.Net (wrapping existing remotes instead of replacing them).
- One money mutation point with analytics tags (`MoneyServer`) -> MoneyService + AnalyticsServer.
- Keyed camera stacks (`FieldOfView`, `ZoomLimits`) and a derived CameraType owner -> CameraService (FOV/zoom so far).
- `CoreGuiHandler` visibility arbiter, `Core.Keybinds` action registry with context dictionaries -> planned (ARCH-P7 remainder).
- ConfigService flags with Studio overrides and one `is_item_enabled` gate -> FeatureFlags.
- Receipt idempotency by purchase id -> ReceiptProcessor template (fixed: save-first, no grant-then-failed-save double grant).
- Anti-teleport rules gated by flags with log-first rollout -> RaceIntegrity Log/Enforce.
- Streaming-aware tag-bound objects (`StatefulObject`) -> Core.Tags.

Weaknesses Space Racers must not copy:
- Hand-rolled persistence with a non-atomic GetAsync/SetAsync session lock and no save retry (Space Racers' UpdateAsync lease is better).
- Grant-then-save receipts that can double grant on save failure.
- Client-trusted hits (aim cone disabled) and client-owned vehicle physics without server plausibility checks.
- Unvalidated FOV/zoom stacks and direct writers bypassing the arbiters.
- Duplicated Core modules drifting between server and client; `--!strict` in ~20 modules.

## Security items reported to the user for the Project 12 team (verified in source, secrets not reproduced here)

1. Two webhook URLs with tokens are hard-coded in source (ServerBase.Logs.NotifyDiscord, Developer.ConsoleServer): rotate and move to Secrets.
2. `InGameExplorer.Permissions` grants the runtime explorer (server and client code execution) to any member of the group at any rank; restrict by rank/user and dev place.
3. `PurchaseServer.process_receipt` grants before saving; a failed save plus Roblox retry grants twice.
4. `Core.Data` session lock is non-atomic (`IMMEDIATE_SAVE_LOCK_ON_JOIN = false`); a saved `false` is overwritten by defaults on load.

## Where the detail lives

The full agent reports are in the 2026-09-26 session transcript, not the repository. Re-run a read-only review (Studio instance "Project 12 DEVELOPMENT") if deeper detail is needed.
