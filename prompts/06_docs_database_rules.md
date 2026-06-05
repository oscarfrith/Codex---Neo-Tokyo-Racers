# Docs Database Rules Prompt

Use this when you want an assistant to clean up or maintain the shared project docs.

```text
Please treat the Neo Tokyo Racers repo docs as a shared project database for ChatGPT and Codex.

Audit and update the docs so future sessions can quickly understand the project:

1. `docs/00_START_HERE.md` should contain only the current high-level baseline, key completed phases, important run order, and links.
2. `docs/06_current_known_issues.md` should contain unresolved issues, deferred work, and verification checks only. Remove resolved items.
3. `docs/07_patch_history.md` should contain concise historical entries, not long implementation dumps.
4. Topic docs should hold system-specific decisions:
   - vehicle assets and folders,
   - driving,
   - UI/customisation,
   - VFX,
   - world/LOD,
   - architecture/script sync.
5. New scripts should have matching phase docs when they change project state.
6. Do not describe untested experiments as the current baseline.
7. Keep docs factual: include dates, exact script names, and Studio verification status where known.

Before editing, show me any stale/conflicting doc entries you find and your proposed cleanup.
```
