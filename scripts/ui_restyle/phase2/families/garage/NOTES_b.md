# Garage family, half B (owned garage and forks): notes for the integrator

Agent F6b. Status: **generated, desk-checked, not installed, not run.** No Luau was run (none offline); `fork_check.py`
was run and passes. Everything here sits in `scripts/ui_restyle/phase2/families/garage/`; half A's files were not touched.

## 1. Acceptance contract for this half

| Surface | Before (and Classic after) | Pulse after | Route |
|---|---|---|---|
| Owned-garage client start, `OwnedGarageClientStarted` | `UI.OwnedGarageClient` | `Garage.OwnedGarageClient` (claim `OwnedGarage`) | new owner |
| Browser state, enter, exit, visit, stream acknowledgement | `UI.OwnedGarageBrowserUI` | `Garage.OwnedGarageBrowserModel` + `Garage.OwnedGarageBrowserUI` | new owner |
| Desk state, 36 call sites, `OwnedGarageManagementOpen` | `UI.OwnedGarageWorkspaceUI` | `Garage.OwnedGarageWorkspaceUI` | fork, line 12 |
| Desk drawing | `UI.GarageWorkspaceUI` + `GarageComponents` | `Garage.OwnedGarageDeskView` + `Garage.GarageCompat` | new view |
| Interior HUD, `OwnedGarageInteriorMode` | `UI.GarageInteriorModeUI` 10-47, 271-278 | `Garage.GarageInteriorHud` | new owner |
| Touch camera guard | `UI.GarageInteriorModeUI` 48-270 | `Garage.TouchCameraGuard` | fork |
| Close on transition | `UI.GarageInteriorTransitionUI` | `Garage.GarageInteriorTransitionUI` | fork, line 6 |
| Entrance prompts, `GarageEntryMode` | `Dealership.GarageEntranceClient` | `Garage.GarageEntranceClient` (claim `GarageEntrance`) | fork |

Must preserve: every remote call, bindable call and attribute write of `contract_b.json`; one request in flight per owner
(`busy`), never retried; one stream-ready acknowledgement; one listener of `OpenOwnedGarageBrowser`; one writer of
`OwnedGarageManagementOpen` (the desk fork); `OwnedGarageClientStarted` set only after every part's `Start()` returned ok;
names `OwnedGarageBrowser`, `GarageList`, `Garage_*`, `Visit_*`, `Enter`, `OwnedGarageInteriorHUD`, `AccessControls`,
`OwnedGarageCanonicalWorkspace`; no `GarageEntranceStatus`. No Cash arithmetic was added: the desk's `ProjectEconomy` is
`Data.ProjectEconomy`, tile affordability is the `PriceColor` the fork already computes, Cash on screen is `CashChip.Bind`.

## 2. Files

```text
after/…UIPulse.Garage.OwnedGarageClient.lua            owner (API1 10 shape)
after/…UIPulse.Garage.OwnedGarageBrowserModel.lua      headless model
after/…UIPulse.Garage.OwnedGarageBrowserUI.lua         Start / Close / IsOpen, layer, view (_mount)
after/…UIPulse.Garage.OwnedGarageDeskView.lua          the desk view the fork calls
after/…UIPulse.Garage.GarageCompat.lua                 ProjectEconomy, ConfirmationModal, Asset
after/…UIPulse.Garage.GarageInteriorHud.lua            interior HUD owner; starts the guard
after/…UIPulse.Garage.OwnedGarageWorkspaceUI.lua       fork (hand-assembled)
after/…UIPulse.Garage.TouchCameraGuard.lua             fork (hand-assembled)
after/…UIPulse.Garage.GarageInteriorTransitionUI.lua   fork (hand-assembled)
after/…UIPulse.Garage.GarageEntranceClient.lua         fork (hand-assembled)
after/…UIPulse.Dev.Fixtures.GarageOwned.lua            gallery items OwnedGarage.Browser (10 states), OwnedGarage.Desk (7 states)
forks/<Module>.json + forks/<Module>.span<lines>.lua   4 definitions, 7 span files
tests/…UIPulse.Garage.OwnedGarageBrowserModel_test.lua 20 pure cases
fork_check.py  contract_b.json  routes_b.json  spec_ops_b.json  NOTES_b.md
```

