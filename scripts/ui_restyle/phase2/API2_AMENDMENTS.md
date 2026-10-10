# API2 amendments

Additions to `API2.md` made after the wave-2 build started. Append; newest last. Each entry names the section it
extends, the unit that needs it and the default, so units that do not use it are unaffected.

## A1. `Collections.Rail` prop `SelectOn` (extends 2.9; needed by `garage`; 2026-10-09)

```lua
Collections.Rail(parent, { ..., SelectOn: "Focus" | "Activate"? }, scope)   -- default "Focus"
Collections._railSelects(selectOn, cause: "Focus" | "Activate"): boolean    -- pure; the rule below
```

- `"Focus"` (the default, and the behaviour of every rail before this entry): a gamepad or keyboard focus move
  selects the tile and calls `OnSelected`, exactly as a click does.
- `"Activate"`: a focus move only highlights the tile (the tile's own focused look) and scrolls it into view;
  `Select`ed state and `OnSelected` change only on an activation (click, tap, gamepad A). For rails whose selection
  navigates or previews a purchase.
- Any other value errors, in props and in `Set`. `Select(key)` and `SetItems` are unchanged.
- Source: `kit/k2/after/...Kit.Collections.lua` (K2); tests in `kit/k2/tests/...Kit.Collections_test.lua`; gallery state
  `Collections.Rail` / `SelectOnActivate`. **The kit unit must be reassembled and reinstalled before `garage`**: an
  installed kit without this prop throws "unknown key SelectOn" when a garage rail is built.
- Users: `Garage.GarageScreenView` (dealership rail and customise rail), `Garage.OwnedGarageDeskView` (desk rail).
  Reason: reviewer finding, garage delivery review: with focus-selects, focusing a slot tile, the Paint card or the
  unlock card navigated at once.

## A2. `Controls.Tabs` touch width and wrap (extends 2.8; needed by `race_entry`; 2026-10-09)

- When `Input` is Touch or `Class` is Compact, every tab is at least `ctx.Touch(1)` wide (48) and the gap between
  tabs is at least `TouchGap` (8), as the height already was. A row wider than the safe area (`ctx.Size.X`) wraps
  onto further lines, each one tab high, so `tabs.Instance.Size` can be more than one line tall. A text tab that was
  widened and has no icon centres its text. Regular with a mouse or gamepad is unchanged: natural widths, one line.
- New pure helper `Controls._tabWrap(x, y, width, lineStep, limit): (x, y)`. No new prop.
- Reason: pre-flight finding: the race-entry tier tabs (E D C B A S) were about 18 px wide on a phone.

## A3. `Surface.Panel` prop `FitContent` (extends 2.7; 2026-10-09)

```lua
Surface.Panel(parent, { ..., FitContent: boolean? }, scope)   -- default false
```

- The size rule, unchanged: a nil `Width` or `Height` **fills the parent** on that axis. A caller that passes no
  `Height` gets a panel as tall as its parent.
- `FitContent = true` with no `Height`: `Content` grows down with its children (`AutomaticSize.Y`; give the children
  offset heights, not scale) and the panel is that height plus the pad above and below. A `Height` wins over
  `FitContent`. No instance is added (budget 4 stands).
- Reason: pre-flight finding: two callers passed no height and got a screen-tall panel.

## A4. `OnActivated(key)` on `Collections.Rail` and `Collections.List` (extends 2.9; 2026-10-09)

```lua
Collections.Rail(parent, { ..., OnSelected: ((key: string) -> ())?, OnActivated: ((key: string) -> ())? }, scope)
Collections.List(parent, { ..., OnSelected: ((key: string) -> ())?, OnActivated: ((key: string) -> ())? }, scope)
```

Use `OnSelected` for highlight and preview, and `OnActivated` for anything that acts. `OnSelected(key)` fires only
when the selection **changes** (a click, or a focus move unless `SelectOn = "Activate"`), so a press on the item that
is already selected never reaches it: that was three "click does nothing" bugs (vehicle spawn, cash packs, phone
race rows). `OnActivated(key)` fires on **every** activation of a row or tile (click, tap, gamepad A), the selected
one included, after any `OnSelected` for the same press; it never fires for a focus move, for `Select(key)` or for a
Locked item. The standalone `Tile` and `ListRow` keep their own `OnActivated: () -> ()` (no key; also every
activation), and an item passed to `SetItems` may still carry one, which runs after the collection's. Both are
optional and replaceable through `Set`.

## A5. `Kit.Input` focus records are strong (extends API1 13; 2026-10-09)

`Input.Focusable` keeps each button's `OnFocus` connections in a strong table and releases them on the button's
`Destroying` (it was weak-keyed by Instance, which can drop a live record). A focusable button must be destroyed,
not just dropped. `Input._holdsFocusRecord(button)` is a test hook. `Kit.Collections`, `Kit.Controls` and
`Kit.Surface` hold no weak tables.

## A6. Picture modes on `Collections.Tile` and `Collections.ListRow`, and `ListRow.TierSide` (extends 2.9; 2026-10-09)

```lua
Collections.Tile(parent, { ..., PictureMode: "Box" | "Full" | "Wide"? }, scope)       -- default "Box"
Collections.ListRow(parent, { ..., PictureMode: "Square" | "Wide"?, TierSide: "Left" | "Right"? }, scope)
                                                                                        -- defaults "Square", "Left"
```

All three are opt-in, are checked like any other prop (an unknown value throws), can be changed through `Set`, and
may be carried by an item passed to `Rail.SetItems` / `List.SetItems`. A caller that passes none of them gets
exactly what it had. `PictureMode` only changes a tile or row that has an `Image`; an `Icon` tile is never changed.

- **Tile `"Full"`**: the picture covers the whole tile, behind the text, in a clipping Frame named `Picture`
  (`Picture.Image`, `Picture.Scrim`). A Slate scrim lies over it and rises to `Opacity.ScrimBottom` at the foot,
  where the name is. The text is always light. The selected tile has **no White fill**: it keeps the thick Pink to
  Violet base line, the growth and the glow, its picture is undimmed, and the others are dimmed
  (`Opacity.RankTrack`; `Opacity.ChipNeutral` under the pointer). Neutral chips get an Ink plate. No `UIStroke`
  (style sheet: no outlines).
- **Tile `"Wide"`**: the picture covers the tile's full width from its top down to a gap above the text; the tile
  keeps its usual looks (White fill when selected).
- **ListRow `"Wide"`**: the picture is shown whole in a box of its own shape (3 wide to 2 high), as tall as the row,
  in place of the square crop.
- **ListRow `TierSide = "Right"`**: the tier letter and the `Sub` line leave the left and stand on one line against
  the right edge (sub-line, then letter); the name is alone between the picture and them. A `Chip` goes under that
  line when the row is tall enough for both, else beside it as before.
- The cover is cut on the car, not on the picture's centre: `Collections._cover(boxWidth, boxHeight, aspect, focusX,
  focusY)` (pure). The kit holds the card picture's shape and focus as design ratios (`PICTURE_ASPECT` 1.5,
  `PICTURE_FOCUS_X` 0.54, `PICTURE_FOCUS_Y` 0.52: the 1536 by 1024 vehicle card renders). `Collections._overPicture(look,
  flags)` (pure) is the look of a `"Full"` tile.
- Budget: a picture-mode tile or row adds 2 instances (`Picture`, `Image`), a `"Full"` tile 2 more (`Scrim`, its
  gradient), made on first use and then reused. Nothing is created on a selection change.
- Users: `garage` dealership rail (`RAIL_PICTURE` in `GarageScreenView`), `free_roam` car panel list.
- Reason: owner feedback 2026-10-09: dealership pictures too small; the free-roam list cut the cars' noses off.

## A7. The Compact (phone) tile: one design for every `Collections.Tile` (extends 2.9 and A6; mobile pass; 2026-10-10)

On `ctx.Class == "Compact"` a tile, alone or in a `Rail` (one row or a grid), is laid out by one rule. Regular is
unchanged. Views can rely on every line below.

- **Size.** Height `CompactTileHeight` (60 dp). Width, in order: the grid cell (`Rows > 1`), `Rail.CellWidth` (dp), else
  `CompactTileMinWidth x 1.25` (110 dp). **The width never follows the name**, so every tile of a rail is the same
  width (it was `max(CompactTileMinWidth, name width)`: 80 to 255 px in one rail).
- **Name.** Bottom-left, `TileNameSmall`, in a fixed two-line box: it wraps to a second line and ends in an ellipsis
  (`TextTruncate.AtEnd`). No `Sub` line and no `ChipLeft` on Compact (as before).
- **Top row**, flush with the top edge, one row high (the `Value` text size, 18 px at scale 1), left to right: tier
  letter, rating, icon; and **exactly one chip against the right edge**: what `Collections._corner` returns (`OWNED` /
  `FITTED` or `ChipRight` for an owned or fitted item, else `Price`, else `ChipRight`; `ChipRightKind = "Tick"` is the
  cyan tick). Nothing in the row overlaps: `Collections._compactTop(width, chip, letter, rating, icon, gap)` (pure)
  keeps the chip and drops **the rating first, then the icon, then the tier letter**. In 110 dp a tier letter and
  rating fit beside `OWNED`; beside a full price (`$150,000`) the rating goes. In a 90 dp grid cell a tier letter
  fits beside one short text chip (`Tier = "S", ChipRight = "Current", ChipRightKind = "Cyan"`) or the tick.
- **Icon.** A tile with no `Image` shows its `Icon` glyph in the top row (row height), not in the middle of the tile.
  A **locked** tile shows the lock glyph there instead (with or without a picture); there is no separate `Lock` part.
- **Picture.** A tile with an `Image` always shows it over the whole tile under the Slate scrim (the `"Full"` look of
  A6), whatever `PictureMode` says: a boxed picture would be 18 px high.
- **Selected** (and controller focus). Never the White fill. With a picture: the A6 `"Full"` look (undimmed picture,
  others dimmed). Without: an opaque Slate plate, light text. Both keep the Pink to Violet base line (4 dp), the
  6 dp growth and the glow. `Collections._compactTile(look, flags, hasPicture)` (pure) is the look.
- Budget unchanged (13; a picture adds the 4 of A6). Source: `Kit.Collections` `renderCompact` in `buildTile`; tests
  `compactTile`, `compactTop`, `Tile C844` in `Kit.Collections_test.lua`; gallery `Collections.Rail` / `LongNames`,
  `LongNamesSelectedLong`, and every `Collections.Tile` state at C844 and C568.

## A8. `Controls.Header`: hidden `Tabs`, and prop `SubMaxWidth` (extends 3.6; mobile pass; 2026-10-10)

```lua
Controls.Header(parent, { ..., SubMaxWidth: number? }, scope)   -- design px; default nil = as before
```

- A `Tabs` whose root is not visible (`Tabs = { Visible = false, ... }`) takes no room: neither its gap nor its
  height counts in `Height()` or the root size. **This changes Regular too** where a header hides its tabs (the
  post-purchase paint page started one tab row low). A visible `Tabs` is laid out exactly as before.
- `SubMaxWidth`: the sub-line is exactly that wide and ends in an ellipsis, for a long status or error line that
  would run under a right-hand column. Without it the line is as wide as its text (unchanged).
- Not changed, by design (API2 2.4 rule 2): on Compact the title row stands beside the Roblox top-left buttons
  (`TopBarKeepOut.X + CompactKeepOutGap`) while the sub-line and tabs start at the slot's left edge under the bar.
  The gap between the title mark and the title is `Space.Gap` in both classes.

## A9. `Controls.Tabs` prop `MaxWidth`, and the Compact wrap limit (extends 2.8 and A2; mobile pass; 2026-10-10)

```lua
Controls.Tabs(parent, { ..., MaxWidth: number? }, scope)   -- design px; default nil
```

- `MaxWidth` wraps the row at that width in any class and input (for tabs inside a panel). Not a number above 0: error.
- Compact without `MaxWidth`: the row wraps at `ctx.Size.X - 2 x CompactMargin` (it was the whole `ctx.Size.X`, so a
  row that started at the margin could pass the right edge by a margin). Regular with touch still wraps at
  `ctx.Size.X`; Regular with a mouse or gamepad never wraps unless `MaxWidth` is given.

## A10. `Controls.ButtonRow` collapses on Compact; `Controls.Dropdown` list placement; `Controls.Slider` on Compact (extends 2.8, 3.6; mobile pass; 2026-10-10)

- **ButtonRow.** On Compact a row wider than `ctx.Size.X - 2 x CompactMargin` shows every secondary button that has
  an `Icon` as icon-only (`Controls._rowCollapses(patch)`, pure: never `Main`, `Buy` or `Icon` variants, never a
  button with no icon). It opens again when the button ids or the screen change. Give secondary buttons an `Icon`
  if a row can be long. Regular never collapses.
- **Dropdown.** `Controls._dropdownPlace(left, top, bottom, width, rows, rowHeight, hostWidth, hostHeight)` (pure):
  under the control; above when it only fits there; when it fits on neither side, on the roomier side with as many
  whole rows as fit (the list scrolls); never past the host's right edge. The first two cases are the old
  behaviour; the last two replace a list that ran off the screen (**both classes**, only where it overflowed).
- **Slider.** Compact: track 4 dp, handle 10 x 26 dp (was 2 px and 4 x 12 px). The hit band was and is 48 dp.

## A11. `Data.DeltaChip` on Compact; `Overlay.Modal` on Compact (extends 3.5, 3.7; mobile pass; 2026-10-10)

- **DeltaChip**, Compact: no arrow (the sign and the colour carry the meaning), role `Label`, and a hairline shorter
  than its text line above and below. In a 176 dp `StatPanel` the chip column is about 23 px (was 32), the bar keeps
  6 segments beside it (was 4) and stacked chips no longer join into one block. Regular unchanged.
- **Modal**, Compact, centred form: a `Width` or `Height` larger than the safe area less `CompactMargin` on each side
  is cut to it, so the panel never leaves the screen (give tall bodies a scroller). The close button's 48 dp hit box
  is centred on the title row and let out past the right padding, so the drawn X is on the title's centre line
  against the panel's right padding (it hung about 11 dp low and inset). Regular unchanged.

## A12. Components bind their root to their context (extends 2.3; mobile pass; 2026-10-10)

`Gauge`, `Minimap`, `PromptBanner`, `Confirm` (its shade), `Button`, `Tabs`, `Header`, `IconButton`, `Stepper`,
`Dropdown`, `Tile`, `Rail`, `ListRow`, `List`, `DeltaChip`, `CashChip` and `FactList` now call
`Metrics.Bind(root, ctx)` when the root is made (as `ButtonRow` and `StatusCluster` did), so kit parts they build
before the root is parented (`BigNumber`, `Surface.Icon`, `Surface.Glow`, `Text.Label`) resolve the component's
context and not the screen's. No visible change where the stage and the screen are the same context (the live game).

## A13. `Overlay.PromptBanner` and `PromptStack` on a touch phone (extends 3.7; mobile pass; 2026-10-10)

Touch on **Compact** is now the *slim* banner; touch on Regular (a tablet) keeps the solid White button, and key or
pad banners are unchanged in both classes.

- The root is still the button and the hit box (48 dp high, 56 for `Main`) but is clear. A child Frame `Plate`
  (Slate at `Opacity.Panel`, `CompactButtonDrawn` 36 dp high, 44 for `Main`, centred in the hit box) is the drawn
  banner; `HairTop`, `HairBottom` and the hold line `Progress` are parented to it. `Plate.Edge` is a Cyan bar
  `TabUnderline` wide down its left side: the tap affordance (the icon sheet has no tap glyph). Text is White
  (action) and TextSecondary (object).
- Width hugs the text: `pad + edge + action + gap + object + pad`, at least `2 x CompactTileMinWidth` (176 dp) and at
  most `Overlay._promptSize` (`CompactPromptWidth`, 300 dp, less on a narrow screen). `_promptSize` itself is
  unchanged and is now the maximum. The `PromptStack` root stays that maximum wide and centres its banners.
- `PromptStack` shows the newest **2** banners on Compact (3 on Regular); `Count()` follows.
- Budget: the slim banner is 8 instances (limit 9). `Plate` and `Edge` are built the first time a banner is slim and
  kept. Tests: `prompt banner, touch` in `Kit.Overlay_test.lua`.

## A14. `Controls.Tabs`: the selected tier's fill is the drawn box (extends 2.8 and A2; mobile pass round 2; 2026-10-10)

- Where a tab's hit box is taller than its drawn box (touch: the hit box is 48 dp, the drawn box `BadgeLarge`), the
  selected tier is no longer the button's whole background. The tabs root has one child Frame **`Fill`** (ZIndex 0,
  under the buttons, not Active) on the selected tier's drawn box: from the top of the drawn box to the bottom of
  its base line, as wide as the tab. It is made with the row when the row has a tier tab, moved on `Select`, hidden
  when no tier is selected, and never created on a selection change. The selected button's background is clear.
- Where the hit box is the drawn box (Regular with a mouse or gamepad) nothing changes: the button's own background
  is the fill and there is no `Fill` child. A Regular touch screen (tablet) with a drawn box under 48 px gets the
  `Fill` too.
- The controller-focus look (`look.Fill`, White over the hit box) is unchanged.
- Views must not assume every child of a tabs root is a tab: tabs are named `Tab<Id>`.
- Tests: `Tabs: on touch the selected tier's fill is the drawn box`. Gallery: `Controls.Tabs | TierButtons` at C844.

