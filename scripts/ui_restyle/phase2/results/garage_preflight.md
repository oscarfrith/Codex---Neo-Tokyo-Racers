# Garage family pre-flight (desk check, read-only)

Date 2026-10-09. Sources read: `families/garage/after/*`, kit working copies `kit/k1..k4/after`, Classic
`GarageUI`, `GarageWorkspaceUI`, `GarageInteriorModeUI`, `GarageModuleCardViewModel`, server `GarageServer`,
`GarageRequestGuard`. Nothing was run. Line numbers are those of the files as read; two agents are editing them, so
each finding also quotes the anchor text. Kit line numbers moved by 3 during the read (Collections is being edited).

Server reply shapes used below (`GarageServer` L979-1218, `GarageRequestGuard`):
- Normal reply, success or failure: `{Success, Message, Profile}` (colour actions with `ReturnProfile`: the same).
- Guard rejection (rate, busy, bad field), profile not loaded, race queue, inside owned garage:
  `{Ok=false, Success=false, Message}`; no `Profile`, no `Catalog`.
- Thrown handler: `{Success=false, Message="Garage server action failed. Please try again."}`.
- There is no unequip action on the server, in Classic or in Pulse. Nothing to trace for "unequip".

Paths traced and found correct (no entry below): Owned filter and equip (including the IN USE move confirmation);
rejected module, cosmetic, neon and vehicle purchases (header sub-line plus toast, selection kept, nothing retried);
Drive with a core module missing (`DriveBlocked` message, no remote sent); Exit from the dealership; Cash + modal
(mouse); vehicle pick in Customisation mode with several vehicles; Visit tab model calls and replies.

## A. Definite bugs, most serious first

### A1. Properties modal: a focus move buys the property (gamepad, keyboard)
`GarageModals.lua` L93-98 (`list = Collections.List(content, { Name = "Properties", OnSelected = ... BuyProperty`).
`Collections.List` has no `SelectOn`: its row host is `Focused = function() choose(slot.Key) end`, and `choose`
calls `OnSelected`. D-pad down from the X onto an unowned row sends `BuyGarageProperty` with no activation.
Fix: buy on activation only. Replace L93-98 and L141:
```lua
list = Collections.List(content, { Name = "Properties" }, buildScope)
...
local rows = GarageModals._propertyRows(state.Rows, money)
for _, row in ipairs(rows) do
	if not row.Locked then
		local key = row.Key
		row.OnActivated = function() model.BuyProperty(key) end   -- ListRow key; fires on click, tap, pad A only
	end
end
list.SetItems(rows)
```

### A2. Owned-garage browser "GARAGE FULL" modal: focus replaces a vehicle; text and list overlap
`OwnedGarageBrowserUI.lua` L207-232. (a) Same `List.OnSelected` on focus: moving focus to a slot row calls
`model:ChooseReplacement(index)` (`EnterSelectedGarage {ReplacementSlotId}`). After a failed attempt the row stays
the list's selection, so pressing it again does nothing (`setSelected` returns false). (b) The modal body is a plain
frame with no layout: the `Body` label and the list both sit at (0, 0) and overlap; their `LayoutOrder` is unused.
Fix: in `Build`, add a column layout and move the choice to row activation:
```lua
local column = Instance.new("UIListLayout")
column.FillDirection = Enum.FillDirection.Vertical
column.SortOrder = Enum.SortOrder.LayoutOrder
column.Padding = UDim.new(0, ctx.Px(space.Gap))
column.Parent = content
...
replacementList = Collections.List(content, { Width = modalWidth() - 2 * space.Pad, LayoutOrder = 2 }, modalScope)
```
and at L386: `slots[index] = { Key = key, Title = ..., Right = tostring(index), OnActivated = function() if not rendering then model:ChooseReplacement(index) end end }` (drop `replacementSlots`).

### A3. `State.ReturnWorkshop` is never cleared by a tab change or by closing
`GarageModel.lua` L1268 `selectTab`, L770 `closeCamera`. Set by `routeToAddModule` (L1421), cleared only in
`returnFromModuleRoute`. Upgrades or Paint, empty slot, unlock card, then press any tab: the detour record stays.
Afterwards in Parts: Back from the module list runs `SourcesBack` -> `returnFromModuleRoute` and jumps to the old
tab; buying or equipping any module does the same (L1449, L1590); the source default uses the Detour rule (L1481).
It also survives Drive, so the second garage session of a Play session starts with it.
Fix: first statement inside `selectTab` after the `if not tab` guard, and in `closeCamera` beside the other resets:
```lua
State.ReturnWorkshop = nil
```

