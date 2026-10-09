# Adversarial review: completeness against the owner's request, and consistency of the result

Date: 2026-10-09. Read-only. Nothing in the repo or in Studio was changed; no Play session was started; no gameplay
module was required. Live checks ran in Edit against "Space Racers v3 (placeId: 93959280828322)",
studio_id `1071f5cf-8bbe-4913-acf7-1c4c410323d9`, by reading script `Source`, attributes and service properties.

Lens: does every player-visible surface end up cohesive under the new switch; are shared components really shared;
does scaling and alignment really improve at 1280x720, 1440p, ultrawide and phone landscape; is switching back one
action; are the phases, the owner's workload and the decisions realistic.

Reviewed: `proposal-A-safest-backup.md`, `proposal-B-most-cohesive.md`, `proposal-C-quality-and-speed.md`, the style
sheet, mockups 01, 02, 04, 05, and the audit notes (critic, foundation-startup, docs-and-delivery, roblox-platform and
fonts-assets in full; the others for scaling, coupling, defects and seams).

## 0. Verdict

| Rank | Proposal | One-line reason |
|---|---|---|
| 1 | **C** (quality and speed) | Best scaling, alignment and legibility rules, measurable lint and budgets, real phone compositions, closest to the previews (tabs in), only four edits. Weak on phase order and on a few leftovers. |
| 2 | **B** (most cohesive) | Covers the most surfaces and has the strictest "no coordinates, roles only" kit, but pays with nine edits to backup scripts, leaves the phone drive controls old-shaped, missed the existing no-save sandbox and asks 15 decisions. |
| 3 | **A** (safest backup) | Strongest proof that Classic is unchanged and the best switch mechanics, but its "generated copy" route carries Classic layout and scale into Pulse (onboarding, garage controller), so the result is not fully cohesive and does not scale everywhere. |

No proposal is buildable as written. The plan in section 5 takes C as the base, A's switch safety and B's cohesion items.

## 1. Findings that apply to all three

1. **Switching back is not one action for the owner himself.** All three have a preview list that gives Pulse to
   listed users while the style is Classic (A `UIStylePreviewUserIds`, B the same name, C `PulseUserIds`). Oscar will be
   on that list. When he sets the style to Classic he still gets Pulse, in Studio Play and live, and will read it as
   "the switch failed". Fix: one value with three states, `Classic`, `Pulse`, `PulsePreview`; the list is read only
   in `PulsePreview`. `Classic` is then absolute.
2. **In the live game switching back is publish plus server restart, and each player keeps the style until rejoin.**
   All three say so; none is "one action" there. The no-publish kill switch is optional in all three. The client
   should honour a `ForceClassic` attribute from Phase 1, so adding the server projection later does not edit
   ClientBase a second time.
3. **The five activity view scripts stay shared and untouched in all three**, so the Duel CHALLENGE button keeps its
   own size and an offset hard-coded against the Classic bottom row (DuelClientView 252-263). That is a copied
   coordinate under Pulse. It must be a named exception with a re-anchor inside the Pulse `ctx`, or a small approved
   edit to the view. None of the three lists it as a decision.
4. **Map icons keep baked colours** (cyan places, pink activities, blue jobs, dark outline and halo; image tint only
   darkens). A and C do not address it. B declares them world art "for now". Under Pulse the minimap and full map will
   show old-palette icons unless a recoloured set is in the upload batch. This needs an explicit ruling.
5. **Not addressed by any proposal:** the onboarding world guide trail (gold literals in
   `OnboardingGuideTrailRenderer` 76 and 121, a separate module) while callouts move to white and pink. Addressed only
   by B: checkpoint and finish colours, the six dealership wayfinding signs, Health and Backpack core UI.
6. **No previews exist for most of what will be built.** The owner chose the direction from pictures. Mockups 07 to 10
   are sketches; there is no picture for any phone composition, the car panel, settings, full map, owned garage,
   onboarding or prompts. All three go from a corrected sheet straight to code. A cheap preview frame (or a gallery
   capture with fixture data) per family, signed before the controller is written, is missing from A and B and only
   partly present in C (garage navigation only).
7. **The whole kit is designed in Phase 1 before any real screen uses it** (A 25 modules, B about 30, C 10). The
   component API will change once the first dense screen meets it. Freeze the kit API after the pilot screen and the
   HUD, not at the Phase 1 gate.
