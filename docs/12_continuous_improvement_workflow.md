# Continuous Improvement Workflow

## Integrated replacement must retire companion UI lesson (2026-07-26)

When a new canonical screen absorbs data from an older companion panel, completing the renderer does not retire the older event listener automatically. Audit every enabled consumer of the screen-open event. If an older isolated panel now duplicates integrated content, remove that exact owner and add its exact runtime GUI name to cleanup; keep any headless action bridge that still owns required server calls.

Full-screen modal backdrops must be rooted in physical-screen space, not a fixed reference canvas that is aspect-scaled for content. Keep the modal panel on the responsive design canvas, but put its backdrop at the `ScreenGui` viewport boundary, explicitly cover no-inset/safe-area edges, and toggle both through one visibility function.

## Parallel authored entry-point discovery lesson (2026-07-26)

When a lifecycle owner is intended to cover a feature mode, discover targets by the authored semantic contract rather than one observed instance name. Racing has parallel `RaceStartZone` and `TimeTrialStartZone` parts under the same `StartZones` owner, each with a `Mode` attribute and the same native prompt path. Registering only the first visible name can make one mode appear fixed while the other retains stale presentation.

For shared device refinements, change the existing renderer and reuse the shared device classifier. A mobile-only scale should be a normal configuration value with desktop fixed at `1.0`; do not fork a second UI or copy the renderer.

## Same-name visual category lesson (2026-07-26)

Do not collapse visually related authored objects into one configuration switch until their gameplay meaning and runtime owner are mapped. In racing, checkpoint-attached guide arrows and physical route-segment `ArrowMarkers` are both called “arrows,” but the first is optional checkpoint presentation and the second is intended active route guidance owned by the session segment window.

Before disabling a visual category, inventory its hierarchy, renderer and state transitions separately. Prefer distinct semantic config names such as `ShowCheckpointArrows` and `ShowRouteArrowMarkers`, then audit each consumer. Acceptance wording such as “remove arrows” must be resolved against concrete instances/screenshots or current authoring structure before one switch is shared across owners.

An eligible-state controller must also assert the required visible state, not merely restore whatever happened to be authored. Preserve authored values for removal/rollback, but make the active presentation contract explicit. When a server periodically recreates or re-enables a native prompt, the local eligibility owner should reassert only its presentation property and leave trigger validation authoritative.

## Retired-owner regression lesson (2026-07-26)

A broad shared-presentation installer can accidentally reactivate a retired controller when it treats every styled source as an enabled runtime owner. Styling compatibility and lifecycle ownership are separate contracts: a source may retain shared renderer calls for rollback/history while its `LocalScript.Disabled` state must remain true.

Before a connected installer targets multiple UI scripts, compare each target against the newest owner map and mirror `Disabled` state. The preflight must classify active, headless bridge, retained-disabled and superseded sources separately. A recovery installer must never require a retired source to be enabled merely because it contains current shared tokens. Committed audit should reject both missing active owners and reactivated retired owners.

When current documentation and the fresh mirror disagree, treat the mirror as state evidence and older handoffs as intended-contract evidence. Resolve the cause before mutation, then encode the corrected owner set into the new canonical audit.

## Large-script local declaration ordering lesson (2026-07-26)

Luau local function declarations are lexical. A function inserted before `local function LaterHelper()` cannot call `LaterHelper` unless it was explicitly forward-declared in scope; it otherwise resolves a different/global value and can compile successfully but fail only on the branch that reaches the call. Prefer removing unnecessary cross-boundary response work. If it is required, project and runtime-test the success branch as well as early rejection branches.

## Empty-table fallback and preview/projection parity lesson (2026-07-26)

In Lua/Luau, an empty table is truthy. A saved record such as `Colors={}` therefore bypasses `record or fallback` even though it contains no usable channels. If preview fills missing members but server projection does not, the preview can look correct while the spawned and rejoined object retains authored defaults.

