# UI restyle audit: project rules and delivery tooling

Read-only pass, 2026-10-08. Repo only (no Studio calls were needed). Sources read: AGENTS.md, CLAUDE.md,
docs/00, 04, 06, 07 (top), 12, 13, 14, 15, docs/architecture/{proportional-mcp-delivery, architecture-programme,
studio-testing-playbook, naming-and-owners, claude-code-setup, targeted-capture-workflow, installer-index,
validation-and-handoffs}, the four UI design docs, docs/design/pulse-racers-ui-style-sheet.md,
scripts/studio_delivery.py, scripts/feature_installer.py, scripts/studio_capture.py (place guard),
scripts/hover_feel/*, scripts/driving_tune/CONTRACT.md, scripts/exotic_category/ui_*/build.py,
scripts/lighting_realism/step2, .claude/agents/delivery-reviewer.md, .claude/commands/*, .claude/settings.json.

## 1. Routing

- The request ends "let me know of any recommendations you have first". That is `suggest:`: recommend, no
  implementation, plan mode (AGENTS.md routing; CLAUDE.md working style; .claude/commands/suggest.md).
- The style sheet is "Design - not approved. Nothing in this document is installed." Its own build order step 1
  is "remaining captures, then lock this sheet". Nothing is approved for `follow:` yet.
- Rules ask the assistant to pick the lane, state it, and keep its safeguards through repairs (docs/14).

## 2. Binding rules

Owners and startup
- One owner per state / geometry / visibility / preview / attachment / persistence concern. "Never add an owner
  to overpower an existing one." Retire, narrow or replace instead (AGENTS.md; docs/14 Ownership and Isolation).
- ClientBase owns startup only and starts GarageUI directly. DriveSessionClient owns vehicle callbacks. Do not
  resurrect GarageClient or retired adapter trees. No duplicate startup owners.
- A compatibility bridge may forward data but must not become another presentation owner (docs/14).
- New substantial behaviour goes in isolated modules, not in a register-limited bootstrap (docs/14; the old
  bootstrap hit "Out of local registers").
- Canonical UI owners (naming-and-owners, foundation V1.1, vehicle card V1.2): GarageUI; ResponsiveUIFoundation
  (corners, strokes, money, confirmation, notifications); RacingUIComponents; UITheme / UIFactory;
  GarageReplacementComponents.VehicleCard; desktop and mobile free-roam HUD controllers; Race* presentation owners.

Backups and fallbacks
- "No in-game backup folders/scripts, fallback implementations or duplicate startup owners unless explicitly
  requested. Keep recovery evidence in the repository." (AGENTS.md). docs/13 s3: "no persistent in-game backups".
- Installers keep in-memory recovery only; ROLLBACK is rebuilt from repo before-sources.

Shared components
- "Reuse actual shared UI components, renderers, layout functions and semantic tokens. Copying coordinates is
  not reuse. Document any necessary page-specific exception." (AGENTS.md)
- Foundation V1.1: no blanket UICorner / descendant scan, no profile polling loop, corners scaled only when a
  renderer constructs them, bevel applicator inspects one named direct child.
- docs/14: extract a framework when a second consumer exists (true here: many consumers).

Authority
- Price, Cash, affordability, spawn, queue and results are display projections of server data. No new remotes.
  Core.Net for any handler; MoneyService.Debit / EconomyServer only. A small diff never bypasses these.
- Racing design system "Locked Ownership Boundaries": reset, finish cleanup, reward calc, PB, matchmaking, route
  guide, transition fade/camera must not change for presentation.

Config and flags
- Tunables as attributes/values under ReplicatedStorage.Config, read with ConfigReader (finite, bounded).
- "New live-tunable behaviour reads FeatureFlags, not ad hoc attributes." FeatureFlags is
  ServerStorage.Modules.Core.FeatureFlags (server only): Flag_<key> on ServerStorage.Config, then dashboard
  ConfigService snapshot, then default. hover_feel recorded four client config switches as an accepted exception
  "because FeatureFlags is server-side" (FEEL-01).

Mobile
- StarterGui.ScreenOrientation = LandscapeSensor. No portrait layouts, no runtime orientation writers.
- docs/14: one responsive composition; mobile designed with the feature, not added later; touch targets,
  safe area, text bounds, controller entry/exit.

Installer discipline
- One approved scope, one canonical installer; repair it, no patch ladder; no splitting an approved phase or
  adding user-run tasks without asking.
- Preflight unique paths/classes and exact expected sources; compile all projected sources before assignment;
  preserve source-size headroom; restore on failure; repeat-safe; AUDIT / APPLY / ROLLBACK in one scope.
- Announce fragile text replacement. Two anchor failures in one live script: stop, refresh real source.
- No gameplay module require through MCP, no hot reload, no automatic mirror-to-Studio sync. Publishing is a
  separate scope.

Capture, review, evidence
- Default: targeted before/after captures of full inventoried script source plus affected config; recheck live
  state immediately before mutation; investigate out-of-scope deltas.
- delivery-reviewer before APPLY on High-Risk (persistence, economy, remotes, architecture, retirement).
  hover_feel (High-Risk) and driving_tune (Standard) both ran it; "READY WITH FIXES" each time.
- Distinguish generated / installed / agent-verified / user-confirmed. Emulator proves layout only.
- Plan mode for suggest:, audit: and any High-Risk task before mutation.

Git and docs
- Stage explicit paths, never `git add -A`; `area: summary`; no force-push; standing authorisation to commit and
  push verified work at the end of each task or handoff; report push only after success.
- Never read or commit docs/studio-full-export-paste.txt.
- Status only in docs/00_START_HERE.md; 06 for risks; one 07 entry per delivery; docs/12 lesson after confirmed
  evidence. Superseded design docs must be updated when the new sheet is approved.

Parallel builds (CLAUDE.md, docs/12)
- Contract first, one folder per agent, agents never touch Studio or git, integrator owns captures, installs,
  Play tests.

Assets
- upload_image / generate / insert tools need Oscar's explicit approval for that asset; ids recorded in repo.

## 3. Where the request meets a standing rule

1. "Keep the old UI as a backup" vs "no in-game backup folders/scripts, fallback implementations". The rule
   has a written exception: "unless explicitly requested". The request is explicit. Allowed, but the form
   should be confirmed and recorded.
2. The exception does not waive the one-owner rules. Old and new must never both be live. If the switch picks
   between two module trees at startup, that is a new startup selection inside or next to ClientBase
   ("ClientBase owns startup only"; "no duplicate startup owners").
3. Rules say to challenge a safer alternative once: keep the old look as code paths inside the existing owners
   behind one style switch (what the sheet proposes), plus repo before-sources and ROLLBACK builds, plus a
   saved copy of the place, rather than parallel copied UI modules. Trade-off: in-file branches roughly double
   the styling code in large scripts (GarageUI about 61 KB, DesktopFreeRoamHudUI about 75 KB, limit 200 KB)
   and the old branch rots; parallel modules are a cleaner switch but are in-game backup scripts and need a
   startup selector.
4. Sheet says the switch is "one Core.FeatureFlags flag". Clients cannot read ServerStorage. Options: server
   publishes the flag as a replicated attribute (new server touchpoint, no remote), or a
   ReplicatedStorage.Config attribute recorded as an exception (FEEL-01 precedent; not dashboard-switchable
   without a place update).
5. "Change all current UI" = many deliveries. Rules: one approved scope / one installer; do not split without
   asking. So the phase list must be approved up front. suggest may propose phases where they help.
6. The sheet reverses approved, user-confirmed rules (its own list): cash blue to yellow; cyan selection to
   white fill; pink structural outlines removed; Phase AO tier palette dropped; dealership price green/red
   (vehicle card V1.2, user-confirmed) to yellow/muted. Michroma dropped. Corner scale 0.70/0.50 to 0. Bevels
   off. Each needs Oscar's confirmation.
7. Sheet step 7 leaves phone and controller to the end; docs/14 says mobile is designed with the feature.
8. Hub removal and Owned/Buy merge change navigation and preview-clearing state. The sheet itself says they
   "need their own acceptance step". docs/13: a mid-stream adjustment must not silently widen the task.
9. Removing the old style later is "retirement" = High-Risk (docs/13), only on Oscar's say.
10. Sheet's contract says lane Standard; rules point to High-Risk for the token/component/switch step (see 6).

## 4. Delivery route in v3 (existing scripts and config)

Documented default: scripts/studio_delivery.py + targeted capture. NOT usable in v3:
- scripts/studio_capture.py line 11: `PLACE_IDS = (121304917315753, 71491191583884, 133417340424236)`; load and
  receive both reject other places. scripts/studio_export_snapshot.lua asserts v2 or Backup v2.
- TOOL-05 (docs/06): "refuse the v3 place ... Adding v3 to the accepted places changes a place guard; it needs
  Oscar's approval."

What every v3 delivery has used instead (hover_feel, driving_tune, exotic ui_*, lighting_realism):
- scripts/<task>/CONTRACT.md (owners, parts and file ownership, interfaces, rules, done-when).
- serve.py: 127.0.0.1 file bridge at the repo root (hover_feel port 8794); GET serves after-sources, POST
  /put/<name> writes exact live source bytes into before/. Config state dumped to before/config.json.
- build.py: anchored edits `(old, new, expected count)` or whole-file after/; djb2 hash of before and after;
  applied_hashes.json so a rebuilt delivery can be applied over its own earlier build; writes out_audit.lua,
  out_apply.lua, out_rollback.lua = `MODE` + JSON `DATA` + installer_engine.lua.
- installer_engine.lua: asserts PlaceId 93959280828322 and Edit; each script state = before / after / prior /
  unknown / missing (unknown or missing blocks); fetches the wanted source over localhost, checks its hash,
  compiles with loadstring; attributes checked against captured before value; new config instances created
  with an `...Installed` marker attribute; nothing written if any blocker; ChangeHistoryService waypoints;
  sources restored if a write fails. ROLLBACK restores before-sources, earlier attribute values, removes
  marked instances.
- Run through execute_luau in Edit: AUDIT, delivery-reviewer, APPLY, ROLLBACK, APPLY, then Play test,
  verification.json, docs, commit. "Save the place in Studio to keep this."

## 5. New ModuleScripts and config folders in v3

- proportional-mcp-delivery: "Creation, deletion, renaming, hierarchy moves, physical properties, typed Roblox
  attributes ... use a dedicated canonical migration. The generic tool does not implement these."
- claude-code-setup: multi_edit never "to create scripts (new scripts are a migration)".
- Tools that can create:
  - scripts/feature_installer.py: ops source, module (new ModuleScript {parent,name,file}), folder, instance
    (class, properties, attributes, tags), attribute. Typed values Vector3 / Color3 / CFrame / UDim2 / Enum.
    Applies in order, rolls back in reverse; create target must be absent from the capture; revert refuses if
    the created item has children it did not create. Needs a studio_capture capture -> blocked on v3.
  - scripts/architecture/installer.py: source, module, attribute, remove_instance. Also capture-based.
  - hover_feel installer_engine.lua: creates config instances (class, name, attributes, Value, children) but
    values come from JSON, so no Color3, and no script Source.
  - lighting_realism/step2 engine (v3): ops source, tree (new instance trees with typed properties and
    attributes), attribute, property, and a `create` op that makes a new script with Source. step2 only used
    source / tree / attribute, so creating a new ModuleScript is not yet exercised in v3.
- So two routes: (A) Oscar approves adding v3 to the capture guard (resolves TOOL-05) and feature_installer.py
  does modules + Folder + Color3Value/StringValue/NumberValue with typed properties; or (B) one canonical v3
  installer for the restyle with module-create and typed-value ops, mock-tested, proven by APPLY/ROLLBACK/APPLY.
- Foundation V1.1 warning: "Studio persisted the V1.1 sources but dropped the eight newly created optional
  Theme tuning NumberValues ... after the mixed source/hierarchy command." Verify new config persists after
  save and reopen; keep code defaults identical to config.

## 6. Tooling limits

- All three capture-based builders assert `bundle.place_id == game.PlaceId` and Edit mode.
- studio_delivery.py: existing source bodies and string/boolean/number attributes only; "Requires dedicated
  migration" for anything else; refuses ServerStorage.Archive, ServerStorage.NeoTokyoRacers, Workspace outside
  World; output must be under scripts/.
- Existing hash-guarded chains in v3:
  - GarageUI: ui_artwork -> ui_dealership -> ui_underglow -> ui_variant_labels (roll back in reverse).
  - GarageWorkspaceUI: ui_artwork. GarageModuleCardViewModel: ui_shop_order.
  - DesktopFreeRoamHudUI: driving_tune.
  A restyle of these becomes the next link; older rollbacks refuse until the restyle is rolled back.
- Never run the Exotic content installer ROLLBACK in v3 (removes the category; v3 saves).
- execute_luau: network unstable, probe localhost each session; Client datamodel cannot use HttpService;
  output capped at 100,000 characters; Server Play has no loadstring; Edit tools unavailable while Play runs.
- Script Source limit 200,000 characters (measured).
- UI exists only in Play (StarterGui empty), so Edit screen_capture shows no UI; Play screenshots omit CoreGui.
- Studio must be rendering (RenderStepped > 0) or tweens freeze and the start screen never completes.
- v3 Play saves the real profile (TEST-01); time trials write PBs (PB-01).
- user_mouse_input coordinates are GUI AbsolutePosition space; same-named buttons need computed coordinates.
- Docs drift: claude-code-setup, /start, /capture and the testing playbook still name v2.
- Fonts: Titillium Web ships with real italic; Barlow Condensed and Kanit do not. No per-panel blur.

## 7. Lanes

- (a) Style tokens + shared components + start-up selection: High-Risk. Reasons: new ModuleScripts and config
  tree (a migration); becomes a dependency of every UI owner (docs/14: "systems that will become dependencies
  for many future features", "architecture", "cross-system APIs"); touches ResponsiveUIFoundation, whose
  original delivery was High-Risk "because it crosses active UI and projects authoritative economy responses";
  a UI selection at startup is "uncertain or multiple runtime owners" (docs/13). Sheet says Standard reviewed
  as one change.
- (b) Screen families: Standard ("connected UI/preview/navigation/presentation with clear owners") with
  High-Risk preservation gates wherever price, Cash, purchase, spawn, queue or results are shown.
  - Free-roam HUD (desktop + mobile), car panel: Standard; spawn/despawn gate.
  - In-race HUD and results: Standard; results from server payload; locked race boundaries.
  - Race menu and entry: Standard; teleport, queue, vehicle lock gates.
  - Dealership, customise, module shop, paint: Standard restyle; hub removal and Owned/Buy merge need their own
    contract and acceptance; raise to High-Risk if owners prove unclear.
  - Modals, settings, owned garage, full map: Standard; owned-garage purchases gate.
- Default flip and old-style removal: High-Risk (retirement), on Oscar's say only.
- Later token-only tuning: Fast.

## 8. Evidence per step

- Edit: before-sources and config dump; compile; AUDIT; APPLY, ROLLBACK, APPLY; after dump compare.
- (a): pure tests via loadstring + fakes; switch off reproduces today's captures; startup states ready.
- Play: rendering check; visible start flow; each screen opened, used, closed, switch on and off; bounds, scale,
  safe area, ancestors; no new errors; rerender counts; instance count within 10%.
- Resolutions: 1280x720, 1920x1080, 3440x1440 (sheet) plus 1366x768, 1600x900, 2560x1440 (free-roam system).
- Phone landscape + controller per family; physical device deferred (iPhone 7 reference).
- Garage matrix from docs/13 s4 and vehicle card V1.2 (ten rerenders, card count, affordability flip).
- Two-client: only for displays of other players (live order, minimap circles). Save/rejoin N/A.
- Reviewer before APPLY on (a), navigation changes, default flip, removal; recommended per family.
- Oscar confirms each screen; validation_record.py for connected evidence.

## 9. Open UI and device issues (docs/06)

TOOL-05, TOOL-03, TEST-01, PB-01, ARCH-P7, MAP-02, MAP-03, ROUTE-01, RP-01, RP-02, DRIVE-02, FEEL-01, EXO-01,
EXO-02, EXO-03, MUS-02, PERF-06, PERF-01, PERF-06-A (resolved, Studio only). Without IDs: bruiser_01 display
defaults (00_START_HERE); screens not captured live (style sheet); dropped Theme NumberValues (foundation V1.1).

## 10. Lessons (docs/12 and delivery records)

Contract first; integrator owns Studio; agents cannot run Luau; first Play test finds what offline cannot
(full-screen backdrop swallowed map clicks); rendering check first; float32 tolerances; start-up fetch can fail
silently; 200,000 character limit; mechanical moves + independent reviewer; measure options offline; pilot
first; mouse coordinate space; weak-table button retention; probe network each session; anchors are fragile;
mixed source/hierarchy writes lost config values.
