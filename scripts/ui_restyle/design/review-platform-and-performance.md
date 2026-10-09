# Adversarial review: Roblox engine correctness and performance

Date: 2026-10-09. Reviewer lens: engine behaviour, sharpness, phone cost, measurable budgets.
Read-only. Studio "Space Racers v3" (93959280828322), Edit, Studio 0.742.0.7421053. Probes used only unparented
temporary instances, destroyed straight after. Nothing was parented, no Play session, no repo file changed.
Inputs read: proposals A, B, C in full; critic, foundation-startup, docs-and-delivery, roblox-platform, fonts-assets in
full; the style sheet; mockups 01, 02, 04, 05; targeted sections of the garage and activity notes.

Legend: [probe] measured in Studio today, [src] read from live source today, [doc] Roblox docs fetched today,
[staff] Roblox staff post fetched today, [calc] my arithmetic, [est] my estimate.

## 1. What I checked, and the result

| # | Check | Result |
|---|---|---|
| 1 | TextSize cap | [probe] 200 reads 100; 100.6 reads 100; 17.6 reads 17 (floor, not round); `UITextSizeConstraint.MaxTextSize` 300 reads 100; `GetTextBoundsAsync` gives 420 px for CUSTOMISE at size 100 and at 200. Confirmed |
| 2 | Barlow faces | [probe] `rbxassetid://12187372847` italic widths at 40: SemiBold 344.67, Bold 348.67, ExtraBold 351.33, Heavy 353.33. Four distinct faces. Digits proportional (ten 1s 119.33, ten 0s 186.67). A bogus id errors ("Request asset was not found"). Confirmed |
| 3 | **Logical pixels are not device pixels** | [probe] `Camera.ViewportSize` and `GetInsetArea` in this Studio = **2065.33 x 1152**. A fractional viewport means Studio draws at 1.5 device pixels per unit on Oscar's PC (3098 x 1728). `GetResolutionScale` and `GetScreenResolution` are RobloxScript-only, so no script can read the ratio. [staff, 2026-03-05, thread 4473249] for the player client: "This is intended functionality: offset is a logical unit that is scaled by the device display setting." [staff, 2025-05-30, thread 3189504] blurry UI came from "all UI being rendered slightly (<1 pixel) misaligned from the pixel grid"; lopsided squares are "a separate pixel-snapping bug"; Studio fix enabled, client fix "soon" |
| 4 | UIShadow | [probe] Instantiates. Properties: Color, Transparency, Offset (UDim2), BlurRadius (UDim), Spread (UDim2), Mode, Inset, ShowBehindParent (true), Enabled, ZIndex (-1). [doc] no text, no inset, no Path2D. [staff] 2026-06-23 "fully released and available to publish"; the 2026-06-04 post still said a client release was "in the near future"; no platform list. **Live phone status still unverified** |
| 5 | Flex, PreferredInput, ViewportDisplaySize, PreferredTextSize | [probe] all present. `Enum.PreferredInput` = KeyboardAndMouse, Gamepad, Touch, MicroGamepad. [doc] a `UITextSizeConstraint` holds text inside its limits "regardless of the player's setting", and TextScaled text is not scaled by it, so the engine scales ordinary text by itself. Multipliers are not published |
| 6 | Safe-area API | [doc] `GuiService:GetInsetArea` is Security None; the Rect is relative to the CoreUISafeInsets area. [src] Foundation 396-409 wraps it in `pcall` and silently falls back to the full viewport. [doc] `TopbarInset` has no stated coordinate space. Never seen on a notched device in this project |
| 7 | Gamepad selection | [probe] `AutoSelectGuiEnabled` and `GuiNavigationEnabled` default true. [src] zero script hits for `AutoSelectGuiEnabled`; `SelectedObject` only in Foundation; FullMapUI 723 binds `ButtonSelect`, the same button the engine uses to start GUI selection |
| 8 | Start-up and replication | [src] ClientBase 105-109 resolves with `WaitForChild`; lines 3-4 index `Modules.Core.ClientLifecycle` directly. No script waits for `game.Loaded` except the loading script's poll. [probe] ReplicatedStorage child order: Modules (153), Config (1,820), Remotes (25), Assets (9,912). `Config.UI` has 17 children, no attributes; a new `Style` child would be 18th, after `LoadingSystem` (10th) |
| 9 | MapIconLayer | [src] 274-275 host `Project` and `Size` exist; 304 `x == x and y == y` hides NaN. A's claim holds. Also 314-317: every shown marker gets a scale-based Position write, pulse markers a UIScale write, and one new table, every frame |
| 10 | RouteGuide | [src] pip and chip are parented to `options.Container` (219, 237). The chip takes an `Enum.Font` (234), so it cannot show a Creator Store face. Two or more frames per route segment |
| 11 | Garage host and open signal | [src] `GarageComponents.CanonicalHost` 294-311 adopts any ScreenGui named `CanonicalGarageGui`, resets DisplayOrder 40 and adds a 1600x900 canvas with a UIScale. `GaragePreviewPresentationClient` 77-91 (shared, never routed) treats a visible `CanonicalGarageGui` as a second garage-open signal beside `GarageSessionActive` |
| 12 | World prompts | [src] TimeTrialServer 1298, 1311 assign `Style = Default` on every ensure. Assigning an unchanged value does not replicate [inferred], so a local Custom should survive unless the prompt is recreated. GarageEntranceClient 152-154 sets Default once at creation |
| 13 | "One mobile test" | [src] `TouchEnabled` appears 37 times in 24 scripts, including shared modules no proposal routes: PreviewCameraClient 39, ThrustPreviewClient 71, VehicleVFXClient 1078, DrivingCameraClient 381, CharacterSprintClient 110 |
| 14 | `tnum` | [probe] `OpenTypeFeatures = "tnum"` is accepted on an unparented label. Effect not measurable without parenting |
| 15 | Activity views | Activity note 47-51, 68, 499: `ctx.Root` is a design-pixel frame under a UIScale and Duel uses hard-coded offsets |
| 16 | Garage controller | Garage note 129-130, 197-207: every interaction calls a `render*` function that rebuilds the page; `renderUpgrade` and `renderPaintShop` rebuild the 3D preview on every call |

