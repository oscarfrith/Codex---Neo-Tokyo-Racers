# Pulse Phase 0 spike harness

Throwaway, Play-only. Nothing here is installed. Status: **generated, not run** (syntax checked by reading and by a
block and bracket balance pass; there is no offline Luau on this PC).

## How to run

1. Start Play (`start_stop_play`). Wait until the start screen is passed and the HUD shows.
2. For each spike: paste the whole file as the `code` of `execute_luau`, `datamodel_type = "Client"`. Edit the
   `ARGS` table at the top first if needed. Each call returns one JSON string and stays under 25 s with the defaults.
   Every wait is a `Heartbeat:Wait()` loop, so Studio does not freeze.
3. Take the capture named in the result's `needsCapture`, then run the next spike (each one replaces only its own
   `PulseSpike_<id>` ScreenGui, so earlier cards stay up until cleanup; run `spike_cleanup.lua` between cards that
   overlap).
4. Finish with `spike_cleanup.lua`, then stop Play.

Rules the files keep: one self-contained file each; only transient client instances (`PlayerGui.PulseSpike_<id>`);
no gameplay module is required; no remote is fired; no saved data; no script is edited. Uncertain APIs are wrapped
in `pcall` and their error text is returned under `errors` or beside the value.

Writes to things the spike did not create, all client-local and restored:

| Spike | Write | Restored by |
|---|---|---|
| 08 | `SetCoreGuiEnabled(PlayerList)` flipped once | Same call, with a retry |
| 08 | `ChatWindowConfiguration` `BackgroundColor3`, `TextColor3`, `FontFace` | Same call in `mode = "probe"`; `mode = "restore"` or cleanup after `mode = "apply"` |
| 11b | Local `Style = Custom` on one ProximityPrompt | Same call; `restoreOnly = true` or cleanup after `leaveCustom = true` |
| 13 | One `BindToRenderStep` named `PulseSpike13_Bound` | Unbound before return; cleanup unbinds again |

`execute_luau` may run at a higher script identity than a LocalScript. A property that is writable here (chat
restyle, `GetScreenResolution`) is confirmed for game code only when a real ModuleScript repeats it in Phase 1.

Cold-cache font answers (01) are only valid on the first run of a fresh Studio session.

## Where each spike must be run

| Spike | Place or state needed |
|---|---|
| 01 | First thing in a **fresh Studio session** (cold font cache). Anywhere |
| 02, 03, 04, 05, 06 | Anywhere. Captures at device resolution; repeat 02 and 04 at 100%, 125% and 150% display scale |
| 07 | Anywhere; repeat in the device emulator with a notched phone |
| 08 | Free roam with the chat window open for the capture. Not during trailer mode |
| 09 | Once per Text Size setting (set in the Esc menu or emulator) |
| 10 | Send keyboard, mouse and gamepad input during the call; repeat in the emulator (phone; touch laptop if available) |
| 11a | Free roam near a start zone; again inside an owned garage; again near another player's car if possible |
| 11b R1 | On foot or in a car **within 24 studs of a start zone** |
| 11b R2 | **Outside** the prompt's range first (`leaveCustom = true`), then move in, capture, `restoreOnly = true` |
| 11b R3 | **Seated in a car parked inside a start zone**, zone centre off screen if possible, `seconds = 18` |
| 12 | Anywhere, soon after start; optional `pollSeconds` |
| 13 | Free roam in a car (so the Classic HUD step runs) with the MicroProfiler open |

## Unknown, spike, and what the result selects

"Primary" and "Fallback" are the methods the plan chose in advance. Fill in **Result**.

