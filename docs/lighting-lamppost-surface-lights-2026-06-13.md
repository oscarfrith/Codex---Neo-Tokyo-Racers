# Night Lamppost Surface Lights

**Created:** 2026-06-13  
**Status:** Generated; requires Studio install and Play verification

Run this whole file in the Roblox Studio Command Bar:

```text
scripts/roblox_lighting_lamppost_surface_lights_install.lua
```

The installer finds a `SurfaceLight` named `SurfaceLight lamppost`, then clones
it onto every MeshPart named `lamppost neon`. If the initial source MeshPart
contains duplicate lights with that name, the installer keeps the first as the
template and removes the duplicate siblings.

Installed lights receive the `NTR_NightLamppostLight` CollectionService tag and
start disabled. The installed `NightLamppostLightController_Active` enables them
only during night mode, using the same `NTR_LightingPreset` attribute and
Brightness fallback as the window material controller.

The existing edit-mode preview scripts were also updated. The Day preview
disables tagged lamppost lights and the Night preview enables them.

The script is rerunnable. All existing child lights named
`SurfaceLight lamppost` are replaced from the current template, allowing the
template to be tuned and then redistributed. On its first successful run, the
installer marks the source light with `NTRLamppostLightTemplate` so later runs
can distinguish it from the copies.

## Verification

1. Run the installer and confirm it prints the intended template path.
2. Check several `lamppost neon` MeshParts for a cloned SurfaceLight.
3. Enter Play mode.
4. Press `N`; all tagged lamppost lights should enable.
5. Press `M`; all tagged lamppost lights should disable.
6. Test streamed city blocks and confirm newly streamed tagged lights follow the
   current mode.

## Rollback

Delete cloned `SurfaceLight lamppost` children from the target MeshParts and
remove `NightLamppostLightController_Active`, or restore the prior place version.

Refresh the Studio mirror after installation and verification.
