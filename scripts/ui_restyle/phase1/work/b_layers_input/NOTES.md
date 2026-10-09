# Agent B notes: Kit.Layers, Kit.Input, Kit.Contracts

Status: **generated, desk-checked only.** No Luau was run; nothing was installed or opened in Studio. The generator was run with `py -3` (3.14) and is byte-stable across runs.

## Files

| File | What |
|---|---|
| `gen_contracts.py` | Generator. `py -3 gen_contracts.py` writes the Contracts source; `--check` fails if the file on disk differs; `--contracts DIR`, `--out FILE` |
| `after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Contracts.lua` | Generated, 11,946 chars. Never edit by hand |
| `after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Layers.lua` | Hand-written |
| `after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Input.lua` | Hand-written |
| `tests/<same names>_test.lua` | One per module, API.md section 13 shape |

The generator's default paths assume it sits in `phase1/work/b_layers_input/`. If it is moved, pass `--contracts` and `--out`, and change `GENERATOR_LABEL` (it is written into `Contracts.Source.Generator`).

## API questions and how each was read

1. **Slot margins on Compact (please decide).** API section 8 says `M = Px(MenuMargin) or Px(HudMargin)` and never mentions `SpaceCompactMargin` (12 dp). Read literally: Menu frame uses `MenuMargin`/`MenuBottom`, every other frame `HudMargin`/`HudBottom`, in both classes. On a 390 dp phone that is a 40 or 68 dp side margin, which looks wrong against the token. It is one function, `margins()` in Layers; the C844 expectations in the Layers test change with it. Phase 1 toasts only use `TopCentre`, which has no side margin.
2. **`Scene` margins.** Not stated. Read as the Hud values.
3. **`RightColumn`, `PromptStack`.** "Created; geometry fixed later": placed at the `TopRight` and `BottomCentre` positions for now.
4. **Top bar and a top safe inset.** Slots sit under `TopBarHeight - Origin.Y` (never below 0), because the root starts at the safe-area top and the top bar is measured from the screen top. Equal to `TopBarHeight` whenever `Origin.Y` is 0 (Studio, `Metrics.Fixed`).
5. **Slot anchors.** Each slot Frame carries the table's anchor as its own `AnchorPoint` (no visual effect at zero size), so a child can copy `slot.AnchorPoint`.
6. **`Live` and `Scrim` numbers.** `<name>Live` is base + 1 and `<name>Scrim` base - 1 unless `Layers.Order` has a row of that exact name. If the default lands on another row, `Create` errors and asks for a row (for example `OwnedGarageBrowserScrim` would hit 170). With both options the scrim sits under the base number.
7. **Existing gui of the same name.** Pulse-marked: error. Unmarked: destroyed for `SharedTopNotification` and `SharedConfirmationOverlay`, error for any other name. The same check runs for the `Scrim` and `Live` names.
8. **Scrim root** is the one root sized by scale (`UDim2.fromScale(1, 1)`), since no metric gives the full-screen size and a tint has no edge to keep sharp. The scrim gui also gets `ClipToDeviceSafeArea = false`.
9. **`Layers.Switch()`** uses `ReplicatedFirst:FindFirstChild("UIStyleSwitch")` and asserts, so it cannot yield. `Create` always calls it as `Layers.Switch()` so the test harness can replace it.
10. **`Metrics.Screen()` is assumed to be one live table** whose fields change in place before `Changed` fires. Layers keeps the reference and relays out on `Changed` unless the payload has `Layout == false`.
11. **`AttachSafeArea` once.** Called with the first gui `Create` makes and never again. If that layer is later destroyed, Metrics is left with a dead gui. In Phase 1 the first layer is the toast layer, which is never destroyed.
12. **`Focusable` has no scope argument**, so its two `OnFocus` connections live until the button is destroyed (a second call on the same button replaces them). The blank selection Frame is left unparented, so it costs no descendant.
13. **`ShouldEnterFocus`.** True when `ctx.Input == "Gamepad"`, or `UserInputService:GetLastInputType()` is Keyboard or a gamepad. "Keyboard navigation" is read as any key press, because Input may not listen to input events (only Metrics may).
14. **`FocusGroup`.** `Enter(preferred)` targets `preferred` if it is in the group and can take focus, else the lowest `order` (insertion order by default). It writes `SelectedObject` only when `ShouldEnterFocus(Metrics.Of(target))` and the target is in the game tree. A trapping group pulls focus back to its last member when focus moves to a non-member, **except** when the new object is in a ScreenGui with a higher DisplayOrder (a confirmation over a modal). Only the most recently entered trap acts. `Leave` restores the saved selection when focus is nil or still inside the group. The group sets no `NextSelection` links.
15. **Binding priority.** `BindBack` default is `Enum.ContextActionPriority.High.Value` (3000); bumpers and triggers use the same. All states are sunk; only Begin calls the handler, through `task.spawn`. `Kit.Overlay.Confirm` must pass 10000 itself.
16. **`Mark` with a text key** needs a TextLabel, TextButton or TextBox and errors otherwise; it does not look for a child label. `Marked(key)` returns a copy and errors on an unknown key.

