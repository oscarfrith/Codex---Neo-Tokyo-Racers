# Adversarial review: project rules, ownership and regression

Date: 2026-10-09. Reviewer lens: AGENTS.md, CLAUDE.md, docs/13, docs/14, docs-and-delivery.md; hidden coupling; any way old
and new could both run; any way the old UI could differ after switching back.

Read-only. Live Studio "Space Racers v3" (93959280828322), Edit mode. Nothing in Studio or the repo was changed, no Play
session was run, and no gameplay module was required. Runtime statements below are read from source.

Read live for this review: ClientBase (whole), Core.ClientLifecycle (whole), LoadingTransitionRuntime 1-100,
InitialLoadingAndStartScreenClient 1-60, OwnedGarageClient (whole), SharedTopNotificationUI (whole), OwnedGarageWorkspaceUI
1-32, RaceLifecyclePresentationClient 1-110, TrailerModeClient (whole), FullMapUI 1-30, 455-536, 838-857, GarageComponents
294-313, RouteGuide 28-95, 168-262, MapIconLayer 262-312, ProfileServer 172-258, RaceTransitionClient 52-150,
GarageEntranceClient 64-227, MobileDriveControlsClient 1-60, MobileDriveInputState (whole), OnboardingClient 100-147,
660-700, GarageInteriorTransitionUI 1-12, ActivityClient 14-92, 230-323, DesktopFreeRoamHudUI 955-966,
RaceBrowserClient 400-412, RaceSessionPresentationClient 117-126, plus about twenty whole-place greps and two read-only
count probes.

## 0. Verdict

1. **A** is the safest against the rules: three edited scripts, the strongest proof that Classic is unchanged, and it found
   most of the coupling by itself. Its weak points are a timing-based per-group fallback and generated copies that carry old
   layout numbers into the new look.
2. **C** is second: four edits, family-atomic routing, the best measurement and gallery tooling. It breaks more coupling in
   the interim (pilot order, hand-forked touch controls, garage tutorial gap) and bundles the navigation change with the first
   Pulse purchases.
3. **B** is last on this lens: nine edited scripts including style branches inside the driving-input owner and two shared
   renderers, a fallback that is not atomic, a second place as the test route, and a retirement phase in a plan whose brief
   is to keep the old UI.

None of the three is ready to approve as written. Section 1 lists gaps all three share.

---

## 1. Gaps that all three proposals share

