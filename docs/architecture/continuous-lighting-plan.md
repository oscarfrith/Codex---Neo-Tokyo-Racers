# Continuous lighting: baseline analysis and approved design

Baseline investigation and approved design, 2026-09-22. The user approved implementation, with streetlights and windows switching at sunset/sunrise. Current task/next action is in [start here](../00_START_HERE.md); observed delivery and acceptance limits are in the [handoff](continuous-lighting-handoff.md). The first section describes the original system captured before implementation.

## Evidence and current behaviour

Freshly discovered Space Racers v1, place 121304917315753, in Edit mode. Git began clean on main at d524833. No gameplay modules were required through MCP and no game instances, source, properties or configuration were changed. The existing Edit view was inspected visually; other stages and transitions were not previewed or playtested.

[Verified targeted capture](../../roblox/captures/lighting-cycle-analysis-20260922/capture.json): 2026-09-22 21:36:37 UTC, 165 source records and 85 nodes across Lighting, lighting config, skies and the relevant garage/development configs. All source hashes match workflow-phase3-after and all exported source files read for this analysis match the fresh capture. This establishes source parity, not whole-place physical parity.

[Supplemental live reads](../../roblox/captures/lighting-cycle-analysis-20260922/analysis-supplement.json) record ColorShift values, sun direction and tag counts. The capture tool rejects underscores in additional property names, so ColorShift_Top/Bottom required a separate read. No capture-tool code was changed. This supplement is observational evidence, not an integrity-checked replacement for the capture manifest.

LightingServer polls once per second, chooses a stage, and applies the complete preset only when its name changes. It replaces ActiveSky at each stage. The schedule is synchronized using Unix time modulo its total length. Live config: AutoCycleEnabled=true, SynchronizeAcrossServers=true, BaseDurationSeconds=90, ManualStage=Day.

The exact stage boundaries and durations are:

| Stage ID | Starts within cycle | Seconds until next stage | Actual ClockTime | Brightness | Exposure | Atmosphere density / haze / glare |
|---|---:|---:|---:|---:|---:|---|
| SevenAM | 0 | 90 | 9.4 (09:24) | 0.22 | -0.45 | 0.237 / 5.40 / 6.90 |
| TenAM | 90 | 90 | 10 | 3.00 | 0.10 | 0.254 / 2.06 / 2.10 |
| Day | 180 | 180 | 12 | 5.15 | 0.10 | 0.220 / 0 / 0 |
| ThreePM | 360 | 90 | 14.5 (14:30) | 3.00 | 0.10 | 0.254 / 2.06 / 2.10 |
| FivePM | 450 | 90 | 14.7 (14:42) | 0.19 | -0.45 | 0.267 / 5.40 / 6.90 |
| EightPM | 540 | 90 | 23.5 (23:30) | 2.40 | 0.11 | 0.307 / 4.09 / 6.86 |
| ClearNight | 630 | 180 | 0 | 2.71 | 0 | 0.307 / 4.09 / 6.86 |
| FourAM | 810 | 90 | 0.5 (00:30) | 2.40 | 0.11 | 0.307 / 4.09 / 6.86 |

Total: 900 seconds / 15 minutes. These values are artistic snapshots, not an already continuous solar schedule. For example, the existing afternoon-to-evening interval advances only 12 in-game minutes, followed by 8 hours 48 minutes in the next interval. Blind time interpolation would alternate between almost stationary and fast-moving shadows.

The live Edit state matches Day. LightingStyle is Realistic, PrioritizeLightingQuality and GlobalShadows are true, ShadowSoftness is 0.2. GeographicLatitude is **189 degrees**. At ClockTime=12 the read-only GetSunDirection result has Y=-0.96815, placing the reported sun direction below the horizon. This is evidence to calibrate latitude and time together, not permission to silently change the accepted art direction.

Other findings:

