export const meta = {
  name: 'ui-restyle-design-panel',
  description: 'Three independent build proposals for the Pulse Racers UI restyle, adversarial review, synthesis and fact check (read-only)',
  phases: [
    { title: 'Propose', detail: 'three proposals from different priorities' },
    { title: 'Attack', detail: 'three reviewers try to break each proposal' },
    { title: 'Synthesise', detail: 'one recommended plan, then a fact check against live source' },
  ],
}

const ROOT = 'C:/Users/Oscar/AppData/Local/Temp/claude/C--Users-Oscar-Documents-LUCIDITY-Codex---Neo-Tokyo-Racers/7ae7a4c9-9cc9-42f4-963e-128daf46addb/scratchpad/ui_restyle_audit'
const SID = '9caa35ea-5714-406b-9ad3-1c2905e20d42'

const BRIEF = `You are helping plan a full UI rebuild for a Roblox game (player-facing title "Pulse Racers"; Studio place "Space Racers v3", placeId 93959280828322). The repo is the current working directory.

STRICTLY READ-ONLY. Do not edit repo files or Studio, do not start Play, never require() a gameplay module through execute_luau. The ONLY file you may write is the one named in your task. Studio tools (read-only use only) load with ToolSearch "select:mcp__Roblox_Studio__script_read,mcp__Roblox_Studio__script_grep,mcp__Roblox_Studio__search_game_tree,mcp__Roblox_Studio__inspect_instance,mcp__Roblox_Studio__execute_luau,mcp__Roblox_Studio__list_roblox_studios"; studio_id "${SID}", Edit mode. Retry transient failures.

THE OWNER'S REQUEST, verbatim: "use recommended steps to get ui similar to the previews shown, but improve them to scale better, align better, more consistent, refined, and any other steps recommended to get best possible look. ensure there is good optimisation with it (but dont sacrifice quality), keep the old ui as a backup, and change all current ui to fit cohesively together. use shared cards etc. to ensure good consistency. ensure we can change back to old ui if needed. let me know of any recommendations you have first"

INPUTS YOU MUST READ:
- The visual target: docs/design/pulse-racers-ui-style-sheet.md and the frames in assets/ui/mockups/pulse_restyle/ (view 01, 02, 04 and 05 at least).
- The audit notes in ${ROOT}/ : freeroam-desktop.md, freeroam-mobile-onboarding.md, garage-core.md, garage-owned-entry.md, racing-menus.md, racing-session.md, map.md, foundation-startup.md, followup-activity-views.md, followup-world-prompts.md, followup-ui-coupled-runtime.md, followup-dev-studio-panels.md, docs-and-delivery.md, roblox-platform.md, fonts-assets.md, critic.md. Read critic.md, foundation-startup.md, docs-and-delivery.md, roblox-platform.md and fonts-assets.md in full; read the others at least for their scaling, coupling, defects and seam sections.

KEY FACTS FROM THE AUDIT (verify in the notes or live source before relying on any of them):
- All UI is built in code. Every UI owner is one closure that exports only start(); logic and view are interleaved. ClientBase starts client modules through Core.ClientLifecycle from an entry list with a path resolve callback (about lines 105 to 109). Several readers recommend choosing old or new module paths there, once, so only one of each pair is ever required and old scripts stay byte-identical.
- 19 scripts require RacingUIComponents (Panel, Label, Button, token readers) and 9 require GarageComponents (VehicleCard, cards, ActionButton, Popup, dropdown). ResponsiveUIFoundation gives primitives (corner, stroke, bevel, money, cash presenter, one confirmation, one toast stack). Making those style-aware IN PLACE would change the old UI, which conflicts with "keep the old UI as a backup"; the critic lists this as the main contradiction. Some surfaces (ActivityClient and its four views, OnboardingClient, owned-garage desk) only restyle through those shared modules today.
- No shared scale source exists. Clamps differ: free-roam HUD min(vw/1920, vh/1080) clamped 0.72 to 1.12; garage MaxScale 1.02 on a 1600x900 reference; racing shell 1200x720 capped at 1.15; phones shrink the desktop canvas to about 0.43, giving 4 to 9 px text and 20 px buttons. No real safe-area maths outside the foundation and race HUD. Touch-plus-keyboard devices start both HUDs. Four different "is mobile" tests exist.
- Performance debt in the old owners: per-frame config lookups and property rewrites, recursive PlayerGui searches on timers, full page rebuilds on every click (garage about 300 instances), about 420 of the desktop HUD's 610 start-up instances are modals most sessions never open, three owners save/restore ScreenGui.Enabled.
- Coupling to respect: OnboardingClient finds targets by instance name, button text and attributes and locks buttons named Car, Race, Garage; FullMapUI and others look up DesktopFreeRoamHud and Minimap by name; RaceLifecyclePresentationClient destroys ScreenGuis with reserved names; PresentationAudioClient plays hover and click on every visible GuiButton (attributes UIAudioSilent, UIAudioSuppressClick, UIAudioHoverCue); TrailerModeClient hides ScreenGuis directly under PlayerGui; GarageSessionActive is the only garage-open signal; bindables live under PlayerScripts.Runtime.
- Core.FeatureFlags is a ServerStorage module: clients cannot read it. A replicated Config attribute was used for client switches before (FEEL-01 precedent). Several existing bool readers return the fallback for a configured false.
- Roblox platform: TextSize is capped at 100 and is line height, not CSS em size (the sheet's sizes are CSS sizes; the sheet's 136 and 200 are impossible as TextSize). Animating UIScale on text flickers. A ScreenGui re-renders whole when any descendant changes, so static and dynamic UI should be in separate ScreenGuis. StyleSheets are released but unsuitable as the switch. UIShadow (coloured glow, no upload) is reported released June 2026 but unverified on a live client. CanvasGroup needs ZIndexBehavior.Sibling; eleven ScreenGuis are Global today. Flex layout is released and unused. Staff guidance favours anchored clusters with fixed-offset content.
- Fonts: Barlow Condensed (used in the mockups) is not available and custom fonts cannot be uploaded. Creator Store Barlow (rbxassetid://12187372847) and Kanit have 18 faces including 800 and 900 italics and measured correctly in v3; Barlow has proportional digits. Titillium Web (shipped) has no italic above Bold and small caps for its line height. Roboto Condensed ships with Bold Italic. Italic faces are cloud assets either way.
- Config.UI holds 130 image references; most icons are white tintable glyphs with inconsistent padding; some art has baked colour. Uploads need the owner's approval per asset. Two upload routes exist.
- Delivery: scripts/studio_delivery.py, feature_installer.py and studio_capture.py all refuse the v3 place. v3 deliveries so far used per-task folders (scripts/hover_feel, scripts/driving_tune, scripts/lighting_realism) with serve.py, exact before-sources, build.py, and AUDIT / APPLY / ROLLBACK run through execute_luau in Edit with hash guards. Creating NEW ModuleScripts in v3 is not yet proven (the lighting_realism engine has an unused create op). Script Source limit is 200,000 characters. v3 Play saves the owner's real profile (purchases spend real in-game Cash; time-trial finishes write personal bests); the no-save sandbox is off.
- Project rules that bind: one owner per concern; no duplicate startup owners; no in-game backups or fallback implementations UNLESS explicitly requested (the owner has now explicitly requested a switchable old UI); authority and server payloads unchanged; mobile designed with each feature (LandscapeSensor, 48 px targets, safe areas), not as a late pass; contract first; parallel build agents never touch Studio or git, one folder each, the integrator installs and Play-tests; delivery-reviewer before APPLY on High-Risk work; plan approval before mutation.
- Not in the mockups but on screen: Roblox player list (top-right, where the sheet puts the status cluster), chat (top-left, where the sheet puts titles), top bar inset, default proximity prompts (ten families), default gamepad selection box, on-foot touch controls, name tags, core notifications.
- Known errors in the style sheet: wrong font assumption, CSS sizes, sizes above 100, Core.FeatureFlags as the switch, GarageReplacementComponents (the real card is GarageComponents.VehicleCard), studio_delivery.py as the route, Standard lane for the foundation step, "instance counts within 10% of today", phone minimap bottom-left (phones have it top-right because steering holds bottom-left), results XP from the result payload (it is not in the payload), phone and controller as a last step.`

