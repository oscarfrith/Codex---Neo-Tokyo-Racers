# UI restyle audit: garage-core

Read-only audit of live Studio (Space Racers v3, placeId 93959280828322, Edit mode) on 2026-10-08.
Nothing was changed in Studio or the repo. Line numbers are live-source line numbers.

## Coverage

Read completely:

| Script | Lines | Chars |
|---|---:|---:|
| `ReplicatedStorage.Modules.Game.Garage.GarageUI` | 703 | 61,205 |
| `ReplicatedStorage.Modules.Game.UI.GarageWorkspaceUI` | 363 | 50,125 |
| `ReplicatedStorage.Modules.Game.UI.GarageBrowserUI` | 130 | 22,271 |
| `ReplicatedStorage.Modules.Game.UI.GarageComponents` | 357 | 49,472 |
| `ReplicatedStorage.Modules.Game.UI.GarageModuleCardViewModel` | 72 | 4,272 |
| `...Garage.PreviewCameraClient` (UI coupling) | 57 | 8,158 |
| `...Garage.GaragePreviewPresentationClient` (UI coupling) | 339 | 11,677 |
| `...UI.RacingUIComponents` (the layer under GarageComponents) | 194 | 8,409 |

Partly read: `ResponsiveUIFoundation` (L1-140 plus StyleMetric, ProjectEconomy, BindReplicatedCash, Confirmation), `OnboardingClient` (L104-112, L140-201), `ClientBase` (head, tail, GarageUI entry). Other scripts were only pattern-counted.

All listed paths exist. The scripts have very long lines (many statements per line), so a line reference often covers a whole function.

## How the four pieces fit

```
ClientBase (composition root)
  -> Garage.GarageUI.start()            controller: state machine, navigation, remote dispatch, preview, modals
       -> UI.GarageBrowserUI.new()      view: vehicle browser (Dealership / Customisation vehicle pick)
       -> UI.GarageWorkspaceUI.new()    view: every other garage page (hub, add, upgrade, paint)
       -> UI.GarageComponents           shared host ScreenGui, shell layout, cards, popup, stat panel
       -> UI.GarageModuleCardViewModel  pure data: owned/shop module rows
       -> UI.RacingUIComponents         Button/Panel/Label/Colour/Font -> ResponsiveUIFoundation
```

`GarageWorkspaceUI` is not garage-only: `OwnedGarageWorkspaceUI` L12-13 also calls `WorkspaceUI.new()` and renames that root `OwnedGarageCanonicalWorkspace`. `GarageComponents.VehicleCard` is also used by `DesktopFreeRoamHudUI` (L744, L775), `MobileFreeRoamHudUI` and `RaceEntryPresentationClient` (L659, L664). `GarageComponents.ActionButton / AnchoredDropdown / AttachDropdownChevron` are used by `GarageInteriorModeUI` (L14-24).

---

## 1. GarageUI (controller)

### 1.1 Purpose and lifecycle

- The garage application: owns the session state, page navigation, every garage remote call, the 3D preview and camera, and four small modals.
- Started once by `StarterPlayerScripts.ClientBase` (entry `GarageUI`, path `ReplicatedStorage.Modules.Game.Garage.GarageUI`, dependencies `DriveSessionClient`, `LoadingTransitionUI`, `SharedTopNotificationUI`; ClientBase L88-91, started through `Core.ClientLifecycle.start`).
- `Client.start()` (L6) is guarded by `started` (L5-8). Everything, including `State`, is a local inside `start()`. Nothing is exported: the `return {Active=true,...}` at L699 is the return of `start()`, which the lifecycle ignores. There is no `stop()`.
- Permanent connections: three BindableEvent listeners (L695-696). Session-scoped: one `RenderStepped` camera connection and the PreviewCamera input connections (L128-136), released in `closeCamera()` (L147-150).
- The two views are constructed at start (L45) and never destroyed.

### 1.2 Instances it builds itself

- `CanonicalGarageModal` (L154-162): full-canvas black Frame, transparency 0.22, ZIndex 100, parented to the shared canvas. Inside it a `Shared.Panel` of fixed 620x420 (560x238 for the move confirmation), a heading label, and an "X" button 38x32.
- Four modal uses: `confirmModuleMove` (L163-170, YES/NO), `showCash` (L171, placeholder text "Cash packs are not configured yet."), `showProperties` (L172-175, scrolling list of garage properties with buy buttons).
- Everything else is drawn by the two views.

### 1.3 Page / state machine

`State` (L44): `Stage` (Closed, Browser, Paint, Hub, Build, Customise), `ShopMode` (Dealership, Customisation), `CategoryId`, `BrowseAll`, `SelectedCockpit`, `SelectedVehicleId`, `SelectedSlot`, `SelectedModuleId`, `SelectedModuleInstanceId`, `ModuleMode` (Slots, Sources, Options), `ModuleOptionMode` (nil, Owned, Buy), `CustomizeTarget` (ALL, Cockpit, THRUST_COLOR, UNDERGLOW, or a slot id), `CustomizeMode` (Colour, Overview, Upgrades), `SelectedColorChannel`, `SelectedPaintAction`, `PreviewModules`, `PreviewProfile`, `PreviewUpgradeId`, `PreviewNeonSlot`, `PreviewVFXMode`, `ReturnWorkshop {Target, Workshop}`, `CameraSection`, `NoPreviewYet`, `GarageCameraActive`, plus `Catalog`, `Profile`, `Economy` from the server.

Entry (L674-696): three BindableEvents in `PlayerScripts.Runtime.Dealership`:

| Event | Mode | First page |
|---|---|---|
| `OpenGarageFromIntro` | Dealership | Browser (buy) |
| `OpenOwnedCockpitCustomisation` | Customisation | Browser (pick an owned vehicle) |
| `OpenDrivingVehicleCustomisation` | DriveIn | Hub (despawns the driven vehicle first, L691) |

Pages, each a `render*` function that fills a context table and hands it to a view:

