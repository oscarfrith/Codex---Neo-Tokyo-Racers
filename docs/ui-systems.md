# UI Systems

**Created / first designed:** Before 2026-05-26  
**Last updated:** 2026-06-03  
**Current status:** Dealership startup UI documented; wider UI system still needs fuller mapping  
**Relevant docs file:** `docs/ui-systems.md`  
**Relevant files to edit:** UI screens and UI client controllers only.

## What The System Does

The game has UI for racing, vehicle feedback, dealership/customisation, and prototype presentation.

The dealership startup UI is currently confirmed through Phase 7:

- Compact intro objective UI.
- Local-only path arrows to the dealership desk.
- Full garage menu opens at `GarageDeskTrigger`, not on spawn.
- First cockpit-buy menu has an Exit button in the bottom-right right column, aligned with the vehicle stats panel and Available Cash frame.
- Exiting the first menu closes the garage and reopens only after leaving/re-entering the desk zone.
- Preview UI/camera behavior starts after cockpit purchase/select.

## Current Folder / Script Names

Known current UI script ownership:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active
```

Wider UI locations still need fuller mapping:

```text
StarterGui
- UI screens TBC

StarterPlayer
- StarterPlayerScripts
  - UI client controllers TBC
```

## Important Attributes / Settings

Design rules:

- UI should be mobile-first.
- UI should support racing readability.
- Avoid clutter during high-speed driving.
- Use clean futuristic styling.
- Keep UI scripts client-side where appropriate.
- Keep data/config separate from UI presentation.

## Current Known Issues

- Exact UI systems are not yet documented.
- Dealership startup UI is documented in `docs/dealership-intro-flow-2026-06-03.md`.
- Need to confirm what UI is functional versus placeholder.
- Need to test on mobile aspect ratios.

## Confirmed Working

- UI exists in the current build.
- Dealership intro/customisation startup UI Phases 1-7 were confirmed working on 2026-06-03.

## Still Needs Testing

- Mobile screen sizes.
- Touch controls.
- Controller support if planned.
- Race HUD clarity at speed.
- Customisation menu usability.
- Performance impact from UI effects.

## Codex Safety Notes

- Do not modify vehicle, LOD, lighting, or economy logic when working on UI unless explicitly requested.
- Keep mobile layouts readable and touch-friendly.
- Preserve working UI behaviour when only styling is requested.
