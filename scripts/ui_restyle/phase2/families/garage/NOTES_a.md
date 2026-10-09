# Garage family, half A (dealership and customise): notes for the integrator and the reviewer

Status: **generated, not installed, not run.** There is no offline Luau here: every source was desk-checked line by
line, block structure and undeclared names were checked by two throw-away scripts, and `gen_actions.py --check` was run
and passes. No test has been executed. Half B's files were not touched.

## 1. Files (all under `scripts/ui_restyle/phase2/families/garage/`)

```text
gen_actions.py                 reads the Classic GarageUI and GarageCatalogClient sources; writes actions.json and the
                               generated block of the model test; --check also compares the model's call sites
actions.json                   24 remote call sites (20 GarageInvoke sites over 16 actions, 4 GarageSessionRequest End)
after/…UIPulse.Garage.GarageRoutes.lua        navigation as data, slot artwork rows, every player-facing string
after/…UIPulse.Garage.GarageModel.lua         the port of GarageUI: state, selectors, transitions, remotes, preview
after/…UIPulse.Garage.GarageScreenView.lua    dealership and customise pages, Regular and Compact
after/…UIPulse.Garage.PaintView.lua           channel switch, three sliders, presets
after/…UIPulse.Garage.GarageModals.lua        cash, properties, move-module and buy-vehicle modals
after/…UIPulse.Garage.GarageClient.lua        the entry that replaces GarageUI
after/…UIPulse.Dev.Fixtures.Garage.lua        9 gallery items, 24 states, over a fake model
tests/…_test.lua               one per module (7 files for this half; 11 in the folder with half B)
contract_a.json  routes_a.json  spec_ops_a.json  CONTRACT_a.md  NOTES_a.md
```

`spec_ops_a.json` creates the `UIPulse.Garage` folder first; half B's fragment has no folder op and depends on it.

## 2. How the safety work is done

- **Action table.** `gen_actions.py` parses every `action:Call`, `self:Call` and `action:Session` in the Classic source
  and records remote, action, payload keys, the expression each key is given, the line, the enclosing function and
  closure, and a sentence on the state that reaches it (the sentence table is keyed by call site; a missing or stale key
  fails the run). `GarageModel.Actions` lists the same 24 rows; the model test compares it with the generated block.
- **Call sites.** Every remote call in the model is one line `call("<remote>", "<action>", {…}) -- GarageUI L<n>`.
  `gen_actions.py --check` reads those lines and fails unless remote, action and payload keys equal the Classic call
  site at the cited line, every Classic call site is cited, and no `call("` exists outside that form. The last model
  test asserts that every `(remote, action, keys)` seen through the fake remotes is in the table and every row was sent.
- **Busy guard and no retry.** `call` is `Adapter:Call` (L21-34) statement for statement: one `GarageInvoke` in flight,
  "Please wait." for a second one, "Garage server did not respond." for a failure, then `Catalog`, `Profile` and
  `Data.ProjectEconomy(result)`. Nothing is sent twice. `GetInitial` goes through the shared `GarageCatalogClient.Fetch`.
- **Affordability and prices.** Prices on screen are catalogue values or reply fields passed through `Data.Money`.
  Dealership tiles compare `leaderstats.Cash` with the catalogue price (Classic `RefreshVehicleCardAffordability`);
  cosmetic and neon tiles compare `Profile.Cash` from the last reply (L556, L579); module shop tiles compare nothing.
  In all three cases the result only mutes the price: **the BUY button is never disabled for lack of Cash and the
  request is sent exactly where Classic sends it.** No Cash arithmetic exists in the family.
- **State and transitions.** `State` has the fields of L44 with the same values. Each Pulse control runs the Classic
  closure of the control it replaces; `GarageRoutes` says which (tabs = L303-305 / L214-216, Shop and Owned = L344 and
  L343, Back = the steps of L362-375, L477, L660-669).
- **Preview.** `buildPreview` keeps the Classic read-only guard and calls `PreviewVehicleClient.Build` only when a key
  made of everything `Build` reads has changed (the shown profile's full fingerprint, `SelectedCockpit`,
  `PreviewModules`, `PreviewNeonSlot`, `SelectedSlot`, `SelectedModuleId`, `SelectedModuleInstanceId`,
  `ThrustPreviewActive`) or the preview root or vehicle is gone. `ApplyPaint` changes the profile, so the next call
  after a paint differs and rebuilds, as Classic's would.