| # | Finding | Live evidence | Consequence | What the plan needs |
|---|---|---|---|---|
| 1 | Classic touch menus are brute-force visibility owners | RaceBrowserClient 402-411 and RaceEntryPresentationClient 348-361: on touch they do **not** publish `FreeRoamHudPresentationMode`; they set `Enabled = false` on every other ScreenGui under PlayerGui, remember the old value, also catch `ChildAdded`, and write the old value back on close. TrailerModeClient 44-63 does the same | In any phase where a Classic race menu or entry runs beside Pulse ScreenGuis, a Pulse owner that writes `ScreenGui.Enabled` on a state change gets a stale value written back. Example: race HUD layer hidden when the entry opened, shown by Pulse at race start, switched off again when the entry closes. A and C allow Enabled writes "on a state change"; B routes all visibility through `Layers.setVisible`, which writes Enabled | Pulse owners never write `ScreenGui.Enabled` while any Classic save-and-restore owner can run. Show and hide with a root `Visible`. State how the Pulse race menu and entry hide other surfaces on touch |
| 2 | Trailer mode re-enables core UI on exit | TrailerModeClient 28-42, 68: Backpack, Chat, PlayerList, Health, EmotesMenu set to true unconditionally | All three add a Pulse core-UI policy that turns the player list off. After one trailer toggle it is back on. Studio tool only | Record as an exception, or have the policy re-assert when the tool toggles. B's "only caller in normal play" is true only because the tool is off |
| 3 | Name and attribute lists are hand-written and each is incomplete | Literal lookups extracted from OnboardingClient: `named`: AccessControls, Boost, BoostButton, Car, DriftLeft, DriftLeftButton, Garage, LapSelector, Race, RaceFormat, TierE. `screenRoot`: OwnedGarageBrowser, RaceBrowser, RaceEntryPresentation. Text: DEALERSHIP, RACE, TIME TRIAL. `workspacePage`: AddModules, UpgradeModules, PaintShop, CustomisationHome, GarageHome, DisplayCars, GarageAssetFamilies, BuildStructure, BuildDecorations. Player attribute `MobileMajorMenuOpen` is read by MobileDriveControlsClient 197, OnboardingClient 474, GarageInteriorModeUI 273 and 276, FullMapUI 450 | A omits `AccessControls`. C omits `DriftLeft`, `DriftRight`, `Boost`, `AccessControls` and the three mobile player attributes. B omits the drift names and is saved only because it leaves that script in place | Generate the contract table from Classic source (per reader script), not by hand. Enforce it with lint and with a Play probe at each gate |
| 4 | Activity views place controls in design pixels | ActivityClient 78-85 builds `DesignRoot` with a UIScale. DuelClientView 252-262 creates a 240x40 button under `ctx.Root` and sets `Position = UDim2.new(0.5, 0, 1, -84)` | A keeps a design-pixel frame with a UIScale (correct). B does not mention it. C says "No UIScale anywhere in the new UI", which cannot hold while the five views are unchanged | One named UIScale exception: the frame handed to the unchanged activity views |
| 5 | The start screen passes parameters by editing shared config | InitialLoadingAndStartScreenClient 26-46: sets `TimeoutSeconds = 86400`, disables non-eligible artworks, calls Begin, restores both. Lines 15-18: early return when `StartScreenEnabled == false` | A's generated copy keeps this. B's and C's hand-written start screen must copy it exactly or the start screen times out; neither names it. B and C place their guard after line 13, before the 15-18 early return | The start-screen contract lists these behaviours line by line. Put the guard after line 18 |
| 6 | World prompts on touch have no fail-safe | With `Style = Custom` the engine draws nothing, so the Pulse banner is the only tap target for ten families (enter vehicle, garage entry, race start) | A banner error on a phone blocks entering cars, garages and races. A and C give this phase the Standard lane | Run-time fail-safe: if a banner cannot be built, set that prompt back to Default locally. High-Risk gate on triggering by key, pad and touch, and on stream in and out. Check the event card's new call site of two race requests against Net's busy lock |
| 7 | Play in v3 always touches the saved profile unless the sandbox is on | ProfileServer 198-226, 252: the sandbox empties vehicles, cockpits and modules, sets Cash to at least 1,000,000, does not reset onboarding, suppresses saves. Live value false. Driving pays Cash (DriveRewardsServer) | B's v3 "no-commit protocol" cannot be clean for any test that drives. A's and C's sandbox route is right but every garage test starts from a purchase, and Oscar turned the sandbox off on purpose (TEST-01) | Oscar's yes for a guarded sandbox window; fixture and gallery checks for everything else |
| 8 | Backup lifetime is undefined for later work | All three freeze Classic | A later non-UI delivery (a new vehicle category, a payload field) can break Classic with nobody looking | Written rule while the backup exists: every later delivery that touches a payload or config Classic reads runs a short Classic smoke check. Record the backup and the switch as exceptions in AGENTS.md with owner and review condition (docs/14, "Record a short exception") |
| 9 | Live preview needs a publish | The preview user list is read from the published place | Publishing is a separate scope (docs/13 section 3) | Name the publish as its own approval |
| 10 | Pulse `OwnedGarageClient` must repeat a side effect | OwnedGarageClient 10 sets `Runtime.UI@OwnedGarageClientStarted`. Nothing reads it today | Low risk, but it is exactly the kind of line a hand-written starter drops | Include it in the parity table |

---

## 2. Proposal A: safest backup

### Fatal flaws

None that cannot be fixed inside its own design. The nearest is serious flaw 1.

### Serious flaws

1. **The automatic per-group fallback is timing-based, and it makes mixed sets a supported state.** A group falls back to
   Classic if a path is not found within 5 s or a pre-start `require` fails. The Shell group is first asked from
   ReplicatedFirst (LoadingTransitionRuntime line 8 runs at require time), where `Pulse.Shell.OnboardingClient` and the kit
   live in ReplicatedStorage and may not have replicated. A slow client can get the Classic loading screen and Classic
   onboarding with everything else Pulse. "Every mix of groups must work" is 64 combinations; only single-group fallbacks
   are smoke-tested, at Phase 9. Pre-start requires also delay every client entry, and A admits "require has no side
   effects" is a rule, not yet a fact.
