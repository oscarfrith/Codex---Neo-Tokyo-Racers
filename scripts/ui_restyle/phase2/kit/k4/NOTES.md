# K4 notes: `Kit.BigNumber`, `Kit.Data`, `Kit.Touch`

Status: **generated, desk-checked only.** No Luau ran (none offline); nothing is installed. Written against `API2.md` as read on 2026-10-09 and against the Phase 1 sources; K1's `Sprites`, `Tokens` v2 and `Metrics` v2 and K2's `Text.RawLabel` were not visible while writing.

## Files

```text
after/ReplicatedStorage.Modules.Game.UIPulse.Kit.BigNumber.lua            13 k
after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Data.lua                 57 k
after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Touch.lua                10 k
after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.BigNumber.lua   1 item, 22 states
after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Data.lua        6 items
after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Touch.lua       5 items
tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.BigNumber_test.lua
tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.Data_test.lua
tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.Touch_test.lua
```

All LF, all under 150,000 characters. Block, bracket and brace balance checked by script; everything else by reading.

## What each module needs from the other kit agents

| Needs | From | Used for |
|---|---|---|
| `Sprites.Digits[128|256]` `{Asset, Cell, Cap, Pitch, PitchTight, Glyphs[token] = {x, y, advance, originX}}`, `Sprites.Punct[128|256]` `{Asset, Glyphs[token] = {x, y, w, h, advance, originX}}` | K1 | BigNumber |
| `Sprites.Touch[control]` `{Idle, Pressed, PlateDp, FrameDp, HitDp}` | K1 | Touch |
| `Tokens.NumberCap`, the new `Space` keys (`StatusHeight`, `StatusPad`, `CompactStatusHeight`, `CompactStatPanelWidth`, `StatRowHeight`, `StatPanelHeight`, `SegmentWidth`, `SegmentGap`, `SegmentHeight`, `FactRowHeight`), `Opacity.TouchDisabled`, `Opacity.RankTrackImage`, `Scale.RegularDp`, the asset keys | K1 | all three |
| `ctx.Dp` | K1 | Touch only |
| `Text.RawLabel(parent, role, ctx)` returning a TextLabel (with a child named `SizeLock` when the role is Fixed) | K2 | Data, and BigNumber's flat state |
| `Surface.Icon`, `Surface.Panel`, `Collections.TierBadge`, `Input.Mark`, `Input.Focusable` with their Phase 1 signatures | K2 | Data |

Data sets the position, size, colour and alignment of every `RawLabel` itself and applies the baseline shift through `Position`, so it does not depend on what `RawLabel` does beyond face and size. `Surface.Divider`, `Controls` and `BigNumber` are allowed to Data by API2 2.1 but are not required: dividers are single Frames built here.

## API2 questions and the reading used

**A1. BigNumber requires `Kit.Text`.** API2 2.1 allows BigNumber only Tokens, Sprites and Metrics; API2 3.1 says the empty-asset state is "one `Text.RawLabel`". Both cannot hold. Reading: 3.1 is the more specific line, `Text` requires nothing that requires BigNumber, so `BigNumber` requires `Text` (header line says so). **The lint require whitelist needs that one row**, or 3.1's flat state has to change.

**A2. Fixed digits are centred in their pitch slot.** 3.1 says "cell x = pen - originX" and also "as `digits.json` `layout` says" (`x = n * pitch - (cell_w - pitch) / 2`). They agree only for the widest digit. Reading: Fixed digits use the `digits.json` rule (every digit centred in a slot, so `1` does not hug the left of its slot); punctuation, and every glyph when `Fixed = false`, uses `pen - originX` and its own advance.

**A3. `BigNumber.Layout` has two additions.** A fourth argument `proportional: boolean?` (the layout of `Fixed = false`; the three-argument call is the Fixed layout), and a field `Unknown: {string}?` in the result (characters with no sprite, skipped), which is how "errors at build, one warning at run time" is implemented.