Repair incomplete records once at their existing authoritative hydration/normalisation owner, preserve every explicit member, and persist through the existing save bridge. Do not add a client recolour or a second appearance owner. For connected appearance work, audit every current asset and compatible location, then verify preview, spawn, lifecycle transitions, and rejoin from the same effective record.

## Studio Command Bar persistence fault lesson (2026-07-19)

If an installer reports success but newly created instances disappear while edits to existing Script sources remain, stop changing feature code. Create a harmless uniquely named Folder in one Command Bar command and read it in a second command in the same place. If that generic probe also disappears, fully restart Studio and repeat it before repairing the installer. A passing post-restart probe identifies a session-level Studio transaction fault; do not add feature-specific recovery logic or blame the Command Bar history-size warning without independent evidence.

If the same fault later recurs and the feature can reuse an existing intended owner, prefer a source-only canonical repair over another hierarchy recovery. Optional generated config/icon folders must use existing-folder or source-default fallbacks rather than hard `WaitForChild` dependencies, and companion HUD behaviour should be folded into the already-designated HUD-policy owner when that preserves ownership boundaries. Record the mixed source/hierarchy state in the mirror before repairing it.

If a fresh mirror proves the source half is already correct but the required non-source contract is itself the blocker, the inverse recovery is allowed: require/compile the committed source without assigning `Source`, mutate only attributes/hierarchy, restart Studio, then run a separate read-only committed-state audit. Assigning identical Source text still counts as a mixed transaction and must be avoided.

**Created:** 2026-07-02  
**Purpose:** Make each Neo Tokyo Racers chat safer, faster, and more useful than the last one.

This project improves through confirmed baselines, good failure notes, and small repeatable scripts. Future chats should treat this file as part of the startup context.

## Startup Rule For New Chats

Before planning or patching, read:

- `AGENTS.md`
- `docs/00_START_HERE.md`
- `docs/06_current_known_issues.md`
- `docs/07_patch_history.md`
- `docs/10_script_source_sync_workflow.md`
- `docs/11_manual_script_copy_map.md`
- this file
- `docs/13_efficient_feature_delivery_protocol.md` for risk lanes, one-install delivery, ownership gates, acceptance contracts, and reusable templates
- `docs/14_new_system_readiness_standard.md` before new systems, substantial expansions, or connected networking/persistence/runtime work
- `docs/15_new_system_contract_template.md` for the compact Standard or full High-Risk contract

Then check `git status --short`.

If the task touches a specific area, read its topic doc before writing a script.

## Implementation Triage And Chat Modes

Apply this to all implementation work, including new systems, phased plans, fixes, UI tweaks, balance changes, refinements, and polish.

Before changing files or writing a Studio command-bar script, classify the request:

- **Do now:** blockers, broken tests, regressions, confusing entry flow, or anything needed to verify the current task safely.
- **Do now if small:** isolated config, copy, layout, or tuning changes that do not disturb confirmed baselines or unrelated systems.
- **Suggest later:** polish, balancing, broad visual refinement, non-blocking UX cleanup, or anything better batched after the core loop is stable.
- **Pause and discuss:** architecture, data ownership, persistence, economy, matchmaking, anti-cheat, player-created content, live-source ambiguity, or changes that may fight a confirmed working baseline.

When the user asks for a mid-stream adjustment or refinement, do not blindly implement it. If the better workflow is to batch it later, say that before creating a patch, explain the stability/efficiency/future-proofing reason, and let the user decide whether to do it now anyway.

Chat-mode prefixes:

- `follow:` means execute the requested task directly, using the normal project safety checks, docs, mirror awareness, and rollback judgement. If the request is risky, stale, or likely to damage the baseline, warn before implementation rather than treating `follow:` as permission to be reckless.
- `suggest:` means do not jump straight to implementation. Compare practical options using the project context and relevant Roblox/racing/open-world patterns, then recommend the best path with tradeoffs and a clear next step.
- `audit:` means inspect and report without changing repo files, Studio objects, saved data, external state, or the active baseline. Read-only diagnostics and measurements are allowed.
- `continue:` means the previous plan is approved. Identify and execute its next uncompleted recommended step using the existing scope, canonical installer, and proportional safety lane. Do not merely restate the plan, invent another phase, broaden scope, or bypass a newly discovered blocker.
- `handoff:` means stop adding features, confirm what is actually working, update the startup/current-issues/history/topic docs, identify generated or superseded work, and prepare a concise next-chat baseline.

