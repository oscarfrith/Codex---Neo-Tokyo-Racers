# Roblox Studio Output Debug Prompt

Use this when you paste Studio Output, errors, audit reports, or command-bar results.

```text
I am pasting Roblox Studio output for Neo Tokyo Racers.

Active repo path:
C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers

GitHub repo:
https://github.com/oscarfrith/Codex---Neo-Tokyo-Racers

Please:

1. Read the repo context first:
   - `AGENTS.md`
   - `docs/00_START_HERE.md`
   - `docs/06_current_known_issues.md`
   - `docs/07_patch_history.md`
   - `docs/10_script_source_sync_workflow.md`
   - any relevant topic docs/scripts for the system involved
2. If live source/hierarchy context matters, inspect `roblox/exported_scripts/` and `roblox/studio_snapshot/` and say whether they look current or stale.
3. Classify the output:
   - harmless informational output,
   - expected verification output,
   - warning that should be tracked,
   - real bug/regression,
   - missing context where another probe is needed.
4. Identify the likely root cause using file/script references where possible.
5. Do not write a fix immediately if a read-only probe or source inspection would reduce risk.
6. If a fix is needed, prefer a small guarded command-bar script and explain:
   - what it changes,
   - what it will not touch,
   - how I verify it in Studio.
7. Update the docs if this changes the project baseline or known issues.
8. If the fix or verification changes Studio scripts/hierarchy/assets/config, refresh or request refresh of the mirror:
   - local receiver: `py scripts/receive_studio_full_snapshot_export.py`
   - Studio exporter: `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua`
   - commit generated `roblox/exported_scripts/` and `roblox/studio_snapshot/`
   - do not commit `docs/studio-full-export-paste.txt`

Studio output:
[PASTE OUTPUT HERE]
```
