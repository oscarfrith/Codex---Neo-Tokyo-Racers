# Sunset exposure, direction and sun presentation — investigation

2026-09-23. Requested exploration and recommendation, **not an installed revision**. The user found the current cycle better but reported pre-sunset overexposure, red sky opposite the sun, an oversized grainy sun and interest in sun rays. [Current status](../00_START_HERE.md). This document proposes a focused refinement of the existing renderer and configuration.

## Evidence

Rediscovered Space Racers v1, place 121304917315753, in Edit. Three live evaluator/config-reader/renderer sources match the repository. Current Continuous config and all six editable palettes were inspected. Temporary comparisons used the existing no-save Play session, normal Play UI, existing configuration publication and existing renderer. No gameplay module was required through MCP, no additional writer or source installation was introduced. Each experiment reset the Play palette before changing its selected fields. Stop discarded the probes; a final comparison confirmed inspected Edit source/config/palette/sky equality. [Before](../../scripts/continuous_lighting/evidence/research-20260923/before.json), [restoration](../../scripts/continuous_lighting/evidence/research-20260923/recovery.json).

At 17:00, the installed blend produces Brightness **2.258**, Exposure **−0.221**, Haze **3.148**, Glare **4.023**, Bloom intensity **0.592**, threshold **1.202**. Day starts at Brightness 5.15 with zero haze/glare; FivePM ends at 0.19 with haze 5.4/glare 6.9. Each field is numerically between valid endpoints, but the combination is not a visually safe intermediate state. [Measured target](../../scripts/continuous_lighting/evidence/research-20260923/baseline-17.json).

The screenshot comparisons isolate several effects:

| Probe | Observed result | Implication |
|---|---|---|
| Original 17:00 blend | Sun-facing sky becomes nearly white | Reproduced reported problem |
| Brightness fixed at 0.2 | Reduces white clipping but creates dull grey sky/darker buildings | Whole-scene dimming alone is a poor solution |
| Glare fixed at zero | Removes white sky but substantially changes fog/sky appearance | Do not remove this styling tool everywhere |
| Haze fixed at 0.75 | Restores blue sky detail; loses much of sunset atmosphere | Haze timing/strength is a principal control |
| Bloom disabled | White sky remains | Bloom is not the primary cause |
| Lighting fades earlier; atmosphere later | Removes the sampled 17:00 white sky while preserving original endpoints mathematically | Recommended mechanism; full-path tuning still needed |
| Warm preset Color/Decay swapped at 17.6 | Red opposite sky becomes blue/purple; sun-facing view still pale | Confirms colour-pair involvement; simple swapping is insufficient |
| Combined curves and moderated warm target | Sampled 17:00 is controlled, but 17.6/18 become too brown/dark | Reject these exact probe colours as final art; retain the approach |
| Sun size 21 → 4, same native texture | Much smaller, cleaner-looking disc; coarse halo far less apparent | Strong first fix for size and edge appearance |
| Large sun, bloom off and glare zero | Grainy rim remains | Bloom/glare alone do not explain the rim |
| Native sun rays 0 / 0.02 / 0.035 / 0.08, spread 0.8 | Small strengths add subtle warm radiance; 0.08 produces a much broader wash | Keep restrained and phase-controlled |

These are paused desktop comparisons, not final polished settings, a measured luminance benchmark, an uninterrupted cycle acceptance test or mobile performance evidence. Camera viewpoints were fixed per comparison, but moving holograms/streamed detail are not identical. Sun-texture pixel dimensions were not verified; enlarged sprite/filtering is a plausible contributor, not a proven sole cause. The live source still uses `rbxasset://sky/sun.jpg` at size 21.

Selected images: [white sky](../../scripts/continuous_lighting/evidence/research-20260923/base17.jpg), [separate curves](../../scripts/continuous_lighting/evidence/research-20260923/early_light_late_haze.jpg), [original opposite sky](../../scripts/continuous_lighting/evidence/research-20260923/horizon_original_opposite.jpg), [colour-pair probe](../../scripts/continuous_lighting/evidence/research-20260923/horizon_swap_opposite.jpg), [large sun without bloom](../../scripts/continuous_lighting/evidence/research-20260923/sun_large_no_bloom.jpg), [small sun without bloom](../../scripts/continuous_lighting/evidence/research-20260923/sun_small_no_bloom.jpg), [low rays](../../scripts/continuous_lighting/evidence/research-20260923/rays_occlusion_0.02.jpg), [high rays](../../scripts/continuous_lighting/evidence/research-20260923/rays_occlusion_0.08.jpg).

## Why the red sky is on the other side

The warm presets have Atmosphere.Color around RGB **112,91,83**, but a much brighter peach Decay around **221,180,164**. Roblox documents Decay as the atmosphere hue away from the sun; haze/glare reveal its influence. This explains the observed directional imbalance, supported by the colour-pair probe. The new sky's four side textures are identical, and rotating a Sky affects its images, not the celestial sun. Rotate neither the solar path nor the sky as the primary correction. [Atmosphere documentation](https://create.roblox.com/docs/environment/atmosphere), [sky orientation/celestial controls](https://create.roblox.com/docs/environment/skybox).