| Page | Function | View | Left rail | Bottom carousel | Buttons |
|---|---|---|---|---|---|
| Browser | `renderBrowser` L190-196 | Browser | Category buttons (ALL + listed) | Vehicle cards; popup on the selected card: BUY $x / BUY ANOTHER / CUSTOMISE | Exit |
| Paint Vehicle (after a purchase) | `renderPaint` L197-200 | Workspace | none | Paint panel, channels Primary/Secondary/Detail | "Customise" (to Hub) |
| Hub ("Garage") | `renderHub` L201-220 | Workspace | none | Three cards: AddModules, UpgradeModules, PaintShop | Drive |
| Add Modules: Slots | `renderBuild` L309-378, `ModuleMode="Slots"` | Workspace | Workshop rail (three workshop cards, L301-307) | Slot cards, EQUIPPED badge | Back (to Hub), Drive |
| Add Modules: Sources | same, `"Sources"` | Workspace | Workshop rail | Two cards: Owned Modules (a locked card when none), Buy Modules | Back, Drive |
| Add Modules: Options | same, `"Options"` + `ModuleOptionMode` | Workspace | Workshop rail | Listing cards (owned or shop); popup EQUIP / BUY | Back, Drive |
| Upgrade Modules | `renderUpgrade` L441-481 | Workspace | Slot rail (L385-393) | Upgrade listing cards + budget pips; popup UPGRADE | Back (to Hub), Drive |
| Paint Shop: Overview | `renderPaintShop` L619-673, `CustomizeMode="Overview"` | Workspace | Paint target rail (L540-552): All, Cockpit, Thrust, Underglow, slots | Paint card, Neon Lights card, or a cosmetic purchase card | Back, Drive |
| Paint Shop: Colour | same, `"Colour"` | Workspace | Paint target rail | Paint panel (channel tabs, three sliders, palette) | Back, Drive |

Where navigation is defined (the lines a tab merge would have to change):

- Hub cards: L213-217. Workshop rail (the same three closures, duplicated): L301-307.
- Add Modules back chain: L362-375. Upgrade back: L477. Paint Shop back: L660-669.
- Owned / Buy step: L340-344 (the Sources page), then L348-360.
- Cross-workshop detour: `routeToAddModule` L280-282 and `returnFromModuleRoute` L274-279 (an empty slot in Upgrade or Paint sends the player to Add Modules and back).
- The Hub has no Back and no Exit (`BackVisible=false` L209, `ExitVisible=false` L178). The only way out of customisation is Drive, which needs an engine, stabilisers and boost (L180).

### 1.4 Scaling and layout

None of its own. Modal sizes are fixed logical offsets inside the shared scaled canvas (L156-167).

### 1.5 Config read

- `Config.UI.GarageReplacement` attributes: `DealershipHiddenCategories` (L59), `VariantLabels_<categoryId>` (L91, for example `Lightweight=GT;Power=EVO`), `WorkspaceCardHeight`, `ModuleCardImageHeight` (L322-323), `CustomiseCategoryCardHeight`, `CustomiseCategoryImageHeight` (L465-466, L641-642), `CustomiseActionIconScale` (L626), `ModuleLockIcon` (L342, L358), `ModuleColourIcon` (L568), `ModuleNeonIcon` (L576, L582).
- `Config.UI.GarageReplacement.NavigationIcons` attributes (L89-90): `BackIcon`, `DriveIcon`, `CustomiseIcon`, `BuildModulesIcon`, `UpgradeModulesIcon`, `PaintShopIcon`, `OwnedModulesIcon`, `BuyModulesIcon`, `UnderglowSidebarIcon`, `UnderglowSidebarIcon_<categoryId>` (L548).
- Per-category artwork through `workspaceUI:ArtworkDefinitions(page, categoryId)` (L333, L386, L541), see 2.4.
- Server catalogue fields used for display: slot `RailLabel`, `Order`; cockpit `MenuImage / CockpitImage / ThumbnailImage / ImageId / Image` (L92-98), with `VehicleCatalog.Get` as fallback; module `CardTitle`, `VariantName`, `Price`, `NeonAvailable`, `NeonPrice`, `Upgrades`; `Catalog.VehicleCosmetics`.
- `ReplicatedStorage.Assets.VehiclePreviews.Categories` (L11) for previews and performance.

### 1.6 Remotes, bindables, attributes

- `ReplicatedStorage.Remotes.Garage.GarageInvoke` (RemoteFunction, L14). All actions go through `Adapter:Call(actionName, payload)` (L21-34): a `Busy` guard returns "Please wait.", the response updates `State.Catalog`, `State.Profile`, `State.Economy`, and `PresentationAudioBridge.Result` plays the outcome sound. `GetInitial` goes through `GarageCatalogClient.Fetch`.
- Actions sent: `GetInitial`, `EnsureCustomisationAccess`, `SelectVehicleInstance`, `BuyCockpitInstance`, `SpawnVehicle`, `DespawnVehicle`, `EquipModuleInstance`, `BuyModuleInstance`, `UpgradeModule`, `BuyNeon`, `BuyVehicleCosmetic`, `SetVehicleCosmeticColor`, `SetCockpitColor`, `SetAllNeonColor`, `SetModuleColor`, `BuyGarageProperty`.
- `ReplicatedStorage.Remotes.UI.GarageSessionRequest` (L15): `End {ReturnToEntry=true}` on exit, drive and failed open.
- `PlayerScripts.Runtime.UI.LoadingTransitionInvoke` (BindableFunction, L16): `Begin`, `Complete`, `Fail` with a generation (L46-52).
- Fires `Runtime.UI.FreeRoamVehicleSpawned`, `Runtime.UI.FreeRoamVehicleExited`, `Runtime.UI.ShowTopNotification`, `Runtime.Dealership.GarageClosedFromDealershipExit`.
- Player attribute `GarageEntryMode`: cleared on every close path (set by `GarageEntranceClient`).
- Public API: `Client.start()` only.

How actions are dispatched from the UI:

