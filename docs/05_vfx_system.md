# VFX System

## Paint Shop neon and underglow boundary

Customisation Three Workshop V1 adds no VFX owner or physical underbody effect. Module Neon preview continues through `PreviewNeonSlot` and the existing paint/preview runtime; saved/runtime visibility continues to use each module instance's `NeonOwned` state and its authored `NEON_OptionalLights` descendants. The Paint Shop `Underglow` target is the existing bulk module-Neon colour editor. Thrust preview continues to use the current `ThrustColour` preview mode.

## Confirmed Garage Preview VFX Ownership — 2026-07-18

Garage preview VFX now have one template attachment and state owner: `ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Visuals.CachedThrustVisualRuntime`.

- `PreviewVFXMode="Idle"` keeps engine idle and hover presentation active while acceleration, boost and stabiliser effects are off.
- `PreviewVFXMode="ThrustColour"` enables acceleration, boost and stabiliser effects for thrust-colour editing.
- `ThrustPreviewController_Active` remains enabled for colour/input compatibility but may not attach or update another `VehicleVFXController`.
- `GaragePreviewPresentationController_Active` keeps `ForceThrustPreview=false`; that attribute is no longer the garage preview mode contract.
- `scripts/roblox_ui_garage_preview_vfx_single_owner_installer.lua` is the final confirmed ownership repair. The earlier camera/VFX V1 and name-based V1.1 gating are superseded as VFX ownership solutions, although their confirmed camera changes remain in the live source.

The refreshed `2026-07-18 23:14:48` mirror contains `NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1` in the cached runtime, preview bridge and garage presentation owner. Do not add another preview attachment, rescan/rebuild loop or enabled-state writer.

## Current Direction

The VFX system is intended to support:

- Engine idle flame/VFX.
- Engine acceleration flame/VFX.
- Boost VFX.
- Stabiliser/drift VFX.
- Hover dust under the cockpit.

The user moved away from generic smoke-style effects toward sharper rocket/jet style effects.

## Engine VFX

Known hierarchy from chat:

```text
EngineJet
  Settings
  EngineOff_Host
    TemplateAttachmentLong
      EngineOff_Fire
    TemplateAttachmentShort
      EngineOff_BeamFlame
    TemplateBeamEndShort
  TemplateHost_Invisible
    TemplateAttachmentLong
      EngineOn_BeamFlame
      EngineOn_BeamFlame
      EngineOn_BeamFlame
      EngineOn_BeamInner
      EngineOn_BeamOuter
      EngineOn_Fire
    TemplateAttachmentShort
    TemplateBeamEndLong
    TemplateBeamEndMid
    TemplateBeamEndShort
```

Known intended behaviour:

- `EngineOff_Fire` plays while driving and not accelerating.
- Engine on VFX plays while accelerating.
- `EngineOff_Fire` should disable while accelerating.

## Boost VFX

Known intended behaviour:

- Boost VFX only turns on while boost is held/active.
- Boost VFX particles should take the selected thrust colour.
- Beams can remain white unless explicitly changed later.

## Stabiliser VFX

Known intended behaviour:

- Left stabiliser VFX turns on when drifting left.
- Right stabiliser VFX turns on when drifting right.
- Not both at once unless both sides are intentionally active in a future design.

## Thrust Colour

Thrust colour applies to:

- Engine particles/fire.
- Boost particles/fire.
- Stabiliser particles/fire.
- `THRUST_COLOR_WhiteByDefault` module assets.

Customisation preview note:

- Dealership Intro Phase 4 moved the local preview vehicle to `Workspace._NTR_ClientOnly.VehiclePreview`.
- Thrust preview/VFX helpers should resolve that local-only root first, then fall back to `Workspace.HOVER_RACING_V2_LOCAL_PREVIEW` only for older rollback states.
- VFX Phase AJ repairs the active cached thrust runtime for this root change.

Known particle names to recolour:

