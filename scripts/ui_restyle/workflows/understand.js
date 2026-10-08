export const meta = {
  name: 'ui-restyle-understand',
  description: 'Read-only audit of every Pulse Racers UI owner, delivery rules and Roblox UI practice ahead of the restyle',
  phases: [
    { title: 'Understand', detail: 'parallel readers over UI owners in live Studio, project rules, platform research' },
    { title: 'Gaps', detail: 'completeness critic, then follow-up readers for anything uncovered' },
  ],
}

const DIR = 'C:/Users/Oscar/AppData/Local/Temp/claude/C--Users-Oscar-Documents-LUCIDITY-Codex---Neo-Tokyo-Racers/7ae7a4c9-9cc9-42f4-963e-128daf46addb/scratchpad/ui_restyle_audit'
const SID = '9caa35ea-5714-406b-9ad3-1c2905e20d42'

const COMMON = `You are auditing the UI of a Roblox game (player-facing title "Pulse Racers"; the Studio place is named "Space Racers v3", placeId 93959280828322) ahead of a full UI restyle. The repo is the current working directory.

STRICTLY READ-ONLY. Do not edit any repo file. Do not change anything in Studio. Do not start Play. Do not call multi_edit, insert_asset, generate_*, upload_image, store_image, start_stop_play or the input tools. Never require() a gameplay module through execute_luau. The ONLY file you may write is your single notes file named below.

What is planned (read this first, about 230 lines): docs/design/pulse-racers-ui-style-sheet.md. The owner wants: the new style applied to ALL UI so it is cohesive; UI built from shared components (cards, tiles, buttons, panels, stat panel) for consistency; better scaling and alignment across PC resolutions, ultrawide and phone landscape; good performance without losing quality; and the OLD UI kept intact as a backup that the game can be switched back to.

Live Studio is the source of truth for script source. Load the Studio tools with ToolSearch query "select:mcp__Roblox_Studio__script_read,mcp__Roblox_Studio__script_grep,mcp__Roblox_Studio__search_game_tree,mcp__Roblox_Studio__inspect_instance,mcp__Roblox_Studio__execute_luau,mcp__Roblox_Studio__list_roblox_studios". Use studio_id "${SID}" (Studio is in Edit mode; datamodel_type is "Edit"). If the id is rejected, call list_roblox_studios and pick the instance named "Space Racers v3 (placeId: 93959280828322)". Other agents are reading the same Studio in parallel: if a call fails transiently, wait and retry up to 3 times. script_read target_file format is "game.ReplicatedStorage.Modules.Game.UI.UITheme". execute_luau is allowed only for read-only queries (for example counting patterns in a script's .Source or listing children).

Known facts from an earlier pass: all UI is built in code (StarterGui is empty); about 20 ScreenGuis exist at start-up; colours live in three near-identical config folders (ReplicatedStorage.Config.UI.DesktopFreeRoamHud.Colours, .Racing.Colours, .GarageExperience) plus Config.UI.Theme (legacy) and roughly 230 Color3.fromRGB literals in scripts; the font Michroma is named in four config values and in script literals; layout numbers live in Config.UI.GarageReplacement attributes (105), DesktopFreeRoamHud.Layout (41) and Racing.Layout/InRace.`

const READER_SCHEMA = {
  type: 'object',
  properties: {
    group: { type: 'string' },
    notesFile: { type: 'string' },
    scripts: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          path: { type: 'string' },
          lines: { type: 'number' },
          role: { type: 'string' },
          startedBy: { type: 'string' },
          screens: { type: 'string' },
          scaling: { type: 'string' },
          coupling: { type: 'string' },
          perf: { type: 'string' },
          styleDebt: { type: 'string' },
        },
        required: ['path', 'role', 'scaling', 'coupling'],
      },
    },
    sharedComponents: { type: 'string' },
    mobileAndInput: { type: 'string' },
    defects: { type: 'array', items: { type: 'string' } },
    restyleSeam: { type: 'string' },
    risks: { type: 'array', items: { type: 'string' } },
    unknowns: { type: 'array', items: { type: 'string' } },
  },
  required: ['group', 'notesFile', 'scripts', 'restyleSeam', 'risks'],
}

