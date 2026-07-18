# Codex Instructions For This Project

This is the Neo Tokyo Racers Roblox hover racing game project.

Before making changes:

1. Read `docs/00_START_HERE.md`.
2. Check `docs/06_current_known_issues.md`.
3. Prefer the newest confirmed working baseline over the newest untested script.
4. Read `docs/12_continuous_improvement_workflow.md` before planning multi-step Studio work.
5. Read `docs/13_efficient_feature_delivery_protocol.md` before planning any connected UI, runtime, persistence, VFX, architecture, or multi-system change.

Working rules:

* Prefer small command-bar scripts over huge rewrites.
* Reuse confirmed shared UI components, layout functions, renderers, and semantic tokens before creating page-specific UI. A new page-specific visual implementation is allowed only when the shared contract cannot support the requirement, and that exception must be documented.
* Do not create in-game backup folders/scripts unless explicitly asked.
* Do not touch unrelated UI/server/VFX systems when changing driving mechanics.
* Use config folders/attributes for tuning values where practical.
* If a script depends on fragile text replacement, say so before writing it.
* If reverting to an older Roblox version would be cleaner, tell the user before creating another patch.
* If two or more source-anchor repairs fail in the same live script, stop and inspect the live source/mirror before writing another patch; prefer an isolated canonical replacement when possible.
* Treat `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled` as register-limited. Do not add new top-level local helpers or large feature blocks to it; use isolated controller scripts/modules plus a tiny table-backed event bridge if a bootstrap hook is unavoidable.
* Apply the project-wide implementation triage rule from `docs/12_continuous_improvement_workflow.md` and the proportional Fast/Standard/High-Risk lanes from `docs/13_efficient_feature_delivery_protocol.md`. Do not force high-risk ceremony onto isolated copy, icon, config, or tuning changes.
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

* `V74` camera assist was confirmed working well by the user.
* `V75` is the latest generated script and adds boost delay plus hover wobble; verify in Studio before treating it as stable.

Preferred paths:

* Current scripts: `scripts/`
* Handoff docs: `docs/`
* Diagrams: `diagrams/`