### A4. Desk: the rail keeps its own selection; some cards go dead
`OwnedGarageDeskView.lua` L252-260 and L469-472. The kit rail fires `OnSelected` only when its selection changes
and has no deselect. Fork cards that navigate to a colour page (rail hidden, no `SetItems`) or do nothing stay
selected in the rail: Style -> Lighting -> Back, Style Structure -> Colour -> Back, Style -> Lighting with no colour
channels, a failed `PreviewDisplay`, Access -> Invitations when disabled. The card then shows selected and a
second press is ignored.
Fix: L469-472 become
```lua
if selectedKey == nil then
	rail.SetItems({}) -- the kit rail keeps its own selection and has no deselect; the pool stays
end
rail.SetItems(items)
if selectedKey then
	rail.Select(selectedKey)
end
```
and the rail's `OnSelected` (L252-260) ends with
```lua
if row and self._rowsByKey[key] == row and row.Selected ~= true and self._context then
	self:_apply(self._context, false) -- the fork did not redraw: drop the rail's selection so the card can be pressed again
end
```

### A5. Interior HUD: every state refresh closes the open Access or Invite list
`GarageInteriorHud.lua` L155-156. `Dropdown.Set` with `Options` always closes the list (`close(); stale = true`),
and `syncView` passes a new `Options` table each time. Pressing INVITE opens the list and starts
`refresh` (L310-316); when `GetManagementState` answers, the list shuts. Same on every `ManagementUpdated` push.
Fix: send `Options` only when their content changed.
```lua
local function optionsKey(list)
	local parts = {}
	for index, option in ipairs(list) do parts[index] = option.Id .. "=" .. option.Text end
	return table.concat(parts, "|")
end
-- in syncView, replacing L155-156 (accessKey, inviteKey are locals beside `syncing`)
local nextAccess, nextInvite = optionsKey(accessOptions), optionsKey(inviteOptions)
if nextAccess ~= accessKey then accessKey = nextAccess; access.Set({ Options = accessOptions }) end
access.Set({ Selected = tostring(state and state.AccessMode or "Private") })
if nextInvite ~= inviteKey then inviteKey = nextInvite; invite.Set({ Options = inviteOptions }) end
invite.Set({ Label = count > 0 and ("INVITE " .. count) or "INVITE", Selected = "" })
```

### A6. A rejected colour leaves the unsaved colour on the 3D vehicle
`GarageModel.lua` L829-831 (`if not (result and result.Success) then ... buildPreview()`). `ApplyPaint` has already
painted the preview. On failure the profile is unchanged, so the Pulse preview key equals `previewKey` and
`buildPreview` builds nothing (Classic rebuilt always). The vehicle keeps a colour that was not saved until some
other input changes the key.
Fix: L831 becomes
```lua
previewKey = nil -- the preview was painted directly; force the rebuild that restores the saved colours
buildPreview()
```

### A7. Desk status strip is drawn off the right edge
`OwnedGarageDeskView.lua` L241. `Data.StatusCluster` does not anchor itself; `TopRight` is a zero-size slot with
anchor (1, 0). With the default anchor (0, 0) the strip starts at the right margin and runs off screen (only
MenuMargin = 68 px of it shows at 1080). `GarageScreenView` (`seat`) and `OwnedGarageBrowserUI` L95 set it.
Fix: after L241
```lua
self._cluster.Instance.AnchorPoint = layer.Slot("TopRight").AnchorPoint
```