const clip = (s, n) => (typeof s === 'string' && s.length > n ? s.slice(0, n) + ' [...]' : s)
const clipArr = (a, n, m) => (Array.isArray(a) ? a.slice(0, n).map(x => (typeof x === 'string' ? clip(x, m) : x)) : a)
const SID_NOTE = 'IMPORTANT: Studio was restarted since the brief above was written. The studio_id in the brief is stale. Use studio_id "1071f5cf-8bbe-4913-acf7-1c4c410323d9" (the instance named "Space Racers v3 (placeId: 93959280828322)", Edit mode); if it is rejected, call list_roblox_studios.\n\n'

const PROPOSAL_SCHEMA = {
  type: 'object',
  properties: {
    proposalFile: { type: 'string' },
    name: { type: 'string' },
    switchModel: { type: 'string' },
    editedOldScripts: { type: 'array', items: { type: 'string' } },
    kit: { type: 'string' },
    scaling: { type: 'string' },
    performance: { type: 'string' },
    phases: { type: 'array', items: { type: 'string' } },
    decisions: { type: 'array', items: { type: 'string' } },
    risks: { type: 'array', items: { type: 'string' } },
  },
  required: ['proposalFile', 'name', 'switchModel', 'editedOldScripts', 'kit', 'scaling', 'performance', 'phases', 'decisions', 'risks'],
}

