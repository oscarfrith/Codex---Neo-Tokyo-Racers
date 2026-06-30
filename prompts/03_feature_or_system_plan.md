# Feature Or System Planning Prompt

Use this when starting a new system, gameplay feature, UI flow, architecture move, or performance pass.

```text
I want to plan a Neo Tokyo Racers feature/system before coding.

Active repo path:
C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers

GitHub repo:
https://github.com/oscarfrith/Codex---Neo-Tokyo-Racers

Use the repo docs, scripts, and Studio mirror as the project database:

- `AGENTS.md`
- `docs/00_START_HERE.md`
- `docs/06_current_known_issues.md`
- `docs/07_patch_history.md`
- `docs/10_script_source_sync_workflow.md`
- relevant topic docs in `docs/`
- relevant command-bar scripts in `scripts/`
- `roblox/exported_scripts/` if live Studio script source context is needed
- `roblox/studio_snapshot/` if live Studio hierarchy/config/object context is needed

Please produce a practical implementation plan:

1. Current baseline: what exists now and what is confirmed working.
2. Mirror freshness: whether `roblox/exported_scripts/` and `roblox/studio_snapshot/` look current enough for this plan.
3. Constraints: systems we must not disturb.
4. Proposed design: the simplest robust approach.
5. Data/config shape: folders, attributes, names, and tuning points.
6. Implementation phases: small safe steps, each testable in Studio.
7. Verification checklist: exact Play/Edit mode checks.
8. Rollback/stop conditions: when to stop and ask before proceeding.
9. Docs to update if we implement it.
10. Studio mirror refresh: when to run `py scripts/receive_studio_full_snapshot_export.py` and `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` so the repo stays a direct mirror after changes.

Do not write code yet unless I explicitly ask after reviewing the plan.

Feature/system:
[DESCRIBE FEATURE HERE]
```
