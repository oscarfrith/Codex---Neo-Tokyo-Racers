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

Lighting interpolation lesson: numerically bounded property blends can still combine high light energy with strong scattering and produce a white sky. Compare intermediate states in both sky directions, then remap a few property groups against the same phase; keep clock motion independent and endpoint/artwork changes explicit. [Measured investigation](architecture/lighting-sunset-refinement-options.md), [implementation evidence](architecture/lighting-sunset-refinement-handoff.md).

Runtime NaN lesson (2026-09-26): an anchored assembly reports infinite AssemblyMass, so force maths on a parked vehicle yields NaN that persists into the next unanchor; normal UI timing can hide it while server-initiated or API paths expose it. Reproduce with the exact server call order, probe forces/positions per frame, and fix the producer plus the component that latches the bad value. Weak-keyed tables whose values close over the key do not release it in Luau; release bindings on the lifecycle event that actually fires (AncestryChanged), not only Destroying.

Architecture programme lesson (2026-09-26): large refactors of closure-scoped scripts are safe when moves are mechanical and provable: analyse free variables/exports/shared mutable state per range, move byte-for-byte into ctx factories rebound at the same position, have an independent reviewer re-resolve scopes, and compare canonical golden replies (sorted keys, normalised generated ids) before and after. Reviewers caught two unsafe money "fixes" (refunds that could mint cash or grant free items): compensation logic must be designed per action, not bolted onto a dispatcher. Camera/UI changes need a rendering viewport (check RenderStepped FPS) before they can be verified.
