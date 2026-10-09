# Pulse UI rebuild: programme contract

Status: **Approved by Oscar 2026-10-09; Phase 0 in progress.** Nothing is installed yet.
Place: Space Racers v3 (93959280828322). Names used: **Classic** = today's UI, **Pulse** = the new UI.
This is `design/recommended-plan.md` made binding, with the corrections of `design/fact-check.md` folded in (appendix D) and Oscar's decisions applied. Where the two differ, this file wins. Each phase adds its own `CONTRACT.md` under this one.

Inputs: the style sheet and mockups 01, 02, 04, 05; the sixteen audit notes; proposals A (safest backup), B (most cohesive), C (quality and speed); the three adversarial reviews; the fact check against live v3 source.

Labels used below: **[live]** read from live v3 source for the plan or the fact check; **[review]** confirmed live by a reviewer; **[note]** from an audit note, read from source, not seen in Play; **[spike]** unverified, settled in Phase 0 before anything depends on it.

## Contract header

```text
System/change: Pulse, a second complete UI set built from one shared kit beside Classic, chosen once
  per session by Config.UI@UIStyle. Classic is removed in Phase 10 once Pulse is confirmed complete.
Delivery lane and reason: High-Risk programme. It adds a second owner for every UI surface, edits
  client start-up (ClientBase, two ReplicatedFirst scripts), draws price, Cash, purchase, spawn, queue
  and result displays, and ends in a retirement. Lane per phase is in section 9.
Goal: every screen reads as one product, scales and aligns on every device, costs less than Classic,
  and can be switched back to Classic by one value until Phase 10.
Current confirmed baseline: v3, 221 scripts, all UI built in code. Config.UI has no attributes and no
  Pulse child; no UIPulse folder; ReplicatedFirst holds only Loading (fact check, 2026-10-09).

Required changes: sections 1 to 8, delivered by the phases in section 9.
Must preserve: every flow, remote, payload, saved field and page id; server authority over price,
  Cash, purchase, spawn, queue and results; the single owners in 2.3; Classic byte-identical apart
  from the five edits in 1.6, and proven so at every gate (1.8); LandscapeSensor; Oscar's profile.
Explicit exclusions: section 11.

Canonical owners:
- State: per surface, the Classic owner or its Pulse owner, never both (1.5). The latch
  ReplicatedFirst.UIStyleSwitch owns the style for the session; Routes owns which module an entry
  name starts.
- Geometry/visibility: Kit.Layers and Kit.Metrics for Pulse; Classic owners unchanged. Pulse never
  writes ScreenGui.Enabled.
- Preview/runtime attachment: unchanged (preview and camera modules are shared and not forked).
- Persistence/authoritative mutation: none added. No server script is edited.

Inputs, outputs and dependencies: two attributes on Config.UI, the folder Config.UI.Pulse, uploaded
  images (section 6), Creator Store Barlow. Reads existing remotes, bindables and attributes only.
Entry, transitions, exit and cleanup: per owner, through ClientLifecycle as today. Style is read once
  per session; a change takes effect on the next Play start or join.
Client/server authority and remote validation: client presentation only. Remote actions and payloads
  are generated from Classic source and compared by lint (1.7).
Stable IDs, saved schema/API version and migration impact: none. Onboarding page ids are kept.
Expected scale and bounded performance budget: section 5.2.
Mobile, touch, controller and accessibility coverage: sections 3, 4 and 5.3; built and verified
  inside each phase.
Streaming/open-world behaviour: PlayerGui only, except world prompts (7.2), which follow streaming
  through scoped listeners.
Failure, cancellation, retry and observability: 1.3.

Shared components/contracts to reuse: section 2.1 (money formatters, cash presenter, ProjectEconomy,
  BindReplicatedCash, GarageModuleCardViewModel, GarageCatalogClient, ConfigReader, ConnectionScope).
Implementation/installer and rollback approach: section 10. One canonical installer engine; AUDIT,
  APPLY and ROLLBACK per phase from repo before-sources. Recovery: set UIStyle to Classic; phase
  ROLLBACK; Roblox version-history restore to the recorded Phase 0 version. Never the Exotic ROLLBACK.

Verification matrix:
- Static/install: Classic manifest and config record in every AUDIT; fork parity; lint; save, reopen.
- Runtime transitions and cleanup: Play in both styles every phase; StartupState; ScreenGui census;
  Classic Play record (1.8).
- Multi-client/security: two-client checks if the tools can drive them [spike]; else fixtures plus
  Oscar's run.
- Save/rejoin/migration: no-save sandbox with profile fingerprint before and after each session.
- Device/performance/streaming: capture matrix and probes (5.3); real-device frame cost needs a
  publish, which is Oscar's action.

Readiness scorecard exceptions or deferred risks: the switch reads a Config attribute, not
  Core.FeatureFlags (1.1); two UI sets exist until Phase 10 (1.8); appendix C lists what is unverified.
Done when: Oscar has confirmed Pulse complete, the default is Pulse (Phase 9) and Classic has been
  retired on his go (Phase 10).
```

## Oscar's decisions, 2026-10-09

He accepted every recommendation. As applied here:

- Pulse is a second UI set beside Classic. Classic stays installed but inactive as the backup, and **is removed once Pulse is confirmed complete** (Phase 10, a separate High-Risk scope that needs his go).
- Typeface: **Barlow** (Creator Store `rbxassetid://12187372847`). The Phase 0 capture is for metrics only, not a choice.
- One shared kit. One scaling rule, with real phone layouts. Image digits for big numbers.
- Roblox player list, health bar and backpack hidden. Chat hidden in full menus. Custom interact prompts if the spike passes.
- Customise becomes tabs after he signs off the flow in the gallery.
- Agent Play tests use the Studio no-save sandbox (`Config.Player.Onboarding@StudioVehicleSandboxEveryPlay`), opened by a guarded script and restored after each session.
- The phases are approved as one plan. His sign-off blocks only at Phases 0, 1, 7, 8 and 9 (and 10).
- The game is an unreleased prototype, so **no live kill switch and no preview user list**. `PulsePreview`, `UIStylePreviewUserIds`, `UIStyleForceClassic`, `UiStyleProjectionServer` and the ServerBase edit are dropped. Non-blocking confirmations happen by Oscar setting `UIStyle` to `Pulse` in Studio. Publishing remains his action.

---

## 0. The contract in one page

**Base.** Two of the three reviewers rank proposal C first (platform and performance; completeness and UX) and the third ranks it second. The contract starts from C and changes it as follows.

| Taken from | What |
|---|---|
| C | Spike before any install; pilot on the race menu; headless model plus kit view per owner; gallery with fixtures; the probe set and budgets; phone compositions drawn on their own; tabs in the garage; one read-only getter in RouteGuide; own Pulse map layers |
| A | The switch latch in ReplicatedFirst; switch attributes on the existing `Config.UI`; proof that Classic is unchanged (221 script hashes, typed config dump, Play record); generated forks with automatic parity checks; garage and owned garage as one unit; 9-slice glow as the default; selection image per component; sandbox test window; two install transactions |
| B | Layout class from geometry only; the engine owns the safe area; scale snapped to steps; anchored slots; roles, not colours; `Claim`; counters published as attributes; one HUD owner; widest core UI policy; profile fingerprint |

**What the owner gets.** One new UI set built from one shared kit, chosen once per session by one value. Classic stays installed, frozen and hash-checked. Five existing scripts get a small reviewed edit; the other 216 of 221 stay byte-identical (no ServerBase edit: the kill switch is dropped). The default stays Classic until Oscar flips it in Phase 9. Classic is retired in Phase 10, a separate High-Risk scope, once he has confirmed Pulse complete.

**Where reviewers disagreed, and what this contract does.**

| Question | Positions | Decision and reason |
|---|---|---|
| Pilot screen and order | Rules review: toasts as pilot, HUD first, race menu and entry together, because Classic touch menus force `ScreenGui.Enabled` on every other ScreenGui. Platform and completeness reviews: race-menu pilot, then HUD | **Race-menu pilot.** The forced-Enabled branch is unreachable with live config **[live]**: `touch = touchDevice and not scaledDesktop` (RaceBrowserClient 27, RaceEntryPresentationClient 31) and `IsEnabled` returns true on touch while `Config.UI.Racing.MobileScaledDesktop@Enabled` is not false (it is true). All devices use `FreeRoamHudPresentationMode`. The gate still tests it on touch |
| Garage navigation (hub to tabs, Shop/Owned) | Rules review: like for like first, tabs as a later phase that can be declined. Completeness review: tabs in the garage phase, accepted in the gallery first | **Tabs in the garage phase.** The previews are the target and a Pulse hub would be throwaway view work. Purchase safety does not depend on where buttons sit: it comes from a generated action and payload table, and from comparing the saved end state after the same purchase sequence in Classic and Pulse. Oscar accepts or rejects the navigation in the gallery before the controller is written |
| Edited scripts: four or five | Rules review: four. Completeness review: five, adding a token seam for the race fade label | **Five.** The label is the only UI in a module nobody should fork (it owns staging acknowledgement and camera). About four lines, with the exact Classic statements kept as the Classic branch, reviewed. If it cannot be done in six lines or fewer it is left and recorded as an exception |
| Per-family switch-back | Completeness review and A: any family can be held on Classic. Rules review: two supported states only | **Two supported states.** Every extra mix is another product to test, and several mixes are broken by construction (Classic HUD beside a Pulse map shows MAP NOT AVAILABLE). The retreat is the whole switch, which is proven at every gate. A Studio-only diagnostic can hold later families on Classic in delivery order |
| Missing-module safety net | Rules review: one existence check after `game:IsLoaded()`. Platform review: no probes, no bounded waits | **No run-time existence check.** The style comes from the attribute alone. The resolver already waits without a bound (`WaitForChild`, ClientBase 107 **[live]**). The installer AUDIT and a pre-publish check prove every routed module exists. A new wait would delay driving and audio owners under Pulse and its cost is unmeasured |
| Minimap renderers | Rules review and A: reuse the shared `MapIconLayer` and route renderer. Platform review and C: own Pulse layers | **Own Pulse icon and route layers** over the shared data modules. The shared renderers write per marker every frame and hold 4 instances per route segment **[note]**, cannot scale icons, and the chip takes an `Enum.Font`. They are view code over shared state, so the drift risk is cosmetic |
| Who sees on-screen pedals | Completeness review: touch laptops should not get them. B: follow `TouchEnabled` | **Follow `TouchEnabled`, as Classic does.** The touch controls are the only writer of driving input and are forked with their input code unchanged. Hiding pedals by preferred input changes driving input and is listed as out of scope |
| Private test place | B and platform review: yes, for a live client. Rules and completeness reviews: not as the test route | **Not the test route.** Game testing uses the existing Studio no-save sandbox. It is off in v3 today (attribute false **[live]**), so each agent session opens it with a guarded Edit write and restores it afterwards (section 10). A blank private experience holding only the spike harness, for real-device rendering facts, stays optional and needs Oscar to publish it |
| PB-01 fix | C and rules review: fix before time-trial finishes. Completeness review: not inside a UI programme | **Not in this programme.** Agents never cross a time-trial finish; results are checked from fixtures and the Quit path |

