# End Session Handoff Prompt

Use this before ending a long ChatGPT/Codex session.

```text
Please finish this Neo Tokyo Racers session by creating a clean handoff.

Use the repo as the source of truth and update files if needed:

1. Check what changed in `scripts/`, `docs/`, `diagrams/`, and any exported Studio script mirrors.
2. Update `docs/00_START_HERE.md` if the current baseline or run order changed.
3. Update `docs/06_current_known_issues.md` with unresolved issues, verification tasks, or deferred work.
4. Update `docs/07_patch_history.md` with concise entries for the work completed.
5. Add or update any phase-specific handoff doc for new scripts.
6. Make sure old failed experiments are not described as current.
7. Give me:
   - the current confirmed baseline,
   - scripts I should run next, in order,
   - Studio verification steps,
   - risks/known issues,
   - GitHub Desktop commit title and description.

Session context:
[OPTIONAL SUMMARY OR OUTPUT HERE]
```
