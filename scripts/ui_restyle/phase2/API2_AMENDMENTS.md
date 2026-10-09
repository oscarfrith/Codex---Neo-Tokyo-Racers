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
