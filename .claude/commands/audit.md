---
description: audit - read-only investigation; no repo, Studio or saved-data changes
argument-hint: <what to investigate>
---
audit: $ARGUMENTS

Read and measure only. Use plan mode.
- Read current baseline/issues and the relevant reference docs; check the issue ledger for an existing ID.
- Inspect live state with read-only MCP tools (search_game_tree, inspect_instance, script_read/grep, get_console_output, screen_capture). execute_luau only for read-only queries; never require gameplay modules. Relevant Roblox skills: rbx-scene-analysis, rbx-perf-profiling, rbx-debug.
- Report: evidence (with time boundaries), likely cause, remaining uncertainty, and the smallest proposed fix with its lane.
No mutations to the repo, Studio, saved data or baseline.