- Purchase of a vehicle: `OnPrimary` L194 -> `BuyCockpitInstance` -> Paint Vehicle page.
- Buy module: card `OnAction` L358 -> `BuyModuleInstance {ModuleId, VehicleId, SlotId}` (buys and equips).
- Equip: `equipInstance` L287-299 -> `EquipModuleInstance {ModuleInstanceId, VehicleId, SlotId, AllowReassign}`; a module in use elsewhere first shows `confirmModuleMove`.
- Upgrade: L437 -> `UpgradeModule {SlotId, ModuleId, UpgradeId}`.
- Paint: `handlePaint(target, channel, color, commit)` L111-124. Every slider movement previews locally with `PreviewVehicle.ApplyPaint`; only `commit=true` (slider release or palette click) calls the server.
- Neon and cosmetics: L554-617.

### 1.7 Input

No keyboard, gamepad or ContextActionService code. Buttons are plain `Activated` handlers.

### 1.8 Per-frame work and rebuilds

- `RenderStepped` while a session is open (L131): `PreviewCamera.Update`. It calls `Shared.CanonicalHost()` every frame, which does a `WaitForChild("PlayerGui")` and three parent checks.
- Every interaction calls a `render*` function, which rebuilds the whole page (see 2.7 and 3.7). `renderBrowser` calls `hideAll()` first (L191), so the browser is fully cleared and rebuilt on every vehicle click.
- `renderUpgrade` (L479) and `renderPaintShop` (L671) call `buildPreview()` on every call, so selecting an upgrade card or switching a paint channel tab rebuilds the 3D preview vehicle.

### 1.9 Hard-coded style

- 22 `Color3.fromRGB` literals. Tier palette table L53; default tier colour L54; modal reds `166,61,70` (L159, L166); affordable green `89,255,102` and unaffordable red `225,56,70` (L435, L557, L587); grey `132,142,145` (L352, L358, L412, L435); upgrade level colours L412.
- Text sizes 18, 15, 14 in modals (L158, L165, L171).
- Fixed modal sizes 620x420, 560x238, buttons 142x40, 38x32.

---

## 2. GarageWorkspaceUI (view)

### 2.1 Purpose and lifecycle

- One reusable page view: header, left rail, right column (stat panel + two economy chips), bottom carousel or paint panel, Back / Next / Exit buttons, upgrade budget strip, floating action popup.
- `WorkspaceUI.new()` (L141-185) builds the persistent shell and connects signals. No `Destroy`. Two instances exist at runtime: GarageUI's and OwnedGarageWorkspaceUI's.
- `Show(context)` L353-357, `RefreshCards(context)` L350-352, `Hide()` L358-361, `Message(text)` L188, `Layout()` L189-198.
- Kept connections: ViewportSize (L183), `UserInputService.InputChanged` for the category wheel (L151-157), six scroller/layout property signals (L181-182), `Root.DescendantAdded/Removing` (L182), replicated Cash binding (L163), arrow and action button handlers (L177-180).

### 2.2 Instance tree

Parent: `PlayerGui.CanonicalGarageGui` > `CanonicalCanvas` (see 4.2).

```
CanonicalGarageWorkspace (Frame, transparent; attributes TutorialWorkspace=true, TutorialPageId)
  Header (MetricCard)            Title, Subtitle labels
  Categories (Panel)             ScrollingFrame CategoryList [UIListLayout, UIPadding]; CategoryPrevious / CategoryNext
  Right (Frame, AutomaticSize Y) Stats (Panel, auto height, UIListLayout); Economy (Frame) > Capacity, Cash (Panels)
  TutorialCardCarousel (Frame)   TutorialCardScroller (ScrollingFrame, X) [UIListLayout, UIPadding]; Paint (Frame)
  Previous, Next (TextButton arrows "<" ">")
  Back, Continue, Exit (ActionButtons)
  UpgradeBudget (Panel, ZIndex 30)
  CardActionPopup (Frame, ZIndex 100) > Action (Button)
```

`LayoutGarageShell` renames `TutorialCardCarousel` to `Carousel` on the first layout (GarageComponents L280).

### 2.3 Scaling and layout

All geometry is delegated to `GarageComponents.LayoutGarageShell` (section 4.3). Workspace-only additions (L189-198): the budget strip is three card widths wide, centred, 48 px above the carousel; the left rail can be stretched to the carousel bottom (`LeftAlignCarouselBottom`) or fitted to its content (`LeftFitContent`). `Layout()` runs twice in every `Show` (L355 and L356) and again on every viewport change.

Text is fixed `TextSize` in logical pixels, scaled only by the canvas UIScale. No `TextScaled` here.

### 2.4 Config read

- `Config.UI.GarageReplacement` through `N(name, fallback)` (L41: attribute first, then child NumberValue): `MobileMinScale`, `DesktopMinScale`, `WorkspaceCardWidth`, `WorkspaceCardHeight`, `CardWidth`, `CardHeight`, `CardImageHeight`, `ModuleCardImageHeight`, `CustomiseCategoryCardHeight`, `CustomiseCategoryImageHeight`, `CategoryButtonHeight`, `BuildLeftPanelPadding`, `Margin`, `CarouselHeight`, `CarouselEndTolerance`, `CategoryArrowGutter/Width/Height/Step`, `CategoryWheelStep`, `UpgradeBudgetHeight`, `UpgradeBudgetPipWidth`, `UpgradeBudgetPipGap`, `UpgradeBudgetPopupClearance`, `MaterialRailTabClearance`, `WorkspacePaintWideWidth`, `LockedModuleIconSize`, `LockedModuleIconYScale`, `EconomyCashTextSize`, `EconomySpacesTextSize`, `StatReference`, `PerformanceRatingTextSize`, `PerformanceHeadingTextSize`, `PerformanceStatNameTextSize`, `PerformanceStatValueTextSize`, `RuntimeAuditEnabled`.
- `Config.UI.GarageReplacement.ModuleArtwork/<Name>` folders (L10-37), 13 of them. Attributes: `DisplayName`, `TargetId`, `SortOrder`, `ShowInBuild`, `ShowInCustomise`, `Image`, `Image_<categoryId>` (per-category override), `Hidden_<categoryId>`. A hard-coded fallback table (L11-25) is used when a folder is missing. Live values differ from the fallback for FrontBody and RearBody sort order (32 and 34 against 72 and 74).
- `Config.UI.DesktopFreeRoamHud.Assets.GarageIcon` (L43, L222).
- `Config.UI.Racing.InRace` is fetched (L40) but `RN` is never called.

