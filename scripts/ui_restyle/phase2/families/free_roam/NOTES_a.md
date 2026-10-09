# FreeRoam family, agent F2a (HUD): notes

Status: **generated, not installed, not run.** There is no offline Luau; every file was desk-checked and passed a bracket and block balance check only. Kit v2 (K2 to K4) and the `UIPulse.Map` modules were still being written, so every kit call is written against `API2.md` and `phase1/API.md`, not against source.

D = `DesktopFreeRoamHudUI`, M = `MobileFreeRoamHudUI` (line numbers of `classic/sources`).

## Files

| File | What |
|---|---|
| `after/…UIPulse.FreeRoam.HudModel.lua` | headless model: state, rules, every remote, bindable and attribute call |
| `after/…UIPulse.FreeRoam.HudView.lua` | Regular, Compact and TouchDrive composition; the frame step |
| `after/…UIPulse.FreeRoam.HudMinimap.lua` | `Kit.Minimap` frame, shared map layers, map maths, the one `RouteGuide.Update` |
| `after/…UIPulse.FreeRoam.CarPanelView.lua` | My Vehicles side panel (list on Regular, grid on Compact) |
| `after/…UIPulse.FreeRoam.HudModals.lua` | `ModalLayer`, Controls, Settings, Get Cash (each built on first open) |
| `after/…UIPulse.FreeRoam.HudClient.lua` | the one HUD owner: `start()`, `IsMinimapShowing()` |
| `after/…UIPulse.Dev.Fixtures.FreeRoam.lua` | 5 gallery items, 17 states, over a fake model |
| `tests/…HudModel_test.lua` (31 cases), `HudMinimap_test`, `CarPanelView_test`, `HudModals_test`, `HudView_test` | pure tests; `HudView_test` also mounts every fixture state at R1080 and C844 |
| `contract_a.json`, `routes_a.json`, `spec_ops_a.json`, `CONTRACT_a.md` | this half's fragments. Agent F2b wrote `*_b.json`; the integrator joins them |

F2b's gallery items are in its own module `Dev.Fixtures.FreeRoamActivity`; mine is `Dev.Fixtures.FreeRoam`. The `FreeRoam` Folder create op may be in both `spec_ops_*.json`: keep one.

## Readings taken where the API was open (each needs the integrator's eye)

