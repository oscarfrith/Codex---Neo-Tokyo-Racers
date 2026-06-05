# New Chat Prompt

Use this at the start of a new ChatGPT or Codex chat:

```text
Use my Neo Tokyo Racers GitHub repo as project context.

First read:
- AGENTS.md
- docs/00_START_HERE.md
- docs/06_current_known_issues.md

Treat docs/ as the source of truth.
Do not rely only on chat memory.

When making changes:
- Prefer small command-bar scripts.
- Avoid touching unrelated systems.
- Do not create Roblox backup folders/scripts unless I ask.
- If reverting to an older stable patch is cleaner, tell me before writing a new patch.
- After making changes, update the relevant docs and docs/07_patch_history.md.
```

For driving-specific work, add:

```text
For driving changes, read docs/03_driving_mechanics.md and compare against the latest confirmed stable script in /scripts.
```

For UI-specific work, add:

```text
For UI changes, read docs/04_customisation_ui.md and preserve the current futuristic style and responsive mobile layout.
```

For VFX-specific work, add:

```text
For VFX changes, read docs/05_vfx_system.md and keep engine/boost/stabiliser thrust colour separate from optional cosmetic neon.
```
