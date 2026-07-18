# Garage transient module preview lifecycle

Date: 2026-07-17

Status: guarded client-state installer generated; awaiting Studio and Play verification.

## Root cause

`State.PreviewModules` is intentionally client-only and does not change equipped or saved module instances. Buy, Equip and the Module Options Back path cleared it, but Build-to-Customise and several other page boundaries did not. Therefore an unequipped module could remain on the garage preview even though Start Driving correctly spawned the authoritative equipped build.

## Fix

- One local `clearTransientModulePreview` owner clears the selected template, selected physical instance, module override map, upgrade selection and neon selection.
- Paint-to-Build, Build Back, Build-to-Customise, Customise Back and Start Driving all invoke that owner.
- Boundaries that stay visible rebuild the preview from the current equipped profile immediately after clearing.
- Owned/Buy browsing on the same module-options page still retains the selected preview until the player buys, equips or leaves that page.

## Safety

No server action, equipment reference, purchase, saved customisation, profile or persistence code changes. The installer patches only the isolated canonical application controller, compiles before assignment, is rerunnable and restores its original Source if the audit fails.