| # | Unknown (plan reference) | Spike file | Primary if... | Fallback if not | Result |
|---|---|---|---|---|---|
| 1 | Font preload on a cold cache; which load signal works (6, 4 Measurement, App. C) | `01_font_load_metrics.lua` | `preloadLabel` or `getTextBoundsAsync` returns after the face is usable and `differsFromFallbackControl` is true: `Kit.Text.Ready` = that signal, 2 s cap | No signal: `Ready` = first `TextBounds` change or the 2 s cap, relayout on change; family that never loads falls back to Roboto Condensed | |
| 2 | Barlow has real ExtraBold, SemiBold and Black italics; cap ratio 0.583 (4, 6) | `01_font_load_metrics.lua` | `barlowWeightsDistinct` true and the H matches the bar: tokens as written | Weights collapse: use the weights that differ; H off the bar: correct `CapRatio` and `BaselineShift` tokens | |
| 3 | `GetTextBoundsAsync` against `TextBounds` (4 Measurement) | `01_font_load_metrics.lua` | `equal` true: measurement cache uses `GetTextBoundsAsync` | Differ: measure with a hidden label | |
| 4 | Barlow digits proportional; ten 1s against ten 0s (4) | `01_font_load_metrics.lua`, `03_opentype_tnum.lua` | Expected proportional: fixed-width cash chip, `BigNumber` sprites | - | |
| 5 | TextSize above 100 clamps (4, [review, probed]) | `02_textsize_above_100.lua` view `sizes` | `textSizeClampsAt100` true: roles cap at 100, numbers are sprites | Not clamped: plain TextSize, sprites still used for tabular numbers | |
| 6 | Text above 100 under a static UIScale (3.4, 4, App. C) | `02_textsize_above_100.lua` view `scale` | Rows E and F as sharp as A: text-only static holder for titles above 100 | Soft: titles stop growing at 100 | |
| 7 | `OpenTypeFeatures = "tnum"` (4, App. C) | `03_opentype_tnum.lua` | `tabularAfter` true on Barlow: allowed for the cash chip, chip width still fixed | Not relied on (the plan's default) | |
| 8 | Hairline rasterising; pixel-grid fix; display-scale ratio (3.4, App. C) | `04_hairlines_pixel_grid.lua` | Plain column and KitRule row even at 100/125/150%: rounded whole pixels, `max(1, round(2 x scale))` | Uneven: even hairline values only (2 px minimum); device capture stays the gate. No UIScale over chrome either way | |
| 9 | UIShadow exists and renders (6 Glow, App. C) | `05_glow_methods.lua` | 9-slice stays the default regardless (works on every client) | UIShadow promoted only after it is also seen on a live phone and PC; Studio cannot promote it | |
| 10 | Gauge by rotating gradient; seam; writes per frame (2.2, 5.2, 6 Gauge) | `06_gauge_gradient_reveal.lua` | No seam, 1 to 2 writes per frame: ring image plus gradient | Seam or soft edge: segmented arc | |
| 11 | `TopbarInset` coordinate space; `ScreenInsets` values (3.3, App. C) | `07_safe_area_topbar.lua` | Cyan rect sits in the free top-bar gap under `DeviceSafeInsets`: use raw | Offset: convert with the matching origin in `topbarInsetIfRelativeTo`; else fixed height from `GetGuiInset` | |
| 12 | Core-gui changed signal exists and fires (7.1, App. C) | `08_chat_core_ui.lua` | `firesOnSetCoreGuiEnabled` true: `CoreUiPolicy` re-asserts on it | Trailer-mode exception recorded; no polling | |
| 13 | Chat window rectangle; run-time restyle (7.1, App. C) | `08_chat_core_ui.lua` (`probe`, then `apply`) | Outline matches: top-left slot starts below it. All three writes take and show: restyle adopted | Rect wrong: fixed chat allowance. Writes fail: chat left as Roblox draws it | |
| 14 | `AutoSelectGuiEnabled` readable (7.1) | `08_chat_core_ui.lua` | Reads: turned off under Pulse as planned | Errors: explicit `GuiService.SelectedObject` management only | |
| 15 | Text Size multipliers (4, App. C) | `09_preferred_text_size.lua` | Multiplier measured at Largest sizes body containers; constrained column stays 1.0 | Not readable: Largest capture pass only | |
| 16 | `PreferredInput` on a touch laptop and a phone with a gamepad (3.1, App. C) | `10_input_preferred.lua` | Property reads and its signal fires: Input = `PreferredInput` | `LastInputTypeChanged` mapped to three classes with a hold | |
| 17 | The ten prompt families as the client sees them (7.2) | `11a_prompt_census.lua` | All prompts fall in families 01 to 10, all `Default` | Anything in `99 Other` is added to the Phase 4 contract | |
| 18 | Local Custom survives the server's 3 s re-assert (7.2, App. C) | `11b_prompt_custom_style.lua` R1 | `survivesServerReassert` true | Prompts stay engine-drawn under Pulse (recorded exception) | |
| 19 | Custom before first show suppresses the default UI (7.2) | `11b_prompt_custom_style.lua` R2 | Capture shows no engine prompt; `defaultUi` count does not rise | Same exception as 18 | |
| 20 | `PromptShown` steady while seated in a start zone (7.2) | `11b_prompt_custom_style.lua` R3 | `promptShownSteady` true: Start banner follows `PromptShown` | Start banner uses its own zone-box test | |
| 21 | Attributes at ReplicatedFirst time on a cold start (1.1, App. C) | `12_replicatedfirst_note.md` (Phase 1), baseline from `12_replication_state_late.lua` | Attribute present at arrival: latch reads straight after `WaitForChild` | Wait on the attribute's changed signal only when nil, bounded by `game:IsLoaded()` | |
| 22 | ClientBase before ReplicatedStorage has arrived (1.3, App. C) | Same | Design does not depend on it; recorded | - | |
| 23 | Classic HUD step isolable in the MicroProfiler (5.3, App. C) | `13_profiler_labels.lua`, `13_profiler_notes.md` | `PCFreeRoamHudPhase4A` shows as a bar: Classic script-time comparison for the desktop HUD | Script time for Pulse alone; Classic compared on frame time and write counts | |
| 24 | `Core.Net` busy lock and token bucket for the event card (7.2, App. C) | `14_net_notes.md` | **Answered from source: safe.** `RaceRequest` has no busy lock, 60 tokens, 20 per second | - | Safe, with the four conditions in the note |
| 25 | Guide trail: second config enough for a Pulse colour (App. A) | `15_guide_trail_notes.md` | **Answered from source: yes, no renderer edit.** Overlay object recommended over a second folder | Second folder with all 30 attributes | Yes; chevron tint to be checked in the Phase 8 capture |
| 26 | Studio tools can drive a two-client local test (10, App. C) | `16_two_client_notes.md` | Both client windows listed and scriptable after Oscar starts the test | Fixture replay plus Oscar's confirmation (expected) | |

Appendix C items **not** in this harness: the sandbox's no-save extent for owned-garage purchases (a server source
read), digit sheet cell sizes (measured offline from the font file by the asset generator), UIShadow on a live
phone and real-device frame cost (need a published build and a device).