const LENSES = [
  { key: 'A-safest-backup', lens: 'Your priority: the safest possible backup and the lowest regression risk. The old UI must remain provably the same as today when switched back, switching must be simple and reliable, and every step must be reversible. Minimise edits to existing scripts and say exactly which are unavoidable.' },
  { key: 'B-most-cohesive', lens: 'Your priority: the most cohesive, consistent and maintainable end state. One source of truth for tokens, scale, safe area, form factor and components; least duplicated logic between old and new; every surface on the same kit (HUD, menus, garage, map, prompts, toasts, activity HUD, onboarding, loading). Say honestly what that costs the backup and how you keep the backup anyway.' },
  { key: 'C-quality-and-speed', lens: 'Your priority: the best-looking, sharpest, best-performing result on PC and phone landscape, reached by the shortest safe path: a rendering spike to settle font, hairlines, glow and big numbers, then a one-screen pilot, then families in the order that shows value earliest. Set explicit performance and legibility budgets and how each is measured.' },
]

const proposalPrompt = l => `${BRIEF}

YOUR TASK: write one complete, independent build proposal. ${l.lens}

Write it to ${ROOT}/design/proposal-${l.key}.md. It must cover, concretely (module names, script paths, line references where relevant):
1. Switch model: how the game chooses old or new UI, where the value lives, when it is read, what a first joiner on a fresh server gets, how the owner switches back, and how you guarantee old and new never both run. List every EXISTING script that must be edited and exactly why; everything else stays byte-identical.
2. What happens to surfaces that only restyle through shared modules (ActivityClient views, OnboardingClient, owned-garage desk, toasts, confirmations, loading and start screens, proximity prompts, speed lines).
3. The new shared kit: module list, each component's API in one line (Panel, Tile, Rail, Button variants, Tabs, StatusCluster, CashChip, StatPanel, SegmentedBar, FactList, Modal/Confirm, Toast, PromptBanner, Icon, Glow, BigNumber), the token source and reader, and the contracts every component obeys (onboarding names, audio attributes, gamepad focus, trailer mode, reserved ScreenGui names).
4. Scaling, alignment and sharpness: one scale and safe-area service, the reference and clamps, how hairlines stay crisp, how text sizes are specified (cap height), numbers above TextSize 100, the form-factor rule, real phone-landscape layouts versus scaled canvases, ultrawide behaviour, the player Text Size setting.
5. Performance: static and dynamic ScreenGui split, pooling, lazy modals, per-frame write rules, instance and frame budgets and how they are measured.
6. Fonts and assets: the typeface decision route, preload, icon sheet, glow route, what must be uploaded and approved.
7. Roblox core UI policy (player list, chat, top bar inset, selection image, on-foot touch controls, name tags) and world prompts.
8. Navigation changes in the sheet (customise hub into tabs, Owned/Buy switch): in or out, and how onboarding survives.
9. Phases in order: each with scope, new modules, lane (Fast, Standard, High-Risk), what the parallel build agents can do versus the integrator, and the verification that ends it. Include how installs are done in v3 (new ModuleScripts, config) and how Play testing avoids changing the owner's saved profile.
10. Decisions the owner must make, each with your recommended default. Top risks and how each is contained.

Then return the structured summary. Hard limits: every string 110 words or fewer; editedOldScripts full "game...." paths; phases as one line each ("N. name - scope - lane - gate"), at most 10; decisions at most 10; risks at most 8.`