**A4. `SetText` also writes `Image` and `Position` when they differ.** 3.1 lists `ImageRectOffset`, `ImageRectSize`, `Size` and `Visible`. A cell that changes between a digit and punctuation must change sheet (`Image`), and a cell whose x moves (Centre or Right alignment with a different width, or punctuation before it) must move. Both are compare-then-write, so a counter such as `142` to `143` writes one `ImageRectOffset` and nothing else. A text with more tokens than `MaxCells` is cut with one warning.

**A5. `CashChip.Bind` wraps `SetTarget`.** 3.5 writes `BindReplicatedCash(player, presenter.SetTarget)`. The Classic presenter's methods take `self` (`presenter:SetTarget(value, forceSnap)`), and the binding calls back with `(number, cashValue)`, so the bare method would receive the number as `self` and the IntValue as the value. The chip passes `function(value) presenter:SetTarget(value) end`. Nothing else differs: the presenter is created with no options, so Classic's `CashCount*` config applies.

**A6. The short form is `$3.6M`, not `$3.61M`.** 3.4 gives `$3.61M` as the example; `FormatCompactMoney` (reused unchanged, 3.5) prints one decimal. The formatter wins.

**A7. Boost needs 9 instances, not 6.** 3.8 asks for a track plus a fill "revealed clockwise", which with the spike 06 method is two clipping windows, each with an image and a gradient: root, `Art`, `ChargeTrack`, `ChargeRight` (+`Fill`, +`Mask`), `ChargeLeft` (+`Fill`, +`Mask`). The other four controls are 2. The test asserts 9. If 6 is binding the reveal method has to change (not attempted: a one-image reveal needs gradient offset behaviour nobody has measured).

**A8. `Touch.Button` extra props.** `Class: "TextButton" | "ImageButton"` (default `TextButton`: every Classic control in `MobileDriveControlsClient` is a TextButton) because 3.8 says the fork states the class but lists no prop for it; and `Pressed`, `Disabled`, `Charge` as props equal to the three setters (the gallery needs canned looks). `Control` and `Class` cannot change after build.

**A9. Plate place in the hit box.** `Sprites.Touch` (as specified) has no anchor field, so `touch.json` `anchor` is copied into `Kit.Touch`: Accelerate bottom right, Brake bottom centre, the rest centred. Hit box = `max(ctx.Dp(HitDp), ctx.Dp(TouchMin))`. The mirror rectangle uses the literal 512 (`touch.json` `size`); `Sprites.Touch` carries no image size. Lint may want that constant whitelisted or added to `Sprites`.

**A10. `SetDisabled` also dims the boost ring** (track and fill), not only `Art`. It never touches `Active`.

**A11. The rank "ring" in `StatusCluster` is the `keycap_blank` glyph.** No ring image is open to `Kit.Data` (the asset table gives `RankArc` and `MinimapRing` to Minimap and Touch only) and `UICorner`/`UIStroke` are forbidden. **Oscar or the integrator should look at it**; the alternatives are a new icon glyph or allowing `RankArc` in Data.

**A12. `StatusCluster` additions.** `Label: string?` (shown in `Vehicle` mode when there is no `Tier`, with the `passenger` icon: the "ON FOOT" strip of component sheet 3) and `FreeRoam: boolean?` (passed to the chip, A13). `SetVehicle(tier, rating)`, `SetSpaces(text)`, `SetRank(rank)` accept nil, which `Set` cannot express. On Compact the strip has no rank ring and the chip stands beside the strip **[seen c11]**. `ShowPlus` shows the spaces plus (Garage only) and the cash plus.

**A13. `CashChip` additions.** `FreeRoam: boolean?`: a chip that is not short prints through `Data.FreeRoamMoney` instead of `Data.Money(amount, false)`. 3.5 names `FreeRoamMoney` for "the HUD chip on Regular" but gives the chip no way to ask for it; the FreeRoam family should pass `FreeRoam = true` (on the cluster or the chip). `OnResized: (() -> ())?` is used by `StatusCluster` so the strip follows the chip without waiting for a deferred signal. `SetAmount(amount)` prints an amount with no count. The constructor formats nothing, so it never yields; the label is empty until `Bind` or `SetAmount`.

