# Starting a new session

In Claude Code, type `/start` followed by the task, for example:

```text
/start follow: widen the paint shop price label so four-digit prices fit
/start audit: CAM-02 camera clamp error after re-entry
/suggest multiplayer lobby for the showroom loop
/design daily login reward with a streak bonus
/start follow: implement the approved daily reward design
```

For a new feature: `/design <idea>` first (writes a spec using the current owners), then `/follow` to build it. Read the [new feature checklist](architecture/architecture-programme.md#new-feature-checklist) and [testing playbook](architecture/studio-testing-playbook.md). Keep Studio visible when UI, camera or race behaviour will be tested (the Play viewport must render).

/start reads AGENTS.md (via CLAUDE.md), 00_START_HERE and the issue ledger, checks Git, connects to the Space Racers Studio instance when needed and states the delivery lane. Routing words (follow:, suggest:, audit:, continue:, handoff:) work as plain text too; see docs/13.

Add context for the system you are touching:
- Driving: docs/03_driving_mechanics.md and driving-feel-tuning-reference-2026-07-13.md.
- UI, garage, dealership or customisation: docs/04_customisation_ui.md and garage-canonical-handoff-2026-07-18.md; preserve its ownership, flow, preview and responsive-layout contracts.
- VFX: docs/05_vfx_system.md; keep engine/boost/stabiliser thrust colour separate from optional cosmetic neon.
- Networking, economy, flags, analytics, camera owners: [architecture programme](architecture/architecture-programme.md).
- Anything else: find the reference doc in [docs index](README.md).

For assistants without the slash commands, use prompts/01_start_every_session.md.