phase('Propose')
const proposals = (await parallel(LENSES.map(l => () => agent(proposalPrompt(l), { label: `propose:${l.key}`, phase: 'Propose', schema: PROPOSAL_SCHEMA })))).filter(Boolean)
log(`${proposals.length} of ${LENSES.length} proposals returned`)

phase('Attack')
const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    reviewFile: { type: 'string' },
    ranking: { type: 'array', items: { type: 'string' } },
    fatalFlaws: { type: 'array', items: { type: 'string' } },
    graft: { type: 'array', items: { type: 'string' } },
    mustFix: { type: 'array', items: { type: 'string' } },
  },
  required: ['reviewFile', 'ranking', 'fatalFlaws', 'graft', 'mustFix'],
}
const REVIEWERS = [
  { key: 'rules-and-regression', lens: 'Project rules, ownership and regression. Check each proposal against AGENTS.md, CLAUDE.md, docs/13, docs/14 and docs-and-delivery.md: one owner per concern, startup rules, backup exception and its limits, authority and payloads unchanged, mobile designed with the feature, installer and capture discipline, lanes and reviewer steps. Hunt for hidden coupling the proposal breaks (onboarding names and texts, reserved ScreenGui names, audio contract, trailer mode, GarageSessionActive, visibility owners, preview clearing) and for any way old and new could both run or the old UI could differ after switching back. Verify at least five of each proposal\'s factual claims against live source.' },
  { key: 'platform-and-performance', lens: 'Roblox engine correctness and performance. Check each proposal against roblox-platform.md and fonts-assets.md and, where needed, a read-only Studio probe: TextSize cap, cap-height sizing, UIScale and hairlines, ScrollingFrame behaviour, CanvasGroup and ZIndexBehavior, UIShadow status, flex, selection and gamepad focus, safe-area APIs, ScreenGui re-render behaviour, font loading, replication timing of the switch value in ReplicatedFirst. Flag anything that depends on an unverified or beta engine feature, anything that will be blurry, misaligned or slow on a phone, and any budget that is not measurable.' },
  { key: 'completeness-and-ux', lens: 'Completeness against the owner\'s request and consistency of the result. For each proposal: does EVERY player-visible surface end up cohesive (use critic.md\'s lists, including Roblox core UI and world prompts), or does something stay old-style under the new switch? Are shared cards and components truly shared (no copied coordinates)? Does it really improve scaling and alignment on 1280x720, 1440p, ultrawide and phone landscape, with real phone layouts? Is switching back genuinely one action? Are the phases and the amount of owner involvement realistic, and are the decisions put to the owner the right ones and few enough?' },
]
const reviewPrompt = r => `${BRIEF}

${SID_NOTE}YOUR TASK: adversarial review. Three independent proposals are in ${ROOT}/design/ : ${proposals.map(p => p.proposalFile).join(' ; ')}. Read all three in full, plus the audit notes you need. Your lens: ${r.lens}

Try to break each proposal. Default to treating an unverified claim as wrong until you have checked it. Write your review to ${ROOT}/design/review-${r.key}.md with, for each proposal: fatal flaws, serious flaws, claims you checked and the result, and its best ideas. End with the plan you would build from the best parts.

Return: ranking (best first, one line each with the reason); fatalFlaws (each prefixed with the proposal letter); graft (the best ideas worth taking from any proposal, with the letter); mustFix (what the final plan must contain or change regardless of which proposal wins). Every string 70 words or fewer; at most 10 items per list.`