`spec_ops_b.json` has no Folder op: `UIPulse.Garage` is created by half A's fragment and must come first.
`Dev.Fixtures.GarageOwned` is an 18th module (API2 5.7 says 17). It is separate so the halves cannot collide; merge its two
items into `Dev.Fixtures.Garage` if the count must hold.

## 3. Forks and `fork_check.py`

`py -3 scripts/ui_restyle/phase2/families/garage/fork_check.py` (add `--json` for a machine result). Result on 2026-10-09:
**PASS, 4 forks.**

| Fork | Classic source | Replaced lines | Kept | Call sites (fork / Classic) |
|---|---|---|---|---|
| `OwnedGarageWorkspaceUI` | `UI.OwnedGarageWorkspaceUI` | 12 | 187 of 188 | 36 / 36 |
| `GarageInteriorTransitionUI` | `UI.GarageInteriorTransitionUI` | 6 | 12 of 13 | 0 / 0 |
| `GarageEntranceClient` | `Dealership.GarageEntranceClient` | 65-91, 93-106 | 185 of 226 | 9 / 9 |
| `TouchCameraGuard` | `UI.GarageInteriorModeUI` | 1-47, 52, 271-280 | 222 of 280 | 0 / 6, all six declared `_moved` |

The check confirms the Classic source against `classic/manifest.json`, rebuilds each fork, compares it byte for byte with
the hand-assembled file, proves every kept line is present and in order, and compares the extracted calls
(`InvokeServer`, `FireServer`, `:Fire`, `:Invoke`, `SetAttribute`, and the wrappers `request`, `operate`, `call`,
`mutate`, `loadingAction` with a literal action).

- **TouchCameraGuard is written as three spans**, not one: the fork format replaces line ranges, so "keep 48-270 with a
  header" is spans 1-47 (header), 52 (the require) and 271-280 (footer). Lines 48-51 and 53-270 are byte-identical. Its six
  Classic call sites all sit in the removed ranges; five moved to `GarageInteriorHud` (the check greps for them there) and
  one (`toast:SetAttribute("Stamp")`) is dropped with the label.
- **`Enabled` writes that survive in a fork:** one, `entry.Prompt.Enabled = enabled` (GarageEntranceClient fork line 106,
  Classic 140). It is `ProximityPrompt.Enabled`. No fork and no new module writes `ScreenGui.Enabled`; the guard and the
  desk view only read or never touch it (guard fork line 64 reads it).
- **Line 1 of three forks is still the Classic comment.** API2 lists only the spans above, so the two-line Pulse header
  (API1 11 rule 2) is missing from `OwnedGarageWorkspaceUI`, `GarageInteriorTransitionUI` and `GarageEntranceClient`.
  Either exempt forks from rule 2 or add a line-1 span to each definition.
- The guard fork keeps `RunService:BindToRenderStep` and two `RunService.Heartbeat:Wait()` (Classic 170, 87, 233): lint
  rule 7 needs a fork exemption (API2 6.6 item 4 names only rules 5, 6 and 9).
- The entrance fork calls `Claim("GarageEntrance")` inside span 65-91: after the Classic `WaitForChild` lines 15-18, before
  any prompt is created. It cannot be earlier without a span API2 does not list.

## 4. Classic behaviour not reproduced exactly

1. **Interior HUD dropdowns.** `Controls.Dropdown` has no open, close or "stay open" call. So: the invite list closes after
   each press (Classic kept it open and refreshed it); hiding the HUD hides the layer rather than closing a list; the
   refresh-on-press (Classic 36, 40, 275) is wired to `dropdown.Instance.Activated` only if that instance is a GuiButton.
   Invite options read `<name> - INVITE` or `<name> - REVOKE` because an option has no detail field.
