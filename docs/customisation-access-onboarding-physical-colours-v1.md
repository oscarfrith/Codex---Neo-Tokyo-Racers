# Customisation Access, Onboarding Visibility, and Physical Colours V1.1

**Status:** confirmed and handed off; complete `2026-07-26 20:46:20` Studio mirror current  
**Delivery lane:** High-Risk, because the scope crosses server-authoritative profile selection, saved physical module-instance state, runtime vehicle projection, entry/session lifecycle, and onboarding presentation.

## Acceptance Contract

Customisation and Drive-In Customisation must reject only profiles with zero records in the authoritative owned `Vehicles` table. Every rejection uses the shared top notification `OWN A VEHICLE TO CUSTOMISE`. A profile with at least one owned vehicle but a missing or stale `CurrentVehicleId` is repaired to a deterministic valid owned vehicle and allowed through.

The objective-card layer remains hidden from the instant a Customisation or Drive-In server session begins until that session ends. This includes entry/loading, Browser, all three workshops, preview, purchase, Back, Drive, Exit, failed UI handoff, and re-entry transitions. Dealership behaviour is unchanged.

Every equipped physical module-instance record must contain an effective saved colour record before it is projected into a spawned vehicle. Existing explicit colours, physical instance identity, Neon ownership/colour, upgrades, purchases/equips, Cash, vehicle ownership, preview ownership, ProfileService authority, and protected front/rear cockpit lights remain authoritative and unchanged.

## Authoritative Diagnosis

`GarageModuleInstanceCustomizationRuntime` accepted a newly purchased module instance whose `Colors` field was `{}` and copied that empty table into the current profile projection. The preview adapter fills absent channels from cockpit/vehicle colours for display, so preview looked correct. The server vehicle builder used `profile.ModuleColors[slotId] or fallback`; an empty table is truthy, so the fallback was skipped and the cloned module retained its authored grey. ProfileService then correctly persisted the incomplete instance record, explaining the same grey after rejoin.

The defect is therefore in physical module-instance record completion, not Color3 serialization, the preview, or an ephemeral client repaint.

## V1.1 Corrective Upgrade

User testing confirmed persistent physical colours and the exact zero-vehicle top notification. Owned-vehicle access then failed at installed server line 1427 because the V1 access helper returned `Profile=V56_profileForClient(profile)` before that local serializer was declared. The zero-vehicle branch returned earlier and therefore masked the forward-reference defect. Studio vehicle sandbox is unrelated.

V1.1 removes that unused response field; the UI already performs its canonical refresh after access. It also accepts access before beginning either native-entry or direct-UI loading. Exact `OWN A VEHICLE TO CUSTOMISE` denial publishes `UI.PurchaseRejected` through the existing presentation-audio bridge, shows the shared top notification, and returns without creating or failing a loading transition.

## Canonical Owners and Changes

- `GarageModuleInstanceCustomizationRuntime` remains the physical module-instance customisation owner. During hydration it fills only missing `Primary`, `Secondary`, `Detail`, `Neon`, and applicable `ThrustColor` channels from the selected vehicle/profile. Explicit saved channels are never overwritten. `FrontLights` and `RearLights` are not added or changed.
- `GarageActionController_Shadow_Disabled` remains enabled and remains the selection/ProfileService bridge despite its historical name. `EnsureCustomisationAccess` counts real vehicle records, repairs a stale selection through the existing selection function, hydrates incomplete physical colours, and persists only when a selection or colour record was repaired.
- `GarageSessionService_Active` calls the server-only binding before mutating character/session presentation for Customisation and Drive-In. This protects native keyboard, touch/clickable prompt, controller, world prompt, and drive-in routes.
- `ModuleShopUIController` applies the same check at the shared UI event funnel, covering direct desktop/mobile shortcuts and any current/future caller of the canonical Customisation bindable events.
- `SharedTopNotificationController_Active` is the single shared top-notification presentation owner. The entrance and UI funnel publish through `ShowTopNotification`; they do not create route-specific banners.
- `OnboardingClient_Active` keeps objective cards hidden while the authoritative `NTR_GarageSessionActive` attribute is true and mode is not Dealership.
- The register-limited bootstrap, preview renderer, vehicle colour applier, ProfileService, three-workshop renderers, race, VFX, audio, dealership, owned garage, and driving owners are not changed.