## 2. One finding that breaks a claim in all three

All three say "every size is `round(n x scale)`, so every edge sits on a whole pixel and hairlines are crisp"
(A 4.2, B 4.6, C 4.4). C adds "a logical pixel is a whole number of device pixels". Check 3 shows this is false:

- Roblox applies the operating system's display scale to offsets on the Windows client, by design. A 1920x1080
  laptop at 150% reports 1280x720; at 125% it reports 1536x864. Oscar's own Studio runs at 1.5.
- At 1.5 only even logical values land on a device pixel. At 1.25 only multiples of four do. `hair(2)` at the 0.667
  floor is 1 logical pixel, which is 1.5 device pixels, on the commonest laptop setting [calc].
- Right- and bottom-anchored clusters inherit the fractional part of the viewport (2065.33 here).
- No script can read the ratio, so no proposal can snap to device pixels.

Consequences: integer metrics are still the best available method, but they are not a guarantee; C's lint "every
AbsolutePosition and AbsoluteSize is a whole number" can pass while the picture is soft; and every Phase 0 sharpness
capture taken in Studio on this PC is taken at 1.5 and does not describe a 100% client or a phone.

The same finding changes the scaling story. The 0.667 floor is not an edge case: a 1080p laptop at 150% sits exactly
on it, and the same laptop with the client windowed is below it. Text above TextSize 100 is not an edge case either:
at Oscar's own viewport the scale is 1.067 and a Barlow ScreenTitle needs 102 [calc].

## 3. Proposal A (safest backup)

