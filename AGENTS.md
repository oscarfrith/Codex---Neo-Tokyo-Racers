# Codex Instructions For This Project

This is the Neo Tokyo Racers Roblox hover racing game project.

Before making changes:

1. Read `docs/00_START_HERE.md`.
2. Check `docs/06_current_known_issues.md`.
3. Prefer the newest confirmed working baseline over the newest untested script.
4. Read `docs/12_continuous_improvement_workflow.md` before planning multi-step Studio work.

Working rules:

* Prefer small command-bar scripts over huge rewrites.
* Do not create in-game backup folders/scripts unless explicitly asked.
* Do not touch unrelated UI/server/VFX systems when changing driving mechanics.
* Use config folders/attributes for tuning values where practical.
* If a script depends on fragile text replacement, say so before writing it.
* If reverting to an older Roblox version would be cleaner, tell the user before creating another patch.
* If two or more source-anchor repairs fail in the same live script, stop and inspect the live source/mirror before writing another patch; prefer an isolated canonical replacement when possible.
* Treat `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled` as register-limited. Do not add new top-level local helpers or large feature blocks to it; use isolated controller scripts/modules plus a tiny table-backed event bridge if a bootstrap hook is unavoidable.
* Apply the project-wide implementation triage rule from `docs/12_continuous_improvement_workflow.md` to all features, systems, tweaks, and refinements. `follow:` means execute with normal safety checks; `suggest:` means compare better options and recommend a stable path before implementation.
* After each confirmed phase, update the docs with the lesson learned so future chats start from the better workflow.

Known current baseline:

* `V74` camera assist was confirmed working well by the user.
* `V75` is the latest generated script and adds boost delay plus hover wobble; verify in Studio before treating it as stable.

Preferred paths:

* Current scripts: `scripts/`
* Handoff docs: `docs/`
* Diagrams: `diagrams/`
