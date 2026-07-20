# New System Readiness Standard

**Version:** 1.0
**Created:** 2026-07-20
**Purpose:** Keep new Neo Tokyo Racers systems compatible with future architectural hardening without slowing isolated prototype work.

This standard extends `docs/12_continuous_improvement_workflow.md` and `docs/13_efficient_feature_delivery_protocol.md`. It does not replace their confirmed-baseline, ownership, one-installer, runtime-evidence, mirror, or handoff rules.

The objective is proportional diligence: establish durable boundaries early for systems that will grow, while keeping small visual and tuning work fast.

## Mandatory Startup Rule

Every new chat that plans or implements a new system, a substantial expansion of an existing system, or a connected runtime/persistence/network change must read this document before proposing the implementation.

The assistant must select the appropriate delivery lane. The user should not need to classify the task or write a technical specification.

The selected lane, acceptance contract and applicable safeguards remain active for the duration of the task, including repairs and follow-up refinements. Reclassify only when new evidence or user-approved scope materially changes the risk; do not quietly drop safeguards mid-task or force the original lane onto unrelated later work.

## Delivery Lanes

### Fast Lane

Use for isolated copy, icon IDs, tuning, configuration, one-owner layout adjustments, and non-persistent decorative changes.

Required:

- confirm the current baseline and affected owner;
- preserve unrelated systems;
- make the smallest durable change;
- run one focused verification;
- update baseline or issue documentation only when it actually changes.

Do not require a formal readiness contract, architecture audit, schema version, lifecycle interface, performance test suite, or broad device matrix when those concerns are genuinely not applicable.

Fast Lane never bypasses the universal rules below. A change involving a remote, saved data, currency, rewards, ownership, or authoritative gameplay cannot be made Fast Lane merely because the code diff is small.

### Standard Lane

Use for a new isolated controller/service, UI flow, world service, reusable component, non-persistent gameplay mechanic, or a connected change with clear existing owners.

Required:

- complete the compact contract in `docs/15_new_system_contract_template.md`;
- identify owners, inputs, outputs, dependencies, lifecycle, scale and relevant client/server boundaries;
- reuse shared contracts and components where they already exist;
- use one canonical implementation/installer with proportional preflight, audit and rollback;
- run the relevant desktop/touch/controller, transition, streaming, cleanup or performance checks;
- record the confirmed baseline and remaining risks.

The contract should normally take minutes. `Not applicable` is a valid answer when accompanied by an obvious reason.

### High-Risk Lane

Use for persistence, inventory, economy, monetisation, rewards, multiplayer authority, anti-cheat, matchmaking, race/session lifecycle, large state machines, architecture, legacy retirement, cross-system APIs, uncertain ownership, or systems that will become dependencies for many future features.

Required:

- complete the full contract in `docs/15_new_system_contract_template.md`;
- establish canonical owners and authority before implementation;
- define data/API versions, compatibility and migration semantics where applicable;
- threat-model every client request and authoritative result;
- declare scaling and performance budgets based on representative targets;
- define failure recovery, rollback and observability;
- use read-only live/runtime evidence when the mirror cannot prove the boundary;
- run relevant repeated-transition, multi-client, save/rejoin, memory/soak, low-end-device, streaming or load checks;
- do not activate the new owner until invariants and rollback are proven.

## Universal Rules

These apply in every lane whenever the concern exists.

### Ownership And Isolation

- One intentional owner decides each relevant state, geometry, visibility, preview, runtime attachment, persistence and cleanup concern.
- A compatibility bridge may forward data or actions but must not become another authority or presentation owner.
- New substantial behaviour belongs in isolated services, controllers or modules, not the register-limited client bootstrap.
- Systems communicate through documented inputs/outputs rather than another system's private tables, UI objects or transient Instances.
- Do not create a second owner to overpower a conflict. Retire, narrow or replace the conflicting owner.

### Server Authority And Exploit Resistance

- Treat every client payload, attribute and timing claim as untrusted.
- Clients send intent; the server calculates or validates authoritative cost, ownership, reward, inventory and progression results.
- Remote handlers validate player/session identity, permission, current state, payload type, range, stable IDs and revision where applicable.
- Bound request frequency and payload size. Rate limits must tolerate normal latency and repeated UI activation without accepting spam.
- Economy, purchase, reward and inventory mutations must be idempotent or duplicate-safe.
- Client-owned vehicle physics does not make client-authored race results authoritative. Validate checkpoint order, elapsed time, reset/teleport transitions and broad movement plausibility server-side.
- Security decisions must not rely on hidden client code, UI visibility or an Instance name being difficult to discover.

### Data, IDs And Compatibility

- Saved and cross-system records use stable IDs, not display names, hierarchy paths, array positions or live Instance references.
- Saved subsystems declare a schema version and a migration/default policy.
- Public cross-system APIs and remote payloads are versioned when compatibility may span releases or multiple consumers.
- Additive fields have safe defaults; renamed or removed fields have an explicit migration or compatibility bridge.
- Only the authoritative profile/session owner mutates persisted state. Read models and BindableFunction results are treated as detached snapshots unless the owner explicitly provides a command boundary.
- Content growth should normally be definition/catalogue driven. Adding another car, race, garage or item should not require another hard-coded runtime branch.

Do not version every private helper. Version boundaries that cross persistence, networking, independently deployed consumers, migration periods, or long-lived content definitions.

