# FreeRoam family, HUD half (agent F2a): acceptance contract

Status: **generated, not installed.** Under `../../CONTRACT.md` and `../../API2.md` 5.3. Agent F2b's half (touch controls, activity HUD, core UI policy, the `RouteGuide` edit) has its own page; the integrator joins them.

## Owners

| Surface | Before (and with `UIStyle` Classic) | After, `UIStyle` Pulse |
|---|---|---|
| Free-roam HUD state, spawn, despawn, exit, teleport, settings writes | `UI.DesktopFreeRoamHudUI`, `UI.MobileFreeRoamHudUI` | `UIPulse.FreeRoam.HudClient` (claim `FreeRoamHud`) over `HudModel`; the mobile entry routes to `UIPulse.NoOp` |
| HUD geometry and visibility | each Classic HUD's own layout and `gui.Enabled` | `Kit.Layers` slots; root `Visible` only |
| Minimap drawing | `MapIconLayer`, `RouteGuide.newMapRenderer` inside each HUD | `HudMinimap` over `Kit.Minimap` and `UIPulse.Map.*`; `FreeRoamMapPlayerMarkers` shared |
| `RouteGuide.Update` per frame | the HUD (the full map while it is open) | `HudMinimap.Step`, once per frame, never while the layer is hidden |
| Cash on screen | `Foundation` presenter in each HUD | `Kit.Data` cash chip bound to `leaderstats.Cash` |

Nothing is persisted. No server script, remote, action, payload key or config value is added.

## Must preserve

1. Every call site in `contract_a.json`: same remote, action, payload keys and busy guard; never retried; never sent from a view.
2. One HUD on every device; ScreenGui `DesktopFreeRoamHud` with `DesignRoot`, `ModalLayer` > `Controls`, `CarPanel`, a showing `Minimap`, and the marks `Car`, `Garage`, `Race`.
3. Player attributes written as Classic does: `DrivingControlsOpen`, `FirstDrivePresentationPending`, `MinimapMode`, and on touch `MobileFreeRoamCarMenuOpen`, `MobileMajorMenuOpen`, `MobileControlMode`.
4. The first-drive reveal: input gate token `FirstDriveControls` / `V1`, close refused until NEXT, 0.55 s fade.
5. Presentation owners and their `KeepTelemetry` values; the map pause while racing; no `ScreenGui.Enabled` write.
6. The cash modal sends nothing.

## Tests

Pure: `tests/*HudModel_test.lua` (rows, sort, filter, category names, rank, presentation rules, every remote as remote + action + payload keys, busy guard, modal state machine, touch attributes), `HudMinimap_test`, `CarPanelView_test`, `HudModals_test`, `HudView_test` (helpers, then every fixture state at R1080 and C844: no error, budget, 0 churn).

Play gates: `NOTES_a.md`, "What the integrator must check in Play".