---

## 1. Switch model

### 1.1 Where the value lives

Attributes on the existing folder `ReplicatedStorage.Config.UI` (it has no attributes and no `Style` or `Pulse` child today **[live]**). The loading script already waits for this folder's child at its line 13 **[live]**, so no new wait is added. That attributes are present when the instance arrives is standard replication behaviour, **[spike]** to confirm at ReplicatedFirst time on a cold start.

| Attribute | Type | Meaning |
|---|---|---|
| `UIStyle` | string | `"Classic"` or `"Pulse"`. Absent or anything else means Classic |
| `UIStyleDevFamilies` | string | Honoured in Studio only. Limits Pulse to the first N delivered families, in delivery order, for fault finding |

There is no preview list, no third state and no force-Classic attribute. Oscar looks at Pulse by setting `UIStyle` to `Pulse` in Studio and pressing Play; setting it back to `Classic` is absolute.

This is a recorded exception to "live-tunable behaviour reads Core.FeatureFlags": that module is `ServerStorage.Modules.Core.FeatureFlags` and no copy exists under ReplicatedStorage **[live]**. Precedent: FEEL-01.

### 1.2 Who reads it and when

One new module, the latch: `game.ReplicatedFirst.UIStyleSwitch` (about 80 lines, no dependencies).

- It is in ReplicatedFirst so the loading script and ClientBase get the same module and the same answer.
- First require: waits for `ReplicatedStorage.Config.UI`, reads the attributes once, stores the result. A later change is ignored for the session.
- API: `Style` ("Classic" or "Pulse"), `Reason`, `Active(family)`, `Claim(surface)` (asserts Pulse and that the surface is unclaimed), `Downgrade(reason)` (1.3), `Report()`.
- It writes its result as attributes on its own ModuleScript, so a probe can read it without a require. In Classic nothing else is written anywhere.

Route data: `ReplicatedStorage.Modules.Game.UIPulse.Routes` (data plus pure functions). It holds the ordered list of delivered families, each entry name's Pulse path, and the Pulse-only entries. `Routes.Compose(entries, state)` returns a new entry list with the same names and dependencies and swapped paths, checks it against the rules of `Lifecycle.validate` (duplicate names, missing dependencies, cycles) and errors on a violation. `Routes.Resolve(entryName)` returns the module currently routed for an entry name, so a Pulse owner that must reach a surface whose family is still Classic never names a Classic path (1.5 rule 7). Each family delivery edits `Routes` only, so **ClientBase is edited once**.

### 1.3 Supported states and failure rules

- **Two supported states:** all Classic, or every delivered family Pulse. During the build "Pulse" means "every family delivered so far"; that set is the state tested at each phase gate.
- **No timing-based fallback and no partial fallback.** The style never depends on what has replicated.
- **One fallback, and it downgrades the latch.** ClientBase runs `Compose` (which validates its result) in one protected call before `lifecycle.start`. `Lifecycle.validate` itself runs unprotected inside `lifecycle.start` (ClientLifecycle 21, asserts at 5 to 8 **[live]**), so an invalid composed list that reached it would stop every client entry; that is why the check is inside the protected call. If `Routes` cannot be required, or `Compose` errors, ClientBase calls `UIStyleSwitch.Downgrade(reason)`, keeps the Classic entry list and warns once.
- **`Downgrade`** is one-way and callable only before `lifecycle.start`. After it `Style` is Classic, `Active()` is false for every family and `Claim` errors. Every other reader of the latch calls `Active()` at the moment of use and never caches the answer (RaceTransitionClient from Phase 5), so it follows the downgrade.
- **Residual from Phase 8.** The two ReplicatedFirst edits read `Active("Shell")` before ClientBase runs. After a downgrade the loading view and start screen already on screen finish that cold start in Pulse while everything ClientBase starts is Classic. Each surface still has one owner. It is a reported failed state (`Reason`, one warning), not a supported one. The installer AUDIT runs `Compose` against the recorded ClientBase entry table, so reaching it means a damaged install. The Phase 8 contract either accepts this residual or moves the check into the latch; that is decided there with the reviewer.
- **No fallback after any `start()` has begun.** A Pulse owner that fails shows `failed` in `ClientBase.StartupState`, as a Classic owner does today. Starting the Classic owner on top of a half-started Pulse one would be two owners.
- **`start()` never waits on assets.** ClientLifecycle gives up on a dependency after 30 seconds and blocks its dependants (30 to 36 **[live]**). The Pulse toast owner and garage owner are dependencies of ActivityClient, DealershipIntroClient and GarageEntranceClient. Font and sheet preload is started by the first Pulse owner in its own task and is non-blocking; no Pulse `start()` yields on `Kit.Text.Ready`, an asset or a remote reply.
- **Observability, not fallback:** under Pulse a delayed check lists any routed entry still not `ready` after 15 seconds and warns once.
- Whether ClientBase can run before ReplicatedStorage has fully arrived is **[spike]** (ClientBase 3 and 4 already index `.Core.ClientLifecycle` and `.ClientTools` without waiting, and work today). The design does not depend on the answer.

### 1.4 What a first joiner gets, and how Oscar switches back

- A first joiner on a fresh server gets the value saved in the published place. There is no server snapshot to race.
- **Studio:** set `Config.UI@UIStyle` to `Classic`, press Play. One value. Two guarded one-line scripts in the repo do the same. This is also how Oscar makes the non-blocking confirmations: set it to `Pulse`, Play, set it back.
- **Published place:** the game is an unreleased prototype with no live players, so there is no kill switch, no server projection and no live preview. A publish carries whatever value is saved; publishing is Oscar's action. If the game is released while Classic still exists, a no-publish switch is a new scope.
- **Whole programme:** every phase has AUDIT, APPLY and ROLLBACK built from repo before-sources. A Roblox version-history restore to the recorded Phase 0 version is the cleaner route if several unrelated things have gone wrong.

### 1.5 How old and new are kept from both running

1. One latch, read once, shared by ReplicatedFirst and ClientBase.
2. One entry name, one path. `ClientLifecycle` requires exactly one module per entry (lines 38 to 44 **[live]**). The other module of a pair is never required: it runs no line, builds no ScreenGui, binds nothing.
3. Entries are re-pathed, never skipped: a dependency that is not `ready` blocks its dependants (ClientLifecycle 36 **[live]**).
4. Every Pulse owner calls `UIStyleSwitch.Claim("<surface>")` first.
5. Pulse reuses the ScreenGui names other scripts look up or destroy on start, so two cannot coexist silently.
6. Every Pulse ScreenGui carries the attribute `UIStyle = "Pulse"`. A census at every gate: none in Classic; in Pulse each delivered family has its own and no duplicate names.
7. Build lint: no Pulse module requires a Classic owner, `GarageComponents` or `RacingUIComponents`, or names a Classic owner's path; no Classic script names a `UIPulse` path. Where Pulse must open a surface whose family is still Classic, it goes through `Routes.Resolve`. The known case is Phase 3: the Pulse HUD opens the full map by click, and until Phase 4 the map is Classic `FullMapUI` (the Classic HUDs require it and call `Open()` at DesktopFreeRoamHudUI 960 and MobileFreeRoamHudUI 260 **[live]**).
8. **Pulse owners never write `ScreenGui.Enabled`.** They show and hide with a root `Visible`. This keeps them clear of every save-and-restore owner (TrailerModeClient today; the Classic touch menus if `MobileScaledDesktop@Enabled` were ever set false) and satisfies FullMapUI's check that the HUD ScreenGui is enabled (465 to 467 **[live]**).

### 1.6 Existing scripts that are edited: the exact list

