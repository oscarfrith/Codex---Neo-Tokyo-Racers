# K3 notes: `Kit.Overlay`, `Kit.Gauge`, `Kit.Minimap` and their fixtures

Status: **generated, desk-checked only.** No Luau ran (there is no offline Luau); the reveal maths and every numeric test value were re-computed in Python, and a block and bracket balance check passes on all twelve files. Nothing was installed. Studio, MCP and git were not touched.

## Files

```text
after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Overlay.lua            source op; before = phase1/after (57,855 chars)
after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Gauge.lua              new
after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Minimap.lua            new
after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Overlay.lua   source op; before = phase1/after
after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Gauge.lua     new
after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Minimap.lua   new
tests/<same names>_test.lua                                             six files, API1 section 13 format
```

`Kit.Overlay_test.lua` is the Phase 1 file byte for byte up to its last case, then the Phase 2 cases. `Kit.Overlay` was edited from the installed Phase 1 file: Toast, Confirm and Modal keep every Phase 1 signature.

## What the three modules call in other agents' modules

None of K1, K2 or K4's code was visible. These are the exact calls; a mismatch is the first thing to look for if a test fails.

| Module | Calls |
|---|---|
| `Tokens` (K1) | `Space`: `GaugeSize GaugeTouchSize CompactGauge MinimapSize CompactMinimap MinimapLabelBand PromptWidth PromptHeight CompactPromptWidth KeyCapSize TitleMarkWidth TitleMarkHeight` plus Phase 1 keys. `Opacity.Vignette`, `Opacity.RankTrackImage`. `Cap.Regular/Compact`. `Asset(key)` for `GaugeTrack GaugeTicks GaugeGlow GaugeArc BoostArc GlowSoft MinimapRing MinimapVignette MapPlayerArrow RankArc` |
| `Sprites` (K1) | `Rings.Size`, `Rings.Gauge.{StartDeg, SweepDeg, ArcRadius, TipFraction}`, `Rings.Minimap.FrameScale`, `Rings.Rank.{FrameScale, StartDeg, SweepRegular, CompactFromDeg, CompactToDeg}` |
| `Metrics` (K1) | `Of`, `ctx.Px`, `ctx.Touch(design)`, `ctx.Scale`, `ctx.Class`, `ctx.Input`, `ctx.Size`, `ctx.TopBarHeight`, `ctx.Origin`, `ctx.Changed`. `ctx.Dp` is not used |
| `Presence` (K1) | `Presence.Open(surface, kind)` returning a release function |
| `Text` (K2) | `RawLabel(parent, role, ctx)`: assumed to return a TextLabel **already parented** to `parent`. `Font`, `SizeFor`, `ReadyChanged`, `Label`, `Measure` |
| `Surface` (K2) | `TitleMark(parent, {Name, Height})` and `.Set({Height})`; `KeyCap(parent, {Name, Text, Size})` and `{Name, Icon, Size}`; `Icon(parent, {Name, Icon, Colour, Size})`, `.Set({Icon})`, `.Set({Size})`, its `Instance` an ImageLabel; `Hairline.Set({Visible})`; `Panel`, `Scrim` (`Menu`, `Confirm`) |
| `Controls` (K2) | `IconButton(parent, {Name, Icon = "close", Size = "Small", OnActivated})` and `.Set({Visible})`; `ButtonRow(parent, {Name, Buttons, Align = "Right", Place = "None"})` and `.Set({Buttons})`; `Button` (Confirm, as Phase 1) |
| `BigNumber` (K4) | `New(parent, {Name, Text, Role, Colour, Align = "Centre", MaxCells = 3}, scope)`, `.SetText(string)`, `.Set({Role})`. K3 sets `AnchorPoint`, `Position` and `ZIndex` on its root |

`Kit.Gauge` requires Tokens, Sprites, Metrics, Text, BigNumber, Perf. `Kit.Minimap` requires Tokens, Sprites, Metrics, Text, Surface, BigNumber (Perf is allowed but not needed). `Kit.Overlay` adds Presence to its Phase 1 list.

## API2 ambiguities and the reading used