const GROUPS = [
  { key: 'freeroam-desktop',
    scripts: ['game.ReplicatedStorage.Modules.Game.UI.DesktopFreeRoamHudUI', 'game.ReplicatedStorage.Modules.Game.UI.FreeRoamVehicleExitButtonClient', 'game.ReplicatedStorage.Modules.Game.Activities.ActivityClient'],
    focus: 'HUD clusters (action bar, cash and rank, minimap, speed and boost gauge, bottom buttons); the car panel and whether it uses the shared vehicle card; the modal layer (settings, controls, cash store, teleport confirm); how speed/boost telemetry reaches the HUD; the UI SCALE (85/100/115) and HUD settings; cash count animation; how other screens hide or suppress this HUD.' },
  { key: 'freeroam-mobile-onboarding',
    scripts: ['game.ReplicatedStorage.Modules.Game.UI.MobileFreeRoamHudUI', 'game.ReplicatedStorage.Modules.Game.Vehicles.MobileDriveControlsClient', 'game.ReplicatedStorage.Modules.Game.UI.OnboardingClient', 'game.ReplicatedStorage.Modules.Game.UI.OnboardingGuideTrailRenderer', 'game.ReplicatedStorage.Modules.Game.UI.SharedTopNotificationUI'],
    focus: 'how desktop versus mobile HUD is chosen; touch control layout and safe areas; whether onboarding highlights UI by instance name or path (this couples the tutorial to the current UI tree and matters for any new view); top notifications.' },
  { key: 'garage-core',
    scripts: ['game.ReplicatedStorage.Modules.Game.Garage.GarageUI', 'game.ReplicatedStorage.Modules.Game.UI.GarageWorkspaceUI', 'game.ReplicatedStorage.Modules.Game.UI.GarageBrowserUI', 'game.ReplicatedStorage.Modules.Game.UI.GarageComponents', 'game.ReplicatedStorage.Modules.Game.UI.GarageModuleCardViewModel'],
    focus: 'the page/state machine (Dealership, Customisation, DriveIn, the Add Modules / Upgrade Modules / Paint Shop hub, slot rail, Owned Modules / Buy Modules, paint channels and areas); where navigation is defined (the style sheet proposes merging the hub into tabs and Owned/Buy into a switch); the VehicleCard and module card component APIs; the stat panel; economy chips; how purchase, equip and paint actions are dispatched; per-category artwork config; preview coupling (skim game.ReplicatedStorage.Modules.Game.Garage.GaragePreviewPresentationClient and PreviewCameraClient only for UI coupling).' },
  { key: 'garage-owned-entry',
    scripts: ['game.ReplicatedStorage.Modules.Game.UI.OwnedGarageBrowserUI', 'game.ReplicatedStorage.Modules.Game.UI.OwnedGarageWorkspaceUI', 'game.ReplicatedStorage.Modules.Game.UI.OwnedGarageClient', 'game.ReplicatedStorage.Modules.Game.UI.GarageInteriorModeUI', 'game.ReplicatedStorage.Modules.Game.UI.GarageInteriorTransitionUI', 'game.ReplicatedStorage.Modules.Game.Dealership.DealershipIntroClient', 'game.ReplicatedStorage.Modules.Game.Dealership.GarageEntranceClient', 'game.ReplicatedStorage.Modules.Game.UI.LoadingTransitionUI'],
    focus: 'owned garage browser and management desk UI, interior HUD (private/invite), entrance prompts and status, dealership intro objective UI, loading transitions between places.' },
  { key: 'racing-menus',
    scripts: ['game.ReplicatedStorage.Modules.Game.Racing.RaceBrowserClient', 'game.ReplicatedStorage.Modules.Game.Racing.RaceEntryPresentationClient', 'game.ReplicatedStorage.Modules.Game.UI.RacingUIComponents', 'game.ReplicatedStorage.Modules.Game.UI.RacingMobileScaledDesktopLayout'],
    focus: 'the 1200x720 reference shell and how it scales; race browser list and detail; time trial / race overview, tier rail, records, vehicle selection (shared vehicle card?); what RacingUIComponents offers and who uses it; how mobile reuses the desktop layout.' },
  { key: 'racing-session',
    scripts: ['game.ReplicatedStorage.Modules.Game.Racing.RaceSessionPresentationClient', 'game.ReplicatedStorage.Modules.Game.Racing.RaceTimeTrialResultCoachClient', 'game.ReplicatedStorage.Modules.Game.Racing.RaceCountdownPresentationClient', 'game.ReplicatedStorage.Modules.Game.Racing.RaceQueueClient', 'game.ReplicatedStorage.Modules.Game.Racing.RaceTransitionClient', 'game.ReplicatedStorage.Modules.Game.Racing.RaceRouteGuideClient', 'game.ReplicatedStorage.Modules.Game.Racing.RaceLifecyclePresentationClient'],
    focus: 'in-race HUD (position, lap, timer, live order, simplified race map, exit confirmation), countdown, queue banner, transition fade, results (where the result payload comes from and which fields exist), route guide arrows; what is updated per frame.' },
  { key: 'map',
    scripts: ['game.ReplicatedStorage.Modules.Game.UI.FullMapUI', 'game.ReplicatedStorage.Modules.Game.UI.MapIconLayer', 'game.ReplicatedStorage.Modules.Game.UI.MapMarkers', 'game.ReplicatedStorage.Modules.Game.UI.MapMath', 'game.ReplicatedStorage.Modules.Game.UI.MapTileSet', 'game.ReplicatedStorage.Modules.Game.UI.RouteGuide', 'game.ReplicatedStorage.Modules.Game.UI.FreeRoamMapPlayerMarkers'],
    focus: 'full-screen map and legend, minimap rendering (tiles, rotation, zoom with speed), icon layer, route line, player markers; whether a round (circular) minimap is feasible with the current rendering (clipping approach); per-frame cost.' },
  { key: 'foundation-startup',
    scripts: ['game.ReplicatedStorage.Modules.Game.UI.ResponsiveUIFoundation', 'game.ReplicatedStorage.Modules.Game.UI.UITheme', 'game.StarterPlayer.StarterPlayerScripts.ClientBase', 'game.ReplicatedStorage.Modules.Core.PathResolver', 'game.ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient', 'game.ReplicatedFirst.Loading.LoadingScreenView'],
    focus: 'the full API of ResponsiveUIFoundation (corners, strokes, bevel, money, metric, confirmation, notifications) and who calls it; how ClientBase discovers and starts client modules (order, list, config) and exactly where one of two alternative UI module sets could be selected at start-up so only one is ever active; find the FeatureFlags module (search the tree for "FeatureFlags" under ReplicatedStorage.Modules.Core and ServerStorage) and report its API, where flags are stored, whether a client can read a flag at start-up, and how flags replicate; the PlayerScripts.Runtime bindable/endpoint convention; Core.Net client usage in brief; the DrivingSpeedEffect ScreenGui inside game.ReplicatedStorage.Modules.Game.Vehicles.DrivingCameraClient (read only that part); the loading and start screens.' },
]

