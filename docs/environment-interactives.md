# Traffic Light Timer System

**Created / first designed:** 2026-04-29  
**Last updated:** 2026-04-29  
**Current status:** Designed / needs hierarchy-matched implementation check  
**Relevant docs file:** `docs/environment-interactives.md`  
**Relevant files to edit:** Traffic light controller script and traffic light model setup only. Do not edit vehicle, lighting, or LOD files unless specifically requested.

## What The System Does

The traffic light system changes traffic light materials on a timer to simulate a simple real-world traffic light cycle.

Instead of changing colours, the asset already has coloured parts. The script changes the active light parts from `SmoothPlastic` to `Neon` when lit, then back when unlit.

Current intended timing:

1. Red for 15 seconds
2. Red + orange for last 3 seconds
3. Green for 15 seconds
4. Orange for 3 seconds
5. Repeat

This is designed to support hundreds of lights efficiently by allowing all traffic lights to share the same cycle.

## Current Folder / Script Names

Known hierarchy as of 2026-04-29:

```text
Workspace
- Traffic Lights
  - Traffic Light Tall A
    - traffic light main
    - traffic light light red
    - traffic light light orange
    - traffic light neon green
```

Folder:

```text
Workspace > Traffic Lights
```

Known model:

```text
Traffic Light Tall A
```

Known light part names:

```text
traffic light light red
traffic light light orange
traffic light neon green
```

Recommended script location:

```text
ServerScriptService
- TrafficLightController.server.lua
```

Actual script name TBC.

## Important Attributes / Settings

Current timing:

```lua
RED_TIME = 15
RED_ORANGE_TIME = 3
GREEN_TIME = 15
ORANGE_TIME = 3
```

Material behaviour:

```lua
Unlit = Enum.Material.SmoothPlastic
Lit = Enum.Material.Neon
```

Design rule:

- All lights changing at the same time is acceptable for the prototype.
- This is more efficient than giving every traffic light its own independent script.
- One central controller should loop through all traffic light models.

## Current Known Issues

- Previous version was not working with the user's actual hierarchy.
- Main cause was likely mismatched part names or script expecting different child names.
- Need to confirm final folder and part naming exactly.
- Need to make the script tolerant of missing parts so one broken traffic light does not stop the whole system.
- Need to decide whether lights should remain synced globally or have simple phase offsets later.

## Confirmed Working

- The desired traffic light behaviour is clearly defined.
- The exact asset hierarchy has been identified.
- The optimisation approach is agreed:
  - One central script
  - Loop over all models
  - Shared global timing
  - No per-light scripts for hundreds of lights

## Still Needs Testing

- Test with one traffic light.
- Test with duplicated traffic lights.
- Test with hundreds of traffic lights.
- Test with StreamingEnabled.
- Test whether streamed-in traffic lights pick up the current cycle state.
- Check server/client replication cost.
- Confirm all light parts switch back to `SmoothPlastic` correctly.
- Confirm there are no warnings from missing parts.

## Codex Safety Notes

- Do not add one script per traffic light.
- Do not edit vehicles, lighting, or LOD while working on traffic lights unless specifically requested.
- Make traffic light code tolerant of missing or renamed parts.
