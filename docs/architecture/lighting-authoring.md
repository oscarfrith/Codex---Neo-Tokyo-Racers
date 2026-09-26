# Editing the day/night cycle

Use Studio's Explorer and Properties panels. Most tuning needs no code. Select `ReplicatedStorage > Config > World > Lighting`; its Attributes hold the cycle controls. [Current installed status](../00_START_HERE.md).

## Speed and preview

| Attribute | Meaning |
|---|---|
| `ContinuousCycleDurationSeconds` | Full day length. `720` is the twelve-minute cycle; `120` is the two-minute test; `900` gives fifteen minutes. Valid range 24–86,400 seconds. |
| `AutoCycleEnabled` | `true` runs the cycle. `false` pauses at `ContinuousManualClockTime`. |
| `ContinuousManualClockTime` | Preview a game hour from 0 up to, but excluding, 24. Try 3.5 dawn, 6 sunrise, 12 day, 18 sunset, 20.5 dusk, or 0 night. |
| `SynchronizeAcrossServers` | Use the shared clock. Turning auto back on rejoins its current phase immediately. |
| `ContinuousSkyName` | Sky template name under `ReplicatedStorage > Assets > World > Skies`. Default `ContinuousSky`. |
| `ContinuousRayFadeHours` | Sun-ray fade distance outside each horizon. Default `0.4` game hours (12 real seconds at 720 seconds/cycle); rays stay full at sunrise/sunset and fade through adjacent twilight. |
| `CycleMode` | `Continuous` or the original `Stepped` system. Change in Edit and restart Play. |

The sun moves evenly throughout the cycle, including while a lighting look is held. `BaseDurationSeconds` and `ManualStage` belong to the original Stepped system; leave them unchanged when tuning Continuous.

Make permanent changes in **Edit**. To experiment live, start Play, select the **Server** view, then edit these configuration attributes. They reach the client automatically, but Stop discards Play-only edits. Record desired values and apply them in Edit afterward. Editing the client copy is not authoritative.

## When a look appears

Inside the Lighting config, expand `ContinuousLooks`. Each child is one milestone. Select it and edit:

- `Preset`: one of `Day`, `ClearNight`, `SevenAM`, `FivePM`, `FourAM`, `EightPM`.
- `Anchor`: `Sunrise`, `Sunset` or `Midnight`.
- `OffsetHours`: game hours before (negative) or after (positive) that anchor.
- `HoldHours`: the complete duration of the full-look hold, centered on the milestone. Sunrise/Sunset use `0.16666666666666666` game hours (1/6), or five real seconds at 720 seconds/cycle. Twilight uses `0.4`, or 12 real seconds (two at test speed).

The folder names are descriptive labels. The preset identities retain their original names; **SevenAM means sunrise and FivePM means sunset**, regardless of the actual clock hour. TenAM and ThreePM remain available only in the original system unless deliberately added to the editable palette and timeline.

| Milestone | Default full look | Clock position |
|---|---|---:|
| NightEnd | ClearNight | 02:00 |
| Dawn | FourAM | 03:30 |
| Sunrise | SevenAM | 06:00 |
| DayStart | Day | 09:30 |
| DayEnd | Day | 14:30 |
| Sunset | FivePM | 18:00 |
| Dusk | EightPM | 20:30 |
| NightStart | ClearNight | 22:00 |

Day holds between DayStart and DayEnd. Night holds from NightStart through midnight to NightEnd. The full warm sunrise spans **05:55-06:05**, sunset **17:55-18:05**: 2.5 real seconds before and after each horizon at the twelve-minute speed. Broader build-up and release remain. Sunrise fades to daylight until 09:30; sunset's approach begins at 14:30. Twilight anchors remain 03:30/20:30. At 720 seconds, one game hour lasts 30 real seconds and the 1/6-hour hold lasts five seconds. Use `HoldHours = desired real seconds * 24 / cycle duration seconds` when changing cycle speed. At 120 seconds, one game hour lasts five seconds; at 900 seconds it lasts 37.5. Example: move DayEnd's `OffsetHours` from `-3.5` to `-4` to start its fade half an hour earlier.

Keep holds separated and retain day/night boundary pairs. Duplicate times, overlapping holds, unknown presets and invalid types are rejected. During Play, a bad edit leaves the last valid configuration active and reports `LightingCycleError` on Lighting / a warning in Output. Correct the setting to resume live tuning. Invalid settings saved in Edit must be repaired before the next startup can succeed.

`SunriseClockTime=6`, `SunsetClockTime=18` and `ContinuousGeographicLatitude=35` are calibrated together. Changing a named sunrise time does not independently move the engine's sun. If the solar path changes, check its actual horizon crossings and move these anchors together. Lamps and windows switch at those sunrise/sunset times.