function readerPrompt(g) {
  return `${COMMON}

YOUR GROUP: "${g.key}". Read each of these scripts completely with script_read (for very long scripts read in line ranges until you have all of it):
${g.scripts.map(s => '- ' + s).join('\n')}
If a listed path does not exist, find the right one with search_game_tree and say so.

Particular focus: ${g.focus}

Write your notes to ${DIR}/${g.key}.md (markdown, as long as needed, with line references). For every script cover:
1. Purpose, and who starts it and when (lifecycle: start, stop, cleanup, connections kept).
2. The instance tree it builds: ScreenGui name, DisplayOrder, IgnoreGuiInset, ResetOnSpawn, main containers.
3. The scaling and layout mechanism in detail: reference canvas size, UIScale formula, anchors, offset versus scale sizing, min/max clamps, safe-area handling, how text is sized, what happens on viewport change.
4. Every config folder, value or attribute it reads.
5. Every remote, bindable, attribute or state it depends on, and its public API (functions other modules call, events it listens to or fires).
6. Input: keyboard, gamepad (GuiService selection), touch, ContextActionService.
7. Per-frame or polling work, and rebuild patterns (what is destroyed and recreated, and when). Estimate instance counts where you can.
8. Mobile and touch differences.
9. Hard-coded colours, fonts and sizes (representative sites with line numbers and a rough count).
10. Defects you can see in the source that would hurt scaling, alignment, consistency or performance (with line numbers).
11. The cleanest seam for a new, switchable presentation that leaves this script untouched as the backup: which parts are state/logic and which are view construction; could a new view module call the same remotes and APIs; what must stay single-owner; what other scripts reference this script's instance names.

Then return the structured answer. Keep it compact: every string field 80 words or fewer; at most 8 items in defects and in risks; put the detail in the notes file. notesFile must be the path you wrote.`
}