- All eight stage skies share the same six skybox texture IDs, sun/moon textures, 3000 stars and moon size 11. Day/TenAM/ThreePM use yaw 0; the others use yaw 90. Sun size switches between 21 and 0. There is no need for image crossfading or repeated sky replacement to preserve the existing texture set.
- Traditional FogStart=0, FogEnd=100000 and FogColor=(192,192,192) are identical across presets. The meaningful current atmospheric differences are Density, Offset, Color, Decay, Haze and Glare. Roblox documents the old fog controls as hidden with an Atmosphere present.
- Ambient moves from warm near-white at sunrise/sunset to blue at midday/night. OutdoorAmbient, environment diffuse/specular, color correction and bloom also change strongly. Brightness alone does not describe perceived scene brightness.
- FivePM brightness 0.19 versus Day 5.15 is roughly a 27x difference, with exposure changing too. Haze/glare are high at both twilight and night. Intermediate values need visual tuning together; numerical continuity alone cannot guarantee a good image.
- Day omits some explicit Enabled flags and the SunRays/DepthOfField sections. Currently SunRays and DepthOfField are disabled, Bloom and ColorCorrection are enabled. Continuous targets must be complete rather than inheriting values from the previous context. ColorGrading is enabled with the Default tonemapper and is not controlled by these presets; preserve it.
- StageVisuals overrides the schedule's lamp/window flags: SevenAM and FivePM actually request night windows and enabled lamps, as do EightPM, ClearNight and FourAM. TenAM, Day and ThreePM request day windows and disabled lamps. Lamp brightness is 2 throughout. Read this config as the visual authority.
- Live tags contain 554 SurfaceLights and 92 window MeshParts. Of these, 9 lights and 53 window entries lie outside Workspace.World. Duplicate paths exist. Existing tag coverage is not new authorization to edit WIP. Preserve memberships, assets and the exact previously approved exceptions; do not run a tag migration or broad cleanup.

## Acceptance contract and ownership

Delivery lane: **High-Risk for the runtime ownership handoff**, because city, dealership preview and owned-garage modules currently write the same environment properties. This is a narrow presentation change; no persistence, economy, inventory, vehicle physics, camera or race-authority change is proposed.

Goal: smooth, legible lighting throughout all 900 seconds, retaining stage IDs/order/durations, synchronized phase, manual selection, garage/preview looks and a tested way back to the captured stepped behaviour.

| Concern | Current owner | Proposed responsibility |
|---|---|---|
| Cycle state and metadata | LightingServer | Keep server authority over mode, schedule, epoch and stage metadata |
| City environment properties | LightingServer | In Continuous mode only, hand presentation to LightingClient; server stops writing those properties |
| Owned garage environment | OwnedGarageEnvironmentLightingClient | Keep interior-context decisions; request/release the original interior preset through the continuous renderer |
| Dealership preview environment | GaragePreviewPresentationClient | Keep preview-context decisions; request/release the original preview preset through the continuous renderer |
| Studio lighting preview | LightingPreviewClient, opt-in | Remain disabled by default; use the same renderer when explicitly enabled |
| Streetlights | NightLamppostLightClient | Keep tagged-light registration and application; consume resolved stage/transition settings |
| Window materials | WindowMaterialClient | Keep material application and streaming registration; switch discrete variants deliberately |
| Geometry / LOD / vehicle attachment | Existing world, LOD and VFX owners | Unchanged |
| Saved identities / data mutation | Existing profile/garage owners | Unchanged; this feature has no saved state or client mutation remote |

ClientBase remains startup only and starts the feature through normal composition. No additional startup script, competing property writer, per-frame remote or gameplay module require through MCP.

## Approved implementation

1. **Retain the existing presets and schedule as the exact stepped reference.** Add continuous-mode tuning keyed by the same stage IDs. Keep the original EightPM dealership preset and ClearNight interior preset untouched so outdoor retuning does not unexpectedly change those spaces. Use config attributes for mode and tuning; keep the ordered keyframe data in a focused module.

2. **Use each existing stage boundary as a visual keyframe.** SevenAM is reached at cycle second 0, TenAM at 90, Day at 180, and so on. Blend throughout the interval to the next keyframe; FourAM at 810 blends into SevenAM at 900/0. The 180-second intervals become a leisurely afternoon/night progression, rather than static holds. This preserves the exact spacing of all stage milestones. Extra twilight control points, if needed, sit inside those intervals and do not add stages or extend the cycle.

