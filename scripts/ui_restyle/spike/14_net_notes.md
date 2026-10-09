# Spike 14 notes: Core.Net busy lock and token bucket, and the event card's two requests

Read from source only (`scripts/ui_restyle/classic/sources/`). No Play code. Answer first:

**Two cached read-only requests per event-card show are safe.** They go to the `RaceRequest` guard, which has no
busy lock, costs 1 token per call, holds 60 tokens and refills 20 per second. Conditions are at the end.

## There is no client Net wrapper

`Core.Net` exists only as `ServerStorage.Modules.Core.Net` (166 lines). Nothing under `ReplicatedStorage.Modules.Core`
is a Net module (the folder holds CameraService, ClientLifecycle, ConfigReader, ConnectionScope, PathResolver,
Signal, Tags). Clients call `RemoteFunction:InvokeServer` directly; where a client has a lock it is a private
boolean in that one script (for example `RaceBrowserClient` 47 `teleportBusy`, `DesktopFreeRoamHudUI` 118 `busy`,
`GarageUI` 20 to 24 `Adapter.Busy`). So the "busy lock and token bucket" in plan 7.2 are both **server side, per
player, per guard**. A Pulse call site shares them with every Classic call site that uses the same remote.

## How the server guard works (`ServerStorage.Modules.Core.Net`)

| Lines | Behaviour |
|---|---|
| 70 to 75 | `Net.guard(spec, clock)`. Defaults: `capacity = 60`, `refill = 20` tokens per second. State is a weak table keyed by player, **one per guard**, so each remote has its own bucket |
| 78 to 80 | Unknown action (not in `spec.actions`) is refused before any token is taken |
| 81 to 84 | Optional `spec.check` field validation, also before tokens |
| 85 to 92 | Token bucket: refill by elapsed time up to capacity, `cost = spec.cost(action)` or `spec.cost` or 1; refuse with `messages.rate` ("Please wait before trying again.") when tokens are short; otherwise subtract |
| 97 to 114 | `run`: counts the call, then `check`. **Busy lock only when `spec.busy` is set** (103 to 106): if a request from this player is already inside the handler, refuse with `messages.busy` ("A request is already running. Please try again."); the flag is cleared after the handler returns or errors (107 to 108, `xpcall`) |
| 109 to 112 | A handler error is caught, warned, and returned as `messages.failed` |
| 130 to 151 | `Net.invoke`: payload sanity first (137 to 142: depth 4, 64 keys, strings up to 8192, finite numbers). A refusal returns `{Ok=false, Success=false, Message=...}` (or `false` for boolean replies). Tokens are subtracted only when `check` passes (91), so a call refused as unknown, invalid or rate-limited takes none; a call refused as busy has already paid its token (`check` at 100 runs before the busy test at 103) |
| 63 to 65 | State is forgotten when the player leaves |
| 46 to 60 | In Studio Play, per-action call and reject counts are mirrored every 5 s to `ServerStorage.Runtime.NetStats` attributes (`RaceRequest_GetEntryDetails = "calls/rejected"`). This is a ready-made server-side check for the Pulse call site |

Guards that set `busy = true`: `GarageInvoke` (`GarageRequestGuard` 35 to 38: capacity 120, refill 60, cost 1 for
colour actions and 6 for the rest) and the activity invoke (`ActivityService` 290 to 291). **`RaceRequest` does not.**

## The two requests the event card would make

Both are actions of `Remotes.Racing.RaceRequest`, guarded at `TimeTrialServer` 1330:
`Net.invoke({name="RaceRequest", actions={... GetEntryDetails=true, GetTimeTrialPersonalBest=true, ...}, capacity=60, refill=20, ...})`.
No `busy`, no `cost`, no `check`.

| Action | Handler | Work done |
|---|---|---|
| `GetEntryDetails` `{EventId, Mode}` | `TimeTrialServer` 1345 to 1352 | `RaceConfigReader.GetEventSummary` (a config read). Returns `{Ok, Summary}` |
| `GetTimeTrialPersonalBest` `{EventId, VehicleTier}` | `TimeTrialServer` 1353 to 1363, then 87 to 104, then `PersonalBestServer.getBest` 276 to 289 | One more `GetEventSummary`, then a BindableFunction into the personal-best session table. `getBest` calls `loadPlayer` first (276 to 277), which is the per-session load, then reads `session.Records`. An empty or `"--"` tier returns `Found=false` without touching the store (1359 to 1361) |

Neither writes anything. Classic already makes the same two calls from the race entry page
(`RaceEntryPresentationClient` 516 and 763 for the personal best; `RaceSessionPresentationClient` 271 `queryPB`).

## Is the new call site safe?

- **Tokens.** Two tokens per show from a bucket of 60 that refills 20 per second. Draining it needs more than 20
  calls per second sustained. Once per `PromptShown`, cached per event, is two calls per event per session.
- **Busy lock.** None on this guard, so the two calls may run at the same time and cannot refuse each other, and
  cannot collide with a Classic or Pulse race-entry page making its own `RaceRequest` calls.
- **Shared bucket.** The bucket is shared with `AcknowledgeStagingReady`, `StartStagedTimeTrial`,
  `ResetActiveTimeTrial` and the other `RaceRequest` actions (1330). A refused `AcknowledgeStagingReady` would
  matter. Two calls against 60 tokens leave that path untouched, **provided the view never retries in a loop**.
- **Yielding.** `InvokeServer` yields. The card must fetch on its own thread and draw from the cache, with the
  render token rule from plan 5.1 rule 8, so a late reply cannot draw into a newer card.
- **`PromptShown` flicker.** If spike 11b shows `PromptShown` firing repeatedly while seated in a zone, an uncached
  fetch per show would multiply calls. The per-event cache makes the count independent of flicker. Add a floor of
  one fetch per event per 30 s for the personal best so a finished run refreshes it without a loop.
- **Failure shape.** A refusal arrives as `{Ok=false, Success=false, Message=...}`; a transport error throws. Wrap
  in `pcall` as `RaceEntryPresentationClient` 72 to 76 does and show the card without the personal-best row.

## Conditions carried into the Phase 4 contract

1. One fetch per event per show at most, cached per `EventId` (and per `VehicleTier` for the personal best).
2. No retry loop; a refusal leaves the row empty until the next show.
3. Never called while a race or staging is active (the card is hidden then anyway).
4. Verify in Play by reading `ServerStorage.Runtime.NetStats` on the Server datamodel before and after ten card
   shows: `RaceRequest_GetEntryDetails` and `RaceRequest_GetTimeTrialPersonalBest` rise by at most the number of
   distinct events, and the rejected half stays 0.
