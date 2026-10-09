# RaceSession family (F4): notes for the integrator

State: **generated only.** Nothing was installed, run in Studio or committed. No Luau ran: every file was desk-checked line by line, and a block and bracket balance script passed on all sources. `tools/lint_phase2.py race_session` reports findings only inside the kept lines of the fork (exempt once `build_forks.py` has run); `tools/parity_check.py race_session` reports 0 open. The kit v2 modules were not on disk for most of the work (`Collections.List`, `Data`, `Overlay.PromptBanner`, `Presence` and others), so every kit call is written from `API2.md` alone and none has been compiled against the real kit.

## Files

- `after/` 11 files: nine `UIPulse.RaceSession.*` modules, `Dev.Fixtures.RaceSession`, and the edited `Racing.RaceTransitionClient`.
- `before/` the byte copy of `RaceTransitionClient`; `seam.diff` is the diff check (0 removed, 4 added, between Classic lines 71 and 72).
- `forks/RouteGuideClient.json` + `RouteGuideClient.wrongway.lua` (span 271-300). `after/...RouteGuideClient.lua` is the hand-assembled copy (433 lines).
- `tests/` nine pure test files. `contract.json`, `routes.json`, `spec_ops.json`, `CONTRACT.md`.

## Classic behaviour not reproduced exactly

Each is also a `dropped` or `added` row of `contract.json` with its API2 reference.

1. **HUD return fix (asked for).** `RacePositionUpdate` no longer shows the HUD when none is active, and is ignored for another `RunId`. If either side has no `RunId` the update is accepted while a session is active (the audit does not list `RunId` on every payload). I also ignore a late checkpoint or lap payload of the run that just ended.
2. **Race timer.** Classic has no race timer. Pulse shows `RACE TIME` from the client clock at the arrival of `RaceStarted` (API2: "the client clock, as today"), not from `StartServerTime`. It is therefore late by the network delay.
3. **Live order.** Four rows round the player (three on Compact) instead of the first six; no avatars; no gap times (the payload has none, the preview shows them).
4. **Time-trial board.** Personal best plus the last three laps (two on Compact) instead of every lap.
5. **Results tables.** Six pooled rows windowed round the local player and the last four session laps, instead of scrolling lists of everything. The leaderboard request still asks for 20. Reason: the 150 budget; 20 rows at 12 instances each is 240. Raise `ResultsView.TABLE_ROWS` to 20 if you prefer Classic's full list over the budget. On Compact the session-lap and highlight list is not drawn (c10).
6. **Results images.** No medal icon (Classic atlas) and no avatars. The medal name stays as text. Race highlights keep Classic's `--` values: no payload fills them.
7. **Results strings.** `BANKED` replaces `PRIZE`; `FINISH` labels the place; `EXITING...` and a failed exit's message are shown as the big title, as Classic does in its `complete` label.
8. **Results buttons.** An in-flight guard is added (Classic can send the exit twice on a double press). The buttons exist before the leaderboard reply (asked for).
9. **Exit during a fade.** If the session ends during the 0.25 s fade, Classic errors and leaves the fade up; Pulse sends no call and fires `RestoreCamera` and `FadeIn`.
10. **Route map.** Regular, non-touch only, as Classic. The marker subject is resolved on every show and on `SeatPart` / `CharacterAdded` events, not by the 0.5 s timed lookup in the frame step (lint rule 7). `MapOpacity` is read on each show, not listened to. `PlayerMarkerScale` is applied; the base size is a token, not `MapPlayerIconSize`.
11. **Queue.** `FreeRoamHudPresentationMode` fires on change only (asked for). Classic's destroy of `RaceQueue_Phase8` at start is not carried.
12. **Presentation mode on touch.** Results fires owner `RaceResults` on every device; Classic's touch branch wrote `Enabled` on a legacy gui instead.
13. **Wrong-way prompt.** A plain `PromptBanner` in slot `PromptStack` (bottom centre), not Danger red under the timer as r14 shows. See question 1.
14. **Countdown.** `GO!` is a `ScreenTitle` label in Cyan, far smaller than r14: the digit sheets have no letters. See question 2.
15. **Reset and exit feedback on Compact.** The buttons are icon-only there, so `RESET DONE`, `RESET FAILED` and `EXIT FAILED` are not visible.

## API questions and the reading used