If the user gives no prefix, use the smart default: implement straightforward safe work, but pause with a recommendation when a request looks like polish, scope drift, architectural change, or a risky interruption to the current system.

The detailed delivery protocol is versioned separately in `docs/13_efficient_feature_delivery_protocol.md`. Future chats should improve that protocol when repeated evidence exposes a better rule, while keeping this file focused on durable project lessons.

## New System Readiness Rule

New systems and substantial expansions must use the proportional readiness standard in `docs/14_new_system_readiness_standard.md`. The assistant chooses Fast, Standard or High-Risk from the actual authority, persistence, lifecycle, scale and dependency impact; the user should not need to classify the task or supply a technical specification.

Keep Fast Lane fast. Standard work uses the compact contract in `docs/15_new_system_contract_template.md`. High-Risk work expands the same contract with explicit security, data compatibility, migration, performance, streaming, observability and rollback evidence. Use `N/A` instead of inventing irrelevant machinery, and document genuine deferred risks before another system depends on them.

## What To Learn Each Time

After each task, record only useful lessons:

- confirmed working baseline;
- exact script that installed or verified it;
- exact Studio Output error if something failed;
- root cause, if known;
- script or workflow superseded by the fix;
- remaining manual verification;
- rollback path.

Do not preserve long failed patch ladders as the current path. Keep them only as history when they explain why the new baseline is safer.

## Safer Script Design

Prefer this order:

1. Read-only audit or diagnostic.
2. Isolated new service/client/module beside the risky script.
3. Canonical replacement of a small isolated script.
4. Guarded exact source patch.
5. Broad or repeated source replacement only if no cleaner route exists.

When a command-bar script patches source text:

- say it is fragile before the user runs it;
- include preflight markers and idempotent checks;
- stop on unknown source shape;
- print useful live-source diagnostics rather than guessing another patch;
- make reruns safe after partial installs.
- avoid unescaped Lua pattern matching for large exact source blocks. `string.gsub` treats punctuation in the source as pattern syntax, so a block can fail to match even when the live source is present. Prefer `string.find(..., plain=true)` plus line-window insertion, or escape every pattern character deliberately.

If two or more source-anchor repairs fail in the same live script, stop and prefer a canonical replacement of the isolated script, or refresh the Studio mirror and inspect the live source before continuing.

## Client Bootstrap Register-Limit Rule

`StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled` is a register-limited legacy bridge. Roblox can fail Play startup with `Out of local registers` when new top-level local helpers are added, even if the feature itself is small.

For future work:

- do not add new top-level local functions, local constants, or bulky UI/feature helpers to the bootstrap;
- put new behavior in isolated LocalScripts or ModuleScripts under `Controllers`;
- if the bootstrap must be touched, add the smallest possible bridge and prefer a single table-backed/global phase namespace over multiple locals;
- after any unavoidable bootstrap bridge, restart Play specifically to check for `Out of local registers` before continuing;
- if the error returns, repair by removing/moving bootstrap locals, not by adding another patch on top.

## Condensing Phases Safely

It is good to reduce the number of Studio Command Bar inputs, but do not merge unrelated risk.

Once the user approves a phase or task scope, treat that boundary as fixed. Do not create additional phases, sub-phases, repair phases, or separate user-run tasks without asking first. If implementation or testing reveals a defect, update the same canonical installer and handoff by default. A new phase requires explicit user approval even when a split would be technically convenient.

Good merged phase:

- one installer plus one smoke in the same dual-mode script;
- one isolated service plus matching remote plus client smoke;
- validation-only phase that changes no gameplay code.

Do not merge:

