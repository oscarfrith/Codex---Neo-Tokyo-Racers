# Agent C notes: Kit.Text, Kit.Surface, their fixtures and tests

Written against `API.md` only. Nothing was run: there is no offline Luau, so every file was desk-checked (block and bracket balance was checked by script; LF line ends; largest source 15,389 characters). Nothing was installed, and Studio and git were not touched.

## Files

| File | Instance |
|---|---|
| `after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Text.lua` | `Kit.Text` |
| `after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Surface.lua` | `Kit.Surface` |
| `after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Text.lua` | items `Text.Label` (22 states), `Text.Roles` (4) |
| `after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Surface.lua` | items `Surface.Panel`, `.Hairline`, `.Scrim`, `.Glow`, `.Icon`, `.IconSheet` |
| `tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.Text_test.lua` | 20 cases |
| `tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.Surface_test.lua` | 17 cases |

The fixtures have no test file of their own (API 13 asks for one per Kit module); the gallery run (U8) exercises them.

## What the code expects from other modules

- `Tokens.Type` keys are the flat names less the `Type` prefix: `Family`, `FallbackFamily`, `CapRatio`, `FallbackCapRatio`, `BaselineShift`, `ItalicPad`, `MinTextSize`, `MaxTextSize`, `ReadyTimeout`. Likewise `Tokens.Space.Hairline`, `.Pad`, `.Gap`, `.GlowTileRadius` and so on, `Tokens.Opacity.Panel` and so on, `Tokens.Cap.Regular[role]` and `Tokens.Cap.Compact[role]`.
- `Tokens.Icons.Glyphs[name] = {column, row}`, zero-based, as the `cell` field of `assets/out/icons.json`. `ImageRectOffset = (column x Cell, row x Cell)`.
- `Tokens.Slices[key] = {Center: Rect, Inset: number}`.
- `ctx.Changed` passes one table; a table with `Layout == false` is ignored. A context with no `Changed` is accepted.
- The tests build contexts with `Metrics.Fixed({Size = ..., TouchEnabled = ..., Input = ...})` and bind them to a detached Frame with `Metrics.Bind`. They carry their own fake scope, because `env` supplies none.
- Fixtures reach the kit as `script.Parent.Parent.Parent.Kit`. The harness's fake `script` must support that if it ever loads a fixture.

## API questions and how I read them

1. **`Text.ReadyChanged: RBXScriptSignal` against "requiring any module creates no instance" (API 1).** A BindableEvent is an instance. I used a small Luau signal with `Connect`, `Once` and `Wait`; its connections have `Disconnect`, which is what `Core.ConnectionScope` releases. `typeof` is `table`, not `RBXScriptSignal`. `Metrics.Changed` has the same question.
2. **Label box when no width is given.** The API does not say how the root gets its size. Rules implemented:
   - no `MaxWidth`, no `Wrap`: one line; the root hugs the text plus the italic padding (`Align` then has nothing to act on);
   - `MaxWidth`: the root is **exactly** that wide (not "up to"); one line truncates at the end, `Wrap` grows downward. `Align` works inside this box;
   - `Wrap` with no `MaxWidth`: the root fills its parent's width and grows downward.
