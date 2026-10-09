# Pulse wave 2: every remaining screen, then Pulse by default

Status: **draft for the delivery-reviewer; nothing installed.** Under `../CONTRACT.md` (the programme contract, "PC"), which wins on any conflict except the recorded changes in section 9. Interfaces and the family table are in `API2.md` ("A2"); Phase 1 is `../phase1/CONTRACT.md` and `../phase1/API.md`. Place: Space Racers v3 (93959280828322).

Oscar's instruction (2026-10-09): finish every remaining screen with the uploaded images, then make Pulse the default so he can test everything. This wave therefore delivers PC phases 2 to 8 as one programme of eight installs (kit v2, then seven families) and ends with the default flip of PC phase 9. Classic stays installed and switchable; retirement (PC phase 10) is not part of it.

## Contract header

```text
System/change: kit v2 (31 uploaded images, new components), then seven Pulse families replacing every
  remaining Classic UI surface: RaceMenu, FreeRoam, WorldMap, RaceSession, RaceEntry, Garage, Shell.
  Four small edits to existing scripts (PC 1.6 rows 2 to 5). Last step: Config.UI@UIStyle = "Pulse".
Delivery lane and reason: High-Risk. Each family installs a second owner for its surfaces; three
  families touch spawn, queue, purchase and Cash display; four existing scripts are edited, two of them
  in ReplicatedFirst start-up. Lane safeguards stay active through every repair (docs/13, docs/14).
Goal: with UIStyle = Pulse every player-facing screen is drawn by one kit, uses the uploaded images,
  scales on every device and costs less than Classic; with UIStyle = Classic the game is today's game.
Current confirmed baseline: Phase 1 installed and verified in Play (commit 7b871e0): latch, Routes,
  kit core, Pulse toasts, gallery; default Classic; 241 scripts; 31 images uploaded
  (assets/uploaded_assets.json); Config.UI.Pulse.Assets attributes still "".
Must preserve: section 3. Explicit exclusions: section 4.
Canonical owners: section 1 (state, geometry and visibility per surface). Preview, camera, runtime
  attachment and persistence owners are unchanged and shared by both styles. No server script changes.
Inputs, outputs and dependencies: existing remotes, bindables and attributes only (A2 section 5);
  Config.UI.Pulse and Config.UI.Pulse.Assets attributes; the shared look-free Classic modules A2 6.6 lists.
Entry, transitions, exit and cleanup: per owner through ClientLifecycle, as today. Style is read once
  per session by the latch.
Client/server authority and remote validation: client presentation only. Every remote call site is a
  copy of the Classic one and is proven by the parity declaration (A2 6.5) and the reviewer.
Stable IDs, saved schema and migration impact: none. Onboarding page ids, vehicle, module, slot,
  property and event ids pass through untouched.
Expected scale and performance budget: PC 5.2, per family in A2 section 5.
Mobile, touch, controller and accessibility coverage: built and verified inside each family
  (Regular, Compact, TouchDrive, gamepad, Largest text).
Streaming/open-world behaviour: PlayerGui only, except world prompts (scoped listeners on three roots).
Failure, cancellation, retry and observability: PC 1.3. No purchase is retried. Routes.StartWatch
  reports any routed entry not ready after 15 s. A family that fails a gate is rolled back alone.
Shared components/contracts to reuse: the Phase 1 kit; A2 sections 1 to 3; the cash presenter,
  money formatters, ProjectEconomy and BindReplicatedCash through Kit.Data only.
Implementation/installer and rollback approach: section 5 and section 8. One engine (../engine),
  one spec per install, AUDIT / APPLY / ROLLBACK from repo before-sources.
Verification matrix: section 6.
Readiness scorecard exceptions or deferred risks: section 9.
Done when: section 7.
```

## 1. Owners, before and after

One row per surface. "After, Classic" is always the "Before" owner, unchanged. Classic modules are never required under Pulse unless A2 6.6 lists them as shared.

