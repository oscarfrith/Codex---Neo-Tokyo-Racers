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
- docs/13_efficient_feature_delivery_protocol.md

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
- Use the proportional Fast/Standard/High-Risk workflow lane; keep isolated changes fast and use ownership/runtime gates only where the risk warrants them.
- Aim for one transactional user-run Studio installer with internal preflight, compile, audit and rollback rather than several setup scripts.
- Treat `continue:` as approval to execute the next uncompleted step of the current plan without inventing another phase.
- Challenge me once, early, when a materially better approach exists; explain the tradeoff, then follow my informed choice.
- After making changes, update the relevant docs and docs/07_patch_history.md.
- Refresh the Studio mirror after Studio-side changes when practical, and do not commit docs/studio-full-export-paste.txt.
```

For driving-specific work, add:

```text
For driving changes, read docs/03_driving_mechanics.md and compare against the latest confirmed stable script in /scripts.
```

For UI-specific work, add:

```text
For UI changes, read docs/04_customisation_ui.md. For garage, dealership or customisation work, also read docs/garage-canonical-handoff-2026-07-18.md and preserve its confirmed ownership, flow, preview and responsive-layout contracts.
```

For VFX-specific work, add:

```text
For VFX changes, read docs/05_vfx_system.md and keep engine/boost/stabiliser thrust colour separate from optional cosmetic neon.
```
