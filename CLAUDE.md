@AGENTS.md

# Claude Code notes

AGENTS.md (imported above) is the single source of project rules, shared with any other assistant. Put durable rules there, not here. This file only covers how Claude Code applies them.

The game is currently titled **Space Racers** (place 121304917315753); older docs and the repo name say Neo Tokyo Racers or Codex. They are the same project.

## Studio connection

- Studio is reached through the Roblox Studio built-in MCP server (Studio: Assistant → … → Manage MCP Servers). Tool mapping, permissions and rules are in [Claude Code setup](docs/architecture/claude-code-setup.md). Read it before the first Studio call of a session.
- Every session: `list_roblox_studios` → pick the instance named `Space Racers v1 (placeId: 121304917315753)` → `get_studio_state`. Never reuse a studio_id from an earlier session.
- Read-only inspection (`search_game_tree`, `inspect_instance`, `script_read`, `script_grep`, `get_console_output`, `screen_capture`) needs no ceremony.
- Game changes go through the delivery routes in docs/13 and docs/architecture/proportional-mcp-delivery.md. `multi_edit` and the generate/insert tools are direct writes; the setup doc says when they are allowed.

## Context budget

- Do not read these whole; search them: docs/history/*, docs/studio-inventory-report-2026-05-28.md, roblox/exported_scripts/manifest.json, and the multi-megabyte scripts/roblox_cleanup_phase*.lua / roblox_performance_phase*.lua installers.
- docs/studio-full-export-paste.txt is blocked by settings; never read or commit it.
- docs/07_patch_history.md holds recent entries only; read the top few. Older entries are in docs/history/patch-history-2026-05-to-2026-08.md.
- [docs/README.md](docs/README.md) separates current reference docs from dated phase handoffs. Prefer the reference doc for a system; open dated handoffs only for regressions or recovery.
- For broad sweeps across docs or scripts, use a subagent so the main session keeps only the conclusion.

## Working style

- Routing words map to slash commands: /suggest, /follow, /audit, /continue, /handoff. Plain `follow:` etc. in a message works the same.
- Use plan mode for suggest: and audit: work, and for any High-Risk lane task before mutation.
- For High-Risk deliveries (persistence, economy, remotes, architecture, retirement), run the `delivery-reviewer` subagent on the spec and diff before APPLY. It has not seen the build and checks it against the contract.
- Local Python: discover it each session (`py -3 --version`, then `python --version`). Capture receivers bind 127.0.0.1:8766, so captures only work when Claude Code runs on the same PC as Studio.
- Git: stage specific paths, never `git add -A` (the root holds ignored historical scripts and large blobs). Commit only when asked or when the handoff is authorised; report push results only after they succeed. Standing authorisation (Oscar, 2026-09-26): "Oscar authorises Claude to commit and push verified work to origin main at the end of each task or handoff. Stage explicit paths only, use area: summary messages, never force-push or rewrite history, never commit docs/studio-full-export-paste.txt."
