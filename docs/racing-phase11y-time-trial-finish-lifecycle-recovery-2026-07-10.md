# Racing Phase 11Y - Time Trial Finish Lifecycle Recovery

**Script:** `scripts/roblox_racing_phase11y_time_trial_finish_lifecycle_recovery.lua`  
**Status:** Generated for Studio install/test  
**Date:** 2026-07-10

## Reason

After Phase 11X passed, repeated time-trial finish/exit loops could still return to the older stuck state where the player could not re-enter time trials/races, use race-browser teleport, or spawn a free-roam car.

Root cause from the mirrored source: `finishRun()` removed the active time-trial run but made the finished race vehicle drive-ready again while result-exit cleanup was still pending. If the result exit was missed, hidden too early, or invoked twice, the player could be left in a stale driving/session boundary state.

## What Phase 11Y Changes

- Patches `TimeTrialService_Active` so a finished time-trial vehicle is marked `NTR_RaceFinishedPendingExit`, frozen, drive-disabled, VFX-disabled, and unseated while the result screen is open.
- Keeps the finished-run cache from Phase 11K, but adds a recovery path if `ExitFinishedTimeTrial` is called after the cache is already gone.
- Lets pressing a start-zone prompt self-heal any stale finished time-trial vehicle before opening the next entry menu.
- Patches `RaceTimeTrialResultCoachClient_Active` so the result panel stays visible until server cleanup confirms success or the fallback cleanup succeeds.

## Verification

1. Run the Phase 11Y script in Studio Edit mode.
2. Restart Play.
3. Start a solo time trial, finish it, press the result coach exit button, and confirm you return to the route teleport/start point.
4. Re-enter the same time trial and finish/exit again.
5. Confirm you can still:
   - open the time-trial entry menu,
   - open the race entry menu,
   - use Race browser teleport,
   - spawn a free-roam car near valid road markers.
6. Repeat the loop at least three times, because this bug appeared after an initially clean pass.

## Boundaries

Phase 11Y does not change rewards, PB persistence, route-guide config, route arrows, VFX isolation, matchmaking, free-roam nav layout, garage server behavior, or the main bootstrap.

## Rollback

Use Roblox Studio version history to revert the two patched live scripts if needed:

- `ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTimeTrialResultCoachClient_Active`
