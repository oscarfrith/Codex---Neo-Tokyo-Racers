# Day / Night Lighting Preset System

**Created / first designed:** 2026-05-26  
**Last updated:** 2026-07-13
**Current status:** Eight-stage AQ/AR/AS cycle installed and mirrored; runtime verification still recommended
**Relevant docs file:** `docs/lighting-and-atmosphere.md`  
**Relevant files to edit:** Lighting preset modules/scripts only. Do not edit vehicle, LOD, or race files unless specifically requested.

## What The System Does

The lighting system allows the game to switch between different atmosphere presets, mainly day and night. It is intended to make Neo Tokyo Racers feel like a colourful futuristic city while still allowing lighting values to be edited visually in Roblox Studio.

The workflow designed was:

1. Apply lighting settings in edit mode.
2. Preview and tune visually.
3. Run a temporary output script to print the values.
4. Copy the values back into the lighting preset table.
5. Use keybinds to switch lighting conditions during testing.

## Current Folder / Script Names

Exact final names TBC.

Known systems:

```text
Lighting preset module/config: TBC
Temporary lighting output/preview script: StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview
Lighting condition toggle script: TBC
```

`TEMP_LightingPreview` is intentionally kept as a temporary tool for checking and tuning day/night lighting settings. Future cleanup scripts should not treat the `TEMP` prefix on this specific script as accidental clutter.

Known keybinds:

```text
N = night mode
M = day mode / alternate condition
```

Known services/objects involved:

```text
Lighting
Atmosphere
Bloom
ColorCorrection
SunRays
DepthOfField
Sky
```

## Important Attributes / Settings

Known day settings captured on or around 2026-05-26:

```lua
Lighting.ClockTime = 12
Lighting.Brightness = 5.150000095367432
Lighting.Ambient = Color3.fromRGB(105,187,255)
Lighting.OutdoorAmbient = Color3.fromRGB(156,214,232)
Lighting.EnvironmentDiffuseScale = 0.47099998593330383
Lighting.EnvironmentSpecularScale = 1
Lighting.ExposureCompensation = 0.10000000149011612
Lighting.ShadowSoftness = 0.20000000298023224
Lighting.GlobalShadows = true
```

Atmosphere day settings:

```lua
Atmosphere.Density = 0.2199999988079071
Atmosphere.Offset = 0.20000000298023224
Atmosphere.Color = Color3.fromRGB(199,199,199)
Atmosphere.Decay = Color3.fromRGB(106,112,125)
Atmosphere.Glare = 0
Atmosphere.Haze = 0
```

ColorCorrection day settings:

```lua
ColorCorrection.Brightness = 0.05000000074505806
ColorCorrection.Contrast = 0
ColorCorrection.Saturation = 0.4000000059604645
```

Bloom day settings:

```lua
Bloom.Intensity = 0.6499999761581421
Bloom.Size = 10
Bloom.Threshold = 1.9040000438690186
```

Important design note:

- Day and night should not just change numbers; they may also need different `Sky` objects.
- If the day skybox remains during night mode, the night preset will look wrong even if Lighting values change correctly.

## Current Known Issues

- Lighting Phase AQ was installed and user-confirmed working on 2026-07-13. It
  extends the system to Day, 5 PM, 8 PM, Night, 4 AM, and 7 AM with explicit
  window and managed street-light signals. The Studio mirror still needs a
  post-Phase-AQ refresh. See
  `docs/lighting-phaseAQ-six-stage-cycle-2026-07-13.md`.

- Night mode was still showing the day sky as of 2026-05-26.
- The likely cause is that the preset switch changes Lighting/Atmosphere values but does not swap, remove, or disable the day `Sky` object.
- Need to confirm final `Sky` handling:
  - Separate `Sky_Day` and `Sky_Night`
  - Or clone the correct sky from storage into `Lighting`
  - Or remove the sky entirely for night if using atmosphere/fog only
- Lighting Phase AP was installed and user-confirmed working. It migrates
  matching building window MeshParts to `Windows Day` / `Windows Night`
  MaterialVariants and installs an event-driven client controller.
- Separate day and night Command Bar scripts are available for applying the
  complete preset and window materials while remaining in Studio edit mode.
- Separate capture scripts save the current edit-mode Lighting, atmosphere,
  post effects, and active Sky back into either the `Day` or `ClearNight`
  runtime preset for the next Play session.
