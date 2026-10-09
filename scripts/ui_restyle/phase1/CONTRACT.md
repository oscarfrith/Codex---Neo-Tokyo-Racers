# Pulse Phase 1: foundation and switch

Status: **draft for the delivery-reviewer; nothing installed.** Under `../CONTRACT.md` (the programme contract, "PC" below), which wins on any conflict. Interfaces are in `API.md`. Place: Space Racers v3 (93959280828322).

## Contract header

```text
System/change: first Pulse install. Latch, Routes, config, kit core, Pulse toast owner, Studio gallery,
one ClientBase edit, AGENTS.md exception text. Default stays Classic.
Delivery lane and reason: High-Risk. It installs a second owner for a surface (toasts), edits client
start-up (ClientBase), and is the first use of the installer engine and of the create op in v3 (PC 9, 10).
Goal: one value switches the session between all Classic and Classic-plus-Pulse-toasts; the kit and
gallery exist so Phase 2 can be built and reviewed; Classic is provably unchanged.
Baseline: 221 scripts, Config.UI has no attributes and no Pulse child, no UIPulse folder, ReplicatedFirst
holds only Loading (phase0/RESULTS.md, classic/manifest.json). Engine never run against the place.
Must preserve / exclusions / owners / tests / recovery: sections 5, 6, 1, 7, 8 below.
Persistence, remotes, server: none. No server script, remote, payload or saved field is touched.
Readiness scorecard: section 9.
Done when: section 7 passes, the reviewer has passed spec and diff, and Oscar accepts the gallery.
```

## 1. Owners, before and after

| Concern | Before | After, `UIStyle` Classic | After, `UIStyle` Pulse |
|---|---|---|---|
| Style for the session | none | `ReplicatedFirst.UIStyleSwitch` (answers Classic) | same latch (answers Pulse, or Classic after `Downgrade`) |
| Which module an entry name starts | ClientBase `entries` | ClientBase `entries`, unchanged | `Routes.Compose` output, built once before `lifecycle.start` |
| Toast state (cards, timers), bindable `ShowTopNotification` | `SharedTopNotificationUI` via `Foundation.CreateTopNotificationController` | unchanged | `UIPulse.Toasts.ToastClient` via `Kit.Overlay.Toast`. The Classic module is never required |
| Toast geometry and scale | Foundation (`IsMobile`, camera viewport, `GetGuiInset`) | unchanged | `Kit.Metrics` and `Kit.Layers` |
| Toast visibility | card create and destroy in `SharedTopNotification` | unchanged | pooled cards, root `Visible`. No `ScreenGui.Enabled` write |
| Confirmations | `Foundation.Confirmation` (callers: both Classic HUDs, `RacingUIComponents`) | unchanged | unchanged in play. `Kit.Overlay.Confirm` exists but only the gallery calls it in Phase 1 |
| Gallery | none | not in the entry list | Pulse-only tool entry `PulseGallery`, Studio only, off by default |
| Preview, attachment, persistence | unchanged | unchanged | unchanged |

## 2. Instances to create (hierarchy transaction, in this order)

RS = `ReplicatedStorage`, UIP = `RS.Modules.Game.UIPulse`. Every row is a `create` op and carries the engine's install mark. ModuleScript sources go on the create op (`after/<full path>.lua`).

| # | Path | Class | Built by |
|---|---|---|---|
| 1 | `ReplicatedFirst.UIStyleSwitch` | ModuleScript | integrator |
| 2 | `UIP` | Folder | - |
| 3 | `UIP.Routes` | ModuleScript | integrator |
| 4 | `UIP.Kit` | Folder | - |
| 5-7 | `UIP.Kit.Tokens`, `.Metrics`, `.Perf` | ModuleScript | agent A |
| 8-10 | `UIP.Kit.Layers`, `.Input`, `.Contracts` | ModuleScript | agent B |
| 11-12 | `UIP.Kit.Text`, `.Surface` | ModuleScript | agent C |
| 13-14 | `UIP.Kit.Controls`, `.Collections` | ModuleScript | agent D |
| 15 | `UIP.Kit.Overlay` | ModuleScript | agent E |
| 16-17 | `UIP.Toasts` (Folder), `UIP.Toasts.ToastClient` | ModuleScript | agent E |
| 18-19 | `UIP.Dev` (Folder), `UIP.Dev.Gallery` | ModuleScript | agent F |
| 20 | `UIP.Dev.Fixtures` | Folder | - |
| 21-25 | `UIP.Dev.Fixtures.Text`, `.Surface`, `.Controls`, `.Collections`, `.Overlay` | ModuleScript | agents C, C, D, D, E |
| 26 | `RS.Config.UI.Pulse` | Folder, with token attributes | integrator (generated) |
| 27 | `RS.Config.UI.Pulse.Assets` | Folder, with asset attributes | integrator (generated) |

