# Neo Tokyo Racers Prompt Pack

Use these prompts to keep ChatGPT and Codex aligned around the same project context, docs, scripts, design decisions, Studio export mirror, and handoff workflow.

## Active Repo

Local shared repo path:

```text
C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers
```

GitHub repo:

```text
https://github.com/oscarfrith/Codex---Neo-Tokyo-Racers
```

## Recommended Use

Start every new ChatGPT or Codex conversation with:

- `01_start_every_session.md`

Use the others when the situation matches:

- `02_studio_output_debug.md` - paste Roblox Studio output/errors and ask for a careful diagnosis.
- `03_feature_or_system_plan.md` - plan a new feature without jumping straight into code.
- `04_end_session_handoff.md` - close a session by updating docs and producing a clean handoff.
- `05_commit_summary.md` - prepare a GitHub Desktop commit title/description.
- `06_refresh_studio_mirror.md` - refresh the GitHub mirror after Studio-side changes.

## Source Of Truth

The shared project memory lives in:

- `AGENTS.md`
- `docs/00_START_HERE.md`
- `docs/06_current_known_issues.md`
- `docs/07_patch_history.md`
- Topic docs in `docs/`
- Current command-bar scripts in `scripts/`
- Studio hierarchy and source mirrors in `roblox/exported_scripts/` and `roblox/studio_snapshot/`

When Studio changes are made, refresh the mirror with:

```text
py scripts/receive_studio_full_snapshot_export.py
```

then run this in the Roblox Studio Command Bar:

```text
scripts/roblox_studio_export_full_snapshot_for_github_v2.lua
```

Commit the generated `roblox/exported_scripts/` and `roblox/studio_snapshot/` changes. Do not commit `docs/studio-full-export-paste.txt`.

When an assistant changes the project, ask it to update docs and refresh or request a refresh of the Studio mirror as part of the same task whenever Studio-side source/hierarchy changed.