**A14. Width during a count.** At the first mid-count render the label is set once to the final text to read its width, then to the counted text; the box then never shrinks until `displayed == authoritative`. That is one extra `Text` write per count, the only one that is not "the text changed".

**A15. `SegmentedBar`.** `Preview = false` clears a preview (a `Set` patch cannot carry nil). With `Preview` below `Value` the white fill stops at the preview and the lost segments are drawn in the preview colour **[seen r03 BOOST]**; `PreviewColour` defaults to Cyan for a gain and Pink for a loss. A preview that differs from the value always shows at least one segment. With no strip image the three layers are plain bars (flat state).

**A16. `StatPanel`.** Row: the bar shows `Value / Max` (Max default 100) with `Preview / Max` previewed; the value cell prints `Text`, else the rounded `Preview or Value`; the delta chip shows `Preview - Value` **[seen r03: 66 with +3]**. The chip column exists only while some row has a delta, and the bar takes the whole segments that fit (16 at most, 8 on Compact), which is why r03 shows shorter bars than r01. `Price` is drawn only on Compact (3.4 lists it in the collapsed form). `Sub` lines are printed as given (not upper-cased) and are hidden on Compact. Height: `Height`, else `StatPanelHeight` on Regular, else (Compact) fitted to the content. `SetHeader({Title, Tier, Rating, Sub, Price})` replaces the header; a missing `Title` keeps the old one, the other four are cleared when left out. Rows are pooled by position, so unchanged ids (or any list of the same length) create and destroy nothing.

**A17. `FactList`.** Extra prop `Width` (design). Without it the list fills a parent that has a width, else `ListWidth` (Compact `CompactStatPanelWidth`). Row icons are created the first time a row slot needs one. Labels and values are upper-cased.

**A18. Lengths with no Compact token** (`StatRowHeight`, `Segment*`, `FactRowHeight`, `StatusPad`, `Pad`, `Gap`) use the Phase 1 `Collections` conversion (x 8 / 22). `CompactStatusHeight` and `CompactStatPanelWidth` are used where they exist.

**A19. Unused allowance.** `Kit.Touch` does not require `Surface`; `Kit.Data` does not require `Controls` or `BigNumber`.

## Tests

- Format of API1 13; nothing yields; nothing is parented; `Data._foundation` is replaced by a fake and put back.
- The fixtures for `CashChip` and `StatusCluster` call `SetAmount`, which calls the real `foundation()` (a require of the Classic module). That is right in the Play gallery; **a pure test that mounts those fixture states must replace `Data._foundation` first**.
- "Only changed cells are written" is checked by comparing every cell's properties before and after (a `Changed` counter would not fire inside a non-yielding test under deferred signals).
- The Touch test installs a spec-equivalent `ctx.Dp` only if K1's `Metrics.Fixed` lacks one, after recording that as a failed case.
- Several layout assertions read `TextBounds` indirectly. They are written to hold whether or not `TextBounds` is live on a detached label.

## For the integrator in Studio

1. Run the three test files with K1 and K2 sources in the same `after/` folder; expect the A1 and A7 lint questions.
2. Gallery, `BigNumber.New`: digit spacing and baseline at R720, R1080, R1440, C844, C568; `Timer` against `TimerTight`; the italic overlap between cells; the 128 to 256 sheet switch (cap 92 px).
3. Gallery, `Data.*`: the `keycap_blank` rank ring (A11); the cash gradient warmth (`CASH_WARM`); the plus buttons (hover, focus, 48 dp hit box on C844); value cell and chip sizes in `StatPanel` against r01 and r03; the Compact panel against c11; segment tiling (a row must start and end on half a gap).
4. Play: `chip.Bind(player)` counts up on a cash gain with no width jitter, snaps down on a spend, and shows `leaderstats.Cash` exactly at rest; the first `Bind` does not stall a view build (it requires the Classic module once).
5. Gallery, `Touch.*`: the charge ring seam at 12 and 6 o'clock, the ring against the boost plate edge, mirrored turn and drift, the disabled look against c20.
6. Parity (integrator's check): `Kit.Touch` contains no `InputBegan`, `InputEnded`, `SetAttribute` or `MobileDriveInputState`.
