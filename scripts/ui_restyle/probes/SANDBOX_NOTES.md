# Studio vehicle sandbox: what it protects

Read from the Classic source dump in `scripts/ui_restyle/classic/sources/` (byte-exact copy of Space Racers v3). Nothing here was run in Studio. File names are shortened: `ProfileServer` is `ServerStorage.Modules.Game.Player.ProfileServer.lua`, and so on.

## Answer

**The no-save guard covers the whole profile, for the whole session.** Every dealership purchase, module, upgrade, paint, garage-property and owned-garage purchase is kept in memory and never written.

**It does not cover three stores that are outside the profile:**

1. Time-trial personal bests (PB-01, confirmed).
2. The global time-trial leaderboard, which is written after a new personal best.
3. The dealership desk objective, which is written the first time the character walks up to the dealership desk.

Whether those three really reach a DataStore in v3 depends on config values that are not in the Phase 0 capture. `profile_fingerprint_server.lua` reports them; see "Not known from source" below.

## The sandbox switch

| Fact | Source |
|---|---|
| The switch is the attribute `StudioVehicleSandboxEveryPlay` on `ReplicatedStorage.Config.Player.Onboarding`. It must be exactly `true`, and only counts in Studio. | `ProfileServer` 179-185 |
| Captured value in v3: `false`. `StudioVehicleSandboxCash` is `1000000`. `StudioReplayEveryPlay` is `false`. | `classic/config_raw.json`, `onboarding` → `Onboarding` attributes |
| Nothing else is needed. There is no vehicle id attribute. `StudioVehicleSandboxCash` is optional and defaults to 1,000,000. | `ProfileServer` 198-226 |
| Only two scripts read these attributes: ProfileServer (sandbox) and OnboardingServer (replay). No client script reads them. | search of all 221 sources |
| When active, the server sets the Player attribute `StudioVehicleSandboxActive = true` and prints `STUDIO VEHICLE SANDBOX active player=<name> saves suppressed`. | `ProfileServer` 223-224 |

`StudioVehicleSandboxActive == true` on the Player is the check to make before any purchase in an agent session. It replicates, so the client probes report it.

## What the sandbox changes in memory

At profile load (`ProfileServer` 198-226):

- **Emptied:** `Vehicles`, `OwnedCockpitInstances`, `OwnedModuleInstances`, `CurrentVehicleId`, `OwnedCockpits`, `OwnedModules`, `InstalledModules`, `ModuleColors`, `NeonOwned`, `ModuleUpgradeLevels`, and every display-space vehicle reference.
- **Raised:** `Cash` becomes the larger of the saved Cash and `StudioVehicleSandboxCash`.
- **Left as loaded:** onboarding progress, Driver Rank and XP, settings, owned garage properties, owned-garage structure, decorations and lighting.

So an agent session starts with no vehicles. Any capture point that needs a car needs one in-memory purchase first.

## Why profile writes cannot happen

| Step | Source |
|---|---|
| `noSave` is decided once, when the profile loads: `not enabledAtLoad or studioVehicleSandboxConfig() ~= nil`. | `ProfileServer` 252 |
| With `noSave`, the load is a plain `GetAsync`. No session lease is taken, so nothing has to be released later. | `ProfileServer` 262-263 |
| The flag is stored on the session as `NoSave`. | `ProfileServer` 311 |
| Every save path (autosave loop 565-581, `SaveNow` binding 482-484, close on leave 387-397, `BindToClose` 583-597) ends in `session.Transport:save`. | `ProfileServer` 366-385 |
| `ProfileStore:save` returns `true, "Save suppressed"` before it encodes or writes anything when `session.NoSave` is set. | `ProfileStore` 62-68 |

Because the flag is read at load, **the attribute must be set in Edit before Play starts.** Changing it during Play does nothing for players already in the server. `sandbox_window.lua` only runs in Edit for this reason.

## Purchases, by route

All of these change only the in-memory profile and then mark it dirty. The dirty flag leads to a save, and the save is suppressed.

| Purchase | Route | Source |
|---|---|---|
| Vehicle (cockpit instance), modules, upgrades, neon, cosmetics | `MoneyService.Debit(profile, ...)`, then `ProfileServer.commit_garage` → `markDirty` | `GarageServer` 618, 1029, 1091, 1157, 1169; 158-160. `ProfileServer` 353-359, 324-334 |
| Garage property (capacity) | `MoneyService.Debit(profile, price, "GarageProperty")` on the same profile | `GarageCapacity` 174-188 |
| Owned-garage structure, decorations, lighting | `ExecuteOwnedGarageCommand` binding → `OwnedGarageAuthoritativeCommand.Execute` → `dirty(commit, ...)` → `markDirty`; Cash through `MoneyService.Debit` | `ProfileServer` 402-418. `OwnedGarageAuthoritativeCommand` 16-30. `OwnedGarageProfile` 155, 167, 175 |
| Owned-garage explicit save | The `SaveNow` binding, which is `saveProfile(player, true)` and is suppressed like any other save | `OwnedGarageManagement` 19. `ProfileServer` 482-484 |
| Race rewards, drive cash, rank XP | `ProfileServer.mark_dirty` | `RaceRewardsServer` 132. `ProgressionService` 89 |
| Onboarding pages and progress | `ExecuteOnboardingCommand` → `markDirty`; or fully in memory when `StudioReplayEveryPlay` is true | `ProfileServer` 419-456. `OnboardingServer` 31-49 |

