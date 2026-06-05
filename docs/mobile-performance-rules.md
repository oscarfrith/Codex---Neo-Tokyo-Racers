# Mobile / Performance Rules

**Created / first designed:** 2026-05-02  
**Last updated:** 2026-05-12  
**Current status:** Active project-wide technical rule set  
**Relevant docs file:** `docs/mobile-performance-rules.md`  
**Relevant files to edit:** Usually docs only. Only edit scripts/assets when the task is specifically performance optimisation.

## What The System Does

This is not one script, but an agreed technical direction for the whole prototype. Neo Tokyo Racers should be built around mobile-safe performance rules because Roblox has a large mobile audience and the game is an open-world racing experience.

## Current Folder / Script Names

No single script.

Relevant systems affected:

- Vehicle controller
- LOD system
- Lighting system
- Traffic lights
- UI
- Open-world assets
- Customisation system

## Important Attributes / Settings

Performance rules agreed:

- Prioritise playable prototype over feature creep.
- Keep scripts simple and robust.
- Avoid unnecessary per-object scripts.
- Prefer central controllers for repeated world logic.
- Use StreamingEnabled-safe code.
- Use LODs and far proxies for the open world.
- Keep post-processing reasonable for mobile.
- Avoid excessive normals/roughness/material texture cost.
- Avoid relying only on Studio performance.
- Test on real mobile where possible.
- Use MicroProfiler, but do not treat it as the only source of truth.
- Watch for draw call spikes when turning the camera or driving quickly.

## Current Known Issues

- Studio can show tiny stutters that may not exactly match live-client performance.
- Draw calls have previously been around 200 but spiking up to around 450 when moving/turning camera.
- This may be caused by streaming, asset loading, render preparation, or camera/vehicle movement through dense areas.
- Need proper published-client and mobile testing.

## Confirmed Working

- The game currently reaches 60 FPS in Studio despite some perceived stutter.
- Existing LOD system is already helping manage the world.
- Current design approach is aligned with mobile performance.

## Still Needs Testing

- Published Roblox client performance.
- Real phone performance.
- Low-memory device performance.
- Performance while racing at speed through dense city areas.
- Draw call behaviour after assets have already streamed/cached.
- Whether post-processing is too expensive.
- Whether vehicle scripts create any frame spikes.
- Whether traffic lights remain cheap at scale.

## Codex Safety Notes

- Do not use this file as a reason to rewrite multiple systems in one patch.
- Performance changes should be targeted, measurable, and easy to revert.
- Keep gameplay feel intact unless the requested task is specifically performance tuning.
