# FreeRoam family, B half (touch, activity, core UI policy, RouteGuide getter): notes

Status: **generated, not installed, never run.** There is no offline Luau; every file was desk-checked line by line, block balance was checked by a tokeniser, and the fork was assembled and diffed by `forks/assemble_touch_fork.py`. The kit v2 sources that existed in `phase2/kit/k1..k4/after` when this was finished were read to check call shapes (Touch, BigNumber, Controls, Collections, Surface, Text, Layers, Metrics, Presence, Data); they may still change.

## Files (all under `scripts/ui_restyle/phase2/families/free_roam/`)

| File | What |
|---|---|
| `after/…UIPulse.FreeRoam.TouchControlsView.lua` | Builders and placement over `Kit.Touch` |
| `after/…UIPulse.FreeRoam.TouchControlsClient.lua` | **Hand-assembled review copy** of the fork (the fork tool output replaces it) |
| `forks/FreeRoam.TouchControlsClient.json`, `.span1.lua`, `.span2.lua` | The fork: Classic lines **22-103** and **176-192** replaced |
| `forks/assemble_touch_fork.py` | Rebuilds the review copy; `--check` proves kept lines and state/attribute lines are unchanged |
| `after/…UIPulse.FreeRoam.ActivityHudView.lua`, `…ActivityHudClient.lua` | Activity host: view, and client with the headless model as `_newModel` |
| `after/…UIPulse.Shell.CoreUiPolicy.lua` | Core UI policy |
| `after/…UIPulse.Dev.Fixtures.FreeRoamActivity.lua` | Gallery fixtures for the two B surfaces (see Q1) |
| `before/…UI.RouteGuide.lua`, `after/…UI.RouteGuide.lua` | Byte copy of Classic, and the edit. `diff` = `91a92,94`, three inserted lines, nothing else |
| `tests/…TouchControlsView_test.lua`, `…ActivityHudView_test.lua`, `…ActivityHudClient_test.lua`, `…Shell.CoreUiPolicy_test.lua` | Pure tests (API1 13 shape) |
| `contract_b.json`, `routes_b.json`, `spec_ops_b.json`, `NOTES_b.md` | Shared fragments, B half |

## Touch fork: side by side

Kept byte for byte (checked by the script): lines 1-21 (start guard, services, the `TouchEnabled` gate at 12, waits, `M` at 20), 104-175 (input, thumbstick, tilt, mode), 193-208 (render step, print, start guard tail).

**Every `MobileDriveInputState` write, Classic against Pulse:**

| Write | Classic line | Pulse |
|---|---|---|
| `M.Refresh()`, or the four fallback assignments `M.Throttle / M.Steer / M.Drift / M.Boost` | 108-109 | same line, kept |
| `M.AnalogDrift = on` (TiltDrift) / `M.State[action] = on` | 114 | same line, kept |
| `M.SetSteering(steer, drift)`, or `M.AnalogSteer / M.AnalogDrift` + `refresh()` | 126 | same line, kept |
| `M.State[key] = false` for every key | 161 | same line, kept |
| `M.AnalogDrift = false` | 162 | same line, kept |
| Reads `M.IsDriving`, `M.AnalogDrift` | 197, 200 | same lines, kept |
| Read `M.BoostPercent` | none | **new**, span 2: drives the boost charge ring (API2 3.8). A read only |

No write to `M` exists in either replaced span, in Classic or in Pulse.

**Every attribute use:**

