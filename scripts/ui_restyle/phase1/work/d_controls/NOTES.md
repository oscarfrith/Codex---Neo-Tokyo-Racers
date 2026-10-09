# Agent D notes: Kit.Controls, Kit.Collections, their fixtures and tests

Status: **generated, desk-checked only.** No Luau was run (none available offline); nothing was installed or opened in Studio. A crude block/bracket balance script passes on all six files; LF line ends; largest source 46,831 characters.

## Files

| File | Instance |
|---|---|
| `after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Controls.lua` | `Button`, `ButtonRow`, `Tabs` |
| `after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Collections.lua` | `Tile`, `Rail`, `ListRow`, `Chip`, `TierBadge` |
| `after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Controls.lua` | 4 gallery items, 29 states |
| `after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Collections.lua` | 5 gallery items, 56 states |
| `tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.Controls_test.lua` | state resolution, constructor contract, row and tab behaviour |
| `tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.Collections_test.lua` | pool keying, state resolution, constructor contract, rail pool |

`Switch`, `Stepper`, `Dropdown`, `Slider` and a public `Pool` are not built (CONTRACT 6 exclusions; API.md 7.3 and 7.4 do not list them).

Pure helpers exported for the tests (underscore names, as `Switch._resolve`): `Controls._resolveButton`, `_caption`, `_rowPatch`, `_resolveTab`, `_stepTab`; `Collections._resolveTile`, `_corner`, `_planPool`, `_resolveChip`, `_badgeSize`.

## API questions, and the reading I implemented

1. **Rail and ListRow width (the main one).** Neither has a width prop, and slot anchors are zero-size, so "fill the parent" gives a zero-width rail in `BottomRail`. Reading: if the parent has a width of its own (`Size.X` not zero) the root is `Scale 1` wide; otherwise the Rail is `ctx.Size.X - parent.Position.X.Offset` wide (slot to the right edge of the safe area) and a ListRow is `ListWidth`. This is exact for `Scene` and for the gallery stage; on a `Menu` or `Hud` frame narrower than the safe area (wider than 2:1 or 21:9) the rail overruns the block. A `Width` prop or a sized `BottomRail` slot would settle it.
2. **Button budget 4 against "slate strip with hairlines".** Root, `Fill`, `Label`, `Icon` is already 4 (5 with the Main `Gradient`). I kept the budget: **the Default button has no top or bottom hairline**, and focused Main, Buy and Danger buttons have no 6 px role-colour base line (r20b calls that line an addition). Hairlines need budget 6 (two frames) or 5 (one `UIGradient` on `Fill`). Say which and it is a small change.
3. **Text inside budgeted components is a raw `TextLabel`, not `Text.Label`.** `Text.Label` costs two instances, which the Button, Tile, Chip and TierBadge budgets cannot carry. Faces and sizes still come only from `Text.Font` and `Text.SizeFor`; baseline shift is `-round(TypeBaselineShift x TextSize)` px and italic padding `Px(TypeItalicPad x cap)`, which may differ from agent C's `Text.Label` by a pixel. Only `Rail.Heading` uses `Text.Label` (`SectionHead` is a holder role). Every raw label carries a `UITextSizeConstraint` named `SizeLock` (API.md excludes it from budgets; the programme contract 4 says it is counted, and a 20-tile rail then holds about 100 of them).
4. **Lengths with no token.** Rule 11.6 forbids pixel literals, and `Tokens.Space` has no Compact values beyond six. All lengths are tokens or a token times a named ratio at the top of each file. Compact uses `TouchGap / Pad` (8 / 22, which is also about 390 / 1080) as the general factor, the listed Compact tokens where they exist, and `max(box, TextSize)` for chip and badge heights. Derived values worth a token later: tile inner margin 18 (`Pad x 0.8`), picture box (0.22 and 0.40 of the tile height), selected growth 16 (`Gap + TileBaseLine`; 6 on Compact), Compact tile height 60 (`TouchMin + CompactMargin`), tab height 46 (`BadgeLarge`), icon box 1.5 x cap, rail-of-seven width 236 (`TileWidth x 0.75`), chip height 38 (`BadgeMedium`; the previews draw 36 and 42).
5. **Tabs budget "3 per tab plus 1".** Each tab is a `TextButton` showing its own text, plus `Underline` and `Icon`; plus the root. So hover and focus recolour the tab button itself (its size never changes); there is no inner `Fill`, and no baseline shift or italic padding on tab text. The focus fill is tight to the text.
6. **Clearing an optional prop.** A patch cannot hold `nil`, so `""` clears a string prop (`Icon`, `Sub`, `Price`, `MarkKey`, ...) and `false` clears `MinWidth`, `Rating` and `OnActivated`.
7. **`Compact7`** is read as "rail-of-seven tile": `TileNameSmall`, and 236 wide when no `CellWidth` is given. On the Compact class every tile is the small composition regardless (picture, one-line name, tier badge and corner chip; no sub-line or left chip; it sizes to its name unless `CellWidth` is set).
8. **Tile corner.** One top-right chip: Owned or Fitted shows `ChipRight` (default text `OWNED` / `FITTED`) and hides `Price`; otherwise `Price`; otherwise `ChipRight` as a neutral chip. The pink `EMPTY` chip of r20a has no prop and is drawn neutral.
9. **Unaffordable and Locked tiles are `Active = false`** as briefed, so a click cannot select them in a Rail; `Rail.Select(key)` still can. If the dealership must preview a car the player cannot afford, that tile must not be `Unaffordable` (or the rule changes).
10. **Rail selection.** `Select(key)` does not call `OnSelected`; a click or a controller focus move does, once per change. `Select` also scrolls the tile into view. `State` on an item is used only as the first selection. A Rail tile's own `OnActivated` still fires after the selection.
11. **Rail focus group.** `Input.FocusGroup` has no remove, and pooled tiles change order, so the Rail registers none and relies on the engine's spatial navigation. ButtonRow and Tabs register one group each and rebuild it when the id list changes.
12. **`ButtonRow` and `Rail` place themselves** for their slots: Right is anchor (1,1) at the parent's bottom-right, Centre is anchor (0,1) at `(0.5, -floor(width / 2))`, Rail is anchor (0,1). The row also accepts `Size`, and per button `Locked`, `MinWidth`, `MarkKey`. Buttons are named `Button<Id>`, tabs `Tab<Id>` (never `Car`, `Race`, `Garage`).
13. **Glow.** `Surface.Glow` is called with `Name = "Glow"`, parent `Fill`, at construction (Main button, Tile, ListRow), and hidden through `Set({Visible})`. A Rail has one glow on a `Selection` frame that moves to the selected cell, so its tiles have none. The tests exclude anything named `Glow` from budgets.
14. **Icon opacity.** `Surface.Icon` has no opacity prop; disabled and locked looks write `ImageTransparency` on its instance when it is an `ImageLabel`. The Tile picture is its own `ImageLabel` (`Visual`) that shows either `Image` or a glyph cut from `Tokens.Icons` and `Tokens.Asset("IconSheet")`, to stay inside 12.
15. **Outside `Active` writes.** Classic onboarding sets `Active` on some buttons. A Button whose `Active` is switched off by another script shows the locked look and does not fight the write (programme contract 2.3). Tile, ListRow and Tabs do not do this.
16. **`ctx.Changed`** is connected only if present, in case `Metrics.Fixed` leaves it nil. `ctx.Touch(1)` is used as "the touch minimum, or 1" where the drawn size is not a single design value (tabs, rows).

