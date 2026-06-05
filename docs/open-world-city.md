# Open World City / Generated Blocks

**Created / first designed:** Before 2026-04-29  
**Last updated:** 2026-05-12  
**Current status:** Implemented / performance testing ongoing  
**Relevant docs file:** `docs/open-world-city.md`  
**Relevant files to edit:** City block folders, generated block tools, LOD configs, and city asset setup only.

## What The System Does

The open world city provides the racing environment for Neo Tokyo Racers. It contains generated city blocks, futuristic/cyberpunk visual identity, fake companies/images, roads, assets, and LOD-managed world detail.

## Current Folder / Script Names

Known folder:

```text
Workspace
- GeneratedCityBlocks
```

Related folders:

```text
ReplicatedStorage
- FarLOD5
```

Possible related folders TBC:

```text
Workspace
- Traffic Lights

Workspace
- RaceRoutes TBC
```

## Important Attributes / Settings

Design rules:

- City should support fast traversal.
- Assets should be modular.
- LODs should protect performance.
- Avoid copyrighted IP and real-world brands.
- Use fictional companies/graphics.
- Keep collision simple where possible.
- Prioritise routes that support racing rather than purely decorative streets.

## Current Known Issues

- Draw call spikes during movement/camera rotation.
- Need to confirm which city assets are too expensive for mobile.
- Need to ensure LODs and StreamingEnabled work together.
- Need to avoid over-detailing areas outside the prototype race route.

## Confirmed Working

- Open-world city assets exist.
- Generated city block folder exists.
- LOD system exists.
- Fake companies/images exist.

## Still Needs Testing

- Full route performance.
- Mobile performance.
- Streaming pop-in.
- Collision issues at racing speed.
- Navigation clarity.
- Whether the first race route has enough visual guidance.
- Whether city density should be reduced near gameplay-critical routes.

## Codex Safety Notes

- Do not edit vehicle, UI, or lighting logic when the task is only city asset documentation.
- Keep city performance tied to LOD and mobile testing.
- Avoid adding dense decorative detail before the first race route is proven.
