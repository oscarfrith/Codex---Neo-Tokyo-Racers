# Start Every Neo Tokyo Racers Session

Use this at the start of each new ChatGPT or Codex conversation.

```text
You are helping me with my Roblox game project, Neo Tokyo Racers.

Active local repo path:
H:\My Drive\Roblox\Neo Tokyo Racers\Codex - Neo Tokyo Racers

GitHub repo:
https://github.com/oscarfrith/Codex---Neo-Tokyo-Racers

Before answering or changing anything, orient yourself from the repo, not from memory:

1. Read `AGENTS.md`.
2. Read `docs/00_START_HERE.md`.
3. Read `docs/06_current_known_issues.md`.
4. Read `docs/07_patch_history.md`.
5. Read `docs/10_script_source_sync_workflow.md`.
6. Read `docs/11_manual_script_copy_map.md`.
7. If the task touches a specific area, also read the relevant topic docs, for example:
   - vehicles/assets: `docs/02_vehicle_folder_system.md`
   - driving: `docs/03_driving_mechanics.md`
   - UI/customisation: `docs/04_customisation_ui.md`
   - VFX: `docs/05_vfx_system.md`
   - LOD/world: `docs/world-streaming-and-lod.md`
8. Check the relevant command-bar scripts in `scripts/`.
9. If live Studio script source or hierarchy matters, check `roblox/exported_scripts/` and `roblox/studio_snapshot/`, then tell me if either appears stale.
10. Check Git status/diff if you have local repo access.

Working rules:

- Prefer the newest confirmed working baseline over the newest untested script.
- Prefer small Roblox Studio Command Bar scripts over huge rewrites.
- Do not create in-game backup folders/scripts unless I explicitly ask.
- Do not touch unrelated UI/server/VFX/driving systems.
- Use config folders/attributes for tuning values where practical.
- If a script depends on fragile text replacement, say that clearly before writing it.
- If reverting to an older Roblox version/history point would be cleaner than another patch, tell me before creating a new patch.
- Treat `docs/`, `scripts/`, `diagrams/`, `roblox/exported_scripts/`, and `roblox/studio_snapshot/` as the shared project database.

Studio mirror rule:

- After any change made in Roblox Studio that affects scripts, hierarchy, assets/folders, services, config attributes, or live object placement, refresh the repo mirror before final handoff whenever practical.
- Use `py scripts/receive_studio_full_snapshot_export.py` locally, then run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in the Roblox Studio Command Bar.
- Commit generated changes under `roblox/exported_scripts/` and `roblox/studio_snapshot/`.
- Do not commit `docs/studio-full-export-paste.txt`.
- If Codex cannot run local commands or cannot access Studio, ask me to run the receiver/exporter and paste the result, rather than pretending the mirror updated automatically.

When you make changes:

- Put command-bar scripts in `scripts/`.
- Put handoff/design docs in `docs/`.
- Add or update the relevant topic doc.
- Update `docs/00_START_HERE.md` when the current baseline changes.
- Update `docs/06_current_known_issues.md` when risks, verification tasks, or deferred work change.
- Update `docs/07_patch_history.md` with a concise entry.
- Refresh or request refresh of the Studio mirror if Studio-side source/hierarchy changed.
- Keep old failed experiments out of the current baseline unless they are intentionally kept for history.
- At the end, give me:
  - what changed,
  - exactly which script to run in Studio,
  - how to verify it,
  - whether the Studio mirror was refreshed,
  - any risks or rollback notes,
  - a GitHub Desktop commit title and description if files changed.

Current task:
[PASTE MY TASK HERE]
```

## Short Version

```text
Use the Neo Tokyo Racers repo as the source of truth.

Active repo path:
H:\My Drive\Roblox\Neo Tokyo Racers\Codex - Neo Tokyo Racers

GitHub repo:
https://github.com/oscarfrith/Codex---Neo-Tokyo-Racers

Start by reading `AGENTS.md`, `docs/00_START_HERE.md`, `docs/06_current_known_issues.md`, `docs/07_patch_history.md`, `docs/10_script_source_sync_workflow.md`, and relevant topic docs/scripts before acting. Treat `roblox/exported_scripts/` and `roblox/studio_snapshot/` as the Studio mirror. After Studio-side changes, refresh the mirror with `py scripts/receive_studio_full_snapshot_export.py` plus the Studio Command Bar exporter, or ask me to run it if you cannot. Keep changes small, update `scripts/` and `docs/` together, and finish with Studio run steps, verification, mirror status, risks, and a commit title/description.

Task:
[PASTE MY TASK HERE]
```
