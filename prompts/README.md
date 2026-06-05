# Neo Tokyo Racers Prompt Pack

Use these prompts to keep ChatGPT and Codex aligned around the same project context, docs, scripts, design decisions, and handoff workflow.

## Recommended Use

Start every new ChatGPT or Codex conversation with:

- `01_start_every_session.md`

Use the others when the situation matches:

- `02_studio_output_debug.md` - paste Roblox Studio output/errors and ask for a careful diagnosis.
- `03_feature_or_system_plan.md` - plan a new feature without jumping straight into code.
- `04_end_session_handoff.md` - close a session by updating docs and producing a clean handoff.
- `05_commit_summary.md` - prepare a GitHub Desktop commit title/description.

## Source Of Truth

The shared project memory lives in:

- `AGENTS.md`
- `docs/00_START_HERE.md`
- `docs/06_current_known_issues.md`
- `docs/07_patch_history.md`
- Topic docs in `docs/`
- Current command-bar scripts in `scripts/`
- Exported Studio mirrors in `roblox/exported_scripts/` when relevant

When an assistant changes the project, ask it to update the docs as part of the same task.
