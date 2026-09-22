# Space Racers — architecture handoff

Latest continuation: performance Phase 2 installed/agent-verified; user playthrough pending. Six server-only roots moved intact; replicated descendants reduced by 14. Mirror 12:07:02 verifies exact projected source/hierarchy/property parity. iPhone 7 and representative load measurements remain pending. See performance-phase2-server-storage.md. Earlier paragraphs below describe the confirmed cleanup milestone.

Space Racers is a playable hover-racing prototype. All five original architecture phases and all four cleanup phases are user-confirmed. User reports committing and pushing. Post-confirmation mirror 2026-09-22 11:00:13 passes exact Phase 4 parity. The separate performance-and-replication-plan.md is proposed only.

The backend uses explicit ServerBase/ClientBase startup, server-only Modules.Core/Game in ServerStorage, client/shared modules in ReplicatedStorage, feature-owned Runtime endpoints, and generic Assets/Config/Remotes roots. Existing gameplay, shared UI/preview/VFX owners, tuning, authority and saved schemas are preserved. See naming-and-owners.md.

Phase 4 cleaned 61 source bodies with 179 private identifier mappings; removed patch-stamp comments and standardised diagnostic labels. The current snapshot workflow is receiver-only and transactional for ordinary import failures, with Windows permission inheritance and nine pipeline tests. Read-only Studio/local audits document actual errors and deliberate exceptions. No automatic production publish or FPS claim.

Final mirror: 2026-09-22 10:25:06, 160 sources, 42,351 nodes and 267,539 captured properties. Every expected source/hierarchy/property matches the accepted September 22 arrival baseline. The user's 628 moved arrow CFrames and new thumbnail model are preserved.

Remaining: protected staging/Archive asset decision; pre-existing camera CAM-02 follow-up; representative device/multiplayer testing and real isolated-place persistence contention/save-rejoin before release. Stable external identifiers and defensive GUI suppression keys are preserved deliberately.

Delivery/rollback/evidence: cleanup-phase4-finalisation.md. Operational instructions: installer-index.md and mcp-workflow.md. Historical company handoff: ../history/cleanup-phase4-prior-docs/company-handoff.md.
