# Agent F notes: gallery, test harness, lint

Nothing here was run in Studio. The Luau files were desk-checked only; the lint has 26 passing tests (`py -3 test_lint_phase1.py`) and reports 0 findings on the gallery source.

## Files

| File | Goes to |
|---|---|
| `after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Gallery.lua` | `phase1/after/` |
| `tests/run_tests.lua` | `phase1/tests/` |
| `lint_phase1.py`, `test_lint_phase1.py` | anywhere under `phase1/` (the default target is the nearest `phase1/after`) |

API.md assigns no fixtures index module to the gallery; none was written. The gallery reads `Dev.Fixtures` children itself.

## API questions and how each was read

1. **"Nothing created until first opened" (task) against API 10 (ScreenGui exists at start, carries the attributes).** Read as API 10: `start()` claims `Gallery`, creates the `PulseGallery` layer, hides `Root` and sets the seven attributes. The backdrop, index and stage are built on the first open.
2. **Where a `Slot = nil` item goes.** "Stage centre" is read as a full-stage Frame `Stage.Centre` handed to `Mount` as `parent`, so a full-size component (Scrim) fills the stage. The gallery then places only a root the fixture left untouched (AnchorPoint 0,0 and Position 0): on a slot it sets the slot's anchor; at centre it centres a root with no Scale in its Size. A root the fixture positioned itself is left alone. If fixtures should always be placed by the gallery, or never, say so.
3. **Window smaller than the stage.** R1080 does not fit beside the index in Oscar's 2065 x 1152 Studio window, so it would always be captured through the UIScale. Added a key-only toggle (Home) that hides the index and gives the stage the whole window; R1080 then mounts at 1:1. It is not an attribute because API 10 lists none. A probe needs a key press for it. **Suggested amendment:** an in attribute `GalleryChrome` (boolean).
4. **Keys.** API 10 names only BackSlash. Added while open: PageUp/PageDown item, Comma/Period state, Minus/Equals preset, Home index. All of them only write the in attributes.
5. **Defaults.** Empty `GalleryItem`, `GalleryState`, `GalleryPreset` resolve to the first item, its first state and `R1080`; the resolved values are written back to the attributes. An unknown id sets `GalleryError` and mounts nothing. A fixture id containing `,` or `|` is refused (it would break `GalleryItems` and `GalleryMounted`).
6. **Tool flag.** `start()` re-checks Studio and `ClientTools@PulseGalleryEnabled` before the claim, as the Classic tool clients do, and reads it without `Core.ClientLifecycle` (not in the gallery's dependency row).
7. **Gallery chrome is raw TextButtons** using `Text.Font("Label")`, `Text.SizeFor` and token colours, not `Kit.Controls`, so the tool still opens when a component is broken. Its sizes are token values through the real screen context. The preset sizes and the 52/58/120/208 top bar values are the only number literals (API 10 data).
8. **`env` in the harness** has one extra field, `env.Scope()`: a `Core.ConnectionScope` loaded from `classic/sources` text (constructors need a scope, and section 13 gives tests no way to get one). `FakeSwitch(style)` follows API 4; a test may set `switch.DevFamilies = {...}`.
9. **Harness output shape.** `{ok, summary, results: {module, name, ok, detail}[], compileErrors: {file, error}[], tokens}`. Every after-source gets `compile` and `size and line ends` rows. `tokens` is `Tokens.Flatten(Tokens.Defaults)` as `{name: {Type, Value}}` (Color3 as three 0 to 255 integers) for `build.py` (CONTRACT 3, E6); change the shape there if `build.py` wants another.
10. **Lint scope.** Not checked statically: pixel literals (rule 6), yields (rule 8), connections through scope (rule 9), globals (the harness reports global writes at load instead). `Color3.new` with only 0 and 1 is allowed everywhere; `Font.new` is allowed in `Kit.Text` as well as Tokens (faces are "not config"). Any `.Enabled =` write is flagged, so a `UIGradient.Enabled` write needs `-- lint-ok: screengui-enabled <reason>` on its line. A `Perf.Bind` step must be an inline function or a function declared in the same file.

## Integrator checks in Studio

- `run_tests.lua`: `loadstring` and `setfenv` on the loaded chunks; the bridge's folder listing (`GET .../after/`) is used to find files, with the declared list as fallback. A module or test that yields is reported as a failure, not waited for. Loading the latch source reads `Config.UI` with `WaitForChild`; that must not yield in Edit.
- The harness watches `game.DescendantAdded` during the run; unrelated Studio activity in that window would show up as a false "parented" row (names are listed).
- Gallery: a `UIScale` on `StageHolder` is assumed to scale its size from its top-left and leave its own `Position` unscaled; check the stage is centred at R1440.
- Gallery: `Layer.Destroy` for a `Layers.Stage` layer is called through the mount scope with one extra argument (the table itself); harmless if `Destroy` takes none.
- Gallery relies on `layer.Metrics.Changed` firing `{Layout = boolean}`; a resize rebuilds the index and remounts.
- BackSlash is ignored only while a TextBox has focus.