const reviews = (await parallel(REVIEWERS.map(r => () => agent(reviewPrompt(r), { label: `attack:${r.key}`, phase: 'Attack', schema: REVIEW_SCHEMA })))).filter(Boolean)
log(`${reviews.length} of ${REVIEWERS.length} reviews returned`)

phase('Synthesise')
const PLAN_SCHEMA = {
  type: 'object',
  properties: {
    planFile: { type: 'string' },
    headline: { type: 'string' },
    recommendations: {
      type: 'array',
      items: {
        type: 'object',
        properties: { title: { type: 'string' }, what: { type: 'string' }, why: { type: 'string' }, tradeoff: { type: 'string' } },
        required: ['title', 'what', 'why'],
      },
    },
    decisions: {
      type: 'array',
      items: {
        type: 'object',
        properties: { question: { type: 'string' }, recommended: { type: 'string' }, why: { type: 'string' } },
        required: ['question', 'recommended'],
      },
    },
    phases: { type: 'array', items: { type: 'string' } },
    editedOldScripts: { type: 'array', items: { type: 'string' } },
    newModules: { type: 'array', items: { type: 'string' } },
    notInScope: { type: 'array', items: { type: 'string' } },
    risks: { type: 'array', items: { type: 'string' } },
    checkableClaims: { type: 'array', items: { type: 'string' } },
  },
  required: ['planFile', 'headline', 'recommendations', 'decisions', 'phases', 'editedOldScripts', 'newModules', 'notInScope', 'risks', 'checkableClaims'],
}
const plan = await agent(`${BRIEF}

${SID_NOTE}YOUR TASK: synthesise ONE recommended plan. Proposals: ${proposals.map(p => p.proposalFile).join(' ; ')}. Reviews: ${reviews.map(r => r.reviewFile).join(' ; ')}. Read all of them in full. Start from the proposal the reviewers rank highest, fix every fatal flaw and must-fix item, and graft the best ideas from the others. Where reviewers disagree, decide and say why. Do not invent facts: anything unverified must be labelled as needing a spike or a check.

Write the full plan to ${ROOT}/design/recommended-plan.md, structured as: switch model and exact list of edited existing scripts; shared kit (modules, components, contracts); scale, safe-area and form-factor service; type and number rules; performance budgets and how they are measured; fonts and assets; Roblox core UI and prompt policy; navigation changes; phases with scope, lane, build split (parallel agents versus integrator) and exit gate; delivery and test route in v3; what is out of scope; risks.

Return the structured summary. Hard limits:
- headline: 70 words or fewer.
- recommendations: 10 to 14, the things the owner should hear before any build starts, in priority order. title 8 words or fewer; what, why and tradeoff 45 words or fewer each, in plain language for a game owner who is not a programmer.
- decisions: at most 9, only ones the owner must make; question 30 words or fewer, recommended 30 words or fewer, why 30 words or fewer.
- phases: at most 10, one line each "N. name - scope - lane - exit gate", 45 words or fewer.
- editedOldScripts: full paths with a few words on why. newModules: names with a few words each, at most 30.
- notInScope and risks: at most 8 each, 35 words or fewer.
- checkableClaims: the 12 factual claims the plan depends on most, each phrased so it can be checked against live Studio source or config (script path and what must be true).`, { label: 'synthesise-plan', phase: 'Synthesise', schema: PLAN_SCHEMA })

