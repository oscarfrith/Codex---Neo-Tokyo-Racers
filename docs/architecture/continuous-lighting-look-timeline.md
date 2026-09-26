# Solar motion and authored lighting looks — approved design

Design response to the user's 2026-09-23 playthrough, subsequently approved for implementation with editable tuning. Current status and next action are in [start here](../00_START_HERE.md); implementation evidence is in the [revision handoff](lighting-look-timeline-handoff.md) and editing instructions in the [authoring guide](lighting-authoring.md). This supersedes the first design's continuous art tuning and eight-stage outdoor look sequence; original Stepped recovery and context ownership remain required. Recommendations below record design intent, not proof of visual acceptance.

## Why the first version lost the intended looks

Read-only MCP inspection rediscovered Space Racers v1 and confirmed that LightingPresets, LightingSchedule, LightingCycleDefinition and LightingCycle match the delivered source hashes. The original presets remain intact. [Observed source/config/sky evidence](../../scripts/continuous_lighting/evidence/revision-analysis-20260923.json).

The first continuous version deliberately overrode important authored values:

| Preset | Original | Continuous override |
|---|---|---|
| SevenAM | Brightness 0.22, exposure -0.45, haze 5.4, glare 6.9 | 1.6, -0.10, 2.2, 1.2 |
| FivePM | Brightness 0.19, exposure -0.45, haze 5.4, glare 6.9 | 1.5, -0.15, 2.5, 1.2 |
| EightPM / FourAM | Brightness 2.4, exposure 0.11, haze 4.09, glare 6.86 | 1.2, 0, 3.1, 0 |

It also multiplies glare down to zero at the horizon. That suppresses an important part of the original atmosphere precisely when the user wants the sunrise/sunset look. Ambient and color-correction data were retained, but reduced scattering and different illumination change their visible result. Roblox documents that atmosphere Color, Haze, Glare and Decay work together; Decay's visible effect depends on nonzero haze and glare. [Atmosphere reference](https://create.roblox.com/docs/environment/atmosphere).

The old names are preset identities, not astronomical clock values. SevenAM must mean Sunrise, FivePM Sunset, FourAM Dawn Twilight and EightPM Dusk Twilight. The first design also blended almost continuously between looks, with no meaningful daytime hold, and its 07:00/17:30 warm targets did not coincide with the calibrated 06:00/18:00 horizon crossings.

## Recommended design

Retain one renderer and separate its input into two tracks:

1. **Solar motion:** synchronized, continuous forward ClockTime, with a fixed calibrated latitude. For predictable two-minute tests, use a uniform 24-hour sweep over 120 seconds (one game hour = five real seconds). Lighting blends do not ease, pause or reset this clock. The existing smooth-motion approach remains; the old weighted stage durations no longer dictate the solar speed or the look sequence.
2. **Authored look:** choose two complete lighting presets and their blend weight from the solar phase. Ignore the preset's stored ClockTime. Resolve full original values at each named visual milestone. Day stays the Day preset through the middle of the day while only the sun/shadows move. TenAM and ThreePM are omitted from this new outdoor look timeline, while their original data and Stepped use remain intact.

The tracks are independently tunable but synchronized to the same phase; two independent timers would drift. Horizon alignment takes priority over the old labels. At the currently calibrated outdoor latitude 35, prior sun-direction measurements place sunrise at 06:00 and sunset at 18:00. Check these against GetSunDirection during implementation. If the solar path is retuned, move the look anchors with its actual horizon crossings. Do not vary latitude during an artistic color blend.

Suggested initial milestones (clock values illustrate the calibrated path; labels identify the original preset):

| Solar milestone | Full lighting look | Elapsed in a 120-second test starting at midnight |
|---|---|---:|
| 21:00 through 03:00 | ClearNight held | 105–120 and 0–15 seconds |
| 04:30, before sunrise | FourAM / dawn twilight | 22.5 seconds |
| 06:00, rising horizon | SevenAM / sunrise | 30 seconds |
| 08:00 through 16:00 | Day held | 40–80 seconds |
| 18:00, setting horizon | FivePM / sunset | 90 seconds |
| 19:30, after sunset | EightPM / dusk twilight | 97.5 seconds |
| 21:00 | ClearNight reached | 105 seconds |

Blend night → dawn twilight from 03:00–04:30, twilight → sunrise from 04:30–06:00, sunrise → day from 06:00–08:00; reverse the progression after 16:00 using the separate sunset/dusk presets. These are deliberately extended, stylized twilight windows, not a claim about real-world twilight duration at that latitude. Use the same durations on each side initially; the different morning/evening authored values are preserved.

Add a small configurable full-look hold around sunrise, sunset and twilight anchors so each authored look is recognizable while the sun continues moving. A starting hold of two real seconds in the accelerated test spans 24 in-game minutes, centered on the milestone; trim adjacent blend intervals to fit it. At the exact horizon the warm preset must be 100%, never halfway toward another look. Day/night holds need no extra intermediate presets.

## Preserve the complete appearance

