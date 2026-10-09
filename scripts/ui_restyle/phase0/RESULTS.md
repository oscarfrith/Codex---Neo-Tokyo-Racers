# UI restyle Phase 0: results

Date: 2026-10-09. Place: Space Racers v3 (93959280828322). Nothing is installed. No game script, config value or asset in the place differs from the start of the day; nothing was uploaded.

Evidence labels: **measured** = read in Studio by a probe; **seen** = judged from a Studio screen capture; **source** = read from the Classic source record; **open** = not settled.

## What was done in Studio

| Step | Mode | Result |
|---|---|---|
| Classic source record | Edit, read-only | 221 scripts and the typed `Config.UI`, `Config.Development`, `Config.Player` dump saved to `../classic/` |
| `classic/out_verify_classic.lua` | Edit, read-only | Run before and after the Play session: 221 of 221 scripts same, 1,124 config values same, 0 failures |
| Sandbox window (`probes/sandbox_window.lua`) | Edit, attribute write | Opened (`StudioVehicleSandboxEveryPlay` false to true), closed and restored to false; marker removed; checked |
| One Play session | Play, sandbox active | Spikes and Classic baselines below. `StudioVehicleSandboxActive` was true on the player throughout |
| `engine/selftest.lua` | Edit, detached instances only | 30 of 30 cases pass (`results/engine_selftest_result.json`) |

**Play session side effects.** In-memory sandbox profile only: one car bought in the dealership ($50,000), a short drive (+$115), one teleport to a race start, one teleport to the dealership. `ProfileStore` line 68 returns "Save suppressed" before any DataStore call when the session is `NoSave`, so the save timestamp on the runtime marker does not mean a write. No time trial was started. The dealership desk objective was already complete on the saved profile, so approaching the desk wrote nothing.

**How files reached the Play session.** The client cannot fetch files and Play has no `loadstring`. The server datamodel can fetch from the local bridge, so each probe was put in a transient `StringValue`, and the client ran it as the source of an unparented `ModuleScript`. Results came back through a transient `RemoteEvent` to the bridge. All of it lived under one `ReplicatedStorage.UIRestyleProbeRelay` folder that died with the Play session (checked absent in Edit afterwards). `shared` persists between `execute_luau` calls in the same Play session.

## Spike results

Raw JSON: `results/s1_spike*.json`. Captures: `captures/`.