1. **Wrong-way prompt.** "A kit label styled as a PromptBanner" read as `Overlay.PromptBanner` with `Action = "WRONG WAY"` and no key. The banner has no Danger kind, no icon prop and no slot under the timer. To match r14 it needs a `Kind = "Danger"` and `Icon` prop and a slot below `TopCentreHud`.
2. **GO!** No role or sprite for giant text. A `GO` sprite or a display role above 100 px is needed to match r14 and c09.
3. **One replaced span and "Claim first".** The fork's claim sits at Classic line 271, inside the one span. Nothing above it creates an instance or connects, so it is the first effect, but it is not the first statement, and the fork keeps Classic line 1 as its header. A second span on line 1 would fix both; I did not add one because API2 says one span.
4. **`Collections.List` size.** API2 gives `RowHeight`, `Width`, `Header` and no height. I put each list in a frame of `Width` by `rows x RowHeight` (plus one header row for results). If the list sizes itself the frame is harmless; if it fills its parent it is needed.
5. **`ListRow.Columns` with a changing column count.** The HUD board has two columns in a race and three in a time trial; the results header changes between `FINISH TIME` and `TIME` through `List.Set({Header = ...})`.
6. **`BigNumber` width.** The root is `MaxCells x pitch` wide, so two Hero numbers do not fit side by side for a time trial. Reading used: one primary number in role `Hero` (9 cells: best lap, or cash in a race) and one secondary in role `Speed` (8 cells: cash, or driver XP in a race), recoloured through `Set({Colour = ...})`. Cash of 1,000,000 or more uses `Data.Money(amount, true)` so it fits 8 cells. The position number has 2 cells, right-aligned, so a single digit sits one cell in from the margin.
7. **Missing tokens (requests; stand-ins used).** Route-map panel: `TileWidth` x `TileHeight` (preview is about 360 x 232). Map marker: `Pad` (22). Queue banner: `ModalMaxWidth` x `ListRowHeight`, Compact `CompactPromptWidth` x `CompactTileHeight`. Results table width: `ToastMaxWidth`, Compact `CompactSidePanelWidth`; fact list width `StatPanelWidth`. Row height: `StatRowHeight`, Compact `CompactStatusHeight`. Hero gap: `TabGap`.
8. **A plain image.** The kit has no image component, so `RaceHudView` creates one `ImageLabel` (`SimplifiedRaceMap`) for the route image from config. `RaceHudClient._asset` contains the content prefix string `rbxassetid://` (Classic line 29) to turn a bare id from config into a content id; the lint does not flag it, the reviewer may.
9. **Driver XP baseline.** Read literally: the baseline is taken when the result payload arrives and the change must come after it. If the server sets `Rank` / `XpIntoRank` before it fires the result, the attributes may replicate first and the hero number never shows. The alternative is a baseline at the last `*Staged` / `*Started`, which could also count XP earned from something else during the race. On a rank change the screen shows `RANK UP` and the new rank, since the XP amount cannot be read from the two attributes alone.
10. **Slots.** HUD buttons use `HudButtons` on every class; c08 draws them top right under the order board. The results column on Regular hangs from `TopCentreHud`; on Compact `Controls.Header` is in `TopLeft` with the body under `header.Height()`.
11. **`View.Mount` has a fourth argument** (`options`: the live layer, a confirmation host for the gallery, `NoPresence`). API2 6.2 lists three.
12. **Presence.** The HUD registers `RaceHud` as kind `Race`, results `RaceResults` as kind `Results`. Fixtures pass `NoPresence`.
13. **`UIFlexItem`** is used once (queue banner title block). No lint rule forbids it.

## Check in Play (sandbox window; never cross a time-trial finish)

1. `StartupState`: the five routed entries are `ready`; `Runtime.Racing@CountdownPresentationReady` is true; `RaceTransitionClient` staging is not degraded.
2. Census: `SharedInRaceHUD`, `SharedInRaceHUDLive`, `RaceCountdown`, `RaceQueueBanner`, `RaceRouteGuide_Phase5`, `UnifiedRaceResults`, `UnifiedRaceResultsScrim` exist once, marked Pulse, no kill-list gui.
3. Time trial start: countdown digits, GO, HUD with lap, timer running, pips advancing, personal-best row; a lap gives the delta chip. Then **EXIT, YES** (the Quit path): fade label `EXITING` styled by the seam, HUD gone and not returning; if the server answers a quit with a `TimeTrialFinished` whose `FinishReason` is `Quit` (I did not read the server), results show `TIME TRIAL ENDED`, both buttons are present while `LOADING GLOBAL RANKINGS` shows, and EXIT TO START returns to the start. RESET: label `RESETTING`, `RESET DONE`.
4. Exit confirmation: NO left and focused, YES right, Escape and B cancel, pad navigation.
5. Race (needs two clients, so Oscar's run): queue banner texts and LEAVE; position, suffix and order rows; the HUD does not return after finish or exit while others still race; results rows fill in as others finish; RACE AGAIN requeues; owner keys `RaceSession` / `RaceQueue` / `RaceResults` reach the free-roam HUD with the right `KeepTelemetry` (gauge kept in the race, gone on results).
6. Driver XP (question 9): on a real race finish, does the number appear within two seconds? Record which replicates first.
7. Kit behaviour I could not see: list sizing (question 4), `Set({Colour})` on `BigNumber`, `Set({Header})` and a third column on `List`, `SegmentedBar` with `Segments` set per event, `PromptBanner` with no key, the Hud scrim, and whether `HudButtons` collides with what the free-roam HUD leaves on screen in a race.
8. Wrong way: drive against the route for three seconds; the banner shows and hides; the 3D guide is unchanged.
9. Budgets by probe: HUD at most 140 with 0 created per event; results at most 150. Gallery: every state of the five `RaceSession.*` items at R720, R1080, R1440, C844, C568, with Largest text.
10. Classic, `UIStyle` Classic: the fade label looks as today (the seam's `Active` is false) and the Classic record is unchanged.