const DOCS_SCHEMA = {
  type: 'object',
  properties: {
    notesFile: { type: 'string' },
    bindingRules: { type: 'array', items: { type: 'string' } },
    ruleConflictsWithRequest: { type: 'array', items: { type: 'string' } },
    deliveryRoute: { type: 'string' },
    newScriptRoute: { type: 'string' },
    toolingLimits: { type: 'array', items: { type: 'string' } },
    lane: { type: 'string' },
    evidenceAndTesting: { type: 'array', items: { type: 'string' } },
    knownUiIssues: { type: 'array', items: { type: 'string' } },
    lessons: { type: 'array', items: { type: 'string' } },
  },
  required: ['notesFile', 'bindingRules', 'deliveryRoute', 'newScriptRoute', 'lane', 'evidenceAndTesting'],
}

const docsPrompt = `${COMMON}

YOUR JOB: establish what this project's own rules and tooling require for a whole-UI rebuild with a switch back to the old UI. You do not need Studio. Read (search rather than read whole where a file is very long; docs/history is out of scope):
- docs/13_efficient_feature_delivery_protocol.md, docs/14_new_system_readiness_standard.md, docs/15_new_system_contract_template.md
- docs/12_continuous_improvement_workflow.md (find the parallel build lessons and UI lessons)
- docs/architecture/proportional-mcp-delivery.md, architecture-programme.md (FeatureFlags, Core.Net, new feature checklist), studio-testing-playbook.md, naming-and-owners.md, claude-code-setup.md, targeted-capture-workflow.md
- docs/04_customisation_ui.md, docs/06_current_known_issues.md (every UI-related or device-related open issue)
- docs/racing-ui-design-system-2026-07-11.md, docs/ui-free-roam-pc-design-system-2026-07-10.md, docs/shared-responsive-ui-foundation-v1.md, docs/shared-vehicle-card-system-v1.md
- scripts/studio_delivery.py and scripts/feature_installer.py (interfaces and limits: which places they accept, whether they can create NEW ModuleScripts and config folders or only replace existing source bodies and attributes, how AUDIT / APPLY / ROLLBACK are produced)
- one recent multi-script delivery as a worked example: scripts/hover_feel/ (CONTRACT.md, how the installer and rollback were built and served) and scripts/exotic_category/ui_artwork/ or ui_dealership/
- AGENTS.md and CLAUDE.md are already in your context.

Write notes to ${DIR}/docs-and-delivery.md, then return:
- bindingRules: the project rules that bind this work (owners, no duplicate startup owners, no in-game backups unless explicitly requested, authority, capture policy, reviewer step, git).
- ruleConflictsWithRequest: where the owner's new request (keep the old UI as a switchable backup; rebuild every screen) meets a standing rule, and what the rules say about explicit requests.
- deliveryRoute: the exact route to change existing scripts and config in v3.
- newScriptRoute: the exact route to add NEW ModuleScripts and config folders in v3, and whether existing tools support it or a canonical installer is needed.
- toolingLimits: limits that will bite (place assertions, v3 support, network access of execute_luau, capture tool rejecting v3, no loadstring in Play, and so on).
- lane: Fast, Standard or High-Risk for (a) shared tokens/components plus start-up selection, (b) each screen family; with the reason.
- evidenceAndTesting: what evidence each step needs (captures, Play tests, device matrix, two-client, reviewer).
- knownUiIssues: open UI or device issues from docs/06 with their IDs.
- lessons: recorded lessons most relevant to a multi-part UI build.
Keep every string 60 words or fewer.`

const RESEARCH_SCHEMA = {
  type: 'object',
  properties: {
    notesFile: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          topic: { type: 'string' },
          conclusion: { type: 'string' },
          confidence: { type: 'string' },
          source: { type: 'string' },
        },
        required: ['topic', 'conclusion', 'confidence'],
      },
    },
    recommendations: { type: 'array', items: { type: 'string' } },
    cautions: { type: 'array', items: { type: 'string' } },
  },
  required: ['notesFile', 'findings', 'recommendations', 'cautions'],
}