## What each look looks like

Expand `ContinuousPresets`, choose a look, then one of its sections. Edit Attributes using the normal number fields and colour pickers:

| Section | Controls |
|---|---|
| Lighting | Brightness, exposure, ambient colours, colour shifts, reflection contribution, fog and shadows |
| Atmosphere | Density, offset, haze, glare, colour and decay |
| ColorCorrection | Brightness, contrast, saturation and tint |
| Bloom | Intensity, threshold and size |
| DepthOfField / SunRays | Existing effect settings |

These are independent copies of the original complete looks. Their initial values preserve the original authoring. **Do not edit `LightingPresets` to tune the new cycle**: that shared source remains the reference for Stepped recovery and garage/dealership lighting. ClockTime and latitude intentionally do not appear inside the editable looks.

Use property values within Roblox's supported ranges. Keep Enabled/GlobalShadows flags identical across looks: instant boolean changes would flash, so incompatible flags are rejected. Enabling an effect for only part of the cycle needs a neutral-intensity transition designed into the renderer. A value deleted from a copied section inherits its original preset/default; keep the complete attributes for predictable editing.

Pause at a full look first, then inspect the transition on both sides. Haze, glare, atmosphere colours and exposure interact with the sun position. Exact old values at a new solar angle do not produce identical pixels. Compare road readability, skyline and vehicle reflections; do not flatten all six looks together.

The red/pink refinement changes the Continuous SevenAM/FivePM copies: Atmosphere Color RGB **255,145,100**, Decay **180,125,140**, Haze **2.2**, Glare **1**; Lighting Ambient **255,180,160**, OutdoorAmbient **240,155,140**, ColorShift_Top **255,145,100**; ColorCorrection TintColor **255,235,230**. Lighting Brightness stays **0.65**; ExposureCompensation is **0.15**, ColorCorrection Brightness **0.055** and Contrast **0.12**. This lifts the warm sky while preserving the low direct-light endpoint. Continuous FourAM/EightPM use Atmosphere Color **145,100,155** and Decay **165,130,185** for violet twilight, with Glare **1.5** instead of the original 6.86. ClearNight Glare is **0.45**, reducing the moon wash while preserving its original fog, bloom, colours and moon size. Other artwork remains unchanged; the explicit SunRays tuning below is separate.

Evening blends red-orange through rose-pink into violet; morning reverses that path. The full warm look holds five seconds at the twelve-minute speed, while its colours also blend through the shoulders. Sunset's outgoing `ColourFadeStart=0.2`, `ColourFadeEnd=1` retain warmth while the other properties begin changing; Dawn mirrors this with `ColourFadeStart=0`, `ColourFadeEnd=0.8`. Original shared artwork is untouched. The user-approved orange V4 palette remains in `roblox/captures/lighting-red-pink-before/capture.json`; earlier exact-value copies remain in their historical captures.

## Different fade speeds

Each milestone folder now has six pairs of Attributes named `LightFadeStart/End`, `ColourFadeStart/End`, `HazeFadeStart/End`, `GlareFadeStart/End`, `DistanceFadeStart/End` and `PostFadeStart/End`. They control the transition **from this milestone to the next**, after the current hold and before the next hold. Fractions are 0–1: start 0/end 0.7 finishes a group's fade in the first 70% of that interval; start 0.3/end 1 delays it until 30% through. Smooth easing applies within the interval. Require `0 <= start < end <= 1`; invalid edits retain the last good runtime configuration.

| Group | Properties |
|---|---|
| Light | Numeric Lighting properties: brightness, exposure, environment scales, fog distances and shadow softness |
| Colour | Every Color3: Lighting ambient/fog/colour shifts, Atmosphere Color/Decay and ColorCorrection TintColor |
| Haze / Glare | The individual Atmosphere property |
| Distance | Atmosphere Density and Offset |
| Post | Numeric Bloom, ColorCorrection, DepthOfField and SunRays properties |

All groups default to 0–1. The authored exceptions are:

| Outgoing milestone | Light | Colour | Haze | Glare | Distance | Post |
|---|---|---|---|---|---|---|
| DayEnd → Sunset | 0–0.7 | 0–0.85 | 0.3–1 | 0.4–1 | 0–1 | 0–0.8 |
| Sunrise → DayStart | 0.3–1 | 0.15–1 | 0–0.7 | 0–0.6 | 0–1 | 0.2–1 |
| Sunset → Dusk | 0–1 | 0.2–1 | 0–1 | 0–1 | 0–1 | 0–1 |
| Dawn → Sunrise | 0–1 | 0–0.8 | 0–1 | 0–1 | 0–1 | 0–1 |

