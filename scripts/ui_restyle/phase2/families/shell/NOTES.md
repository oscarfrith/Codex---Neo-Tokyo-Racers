# Shell family (F7): notes for the integrator

Nothing here has run in Studio. There is no offline Luau: every Luau file was desk-checked line by line; the Python checks below did run.

## Files

```text
after/  ReplicatedStorage.Modules.Game.UIPulse.Shell.OnboardingModel.lua      headless state machine (deps-injected)
        ReplicatedStorage.Modules.Game.UIPulse.Shell.OnboardingView.lua       callout, dimmer, objective cards
        ReplicatedStorage.Modules.Game.UIPulse.Shell.OnboardingClient.lua     entry; mark-based target finder, locks, trail
        ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Shell.lua         3 gallery items, 19 states
        ReplicatedFirst.Loading.LoadingScreenViewPulse.lua                    new
        ReplicatedFirst.Loading.StartScreenPulse.lua                          hand assembly of the fork (build tool is the authority)
        ReplicatedFirst.Loading.LoadingTransitionRuntime.lua                  edit 1
        ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient.lua        edit 2
before/ the two edited scripts, byte copies of classic/sources (cmp: identical)
forks/  StartScreenPulse.json + 7 replacement spans
tests/  6 pure test files (API1 13 format)
contract.json  routes.json  spec_ops.json  CONTRACT.md  NOTES.md
build_shell.py     assembles before/, the two edits and the fork; verifies them; checks the model tables against the
                   generated contract; writes the EXPECTED block of the model test.  py -3 build_shell.py [--check]
gen_fragments.py   writes the three JSON fragments
```

## The two edits (verified)

```text
LoadingTransitionRuntime            diff: 8c8,9   (1 line removed, 2 added; 176 -> 177 lines)
InitialLoadingAndStartScreenClient  diff: 18a19,20 (0 removed, 2 added; 328 -> 330 lines)
```