20 new ModuleScripts (221 becomes 241 scripts). No Script or LocalScript is created.

## 3. Attributes to add

| Instance | Name | Type | Value | Op |
|---|---|---|---|---|
| `RS.Config.UI` | `UIStyle` | string | `"Classic"` | `attribute`, before `null`, `was: ["Pulse"]` |
| `RS.Config.UI` | `UIStyleDevFamilies` | string | `""` | `attribute`, before `null`, `was: ["Toasts", "Nope"]` |
| `RS.Config.Development.ClientTools` | `PulseGalleryEnabled` | boolean | `false` | `attribute`, before `null`, `was: [true]` |
| `RS.Config.UI.Pulse` | every flat token of API.md 3.1 to 3.5, plus `PerfDebug` = `false` | Color3 / number / string / boolean | the code default | on create op 26 |
| `RS.Config.UI.Pulse.Assets` | the 20 keys of API.md 3.6 | string | `""` | on create op 27 |

- The token ops are generated, never typed: `build.py` input is the JSON of `Tokens.Flatten(Tokens.Defaults)` produced by the Edit test run (7.1). The build fails if a name, type or value in `spec.json` differs from it. Code defaults equal config by construction.
- `was` values exist so a switch or test value left behind does not block ROLLBACK. APPLY is still run only with `UIStyle = "Classic"`.
- `classic/out_verify_classic.lua` is rebuilt with `phase1/declared.json`: `scripts` (ClientBase after-hash), `addedScripts` (the 20), `configNodes` (`UI.Pulse`, `UI.Pulse.Assets`), `configAttrs` (the three in the first three rows).

## 4. The ClientBase edit (sources transaction, the only `source` op)

Against `classic/sources/StarterPlayer.StarterPlayerScripts.ClientBase.lua` (112 lines, 7,577 chars). Lines 1 to 104 and the old 105 to 112 are byte-identical; eight lines are inserted after line 104.

Before, lines 104 to 105:

```lua
local state=Instance.new("Folder"); state.Name="StartupState"; state.Parent=script
lifecycle.start(entries,function(entry)
```

After, lines 104 to 113:

```lua
local state=Instance.new("Folder"); state.Name="StartupState"; state.Parent=script
local okSwitch,switch=pcall(function() return require(game:GetService("ReplicatedFirst"):FindFirstChild("UIStyleSwitch")) end)
if okSwitch and type(switch)=="table" and switch.Style=="Pulse" then
	local okRoutes,composed=pcall(function() return require(RS:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UIPulse"):WaitForChild("Routes")).Compose(entries,switch) end)
	if okRoutes and type(composed)=="table" then entries=composed else
		pcall(switch.Downgrade,"Routes: "..tostring(composed))
		warn("[ClientBase] Pulse routes failed; Classic for this session: "..tostring(composed))
	end
elseif not (okSwitch and type(switch)=="table") then warn("[ClientBase] UIStyleSwitch unavailable; Classic for this session: "..tostring(switch)) end
lifecycle.start(entries,function(entry)
```

Invariants the reviewer checks:

1. **Classic path = today's statements plus one protected require.** With `Style ~= "Pulse"` the only new work is the `pcall(require)` and two false conditions. `entries` is the same table; the resolver (old 105 to 109) and both callbacks are untouched.
2. **One timing change in Classic, stated:** the latch's first require waits for `RS.Config.UI` (PC 1.2). ClientBase line 4 waits only for `Config.Development` today. Every Classic UI owner already waits for `Config.UI.Theme` unbounded.
3. **A missing or broken latch gives Classic, never a hang:** `FindFirstChild`, so `require(nil)` errors inside the `pcall`. ReplicatedFirst content is present before any StarterPlayerScripts script runs. A failed require and a require that returns a non-table both warn once (`UIStyleSwitch unavailable; Classic for this session`); a table whose `Style` is not `Pulse` is the normal Classic path and is silent.
4. **Pulse path:** `Compose` validates its own output (duplicates, missing dependencies, cycles, as `Lifecycle.validate` 5 to 8) inside the protected call, so `lifecycle.start` line 21 cannot throw on a composed list. `entries` is swapped only on success.
5. **Fallback keeps the Classic list and downgrades the latch,** with one warning. After it `Style` is Classic, `Active()` is false, `Claim` errors (PC 1.3).
6. **No fallback after any start.** `Downgrade` errors once any `Claim` has been made; nothing in ClientBase runs after `lifecycle.start`.
7. **No existence probe and no bounded wait** for `Routes` (PC 0). A missing `Routes` under Pulse hangs start-up; AUDIT proves it exists and the value is Classic by default.
8. ClientBase is edited once in the programme. Later families edit `Routes` only.