2. **Generated copies carry Classic layout numbers and Classic debt into Pulse.** `RacingCompat` is a second component API
   beside the kit. The generated onboarding keeps `ownerScale`, which borrows a UIScale from the target; Pulse has none, so
   every callout uses the fallback clamp of 0.68 to 1.08 while the rest of the UI reaches 2.0 at 4K. Its Next button stays
   104x44. The generated start screen keeps four pixel presets. The generated GarageUI keeps `buildPreview()` on every
   upgrade and paint render (20 call sites in the script) unless each is listed. This conflicts with "copying coordinates
   is not reuse" and with the owner's "scale better, align better, more consistent".
3. **Its own lint rejects its own desk fork.** A says the only replacement in the generated OwnedGarageWorkspaceUI is the
   view require. Line 12 also requires GarageComponents (used at 30 and 79) and RacingUIComponents. A's lint forbids a
   Pulse module requiring GarageComponents, and no shim is listed.
4. **The hidden-chip mirror breaks docs/14.** Reading the Text of a hidden label that RouteGuide's renderer owns is
   "another system's UI objects". The NaN projection plus a second rim layer gives one marker two renderers. A one-function
   read-only getter is cleaner, and A says so itself.
5. **The touch drive controls are hand-written.** That is a hand copy of 209 lines that write driving input. A has a
   generation tool with parity checks and does not use it here.
6. **The Race group ships in two phases.** In Phase 3 the Pulse race HUD runs beside the Classic race menu and entry, so
   shared gap 1 applies on touch.
7. **`measure_client.lua` "reads the Kit.Frame counters".** From MCP that is a module require unless the counters are
   published as attributes. Rule: no gameplay module require through MCP.
8. **The results check uses "a Studio-only hook" inside a shipped owner.** Use gallery fixtures instead.
9. Smaller: Phase 0 is labelled Standard but holds the first module create in v3; the font file download for the digit
   sheet is not listed for approval; `AccessControls` is missing from the reserved names; hand-written owners (HUD, race,
   map) still drift while Classic is frozen for the whole programme.

### Claims checked

| Claim | Result |
|---|---|
| ClientBase resolver at 105-109, 46 entries, `StartupState` at 104 | Correct |
| ClientLifecycle is 49 lines; a non-ready dependency blocks at 36 | Correct |
| LoadingTransitionRuntime: view require 8, colours 40, `View.Create` 47 | Correct |
| Start screen: early return 15-18, runtime 21, RacingUIComponents 22 | Correct |
| OwnedGarageClient 18 lines, four modules by name at 8-9 | Correct |
| SharedTopNotificationUI 27 lines, controller at 17 | Correct |
| HUDs find the full map by module name (Desktop 960, Mobile 260) | Correct. A never-started FullMapUI returns false from `Open` (line 20), so a Classic HUD beside a Pulse map shows "MAP NOT AVAILABLE"; it does not create a second owner |
| ActivityClient is required only by ClientBase | Correct. `Client.Context` is exported at 289; nothing reads it |
| 19 and 9 requirers | Correct (8 for the foundation) |
| `Config.UI`: no attributes, 17 folders, no Style or Pulse | Correct |
| RouteGuide: `GetActive` public at 89, state private at 36-38, pip and chip parented to `Container` at 219 and 237 | Correct |
| MapIconLayer: host projection at 274-275, NaN hides at 304 | Correct |
| Sandbox: Studio only, one attribute, live value false | Correct |
| `SetCoreGuiEnabled` only in TrailerModeClient | Correct |
| 221 scripts in the place | Correct |
| TimeTrialServer re-asserts prompt Style every 3 s | Correct (1311; loop 1413-1418) |
| "The only replacement is the view require" (desk fork) | **Wrong**, see serious flaw 3 |
| The three mobile player attributes "keep one writer" | Partly wrong: `MobileControlMode` already has two writers (MobileDriveControlsClient 166, 173; MobileFreeRoamHudUI 201) |
| Reserved-name list is complete | **Wrong**: `AccessControls` is missing |

### Best ideas