8. **Owner gates are all written as blocking.** Nine or ten "Oscar confirms" steps, plus device checks, will stall a
   programme whose owner prefers end-to-end delivery. Only High-Risk gates should block (foundation, purchases, start-up
   path, flip); look-and-feel confirmations can lag behind through the preview state.
9. **Freeze policy against the vehicle-category workflow.** New categories have needed GarageUI edits before (the
   ui_artwork, ui_dealership, ui_underglow, ui_variant_labels chain). A states what happens if Classic must change
   mid-programme. B says later features land in Pulse only (the backup then lacks them). C is silent.

## 2. Proposal A (safest backup)

### Fatal flaws (as written)

- **F-A1. Generated copies carry Classic geometry and scale into Pulse, so "all UI cohesive, scales better" is not
  met.** Pulse onboarding is "generated from the Classic source with about ten listed replacements". Checked live:
  `OnboardingClient` has 48 `UDim2.` sites, 17 `TextSize` sites, 14 `GetDescendants` calls and 46 config reads, and its
  `ownerScale` (235-246) takes scale from a `UIScale` ancestor of the target or falls back to
  `clamp(min(X/1600, Y/900), .68, 1.08)`. Pulse screens have no `UIScale`, so every callout uses the fallback and stops
  at 1.08 while the rest of Pulse is 1.33 at 1440p and 2.0 at 4K. The 5 Hz PlayerGui walks, the literal card offsets,
  the objective card at a literal Y of 66 (where Pulse puts titles and the event card) and the missing controller path
  all survive. Ten replacements cannot fix that; a larger spec is no longer a mechanical copy.
- **F-A2. The layout family is chosen from input, at start.** "Phone: touch is the preferred input and the safe short
  side is under 600. Desktop: everything else. Decided at start." A phone with a gamepad attached (common for a racing
  game) has `PreferredInput = Gamepad`, so it gets the Desktop layout at the 0.60 clamp on a 390-unit-tall screen, for
  the whole session. A short desktop window has the same problem. Geometry must choose the layout; input only chooses
  affordances (B and C do this).

### Serious flaws

- Garage Phase 5 keeps the hub, so the Customise screen does not match mockups 04 and 05 until Phase 8, and Phase 8
  "can be declined". The previews are the stated target.
- Phase 8 then hand-edits the controller that Phase 5 generated. From that point the "same text, remote parity on every
  build" guarantee no longer applies to the garage, the place where Cash is spent. The safety argument is temporary.
- The generated garage controller keeps Classic behaviour defects: full `render*` on every click and `buildPreview()`
  on every upgrade or paint-channel select (GarageUI 479, 671). The "20 instances per click" budget depends entirely
  on the view diffing a full context; the 3D preview rebuild is not fixed at all.
- `RacingCompat` (the 20 RacingUIComponents members redrawn with Pulse tokens) is a second component vocabulary inside
  Pulse. Screens on it are positioned by Classic numbers. That is reskin, not reuse.
- Left old-style under Pulse: the race fade label (GothamBold then Michroma, 17 px, unscaled, RaceTransitionClient
  57-72), which also sits under race results. A lists the module as "never routed".
- Round-minimap route distance is read by mirroring the text of a hidden chip, to avoid a five-line read-only getter in
  RouteGuide. That is a fragile bridge chosen only to keep the edit count at three.
- "Every mix of groups must work" is a large untested claim; only six single-group fallbacks are smoke-tested at Phase 9.
- Group pre-check waits up to 5 s per missing path and pre-requires every Pulse entry module before any owner starts.
  "Require has no side effects" is a rule, not yet a fact (A says so).
- The 14-point Play record, run in full three times and in short form after every other phase, needs a car bought in
  the sandbox each run and is likely to be flaky. It proves Classic, which is good, but it is a lot of integrator time.
- Ultrawide rule covers HUD corners only; full menus on 21:9 and 32:9 are not specified.
- Decision 4 (sharpness method) is not an owner decision; decision 10 bundles eight separate colour reversals.

### Claims checked