### Fatal
1. **Layout family is chosen from the preferred input, not from the space available** (4.1). Phone needs "touch is the
   preferred input". A phone with a gamepad attached at start, a laptop whose scaled viewport is under about 650
   units tall, or a small window, all get the Desktop family at the 0.60 floor: a 1080-unit design on a 390 to 600
   unit screen. It overflows. A's own section 11 lists the start-of-session `PreferredInput` value as unchecked.
2. **A's performance budgets cannot be met by A's own method.** The generated `GarageUI` keeps the Classic controller
   text, which re-renders the page and rebuilds the 3D preview on every click (check 16). The minimap reuses the
   unchanged `MapIconLayer` and route renderer, which write per marker per frame and hold two or more frames per route
   segment (checks 9, 10). "20 or fewer instances per click" and "12 or fewer writes per frame" are then either
   missed or measured with the heaviest parts left out.

### Serious
- Group preflight (1.2) requires every Pulse entry module of a group before any owner starts, with a 5 second bounded
  wait per path. Under Pulse this holds up all 46 entries, including driving and audio. From Phase 7 the Shell group
  is decided inside ReplicatedFirst, where ReplicatedStorage is still arriving, so a slow connection silently gives
  Classic. Style must not depend on network timing.
- "HUD script time 0.25 ms on the dev PC" and "writes per frame" are read from the kit's own counters. Classic has no
  counter, so there is no baseline, and nothing measures a phone.
- The route-distance label mirrors the text of a hidden chip that the old renderer keeps updating every frame.
- UIScale stays in two places (title holder, activity frame). Honest, but the title holder is the default path on
  Oscar's own screen, not a 1440p special case.
- Rails do not reserve room for the glow; a ScrollingFrame always clips it.
- `Text.Measure` is synchronous, but a Creator Store face can only be measured through a yielding call or a parented
  label after the face has loaded. No relayout when the face arrives.

### Claims checked
ClientBase 105-109, MapIconLayer 274-275 and 304, RouteGuide 219 and 237: all correct. Barlow widths and the 100 cap:
correct. "Whole pixels" claim: wrong on scaled displays (section 2).

### Best ideas
- Scale from `min(safeH / 1080, safeW / 1600)`: 4:3 tablets and narrow windows keep a usable canvas.
- 9-slice glow as the default until UIShadow is seen on a live phone and PC client.
- Selection image set per component, so Classic screens keep a visible focus box in any mixed state.
- Switch attribute on `Config.UI` itself, which arrives with the instance the loading script already waits for.
- One `Kit.Frame` binding point with counters; glow capped at six.

## 4. Proposal B (most cohesive)

### Fatal
1. **Per-entry fallback with a non-yielding existence test** (1.2). `PathFor` uses `FindFirstChild` at resolve time and
   returns the Classic path if the Pulse module is not there yet. Nothing in ClientBase waits for the game to finish
   loading (check 8). If `Screens.Hud.FreeRoamHud` is late or missing, `DesktopFreeRoamHudUI` resolves to Classic
   (which returns early on a touch device) while `MobileFreeRoamHudUI` resolves to the inert module: **a phone with
   no HUD**. There are no families, so any mix is possible.

### Serious
- Flex rows (`ButtonRow`, 4.6) with Fill or Grow give fractional child sizes, and "content anchors with plain scale
  positions" (4.5) puts centred clusters on half pixels in odd-width parents. Both contradict B's own integer rule,
  and B has no geometry check to catch it.
- `PlayerGui.SelectionImageObject` set to an invisible image leaves every still-Classic screen with no visible
  gamepad focus during the eight build phases.
- Arrangement from `TouchEnabled` puts every touch-screen laptop permanently in the phone arrangement with drive
  controls on screen. It does match the shared modules (check 13), which is its one merit.
