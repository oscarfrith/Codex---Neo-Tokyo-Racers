# Feature Or System Planning Prompt

Use this when starting a new system, gameplay feature, UI flow, architecture move, or performance pass.

```text
I want to plan a Neo Tokyo Racers feature/system before coding.

Use the repo docs and scripts as the project database:

- `AGENTS.md`
- `docs/00_START_HERE.md`
- `docs/06_current_known_issues.md`
- `docs/07_patch_history.md`
- relevant topic docs in `docs/`
- relevant command-bar scripts in `scripts/`
- `roblox/exported_scripts/` if live Studio source context is needed

Please produce a practical implementation plan:

1. Current baseline: what exists now and what is confirmed working.
2. Constraints: systems we must not disturb.
3. Proposed design: the simplest robust approach.
4. Data/config shape: folders, attributes, names, and tuning points.
5. Implementation phases: small safe steps, each testable in Studio.
6. Verification checklist: exact Play/Edit mode checks.
7. Rollback/stop conditions: when to stop and ask before proceeding.
8. Docs to update if we implement it.

Do not write code yet unless I explicitly ask after reviewing the plan.

Feature/system:
[DESCRIBE FEATURE HERE]
```
