# Agent E: Kit.Overlay, Toasts.ToastClient, Fixtures.Overlay

Status: **generated**. Desk-checked only; no offline Luau, nothing run, nothing installed, Studio not touched.

## Files

| File | Instance |
|---|---|
| `after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Overlay.lua` | `Kit.Overlay` (Toast, Confirm, Modal) |
| `after/ReplicatedStorage.Modules.Game.UIPulse.Toasts.ToastClient.lua` | Pulse toast owner, `start()` |
| `after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Overlay.lua` | gallery items `Overlay.Toast`, `Overlay.Confirm`, `Overlay.Modal` |
| `tests/..Kit.Overlay_test.lua`, `tests/..Toasts.ToastClient_test.lua`, `tests/..Dev.Fixtures.Overlay_test.lua` | pure tests, API.md 13 signature |

All sources are LF, largest 31.7k characters.

## API questions and how I read them

1. **Toast parent: "the layer root" (7.5) against "mount in slot TopCentre" (10).** The component takes either. Its root is anchored (0.5, 0) and placed at `floor(parent.AbsoluteSize.X / 2), 0`, which is 0,0 in a zero-size slot and the top centre of a full-size parent. `ToastClient` passes `layer.Slot("TopCentre")`. Under a full-size parent the component does not add the top-bar offset itself.
2. **Toast root name.** 7.5 says the component "builds `Stack`"; the convention says the default name is the component name. The root is named `Stack` (the Classic name), `props.Name` overrides. Tree in play: `SharedTopNotification.Root.SlotTopCentre.Stack.Card1..3` (Classic had `Stack` directly under the ScreenGui; nothing reads it by path).
3. **`Text.Measure(text, role, ctx, maxWidth)`**: I pass `maxWidth` in **real pixels** (the return is real pixels). If agent C reads it as a design value, wrapped toasts are measured slightly wrong at scales other than 1; the TextBounds fit below corrects a card that is too short, not one that is too tall.
4. **Confirm has no `scope` argument and the kit may not create `Core.ConnectionScope`.** Overlay carries a small private scope with the same four methods. Every component here builds into such a private scope and adds one release function to the caller's scope, so `Destroy()` can release everything without reaching into the caller's scope (the function left behind is repeat-safe).
5. **`Modal.Height` nil.** Passed to `Surface.Panel` as absent; the modal's inner frame then uses `AutomaticSize = Y`. Whether the panel itself grows depends on what `Surface.Panel` does with no height. With a height, the inner frame fills the panel below the title.
6. **`Modal.Content`** is my frame named `Body` inside `panel.Content`, below the title row. `Build(content, scope)` receives the modal's private scope.
7. **Modal focus trap.** A trapping `Input.FocusGroup` and `Input.BindBack` are created per opening in a per-opening scope and released at `Close`. Buttons are found with `GetDescendants` on the content at each `Open` (`Selectable` GuiButtons, `group.Add(button)` with no order).
8. **`Set({MaxCards = n})`** grows or shrinks the pool (the only time cards are created or destroyed after build).
9. **Test hooks**, following `Switch._resolve`: `Overlay._toastText`, `_toastDuration`, `_toastPick` (pure) and `ToastClient._bindable(folder)`. Not for callers.
10. **Requires in `ToastClient` and `Fixtures.Overlay` are resolved lazily** (inside `start()` and on the first mount), so the test harness can load both without a `script.Parent.Parent...` chain. `ToastClient` also requires `Core.ConnectionScope` (allowed for owners) with `FindFirstChild`, never a wait.
11. **`ctx.Changed` and `Text.ReadyChanged`** are connected only if non-nil, in case `Metrics.Fixed` returns no signal.

## Where Classic behaviour is not matched exactly

Toast

- **Card not shown until measured.** `Show` returns at once and starts the duration timer at once (as Classic), but the card appears only when `Text.Measure` returns in its own thread. On a cold font that can be a few tenths of a second; if the timer ends first the card never appears.
- **`Count()`** counts cards whose timer is running. A card fading out (0.12 s) is not counted, which is when Classic had already removed it.
- **Pool order.** A new message takes an idle card first (least recently used), else the oldest showing card. Newest is at the bottom, as Classic.
- **Text is centred** as Classic; the previews show left text with an icon. No icon, kind or edge colour exists in the API, so every card has the neutral white edge and no top hairline.
- Same text while its card is showing restarts the timer and does not add a card (contract addition).
- No yield between creating the bindable and connecting it, as Classic; a fire in that gap is still lost in both.

