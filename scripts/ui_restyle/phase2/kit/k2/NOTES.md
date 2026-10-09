# K2 notes: Text, Surface, Controls, Collections, Input and their fixtures

Status: **generated, desk-checked only.** There is no offline Luau here, so nothing below has been compiled or run. A Python pass checked block and bracket balance, that every `Space.*`, `Opacity.*`, `Type.*` and colour role used exists in Phase 1 `Tokens` or in the API2 2.2 additions, and that every icon and map glyph name is on the API2 1.2 lists. The first Edit-harness run is the real compile.

Every file started as a byte copy of `phase1/after/` or `phase1/tests/` and was then edited. All sources are LF, ASCII, under 150,000 characters (largest: `Kit.Controls` 77,787).

## Files

```text
after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Text.lua              tests/..Kit.Text_test.lua
after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Surface.lua           tests/..Kit.Surface_test.lua
after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Controls.lua          tests/..Kit.Controls_test.lua
after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Collections.lua       tests/..Kit.Collections_test.lua
after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Input.lua             tests/..Kit.Input_test.lua
after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Text.lua
after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Surface.lua
after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Controls.lua
after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Collections.lua
```

The tests need K1's `Tokens`, `Sprites`, `Metrics` and `Contracts` in the same `after/` folder the harness serves. They do not run against the Phase 1 `Tokens` (no `Sprites`, no `ButtonPlate`, and so on).

## What K2 calls on K1 (exactly as API2 declares)

- `Sprites.Icons.{Asset, Cell, Glyphs}`, `Sprites.MapIcons.{Asset, Cell, PinTipY, Pins, Glyphs}`, `Sprites.Rings.TitleSlash.Size` (`{160, 192}`).
- `Tokens.Asset(key)` for `IconSheet`, `MapIconSheet`, `GlowSoft`, `GlowTight`, `GlowLine`, `TitleSlash`, `KeyCap`; `Tokens.Slices`; `Tokens.Icons.{Cell, Glyphs}` (Collections only, because it may not require Sprites).
- New `Space` keys: `TextShadowOffset`, `TitleMarkHeight`, `KeyCapSize`, `HudButtonHeight`, `CompactHudButton`, `ActionTileWidth`, `ActionTileHeight`, `CompactActionTile`, `CompactStatusHeight`, `SwitchGap`, `StepperWidth`, `SliderHeight`, `DropdownRowHeight`, `HeaderTabsGap`, `CompactKeepOutGap`, `CompactTileHeight`. New `Opacity` keys: `TextShadow`, `ButtonPlate`, `HairButtonTop`, `HairButtonBottom`.
- `ctx.TopBarHeight`, `ctx.TopBarKeepOut`, `ctx.Origin`, `ctx.Size`, `ctx.Px`, `ctx.Hair`, `ctx.Touch`. `ctx.Dp` and `ctx.ChatKeepOut` are not used by K2.
- Slot frames are recognised by their name starting with `Slot` and by their `AnchorPoint` (API1 8).

## Why the Phase 1 captures showed no plate, hairline, icon or glow

- **Icons and glows**: every asset id was `""`. Nothing in the code was wrong; they appear with the ids.
- **Plates**: the Default button and the tile were already Slate at 0.86, but had no hairlines, and the gallery stage is near black, so a Slate plate cannot be seen on it. Buttons now carry `HairTop` and `HairBottom`, tiles carry `HairBottom`, and the Controls and Collections fixtures put a `Surface.Scrim` (Menu) behind anything mounted on the stage centre frame.
- **Glow layering was wrong and would have shown as soon as the ids arrived.** Phase 1 parented the 9-slice *inside* the plate it lights (`Surface.Glow(fill, ...)`). Under `ZIndexBehavior.Sibling` a child always draws over its parent, and the glow art has a solid centre, so a Pink glow would have been drawn over the white selected tile and over the main button's gradient. The glow now lives in a Frame named `Glow` that is a **sibling under** the plate (`ZIndex` 0, same box as `Fill`), on Button (Main), Tile and ListRow. `Surface.Glow` itself is unchanged. Rail and List keep one shared glow in `Scroller.Selection`, as Phase 1's Rail did.