1. **Gauge budget 26 against "each revealed image is two half windows named `<Layer>Left`, `<Layer>Right`" (3.2).** Six windows give 28 instances. Because "Glow and Arc share angles", the `Glow` and `Arc` images share one pair of windows, `ArcLeft` and `ArcRight`; `BoostLeft` and `BoostRight` hold `BoostArc`. Total is exactly 26 with the tip counted (root, Track, Ticks, 4 windows, 6 images, 6 masks, Tip, Speed x 4, Unit, BoostText). There is no `GlowLeft` or `GlowRight`. The boost image is named `BoostArc`, not `Boost`, because `Boost` is a reserved name.
2. **`Gauge.Angles` (3.2) gives no formula.** Angles are clockwise from +X. A mask at `Rotation` r shows the angles (r + 90, r + 270), so a fill ending at angle a needs r = a + 90 (spike 06 agrees). `Angles(fraction)` returns `(left, right)`:
   - left window (135 to 270): `a + 90` while the fill is short of 12 o'clock; `380` once it reaches it; `200` when empty;
   - right window (270 to 405): `a - 270` past 12 o'clock; `-20` before.
   The three fixed values park the mask edge 20 degrees from the seam, inside the gap the gauge images leave empty at the bottom (45 to 135). A mask edge left lying exactly on the join has a soft step about 0.002 of the frame wide, which would draw a faint column at 12 o'clock. Check values: `Angles(0) = 200, -20`; `Angles(0.25) = 292.5, -20`; `Angles(0.5) = 380, -20`; `Angles(0.75) = 380, 67.5`; `Angles(1) = 380, 135`.