- The latch in ReplicatedFirst, so the loading script and ClientBase share one answer with no new wait.
- Three edits, and extra entries only when Pulse, so Classic start-up is unchanged.
- The Classic record: hashes of all 221 scripts and a typed config dump checked in every AUDIT, plus a Play record at 14
  fixed points after every phase that edits an existing script.
- Generated controllers with automatic parity of remote calls, bindable fires and attribute writes where Cash or saved ids
  are involved.
- Build lint: no Pulse module requires a Classic owner; trap names refused.
- Like-for-like garage first, navigation later as its own phase that can be declined.
- Groups worked out from direct requires (map with HUD; the four owned-garage modules as one unit).
- Design-pixel frame and value-mapped colours for the unchanged activity views.
- Selection image per Pulse component, so Classic screens keep the default box.
- The sandbox test window with a guard: APPLY and handoff refuse while it is open.
- Installs in two transactions, save and reopen check, 150,000 character build limit, module-create pilot in Phase 0.

---

## 3. Proposal B: most cohesive

### Fatal flaws

1. **The missing-module fallback is per entry, not atomic.** `PathFor` falls back one entry at a time. If
   `Screens.Hud.FreeRoamHud` is missing, `DesktopFreeRoamHudUI` falls back to Classic, which returns early on a phone, while
   `MobileFreeRoamHudUI` still resolves to the inert module: a phone gets no HUD. Other single misses give a Classic HUD
   beside a Pulse map ("MAP NOT AVAILABLE" from the minimap), or a Pulse onboarding that finds targets by anchors beside a
   Classic screen that has none. The fallback exists for exactly that case and produces a broken set in it.
2. **Nine edited scripts, six of them style branches or option growth inside Classic code.** This is the contradiction the
   critic named, brought back at smaller scale: MobileDriveControlsClient (driving input), GarageEntranceClient,
   RaceTransitionClient, OwnedGarageWorkspaceUI, MapIconLayer, RouteGuide. The backup is no longer provably the old UI,
   Classic runs through edited code in every session, and full removal needs rollbacks in reverse order across six phases
   that any unrelated delivery to those scripts will break. A and C show that five or six of the nine can be avoided.

### Serious flaws

1. **Seam edit 9 is not "about 20 lines".** MobileDriveControlsClient has 26 instance builders, 6 corner calls (radius 16),
   5 stroke calls, a gradient, 7 colour literals and Michroma (lines 22-36, 54-60). A Pulse look there means a large branch
   inside the script that writes driving input. B's own rule says fused owners are never edited; edits 8 and 9 edit two.
2. **The recommended test route is a second experience.** It needs a place-guard change, installs every phase twice, and
   gives evidence from a place that is not v3. docs/13 section 4 says to use the existing no-save sandbox. The v3 fallback
   ("non-mutating flows") is wrong for anything that drives.
3. **Phase 9 retires Classic.** The brief is to keep the old UI. A retirement phase in an approved phase list reads as
   pre-approval.
4. **`Layers.setVisible` writes `ScreenGui.Enabled`.** See shared gap 1; B's Phases 3 and 4 run the Pulse HUD beside the
   Classic race menu and entry.
5. **An invisible `PlayerGui.SelectionImageObject` is global.** Classic screens still in use during Phases 1 to 7 lose the
   focus box for gamepad players.
6. **Three new ClientBase entries exist in Classic too** (two inert, one tool). Classic start-up state changes.
7. **Phase 0 is labelled Fast** but sets up a second experience, a guard change and a spike.
8. **About 3,400 lines of logic copied by hand**, checked only by contract tables and the reviewer. No automatic parity.
9. Smaller: the shared desk controller passes the Classic tier palette (OwnedGarageWorkspaceUI line 15) to the Pulse view;
   the activity design-pixel frame is not mentioned; chat, bubble chat, health and backpack add more service-level writers;
   Pulse reads Classic folders for behaviour values, so tuning one tunes both.

### Claims checked