## Contracts: what the generator decides

- **Reserved** = `_reserved_names.json` `names` (79), plus ScreenGui names from `names_looked_up_only_by_their_definer` (needed for `ActivityHud`, `MobileDriveControls_Phase1`, `SharedConfirmationOverlay`), plus every name and ScreenGui the onboarding resolvers look for (needed for `TierE` to `TierS`). 98 names. The build stops if any name of programme contract 2.3 is missing, or if a name is both reserved and trap.
- **Reserved contains generic names** that Classic happens to share between scripts: `Root`, `Panel`, `Text`, `Status`, `Body`, `Image`, `Price`, `Rating`, `Back`, `Buy`, `Exit`, `Detail`, `Cash`, `Settings`, `Controls`, `Stroke`. API.md itself assigns `Root`. Lint rule 10 will need an allow-list or a narrower rule, or it will flag kit children.
- **Trap** = `DriveHUD`, `TouchGui`, `DrivingSpeedEffect` (each verified against the tables) plus the 11 names of `legacyNames` read from `RaceLifecyclePresentationClient.json`. **TrapDescendants** = the four roots, verified present in `lookups_without_static_definer`. `Layers.Check` refuses both sets.
- **Marks keys** (my scheme; API.md does not define one): a legacy name is its own key (`Car`, `Race`, `Garage`, `Categories`, `TierE`, ...); `Card` sets `CanonicalGarageCard = true`; `Card.<id>` adds `CanonicalGarageCardId`; `Page.<id>` sets `TutorialWorkspace = true` and `TutorialPageId`; `Text.TimeTrial`, `Text.Race`, `Text.Dealership` set the text. 52 keys. Fixtures written by other agents that pass a `MarkKey` must use one of these or `Mark` errors.
- **PlayerAttributes** keys are bare attribute names (player and PlayerGui together). The type is inferred from literal values and a few plain expression shapes in the writers; 32 of 65 are `"unknown"`. Treat it as a hint, not a schema.
- **Source.Inputs** are sha256 of each input with CRLF folded to LF, so a Windows checkout does not change them. A fifth input, `RaceLifecyclePresentationClient.json`, is fingerprinted as well.

## For the integrator to check in Studio

1. `ScreenGui.ScreenInsets` reads back `DeviceSafeInsets` (content) and `None` (scrim) after `IgnoreGuiInset = true` is set first; `ClipToDeviceSafeArea = false` is accepted on the scrim.
2. An unparented transparent Frame as `SelectionImageObject` hides the engine selection box on a Pulse button (gamepad or keyboard navigation in the gallery).
3. `ContextActionService:BindActionAtPriority` and `GetAllBoundActionInfo` behave in Edit under `execute_luau`; the Input test binds four actions and unbinds them. If Edit refuses, that one case fails and the rest stand.
4. Escape bound at 3000 through `BindBack` reaches the handler before the Roblox menu (Classic binds it at 10000).
5. The trap rule in note 14 with a real confirmation over a real modal.
6. `Metrics.Of` on a slot of a staged layer returns the bound context (the Layers test asserts it; it depends on agent A's `Bind`).