This lowers daytime illumination before building strong evening scattering and reverses that sequence in the morning. It uses one shared phase, so scrubbing, late joins and duration changes cannot leave separate tweens running out of sync. Exact authored endpoints remain reachable; the only solar-dependent appearance multiplier is the ray gate described next.

The single existing renderer updates before every rendered frame. It no longer drops timer remainder or skips two/three frames between updates. This improves transition cadence without adding smoothing lag or a second lighting writer. At low frame rates, values still advance to the correct shared phase; this cannot hide a device frame stall. Lamp/window switches and existing indoor context entry remain deliberate discrete events.

## Sun and rays

ContinuousSky's `SunAngularSize` is **9**, 1.5 times the previous 6, constant throughout Continuous mode. Edit that Sky property and restart Play; the sun keeps its native texture and follows ClockTime. Original shared sky templates are unchanged.

In every Continuous preset, SunRays `Enabled=true` and `Spread=0.9`. Intensity is **0.07** in Day, **0.2** in SevenAM/FivePM, and **0** in twilight/night. Warm peak intensity is eight times the previous 0.025; Day is 8.75 times the previous 0.008. These are property ratios, not measured perceived-brightness ratios.

The outdoor ray envelope stays at full strength from 06:00 through 18:00, including both exact horizons. It ramps up over **05:36-06:00** and fades out over **18:00-18:24**, reaching zero beyond those windows. Each fade lasts 12 real seconds at the twelve-minute speed. This preserves dramatic horizon rays while preventing them lingering into deep night. The wrapped solar-phase calculation also supports valid horizons near midnight; ContinuousRayFadeHours must fit half the night interval. The native effect still depends on the sun's screen position, occlusion and graphics quality.

Edit **ContinuousPresets > look > SunRays** to tune the running cycle. Direct edits to Lighting > SunRays are overwritten by the cycle's sole renderer during Play. Setting every preset Intensity to zero disables rays smoothly; keep Enabled consistent across all looks. Interior/dealership contexts retain their original disabled effect. This envelope uses calibrated 06:00/18:00 anchors, not a separate astronomical solver; recalibrate if changing latitude/solar geometry.

## Sky and context

`ReplicatedStorage > Assets > World > Skies > ContinuousSky` is the common cloudless background. It keeps a sun, moon and stars. Change its properties in Edit and restart Play to refresh the cached renderer. Original sky templates are preserved. Garage/dealership contexts retain their original looks and skies; leaving them restores the current outdoor phase.

Coloured skies are supported through the smoothly blended Atmosphere Color/Decay and haze over this common background. Color controls the atmospheric hue; Decay influences the side away from the sun. A warm Color plus cooler Decay gives directional colour without a painted sun. [Roblox atmosphere reference](https://create.roblox.com/docs/environment/atmosphere).

A custom coloured skybox is also possible using six seamless image assets. Use a quiet, direction-neutral gradient with no painted sun or bright sunset cloud bank. Image IDs cannot be numerically blended by this renderer; selecting separate stage skyboxes would jump. The current design deliberately keeps one cloudless background while atmosphere colours change. Skybox rotation affects only the images, not the sun. [Roblox skybox reference](https://create.roblox.com/docs/environment/skybox). Custom images, uploading and a second sky renderer are not part of this refinement.

The existing opt-in Studio lighting-preview tool also supports 1 sunrise, 2/3/4 day, 5 sunset, 6 dusk, 7/N night, 8 dawn, M day, brackets quarter-hour scrubbing, and R to resume. It requires its existing ClientTools opt-in; keep it disabled for ordinary play. Config-based server preview above does not require that tool.

## Return to the original system

Stop Play, set the Lighting config's `CycleMode` to `Stepped`, and start Play again. The original eight-stage schedule, timing and sky behaviour return. Your Continuous tuning stays available; switch back to `Continuous` and restart to use it again.

Full source removal/recovery uses the same guarded [canonical installer](../../scripts/continuous_lighting/install.lua). It refuses to delete altered tuning or unrelated contents. After custom authoring, capture those edits before preparing a full rollback; do not force the installer past its guard. The simple Stepped mode switch does not require discarding custom tuning. [Technical delivery and recovery](lighting-horizon-moon-handoff.md). The installer's `REVERT_REFINEMENT` restores the previous V6 warm/twilight/night tuning, eighteen-second holds and sun size 6; cycle speed and ray envelope are unchanged; `REFINE` reapplies this refinement. Both refuse intervening edits and leave the installed system in place. Historical refinements need their matching captured source/config state; do not run them as a migration queue.
