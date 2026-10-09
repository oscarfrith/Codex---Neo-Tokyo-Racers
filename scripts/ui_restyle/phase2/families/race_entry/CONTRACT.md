# RaceEntry family: acceptance contract

Status: **generated, not installed, not run** (no offline Luau; every file was desk-checked). Under `../../CONTRACT.md` and `../../API2.md` 5.6. Classic source = `classic/sources/ReplicatedStorage.Modules.Game.Racing.RaceEntryPresentationClient.lua` ("C" + line).

## Owners

| Surface | Before, and after with `UIStyle` Classic | After, `UIStyle` Pulse |
|---|---|---|
| Race entry pages, the `RaceEntryPresentation` ScreenGui, the one listener on `RaceEntryPresentationRequest`, the one sender of `RaceEntryLegacyAction` (`Close`, `StartSelectedVehicle`), presentation owner `RaceEntry` | `Racing.RaceEntryPresentationClient` | `UIPulse.RaceEntry.RaceEntryClient` (claim `RaceEntry`) over `RaceEntryModel` (state, the three remote reads, the fires) and `SetupView`, `RecordsView`, `VehicleView` (kit drawing) |
| Vehicle spawn, `StartStagedTimeTrial`, queue join, entry-open tracking | `RaceEntryMenuClient` 63-85, `RaceLifecyclePresentationClient` 242-250 | the same two scripts, unchanged and never named |

Route: new owner. Entry name `RaceEntryPresentationClient` and its dependency `LoadingTransitionUI` are kept. No existing script is edited. Nothing is saved; no server change.

## Must preserve

1. **Pages and order.** Time trial: Setup, Records, Vehicles. Race: Setup, Vehicles. Back: Records to Setup; Vehicles to Setup (race) or Records (time trial) (C604, C673). The tabs reset to Setup (C869-870). Every open starts on time-trial Setup with the event's default lap, clamped (C880-887).
2. **Gates.** NEXT (now VIEW RECORDS) and CHOOSE VEHICLE in a time trial need `ownedTiers[selectedTier]`; the text is `OWN A X CLASS VEHICLE TO ENTER` (C601, C804). Race CHOOSE VEHICLE has no gate (C482). Start needs a selected vehicle (C675).
3. **Calls out, copied from the Classic call sites.** `GarageInvoke` `GetInitial` through `GarageCatalogClient.Fetch(remote, {})` on every open (C73, C213). `RaceRequest` `GetTimeTrialPersonalBest {EventId, VehicleTier}` (C763) and `GetTimeTrialLeaderboard {EventId, VehicleTier, Limit = 20}` (C521). `RaceEntryLegacyAction:Fire("Close")` (C481, C807). `RaceEntryLegacyAction:Fire("StartSelectedVehicle", {Mode, EventId, VehicleId, CockpitId, Tier, LapCount})` (C679), which is also the race queue request. `FreeRoamHudPresentationMode:Fire({Owner = "RaceEntry", Active, KeepTelemetry = false})` (C346). The screen is hidden before either `RaceEntryLegacyAction` fire, as Classic does; nothing is retried.
4. **Prize preview.** `clamp(floor(base x multiplier / nearest + 0.5) x nearest, MinReward, MaxReward)` from `Config.Racing.Rewards.Race` with the Classic fallbacks (C98-108), byte for byte. No other client arithmetic on money.
5. **Vehicle list.** What can be chosen is the Classic list: every owned vehicle in a race, `tier == selectedTier` in a time trial (C268). Order: rating, highest first. No Category or Sort control and no "N of M eligible" text.
6. **Names other scripts read.** ScreenGui `RaceEntryPresentation` (order 180); `TierE` to `TierS`, `LapSelector`, `PrizeSummary`, `MedalTargets` on the time-trial Setup page only; `RaceFormat` on the race Setup page only; two buttons with the texts `TIME TRIAL` and `RACE`. All through `Input.Mark` or a `MarkKey`.
7. **Never:** a `ScreenGui.Enabled` write, a second listener on `RaceEntryLegacyAction` or `StartRaceQueueRequest`, a spawn, queue or start remote from this owner, a new remote, action or payload key.

## Fixes carried (API2 5.6)

Fetch first, then draw: replies land in the model, the views draw the model's snapshot. One render token (`model.Revision()`): an overtaken snapshot is not drawn. Each reply carries its open token and is dropped after a close or a newer open. Footer buttons exist before any reply. `GetTimeTrialMedals` and `GetEventSummary` are protected. The personal best and the leaderboard are asked once per event and tier per open.

## Tests (pure, `tests/`)

| File | Covers |
|---|---|
| `RaceEntryModel_test` | page flow for both modes and the shortcut; gates; lap clamp; the prize rule against a verbatim copy of C98-108 (225 samples over five config fixtures) and in the race snapshot for every tier; pairing of event ids; owned tiers; catalogue index; vehicle eligibility, sort and tie-breaks; default selection; the three remote reads as (remote, action, keys); the `StartSelectedVehicle` payload for a time trial and for a race (the queue request); `Close`; fire order; double press; stale and out-of-order replies; odd reply shapes; the empty, loading and unavailable leaderboard |
| `SetupView_test`, `RecordsView_test`, `VehicleView_test` | every fixture state at R1080 and C844: no error, at most 220 instances, a second render changes no property; tier, lap, vehicle and row changes create and destroy nothing; one footer per page under repeated renders; the reserved names and the two texts where they must and must not be; an overtaken snapshot is not drawn; the vehicle row is in slot `RailButtons` |
| `RaceEntryClient_test` | owner shape; the two pure resolvers |
| `Dev.Fixtures.RaceEntry_test` | gallery shape; required states; every canned snapshot has the real model's shape |

## Done when

Steps 1 to 12 of `../../CONTRACT.md` section 5 pass for this install, and in Play with `UIStyle` Pulse: the `StartSelectedVehicle` payload equals Classic's for the same choices (time trial and race); the prize preview equals Classic's for every tier fixture; no stale page or duplicate footer under rapid clicks; Classic onboarding replays pages 17 to 19 (EventMode, TimeTrialSetup, RaceSetup); one `RaceEntryPresentation` gui, marked Pulse, never `Enabled`-written; no agent crosses a time-trial finish.