3. **Calibrate the sun path first.** Implemented clock anchors: 07:00, 10:00, 12:00, 15:00, 17:30, 20:00, 00:00 and 04:00. Live sun-direction measurements support a fixed outdoor latitude of 35, with sunrise at 06:00 and sunset at 18:00. Original latitude 189 is retained for Stepped mode and original interior/dealership presets. Brightness, exposure, haze and glare are retuned only through continuous outdoor overrides. Final artistic acceptance remains a visual playthrough, not a numerical claim.

4. **Separate clock movement from visual blending.** Evaluate an unwrapped forward timeline, e.g. 20 → 24 → 28 → 31, then wrap only the final ClockTime modulo 24. Use a monotone, bounded curve with continuous speed at joins for time, rather than easing the sun to a stop at every stage. Use bounded eased interpolation for visual properties; no spline overshoot into invalid density, negative intensity or excessive exposure. Calculate the target directly from absolute cycle time so late joins and frame drops do not accumulate drift.

5. **Tune linked visual groups together.** Interpolate Ambient/OutdoorAmbient/ColorShift, Brightness/Exposure, environment diffuse/specular, Atmosphere Color/Decay/Density/Offset/Haze/Glare, bloom and color correction. Treat exposure as stops and tune its interaction with brightness instead of applying an additional arbitrary multiplier. Use direct bounded color interpolation as the baseline and add authored twilight control points if midpoints become grey, muddy or overbright. Reduce daytime glare before the sun gets high; introduce evening haze and cool night tones in a controlled order. Keep a readability floor established through road/vehicle checks. Keep constant settings constant: no cycling of shadows, tonemapper, rendering style or disabled depth of field/sun rays. Preserve legacy fog values unless a deliberate visual need emerges.

6. **Keep one active sky.** Reuse the existing textures. Recommend one fixed sky orientation in Continuous mode, selected during preview, because interpolating 0↔90 degrees would visibly rotate the clouds back and forth. Keep the sun/moon size consistent where the normal horizon already hides them; verify this after solar calibration. Avoid shrinking the sun to zero while it is still visible. Preserve original sky templates for Stepped mode and interior/preview looks.

7. **Make environment ownership explicit.** Add a small shared renderer for continuous-mode application. Existing interior and preview controllers supply context intent instead of directly setting Lighting while Continuous is active. Explicit precedence: enabled Studio preview, active dealership preview, owned interior, then city. Verify overlaps using the existing normal UI flow. On context exit, immediately evaluate the current city phase rather than restoring a stale preset or the entry snapshot. Any short handoff blend must have a generation/cancellation guard so a delayed exit cannot overwrite a newly entered context. Resolve the current context before the first rendered frame after startup. Failed optional presentation must not block driving/profile startup.

8. **Use synchronized client rendering.** LightingServer publishes mode/epoch/config revision and retains compatibility stage metadata at boundaries. The client evaluates fractional server time using GetServerTimeNow; synchronized mode retains the existing Unix epoch alignment. Unsynchronized mode uses a server-published session epoch so clients in that server still agree. No frame-by-frame network traffic. Validate configuration on change, bound updates to existing effects/sky, and avoid unchanged writes. Manual mode freezes the selected continuous keyframe; resumed auto mode immediately rejoins the synchronized phase. Manual/debug jumps and portal context entry/exit are deliberate immediate selections; the automatic city timeline is the continuous path.

9. **Switch lamps and windows at sunrise/sunset.** Per the user's refinement, both switch discretely at ClockTime 06:00 and 18:00 in Continuous mode. Lamp brightness remains 2; existing window material IDs remain unchanged. LightingServer resolves those signals from the same clock curve as the renderer. NightLamppostLightClient and WindowMaterialClient retain event-driven registration/application and apply the current state to streamed-in objects. StageVisuals remains the untouched authority in Stepped mode. No texture blends, lamp fade loop, tag edits or global per-frame scans.

Design cost: one constant-size environment evaluation capped at 30 Hz, one active sky and the existing effect set. Per-player work does not scan other players or vehicles. Streetlight/window work happens on switch or registration. Runtime tests observed one stable sky and seven Lighting children; these counts do not establish phone performance or bounded detached references/connections. Check low graphics readability and representative mobile performance before acceptance.