| Claim | Result |
|---|---|
| ClientBase 105-108; ClientLifecycle 38-44, 29, 36 | Correct |
| `ReplicatedStorage.Modules.Core` contents; no flag reader | Correct |
| Loading view hard-wired at 8, 40, 47 | Correct |
| Start screen 13, 15-18, 22-23, 38, 53 | Correct |
| SharedTopNotificationUI 17; OwnedGarageClient 8-9 | Correct |
| Desk controller: requires on line 12; uses only `ProjectEconomy`, `ConfirmationModal`, `UI.Asset`; no `Instance.new` | Correct (0 `Instance.new`; `Shared.` at 30 and 79). It is not style-free: 9 `Color3.fromRGB`, including the tier palette at 15 |
| ActivityClient 23-43, 71-88, 293 | Correct |
| GarageEntranceClient private label 70-106; RaceTransitionClient label 57-72 | Correct (Michroma at 70) |
| Requirers 19, 9, 8 | Correct |
| MobileDriveControlsClient gate at line 12 is `TouchEnabled` | Correct |
| `TutorialTargetId` is written by GarageWorkspaceUI and read by nothing | Correct (164 and 165) |
| Seam edit 9 is about 20 lines of art ids, tints and margins | **Not credible**, see serious flaw 1 |
| "Owners with logic and view fused in one closure are never edited" | **Contradicted** by edits 8 and 9 |
| v3 can be used for "non-mutating flows" | **Wrong** for any driving test |

### Best ideas

- `UIStyle.Claim(surface)`: a run-time assertion that a surface has one Pulse owner.
- Garage route table with `Hub` and `Tabs`: like for like first, the new navigation separately switchable.
- Roles, not colours: a screen cannot pass a `Color3` to a component.
- Kit timing and write counters published as attributes on a client-only folder, readable without a require.
- One HUD owner; class from geometry, arrangement from `TouchEnabled`, the same gate the drive controls use.
- Profile fingerprint before and after each session, and the negative-user-id local server check.
- The plain statement of what the backup costs, and "a later server change must keep Classic working or Oscar ends the
  backup".
- Creation and source edits never share a call; create op proven with save and re-read.
- Reviewer on every edit to an existing script, even inside a Standard phase.

---

## 4. Proposal C: quality and speed

### Fatal flaws

None that cannot be fixed inside its own design. The nearest are serious flaws 1 and 3.

### Serious flaws

1. **The pilot is the screen with the hardest touch coupling.** Phase 2 replaces RaceBrowserClient while both Classic HUDs
   still run. On touch the Classic race menu hides every other ScreenGui by force and does not publish presentation mode
   (402-411). The Pulse pilot must either copy that hack over Classic ScreenGuis or leave the Classic mobile HUD on top of
   the new menu. The Phase 2 gate does not test it.
2. **Driving input and map renderers are forked by hand.** MobileDriveControlsClient is routed to new Pulse touch controls,
   and `IconLayer`, `RouteLayer` and `MapMathEx` are new copies. The tutorial contract omits `DriftLeft`, `DriftRight` and
   `Boost`, so the `MobileDriving` tutorial page is lost on touch from Phase 3 to Phase 8.
3. **The navigation change ships with the first Pulse purchases.** Tabs and the Shop/Owned switch are built into the Phase
   6 controller. There is no like-for-like Pulse garage to compare purchase, equip and preview-clearing flows against
   Classic, and no Pulse hub to fall back to if Oscar rejects the tabs.
4. **Garage and owned garage are split across Phases 6 and 7.** That is why C must forbid the name `CanonicalGarageGui`
   and accept a dealership tutorial gap. Delivering both together (as A and B do) keeps the name and the tutorial.
5. **The interim contract misses player attributes.** `MobileMajorMenuOpen` and `MobileFreeRoamCarMenuOpen` are read by the
   Classic full map (until Phase 8) and the Classic interior HUD (until Phase 7). If the Pulse HUD does not write them, the
   full map can open over a Pulse modal on touch.
6. **The family fallback is not prefix-closed.** C relies on "a newer Pulse family only ever meets older Classic families",
   but a missing module makes only that family Classic. A missing HUD family with a present map family gives a Classic HUD
   beside a Pulse map.
7. **"No UIScale anywhere" is false while the activity views are unchanged** (shared gap 4).
8. **Ten large kit modules with no size or local-count guard** (200,000 characters; the 200-local limit has bitten this
   project before).
