# Agent K1 notes: Tokens, Sprites, Metrics, Layers, Contracts, Presence (kit v2)

Status: **generated, desk-checked only.** No Luau was run (there is none offline); nothing was installed, no Studio, no git. The three generators were run with `py -3` (3.14) and are byte-stable (`--check` passes). Desk checks done by script: block and bracket balance of every source and test; the 200 flat tokens of the Tokens test against the Tokens source; all 76 slot expectations of the Layers test against a Python port of `slotLayout`.

## Files

| File | What |
|---|---|
| `gen_sprites.py` | Writes `Kit.Sprites` and the marked asset-id block of `Kit.Tokens`. `--check`, `--assets`, `--out`, `--tokens` |
| `gen_contracts.py` | Copied from `phase1/work/b_layers_input/` and extended (API2 2.5). `--check`, `--contracts`, `--out` |
| `gen_tokens_flat.py` | Writes `tokens_flat.json` by parsing the Tokens source; stops if a Phase 1 token changed |
| `tokens_flat.json` | 74 new token attributes (`tokens`), the 31 asset ids (`assets`, with `assets_before`: `""` existed, `null` new) and `assets_retired` |
| `after/...Kit.Sprites.lua` | Generated, new, 9,471 chars |
| `after/...Kit.Contracts.lua` | Generated, 38,861 chars |
| `after/...Kit.Tokens.lua` | Hand-written from the Phase 1 file, except the block between the `GENERATED ASSETS` markers |
| `after/...Kit.Metrics.lua`, `after/...Kit.Layers.lua` | Hand-edited from the Phase 1 files |
| `after/...Kit.Presence.lua` | New |
| `tests/<same six names>_test.lua` | API1 section 13 shape. Four updated from Phase 1, two new |

Both generators find `scripts/ui_restyle` from their own location and write that location into `Source.Generator`, so they can be moved to `phase2/kit/` (API2 1.2 names that folder; API2 6.1 and my brief say `k1/`). After a move, pass `--out`/`--tokens` or keep an `after/` folder beside them, and run them once: the label line of both generated files changes.

Every source's line 2 now reads `Pulse UI (phase2)` (API2 6.6); Tokens' `Requires:` is `Sprites`.

## API2 questions and the reading used