## 3. Classic behaviour not reproduced exactly (exhaustive; each is also in `contract_a.json`)

Navigation, by design of API2 5.7:

1. **Hub page removed.** Where Classic drew the hub (after picking an owned vehicle, on the drive-in entry, after
   post-purchase paint, on Back from a workshop) the Parts tab opens with the hub's Add Modules closure. `State.Stage`
   is `"Hub"` only for the instant between the two.
2. **Back.** From Upgrades and Paint, Back opens the Parts tab (Classic: the hub). On the Parts slot list Back is shown
   **disabled** (Classic's hub had no Back; the Classic slot list's Back went to the hub). The only ways out of customise
   are Drive, as in Classic.
3. **"Owned Modules / Buy Modules" page removed.** Choosing a slot opens the Shop list; after the empty-slot detour the
   Owned list opens when a compatible owned module exists. Back from a list runs both Classic Back steps (list to
   sources, sources to slots or to the detour's origin). The Owned side of the switch is locked exactly when Classic's
   Owned card was (no compatible owned module).
4. **Tabs everywhere.** Classic offered the three workshops from the hub and from Add Modules pages only; the tabs are on
   every customise page. A tab change runs the same closure, so the transient preview is cleared as before. As in
   Classic's workshop rail, a tab change does not clear `ReturnWorkshop`.
5. **Left rails became one picker.** The slot rail (Upgrades) and target rail (Paint) are a dropdown under the header
   carrying the `Categories` mark; an unfitted slot's option ends in "EMPTY" (Classic: a muted card). Mockup 06 shows
   the paint areas as a tile rail instead; with the rail used for the Paint / Neon / cosmetic cards (which the previews
   do not lay out) I kept Classic's split of "picker on the left, cards or colour controls below".

Additions that change what the player does:

6. **Purchase confirmation for a vehicle** (preview c15) before `BuyCockpitInstance`. Same call site and payload; cancel
   sends nothing. The "cash after" and "spaces after" rows of the preview are **not** shown (client arithmetic).
7. **Toast with every inline message** (`ShowTopNotification`), including the success line "Module purchased and equipped."
8. **Disabled main button while nothing is selected** (BUY / EQUIP / UPGRADE), so a selection creates nothing. This is
   "nothing selected", never "cannot afford".

Presentation differences with a behavioural edge:

9. Dealership BUY shows the price on every device (Classic omitted it on touch).
10. The dealership opens with the tiles drawn and none selected for one deferred step (Classic drew no tiles until the
    automatic first selection). On the first open the stat panel reads NO VEHICLES AVAILABLE for that step; on a
    category change it keeps its previous content, as Classic did.
11. After a refused `UpgradeModule` the card is deselected with the message (Classic left it looking selected).
12. After a garage property purchase the Spaces text is redrawn (Classic left it stale until the next page).
13. A module's rating is on its status line, not a badge. Module, slot and upgrade tiles carry `CanonicalGarageCard`
    but not `CanonicalGarageCardId` (question 4 below).
14. Paint: no CURRENT swatch; Compact shows the first preset row only. A channel with no saved colour starts at
    `Color3.new(1, 1, 1)`, exactly as Classic (GarageUI L523; `PaintView._seed`), so this is no longer a difference.
    Channel names are words ("Front lights"), where Classic upper-cased the id.
15. Stat rows: the kit shows the previewed value with a delta chip; Classic showed value and signed difference. Same
    numbers (`floor(x + 0.5)` of the same headline fields, same `StatReference`).
16. Not carried: carousel arrows, scroll memory, mouse-wheel scrolling of the left rail, the geometry and ownership
    audits and their console lines, `[Garage Route]` prints.
17. A `GarageSessionRequest` reply that is not a table is treated as "Garage session did not respond." (Classic would
    index it).
18. The camera step is bound through `Kit.Perf` to the live layer root; it runs while a page shows. Classic's ran from
    `startCamera` to `closeCamera`, which is the same interval except the moments inside `open()` before the first draw.

## 4. API and seam questions (the reading used)

1. **Roots and slots.** API2 5.7 wants `CanonicalGarageBrowser` and `CanonicalGarageWorkspace` under the layer root with
   the marked targets inside them, and API2 6.2 wants positions only from slots, which are children of the layer root.
   I create the two page frames under `layer.Root` and compose slots inside each with `Layers.Stage(page, ctx, "Scene")`
   (as half B's desk does). If `Layers.Stage` is meant for the gallery only, the alternative is a kit call that makes a
   named sub-root with slots.
2. **The static root is never hidden.** Half B's desk parents its root into `CanonicalCanvas`, so `GarageClient` leaves
   `layer.Root` visible and the view hides its two pages, its scrim component and the live layer instead. The camera
   step is bound to the live root for the same reason.
3. **Page marks.** The tab bar is marked `Page.CustomisationHome` once. One `Body` frame holds the rail, picker and
   budget and is **re-marked** with the current tab's `Page.<id>` on a tab change (the attribute changes; nothing is
   created). `Input.Marked("Page.AddModules")` therefore still lists the body on other tabs: the Shell family should read
   the instance's `PulseMark` or `TutorialPageId` attribute. On post-purchase paint the body is hidden.
4. **`CanonicalGarageCardId` for slot ids.** My brief asks for slot ids through `Input.Mark`; `Kit.Contracts.Marks` has
   `Card.<id>` for nine ids and no slot id. The view uses `Card.<slot id>` when the key exists, else `Card`. Classic
   onboarding filters by `AddModules`, `UpgradeModules`, `PaintShop` only, so it is unaffected. If slot ids are wanted,
   K1's generator needs the keys.
5. **`Capacity`.** The status strip (with the Cash chip) is on the live layer, as API2 3.4 asks. Classic onboarding
   looks for `Capacity` under the dealership page, so the view puts an empty frame of the strip's size, marked
   `Capacity`, in the page's `TopRight` slot. `StatusCluster` itself is not marked.
6. **Instance budget (programme contract 5.2: 240 live).** Not met in every state by construction: the kit's own
   budgets give 84 for a stat panel with six rows and 13 per tile, so a stat panel plus twelve tiles is already 240.
   What I did: only one of the two pages is kept; the customise stat panel, switch, picker, budget, paint controls and
   modals are built on first use. The view test asserts 240 for every non-paint state and 320 for the colour pages (26
   preset swatches at 3 each). Both numbers are estimates until the test runs. A decision is needed if the census
   counts hidden instances or pooled tiles.
7. **Token requests.** `PaintView` sizes its panel and Compact sliders from existing tokens by arithmetic
   (`StatPanelHeight - 2 x ButtonHeight`, `ListWidth`, `CompactStatPanelWidth`, `CompactStatusHeight + 2 x TouchMin`).
   Proper tokens (`PaintPanelWidth`, `PaintPanelHeight`, `CompactPaintSliderWidth`, `CompactPaintHeight`) would be
   cleaner. The modal uses `ConfirmWidth` x `StatPanelHeight`.
8. **Lint exceptions to confirm.** (a) `PaintView` builds `Color3` values (`fromHSV`, `fromRGB`, `new`) for the slider
   ramps and presets: the paint named exception of PC 2.3, needed by `Slider.Gradient` and `Swatch.Colour`.
   (b) `GarageScreenView` and `PaintView` create plain `Frame`s (page roots, holders) and `UIListLayout`s (one with
   `Wraps`), because the kit has no stack or grid container; sizes are `ctx.Px` of tokens. (c) `GarageClient` requires
   the shared modules listed on its line 2, including `VehiclePerformanceResolver`, `VehicleCatalog` and
   `GaragePropertyCatalog`, which API2 6.6 does not name but Classic GarageUI requires (not UI modules).
9. **Kit behaviours I relied on without being able to run them.** `Rail.SetItems({})` then `SetItems(list)` clears the
   rail's own selection without destroying pooled tiles (the rail has no deselect and `Select` errors on an unknown
   key); a tile ignores `Rating` without `Tier`; `ButtonRow.Set({Buttons = …})` with the same ids patches in place;
   `Header.Set({Tabs = …})` keeps the same `header.Tabs` instance; `Tabs` with `Bumpers` or `Triggers` only reacts while
   shown (the model ignores a stray call anyway); `StatPanel`, `StatusCluster`, `Rail`, `Tabs`, `Dropdown`,
   `SegmentedBar` and `Surface.Scrim` accept `Visible` in `Set`; `Slider` fills a parent that has a width.
