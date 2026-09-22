# Delivery workflow

Version 2.3, 2026-09-22. Canonical procedure for delivery, testing, recovery and Git. Current task/status belongs in [start here](00_START_HERE.md); specialist system safeguards remain in [readiness](14_new_system_readiness_standard.md).

## 1. Orient and choose scope

Read AGENTS, startup/issues and relevant topic/source files. Check Git. For Studio work rediscover the target instance, verify place ID and Edit/Play mode, and inspect the actual affected state. Studio is authoritative; a dated export is evidence, not automatic sync input. Source parity alone cannot prove physical parity.
Read the [lesson index](12_continuous_improvement_workflow.md) for multi-step Studio work; load detailed history only when relevant.

| Routing | Action |
|---|---|
| follow: | Implement within requested scope using proportional safeguards. |
| suggest: | Compare approaches and recommend; no implementation. |
| audit: | Read/measure only; no repo, Studio, saved-data or baseline mutations. |
| continue: | Execute the next incomplete approved step; resolve failures in the same scope, without reopening settled decisions or inventing new phases. |
| handoff: | Stop expansion; record installed/tested state, unresolved work and recovery. |

One approved scope, one canonical installer where needed, one focused verification and handoff. Do not split a phase or add user-run patches without approval. Challenge a materially better alternative once with concrete tradeoffs.

Implementation triage applies to fixes and refinements too: do required blockers/regressions now; do isolated safe config/copy/tuning work when requested; suggest batching optional polish later; discuss unresolved architecture, ownership, persistence/economy or live-source ambiguity before mutation. Existing scope approval remains valid. A mid-stream adjustment should not silently widen the task; explain a better batching option once and respect the user's choice.

## 2. Apply proportional safeguards

| Lane | Work | Required evidence |
|---|---|---|
| Fast | Isolated copy/icon/config/tuning or one-owner layout | Inspect owner/baseline; guarded installer or direct repo edit; focused check. No formal system ceremony. |
| Standard | Connected UI/preview/navigation/presentation with clear owners | Concise contract, shared-component/owner review, current source/mirror, transactional installer, affected transition/input tests. |
| High-Risk | Persistence/economy/inventory/architecture/retirement, uncertain or multiple runtime owners, VFX attachment | Live audit where necessary, authority/invariants/migration semantics, complete recovery and applicable lifecycle/security/save/load/device tests. |

A small diff cannot bypass remote, saved-data, authority, reward or lifecycle safeguards. For new systems, substantial expansions and connected networking/persistence/runtime work read [readiness](14_new_system_readiness_standard.md); use [the contract](15_new_system_contract_template.md) for Standard/High-Risk work. N/A is valid for irrelevant concerns; the assistant derives the contract.

Before connected implementation state goal, baseline, changes, preserved behaviour, shared owners, entry/transitions/exit, input/device coverage, persistence impact, exclusions and done-when checks.
Identify owners for state, geometry, visibility, preview, runtime attachment and persistence. Reuse the actual shared implementation; document necessary exceptions. Fix invalid-state producers, not only their symptoms.

## 3. Prepare and apply

Use [proportional MCP delivery](architecture/proportional-mcp-delivery.md): direct repository edits for docs, the guarded bundle tool for existing source bodies/primitive attributes, and a dedicated canonical installer for migrations beyond that support. The assistant handles capture, build, execution and authorised Git steps. Command Bar remains the access fallback. MCP does not remove review, baseline or recovery requirements.

For connected installers:
- Preflight unique paths/classes, exact expected sources/config and anchors; stop on unexpected drift.
- Compile all projected sources before assignment and preserve source-size headroom.
- Capture every affected source, property, attribute and object for appropriate repository-backed/in-memory recovery; no persistent in-game backups.
- Apply guarded mutations, audit the result, and restore affected state on assignment/audit failure.
- Detect complete prior installation or prove safe repeat execution. Keep INSTALL/AUDIT and deliberate recovery in one canonical scope.
- Repair that installer after failure; do not add a patch ladder.

Announce fragile text replacement beforehand. After two failed anchor repairs in one live source, stop, inspect/refresh and prefer an isolated canonical replacement. Never issue a third guessed patch. If an older Roblox version is cleaner, explain before adding another patch.
No gameplay module require through MCP, hot reload, duplicate owners or automatic mirror-to-Studio syncing. Inspect ordinary ServerBase/ClientBase startup. Publishing requires separate scope.