const platformPrompt = `${COMMON}

YOUR JOB: web research on current (2025 to 2026) Roblox UI engineering practice, to decide how to build a sharp, well-aligned, scalable and efficient code-built UI. Load WebSearch and WebFetch with ToolSearch ("select:WebSearch,WebFetch"). Prefer create.roblox.com/docs and devforum.roblox.com announcements and staff posts; give the URL for every claim; mark anything you could not confirm. You may also use the Studio tool mcp__Roblox_Studio__skill (load it with ToolSearch) to search Roblox docs if it offers that. Topics:
1. Scaling strategy: one UIScale on a reference canvas versus scale-based sizes versus anchored clusters; how each affects text sharpness and pixel alignment (fractional pixels, blurry text, 1px hairlines at non-integer scales); best practice for hairlines and thin rules.
2. Layout: UIListLayout flex (UIFlexItem), AutomaticSize, UIGridLayout, UIAspectRatioConstraint, UISizeConstraint, UITextSizeConstraint; cost of layout invalidation; ScrollingFrame best practice for horizontal rails.
3. Text: FontFace weights and italics, TextScaled pitfalls, RichText, text bounds measurement, tabular or fixed-width digits for changing numbers.
4. UI styling: StyleSheet / StyleRule / StyleLink / tokens. Is it released for production, what does it support, performance, limits, and is it a sound way to switch a whole theme on a code-built UI?
5. Rendering cost: CanvasGroup (memory, when it re-renders), UIStroke, UIGradient, UICorner, ImageLabel 9-slice, transparency overdraw, many small frames versus images; batching; ScreenGui count and DisplayOrder; what causes UI re-layout or re-draw each frame.
6. Glow and soft shadow techniques without a native blur; image resolution and ScaleType for crisp results on high-DPI and phone screens.
7. Path2D (UI vector paths): is it production-ready, can it draw arcs for a speed gauge and a route outline, cost versus images.
8. Clipping to a circle for a round minimap: CanvasGroup with UICorner versus mask image; costs.
9. Gamepad and keyboard navigation: GuiService.SelectedObject, selection groups, SelectionImageObject styling, auto-selection rules.
10. Safe areas and insets on phones: ScreenInsets, GuiService:GetGuiInset, notch handling in landscape.
11. Updating UI efficiently: property writes per frame, tweens versus manual lerp, pooling tiles versus destroy and recreate, instance count guidance, memory.
12. Any 2025 to 2026 UI engine features that would change the plan (new stroke options, text features, UI drag, layout additions).
Write notes to ${DIR}/roblox-platform.md. Return findings (one per topic at least; conclusion 60 words or fewer; confidence high/medium/low), recommendations (concrete, for this build), and cautions.`

const fontsPrompt = `${COMMON}

YOUR JOB: fonts, existing image assets and the asset route.
A. Fonts. The style sheet wants one heavy condensed italic face (the mockups use Barlow Condensed ExtraBold Italic, like Need for Speed Heat). A probe showed Barlow Condensed and Kanit are NOT shipped as rbxasset families, while Titillium Web, Roboto Condensed and Source Sans Pro ship with a real italic, and Oswald ships without one.
 - With a read-only execute_luau in Edit, enumerate every shipped font family (iterate Enum.Font, use Font.fromEnum to get the family) and, with TextService:GetTextBoundsAsync on a GetTextBoundsParams (never parent an instance), measure each family at Bold and at the heaviest weight, Normal versus Italic, to find which have a real italic and how wide they set "CUSTOMISE 0123456789" at size 40. Report the narrow, heavy, real-italic candidates.
 - Web research (load WebSearch and WebFetch with ToolSearch): are Creator Store fonts (create.roblox.com/store/fonts) usable in experiences in 2025 to 2026, how are they referenced in code (Font.new with an rbxassetid family?), is Barlow Condensed (or a close match: Saira Condensed, Big Shoulders, Fjalla One, League Gothic Italic, Bebas Neue, Anton, Teko, Rajdhani, Chakra Petch, Exo 2) available there, and can developers upload custom fonts? Give URLs. If a family asset id is found, test it with the same read-only GetTextBoundsAsync probe.
B. Existing image assets. Using search_game_tree and inspect_instance (or one read-only execute_luau), list the image and icon assets already referenced under ReplicatedStorage.Config.UI (DesktopFreeRoamHud.Assets, MobileFreeRoamHud.Assets, Racing.Assets, GarageReplacement.NavigationIcons, ModuleArtwork, OwnedGarageIcons, MapIcons, LoadingSystem and others): name, asset id, and what each is for. Say which of the style sheet's icons already exist (car, garage/home, race flag, tools, settings, exit, back, drive wheel, lock and so on) and which are missing.
C. Asset route. From the repo, find how images were made and uploaded before (scripts/map_art/README.md, scripts/hover_feel/vfx_textures/, scripts/exotic_category/mesh/images.py and compose_diagrams.py, any use of the Studio upload_image / store_image tools, and docs mentioning image upload). Report the working route, its limits, and whether uploads need the owner to act.
Write notes to ${DIR}/fonts-assets.md. Return findings (conclusion 60 words or fewer each), recommendations and cautions.`