3. **Italic padding inside a budget of 2.** A `UIPadding` would be a third instance in every label and break every budget built on labels. Instead the label sizes itself with `AutomaticSize`, and the root reads the label's `AbsoluteSize` back and sets its own width to text plus padding. The read-back divides out any `UIScale` above it using the root's known line height, so it holds under the holder scale and the gallery `StageHolder`. Cost: one `AbsoluteSize` connection per hugging label. On a detached parent the root is text-tight until it is first laid out.
4. **Budget 2 against the holder `UIScale`.** API 7 excludes only a `Glow` and a `UITextSizeConstraint`. A title above TextSize 100 has a third instance, the `UIScale` named `HolderScale` (4 with a shadow). Suggest the budget text excludes it too.
5. **`Fixed` default and "display roles".** Read literally from API 3.4: display roles are every role except `Label` and `Body`. The programme contract counts `Value` as a role that grows with the Text Size setting; here `Value` is Fixed unless `Fixed = false`.
6. **`Upper` default.** Display roles are upper-cased; `Label` and `Body` are not unless `Upper = true`.
7. **Baseline shift** is `round(TypeBaselineShift x TextSize)` pixels upward (not x cap). **Italic padding** is `round(0.2 x cap x scale)`.
8. **Shadow.** No shadow token exists. It is a second TextLabel named `Shadow` in `Ink`, offset by `ctx.Hair(Space.Hairline)` in both axes, at `Opacity.Panel`. It is a hard offset copy, not a soft blur. Tokens such as `OpacityTextShadow` and `SpaceTextShadow` would be cleaner.
9. **`Text.Preload` failure.** "Failure" is an error from `GetTextBoundsAsync`. Then the family and cap ratio switch to the fallback, one warning, and `Ready` becomes true once all three faces have answered. A face that is merely slow does not switch the family; `WaitReady` returns false at its timeout and stays usable. `WaitReady` calls `Preload` itself.
10. **`Text.Measure`** returns the bounds of the text itself in real pixels (times the holder scale, rounded up). A hugging Label root is wider by the italic padding. It does not upper-case; the caller passes the text as it will be shown. With no `maxWidth` it leaves `GetTextBoundsParams.Width` at its default.
11. **`Glow` with an empty asset.** API 3.6 says "creates no instance"; 7.2 says the component's `Instance` is a zero-size Frame. I followed 7.2, since a Component must have an `Instance`.
12. **`Glow` "behind the parent".** Under `ZIndexBehavior = Sibling` a child can never draw behind its own parent's background. The glow is parented into `parent` with `ZIndex = parent.ZIndex - 1`, so it draws under the parent's other children (a `Fill`, labels) and outside the parent's edges. The parent must not clip descendants and must not hold a layout object. A parent that draws its own opaque background will show the image's middle over it.
13. **`Glow` kinds.** `Tile` uses `GlowSoft`, `GlowTileRadius`, `Opacity.GlowTile`. `Button` uses `GlowTight`, `GlowButtonRadius`, `GlowButton`. `Line` uses `GlowLine` and `Ring` uses `GlowTight`, both with `GlowRingRadius` and `Opacity.GlowRing`: the API names no radius or opacity for `Line`. `SliceScale = radius / Slices.Inset`, and the image reaches one radius past each edge.
14. **`Panel` with `Width` or `Height` nil** fills the parent on that axis. Auto-height from content would need a `UIPadding` (budget 4 is root, `HairTop`, `HairBottom`, `Content`). `Hairlines = false` hides the two frames; it does not remove them.
15. **`Scrim` kind `Garage`.** Budget 2 allows one gradient. It is `ScrimTop` fading out from the left edge to 38% of the width. The style sheet's bottom 40% band is not drawn. The menu scrim's "faint pink corner" is not drawn either.
16. **`Icon.Size`** is required. `Icon`, `Glow` and `Hairline` require their `Colour`/`Kind`/`Edge` as the table lists them.
17. **Lint rule 6, literals outside Tokens.** Present on purpose: `Color3.new(1, 1, 1)` as the gradient base; gradient rotation 90; `0.38` (garage fade end); `512` (measure cache size); `0.6` (width estimate, used only if measuring fails); `0.01` (rounding guard).

## For the integrator to check in Studio

- **Hugging labels**: after the first layout the root is wider than the text by the italic padding, at R720, R1080 and R1440, and inside the gallery when `StageHolder` carries a `UIScale`.
- **Title above 100** (`Text.Label` state `ScreenTitle` at R1440): sharp, and `AutomaticSize` under the holder `UIScale` gives the right box (test U12).
- **`UITextSizeConstraint` without `TextScaled`**: confirm it really stops the Text Size setting from growing display roles. If it does not, `Fixed` needs another method.
- **`GetTextBoundsParams.Width` default**: confirm that leaving it unset measures one unwrapped line.
- **Font equality**: `write` skips a property whose value already matches; this relies on `Font`, `UDim2`, `Rect` and `Color3` comparing by value.
- **Glow, once `GlowSoft`, `GlowTight` and `GlowLine` are uploaded**: the band is one radius deep and the corners are even; `GlowLine` is sliced on one axis only and is stretched vertically across the parent height plus two radii.
- **Baseline**: capitals look centred in a 64 px button with the 4% shift.