const CHECK_SCHEMA = {
  type: 'object',
  properties: {
    checkFile: { type: 'string' },
    results: {
      type: 'array',
      items: {
        type: 'object',
        properties: { claim: { type: 'string' }, verdict: { type: 'string' }, evidence: { type: 'string' }, fix: { type: 'string' } },
        required: ['claim', 'verdict', 'evidence'],
      },
    },
    planErrors: { type: 'array', items: { type: 'string' } },
  },
  required: ['checkFile', 'results', 'planErrors'],
}
let check = null
if (plan) {
  check = await agent(`${BRIEF}

${SID_NOTE}YOUR TASK: fact check. A recommended plan is at ${plan.planFile}. Read it in full. Check each of these claims against LIVE Studio source and config (script_read, inspect_instance, read-only execute_luau), not against the audit notes:
${(plan.checkableClaims || []).map((c, i) => (i + 1) + '. ' + c).join('\n')}
Then read the plan once more looking for anything else that is factually wrong, internally inconsistent, or that breaks a project rule in AGENTS.md.
In particular confirm from live source: how ClientBase resolves and starts modules and whether one path per entry can be chosen there; whether an attribute or value under ReplicatedStorage.Config is readable from ReplicatedFirst code before the loading screen draws; which scripts require RacingUIComponents and GarageComponents; whether a ModuleScript created at Edit time under ReplicatedStorage.Modules.Game.UI would be picked up without other registration.
Write ${ROOT}/design/fact-check.md. Return results (verdict is one of CONFIRMED, WRONG, PARTLY, UNVERIFIABLE; evidence 45 words or fewer with script and line; fix 30 words or fewer when not CONFIRMED) and planErrors (at most 10, 45 words or fewer each).`, { label: 'fact-check', phase: 'Synthesise', schema: CHECK_SCHEMA })
}

return {
  proposals: proposals.map(p => ({ name: p.name, file: p.proposalFile, switchModel: clip(p.switchModel, 700), editedOldScripts: clipArr(p.editedOldScripts, 20, 200) })),
  reviews: reviews.map(r => ({ file: r.reviewFile, ranking: clipArr(r.ranking, 4, 400), fatalFlaws: clipArr(r.fatalFlaws, 10, 420), mustFix: clipArr(r.mustFix, 10, 420) })),
  plan: plan && {
    planFile: plan.planFile,
    headline: clip(plan.headline, 600),
    recommendations: (plan.recommendations || []).slice(0, 14).map(x => ({ title: clip(x.title, 90), what: clip(x.what, 380), why: clip(x.why, 380), tradeoff: clip(x.tradeoff, 380) })),
    decisions: (plan.decisions || []).slice(0, 9).map(x => ({ question: clip(x.question, 260), recommended: clip(x.recommended, 260), why: clip(x.why, 260) })),
    phases: clipArr(plan.phases, 10, 420),
    editedOldScripts: clipArr(plan.editedOldScripts, 25, 220),
    newModules: clipArr(plan.newModules, 30, 160),
    notInScope: clipArr(plan.notInScope, 8, 300),
    risks: clipArr(plan.risks, 8, 300),
  },
  check: check && { checkFile: check.checkFile, results: (check.results || []).map(x => ({ claim: clip(x.claim, 220), verdict: x.verdict, evidence: clip(x.evidence, 320), fix: clip(x.fix, 220) })), planErrors: clipArr(check.planErrors, 10, 360) },
}