| Attribute | Classic | Pulse |
|---|---|---|
| Player `MobileControlMode` write `"Arrows"` (no gyroscope) | 166 | kept |
| Player `MobileControlMode` write default mode when unset | 173 | kept |
| Player `MobileControlMode` read and changed signal | 153, 172, 174 | kept |
| Player `MobileFreeRoamCarMenuOpen`, `MobileMajorMenuOpen` read | 197 | kept |
| Config `DefaultControlMode`, `TiltDeadzoneDegrees`, `TiltMaxDegrees`, `TiltSmoothing` through `A()` | 154, 165, 173, 200 | kept; `A()` itself (Classic 31) is copied unchanged into span 1 |
| `Config.Vehicles.MobileControls` `DriftEnterThreshold`, `DriftExitThreshold` | 132-133 | kept |
| Button attribute `ControlVisual` = Arrow / Pedal / Default | written 54, read 67 | written in span 1 with the Classic `visualKind` (copied); no longer read (`pressed` calls `SetPressed`) |
| Button attribute `UIAudioSuppressClick` = true on the nine controls and `ThumbstickHit` | 54, 95 | written in span 1, same instances, same value |
| 15 look and layout config attributes and 5 asset lookups | 53-92, 179-189 | **dropped** (listed in `contract_b.json`) |

**Bindables and remotes:** none in Classic, none in Pulse.