| # | Script | Phase | Edit | Why nothing smaller works |
|---|---|---|---|---|
| 1 | `game.StarterPlayer.StarterPlayerScripts.ClientBase` | 1 | About eight lines between 104 and 105: protected require of the latch; when Pulse, one protected call that requires `Routes` and runs `Routes.Compose(entries, state)`, which validates the composed list; `entries` is swapped only on success, otherwise `Downgrade` and the Classic list (1.3). Resolver 105 to 109 untouched. Edited once | It is the only code that turns an entry into a module **[live]**. Validation has to happen here because `Lifecycle.validate` throws inside `lifecycle.start` |
| 2 | `game.ReplicatedStorage.Modules.Game.UI.RouteGuide` | 3 | One additive read-only function after line 91: `GetRouteState()` returning route points, version, progress and remaining distance | `route` and `progress` are private locals (36 to 38 **[live]**); only `GetActive()` is public. No behaviour change for Classic |
| 3 | `game.ReplicatedStorage.Modules.Game.Racing.RaceTransitionClient` | 5 | About four lines at 57 to 72: when the latch says Pulse, the fade label takes font, colour and size from Pulse tokens; otherwise today's literals | It owns the staging acknowledgement, the camera and the loading generation and must not be forked **[note]**. Its one label is a font literal |
| 4 | `game.ReplicatedFirst.Loading.LoadingTransitionRuntime` | 8 | Line 8 only: require `LoadingScreenViewPulse` when `UIStyleSwitch.Active("Shell")`, else `LoadingScreenView` | The view is required at module load **[live]** and the runtime must stay the one singleton (input gate, audio duck, presentation state) |
| 5 | `game.ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient` | 8 | One guard after line 18: when `Active("Shell")`, run `StartScreenPulse` and return | It auto-runs outside ClientBase. Exactly one start-screen flow may call `Begin` and set `StartScreenActive`. The guard goes after the `StartScreenEnabled` early return (15 to 18 **[live]**) |

Five scripts are edited and 216 of 221 stay byte-identical. With `UIStyle` Classic each edited script runs the same statements as today plus one protected require of the latch (script 2 gains one function nobody calls). RaceTransitionClient has no `require(` today **[live]**, so its latch require is new code in that script and is read at use, not at load. The delivery-reviewer runs on every one of these edits.

**Not edited**, although the audit or a proposal suggested it: `RacingUIComponents`, `GarageComponents`, `ResponsiveUIFoundation`, `UITheme`, `GarageWorkspaceUI`, `OwnedGarageWorkspaceUI`, `OwnedGarageClient`, `SharedTopNotificationUI`, `ActivityClient` and the five activity views, `OnboardingClient`, `MapIconLayer`, `MapMath`, `FreeRoamMapPlayerMarkers`, `MobileDriveControlsClient`, `GarageEntranceClient`, `TimeTrialServer` and every other server script. No value in `Theme`, `Racing`, `DesktopFreeRoamHud`, `MobileFreeRoamHud`, `GarageExperience`, `GarageReplacement`, `LoadingSystem` or the map folders changes.

**Config that is added:** the two attributes in 1.1; one new folder `ReplicatedStorage.Config.UI.Pulse`; one attribute `Config.Development.ClientTools@PulseGalleryEnabled`.

### 1.7 How each Classic owner is replaced

Three routes. No shared module is made style-aware.

