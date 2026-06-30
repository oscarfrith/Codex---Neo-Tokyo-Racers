# VFX System

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

## Performance Notes

Known performance choices:

- Cached VFX runtime was added to avoid repeated cloning.
- A weld leak in cached thrust visuals was fixed in V66.
- Particle rates should stay moderate on mobile.
- Beams are generally efficient, but lots of animated textures/particles across many cars still need profiling.

## Mobile Late-Socket Repair

Prepared repair:

- `scripts/roblox_vfx_mobile_late_socket_rescan_repair.lua`

Observed issue:

- Engine, boost, or stabiliser VFX can intermittently fail to appear on mobile.

Likely root cause from the current mirror:

- `VehicleVFXController.Attach` attaches template VFX only to sockets present during the first scan.
- On mobile, vehicle/module descendants or the vehicle root can arrive later than the initial attach, so engine/boost/stabiliser sockets or the visibility root may be missed.
- Once missed, the controller keeps running but does not attach templates to the late sockets, and a missing root can keep template VFX culled.

Fix intent:

- Track sockets already handled by `VehicleVFXController`.
- Periodically rescan the vehicle for new `VFXSocket` / `VFX_` attachments.
- Attach template VFX only to newly discovered sockets, avoiding duplicate hosts.
- Refresh the controller root if it was not available during the first attach.

Verification:

- Run the repair in Studio edit mode.
- Start a fresh mobile/emulator Play session.
- Spawn a complete vehicle and confirm engine idle/on, boost, and left/right stabiliser drift VFX appear.
- Repeat once or twice after respawn/re-enter because the bug was intermittent.