## API2 ambiguities and the reading taken

1. **`Text.RawLabel` "baseline shift"** (2.6). A bare TextLabel has no holder to shift inside. Reading: the label is built at `Position (0, -shift)`, `Size (0, TextSize)`, `AutomaticSize = X`, named `Label`, white, left aligned. A caller that sets its own `Position` must subtract the shift itself (`round(Type.BaselineShift x TextSize)`); a caller that sets a fixed width should clear `AutomaticSize`. A holder role stops at 100 (no `UIScale`).
2. **`Text` "Value is Fixed"** (2.6). Phase 1 already treated `Value` as a display role, so the behaviour is unchanged; it is now an explicit table (`Label` and `Body` grow, everything else is Fixed).
3. **`Surface.Scrim` Garage "two gradients, budget 3"** (2.7). One Frame can carry one `UIGradient`, so two gradients need two frames: root + gradient + `Bottom` + gradient = **4**. Built as 4; the test says 4. `Hud` needs only one gradient (dark, clear, clear, dark) = 2.
4. **`Surface.KeyCap` "letter (role Value)"** (2.7) against 2.1, which does not let Surface require `Kit.Text`. Reading: the letter's face and size are computed in Surface from `Tokens.Type` and `Tokens.Cap` (ExtraBold Italic, the `Value` cap). It does not follow `Text`'s fallback family if Barlow fails to load. Lint may flag the `Font.new(Type.Family, ...)` call; the family string is a token.
5. **`Surface.TitleMark` size** (2.7). `Height` is the ImageLabel's height; the width is `Height x 160 / 192`. `Space.TitleMarkWidth` and `Sprites.Rings.TitleSlash.Design` are not used. The empty-asset block is the same box.
6. **`ButtonRow` `Place = "Slot"` in a parent that is not a slot** (2.8). Reading: in a frame named `Slot...` the row copies the slot's anchor; in any other parent `Align` decides exactly as in Phase 1 (Right = bottom-right corner, Centre = bottom centre), so `Overlay` and Phase 1 callers keep working. `Place = "None"` writes neither `AnchorPoint` nor `Position`. A 0.5 anchor is written as a whole-pixel offset, not a scale anchor.
7. **"Every row is ButtonHeight (64) high"** (2.8). Reading: on Regular the row frame is at least `Px(64)`; shorter (Hud, 56) buttons sit on its bottom edge. On Compact the row is the tallest hit box.
8. **`Button` Danger hairlines and focus** (2.8). Only the Slate plates (`Default`, `Icon`) show hairlines. From preview r20b: a filled variant keeps a base line in its role colour (Pink, Yellow, Danger) while its fill is white on hover, press, focus or `Selected`. It reuses `HairBottom`, so it costs no instance. API2 says only "hide the hairlines"; say if the base line should go.
9. **`Tabs` `Count` and `Segment`** (2.8). `Count` is appended to the tab text ("PARTS 7/7") in the same label, to stay at 3 instances per tab. `Segment` uses the `Tab` role, `SwitchGap`, a lower row (`BadgeMedium`) and never draws icons. A tier button is text only (no icon), its cell at least as wide as it is high.
10. **`Tile.Selectable` "default true ... unless Selectable = true is passed"** (2.9). Reading: `Locked` is active only when `Selectable == true` is passed explicitly; `Selectable = false` switches any tile off; otherwise a tile is active (including `Unaffordable`).
11. **`Tile` child name `HairBottom` and budget 13** (2.9). Phase 1's `BaseLine` frame is renamed `HairBottom`: it is the hairline, and when selected the thick line, with a `UIGradient` child (Pink to Violet, made disabled with the tile so selecting creates nothing). `ChipRightKind = "Tick"` is an `Icon` named `Tick` (Ink tick on a Cyan cell) and wins over price and status. Every part at once is exactly 13.
12. **`Rail.Rows`** (2.9: "2 gives the Compact car-panel grid, vertical scroll"; preview c03 is two cells *across*). Reading: `Rows` is the number of lanes across the scroll axis. 1 = the horizontal rail. More = a grid that many cells across with equal cell widths, scrolling vertically, hanging from the top of its parent and filling its height when the parent has one (else 3 cell rows).
13. **`Rail.HeadingRight`** (2.9). A zero-width Frame at the right of the heading text with a horizontal `UIListLayout`, bottom aligned on the foot of the heading capitals, so a `Tabs` mounted in it needs no position.
14. **`ListRow.Columns`** (2.9). With three or more columns the first is a fixed narrow one (a position number); the rest share the width equally; the last is right aligned. Column 1 reuses `Title` and the last reuses `Right`. `List.Header` uses the same boxes (`Collections._columnBox`).
15. **`TierBadge` Compact height "CompactStatusHeight - 4"** (2.9). The 4 is written as two hairlines (`Space.Hairline` twice), to keep the literal out of the module. All three sizes are that height on Compact. `Dim` is `Opacity.Locked` (was `TabLocked`), also on the badge inside a tile or row.
16. **`Collections.Pool.Count`** (2.9). Returns two numbers: how many were made, then how many are out.
17. **`Input.BindAction` handler** (2.10). It is the raw `ContextActionService` callback `(actionName, inputState, inputObject)` and its return value is passed through, so a Classic handler can be bound unchanged. Default priority is the same as the other bindings (High).
18. **`Header`** (3.6). `Count` is a muted `Status` label right of the title; `Sub` is a `Tab`-role line under it. `header.Height()` is real px from the slot's top to the bottom of the header. The mark and title keep the Regular proportion on Compact. Keep-out rule 2 is the pure `Controls._headerPlace`; it treats the slot's x as the distance from the left of the safe area, so in a `Menu` root narrower than the safe area the title only moves further from the Roblox buttons. `header.Tabs` is nil when no `Tabs` prop was given.
19. **`Switch` cell order, `IconButton` `Small`, `Swatch` size, `Stepper` height** (3.6) are not stated. Readings: the On cell is the left one (r20b ROTATE | NORTH UP); `Small` is `KeyCapSize` (Compact `CompactStatusHeight`); a swatch is `Space.IconButton` square and at least the touch size; a stepper is `ButtonHeight` high and `StepperWidth` wide. Switch and Dropdown heights are `HudButtonHeight` and `DropdownRowHeight`.
20. **`Dropdown`** (3.6). Budget 5 closed leaves no room for hairlines, so the closed plate has none. The list is built on the first `Open` in the top GuiObject above the control (the layer's Root), kept hidden between openings, rebuilt after an `Options` change, and destroyed with the control. Option text is centred. Added methods: `Open()`, `Close()`, `IsOpen()`.
21. **`Slider`** (3.6). `OnChanged` is coalesced with `task.defer`, so the input events of one frame give one call. Key steps call `OnChanged` then `OnReleased`. Left and right are bound (through `Input.BindAction`, name `Pulse_Slider_<n>`) only while the slider holds focus. With `Gradient` the filled part is hidden and the track shows the ramp.

## Additions beyond API2 (all additive)

- Pure test seams: `Controls._buttonHeight`, `_rowAnchor`, `_tabCaption`, `_headerPlace`, `_iconButtonSize`, `_stepValue`, `_slideValue`; `Collections._columnBox`. `_resolveButton` gains `Hair`, `BaseLine` and the `Selected` flag; `_resolveTab` gains `TierInk`, `TierFill` and the `Tier` flag; `_resolveTile` reads `flags.Selectable`; `_corner` takes `chipRightKind`.
- `ButtonRow` button entries accept `IconOnly` and `Selected`.
- `Controls` holds a private `miniScope` for one slider drag, one slider focus or one dropdown opening (as `Overlay` already does for a modal); each is destroyed by its component.

## Phase 1 test expectations changed (each because API2 changes it)

| Test file | Was | Now | API2 |
|---|---|---|---|
| Text | budget count included the holder `UIScale` | excluded | 2.6 |
| Surface | Icon case read `Tokens.Icons` | reads `Sprites.Icons` | 2.7 |
| Surface | `Scrim Garage` budget 2 | 4 (API2 says 3; ambiguity 3) | 2.7 |
| Controls | Default fill opacity `Opacity.Panel` | `Opacity.ButtonPlate` | 2.8 |
| Controls | Button budgets 4, Main 5; ButtonRow 1+4+4+5 | 6, Main 7; 1+6+6+7 | 2.8 |
| Collections | `_resolveTile` Unaffordable `Active == false` | `true` | 2.9 |
| Collections | Tile case: Unaffordable sets `Active` false | stays active; Locked false; `Selectable` cases added | 2.9 |
| Collections | Tile budget 12, ListRow budget 10 | 13, 12 | 2.9 |

Nothing else in the Phase 1 cases was altered. The Controls test's `contract` helper now skips the budget case when no limit is given (Header has no stated budget). New cases were added for every API2 item; the Surface test also builds every constructor with all asset ids emptied (skipped if `Tokens.Assets` is frozen).

## Lint points to expect

- `Color3` values in `Dev.Fixtures.Controls` (the Slider ramp and the Swatch colours) and in the tests: these are the two named colour exceptions and need example colours.
- `Surface.KeyCap` builds a `Font` (ambiguity 4).
- `UIListLayout` inside `Rail.HeadingRight`; `UIGradient` on tile and row base lines, the Main button, the Slider track and the scrims.
- Small non-pixel counts as literals: `DROPDOWN_ROWS = 6`, `GRID_ROWS = 3`, `LIST_ROWS = 5`, slider steps 1/100 and 1/20.

## What the integrator must check in Studio

1. **Compile and the pure tests** with K1's modules in the same folder. Anything that fails to compile is most likely a token or Sprites field K1 named differently from API2.
2. **Glow**: Main button, selected Tile, selected ListRow, and the selected cell of a Rail and a List. The glow must be behind the plate, the white fill must stay white, and it must not be clipped (Rail and List scrollers are a glow radius larger than their cells).
3. **Hairlines and plates** on the Default button, IconButton, Stepper and Tile over a real scene, and the role base line of Main, Buy and Danger on hover and controller focus (ambiguity 8).
4. **Icons** before labels in Button and Tabs, the `Tick` corner, the lock, and the Dropdown chevron: the glyphs have padding inside their cells, so check their optical size and centring.
5. **`TitleMark`** next to a `ScreenTitle`: the capitals should stand on the bottom of the mark. The image includes its own glow margin, so the slash may sit low or wide; `Header` places the title one `Gap` right of the image box.
6. **`Header` on a phone preset and on the live screen**: the title beside the Roblox buttons, tabs under the bar, nothing inside `TopBarKeepOut`; then a `Menu` frame on a wide phone, where the title sits further right than strictly needed.
7. **`Rail` in the sized `BottomRail` slot** (fills it, clips at the root's right edge) and the grid (`Rows = 2`) in `SidePanel` on C844: equal cells, vertical scroll, the grown selected tile not clipped.
8. **`Rail.HeadingRight`** with a Segment `Tabs`: baseline against the heading (r03).
9. **`Dropdown`**: list position under the button (and above it near the bottom edge), outside press, Escape and ButtonB close, focus trapped; in the gallery, under the stage `UIScale`.
10. **`Slider`**: mouse and touch drag, that it blocks camera orbit, left and right on keyboard and D-pad while focused, the bumper for the coarse step, and that focus can still leave it up and down.
11. **`Tabs`**: bumpers on the main tabs and triggers on a Segment at the same time; tier buttons with a locked tier.
12. **Gamepad focus** across a `ButtonRow`, a `Rail` and a `List` (each registers one focus group and removes pooled items it hides).
13. **Largest Text Size**: `Label` and `Body` grow; chips, badges, buttons and `Value` do not.
14. **`KeyCap`**: slice scale of the cap at 40 px and the width of SPACE and ESC once their bounds arrive.
15. **`Text.StyleForeign`** sizes for `Metrics.Screen()` at the moment of the call; the RaceTransition seam must call it again if the screen class can change while its label lives.
16. The gallery's own slot table (Phase 1 `Dev.Gallery`) does not know the new slots (`RailButtons`, `HudButtons`, `SidePanel`); the fixtures that use them (`Controls.ButtonRowOnRail`, `Controls.ButtonRowHud`, `Collections.RailGrid`) place themselves, but they need K1's `Layers.Stage` to serve those slot names.