### 2.5 Context contract (the view API)

`Show(context)` reads: `Title`, `Subtitle`, `TutorialPageId`, `Legacy`, `Cash`, `CapacityText`, `CapacityIcon`, `ShowCashPlus`, `ShowCapacityPlus`, `OnCash`, `OnCapacity`, `ShowStats`, `RenderStats(parent)` or `Performance / BaselinePerformance / TierColor`, `ShowLeft`, `LeftItems[] {Id, Text, Image, ImageKey, ImageZoom, Selected, Muted, OnSelect}`, `LeftCardMode`, `LeftFloating`, `LeftSharedCardSize`, `LeftFitContent`, `LeftAlignCarouselBottom`, `LeftCardHeight`, `LeftCardImageHeight`, `Cards[]`, `SelectedAction {RowId, Text, OnActivate}`, `EmptyMessage`, `UpgradeBudget {Label, Used, Capacity}`, `MaterialChannels`, `ColorChannels`, `SelectedChannel`, `Colors`, `OnChannel`, `OnColor(channel, color, commit)`, `BackVisible/BackText/BackIcon/BackIconText/OnBack`, `NextVisible/NextText/NextIcon/NextIconText/OnNext`, `ExitVisible/ExitText/ExitIcon/ExitIconText/OnExit`, `ExitBelowEconomy`, `CarouselScrollKey`, `CategoryScrollKey`, `RuntimeAudit`.

Card row: `Id`, `CardKind` ("Listing", "Vehicle", or nil for an image card), `DisplayName`, `Image`, `ImageKey`, `ImageZoom`, `Badge`, `BadgeColor`, `BadgeStyle`, `EmptyPlus`, `Muted`, `VehicleName`, `Variant`, `TagText`, `TagColor`, `Price`, `PriceText`, `PriceColor`, `Footer`, `SemanticState`, `LockImage`, `Selected`, `ActionText`, `OnSelect`, `OnAction`.

Other methods used from outside: `DrawPerformance(parent, now, base, tierColor)` L226, `ArtworkDefinitions(page, categoryId)` L203 (does not use `self`), `IsTouchBlocked(position)` L133 and the `TouchMapEnabled` field (owned garage only), `.Root`, `.Subtitle`.

### 2.6 Input

- Mouse and touch through `Activated`.
- Custom mouse-wheel scrolling for the left rail (L151-157).
- Paint sliders: `InputBegan` on the track, then two `UserInputService` connections for the drag (L276).
- No gamepad or keyboard code. Scroll bars are hidden (`ScrollBarThickness=0`); arrows are text glyphs.

### 2.7 Rebuilds and counts

`Show` destroys and recreates everything tagged `GeneratedGarageWorkspace`: the left rail, stat panel, both economy chips, all cards or the whole paint panel, and the budget strip. Each `Racing.Button` is 7 instances (TextButton, UICorner, bevel Frame with UICorner and UIGradient, two UIStrokes) and two hover connections.

Rough generated instance counts per `Show`:

| Page | Left rail | Stats | Economy | Body | Total |
|---|---:|---:|---:|---:|---:|
| Add Modules, 12 listing cards | 36 | 58 | 17 | 216 | about 330 |
| Upgrade, 8 slots, 6 upgrades, 10 pips | 96 | 58 | 17 | 140 | about 310 |
| Paint Shop colour, 11 targets | 132 | 0 | 17 | 160 | about 310 |

The persistent shell is about 85 instances per workspace instance. Selecting any card triggers this full rebuild, because the controller re-renders the page to move the selection.

### 2.8 Mobile and touch

- Touch scaling is in `LayoutGarageShell` (4.3).
- Touch surface map (L49-139): a list of rectangles of everything drawn, used by the owned garage to stop camera touches under UI. Only active when `TouchMapEnabled` is set, which GarageUI never does.

### 2.9 Hard-coded style

- 16 `Color3.fromRGB`, 11 `Color3.new`, 12 `Color3.fromHSV`. Selected tab or rail button fill `94,32,75` (L214, L239); action button red `166,61,70` (L172, L174); cash green `89,255,102` (L221); palette greys L283.
- Text sizes: 30 and 22 (arrows L169, L171), 13 (budget L230, empty message L249), 11 (slider labels L271), 9 ("CURRENT" L280).
- Fixed sizes: "+" buttons 32x30 (L221, L223), economy icon 28x28, tabs 34 high, paint panel 156 high, slider track 10 high, knob 5x18, swatches 24 high, 15 palette columns (L279), budget pips 16 high.

---

## 3. GarageBrowserUI (view)

### 3.1 Purpose and lifecycle

- The vehicle browser for Dealership (buy) and Customisation (pick an owned vehicle). `Browser.new()` L25-44, `Show(context)` L113-124, `Hide()` L125-128, `Layout()` L45-48. No `Destroy`.
- Kept connections: ViewportSize (L42), five scroller signals (L41), replicated Cash binding (L34), arrows and Exit.

### 3.2 Instance tree

```
CanonicalGarageBrowser (Frame, transparent)
  Header (MetricCard)   Title, Subtitle
  Categories (Panel)    ScrollingFrame [UIListLayout, UIPadding] > one Racing.Button per category
  Right (Frame)         Stats (Panel); Economy > Capacity, Cash
  Carousel (Frame)      VehicleScroller (ScrollingFrame, X) > VehicleCard x N
  Previous, Next (arrows), Exit (ActionButton), CardActionPopup
```

