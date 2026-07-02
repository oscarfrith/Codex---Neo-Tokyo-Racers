# New Chat Prompt

Use this at the start of a new ChatGPT or Codex chat:

```text
Use my Neo Tokyo Racers GitHub repo as project context.

First read:
- AGENTS.md
- docs/00_START_HERE.md
- docs/06_current_known_issues.md
- docs/07_patch_history.md
- docs/10_script_source_sync_workflow.md
- docs/11_manual_script_copy_map.md
- docs/12_continuous_improvement_workflow.md

Treat docs/ as the source of truth.
Do not rely only on chat memory.
Check git status before changing files.

When making changes:
- Prefer small command-bar scripts.
- Avoid touching unrelated systems.
- Do not create Roblox backup folders/scripts unless I ask.
- If reverting to an older stable patch is cleaner, tell me before writing a new patch.
- If source-anchor repairs start failing repeatedly, stop and inspect the live source/mirror before creating another patch.
- Prefer isolated services/client scripts or canonical replacement of a small isolated script over repeated patches to the large bootstrap/controller.
- After making changes, update the relevant docs and docs/07_patch_history.md.
- Refresh the Studio mirror after Studio-side changes when practical, and do not commit docs/studio-full-export-paste.txt.
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