- A lamppost SurfaceLight installer is generated to distribute the
  `SurfaceLight lamppost` template onto every `lamppost neon` MeshPart. Its
  isolated client controller keeps the tagged lights disabled during day and
  enabled during night.
- The current ClearNight preset uses `ClockTime = 12.1`, so window night-mode
  detection cannot safely use ClockTime. Phase AP prefers the
  `NTR_LightingPreset` Lighting attribute and uses Brightness as compatibility
  fallback for the existing N/M preview tool.

## Six-Stage Phase AQ Design

Phase AQ keeps the confirmed preset/capture workflow and adds an editable
`LightingCycleConfig` Folder plus ordered schedule ModuleScript. Day and Night
use duration weight `2`; 5 PM, 8 PM, 4 AM, and 7 AM use weight `1`. Explicit
`NTR_StreetLightsOn` and `NTR_WindowMode` attributes replace fragile darkness
inference for the new preset names.

The installer captures the current Edit-mode condition into `FivePM`, initially
copies it into independent `SevenAM` data, and initializes independent EightPM
and FourAM data from ClearNight. A reusable multi-target capture tool and a
single selected-stage Edit-mode preview tool replace the need for duplicate
per-stage capture/preview scripts.

Phase AR adds independent `TenAM` and `ThreePM` presets copied from Day and
expands the chronological cycle to eight stages. Install it from
`docs/lighting-phaseAR-10am-3pm-day-copies-2026-07-13.md`.

Phase AS adds per-stage `StageVisuals` folders for explicit window mode,
street-light enabled state, and street-light brightness. Environmental capture
does not overwrite them; preview/runtime reads them as the sole visual-state
configuration owner.
See `docs/lighting-phaseAS-stage-visual-config-2026-07-13.md`.

## Text Snapshot Tool

Run `scripts/roblox_lighting_capture_current_to_text_value.lua` in Edit mode to
write the current environment into:

```text
ReplicatedStorage.Shared.LightingCycleConfig.CurrentLightingCaptureText
```

The StringValue contains a deterministic Lua table with Lighting, atmosphere,
post-effects, active Sky properties, current preset name, and the current
preset's config-owned StageVisual settings when available. The tool does not
change presets or runtime behavior; rerunning it refreshes the same StringValue.

The `2026-07-14 00:15:37` mirror confirms the text snapshot tool output and all
AQ/AR/AS config folders. The pasted `FivePM` snapshot is already present in both
`FivePM` and `SevenAM`; their environment tables are identical except for their
separate `FivePMSky` / `SevenAMSky` names. Both StageVisual folders use Day
windows, street lights disabled, and brightness `2`.

Follow-up screenshot comparison proved that mirrored state was the incorrect
bright Picture 1 look. The intended warm Picture 2 state is the later
`2026-07-13T23:28:12Z` text snapshot. A targeted importer is generated as
`scripts/roblox_lighting_replace_5pm_7am_with_warm_snapshot.lua`; it replaces
only FivePM/SevenAM environment and Sky data while preserving StageVisual config.

## Confirmed Working

- Lighting values can be tuned in edit mode.
- Temporary output workflow successfully prints values for copying into presets.
- Day settings have been captured.
- Key-based lighting switching exists in some form.
- `TEMP_LightingPreview` is intentionally retained as a lighting preview/testing tool.

## Still Needs Testing

- Night sky replacement/removal.
- Whether `N` and `M` correctly update every relevant post-processing object.
- Whether the system works after publishing.
- Whether lighting state is local-only or server/global.
- Mobile visual performance with Bloom, ColorCorrection, SunRays, and DepthOfField.
- Whether DepthOfField should be reduced or disabled for gameplay clarity.
- Whether night visibility is good enough for racing.

## Codex Safety Notes

- Do not edit vehicle, LOD, or race files when working on lighting presets.
- If a lighting script name is `TBC`, inspect Studio before renaming or patching.
- Treat the skybox issue as unresolved until night mode is verified in Studio or a published client.
- Do not rename or remove `TEMP_LightingPreview` during general cleanup unless the lighting workflow has been replaced by a cleaner tool.
- Before running Phase AP, confirm both MaterialVariants exist and use the same
  BaseMaterial. The migration removes matching SurfaceAppearance children and
  clears MeshPart texture content, so Roblox version history is the rollback.