phase('Understand')
const thunks = GROUPS.map(g => () => agent(readerPrompt(g), { label: `read:${g.key}`, phase: 'Understand', schema: READER_SCHEMA }))
thunks.push(() => agent(docsPrompt, { label: 'docs-and-delivery', phase: 'Understand', schema: DOCS_SCHEMA }))
thunks.push(() => agent(platformPrompt, { label: 'roblox-platform', phase: 'Understand', schema: RESEARCH_SCHEMA }))
thunks.push(() => agent(fontsPrompt, { label: 'fonts-assets', phase: 'Understand', schema: RESEARCH_SCHEMA }))
const all = await parallel(thunks)
const readers = all.slice(0, GROUPS.length)
const docs = all[GROUPS.length]
const platform = all[GROUPS.length + 1]
const fonts = all[GROUPS.length + 2]
const failed = GROUPS.filter((g, i) => !readers[i]).map(g => g.key)
if (failed.length) log(`Readers that returned nothing: ${failed.join(', ')}`)

phase('Gaps')
const CRITIC_SCHEMA = {
  type: 'object',
  properties: {
    notesFile: { type: 'string' },
    uncoveredGroups: {
      type: 'array',
      items: {
        type: 'object',
        properties: { key: { type: 'string' }, scripts: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } },
        required: ['key', 'scripts', 'why'],
      },
    },
    otherSurfaces: { type: 'array', items: { type: 'string' } },
    contradictions: { type: 'array', items: { type: 'string' } },
    openQuestions: { type: 'array', items: { type: 'string' } },
  },
  required: ['notesFile', 'uncoveredGroups', 'otherSurfaces', 'contradictions', 'openQuestions'],
}
const covered = GROUPS.flatMap(g => g.scripts)
const critic = await agent(`${COMMON}

YOUR JOB: completeness critic. Readers have audited these scripts:
${covered.map(s => '- ' + s).join('\n')}
Groups whose reader failed (treat their scripts as uncovered): ${failed.join(', ') || 'none'}.
Their notes are in ${DIR}/ (read them; one .md per group, plus docs-and-delivery.md, roblox-platform.md, fonts-assets.md).

1. With one read-only execute_luau in Edit, sweep EVERY LuaSourceContainer in the place (ReplicatedStorage, ReplicatedFirst, StarterPlayer, StarterGui, ServerScriptService, ServerStorage, Workspace) and list those whose Source creates or styles player-visible UI: Instance.new of ScreenGui, BillboardGui, SurfaceGui, TextLabel, TextButton, ImageLabel, ImageButton, Frame, ProximityPrompt, Highlight used as UI; StarterGui:SetCore or SetCoreGuiEnabled; GuiService or TopBar changes; PlayerGui access. Return path, line count and which patterns matched. Also list any pre-built GUI instances (ScreenGui, BillboardGui, SurfaceGui) that exist in the place hierarchy rather than being built in code (for example signs in Workspace are world art and can be ignored; name-tags, prompts, markers and vehicle or garage billboards are UI).
2. Compare with the covered list. Anything player-visible that no reader covered goes into uncoveredGroups: group related scripts (at most 4 groups, at most 6 scripts each), give full "game...." paths, and say why it matters for a cohesive restyle (for example world prompts, name tags, race arrows, vehicle seat prompts, dev panels, server-created GUIs).
3. otherSurfaces: UI that is not a script to read but must be decided on (Roblox core UI such as the top bar, chat, player list, proximity prompt default style, purchase prompts, the start screen logo art).
4. contradictions: places where two readers' notes disagree, or a reader's claim looks wrong against the source (check a few claims yourself).
5. openQuestions: what is still unknown that the build will need.
Write notes to ${DIR}/critic.md. Keep every string 60 words or fewer.`, { label: 'completeness-critic', phase: 'Gaps', schema: CRITIC_SCHEMA })

let followups = []
if (critic && critic.uncoveredGroups && critic.uncoveredGroups.length) {
  const groups = critic.uncoveredGroups.slice(0, 4)
  if (critic.uncoveredGroups.length > 4) log(`Critic named ${critic.uncoveredGroups.length} uncovered groups; reading the first 4 only`)
  followups = (await parallel(groups.map(g => () => agent(readerPrompt({ key: 'followup-' + g.key.replace(/[^a-z0-9-]/gi, '-'), scripts: g.scripts, focus: g.why }), { label: `read:${g.key}`, phase: 'Gaps', schema: READER_SCHEMA })))).filter(Boolean)
}

return { notesDir: DIR, readers: readers.filter(Boolean), failed, docs, platform, fonts, critic, followups }
