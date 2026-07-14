# Racing UI Phase 16F - Streaming-Safe Course Arrows

**Status:** Installed and confirmed working by the user on 2026-07-13. Refresh and push the Studio mirror before the next source change; the repository mirror at handoff still shows the pre-16F Phase 16E owner.

## Outcome

Phase 16E substantially improved the reported driving stutter, but the local course-guidance arrows remained invisible. The refreshed mirror showed that the transparency fallback itself was correct; the active client simply had no arrow parts in its cached segment when visibility was applied.

## Root cause

`RaceSessionAssetsClient_Active` cached each arrow segment's descendants once. With `StreamingEnabled`, a segment folder can exist before its MeshParts arrive. That produced an empty permanent part cache. The controller then stored an unchanged run/route/segment signature, so subsequent lightweight updates skipped the segment even after its parts streamed in.

An exact `RouteId` folder lookup was also unnecessarily fragile when catalog and Workspace identifiers differed only by separators or casing.

## Repair

Use `scripts/roblox_racing_ui_phase16f_streaming_safe_arrow_visibility.lua` in Studio Edit mode.

Phase 16F changes only the isolated local course-arrow presentation owner:

- registers existing and late-streamed BaseParts for each segment;
- immediately applies the segment's current visible/hidden state to every late part;
- retries when a route or `ArrowMarkers` folder has not streamed yet instead of caching the miss;
- invalidates the lightweight signature when segment folders arrive or leave;
- resolves route folders by exact name first, then by a normalized name/`RouteId` attribute;
- preserves `NTR_ArrowOriginalTransparency`, with `0` as the visible fallback;
- keeps arrow parts non-collidable locally.

It does not restore opponent markers, broad descendant polling, legacy UI, or render-step scans. Server collision proxies, checkpoint progression, LOD, rewards, PB ownership, matchmaking, Phase 8H reset, and Phase 11Y cleanup are unchanged.

## Test

1. Run the installer with `MODE = "INSTALL"` in Studio Edit mode.
2. Restart Play completely.
3. Start a time trial and confirm the local upcoming course segments appear.
4. Drive through several checkpoints and confirm the visible window advances without a recurring stutter.
5. Exit and start again to confirm the arrows reappear.
6. Stop Play, set `MODE = "SMOKE"`, and run the same script in Edit mode.

If the arrows still do not appear, refresh the mirror before another source repair and capture the client Output plus the live `ArrowMarkers` hierarchy. Do not add another transparency patch before checking whether the streamed parts and route identifier are present.