## Already answered from source

- **14:** there is no client Net wrapper. Limits are server side, per player, per guard. The event card's two
  `RaceRequest` actions cost 1 token each from 60 (refill 20 per second) with no busy lock.
- **15:** `OnboardingGuideTrailRenderer` reads only `config:GetAttribute`; colour is the `TutorialGold` attribute,
  re-read every frame. Any object with that method works.
- **11 (lines confirmed):** `TimeTrialServer` writes `Style = Default` at 1298 (create) and 1311 (every pass);
  the pass runs every 3 s (1414 to 1417). The server value never changes, so no update should replicate: expected
  `reverts = 0`.
- **12:** `ClientBase.StartupState` (a Folder under the script, line 104) publishes status strings only, no timings.
- **13:** only `.WorldLOD.Step` is labelled in Classic. The desktop HUD step is the render-step binding
  `PCFreeRoamHudPhase4A`; the mobile HUD step is an unnamed connection.
- **05, 06:** no soft-glow or ring UI image exists in `Config.UI` or the Classic sources, and `SliceCenter` is used
  nowhere. The placeholders are the game's VFX textures `glow_soft` (77716974295974) and `shock_ring`
  (98670230449915) from `scripts/hover_feel/vfx/texture_ids.json`.

## Files

`01` to `13` Luau spikes (11 is split into `11a` and `11b`), `spike_cleanup.lua`, and the notes
`12_replicatedfirst_note.md`, `13_profiler_notes.md`, `14_net_notes.md`, `15_guide_trail_notes.md`,
`16_two_client_notes.md`.
