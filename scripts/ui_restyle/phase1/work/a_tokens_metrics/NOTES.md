# Agent A notes: Kit.Tokens, Kit.Metrics, Kit.Perf

State: generated and desk-checked only. Nothing was compiled or run (no offline Luau); no Studio, no git.

## Files

- `after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens.lua`
- `after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Metrics.lua`
- `after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Perf.lua`
- `tests/<same names>_test.lua` (three files, API.md 13 signature)

## API questions and the reading used

1. **`Tokens.Flatten` scope.** Flattens 3.1 to 3.5 only (126 names: 13 Colour, 6 Tier, 15 Opacity, 40 Space, 9 Type, 13 Cap, 13 CompactCap, 17 Scale). `Assets`, `Slices` and `Icons` are not in it: asset keys have no prefix and live on a different folder (CONTRACT 3), and a Rect is outside the return type. The generator must take the 20 asset attribute names from `Tokens.Defaults.Assets`, and add `PerfDebug` itself.
2. **`ScaleRegularMin` and `ScaleHudMaxAspect`** are `16/24` and `21/9` in code, not the 7-digit decimals printed in API.md. The JSON passed to `build.py` must keep full double precision, or the attribute value will differ from the code default and 1280x720 snaps to 15/24.
3. **Live token tables are not frozen** (only `Defaults` is). API.md says `Text.Preload` "switches to the fallback family and CapRatio" and does not say where that state lives, so writes are not blocked.
4. **`Tokens.Asset` with an unknown key** returns nil and warns once (API.md covers only `""`).
5. **Config attributes that are not tokens** (`PerfDebug`) are ignored silently. A non-finite number counts as a wrong type.
6. **`ctx.Touch`**: "TouchMin real px" is read literally: the floor is 48 unscaled pixels, in Compact or with Touch input, at any scale.
7. **`ctx.Px` of a negative value** mirrors the positive rule (at least 1 in magnitude).
8. **`Metrics.Fixed` defaults**: `Input` follows `TouchEnabled`; `TopBarHeight` 0 and `TopBarKeepOut` (0, height) when not given (API.md gives no default, and 58 or 208 in Metrics would be pixel literals outside Tokens). The gallery passes both.
9. **`Metrics.Bind` is not a weak table.** Instance keys in a weak table can vanish while the instance is alive, so the entry is strong and is removed on the root's `Destroying`. A bound root must be destroyed, not just dropped. That one connection is not in a scope (Bind has no scope argument).
10. **`AttachSafeArea` twice**: same gui is a no-op; a different gui is ignored with one warning unless the first has left the tree, then it replaces it. Attaching refreshes the screen context at once and fires `Changed` if anything differs.
11. **`Changed` timing**: layout sources (camera, viewport, safe gui size and position, `TopbarInset`, `PreferredTextSize`) restart a `ResizeSettle` timer and fire once. An input change fires on the next deferred step, not after the settle time. A `PreferredTextSize` change fires `Layout = true` even though no field changes. Nothing fires when nothing changed.
12. **`Fixed` contexts share one never-fired BindableEvent** for `Changed` (created on the first `Fixed` call, unparented).
13. **`Screen()` connects its listeners only when `RunService:IsRunning()`.** In Edit (the pure tests) it is a snapshot, so the test run leaves no connection in the Studio session. It still creates one unparented BindableEvent.
14. **`Perf.Bind`** watches `layerRoot.Visible` itself, not ancestors (literal). It also disconnects on the root's `Destroying`. A step error is caught, reported once per name and the binding keeps running.
15. **`Perf.Count` publishes running totals**, not per-second rates. Counter names are made attribute-safe (`[^%w_]` to `_`, 100 chars). The publisher thread starts on the first `Count` while enabled; the folder is created then, not at require.
16. **Rule 9 and Metrics**: the service listeners are session-long and have no scope. Rule 6: Metrics holds `1e-6` (the API.md snap guard) and Perf holds `1` and `100` (seconds, attribute name length); none is a pixel value. The lint may need to allow them.

## For the integrator to check in Studio

- Compile (E1) and E3 for the three tests.
- In Edit through `execute_luau`: `GuiService.TopbarInset` and `UserInputService.PreferredInput` are readable (the "Of with and without Bind" case calls `Screen()`).
- In Play: the attached ScreenGui's `AbsoluteSize` is non-zero and `AbsolutePosition` is the safe-area origin in `ScreenInsets.None` space. While it reads zero, Metrics uses the camera viewport with origin (0, 0).
- `TopbarInset` can read as an empty Rect early in a session; `TopBarHeight` is then 0 until the property signal fires and `Changed` follows 0.25 s later. If the toast slot is laid out before that, it corrects itself on `Changed`.
- `Size` is not floored (Oscar's Studio reports 2065.33 wide); `Kit.Layers` floors where it places right and bottom clusters.
- RenderStepped connect and disconnect on `Visible` when the first frame step arrives (Phase 2); Phase 1 has none.
