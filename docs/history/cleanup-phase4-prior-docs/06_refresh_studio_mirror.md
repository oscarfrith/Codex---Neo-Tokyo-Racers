Current override (2026-09-22): Read docs/00_START_HERE.md and docs/architecture/cleanup-phase4-finalisation.md first. Phase 4 is installed; do not reinstall or follow obsolete next-phase instructions below. User test and protected-asset decision remain open.

# Refresh Studio Mirror Prompt

Current 2026-09-05 workflow: follow docs/architecture/mcp-workflow.md and docs/architecture/installer-index.md. Read compact current baseline/issues first; historical run instructions below are recovery context. Execute approved canonical scripts through MCP and preserve the raw paste diff. Phase 1 has no gameplay installer.

Use this after Roblox Studio changes, or whenever `roblox/exported_scripts/` / `roblox/studio_snapshot/` may be stale.

```text
Please help me refresh the Neo Tokyo Racers Studio mirror in GitHub.

Active repo path:
C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers

GitHub repo:
https://github.com/oscarfrith/Codex---Neo-Tokyo-Racers

Goal:
Update the repo so `roblox/exported_scripts/` and `roblox/studio_snapshot/` directly mirror the current Roblox Studio game hierarchy and all Script, LocalScript, and ModuleScript sources.

Use this workflow:

1. Start the local receiver from the repo folder:
   `py scripts/receive_studio_snapshot.py`

2. In Roblox Studio, run this Command Bar script:
   `scripts/studio_export_snapshot.lua`

3. Confirm the receiver says:
   `Studio export received and imported successfully.`

4. Verify:
   - `roblox/exported_scripts/MANIFEST.md` has the expected script count.
   - `roblox/studio_snapshot/hierarchy.md` has the latest Studio timestamp.
   - `roblox/studio_snapshot/checksums.json` exists and has one entry per exported script.
   - Current paths like `NeoTokyoRacersClient` are present.
   - Removed old paths like `ReplicatedStorage.HOVER_RACING_V2_KIT` are not present unless intentionally still in Studio.

5. Check Git status/diff if local command access is available.

6. Tell me exactly what to commit in GitHub Desktop.

Do not commit:
`docs/studio-full-export-paste.txt`

Commit title suggestion:
`Refresh Roblox Studio mirror`

Commit description suggestion:
`Updates exported script sources, hierarchy snapshot, source manifest, and checksums from the current Roblox Studio place.`
```