## 5. Family "Toasts"

Generated table: `classic/contracts/SharedTopNotificationUI.json`, `_screenguis.json`, `_reserved_names.json`. Entry name `SharedTopNotificationUI` (dependencies `{}`) is re-pathed to `UIP.Toasts.ToastClient`.

**Who depends on it (read from source):**

| Consumer | How | Consequence for Pulse |
|---|---|---|
| ClientBase entries `ActivityClient`, `GarageUI` | declared dependency; blocked if not `ready` within 30 s (ClientLifecycle 30 to 36). `DealershipIntroClient` and `GarageEntranceClient` depend on `GarageUI` | `start()` yields on no asset, font or remote and must not fail |
| `DesktopFreeRoamHudUI` 100, `MobileFreeRoamHudUI` 38 | `WaitForChild("ShowTopNotification")`, unbounded, at module load, **no declared dependency**; fire `(text, 2.2)` at 365 and 78 | none. The bindable is Studio-authored and already in `PlayerScripts.Runtime.UI` when any client script runs, so these waits cannot hang under either style; the Pulse owner adopts it |
| `ActivityClient` 60, `FullMapUI` 92, `RaceBrowserClient` 452, `OwnedGarageBrowserUI` 50 | `FindFirstChild` then `:Fire(text, seconds)` (2.4, 2.2, 2.2, 2.2) | same name, class and argument order |
| `GarageUI` 681, `GarageEntranceClient` 96 | `FindFirstChild` then `:Fire(text)` with no duration | default duration |

No module requires `SharedTopNotificationUI` or calls `CreateTopNotificationController` except the owner itself. No remote, attribute, player attribute, render step or context action is involved.

**Must honour:**

| Item | Classic value | Pulse |
|---|---|---|
| Bindable | `Players.LocalPlayer.PlayerScripts.Runtime.UI.ShowTopNotification`, a Studio-authored BindableEvent that already exists at `StarterPlayer.StarterPlayerScripts.Runtime.UI` (verified in the live place). The owner adopts it; it does not create it | same: `FindFirstChild` first, one `Event` connection, never a second bindable. Creating one only if it is truly absent is kept as a harmless guard |
| Handler | `(message, duration)` | same |
| Text | `string.upper(tostring(message or ""))`; empty ignored | same |
| Duration | `clamp(tonumber(duration) or 2.5, 0.5, 10)` | same |
| Max cards | 3 (`TopNotificationMaxCards` is absent from the config record); oldest removed first | `Tokens.Space.ToastMaxCards` = 3 |
| ScreenGui | `SharedTopNotification`, DisplayOrder 1100, `ResetOnSpawn` false, child `Stack` directly under the ScreenGui; an existing one of that name is destroyed first | same name and order; made by `Kit.Layers`; `UIStyle = "Pulse"`. **Recorded difference:** the stack is at `SharedTopNotification.Root.SlotTopCentre.Stack`, not directly under the ScreenGui. No Classic consumer reads `Stack` (verified in the live place) |
| Controller shape | `{Gui, Show, Relayout, Count}` | same four, plus the kit's `Instance`, `Set`, `Destroy` |
| Position | top centre, `max(12, inset.Y + 10)` | slot `TopCentre` (below the top bar, API.md 6) |

**No create-before-yield hazard.** An earlier draft required the bindable to be created before the first yield of `start()`. That hazard does not exist: the bindable is authored in Studio, so the HUD waits at `DesktopFreeRoamHudUI` 100 and `MobileFreeRoamHudUI` 38 return at once whichever owner runs, and whether or not it has started.