## A15. `Collections.ListRow` selected on Compact (extends 2.9 and A7; mobile pass round 2; 2026-10-10)

On `ctx.Class == "Compact"` a `ListRow` (alone or in a `List`) takes `Collections._compactTile(look, flags, false)`:
the selected (or controller-focused) row is an **opaque Slate plate with light text** (title, sub-line and right-hand
text White; a neutral chip keeps its White at `ChipNeutral` plate), never the White fill with Ink text. It keeps the
Pink to Violet base line, now `2 x Hairline` (4 dp, the Compact tile's line; it was `TileBaseLine x 8/22`, about
2 px), the list's glow, and the Pink left bar of an `Accent` row. A `Columns` row follows the same look. Regular is
unchanged. Tests: `ListRow C844: Selected is an opaque Slate plate`. Gallery: `Collections.ListRow | Selected`,
`LiveOrderYou`, `VehicleSpawnedSelected`, `TierRightChipSelected`, and `Collections.List | Results` at C844.

## A16. `Collections.List` prop `Dense` (extends 2.9; mobile pass round 2; 2026-10-10)

```lua
Collections.List(parent, { ..., Dense: boolean? }, scope)   -- default nil = as before
```

`Dense = true` drops the touch-size floor (`ctx.Touch(1)`, 48 px on touch) from the height of the list's rows, for a
display-only list nobody presses (a leaderboard, a results table). Give it a `RowHeight` as well: the default row
height on Compact is `TouchMin` itself. An item's own `Height` is honoured without the floor too. It can be set and
cleared with `Set`. Without `Dense`, and on Regular with a mouse (which has no floor), nothing changes. A standalone
`ListRow` always keeps the floor. Tests: `List: Dense drops the touch-size floor`. No gallery state uses it yet.