- `BoostOn_Fire`
- `EngineOff_Fire`
- `EngineOn_Fire`
- `StabiliserOn_Fire`

Known rule:

- Beam effects can stay white.
- Cosmetic optional neon should not be changed by thrust colour.

Vehicle Cosmetics V1 hardens this rule at both active thrust-colour presentation owners. Any PointLight, SpotLight, or SurfaceLight carrying the `FrontLights`/`RearLights` channel or cockpit-light ownership metadata is excluded before thrust VFX classification. The new underglow SurfaceLight uses its own `Underglow` channel and is coloured only by the vehicle cosmetic presenter.

Vehicle Cosmetics V1.2 treats every attributed underglow SurfaceLight as protected, regardless of its parent name or location. Runtime presentation owns only saved colour and purchase-enabled state; emitter count, Brightness, Range, Angle, Face and Shadows remain authored per cockpit. The installer warns when a cockpit exceeds four lights so mobile cost is visible without overriding the designer's setup. There is no frame-loop scan.

## Performance Notes

Known performance choices:

- Cached VFX runtime was added to avoid repeated cloning.
- A weld leak in cached thrust visuals was fixed in V66.
- Particle rates should stay moderate on mobile.
- Beams are generally efficient, but lots of animated textures/particles across many cars still need profiling.

## Mobile Attach Reliability

Current confirmed baseline:

- `scripts/roblox_vfx_restore_mirror_known_good_baseline.lua` restored the known-good VFX source baseline after the failed rescan/rebuild repair sequence.
- `scripts/roblox_vfx_mobile_delayed_attach_once.lua` was installed next and reported working.
- Engine idle/on, boost, and stabiliser/drift VFX toggle correctly again.
- `RuntimeVFXController_Active` no longer grows continuously, and the 3-5 second VFX cut-out/reappear cycle is resolved.

Observed original issue:

- Engine, boost, or stabiliser VFX could intermittently fail to appear on mobile.

Likely cause:

- On mobile, vehicle/module descendants or the vehicle root can arrive shortly after the first `VehicleVFXController.Attach` scan.
- A continuous rescan/rebuild approach is unsafe for this system because cloned runtime VFX hosts contain descendants that can be mistaken for fresh VFX targets.

Current fix:

- `scripts/roblox_vfx_mobile_delayed_attach_once.lua` adds `MobileInitialAttachDelaySeconds` under `VehicleTemplates.00_GLOBAL_VFX_SETTINGS`.
- Mobile `VehicleVFXController.Attach` waits briefly, then performs one socket attach pass only.
- Desktop attach remains immediate.
- The fix does not continuously rescan sockets, clear hosts, rebuild hosts, or add another VFX owner.

Verification:

- Start a fresh mobile/emulator Play session.
- Expect mobile VFX to appear roughly `0.45s` after vehicle/preview creation.
- Spawn a complete vehicle and confirm engine idle/on, boost, and left/right stabiliser drift VFX appear.
- Repeat after respawn/re-enter because the original bug was intermittent.
- Watch `RuntimeVFXController_Active`, total instance count, and unparented Beam count for 60-120 seconds. They should not climb continuously.

Do not rerun:

- The previous late-socket/rescan/rebuild repair ladder is retained only in Git history if committed. Do not treat it as the active repair path unless deliberately reproducing the failed experiment.
## Owned garage environment lighting override

Owned-garage ambient environment presentation is local. `OwnedGarageEnvironmentLightingController_Active` applies the existing shared `ClearNight` Lighting/effect/Sky preset only while the local player's `NTR_OwnedGarageInside` attribute is true. It coalesces external Lighting/effect/Sky changes so development preview keys or a city-stage transition cannot leave the interior on a different preset. It does not publish or modify the city cycle's `NTR_LightingPreset`, `NTR_StreetLightsOn` or `NTR_WindowMode` attributes, and it does not alter the owned garage's custom fixture assets or saved Primary/Secondary colours. The latest valid city preset is reapplied on exit so a cycle change during the visit is not reverted.