10. **Replicated Cash for tile affordability.** `Kit.Data` exposes `BindReplicatedCash` only through `CashChip.Bind`, so
    `GarageClient` listens to `leaderstats.Cash` itself (read only, scoped, no wait) and tells the model. A
    `Data.BindCash(player, callback)` would remove the duplicate.
11. **Test harness.** The model test replaces `Kit.Data._foundation` on the module `env.Load` returns; this assumes the
    harness gives the model the same `Kit.Data` table. It loads the shared `GarageModuleCardViewModel` through
    `env.Load` when the harness can, else uses a stand-in with the same row fields. Family modules reach the kit as
    `script.Parent.Parent.Kit.<Name>`.
12. **`Presence`.** `GarageClient` opens `Presence.Open("Garage", "Garage")` while `Player@GarageSessionActive` is true.
    Half B does not open that surface. The panel modal registers itself as `CanonicalGarageModal` (kit behaviour).
13. **Dealership gallery state "Loading".** Used for the one-step state before the first row is selected; there is no
    other loading state (the loading transition covers the fetch).

## 5. What the integrator must check in Play (sandbox window only)

Purchase matrix, Classic against Pulse, same sequence, equal profile fingerprint at the end:

| Step | Expect on the wire (and nothing else) |
|---|---|
| Dealership entry | `GetInitial` once (twice only when the catalogue revision is stale) |
| Buy a vehicle: press BUY, then CANCEL | nothing |
| Press BUY, then BUY | one `BuyCockpitInstance {CockpitId, CategoryId}`; post-purchase paint opens |
| Buy with too little Cash | the same one call; server refusal as inline line and toast; no second call |
| Double press on the confirmation, or a second purchase while one is in flight | one call; "Please wait." for the other |
| Post-purchase paint: drag, release, preset | no call while dragging; one `SetCockpitColor {… Scope = "WholeVehicle"}` per release or preset |
| Parts: Shop, buy unlocked module | `BuyModuleInstance {ModuleId, VehicleId, SlotId}`; locked module offers no BUY |
| Parts: Owned, equip free module; equip one in use (NO, then YES) | `EquipModuleInstance {… AllowReassign = false}`; nothing; `{… AllowReassign = true}` |
| Upgrades: upgrade until the budget is full and until a level is maxed | `UpgradeModule {SlotId, ModuleId, UpgradeId}` each; no button on a maxed or limit-reached card |
| Paint: each target (All, Cockpit, Thrust, Underglow, a slot; Neon channel) | the action of `actions.json` lines 115-122 |
| Paint: buy Thrust Colour, Underglow, a slot's Neon | `BuyVehicleCosmetic {CosmeticId}`, `BuyNeon {SlotId}`; then the colour controls open |
| Spaces plus: buy a property | `BuyGarageProperty {PropertyId}`; an owned row does nothing (sandbox no-save extent applies) |
| Drive without boost | nothing; the Classic sentence as inline line and toast |
| Drive | `GarageSessionRequest End {ReturnToEntry = true}` then `SpawnVehicle {}`; vehicle spawns |
| Exit from the dealership; each of the three entries; entry refused without a vehicle | as the model test cases of the same names |