- server source patch plus major UI source patch plus VFX/driving changes;
- multiple fragile text replacements in unrelated scripts;
- cleanup/deletion with feature install;
- DataStore live-save changes with visual/UI experiments.

## Mirror And Staleness Rules

Treat `roblox/exported_scripts/` and `roblox/studio_snapshot/` as a searchable mirror, not live source.

Before a fragile patch, refresh or inspect the mirror if:

- Studio has changed since the last commit;
- a previous patch partially installed;
- an anchor is missing;
- line numbers shifted after repairs;
- the error mentions a live source path that differs from the mirror.

After a Studio-side change affects scripts, hierarchy, assets, services, config attributes, or live object placement, refresh the mirror before final handoff whenever practical.

Never commit `docs/studio-full-export-paste.txt`.

## Failure Handling

Use a diagnostic before a second guess. The best pattern is:

- reproduce or capture exact Output;
- identify whether the failing object/source is current live Studio or stale mirror;
- add a read-only diagnostic if the root is unclear;
- patch only after the diagnostic narrows the cause;
- update docs with the confirmed root, not just the symptom.

If a workaround is rejected by the user, mark it as rejected and name the desired behavior. Future chats should not resurrect rejected behavior unless the user explicitly asks.

## Documentation Handoff Checklist

When a phase or fix is confirmed:

- update `docs/00_START_HERE.md` if the current baseline changes;
- update `docs/06_current_known_issues.md` for risks, verification, or deferred work;
- update `docs/07_patch_history.md` with a concise entry;
- update the topic doc or phase plan that owns the system;
- if a workflow lesson was learned, update this file or `docs/10_script_source_sync_workflow.md`;
- include exact Studio script names and verification instructions in the final handoff.

## Current Lessons From The Garage MVP Run

- The PC free-roam UI overhaul established that visual concepts should be locked into shared semantic tokens before implementation. Pink owns structure/navigation, cyan or blue owns active/live state, red owns destructive actions, and existing tier colours remain informational. Future UI pages should reuse those meanings instead of choosing accents page by page.
- The PC free-roam UI run also established a stable implementation order: lock mockups and semantic tokens, audit live owners, install one isolated canonical controller, diagnose responsive layout with absolute runtime measurements, then add gameplay integrations as isolated server-authoritative services. Avoid accumulating visual source-patch ladders after the isolated controller exists.
- For Roblox minimaps made from supplied 2D artwork, a north-up translated tile canvas preserves clipping, colour, and predictable coordinates more reliably than rotating ImageLabel descendants or rendering the artwork through a lit ViewportFrame. Keep player heading on the centre marker and keep map rotation independent from coordinate calibration.
- Treat a confirmed phase plus refreshed mirror plus pushed Git as a deliberate handoff boundary. Update startup/current-issues/topic/history docs at that point, remove superseded warnings, record the rollback baseline, and move a different system into a new chat rather than carrying a long experimental history forward.

- The Phase 17 module popup issue needed runtime-coordinate diagnostics, not repeated visual guesses. Future UI placement bugs should print absolute positions, parent, scale, selected target, and visible bounds before another repair.
- The Phase 23 access work showed that repeated anchor repairs against a drifting isolated service are worse than a canonical replacement. For isolated scripts, canonical replacement is often safer after partial installs.
- The Phase 24-28 garage MVP was smoother when new behavior lived in separate services/client scripts instead of the large garage controller or main client bootstrap.
- The mirror receiver should not block the mirror import just because the raw paste file cannot be written. `scripts/receive_studio_full_snapshot_export.py` now falls back to in-memory import for that case.
- Final audit scripts are worth keeping. Phase 28 caught the whole stack in one smoke and gave a clear completion signal.

## Current Lessons From Drive-In Customisation