3. **Speed number on the smaller Regular gauge.** 3.2 says role `Speed`. With `GaugeTouchSize` 240 on a Regular screen the `Speed` cap (95) makes three digits about 200 px wide in a 217 px plate. The gauge uses role `Timer` (62) when `Size` is under the midpoint of `GaugeSize` and `GaugeTouchSize` on Regular, and `Speed` otherwise. **A deviation; one line in `speedRole()` to undo.**
4. **`PromptBanner` height and `Main` (3.7).** The text says "a slate strip `PromptWidth` x `PromptHeight`" and gives `Main` no meaning; r16a and r16b show 64 px banners and one 84 px race-start banner. Reading: `Main = true` is `PromptHeight` (84), otherwise `ButtonHeight` (64). Compact has no height token: `ctx.Touch(CompactButtonDrawn)`, plus `TouchGap` for Main. Every height goes through `ctx.Touch`, so a touch banner is never under 48.
5. **`PromptBanner` root class.** "With `ctx.Input == Touch` ... the whole banner is a TextButton ... otherwise it is not clickable", and the cap follows `ctx.Input` live. A class cannot change live, so the root is **always a TextButton**; `Active` is true only on touch, and presses are ignored unless the input class is Touch. `Selectable` is false.
6. **`PromptBanner` look on touch** is read off r16b: White fill, Ink text, action and object centred as a pair, no hairlines.
7. **`PromptStack` props, `Count` and `Show` semantics are not specified.** Props are `Name`, `LayoutOrder`, `Visible`. `Count()` is the number **shown** (at most 3). `Show(id, props)` treats `props` as the whole prompt: a key left out returns to its default. A fourth prompt hides the oldest, which returns when a newer one is hidden. The Component `Show` returns is pooled: do not keep it after `Hide(id)`.
8. **`Modal.Buttons: ButtonRowProps?`** is read as `{Buttons = {...}}`; a bare list of buttons is accepted too. Only its `Buttons` is passed on (`Align` is always Right, `Place` always None; the modal places the row bottom-right itself).
9. **`Modal` `Side` and `Scrim`** are fixed at construction (`Set` with a different value errors). Defaults: Centre has scrim `Confirm` (as Phase 1), a side panel has `None`. A side panel needs no `Width`, fills its parent (slot `SidePanel`) and ignores `Width` and `Height`. On Regular it insets its title and body by `HudMargin` and `barBottom + TopBarGap` (2.4 says "content insets itself"); the Menu frame's 68 px margin is not known to the modal. A centred modal with scrim `None` has `Active = false` on its root so the scene stays clickable.
10. **`Presence` surface name** for a modal is its `Name` prop (default `"Modal"`). Two open modals need different names.
11. **`Minimap.Content: Frame` against "Content is the programme's one CanvasGroup".** A CanvasGroup is not a Frame, and `SetRound` would have to swap the instance a screen is holding. `Content` is a clipping **Frame that never changes identity**; it sits inside the CanvasGroup `Round` (with the vignette) when round and directly on the root when not. `Round = false` at build creates no CanvasGroup.
12. **"The one `UICorner`" against "a small Ink disc" and "a round Ink badge" (3.3).** Three corners are used: the `Round` clip, the `North` disc and the Compact `RankBadge`. 6.6 rule 2 allows `UICorner` in this module without a count; if the lint counts, the two discs are the ones to change.
13. **Rank arc and "the same two-half reveal as the gauge".** `RankArc` is a full ring, so a half window would also show the part before the start. The left window is cut at the start: the top-left quarter on Regular (180 to 270); on Compact it reaches down to the height of 165 degrees (a horizontal cut, 15 degrees off radial at the arc's end). The right window (top-right quarter, 270 to 285) is built only on Compact. The track is the same image at `RankTrackImage`, limited by the same windows, with a fixed mask on the right.
14. **Rank arc radius is not in `Sprites`.** `Kit.Minimap` carries `RANK_MID = (244 - 13/2) / 512` from `rings.json`. Request: add it to `Sprites.Rings.Rank`.
15. **`SetHeading(mapRotationDegrees)`**: read as the clockwise rotation of the map canvas (GuiObject.Rotation sense). North is drawn at `270 + rotation` on the rim, so 0 is top and 180 is bottom (the r00 frame).
16. **Toast with an icon.** The Phase 1 test caps the pool at 11 descendants, so a card's icon is built the first time a message asks for one, then kept and hidden. An unknown icon name warns once and shows the toast without it. An unknown `Kind` is Neutral. A duplicate text takes the newer kind.
17. **`ShowRank` default** is true. **`Minimap` label** is hidden on Compact (`MinimapLabelBand` is 0 there).
18. **Slot anchor.** The gauge, the minimap and no other K3 root copy the parent's `AnchorPoint` when the parent's name starts with `Slot` (API1 8 leaves this to "the child").

## For the lint

- `Kit.Gauge` names the asset key `GlowSoft` (the tip, API2 3.2), outside the "Used by" column of 1.1.
- Layout ratios that have no token are module constants, each with its source frame: gauge `SPEED_Y`, `UNIT_Y`, `BOOST_Y`; minimap `RANK_X`, `RANK_LABEL_Y`, `RANK_NUMBER_Y`, `BADGE`, `NORTH`, `NORTH_GLYPH`, `ARROW`. They are fractions of the frame, not pixels.
- `gauge._writes()`, `minimap._writes()`, `banner._press()`, `banner._release()` are test and probe seams outside API2.
- `Kit.Gauge` and `Kit.Minimap` connect through the caller's `scope` and disconnect in `Destroy` (the `Kit.Surface` pattern); `Kit.Overlay` keeps its private scope.
- The frame-step path (`SetSpeed`, `SetBoost`, `SetHeading`, `SetArrow`) has no lookup and no `Instance.new`.

## What the integrator must check in Studio

1. **Gauge seam at 12 o'clock** (gallery `Gauge.Gauge`, states `BeforeSeam`, `AtSeam`, `PastSeam`, then `SlowSweep`), at R720, R1080, R1440 and C844: no dark or bright column where `ArcLeft` meets `ArcRight`, for the arc, its glow and the boost arc. The side is forced even so the join is on a whole pixel; the gallery's stage `UIScale` can still put it on a half pixel, so judge at a preset that fits the window unscaled, and in the live HUD.
2. **Reveal direction and edge.** Fill starts bottom-left and runs clockwise over the top. If it is mirrored or starts elsewhere, the convention in ambiguity 2 is wrong for the engine and only `sweep()` changes. Leading edge: no stair-step, no colour past it.
3. **`Parked`:** no stub of arc or glow at the start; no tip. **`Full`:** the arc reaches its end with no cut short of 45 degrees; the tip sits on the arc.
4. **Writes** (state `Sweep`; attributes `GaugeFrames` and `GaugeWrites` on the gauge root, published once a second): mean under 4 a frame. The bench counts glow and arc masks separately, so one angle step is 2 gradient writes.
5. **Speed number:** centred on the plate at each size; role choice of ambiguity 3 at `TouchSize`.
6. **Minimap:** round clip is clean (CanvasGroup edge quality at C844); vignette inside the ring; rank arc begins at 9 o'clock on Regular and its track ends at 12; Compact arc runs 165 to 285 with the badge on its start; `RANK` and the number do not touch the arc; `N` disc on the rim and readable; the arrow image points up at rotation 0; `Square` state.
7. **Prompt banners:** action and object sit side by side once the text has a size (the object's position is read back from the action's width); the same under the Largest text setting; key cap and pad glyph look; `Touch` and `HoldTouch` states press and release once each (attributes `PromptPresses`, `PromptReleases`), including a finger slid off the banner.
8. **Modal:** title mark size beside the title (Confirm and Modal, both classes); footer row and X position; the side panel in slot `SidePanel` on R1080 and C844; `Presence` released on every close path.
9. **Toast `Kinds`:** edge colours, icon position and fade; a long Bad message with an icon wraps inside the card.

## Not done

- No run of any test. No capture. No lint run (the phase 2 lint does not exist yet).
- The gauge's segmented fallback is not built (API2 3.2).
- A prompt object that is too long is truncated with an ellipsis on key and pad input; on touch it is not truncated.