### A8. Hidden buttons still take their width in a ButtonRow
`OwnedGarageDeskView.lua` L487, L496, L641-644 and `OwnedGarageBrowserUI.lua` L370 hide row buttons with
`Button(id).Set({ Visible = false })`. `ButtonRow.layout` places every entry whatever its `Visible`, so the row
keeps the gaps. Desk Home page: only EXIT shows, standing left of the empty SAVE and Action plates (two Main
buttons). Browser with no garage or an empty Visit list: EXIT stands left of the hidden ENTER.
Fix (desk): build the row from the visible buttons, as `GarageScreenView.syncButtons` does. In `_build` keep the
four callbacks in `self._calls = { Back = ..., Exit = ..., Next = ..., Action = ... }` and create the row with
`Buttons = {}`; in `_apply` store `self._back`, and on `full` `self._next`, `self._exit` (text or nil), then call:
```lua
function DeskView:_syncButtons()
	local list, calls, action = {}, self._calls, self._action
	if self._back then table.insert(list, { Id = "Back", Text = self._back, Icon = "back", OnActivated = calls.Back }) end
	if self._exit then table.insert(list, { Id = "Exit", Text = self._exit, Icon = "exit", OnActivated = calls.Exit }) end
	if self._next then table.insert(list, { Id = "Next", Variant = "Main", Text = self._next, OnActivated = calls.Next }) end
	if action then table.insert(list, { Id = "Action", Variant = "Main", Text = string.upper(tostring(action.Text)), OnActivated = calls.Action }) end
	self._buttons.Set({ Buttons = list })
end
```
(`_renderCards` and `_renderPaint` only set `self._action`.) Browser: replace L370 by
`buttons.Set({ Buttons = enter.Visible and { exitSpec, { Id = "Enter", Variant = "Main", Text = enter.Text, Icon = "garage", Disabled = not enter.Enabled, MarkKey = "Enter", OnActivated = function() model:Enter() end } } or { exitSpec } })`
and drop `enterButton` and its `Input.Mark` (the row's `MarkKey` does it).

### A9. Properties modal: rows built after `Open` are outside the focus trap (gamepad)
`GarageModals.lua` L134-143. `Overlay.Modal.Open` adds the buttons that exist at that moment to a trapping focus
group. On the first open the list is empty (rows are set after `panel.Open()`), so only the X is in the group and
focus is pulled back from every row. Fix, after the `SetItems` calls:
```lua
syncing = true; panel.Close(); syncing = false -- the trap lists the buttons present at Open: re-enter it with the rows
panel.Open()
```
The same applies to the browser's replacement list (`modal.Open()` at L378 precedes `SetItems` at L388): move the
`if not modal.IsOpen() then modal.Open() end` below the `SetItems` block and open once before it when
`replacementList` is still nil.

### A10. The panel modal can end up under a page
`GarageModals.lua` L77. The modal root is a child of `CanonicalCanvas` with ZIndex 1. `GarageScreenView` destroys
and recreates the page frame on every Browser <-> Workspace change (`releasePage`, `ensureWorkspace`), so a page
created after the modal is a later sibling and draws over it; its tiles and buttons stay clickable with the modal
open. Sequence: Spaces + in the dealership, close, buy a vehicle, Cash + in Customise. Classic used ZIndex 100.
Fix: after `panel = Overlay.Modal(...)`: `panel.Instance.ZIndex = 100` (the kit never writes the root's ZIndex; the
dropdown catcher uses the highest sibling ZIndex + 1 and stays above).

### A11. Desk colour panel is smaller than its content (Regular)
`OwnedGarageDeskView.lua` L512-514. Height counts a slider as `SliderHeight` (40); a labelled kit slider is
31 + 40 = 71. Content at 1080: tabs 42 + 3 x 71 + 2 x 64 + 5 gaps x 10 = 433 against 416 - 44 = 372 inside the
panel: the second preset row hangs 61 px below the panel, 31 px below the screen. Row 1 is 14 swatches:
14 x 64 + 13 x 10 = 1026 against 856 of content width; it runs 170 px past the panel's right edge.
Fix: size the panel from what it holds, after the swatches are built:
```lua
local function fitPanel()
	local pad, scale = self._ctx.Px(space.Pad), self._ctx.Scale
	local wide = math.max(paint.channelRow.AbsoluteSize.X, paint.rows[1].AbsoluteSize.X, paint.rows[2].AbsoluteSize.X)
	paint.panel.Set({ Width = (wide + 2 * pad) / scale, Height = (column.AbsoluteContentSize.Y + 2 * pad) / scale })
end
self._scope:connect(column:GetPropertyChangedSignal("AbsoluteContentSize"), fitPanel)
fitPanel()
```
(keep the two palette frames in `paint.rows`). See C3 for Compact.

## B. Probable bugs; check in Play

1. Gamepad, focus after a tile press. `GarageScreenView.syncRail` L494-498 and A4's fix clear the rail with
   `SetItems({})`, which hides the focused tile. Look: after pad A on a slot, unlock or Paint tile, is a tile still
   highlighted and does the D-pad still move.
2. Gamepad, first focus. No garage page calls `FocusGroup.Enter`; look whether a pad can reach tabs, tiles and
   buttons without the Roblox selection toggle (dealership, customise, desk, browser).
3. Gamepad, bumpers on Paint. Header tabs bind L1/R1 (`Bumpers = true`); `Controls.Slider` reads the same buttons
   as its coarse-step modifier. Look: holding a bumper on a slider changes tab.
4. Spaces after a capacity purchase. `GarageModel.buyProperty` L881-885 redraws the modal only; `page.Spaces` is
   from the last page build (Classic is the same). Look: strip still shows the old "n / m". Fix if wanted, after a
   successful reply: `local o, c = capacity(); page.Spaces = o .. " / " .. c; emit("render")`.
5. Rejected capacity purchase: the text goes to the header sub-line under the open panel and to the toast. Look
   that the toast is readable over the panel.
6. Rejected upgrade (`GarageModel` L1681-1687): `PreviewUpgradeId` is cleared but the page is not rebuilt; the tile
   stays selected with the stat preview and an enabled Upgrade button (Classic is the same).
7. `message(r.Message)` prints "nil" if a failure reply has no Message (L883, L1455, L1583, L1686, L1959). The
   server paths read all return text; a `tostring(r.Message or TEXT.PurchaseFailed)` costs nothing.
8. Browser tabs while busy. `OwnedGarageBrowserUI` L82-87: the kit tab is already switched when `model:SetMode`
   ignores the press (busy). Fix: after it, `header.Tabs.Select(model:Snapshot().Mode == "Visit" and TAB_VISIT or TAB_MINE)`.
9. Replacement failure: `ChooseReplacement` writes the status line, which is under the modal scrim.
10. `PaintView` Regular: tabs 42 + gap 10 + 3 x 71 + 2 x 10 = 285 against 320 - 44 = 276 of panel content; the
    third slider's lower edge is 9 px over the hairline.
11. Pooled desk tiles keep `CanonicalGarageCardId` from an earlier mark (Home and Build cards); a later "Card"
    mark does not clear it, and the onboarding `matches` test accepts attributes that are still set. Look at
    onboarding pages 9 to 14 for a highlight on the wrong card.
12. Interior HUD toasts send `{Text, Icon, Kind}, 2.4`; every other garage owner sends a string. Look that
    "ACCESS MODE SAVED" and "PLAYER INVITED" draw.
13. Drive pressed while a colour commit is in flight: `SpawnVehicle` gets the busy reply and the garage closes
    with no vehicle (Classic is the same).
14. Kit weak tables keyed by live instances: `Overlay.openConfirms` L614, `Input.focusConnections` L17. Both
    recover when an entry drops (the replaced confirmation is still cancelled through `Destroying`); no garage
    file has one.
15. Compact dealership tile with a short name: tier badge (about 42 px) plus compact price chip (about 53 px)
    against a tile of 88 to 92 px. Look for the chip on the badge.

## C. Compact layout, computed

Assumptions: safe area equals the screen; `TopbarInset.Height` 58; scale 1.00 at 844x390 and 0.85 at 568x320;
Compact unit 8/22; text widths estimated at 0.5 x TextSize per glyph (marked "est."). Rectangles are x1..x2, y1..y2
in screen px.

Frame (Scene): 844x390: margin 12, top 8, base 382, RightColumn 656..832 from y 45, RailButtons corner (832, 308),
BottomRail corner (12, 382). 568x320: margin 10, top 7, base 313, RightColumn 408..558 from y 38, RailButtons
corner (558, 250).

| Part | 844x390 | 568x320 |
|---|---|---|
| Header (title beside Roblox buttons, sub, tabs) | y 8..140 | y 7..135 |
| Status strip | 652..832, 8..38 (est. width) | 390..558, 7..33 |
| Stat panel (dealership, with price row) | 656..832, 45..211 | 408..558, 38..178 |
| Button row (hit box 48) | right edge 832, 260..308 | right edge 558, 202..250 |
| Rail (heading, then 60 px tiles) | 12..844, 290..382 | 10..568, 235..313 |

**C1. Cash and Properties modal is taller than the screen.** `GarageModals` L80-81 pass `ConfirmWidth` 650 and
`StatPanelHeight` 448 as design values; `Surface.Panel` uses `ctx.Px` with no Compact conversion. 844x390:
650x448 at 97..747, 0..448: 58 px below the screen. 568x320: 553x381 at 7..560, 0..381: 61 px below.
Fix (GarageModals, with `local Metrics = require(Kit.Metrics)`):
```lua
local ctx = Metrics.Of(root)
local room = 2 * ctx.Px(Space.CompactMargin)
local compact = ctx.Class == "Compact"
Width = compact and math.floor(math.min(Space.ConfirmWidth, (ctx.Size.X - room) / ctx.Scale)) or Space.ConfirmWidth,
Height = compact and math.floor(math.min(Space.StatPanelHeight, (ctx.Size.Y - room) / ctx.Scale)) or Space.StatPanelHeight,
```

**C2. Paint tab, colour page.** `PaintView` controls are 3 x 176 + 2 x 10 = 548 wide and 48 + 10 + 65 = 123 high.
844x390: picker 12.., 150..198; controls 12..560, 208..331; presets (13 swatches of 48) 12..756, 334..382; buttons
260..308 right of x 640 (est.). Fits with 3 px to spare. 568x320: picker 144..192; controls 10..478, 201..320;
presets (9 swatches) 10..514, 265..313. The slider row (258..320) lies on the preset row and ends on the screen
edge. Fix options: on Compact drop the picker into the header line (the tab row is 48 high and the picker could
stand right of the tabs), or hide the preset row when `controls` bottom passes `base - 48`.

**C3. Desk colour panel.** `OwnedGarageDeskView` L512-514: 900x416 design. 844x390: 12..912, -34..382 (68 px past
the right edge, 34 above the top). 568x320: 10..775, -41..313. With Compact hit sizes the content needs about
846 x 433, so resizing alone cannot fit: Compact needs the `PaintView` arrangement (sliders side by side, one
preset row).

**C4. Compact tiles draw no Sub and no ChipLeft** (kit `Collections` tile: "Regular only"). In the module list the
variant (Standard, Lightweight, Power) is `ChipLeft` and the status and rating are `Sub`: three variants of one
source vehicle show the same name. Upgrade tiles lose "LEVEL n" and the effect line. Fix in
`GarageScreenView._tileProps`, before the return:
```lua
local title = tostring(item.Title or "")
if compact and item.ChipLeft ~= nil and (item.Kind == "Module" or item.Kind == "Upgrade") then
	title = title .. " " .. tostring(item.ChipLeft)
end
```
and use `Title = title`.

**C5. Header sub-line against the stat panel (est.).** The sub-line is one unwrapped line at y 66..84 (844) or
65..80 (568). `UpgradesSub` (68 glyphs): 12..590 at 844 (clear of 656); 10..500 at 568, over the stat panel at
408. `PostPaintSub` (60): 10..442 at 568, over the panel. `DriveBlocked` (56): 10..413 at 568, touching it.
Fix: shorter Compact texts in `GarageRoutes.Text`, or pass `Sub = ""` on Compact when a message is not showing.

**C6. Dealership category tabs at 568 (est.).** ALL plus five categories is about 394 px: 10..404, y 88..136,
ending at the stat panel (408). A sixth category overlaps it.

**C7. Owned-garage browser** (layout already known broken; numbers for the fix). 844x390: list 12..244,
124..326; detail 532..832, 124..358; buttons 334..382 right of x 614 (est.): the facts panel overlaps the button
hit boxes by 24 px. 568x320: list 10..207, 122..264; detail 303..558, 122..322: 2 px past the screen and over the
buttons (265..313). `layout()` L294-300 never limits `detailHeight` to `available`.

**C8. Desk button row.** With A8 unfixed the Compact row reserves Back + Exit + SAVE + Action (about 351 px);
EXIT stands at about 564..634 at 844 with nothing to its right.

## Counts

A: 11 definite. B: 15 probable. C: 8 Compact.
