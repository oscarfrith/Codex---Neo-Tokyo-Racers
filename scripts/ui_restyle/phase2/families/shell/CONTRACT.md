# Shell family (F7): acceptance contract

Status: **generated, not installed.** Binding documents: `../../API2.md` 5.8 and section 6, `../../../phase1/API.md`, `../../CONTRACT.md`, programme contract 1.3, 1.5 to 1.7, 2.3, 8, Appendix A. Lane: High-Risk (saved onboarding state, a remote, start-up owners, two edits to existing ReplicatedFirst scripts). Reviewer required on the two edits, the fork and the model.

## Owners, before and after

| Surface | Classic owner | Pulse owner | Route |
|---|---|---|---|
| Onboarding callouts, objective cards, HUD shortcut locks, first-drive trigger, world guide trail | `ReplicatedStorage.Modules.Game.UI.OnboardingClient` (entry `OnboardingClient`) | `UIPulse.Shell.OnboardingClient` over `Shell.OnboardingModel` and `Shell.OnboardingView`; claims `Onboarding` | new owner, swapped in `Routes` |
| Loading view | `ReplicatedFirst.Loading.LoadingScreenView` | `ReplicatedFirst.Loading.LoadingScreenViewPulse`; claims `Loading` once the routes are committed | chosen by `LoadingTransitionRuntime` line 8 (edit 1); Classic view if the Pulse one is missing or errors on require |
| Start screen | `ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient` lines 20 to 328 | `ReplicatedFirst.Loading.StartScreenPulse` (`Run`); claims `StartScreen` once the routes are committed | logic-identical fork, entered by the guard after line 18 (edit 2); the Classic flow runs if `Run` returns false (stopped before `Begin`) |
| Loading runtime, artwork catalogue, `LoadingTransitionUI`, guide trail renderer, onboarding server | unchanged | unchanged | left as they are |

One owner per surface: under Pulse the Classic `OnboardingClient` is never required (one entry name, one path), the runtime requires exactly one view, and the Classic start-screen script returns before `Runtime.Start` when `Run` returned true. `Run` returns false only when it stopped before `Begin`; from `Begin` onwards it returns true or raises.

## Must preserve

1. **Saved state.** The 19 page ids and `PCDriving` are passed through untouched; the two remote calls are `OnboardingInvoke:InvokeServer("GetState", {})` and `("MarkSeen", {PageId = pageId})`, from one `call` function in the model. No new remote, action, key, bindable or attribute.
2. **Returning players get their saved progress.** The `GetState` retry (60 attempts, `min(5, 0.5 x attempt)` s) is carried; no page, objective card or trail shows before the reply.
3. **Page order, cards, action steps (`N6`, `X3`), placement, stage gates, the 0.18 s advance debounce, page abandon after `PageAbandonSeconds`, the first-drive rule and its `FirstDrivePresentationPending` write, the loading and map gate, the objective rules and the `Objective.Complete` sound**: as the Classic source (line references are in the model).
4. **Locks**: `Active`, `Selectable`, `AutoButtonColor` on the buttons marked `Car`, `Race`, `Garage`, each unlocked by its shortcut page. Pulse adds a release for the session, with one warning, when the saved progress never arrives or an open page cannot find a target for 10 s: the player is never left with dead HUD buttons.
5. **Loading**: the runtime singleton, its input gate, audio duck and presentation state are untouched; the view keeps the interface it calls. `LoadingSafeContent` > `SafeRoot` > `Status` (TextLabel), `ProgressTrack` > `ProgressFill` (childless Frame, X scale = progress) are kept for the start-screen flow. Artwork handling is the Classic code.
6. **Start screen**: exactly one flow calls `Begin`; the temporary `TimeoutSeconds` and artwork `Enabled` writes and their restore, every `StartScreenActive` write, `release`, and the Play and Shop handlers (`FreeRoamHudTeleportInvoke:InvokeServer("TeleportToDealership")`, `FreeRoamVehicleExited`) are Classic text, byte for byte.
7. **Classic can never break**: both edits read the latch, find the Pulse module with `FindFirstChild` and require it inside one `pcall`; a missing or failing latch or Pulse module gives the Classic view and the Classic flow. With style Classic each script runs today's statements plus one protected latch require.
8. **The player always gets in**: the Pulse menu build runs after `Begin` and is protected; if it fails, the kept `release(true, ...)` runs (the path Play takes). `release` cannot be stopped by the kit scope.
9. No `ScreenGui.Enabled` write in any new owner; ScreenGuis only from `Layers.Create`.

## Changed on purpose (each is in `contract.json` with its API2 reference)

Targets and menu state come from `Kit.Input` marks and `Kit.Presence`, on events, never from a timed walk of PlayerGui or Workspace. Callouts use the kit scale, advance by pad and keyboard, and are White and Pink. Objective cards sit in the `TopLeftHud` slot without slide tweens. The trail is Cyan through a config overlay. The loading status reads `LOADING PULSE RACERS`. The start menu is kit buttons (Shop, then Play; no portrait branch).

## Verification

| Check | Where | State |
|---|---|---|
| The two edits equal API2 5.8 and each is one hunk | `build_shell.py` (asserts), `diff before/ after/` | pass |
| Fork: kept lines are exactly the Classic lines outside the declared spans; no remote, fire or attribute write in a replacement span | `build_shell.py` | pass |
| Model tables equal `classic/contracts/_onboarding_targets.json` (19 pages, 33 cards, helper and literals per card and signal, copy, placement, action steps) | `build_shell.py`; again in the model test from a generated block | pass offline; test not yet run |
| Lint | `tools/lint_phase2.py shell` (after `build_forks.py shell`) | 0 open; 2 accepted in `integrator/lint_accept.json`, 4 kept fork lines listed for review |
| Fork build | `tools/build_forks.py shell` | hand assembly matches (129 kept lines) |
| Parity | `tools/parity_check.py shell` | 0 open |
| Pure tests (6 files): state machine sequences, every page begins and completes once, returning player, gates, first drive, objectives, remote shapes, target finder, locks, view placement rules, view mount at R1080 and C844, loading interface parity, menu builder | `tests/` | written, desk-checked, **not run** (no offline Luau) |
| Play: cold starts in both styles, fresh-profile onboarding replay on PC, a phone preset and a controller, start screen by pad and keyboard, exactly one `Begin` | integrator, API2 5.8 gates | open |

## Recovery

`Config.UI@UIStyle = "Classic"` restores every Classic owner, including the loading view and start screen, on the next Play. The install's ROLLBACK restores the two edited scripts from `before/` and removes the six modules.