- "0.6 ms per frame on a phone" cannot be measured from Studio; the emulator runs on the PC.
- Additive options in `MapIconLayer` and `RouteGuide` put new branches in per-frame code that Classic also runs.
- A kit multiplier for `PreferredTextSize` would double the engine's own scaling (check 5). B flags it; the answer is
  already in the docs.
- The Regular class has no stated minimum canvas. At the floor it is as small as 1500 x 900 design units [calc].

### Claims checked
`ViewportDisplaySize`, `PreferredInput`, `PreferredTextSize`, `UIShadow`, flex exist: correct. "Attributes arrive with
their instance": accepted, standard replication behaviour, not probed. Scale table: correct as arithmetic, but
"3840x2160 gives 2.0" is only true at 100% display scale.

### Best ideas
- Class from geometry only; arrangement and input as separate answers. The only form-factor rule that survives
  section 2.
- Content in `DeviceSafeInsets` ScreenGuis and scrims in a `None` sibling: the engine owns the safe area.
- Scale snapped to steps and relayout only after a resize settles: keeps the glyph atlas small.
- A separate published sandbox experience: the only route in any proposal to a live client and a real phone
  *before* the kit is fixed. UIShadow gated on that check.
- Square minimap fallback by config; rail padding for glow; `Tokens` as a Luau table with config as tuning.
- One HUD owner; budgets for glows and translucent full-screen layers.

## 5. Proposal C (quality and speed)

### Fatal
1. None unique to C. C states the false device-pixel claim most strongly and builds a gate on it (section 2).

### Serious
- All layers use `ScreenInsets = None` and C computes the safe rectangle itself from `GetInsetArea`, an API this
  project wraps in a silent `pcall` fallback and has never seen on a notched device. B's engine-owned route is safer.
- The Desktop composition has width classes only. At the floor the canvas can be 900 units tall, not 1080; the
  commonest laptop case lands there.
- Scale ceiling 2.5 with Barlow puts ScreenTitle, SectionHead, ButtonMain, Button, TileName and Status above
  TextSize 100 [calc]. The proposed caps sprite sheet with a kerning table is a home-made text renderer, and it
  changes title width by about 22% between screens that use it and screens that fall back.
- The digit sheet "at about 300 px cap height" does not fit 18 glyphs in one 1024 sheet [est], and drawing it at
  63 to 95 units is three to five times reduction, against the staff "author at about 2x" guidance.
- UIShadow becomes the default after a Studio Play check only. Studio is not a live phone.
- `Compose` uses the same non-yielding existence walk as B. It is family-atomic, so no missing HUD, but a late
  family breaks the "newer Pulse only meets older Classic" rule (Pulse onboarding with a Classic HUD).
- The switch sits on a new child folder with a 10 second bounded wait, later than an attribute on `Config.UI`.
- "No UIScale anywhere" cannot hold: the unchanged activity views need a design-pixel frame (check 15).
- `CanonicalGarageGui` is forbidden, which removes the second garage-open signal a shared module reads (check 11).
- "Pulse not above Classic in any sample pair" is not a usable test: styles need separate sessions and frame time is
  noisy. "Not above Classic" script time has no Classic counter. "25 MB texture" is arithmetic only.
- "On a phone [relayout] never happens in play": a 180 degree turn under LandscapeSensor swaps the notch side.

### Claims checked
`GarageComponents` 294-311, RouteGuide 34-39 and 89-91 region, ClientBase 104-112: correct. Label 17 at the floor,
TextSize 14 as cap 8: correct [calc]. "Logical pixel is a whole number of device pixels": **wrong**.

### Best ideas
- Spike before any install, then a pilot on the race menu before the HUD.
- The probe set: instance census, churn probe, static-layer write probe, layout lint, capture matrix. The only
  proposal whose budgets are mostly measured from outside the code under test.
