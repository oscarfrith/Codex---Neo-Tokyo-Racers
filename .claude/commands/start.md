---
description: Start a Space Racers session - orient from repo, Git and live Studio
argument-hint: [task or follow:/suggest:/audit:/continue:/handoff: ...]
---
Start a Space Racers session.

1. Read docs/00_START_HERE.md and docs/06_current_known_issues.md (AGENTS.md is already loaded via CLAUDE.md). Follow the task-specific reading route; use docs/README.md to find the current reference doc for a system rather than dated handoffs.
2. Run `git status` and `git log -1 --oneline`. Report uncommitted work briefly; do not commit it.
3. If the task needs live evidence: read docs/architecture/claude-code-setup.md, then list_roblox_studios, choose Space Racers v1 (placeId 121304917315753), get_studio_state. Report place and mode.
4. Determine the next approved step from 00_START_HERE, not from historical installers. Do not rerun installed migrations.
5. Choose the lane (Fast / Standard / High-Risk) per docs/13 and say which in one line.

Task: $ARGUMENTS

If no task was given, summarise the current task, next action and open gates in five lines or fewer and ask what to do.