| # | Unknown | Result | Method chosen |
|---|---|---|---|
| 01 | Barlow loads; how to wait for it | **Measured.** ExtraBold, SemiBold and Black Italic load in about 0.3 s on a cold session. `ContentProvider:PreloadAsync` on a TextLabel reports the family as Success; on the bare family string it reports Failure. `TextService:GetTextBoundsAsync` waits for the face and equals `TextBounds`. A missing family falls back silently to a tabular face | `Kit.Text.Ready` = `GetTextBoundsAsync` per face, with the 2 s limit. Preload through a label, never the bare string |
| 01 | Cap ratio, digit widths | **Measured.** Line height equals TextSize. Digits are proportional: at TextSize 100, "1" is 29 px and "4" is 51 px; ten 1s 293 px against ten 0s 467 px. **Seen:** the cap bar drawn at 0.583 matches the capital H | CapRatio 0.583 stands. Fixed-width cash chip; image digits for big numbers |
| 02 | TextSize above 100 | **Measured.** Requests of 101, 120, 136 and 200 read back as 100. `UITextSizeConstraint.MaxTextSize` also stops at 100 | Confirmed |
| 02 | Text under a static UIScale | **Measured and seen.** TextSize 100 under UIScale 1.25, 1.5 and 2.0 gives line heights 125, 150 and 200 and is redrawn sharp, not stretched, at the capture's resolution | Titles above 100 use the text-only static UIScale holder (the contract's named exception). Check once more on a real display in Phase 1 |
| 03 | `OpenTypeFeatures = "tnum"` | **Measured.** The property accepts the value; Barlow's digit widths do not change | Not used. Fixed chip width as planned |
| 04 | Hairlines on the pixel grid | **Open.** Positions and sizes were recorded, but the MCP capture is scaled (viewport 2065.33 x 1152 against a 1920 px image), so sharpness cannot be judged from it. Under any UIScale no item lands on whole pixels | Best-effort rule stands (no UIScale over chrome, rounded whole pixels). Needs a device-resolution capture by Oscar or on a real display |
| 05 | Glow method | **Measured and seen.** `UIShadow` exists (properties `BlurRadius` UDim, `Spread` UDim2, `Offset`, `Color`, `Transparency`, `ShowBehindParent`, `Inset`) but drew nothing visible with the values tried. A 9-slice image drew an even glow with one instance. Stacked strokes band visibly | 9-slice is the default. `UIShadow` stays behind the token, untested with correct UDim values |
| 06 | Gauge reveal | **Measured.** Rotating-gradient reveal: 1 write per frame (max 2), 7 instances. Segment fallback: 1.85 per frame (max 4), 48 instances. **Seen** only on a placeholder texture, so the seam at 12 and 6 o'clock is not judged | Gradient reveal stays primary. Judge the seam with the real ring image once it is uploaded |
| 07 | Safe area and top bar | **Measured.** All four `ScreenInsets` values exist. Top bar is 58 px in Studio. `GuiService.TopbarInset` is (208, 0) to (2065, 58): the free strip right of the Roblox buttons, in `DeviceSafeInsets`/`None` space. A new ScreenGui defaults to `CoreUISafeInsets` | `Kit.Layers` sets `ScreenInsets` explicitly on every ScreenGui. Top slots may sit beside the top bar buttons (from x = `TopbarInset.Min.X`) or below 58 px |
| 08 | Core UI changed signal | **Measured.** `StarterGui.CoreGuiChangedSignal` cannot be connected by game scripts ("lacking capability RobloxScript"). `SetCoreGuiEnabled` and `GetCoreGuiEnabled` work | The trailer-tool exception is recorded. No polling |
| 08 | Chat window | **Measured.** `ChatWindowConfiguration` reports its rectangle (8,12; 475 x 273.5) and accepts `FontFace`, `TextColor3` and `BackgroundColor3` at run time; all three were restored | Run-time chat restyle is available. Top-left slot can read the chat rectangle |
| 08 | `AutoSelectGuiEnabled` | **Measured.** Readable; true today | As planned |
| 09 | Text Size setting | **Measured.** `GuiService.PreferredTextSize` exists (Medium, Large, Larger, Largest). At Medium the multiplier is 1. The other settings are a user preference and cannot be set by script | **Open:** the multipliers. Oscar changes the setting once in Studio and the spike is re-run |
| 10 | Preferred input | **Measured.** `UserInputService.PreferredInput` exists with a changed signal (KeyboardAndMouse, Gamepad, Touch, MicroGamepad) | As planned. Touch laptop and phone-with-gamepad values need the device emulator or hardware |
| 11 | Local `Style = Custom` on a prompt | **Measured**, on foot at a race start (`RaceEntryPrompt`, "Join Race"). Out of range for 14 s: 0 reverts across four server passes. In range for 7 s: `PromptShown` fired once, `PromptHidden` never, 0 reverts, no default prompt UI | Custom prompt banners go ahead. **Open:** the same check while seated in a start zone, and a trigger through `InputHoldBegin` from a banner on touch |
| 11a | Prompt census | **Measured** at the start screen: 9 prompts streamed in, all `Default` style, none needing line of sight (`results/s1_spike11a_start.json`) | Families as in the contract |
| 12 | Attributes at ReplicatedFirst time; ClientBase before ReplicatedStorage | **Open.** Needs a temporary attribute, which is an Edit write. Planned as the first step of Phase 1 with the latch (`spike/12_replicatedfirst_note.md`) | Unchanged |
| 13 | Profiler labels | **Measured.** `debug.profilebegin`/`profileend` and memory categories work on the client. **Source:** the Classic desktop HUD step is the render-step binding `PCFreeRoamHudPhase4A`; the only Classic label is `.WorldLOD.Step` | `Kit.Perf` labels every Pulse frame step. A Classic script-time comparison needs a MicroProfiler capture, not done |
| 14 | `Core.Net` busy lock for the event card | **Source.** No client wrapper; limits are server-side per player. The two `RaceRequest` reads cost one token each of 60, refilled at 20 per second, with no busy lock (`TimeTrialServer` 1330) | Safe as planned |
| 15 | Guide trail colour | **Source.** `GuideTrail.new(config)` only calls `config:GetAttribute`. A second folder would need all 30 trail attributes | Pass an overlay object that answers `GetAttribute`, not a second folder |
| 16 | Two-client local test | **Source.** The Studio tools start one Play client only | Fixture replay plus Oscar's confirmation |
| - | Creating a ModuleScript in v3, save and reopen | **Open.** First step of Phase 1 by contract. The engine's create path passes its self-test on detached instances only | Unchanged |
| - | Real-device frame cost, UIShadow on a live phone | **Open.** Needs a published build | Unchanged |

