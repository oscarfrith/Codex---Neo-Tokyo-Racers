# Codex Instructions For This Project

This is the Neo Tokyo Racers Roblox hover racing game project.

Before making changes:

1. Read `docs/00_START_HERE.md`.
2. Check `docs/06_current_known_issues.md`.
3. Prefer the newest confirmed working baseline over the newest untested script.

Working rules:

- Prefer small command-bar scripts over huge rewrites.
- Do not create in-game backup folders/scripts unless explicitly asked.
- Do not touch unrelated UI/server/VFX systems when changing driving mechanics.
- Use config folders/attributes for tuning values where practical.
- If a script depends on fragile text replacement, say so before writing it.
- If reverting to an older Roblox version would be cleaner, tell the user before creating another patch.

Known current baseline:

- `V74` camera assist was confirmed working well by the user.
- `V75` is the latest generated script and adds boost delay plus hover wobble; verify in Studio before treating it as stable.

Preferred paths:

- Current scripts: `scripts/`
- Handoff docs: `docs/`
- Diagrams: `diagrams/`