| Claim | Result |
|---|---|
| ClientBase resolver at 105-109, `StartupState` at 104 | Confirmed live |
| `Config.UI` has no attributes, no `Style` or `Pulse` child | Confirmed live |
| RouteGuide: `GetActive()` public (89-91), `route` and `progress` private (36-38) | Confirmed live |
| MapIconLayer host projection (274-275) and NaN hides the icon (304) | Confirmed live. The no-edit round minimap for icons is feasible; edge clamp at 305-307 is square, as A says |
| No-save sandbox: ProfileServer 178-185 Studio only, live value false | Confirmed live. 198-226 wipes vehicles in memory and sets at least 1,000,000 Cash; 252 sets `noSave` |
| `SetCoreGuiEnabled` only in TrailerModeClient | Confirmed (grep) |
| InitialLoading: early return 15-18, requires at 21 and 22 | Confirmed live |
| Reusing the name `CanonicalGarageGui` is safe | True only because A switches garage and owned garage as one group: `GarageComponents.CanonicalHost` (295-311) adopts any ScreenGui of that name, forces `CanonicalCanvas` to 1600x900 and inserts a UIScale. Callers are GarageUI, GarageBrowserUI and GarageWorkspaceUI only |
| "Three existing scripts edited" | Consistent with the design. The price is F-A1 and the chip mirror |
| Onboarding copy needs "about ten replacements" | Wrong for a cohesive result (counts above) |

### Best ideas

- Atomic groups decided before any `start()`, with a bounded wait, and no fallback after a start has begun.
- Garage plus owned garage as one switch unit (this is what keeps Classic onboarding working on the Pulse garage).
- Classic manifest: hashes of all 221 scripts and a typed config dump, checked inside every installer AUDIT.
- Mechanical forks with a build-time diff check and remote, bindable and attribute parity lists. Right tool where the
  controller is already separate (OwnedGarageWorkspaceUI, GarageEntranceClient).
- No edit to MapIconLayer (host projection). Trap-name list refused by the ScreenGui factory and by lint.
- States what happens when Classic must change mid-programme. Records a Phase 0 place version.
- Golden reply comparison, Classic against Pulse, for a fixed purchase sequence in the sandbox.
- Results verified by payload replay; agents never finish a time trial.

## 3. Proposal B (most cohesive)

### Fatal flaws (as written)

- **F-B1. The phone drive controls stay old-shaped and off the shared scale.** Edit 9 changes art ids, tints and
  margins only ("about 20 lines"). Checked live: `MobileDriveControlsClient` has 41 `UDim2.` sites, 7 `tiny` branches,
  7 colour literals, raw `UICorner` radii 12, 16 and 999 and raw `UIStroke`. `tiny = vp.Y < 500` is true on every
  phone, so Boost stays 44 px and Tilt Recenter about 43 px, pedals stay a fixed 125 px, corners stay round and strokes
  stay on. That breaks B's own rules (48 px, square, no strokes, one scale service) on the surface a phone player
  touches most. It is also a Pulse branch inside a Classic script that writes driving input.

### Serious flaws

