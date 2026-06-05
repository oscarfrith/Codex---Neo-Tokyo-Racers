# Current Mechanics

**Document status:** Current prototype mechanics reference  
**Document created:** 2026-05-28  
**Document last updated:** 2026-06-03  
**Source:** ChatGPT project notes and current Roblox Studio implementation discussions  
**Current status:** Active index / source-of-truth summary  

## Codex Usage Rule

When using this document with Codex:

- Treat the newest `Last updated` date as the most reliable version of each system.
- Only edit files related to the system being requested.
- Do not rewrite unrelated systems.
- Do not replace newer files with older logic unless explicitly requested.
- If a script/folder name is marked `TBC`, inspect the Roblox project or ask for the latest hierarchy before renaming files.
- Prefer small targeted changes over large rewrites.
- Preserve existing working behaviour unless the task specifically asks to replace it.

## System Index

Architecture planning:

- [architecture-reorganisation-plan.md](architecture-reorganisation-plan.md)
- [hierarchy-migration-plan-2026-05-28.md](hierarchy-migration-plan-2026-05-28.md)
- [studio-inventory-report-2026-05-28.md](studio-inventory-report-2026-05-28.md)

| System | Status | Last updated | Detailed doc |
| --- | --- | --- | --- |
| Hover Racing Vehicle / Driver Seat System | Implemented / needs wider testing | 2026-05-26 | [vehicle-systems.md](vehicle-systems.md) |
| Day / Night Lighting Preset System | Partially working / night sky issue unresolved | 2026-05-26 | [lighting-and-atmosphere.md](lighting-and-atmosphere.md) |
| Open World LOD / Far Proxy System | Implemented / foliage LOD issue previously found | 2026-04-29 | [world-streaming-and-lod.md](world-streaming-and-lod.md) |
| Traffic Light Timer System | Designed / needs hierarchy-matched implementation check | 2026-04-29 | [environment-interactives.md](environment-interactives.md) |
| Mobile / Performance Rules | Active project-wide technical rule set | 2026-05-12 | [mobile-performance-rules.md](mobile-performance-rules.md) |
| Customisation System | Dealership/cockpit startup flow documented; wider module/customisation details still need fuller mapping | 2026-06-03 | [customisation-system.md](customisation-system.md) |
| UI Systems | Dealership startup UI documented; wider UI system still needs fuller mapping | 2026-06-03 | [ui-systems.md](ui-systems.md) |
| Dealership Intro / Startup Flow | Phases 1-7 installed and user-confirmed working | 2026-06-03 | [dealership-intro-flow-2026-06-03.md](dealership-intro-flow-2026-06-03.md) |
| Race Events / First Race Prototype | Planned / not confirmed implemented | 2026-05-26 | [race-events.md](race-events.md) |
| Open World City / Generated Blocks | Implemented / performance testing ongoing | 2026-05-12 | [open-world-city.md](open-world-city.md) |

## Known Project-Wide Issues

**Created / first designed:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Active checklist  
**Relevant docs file:** `docs/current-mechanics.md`

- Some exact script/folder names still need recording from Roblox Studio.
- Night mode currently has a day skybox issue, last discussed 2026-05-26.
- LOD4 foliage visibility previously behaved incorrectly, last discussed 2026-04-29.
- Traffic light script needed adjustment to match the actual hierarchy, last discussed 2026-04-29.
- Draw calls can spike when moving or rotating the camera, last discussed 2026-05-12.
- Mobile testing is still needed.
- Published-client testing is still needed.
- Some existing systems are implemented but not yet documented in GitHub.

## Confirmed Working Across The Project

- Vehicle driving mechanics exist.
- Driver seat position keeper runs.
- Open-world city exists.
- LOD system exists.
- Far LOD5 system exists.
- Lighting preset workflow exists.
- Day lighting values have been captured.
- UI exists.
- Customisation exists.
- Dealership intro Phases 1-7 are working: desk-gated garage open, delayed local preview after cockpit purchase/select, restored preview orbit camera, editable final vehicle exit spawn, and first-menu Exit/reopen gating.
- Traffic light behaviour has been designed.
- The project direction is clear: playable futuristic hover-racing prototype for funding.

## Still Needs Testing Across The Project

- Full gameplay loop from spawn to race completion.
- Multiplayer.
- Mobile.
- Published client.
- StreamingEnabled edge cases.
- Save/load if used.
- Performance over long play sessions.
- Race route readability.
- Vehicle stability at high speed.
- Lighting changes in live gameplay.
- LOD transitions during fast driving.

## Codex Safety Notes

- Do not use this index as permission to rewrite multiple systems at once.
- When a task targets one system, read that system doc first and edit only related docs or code.
- If a future task needs code changes, update the relevant docs after the implementation is confirmed in Studio.
