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

## A20. `Kit.Gauge`: gear readout, shift light, punch and `Step`; budget 28 (extends 3.2; drivetrain_feel; 2026-10-20)

Source: `scripts/drivetrain_feel/hud/after/Gauge.lua`
(canonical copy: `kit/k3/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Gauge.lua`). Approved with the drivetrain_feel
plan (Oscar, 2026-10-20; `scripts/drivetrain_feel/CONTRACT.md` section 7). This entry is the recorded exception to
"the Kit API is frozen after the free-roam HUD" (PC 2.2). The delivery-reviewer signs it off with the delivery.

```lua
Gauge.Light: { Off = 0, Warm = 1, Shift = 2, Limiter = 3, Spin = 4, Overdrive = 5 }   -- frozen
Gauge.New(parent, props, scope): Component & {
  SetSpeed, SetBoost, SetUnit, SetVisibleBoost,                 -- unchanged
  SetGear: (text: string?) -> (),       -- "N", "R", "1".."7"; a number shows its digits; nil or "" hides the readout
  PunchGear: () -> (),                  -- one punch of the shown gear; nothing while no gear shows
  SetShiftLight: (level: number) -> (), -- a Gauge.Light level; anything else is Off
  Step: (dt: number) -> () }            -- advances the punch and light clocks; call once a frame, first in the owner's step
```

No new prop and no change to an existing signature, value or default. A gauge that is never given a gear (every car
without drivetrain telemetry, and Classic, which does not use the kit) looks and writes exactly as before.

**New part: one `TextLabel` named `Gear`** (child of the root, ZIndex 6, hidden at build).

- Built with `Text.RawLabel(root, role, ctx)` in its real role. Role per gauge, following the speed number's own
  steps: `Status` on the full Regular gauge, `Value` on the smaller Regular (touch) gauge, `SectionHead` on Compact
  (12.6 dp, larger than the 9.7 dp unit line it replaces). All three are Fixed (API2 2.6), so the gear carries a
  **`SizeLock`**, found once at build. `layout()` sets the face and size of the current role with `Text.Font` and
  `Text.SizeFor`, and writes the lock's `MaxTextSize` = the top punch step (the box height). The punch stays a plain
  `TextSize` write, and the player's Text Size setting grows the gear no further than its box (`TextFits` at Largest).
  `AutomaticSize` is `None`: the gear is live text (PC 4 "AutomaticSize only on static text"), and `layout()` sets
  its box.
- Placed in the empty bottom gap of the ring at `GEAR_Y = 0.41` of the frame on Regular (below the boost line). On
  Compact (92 dp, no boost line) it takes the unit line's place at `GEAR_Y_COMPACT = 0.205` (the unit's 0.181, lowered
  2 dp so the larger cap clears the speed digits) and **`Unit` is hidden while a gear shows**; `SetGear(nil)` shows it
  again. Regular keeps `Unit`.
- The box spans the frame width (text centred) and is as tall as the largest punch step, centred on its line, so a
  punch writes only `TextSize` and nothing relayouts.
