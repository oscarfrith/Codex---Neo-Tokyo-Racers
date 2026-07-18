# Garage Module Inventory And Upgrade Audit

Status: Play-server audit completed on 2026-07-16.

Script: `scripts/roblox_ui_garage_module_inventory_upgrade_audit.lua`

## Purpose

This is the read-only gate before changing the module inventory and module-menu UI. It distinguishes genuine purchases from accidental default or migration copies, validates every installed instance reference, and explains why performance-upgrade cards are absent.

It does not call `GarageInvoke`, mark the profile dirty, save the profile, create instances, repair records, or change source/config/UI objects.

## Run instructions

1. Paste the script into the Studio Command Bar.
2. Start a normal Play session and wait for the player profile to load.
3. Switch the Command Bar execution context to **Server**.
4. Run the script once.
5. Copy the complete output beginning with `[NTR Garage Module Audit]` back to Codex.

If Studio says to use the Server Command Bar, change the Command Bar context from Client to Server and rerun it. Do not run an inventory cleanup script before reviewing this output.

## Output used by the next stage

- Counts per module template and acquisition `Source`.
- Installed, available, orphaned and multiply-referenced instances.
- Vehicle ownership/reference mismatches.
- Installed module model/type/materialisation state.
- Legacy definition count and runtime upgrade catalog count.
- A final compact `SUMMARY` line.

## Guardrail for cleanup

The next stage may automatically collapse only duplicates whose source and references prove they were accidental grants or migrations. Purchased instances and ambiguous records must be preserved. Any transfer between vehicles must be server-authoritative and update both vehicles atomically.

## Confirmed result

The live profile contained 6 vehicles, 6 cockpit instances and 1,428 module instances across 26 templates:

- `LegacyInstalledModules`: 1,402 instances.
- `IncludedWithCockpit`: 20 instances.
- `BuyModuleInstance`: 6 instances.
- 1,378 instances claimed to be equipped but had no vehicle-slot reference.
- All actual vehicle-slot references resolved correctly.
- No live instance was referenced by multiple slots.
- No referenced instance had an ownership mismatch.

This proves the large ownership counts are persisted legacy-reconciliation debris, not legitimate purchases and not a UI grouping defect. The live request handler still runs default attachment and instance reconciliation before every garage action. On a template mismatch, `V84_ensureInstanceInventory` creates a replacement `LegacyInstalledModules` instance and overwrites the slot without clearing the former instance's `EquippedVehicleId`; repeated reconciliation therefore leaves hundreds of equipped-but-unreferenced records.

The cleanup stage must preserve every referenced instance and all six `BuyModuleInstance` records. It must classify unreferenced records by source in dry-run output before deleting anything, and remove the per-request creation path before cleaning saved profiles so the corruption cannot return.

The upgrade audit found four empty catalogs: the installed Standard Engine1, Engine2, Stabilisers and Boost modules. These models are intentionally materialised with `Upgradable=false`, zero point capacity and no `VehiclePerformanceV2UpgradePaths`; Lightweight and Power variants contain the V2 paths. Therefore the empty page is the current balancing contract, not a failed catalog lookup. The UI should show a clear Standard-module non-upgradable state unless Standard upgrade paths are deliberately designed and balanced later.