| Family | Surface | Before (and after with `UIStyle` Classic) | After, `UIStyle` Pulse | Route (PC 1.7) |
|---|---|---|---|---|
| Kit | tokens, sprites, layers, components | Phase 1 kit | kit v2 (A2 1 to 3) | source edits of Phase 1 modules, new modules |
| RaceMenu | race menu state, teleport, set route | `Racing.RaceBrowserClient` | `UIPulse.RaceMenu.RaceMenuClient` (model + view) | new owner |
| FreeRoam | HUD state, car panel, modals, spawn, despawn, exit | `UI.DesktopFreeRoamHudUI` and `UI.MobileFreeRoamHudUI` | `FreeRoam.HudClient` (one owner); the mobile entry routes to `UIPulse.NoOp` | new owner |
| FreeRoam | touch drive controls | `Vehicles.MobileDriveControlsClient` | `FreeRoam.TouchControlsClient` | fork, input code unchanged |
| FreeRoam | activity HUD host | `Activities.ActivityClient` (five shared views) | `FreeRoam.ActivityHudClient` (same five views) | new owner |
| FreeRoam | Roblox core UI | none (engine defaults) | `Shell.CoreUiPolicy` | Pulse-only |
| FreeRoam | route state read | `UI.RouteGuide` | same module + `GetRouteState()` | edited (additive) |
| WorldMap | full map, waypoint, `FullMapOpen` | `UI.FullMapUI` | `WorldMap.FullMapClient` | new owner |
| WorldMap | minimap and map icon and route drawing | `UI.MapIconLayer`, `RouteGuide.newMapRenderer` | `UIPulse.Map.MapCanvas`, `MapIcons`, `MapRoute` over the shared data modules | new view layers |
| WorldMap | world prompt drawing, event card | engine default prompt UI | `World.WorldPromptView`, `World.EventCardView`; `Triggered` handlers and `Enabled` writers unchanged | Pulse-only |
| RaceSession | in-race HUD, reset, exit | `Racing.RaceSessionPresentationClient` | `RaceSession.RaceHudClient` | new owner |
| RaceSession | countdown, `CountdownPresentationReady` | `Racing.RaceCountdownPresentationClient` | `RaceSession.CountdownClient` | new owner |
| RaceSession | queue join and leave, banner | `Racing.RaceQueueClient` | `RaceSession.QueueClient` | new owner |
| RaceSession | results, race again, exit to start | `Racing.RaceTimeTrialResultCoachClient` | `RaceSession.ResultsClient` | new owner |
| RaceSession | 3D gate guide, wrong-way prompt | `Racing.RaceRouteGuideClient` | `RaceSession.RouteGuideClient` | fork (one span) |
| RaceSession | race fade label | `Racing.RaceTransitionClient` | same module, label styled by tokens | edited (seam) |
| RaceEntry | entry pages, vehicle start request | `Racing.RaceEntryPresentationClient` | `RaceEntry.RaceEntryClient` | new owner |
| Garage | dealership, customise, paint, purchases, drive | `Garage.GarageUI` + `UI.GarageBrowserUI`, `GarageWorkspaceUI`, `GarageComponents` | `Garage.GarageClient` (model, routes, views) | new owner |
| Garage | owned-garage browser, stream acknowledgement | `UI.OwnedGarageClient`, `UI.OwnedGarageBrowserUI` | `Garage.OwnedGarageClient`, `Garage.OwnedGarageBrowserUI` | new owner |
| Garage | owned-garage desk, `OwnedGarageManagementOpen` | `UI.OwnedGarageWorkspaceUI` | `Garage.OwnedGarageWorkspaceUI` + `OwnedGarageDeskView`, `GarageCompat` | fork (line 12) |
| Garage | interior HUD, touch camera guard | `UI.GarageInteriorModeUI` | `Garage.GarageInteriorHud` + `Garage.TouchCameraGuard` | new owner + fork |
| Garage | interior transition, entrance prompts | `UI.GarageInteriorTransitionUI`, `Dealership.GarageEntranceClient` | `Garage.GarageInteriorTransitionUI`, `Garage.GarageEntranceClient` | forks |
| Shell | onboarding state, callouts, locks, guide trail target | `UI.OnboardingClient` | `Shell.OnboardingClient` | new owner |
| Shell | loading view | `ReplicatedFirst.Loading.LoadingScreenView` | `ReplicatedFirst.Loading.LoadingScreenViewPulse`; the runtime singleton is shared | new view; runtime edited (line 8) |
| Shell | start screen flow, `StartScreenActive` | `ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient` | `ReplicatedFirst.Loading.StartScreenPulse`, run by the same script | fork; script edited (guard) |