2. **HUD and entrance messages are toasts.** HUD: `ShowTopNotification:Fire({Text, Icon, Kind}, 2.4)` instead of the private
   label. Entrance: every message uses the Classic statement `notification:Fire(text)`, so it shows for the toast default
   (2.5 s, not 2 s) and is upper-cased by the toast.
3. **Desk look.** Left category cards become one tab row (`Categories`); the card popup becomes the main button of the
   button row; no artwork fallback from `ModuleArtwork`, no scroll memory, no muted look for "used in another garage"
   (the text still says so). The Cash and Spaces plus buttons are not drawn (Classic drew them with no handler).
4. **Desk touch map.** `IsTouchBlocked` tests the rectangles of the mounted kit components (header, tabs, status strip,
   rail, buttons, paint panel), not each rendered pixel surface, and does not switch scrollers off when they do not
   overflow. A touch on an empty part of the rail holds the camera where Classic let it pan.
5. **A tab row needs a selected tab.** When the fork marks no left item selected (Classic: Build > Structure after
   visiting Style > All Structure), the first tab is shown selected.
6. **Browser.** Title is `GARAGES` with tabs; rows show `<filled> / <capacity> SPACES FILLED` (Classic `<n> BAYS`); the
   "cannot visit" rows are not dimmed; no touch hardening (kit hit boxes). Row keys keep `Garage_<id>` and `Visit_<id>`.
7. **Classic crash paths are closed, not copied.** `visitAction`, `Enter` and the replacement choice read the selection
   after the loading call returns; if it is gone Classic throws and stays `busy` for ever. The model sends nothing, reports
   the attempt as failed and clears `busy`. Reply lists are filtered to table rows.
8. **`modal:Destroy()`.** Classic `Foundation.Confirmation` returns no `Destroy`, so Classic `closeModal` (desk line 34)
   throws when the desk closes while "VEHICLE ALREADY DISPLAYED" is open, before `OwnedGarageManagementOpen` is cleared.
   `GarageCompat.ConfirmationModal` returns one (API2 5.7), so Pulse closes cleanly. This is a behaviour difference.

## 5. API and seam questions (the reading used)

1. **Where the desk root lives (seam with half A).** `OwnedGarageDeskView.new()` makes the root frame detached. On the first
   `Show` it looks up `PlayerGui.CanonicalGarageGui.CanonicalCanvas` by name and parents the root there, then builds its own
   slots with `Layers.Stage(root child, Metrics.Of(root), "Scene")`. It writes nothing of half A's layer. **This needs
   `CanonicalCanvas` to be visible while the desk is open.** If `GarageClient` hides its layer with `layer.SetVisible(false)`
   when no garage session is active, the desk is invisible (one warning is printed) and half A must instead hide its two
   roots, or the seam needs a call. The desk never opens before `GarageClient` has started in practice, but nothing
   enforces the order (`OwnedGarageClient` does not depend on `GarageUI`).
2. **Scrim.** The desk mounts no scrim; half A's `CanonicalGarageGuiScrim` is not used by it. The Cash chip of the desk is
   on the static layer (the Live layer belongs to half A).
3. **`Rail` and `List` selection.** Only `OnSelected(key)` is passed, never a per-item `OnActivated`, so a press cannot
   run a desk action twice. Programmatic `Select` and `Set` during a render are ignored through a `rendering` flag in case
   the kit calls `OnSelected` from them.
4. **Pooled tiles and marks.** `MarkKey` is `Card.<id>` for the six ids the contract has, else `Card`. If the kit reuses a
   pooled tile for another key without clearing `CanonicalGarageCardId`, onboarding could highlight the wrong card.