Confirm

- **Scrim covers the safe area only.** `Layers.Create` gives one `DeviceSafeInsets` ScreenGui; Classic's backdrop used `ScreenInsets.None`. I did not use `Scrim = true` because it adds a second ScreenGui (`SharedConfirmationOverlayScrim`) that a Classic confirmation replacing ours by name would not remove. Integrator's call.
- **`ZIndexBehavior`** is Sibling (Layers), Classic used Global. Internal only.
- **Replacement.** An open Pulse confirmation that is replaced (by a Pulse or a Classic one) is cancelled once and its `OnCancel` runs; Classic left the replaced one bound until the next Escape. A Pulse replacement cancels the old one before reading `GuiService.SelectedObject`, so the restored selection is the original one.
- **Selection restore is protected**: if writing the saved selection fails, selection is cleared instead of leaving the overlay half closed.
- **Deferred NO focus** has one extra guard (`IsDescendantOf(game)`), for detached hosts in tests.
- **Layout**: left-aligned body, buttons right-aligned and sized by `Controls.Button` (min width `ButtonHeight x 2` for both), title role `SectionHead` with the title mark (image, or a Pink block when the asset is empty), panel 650 wide and auto-height. Classic was a fixed 650 x 270 with centred text and two 270-wide buttons.
- The panel is built from Tokens plus `Surface.Hairline`, **not `Surface.Panel`**, because body auto-height needs a panel whose height I control. `Modal` does use `Surface.Panel`.
- Context action name is `Pulse_ConfirmExit_<n>` (API 9), bound directly at priority 10000 with Sink, not through `Input.BindBack`, so the Classic semantics do not depend on that helper.
- If the build throws, the layer and scope are released and the error is rethrown; nothing stays bound.

## Check in Studio (integrator)

1. **Compile** all three sources (E1) and run the lint: `Vector2.new(0.5, 0)` (the slot anchor) and `UDim2.fromScale(1, 1)` (full-size shade and modal root) are the only scale values; the fixture has a timed refresh loop (`task.wait(8)`), which is not a presence poll.
2. **U7**: `ActivityClient`, `GarageUI` and both HUD entries `ready`; `PlayerScripts.Runtime.UI` exists before start (AUDIT).
3. **U5/U6**: card widths are even and positions whole; `TextFits`; churn 0 after any toast (tweens are created once per card and are never parented).
4. **Baseline shift**: toast and confirm body text use `Text.Font("Body")` and `Text.SizeFor` on a plain TextLabel (I need explicit sizes and transparency), so `Type.BaselineShift` is not applied there. Look at vertical centring of upper-case toast text.
5. **Largest text setting**: a card grows in height from the label's `TextBounds` when the engine enlarges the text; it does not widen. Check the result at Largest.
6. **Title holder**: the confirm and modal title row is a fixed `ceil(textSize x holderScale)` high and the `Text.Label` holder is placed at x = mark + gap. Check the title sits in the row at R720, R1440 and both Compact presets.
7. **Confirm centring** is computed from `AbsoluteSize` (whole pixels, no scale anchor). Check there is no one-frame jump when it opens, and its position under the gallery's `StageHolder` UIScale.
8. **U10** in the gallery: the fixture leaves a `ConfirmFixture` frame on the stage with attributes `ConfirmResult` (`Open`, `Cancelled`, `Confirmed`) and `ConfirmCloses`, and an `OPEN CONFIRM` button; the modal fixture has `ModalOpen`, `ModalCloses`. Fixtures parent the overlay into the ancestor named `Stage` when there is one, so a nil-slot anchor of zero size still gets a full-stage scrim.
9. **Destroying path**: destroy `SharedConfirmationOverlay` by hand while a Pulse confirmation is open; expect one `OnCancel`, Escape free again, no error (the layer is released in a deferred call).
10. `Tween:Cancel()` on a tween that never played, and `ContextActionService` / `Input.FocusGroup` in Edit under the test harness, are assumed harmless.
