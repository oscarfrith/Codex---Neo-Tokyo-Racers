# RaceMenu family: acceptance contract

Status: **generated, not installed.** Under `../../CONTRACT.md` (wave) and `../../API2.md` section 5.2. Lane: High-Risk (second owner of a surface that sends a teleport remote). Line numbers are the Classic race browser source named in API2 5.2.

## Owners

| Surface | Before, and after with `UIStyle` Classic | After with `UIStyle` Pulse |
|---|---|---|
| Race menu state, teleport, set route, open and close | `Racing.RaceBrowserClient` | `UIPulse.RaceMenu.RaceMenuModel` (headless) started by `RaceMenu.RaceMenuClient` |
| Race menu drawing | the same script (`RacingUIComponents`) | `RaceMenu.RaceMenuView` (kit only; Regular and Compact) |
| ScreenGui `RaceBrowser` 170 (+ `RaceBrowserScrim` 169) | `Instance.new` at 459 | `Layers.Create("RaceBrowser", {Frame = "Menu", Scrim = true})` |
| The one `OpenRaceBrowser` listener | 606 | `RaceMenuClient` |
| Presentation owner key `"RaceBrowser"` | 400 | `RaceMenuModel` |
| Gallery states | none | `Dev.Fixtures.RaceMenu` |

Route: `RaceBrowserClient` entry re-pathed to `UIPulse.RaceMenu.RaceMenuClient` (`routes.json`). Claim: `RaceBrowser`. No Classic script is edited, no server script, no config value, no new remote, bindable, attribute or saved field.

Geometry owner: `Kit.Layers` slots and `Kit.Metrics`. Visibility owner: the layer root `Visible` (never `ScreenGui.Enabled`). State owner: the model. Persistence: none.

## Must preserve

1. **Teleport** (416-441): `teleportBusy` guard; `RaceTransitionRequest {Step = "FadeOut", Reason = "BrowserTeleport", Label = "TELEPORTING"}`; 0.25 s; `Remotes.Racing.RaceBrowserTeleportInvoke:InvokeServer("TeleportToRaceStart", {EventId, Mode})`, time trial when the row has one, else race; success is `Ok == true or Success == true`; on failure `FadeIn {Reason = "BrowserTeleportFailed", Delay = 0.08}` and the inline text `Message or Error or "TELEPORT FAILED"`; on success `FreeRoamVehicleExited`, close, `RestoreCamera {Reason = "BrowserTeleport"}`, `FadeIn {Reason = "BrowserTeleport", Delay = 0.3}`. One call in flight, never retried, never sent from the view.
2. **Set route** (444-454): `RouteGuide.SetDestinationById(Key, "Player")`; false gives `NO ROUTE FOR THIS EVENT YET` and the menu stays open; true closes and fires `ShowTopNotification("ROUTE SET: " .. upper(DisplayName), 2.2)`.
3. **Rows** (70-106): one row per `RouteId` from `TimeTrialCatalog` then `RaceCatalog`; `Primary` is the time trial when present; sorted by lower-case name; rebuilt and the first row selected on every open. `mediaFor`, `availabilityText`, `routeDescriptor` and the facts rule (267-274) unchanged.
4. **Open and close** (402-415, 606-608): `OpenRaceBrowser` toggles; `FreeRoamHudPresentationMode {Owner = "RaceBrowser", Active, KeepTelemetry = false}` on every open and close, on every device.
5. **Names**: ScreenGui `RaceBrowser`; `CardContent` on the event list and `TeleportToStart` on the main button, both through `Input.Mark` (onboarding N1, N6).
6. **Empty state**: `NO EVENTS AVAILABLE`, SET ROUTE and TELEPORT disabled.

## New in Pulse (API2 5.2)

Filter tabs (All events, Time trials, Races) as a client-side filter of the same rows; Escape and ButtonB close (Compact detail goes back first); bumpers step the tabs; Compact is list, then detail; `Presence.Open("RaceBrowser", "FullMenu")`; a cash chip. Every difference from Classic is in `contract.json` `dropped` / `added`.

## Budget and rules

At most 150 instances; 0 created or destroyed on a row click, filter change or Compact page change (keyed list pool, components patched through `Set`). Fetch first, then draw: rows are built before `Changed("Open")`, and one render token discards a result that outlived its opening. `start()` claims first, has only bounded waits and reaches `ready` without the font, an asset or a remote.

## Tests

| Where | What |
|---|---|
| `tests/…RaceMenuModel_test.lua` (pure) | rows, fallbacks, media / availability / descriptor / facts, filter, open and close payloads, selection, pages, the remote action and payload-key table, the four transition payloads, the success and failure sequences in order, busy guard, late reply, set route, missing bindables |
| `tests/…RaceMenuView_test.lua` (pure, needs kit v2) | every fixture state at R1080 and C844: no error, budget, no ScreenGui; second `Render` changes nothing; row click, filter and page change create nothing; marks present; empty state disables TELEPORT |
| `tests/…RaceMenuClient_test.lua`, `…Fixtures.RaceMenu_test.lua` | owner shape, bounded resolver, fixture registration |
| Integrator, Play, Pulse | `NOTES.md` section "Check in Play": teleport and set-route sequences against the Classic record, Classic onboarding N1 and N6, HUD hides and returns, pad and Escape, census (one `RaceBrowser`, marked Pulse), 0 churn by probe |
| Integrator, Play, Classic | smoke: the Classic race browser unchanged |

Done when the pure tests, lint and parity pass, the reviewer has no open finding, and the Play gates of API2 5.2 pass in the sandbox window. Recovery: `UIStyle = "Classic"`, or this family's ROLLBACK (removes four marked modules and the `Routes` rows).