Left as they are under both styles: every entry A2 section 4 lists as untouched, `MapMarkers`, `MapMath`, `MapTileSet`, `FreeRoamMapPlayerMarkers`, `GarageModuleCardViewModel`, `GarageCatalogClient`, `ResponsiveUIFoundation`, the preview and camera modules, the five activity views, `LoadingArtworkCatalog`, `OnboardingGuideTrailRenderer`, and every server script.

Geometry and visibility: `Kit.Metrics` and `Kit.Layers` for every Pulse surface; no Pulse module writes `ScreenGui.Enabled` (PC 1.5 rule 8). Persistence and authoritative mutation: none added.

## 2. What is installed

| # | Install | New ModuleScripts | Edited existing scripts | Config |
|---|---|---|---|---|
| 0 | Kit v2 | `Kit.Sprites`, `Kit.Presence`, `Kit.BigNumber`, `Kit.Data`, `Kit.Gauge`, `Kit.Minimap`, `Kit.Touch`, `UIPulse.NoOp`, five `Dev.Fixtures.*` additions | source ops on the 12 Phase 1 kit modules and the gallery (before = `phase1/after/`) | 31 attributes on `Config.UI.Pulse.Assets` set to the uploaded ids (before `""`; 10 `Touch*` and 6 other new keys before `null`); new token attributes on `Config.UI.Pulse` |
| 1 | RaceMenu | 4 | `Routes` | - |
| 2 | FreeRoam | 12 + the 3 `UIPulse.Map.*` | `Routes`; `UI.RouteGuide` (getter) | - |
| 3 | WorldMap | 7 | `Routes` | - |
| 4 | RaceSession | 10 | `Routes`; `Racing.RaceTransitionClient` (seam) | - |
| 5 | RaceEntry | 6 | `Routes` | - |
| 6 | Garage | 17 | `Routes` | - |
| 7 | Shell | 6 (two in `ReplicatedFirst.Loading`) | `Routes`; `LoadingTransitionRuntime` (line 8); `InitialLoadingAndStartScreenClient` (guard) | - |
| 8 | Default flip | none | none | `Config.UI@UIStyle` `"Classic"` to `"Pulse"` |

About 70 new ModuleScripts. No Script or LocalScript is created. ClientBase is not edited again (PC 1.6 row 1). Each `Routes` edit adds one family name and its swap and add rows, generated from the families' `routes.json`; nothing else in `Routes` changes. The exact text of each edit to an existing Classic script is in A2 5.3, 5.5 and 5.8 and is the only change allowed in that script.

## 3. Must preserve

1. **Classic.** With `UIStyle` Classic every script runs today's statements; the four edited scripts run today's statements plus one protected latch read each (`RouteGuide` gains one function nobody calls). `classic/out_verify_classic.lua`, rebuilt with each install's `declared.json`, passes in every AUDIT (PC 1.8).
2. **Server authority.** Price, Cash, purchase, spawn, despawn, teleport, queue, results and onboarding state are decided by the server. No new remote, action, payload key, saved field, economy value or server edit. Cash on screen is `leaderstats.Cash` or a reply field; the only client arithmetic is the existing count-up and the race-entry prize preview rule carried from Classic.
3. **Call sites.** Every remote call, bindable fire, attribute write and context action of a replaced owner is reproduced with the same name, action string and payload keys, behind the same busy guard, unless A2 section 5 lists it as dropped. No purchase or spawn is retried.
4. **Single owners** (PC 2.3): one caller of `RouteGuide.Update` per frame; one writer each of `FullMapOpen`, `OwnedGarageManagementOpen`, `StartScreenActive`, `CountdownPresentationReady`, `MobileMajorMenuOpen`, `MobileFreeRoamCarMenuOpen`, `MobileControlMode`; one listener each for `StartRaceQueueRequest`, `RaceEntryLegacyAction`, `OpenRaceBrowser`, `OpenOwnedGarageBrowser` and the three garage `Open*` events; one `PreviewCamera` input binder; one loading runtime singleton; one start-screen flow that calls `Begin`; one stream-ready acknowledgement; `GarageSessionActive` stays the only garage-open signal; the `FreeRoamHudPresentationMode` owner keys and `KeepTelemetry` values.
5. **Driving input.** Every `MobileDriveInputState` write of the touch controls is unchanged (fork parity). Pedals still follow `TouchEnabled`.
6. **Names other scripts read**: the reserved names and onboarding marks of A2 section 5, applied through `Kit.Input.Mark` and `Layers.Create`; no trap name is created.
7. **Onboarding.** The 19 page ids and `PCDriving` are unchanged. Classic onboarding keeps working on every Pulse screen delivered before the Shell family.
8. **Behaviour that is not look** (PC 8): the empty-slot detour and return, preview clearing on tab change, Drive needing engine, stabilisers and boost, where Back goes, errors as a toast and an inline line, race-entry page order, confirmation behaviour (NO left, YES right, NO focused, Escape and B cancel).
9. `LandscapeSensor`; Oscar's profile (agents play only in the sandbox window); the existing hash chains (no new link); the Exotic content ROLLBACK is never run.