### 3.3 Scaling and layout

Same shell function as the workspace. Cash and Spaces text use `TextScaled` with a `UITextSizeConstraint` (17/16 maximum on desktop, 11/10 on touch, minimum 10 or 8; L79-82). Everything else is fixed `TextSize`.

### 3.4 Config read

- `N(name, fallback)` here reads only child NumberValues (L14), unlike the workspace's reader. Keys: `EconomyHeight`, `MobileMinScale`, `DesktopMinScale`, `CarouselEndTolerance` (an attribute, so the fallback 4 is always used), `CardWidth`, `CardHeight`, `StatReference`, `CategoryButtonHeight`.
- `NavigationIcons.ExitIcon` (L39), `DesktopFreeRoamHud.Assets.GarageIcon` (L82).

### 3.5 Context contract

`Mode`, `State` (reads `Profile`, `BrowseAll`, `CategoryId`, `SelectedVehicleId`, `SelectedCockpit`, `Catalog`), `Category`, `Categories`, `Cash`, `CapacityText`, `AutoPreview`, `Legacy`, `CarouselScrollKey`, `ResolveImage(cockpit)`, `ResolvePerformance(cockpit)`, `TierColor(tier)`, `OwnedCount(cockpitId)`, `OnCategory(id, all)`, `OnSelect(row)`, `OnPrimary(row)`, `OnExit()`, `OnCash()`, `OnCapacity()`. GarageUI also writes `browser.Subtitle.Text` directly for error messages (L153, L194).

The browser reads the profile itself to build rows (`Rows`, L64-72), so it is not a pure view.

### 3.6 Input

Mouse and touch only. Vehicle cards are selectable TextButtons with a focus style (GarageComponents L120-121), nothing more.

### 3.7 Rebuilds and counts

- Every `Show` rebuilds all category buttons, all vehicle cards (about 18 instances each), the stat panel (58) and the economy chips (about 19). With 12 vehicles and four categories that is about 330 instances.
- Opening the browser renders twice: with `AutoPreview` set, `Show` defers `OnSelect(rows[1])` and returns early (L118); that call renders again.
- `Audit` (L85-102) is not gated by `RuntimeAuditEnabled`: every `Show` schedules one more `Layout` and `UpdateCarousel`, and prints a geometry line once per viewport and mode.

### 3.8 Mobile and touch

- Smaller Cash and Spaces text (L78-80).
- The popup omits the price on touch: "BUY" instead of "BUY $40,000" (L122).

### 3.9 Hard-coded style

Selected category fill `94,32,75` (L115), Exit red `166,61,70` (L39), cash green (L81), arrow text size 30 (L37), "+" buttons 32x30, icon 28x28.

---

## 4. GarageComponents (shared components and shell)

### 4.1 Purpose

Stateless builders plus three module-level singletons: the canonical host (L294-311), the presentation owner (L172-203) and a weak audit-key table (L225).

### 4.2 Host ScreenGui (`CanonicalHost`, L295-311)

- `PlayerGui.CanonicalGarageGui`: `ResetOnSpawn=false`, `IgnoreGuiInset=true`, `ZIndexBehavior=Sibling`, `DisplayOrder=40`, `Enabled=true` always. Pages are shown and hidden with `Root.Visible`.
- `CanonicalCanvas` (Frame, transparent) with one `UIScale` named `CanonicalScale`. Every garage root is a child of the canvas: `CanonicalGarageBrowser`, `CanonicalGarageWorkspace`, `OwnedGarageCanonicalWorkspace`, and `CanonicalGarageModal` when open.

### 4.3 Shell layout (`LayoutGarageShell`, L274-293)

- Reference canvas 1600x900 (`BaseWidth`, `BaseHeight`).
- `scale = clamp(min(availableWidth / 1600, availableHeight / 900), minimum, MaxScale)`, `MaxScale = 1.02`.
- `minimum`: `DesktopMinScale` 0.68 without touch; with touch `TouchScaleMin` 0.25 (the `MobileMinScale` 0.42 passed by the views is ignored on that path).
- The canvas and the page root are sized to the viewport divided by the scale, so the logical canvas is always 900 tall or taller and as wide as the aspect ratio makes it. Everything inside is positioned with logical pixel offsets against that width and height:
  - header: centred at the top, y 28, 420 wide, `HeaderHeight` 82;
  - left rail: x 18, y 72, width 214 or 238, height down to 82 above the carousel (minimum 170);
  - right column: anchored to the right edge at y 28, width 354; stat panel above the two economy chips (each 46 high, 10 gap);
  - carousel: full width less 62 each side, 166 high, 18 above the bottom edge;
  - arrows at the left and right margins, vertically centred on the carousel;
  - action buttons: 170x46, anchored bottom-right, 48 above the carousel, laid out right to left.
- Safe area: fixed `TouchSafeTop/Bottom/Side` of 4 pixels on touch only. The source of truth for size is `Camera.ViewportSize`, not the ScreenGui's own size.
- Touch detection is `UserInputService.TouchEnabled`. On touch the left rail's top is set in physical pixels (`TouchCategoryTop` 82, or 68 below 500 px height).
- Only the carousel arrows get a minimum physical size (`TouchArrowPixels` 32, L251-256).
- On viewport change each view calls `Layout()` again; nothing is rebuilt.

Resulting scale at common sizes:

| Viewport | Scale | Logical canvas | 10 px label becomes | 46 px button becomes |
|---|---:|---|---:|---:|
| 1280x720 | 0.80 | 1600x900 | 8.0 px | 37 px |
| 1920x1080 | 1.02 | 1882x1059 | 10.2 px | 47 px |
| 2560x1440 | 1.02 | 2510x1412 | 10.2 px | 47 px |
| 3440x1440 | 1.02 | 3373x1412 | 10.2 px | 47 px |
| 3840x2160 | 1.02 | 3765x2118 | 10.2 px | 47 px |
| 844x390 phone | 0.42 | 1970x900 | 4.2 px | 20 px |
| 932x430 phone | 0.47 | 1970x900 | 4.7 px | 22 px |