Visual refinement from live testing: residual atmosphere glare produced a washed-out skyline after sunset even though all values interpolated smoothly. The evaluator now fades glare with a bounded horizon-height mask, reaching zero before the sun is below the horizon. Paused dusk and late-morning reference images are retained with the evidence. This avoids changing original presets or introducing extra stages.

## Easy reversion and delivery

- Add `CycleMode = "Stepped" | "Continuous"` to the existing lighting config. APPLY defaults to Stepped; the separate CONTINUOUS action activates the approved implementation. The switch is evaluated at clean startup: changing it and restarting Play gives a simple, predictable rollback. No live mode-switch complexity is needed for an A/B test.
- Stepped mode follows the original server and context paths with original presets, sky behaviour, schedule and StageVisuals values. Continuous mode activates the renderer and disables conflicting writes. Both modes share the canonical modules; there is no duplicate startup tree, in-game backup folder or independently running old controller.
- Keep original latitude/settings in the captured reference. The renderer must restore the legacy baseline when applying legacy interior/preview contexts; returning outdoors reapplies the continuous baseline. Test this explicitly if continuous latitude differs.
- Build one guarded canonical installer for the approved scope, including new modules/startup registration/config, audit and explicit recovery. Existing source-only delivery cannot handle these additions by itself. Refuse unexpected source/config drift, compile projected sources first and restore the affected state on install failure. Do not rerun historical lighting or architecture migrations.
- Before implementation, refresh the capture and include every actual property/config/object to be mutated. If lamps/materials will be edited in Edit, capture those exact in-scope objects/properties separately; the current tag inventory is not their property backup. No WIP, staging, Archive or physical asset migration.
- A full code rollback restores the captured affected sources/config/Lighting properties and removes only verified newly installed artifacts. Keep this recovery in the same installer and repository. Test both config reversion and full recovery; a promised toggle is not yet a verified rollback.

## Acceptance checks for implementation

1. Static/numerical: all eight boundaries remain at 0/90/180/360/450/540/630/810, wrap at 900; sample every second plus either side of every boundary. Require finite/in-range complete targets, forward unwrapped time, no endpoint jumps and no source drift outside scope. Check manual, synchronized and server-local modes, startup at arbitrary phase and invalid config.
2. Visual: inspect the entire accelerated cycle and a normal-speed cycle, then pause each transition at 0/25/50/75/100 percent and inspect sunrise/sunset more densely. Use consistent road, skyline, shaded road/tunnel and vehicle-paint viewpoints. Evaluate shadow direction, glare, fog visibility, neon bloom, saturation and road readability on high and low graphics. Numerical smoothness alone does not pass this check.
3. Context/lifecycle: enter/exit dealership and owned garage halfway through fades and across boundaries; test overlapping context changes, respawn, late join and streamed lights/windows. Confirm no flashes, stale city restore, duplicate sky/effects, extra loops or retained registrations after repetition. Keep Studio preview opt-in.
4. Synchronization/performance: compare two normally started clients, including late join; profile environment writes and light transition cost with representative content and mobile quality. No claim of 15-player or real-device verification until observed.
5. Recovery: return CycleMode to Stepped, restart and compare the original eight targets, timers, sky settings, garage behaviours and lamp/window modes to the capture. Exercise guarded full recovery without overwriting unrelated edits.

This checklist is the acceptance target, not a statement that every item passed. See the dated [handoff](continuous-lighting-handoff.md) and [validation record](continuous-lighting-validation.json) for observed results, evidence boundaries and remaining checks. This is one connected lighting delivery; historical phases are not a new run queue.

## Engine references

- [Lighting reference](https://create.roblox.com/docs/reference/engine/classes/Lighting): clock, latitude, exposure and fog semantics.
- [Atmospheric effects](https://create.roblox.com/docs/environment/atmosphere): Density/Offset interaction and Color/Decay/Haze/Glare.
- [Sky reference](https://create.roblox.com/docs/reference/engine/classes/Sky): image properties, orientation and celestial settings.
- [Workspace.GetServerTimeNow](https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow): smoothed client approximation of server Unix time; presentation synchronization only, not a rewards clock.