9. Smaller: `PlayerGui.SelectionImageObject` is global in Pulse, so Classic screens show the kit focus frame in the interim;
   slice images are uploaded even if unused; the caps sprite sheet is a custom text renderer and should stay a last resort;
   the optional kill switch adds a server writer and a 2 second start-up wait; the Classic proof is weaker than A's
   (captures compared by eye, no programme-wide record).

### Claims checked

| Claim | Result |
|---|---|
| ClientBase 5, 104-112; ClientLifecycle 20-47 | Correct |
| LoadingTransitionRuntime 8, 33-47; start screen 13-53 | Correct |
| SharedTopNotificationUI 17; OwnedGarageClient 8-9 | Correct |
| Desk controller 12-13, 30, 79; two members of GarageComponents used | Correct |
| GarageInteriorTransitionUI line 6 requires the browser and desk by name | Correct |
| GarageComponents 294-311 adopts any ScreenGui named `CanonicalGarageGui` | Correct. It also forces a 1600x900 canvas, DisplayOrder 40, and deletes other UIScales on the canvas |
| FullMapUI 464-478 needs a showing `Minimap` under either HUD name | Correct |
| OnboardingClient 666-671 locks every GuiButton named Car, Race or Garage | Correct |
| RouteGuide 34-39, 89-91 | Correct |
| ProfileServer 179-226, 252: empty garage, 1,000,000 Cash, no save | Correct |
| `lighting_realism/step2/install.lua` has a create op (61, 102) | Correct |
| RaceLifecyclePresentationClient 23-35 kill list | Correct |
| GarageUI 274-282 empty-slot detour | Correct |
| "Old onboarding cannot see garage pages between Phase 6 and 8" | Overstated. Only the Dealership page is tied to `CanonicalGarageGui` (OnboardingClient 142-147). Workshop pages are found by attributes anywhere in PlayerGui |
| "No UIScale anywhere in the new UI" | **Wrong** while the activity views are unchanged |
| Tutorial contract is complete | **Wrong**: `DriftLeft`, `DriftRight`, `Boost`, `AccessControls` missing |
| "A newer Pulse family only ever meets older Classic families" | **Not enforced** by the fallback |

### Best ideas

- Family-atomic route swap with ClientBase edited once and all later changes in a `Routes` data module.
- The gallery: any view mounted with fixtures, no remotes, no profile. Results and rare states are checked without
  finishing a time trial.
- The probe set: instance census, churn probe, static-layer write probe, layout lint (whole pixels, 48 dp targets, minimum
  text, reserved names).
- `Kit.Input.Mark`: views never type a legacy name; the same call registers the target for the new onboarding.
- The read-only `GetRouteState()` getter in RouteGuide.
- The two-function shim for the desk fork, with the fork proven by diff.
- Freeze Classic per family once its Pulse version is confirmed, not for the whole programme.
- A separate small fix for PB-01 before any agent finishes a time trial.
- Bool attributes read with `== true`; fetch first, then draw, with one render token per screen.
- Rendering spike before any install; uploads at the end of the spike so moderation is done before use.

---

## 5. The plan I would build

A's switch and proof, C's tooling and model-plus-view owners, B's garage route table. Changes from all three are marked.

**Switch**

1. One string attribute `UIStyle` on `Config.UI` plus a preview user list. Read once by a latch in ReplicatedFirst (A).
2. Two supported states only: all Classic, or every delivered family Pulse. `Routes` holds an ordered list of delivered
   families (C). A diagnostic prefix cut is Studio only and prefix-closed.
3. No timing-based fallback and no partial fallback. The style comes from the attribute alone. Install AUDIT is what
   guarantees every delivered Pulse module exists. As a safety net, ClientBase makes one all-or-nothing check after
   `game:IsLoaded()` and before `lifecycle.start`: if any delivered module is missing, every ClientBase entry is Classic
   for the session, with one warning. The loading view (Phase 7) only depends on its own ReplicatedFirst modules and the
   kit, behind a protected require. No fallback after any start. (Changed from A, B and C.)
4. Every Pulse owner calls `Claim` first (B) and marks its ScreenGuis; a census runs at every gate.

**Edited scripts: four**