5. **Page marks.** The desk root holds one host frame per tutorial page, each marked once with `Page.<id>`, and moves its
   stage between them; so the view never types `TutorialPageId` and creates nothing on a page change.
6. **Kit calls I could not confirm:** `Tabs.Set({Tabs = …})`; `Dropdown.Set({Options, Selected = ""})` (no selection);
   `Rail.HeadingRight` (nil is tolerated); `ButtonRow` relayout when a button's `Visible` changes; `Panel` with explicit
   `Height`; `Layers.Stage` following a resize; `header.Tabs.Set({Visible})`.
7. **No kit image component.** The browser picture is one plain `ImageLabel` named `Image` in the hero panel.
8. **Paint colours.** The desk colour page builds its presets and slider gradients with `Color3.fromHSV` (the Classic
   numbers of GarageWorkspaceUI 261-263, 282-283) and passes them to `Slider.Gradient` and `Swatch.Colour` (the paint
   exceptions). Lint rule 6 will flag `Color3` in `OwnedGarageDeskView`; `GarageCompat.Asset` holds the string
   `rbxassetid://` (a prefix, not an id). The panel size is arithmetic over tokens (`ModalMaxWidth`, `SliderHeight`,
   `ButtonHeight`, `Gap`, `Pad`); a real token is a request, as are the browser's column widths.
9. **`start()` robustness.** Kit view builds are inside `xpcall`: a failure warns once (`[Pulse.OwnedGarageBrowserUI]`,
   `[Pulse.GarageInteriorHud]`, `[Pulse.OwnedGarageDeskView]`) and leaves that screen closed or bare, while the stream
   acknowledgement, exit prompts, attributes and the guard keep working. `Layers.Create` and the Classic waits are not
   wrapped. Treat any of those three warnings as a failed gate.
10. **The stream wait** (model `OnPush`) keeps Classic's `task.wait(0.05)` loop up to the server's timeout. It is a
    deadline, not a presence poll, but rule 6.6 item 5 may flag it.
11. **No fixture for the interior HUD** (its two controls are built inside `Start`).

## 6. What to check in Play (sandbox window, `UIStyle` Pulse)

- Console: none of the three warnings of 5.9; `StartupState` `OwnedGarageClient` and `GarageEntranceClient` `ready`;
  `Runtime.UI@OwnedGarageClientStarted` true; claims `OwnedGarage`, `GarageEntrance`.
- Census: `OwnedGarageBrowser` 171, `OwnedGarageBrowserScrim` 168, `OwnedGarageInteriorHUD` 58 with child `AccessControls`;
  no `GarageEntranceStatus`; `OwnedGarageCanonicalWorkspace` under `CanonicalCanvas` after the desk first opens.
- Browser: opens from the HUD button and from an entry prompt on the right property; enter, the garage-full choice,
  return to city; visit and leave with a second player (Oscar); streaming enter completes (one `OwnedGarageStreamReady`).
- Foot exit and drive out: loading screen begins on the prompt and ends on the result.
- Desk: **is it visible (5.1)?** Home, Display Cars (preview, DISPLAY, the "already displayed" confirmation), Build
  (BUY and EQUIP within the sandbox's no-save extent; compare the end state with Classic), Style colour and material,
  SAVE, BACK on every page, EXIT; `OwnedGarageManagementOpen` true only while open; one press sends one request.
- Interior HUD: shown only to the owner on foot with the desk closed; access mode saves; invite and revoke; toasts.
- Touch (emulator): the camera holds while touching desk surfaces and the thumbstick area, pans elsewhere.
- Entrance: three prompts; drive-in refusal and "OWN A VEHICLE TO CUSTOMISE" show as toasts; `GarageEntryMode` set and
  cleared as Classic.
- Classic onboarding on the Pulse screens: X1 `GarageList`, X3 `Enter`, Z1-Z3 cards, AA1 `TutorialCardScroller`,
  AB1 family cards, AC1 and AD1 `Categories`.