## Classic baselines

One session, desktop, viewport 2065.33 x 1152 (Oscar's Studio at a scaled display), keyboard and mouse, sandbox profile. Raw files: `results/census_*`, `rec_*`, `lint_*`, `write_*`, `perf_*`, `churn_*`.

### Instances (measured)

| Surface | Total | Visible at that point | Plan's reading from source |
|---|---|---|---|
| All ScreenGuis at the start screen | 1,382 in 20 ScreenGuis | 158 | - |
| `DesktopFreeRoamHud`, built at start | 712 (124 strokes, 66 gradients, 142 corners) | 110 on foot, 167 seated | about 610 |
| ... with Settings open | 712 | 322 | modal 100 to 210 |
| ... with Get Cash open | 712 | 211 | |
| `RaceBrowser` open | 104 | 103 | about 70 per rebuild |
| `FullMap` open | 233 | 139 | - |
| `OwnedGarageBrowser` open | 76 | 73 | - |
| `CanonicalGarageGui`, dealership | 433 | 252 | 300 to 330 |
| ... Customise hub / Parts / module shop / Upgrades | 472 / 577 / 496 / 579 | 150 / 272 / 191 / 278 | |
| `SharedConfirmationOverlay` | 23 | 23 | - |

The Pulse budgets in the contract (HUD at most 260 at start, garage page at most 240 live) stand against these.

### Rebuild on a click (measured)

| Interaction | Added | Removed |
|---|---|---|
| Race menu, select another event | about 70 | about 70 |
| Customise Parts, click one slot | 135 | 216 |

Pulse budget: 0 for both.

### Property writes on the free-roam HUD (measured; same-value writes are invisible to the probe)

| State | Median per frame | 95th | Max | Notes |
|---|---|---|---|---|
| On foot, standing | 0 | 0 | 0 | 8 s |
| Seated, parked | 9 | - | - | 6 s. Map icon `Position` and the player marker, every frame, because the parked car sways |
| Seated, throttle held | 11 | 14 | 32 | 7 s. `Position` 69%, `Rotation` 17%, `Size` 8%, `Text` 5%. The car was near-stationary by the end of the sample (obstructed), so this is not a clean steady-drive figure |

Pulse budgets: 0 parked, median at most 16 driving. The parked figure confirms the plan's point that the shared map icon renderer writes every frame.

### Frame time (measured, Studio, 60 fps cap)

On foot: median 16.69 ms, 95th 17.52, max 19.09. Driving attempt: median 16.66 ms, 95th 17.62, max 18.39. Studio is capped, so this is a floor for regressions, not a cost measure.

### Layout lint, free-roam HUD on foot (measured)

59 of 59 visible objects sit off whole pixels; 13 fractional strokes; smallest effective text 10.67 px; all text in Michroma; HUD cover 3.6% of the screen. Distinct visible text sizes: 4 on foot, 9 in the garage, up to 9 in HUD modals.

### Play record stability (measured)

- Start screen: two records minutes apart gave the same hash.
- Seated: two records 4 s apart differ only in `DesktopFreeRoamHud`. With the ignore list `^MapCanvas$`, `^PlayerMarker$`, `^NorthArrow$`, `^MapIcons$`, `^BoostFill$`, `^GaugeSegment`, `^Vehicle_` two records 5 s apart are identical.
- **Not done:** a second full Play session for run "b" of every point. Cross-session stability (generated vehicle ids, job positions) is unproven; the Phase 1 gate takes the full record twice before it compares anything.

### Capture points reached

`01_start`, `02_on_foot`, `03_driving_parked`, `05b_settings`, `05c_cash`, `06_full_map`, `07_race_menu`, `11_dealership`, `11b_post_purchase_paint`, `12a_customise_hub`, `12b_parts`, `12b2_module_shop`, `12c_upgrades`, `13a_garage_browser`, `14_confirm`.

Not reached: car panel, Controls modal, race entry pages, in-race HUD and exit confirmation, Paint Shop page from the hub, owned-garage interior and desk, results. The file `*_12d_paint_*` is mislabelled: the click landed on the Upgrades page and it is a second Upgrades record.

Facts learned for the capture steps: `user_mouse_input` coordinates are `AbsolutePosition` values (no top-bar offset added); the sandbox profile owns the starter garage `STARTER_TWO_BAY`; the dealership teleport lands 80 studs from the desk; sandbox Cash was 3,613,709, not the configured 1,000,000.

## Deliverables

| Item | Where | State |
|---|---|---|
| Programme contract | `../CONTRACT.md` | Written; fact-check corrections and Oscar's 2026-10-09 decisions folded in |
| Style sheet v2 | `docs/design/pulse-racers-ui-style-sheet.md` | Awaiting Oscar |
| Classic record and verify | `../classic/` | Run in Studio, passing |
| Generated contract tables | `../classic/contracts/` (83 owners, 79 reserved names, 19 onboarding pages and 33 cards, 65 player attributes, 26 ScreenGuis, 69 remote actions; 214 items it could not resolve are listed in `INDEX.md`) | 26 pinned tests pass |
| Installer engine | `../engine/` | 37 offline tests and 30 Studio self-test cases pass. Never run against the place |
| Probes | `../probes/` | Run in Play: census, play record, layout lint, write, churn, perf, both fingerprints (server), sandbox window. Churn used the start/stop pair and writes used the blocking probe. Not run: `churn_probe`, `write_start/stop`, client and saved fingerprints |
| Spike harness | `../spike/` | 01 to 13 run once each |
| Preview frames, desktop | `assets/ui/mockups/pulse_restyle/phase0/regular/index.html` (32 images) | Awaiting Oscar |
| Preview frames, phone | `assets/ui/mockups/pulse_restyle/phase0/compact/index.html` (30 images) | Awaiting Oscar |
| Asset batch | `../assets/out/contact_sheet.png`, `../assets/upload_manifest.json` (18 files) | Generated. Not uploaded |

## Exit gate: what Oscar decides

Approve or change:

1. **Style sheet v2** and the two preview galleries.
2. **The upload batch** of 18 images from the contact sheet. Each upload is made only after his yes. Weak drawings the agent would redo first: checkpoints, duel, drift arrow, LB/RB lettering, set-route.
3. **Open design questions** (defaults in brackets):
   - Garage rail of seven in the wider Barlow face: two-line names, or six tiles? [two-line names]
   - Map markers white, or coloured by family? [coloured by family]
   - Confirmation before buying a vehicle (none today)? [no change]
   - Number spacing for image digits: safe or tight? [safe]
   - Chequered corner mark: white and tintable, or two-tone as in the mockups? [two-tone]
   - Wordmark: the placeholder lockup, or his own art? [his own art; the start screen keeps its current logo]
   - Phone: Boost above steering, as today, or above the accelerator? [as today]
   - Phone: Cash in short form ($3.61M)? [yes]
   - Phone paint arrangement as drawn? [yes]
   - Onboarding highlight in white and pink instead of gold? [white and pink]
   - Hide Get Cash until products exist? [keep as today]
   - Action bar and minimap inside owned garages? [as today]
   - "LOADING NEO TOKYO" text: replace? [yes, with "LOADING PULSE RACERS"]
4. **One request:** set Roblox's Text Size to Largest once in Studio so spike 09 can read the multipliers, or accept that as a Phase 1 check.