- Confirmed UI reuse is an implementation rule, not a visual suggestion. When a later page should match an approved page, extract or extend the approved component/layout/renderer and make both pages call it. Copying coordinates or recreating the style in a second controller is considered drift-prone and requires a documented exception.
- Phase 1 confirmed again that `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled` is register-limited. New systems should live in isolated controllers/services, with only tiny table-backed bootstrap bridges when unavoidable.
- Phase 2 showed that UI/camera correctness can require a full session state handoff, not just opening an existing menu. If a vehicle is despawned into garage customisation, explicitly handle player hold/freeze, camera, preview vehicle, and eventual unlock.
- Phase 3/3B showed that drive-in session locks must be released before the normal garage `SpawnVehicle` handoff. Otherwise seating/spawn can race an anchored hidden character and produce undriveable vehicles or streaming focus issues.
- The Phase 3 partial install showed why command-bar source patchers should not use unescaped `string.gsub` for punctuation-heavy Lua source. The safer repair used plain matching to find the `Customise -> SpawnVehicle` branch and inserted the smallest unlock block before the call.
- The dealership V3 attempts showed that a nominal isolated presentation controller is not a true replacement while bootstrap rendering still creates, positions or refreshes the same visual surface. A clean UI replacement must have one geometry owner, hide/disable the superseded visual owner, retain only a small data/action bridge, and verify absolute runtime geometry before another visual iteration.
- Card-relative actions are a shared component contract, not a page-by-page layout detail. BUY, EQUIP and CUSTOMISE popups should all derive their rendered centre from the selected card after scaling; module cards should reserve artwork space before assets exist so later images do not require a card redesign.

## Current Lessons From Racing Session Assets

- Phase 11L arrow visual regression showed that when server collision/session proxies already own progression state, client visuals should sync from that server state instead of maintaining an independent checkpoint counter. If arrows/barriers collide correctly but display incorrectly, inspect `RaceInstances.<RunId>.SessionAssets.ArrowBarrierProxies.ParticipantSegments` before patching route folders or checkpoint events.
- Phase 11L arrow proxy-sync V1 also showed that route arrow visuals must restore saved `NTR_ArrowOriginalTransparency` when shown. Phase 10B hides shared arrow parts by setting real `Transparency = 1`, so `LocalTransparencyModifier = 0` alone is not enough to make them visible again.
- Phase 11N keeps competitive readout work prototype-safe by reading local player PBs through the existing server PB binding and caching by event+tier. Do not jump to global/friends leaderboards until DataStore-enabled save/rejoin behavior is confirmed.
- Phase 11O keeps the broader PB board isolated in a new client instead of patching the confirmed entry menu again. Prefer isolated UI companions when the underlying menu is already working and the feature can listen to existing remotes. Companion UI must also observe the owning menu's closed state, not only session-start/session-end events, so close-without-start paths do not leave orphan panels on screen.
- Phase 11P should not be treated as a stable baseline. It showed that even small result UI polish can distract from a deeper lifecycle problem. When finish/exit leaves the player in driving HUD/state, inspect handoff pairs first: racing start uses `FreeRoamVehicleSpawned`, so racing finish/exit must fire the matching `FreeRoamVehicleExited`.
- Phase 11R showed that generated source strings should use explicit `\n` escapes when stitching a comment marker and a following code line. Long-bracket concatenation can make mirror review harder if the intended newline does not land as expected.
- Phase 11S follows the project rule that after a lifecycle regression is fixed, run a read-only baseline audit before resuming polish. This is especially important when the previous attempted polish exposed or coincided with a session handoff bug.
- Phase 11S V2 clarified audit context: Play-client command-bar runs cannot inspect `ServerScriptService`, so server-only checks must be skipped or run from Edit/server context. Do not treat missing server scripts from a client audit as gameplay failure.
- Phase 11T applies the safer pattern after Phase 11P: result polish should live in an isolated companion client when the underlying race entry/session lifecycle is confirmed. If presentation overlaps with legacy UI, adjust the companion's local hiding behavior instead of patching the confirmed entry client again.
- Phase 11U V2 was confirmed working after narrowing cleanup to only `NTR_RaceHud_Phase3.Panel`. Legacy UI can outlive newer companion panels even when the core lifecycle is healthy, but cleanup clients must be extremely specific. Do not hide result/medal/exit fallback UI when fixing an orphan HUD.
- Phase 11V V2 confirmed the value of context-aware audits: a Play-client run passed with `pass=79 warn=1 fail=0`, and the only warning was expected server-source visibility. Treat `fail=0` plus understood warnings as the gate, not a demand for zero warnings in every Studio context.
- Phase 11W keeps DataStore testing explicit. Persistence verification should start as audit/config control and require a deliberate enable mode plus restart, so prototype sessions do not quietly start writing saved PB data while unrelated racing polish is being tested.
- Phase 11W V2 clarified that runtime-created BindableFunctions should not be required in Edit-mode audits. If a service creates support folders/bindings on startup, Edit-mode audits should verify the service source marker and report missing runtime children as warnings, then reserve hard binding checks for Play/server context.
- Phase 11W V2 was confirmed working after the saved PB rejoin path succeeded. After persistence is confirmed, the safer next move is a release-candidate audit/smoke gate before adding new competitive features, because saved records, rewards, queueing, result cleanup, arrows, and visibility now interact as one prototype loop.
- Phase 11Y showed that a passing audit plus one clean finish/exit loop is not enough for lifecycle bugs. If a session-finished vehicle remains in Workspace while result cleanup is pending, it must stay explicitly marked as pending cleanup and drive-disabled; do not let it become a normal free-roam owner vehicle before exit/teleport cleanup completes.
- Phase 11Z applies that lesson by adding runtime vehicle-state checks to the release-candidate audit. Future audits for lifecycle-sensitive systems should inspect live runtime leftovers, not only source markers and static config.
- Phase 11Z was confirmed and locked as the racing prototype release-candidate baseline before moving future adjustments into new chats. When a long phased implementation reaches a stable gate, create a short next-chat handoff doc that names the locked baseline, key scripts, preserved architecture rules, recommended next branches, and remaining risks.

