# Claude Code setup and Studio MCP rules

Added 2026-09-26 when the primary assistant moved from Codex to Claude Code. Procedure stays in the [delivery workflow](../13_efficient_feature_delivery_protocol.md); this page covers only the tool layer. Current status lives in [start here](../00_START_HERE.md).

## One-time setup per machine

1. Install Claude Code (the Code tab in the Claude desktop app, or the CLI) and open this repository folder as the project. It must run on the same PC as Studio: capture receivers listen on 127.0.0.1 and local Python runs the delivery tools.
2. In Studio: Assistant → … → Manage MCP Servers → turn on **Enable Studio as MCP server** → Quick Connect → toggle **Claude Code**. A green indicator shows a connected client.
3. In Claude Code run `/mcp` and confirm the Roblox Studio server is connected. If the server's name is not `Roblox_Studio`, update the `mcp__Roblox_Studio__*` rules in `.claude/settings.json` to match.
4. Start each session with `/start` (or `/start <task>`).

The older standalone rbx-studio-mcp server is no longer maintained by Roblox; do not install it alongside the built-in server.

## Tool mapping

| Need | Built-in MCP tool | Notes |
|---|---|---|
| Find the instance | list_roblox_studios | Choose `Space Racers v1 (placeId: 121304917315753)`. IDs change per session. |
| Mode check | get_studio_state | Edit for installs/captures; Client/Server only during Play. |
| Hierarchy / properties | search_game_tree, inspect_instance | Read-only. |
| Script source | script_read, script_grep, script_search | Read-only. Prefer these to reading exported mirrors for current source. |
| Output | get_console_output | Record session/time boundaries in evidence. |
| Run Luau | execute_luau | Used for targeted capture producer, generated AUDIT/APPLY/ROLLBACK deliveries and read-only audits. Never `require` gameplay modules (AGENTS rule). |
| Play / stop | start_stop_play | Sandbox and replay remain no-save; check TEST-01 before mutation tests. |
| Visuals | screen_capture | Edit-time camera captures. Good for lighting/UI evidence; save under the task's roblox/captures folder. |
| Input during Play | user_keyboard_input, user_mouse_input, character_navigation | Lets the assistant drive normal UI flow. See evidence rules below. |
| Direct script edit | multi_edit | Text-anchor replacement or new script creation. See rules. |
| Assets | insert_asset, search_asset, generate_mesh/material/texture/procedural_model, upload_image, store_image | Create objects or assets. See rules. |
| Roblox skills | skill | rbx-scene-analysis, rbx-perf-profiling, rbx-debug, rbx-device-simulator-lua, rbx-unit-test and docs search. Useful for PERF-06-A, CAM-02 and device layout checks. |

## Rules for the write tools

- **Default route unchanged.** Existing source bodies and primitive attributes go through `scripts/studio_delivery.py` (AUDIT → review → APPLY via execute_luau). Migrations beyond that use one canonical installer. See [proportional delivery](proportional-mcp-delivery.md).
- **multi_edit** is allowed only for Fast-lane edits to one owner with a targeted `sources` before-capture taken first and an after-capture compared afterwards. Announce it as fragile text replacement (AGENTS rule). The two-failure anchor limit applies. Never use it for Standard/High-Risk work, protected roots, or to create scripts (new scripts are a migration).
- **Asset and generation tools** create objects, so they need explicit user approval for that asset and a Workspace scope inside World or an approved exception. Generated meshes/textures are WIP until the user accepts them visually.
- **start_stop_play** is fine for tests. Stop Play before any Edit-mode capture or install, and re-check `get_studio_state`.

## Evidence categories with assistant-driven input

Driving the client with user_keyboard_input / user_mouse_input and confirming with screen captures and state reads counts as **agent-verified normal UI** when the start screen has been passed through the visible flow (start_screen_active false). Record `interaction: normal-ui` and `visible_input_verified: true` only if the input went through the real UI, not a direct API call. It remains Studio evidence: it is not physical-device, multiplayer, published-persistence or user-confirmed feel. Subjective acceptance (driving feel, visual taste) still belongs to the user.

## Suggested use by role

- **Design:** the Claude app (claude.ai) for concept work, UI mockups and design briefs you want to see and iterate on; `/design` in Claude Code to turn an approved direction into a contract under docs using the existing design systems (racing-ui-design-system, ui-free-roam-pc-design-system, shared-responsive-ui-foundation-v1).
- **Build:** `/follow` or `/continue` with the lane safeguards in docs/13.
- **Review:** the `delivery-reviewer` subagent for High-Risk specs and diffs before APPLY.
- **Model choice:** the strongest available model for suggest:/High-Risk work; a faster model is fine for Fast-lane copy, config and tuning.