### 4.4 Component APIs

`VehicleCard(parent, props)` L108-139. Props: `Name`, `Size` (default 226x146), `DisplayName`, `Image`, `ImageZoom` (1.08), `ImageScaleType`, `Rating` (text such as "A 412"), `RatingColor`, `RatingScale` (0.65 to 1.5), `Selected`, `Owned`, `SemanticState` (Owned, Purchase, Empty, Unavailable), `EmptyPlus`, `EmptyGlyph`, `EmptyText`, `EmptyTextSize`, `FallbackTextSize`, `Muted`, `Active`, `Selectable`, `OfferPurchase`, `Price`, `Cash`, `FooterHeight`, `NameTextSize`, `UnavailableText`, `UnavailableTextSize`. Returns a TextButton with attributes `CanonicalGarageCard`, `CanonicalVehicleCard`, `VehicleCardSemanticState`, `VehicleOwned`, `VehicleSelected`, `VehicleFocused`, `PurchasePrice`, `Affordable`. Children: `ImageSlot/Artwork`, `ArtworkFallback` (text "HOVERCAR" when there is no image), `NamePlate/ItemName`, `NamePlate/PurchasePrice`, `RatingBadge`, `EmptyPlus`, `Unavailable`. `RefreshVehicleCardsAffordability(root, cash)` L101-107 recolours prices without rebuilding.

`Card(parent, props)` L72-91: image card. Props `Name`, `Size`, `Selected`, `Muted`, `Image`, `ImageHeight`, `ImageZoom`, `ImageScaleType`, `NameOverlay`, `DisplayName`, `NameTextSize`, `NameRole`, `EmptyPlus`, `Rating`, `RatingStyle` ("TextOnlyPrice"), `RatingColor`. `ModuleCard` and `ModuleCategoryCard` (L141-142) are the same card with the name under the image.

`ModuleListingCard(parent, props)` L143-162: text card, default 210x146. Props `VehicleName` or `Eyebrow`, `TagText` or `Variant`, `TagColor`, `Badge`, `BadgeColor`, `Price` or `PriceText`, `PriceColor`, `Footer`, `SemanticState` (Shop, Locked, Equipped, Invested, InUse, Available, Upgrade, Unavailable), `LockImage`, `LockIconSize`, `LockIconYScale`, `Selected`. Attribute `ModuleSemanticState`.

Stat panel: `RenderPerformance(parent, options)` L204-224. Options `Performance {Overall {Tier, PerformanceIndex}, Headline {Speed, Acceleration, Handling, Drift, Braking, Boost}}`, `Baseline`, `TierColor(tier)`, `Reference` (bar full scale, 180), `GeneratedAttribute`, `EmptyText`, four text sizes. Draws a tier-coloured header ("A  412" and "PERFORMANCE") and six rows: name, value, signed difference against the baseline, and a continuous gradient bar. 58 instances.