**Added (PC 2.2):** kit scale and safe area; fade in and out by transparency (no scale tween); pooled cards (0 created or destroyed after the third toast); duplicate suppression (the same text while its card is showing restarts that card's timer); measured with the real face; body role sized for the Largest text setting.

**Cold font and pooled cards.** A card's display timer starts when the card becomes visible, never before its measure. `Text.Measure` waits at most `TypeReadyTimeout` (2 s), then the card is laid out from an estimate and laid out again when the face arrives. Classic destroyed its cards; a hidden pooled card has `Visible = false` and empty label text, so a search of PlayerGui by name and text (`OnboardingClient`) cannot match one.

**Also started by this owner, each in its own task:** `Kit.Text.Preload()` and the 15-second not-ready report `Routes.StartWatch()` (PC 1.3). Neither can block or fail `start()`.

## 6. Must preserve, and exclusions

**Must preserve**

- The 220 other scripts byte-identical; ClientBase equal to its recorded after-hash; every existing config value (1,124 recorded).
- In Classic: the same entry list, order, dependencies and tool flags; `StartupState` holds the same names and statuses; no Pulse ScreenGui; no module under `UIPulse` required.
- Entry names, dependencies and order under Pulse; only `SharedTopNotificationUI`'s path changes and `PulseGallery` is appended.
- Toast behaviour in the table above. `Foundation.Confirmation` remains the only confirmation in play.
- `PlayerScripts.Runtime` as the home of bindables; LandscapeSensor; Oscar's profile (sandbox window and fingerprint, PC 10).
- No `ScreenGui.Enabled` write, no trap name, no Classic UI module required from Pulse (PC 1.5).

**Accepted risks (delivery-reviewer)**

- A toast fired after a failed Pulse start is lost silently: the Classic owner is never started in a Pulse session (by contract). Recovery is `UIStyle = "Classic"`.
- `Downgrade` stays legal until the first `Claim`.
- The engine does not state-check the attribute values (tokens) carried on a create op; only the three `attribute` ops are checked against before, after and `was`.

**Exclusions**

- Any other family, owner or screen. `GarageEntranceStatus` and the other private status labels stay Classic (Phase 7).
- `Switch`, `Stepper`, `Dropdown`, `Slider`, `Kit.Data`, `PromptBanner`, `BigNumber` sprites, `Pool` as a public API: built with the first screen that needs them.
- Asset uploads. Every `Tokens.Assets` value is `""`; each component renders from flat frames.
- Any edit to `SharedTopNotificationUI`, `ResponsiveUIFoundation`, `ClientLifecycle`, the two ReplicatedFirst scripts, or any server script. No `Theme` value read or changed.
- The core UI policy, chat hiding and `AutoSelectGuiEnabled` (Phase 3). Kit API freeze (after Phase 3).
- Publishing. Real-device checks.

## 7. Acceptance tests

Evidence goes to `phase1/verification.json`. "I" = integrator, "O" = Oscar.

### 7.1 Edit: compile and pure tests (I)

| ID | Test | Pass |
|---|---|---|
| E1 | `build.py phase1`: every after-source LF only, under 150,000 chars, compiles | no failure |
| E2 | Static lint over `after/` (API.md 11) | 0 findings |
| E3 | `phase1/tests/run_tests.lua` through `execute_luau` in Edit: loads sources as strings, fake `script` and `require`, runs every `*_test.lua` | all `ok`; nothing parented to the game tree; nothing left in `shared` |
| E4 | `Routes` test against the recorded ClientBase entry table (`classic/contracts/_clientbase_entries.json`): composed list has the same names in the same order plus `PulseGallery`; passes a copy of `Lifecycle.validate`; one path differs | as stated |
| E5 | `Routes` failure cases: unknown dev family, missing swap target, duplicate name, missing dependency, cycle | each errors; input list not mutated; `Commit` not called |
| E6 | `Tokens.Flatten(Tokens.Defaults)` equals the generated attribute ops | equal |
| E7 | `engine/selftest.lua` | 30 of 30, as in Phase 0 |

### 7.2 Installer: create proof (spec `scripts/ui_restyle/phase1_proof/`, one op)

The op creates `RS.Modules.Game.UIPulseCreateProof` (ModuleScript, source `return {}`, never required). It is not part of the Phase 1 spec and does not remain.

| Step | Who | Action | Pass |
|---|---|---|---|
| P1 | I | AUDIT | op `before`; Classic verify 221 of 221, 0 failures |
| P2 | I | APPLY, AUDIT | `after`; mark and fingerprint present |
| P3 | **O** | **Save the place, close it, reopen it.** The integrator stops here and waits | - |
| P4 | I | Rediscover the Studio instance; AUDIT | still `after`; mark attribute and source fingerprint unchanged; verify lists one declared added script and nothing else |
| P5 | I | ROLLBACK, AUDIT | `before`; instance gone; verify 221 of 221 with no declared item |
| P6 | I | APPLY, AUDIT, ROLLBACK, AUDIT | `after`, then `before` |

The integrator builds and runs 7.1 while waiting at P3. If Studio is closed without a later save, the saved place still holds the inert marked module; the same ROLLBACK removes it. The first save after P6 (step M5) persists the removal.

### 7.3 Installer: Phase 1 spec (I, except M5)

| Step | Action | Pass |
|---|---|---|
| M0 | Classic Play record, full 14 points, run a and run b in separate sessions (sandbox window open, then closed) | a equals b under the Phase 0 ignore list; else the list is extended and recorded before anything is compared |
| M1 | AUDIT | all `before`; both transactions `before`; sources compile; Classic verify clean |
| M2 | delivery-reviewer on `spec.json`, the ClientBase diff, the latch and `Routes` | pass |
| M3 | APPLY (hierarchy), AUDIT, APPLY (sources), AUDIT | `after` |
| M4 | ROLLBACK, ROLLBACK, AUDIT (`before`, verify 221 of 221), then M3 again | as stated |
| M5 | **O: save, close, reopen.** Then AUDIT | every item `after`; verify shows only the declared edit, 20 added scripts, 2 nodes, 3 attributes |

### 7.4 Play, `UIStyle` Classic (I)

| ID | Test | Pass |
|---|---|---|
| C1 | Full Play record, 14 points | identical to M0 under the ignore list |
| C2 | `ClientBase.StartupState` | same names and statuses as M0; no `PulseGallery` attribute |
| C3 | Census | 0 ScreenGuis with `UIStyle = "Pulse"`; no `PulseGallery` |
| C4 | Latch attributes on `ReplicatedFirst.UIStyleSwitch` | `UIStyleResolved = "Classic"`, reason `attribute:Classic`, no claims, not committed |
| C5 | Console | same distinct errors and warnings as M0 |
| C6 | A toast (set a route in the race menu) | Classic card |
| C7 | Spike 12: `UIStyleRawAtRead`, `UIStyleLoadedAtRead` on a cold start | raw value is `Classic`, not `nil`; recorded |

### 7.5 Play, `UIStyle` Pulse (I; set by `phase1/set_style.lua`, restored after)

| ID | Test | Pass |
|---|---|---|
| U1 | Short Play record (four points plus a toast point) against Classic | only `SharedTopNotification` differs |
| U2 | `StartupState` | all Classic names `ready` as in M0; `PulseGallery` = `skipped` |
| U3 | Census | exactly one Pulse ScreenGui, `SharedTopNotification`, DisplayOrder 1100, no duplicate names |
| U4 | Claim and latch | `UIStyleClaims = "Toasts"`, committed, families `Toasts` |
| U5 | Toasts from the race menu, the full map and the Classic HUD; four in a row; the same text twice | Pulse cards; at most 3; duplicate restarts the timer; all gone after their duration; churn 0 after the third |
| U6 | `layout_lint` on `SharedTopNotification` with a card showing | whole pixels, TextSize at least 14, `TextFits` |
| U7 | `ActivityClient`, `GarageUI`, both HUD entries | `ready` (bindable present in time) |
| U8 | `PulseGalleryEnabled = true`: every registered item, every state, at R720, R1080, R1440, C844, C568, with assets empty | `GalleryMounted` matches and `GalleryError` is empty for each; one capture per item and preset |
| U9 | `layout_lint` and `instance_census` on the gallery stage per item | no fractional geometry, text at least 14, `TextFits` with the longest fixture, targets at least 48 dp on C presets, budgets of API.md 7 |
| U10 | `Kit.Overlay.Confirm` in the gallery: Escape, ButtonB, NO focused with keyboard or pad, once-only close, focus restored | as `Foundation.Confirmation` |
| U11 | Forced failure: `UIStyleDevFamilies = "Nope"` | one ClientBase warning; reason `downgraded:...`; C2, C3, C6 hold; short record equals Classic |
| U12 | Title above TextSize 100 on a real display at 100% | sharp (Phase 0 spike 02 follow-up); recorded seen or open |
| U13 | Profile fingerprint before and after each session | equal |

### 7.6 Switch back, and Oscar

| ID | Test | Pass |
|---|---|---|
| S1 | I: `UIStyle = "Classic"`, `UIStyleDevFamilies = ""`, `PulseGalleryEnabled = false`; Play; short record | equals M0; C3 holds |
| S2 | I: AUDIT | all `after`; sandbox attribute back at its earlier value |
| S3 | **O**: sets `UIStyle` to `Pulse`, opens the gallery, then sets it back | accepts the gallery (blocking gate, PC 9) |

## 8. Recovery

1. `Config.UI@UIStyle = "Classic"`. Absolute; needs no installer.
2. Phase ROLLBACK, in the engine's order: **run 1 sources** (ClientBase back to its before-source), AUDIT; **run 2 hierarchy**, ops in reverse (attributes removed, `Config.UI.Pulse.Assets`, `Config.UI.Pulse`, fixtures, `Dev`, `Toasts`, `Kit` modules, `Kit`, `Routes`, `UIPulse`, the latch), AUDIT `before`. Then the Classic verify built without `declared.json`: 221 of 221, 1,124 values. ClientBase never refers to a latch that is gone, because sources go first.
3. Roblox version-history restore to the recorded Phase 0 version, if several unrelated things are wrong. Never the Exotic ROLLBACK.

ROLLBACK refuses if a created instance has an unmarked child; remove nothing by hand. The proof spec has its own ROLLBACK.

## 9. Readiness scorecard

| Area | State | Note |
|---|---|---|
| Ownership | PASS at gate | section 1; census and `Claim` |
| Security | N/A | client presentation only |
| Data | N/A | no saved field or id |
| Lifecycle | PASS at gate | owners start once; components release through `ConnectionScope` |
| Performance | PASS at gate | toast churn 0; gallery census against budgets. Frame cost not claimed |
| Mobile/input | DEFERRED | Compact by emulated frame only; real phone needs a publish (Phase 3) |
| Streaming | N/A | PlayerGui only |
| Failure handling | PASS at gate | U11; no fallback after start |
| Observability | PASS at gate | latch attributes, `StartupState`, 15 s report |
| Documentation | PASS at gate | `verification.json`, docs 00, 06, one 07 entry |

## 10. Build split

Agents work only in `phase1/work/<agent>/` (`after/`, `tests/`, `NOTES.md`), never in Studio or git, and code against `API.md` only. All six start together; none waits for another's source.

| Agent | Folder | Files (instance names) |
|---|---|---|
| A | `work/a_tokens_metrics` | `Kit.Tokens`, `Kit.Metrics`, `Kit.Perf` and their tests |
| B | `work/b_layers_input` | `Kit.Layers`, `Kit.Input`, `Kit.Contracts`, `gen_contracts.py` (from `classic/contracts/`), tests |
| C | `work/c_text_surface` | `Kit.Text`, `Kit.Surface`, `Fixtures.Text`, `Fixtures.Surface`, tests |
| D | `work/d_controls` | `Kit.Controls`, `Kit.Collections`, `Fixtures.Controls`, `Fixtures.Collections`, tests |
| E | `work/e_overlay_toasts` | `Kit.Overlay`, `Toasts.ToastClient`, `Fixtures.Overlay`, tests |
| F | `work/f_gallery` | `Dev.Gallery`, `tests/run_tests.lua` (the harness), the static lint script |

Integration order (dependency order): Tokens, Contracts, Perf; Metrics; Layers, Text; Surface, Input; Controls, Collections; Overlay; ToastClient; Gallery.

**Integrator:** this contract and `API.md`; the latch, `Routes`, the ClientBase after-source, `spec.json`, `declared.json`, `set_style.lua` (guarded, records and restores), the proof spec; copies agent files into `phase1/after/` and `phase1/tests/`; resolves API mismatches by amending `API.md` first; every Studio step, capture, Play test and measurement; the reviewer runs; the AGENTS.md text; docs; git.

## 11. AGENTS.md exception text (repo edit, added under "Durable rules")

```text
- Pulse UI backup exception (owner: Oscar; ends at Pulse Phase 10). Two UI sets are installed. One value,
ReplicatedStorage.Config.UI@UIStyle, read once per session by ReplicatedFirst.UIStyleSwitch (a Config
attribute, not Core.FeatureFlags), chooses Classic or Pulse; each surface has exactly one running owner
and Pulse owners live under ReplicatedStorage.Modules.Game.UIPulse. Classic UI scripts are frozen and
hash-checked (scripts/ui_restyle/classic). A delivery that must change one, or a payload or config value
Classic reads, runs the Classic verify and a Classic smoke check and lands in both sets. Review at the
default flip (Phase 9) and at each such delivery. Contract: scripts/ui_restyle/CONTRACT.md.
```