## Known limits

- **Lazy parts.** A tile or row creates `Sub`, chips, tier cells and the lock on first need and then only hides them. A selection change never creates anything; `SetItems` with the same keys never does; a data change that gives a pooled tile a kind of part it has never shown creates that part once.
- Hover uses `MouseEnter` / `MouseLeave` and is ignored while `ctx.Input` is `Touch`.
- Button and tab widths come from `TextBounds`; they settle through the `TextBounds` and `Text.ReadyChanged` signals. If `TextBounds` is zero on a detached label, a detached button is its padding or minimum width until it is shown.
- `Mark` on a tab may set the tab button's text; the next render writes the tab's own upper-cased text back.
- The Rail scroller is wider and taller than the cells by the glow radius (46 px at 1080), so tiles scrolled left show in that strip of the left margin.
- No mouse-wheel handling on the horizontal scroller.

## Integrator checks in Studio

1. E3 run of both test files; the "Set with an unchanged patch" and budget cases depend on agents A to C (`Metrics.Fixed`, `Text.SizeFor`, `Surface.Icon`, `Surface.Glow`, `Input.Focusable`).
2. Whether `TextBounds` is filled on detached labels (widths in the pure tests are not asserted for that reason).
3. Gallery at R720, R1080, R1440, C844, C568: text fit of the longest states (`MainLongest`, `RaceEntryLongest`, `LongestStrings`, `PartsSeven` two-line names), 48 dp hit boxes on C presets, whole-pixel geometry.
4. Baseline of raw labels against `Text.Label` text on the same line (item 3), and the tile and button look without hairlines (item 2).
5. Rail in `BottomRail`: width, right-edge clipping, glow strip, selected tile growth not clipped, gamepad left and right through the tiles, `ScrollTo`.
6. Lint: the fixtures pass design numbers in props (`MinWidth = 250`, `CellWidth = 236`); the kit files contain no `Color3`, `Font` or pixel literal.
