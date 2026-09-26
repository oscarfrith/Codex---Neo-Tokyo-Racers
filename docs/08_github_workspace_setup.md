# Workspace and GitHub setup

GitHub is the long-term memory for this project; the repository, not chat history, is the source of truth. Remote: github.com/oscarfrith/Codex---Neo-Tokyo-Racers (private). Local checkout on the main PC: C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers.

## Assistant setup

The primary assistant is Claude Code, run on the same PC as Roblox Studio. Follow [Claude Code setup](architecture/claude-code-setup.md) once per machine: open this folder in Claude Code, enable Studio's built-in MCP server and Quick Connect Claude Code, then check `/mcp`. Start every session with `/start`.

CLAUDE.md imports AGENTS.md, so durable rules live in AGENTS.md for any assistant. Other assistants (for example Codex) can still work from AGENTS.md and prompts/.

## What is tracked

AGENTS.md, CLAUDE.md, README.md, .claude/ (settings.json, commands, agents; not settings.local.json), docs/, scripts/, diagrams/, roblox/captures, roblox/source_store and the dated full checkpoint folders, .gitignore, .gitattributes. Never commit docs/studio-full-export-paste.txt.

## Committing

Commit and push with GitHub Desktop, or ask Claude Code to commit specific paths during a handoff. Stage explicit paths; the root contains ignored historical scripts and large blobs. Commit message style:

```text
lighting: brighter horizons and five-second warm holds
docs: record V6 lighting acceptance
tools: add targeted capture compare details
```

## Stable baseline rule

Only mark work as user-confirmed after the user has play-tested it. Keep generated, installed, agent-verified and user-confirmed separate (AGENTS.md). Current status belongs only in [00_START_HERE](00_START_HERE.md).

Previous ChatGPT/Codex-era setup text: see Git history of this file.
