# RaceMenu family (F1): notes for the integrator

Status: **generated only.** Nothing was run: there is no offline Luau, the kit v2 sources were not visible, and no Studio or git command was used. Every file was desk-checked by hand. The model test needs no kit module; the view test needs kit v2.

## Files

```text
CONTRACT.md  NOTES.md  contract.json  routes.json  spec_ops.json
after/ReplicatedStorage.Modules.Game.UIPulse.RaceMenu.RaceMenuModel.lua     headless; requires nothing (deps injected)
after/ReplicatedStorage.Modules.Game.UIPulse.RaceMenu.RaceMenuView.lua      Regular and Compact branches of one layout
after/ReplicatedStorage.Modules.Game.UIPulse.RaceMenu.RaceMenuClient.lua    entry; start()
after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.RaceMenu.lua      one gallery item, 13 states
tests/<same four names>_test.lua
```

`spec_ops.json` is a bare list of five create ops (the `RaceMenu` folder, then four ModuleScripts). `Dev.Fixtures` already exists (Phase 1), so no op creates it.

## Classic behaviour not reproduced exactly

1. **Mode read after the wait.** Classic reads `EventId` before the 0.25 s wait (418) and `Mode` after it (425), so a row click during the fade could send one row's event with another row's mode. Pulse takes both from the row selected when TELEPORT was pressed. Same remote, action and keys.
2. **Late failure text.** Classic draws a teleport failure into whatever opening is showing when the reply lands. Pulse drops the text if the menu was closed and opened again meanwhile (render token). The `FadeIn` still fires.
3. **Filter resets on open.** Classic has no filter; Pulse resets it to All on every open so "first row selected on every open" keeps its meaning.
4. **Row text split.** `availabilityText` and `routeDescriptor` are byte-equal to Classic (bullet separator kept). The detail facts carry the Classic values but are drawn as label and value, so `3 LAPS` is `LAPS | 3` and `2-6 PLAYERS` is `PLAYERS | 2 TO 6` (a single number when min equals max). The `Classic` field of each fact holds the old string and is tested.
5. **Start waits.** Classic waits without limit for modules, remote, config and bindable. Pulse waits at most 5 s per hop (zero when present), then starts anyway: a missing remote makes TELEPORT fail with `TELEPORT FAILED`, a missing `RouteGuide` gives the no-route line, a missing config gives the empty state, and a late `OpenRaceBrowser` is connected by a background task. If `Runtime.Racing` is missing Classic would hang on the fade; Pulse skips the fade.
6. **`SetDestinationById` error** reads as no route (Classic would throw in the click handler).
7. **Clicking the selected row again** renders nothing (Classic rebuilt the list and detail).
8. Not drawn: the `EVENT DETAILS` heading, the `TRACK IMAGE` placeholder text (an image-less hero is plain slate with the name), the per-row thumbnail placeholder.

## API questions and the reading used