Start from the original LightingPresets values, removing the first version's outdoor brightness/exposure/haze/glare overrides and its automatic horizon glare suppression. Normalize missing fields once so entry order cannot leak prior settings. Use one bounded eased weight across the complete preset pair, preserving exact endpoints. Avoid independent sequential tweens that drift or keep running after context changes.

Coverage includes Ambient, OutdoorAmbient, ColorShift_Top/Bottom, Brightness, ExposureCompensation, environment diffuse/specular, shadow softness, fog color/start/end, every Atmosphere property, bloom and color-correction properties, and authored depth-of-field/sun-ray settings. Equal properties stay equal. Existing disabled effects stay disabled; any future enable change needs an explicit neutral-intensity transition rather than a boolean flash. ColorGrading/rendering style/global shadow mode stay at their existing common baseline. No arbitrary extra brightness multiplier, saturation override or generic glare cutoff.

ClockTime/TimeOfDay and fixed GeographicLatitude belong to solar motion. The requested common cloudless sky is a separate explicit art choice. These are the deliberate exceptions to copying a legacy preset wholesale. Original streetlights and window owners continue their discrete horizon switches; world neon, point lights, vehicle lamps, materials and geometry are outside this environment-preset change.

Matching property values does not guarantee identical pixels: a correctly positioned sun and a different sky background change scattering, reflections and illumination. First preview unmodified full presets at the intended solar positions. If a target is too bright or obscures the road, compare it against the original reference and tune that specific issue while retaining the authored warm/purple color, haze and density. Do not silently flatten all twilight effects to fix one washout. The legacy fog values are identical across these presets; the visible authored variation principally comes from Atmosphere.

## Cloudless sky

Recommend **one seamless, neutral cloudless Sky**, retaining the sun, moon and stars. Use a low-detail neutral background with no painted clouds, sun, sunset or fixed purple/orange glow, so atmosphere and color correction supply those colors. Keep orientation fixed. This intentionally replaces the old background artwork for Continuous mode only; preserve every original sky template for Stepped and interior/dealership contexts.

Live inspection found no Clouds object under Terrain. The current sky templates all share the same six image assets, so merely skipping their stage swaps does not remove background artwork. Sky images and celestial bodies are distinct controls; Roblox exposes the latter on Sky and positions them from ClockTime. [Sky reference](https://create.roblox.com/docs/environment/skybox). A verified cloudless texture set must be selected and visually compared before activation; no asset ID or cloudless result is assumed from blank texture fields. Retaining a controlled Sky is preferable to relying on the engine's unspecified/default background after deleting it.

Changing the sky can affect vehicle reflections and perceived fog contrast. Include glossy vehicle paint, skyline and distant road views in the comparison. Keep celestial size consistent with the chosen solar presentation; do not restore the legacy sun-size-zero night toggle while the sun is visible.

## Delivery and acceptance contract

Retain the existing High-Risk safeguards for the connected runtime handoff, without adding an owner. LightingServer owns shared phase/config and discrete lamp/window signals; LightingCycle calculates solar phase and complete look targets; LightingClient is the sole environment writer. Existing dealership, owned interior and opted-in preview modules retain context decisions. ClientBase remains startup only. Geometry/LOD/VFX, camera, saved identities, remotes, persistence and protected assets are unchanged.

Use a dedicated `ContinuousCycleDurationSeconds=120` setting for the test cycle. Keep legacy BaseDurationSeconds=90 and LightingSchedule unchanged so Stepped remains the original 15-minute system. A later duration of 900 scales this same new look timeline without changing its solar relationships. Full-look holds are authored in game hours and scale with duration, not fixed real-time waits. Distinguish artist-facing names from the preserved preset IDs and compatibility metadata; do not delete or rename saved/shared identities.

Revise the existing canonical installer from a fresh guarded baseline; no historical migration replay or additional patch installer. Test original Stepped reversion and full repository-backed recovery. Preserve original context priority and immediate restoration of the current city phase on exit. Preview/scrubbing uses the existing opt-in tool and renderer, disabled afterward. The initial implementation should include one bounded source audit for other ClockTime consumers before changing cycle duration.

Done-when checks for this revision:

- Exact original non-solar property values at Day, Night, sunrise, sunset and both twilight anchors; TenAM/ThreePM never enter the new outdoor look selection. Complete settings on every context/entry order.
- Smooth forward clock independent of look easing/holds; exactly 120 seconds per test loop; no wrap or blend jumps, no numerical overshoot and correct lamp/window horizon switches.
- Paused reference comparison at every full preset, then intermediate quarter points, using road, skyline and vehicle views. Warm sunrise/sunset and purple dawn/dusk must remain clearly identifiable. Start with these visual comparisons before another long numerical test run.
- Visible uninterrupted two-minute run, both horizon crossings and midnight, then normal-speed and low-graphics review. Numeric continuity does not certify visual quality.
- Normal dealership and owned-garage release, respawn, streamed light/window registration and two-client/late-join phase agreement, with remaining physical-device checks honestly recorded.
- Clean mode reversion and guarded rollback; no unrelated source/config/asset changes, no publish.

This design adopts the user's revised presentation goals and two-minute test target. It does not claim the first lighting delivery's artistic result was accepted. The dated revision handoff separates installed behaviour, agent checks and remaining visual acceptance.