Also: Cash chip and tile prices never move before a reply; the empty-slot detour from Upgrades and from Paint and
both returns (after BUY, after EQUIP, by Back); orbit and zoom of the preview with the pointer over empty scene, and
blocked over panels, tiles and sliders (page frames are `Active = false`); `churn_probe` on a tile selection, a tab
change and a Cash change (0 expected); the preview is not rebuilt on an upgrade-card selection or a channel change
(count `LocalVehiclePreview` child churn); Classic onboarding pages 1 to 5 and 9 to 14 find their targets (`Categories`,
`Stats`, `Capacity`, `VehicleScroller`, the three tab buttons, `TutorialCardScroller`, `UpgradeBudget`); the desk of half
B shows with no dealership session open; `GaragePreviewPresentationClient` lighting follows the session;
`StartupState.GarageUI` is `ready` with no remote reply pending; the instance census per page; Compact (C844, C568) fit
of the paint controls and of the stat panel on the dealership; a gamepad pass (bumpers, triggers, B on modals).

## 6. Reviewer-fix pass (2026-10-09): what changed and what remains

Applied after the delivery review of the whole family. No remote, action, payload key or value source changed:
`gen_actions.py --check` still reports 24 call sites equal to Classic, `fork_check.py` passes the 4 forks.

1. **A draw fault no longer strands the player.** `GarageClient` wraps every draw in `Client._protect` (pure, tested).
   On a fault it warns once (`[Pulse.GarageClient] render failed; closing the garage: <error>`), then, deferred so the
   model transition that raised it finishes first, calls `GarageModel.Abort()` and releases the broken view.
   `Abort` runs the Exit function unchanged (GarageUI L195: loading Begin, `GarageSessionRequest` `End {ReturnToEntry}`,
   close, `GarageClosedFromDealershipExit`, loading Complete) from any page, then fires `ShowTopNotification`
   "Garage unavailable". The server clears `GarageSessionActive` on End; the client clears `GarageEntryMode`, releases
   the camera and drops the preview. It adds no call site (the model's 24 `call(...)` lines are untouched).
   - **End refused or unanswered:** `Abort` still closes the client side (loading Fail, attribute cleared, camera back),
     as the open path already does at L684 and L689 where it ignores the End reply. The server may then still hold the
     session (`GarageSessionActive` true, so Presence stays open) until the player re-enters or the server times it out.
     That is a server state Classic can also reach from those two lines; it is not retried.
   - **A purchase in flight when the fault lands:** the purchase's own continuation runs after the close, exactly as it
     would if Exit were pressed during a purchase (Classic has no guard there either). Not changed.
2. **`start()` builds nothing fragile.** The view is mounted the first time the model has something to show, inside the
   protected draw; `Surface.Scrim`, the status strip and both pages are therefore built on first open, not at start.
   The entry events are connected before the optional parts, and the camera step, the Cash watch and the Presence
   mirror are each protected and reported once. **What can still fail `start()`:** a missing or throwing module at
   require (the ten shared modules, `Core.ConnectionScope`, the kit), `Switch().Claim`, the two `Layers.Create` calls
   and `GarageModel.new` (a table constructor). The `WaitForChild` calls do not fail, they wait. If `start()` does
   fail, the entrance fork still sends `Begin` and waits 5 s for the event before its own Classic fallback (kept lines
   158-166: `End`, attribute cleared, loading Fail, "Garage UI handoff is unavailable."), but only when the event
   instance is missing; an event that exists with no listener still leaves the loading screen up. That case needs a
   change to kept Classic lines of the fork and was not made.
3. **Shop / Owned switch** (`SelectSource`) now clears the transient preview and calls `buildPreview()` before choosing
   the source, which is Classic's Back from Options (L363-367) followed by the source card (L343, L344). Pure test added.
4. **Unset paint channel:** see 3.14 above. Pure test added (`PaintView._seed`).
5. **Gamepad focus.** The three garage rails (dealership, customise, desk) pass `SelectOn = "Activate"` (new optional
   `Collections.Rail` prop, `../../API2_AMENDMENTS.md` A1): focus only highlights, selection needs an activation. This
   needs the kit change installed first. The dealership rail is included because a selection there builds the 3D
   preview and arms BUY; say so if focus-to-preview is wanted back there (remove the one prop at `ensureBrowser`).
6. **Declarations.** `contract_a.json`: `replaces` names `GarageComponents` (its generated contract exists); the two
   `SelectVehicleInstance` sites share a row (keys are the union, each site's keys under `sites`); one
   `LoadingTransitionInvoke` row with the union of keys and the per-action keys; names are the bare mark keys; prefix
   attribute names; the camera step is render step `GarageCamera` with an `added` entry. `parity_check.py garage`: 0 open.
7. **Lint:** 0 open. Six accept rows in `../../integrator/lint_accept.json` (the bindable created under a Classic name,
   three look-free Classic data modules, paint colour data in `PaintView` and `OwnedGarageDeskView`). Fork-kept lines
   need no row once `build_forks.py garage` has run (it has; `integrator/forks_out/garage/` is generated).
