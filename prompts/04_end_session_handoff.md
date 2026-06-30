# End Session Handoff Prompt

Use this when closing a Neo Tokyo Racers session and preparing a clean handoff.

```text
Please finish this Neo Tokyo Racers session by creating a clean handoff.

Active repo path:
C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers

GitHub repo:
https://github.com/oscarfrith/Codex---Neo-Tokyo-Racers

Use the repo as the source of truth and update files if needed:

1. Check what changed in `scripts/`, `docs/`, `diagrams/`, `roblox/exported_scripts/`, and `roblox/studio_snapshot/`.
2. Update `docs/00_START_HERE.md` if the current baseline or run order changed.
3. Update `docs/06_current_known_issues.md` with unresolved issues, verification tasks, mirror staleness, or deferred work.
4. Update `docs/07_patch_history.md` with concise entries for the work completed.
5. Add or update any topic/phase-specific handoff doc for new scripts.
6. Make sure old failed experiments are not described as current.
7. If Studio scripts, hierarchy, assets/folders, service layout, config attributes, or live object placement changed, refresh the Studio mirror before final handoff whenever practical:
   - Run local receiver: `py scripts/receive_studio_full_snapshot_export.py`
   - Run Studio exporter: `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua`
   - Verify `roblox/exported_scripts/MANIFEST.md`, `roblox/studio_snapshot/hierarchy.md`, and `roblox/studio_snapshot/checksums.json`
   - Do not commit `docs/studio-full-export-paste.txt`
8. If Codex cannot access local commands or Studio, ask me to run the mirror refresh and paste/push the result.

Give me:

- the current confirmed baseline,
- scripts I should run next, in order,
- Studio verification steps,
- Studio mirror status: refreshed/current/stale/not checked,
- risks/known issues,
- GitHub Desktop commit title and description.
```