**Locals the kept code reads, and what span 1 gives it:** `A`, `PINK`, `CYAN` (token colours), `gui` (a proxy whose `Enabled` is the layer root's `Visible`), `root` (`DriveRoot`, a child of the layer root, so line 197's write cannot feed its own read), `pressed`, the seven control buttons plus `tiltDrift`, `tiltRecenter` (real TextButtons), `thumbHit`, `thumbOuter`, `thumbKnob` (real instances; the knob is a centre-anchored child of the outer pad because line 135 writes its `Position` as a scale), `outerStroke` (proxy: a `Color` write recolours two hairlines), `tiltStatus` (proxy: `Text` and `Visible` go to the kit label's `Set`). Span 2 gives `layout`.

Every control root is a **TextButton**, as in Classic (line 54). `Kit.Touch` takes `Class`; the default is already TextButton, so it is not passed.

## Classic behaviour not reproduced exactly

Touch:
1. **Sizes and offsets are no longer config-driven.** `PedalSize`, `PedalBottomOffset`, `PedalRightOffset`, `PedalGap`, `ArrowWidthMultiplier` and the opacity attributes are not read. Sizes are `ctx.Dp(Sprites.Touch[..].HitDp)`; margins are the kit margins. Positions follow the Classic arrangement, not Classic's pixels.
2. **Boost now has a pressed look and a charge ring** (Classic Boost ignored `pressed`).
3. **Thumbstick is square and flat** (slate pad, two hairlines, square knob). `Kit.Touch` has no thumbstick art and a family view may not use `UICorner` or an asset key. `InnerTurnRing` is not built. Pad side = the arrow cluster's larger side (about 120 dp; Classic `clamp(vp.Y x 0.265, 132, 188)`), knob = `CompactHudButton` dp.
4. **Tilt group is a bottom-left stack** (status, RECENTER, drift). As in Classic, the status line can touch the Boost button's box.
5. Layout reads the layer root (safe area), not the camera viewport, so the controls move in from a notch.

Activity:
6. **Scale.** Classic `clamp(vp.Y / 720, 0.55, 1)` / `clamp(min(x / 1920, y / 1080), 0.72, 1.12)` is replaced by the kit scale on the design root. The Duel button is therefore larger on a phone (kit dp, not 0.55 x).
7. **Duel button look and size** are the kit's (`Controls.Button`, size Hud, width follows the text). `Size`, `Color`, `StrokeColor`, `TextColor` are accepted and unused.
8. **Rank-up waits by signal, not by a 1 s loop**: the same `racing()` rule, re-checked on `RaceQueueActive`, `SeatPart`, the seated vehicle's attributes and character changes, same 600 s limit. The card appears at the moment the race ends, not up to 1 s later. A vehicle attribute that changes while the player is not seated in it is not observed (then the 600 s limit applies).
9. **One rank-up card at a time**; no scale pop (no UIScale tween). Card text is Classic's `RANK <n>`; the mockup's `6 → 7` is not drawn because the payload carries only the new rank.
10. **Offer buttons are reordered** so the main (accept) button is right-most [seen r17]; the stake menu order is unchanged. Accent meaning is mapped by value: `Theme.Telemetry` = main button, `Theme.HighSpeed` = Buy.
11. **Strip:** white text with a coloured left edge (Classic coloured the text and stroke). The X stays for every kind, Passenger included, as in Classic (r17 draws none for a rider).
12. **Theme values are Pulse tokens.** `ElectricBlue` (courier beacon, parcel band, map marker colour) is Violet: the palette has no blue. `Theme.Font` is `Text.Font("Label")` (a `Font`, Classic had `Enum.Font`); no view reads it.
13. `ctx.UI.Label` returns a proxy over a kit label, not a TextLabel. None of the five views calls it.
14. Countdown number is capped at 99 (two image cells). "GO!" is text: the digit sheets have no letters.
15. If the full map is open when a countdown passes zero, the card is removed when the map closes (the live step does not run while hidden).

Core UI: nothing Classic to compare (Classic has no owner).

## API and seam questions (the reading used is in brackets)

- **Q1 Fixtures.** `Dev.Fixtures.FreeRoam` is the A half's module, and one module has one owner. [I wrote a 13th module, `Dev.Fixtures.FreeRoamActivity`; merge it into A's or install it as is. It builds its own `Layers.Stage` on the gallery's `Stage` ancestor because a view needs a whole layer, not a slot.]
- **Q2 Fork header and Claim.** API2 5.3 lists exactly two replaced spans, so lines 1-2 of the fork are Classic's (`-- Canonical feature implementation…`), not the API2 6.6 header; the Pulse header is the first two lines of span 1 (file lines 22-23). `Claim("TouchControls")` is the first statement of span 1, which is after the kept `TouchEnabled` gate (12) and the kept waits (15-20). [Literal two spans. If the header must be line 1-2, add a third span for line 1.]
- **Q3 Lint against the kept ranges.** API2 6.6 rule 4 exempts kept ranges from rules 5, 6 and 9 only. The kept code also has `RunService.RenderStepped` (196, rule 7), per-frame `GetAttribute` (197, 200) and `WaitForChild` in an input handler (132-133). [Kept, as 5.3 orders; the lint needs a fork exemption for rule 7 in kept ranges.]
- **Q4 Job strip slot.** No slot is assigned. `TopCentre` is the toast slot. [`TopCentreHud`; on Compact pushed down by one action tile hit box plus `TouchGap`, because the Compact action bar is top centre.] On Regular the strip (y from `Px(40)`, `StatusHeight` high) and a toast card (from `barBottom + 10`) overlap while a toast shows. Classic had the same closeness. A slot or a token would settle it.
- **Q5 Offer slot.** [`PromptStack` on the live layer.] A world prompt banner (`PulseWorldPrompts`, same slot, lower DisplayOrder) can sit under an offer for its 15 s.
- **Q6 Countdown and rank-up share slot `Centre`** and can overlap if a rank-up lands during a duel countdown (Classic placed them at 0.42 and 0.36 of the height).
- **Q7 Design root.** API2 6.6 rule 2 puts the design-pixel `UIScale` in `ActivityHudClient`, so the client (not the view) builds `DesignPixels` + `DesignScale` under the layer root named `DesignRoot`. Kit components inside it would be scaled twice, so the frame is bound to `Metrics.Fixed` at a reference size (scale exactly 1, same class). A class change (Compact to Regular by window resize) does not restyle the already-built Duel button.
- **Q8 "Clears the bottom row" without repeating view numbers.** The root's bottom edge is lifted by `max(0, row + gap - offset)`; `offset` is read from the Duel button's own `Position` (the view writes `1, -120` or `1, -84`), `row` is `HudBottom + HudButtonHeight` (Standard) or bottom + gauge size (TouchDrive). Results: phone 0, desktop 10 design px, touch tablet 158.
- **Q9 Chat mechanism.** [`StarterGui:SetCoreGuiEnabled(Chat, …)`, measured working in Phase 0.] `Kit.Metrics` cannot hear that call (the core-gui changed signal is not connectable), so `ChatKeepOut` is refreshed only by its other signals. If a layout pass runs while chat is off and none follows when it returns, top-left HUD content can sit over chat. Alternative if seen: toggle `ChatWindowConfiguration.Enabled` and `ChatInputBarConfiguration.Enabled`, which Metrics can observe.
- **Q10 Chat blocking kinds.** API2 5.3 says every kind except `Race` [used: FullMenu, Garage, Results, Map, Modal, SidePanel, Loading]; PC 7.1 names only full menu, garage, results and map. So a HUD modal or the car side panel also hides chat.
- **Q11 `IsMobile`.** Classic line 32 is outside the model ranges API2 lists. [Kept: `TouchEnabled and not KeyboardEnabled`, so the Duel view picks the same branch as in Classic.]
- **Q12 World beacon.** Classic 219-233 is copied (API2 5.3 model range), so `ActivityHudClient` holds stud and light literals (260, 6, 130, 0.45, 40, 2). They are world art, not UI pixels; lint rule 6 needs to allow them or they need tokens.
- **Q13 `RouteGuide.GetRouteState`** is inserted as exactly the three lines of API2 5.3, with no blank line before it.
- **Q14** The spec op `b_folder_freeroam` duplicates A's folder op; keep one. `b_folder_shell` creates `UIPulse.Shell` (first module there).

## What the integrator must check in Play (TouchDrive emulator unless stated)

1. **Input-state trace, Classic against Pulse**, each mode (Arrows, Thumbstick, Tilt if a gyroscope is emulated): press and release each control, two fingers, slide off a button, open the car menu while holding accelerate (inputs clear), leave the seat while holding (inputs clear).
2. Controls show only while driving and with `MobileFreeRoamCarMenuOpen` and `MobileMajorMenuOpen` false; `PlayerGui.MobileDriveControls_Phase1.Root.DriveRoot.Visible` follows it; the ScreenGui's `Enabled` is never written.
3. Thumbstick: the knob travels inside the pad, the drift colour swap works (knob Pink, hairlines Cyan), release recentres.
4. Mode switch from the HUD settings (`MobileControlMode`): the right nine controls show and hide; RECENTER writes "TILT CALIBRATED".
5. Positions against `c02` and `c20` at 844 x 390, 568 x 320 and a tablet; nothing overlaps the HUD half's gauge, Exit button, minimap or status chip; 8 dp between touch targets; Boost ring follows the gauge's boost percent.
6. Classic onboarding finds `DriftLeft`, `DriftRight`, `Boost` (mobile driving cards D7, D8) and the callout sits on them.
7. Console: `[MobileDriveControlsClient] Compact boost plate and touch controls active.` still prints (kept line); no error from the proxies.
8. Activity: a taxi fare and a courier job end to end (strip text, X cancels with "JOB CANCELLED", beacons, route), riding as a passenger (strip), a duel if a second client is available (CHALLENGE button position above the bottom row on desktop, phone and tablet; stake menu; countdown digits, "GO!"; result toast). Otherwise drive the states through the gallery item `FreeRoam.ActivityHud`.
9. Compact stake menu with four options: does the button row fit `CompactPromptWidth`? (Not provable offline.)
10. Strip against toasts (Q4), offer against a world prompt (Q5).
11. Full map open: both activity layers hidden by root `Visible`; closing restores them.
12. Rank-up: fire in free roam (card for 3.5 s, reward chip text equals Classic's amount format) and during a race (appears when the race ends).
13. Core UI under Pulse: player list, health, backpack gone; chat hides on race menu, garage, map, a HUD modal, and returns; chat stays in a race; Select no longer starts engine GUI selection; chat window face and colours changed; then switch to Classic and confirm core UI is untouched (the module is never required).
14. `ClientBase.StartupState`: `MobileDriveControlsClient`, `ActivityClient`, `PulseCoreUiPolicy` all `ready`; on a non-touch device the touch entry is `ready` with no gui and no claim.
15. Budgets by probe: `ActivityHud` static writes 0 while a strip text is unchanged; `ActivityHudLive` hidden with nothing live; touch controls 0 writes per frame while idle.
