# Hover Racing Vehicle / Driver Seat System

**Created / first designed:** 2026-05-26  
**Last updated:** 2026-05-26  
**Current status:** Implemented / needs wider testing  
**Relevant docs file:** `docs/vehicle-systems.md`  
**Relevant files to edit:** Vehicle scripts only. Do not edit lighting, LOD, traffic lights, or city generation unless specifically requested.

## What The System Does

Core hover-racing vehicle setup for the current playable prototype. The vehicle is based around a driver seat / control seat and hover-style racing behaviour, with the goal of supporting fast futuristic racing in an open-world city.

The current known implemented system includes a driver seat position keeper that appears to maintain or correct the driver/seat position while the vehicle is in use.

## Current Folder / Script Names

Known script:

```text
HOVER_RACING_V2_DriverSeatPosition
```

Known output:

```text
Hover Racing driver seat position keeper running.
```

Likely location:

```text
Server-side script, exact hierarchy TBC
```

Related planned/previously discussed systems:

- Vehicle driving mechanics
- Hovercraft-style handling
- Customisation-ready modular vehicle structure
- Mobile-friendly controls
- Possible future tilt steering support using `UserInputService`

## Important Attributes / Settings

Current exact attributes are TBC.

Design rules already agreed:

- Prioritise playable prototype over over-engineered vehicle systems.
- Keep code modular and easy to debug.
- Server/client separation should be clear.
- Vehicle should remain StreamingEnabled-safe.
- Mobile performance is a priority.
- Decorative vehicle parts should not drive physics complexity unnecessarily.
- Vehicle collision/hitbox should ideally be simple and robust.

## Current Known Issues

- Exact final vehicle hierarchy still needs documenting.
- Need to confirm which scripts are server-side, client-side, and shared modules.
- Need to confirm whether current driving behaviour is fully stable across multiplayer.
- Need to confirm whether driver seat correction causes any jitter, snapping, or desync.
- Mobile control feel still needs real device testing.

## Confirmed Working

- `HOVER_RACING_V2_DriverSeatPosition` runs successfully on the server.
- Vehicle driving mechanics already exist in the current build.
- The project has an established hover-racing direction and playable prototype focus.

## Still Needs Testing

- Multiplayer behaviour with more than one player.
- Published Roblox client test, not just Studio.
- Mobile device performance and control feel.
- Seat enter/exit reliability.
- Respawn/reset behaviour.
- Vehicle behaviour with StreamingEnabled on.
- Network ownership / physics smoothness.
- Whether the driver seat position keeper causes performance or replication issues.

## Codex Safety Notes

- Do not modify lighting, LOD, traffic lights, or city generation when working on vehicle scripts.
- If a script/folder name is marked `TBC`, inspect the Roblox project before renaming or patching.
- Preserve currently working driving behaviour unless the task explicitly asks to replace it.
