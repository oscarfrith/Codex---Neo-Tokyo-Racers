# Mobile pass (2026-10-10): shared brief for family agents

Owner request (Oscar): "test and fix up all the mobile UI, lots of it isn't arranged correctly, and check the PC UI is
all working well. Fix anything wrong and clean everything up."

You fix one family of the Pulse UI (Roblox, Luau) so that it is correct on a phone, without changing how it looks on
desktop. You edit repo source only. The integrator (the main session) installs into Studio, captures and Play-tests.

## Hard rules

- No Roblox Studio tools, no git commands (read-only `git diff` on your own files is fine).
- Edit only the files listed as yours in your task. If a kit file (`scripts/ui_restyle/phase2/kit/**`) must change,
  do NOT edit it: write the exact change you need (file, function, old text, new text, why) in your report under
  "Kit requests". Several agents run at once and the kit is shared.
- Desktop (ctx.Class == "Regular") layout and look must stay exactly as they are unless you find a desktop bug; say
  so explicitly if you change anything a desktop player would see.
- Reuse kit tokens, text roles and `ctx.Px` / `ctx.Dp` / `ctx.Touch`; no copied pixel coordinates, no new colours.
- Kit components are `Kit.X(parent, props, scope) -> {Instance, Set, Destroy}`; they throw on unknown props and
  re-write their own `Visible` on `Set` (use `Set({Visible = ...})`). `List`/`Rail` `OnSelected` fires only on a
  change of selection; use `OnActivated` for actions.
- After editing run, from the repo root, and fix what they report in your files:
  `py -3 scripts/ui_restyle/phase2/tools/check_kit_calls.py` (must stay at 0 ERRORs) and
  `py -3 scripts/ui_restyle/phase2/tools/lint_phase2.py <family>` (no new findings).
  There is no Luau interpreter on this PC: re-read your diffs for syntax.

## What a phone is here

- The kit's screen context (`Kit.Metrics`, `scripts/ui_restyle/phase2/kit/k1/after/...Kit.Metrics.lua`) gives
  `ctx.Class` ("Compact" on phones: safe height < the compact threshold), `ctx.Arrangement` ("TouchDrive" when the
  device has touch), `ctx.Input`, `ctx.Scale`, `ctx.Size` (safe area in px), `ctx.TopBarKeepOut`.
- Reference phone: 844 x 390 px landscape (also check your arithmetic at 568 x 320). `ctx.Px(n)` converts design
  px to screen px; on a 390 px high phone the Compact scale is about 1.0, so a design value of 96 is about 96 px of
  a 390 px screen: far too big for most things. Read `Tokens.Scale` and `Tokens.Space` in
  `kit/k1/after/...Kit.Tokens.lua` for the real numbers before judging sizes.
- Roblox's own top-left buttons occupy about 120 x 52 px on a phone (`ctx.TopBarKeepOut`); the touch driving
  controls occupy the bottom-left and bottom-right corners while driving.

## Owner's standing preferences for phone (from earlier reviews)

- Phone UI is small and keeps clear of the middle of the screen; show as much of the world as possible.
- Free-roam action buttons (car, garage, races, dealership, settings) sit top centre on phone.
- Buttons go above carousels/rails, on the rail's heading line.
- Stats stay visible in the phone dealership.
- No drop-downs on the phone My Vehicles panel or on race entry.
- Minimap ring with the rank arc around it; tier colours as the game defines them.
- Touch driving controls keep the current game's arrangement, restyled.

## Defect classes seen in the phone captures so far (look for these in your family)

1. Text or numbers far too large for the phone (e.g. the free-roam speed number is taller than the gauge it sits
   in and overlaps the EXIT button; the activity strip text is wider than the screen).
2. Elements placed partly off-screen (touch brake/accelerate buttons hang below and right of the screen edge).
3. Elements overlapping each other (tier badge over the "OWNED" chip on vehicle tiles; cash chip under panels;
   HUD buttons showing through a modal's scrim).
4. Selected state unreadable (white tile with white text).
5. Tiles/rows too small to show their picture; clipped rows at the bottom of a panel.
6. Things that should be hidden on phone still shown, or missing things that should be there.

## Captures

Captures are JPEGs of the whole Studio viewport, 1920 px wide. The phone preview (844 x 390) is the dark slate
rectangle at about x 724..1509, y 462..825 of the image; its label (item | state | preset) is the text line near the
top. Anything drawn outside that rectangle is OFF-SCREEN on a real phone. Crop and upscale the rectangle with
Pillow (`py -3`) to look closely, e.g. crop box (700, 440, 1540, 850) then resize x2, save under
`scripts/ui_restyle/phase2/mobile_pass/work/<family>/` and Read the PNG. The previews come from the dev gallery,
which mounts each fixture in `...UIPulse.Dev.Fixtures.<Family>.lua` with a fixed phone context; the fixture state
names tell you which props were used. States that were not captured still need to be right: reason about them from
the code.

## Report (your final message)

1. Each defect you found: screen, state, cause (file:line), fix.
2. Files changed.
3. Kit requests (exact).
4. Anything a desktop player will see differently.
5. What you could not verify and what the integrator should look at in the phone preview.