## Current Lessons From Racing

- Phase 8C showed that repeated logic blocks may not be text-identical once they sit in different branches. Duplicate source-anchor repairs should handle each known branch shape explicitly, accept already-repaired markers, and print the replacement count, so partial or slightly drifted live source does not force another guessed patch.
- Phase 8C testing also showed that fixing a suspected vehicle handoff is not enough when the symptom is camera/UI transition state. Future racing transition repairs should log and restore camera type/subject plus HUD visibility before and after start/reset/quit, then keep fade/camera/HUD presentation in an isolated client controller.
- Phase 8D reset testing showed that repeated CFrame/facing patches can miss the real owner of orientation. The active driving loop keeps a local `yawHeading`, so reset-to-checkpoint facing needs a reset handoff that either syncs that heading or restarts the existing driving handoff after the server-authoritative reset pose. Prefer identifying state owners before another visual/physics patch.
- Phase 8E testing showed that restarting the full driving handoff during an active reset is too broad: it can disturb controls, camera, VFX, and streaming. When a large bootstrap-owned controller needs one internal value changed, prefer a tiny payload bridge for that exact value over rerunning the whole start path.
- Phase 8F testing showed that even a narrow client-side yaw/velocity intervention can be too much while server reset, camera restore, and streaming are all settling. For reset regressions, restore a single owner first: server moves the vehicle, client handles presentation only. Re-add orientation polish only after the stable reset baseline is reconfirmed.
- Phase 8H changed the reset architecture from live vehicle teleport to respawn-on-reset. For racing resets, prefer destroying the old physics assembly and spawning a clean replacement at the reset pose when momentum, facing, camera, and streaming are all involved. Use fade as a deliberate reset penalty and avoid client-side vehicle pokes.
- Phase 9A confirmed the best-session-result model for time trials: lap/infinite sessions should grant rewards once on finish/quit from the best completed lap/result, not on every lap. Future racing economy work should preserve that anti-farming shape unless deliberately redesigned.
- Phase 10A starts race-only physical assets as simple server-owned colliders cloned from hidden authoring markers. Keep rich mesh/VFX/jump/boost behavior layered after the simple collision path is proven, especially for mobile performance and debugging.