- Own Pulse map layers (pooled route segments, own icon layer) with one read-only `RouteGuide` getter.
- Frame loops disconnected while hidden; preview rebuilt only when its input changes; one render token per screen.
- Phone compositions drawn against 844x390 and 640x360; TextSize 14 floor; contrast and HUD-cover budgets.
- Slice glow images uploaded regardless, so the glow method is one token.

## 6. Ranking from this lens

1. **C**: best measurement, spike-first, real per-frame fixes; flaws are fixable by taking B's foundations.
2. **B**: best engine foundations (geometry class, engine safe area, scale steps, live-client test place); one
   start-up flaw that can leave a phone with no HUD, and weak measurement.
3. **A**: best backup, weakest here: input-based layout family, and generated copies and reused renderers keep the
   costs the rebuild is meant to remove.

## 7. The plan I would build

1. **Phase 0 on the right machines.** Record `ViewportSize` and the display scale for every capture. Test hairlines,
   text above 100, glow and the round minimap in the **player client** at 100%, 125% and 150% Windows scale and on
   one iPhone and one Android phone, judged from device-resolution screenshots. Use B's sandbox experience to get a
   live client. Test `tnum`, `TopbarInset` space, the Text Size setting at Largest, and font preload on a cold cache.
2. **Metrics.** One service. Class from geometry only (B). Scale `min(safeH / 1080, safeW / 1600)` (A), floored to
   steps, 0.667 to 2.0, relayout after the resize settles (B). Desktop compositions specified at 1500 x 900 as well
   as 1920 x 1080; phone at 844x390, 640x360 and 568x320.
3. **Geometry.** Integer metrics, stated as "whole logical pixels, best effort". Round edges, not sizes. Hairline and
   spacing tokens chosen even where the design allows. No flex Fill or Grow, no scale anchors for centred content.
   C's layout lint and static probe as gates, plus a device-resolution capture per phase.
4. **Safe area.** Content in `DeviceSafeInsets` ScreenGuis, scrims in `None` (B). Sizes read from the ScreenGui, not
   from `GetInsetArea`. On phones, try the status cluster inside the free top-bar area.
5. **Text.** Cap-height tokens; Barlow pending the capture. TextSize capped at 100 for every non-title role. Titles
   decided by the device-resolution capture: static holder if crisp, otherwise a lower title cap. No kerning-table
   renderer unless the capture leaves no choice. Digit sprites in two authored sizes, ten digits per sheet.
   A `UITextSizeConstraint` on capped roles, counted in the instance budgets.
6. **Switch.** Attribute on `Config.UI` (A, B). Families decided atomically (A, C) with unconditional `WaitForChild`,
   no bounded waits, no existence probes, no up-front requires. The installer AUDIT proves the modules exist.
7. **Performance.** C's rules and probes. Static and live ScreenGuis, live above static. Own Pulse map layers (C).
   Budgets counted from outside: census, churn, writes per frame on the live layer, distinct text sizes. Shared
   modules included in the HUD numbers. Phone frame cost from a MicroProfiler capture on a real device, or not
   claimed.
8. **Glow.** 9-slice default (A); UIShadow only after a live phone and PC check (B). Rails reserve glow padding.
9. **Gamepad.** Decide `AutoSelectGuiEnabled`, make HUD tiles non-selectable while driving, explicit focus entry and
   exit, per-component selection image until every screen is Pulse (A).
10. **Order.** Spike, foundation, race-menu pilot, HUD (C). Activity frame keeps one static UIScale, named as the
    exception.

## 8. Not verified

- How the engine snaps a 1.5 device-pixel line, and whether the 2025 client pixel-grid fix shipped.
- Display scale behaviour on Android, and on the Windows client beyond the staff statement.
- UIShadow on a live phone; crispness of text above 100 under a static UIScale; `PreloadAsync` for font faces.
- Whether ClientBase can run before ReplicatedStorage has fully arrived. Treated as possible, because nothing waits.
- Digit sheet sizes are estimates from Barlow Condensed proportions, not measured from the font file.
