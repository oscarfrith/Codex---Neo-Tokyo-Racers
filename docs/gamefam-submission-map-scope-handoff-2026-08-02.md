# Gamefam Submission Map Scope Handoff

**Date:** 2026-08-02  
**Status:** Submission direction approved; Studio boundary placement and presentation pass pending  
**Scope:** Documentation and submission planning only; no runtime, persistence, source, hierarchy or asset changes

## Locked Submission Position

The approximately 20 completed city blocks will be presented as Neo Tokyo Racers' intentional playable prototype district for the Gamefam submission. The rest of the city does not need launch-quality completion for this prototype.

- Keep clean, simple distant blockouts where they help communicate the intended city scale and skyline.
- Prevent players from entering visibly unfinished, half-modelled or confusing areas.
- Do not delete the wider city work. Closed areas remain future-production content, not discarded content.
- Do not delay the submission to complete the whole launch map unless the controlled district cannot support the complete prototype loop.
- Cap the focused submission-map pass at roughly one to three working days unless a genuine blocker is found.

## Playable-District Contract

The accessible district must contain a coherent end-to-end prototype experience:

- spawn and initial orientation;
- dealership and vehicle acquisition;
- vehicle spawning and free-roam driving;
- customisation and garage access required by the submission build;
- both current integrated Race/Time Trial experiences, including Shifted Canal and Showroom Loop;
- safe returns from races, menus, teleports, resets and vehicle recovery.

No required prompt, marker, route, teleport, objective or road should direct a reviewer into a closed or visibly unfinished area.

## Boundary and Presentation Rules

Use authored, readable world boundaries rather than unexplained invisible walls. Suitable treatments include construction barriers, security gates, road closures, unfinished bridges, blocked tunnels and district checkpoints.

Each boundary should:

- be obvious at racing speed and from both approach directions;
- have reliable collision and leave enough braking/turnaround space;
- avoid trapping, launching or wedging hover vehicles;
- disable or remove prompts and markers that imply the closed route is usable;
- preserve a clean view beyond it with simple massing or skyline silhouettes;
- remain understandable on desktop, controller and landscape phone/tablet.

Invisible collision may support a visible boundary but should not be the only explanation. Avoid destructive cleanup scripts: exact barrier placement, selective hiding and visual cleanup require author judgement in Studio.

## Submission Triage

Treat these as blockers:

- falling through the world, broken collision or unrecoverable vehicle traps;
- either current race or its normal approach crossing a closed area;
- onboarding, map markers, objectives or teleports leading outside the playable district;
- severe unfinished geometry visible from the main routes or capture points;
- exposed building backs, large holes, floating pieces or obvious placeholder clutter on the review path;
- a WIP region imposing a material performance cost despite being inaccessible.

Treat clean greybox massing, distant silhouettes and deliberately closed roads as acceptable prototype context when they look intentional.

## Done-When Checks

Before submission:

1. Test the complete new-player path on a fresh profile without developer shortcuts.
2. Drive every accessible road and every boundary at speed; confirm collision, turnaround and vehicle recovery.
3. Complete Shifted Canal and Showroom Loop in both applicable Race/Time Trial flows and verify their approaches and exits.
4. Check objectives, prompts, map markers, dealership, customisation, garage, teleports, reset and respawn for routes into closed space.
5. Review the district and skyline from the main roads, race starts, finish areas and intended screenshots in representative lighting.
6. Repeat the critical route on desktop/controller and landscape phone/tablet, including a representative low-end-mobile streaming/LOD check.
7. Capture a short reviewer route through the strongest blocks so the build communicates density and direction quickly.

## Implementation and Mirror Handoff

No Command Bar script is created or required by this handoff. Place boundaries and perform selective presentation cleanup manually in Studio once the exact district edge is chosen.

After any Studio-side boundary, asset, hierarchy, prompt, marker or placement change, refresh the complete repository mirror using the normal receiver/exporter workflow before declaring the submission build locked. Do not commit `docs/studio-full-export-paste.txt`.

## Risk and Rollback

The primary risk is either exposing visibly unfinished work or closing so much space that the city feels small and the main loop becomes awkward. Preserve clean distant scale while controlling physical access.

This decision changes no player data, vehicle data, progression, economy, leaderboard or persistence contract. Rollback is non-destructive: reopen or move individual boundaries and restore any deliberately hidden presentation assets. Do not delete wider-city source geometry merely to prepare the prototype.
