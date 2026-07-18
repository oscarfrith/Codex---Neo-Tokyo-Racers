# Garage Phase 0 Ownership And Dependency Audit

**Date:** 2026-07-15  
**Status:** Completed; retirement gate blocked with confirmed extraction map  
**Script:** `scripts/roblox_ui_garage_phase0_ownership_dependency_audit.lua`

## Purpose

This is the mandatory read-only gate before another garage UI implementation. It replaces the previous practice of repairing the V3/V3.1 installer without proving who owns the visible UI.

The refreshed mirror shows that canonical Browser and Workspace modules exist, but the register-limited bootstrap still:

- constructs `HOVER_RACING_V2_GarageUI`;
- owns `setupUI` and garage page assembly;
- owns the page transitions and server-action callbacks;
- remains referenced by several visibility/session companion clients.

The canonical modules are therefore not yet a complete replacement. The old and new systems still share ownership and failure boundaries.

## Safety

The audit is read only. It does not create reports in Studio, edit Source, change attributes, toggle scripts, change visibility, or reparent anything.

Do not rerun the V3/V3.1 remaining-menu installer before collecting both audit outputs.

## How To Run

Use the same script twice as one audit phase:

1. In **Edit mode**, paste the complete script into the Command Bar and run it. Save all lines beginning `[NTR Garage Phase 0 Audit]`.
2. Start **Play**, reproduce the broken garage page, switch the Command Bar to **Client**, and run the same script again while that page is visible. Save the complete second output.

The Edit run proves static ownership and retirement dependencies. The Play-client run identifies the actual visible owner and prints the absolute geometry of visible canonical and legacy roots.

## Gate Meaning

`RETIREMENT GATE PASS` means the old UI has no source references, no constructor and no action/state ownership. Only then is direct deletion safe.

`RETIREMENT GATE BLOCKED` is expected for the current mirror. Its evidence becomes the exact extraction map for the next implementation:

- isolated garage application/state controller;
- isolated server-action/profile adapter;
- small session and camera bridge;
- one explicit canonical presentation owner;
- removal of bootstrap rendering only after those dependencies pass.

The runtime result must show one visible canonical root and no visible legacy top-level surfaces. A visible legacy surface with no canonical root is the current regression and is reported as `Legacy runtime owner won`.

## Next Step After Results

Use the two outputs to write one canonical replacement specification. Do not write another source patch until every blocker has an assigned replacement owner. Keep the approved V1.4 Browser visuals and the shared components, but move state/action/page assembly out of the bootstrap rather than copying its legacy UI tree.

## Confirmed Results

The user ran both contexts on 2026-07-15.

Static summary:

```text
pass=6 warn=1 blocker=6 info=21
RETIREMENT GATE BLOCKED
```

Runtime summary while the broken page was visible:

```text
pass=0 warn=0 blocker=1 info=8
Legacy runtime owner won: legacy surfaces are visible and no canonical root is visible.
```

The approved Browser did initially start correctly:

```text
[NTR Garage Presentation Owner] PASS Browser
[NTR Garage Replacement Runtime] GEOMETRY PASS 1920x1080:Customisation
```

It failed during the transition to Workspace because the installed Workspace source requires a module that is absent from the refreshed hierarchy:

```text
Infinite yield possible on ... Controllers.UI:WaitForChild("GarageModuleArtworkRegistry")
GarageWorkspaceController:9
```

`Config.UI.GarageReplacement.ModuleArtwork` exists but is empty. All eleven required category folders are absent. The installer therefore switched source ownership without proving that its complete dependency graph persisted through a fresh Play session.

A separate bootstrap startup defect is also confirmed:

```text
Attempt to connect failed: Passed value is not a function
NeoTokyoRacersClient_Bootstrap_Shadow_Disabled:3675
```

Line 3675 is `getMore.MouseButton1Click:Connect(showCashShop)`. The refreshed bootstrap contains calls to `showCashShop` but no definition, so this is a real missing callback rather than a layout symptom. Do not repair this callback inside the legacy constructor; the canonical action adapter must own the cash action.

## Confirmed Ownership Map

### Retain

- `GarageBrowserController`: approved Browser renderer; its runtime geometry passed.
- `GarageWorkspaceController`: retain its visual contract, but only after its dependencies are source-controlled and injected/validated.
- `GarageReplacementComponents`: shared shell, cards, stats and popup components.
- `GarageActionController_Shadow_Disabled`: the audit confirmed required server actions exist.
- `GarageSessionService_Active`: enabled and already publishes `NTR_GarageSessionActive` and `NTR_GarageSessionMode`.

### Extract from the bootstrap

- Page state and routing for Browser, Paint, Build and Customise.
- The 25 current server-action call sites, consolidated behind one isolated action adapter.
- Profile/cash/capacity view-model assembly.
- Preview vehicle and garage camera commands needed by the canonical application.
- Entry, close and Start Driving handoffs.

### Replace legacy-name observers

Nine source objects still reference `HOVER_RACING_V2_GarageUI`. Active menu/VFX/HUD/sprint observers must read the existing neutral `NTR_GarageSessionActive` attribute instead. The disabled `DriveInCustomisationZoneClient_Active` and `GarageExperienceController_Active` can be removed only at the final zero-reference gate.

### Retire after the gate passes

- Bootstrap `setupUI` and `HOVER_RACING_V2_GarageUI` construction.
- Bootstrap page renderers: `renderCockpitShop`, `renderCockpitPaint`, `renderModuleShop`, `renderCustomise`.
- Legacy cash, capacity, stats, navigation, paint, module and customisation surfaces.
- The disabled legacy presentation controller and obsolete drive-in client.

The audit's seven broad ScreenGui-constructor hits include unrelated entrance/interior/racing interfaces. They are review information, not proof that all seven compete for garage presentation. The runtime evidence identifies the actual conflict as `HOVER_RACING_V2_GarageUI` versus `CanonicalGarageGui`.

## Required Transactional Installation Rule

The next implementation must stage every canonical module and all eleven artwork folders before changing presentation ownership. It must compile/read back every source, validate every required instance and marker, and only then perform the final small activation switch. If staging or validation fails, legacy ownership must remain unchanged. A fresh Play restart—not an immediate installer assertion—is the acceptance gate.
