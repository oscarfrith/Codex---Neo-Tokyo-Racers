---
description: Move dated phase handoff docs into docs/history without breaking links (dry run first)
---
Reorganise docs so the docs/ root holds only reference docs.
1. Use docs/README.md: every file listed under "Dated phase handoffs" is a candidate. Exclude anything linked from AGENTS.md, CLAUDE.md, docs/00_START_HERE.md, docs/06, docs/13, docs/14 or the current reference docs unless you also update that link.
2. Dry run: produce the move list (target docs/history/phases/<system>/) and every inbound link (grep across *.md, *.json, *.py, *.lua) that must change. Show it and wait for approval.
3. After approval: `git mv` each file, rewrite inbound links and the moved files' own relative links, then verify no markdown link under docs/, AGENTS.md, CLAUDE.md or README.md points to a missing file.
4. Update docs/README.md. Commit only if authorised. No Studio changes.