The added lines are character for character the text of API2 5.8 (amended with the reviewer's fixes 1 and 2). `build_shell.py` asserts the anchors (line 8 text; lines 15 to 19; `packageFolder` declared at runtime line 6 and start-script line 11), that the Classic require of line 8 is carried as written, and that each diff is exactly one hunk.

## Reviewer fixes (2026-10-09), desk-checked, not run

1. **Runtime line 8**: latch read, `packageFolder:FindFirstChild("LoadingScreenViewPulse")` and its require share one `pcall`; anything but a table gives the Classic require. Style Classic: `Active` is false, nothing Pulse is looked up.
2. **Start-script guard**: the same shape for `StartScreenPulse`; the script returns only when `Run()` returned `true`. `Run()` itself is not protected by the caller on purpose: an error after `Begin` must not start a second flow.
   `Run` result: kit missing after one 5 s budget, a kit module erroring on require, or any error before `Begin` -> `false` (warned; Classic flow runs). `Begin` refused, safe content missing, menu build failed (released), menu shown -> `true`. Error after `Begin` in a kept line -> raised again (as in the Classic script; no second flow). The flag `began` is set in the `Begin` span (03) immediately before the call.
3. **Menu build** (span 04) is inside `pcall`. On failure the kept handler lines still run, against stand-in signals that never fire, and the footer span calls the kept `release(true, "MenuUnavailable")`: the same statements Play runs, so `Status` and `ProgressTrack` are shown again and the completion overlay is removed for later loading screens (the 216-221 path would have left them hidden, because it is written for the point before they are hidden). No span adds a `SetAttribute`, `InvokeServer` or `Fire` (still checked). The scope teardown inside `release` is protected.

Left open by these fixes: (a) `FindFirstChild` at ReplicatedFirst time is not proven on a cold start (already a deferred risk for the latch, spike 12): if the Pulse module has not replicated when the line runs, that session silently gets the Classic view or start screen. (b) The 5 s kit budget can also give a Classic start screen on a slow join while everything else is Pulse. (c) `LoadingScreenViewPulse` still loads its kit inside `Create` with 20 s waits and asserts: a failure there makes `Runtime.Start` raise for every requirer, which fix 1 (require-time only) does not cover.

## Pre-flight review (2026-10-09), desk-checked, not run

Targets: see `ONBOARDING_TARGETS.md` (52 targets: 49 ok, 3 mismatched and fixed here, 0 missing).

1. **Name marks undone by the kit** (G4 `Stats`, L2 `UpgradeBudget`): `Text.Label` and `Surface.Panel` write their root `Name` when they draw. The finder now also accepts `PulseMark == key` for a name mark (`OnboardingClient` `matches`).
2. **N6 on Compact**: the teleport button is on the race menu's detail page, where the page root (the list) is hidden; the page was abandoned after 3 s. `Model.OffRoot = { N6 = true }` keeps the page while the card's own target shows.
3. **Locks are always released.** `Model.LocksReleased` (one warning, then `Locks()` answers true for all three) is set when `GetState` fails 60 times, or when an open page cannot find a card target for `TargetGiveUpSeconds` (config attribute, default 10). Pages, callouts and `MarkSeen` are untouched: a stuck page keeps waiting as in Classic.
4. **First-drive watchdog.** 3 s after `OpenDrivingControlsFromOnboarding` is fired, `FirstDrivePresentationPending` still true with `DrivingControlsOpen` not true means nobody opened the modal: the flag is cleared with one warning. Before, that state blocked every page for the session (so `Car` never unlocked on PC).
5. **A completed page stays seen until its `MarkSeen` reply.** Classic replaced its whole state with every reply and every `OnboardingStateChanged`; a state built before the server recorded the page made it begin again and locked its button again. `_pendingSeen` is merged into every adopted state; `MarkSeen` is sent exactly as before (once, at page completion, and once for `PCDriving`).
6. **Loading view fails soft.** The kit budget is 5 s in total (was 20 s per instance). If the kit is missing, a kit module errors, or `Layers.Create` or the mount fails, `Create` warns and returns the Classic `LoadingScreenView` object (same interface), so `Runtime.Start` never raises for a Pulse reason. This closes open point (c) above.

**For the integrator's lint accept file** (`integrator/lint_accept.json`, not edited from here): (a) a new `classic-require` finding at `LoadingScreenViewPulse` line 194 (`require(module)` of `LoadingScreenView`, the fail-soft path of item 6) needs an entry; (b) the existing `frame-signal` entry is pinned to line 319 and the carried `RenderStepped` line is now 356.

The two edited Classic scripts are unchanged: their diffs against `before/` are as they were.

## Offline checks that ran

- `py -3 build_shell.py` and `--check`: all pass (edits, fork kept lines, 33 cards and 19 pages against `_onboarding_targets.json`).
- `tools/parity_check.py shell`: 0 open.
- `tools/build_forks.py shell`: the hand assembly matches the built fork (129 kept lines).
- `tools/lint_phase2.py shell`: 0 open. Six findings sit in Classic text that API2 5.8 says to keep: two are accepted in `integrator/lint_accept.json` (`frame-signal`, `classic-require`); the other four are kept fork lines the tool lists for review without counting, once `build_forks.py shell` has run:
  - `LoadingScreenViewPulse` `frame-signal`: the `RenderStepped:Wait()` of the grid-promotion wait, Classic `LoadingScreenView` 187 ("artwork handling is carried from the Classic view unchanged").
  - `StartScreenPulse` `classic-require` (the kept line 21, `LoadingTransitionRuntime`), three `warn-prefix` (kept warnings 48, 81, 323) and `poll-loop` (the kept readiness loop 64 to 71).

## API questions, and the reading used

1. **`Kit.Input` has no "a mark was added" signal.** `Marked(key)` can only be asked. A screen that opens, fetches, then draws its marked parts gives no event when the parts appear. Reading used: no kit change. The client re-checks on events (Presence, the attributes and bindables Classic listens to, `Visible` / `AncestryChanged` / attribute changes on already-marked instances and their ancestors, an activation input ending, sitting down) and then at 0.15, 0.4, 1, 2 and 4 s after the last event (bounded; nothing runs when idle, and nothing at all once onboarding is finished). **Request:** `Input.MarkAdded: Signal (instance, key)`. With it the input trigger and the settle timers can go. Until then a page whose marked parts first appear more than 4 s after the last event waits for the next event.
2. **`Claim` cannot be first in ReplicatedFirst.** `Switch.Claim` asserts `committed`, and `Commit` runs in ClientBase after the loading view and start screen exist. Reading used: both modules create their layer, then claim `Loading` / `StartScreen` when the latch's own `UIStyleCommitted` attribute turns true (an attribute signal on the latch ModuleScript, no polling), and never after a downgrade. If the integrator prefers no claim at all for these two, delete `claimWhenCommitted`.
3. **`LoadingBackground` is not created.** The task brief says the name is kept; API2 5.8 and the ladder (2.4) put the artwork in `LoadingSafeContentScrim` and `Layers.Create` refuses a name outside `Layers.Order`. Reading used: API2. No other script reads `LoadingBackground` (audit foundation-startup 553). The "four children" kept are `SafeRoot`, `Status`, `ProgressTrack`, `ProgressFill`; `BlackBacking`, `ArtworkClip`, `ArtworkMotion`, `SingleArtwork`, `GridArtwork`, `InputBlocker` keep their names under the scrim root.
4. **`Status` must be a real TextLabel** (the kept start-screen lines write `status.Text` and `status.Visible`), so it is not a `Text.Label` component. It is styled with `Text.Font(role)` and `Text.SizeFor(role, ctx)`, both public, role `Button`. `ProgressFill` has no children because the flow clones it.
5. **Onboarding layer is `Bare` (API2 5.8) but the cards need a slot.** Reading used: a `Layers.Stage(root, ctx, "Hud")` inside the Bare root gives `TopLeftHud`. The start screen does the same with a `Menu` stage on `SafeRoot`, as 5.8 says.
6. **Three Classic page signals look for a ScreenGui, which cannot carry a mark.** Reading used: `Dealership` = a showing `Text.Dealership`; `RaceBrowser` = a showing `CardContent`; `GarageBrowser` = a showing `GarageList` (the marks API2 5.2 and 5.7 require on those screens). `EventMode` = both `Text.TimeTrial` and `Text.Race` showing. Other families must not mark `CardContent` or `GarageList` anywhere else.
7. **Re-marked instances.** `Input.Mark(body, "Page.B")` on a body already registered as `Page.A` leaves it in both lists. The finder therefore checks that an instance still carries the mark (name, text, attributes from `Contracts.Marks`) before using it. A view may re-mark one body per tab.
8. **Kit calls made with raw instances.** The dimmer, highlight edges, connector and card backing are plain Frames coloured from `Tokens.Colour` / `Tokens.Opacity` (no literal); the kit has no "cut-out dimmer" or "frame" component. Positions inside the callout are computed from the target rectangle, which is the one place a screen must hold coordinates.
9. **Token requests** (nearest existing token used meanwhile): callout width (`PromptWidth` / `CompactPromptWidth`; preview 560), highlight padding (`TileBaseLine`), objective card width (`StatPanelWidth` / `CompactStatPanelWidth`; preview 436) and number cell (`BadgeLarge` / `CompactStatusHeight`), NEXT minimum width (`StepperWidth` / `CompactTileMinWidth`), loading bar width (`ToastMaxWidth`; preview 720) and height (`SegmentHeight`), start-menu lift (it sits in `BottomCentre`; the preview has it about 100 px higher, where Classic's `StartScreenButtonYScaleDesktop` 0.82 put it).
10. **`UIPulse.Shell` folder** is created by the FreeRoam install (`Shell.CoreUiPolicy`). `spec_ops.json` carries the create op with a note; drop it if the chain already has the folder.
11. **Fork spans.** API2 5.8 lists 22, 38, 113-229, 231-280, 282-291. Two more were needed to turn a script into a module: 1-19 (header: services, kit loader, menu builder, the opening of `Run`, and the locals of Classic 8 to 10 and 13) and 328 (the print, which becomes the closing of `Run`). `packageFolder`, `kit`, `Workspace` and `UserInputService` are not re-declared: no kept line uses them (checked by `build_shell.py`).
12. **Test harness.** The view and the two ReplicatedFirst modules resolve the kit lazily through seams (`View._modules`, `LoadingScreenViewPulse._kit`, `StartScreenPulse._kit`) so requiring them never touches the place; tests pass kit modules from `env.Load`. The tests need `env.Load` to resolve `...UIPulse.Shell.OnboardingModel` and the v2 kit, and `env.Scope()`.

## Classic behaviour not reproduced exactly

| Classic | Pulse | Why |
|---|---|---|
| 0.2 s tick for locks, cards, trail and page poll | events plus a bounded settle | API2 5.8 |
| Pages could begin before `GetState` returned | pages wait for the saved state | returning players never see a new-player callout |
| Callout scale borrowed from the target's `UIScale`; Michroma measurement; gold | kit scale; kit text; White frame, Pink glow and label | API2 2.10, 5.8 |
| Layout after `TargetStabilityFrames` rendered frames | relayout on `AbsolutePosition` / `AbsoluteSize` signals | no frame binding outside `Kit.Perf` |
| Missing-target retry every 0.08 s forever | backs off to 0.64 s | API2 6.6 rule 5 |
| Objective cards slide in and out, stagger, unlock delay; every desired card shows title, hint and `n/3` | pooled cards switch `Visible`; Regular: header plus cards, the first expanded with its hint; Compact: the first card only, as a strip | previews r18, c18; no CanvasGroup |
| Cards hang under `AccessControls` in an owned garage, under the shortcut row on phones, shrink above Boost | always the `TopLeftHud` slot | those names are not marks |
| `majorMenuOpen` walks PlayerGui (`CarPanel`, `ModalLayer`, workspaces, three ScreenGuis) | `Presence.Any()` plus the same attributes and presentation owners | API2 5.8. Depends on every Pulse menu, modal and side panel registering in Presence |
| Card search scoped to the page root's subtree | "on the same Pulse layer" (static and live guis are siblings), else any showing instance | layers |
| No pad or keyboard path | NEXT takes focus (trapping group); on an action step focus stays with the screen | API2 5.8 |
| Loading: two ScreenGuis switched by `Enabled`; status centred above a rounded gradient bar on every device | two layer roots switched by `Visible`; Regular keeps Classic's 81% height, Compact puts a full-width bar on the bottom margin | previews r19a, c19a |
| Start screen: Play then Shop, optional config icons, three layouts, `StartScreenButtonYScale*` | Shop then Play (main right-most), kit icons, Regular row in `BottomCentre` with READY above, Compact row in `BottomRight`; the three Y-scale attributes and two icon attributes are no longer read | preview r19b; API2 5.8 |
| Busy state changed `Active` and the label | `Disabled` on both kit buttons (same `Active`, plus the disabled look) and the label | kit |

Not built from the previews: callout titles ("YOUR GARAGE"), the trail distance line, the loading tip line and percentage, the Compact start screen without Shop (Shop is kept: "Play and Shop behaviours unchanged"). None exists in Classic data.

## What the integrator must check in Play

1. **Cold start, `UIStyle` Classic**: full Play record identical; `LoadingScreenView` is the view; the Classic start screen runs; no `[Pulse.` line. Then with the latch ModuleScript temporarily absent in a scratch copy: still Classic (the `pcall` guard).
2. **Cold start, `UIStyle` Pulse**: `LoadingSafeContentScrim` (1000) and `LoadingSafeContent` (1001) exist once, marked `UIStyle = "Pulse"`, no `LoadingBackground`; status `LOADING PULSE RACERS`, then `LOADING WORLD` / `PREPARING CITY` / `FINALISING` / `READY`; the bar fills; the completion overlay (`StartScreenCompletionFill`) fills and is removed; Play and Shop appear, Play focused with a pad; Play releases; Shop teleports and releases; exactly one `Begin` (generation 1); `StartScreenActive` true then false; `UIStyleClaims` ends with `Loading`, `StartScreen`, `Onboarding`. Whether the kit modules are already replicated when `Runtime.Start` runs (the loading view waits 5 s in total, then warns and returns the Classic view; the start screen waits 5 s in total, then hands over to Classic with a `[Pulse.StartScreenPulse]` warning). Failure drills in a scratch copy: remove `StartScreenPulse` (Classic start screen, one `Begin`); remove `LoadingScreenViewPulse` (Classic view); make `_buildMenu` error (warning, then the player is released into the game with `StartScreenActive` false).
3. **Every later loading transition** (dealership travel, garage enter and exit, race start): the Pulse view shows, fades and hides; input is blocked and released; chat policy sees `Presence` kind `Loading`.
4. **Fresh sandbox profile (`StudioReplayEveryPlay` window), PC**: no `[Onboarding] HUD shortcuts unlocked` and no `first-drive controls did not open` warning (either one is a fallback that fired); every page begins and completes once (`[Tutorial] begin` / `complete` lines: 19 on touch, 18 plus the first-drive controls on PC); the highlight sits on the right control on every card; N6 and X3 advance by pressing the highlighted button; NEXT works by click, Enter and pad A; `Car`, `Garage`, `Race` unlock in that order; objective cards and the `Objective.Complete` sound; the trail (Cyan) leads to the dealership desk and later to the garage desk; nothing shows during loading, the full map, or the controls modal. Repeat on a phone preset (MobileDriving D7, D8) and with a controller.
5. **Returning profile**: no callout, no card, no trail, the three buttons usable as soon as `GetState` returns.
6. **Timing of first appearance** for pages whose parts are drawn after a fetch (race entry Setup, dealership): if a callout arrives late or needs a click, that is question 1.
7. **Chevron tint**: texture `103838921533168` tinted Cyan (spike 15 item 2); if muddy, a white chevron id goes in the overlay.
8. Gallery: `Shell.Onboarding`, `Shell.Loading`, `Shell.StartScreen` at R720, R1080, R1440, C844, C568; Largest text on the callout body.