1. **Sized slots and the "copy the anchor, Position zero" rule (2.4). Other agents need to know this.** In a zero-size slot a child at `Position` zero with the slot's anchor is correct. In a sized slot it is only correct on an axis where the anchor is 0. So: `BottomRail` (anchor 0,1) is sized in **width only** (`W - M`, height 0), which keeps Phase 1 children right. `RightColumn` (anchor 1,0) has width and a height (`H - B - top`); `SidePanel` is as the table says. In `RightColumn` and Compact `SidePanel` a child must **fill** (`Size` scale 1, anchor 0,0) or use `Position = UDim2.fromScale(anchor.X, anchor.Y)`; a child that copies anchor (1,0) and sits at `Position` zero lands one slot-width to the left.
2. **`RightColumn` height** is not stated; I used "down to the bottom margin" so `fromScale(1, 1)` is usable.
3. **`RightColumn` on Hud + TouchDrive + Regular "starts under the minimap".** Read as `Px(HudRightColumnTop) + Px(MinimapSize) + Px(MinimapLabelBand) + Px(Gap)` (the label band belongs to the minimap; one gap so they do not touch). Only the `Hud` frame moves.
4. **Slot anchors and sizes are now written on every relayout**, because `ActionBar`, `SidePanel`, `Minimap`, `Gauge` and `HudButtons` change anchor with class or arrangement. The Phase 1 gallery keeps its own `SLOT_ANCHOR` table for the eight old names, which still match.
5. **`TopCentreHud` and `ActionBar` on Regular use `Px(TopRightTop)` in every frame** (literal), also in `Menu` and `Scene` where `TopRight` is at 67.
6. **`HudStatus`**: `= TopRight` except Compact + TouchDrive (`minimap top + Px(CompactMinimap) + Px(TouchGap)`). Regular + TouchDrive stays at `TopRight` (literal; the table gives no Regular difference).
7. **Compact Standard `Minimap`**: `(M + Px(MinimapInset), H - B)`; `MinimapInset` has no Compact token, so it is 18 dp.
8. **`PromptStack` Regular** is `H - Px(PromptLift)` with no `B` (literal).
9. **Ladder rows.** Every name in the API2 2.4 block is a row of `Layers.Order` (34 rows), including the ones that equal base +/- 1. `Layers.Check` therefore accepts `FullMapLive`, `RaceBrowserScrim` and the like as layer names; `Create(name, {Live = true})` and `{Scrim = true}` take the row. `OnboardingScrim` has no row and derives 989, which is free. `GarageEntranceStatus` and `MobileFreeRoamHud_Phase1` have no row.
10. **`RootName`** is refused when empty, not a string, or a trap name. The scrim gui's root stays `Root`. `Layers.Stage` always names its root `Root` (it has no options argument).
11. **`ctx.Dp` (2.3)**: Regular is `round(dp x ScaleRegularDp)` and does **not** follow the screen scale (literal). 0 stays 0 and a negative value mirrors, as `Px` does (API2 says "at least 1"; a zero size staying zero seemed the safer reading).
12. **`Metrics.Fixed` spec `Dp`**: "optional fields with the same names" read literally: a function given as `spec.Dp` replaces the built-in one.
13. **`ChatKeepOut`** is `ceil(AbsolutePosition + AbsoluteSize)` of `ChatWindowConfiguration`, `(0, 0)` when the object is missing, `Enabled` is false, the Chat core gui is off or the size is zero. All reads are protected, so legacy chat or an early core call reads as no chat. Listeners (Play only): the three properties and `StarterGui.CoreGuiChangedSignal`. No offset is added for the top bar: API2 says the value is already in `ScreenInsets.None` space.
14. **`Metrics.Changed` type (2.6 calls it a Luau signal).** The installed Metrics uses a `BindableEvent`'s `Event`, and API2 2.3 says "nothing else changes", so I kept it: `typeof` is `RBXScriptSignal`; `Connect`, `Once` and `Wait` exist either way. `Presence.Changed` **is** a Luau signal (the module may create no instance), the same shape as `Text.ReadyChanged`.
15. **`Presence`**: counts are per surface and per kind. `Changed` fires `(surface, kind, true)` when a surface first opens under a kind and `(surface, kind, false)` when its last release under that kind runs; a surface opened twice fires once each way. `Open` errors on an unknown kind or an empty surface; `Any(unknownKind)` warns once and returns false; `Any()` is "anything open". There is no "any kind except Race" helper in the API: callers test the kinds they mean.
16. **`Tokens.Icons`** is `{Cell = Sprites.Icons.Cell, Glyphs = Sprites.Icons.Glyphs}`: the same frozen glyph table, not a copy.
17. **`Sprites` is frozen all the way down** and holds asset **keys**, never ids. `Rings.Minimap.FrameScale` and `Rings.Rank.FrameScale` are written as the expressions `512 / 480` and `1.099 * 512 / 480`. `TitleSlash.Design` is `{53.3, 64}` as printed in API2 (the exact value is 160 / 3). Glyph tables are in sheet order. `TipFraction` and the four rank angles exist only as prose in `rings.json`; they are constants in the generator, which stops if the prose no longer contains those numbers.
18. **`Sprites.Source.Inputs`** lists the six geometry files read and `uploaded_assets.json`. `marks.json` is not read (nothing in API2 1.2 comes from it). `static_geometry.json` is read only to stop the build if a glow or key-cap slice no longer equals `Tokens.Slices`.
19. **`Contracts.Owner`**: 29 owners = every Classic script API2 section 5 replaces, forks or edits (list `OWNERS` in the generator). `Remotes` = client-to-server **calls** only (listens have no action), sorted keys; a call with no action has `Action = ""`; a remote chosen at run time is listed once per candidate remote (so `RaceSessionPresentationClient` shows each of its four actions under both remotes); an opaque receiver is skipped. `Bindables` = names fired, connected, invoked, handled or created. `Attributes` = names **written or listened to** (plain reads are left out: they are mostly config). Names built at run time are skipped.
20. **`Contracts.GenericNames`** is a set (`{[name] = true}`), like the other name sets.