### Lifecycle And Cleanup

- Any owner that creates connections, tasks, loops, clones, temporary state, camera/input ownership, UI, VFX, or player/vehicle/session references must define how those resources stop and are released.
- Startup and mutation paths are idempotent or explicitly reject an already-active duplicate.
- After every yield or deferred callback, revalidate that the player, session, vehicle, UI and owning generation are still current.
- Player removal, vehicle destruction, UI close, session exit and streaming removal release their owned references.
- Repeated entry/exit must not grow live owners, connections, instances or memory beyond a stable bounded level.
- Prefer event-driven registration. Polling is allowed only when it is bounded, justified and cheaper/safer than the available lifecycle events.

Pure calculation and immutable data modules do not need artificial `Init`, `Start` or `Destroy` methods.

### Performance And Scaling Budgets

For Standard and High-Risk systems, state what grows with players, vehicles, races, garages, city blocks, catalogue rows, UI cards, VFX or streamed regions.

- No unbounded `GetDescendants()` or whole-Workspace scans inside frame/heartbeat loops.
- Do not recalculate static layout, catalogues, definitions or tuning on every frame.
- Cache stable definitions and resolved configuration; invalidate that cache deliberately when its source changes.
- Do not repeatedly write properties or attributes when their value is unchanged.
- Bound active connections, instances, remote frequency, payload size, effects and per-frame work.
- Prefer paging, lazy loading, pooling or virtualisation when a catalogue can grow beyond a small visible set.
- Profile representative worst cases, including the target 15-player lobby, busy race presentation, streamed city content and a low-end mobile quality tier.

Budgets should be based on measurements and revised as the game grows. Do not invent elaborate optimisations before evidence or a known scale multiplier exists.

### Mobile, Input And Accessibility

- Use one responsive composition across desktop, tablet and phone where practical.
- Define touch targets, safe-area behaviour, text bounds and orientation/viewport changes.
- Include keyboard/mouse, touch and controller entry/exit behaviour when the feature is reachable from those inputs.
- Core gameplay remains readable and functional with reduced VFX, shadows, lights and render distance.
- Mobile support is designed with the feature, not added as an unrelated replacement implementation later.

### Streaming And Open-World Safety

- Client systems must not assume distant Workspace content is loaded.
- Observe tagged/runtime objects entering and leaving scope; release references to streamed-out objects.
- Server-owned race, reward, collision and persistence decisions remain valid when clients lack distant presentation objects.
- Client presentation reconstructs safely after streaming or respawn.
- World systems operate on registered/active/nearby regions where practical rather than repeatedly scanning the whole city.
- Authoring definitions and inactive templates remain separate from active runtime clones.

### Failure Containment And Observability

- Optional presentation failure must not prevent unrelated core systems such as profile loading or driving from starting.
- Network and persistence calls use safe failure responses, timeouts/cancellation where applicable, and retry only when duplicate-safe.
- Warnings identify the system, action, relevant stable ID and rejection/failure reason without exposing sensitive saved data.
- High-risk systems expose enough low-cost evidence to identify lifecycle generation, current owner/state, transaction result and bounded active counts.
- Detailed diagnostics are sampled, gated or disabled in production rather than written every frame.

## Avoiding Workflow Waste

- Use the minimum durable abstraction for known consumers. Extract a reusable framework when a second consumer exists or expansion is already confirmed.
- Allow `Not applicable`; do not invent networking, persistence, lifecycle or streaming machinery for a feature that does not own those concerns.
- Put designer-tunable values in config. Keep private structural constants in code unless another owner genuinely needs them.
- Combine readiness evidence with the canonical installer/audit instead of creating many user-run preparation steps.
- Classify audit output as `BLOCKER`, `WARN` or `INFO`. Only blockers automatically stop activation.
- Record a short exception when a rule does not fit, including the reason, owner and condition for review. Exceptions cannot waive server authority, persistence ownership or destructive safety.
- Remove or narrow rules that repeatedly create work without catching failures; strengthen rules when repeated evidence proves a gap.

## Readiness Scorecard

Before a Standard or High-Risk system becomes a dependency for later systems, record each applicable row as `PASS`, `N/A`, or `DEFERRED` with a named risk:

| Area | Ready when |
|---|---|
| Ownership | One canonical owner exists for every relevant concern. |
| Security | Client intent is validated and authoritative results remain server-owned. |
| Data | Stable IDs, version/defaults and migration decisions are explicit. |
| Lifecycle | Repeated entry/exit and destruction release owned resources. |
| Performance | Growth dimensions are bounded and representative evidence passes. |
| Mobile/input | Required device/input behaviours are confirmed. |
| Streaming | Objects may enter/leave scope without corrupting state or leaking owners. |
| Failure handling | Rejection, timeout, retry and rollback behaviour is safe. |
| Observability | Failures and owner/session state can be diagnosed at low cost. |
| Documentation | Dependencies, verification, baseline and rollback are recorded. |

`DEFERRED` is acceptable for non-blocking work only when the current limitation and the point before which it must be resolved are documented in `docs/06_current_known_issues.md`.

## Confirmation And Review

After confirmation:

1. update the relevant topic document and baseline/history/known-issues files;
2. refresh the Studio mirror when Studio state changed;
3. mark superseded owners and experiments clearly;
4. retain one canonical installer and rollback point;
5. review this standard when repeated project evidence shows a rule is too weak or too restrictive.