- **Q1 `Collections.List` size.** The API gives `RowHeight` and `Width` and says "same contract as `Rail`", which "fills a sized parent". I pass no `Width` and parent the list into a sized frame (`EventListHost`). If `List` instead defaults to `ListWidth`, the Compact list will not be full width: pass `Width` there.
- **Q2 `ListRow` chip.** `ChipKind` is read as the `Collections.Chip` kinds. Regular rows use `Chip = "CIRCUIT • 3 LAPS"` (`Neutral`) and `Sub` = modes; Compact rows use `Sub` = type and modes, `Right` = `3 LAPS · 2 TO 6`, `Chip` = prize (`Yellow`). The laps and players glyphs of c05 cannot be expressed with `ListRow` props.
- **Q3 Status cluster.** The target frames show the vehicle badge, rank ring and cash top right, but 5.2 lists no data source for vehicle or rank and `RaceBrowser` has no live layer (`RaceBrowserLive` would be 171, taken). I mount `Data.StatusCluster {Mode = "CashOnly"}` in `TopRight` on the static layer and the client calls `view.BindCash(player)` in its own thread. This breaks "mount the chip on a live layer"; if that matters, delete the `tree.Status` block and `BindCash`.
- **Q4 Slot children.** API1 8 says a child takes the slot's anchor and zero position; it is unclear whether a component does this itself. `Header` and `ButtonRow` are documented as self-placing and are left alone. For `StatusCluster` and the status-line label the view writes `AnchorPoint` and `Position` itself.
- **Q5 Real-pixel sizes.** Kit size props are design values, and there is no way to say "fill what is left". The view reads `M`, `W - M`, top and bottom from the `TopLeft` and `BottomRight` slot `Position` offsets (deferred one step after `Metrics.Changed` so the layer has moved them), computes whole-pixel boxes, and passes `pixels / ctx.Scale` as `Width` / `Height` to `Surface.Panel`. It assumes slot positions are pure offsets and that `header.Height()` is measured from the slot origin to where a body may start.
- **Q6 No image component.** The kit has no constructor for an arbitrary image. The hero and map pictures are two raw `ImageLabel`s (`TrackPicture`, `MapPicture`) inside `Panel.Content`; the view also makes two transparent host frames (`MenuBody`, `EventListHost`). No colour, font or id literal is involved.
- **Q7 Focus.** `List` and `ButtonRow` own their focus groups and expose no `Enter`. On open the view sets `GuiService.SelectedObject` to the selected row (`list.Row(key).Instance`) when `Input.ShouldEnterFocus(ctx)`, and clears it on close if it is inside the root.
- **Q8 Bumpers and back.** `Tabs` is built with `Bumpers = false`: it is not stated that "while the row is shown" follows a hidden layer root, and a permanent L1/R1 or B binding would take driving input. The client binds `Input.BindBack` and `Input.BindBumpers` on a scope that lives only while the menu is open.
- **Q9 Two headers on Compact.** `Set` cannot remove `Tabs`, so the Compact tree has a list header (title, tabs, count) and a detail header (event name), swapped by `Visible`. Whether `Header` draws `Count` on Compact (c05 shows `5 EVENTS` bottom left) is the kit's choice.
- **Q10 Tab ids.** `All`, `TimeTrials`, `Races`: never `Race`, in case `Tabs` names buttons by id (Classic onboarding locks every GuiButton named `Race`).
- **Q11 `Data.Money`.** Injected as `deps.Money` so the model requires nothing. Its first call may yield (API2 3.5); the client warms it in a task at start, and an open that does yield is covered by the render token.
- **Q12 Tokens used for sizes with no token of their own** (requests, not constants): list width `ListWidth` (mockup is nearer 595), facts width `StatPanelWidth` (Regular) and `CompactSidePanelWidth` (Compact), Compact hero strip `CompactTileHeight`, Compact row `TouchMin`. The hero takes half the body height (`floor((h - gap) / 2)`).
- **Q13 Budget.** Estimated near the limit on Regular with two events using the kit's maximum budgets (header 16, cluster 26, 2 rows 24, facts 32, buttons 20, panels and labels 27); each further row adds up to 12. The view test counts everything under the root except the empty slot anchors.
- **Q14 Gallery mount.** `Mount` receives a parent, not a layer, so the fixture builds its own `Layers.Stage(host, ctx, "Menu")` inside a full-size host frame and returns `{Instance = host, Layer, Model, View, Set, Destroy}`.
- **Q15 Signal.** `model.Changed` is a small in-module Luau signal (`Connect`, `Once`; handlers run through `task.spawn`). It has no public fire method, so the parity scan for `:Fire(` sees only the four bindables.

## Check in Play (Pulse, sandbox window)

1. Start: `RaceBrowserClient` entry `ready`; one `PlayerGui.RaceBrowser` (170) and `RaceBrowserScrim` (169), both `UIStyle = "Pulse"`, root hidden; no console error.
2. HUD race button opens and closes it; the HUD hides and returns (also in the touch emulator); `Enabled` of every ScreenGui is untouched.
3. Teleport from a time-trial row and from a race-only row: fade out, arrive, camera restored, fade in; a forced failure shows the server text inline and fades back in. Compare the bindable and remote order with the Classic record.
4. Set route: toast `ROUTE SET: <NAME>`, route guide active, menu closed; an event with no route shows the inline line.
5. Classic onboarding N1 (`CardContent`) and N6 (`TeleportToStart`): targets found, callout position and size on Regular and Compact. **On Compact `TeleportToStart` is visible only on the detail page**, so N6 may wait until a row is tapped: record what happens.
6. Row click, filter change and Compact page change by `churn_probe`: 0 created, 0 destroyed. Census against 150.
7. Pad: focus enters on open, B backs out and closes, bumpers change the filter and are released after close (boost and drift inputs unaffected). Escape closes.
8. Layout at R720, R1080, R1440, C844, C568 through the gallery item `RaceMenu.Screen` (states `Default`, `FiveEvents`, `LongStrings`, `LongStringsDetail`, `Empty`, `TeleportFailed`); the Compact list width (Q1), the status line against the Compact buttons, the cash chip (Q3), real track and map images in the live menu (fixtures carry none).
9. Classic smoke: with `UIStyle = "Classic"` the old browser is unchanged.