1. **Where the `Minimap` name lives.** API2 5.3 says the showing `Minimap` under `DesktopFreeRoamHud.DesignRoot` "is the `Kit.Minimap` root", and also that static and live layers are separate with 0 writes to the static layer while driving. The map canvas moves every frame, so the kit minimap is on `DesktopFreeRoamHudLive`. The static gui carries an empty Frame named `Minimap` in its `Minimap` slot whose `Visible` mirrors the minimap (written on change only). Classic `FullMapUI` 464-478 finds that frame. If the integrator prefers the literal reading, move `HudMinimap.Mount` to `layer.Slot("Minimap")` in `HudView` and delete the marker: two lines.
2. **`View.Mount(layer, model, scope)` has a fourth argument** in `HudView`: `extra` (the live layer, player, drive state, subject, cached config). The HUD needs two layers and API2 6.2 names one.
3. **`HudView` returns `Step`** as well as `Render` and `Destroy`. `HudClient` passes it to the one `Perf.Bind("FreeRoamHud", liveRoot, step)`.
4. **Rebuild on class change** is done by the client (destroy the view scope, mount again) when `Metrics.Changed` reports a layout change and the class or arrangement differs. Model state survives.
5. **Anchors.** I assumed only `ButtonRow` places itself in a slot. For `StatusCluster`, `Gauge` and `Minimap` the view sets `Instance.AnchorPoint = slot.AnchorPoint` and `Position = 0`. If the kit does this itself the two writes are harmless.
6. **`Overlay.Modal`.** Assumed: `Open()` builds synchronously on first call; `Close()` is repeat-safe; `OnClose` may or may not fire for a programmatic `Close()` (both handled); `props.Name` names the root, and the root is `Visible` exactly while open (this is what makes `ModalLayer.Controls` and `CarPanel` satisfy OnboardingClient 459-462 and 475-476); a `Side` modal's `Content` has a real height (the car list is sized `1, -(top + bottom)` of it). **Seam question:** the modal has no "may I close" hook. During the first-drive reveal Classic refuses to close (D442). On Escape or B the kit closes its modal, the model refuses, and `HudModals` opens it again. A `CanClose` prop would be cleaner.
7. **Modal backdrop click** does not close (D543, M189 did). The kit modal root is `Active`. Listed in `dropped`.
8. **First-drive reveal backdrop.** `ModalLayer` itself is the black backdrop: transparency 0 while the reveal shows, tweened to 1 over 0.55 s (D455) while the model's timer runs; the kit modal is closed at the start of the fade, so `Controls` is hidden and `ModalLayer` stays visible, as Classic.
9. **`Collections.List` and `Rail` fill a sized parent** (API2 2.4 says so for `Rail`; assumed for `List`). `ListRow` has no rating prop, so the rating is in `Sub` ("939  EXOTIC").
10. **Settings rows** use `Controls.Tabs` with `Style = "Segment"`, and `tabs.Select(id)` to follow the model. `Locked` marks Tilt without a gyroscope.
11. **`StatusCluster`.** Used `Set({Mode, Tier, Rating, Rank})` rather than `SetVehicle(...)` / `SetRank(...)`, whose arguments API2 3.4 does not give. It is mounted on the **live** layer because its cash chip counts.
12. **`UIP.Map` props.** `IconSize` and `Width` are passed as design values (kit convention). `MapView.CentreX / CentreZ` are filled with world X and Z of the smoothed map centre; `Size` is real px.
13. **`RouteGuide.GetRouteState()` clones the points on every call**, so the minimap reads it on `RouteGuide.Changed` and at most 10 times a second (RouteGuide's own ProgressHz), not every frame. If the function is missing (edit not installed) the route layer is simply not stepped.
14. **Gauge speed and "driving"** come from `MobileDriveInputState` (API2 5.3). Classic desktop showed telemetry for any owned seat and fell back to physical speed (D1284); that fallback is not carried.
15. **`VehicleDisplayNames` is not on the shared-module list (API2 6.6 rule 1, "exhaustive").** D645-648 needs `CategoryName`. Literal reading taken: the three functions it uses are carried in `HudModel` (`_titleWords`, `_categoryIndex`, `_categoryName`), tested. **API question:** add `VehicleDisplayNames` to the list and I delete 45 lines.
16. **Model deps.** The model takes `Confirm` (the client binds `Overlay.Confirm(layer.Root, …)`) and `OpenFullMap` (the client calls `Routes.Resolve("FullMapUI").Open()`), so it requires no kit module at all.
17. **Subject tracking** (which part the map follows) is in `HudClient`, kept current by `CharacterAdded`, `ChildAdded` and `Humanoid.SeatPart` listeners, so the frame step reads one table field. Rule as D1145: the owned vehicle's `PrimaryPart` or `CockpitRoot_DoNotRename`, else `HumanoidRootPart`.

## Token requests (interim token used)

| Wanted | Interim | Where |
|---|---|---|
| `MinimapIconSize`, `CompactMinimapIconSize` | `Pad` 22, `CompactMargin` 12 dp | `HudMinimap` (map icons; also the reference size for other-player markers) |
| `MapRouteWidth` | `TabUnderline` 4 | `HudMinimap` |
| `CompactModalWidth` | `CompactPromptWidth` 300 dp | `HudModals` |
| a row height for modal rows | `StatRowHeight` 48, `ListRowHeight` 96, `Pad` 22 for one text line | `HudModals`, `CarPanelView` |

`LAYER_ZINDEX = 10` in `HudModals` is a z-order, not a pixel value.

## Classic behaviour not reproduced exactly

All are in `contract_a.json` under `dropped` or `added`. The ones a player could notice:

- Backdrop click does not close a modal; the phone car menu has no outside-tap close (X, Escape or B instead).
- The PlayerGui walk for `GarageRoot` / `DealershipRoot` / `CustomisationRoot` is gone; `GarageSessionActive`, `OwnedGarageManagementOpen`, `FullMapOpen` and presentation owners hide the HUD.
- Cash is no longer moved inside an owned garage, and cash and the status strip stay visible while the car panel is open.
- Vehicle rows show `CURRENT` on `profile.CurrentVehicleId` (Classic's selected card). The previews say SPAWNED / PARKED, which the profile does not tell us; not used.
- The title count ("MY VEHICLES 6") and the district label under the minimap are not drawn (no modal count prop; no district data source in Classic).
- Controls rows are Classic's text (W, S, A / D, SHIFT drift, SPACE boost, R reset) plus M / MAP. The preview r10a shows different keys; I kept what the game says today.
- Passenger labels are Classic's FRIENDS / ANYONE / NOBODY (c04a), not r10b's EVERYONE / NO ONE.
- The best-value pack is the fourth, as D568 (r10c marks the third).
- Speed-zoom tuning attributes now apply on desktop too (Classic desktop read value children only, defect D4).
- On a touch device the Controls modal does not write `MobileMajorMenuOpen` (Classic's mobile HUD had no such modal); Settings and Get Cash do.
- Despawn: the panel closes on touch (M310) and stays open elsewhere (D825-836). Rows are not re-read after a despawn, as Classic.
- PC 7.1 "HUD tiles are not selectable while driving" is **not** done: Classic onboarding writes `Selectable` on Car, Race and Garage, and the kit has no prop for it.
- North marker follows `Kit.Minimap.SetHeading`; `MapNorthArrowMode` (Hidden / Orbit / Corner) is not read.

## What the integrator must check in Play

1. `StartupState` `DesktopFreeRoamHudUI` and `MobileFreeRoamHudUI` both `ready`; census: `DesktopFreeRoamHud` 85 and `DesktopFreeRoamHudLive` 86, no `MobileFreeRoamHud_Phase1`, on desktop and in the phone emulator.
2. Spawn, despawn, exit and teleport: payloads and toasts against a Classic session; the busy guard (double click sends one call).
3. The Classic full map opens by minimap click, M and Select (it needs the static `Minimap` marker and `layer.Root.Visible`); the HUD hides while it is open and exactly one owner calls `RouteGuide.Update` (a same-frame overlap at the open and close edges is possible with deferred signals: check it does not double-fire `Arrived`).
4. Classic onboarding: callouts find `Car`, `Garage`, `Race`; the lock write shows the locked look and is not overwritten (`mirrorLock` in `HudView`); `controlsOpen()` and `majorMenuOpen()` see `ModalLayer`, `Controls`, `CarPanel`; the first-drive reveal (black backdrop, NEXT, fade, input gate released, `FirstDrivePresentationPending` false).
5. Touch: `MobileFreeRoamCarMenuOpen`, `MobileMajorMenuOpen`, `MobileControlMode` values at the Classic moments; pedals hide under the car panel and Settings; Tilt locked without a gyroscope.
6. Budgets: instance census at start (260 Regular, 220 Compact), `write_probe` on the static gui while driving (expect 0), live writes per frame, 0 churn on sort and filter.
7. Layout at R720, R1080, R1440, C844, C568: the modal content sizes (see reading 6), the car list height, the action bar under the status strip, the Compact action row top-centre, the gauge and Exit positions in TouchDrive.
8. The gallery: `FreeRoam.Hud`, `FreeRoam.CarPanel`, `FreeRoam.Modal.Controls`, `.Settings`, `.Cash`.
9. Cash chip: counts from `leaderstats.Cash`; the bind runs in its own task and a failure only warns.
10. Rank: the arc and number follow `Rank`, `XpIntoRank`, `XpForNext`; with no `Rank` attribute the arc is empty.
