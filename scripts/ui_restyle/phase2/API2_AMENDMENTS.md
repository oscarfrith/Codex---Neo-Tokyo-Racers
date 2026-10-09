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