- **Budget 26 becomes 28.** API2 count (root included, size locks excluded, as the k3 `budgetOf`): **27**. Raw
  descendants plus root, with the `BoostText` and `Gear` size locks: **29** (under the PC table's 32 for the gauge).
  Parts: root, Track, Ticks, ArcLeft, ArcRight, BoostLeft, BoostRight, 6 images, 6 masks, Tip, Speed (root + 3
  cells), Unit, BoostText (+ SizeLock), **Gear (+ SizeLock)**.

**Shift light: the gear text colour and the `Tip` tint, nothing else.** Baked images keep `ImageColor3` white and the
`Speed` BigNumber colour is never changed (`Set({Colour})` would rewrite every cell).

| Level | Gear text and tip |
|---|---|
| 0 Off | `White` (the tip's colour today) |
| 1 Warm | `Cyan` |
| 2 Shift | `Pink` |
| 3 Limiter | `Pink` / `White` flash at **3 Hz**, duty 0.5, lit on its first frame (phase-locked to the level change). HudView sends it in a gear only: the limiter in N (neutral revs on the countdown) shows as a steady 2 Shift, so there is no bounce effect in neutral |
| 4 Spin warning | amber = `Yellow:Lerp(Pink, 0.3)` (255, 173, 80), steady. Derived from tokens like the cash chip's warm yellow (Kit.Data `CASH_WARM`); no colour literal. A `Colour.Warning` token would replace it if the integrator prefers |
| 5 Overdrive | brightness pulse `Cyan` toward `White` (0 to 60%) and back at 1.5 Hz in 4 whole steps (precomputed colours, no per-frame `Color3` allocation) |

A light change writes 2 properties; a steady light writes nothing per frame. Flashing never exceeds 3 Hz (PC and
drivetrain_feel contract 7).

**Punch.** `PunchGear` sets `TextSize` to base x 1.15 at once, then `Step` settles it in whole steps (x1.10, x1.05,
base) on an exponential clock (time constant 0.12 s): about 0.22 s, at most 3 extra text sizes, one write per step,
capped at `Type.MaxTextSize`. No `UIScale` anywhere in the gauge. **Recorded exception to PC 4 "TextSize is never
tweened"**: one or two glyphs, discrete steps, at most one punch per shift (shifts are at least
`ShiftMinIntervalSeconds` 0.25 s apart). `SetGear(nil)` ends a running punch.
**Recorded exception to PC 4 "At most twelve distinct text sizes on screen"**, for the punch only. Its steps
(47, 45 and 43 at 1080 on the full gauge) are transient. The gear shows one size at a time, so at any moment the punch
adds at most one size to the screen, for about 0.22 s per shift. The gear's base size is a role size and counts
toward the twelve like any other text. The integrator's census checks the steady HUD with a gear showing.

**`Step(dt)`.** The gauge still has no frame binding of its own. The owner calls `Step` from its one `Perf.Bind` step
(HudView.Step; the gallery fixture's step). It is called **first** in that step, before the frame's `SetGear`,
`PunchGear` and `SetShiftLight`. A punch or light change is then drawn at its full value before its clock moves, so
the top punch step shows for one frame at any frame rate. Called after them, it would skip the x1.15 step below about
46 fps. `Step` returns at once when no punch runs and the light is steady, and it ignores `dt <= 0`, NaN and nil.
Clocks are time-based, so the flash rate and the punch length do not depend on frame rate; the frames sampled from
them do. The light clock wraps every 2 s (a whole number of flash and pulse periods). No lookup, no creation.

**Write costs** (counted by `_writes()`, which now includes these setters): `SetGear` 1 (text) and 1 to 3 on show or
hide (visibility, and `Unit` on Compact); `PunchGear` 1; `SetShiftLight` 2 on a change; `Step` at most 1 punch write
plus 2 light writes in a frame. Steady drive with telemetry adds nothing per frame; the rpm arc costs what the speed
arc did (2 mask writes and 1 tip write per half-degree step).

**Pure test seams** (outside API2, like `_sweep`): `_gearText`, `_lightLevel`, `_flashOn`, `_lightColour`,
`_punchLevel`, `_punchSize`.

**Users.** `FreeRoam.HudView` through `HudView._telemetry(gauge)` (drivetrain_feel contract 3.2 and 7: rpm arc with a
needle spring, gear, punch on `GearRevision`, `ShiftLight` 0..4 and `Overdrive` mapped onto `Gauge.Light`, the
limiter in N as a steady Shift); `Dev.Fixtures.Gauge` (states `GearN`, `Gear1`, `Gear7`, `Reverse`, `ShiftWarm`,
`ShiftLight`, `Limiter` (in 3rd), `NeutralLimiter`, `SpinWarning`, `Overdrive`, `GearPunch`, `GearRun`,
`GearTouchSize`; fixture props `Gear`, `Light`, `Punch`, `Rpm`).

**Style sheet** (`docs/design/pulse-racers-ui-style-sheet.md` line 209, "The outer arc is speed"): add "For a car that
sends drivetrain telemetry (Exotic) the outer arc is rpm, with the redline at 0.87 of the sweep inside the pink last
fifth, and the gear sits in the bottom gap (on a phone it replaces the unit line); the shift light is the gear's colour
and the tip." Line 144 (baked images never tinted) is unchanged and holds.

Tests: `kit/k3/tests/...Kit.Gauge_test.lua` (budget 28 by the API2 count, the gear `SizeLock` at the top punch step
and no `AutomaticSize`, gear show/hide and Compact unit swap, light colours, no baked or digit tint, 3 Hz at 60 and
20 fps, punch steps and no `UIScale`, steady-drive writes) and `...Dev.Fixtures.Gauge_test.lua` (the new states and
the gear run).