ClientBase (once), RouteGuide (one read-only getter, replacing A's mirror), LoadingTransitionRuntime (line 8),
InitialLoadingAndStartScreenClient (guard after line 18). Reviewer on each. Nothing else in Classic changes, and A's
record of 221 hashes, the typed config dump and the Play record prove it in every AUDIT.

**How each kind of owner is replaced**

| Owner | Route |
|---|---|
| Controllers that spend Cash or hold saved ids and already have a separate view (GarageUI, OwnedGarageWorkspaceUI, GarageEntranceClient, GarageInteriorTransitionUI) | Generated from Classic with a fork list and automatic parity of remotes, bindables and attribute writes (A). All three requires on the desk's line 12 handled, with C's shim. Views are new kit views |
| MobileDriveControlsClient | Generated copy with an input-write parity check. Not hand-forked (A, C) and not branched in place (B) |
| HUD, race session, race menu and entry, full map, onboarding, start screen | New headless model plus kit view (B, C), with a parity table generated from Classic source and gallery fixtures. No `RacingCompat` layer for these |
| Activity HUD | New owner, same `ctx`, design-pixel frame as the one UIScale exception (A) |
| Minimap | Shared MapIconLayer in host-projection mode; route state from the new getter |

**Rules added to the kit contract**

- Pulse owners never write `ScreenGui.Enabled`; root `Visible` only.
- Name, text, attribute and player-attribute tables are generated from Classic source and enforced by lint and a Play probe.
- Selection image per component (A). Roles, not colours (B). Counters as attributes (B). Size and local-count guard in
  the build (A).
- World prompt banner has a run-time fail-safe back to Default.

**Phases** (approved as one list; each has its own contract, one installer run, reviewer before APPLY where marked)

| # | Phase | Lane | Notes |
|---|---|---|---|
| 0 | Decide and prove | Standard, reviewer on the engine | Decisions; Classic record taken twice; baseline with C's probes; rendering spike in the sandbox; module-create pilot with save and reopen; generated contract tables; sheet v2; AGENTS.md exception text |
| 1 | Foundation and switch | High-Risk | Latch, Routes, kit, toasts, confirm, gallery, probes. ClientBase edit. Toasts are the pilot |
| 2 | Free-roam HUD | Standard, High-Risk gates on spawn, despawn, exit, teleport | Desktop, tablet, phone; generated touch controls; activity HUD; core UI policy; RouteGuide getter |
| 3 | Race session and results | Standard, results from payload only | Results checked from fixtures; no agent time-trial finish until PB-01 is fixed |
| 4 | Race menu and entry | Standard, gates on teleport, queue, vehicle start | Both together, so the Classic touch suppressors leave together |
| 5 | Garage and owned garage, like for like | High-Risk | Both together, `CanonicalGarageGui` names kept, Classic onboarding keeps working; `Hub` route (B) |
| 6 | Full map, world prompts, event card | Standard, High-Risk gate on prompt triggering | |
| 7 | Onboarding, loading view, start screen | High-Risk | Same page ids; full replay on a fresh sandbox profile |
| 8 | Garage navigation (`Tabs`, Shop/Owned) | High-Risk, own contract | Can be declined |
| 9 | Whole-game matrix and default flip | High-Risk | Classic stays installed and switchable. No retirement phase |

**Testing and delivery**

- Per-phase folder under `scripts/ui_restyle/`, one engine, CONTRACT.md first, exact before-sources, AUDIT, reviewer,
  APPLY, ROLLBACK, APPLY, save and reopen, AUDIT again, Play, `verification.json`, docs 00, 06, one 07 entry, commit.
- Hierarchy and config in one transaction, sources in a second.
- Agent Play only inside a guarded sandbox window (needs Oscar's yes); profile fingerprint before and after (B).
- Parallel agents: one folder each, never Studio or git. The integrator installs and Play-tests.
- While the backup exists, later deliveries that touch a payload or config Classic reads run a Classic smoke check.

## 6. Not verified

- Nothing was run in Play. The stale-restore sequence in shared gap 1 is read from source, not observed.
- Whether ClientBase can run before ReplicatedStorage has finished replicating was not tested. The plan above waits for
  `game:IsLoaded()` before its one existence check so it does not depend on the answer; that wait is new in the Pulse
  path only and its cost should be measured in Phase 1.
- Net's busy-lock behaviour for the event card's requests was not read.
- The step-target names inside OnboardingClient's page tables were taken from the audit note, not re-extracted.
