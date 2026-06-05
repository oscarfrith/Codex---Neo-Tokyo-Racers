# Start Every Neo Tokyo Racers Session

Use this at the start of each new ChatGPT or Codex conversation.

```text
You are helping me with my Roblox game project, Neo Tokyo Racers.

Repo path:
C:\Users\Oscar\Documents\Codex\2026-05-02\Neo Tokyo Racers

Before answering or changing anything, orient yourself from the repo, not from memory:

1. Read `AGENTS.md`.
2. Read `docs/00_START_HERE.md`.
3. Read `docs/06_current_known_issues.md`.
4. Read `docs/07_patch_history.md`.
5. If the task touches a specific area, also read the relevant topic docs, for example:
   - vehicles/assets: `docs/02_vehicle_folder_system.md`
   - driving: `docs/03_driving_mechanics.md`
   - UI/customisation: `docs/04_customisation_ui.md`
   - VFX: `docs/05_vfx_system.md`
   - LOD/world: `docs/world-streaming-and-lod.md`
   - architecture/script sync: `docs/10_script_source_sync_workflow.md` and `docs/11_manual_script_copy_map.md`
6. Check the relevant scripts in `scripts/`.
7. If live Studio script source matters, check `roblox/exported_scripts/` and tell me if it may be stale.
8. Check Git status/diff if you have local repo access.

Working rules:

- Prefer the newest confirmed working baseline over the newest untested script.
- Prefer small Roblox Studio Command Bar scripts over huge rewrites.
- Do not create in-game backup folders/scripts unless I explicitly ask.
- Do not touch unrelated UI/server/VFX/driving systems.
- Use config folders/attributes for tuning values where practical.
- If a script depends on fragile text replacement, say that clearly before writing it.
- If reverting to an older Roblox version/history point would be cleaner than another patch, tell me before creating a new patch.
- Treat `docs/`, `scripts/`, and `diagrams/` as the shared project database.

When you make changes:

- Put command-bar scripts in `scripts/`.
- Put handoff/design docs in `docs/`.
- Add or update the relevant topic doc.
- Update `docs/00_START_HERE.md` when the current baseline changes.
- Update `docs/06_current_known_issues.md` when risks, verification tasks, or deferred work change.
- Update `docs/07_patch_history.md` with a concise entry.
- Keep old failed experiments out of the current baseline unless they are intentionally kept for history.
- At the end, give me:
  - what changed,
  - exactly which script to run in Studio,
  - how to verify it,
  - any risks or rollback notes,
  - a GitHub Desktop commit title and description if files changed.

Current task:
[PASTE MY TASK HERE]
```

## Short Version

```text
Use the Neo Tokyo Racers repo as the source of truth. Start by reading `AGENTS.md`, `docs/00_START_HERE.md`, `docs/06_current_known_issues.md`, and `docs/07_patch_history.md`, then inspect the relevant topic docs/scripts before acting. Keep changes small, update `scripts/` and `docs/` together, and finish with Studio run steps, verification, risks, and a commit title/description.

Task:
[PASTE MY TASK HERE]
```
