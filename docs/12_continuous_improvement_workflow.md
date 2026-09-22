# Workflow lesson index

Read this compact index before multi-step Studio work. The [delivery workflow](13_efficient_feature_delivery_protocol.md) is the active procedure; lessons below explain relevant failure patterns, not extra startup tasks.

- **Baseline:** inspect current live state before fragile patches; source parity misses physical edits. Preserve accepted drift.
- **Ownership:** identify the actual state/geometry/attachment owner before patching symptoms. No gameplay require through MCP or duplicate startup.
- **UI:** reuse shared geometry/renderers; distinguish visible content from input containers and inspect hidden ancestors.
- **Testing:** confirm interactive entry before counting gameplay cycles. API success and flat parented counts are not visual or resource-lifecycle acceptance.
- **Performance:** distinguish JSON from wire bytes, intervals from CPU, Studio from device memory and warm-up from continued growth.
- **Catalogue:** one canonical authoring source; generated data/preview freshness and restart boundaries are explicit.
- **Persistence:** one saved-state owner; sandbox checks do not establish published save/rejoin or multi-server contention.
- **Recovery:** one canonical installer, bounded failures, no in-game backups. Windows capture staging inherits repo ACLs.
- **Documentation:** current status has one home in 00_START_HERE. Link to it; replace obsolete instructions instead of stacking contradictory banners.

Detailed incident evidence and prior lessons: [historical collection](history/workflow-before-mcp-phase1/docs/12_continuous_improvement_workflow.md). Search it by affected system when needed; do not reread the whole collection every session.
Workflow Phase 1 lesson: duplicated status and hard-coded prompt run queues drifted even after successful migrations. Centralise procedure/status and keep prompts as routing instructions.

Workflow Phase 2 lesson: scope capture by required evidence, not by every physical object. Inventory all covered source paths, capture selected properties/tags, and require explicit historical input so an old mirror cannot silently pass a current check. Artifact size is not transport/time performance.

Workflow Phase 3 lesson: reuse verified captures as delivery preconditions; reject partial state rather than guessing. Test transaction faults with pure mocks, reserve game mutation for requested changes, and verify each dependent local command succeeds before MCP execution. Restoration of specified values is not proof of recovery from runtime side effects.

Workflow Phase 4 lesson: record selected checks and their evidence category explicitly. Reject API-to-UI, emulator-to-device and no-save-to-persistence substitutions. File hashes prevent unnoticed evidence changes but cannot certify an observation or the completeness of the chosen checks. Leave unavailable tests open with a concrete next action.
