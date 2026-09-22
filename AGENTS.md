# Codex Instructions For This Project

This is the Space Racers Roblox hover racing prototype.

Before making changes:

1. Read `docs/00_START_HERE.md`.
2. Check `docs/06_current_known_issues.md`.
3. Prefer the newest confirmed working baseline over the newest untested script.
4. Read `docs/12_continuous_improvement_workflow.md` before planning multi-step Studio work.
5. Read `docs/13_efficient_feature_delivery_protocol.md` before planning any connected UI, runtime, persistence, VFX, architecture, or multi-system change.
6. Read `docs/14_new_system_readiness_standard.md` before planning or implementing a new system, a substantial system expansion, or connected networking/persistence/runtime work. Use `docs/15_new_system_contract_template.md` for Standard and High-Risk work.

Working rules:

* Prefer small command-bar scripts over huge rewrites.
* Reuse confirmed shared UI components, layout functions, renderers, and semantic tokens before creating page-specific UI. A new page-specific visual implementation is allowed only when the shared contract cannot support the requirement, and that exception must be documented.
* Mobile phones and tablets use the native `StarterGui.ScreenOrientation = LandscapeSensor` project contract. Do not add portrait-specific layouts or runtime orientation writers unless the product orientation requirement is deliberately changed.
* Do not create in-game backup folders/scripts unless explicitly asked.
* Do not touch unrelated UI/server/VFX systems when changing driving mechanics.
* Use config folders/attributes for tuning values where practical.
* If a script depends on fragile text replacement, say so before writing it.
* If reverting to an older Roblox version would be cleaner, tell the user before creating another patch.
* If two or more source-anchor repairs fail in the same live script, stop and inspect the live source/mirror before writing another patch; prefer an isolated canonical replacement when possible.
* GarageClient and old client/server adapter trees were removed in complete cleanup Phase 2. Do not resurrect them. ClientBase starts GarageUI directly; DriveSessionClient owns vehicle-session callbacks. Keep shared rendering/preview/geometry owners and explicit feature APIs; ClientBase owns startup only.
* Apply the project-wide implementation triage rule from `docs/12_continuous_improvement_workflow.md` and the proportional Fast/Standard/High-Risk lanes from `docs/13_efficient_feature_delivery_protocol.md`. Do not force high-risk ceremony onto isolated copy, icon, config, or tuning changes.
* New systems and substantial expansions must also pass the proportional readiness rules in `docs/14_new_system_readiness_standard.md`. The assistant selects the lane, derives the contract and applies it for the duration of that task; `N/A` is allowed for irrelevant concerns, but remotes, authoritative gameplay, saved data, economy, rewards, ownership and lifecycle boundaries cannot bypass their applicable safeguards because a diff is small.
* Chat prefixes are routing contracts: `follow:` implements directly with proportional safeguards; `suggest:` compares approaches and recommends without implementing; `audit:` is read-only; `continue:` executes the next uncompleted step of the already-approved plan; `handoff:` locks the confirmed baseline and updates the handoff. A prefix never authorises unrelated scope or bypasses a genuine safety blocker.
* Optimise for one user-run Studio installer with internal preflight, compile, audit, idempotency, and rollback—not many user-run setup steps. Use a separate read-only Studio audit only when live runtime evidence cannot be established from the mirror or safely inside the installer.
* Before connected changes, establish the intended owner for state, geometry, visibility, preview, runtime attachment, and persistence. Do not add a new owner to fix competing existing owners.
* For complex or ambiguous requests, restate a concise acceptance contract before implementation: goal, required changes, preserved behaviour, shared components, state transitions, device coverage, persistence impact, and done-when checks. Skip this ceremony for genuinely isolated changes.
* Challenge a request once, early, when a materially safer, faster, more reusable, or more future-proof approach exists. Explain the alternative and tradeoff concretely; after the user chooses, proceed without repeatedly reopening the decision.
* Maintain one canonical installer per approved scope. Repair that installer after a failure instead of building a patch ladder. If the live baseline no longer matches, stop and refresh/inspect rather than guessing.
* “Reuse” means calling the same shared component, renderer, layout function, state owner, or semantic token—not copying its coordinates or recreating its appearance.
* Once the user approves a phase or task scope, do not subdivide it into additional phases, patches, or user-run tasks without asking first. Keep necessary repairs in the same canonical script/phase unless the user approves a split.
* After each confirmed phase, update the docs with the lesson learned so future chats start from the better workflow.

Known current baseline:

* All four complete-cleanup phases and all five original architecture phases are user-confirmed. Performance Phase 5 is installed and agent-verified; user playthrough pending. Read docs/architecture/performance-phase5-catalogue-transport.md. Mirror 2026-09-22 13:01:09 passes exact 165-source/44,465-node parity. Garage catalogue snapshots are static per server/Play session; authoring edits require restart. Original templates stay in ServerStorage.Assets.Vehicles; check generated outputs with scripts/performance_phase4/check_projection.py. Phase 6 device/load acceptance remains pending, with iPhone 7 selected. Do not rerun prior installations.
* User approved preserving September 22 physical edits (628 arrow CFrames, 66 added thumbnail records). Complete-cleanup Phase 4 changed sources only; performance Phase 4 moves the original vehicle template root intact and generates preview copies. World-only Workspace boundary and prior exact two-tag exception remain; WIP, physical assets and staging/Archive are protected.
* Preserve saved identity/schema contracts, development tools and lifecycle safeguards. No in-game backups, fallback implementations or new owners. Protected-asset disposition remains unresolved before overall closure.
* Current pipeline: scripts/receive_studio_snapshot.py + scripts/studio_export_snapshot.lua; validate with scripts/verify_studio_mirror.py and scripts/performance_phase5/verify_migration.py. Roll back performance Phase 5, then Phase 4, Phase 3 and Phase 2 before older cleanup recovery. Old tools are archived under scripts/history/snapshot_before_cleanup_phase4.
* Audits: scripts/studio_cleanup_audit.lua and scripts/audit_cleanup.py. No gameplay require through MCP. Windows staging must inherit repo ACLs.
* Distinguish generated, installed, runtime verified and user confirmed. Camera CAM-02 is pre-existing and separate.

Preferred paths:

* Current scripts: `scripts/`
* Handoff docs: `docs/`
* Diagrams: `diagrams/`
