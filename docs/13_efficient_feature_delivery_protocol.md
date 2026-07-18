# Efficient Feature Delivery Protocol

**Version:** 1.0  
**Created:** 2026-07-18  
**Purpose:** Deliver Neo Tokyo Racers changes quickly, usually through one user-run Studio installer, while preventing patch ladders, competing owners, stale-baseline failures, and hard-to-edit one-off systems.

This protocol is intentionally editable. Future chats should improve it when confirmed evidence shows a rule is too weak, too restrictive, or no longer relevant. The goal is not more ceremony; the goal is fewer Studio install/test/repair cycles.

## Primary Outcome

Optimise for:

1. proportional internal investigation;
2. one approved scope;
3. one canonical user-run installer containing its own safeguards;
4. one focused verification pass;
5. one confirmed, documented handoff.

Ten internal checks behind one installer are normally more efficient than one lightly checked installer followed by three repair installs. Ten separate user-run preparation steps are not efficient and should be avoided.

## Proportional Workflow Lanes

### Fast Lane

Use for isolated copy, icon IDs, configuration attributes, tuning values, and small layout changes with one clear owner.

Required work:

- inspect the affected shared component or config;
- confirm the change is isolated;
- preserve the confirmed baseline;
- generate one guarded installer or direct repo edit;
- include a compact verification.

Do not require a formal owner map, separate audit phase, or long acceptance contract for genuinely isolated work.

### Standard Lane

Use for connected menu flow, responsive layout, shared cards, preview behaviour, navigation, camera presentation, or changes affecting multiple pages.

Required work:

- write a concise acceptance contract;
- identify the shared implementation and relevant owners;
- inspect the current mirror and known issues;
- simulate or review source transformations before delivery where possible;
- produce one transactional installer with embedded audit and rollback;
- define a focused desktop/touch or transition test matrix.

This is the default lane for most garage and UI work.

### High-Risk Lane

Use for persistence, inventory migration, economy, architecture, legacy retirement, multiple runtime owners, VFX attachment, large state-machine changes, or uncertain live-source ownership.

Required work:

- perform a read-only ownership/data/runtime audit when the mirror cannot prove the live state;
- agree on the canonical owner and migration semantics;
- fix the producer of invalid state before cleaning stored state;
- use transactional mutation and validate invariants before persistence;
- provide a rollback path appropriate to the system;
- run the relevant repeated-transition, save/rejoin, memory, or multi-device smoke.

A separate read-only Studio audit is acceptable here when live runtime evidence is required. It should be the exception, not an automatic extra phase.

## Prefix Routing Contracts

### `follow:`

Implement the request directly using the appropriate lane. Warn only when the baseline is stale, the request is unsafe, or a materially better architecture should be considered first.

### `suggest:`

Do not implement yet. Compare practical approaches, challenge weak assumptions, explain tradeoffs, recommend the best path, and name the next action.

### `audit:`

Read and measure only. Do not modify repo files, Studio objects, saved data, external state, or the active baseline. The output should identify evidence, likely root cause, remaining uncertainty, and the recommended next action.

### `continue:`

Treat the current plan and its scope as approved. Determine the next uncompleted recommended step from the conversation and project docs, then execute it.

`continue:` must not:

- merely restate the plan;
- reopen decisions without new evidence;
- create an extra phase or separate repair script without approval;
- expand into unrelated work;
- skip a real blocker, stale-baseline warning, or destructive-action boundary.

If the prior step failed, update the same canonical installer unless inspection proves the baseline changed enough to require a replacement.

### `handoff:`

Stop feature expansion. Confirm the installed and tested baseline, refresh or request the mirror where needed, update the relevant documentation, mark generated/superseded/untested work accurately, and produce a concise next-chat starting point.

## Acceptance Contract

Use this before Standard/High-Risk implementation or whenever the request contains several interacting changes. The assistant owns the responsibility for deriving and restating it; the user should not need to produce a technical specification.

```text
Goal:
Current confirmed baseline:
Required changes:
Must preserve:
Shared components/owners to reuse:
Entry, transition and exit behaviour:
Desktop/touch coverage:
Persistence or economy impact:
Explicit exclusions:
Done when:
```

Keep it concise. Do not delay an obvious small fix to fill every field.

## Ownership Gate

Before changing connected runtime behaviour, identify which system owns each relevant concern:

| Concern | Question |
|---|---|
| State | Who decides the current page/mode/value? |
| Geometry | Who creates and positions the visible UI? |
| Visibility | Who can show, hide, or refresh it later? |
| Preview | Who creates and clears transient client-only state? |
| Runtime attachment | Who attaches controllers, connections, VFX, or update loops? |
| Persistence | Who validates and saves the authoritative value? |

There should be one intentional owner per concern. A compatibility bridge may forward data or actions, but it must not become a second presentation or persistence owner.

