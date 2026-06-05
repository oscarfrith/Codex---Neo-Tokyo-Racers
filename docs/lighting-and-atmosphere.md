# Day / Night Lighting Preset System

**Created / first designed:** 2026-05-26  
**Last updated:** 2026-05-28  
**Current status:** Partially working / night sky issue unresolved  
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

- Night mode was still showing the day sky as of 2026-05-26.
- The likely cause is that the preset switch changes Lighting/Atmosphere values but does not swap, remove, or disable the day `Sky` object.
- Need to confirm final `Sky` handling:
  - Separate `Sky_Day` and `Sky_Night`
  - Or clone the correct sky from storage into `Lighting`
  - Or remove the sky entirely for night if using atmosphere/fog only

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