## Phase 1 test expectations that changed (each by an explicit API2 line)

Tokens test:
- "assets: 20 keys, all empty by default" is now 31 keys, each an `rbxassetid://` default, the five retired keys absent (1.1, 2.2).
- The `expected` flat table gained the 74 new names; the count checks now include `NumberCap` (2.2). No Phase 1 value changed.

Layers test:
- C844 Hud: `TopLeft` (40,64) to (12,8); `TopRight` (804,40) to (832,8); `BottomRight` (804,362) to (832,382); `BottomCentre` (422,362) to (422,382); `BottomRail` (40,362) to (12,382). `TopCentre` unchanged (2.4 margins, `TopLeft` and `TopRight` rows).
- C844 Menu: `TopLeft` (68,64) to (12,8); `TopRight` (712,40) to (768,8); `BottomRight` (712,360) to (768,382); `BottomCentre` (390,360) to (390,382).
- R1080 Menu: `TopRight` (1852,40) to (1852,67) (2.4 `TopRight` changed).
- R1080 Scene: `TopLeft` (40,70) to (68,70); `BottomRight` (1880,1052) to (1852,1050) (2.4: Scene takes the Menu margins).
- `BottomRail` is no longer zero-size: width `W - M` (2.4 "changed: sized"). The helper now checks a size per slot.
- "all eight slots" is now nineteen, and `Stage` makes 1 + 19 instances (2.4 slot table).

Metrics and Contracts tests: no Phase 1 expectation changed; cases were added.

## For the other kit agents and the integrator

- Phase 1 `Kit.Overlay` line 524 reads `Tokens.Asset("TitleMark")`. That key is gone: it now returns nil and warns once. K3's Overlay must use `Surface.TitleMark` (API2 2.11).
- The harness must register `Kit.Sprites` and `Kit.Presence` as sources (Tokens now requires Sprites at load).
- The gallery's `GalleryChat` toggle (2.3) passes `ChatKeepOut = Vector2.new(483, 286)` to `Metrics.Fixed`; that field exists.
- `tokens_flat.json` is a desk product. Regenerate the attribute ops from `Tokens.Flatten(Tokens.Defaults)` in Studio as in Phase 1; it should give 200 names, of which the 74 in this file are new.

## For the integrator to check in Studio

1. Compile all six sources; run the six tests in Edit. The Presence test prints one expected warning (`[Pulse.Presence] Any asked for unknown kind 'Menu'`).
2. `ChatWindowConfiguration.AbsolutePosition` / `AbsoluteSize`: are they in `ScreenInsets.None` space (API2 measure: (8,12) 475 x 273.5, so `ChatKeepOut` (483, 286))? If they are relative to the area under the top bar, `readChatKeepOut` in Metrics needs the inset added.
3. Do the three `GetPropertyChangedSignal` connections on `ChatWindowConfiguration` fire, and does collapsing chat from the top bar change `Enabled` or the size (the API2 2.3 assumption)? If not, record that `ChatKeepOut` is the full rectangle whenever chat is enabled. `StarterGui.CoreGuiChangedSignal` covers `SetCoreGuiEnabled(Chat, ...)` from `CoreUiPolicy`.
4. `StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat)` in Edit under `execute_luau` (the Metrics test calls `Screen()`; the read is protected, so a refusal only gives (0, 0)).
5. `TopLeftHud` against the real chat window, and the Hud + TouchDrive + Regular `RightColumn` start (note 3) on a tablet preset.
6. A component mounted in `RightColumn` and Compact `SidePanel` (note 1): check K2/K3 fill the slot rather than sit at `Position` zero with anchor (1,0).
7. The 31 ids load (no failed-image warnings) once the `Config.UI.Pulse.Assets` attributes hold the ids. Note that an attribute still `""` (the Phase 1 state of 15 keys) overrides the code default and gives the flat state, as API2 1.1 says.
8. `Layers.Create(name, {RootName = "DesignRoot"})` gives `gui.DesignRoot`; `Create("LoadingSafeContent", {Scrim = true, RootName = "SafeRoot"})` gives orders 1001 and 1000.