Author a warm sunward Color and a quieter, cooler opposite Decay **together** with haze/glare. Keep a subtle opposite-side twilight tint if attractive, but make the dominant warm horizon agree with the sun. Preserve the purple FourAM/EightPM identity. Literal swapping eliminated the red background but did not achieve the desired sun-facing colour, so a balanced pair is necessary.

## Options and recommended choice

| Approach | Benefit | Cost / decision |
|---|---|---|
| Reduce overall exposure | Small change | Dims road, vehicles and neon as well; use only for small final compensation |
| Permanently lower all fog/glare | Simple | Loses authored atmosphere; reject as the general fix |
| Separate property fade curves | Avoids bright daylight coexisting with strong late-sunset scattering | Best foundation; independently tune a few groups |
| Geometric/log brightness blending | Drops large brightness ratios more naturally than an arithmetic average | Worth comparing within the light group; cannot by itself solve haze/colour and needs defined zero handling |
| Extra authored transition control points | Direct art control over troublesome shoulder periods | Useful if grouped curves cannot maintain warmth; add only a small number, not eight new stage presets |
| Targeted continuous-palette retuning plus curves | Corrects intermediate exposure and full-target directional colour | **Recommended combination**; keep original shared presets untouched |
| Camera-facing automatic exposure | Could react to bright areas | Can cause visible pumping when turning toward neon/buildings; unnecessary new feedback behaviour |
| Custom sky dome, fake sun or volumetric beams | Maximum art control | More assets, occlusion/streaming/device work and ownership complexity; unnecessary first-line change |

The log-blend, automatic-exposure and custom-sky/beam alternatives are architectural assessments, not implemented or visually compared prototypes. The table above separates them from the actual Play probes.

## Proposed implementation

Retain the uniform solar clock, existing milestone timings/holds, 120-second test duration, cloudless background and 06:00/18:00 lamp/window switches. Keep LightingServer state ownership and LightingClient's single writer. Reuse the same canonical installer if this recommendation is approved.

1. **Give property groups independent progress curves.** Use deterministic eased remaps of the same current transition phase, never separate running TweenService jobs. For sunset, lower direct brightness/exposure first, develop colour progressively, and bring strong haze/glare later after daylight energy has reduced. Keep density/offset separately controllable from glare; these affect distance readability. Mirror the physical sequence on sunrise: dissipate strong scattering before increasing daytime illumination. Curve endpoints must remain exact, continuous and bounded, with no clock changes or jumps at holds/wrap.
2. **Retune only problematic continuous fields.** Adjust SevenAM/FivePM Color/Decay, Haze/Glare and modest exposure support together, keeping their warm identity and road visibility. Start glare around 1–2 rather than 6.9 and haze around 2–3.5 rather than 5.4 as a search range, not an accepted preset. Do not copy the dark/brown hybrid probe wholesale. Keep Day/Night and purple twilight as references; touch adjacent fields only where the complete transition demonstrates a need. Compare rays off while settling this base.
3. **Use a 4° sun initially.** That worked substantially better in the comparison; tune within roughly 3–5° for this stylised city. Keep size fixed initially. If the small native disc still has objectionable edges on devices, use a verified clean soft-edge sun image via the existing Sky sun-texture property, retaining native alignment/occlusion. A custom image is a contingency, not a promised cure for renderer aliasing. [Native sun controls](https://create.roblox.com/docs/environment/skybox).
4. **Add restrained native rays after exposure is stable.** Start near intensity 0.02, test peaks up to about 0.035 and spread around 0.8. Fade intensity by solar elevation: mild during daylight, slightly stronger near low sun, smoothly zero below the horizon. Enable the effect consistently for Continuous looks and animate Intensity through zero; do not toggle Enabled between keyframes. Existing indoor contexts must retain their original effect state. Roblox's native rays respond to occluding objects, but are a screen effect rather than authored world-space volumetric shafts. Graphics quality can affect post-processing visibility, so the scene must remain attractive without them. [Post-processing reference](https://create.roblox.com/docs/environment/post-processing-effects).

Expose simple per-transition controls in the existing configuration: `LightFadeStart/End`, `ColourFadeStart/End`, `HazeFadeStart/End`, `GlareFadeStart/End` as normalized fractions of the blend interval, plus ray strength/spread. Use documented group membership and explicit per-property exceptions only where necessary. Keep artists editing values and timing in one place; avoid hidden multipliers. Validate ordered finite curve limits and retain the existing last-good-config behaviour. Sun size remains on the existing sky template unless the approved implementation deliberately exposes it alongside the other controls.

## Verification and recovery for an approved refinement

First use fixed road/vehicle and elevated skyline cameras facing toward, across and away from the sun. Compare 16:00–19:30 and the mirrored dawn at close intervals, especially the mid-blend region and exact horizons. Check no white-sky pulse, abrupt dark interval, reversed dominant colour, halo ring or night-ray glow. Then run the full two-minute cycle, representative 900-second transitions, low graphics and a physical target device. Include native rays both occluded and unobstructed; the current probes do not certify partial-occlusion quality.

Protect original LightingPresets, LightingSchedule, sky templates, identities, geometry and existing owners. Preserve the exact installed V2 palette and sources in the repository capture so refinement can be restored without reinterpreting older handoffs. The existing Stepped switch continues to restore the original system. No migrations, publishing or source installation were performed during this investigation.
