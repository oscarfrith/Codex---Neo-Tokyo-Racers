# Space Racers — architecture handoff

Space Racers is a playable hover-racing prototype. Five original architecture phases and cleanup Phases 1–3 are user-confirmed. Cleanup Phase 4 is installed and agent-verified; final user playthrough pending.

The backend uses explicit ServerBase/ClientBase startup, server-only Modules.Core/Game in ServerStorage, client/shared modules in ReplicatedStorage, feature-owned Runtime endpoints, and generic Assets/Config/Remotes roots. Existing gameplay, shared UI/preview/VFX owners, tuning, authority and saved schemas are preserved. See naming-and-owners.md.

Phase 4 cleaned 61 source bodies with 179 private identifier mappings; removed patch-stamp comments and standardised diagnostic labels. The current snapshot workflow is receiver-only and transactional for ordinary import failures, with Windows permission inheritance and nine pipeline tests. Read-only Studio/local audits document actual errors and deliberate exceptions. No automatic production publish or FPS claim.

Final mirror: 2026-09-22 10:25:06, 160 sources, 42,351 nodes and 267,539 captured properties. Every expected source/hierarchy/property matches the accepted September 22 arrival baseline. The user's 628 moved arrow CFrames and new thumbnail model are preserved.

Remaining: user full gameplay checkpoint; protected staging/Archive asset decision; pre-existing camera CAM-02 follow-up; representative device/multiplayer testing and real isolated-place persistence contention/save-rejoin before release. Stable external identifiers and defensive GUI suppression keys are preserved deliberately.

Delivery/rollback/evidence: cleanup-phase4-finalisation.md. Operational instructions: installer-index.md and mcp-workflow.md. Historical company handoff: ../history/cleanup-phase4-prior-docs/company-handoff.md.