| Route | Used for | Checks |
|---|---|---|
| **New owner**: headless model (state, remotes, reducers) plus kit views plus a thin `Client.start()` | Toasts; race menu; free-roam HUD (one owner for every form factor, `MobileFreeRoamHudUI` routes to a no-op as `FreeRoamVehicleExitButtonClient` already is); activity HUD; full map; race session, countdown, queue, route-guide prompt, results; race entry; garage; owned-garage browser and interior HUD; onboarding; loading view | A contract table per Classic owner, **generated from Classic source by a tool** (remote actions and payload keys, bindable fires and listens, attribute reads and writes, ScreenGui names, name and text lookups, render-step and action names, audio bridge calls). The Pulse owner declares its own list and lint compares them. Gallery fixtures for every state |
| **Logic-identical fork**: the build tool copies named line ranges of the Classic source unchanged and replaces only the listed spans | `OwnedGarageWorkspaceUI` (line 12's requires only: view, a two-function `GarageComponents` shim, a one-function `RacingUIComponents` shim); `GarageInteriorTransitionUI` (require targets); `GarageEntranceClient` (status label and `flash` become the toast); `MobileDriveControlsClient` (input, thumbstick, tilt and mode code unchanged; builders and layout new); the touch camera guard from `GarageInteriorModeUI` 48 to 270, moved into its own module with **one listed replaced span**: line 52 requires Classic `OwnedGarageWorkspaceUI` by path **[live]** and becomes the Pulse desk fork (an unchanged copy would ask a module that was never started, so `IsCameraTouchBlocked` would always be false, and it would fail lint rule 7); the start-screen flow from `InitialLoadingAndStartScreenClient` (menu builder and the `RacingUIComponents` require at line 22 replaced; the temporary `TimeoutSeconds` and artwork `Enabled` edits at 26 to 46 kept exactly) | On every build: the diff is exactly the listed spans; remote calls, bindable fires and attribute writes extracted from both sources are identical; for the touch controls every `MobileDriveInputState` write is identical. A changed Classic source stops the build |
| **Left as it is** under both styles | `RaceLifecyclePresentationClient`, `RaceEntryMenuClient`, `RaceParticipantVisibilityClient`, `RaceSessionAssetsClient`, `LoadingTransitionUI`, `DriveSessionClient`, the audio runtimes, `GaragePreviewPresentationClient`, `ThrustPreviewClient`, `RuntimeVFXClient`, `DealershipIntroClient` (its pill is off in v3), the five activity views, `MapMarkers`, `MapMath`, `MapTileSet`, `FreeRoamMapPlayerMarkers`, `GarageModuleCardViewModel`, `GarageCatalogClient`, the preview and camera modules, the dev tools | None needed |

There is no `RacingCompat` layer and no generated copy that carries Classic layout numbers. Onboarding and the garage controller are rebuilt, because a generated copy would keep Classic's borrowed scale, PlayerGui walks, full page rebuilds and preview rebuilds.

### 1.8 Proof that Classic is unchanged

| Proof | What | When |
|---|---|---|
| Source list | `scripts/ui_restyle/classic/manifest.json`: path, class, length and two hashes for all 221 scripts **[live count]**, with exact copies in `classic/sources/` | Recorded in Phase 0 |
| Config record | Typed dump of `ReplicatedStorage.Config.UI` and the UI-related service settings | Phase 0 |
| `out_verify_classic.lua` | Read-only Edit script. Recomputes both. The declared edits must match their recorded after-hash; declared config additions are listed | Inside every installer AUDIT and on demand |
| Play record | Client-side read-only snapshot at 14 fixed points: per ScreenGui name, DisplayOrder, instance count, and a hash of class, name, size, position, colour, text, font and image, with Cash, timers and ids normalised. Taken twice in Phase 0 to find unstable fields | Full run after Phases 1, 8 and 9. Short run (four points plus the surface touched) after every other phase |
| Start-up state | `ClientBase.StartupState` statuses and the set of console errors | Every phase, both styles |

**While the backup exists (until Phase 10):** Classic is frozen. If a later approved delivery has to change a Classic UI script (a new vehicle category has needed GarageUI edits before), the forks stop building on the hash mismatch, the Classic record is re-taken, and the feature lands in both sets or Oscar brings Phase 10 forward. Every later delivery that touches a payload or config Classic reads runs a short Classic smoke check. The backup and the switch are recorded in AGENTS.md as an explicit exception with owner (Oscar), review condition (the default flip, then each such delivery) and end (Phase 10).

---

## 2. The shared kit

### 2.1 Modules

All new, under `ReplicatedStorage.Modules.Game.UIPulse`. Kit modules create nothing and yield nothing when required. The build fails if any source passes 150,000 characters (limit 200,000) or any function nears the 200-local limit.

| Module | Holds |
|---|---|
| `Kit.Tokens` | Colour roles, cap heights, spacing scale, opacities, hairlines, glow, asset ids. A Luau table in git is the source of truth; `Config.UI.Pulse` holds the same values as typed attributes for tuning; read once; code defaults equal config |
| `Kit.Metrics` | The one scale, safe-area, form-factor, input and text service (section 3) |
| `Kit.Layers` | ScreenGui factory, DisplayOrder ladder (today's numbers reused), anchored slots, static and live layers, reserved and trap names |
| `Kit.Text` | `Text`, `BigNumber`, measurement cache, preload and the `Ready` signal |
| `Kit.Surface` | `Panel`, `Hairline`, `Scrim`, `Glow`, `Icon` |
| `Kit.Controls` | `Button` variants, `ButtonRow`, `Tabs`, `Switch`, `Stepper`, `Dropdown`, `Slider` |
| `Kit.Collections` | `Tile`, `Rail`, `ListRow`, `Chip`, `TierBadge`, `Pool` |
| `Kit.Data` | `StatusCluster`, `CashChip`, `StatPanel`, `SegmentedBar`, `FactList`, `Gauge`, `MinimapFrame` |
| `Kit.Overlay` | `Modal`, `Confirm`, `Toast`, `PromptBanner` |
| `Kit.Input` | Focus groups, back, bumper and trigger binding, `Mark`, audio attributes |
| `Kit.Contracts` | Generated tables: onboarding names, texts and attributes; player attributes; reserved and trap names |
| `Kit.Perf` | One frame-binding point; time and write counters published as attributes on a client-only folder when a Studio debug attribute is on |

Reused unchanged from Classic because they carry no look: the money formatters, cash presenter, `ProjectEconomy` and `BindReplicatedCash` in `ResponsiveUIFoundation`; `GarageModuleCardViewModel`; `GarageCatalogClient`; `Core.ConfigReader`; `Core.ConnectionScope`. One money formatter stays one money formatter.

### 2.2 Components

Every constructor is `Kit.X(parent, props, scope)` and returns `{Instance, Set(patch), Destroy()}`. `Set` writes only what changed. Sizes are design values; the kit converts them.

| Component | One-line contract |
|---|---|
| `Panel` | Slate at 0.86, top and bottom hairline frames, square, padding token. At most 3 instances. `Active` so it blocks camera drag |
| `Tile` | **The one shared card** for parts, vehicles, events and listings (garage rails, dealership, HUD car panel, race entry vehicle choice, owned-garage desk). A real TextButton. States: Default, Selected (white fill, ink text, pink base line, glow, inner visual 10% larger), Owned or Fitted, Locked, Unaffordable. Slot diagrams turn ink on a white tile. A designed no-image state (EXO-03) |
| `Rail` | One horizontal row, fixed cells, keyed pool, heading with count, padding reserved for glow and growth, selection group. `SetItems`, `Select`, `ScrollTo` |
| `ListRow` | Event rows, leaderboard rows, live-order rows. Selected as Tile |
| `Button` | Variants Default, Main, Buy, Danger, Icon. At most 4 instances (5 for Main). Disabled sets `Active = false`. Never under 48 dp on touch |
| `ButtonRow` | Order is always back or exit, secondary, main. Fixed offsets, no flex fill |
| `Tabs`, `Switch` | White with a pink underline when active; bumpers switch tabs, triggers switch the two-option form |
| `StatusCluster`, `CashChip` | One strip in the same slot on every screen. Cash binds `leaderstats.Cash` through the existing presenter and lives on a live layer; chip width is fixed during a count |
| `StatPanel`, `SegmentedBar`, `FactList` | Rows updated in place. The bar is tiled image strips (at most 4 instances), not twenty frames |
| `Modal`, `Confirm` | Built on first open. `Confirm` takes the same options and returns the same table as `Foundation.Confirmation`, keeps its behaviour list exactly (focus save and restore, Escape and ButtonB sunk at priority 10000, NO left and YES right, NO focused, once-only close, overlay name `SharedConfirmationOverlay`, DisplayOrder 1250), and adds 48 dp buttons, body auto-height and a clean cancel when a Classic confirmation replaces it by name |
| `Toast` | Same shape as the Foundation controller. Scale, safe area, fade, duplicate suppression, measured with the real face |
| `PromptBanner` | Action, object, key cap or gamepad glyph; on touch a real button of at least 48 dp with no key cap |
| `BigNumber` | Digit sprites in fixed cells; only changed cells are written |
| `Gauge`, `MinimapFrame` | Image arcs revealed by a rotating gradient; round CanvasGroup with ring, square fallback by config |
| `Icon`, `Glow` | One sprite sheet, tinted by role. Glow method behind one token |

**Scope of the first build.** Phase 1 builds only what toasts, confirmations, the gallery and the pilot need. Other components arrive with the first screen that uses them. The API is reviewed after the pilot and **frozen after the free-roam HUD**, not at the Phase 1 gate.

### 2.3 Contracts every component obeys

- **Roles, not colours.** A screen cannot pass a `Color3`. Named exceptions: paint swatches, medal markers, the activity theme (views assign it to parts and lights), map marker colours.
- **No coordinates in screens.** Layout is anchored slots (`TopLeft` title, `TopRight` status, `RightColumn`, `BottomRail`, `BottomRight` buttons, `BottomCentre`, `TopCentre`, `PromptStack`) inside three composition frames: `Hud`, `Scene` (garage) and `Menu` (a centred block no wider than 2:1).
- **Onboarding.** Views call `Kit.Input.Mark(instance, key)`. It applies the legacy name, text or attributes from the generated table and registers the instance for the Pulse onboarding. Views never type a tutorial name. Lint fails any other Pulse button named `Car`, `Race` or `Garage`, because Classic onboarding sets `Active` on every GuiButton with those names (OnboardingClient 666 to 671 **[live]**). Buttons show a locked look when `Active` is false.
- **Classic onboarding scale on Pulse screens.** Classic onboarding takes a callout's scale from the first `UIScale` above its target (OnboardingClient 235 to 244 **[live]**). Pulse screens have none, so from Phase 2 until onboarding is rebuilt in Phase 8 callouts on Pulse screens would use the default or the 0.6 phone value. Phase 0 reads those lines and picks the remedy (what `Mark` provides, or a recorded exception). The gates of Phases 2 to 7 check callout size and position on Regular and Compact, not only that targets are found.
- **Audio** (`PresentationAudioClient`). The GuiButton is the visible root. Disabled, locked and unaffordable set `Active = false`. Hover and press change an inner frame, never the hit box. Scrims and decorative buttons set `UIAudioHoverCue = ""` and `UIAudioSuppressClick = true`. Success and reject sounds stay with the one state owner.
- **Gamepad.** Every control is a real, selectable `GuiButton`. Focus is the selected look. The selection image is set **per component**, so Classic screens keep the default box in any mixed session. Modals trap focus and restore the previous selection. Focus is entered on open only when gamepad or keyboard navigation is the preferred input.
- **ScreenGuis.** Created only by `Kit.Layers`, at owner start, as direct children of PlayerGui. `ZIndexBehavior.Sibling`, `ResetOnSpawn = false`, the `UIStyle` mark. Never `Enabled` writes (1.5).
- **Reserved names kept** because other scripts look them up: `DesktopFreeRoamHud` (with `DesignRoot`, `ModalLayer`, `Controls`, `CarPanel`, a showing `Minimap`), `MobileDriveControls_Phase1` (`DriftLeft`, `DriftRight`, `Boost`), `ActivityHud`, `RaceBrowser` (`CardContent`, `TeleportToStart`), `RaceEntryPresentation` (`TierE` to `TierS`, `LapSelector`, `PrizeSummary`, `MedalTargets`, `RaceFormat`, the texts `TIME TRIAL` and `RACE`), `CanonicalGarageGui` > `CanonicalCanvas` > `CanonicalGarageBrowser` and `CanonicalGarageWorkspace` (and the text `DEALERSHIP`), `OwnedGarageBrowser`, `AccessControls`, `SharedTopNotification`, `SharedConfirmationOverlay`, `LoadingSafeContent` and its four children. The full list is generated, not this hand list.
- **Trap names refused** by the factory and by lint: `DriveHUD`, `TouchGui`, `DrivingSpeedEffect`, the kill list in `RaceLifecyclePresentationClient`, and descendants named `GarageRoot`, `DealershipRoot`, `CustomisationRoot`, `CustomizationRoot`.
- **Player attributes.** From Phase 3 the Pulse HUD writes `MobileFreeRoamCarMenuOpen`, `MobileMajorMenuOpen` and `MobileControlMode` as Classic does; four other scripts read the second (MobileDriveControlsClient, OnboardingClient, GarageInteriorModeUI, FullMapUI) **[live]**.
- **Camera orbit.** Full-screen tints are `Active = false`, panels `Active = true` (`PreviewCameraClient`).
- **Single owners kept.** One caller of `RouteGuide.Update` per frame; owner keys and `KeepTelemetry` values on `FreeRoamHudPresentationMode`; `CountdownPresentationReady`; `GarageSessionActive` as the only garage-open signal; bindables stay under `PlayerScripts.Runtime`.

---

## 3. Scale, safe area and form factor

One service, `Kit.Metrics`. It is the only code that listens to the viewport, camera, safe insets, top-bar inset, preferred input and text setting. It replaces the clamps 0.72 to 1.12, 1.02 and 1.15, the phone floors, the four "is mobile" tests and the three safe-area methods.

### 3.1 Three separate answers

| Answer | Rule | Changes |
|---|---|---|
| **Class** | Geometry only. `Compact` when the safe height is under 600 or the safe width under 1000 (leave Compact at 640). Otherwise `Regular`, with a width band: Narrow under 1600 logical, Wide over 2300 | Which composition is laid out. A phone with a gamepad is still Compact; a small desktop window is Compact because that is what fits |
| **Arrangement** | `TouchDrive` when `UserInputService.TouchEnabled`, the gate `MobileDriveControlsClient` uses at line 12 **[live]**. Otherwise `Standard` | Where the minimap and gauge sit. In TouchDrive the minimap is top-right and the gauge bottom-centre, because steering holds bottom-left |
| **Input** | `UserInputService.PreferredInput`, live (zero uses in the place today **[live]**) | Key caps and glyphs, focus entry, touch-target floors. Never rebuilds a screen |

One HUD owner means the double-HUD case on touch-plus-keyboard devices cannot occur.

### 3.2 Scale

| Class | Reference | Scale |
|---|---|---|
| Regular | 1920 x 1080 design values | `min(safeHeight / 1080, safeWidth / 1600)`, clamped 0.667 to 2.0, snapped down to steps of 1/24 |
| Compact | 844 x 390 dp | `safeHeight / 390`, clamped about 0.85 to 1.25; final clamps set from the phone previews |

- Examples at 100% display scale: 1280x720 gives 0.667, 1920x1080 gives 1.0, 2560x1440 and 3440x1440 give 1.333, 3840x2160 gives 2.0, a 1180x820 tablet about 0.71.
- Below the floor the canvas gets smaller, not the UI. Regular compositions are specified at 1500 x 900 as well as 1920 x 1080. Compact is drawn at 844x390, 640x360 and 568x320.
- Steps keep the set of text sizes small; many sizes fill the glyph atlas on phones. Relayout runs once after a resize settles.
- **The floor is a common case, not an edge case.** Roblox applies the operating system's display scale to offsets: a 1080p laptop at 150% reports 1280x720. Oscar's Studio reports 2065.33 x 1152 **[review]**.

### 3.3 Safe area

- Content ScreenGuis use `ScreenInsets = DeviceSafeInsets`: the engine removes notches and rounded corners. Tints and scrims sit in a sibling ScreenGui with `ScreenInsets = None`.
- Sizes are read from the ScreenGui, not from `GetInsetArea` (this project wraps that call in a silent fallback and has never seen it on a notched device).
- Top slots start below the top bar. The coordinate space of `GuiService.TopbarInset` is **[spike]**.

### 3.4 Sharpness and alignment

- No `UIScale` over chrome. Every size and offset is a rounded whole logical pixel. Hairlines are `max(1, round(n x scale))`.
- **This is best effort, not a guarantee.** A logical pixel is not a device pixel on scaled displays, and no script can read the ratio **[review]**. So: round edges and derive sizes from them, prefer even hairline and spacing values, place right and bottom clusters from a floored viewport, use no flex fill or grow, and compute centred positions instead of using scale anchors.
- The gate is a **device-resolution capture** per phase, on real displays at 100%, 125% and 150% and on a phone, not only the layout lint.
- Named `UIScale` exceptions, never animated: the design-pixel frame handed to the unchanged activity views (Duel places a 240 x 52 button in design pixels **[review]**), and a text-only holder for titles if the spike shows it is crisp.
- Ultrawide: HUD corner clusters follow the edges up to 21:9, then stay inside a centred 21:9 box. Menus stay a centred block.

---

## 4. Type and number rules

- **Roles are cap heights**, not TextSize. At the 1080 reference (sheet size x 0.70): ScreenTitle 56, SectionHead 38, HeroNumber 140, SpeedNumber 95, ButtonMain 31, Button and TileName 27 (21 on a rail of seven), Status 24, Tab 20, Value 18, Label 15. Compact has its own table, set from the phone previews.
- `TextSize = round(cap x scale / CapRatio)`. `CapRatio` is a font token (Barlow 0.583, Roboto Condensed 0.607, Titillium Web 0.447 **[note]**). Changing the face is a token edit.
- **Floor:** TextSize 14 on every device. Label is 17 at 1280x720 and 26 at 1080p with Barlow.
- **TextSize stops at 100** **[review, probed]**. With Barlow, ScreenTitle reaches 100 at scale 1.04, SectionHead at 1.54, ButtonMain at 1.88. So titles are affected from just above 1080p, including on Oscar's own screen.
  - Numbers (speed, results cash and XP, race position, countdown, timers) use `BigNumber` sprites drawn offline from Barlow Condensed ExtraBold Italic. Two authored sizes, about ten digits per sheet plus a punctuation sheet. Cell sizes are estimates until measured from the offline render in Phase 0 (section 6).
  - Words above 100: the spike compares TextSize 100 in a static holder against simply capping the role at 100. If the holder is soft, titles stop growing at 100. **No home-made text renderer** (a caps sprite sheet with a kerning table) is built.
- **Changing numbers that are not sprites.** Barlow's digits are proportional. The cash chip keeps a fixed width during a count. `OpenTypeFeatures = "tnum"` is **[spike]** and not relied on.
- Italic labels get right padding of 0.2 x cap. A `BaselineShift` token centres capitals (Barlow sits about 4% low).
- No `TextScaled`. `AutomaticSize` only on static text. Text is never under an animated scale and TextSize is never tweened. At most twelve distinct text sizes on screen.
- **Measurement.** A Creator Store face can only be measured after it has loaded. A screen's first show waits for `Kit.Text.Ready` or 2 seconds and relays out when the face arrives. A family that fails to load falls back to Roboto Condensed with one warning.
- **Player Text Size setting.** The engine scales ordinary text itself; the kit adds no multiplier of its own. Body roles (Label, Value, sentences, toasts, modal bodies, prompt banners) grow in containers sized for the largest setting. Display roles and fixed chips carry a `UITextSizeConstraint`, counted in the instance budgets. Every gate includes a pass at Largest. The multipliers are **[spike]**.

---

## 5. Performance

### 5.1 Rules

1. **Static and live layers.** A ScreenGui re-renders whole when any descendant changes. Each surface has a static ScreenGui and, where something changes at 1 Hz or more, a live one above it (gauge, minimap canvas, timers, cash count, progress bars).
2. **Pooling.** Rails, lists, order rows, result rows and toasts are keyed pools kept parented. A selection or data change creates and destroys nothing.
3. **Lazy modals and pages.** Built on first open. About 420 of today's 610 desktop HUD start-up instances are modals most sessions never open **[note]**.
4. **Per-frame code** may not call `FindFirstChild`, `WaitForChild`, `GetAttribute`, `GetDescendants` or `Instance.new`. Config is cached at start. Lint checks functions bound through `Kit.Perf`.
5. **Write on change.** Speed changes with the integer, gauge angle in half degrees, boost in whole percent.
6. **Frame loops run only while their layer is shown**; they are disconnected when hidden.
7. **No polling for presence.** Menu state comes from the attributes and bindables that already exist. No timer walks PlayerGui or Workspace.
8. **Fetch first, then draw; one render token per screen.** A late reply cannot draw into a newer page (removes the race-entry stale-page and duplicate-footer defects).
9. **The 3D preview is rebuilt only when its input changes** (today every upgrade-card select and paint-channel switch rebuilds it **[note]**).
10. **Own map layers.** Route line: at most 64 pooled segments, clipped to the view in code. Icons: pooled, compared before writing, scaled with the screen. Both read the shared `MapMarkers` and `RouteGuide` state.
11. No structural `UIStroke`, no bevel, `UICorner` only on the minimap, one CanvasGroup.

### 5.2 Budgets

Initial targets. Classic figures are the audit's readings from source; Phase 0 measures them and the measured numbers become the baseline. The sheet's "within 10% of today" is dropped.

| Measure | Classic today (from source) | Pulse budget |
|---|---|---|
| Free-roam HUD at start, Regular (static plus live) | about 610 | at most 260; modals 0 until opened |
| Free-roam HUD, Compact | about 170 plus modals | at most 220, touch controls excluded |
| One HUD modal | 100 to 210, built at start | at most 120, built on first open |
| Garage page | 300 to 330 rebuilt on every click | at most 240 live; 0 created or destroyed on a selection |
| Race menu | about 70 rebuilt per row click | at most 150; 0 per click |
| Race entry page | 97 to 250 rebuilt per click | at most 220; 0 per click |
| In-race HUD | 42 rebuilt per event | at most 140; 0 per event |
| Results | 105 to 145 rebuilt per update | at most 150; rows pooled |
| Minimap route layer | 400 to 1,200 (4 per segment) | at most 64 |
| Writes to the static HUD layer over 10 s of driving | not applicable | 0 |
| Writes per frame on the live HUD layer, parked, **shared modules included** | about 14 unconditional plus map and gauge writes | 0 from Pulse code; anything from a shared module is reported |
| Writes per frame on the live HUD layer, steady drive, shared modules included | 32 gauge writes plus about 14 | median at most 16 |
| Config or attribute lookups per frame in Pulse code | about 45 while driving | 0 |
| Distinct text sizes on screen | not measured | at most 12 |
| Glows on screen; translucent full-screen layers on Compact | none | at most 12; at most 2 |
| Instances per button, panel, tile, segmented bar | 7, 4 to 9, about 17, 32 for the gauge | 4 (5 main), 3, 12, 4 |

Legibility and alignment: smallest text TextSize 14; every active button at least 48 x 48 dp with 8 dp between targets on touch devices; contrast at least 4.5:1, or 3:1 for large capitals; `TextFits` true with the longest fixture strings at the largest text setting; whole logical pixels; cluster edges on the margin tokens; free-roam HUD panels cover at most 12% of the screen at 1080p and 18% on a phone.

### 5.3 How they are measured

All by the integrator in Play through read-only client probes run with `execute_luau`. No gameplay module is required. Classic and Pulse are measured in separate sessions.

- `instance_census`: descendants per ScreenGui by class, plus counts of strokes, gradients, corners, shadows, CanvasGroups and distinct text sizes.
- `churn_probe`: `DescendantAdded` and `DescendantRemoving` under a layer across a scripted interaction.
- `write_probe`: `Changed` on every instance of a layer for 10 seconds, static and live layers separately. This counts from outside the code under test, so shared modules are included.
- `layout_lint`: whole-pixel geometry, hairline thickness, minimum TextSize, `TextFits`, 48 dp targets, margin equality, overlap, HUD cover, reserved and trap names, missing mark.
- `perf_sample`: 20-second samples at a fixed spot and on a fixed drive, three runs per style, median and 95th percentile. The comparison is against Classic's own run-to-run spread, not sample by sample.
- Script time: `debug.profilebegin` labels around Pulse frame steps. A Classic comparison is made only if the Classic step can be isolated in a MicroProfiler capture **[spike]**; otherwise it is reported for Pulse alone.
- **Phone frame cost is claimed only from a MicroProfiler capture on a real device.** The emulator proves layout, not speed.
- Capture matrix per family: 1280x720, 1366x768, 1920x1080, 2560x1440, 3440x1440, 3840x2160, tablet 1180x820, phones 844x390 with a notch, 640x360, 932x430 and 568x320, then a gamepad pass and a Largest-text pass. The viewport and display scale are recorded with every capture.

---

## 6. Fonts and assets

- **Typeface: Barlow, decided.** ExtraBold Italic for display and SemiBold Italic for labels, Creator Store `rbxassetid://12187372847`. Barlow Condensed (the mockup face) is not in Roblox and fonts cannot be uploaded. Phase 0 still draws the Customise screen in Barlow at three desktop sizes and a phone, but only to measure: cap ratio, baseline shift, widths against the mockups, TextSize 100 behaviour, `tnum`. Its costs are about 22% more width than the mockups and proportional digits, both handled above. Roboto Condensed is the load-failure fallback only. If Roblox adds Barlow Condensed the swap is one token.
- **Preload.** Every italic face is a cloud asset. Faces and sheets are preloaded by the first Pulse owner, and from Phase 8 by the Pulse loading view. `PreloadAsync` for font faces on a cold cache is **[spike]**.
- **Icon sheet.** One 1024 px sheet, 128 px cells, every glyph pure white in the same ink box, alpha-bled. Existing white glyphs are exported and re-centred (their padding varies from 75% to 100% today); missing and baked-colour ones are drawn (pin, set route, tick, loop, gamepad, upgrade arrow, coin, lock, boost, trophy, route, laps, checkpoints, players, chevrons, plus, close, north marker, key cap, gamepad glyphs).
- **Glow.** Default: three static 9-slice images, which work on every client. `UIShadow` is reported released on 2026-06-23 but is unverified on a live phone; it becomes the default only after it is seen on a live phone and PC client. The method is one token.
- **Gauge.** Ring images revealed by a rotating linear gradient. Radial gradients are Studio Beta and are not used. A segmented arc is the fallback if the capture shows a seam.
- **Map icons.** The 14 map icons have baked colours and cannot be tinted. Recommended: a redrawn white set tinted by role, so both maps match the palette. Classic keeps its ids.
- **Uploads, one batch from one contact sheet, each needing Oscar's yes:** icon sheet; three glow slices; two or three digit sheets; gauge ring and tick ring; minimap ring and vignette; title mark, chequered corner and key cap; white map player arrow; recoloured map icons; four touch-control images redrawn white. About 14 to 18 files. Ids go to `Config.UI.Pulse.Assets` and `scripts/ui_restyle/assets/uploaded_assets.json`. No existing asset id changes. Uploads cannot be edited; each revision is a new id.
- **Offline rendering.** Digit sheets and drawn icons are rendered by headless Chrome from an HTML page that uses the Google Fonts web face (Barlow Condensed ExtraBold Italic for digits), then cut to sheets. No font file is downloaded or kept in the repo, so no separate approval is needed for one.
- Uploads are made at the end of Phase 0 so moderation finishes before Phase 1 needs them.

---

## 7. Roblox core UI and world prompts

### 7.1 Core UI policy

One Pulse-only owner, `UIPulse.Shell.CoreUiPolicy`, added by `Routes` in Phase 3. In Classic the module is never required, so Classic is exactly as today.

| Core element | Policy in Pulse | Reason |
|---|---|---|
| Player list (top-right, shows Cash) | Off. `leaderstats` stays; the cash binding needs it | It sits where the status cluster goes and repeats the cash chip |
| Health bar, backpack | Off | Nothing uses them |
| Chat (top-left) | Kept, **including in races**. Hidden while a full menu, garage screen, results or the full map is open, restored after. The top-left slot starts below the chat window while it shows. A run-time restyle (slate, kit font) is adopted if the spike shows it works | Titles and the event card are top-left; hiding chat in races would be a product change |
| Top bar | Top slots start below it | At 720p the scaled margin is smaller than the bar |
| Gamepad selection | Selection image per component. `GuiService.AutoSelectGuiEnabled` is turned off under Pulse, because the full map binds the same Select button the engine uses to start GUI selection; focus is entered and left explicitly; HUD tiles are not selectable while driving | The default blue box does not match, and stray selection while driving steals input |
| On-foot touch controls | Roblox defaults kept; bottom corners stay clear on foot | Familiar, and other scripts read them by name |
| Name tags, health over heads, core notifications, Esc menu, purchase prompts, emotes | Unchanged | Owned elsewhere or cannot be styled |

Known exception: the Studio-only trailer tool re-enables core UI on exit. The policy re-asserts on the engine's core-gui changed signal if that works **[spike]**; otherwise the exception is recorded. `SetCoreGuiEnabled` has one caller today, that tool **[live]**.

### 7.2 World prompts

Client only. No server script is edited (`TimeTrialServer` writes personal bests and grants rewards).

- `UIPulse.World.WorldPromptView` sets `Style = Custom` **locally** on known prompts as they stream in, through scoped listeners on the three known roots, the two static exterior prompts and the three client-made families. In Classic it is never required.
- It draws `PromptBanner` on `PromptShown` and removes it on `PromptHidden`. It never writes `Enabled`, never connects `Triggered`, never calls a remote for the action. On touch the banner is the button and calls `InputHoldBegin` and `InputHoldEnd`, so the server sees the same trigger.
- Banners are **screen-anchored** in one stack in the lower middle of the screen: no per-frame cost, a proper touch target, hidden by trailer mode.
- It hides what the default UI shows wrongly: Enter on cars the player does not own, desk and drive-out banners for visitors, everything while a major menu or results are open.
- **Fail-safe.** With `Style = Custom` the engine draws nothing, so on touch the banner is the only tap target for entering cars, garages and races. A prompt is set to Custom only after the banner host exists. If a banner cannot be built or errors, that prompt is set back to Default locally and left alone.
- The event card and Start banner read zone attributes and two existing rate-limited requests, once per show, cached per event. The new call site is checked against `Core.Net`'s busy lock and token bucket before the build; that code has not been read yet.
- Three engine behaviours are **[spike]**: a local Custom survives the server's re-assert of Default every 3 seconds (TimeTrialServer 1298 and 1311 set `Default` **[live]**); setting Custom before first show suppresses the default UI; `PromptShown` is steady while seated in a start zone. If the first two fail, prompts stay engine-drawn under Pulse as a recorded exception.

---

## 8. Navigation changes

| Change in the sheet | In or out | How |
|---|---|---|
| Customise hub becomes three tabs (Parts, Upgrades, Paint) | **In**, in the garage phase | Accepted in the gallery with fixtures before the controller is written. The model keeps Classic's state fields and transition rules; the route between pages is data. If Oscar rejects tabs at that point, the hub table is built instead |
| Owned and Buy become a Shop / Owned switch | **In**, same step | A view-level filter over the two row lists `GarageModuleCardViewModel` already builds |
| Race menu filter tabs | **In** | A client-side filter of the same list |
| Race entry: Exit, View records, Choose vehicle on one screen | **In as a shortcut only** | Pages and their order stay |
| In-race timer and checkpoint pips | **In** | The fields are already in the payloads **[note]** |
| In-race delta chip | **Lap against best lap only** | Per-checkpoint personal-best splits are not sent |
| Free-roam minimap during races | **Out** | None runs today and the map is paused on purpose. The restyled route map stays on Regular |
| Results: driver XP hero number | **In, from replicated attributes** | It is in neither result payload **[note]**. Shown as the change in `Rank` and `XpIntoRank` after the result; hidden if none arrives within 2 seconds. Medals, leaderboard and lap list stay, below the hero numbers |
| Phone minimap bottom-left | **Out** | Stays top-right |
| Settings rows that do nothing | **Not rebuilt** | Only passenger access, minimap mode and (on touch) control mode appear |
| Full map key hints | **Kept** | The one exception to "no key hints"; without them the map controls cannot be discovered |

Behaviour the garage contract restates, because it is not look: the empty-slot detour from Upgrades or Paint to Parts and back (GarageUI 274 to 282); preview clearing on tab change; Drive needing engine, stabilisers and boost; where Back goes; errors as a toast and an inline line; Cash and Spaces plus buttons on the status cluster.

How onboarding survives: page ids are saved, server-checked state and never change. The tab bar carries the `CustomisationHome` page marks and the three tabs carry the card ids `AddModules`, `UpgradeModules` and `PaintShop`; the page body carries the current tab's page id. Because garage and owned garage are one family and keep the `CanonicalGarageGui` names, Classic onboarding keeps working on the Pulse garage until its replacement lands. (`GarageComponents.CanonicalHost` adopts any ScreenGui of that name, but its only callers are GarageUI, GarageBrowserUI and GarageWorkspaceUI **[live]**, none of which run when the family is Pulse.) A full replay on a fresh sandbox profile is a gate in Phases 7 and 8.

---

## 9. Phases

Approved by Oscar as one list on 2026-10-09. Each phase is one approved scope with its own `CONTRACT.md` and one installer. Phones and controllers are designed and verified inside each phase.

**Owner gates.** Blocking: Phases 0, 1, 7, 8, 9 and 10. All other confirmations are made by Oscar setting `Config.UI@UIStyle` to `Pulse` in Studio when he has time, and do not hold the next phase. Every phase records whether it is generated, installed, agent-verified or user-confirmed.

**Lanes.** A phase that installs a second owner for a surface is High-Risk (docs/13: uncertain or multiple runtime owners). That is every phase from 1 to 10. Each runs the `delivery-reviewer` on its spec and diff before APPLY, and again on any edit to an existing script and on each fork.

**Build split in every phase.** Parallel agents get one folder each, a contract first, and never touch Studio or git. They write Luau sources, offline art, fixtures and test cases. Headless models for later phases can be written early; views wait for the kit API freeze. The integrator owns Studio, installs, the fork builds, captures, uploads, Play tests, measurements and git.

**Edit tests through `loadstring`** are limited to pure model and kit code: sources fed as strings with fakes, no `require` of any module in the place, no instance parented into the game tree, nothing left behind. AGENTS.md forbids requiring gameplay modules through MCP and separate module caches; anything that needs a real module, service state or a remote is verified in Play from normal start-up evidence.

| # | Phase | Scope | Lane | Parallel agents | Integrator | Exit gate |
|---|---|---|---|---|---|---|
| 0 | Spike, previews, records | No script, config value or asset in the place is installed or changed, with one stated exception: each Play session is opened by the guarded sandbox script, which writes `Config.Player.Onboarding@StudioVehicleSandboxEveryPlay` in Edit and restores and checks the earlier value afterwards. Everything else the phase creates in Studio is a transient Play-session instance (spike harness and probes), gone when Play stops. Harness for every **[spike]** item. Classic source and config record; Play record taken twice. Classic baselines with the probes. Preview frames for every screen the mockups do not cover and for each Compact composition. Generated contract tables. Surface ledger. Style sheet v2. Barlow metrics capture. Asset contact sheet, then the upload batch on Oscar's yes (images in his inventory; nothing in the place references them yet) | Fast: read-only, apart from the sandbox attribute window (an Edit write, restored) and transient Play-session instances | Contract and sheet v2; preview frames; contract extractor; installer engine and mock tests; asset generators; probes | Every Studio step; the sandbox window; spike captures on real displays | Oscar approves sheet v2, the previews and the asset batch. Each unknown is resolved to a chosen method. Classic record stable. Sandbox attribute back at its earlier value |
| 1 | Foundation and switch | Installer engine and the first module create in v3. Latch, `Routes`, config, kit core, toasts, `Confirm`, gallery, probes. ClientBase edit. AGENTS.md exception text | **High-Risk** | Tokens and metrics; layers, input, contracts; text and surface; controls and collections the pilot needs; overlay; gallery and fixtures | Contract, latch, `Routes`, ClientBase diff, install, Play in both styles | Create proven with save, reopen and rollback. APPLY, ROLLBACK, APPLY. Reviewer. Classic: full Play record identical, all entries ready. Pulse: only toasts differ. A forced `Compose` failure downgrades to a clean Classic session. Oscar accepts the gallery |
| 2 | Pilot: race menu | `RaceBrowser` for Regular, Compact and gamepad, against mockup 02 | **High-Risk** (second owner); gates on teleport and set route | Model with fixtures; Regular view; Compact view (list, then detail) | Install, Play | Reviewer. Lint and budgets on the matrix. 0 churn per row click. Classic onboarding finds its targets and its callouts are the right size. Teleport and route sequences match the table. On touch the Classic HUD and controls hide and return. Kit API reviewed |
| 3 | Free-roam screen | One HUD owner, gauge, round minimap, status cluster, action bar, car panel, lazy Controls, Settings and Cash modals, touch controls fork, activity HUD, core UI policy. RouteGuide getter | **High-Risk** (second owner); gates on spawn, despawn, exit, teleport and driving input | HUD model; Regular composition; Compact composition; gauge and numbers; minimap layers; car panel and modals; touch fork spec and view; activity context | RouteGuide edit, fork build, install, Play on desktop, phone, tablet, gamepad; input-state trace Classic against Pulse | Reviewer on the spec, the edit and the fork. HUD budgets against baseline. One HUD on touch plus keyboard. Classic map opens by click (through `Routes.Resolve`), M and Select. Classic onboarding locks and callouts work. Five activity views work untouched. Kit API frozen |
| 4 | World and map | Full map; prompt banners for all ten families; event card and Start banner | **High-Risk** (second owner); gate on prompt triggering | Map model; map view and legend; prompt view; event card | Install; Play with keyboard, touch, gamepad; streaming in and out | Reviewer. Map single-owner list ticked. Prompts trigger the same server handlers by key, pad and touch. A forced banner error falls back to Default. Classic prompts untouched in Classic |
| 5 | Race session and results | In-race HUD, countdown, queue banner, wrong-way and gate prompts, results. Race fade label seam | **High-Risk** (second owner); check that results are a projection of the payload | Session model with payload fixtures; HUD views; results view; small owners | RaceTransitionClient edit, install, Play, fixture replay, Quit path | Reviewer on the spec and the edit. `CountdownPresentationReady` still set. Owner keys unchanged. HUD does not return after finish or exit. Every result state from fixtures. No personal best written by an agent |
| 6 | Race entry | Setup, records, vehicle choice on the shared tile | **High-Risk** (second owner); gates on queue and vehicle start | Entry model; views; Compact | Install; Play; Classic onboarding replay for the race pages | Reviewer. Names and the two texts kept. No stale page or duplicate footer under rapid clicks. `StartSelectedVehicle` payload identical. Prize preview equals the Classic rule |
| 7 | Garage, one atomic family | Dealership, Customise with tabs and Shop/Owned, upgrades, paint, post-purchase paint, modals; owned-garage browser, desk fork, interior HUD with the guard extraction, transition fork, entrance fork | **High-Risk** | Garage model and routes; garage screen; paint panel; modals; owned-garage browser; desk view; interior HUD; fork specs; Compact; fixtures | Navigation accepted in the gallery first. Forks, install, sandbox purchase matrix, end-state comparison Classic against Pulse, onboarding replay | Fork checks pass. Action and payload table matches. End state equal. Affordability is the server projection. Orbit works under scrims. 0 churn on selection. Reviewer. Oscar confirms one real purchase |
| 8 | Shell | Onboarding rebuilt on marks and the kit scale (same page ids), guide trail colour, loading view, start screen. Two ReplicatedFirst edits. The downgrade residual of 1.3 settled | **High-Risk** | Onboarding model; onboarding view; loading view; start-screen fork spec and view | The two edits, install, cold starts in both styles, full replay on a fresh sandbox profile on PC, phone and controller | Classic full Play record identical. Start reachable by pad and keyboard. Every page begins and completes once. No timer walks PlayerGui or Workspace. Reviewer. Oscar confirms |
| 9 | Hardening and flip | Whole-game matrix in both styles; budgets; census; real-device frame time if Oscar publishes; docs | **High-Risk** | Checklists, evidence, docs | Matrix, flip, full Classic record once more | Every row passes. Switch back proven after the flip. Oscar says flip. Classic stays installed and switchable until Phase 10 |
| 10 | Retire Classic | A separate scope with its own contract, written only when Oscar has confirmed Pulse complete and says go. Removes the Classic UI owners and the Classic-only shared modules and config, collapses `Routes` and the latch branches in the five edited scripts to Pulse only, and removes the `UIStyle` attributes and the AGENTS.md exception. What stays because Pulse reuses it (2.1 and the "left as it is" row of 1.7) is listed there from live requires, not from this table | **High-Risk** (retirement) | Retirement inventory from live requires; docs | Recovery evidence first (Classic record in `classic/`, the Roblox version id), install, Play, docs | Reviewer. Nothing Pulse requires is removed. All entries ready, no new errors. Recovery route proven on paper to a named version. Oscar confirms |

---

## 10. Delivery and test route in v3

- **Folder.** `scripts/ui_restyle/` (it holds the audit and the design pass): this `CONTRACT.md`, the kit contract, `engine/` (installer), `classic/` (Classic source record), `tools/`, `probes/`, `spike/`, `previews/`, `assets/`, and one sub-folder per phase with `CONTRACT.md`, `before/`, `after/`, `build.py`, `out_audit.lua`, `out_apply.lua`, `out_rollback.lua` and `verification.json`.
- **Tools that are not used.** `studio_delivery.py`, `feature_installer.py` and `studio_capture.py` refuse v3. The place guard is not changed.
- **Engine.** One canonical installer for the programme: the lighting_realism step 2 engine (ops `source`, `tree`, `attribute`, `property`, `create`) with the hover_feel hash guards. It asserts the place id and Edit mode; every existing script must match its before, after or prior hash; sources are fetched from `serve.py` on 127.0.0.1, hash-checked and compiled before any write; nothing is written if anything blocks; sources are restored on failure.
- **New ModuleScripts** use the `create` op, which v3 has never exercised. Phase 1 starts by creating one inert module, saving, reopening, auditing, rolling back and creating it again. Created instances carry an install mark; ROLLBACK removes only marked instances whose hash matches and refuses if one has children it did not create.
- **Two transactions per phase.** Hierarchy and config first, verified; then sources. A mixed command once lost new config values. After APPLY the place is saved and reopened and AUDIT must still report "after" for every item.
- **Order of a delivery.** Capture, build, AUDIT (which runs the Classic check), delivery-reviewer where marked and on every edit to an existing script, APPLY, ROLLBACK, APPLY, save and reopen, Play verification, `verification.json`, docs (00, 06, one 07 entry), commit and push.
- **Existing hash chains** (GarageUI, GarageWorkspaceUI, GarageModuleCardViewModel, DesktopFreeRoamHudUI) get no new link. The Exotic content ROLLBACK is never run in v3.
- **Play without touching Oscar's profile.** Agent sessions use the existing Studio sandbox: `Config.Player.Onboarding@StudioVehicleSandboxEveryPlay = true` gives an in-memory profile and suppresses saves (ProfileServer 183 and 252 **[live]**; live value false). A guarded script opens the test window, records the earlier values, restores and checks them after each session; an installer APPLY and a handoff both refuse while it is open. Oscar approved this on 2026-10-09. It is an Edit attribute write, so no phase that uses it is strictly read-only. `StudioReplayEveryPlay` is turned on only for onboarding tests, by the same script.
  - The extent of the no-save guard for owned-garage purchases is read in Phase 0. Until then desk tests stop at preview and cancel.
  - A profile fingerprint (Cash, owned vehicle ids, module counts, personal bests, through existing read-only actions) is taken before and after each session and compared.
  - Time trials write personal bests even in the sandbox (PB-01). Agents never cross a time-trial finish. Results are verified from gallery fixtures and the Quit path; a real finish is Oscar's confirmation run.
  - Two-client checks use a local test with test accounts if the Studio tools can drive it **[spike]**; otherwise fixture replay plus Oscar's confirmation.
- **Gallery.** `UIPulse.Dev.Gallery`, a Studio-only tool entry added only under Pulse, mounts any view with fixtures in its own ScreenGui: no remotes, no profile. It is how every state is checked at every size and how parallel agents' work is reviewed.
- **Publishing** is Oscar's action, each time. There is no live preview. Real-phone checks and real-device frame cost need a publish, so they are scheduled around one, not assumed. The optional blank test experience would hold only the spike harness, so no installer guard changes and nothing is installed twice.
- **Docs.** Status only in `docs/00_START_HERE.md`; superseded design docs are marked when sheet v2 is approved.

---

## 11. Out of scope

- Removing any part of Classic before Phase 10. Retirement is Phase 10, on Oscar's go, and is not started by any earlier phase.
- A live kill switch, a preview user list, a server projection of a dashboard flag, and any ServerBase edit.
- Any edit to `RacingUIComponents`, `GarageComponents`, `ResponsiveUIFoundation`, `UITheme`, `MapIconLayer`, the five activity views or any server script. No new remote, payload, saved field, economy value or purchase owner.
- Fixing Classic's defects, including the duel stake-menu bug (it lives in a shared view) and PB-01.
- Driving, VFX, audio, world art, speed lines, start-screen artwork, name tags, the dealership signs, city billboards, checkpoint and finish colours, dev panels, the dealership intro pill.
- Hiding on-screen pedals when a keyboard or gamepad is the preferred input. That changes the only writer of driving input and needs its own contract.
- A live free-roam minimap during races; per-checkpoint personal-best deltas; a working UI SCALE setting; cash packs; the unreachable owned-garage Access pages.
- Portrait layouts and localisation.
- Changing the capture place guard, and the docs that still name v2.

---

## 12. Risks

| Risk | Containment |
|---|---|
| A rendering assumption is wrong (text above 100, hairlines on scaled displays, UIShadow on live clients, local prompt Style, font preload) | Phase 0 decides each with captures on real displays before anything is built; a fallback is chosen in advance for each; method behind a token |
| Copied controller logic differs from Classic, worst where Cash is spent | Generated contract tables enforced by lint; logic-identical forks with automatic parity; end-state comparison in the sandbox; reviewer; Classic frozen and hash-checked |
| Old and new both run, or a mixed set misbehaves | One latch; one path per entry name; two supported states; `Claim`; no `Enabled` writes; census at every gate; no fallback after a start |
| Onboarding breaks silently | Names generated from Classic source; `Mark`; lint; Classic onboarding left running until its replacement exists; fresh-profile replays in Phases 7 and 8 |
| A test changes Oscar's Cash, purchases or personal bests | Sandbox window with guard and restore; fingerprint; no time-trial finishes by agents; fixtures |
| The v3 install route fails for new modules or loses config | Create proof first; two transactions; save and reopen; code defaults equal config; size guard |
| The backup falls behind as the game changes | Classic smoke rule for later deliveries; manifest in every AUDIT; AGENTS.md exception with a review condition and an end (Phase 10). About 3,400 lines of logic exist twice while the backup exists |
| Size and evidence: eleven phases, about 70 new modules, phone speed unknown until a real device | Default stays Classic; every phase leaves a working game in either style; blocking gates only at 0, 1, 7, 8, 9 and 10; real-device checks at Phases 3, 7 and 9 when Oscar publishes |
| Retirement removes something Pulse still needs | Phase 10 inventory built from live requires; reviewer; version id recorded first; Classic record kept in the repo |

---

## Appendix A. Surface ledger

| Surface | Outcome |
|---|---|
| Free-roam HUD (desktop and mobile), car panel, Controls, Settings, Get Cash | Pulse, Phase 3 |
| Touch drive controls | Pulse fork with input code unchanged, Phase 3 |
| Activity strip, offer card, countdown, rank-up; Duel CHALLENGE button | Pulse context, Phase 3. The five view scripts are shared. The button stays in a design-pixel frame placed by Pulse so its hard-coded offset clears the Pulse bottom row: a named exception |
| Job and ride prompts; all ten world prompt families | Pulse banners, Phase 4, if the spike passes |
| Toasts; the three private status labels | Pulse toast, Phases 1 and 7 |
| Confirmations, garage modals, race exit confirmation | `Kit.Confirm` and `Kit.Modal` |
| Race menu; race entry; in-race HUD, countdown, queue, wrong-way, gate pills; results | Pulse, Phases 2, 6, 5 |
| Race fade label | Token seam, Phase 5 |
| Dealership, Customise, module shop, upgrades, paint; owned-garage browser, desk, interior HUD; entrance status | Pulse, Phase 7 |
| Minimaps; full map; map icons; other-player dots | Pulse layers, Phases 3 and 4; recoloured icons if approved; shared marker module with a Pulse config folder |
| Onboarding callouts and objective cards; world guide trail colour | Pulse, Phase 8. The trail renderer takes its config as an argument **[live]**; whether a second config folder is enough is checked in Phase 0 |
| Loading view and start screen | Pulse, Phase 8. Artwork unchanged |
| Player list, health, backpack, chat, top bar, selection box | Core UI policy, Phase 3 |
| Speed lines, dev panels, dealership intro pill, name tags, core notifications, Esc menu, purchase prompts, emotes, world signs and beacons, route arrows | Excluded, by name |

## Appendix B. Reviewer must-fix items and where they are closed

| Item | Closed by |
|---|---|
| Timing-based or per-entry fallback (A, B, C) | 1.3: none; one fallback before anything ClientBase starts, which downgrades the latch |
| Preview list overrides Classic (all three) | 1.1: no preview list; two values only |
| Classic touch menus force `Enabled` (rules review) | Shown unreachable with live config; 1.5 rule 8; tested in the Phase 2 gate |
| Hand-written name lists (all three) | 1.7 and 2.3: generated from Classic source, lint and a Play probe |
| "No UIScale anywhere" (C) | 3.4: two named exceptions |
| "Whole pixels are crisp" (all three) | 3.4: best effort, device-resolution captures as the gate |
| Layout family from input (A) | 3.1: geometry only |
| Budgets that leave out the heaviest parts (A) | 5.1 rule 10, 5.2 and 5.3: own map layers, shared modules counted from outside |
| Nine edited scripts with style branches (B) | 1.6: five, one of them a label seam |
| Second place as the test route, retirement phase (B) | Section 10; retirement is Phase 10, a separate scope on Oscar's go |
| Global selection image (B, C) | 2.3: per component |
| Hand-forked touch controls (A, C); art-only seam (B) | 1.7: logic-identical fork with input parity |
| Generated copies carrying Classic layout; `RacingCompat` (A) | 1.7: rebuilt as model plus view |
| Start screen edits shared config; guard position (B, C) | 1.6 and 1.7: guard after line 18; flow forked unchanged |
| Prompts on touch have no fail-safe (all three) | 7.2 |
| Navigation shipped with first purchases (C); hub kept (A); two tables kept (B) | Section 0 and 8 |
| Garage and owned garage split (C) | Phase 7 is one family |
| Activity HUD, onboarding and map bundled late (C) | Activity HUD in Phase 3; map in Phase 4 |
| Kit designed before any screen uses it (all three) | 2.2: API frozen after Phase 3 |
| Every owner gate blocking (all three) | Section 9 |
| No previews for most screens (all three) | Phase 0 |
| Backup lifetime undefined (all three) | 1.8; it ends at Phase 10 |
| Publish not named (all three) | Section 10 |
| Trailer mode re-enables core UI (all three) | 7.1 |
| `OwnedGarageClientStarted` side effect (rules review) | In the generated table; set at OwnedGarageClient line 10 **[live]** |

## Appendix C. Not verified

Nothing was run in Play. Every Classic instance count and pixel size is the audit's reading of source. Open until the spike: text above 100 under a static scale; hairline rasterising and whether the client pixel-grid fix has shipped; UIShadow on a live phone; `tnum`; font preload on a cold cache; `TopbarInset` coordinates; the chat window rectangle and run-time restyle; Text Size multipliers; the three prompt behaviours; the core-gui changed signal; attributes at ReplicatedFirst time on a cold start; whether ClientBase can run before ReplicatedStorage has arrived; `PreferredInput` on a touch laptop and on a phone with a gamepad; whether the Studio tools can drive a two-client local test; the sandbox's no-save extent for owned-garage purchases; `Core.Net`'s busy lock for the event card's requests; whether the Classic HUD step can be isolated in a MicroProfiler capture; digit sheet cell sizes; real-device frame cost; creating a ModuleScript in v3 through the tools with save and reopen (first step of Phase 1); the Classic onboarding callout scale on a screen with no `UIScale`; Oscar's viewport of 2065.33 x 1152.

## Appendix D. Fact-check corrections and where they are folded in

| # | Correction (fact-check.md) | Where |
|---|---|---|
| 1 | Touch camera guard cannot be moved unchanged: line 52 requires Classic `OwnedGarageWorkspaceUI` | 1.7, fork row: line 52 is a listed replaced span |
| 2 | The fallback is not all-or-nothing from Phase 8 | 1.3: the fallback downgrades the latch; readers call `Active()` at use; Phase 8 residual stated and settled in that contract |
| 3 | `Lifecycle.validate` is outside the protected block | 1.2, 1.3, 1.6 row 1: `Compose` validates inside the protected call before the swap |
| 4 | Phase 3 breaks lint rule 7 (Classic map by click) | 1.2 and 1.5 rule 7: `Routes.Resolve`; Phase 3 gate |
| 5 | Lanes: second owners are High-Risk; reviewer missing on 2, 4, 6 | Section 9: Phases 1 to 10 High-Risk with the reviewer |
| 6 | Phase 0 is not read-only | Phase 0 row and section 10: sandbox window is an Edit write, restored; approved |
| 7 | 30-second dependency timeout | 1.3: `start()` never waits on assets; preload is non-blocking |
| 8 | Classic onboarding scale on Pulse screens | 2.3; gates of Phases 2 to 7; remedy picked in Phase 0 |
| 9 | Edit tests through `loadstring` | Section 9: pure model and kit code only |
| 10 | Edit count with the kill switch | Kill switch dropped: five edited, 216 identical (section 0, 1.6) |
| Section 3, WRONG | Guard "moved unchanged" | As 1 |
| Section 3, PARTLY | Sandbox described as existing without saying it is off | Section 0 table, Phase 0 row, section 10 |
| Section 2, PARTLY | Attribute arrival at ReplicatedFirst time; ModuleScript create untested | Remain **[spike]** (1.1) and the first step of Phase 1 (section 10) |