Others: `ActionButton / SetActionButton` L47-59 (icon or glyph plus text, 170x46), `Panel` L65-68, `MetricCard` L69-71, `Popup(root)` L163-171 (`Set(target, text, fn, scale)`, `Hide`, `Destroy`), `EconomyMetric` L46, `FormatMoney` (compact), `FormatFullMoney`, `FormatDealershipPrice`, `ProjectEconomy`, `UpdateHorizontalCardCanvas` L17-38 (centres a short row, sets the canvas width), `HeaderTextSizes` L228, `AcquirePresentation / ReleasePresentation / AuditPresentation` L181-203, `ConfirmationModal` L312 (wraps the foundation's confirmation), `AttachDropdownChevron`, `SetDropdownOpen`, `AnchoredDropdown` L315-355.

Economy chips are not a component. Each view builds its own Cash and Capacity chip from `Panel` + `EconomyMetric` + a "+" button (Browser L76-83, Workspace L219-224).

### 4.5 Config read

- `Config.UI.GarageReplacement`: `BaseWidth`, `BaseHeight`, `MaxScale`, `Margin`, `Gap`, `CarouselHeight`, `ArrowWidth`, `ArrowHeight`, `CategoryWidth`, `ModuleCategoryRailWidth`, `CategoryCarouselClearance`, `StatsWidth`, `EconomyHeight`, `EconomyCardHeight`, `EconomyStackGap`, `HeaderHeight`, `HeaderTitleTextSize`, `HeaderSubtitleTextSize`, `NavigationButtonHeight`, `NavigationPopupClearance`, `ResponsiveTouchEnabled`, `TouchSafeTop/Bottom/Side`, `TouchScaleMin`, `TouchCategoryTop`, `TouchCategoryTopTiny`, `TouchArrowPixels`, `RuntimeAuditEnabled`.
- `Config.UI.Racing.InRace`: `MetricCardTransparency`, `MetricCardCornerRadius` (L70).
- Through `RacingUIComponents`: `Config.UI.Racing.Colours` (Text, Panel, PanelSoft, PanelDeep, PanelBlue, ElectricBlue, Outline, OutlineSoft, Telemetry, Muted, Danger; "Success" is requested but does not exist, so its literal fallback is always used), `Racing.Typography.FontFamily` (Michroma), `Racing.Layout.CornerRadius`, and `Config.UI.Theme` for corner scale, stroke widths and bevel.

### 4.6 Per-frame work

- `Popup`: a `RenderStepped` connection while a popup is shown, re-positioning it over the selected card (L168-170).
- `AcquirePresentation`: a `RenderStepped` loop only when legacy surfaces are passed. GarageUI passes an empty table, so it never runs.

### 4.7 Hard-coded style

40 `Color3.fromRGB` literals and 31 literal text sizes. Examples: selected card fill `18,45,54` (L74, L116); invested fill `92,31,73` and `118,38,91` (L146, L148); name plate `5,8,12` (L81, L127); grey `132,142,145` (L73, L115, L145); price green `89,255,102` (L96, L135, L156, L216); loss red `255,105,116` (L216); variant blue `100,205,232` (L152). Text sizes 9 to 15 on cards (L81-87, L129-135, L151-160), 11 to 20 in the stat panel (L209-220).

Across the four UI scripts: 84 `Color3.fromRGB`, 20 `Color3.new`, 61 literal `TextSize`, 90 `Racing.Colour` lookups. No script names a font; the font comes from `Racing.Font`, and `ResponsiveUIFoundation.StyleMetric` hard-codes Michroma for every metric label.

---

## 5. GarageModuleCardViewModel

Pure data, no instances, no config, no remotes. `Variant(module)`, `Rating(module, instance, resolver)`, `CardText(row)`, `Owned(context)` (rows sorted Equipped, Available, In use, then rating), `Shop(context)` (unlocked first, then source rating, price). Row fields: `Id`, `Module`, `Item`, `State`, `Status` (already display text such as "IN USE BY ...", "OWNED x2", "BUY ... TO UNLOCK"), `Variant`, `VehicleName`, `Title`, `Tag`, `Rating`, `OwnerVehicleId`, `Locked`, `Price`, `SourceRating`. Reusable unchanged by a new view.

---

## 6. Preview coupling

- `PreviewCameraClient`: GarageUI is its only caller. `BindInput` (L36-51) orbits on right-drag or touch-drag and zooms on wheel or pinch. `pointerBlocked` (L31-33) asks `PlayerGui:GetGuiObjectsAtPosition` and blocks the drag if any ancestor is a GuiButton, a ScrollingFrame or has `Active=true`. A new full-screen dim or gradient frame must be `Active=false`, and panels must be `Active=true`, or orbiting breaks. `Update` sets `CameraType=Scriptable` every frame and is skipped when the Gui passed in is disabled. Camera sections per slot are a table in this module (L10) plus `PreviewCamera*` attributes.
- `GaragePreviewPresentationClient`: always-on `RenderStepped`; every 0.1 s it decides whether the garage is open from the player attribute `GarageSessionActive` or, by instance name, from `CanonicalGarageGui > CanonicalCanvas > CanonicalGarageBrowser / CanonicalGarageWorkspace` being visible (L77-91). It owns the dealership lighting context and the preview wobble. No other UI coupling.
- GarageUI sets the preview root attribute `PreviewVFXMode` (L106, L110), read by `ThrustPreviewClient`.
- State fields the preview modules read: `Profile`, `PreviewProfile`, `PreviewModules`, `PreviewNeonSlot`, `SelectedSlot`, `SelectedModuleId`, `TargetFocus`.

## 7. Who else depends on these instance names

| Dependent | What it looks up |
|---|---|
| `OnboardingClient` L143 | `CanonicalGarageGui > CanonicalCanvas > CanonicalGarageBrowser` |
| `OnboardingClient` L154-183 | buttons with attribute `CanonicalGarageCard`, and `CanonicalGarageCardId` equal to `AddModules`, `UpgradeModules`, `PaintShop` (the hub cards) |
| `OnboardingClient` L184-200 | attribute `TutorialWorkspace` with `TutorialPageId` (`CustomisationHome`, `AddModules`, `UpgradeModules`, `PaintShop`); children named `Categories`, `Stats`, `Capacity`, `UpgradeBudget`, `VehicleScroller`, `TutorialCardScroller` |
| `OnboardingClient` L110 | stops walking up at a parent named `CanonicalCanvas` |
| `GaragePreviewPresentationClient` L77-87 | the four canonical names above |
| `GarageUI` L138-146 | `PlayerGui.GarageUI` (legacy) and `CanonicalGarageGui` |

Removing the hub removes the three cards the tutorial points at on the `CustomisationHome` page.

## 8. Unused config

No script reads these `GarageReplacement` keys: `TouchTargetPixels`, `TouchActionPixels`, `TouchPopupPixels`, `TouchCompactTargetPixels`, `TouchTextScale`, `TouchTextThreshold`, `TouchTextMaxSize`, `TouchDenseTextMinSize`, `TouchTopLeftClearance`, `TouchVisualControlScaling`, `PaintPaletteColumns`, `PaintCommitOnRelease`, `UpgradeBudgetWidth`, `UpgradeBudgetTextSize`, `WorkspacePaintWidth`, `WorkspaceStatsHeight`, `ModuleCosmeticsIcon`, `ModulePerformanceIcon`, `DesktopFullProfilePollingEnabled`, the five `PreviewCameraFade*` keys, `PreviewCameraSessionScoped`, and the six `PreviewHover/PreviewThrust*` keys. `restoreResponsive` (GarageComponents L234-243) restores attributes that nothing sets.

## 9. Defects

Scaling:

1. `MaxScale` 1.02 on a 1600x900 reference (GarageComponents L277). The UI stops growing at about 1632x918. At 1440p, ultrawide and 4K, labels stay 9 to 13 physical pixels and cards about 214 wide.
2. Phone landscape shrinks the desktop layout to about 42%. Labels land at 4 to 6 pixels, action buttons at 20, "+" buttons at 14x13, paint swatches at 22x10, the slider knob at 2x8. Only the carousel arrows have a minimum size (L251-256). The touch-target and touch-text config keys exist but are unread.
3. Layout is computed from `Camera.ViewportSize` with a fixed 4 px inset (L275-278) while the ScreenGui sets `IgnoreGuiInset=true` and no `ScreenInsets`. The shared confirmation explicitly sets `ScreenInsets=None`, the garage host does not, so on a notched phone the canvas may be wider than the area the ScreenGui actually covers. Needs a device check.
4. The ViewportSize listener is attached to the camera object that existed at construction (Browser L42, Workspace L183) and is not re-attached if `CurrentCamera` is replaced.
5. Two workspace instances and the browser share one canvas and one UIScale, and each `Layout` call writes both (L277-278). A view with a different reference size cannot share this host.

Alignment and consistency:

6. Three different "selected" looks: cards use a cyan outline and teal fill (L74, L116), rail buttons and tabs a magenta fill `94,32,75`, invested listing cards a different magenta. Four different reds and one green are literals; "Success" is not a colour in config.
7. Money is formatted three ways on the same screens: full in the browser Cash chip (Browser L81), compact in the workspace Cash chip (Workspace L221), two-decimal millions on the vehicle card (L135), compact in the popup (Browser L122).
8. The three config readers differ: Browser `N` reads child values only (L14), Workspace `N` reads attribute then child (L41), Components adds a third (L227). An attribute edit can change one view and not the other.
9. Errors and status messages overwrite the page subtitle (GarageUI L153, Workspace L188) in a fixed 420 px header with no error styling.
10. The move confirmation, cash and properties modals are hand-built (GarageUI L154-175) instead of using the shared confirmation, so they have no focus handling or cancel binding and a different size and style. After buying a garage property the Spaces chip is not refreshed.
11. The stat panel columns are 55% + 25% + 18% from 82%, the listing card uses fixed offsets for a 210x146 card with a fixed 112 px tag, and names truncate at the end on both cards.

Performance:

12. Every click rebuilds the page: about 300 to 330 instances destroyed and created, with their connections, including the 58-instance stat panel that often has not changed. `Layout` runs twice per `Show` and the browser schedules a third.
13. `buildPreview()` runs on every `renderUpgrade` and `renderPaintShop` call (GarageUI L479, L671), so the 3D preview is rebuilt when only a card selection or paint channel changed.
14. The browser opens with two full renders (Browser L118).
15. Unconditional output: route, ownership, dependency and modal-geometry prints in GarageUI (L144, L160, L194, L695, L698), the browser geometry audit, and the touch responsive audit, which walks all descendants once per page title on touch devices (GarageComponents L257-273).
16. Paint slider drags connect two global input listeners that are released only on input end (Workspace L276). A rebuild or close during a drag leaves them connected to destroyed instances. Slider movement calls `ApplyPaint` on the preview on every input event.
17. Every button carries two UIStrokes and a bevel overlay (7 instances). The new style needs none of them.

Input:

18. No controller support beyond default selection: no initial focus, no back binding, no bumper or trigger handling, and the BUY / EQUIP popup is a separate floating button that focus has to find.

## 10. Seam for a switchable new presentation

What is logic and what is view:

- Logic (GarageUI): `State`, the catalogue selectors (L55-74), performance lookups (L75-87), preview and camera orchestration (L99-136), `Adapter` and all remote calls, the session open and close paths (L179-189, L195, L674-694), and the navigation closures inside the `render*` functions.
- View construction inside GarageUI: the four modals (L154-175) and the tier colour table (L53).
- Views: GarageBrowserUI and GarageWorkspaceUI, reached only through `new`, `Show`, `Hide`, `Message`, `.Root.Visible`, `.Subtitle.Text`, `DrawPerformance` and `ArtworkDefinitions`.
- Pure and reusable as they are: GarageModuleCardViewModel, GarageCatalogClient, PreviewVehicleClient, PreviewCameraClient, GarageModuleInstancePreviewAdapter, GarageVehiclePreviewProfile, VehiclePerformanceResolver, PresentationAudioBridge, the artwork config.

Two options:

A. View swap only. New browser and workspace view modules that accept the same context tables, selected at GarageUI L13 / L45. This restyles every page and can move the popup action into the button row, since `ActionText` and `OnAction` are already in the row data. It cannot deliver the navigation changes: the workshop tab callbacks are only supplied on Add Modules pages (L324), the Owned / Buy choice is a controller page (L340-344), and the context carries neither the fitted part name per slot nor the names for the stat panel. It also needs an edit inside GarageUI.

B. New controller beside the old one (recommended). A new garage application module that copies GarageUI's logic, builds the new navigation, and draws with new shared components in its own ScreenGui. GarageUI, GarageBrowserUI, GarageWorkspaceUI and GarageComponents stay byte-for-byte as the backup. The switch is one choice at the composition root: ClientBase starts exactly one of the two. Both can call the same remotes and bindables; the server sees no difference.

Must stay single-owner (only one controller may be started per session):

- the three `Open*` BindableEvent listeners, otherwise both controllers open a session;
- the `GarageInvoke` busy guard and the `GarageSessionRequest` End call;
- `GarageEntryMode`, `GarageClosedFromDealershipExit`, `FreeRoamVehicleSpawned / Exited`, and the loading-transition generations;
- the preview root and `PreviewCameraClient` input (its connection list is module-level; a second `BindInput` unbinds the first);
- camera type and its restore on close.

A new view must also:

- use its own ScreenGui and scale, because the old canvas and UIScale are still driven by the owned-garage workspace;
- reproduce the tutorial hooks in section 7 or update OnboardingClient in the same delivery;
- keep `GaragePreviewPresentationClient` working (it will, through `GarageSessionActive`; the name check is only a fallback);
- respect the `pointerBlocked` rule for camera orbit;
- keep VehicleCard's attribute contract if the HUD car panel and race entry are to share the new tile.

The style switch itself: `Core.FeatureFlags` lives in `ServerStorage.Modules.Core` and no client script reads it. The client needs a replicated value, read once at start and held for the session.

## 11. Open points for the design

- The style sheet does not lay out: the Upgrade page (slot picker, upgrade tiles and budget pips together), the Paint overview step (Paint / Neon Lights / cosmetic purchase cards), the post-purchase Paint Vehicle page, the "no owned modules" and "equip to unlock" states, the three modals, or where error messages go once the subtitle is gone.
- "Back" on Customise has no destination today: the hub has no Back or Exit.
- The Cash and Spaces "+" buttons open the cash and garage-property modals; the status cluster needs a place for them.
- Exotic cockpits have no card image (known issue EXO-03), so tiles need a designed no-image state.
- The style sheet's cash count-up uses the foundation's cash presenter; the garage chips set text directly today.
