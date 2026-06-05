# End Session Handoff Prompt

Use this before ending a long ChatGPT/Codex session.

```text
Please finish this Neo Tokyo Racers session by creating a clean handoff.

Active repo path:
H:\My Drive\Roblox\Neo Tokyo Racers\Codex - Neo Tokyo Racers

GitHub repo:
https://github.com/oscarfrith/Codex---Neo-Tokyo-Racers

Use the repo as the source of truth and update files if needed:

1. Check what changed in `scripts/`, `docs/`, `diagrams/`, `roblox/exported_scripts/`, and `roblox/studio_snapshot/`.
2. Update `docs/00_START_HERE.md` if the current baseline or run order changed.
3. Update `docs/06_current_known_issues.md` with unresolved issues, verification tasks, mirror staleness, or deferred work.
4. Update `docs/07_patch_history.md` with concise entries for the work completed.
5. Add or update any phase-specific handoff doc for new scripts.
6. Make sure old failed experiments are not described as current.
7. If Studio scripts, hierarchy, assets/folders, service layout, config attributes, or live object placement changed, refresh the Studio mirror before final handoff whenever practical:
   - run local receiver: `py scripts/receive_studio_full_snapshot_export.py`
   - run Studio exporter: `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua`
   - verify `roblox/exported_scripts/MANIFEST.md`, `roblox/studio_snapshot/hierarchy.md`, and `roblox/studio_snapshot/checksums.json`
   - do not commit `docs/studio-full-export-paste.txt`
8. If Codex cannot access local commands or Studio, ask me to run the mirror refresh and paste/push the result.
9. Give me:
   - the current confirmed baseline,
   - scripts I should run next, in order,
   - Studio verification steps,
   - Studio mirror status: refreshed/current/stale/not checked,
   - risks/known issues,
   - GitHub Desktop commit title and description.

Session context:
[OPTIONAL SUMMARY OR OUTPUT HERE]
```