## 4. Exclusions

- Retiring or editing any Classic owner, `GarageComponents`, `RacingUIComponents`, `ResponsiveUIFoundation`, `UITheme`, `MapIconLayer`, the five activity views, or any server script (PC 11). Retirement is PC phase 10, a separate scope on Oscar's go.
- Fixing Classic defects in Classic, including the duel stake-menu bug and PB-01. Pulse owners carry only the fixes A2 section 5 names (stale race-entry page, HUD returning after finish, results buttons before the leaderboard reply).
- The 3D race gate guide, route arrows, start-zone auras, name tags, speed lines, dev panels, the dealership intro pill, world signs, start-screen artwork and the wordmark (the placeholder was not uploaded).
- A live free-roam minimap during races; per-checkpoint personal-best deltas; cash products; a working UI SCALE setting; the unreachable owned-garage Access pages; portrait layouts; localisation.
- Hiding on-screen pedals by preferred input; any change to driving, VFX, audio or camera modules.
- Real-device frame cost and real-phone checks, which need a publish (Oscar's action).
- A per-family switch-back in normal use. `UIStyleDevFamilies` (Studio only) remains a fault-finding tool.

## 5. Install order and the steps of one install

Order is fixed: **kit v2, RaceMenu, FreeRoam, WorldMap, RaceSession, RaceEntry, Garage, Shell, then the flip.** It is the order of `Routes.Families`; `Compose` requires the active families to be a prefix of it. A family is not started until the one before it has passed step 12.

Build: parallel agents (four kit agents, then one or two per family) write sources, fixtures, tests and fragments in their own folders (A2 6.1) and never touch Studio or git. Family agents may write models and tests while the kit is built; views are checked against kit v2 once it is installed. The integrator owns everything below.

| Step | What | Passes when |
|---|---|---|
| 1 | Assemble `spec.json` from the fragments; build forks from `forks/*.json`; regenerate `Routes` and `declared.json` | `engine/build.py` succeeds; every after-source is LF, under 150,000 characters |
| 2 | Compile | every source compiles (`loadstring` in AUDIT and the Edit harness) |
| 3 | Pure tests in Edit (`run_tests.lua`, API1 13) for the family and the whole kit | all ok; nothing parented into the game tree; nothing left in `shared` |
| 4 | Lint (API1 11 with A2 6.6), including budgets and the asset-key and require whitelists | 0 findings |
| 5 | Parity check: `contract.json` against `classic/contracts/<Owner>.json` and against the Pulse source; fork diffs equal the listed spans; for the touch fork every `MobileDriveInputState` write identical | no difference outside `dropped` and `added`, each with an A2 reference |
| 6 | `delivery-reviewer` (it has not seen the build): on the spec and diff of **every** install; again on each edit to an existing script (FreeRoam, RaceSession, Shell) and on each fork; on the **whole Garage family** with the purchase table | no open finding |
| 7 | AUDIT (runs the Classic verify) | every op `before`; Classic 241 + declared scripts unchanged; sandbox window closed |
| 8 | APPLY hierarchy, AUDIT, APPLY sources, AUDIT; save and reopen; AUDIT | every op `after` after the reopen |
| 9 | ROLLBACK, AUDIT, then APPLY again (once per install, before Play) | `before`, then `after` |
| 10 | Play, `UIStyle` Classic, sandbox window: smoke | all entries `ready`; short Play record (four points plus the surface touched) equals the Classic record; no new console error. **Full** Play record after kit v2, Shell and the flip |
| 11 | Play, `UIStyle` Pulse (every family delivered so far), sandbox window | the family's gates (A2 section 5); census: one owner per surface, every Pulse gui marked, no duplicate names, none of the replaced Classic guis; `StartupState` all `ready`; budgets by probe; capture matrix through the gallery presets and the live screen; gamepad pass; Largest text pass; profile fingerprint equal before and after |
| 12 | `verification.json`, docs (`docs/00_START_HERE.md`, `docs/06`, one `docs/07` entry), commit and push of explicit paths | recorded as generated, installed, agent-verified; user-confirmed only when Oscar says so |

Between installs `Config.UI@UIStyle` is left at `"Classic"`. Oscar can look at the delivered families at any time by setting it to `"Pulse"`; that confirmation does not block the next family, except: the garage navigation (tabs, Shop / Owned) is accepted by him in the gallery before the garage controller is finished (PC 8), and he confirms one real purchase before the flip.

**The flip (install 8)** is one `attribute` op, run when every family has passed step 12 and Oscar asks for it: `Config.UI@UIStyle` `"Classic"` to `"Pulse"`, then save. Before it: the whole-game matrix in both styles, the census, a full Classic Play record. After it: the switch back to Classic is proven once more.

## 6. Verification matrix

| Area | Check | Where |
|---|---|---|
| Static/install | compile, lint, pure tests, parity, fork diff, Classic verify, save and reopen | steps 1 to 9 |
| Runtime transitions and cleanup | open, close and re-open of every screen; garage enter and exit by each of the three entries; race entry to queue to race to results to exit; map open while driving; respawn; `StartupState`; census; 0 churn on selection | step 11 |
| Authority and security | parity declaration; reviewer on purchase and spawn call sites; garage end-state comparison Classic against Pulse on the same purchase sequence; affordability is the server projection | steps 5, 6, 11 (Garage) |
| Multi-client | fixtures plus Oscar's run (the Studio tools start one client, Phase 0 spike 16); the HUD-return and queue cases are flagged for his two-client test | step 11, Oscar |
| Save/rejoin/migration | no schema change; sandbox profile only; fingerprint before and after every session; no time-trial finish by an agent | step 11 |
| Device/performance | gallery presets R720, R1080, R1440, C844, C568; live captures at Oscar's viewport; budgets by `instance_census`, `churn_probe`, `write_probe`; real-device cost deferred to a publish | step 11 |
| Mobile/touch/controller | TouchDrive arrangement in the device emulator; touch input-state trace; pad navigation of every menu; prompt triggers by key, pad and touch | step 11 |
| Onboarding | Classic onboarding on each Pulse family as delivered; full replay on a fresh sandbox profile after Garage and after Shell | step 11 |
| Recovery | ROLLBACK then APPLY per install; switch back after the flip | steps 9, flip |

## 7. Done when

Every install has passed steps 1 to 12; the reviewer has no open finding; with `UIStyle` Pulse no Classic UI owner starts and every screen in the style sheet's scope is drawn by Pulse; with `UIStyle` Classic the full Play record equals the Classic record; Oscar has accepted the garage navigation and one real purchase; and, at his request, `Config.UI@UIStyle` is `"Pulse"` in the saved place. Publishing stays his action.

## 8. Recovery

1. **One value:** set `Config.UI@UIStyle` to `"Classic"` and press Play (`phase1/set_style.lua` does the same). It works at every point of the wave, including after the flip, until PC phase 10.
2. **Per-family ROLLBACK:** each install's `out_rollback.lua` removes that install's marked modules and restores the edited scripts and `Routes` from repo before-sources. Families are rolled back in reverse order of install (a later family's `Routes` edit has the earlier one as its before). The engine refuses if a marked instance has unmarked children or a source matches neither before, after nor a prior fingerprint.
3. **In Studio only, for fault finding:** `UIStyleDevFamilies` holds later families on Classic in delivery order.
4. **Several unrelated faults:** Roblox version-history restore to the version recorded before the kit v2 install (recorded in `verification.json`); say so before another patch (AGENTS.md).
5. Never the Exotic content ROLLBACK. After two source-anchor failures in one live script, stop and refresh the source.

## 9. Scorecard, recorded changes and deferred risks

| Item | State |
|---|---|
| Single owner per surface | PASS at gate: latch, one path per entry, `Claim`, census (step 11) |
| Authority and validation | PASS at gate: parity declaration, reviewer, end-state comparison |
| Persistence | PASS: none added |
| Lifecycle and cleanup | PASS at gate: scopes, `ClientLifecycle`, 0 churn probes |
| Failure handling | PASS at gate: no fallback after start; per-family rollback; one-value switch |
| Performance budget | PASS at gate in Studio; real-device cost DEFERRED to a publish |
| Device and input coverage | PASS at gate in the emulator and gallery; real phone DEFERRED to a publish |
| Observability | PASS: `StartupState`, `Routes.StartWatch`, `Kit.Perf` counters, latch attributes |

Recorded changes to the programme contract in this wave (each needs the reviewer's eye; A2 holds the detail):

1. **`ResponsiveUIFoundation` is required by one Pulse module, `Kit.Data`**, for the cash presenter, money formatters, `ProjectEconomy` and `BindReplicatedCash` (PC 2.1 says these are reused unchanged; API1 rule 3 forbade the require). A2 3.5.
2. **`RaceRouteGuideClient` is a fork, not a new owner** (PC 1.7 listed the route-guide prompt under new owners). Its 3D guide is excluded world art; only the wrong-way label is replaced. A2 5.5.
3. **The RaceTransitionClient seam styles the label through `Kit.Text.StyleForeign`** after the Classic literals instead of branching them: four inserted lines, Classic statements untouched. A2 5.5.
4. **`LoadingTransitionRuntime` line 8 becomes two lines** so a missing latch, a missing `LoadingScreenViewPulse` or one that errors on require gives the Classic view (PC 1.6 said "line 8 only"): the Pulse view is found with `FindFirstChild` and required inside the same `pcall` as the latch, and the Classic require of line 8 is the fallback, as written. The start-screen guard in `InitialLoadingAndStartScreenClient` is protected the same way and returns only when `StartScreenPulse.Run()` returned true (false = stopped before `Begin`). A2 5.8.
5. **The Shell downgrade residual of PC 1.3 is accepted**, not moved into the latch.
6. **No remedy for the Classic onboarding callout scale** on Pulse screens: the Classic fall-through scale is within 8% of the kit scale. A2 2.10.
7. **Unaffordable tiles stay selectable** (the kit's Phase 1 rule made them inert); only the Buy button is disabled, as in Classic. A2 2.9.
8. **`FullMap` DisplayOrder comes from the ladder**, not `Config.UI.FullMap@DisplayOrder`. A2 5.4.
9. **Five retired asset attributes stay on `Config.UI.Pulse.Assets` as `""`** and are ignored. A2 1.1.
10. PC phase gates 2 to 8 named Oscar's sign-off as blocking only at 7 and 8; in this wave the garage navigation and one purchase remain his, and the rest is his test after the flip, as he asked.

Deferred or unverified, carried into the gates: the gauge reveal seam on the real images; whether chat collapse is observable (`ChatKeepOut`, A2 2.3); the attribute read at ReplicatedFirst time on a cold start and `FindFirstChild` of the latch there (Phase 0 spike 12, first step of the Shell install); prompts while seated in a start zone and touch `InputHoldBegin` (spike 11); Text Size multipliers (spike 09); hairline sharpness on a real display; the sandbox no-save extent for owned-garage purchases; two-client behaviour.

## 10. Build split

| Agent | Folder | Owns |
|---|---|---|
| K1 | `phase2/kit/k1` | `Tokens`, `Sprites` and its generator, `Metrics`, `Layers`, `Contracts` and its generator, `Presence` |
| K2 | `phase2/kit/k2` | `Text`, `Surface`, `Controls`, `Collections`, `Input`, their fixtures |
| K3 | `phase2/kit/k3` | `Overlay`, `Gauge`, `Minimap`, their fixtures |
| K4 | `phase2/kit/k4` | `BigNumber`, `Data`, `Touch`, their fixtures |
| F1 | `families/race_menu` | A2 5.2 |
| F2 (a, b) | `families/free_roam` | A2 5.3 |
| F3 | `families/world_map` | A2 5.4, including `UIPulse.Map.*` |
| F4 | `families/race_session` | A2 5.5 |
| F5 | `families/race_entry` | A2 5.6 |
| F6 (a, b) | `families/garage` | A2 5.7 |
| F7 | `families/shell` | A2 5.8 |
| Integrator | `phase2/` | specs, `Routes`, `UIPulse.NoOp`, fork tool, lint, parity check, Studio, Play, captures, docs, git |

One ModuleScript, one owning agent. `API2.md` is amended by the integrator only, before the code that depends on the amendment.
