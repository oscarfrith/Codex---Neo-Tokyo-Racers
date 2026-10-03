# Vehicle assets and configuration

Public data ownership: VehicleCatalogData is generated from the authoring attributes/upgrade folders; VehicleCatalog resolves stable IDs, VehicleDefinition shares Instance/record reads, and VehicleTemplateIndex resolves preview models by bounded paths. After content edits, take a vehicles targeted capture and run scripts/performance_phase4/check_projection.py --capture <capture.json>; regenerate through the content change installer and restart Play. Canonical templates now live in ServerStorage.Assets.Vehicles. Generated VehiclePreviews and VehicleCatalogData must be regenerated together after authoring changes.

Performance Phase 2 moved PlayerProfileSchema/GarageProfileProjection and the vehicle performance writer to ServerStorage.Modules, plus Persistence/PersonalBests/Leaderboards to ServerStorage.Config. Shared calculators remain replicated. Phase 4 moves full categories server-side and gives preview/HUD clients generated VehiclePreviews categories. Client calculations now use generated catalogue records. See architecture/performance-phase2-server-storage.md.

Current baseline and acceptance: [start here](00_START_HERE.md); outstanding checks: [open issues](06_current_known_issues.md).

ServerStorage.Assets.Vehicles holds active authoring/spawn categories; ReplicatedStorage.Assets.VehiclePreviews holds generated preview geometry. ServerStorage.Assets.Garage and Racing hold server templates. Config.Vehicles groups Driving, Dynamics, Camera, Performance, Spawn, MobileControls, DriveRewards, Authoring, DriverSeat and StabiliserVFX. ModuleSlots/VFXAttachments are folder hooks; physical hooks are unchanged. Staging/Archive remain protected pending decision.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/02_vehicle_folder_system.md; old installation instructions are historical, not pending tasks.

## Second category, ten slots and the catalogue split (Backup v2, 2026-10-03)

This section describes **Space Racers Backup v2 (place 133417340424236) only**. v2 still has one category, eight slots and a single-source VehicleCatalogData. Contract and evidence: [Exotic category contract](architecture/exotic-category-contract.md). Names, IDs and semantics: scripts/exotic_category/INTERFACE.md.

### Categories

ServerStorage.Assets.Vehicles.Categories holds two folders. PIERCER stays the first child.

| Folder | CategoryId | Cockpits | Module models | Slots | Gate |
|---|---|---:|---:|---:|---|
| PIERCER | bruiser | 6 | 116 | 8 | none |
| EXOTIC | exotic | 6 | 108 | 10 | FeatureFlag = "VehicleClass_exotic" |

Every ID is permanent once a place that saves has sold it. IDs are unique across all categories.

### Slots

An Exotic cockpit has the eight Piercer slots plus FrontBody (Nose) and RearBody (Engine Deck).

- All six Exotic cockpits carry the same ten `ModuleSlots/SLOT_<SlotId>` folders. The catalogue reads a category's slot list from its first cockpit.
- Every mount sits at the root origin. The root part is the Piercer root.
- FrontBody and RearBody are required slots on a cockpit that has them. A module move cannot leave them empty.
- A bought Exotic gets a default module in all ten slots. The purchase is refused before the debit if any default is missing or does not fit.

### Opt-in attributes

Absent means the Piercer behaviour. Piercer has none of these.

| Where | Attribute | Effect |
|---|---|---|
| Category folder | FeatureFlag | Names a Core.FeatureFlags key. Flag off: the category is left out of the catalogue and both buy actions refuse. |
| Slot folder | RailLabel | Player-facing slot label in this category |
| Module model | CardTitle | Title on the module's shop and inventory card |
| Module model | RatingReferenceCockpitId | Reference cockpit for the module rating. Absent: bruiser_01. Exotic modules use exotic_03. |
| Cockpit model | `Default<SlotId>ModuleId` | Default module for a slot other than the four legacy ones (FrontBody, RearBody, SidePods, FrontBumper, RearBumper, RearSpoiler) |
| Cockpit model | DriverSeatOffsetX/Y/Z | Driver seat offset in root local space. The fallback to the global value is per axis. |
| Cockpit model | PassengerSeatOffsetX/Y/Z | Passenger seat offset in root local space. The fallback is per axis. |

Rules an author must keep:

- The four legacy slots keep their seven legacy default attribute names. Exotic cockpits set all seven and the six new ones.
- A Standard core module has Price = PurchasePrice = 0. It must carry SourceCockpitId and its own CategoryId, or an extra copy is charged 1,000 and not 12% of the cockpit price.
- No instance inside a module template has a name containing cockpit, engineon, engineoff, booston, stabiliseron or stabilizeron. No body module instance name contains engine, boost, stabiliser or stabilizer. Live code matches these words.
- Never set a PurchaseDisabled attribute on a category folder. The field is reserved. Folder attributes are copied to the client, so it would hide the category with no server enforcement.
- Do not turn a category's flag off once a saved profile owns one of its vehicles.

### Catalogue: an index plus chunk modules

VehicleCatalogData keeps its path and is now a generated index. The records live in child ModuleScripts named `VehicleCatalogData.<FOLDER>_<n>`. As installed: PIERCER_1, PIERCER_2, EXOTIC_1, EXOTIC_2 (12 cockpits, 224 modules).

- Roblox rejects a script Source of 200,000 characters or more. The single-source file was 197,226 characters with Piercer alone.
- The generator groups records by category folder, fills each chunk to 150,000 characters and asserts every source is under 190,000.
- The index asserts on a duplicate id across chunks.
- VehicleCatalog and every reader are unchanged.
- Never edit the index or a chunk by hand.

### Regenerating after an authoring edit

The generator is scripts/exotic_category/catalogue/catalogue_gen.lua. It reads ServerStorage.Assets.Vehicles.Categories and returns the index and chunk sources. It never writes; an installer writes what it returns.

1. For Exotic content, change the data (scripts/exotic_category/stage_b/data/*.json, or the balance build for stats and prices). Then rebuild with scripts/exotic_category/stage_b/build_content.py, run AUDIT, review, and run APPLY in Edit.
2. APPLY replaces the installer's own earlier content. It regenerates the index, the EXOTIC_n chunks and the preview copy together.
3. A Piercer authoring edit in that place must regenerate the PIERCER_n chunks with the same generator. The Stage B installer blocks while VehicleCatalogData does not equal the generator output.
4. Restart Play. The catalogue is read once at startup.
5. Take a vehicles capture and run scripts/performance_phase4/check_projection.py and scripts/performance_phase3/check_catalogue.py with --capture. Both accept the single-source form and the split form.

### Who owns the EXOTIC folders

The Stage B installer (scripts/exotic_category/stage_b/, [guide](../scripts/exotic_category/stage_b/README.md)) owns:

- ServerStorage.Assets.Vehicles.Categories.EXOTIC;
- ReplicatedStorage.Assets.VehiclePreviews.Categories.EXOTIC;
- the four VFX template folders EngineJet_Exotic, BoostJet_Exotic, StabiliserJet_ExoticLeft and StabiliserJet_ExoticRight;
- the VehicleCatalogData.EXOTIC_n chunks.

Each created root carries InstalledBy = "exotic_category/stage_b" and a signature of its descendants. A hand edit to a created root makes AUDIT report a blocker, and ROLLBACK then refuses. Change Exotic content through the data files and the installer, not by hand in Studio. Geometry comes from scripts/vehicle_blockouts/specs/exotic.json, not from Workspace.VehicleCategoryBlockouts.