## 4. Verify what changed

Use the existing no-save sandbox for mutation smoke tests and verify its state first. Sandbox success does not prove published saving or contention safety. Keep the client visible during input checks.
Confirm normal startup and interactive UI state before counting player-flow tests. API responses behind a start screen are API-only evidence. Source matches prove installation, not gameplay.

| Concern | Relevant checks |
|---|---|
| UI | Parent/visible ancestors, absolute bounds/scale/safe area, entry/back/exit, relevant desktop/touch/controller input |
| Garage | Dealership paint/hub/exit; owned appearance; drive-in camera/session release; module browse/back clears unbought preview; customise/back clears temporary overrides |
| Runtime/VFX | Existing owner, host/connections/clones, repeat entry/destruction/stream-out cleanup |
| Persistence/economy | Authority, invariants, failure/retry, fresh state; isolated published save/rejoin/contention when applicable |
| Performance | Comparable route/cache/build/device/load, frame tails, settled/peak resources, bounded observation window |

Use the [reusable validation and handoff procedure](architecture/validation-and-handoffs.md) and scripts/validation_checks.json to select repeatable checks. For connected or deferred work, scripts/validation_record.py preserves evidence types, pinned artifacts and open next actions. This does not replace judging the evidence or selecting the right tests.

Choose applicable checks; do not run every matrix for a copy edit. Report unavailable tests as deferred with a named risk. Flat parented counts do not prove detached references or connections are bounded; successful idle samples are not device/load evidence. Preserve one responsive composition.

## 5. Capture and recover

**Default: targeted before/after captures**, including complete inventoried script source and the affected hierarchy/config/property/tag scope. Follow [targeted capture](architecture/targeted-capture-workflow.md). Review source changes outside scope; do not overwrite them. Recheck live affected state immediately before mutation.
Use full checkpoints for broad hierarchy migrations, unexplained broad drift or recovery needs beyond scoped coverage; see [full snapshot procedure](10_script_source_sync_workflow.md). Documentation-only work and unchanged Edit state after Play do not require an export.
If local/Studio access is unavailable, request the appropriate capture and state what remains unverified. Never claim a capture occurred automatically. Catalogue/preview and naming checks accept verified targeted records; historical full mirrors must be explicitly selected.

Validate integrity and the applicable expected baseline. Do not force an older migration verifier over intentional newer changes. Preserve physical edits and inspect drift; tags need separate live evidence and duplicate paths need scoped/multiset handling.
The mirror is not a complete place/terrain backup. For recovery, use compatible repository evidence and the dependency order in the tool index; refresh and reverify afterward. Do not restore obsolete owners.

## 6. Document and commit

| Owner document | Update only when |
|---|---|
| AGENTS | A durable working rule changes |
| 00_START_HERE | Current baseline/task/next action changes |
| 06_current_known_issues | A risk, blocker or outstanding check changes |
| Topic docs | Ownership, API, authoring or behaviour contract changes |
| 07_patch_history | A delivery completes; one concise historical entry |
| 12 lesson index | Confirmed evidence yields a reusable lesson |

Do not repeat status paragraphs across topics/prompts. Historical handoffs remain dated; they are not current run instructions.
Inspect scope/diffs, run relevant checks and commit verified changes using existing authorisation. Preserve unrelated work. Never commit docs/studio-full-export-paste.txt. Distinguish a local commit from a confirmed successful push.
Handoff: what changed, checks passed/deferred, any exact Studio script still needed, mirror status/date, risks/recovery, commit title/description or actual commit. Never promote an untested result to confirmed.

## Maintenance

Narrow rules that cause ceremony without catching failures; strengthen them from repeated evidence. Keep Fast Lane fast and system safeguards intact. Version/date material policy changes.
Version 2.3 adds reusable checks and scoped evidence/handoffs. Version 2.2 adds supported guarded delivery and explicit migration limits. Version 2.1 activated verified targeted capture. Version 2.0 consolidated prior 1.1 and MCP procedure. [Prior text](history/workflow-before-mcp-phase1/docs/13_efficient_feature_delivery_protocol.md) retains detailed historical context.