**Owned-garage purchases are no-save under the sandbox.** The plan's "desk tests stop at preview and cancel" rule can be lifted for the sandbox once Oscar accepts this note, with one condition: confirm `StudioVehicleSandboxActive == true` in that Play session first.

## What the sandbox does not protect

### PB-01: time-trial personal bests (confirmed)

- `TimeTrialServer` records a personal best on every accepted finish: `recordPersistentPersonalBest` (72-85), called at line 767. There is no sandbox or Studio check on that path.
- `PersonalBestServer` keeps its own session and its own DataStore (`getStore` 122-124). It never reads `StudioVehicleSandboxEveryPlay`; the string "Sandbox" does not occur in the file.
- Its only gate is the BoolValue `ServerStorage.Config.Racing.PersonalBests.DataStoreEnabled` (106-108, 243-249). When that is true and the UserId is positive, a new best is written with `UpdateAsync` (256-261).
- **Extra risk found:** on leave and on shutdown it calls `savePlayer(player, true)` (380-390). With `force` it skips the "nothing changed" check (234-236) and writes whatever records it holds. If the initial load failed (200-211), it holds an empty table and would write that over the stored records. This is existing behaviour, not caused by the sandbox, and it applies to every Studio Play when that DataStore is enabled.

### Quitting a time trial can also record a personal best

The plan says results are reached "via the Quit path". From source, Quit has two outcomes (`TimeTrialServer` 684-710):

- **No lap completed:** the server fires `TimeTrialEnded` and sends the player back to the start. No results screen, no personal best, no reward.
- **At least one lap completed** (multi-lap events): it calls `sendTimeTrialResult(player, run, run.BestLapSeconds, "Quit", true)` (697). That is the normal result path, so it records the personal best (767) and grants the reward (776).

So the results screen cannot be reached through Quit without the same write as a finish. Agents may use Quit only before the first lap is complete, and that shows no results screen. The results capture point needs a gallery fixture or Oscar's own run.

### Global leaderboard

After a new personal best, `TimeTrialServer` 79-81 invokes `GlobalLeaderboardServer.record`, which writes an ordered store and a metadata store (`GlobalLeaderboardServer` 40-60). Gate: the value `ServerStorage.Config.Racing.Leaderboards.DataStoreEnabled` (28) and a positive UserId (43). No sandbox check.

### Dealership desk objective

- The client fires `CompleteDealershipIntroObjective` the first time the character comes within the desk activation distance of `Workspace.World.Dealership.Intro.Desk.GarageDeskTrigger` while the Player attribute `DealershipIntroObjectiveComplete` is not true (`DealershipIntroClient` 583-595, 707-714). It is skipped when the Intro attribute `PersistIntroObjectiveCompletion` is false (589).
- The server then calls `SetAsync("desk_objective_<UserId>", true)` on the store named by the Intro attribute `DataStoreName`, default `NTR_DealershipIntro_v1` (`IntroProgressServer` 24, 91-116, 139-156, 200-212). No sandbox or Studio check.
- If `DealershipIntroObjectiveComplete` is already true for Oscar's account, walking to the desk writes nothing. Check the attribute before the dealership capture point.

### Smaller items

- **Passenger setting:** the HUD Settings modal calls `SetPassengerAccess` (`ActivityService` 213). It is stored in the profile, so the sandbox suppresses it, but outside the sandbox it is a saved change.
- **Duel stake markers:** `DuelService` 163-201 writes its own DataStore. It needs two players, so agent sessions do not reach it.
- **Analytics:** `AnalyticsServer` logs economy and onboarding events when the `AnalyticsEnabled` flag is on (20-28, 37-46, 54-77). There is no Studio check in the file. Whether Roblox records analytics from Studio is not something the source shows.

## Not known from source

| Unknown | How to learn it |
|---|---|
| `ServerStorage.Config.Player.Persistence@DataStoreEnabled` in v3. If false, no profile is ever saved, sandbox or not (`ProfileServer` 106-108, 252). | `profile_fingerprint_server.lua` → `config.persistence` |
| `ServerStorage.Config.Racing.PersonalBests.DataStoreEnabled` and `...Leaderboards.DataStoreEnabled`. These decide whether PB-01 reaches a DataStore. | same probe → `config.personalBests`, `config.leaderboards` |
| Whether Studio has API access to DataStores for this place. | `profile_fingerprint_saved.lua` reports each read as ok or failed |
| Whether the desk objective is already complete for Oscar's account. | Player attribute `DealershipIntroObjectiveComplete` in any probe that lists Player attributes |
| Whether the sandbox profile owns a starter garage (owned-garage capture point). | Open the owned-garage browser in a sandbox session |

## What the window tool does

`sandbox_window.lua` (Edit only, place id checked):

- **open:** stores the current values of `StudioVehicleSandboxEveryPlay` and `StudioReplayEveryPlay` (including "absent") as JSON in the attribute `UIRestyleTestWindow` on the same folder, then sets the sandbox attribute to `true`. Replay is set only with `ARGS.replay = true`. Refuses if the marker already exists.
- **close:** restores both values exactly, verifies them, then removes the marker. Refuses if the window is not open. If the restore does not verify, the marker is kept.
- **status:** reports the marker and current values. An installer APPLY and a handoff should call this and refuse while `open` is true.

The marker attribute is harmless at run time: no script lists the attributes of that folder. It does make the place differ from the Classic config record until the window is closed, so close it before any AUDIT, save-and-reopen check or publish.