Do not add another owner to overpower a conflicting owner. Retire, narrow, or replace the conflict.

## Shared Implementation Gate

When the user says a page should be the same as an approved page, reuse the actual component, renderer, layout function, state owner, semantic token, or responsive transform.

Copying coordinates, recreating a similar card, or duplicating a renderer is not reuse. A page-specific implementation is allowed only when the shared contract genuinely cannot express the requirement; document why.

Prefer the minimum durable abstraction: enough shared structure for known consumers, without building speculative systems for hypothetical features.

## One-Installer Contract

For an approved scope, prefer one canonical script with `INSTALL` and `AUDIT` modes where practical. It should:

- preflight required hierarchy, class names, baseline markers, and unique anchors;
- be safe to rerun or clearly detect an existing complete installation;
- compile every projected Script/LocalScript/ModuleScript source before assignment;
- keep projected source safely below Studio's maximum, with useful headroom;
- snapshot every source, property, attribute, and object it mutates;
- perform mutation inside a guarded transaction;
- run a post-install audit;
- restore the complete snapshot on assignment or audit failure;
- print focused verification instructions.

If the installer itself fails to parse, correct the same canonical file. Do not create a separate repair installer.

## Failure Budget

1. First unexpected failure: capture the complete error and diagnose the responsible owner/source.
2. Second missing/changed source anchor in the same live script: stop patching, refresh or inspect the live source, and prefer a canonical isolated replacement.
3. Never issue a third guessed source patch against an unverified baseline.

If runtime behaviour contradicts a passing static audit, add runtime evidence rather than another visual or name-based guess.

## Runtime Evidence Gate

Use evidence appropriate to the symptom:

- UI geometry: absolute position/size, parent, applied scale, safe area, visible bounds;
- state flow: entry source, current stage, transition, exit destination, cleanup calls;
- preview: clone identity, profile fingerprint, transient overrides, cleanup boundary;
- VFX/controllers: attachment owner, connection/host count, enabled groups, repeated-entry growth;
- persistence: authoritative references, invariants, before/after snapshot, save/rejoin;
- performance: stable instance/memory counts over repeated transitions and a meaningful observation window.

Static source markers prove installation shape, not correct runtime ownership.

## UI Transition Test Matrix

For connected garage work, select only the relevant rows and fill expected results before testing:

| Entry | Transition | Exit/Back | Required cleanup |
|---|---|---|---|
| Dealership | Vehicle → Paint → Hub | Exit or Drive | Factory preview and temporary actions cleared |
| Owned Customisation | Vehicle → Hub | Exit or Drive | Owned saved appearance restored |
| Drive-In | Current vehicle → Hub | Drive | Character/session/camera handoff released |
| Build Modules | Slot → Owned/Buy → Preview/Action | Back or Drive | Unbought/unequipped preview cleared |
| Edit & Upgrade | Category → Colour/Cosmetic/Performance | Back or Drive | Temporary colour/neon/module state cleared |

Test the same canonical composition at the required desktop, tablet, and phone profiles rather than maintaining separate UI implementations.

## Challenge Rule

Challenge the user once, early, when a materially safer, faster, clearer, more reusable, or more future-proof approach exists.

The challenge must include:

- the concrete risk in the requested approach;
- the recommended alternative;
- the practical benefit;
- the tradeoff or added cost.

After the user makes an informed choice, proceed without repeatedly reopening the decision unless new evidence changes the risk.

## Confirmation And Handoff Boundary

After the user confirms a phase:

1. treat that exact behaviour as the newest working baseline;
2. refresh the Studio mirror before another fragile Studio patch or final handoff;
3. update startup, current issues, patch history, topic documentation, and workflow lessons where relevant;
4. mark older attempts as superseded rather than leaving several apparent current paths;
5. start a new chat when moving to a materially different subsystem or after a long experimental ladder.

## How Future Chats Should Improve This Protocol

This protocol is a living system, not an immutable policy.

Change it when confirmed project evidence shows that a rule:

- repeatedly prevents failures and should become a compact hard rule in `AGENTS.md`;
- creates ceremony without reducing risk and should be narrowed to a higher-risk lane;
- is obsolete because an owner or legacy system was retired;
- misses a recurring failure pattern;
- can be automated inside an installer or audit instead of becoming another user step.

When changing the protocol:

1. record the concrete incident or repeated pattern;
2. state whether the change improves speed, safety, editability, or all three;
3. keep `AGENTS.md` concise and move explanations/templates here;
4. avoid rules based on a single unexplained failure;
5. preserve proportionality—Fast Lane must remain fast;
6. update the version and date below.

## Revision Log

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-07-18 | Added proportional delivery lanes, one-install objective, owner and shared-component gates, five chat prefixes including `continue:`, runtime evidence, failure budget, acceptance/transition templates, challenge rule, and an explicit self-improvement process. |