- **Nine backup scripts are edited**, two of them shared per-frame renderers that Classic uses (MapIconLayer about 25
  lines, RouteGuide about 30) and four of them Pulse branches inside Classic owners. "Keep the old UI as a backup" is
  weakest here. MapIconLayer did not need an edit (A's host projection is confirmed).
- **Missed the existing Studio no-save sandbox** (ProfileServer 178-185, 252; confirmed live). Instead it asks Oscar to
  create a second experience, extends the installer guard to it, and installs every phase twice. Without that copy, B's
  v3 protocol stops at the purchase confirmation, so purchases are never exercised in v3.
- **No atomic families and no per-family switch-back.** `PathFor` falls back per entry. The OwnedGarageWorkspaceUI seam
  picks its view from `IsPulse`, not from what its entry resolved to, so a partial install can pair a Classic owner
  with a Pulse view. After the flip the only partial retreat is a phase ROLLBACK.
- The existence check is a non-yielding `FindFirstChild` walk. Whether every module has replicated when ClientBase runs
  was not verified by anyone; a miss gives a silently mixed session.
- Phase 2 puts the start screen, loading view, prompts and core UI policy first, on the High-Risk start-up path, before
  any ordinary screen has proved the kit. Pulse prompt banners then sit over a Classic HUD for a phase.
- `TouchDrive` arrangement follows `TouchEnabled`, so a touch laptop driven by keyboard gets the phone arrangement and
  on-screen pedals for the session.
- Ultrawide menus keep 100 dp margins "from the real edges": on 32:9 the race menu's list and detail are pulled apart.
- Chat is hidden during races. That is a product change in a multiplayer racer and is buried in a table.
- **15 owner decisions.** D9, D12, D13 and D14 are defaults to report, not decisions. D15 (backup lifetime) and Phase 9
  (retire Classic) are premature next to "ensure we can change back".
- "Later fixes and features land in Pulse only": the backup falls behind (finding 1.9).
- Two navigation tables (`Hub` and `Tabs`) are both built and kept, behind a second switch.

### Claims checked

| Claim | Result |
|---|---|
| `TutorialTargetId` is written by GarageWorkspaceUI and read by nothing | Confirmed live (one script mentions it) |
| OwnedGarageWorkspaceUI holds its view require on line 12 | Confirmed live; the line is about 2,300 characters, so whole-script replace is right |
| MobileDriveControlsClient gate is `TouchEnabled` (line 12) | Confirmed live |
| `ViewportDisplaySize`, `PreferredInput`, `PreferredTextSize`, `UIShadow` exist in this build | Confirmed live (existence only; rendering needs Play) |
| Chat window and bubbles can be restyled at run time | Properties exist on ChatWindowConfiguration and BubbleChatConfiguration (FontFace, BackgroundColor3, TextColor3, TextSize). Effect not seen; needs Play |
| "v3 Play has no safe way to test purchases" | Wrong; the sandbox flag exists and is off |
| Edit 9 gives kit-quality touch controls | Wrong (F-B1) |
| "Every surface moves to the kit" | Not true for drive controls; true for the race fade label and entrance label, which A and C leave or fork |

### Best ideas

- Anchored slots (`TopLeft` title, `TopRight` status, `RightColumn`, `BottomRail`, `BottomRight` buttons) defined
  once; screens hold no coordinates; the status cluster is in the same slot everywhere.
- Colours by role only: a screen cannot pass a `Color3` (named exceptions: swatches, medals, activity theme).
- One HUD owner for every form factor; layout class from geometry, arrangement and input separate.
- Scale snapped to steps of 1/24, relayout after the resize settles (fewer glyph sizes).
- Tutorial anchors (`AnchorId`) with the legacy names kept alongside; a locked look on action-bar tiles.
- The widest core UI policy: player list, health and backpack off, chat and bubbles restyled, top bar handled once.
- Four-line token seam for the race fade label, so nothing is Michroma under Pulse.
- Slot diagrams turn ink on a white selected tile; a designed no-image tile state (EXO-03).
- Compact race menu becomes list then detail instead of two shrunk panes.
- Place baseline: Roblox version recorded and a local copy saved before Phase 1.
- Parity audit: every Pulse ScreenGui carries a mark; in Classic there must be none.
- States plainly what the backup costs.

## 4. Proposal C (quality and speed)

### Fatal flaws

None that sink it. Two things are wrong as written and must change (see serious flaws 1 and 2).

### Serious flaws

1. **The race fade label stays in the old face under Pulse**, stated as a choice. It is also the hold under race
   results. Small, but it is exactly "something old-style under the new switch".
2. **Phase order leaves the main screen mixed for most of the programme.** Activity HUD, onboarding and full map are
   Phase 8. From Phase 3 to Phase 8 the free-roam screen shows a Pulse HUD with a Classic job strip, offer card and
   objective cards on top. Oscar cannot judge cohesion of the screen he sees most until the end. A and B put the
   activity `ctx` with the HUD.
3. **Garage and owned garage are split across Phases 6 and 7**, which forces the name `CanonicalGarageGui` to be
   forbidden (confirmed: the old host adopts it). Result: Classic onboarding cannot see Pulse garage pages for three
   phases, and the tutorial marks placed in Phase 6 meet their real consumer only in Phase 8.
4. **Navigation change and first garage delivery are one step.** There is no like-for-like run against Classic for
   purchases. Mitigations are present (headless model with fixtures, audit-table review, sandbox matrix) but A's golden
   reply comparison is missing.
5. `Families` can only limit Pulse to a prefix of delivered families. A fault in the HUD means reverting everything
   delivered after it. After the flip there is no single-family retreat.
6. Touch controls and GarageEntranceClient are forked ("proven by diff" for requires only). A fork of the sole writer
   of driving input has no parity check; steering feel on phones could drift.
7. A caps sprite sheet with a kerning table for titles is a custom text renderer. It is a fallback, but it is the
   heaviest one on offer and cannot be localised later.
8. Asks for a PB-01 fix (a TimeTrialServer edit, High-Risk, personal bests) inside a UI programme. Fixture and quit-path
   verification already cover results.
9. The existence check is a non-yielding walk (same doubt as B). `UiStyle` waits up to 10 s for a new `Style` folder;
   an attribute on the existing `Config.UI` needs no wait at all.
10. Phase 8 bundles three unrelated families, one of them High-Risk. Phase 6 is very large.
11. Health, guide trail colour, map icon colours, world signs and the Duel button are not ruled on.

### Claims checked

| Claim | Result |
|---|---|
| `GarageComponents` 294-311 re-uses any ScreenGui named `CanonicalGarageGui` | Confirmed live, and it also resizes the canvas and adds a UIScale |
| `OnboardingClient` 666-671 disables every button named Car, Race, Garage | Confirmed live |
| `RouteGuide` 34-39 private state, 89-91 `GetActive` | Confirmed live |
| ProfileServer 179-226, 252; both sandbox flags false | Confirmed live |
| `OwnedGarageWorkspaceUI` line 12 holds the two require targets | Confirmed live |
| ChatWindowConfiguration exposes `Enabled`, alignment, `AbsoluteSize` (reads 0,0 in Edit) | Confirmed live |
| TextSize is clamped at 100; Barlow `Font.new` constructs; `ProximityPromptStyle.Custom` exists | Confirmed live (not rendered) |
| "Four existing scripts edited" | Consistent, but two more owners are forked rather than edited |
| "A newer Pulse family only ever meets older Classic families" | Holds only while no earlier family falls back; the per-family existence check can break it |

### Best ideas

- Opens with ten recommendations, which is what the owner asked for first.
- A throwaway Play-only spike settles every rendering unknown before anything is installed or uploaded.
- Pilot on the race menu (one owner, one remote, no frame loop, a real-capture mockup) before the HUD.
- Three composition frames, `Hud`, `Scene`, `Menu`; full menus are a centred block no wider than 2:1; three logical
  widths (Narrow, Regular, Wide) instead of shrinking below the floor.
- Legibility and alignment budgets with a `layout_lint` probe: whole-pixel geometry, TextSize 14 floor, `TextFits`
  with the longest strings at Largest text, 48 dp targets with 8 dp gaps, margin equality, HUD cover, contrast worked
  from the tokens.
- A phone type set of its own, drawn against 844x390 and 640x360; ten-viewport capture matrix.
- `Kit.Input.Mark(instance, key)`: views never type a tutorial name; one contract table.
- Screen-anchored prompt stack (no per-frame cost, proper touch target, hidden by trailer mode).
- Gallery tool with fixture data; garage navigation accepted there before the controller is written.
- Tabs and Shop/Owned in, so the result matches mockups 04 and 05. Dead settings rows not rebuilt.
- One additive read-only getter in RouteGuide instead of renderer options or a text mirror.
- Glow slices uploaded anyway so the fallback is a token edit; `KillSwitch` can only ever force Classic.

## 5. The plan I would build

Base: C. From A: the switch mechanics and the Classic proof. From B: the cohesion rules and residual surfaces.

**Switch.** One string attribute `UIStyle` on the existing `Config.UI` (no new wait): `Classic`, `Pulse`,
`PulsePreview`. The preview user list is read only in `PulsePreview`, so `Classic` is absolute and is one action.
`UIStyleClassicFamilies` names any families held on Classic (not a prefix). The client honours `UIStyleForceClassic`
from Phase 1; the server projection is added only if Oscar wants a no-publish retreat. Latch once per session.
Families are atomic, decided before any `start()`, with a bounded wait; no fallback after a start.

**Edited scripts: five.** ClientBase; LoadingTransitionRuntime (one line); InitialLoadingAndStartScreenClient (one
guard); RouteGuide (one read-only getter); RaceTransitionClient (label font and colour from tokens when Pulse). No
edit to MapIconLayer, RacingUIComponents, GarageComponents or ResponsiveUIFoundation. Mechanical forks with A's diff
and parity checks for OwnedGarageWorkspaceUI and GarageEntranceClient. Touch drive controls: a fork whose input logic
is text-identical and whose view and layout are new, with an input-state parity test and a real-phone check.
Everything else rebuilt as headless model plus kit view (onboarding and garage included; no `RacingCompat`).
All other scripts and all existing config stay byte-identical, proved by A's manifest in every AUDIT. Freeze policy
written down, including what happens when a new vehicle category lands.

**Kit rules.** Integer pixels, no UIScale (one named exception: the activity `ctx.Root`, with the Duel button
re-anchored by the Pulse `ctx`). Layout family from geometry only; input changes affordances only. B's anchored slots
and role-only colours. C's composition frames, phone type set, budgets and lint. One Tile for parts, vehicles, events
and listings, with ink-on-white diagrams and a no-image state. Kit API frozen after the pilot and the HUD.

**Phases.**

| # | Phase | Notes |
|---|---|---|
| 0 | Spike, previews, decisions | C's spike. Corrected sheet. Preview frames for every un-mocked screen and each phone composition. A surface ledger: every item in critic.md marked Pulse, shared and style-neutral, or excluded with a reason. Classic manifest, place version and local copy. Asset contact sheet |
| 1 | Foundation and switch | Switch, tokens, scale, layers, the components the pilot needs, toasts, confirm, gallery, installer create-op proof. High-Risk |
| 2 | Pilot: race menu | PC, phone, controller. Kit API reviewed afterwards |
| 3 | Free-roam screen | HUD, car panel, lazy modals, touch controls, activity `ctx`, core UI policy. So the screen in mockup 01 is whole |
| 4 | World and map | Prompt banners, event card, Start banner, full map, map icon ruling applied |
| 5 | Race session | In-race HUD, countdown, queue, results (payload replay), race fade label seam |
| 6 | Race entry | Setup, records, vehicles on the shared tile |
| 7 | Garage, one atomic family | Dealership, Customise with tabs and Shop/Owned (accepted in the gallery first), paint, modals, owned-garage browser, desk and interior HUD, entrance status. Golden reply comparison against Classic. High-Risk |
| 8 | Shell | Onboarding rebuilt on marks and the kit scale, guide trail colour, loading view, start screen. High-Risk |
| 9 | Hardening and flip | Full matrix in both styles, single-family retreat test for each family, switch back proven after the flip. Classic stays; retirement is not in this plan |

**Testing.** Studio no-save sandbox through a guarded toggle (it exists). Agents never finish a time trial; results by
payload replay and the quit path. No PB-01 fix inside this programme. A private test place for real phones is
optional and Oscar's call; if declined, real-phone checks are his and are scheduled at Phases 3, 7 and 9.

**Owner involvement.** One sitting at Phase 0. Blocking gates only at Phases 1, 7, 8 and 9. All other confirmations
are done through `PulsePreview` when he has time and do not hold the next phase.

**Decisions to put to Oscar (eight, each with a recommended default).**

1. Form of the backup: parallel Pulse modules, five edited scripts, Classic frozen and hash-checked; freeze policy.
2. Switch: place attribute with three states; a no-publish kill switch now, at the flip, or never.
3. Typeface, from the three-way capture (recommended Barlow), and approval to fetch the font file for digit sprites.
4. One asset batch from one contact sheet, including recoloured map icons if ruling 5 says so.
5. Colour rulings: cash yellow, white selection, white tier badges, muted unaffordable price; tutorial and guide trail
   colour; map icons, job colours and checkpoint colours (Pulse palette or declared world art).
6. Roblox core UI: player list, health and backpack off; chat restyled, hidden in full menus, kept in races.
7. Navigation and prompts: tabs and Shop/Owned in the garage phase; custom prompt banners if the spike passes.
8. Test mode: sandbox toggle for agent sessions; optional private test place; the phase list as one approved scope.

## 6. Not verified in this review

- Nothing was run in Play. Local prompt `Style`, text above 100, hairline rounding, UIShadow on a live client, the
  chat restyle and the Text Size multipliers remain spike items.
- Whether all of ReplicatedStorage has replicated before ClientBase runs (it decides whether a non-yielding existence
  check is safe). Use a bounded wait regardless.
- The extent of the sandbox's no-save guard for owned-garage purchases beyond the `noSave` flag at line 252.
- Instance counts and pixel sizes for Classic are the audit's source readings, not measurements.
