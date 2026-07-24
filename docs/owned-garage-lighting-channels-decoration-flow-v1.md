# Owned Garage Lighting Channels And Decoration Flow V1

Status: user-confirmed working and represented in the complete `2026-07-23 22:22:32/33` Studio mirror. The installer is recovery-only for this exact scope.

Canonical installer: `scripts/roblox_owned_garage_lighting_channels_and_decoration_flow_v1.lua`

Revision: `NTR_OWNED_GARAGE_LIGHTING_CHANNELS_DECORATION_FLOW_V1`

## Acceptance contract

This is a bounded Standard-lane correction across the existing finish capability owner and management presentation owner. It adds no remote, service, ScreenGui, saved field, schema migration, economy action or physical asset.

Done means:

- `ColourSlots.Primary` and `ColourSlots.Secondary` are authoritative regardless of descendant names.
- Descendant BaseParts and attached `PointLight`, `SpotLight` and `SurfaceLight` objects inherit the same folder channel.
- `Fixed` and `Technical` descendants cannot be recoloured by saved finish data.
- An empty channel is omitted from the Style Lighting tabs.
- saved Primary and Secondary colours remain independent and are not reset;
- Lighting SAVE uses `OwnedGarageIcons.Navigation.Save`;
- selecting an equipped Decoration Style location opens the shared colour sliders directly;
- empty locations retain the existing Install Asset route and assets without colour channels retain the shared unavailable state.

## Root cause

The refreshed authoritative hierarchy contains stale duplicated metadata. In `LightingOption01`, housing parts under `Fixed` still carry `GarageColourChannel=Primary`, while emitter parts under `ColourSlots.Primary` carry `GarageColourChannel=Secondary`. `OwnedGarageFinishRuntime` previously resolved direct attributes before folder ancestry. A saved blue Primary value therefore recoloured fixed housings, while Primary and Secondary affected different halves of the intended fixture.

The installer keeps saved colours intact. It makes canonical folder ancestry win, explicitly protects `Fixed` and `Technical`, makes capability inspection aware of supported light instances and removes legacy `GarageColourChannel`/`LightingChannel` attributes only from objects already inside the authoritative lighting option folders. It does not inspect or modify `ReplicatedStorage.ZZZ`.

## Authoring contract

```text
ServerStorage.NeoTokyoRacers.OwnedGarage.LightingAssets.<TemplateId>.<LightingOption>
  ColourSlots
    Primary
      <arbitrarily named models and parts>
        <arbitrarily named neon part>
          <PointLight, SpotLight or SurfaceLight>
    Secondary
      <optional arbitrarily named content>
  Fixed
    <authored housings and other non-editable visuals>
  Technical
    <implementation-only content>
```

Names do not participate in channel resolution. Options 02-04 currently retain housings inside `ColourSlots.Primary`; those will correctly remain Primary-editable until the author moves them to `Fixed`. The installer deliberately does not move, create or delete assets.

## Ownership and state

- `OwnedGarageFinishRuntime` remains capability, validation and colour-application owner.
- `OwnedGarageWorkspaceController` remains draft/navigation owner and continues to call the shared colour-slider renderer.
- `OwnedGarageProfileRuntime` and ProfileService remain the only persistence owners.
- `OwnedGarageManagementRuntime` remains the physical runtime/preview owner.
- Stable preset, decoration and finish IDs remain unchanged.

## Installation and verification

1. Run the complete installer once in Studio Edit mode.
2. Require `[NTR Owned Garage Lighting Channels + Decoration Flow V1] PASS` followed by `READY`.
3. Fully restart Studio before Play so cached required modules and existing runtime clones cannot mask the new contract.
4. Enter the starter garage with Lighting Option 1.
5. Confirm the housings retain their authored black colour.
6. Open Style Garage > Lighting. Option 1 currently has populated Primary content and empty Secondary content, so only Primary should appear.
7. Change Primary. Every eligible neon part and its attached supported light should change together. Save, remain on the editor, close/reopen and rejoin to confirm persistence.
8. Temporarily author a complete fixture beneath Secondary, restart Play and confirm Secondary appears and changes both its neon and attached light without reverting Primary. Remove that test fixture afterward if it is not intended content.
9. Confirm the Lighting SAVE button displays the configured Save icon.
10. Open Style Garage > Decorations. Selecting All Decorations or an equipped colour-capable location must open the existing colour sliders immediately, with no intermediate Colour card.
11. Select another location using the left rail; the sliders must update directly. Back must return to the Style Garage family page.
12. Confirm an empty location still offers Install Asset and a decoration with no channels still reports that colour editing is unavailable.
13. Regression-check Structure colour/material editing, Build purchase/equip, display cars, Back/Exit, desktop and phone layouts.
14. Refresh both Studio mirror areas before treating this revision as confirmed.

The first attempted run stopped during read-only preflight because the installer incorrectly treated `OwnedGarageIcons.Navigation.Save` as a child `StringValue`. The established icon contract stores `Save` as a string attribute on the `Navigation` folder. The same canonical installer now validates that attribute through `GetAttribute`, matching the existing UI resolver. The failed run changed nothing.

## Rollback and risks

The installer uniqueness-checks every compressed-source anchor and compiles both projected modules before mutation. It snapshots both sources and every touched legacy metadata attribute and restores them if its committed-state audit fails.

Saved finish values are preserved. Any object intentionally relying on a direct channel attribute while already placed beneath a different canonical folder will now follow its folder; this is the intended authoring rule. Objects outside `ColourSlots`, `Fixed` and `Technical` retain the legacy attribute fallback.

Use the current freshly mirrored pre-install state as rollback. Do not rerun Phase 14 or clear player data to compensate for a failed check.