## Single Studio Installer

Run only:

```text
scripts/roblox_customisation_access_onboarding_physical_colours_v1.lua
```

Start with `MODE = "INSTALL"` in Studio Edit mode. The installer:

1. verifies exact active owners and confirmed source anchors;
2. audits every authoritative cockpit for all eight current slot locations;
3. audits module-template coverage for Boost, both Engine locations, Front Bumper, Rear Bumper, Rear Spoiler, Side Pods, and Stabilisers;
4. compiles every projected source before mutation;
5. applies one transaction with automatic in-run rollback;
6. proves idempotent source projection and owner counts;
7. prints `INSTALL PASS` and the per-location catalogue report.

After runtime verification, rerun the same file with `MODE = "AUDIT"`. `ROLLBACK` is guarded: it restores only sources that still carry this exact revision and removes only the notification objects created by this scope. It intentionally refuses source drift.

The installer uses guarded exact replacement in the large active garage action controller. An anchor mismatch is a stop condition: refresh/inspect the live source instead of weakening the guard or creating a follow-up patch.

## Runtime Verification Matrix

Use isolated profiles and record failures by vehicle, slot, device, and lifecycle transition.

1. Zero vehicles:
   - trigger Customisation using the desktop/mobile shortcut, world desk prompt, drive-in route where reachable, keyboard, touch/clickable prompt, and controller;
   - confirm every canonical route refuses entry and shows exactly `OWN A VEHICLE TO CUSTOMISE` at the top;
   - confirm no garage session, hidden character, preview, Cash, vehicle, or save mutation remains.
2. Stale selection:
   - use a profile with at least one valid `Vehicles` record and missing/invalid `CurrentVehicleId`;
   - enter through the shortcut and world routes;
   - confirm a deterministic owned vehicle is selected, access succeeds, and the repaired selection survives rejoin.
3. Onboarding:
   - keep applicable objectives incomplete;
   - exercise entry/loading, Browser, Add Modules, Upgrade Modules, Paint Shop, preview, purchase, Back, Drive, Exit, failed/rapid re-entry, and re-entry;
   - confirm objective cards never overlap Customisation and return after the session only if still applicable.
4. Physical module colours:
   - for every current cockpit/vehicle and every compatible module-location type, buy and equip a module;
   - compare `Primary`, `Secondary`, `Detail`, Neon where supported/owned, and thrust colour where applicable between preview and the spawned physical model;
   - drive, exit/re-enter, respawn, switch away/back, and rejoin;
   - confirm exact preview/spawn parity through every transition.
5. Preservation:
   - confirm Neon purchase/state, module upgrades, module-instance identity, protected front/rear lights, Cash deltas, ownership, ProfileService saves, three-workshop navigation, Dealership, owned garage, racing, VFX, audio, and driving remain correct.
6. Devices and growth:
   - complete desktop, landscape phone, touch, and controller entry/exit checks;
   - repeat entry/exit at least ten times and confirm one notification controller/event, no duplicate prompts, no accumulating preview instances, connections, presentation owners, or session attributes.

## Mirror and Confirmation Gate

The user confirmed V1.1 working and requested handoff. The complete `2026-07-26 20:46:20` mirror contains 188 matching checksum, source-manifest and exported-script entries, every V1.1 revision marker, the shared notification event/controller and the corrected access-before-loading ordering. Neither mirror area appears stale.

The canonical installer remains recovery and read-only audit evidence for this exact scope. Do not rerun it for ordinary use. Retain the runtime matrix above as release regression, and never commit `docs/studio-full-export-paste.txt`.