## A17. `Data.FactList`: label and value share the row (extends 3.5; mobile pass round 2; 2026-10-10)

- **Both classes.** The value has priority: a text value keeps its box (the row less the icon inset, right aligned)
  and a `Prize` chip its text width plus two gaps, never wider than the row less the icon inset. The label is as
  wide as what is left less one `Gap` (`Size = UDim2.new(1, -(inset + value + gap), 0, rowHeight)`) and both have
  `TextTruncate = AtEnd`, so a long pair no longer overlaps: the label ends in an ellipsis first, the value only
  when it alone is wider than the row. A label with no room at all is hidden. With strings that fit, a row draws
  exactly as before.
- `Data._factSplit(rowWidth, labelX, valueBox, gap)` (pure) returns the value box, the label's inset and whether a
  label fits; `rowWidth` 0 (a parent-wide list not laid out yet) cuts nothing. The list now also redraws when its
  root's `AbsoluteSize` changes.
- Budget unchanged (6 a row). Tests: `factSplit`, `FactList: the label ends before the value`. Gallery:
  `Data.FactList | LongestStrings` (and `RaceEntry`, `NoIcons` for the unchanged case) at C844 and R1080.

## A18. `Controls.Header` prop `MaxWidth` (extends 3.6 and A8; mobile pass round 2; 2026-10-10)

```lua
Controls.Header(parent, { ..., MaxWidth: number? }, scope)   -- design px; default nil = as before
```

The title is cut to that width and ends in an ellipsis (a long event name that would run under the cash chip or a
right-hand column). The title's `Text.Label` is then exactly `MaxWidth` wide, but the count and the header's own
width follow the drawn text, so a title that fits is laid out as it is without `MaxWidth`. Not a number above 0:
error. It can be given or changed with `Set`, not removed (a patch cannot carry nil). Tests: `Header: MaxWidth cuts
the title`. No gallery state uses it yet (`Controls.Header | LongestTitle` is the state to give it to).

## A19. Test note: `Tabs.MaxWidth` (A9) was right; its test was not (mobile pass round 2; 2026-10-10)

`Tabs.Set({ MaxWidth = n })` did re-wrap. The test staged twelve tabs detached, where text does not measure, so the
row was only its gaps (11 x `TabGap` = 374 px) and never reached the 400 px it asked for. The test now wraps at half
the measured one-line row. No code change.
