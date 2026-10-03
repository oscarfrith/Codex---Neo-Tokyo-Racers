"""Exotic category, Stage A, server sources.

Copies each owner's before-blob from roblox/captures/exotic-before/capture.json byte for byte, applies the
hunks below (every `before` text must occur exactly once), and writes:
  after/<ScriptName>.lua   complete after-sources
  ops.json                 source operations for the feature installer
  test_sources.json        repo-relative paths of the before blobs, after files and tests.lua (read by run_tests.lua)
  CHANGES.md               every hunk with before, after, reason and the Piercer argument

Run: py -3 scripts/exotic_category/stage_a/server/build.py
Never touches Studio. Writes only inside this folder.

In the hunk texts a leading run of `~` stands for the same number of tab characters.
"""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
CAPTURE = 'roblox/captures/exotic-before/capture.json'
REL = 'scripts/exotic_category/stage_a/server'

GARAGE = ['ServerStorage', 'Modules', 'Game', 'Garage']
PATHS = {
    'GarageServer': GARAGE + ['GarageServer'],
    'GarageCatalogLookup': GARAGE + ['GarageCatalogLookup'],
    'GarageCatalogService': GARAGE + ['GarageCatalogService'],
    'GarageClientProfile': GARAGE + ['GarageClientProfile'],
    'OwnedGarageDisplay': GARAGE + ['OwnedGarageDisplay'],
    'VehicleBuildService': GARAGE + ['VehicleBuildService'],
    'DriverSeatServer': ['ServerStorage', 'Modules', 'Game', 'Vehicles', 'DriverSeatServer'],
}


def T(text):
    """Leading `~` run -> tabs. Strips the first newline of a triple-quoted block."""
    if text.startswith('\n'):
        text = text[1:]
    return re.sub(r'(?m)^~+', lambda m: '\t' * len(m.group(0)), text)


HUNKS = []


def hunk(script, ident, title, before, after, why, piercer):
    HUNKS.append(dict(script=script, id=ident, title=title, before=T(before), after=T(after), why=why, piercer=piercer))


# --------------------------------------------------------------------------------------------- GarageServer

hunk('GarageServer', 'GS1', 'Require Core.FeatureFlags', '''
~local moduleUpgrades = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("Performance"):WaitForChild("VehicleModuleUpgradeRuntime"))
''', '''
~local moduleUpgrades = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("Performance"):WaitForChild("VehicleModuleUpgradeRuntime"))
~local FeatureFlags = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("FeatureFlags"))
''',
     'The category gate reads `Core.FeatureFlags`. The require form is the one `OwnedGarageManagement` already uses for the same module.',
     'Requiring the module has no effect by itself: its refresh loop starts only on the first `Get`/`IsEnabled` call, and that call is reached only for a category folder with a `FeatureFlag` attribute. PIERCER has none.')

hunk('GarageServer', 'GS2', 'Category flag helpers', '''
~local function defaultModuleIdsForCockpit(cockpit)
''', '''
~-- Exotic category (Stage A). A category folder may carry a FeatureFlag attribute naming a Core.FeatureFlags key.
~-- No attribute (Piercer) means always enabled. The flag gates the catalogue and new purchases, never owned vehicles.
~local function categoryFolderOf(item)
~~local current = item
~~while current and current.Parent ~= categoriesRoot do
~~~current = current.Parent
~~end
~~return current
~end

~local function categoryFlagEnabled(categoryFolder)
~~local flagKey = categoryFolder and categoryFolder:GetAttribute("FeatureFlag")
~~if typeof(flagKey) ~= "string" or flagKey == "" then return true end
~~return FeatureFlags.IsEnabled(flagKey, false)
~end

~local function defaultModuleIdsForCockpit(cockpit)
''',
     '`categoryFolderOf` finds the category folder that really holds a template (no first-child fallback). `categoryFlagEnabled` is the one definition of the gate; `GarageCatalogService` receives it through ctx (GS11) so the catalogue and both buy actions cannot disagree.',
     'New functions only. For a folder without a `FeatureFlag` string attribute `categoryFlagEnabled` returns true before touching `FeatureFlags`. PIERCER has no such attribute (capture and live check).')

hunk('GarageServer', 'GS3', 'Defaults by slot', '''
~~~Boost = garageServer_string(cockpit, "DefaultBoostModuleId", nil),
~~}
~end

~local function grantDefaultModulesForCurrentCockpit(profile)
''', '''
~~~Boost = garageServer_string(cockpit, "DefaultBoostModuleId", nil),
~~}
~end

~-- Exotic category (Stage A): default module per slot. The four legacy slots exactly as before. Any other
~-- SLOT_<Id> folder on the cockpit takes the cockpit attribute Default<Id>ModuleId when it is present; the second
~-- result marks those slots, which are granted once per vehicle.
~local function defaultSlotModuleIdsForCockpit(cockpit)
~~local defaults = defaultModuleIdsForCockpit(cockpit)
~~local slotDefaults = {
~~~Engine1 = defaults.Engine,
~~~Engine2 = defaults.RearEngine,
~~~Stabilisers = defaults.Stabilisers,
~~~Boost = defaults.Boost,
~~}
~~local optionalSlots = {}
~~local slotRoot = cockpit and cockpit:FindFirstChild("ModuleSlots", true)
~~if slotRoot then
~~~for _, slot in ipairs(slotRoot:GetChildren()) do
~~~~local slotId = string.match(slot.Name, "^SLOT_(.+)$")
~~~~if slotId and slotId ~= "Engine1" and slotId ~= "Engine2" and slotId ~= "Stabilisers" and slotId ~= "Boost" then
~~~~~local moduleId = garageServer_string(cockpit, "Default" .. slotId .. "ModuleId", nil)
~~~~~if moduleId then
~~~~~~slotDefaults[slotId] = moduleId
~~~~~~optionalSlots[slotId] = true
~~~~~end
~~~~end
~~~end
~~end
~~return slotDefaults, optionalSlots
~end

~local function grantDefaultModulesForCurrentCockpit(profile)
''',
     'One owner for the slot-to-default map, used by the grant (GS5) and by the purchase pre-check (GS7). The legacy table constructor is moved here unchanged. `defaultModuleIdsForCockpit` and `grantDefaultModulesForCurrentCockpit` are not edited.',
     'A new-slot entry needs a cockpit attribute `Default<SlotId>ModuleId` for a slot other than Engine1, Engine2, Stabilisers, Boost. Piercer slots are those four plus FrontBumper, RearBumper, RearSpoiler, SidePods, and no Piercer cockpit has `DefaultFrontBumperModuleId`, `DefaultRearBumperModuleId`, `DefaultRearSpoilerModuleId` or `DefaultSidePodsModuleId` (capture: the only `Default*ModuleId` names are the seven legacy ones; live check: none on any slot other than Stabilisers and Boost). So the map has the same four keys, built by the same constructor, and `optionalSlots` is empty.')

hunk('GarageServer', 'GS4', 'Grant-once guard helper', '''
attachDefaultModuleInstancesToCurrentVehicle = function(profile)
''', '''
~-- Exotic category (Stage A): true when the vehicle already received this default once (the instance may since
~-- have been moved to another vehicle). Uses the existing record fields TemplateId and GrantedForVehicleId.
~local function defaultAlreadyGrantedForVehicle(profile, vehicleId, moduleId)
~~for _, instance in pairs(profile.OwnedModuleInstances or {}) do
~~~if typeof(instance) == "table" and instance.GrantedForVehicleId ~= nil
~~~~and tostring(instance.GrantedForVehicleId) == tostring(vehicleId)
~~~~and tostring(instance.TemplateId or "") == tostring(moduleId) then
~~~~return true
~~~end
~~end
~~return false
~end
attachDefaultModuleInstancesToCurrentVehicle = function(profile)
''',
     'Closes the re-grant loop (gaps.md Q3) for the new-slot defaults without a new record field.',
     'New function only. It is called only for slots in `optionalSlots`, which is empty for Piercer (GS3).')

hunk('GarageServer', 'GS5', 'attachDefaultModuleInstancesToCurrentVehicle: use the shared map', '''
~~local defaults = defaultModuleIdsForCockpit(cockpit)
~~local slotDefaults = {
~~~Engine1 = defaults.Engine,
~~~Engine2 = defaults.RearEngine,
~~~Stabilisers = defaults.Stabilisers,
~~~Boost = defaults.Boost,
~~}
~~vehicle.InstalledModules = typeof(vehicle.InstalledModules) == "table" and vehicle.InstalledModules or {}
''', '''
~~local slotDefaults, optionalSlots = defaultSlotModuleIdsForCockpit(cockpit)
~~vehicle.InstalledModules = typeof(vehicle.InstalledModules) == "table" and vehicle.InstalledModules or {}
''',
     'The map now comes from GS3 so new-slot defaults are attached too.',
     'For a Piercer cockpit GS3 returns the table this code built inline before (same constructor, same four keys) and an empty `optionalSlots`.')

hunk('GarageServer', 'GS6', 'attachDefaultModuleInstancesToCurrentVehicle: grant new-slot defaults once', '''
~~~if moduleId and findModule(profile.CurrentCategory, moduleId) and not vehicle.InstalledModules[slotId] then
~~~~local moduleInstanceId = generateId("module")
''', '''
~~~local optional = optionalSlots[slotId] == true
~~~local granted = false
~~~if moduleId and findModule(profile.CurrentCategory, moduleId) and not vehicle.InstalledModules[slotId] and not (optional and defaultAlreadyGrantedForVehicle(profile, vehicleId, moduleId)) then
~~~~local moduleInstanceId = generateId("module")
''',
     'A new-slot default is created only when the slot is empty and this vehicle has not been given that template before.',
     'For the four legacy slots `optional` is false, so `not (optional and ...)` is true and the condition is the old one. Piercer has only legacy defaults.')

hunk('GarageServer', 'GS6b', 'attachDefaultModuleInstancesToCurrentVehicle: session mirrors follow a real grant', '''
~~~~vehicle.InstalledModules[slotId] = moduleInstanceId
~~~end
~~~if vehicleId == profile.CurrentVehicleId and moduleId then
~~~~profile.InstalledModules[slotId] = moduleId
~~~end
''', '''
~~~~vehicle.InstalledModules[slotId] = moduleInstanceId
~~~~granted = true
~~~~-- On a cockpit with new-slot defaults the session neon mirror may still hold the previously selected
~~~~-- vehicle's value for this slot. The granted instance owns no neon, so the mirror says so and the next
~~~~-- capture cannot copy the old value into it.
~~~~if next(optionalSlots) ~= nil then
~~~~~profile.NeonOwned = typeof(profile.NeonOwned) == "table" and profile.NeonOwned or {}
~~~~~profile.NeonOwned[slotId] = false
~~~~end
~~~end
~~~if vehicleId == profile.CurrentVehicleId and moduleId and (granted or not optional) then
~~~~profile.InstalledModules[slotId] = moduleId
~~~end
''',
     'Two things. (1) For a new slot the session mirror `profile.InstalledModules[slotId]` is written only when an instance was really attached, so a slot the player left empty, or filled with another part, is not shown as holding the default. (2) Review round 1, free neon: `buyCockpitInstance` does not reset the session mirror `profile.NeonOwned`, so after a purchase it still holds the previous vehicle\'s value per slot, and the next `GarageModuleInstanceCustomization.CaptureSlot` (through `CaptureAll` in `SetCockpitColor`, the cosmetic colour actions and the top of every `BuyModuleInstance`) copies `profile.NeonOwned[slotId] == true` into the instance now in that slot. With ten granted slots on an Exotic that would hand out neon worth 5000 to 9500 per slot without a debit. The mirror is therefore set to the granted record\'s own value (`NeonOwned = false`) for every slot granted on a cockpit that has new-slot defaults. The function always works on `profile.CurrentVehicleId`, so the mirror entry is the current vehicle\'s.',
     'For legacy slots `not optional` is true, so the second condition is the old `vehicleId == profile.CurrentVehicleId and moduleId`. The neon line needs `next(optionalSlots) ~= nil`, and `optionalSlots` is empty for every Piercer cockpit (GS3), so no Piercer reply gains or changes a `NeonOwned` key (golden step 02 included). The same inheritance on the four legacy slots of a Piercer exists today and is left as it is: see "Findings not fixed".')

hunk('GarageServer', 'GS7', 'buyCockpitInstance: validate before any mutation or debit', '''
~local function buyCockpitInstance(profile, args)
~~args = typeof(args) == "table" and args or {}
~~local requestedCategory = tostring(args.CategoryId or profile.CurrentCategory or "")
~~if requestedCategory ~= "" then profile.CurrentCategory = requestedCategory end
~~local cockpitId = tostring(args.CockpitId or "")
~~local cockpit = findCockpit(profile.CurrentCategory, cockpitId)
~~if not cockpit then
~~~return false, "Cockpit not found."
~~end
~~ensureInstanceInventory(profile)
~~if countGarageEntries(profile.Vehicles) >= profileGarageCapacity(profile) then
~~~return false, "Garage full. Buy more garage space to store more vehicles."
~~end
~~local price = garageServer_number(cockpit, "Price", 0)
~~if profile.Cash < price then
~~~return false, "Not enough cash."
~~end
~~MoneyService.Debit(profile, price, "CockpitInstance")
''', '''
~-- Exotic category (Stage A): every default module must exist and fit its slot before any money moves.
~local function cockpitDefaultsInstallable(categoryId, cockpit)
~~for slotId, moduleId in pairs((defaultSlotModuleIdsForCockpit(cockpit))) do
~~~local module = findModule(categoryId, moduleId)
~~~local mount = cockpit:FindFirstChild("SLOT_" .. tostring(slotId), true)
~~~if not module or not mount then return false end
~~~local slotType = garageServer_string(mount, "ModuleType", moduleTypeFromText(slotId))
~~~if slotType and slotType ~= "" and moduleTypeForModel(module) ~= slotType then return false end
~~~if not moduleFitsSlot(module, slotId, garageServer_string(mount, "AllowedModuleFolder", "")) then return false end
~~end
~~return true
~end
~local function buyCockpitInstance(profile, args)
~~args = typeof(args) == "table" and args or {}
~~local requestedCategory = tostring(args.CategoryId or profile.CurrentCategory or "")
~~local cockpitId = tostring(args.CockpitId or "")
~~local cockpit = findCockpit(requestedCategory ~= "" and requestedCategory or profile.CurrentCategory, cockpitId)
~~if not cockpit then
~~~return false, "Cockpit not found."
~~end
~~-- Nothing on the profile changes until every check has passed. The category that is written is the cockpit's own:
~~-- its CategoryId attribute, else the id of the category folder that holds it (the catalogue's rule). The request
~~-- string is only compared with it, never written.
~~local cockpitFolder = categoryFolderOf(cockpit)
~~local purchaseCategory = garageServer_string(cockpit, "CategoryId", nil) or (cockpitFolder and (garageServer_string(cockpitFolder, "CategoryId", nil) or slug(cockpitFolder.Name))) or ""
~~if args.CategoryId ~= nil and requestedCategory ~= "" and requestedCategory ~= purchaseCategory then
~~~return false, "Cockpit not found."
~~end
~~if not categoryFlagEnabled(cockpitFolder) then
~~~return false, "Vehicle unavailable."
~~end
~~ensureInstanceInventory(profile)
~~if countGarageEntries(profile.Vehicles) >= profileGarageCapacity(profile) then
~~~return false, "Garage full. Buy more garage space to store more vehicles."
~~end
~~local price = garageServer_number(cockpit, "Price", 0)
~~if profile.Cash < price then
~~~return false, "Not enough cash."
~~end
~~if not cockpitDefaultsInstallable(purchaseCategory ~= "" and purchaseCategory or profile.CurrentCategory, cockpit) then
~~~return false, "Vehicle unavailable."
~~end
~~if purchaseCategory ~= "" then profile.CurrentCategory = purchaseCategory end
~~MoneyService.Debit(profile, price, "CockpitInstance")
''',
     'Order now: find the cockpit (no profile write); category sent by the client must equal the cockpit\'s own category; flag; capacity; cash; default pre-check; only then `CurrentCategory`, debit, vehicle, defaults. Fixes the session corruption after a failed cross-category buy (economy.md R1), the saved arbitrary `CategoryId` (R7) and the debit before a broken default (R10). The slot checks in `cockpitDefaultsInstallable` are the same three rules as `instanceFits` (553-560), applied to the cockpit template. Everything after the debit is unchanged. Review round 1: the written category never falls back to the request string. A cockpit authored without a `CategoryId` attribute takes the id of the category folder that holds it, by the rule `GarageCatalogService` uses for the catalogue (`CategoryId` attribute of the folder, else `slug(folder.Name)`), and a sent `CategoryId` is compared with that value. Before this fix such a cockpit skipped the comparison and saved the client\'s string (R7 again).',
     'Golden steps 02, 09, 11 send `CategoryId="bruiser"`. Step 11 (`CockpitId="nope"`): `findCockpit("bruiser","nope")` is nil in both versions, reply "Cockpit not found.", and `ensureInstanceInventory` is not reached in either. Step 09 (`bruiser_06`): cockpit found; its `CategoryId` attribute is "bruiser" (all six Piercer cockpits, capture) and equals the request; PIERCER has no `FeatureFlag`; then the same `ensureInstanceInventory`, capacity check and cash check in the same order give "Not enough cash.". Step 02 (`bruiser_01`): same path, then the pre-check passes (live check: all 24 Piercer legacy defaults exist, their `SLOT_` folders exist, type and fit match), then `CurrentCategory = "bruiser"` exactly as the old line wrote it, then the unchanged debit and grants. The reply profile is the same because in every failing case `CurrentCategory` was already "bruiser". The mismatch branch needs a request category different from the cockpit\'s own category; the folder-id branch needs a cockpit without a `CategoryId` attribute; the flag branch needs a `FeatureFlag` attribute; the "Vehicle unavailable." pre-check branch needs a default whose template or slot is missing or does not fit. Piercer data has none of these: `purchaseCategory` is "bruiser" from the cockpit attribute, the value the old line wrote.')

hunk('GarageServer', 'GS8', 'coreSlotRequired: FrontBody and RearBody', '''
~~if slotId=="Stabilisers" or slotId=="Boost" then return true end
''', '''
~~if slotId=="Stabilisers" or slotId=="Boost" then return true end
~~if slotId=="FrontBody" or slotId=="RearBody" then local _,_,mount=vehicleModuleContext(profile,vehicleId,slotId); return mount~=nil end
''',
     'A body slot cannot be left empty by a module move when the cockpit has that slot (INTERFACE "coreSlotRequired").',
     'The branch needs `slotId` "FrontBody" or "RearBody". The hook is called with the source slot of a moved instance, and a Piercer vehicle cannot hold an instance in those slots because `instanceFits` rejects them ("Slot not found on this cockpit."). Even with such a key in a damaged save, the Piercer cockpit has no `SLOT_FrontBody`/`SLOT_RearBody`, so `mount` is nil and the result is `false`, the old value.')

hunk('GarageServer', 'GS9', 'buyModuleInstance: vehicle category, then flag', '''
~~local module=findModule(profile.CurrentCategory,moduleId); if not module then return false,"Module not found." end
''', '''
~~local targetVehicle=profile.Vehicles and profile.Vehicles[vehicleId]
~~local module=findModule(typeof(targetVehicle)=="table" and targetVehicle.CategoryId or profile.CurrentCategory,moduleId); if not module then return false,"Module not found." end
~~if not categoryFlagEnabled(categoryFolderOf(module)) then return false,"Module unavailable." end
''',
     'The module template and price come from the target vehicle\'s category (economy.md R12), the same expression `instanceFits` uses (`vehicle.CategoryId or profile.CurrentCategory`). A flagged-off category refuses the buy.',
     'With an unknown vehicle id, or a vehicle without `CategoryId`, the lookup category is `profile.CurrentCategory` as before. For a Piercer vehicle `CategoryId` is "bruiser"; with only PIERCER present every category value resolves to PIERCER, and with EXOTIC present the client sends `VehicleId = CurrentVehicleId`, whose category is `CurrentCategory` (set by `syncLegacyFromCurrentVehicle`). So the same template is found, "Module not found." stays first, and the lock and fit checks follow in the old order. The flag branch needs a `FeatureFlag` attribute on the module\'s category folder; PIERCER has none.')

hunk('GarageServer', 'GS10a', 'vehicleSummaries: warn-once helper', '''
~local function vehicleSummaries(profile,summaryPlayer)
''', '''
~-- Exotic category (Stage A): an owned vehicle whose cockpit template is missing or not V2 materialised is left
~-- out of the summaries with one warning per template, instead of failing every garage reply.
~local missingCockpitTemplateWarned = {}
~local function warnMissingCockpitTemplate(vehicleId, categoryId, cockpitId)
~~local key = tostring(categoryId) .. "/" .. tostring(cockpitId)
~~if missingCockpitTemplateWarned[key] then return end
~~missingCockpitTemplateWarned[key] = true
~~warn("[GarageServer] Vehicle summary skipped for " .. tostring(vehicleId) .. ": cockpit template " .. key .. " is missing or not V2 materialised.")
~end
~-- An installed module whose template is missing is left out of the stats (totalStats and CalculateProfile skip
~-- it). Each category/module pair is looked up here once per server, and a missing one is reported once.
~local moduleTemplateChecked = {}
~local function warnMissingModuleTemplates(vehicleId, profile)
~~for slotId, moduleId in pairs(profile.InstalledModules or {}) do
~~~local key = tostring(profile.CurrentCategory) .. "/" .. tostring(moduleId)
~~~if not moduleTemplateChecked[key] then
~~~~moduleTemplateChecked[key] = true
~~~~if not findModule(profile.CurrentCategory, moduleId) then
~~~~~warn("[GarageServer] Vehicle summary for " .. tostring(vehicleId) .. ": module template " .. key .. " (slot " .. tostring(slotId) .. ") is missing; the module is skipped.")
~~~~end
~~~end
~~end
~end
~local function vehicleSummaries(profile,summaryPlayer)
''',
     'Support for GS10b. Warns once per category/cockpit pair per server so a broken template cannot flood the log. Review round 1: INTERFACE also asks for a `warn` when a module template of an owned vehicle is missing. `warnMissingModuleTemplates` gives it. It runs in `vehicleSummaries` right after `syncLegacyFromCurrentVehicle`, where `profile.InstalledModules` is exactly that vehicle\'s installed templates (the session mirror elsewhere can hold another vehicle\'s entries after a purchase and would warn falsely, so `GarageClientProfile.totalStats` is not the place). Templates do not change while a server runs, so each category/module pair costs one `findModule` call per server, then a table lookup.',
     'New functions only; called only from GS10b. `warnMissingModuleTemplates` reads the profile and writes nothing to it. Every module template installed on a Piercer vehicle exists, so it never warns; a `warn` is not part of any reply.')

hunk('GarageServer', 'GS10b', 'vehicleSummaries: skip a vehicle without a usable cockpit template', '''
~~~~~local cockpit = findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
~~~~~local performance = moduleUpgrades.CalculateProfile(
''', '''
~~~~~local cockpit = findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
~~~~~if not (cockpit and cockpit:GetAttribute("V2Materialised") == true) then
~~~~~~warnMissingCockpitTemplate(vehicleId, profile.CurrentCategory, profile.CurrentCockpit)
~~~~~~continue
~~~~~end
~~~~~warnMissingModuleTemplates(vehicleId, profile)
~~~~~local performance = moduleUpgrades.CalculateProfile(
''',
     '`CalculateProfile` asserts exactly this condition (`VehicleModuleUpgradeRuntime` 106). Today a missing template throws and every garage request for that player fails (economy.md R3). The `continue` skips only this vehicle; `restoreProfileSelection` after the loop still runs. Missing module templates already do not throw (`CalculateProfile` and `totalStats` both test `if module then`); the new call only adds the `warn` INTERFACE asks for (GS10a).',
     'The branch needs an owned vehicle whose cockpit template is absent or lacks `V2Materialised=true`. All six Piercer cockpits exist with `V2Materialised=true` (capture and live check), so the guard is false and the old lines run unchanged. The added call changes nothing on the profile and warns only for a module template that is missing; Piercer has none.')

hunk('GarageServer', 'GS11', 'Pass the gate to GarageCatalogService', '''
({PREVIEW_POS = PREVIEW_POS, categoriesRoot = categoriesRoot, cosmeticCatalog = cosmeticCatalog, findSourceCockpit = findSourceCockpit,''', '''
({PREVIEW_POS = PREVIEW_POS, categoriesRoot = categoriesRoot, categoryFlagEnabled = categoryFlagEnabled, cosmeticCatalog = cosmeticCatalog, findSourceCockpit = findSourceCockpit,''',
     'One gate definition for the catalogue and the buy actions.',
     'Adds one ctx field. `GarageCatalogService` uses it as described in GC4 and GC5.')

# -------------------------------------------------------------------------------------- GarageCatalogLookup

hunk('GarageCatalogLookup', 'GL1', 'findSourceCockpit: module category first (line 97)', '''
~~return sourceCockpitId, findCockpit(profile and profile.CurrentCategory or "bruiser", sourceCockpitId)
''', '''
~~return sourceCockpitId, findCockpit(garageServer_string(module, "CategoryId", nil) or (profile and profile.CurrentCategory or "bruiser"), sourceCockpitId)
''',
     'The source cockpit of a module is in the module\'s own category. With `profile == nil` (the catalogue builder) an Exotic module was looked up in "bruiser" and its `SourceCockpitDisplayName` became the raw id.',
     'All 116 Piercer modules have `CategoryId="bruiser"` (capture and live check). `findCockpit("bruiser", id)` resolves the PIERCER folder by its `CategoryId` attribute. The old argument was "bruiser" (nil profile) or `profile.CurrentCategory`, which for a Piercer module is "bruiser" or, with one category, falls back to the first child PIERCER. Same folder, same cockpit. A module without the attribute uses the old expression.')

hunk('GarageCatalogLookup', 'GL2', 'modulePurchasePrice: module category (line 123)', '''
~~local cockpit = sourceCockpitId and findCockpit("bruiser", sourceCockpitId)
''', '''
~~local cockpit = sourceCockpitId and findCockpit(garageServer_string(module, "CategoryId", "bruiser"), sourceCockpitId)
''',
     'The 12 percent fallback price must use the source cockpit in the module\'s own category (economy.md R5).',
     'Piercer modules carry `CategoryId="bruiser"`, the old literal; a module without the attribute falls back to "bruiser". This line is reached only when the module has no positive `ExtraCopyPrice`/`ModuleCopyPrice`/`PurchasePrice`/`Price`.')

hunk('GarageCatalogLookup', 'GL3', 'moduleLockedMessage: module category (line 131)', '''
~~local cockpit = sourceCockpitId and findCockpit(profile.CurrentCategory, sourceCockpitId)
''', '''
~~local cockpit = sourceCockpitId and findCockpit(garageServer_string(module, "CategoryId", profile.CurrentCategory), sourceCockpitId)
''',
     'Not listed in INTERFACE.md (see "Additions beyond INTERFACE.md"). GS9 lets `buyModuleInstance` resolve a module in a category other than `profile.CurrentCategory`; without this line the lock message for such a module would name the raw cockpit id instead of its display name.',
     'Piercer modules carry `CategoryId="bruiser"`. `findCockpit("bruiser", id)` and the old `findCockpit(profile.CurrentCategory, id)` return the same Piercer cockpit whenever the old call found one (with one category every value resolves to PIERCER; with two, the old call found it only when `CurrentCategory` resolved to PIERCER). The message text is unchanged. A module without the attribute uses `profile.CurrentCategory` as before.')

# ------------------------------------------------------------------------------------- GarageCatalogService

hunk('GarageCatalogService', 'GC1', 'ctx: categoryFlagEnabled', '''
~local categoriesRoot = ctx.categoriesRoot
''', '''
~local categoriesRoot = ctx.categoriesRoot
~-- The gate is owned by GarageServer (categoryFlagEnabled). If this module ever runs under a GarageServer that
~-- does not pass it, a category without a FeatureFlag (Piercer) stays listed and a flagged one stays hidden.
~local categoryFlagEnabled = ctx.categoryFlagEnabled
~if categoryFlagEnabled == nil then
~~warn("[GarageCatalogService] ctx.categoryFlagEnabled is missing; flagged categories are hidden.")
~~categoryFlagEnabled = function(categoryFolder)
~~~local flagKey = categoryFolder:GetAttribute("FeatureFlag")
~~~return typeof(flagKey) ~= "string" or flagKey == ""
~~end
~end
''',
     'Receives the gate defined in `GarageServer` (GS2, GS11). Review round 1: the gate is called without a nil test in GC4 and GC5, so this source installed or rolled back out of step with `GarageServer` (no GS11) would throw "attempt to call a nil value" in every `GetInitial`, Piercer included. With the gate missing, the module now warns once at start-up and treats every flagged category as off: the Piercer catalogue is unchanged and nothing unapproved is listed. It does not read `Core.FeatureFlags` itself, so there is still one definition of the flag read.',
     'With the shipped `GarageServer` (GS11) the ctx field is a function, so the branch is not entered and the local is the same value as before. Without it, a folder with no `FeatureFlag` string attribute (PIERCER) returns true, as `GarageServer.categoryFlagEnabled` does.')

hunk('GarageCatalogService', 'GC2', 'Slot record: RailLabel when present', '''
~~~~~~Order = garageServer_number(slot, "Order", #slots + 1),
''', '''
~~~~~~Order = garageServer_number(slot, "Order", #slots + 1),
~~~~~~RailLabel = garageServer_string(slot, "RailLabel", nil),
''',
     'Sends the slot folder attribute `RailLabel` to the client as slot field `RailLabel`.',
     '`garageServer_string` returns nil unless the slot has a non-empty string attribute (or a ValueBase child) named `RailLabel`. A nil field in a table constructor creates no key, so the Piercer slot records have the same six keys and the payload is byte-identical. No Piercer slot folder has the attribute; their only child is `Mount_DoNotRename` (capture).')

hunk('GarageCatalogService', 'GC3', 'Module record: CardTitle when present', '''
~~~DisplayName = garageServer_string(item, "DisplayName", garageServer_string(item, "ModuleName", item.Name)),
''', '''
~~~DisplayName = garageServer_string(item, "DisplayName", garageServer_string(item, "ModuleName", item.Name)),
~~~CardTitle = garageServer_string(item, "CardTitle", nil),
''',
     'Sends the module attribute `CardTitle` to the client as module field `CardTitle`.',
     'Same rule as GC2: nil creates no key. None of the 116 Piercer modules has a `CardTitle` attribute or a child of that name (capture and live check).')

hunk('GarageCatalogService', 'GC4', 'Catalogue build: leave out a flagged-off category', '''
~~~if categoryFolder:IsA("Folder") or categoryFolder:IsA("Model") then
''', '''
~~~if (categoryFolder:IsA("Folder") or categoryFolder:IsA("Model")) and categoryFlagEnabled(categoryFolder) then
''',
     'A category whose `FeatureFlag` key is not enabled is not sent to clients.',
     '`categoryFlagEnabled` returns true for a folder without a `FeatureFlag` attribute, so PIERCER passes and the rest of the loop body is unchanged.')

hunk('GarageCatalogService', 'GC5', 'Catalogue snapshot: rebuild when a category flag flips', '''
~local catalogueSnapshot
~local catalogueRevision=game:GetService("HttpService"):GenerateGUID(false)
''', '''
~-- Exotic category (Stage A): flagged categories are part of the snapshot, so a flag flip rebuilds it under a new
~-- revision. With no FeatureFlag attribute on any category the state is always "" and nothing ever rebuilds.
~local function categoryFlagState()
~~local flagState = ""
~~for _, categoryFolder in ipairs(categoriesRoot:GetChildren()) do
~~~local flagKey = categoryFolder:GetAttribute("FeatureFlag")
~~~if typeof(flagKey) == "string" and flagKey ~= "" then
~~~~flagState ..= flagKey .. (categoryFlagEnabled(categoryFolder) and "=1;" or "=0;")
~~~end
~~end
~~return flagState
~end
~local catalogueSnapshot
~local catalogueFlagState
~local catalogueRevision=game:GetService("HttpService"):GenerateGUID(false)
''',
     'Not in INTERFACE.md (see "Additions beyond INTERFACE.md"). The snapshot is cached for the life of the server (economy.md R15). Without this a flag turned off at run time would keep the category in the catalogue, and a flag turned on would allow buys of a category no client can see.',
     'New function and one new local. For Piercer only, the loop finds no `FeatureFlag` attribute, never calls `categoryFlagEnabled` and returns "".')

hunk('GarageCatalogService', 'GC5b', 'garageServer_catalog: compare the flag state', '''
~~if not catalogueSnapshot then catalogueSnapshot=freezeCatalogue(garageServer_buildCatalog()) end
''', '''
~~local flagState=categoryFlagState()
~~if catalogueSnapshot and flagState~=catalogueFlagState then catalogueSnapshot=nil; catalogueRevision=game:GetService("HttpService"):GenerateGUID(false) end
~~if not catalogueSnapshot then catalogueSnapshot=freezeCatalogue(garageServer_buildCatalog()); catalogueFlagState=flagState end
''',
     'Drops the snapshot and issues a new revision when the on/off state of a flagged category differs from the state the snapshot was built with. Feature flag reads never yield, so the state and the build are consistent.',
     'With no flagged category `flagState` is "" on every call and equals the stored "" after the first build, so the snapshot is built once and `catalogueRevision` keeps its start-up GUID, exactly as before (golden step 18 still gets a nil catalogue for a known revision).')

# --------------------------------------------------------------------------------------- GarageClientProfile

hunk('GarageClientProfile', 'CP1', 'profileForClient: Performance helper', '''
~local function profileForClient(profile)
''', '''
~-- Exotic category (Stage A): when the current cockpit template is missing or not V2 materialised the reply has
~-- no Performance block and the server warns once, instead of the CalculateProfile assert failing every reply.
~local missingCockpitTemplateWarned = {}
~local function currentPerformance(profile)
~~local totals = totalStats(profile)
~~local cockpit = findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
~~if not (cockpit and cockpit:GetAttribute("V2Materialised") == true) then
~~~local key = tostring(profile.CurrentCategory) .. "/" .. tostring(profile.CurrentCockpit)
~~~if not missingCockpitTemplateWarned[key] then
~~~~missingCockpitTemplateWarned[key] = true
~~~~warn("[GarageClientProfile] Performance omitted: cockpit template " .. key .. " is missing or not V2 materialised.")
~~~end
~~~return nil
~~end
~~return moduleUpgrades.CalculateProfile(profile._Player, profile, totals, cockpit, findModule, moduleTypeForModel)
~end

~local function profileForClient(profile)
''',
     'Needed for the missing-template rule: `vehicleSummaries` (GS10b) covers the per-vehicle loop, but this call for the current selection asserts the same condition and would still fail every reply.',
     'New function. `totalStats` then `findCockpit` then `CalculateProfile` run in the same order as the old inline argument list.')

hunk('GarageClientProfile', 'CP2', 'profileForClient: use the helper', '''
~~~Performance = moduleUpgrades.CalculateProfile(
~~~~profile._Player,
~~~~profile,
~~~~totalStats(profile),
~~~~findCockpit(profile.CurrentCategory, profile.CurrentCockpit),
~~~~findModule,
~~~~moduleTypeForModel
~~~),
''', '''
~~~Performance = currentPerformance(profile),
''',
     'See CP1.',
     'The guard needs a current cockpit that is absent or not `V2Materialised`. For Piercer the current cockpit is an owned Piercer cockpit or the default `bruiser_01`; all six exist with `V2Materialised=true`. The same `CalculateProfile` call then runs with the same six arguments and its result fills `Performance` at the same place in the reply.')

# ---------------------------------------------------------------------------------------- OwnedGarageDisplay

hunk('OwnedGarageDisplay', 'OD1', 'categoryFolder: match the CategoryId attribute first', '''
~for _,child in ipairs(categories:GetChildren()) do if string.lower(child.Name)==wanted then return child end end
''', '''
~for _,child in ipairs(categories:GetChildren()) do local id=child:GetAttribute("CategoryId"); if type(id)=="string" and id~="" and string.lower(id)==wanted then return child end end
~for _,child in ipairs(categories:GetChildren()) do if string.lower(child.Name)==wanted then return child end end
''',
     'A saved vehicle carries the category id ("bruiser", "exotic"), not the folder name. Today "bruiser" matches no folder name and works only through the first-child fallback (economy.md R8). Review round 1: only a non-empty string attribute can match. The first form compared `tostring(attribute or "")`, so an empty `categoryId` matched any folder without the attribute, where the old code went to the fallback.',
     'For "bruiser" (or a nil id, which becomes "bruiser") the new first loop returns PIERCER, the folder the old code reached through `FindFirstChild("BRUISER") or categories:GetChildren()[1]`. A value that matches no `CategoryId` attribute, the empty string included, falls through to the unchanged name loop and fallback. Same folder in every Piercer case.')

# --------------------------------------------------------------------------------------- VehicleBuildService

hunk('VehicleBuildService', 'VB1', 'addPassengerSeat: comment', '''
~-- Offset comes from ReplicatedStorage.Config.Activities.Passengers SeatOffsetX/Y/Z (default 0, 1.45, 11).
''', '''
~-- Offset comes from ReplicatedStorage.Config.Activities.Passengers SeatOffsetX/Y/Z (default 0, 1.45, 11).
~-- A cockpit may override an axis with the attribute PassengerSeatOffsetX/Y/Z (root local space).
''',
     'Documents VB2.',
     'Comment only.')

hunk('VehicleBuildService', 'VB2', 'addPassengerSeat: per-cockpit offset', '''
~~local function offset(key, fallback)
~~~local value = tonumber(config and config:GetAttribute(key))
~~~if value == nil or value ~= value then return fallback end
~~~return math.clamp(value, -40, 40)
~~end
''', '''
~~local function offset(key, fallback, cockpitKey)
~~~local value = vehicle:GetAttribute(cockpitKey)
~~~if typeof(value) ~= "number" or value ~= value then value = tonumber(config and config:GetAttribute(key)) end
~~~if value == nil or value ~= value then return fallback end
~~~return math.clamp(value, -40, 40)
~~end
''',
     'The spawned vehicle is a clone of the cockpit template, so it carries the cockpit\'s attributes. A numeric `PassengerSeatOffsetX/Y/Z` wins for that axis; the same clamp applies.',
     'Piercer cockpits have no `PassengerSeatOffset*` attribute (capture and live check), so `value` is nil, the old `tonumber(config ...)` line runs and the rest is unchanged.')

hunk('VehicleBuildService', 'VB3', 'addPassengerSeat: pass the attribute names', '''
~~seat.CFrame = root.CFrame * CFrame.new(offset("SeatOffsetX", 0), offset("SeatOffsetY", 1.45), offset("SeatOffsetZ", 11))
''', '''
~~seat.CFrame = root.CFrame * CFrame.new(offset("SeatOffsetX", 0, "PassengerSeatOffsetX"), offset("SeatOffsetY", 1.45, "PassengerSeatOffsetY"), offset("SeatOffsetZ", 11, "PassengerSeatOffsetZ"))
''',
     'See VB2.',
     'Same three calls in the same order; the third argument only names an attribute that Piercer lacks.')

# ------------------------------------------------------------------------------------------ DriverSeatServer

hunk('DriverSeatServer', 'DS1', 'getOffset: per-cockpit offset', '''
local function getOffset()
~local config = getConfig()
~return Vector3.new(
~~readValue(config, "LocalX", 0),
~~readValue(config, "LocalY", 1.45),
~~readValue(config, "LocalZ", 7)
~)
end
''', '''
-- A cockpit may carry DriverSeatOffsetX/Y/Z (root local space); the spawned vehicle is a clone of it. An axis
-- without a numeric attribute uses the global Config.Vehicles.DriverSeat value as before.
local function getOffset(vehicle)
~local config = getConfig()
~local function axis(attributeName, valueName, fallback)
~~local override = vehicle and vehicle:GetAttribute(attributeName)
~~if typeof(override) == "number" and override == override then return override end
~~return readValue(config, valueName, fallback)
~end
~return Vector3.new(
~~axis("DriverSeatOffsetX", "LocalX", 0),
~~axis("DriverSeatOffsetY", "LocalY", 1.45),
~~axis("DriverSeatOffsetZ", "LocalZ", 7)
~)
end
''',
     'Per-cockpit driver seat offset (gaps.md C6, Q1).',
     'Piercer cockpits have no `DriverSeatOffset*` attribute (capture and live check), so each axis returns the same `readValue(config, ...)` as before.')

hunk('DriverSeatServer', 'DS2', 'applySeatPosition: pass the vehicle', '''
~local offset = getOffset()
''', '''
~local offset = getOffset(vehicle)
''',
     'See DS1.',
     'Same call, with the vehicle that `applySeatPosition` already holds.')


def manifest_row(path):
    capture = json.loads((ROOT / CAPTURE).read_text(encoding='utf8'))
    rows = [r for r in capture['manifest'] if r['path_parts'] == path]
    assert len(rows) == 1, path
    return rows[0]


def main():
    (HERE / 'after').mkdir(exist_ok=True)
    ops, report = [], []
    for name, path in PATHS.items():
        row = manifest_row(path)
        before = (ROOT / row['file']).read_bytes()
        assert hashlib.sha256(before).hexdigest() == row['source_sha256'], name
        original = before.decode('utf8')
        text = original
        assert '\r' not in text
        mine = [h for h in HUNKS if h['script'] == name]
        assert mine, name
        for h in mine:
            assert h['after'].isascii(), h['id']
            assert original.count(h['before']) == 1, '%s: before text occurs %d times in the blob' % (h['id'], original.count(h['before']))
            assert text.count(h['before']) == 1, '%s: before text occurs %d times' % (h['id'], text.count(h['before']))
            h['before_line'] = original[:original.index(h['before'])].count('\n') + 1
            text = text.replace(h['before'], h['after'])
        out = HERE / 'after' / (name + '.lua')
        out.write_bytes(text.encode('utf8'))
        ops.append(dict(kind='source', path=path, file='%s/after/%s.lua' % (REL, name)))
        report.append((name, path, row, len(before), len(text.encode('utf8')), mine))
    (HERE / 'ops.json').write_bytes((json.dumps(ops, indent=1) + '\n').encode('utf8'))
    test_sources = dict(before={name: row['file'] for name, _, row, _, _, _ in report},
                        after={name: '%s/after/%s.lua' % (REL, name) for name, _, _, _, _, _ in report},
                        tests='%s/tests.lua' % REL)
    (HERE / 'test_sources.json').write_bytes((json.dumps(test_sources, indent=1) + '\n').encode('utf8'))
    write_changes(report)
    for name, _, _, a, b, mine in report:
        print('%-22s %6d -> %6d bytes, %d hunks' % (name, a, b, len(mine)))


def fence(text):
    return '```lua\n' + text.rstrip('\n') + '\n```\n'


def write_changes(report):
    out = []
    out.append('# Exotic category, Stage A: server source changes\n')
    out.append('Generated by `%s/build.py` from the hunks it applies. Do not edit by hand.\n' % REL)
    out.append('Before-sources: the blobs named in `%s` (SHA-256 checked by the build). '
               'Each `before` text occurs exactly once in its blob. Line numbers are lines of the before-source.\n' % CAPTURE)
    out.append('Indentation in the blocks below is tabs, as in the sources.\n')
    out.append('## Files\n')
    out.append('| Script | Before blob | Bytes before | Bytes after | Hunks |')
    out.append('|---|---|---:|---:|---|')
    for name, path, row, a, b, mine in report:
        out.append('| `%s` | `%s` | %d | %d | %s |' % ('.'.join(path), row['file'].split('/')[-1][:16] + '...', a, b, ', '.join(h['id'] for h in mine)))
    out.append('')
    out.append('## What Piercer lacks\n')
    out.append('Every new branch is reached only through data in this table. Checked in the capture hierarchy and live (read-only) on 2026-10-02.\n')
    out.append('| Data | Where a new branch needs it | Piercer today |')
    out.append('|---|---|---|')
    out.append('| `FeatureFlag` attribute on a category folder | GS2, GS7, GS9, GC4, GC5 | PIERCER has `CategoryId`, `Description`, `DisplayName`, `ModuleCompatibility` only |')
    out.append('| `Default<SlotId>ModuleId` for a slot other than the four legacy ones | GS3, GS5, GS6, GS6b (grant-once guard, mirror write, neon mirror reset) | Only the seven legacy names exist on the six cockpits |')
    out.append('| `SLOT_FrontBody` / `SLOT_RearBody` | GS8 | Eight slots, neither of these |')
    out.append('| A default whose template or slot is missing or does not fit | GS7 ("Vehicle unavailable.") | All 24 legacy defaults exist and fit (live check) |')
    out.append('| Request `CategoryId` different from the cockpit\'s own category | GS7 ("Cockpit not found.") | The client sends the catalogue value "bruiser"; all six cockpits carry "bruiser" |')
    out.append('| A cockpit without a `CategoryId` attribute | GS7 (category taken from the category folder) | All six cockpits carry `CategoryId="bruiser"` (capture and live test) |')
    out.append('| Module `CategoryId` other than "bruiser" | GL1, GL2, GL3 | All 116 modules carry "bruiser" |')
    out.append('| `RailLabel` on a slot folder, `CardTitle` on a module | GC2, GC3 | None |')
    out.append('| Owned vehicle or current selection without a `V2Materialised` cockpit template | GS10b, CP1 | All six cockpits exist with `V2Materialised=true` |')
    out.append('| Owned vehicle with an installed module whose template is missing | GS10a (`warn`) | All 116 module templates exist |')
    out.append('| `GarageCatalogService` built without `ctx.categoryFlagEnabled` | GC1 (default gate and `warn`) | The shipped `GarageServer` passes it (GS11; test "GS11 wiring") |')
    out.append('| `DriverSeatOffsetX/Y/Z`, `PassengerSeatOffsetX/Y/Z` on a cockpit | DS1, VB2 | None |')
    out.append('')
    out.append('## Differences that are intended\n')
    out.append('None of these is reachable with the shipped client and today\'s Piercer data. They are listed so a reviewer does not have to find them.\n')
    out.append('| Request or state | Before | After | Hunk |')
    out.append('|---|---|---|---|')
    out.append('| `BuyCockpitInstance` with a `CategoryId` that is not the cockpit\'s own (for example "zzz", "PIERCER") and a Piercer `CockpitId` | Bought; vehicle saved with that string as `CategoryId` | `false, "Cockpit not found."`, nothing changed | GS7 |')
    out.append('| Any failed `BuyCockpitInstance` | `profile.CurrentCategory` already overwritten with the requested string | Profile untouched | GS7 |')
    out.append('| `BuyCockpitInstance` without `CategoryId` | Vehicle saved with the session `CurrentCategory` string | Vehicle saved with the cockpit\'s own category (the same value unless the session string was not a real id) | GS7 |')
    out.append('| `BuyCockpitInstance` for a cockpit that has no `CategoryId` attribute | Vehicle saved with the request string, or the session string | Vehicle saved with the id of the category folder that holds the cockpit; a sent `CategoryId` must equal it, else `false, "Cockpit not found."` | GS7 |')
    out.append('| A cockpit whose default module template or slot is missing or unfit | Sold; that default silently not attached | `false, "Vehicle unavailable."` before the debit | GS7 |')
    out.append('| `BuyModuleInstance` for a vehicle of another category than the session\'s current one | "Module not found." | Module resolved in that vehicle\'s category | GS9 |')
    out.append('| Owned vehicle, or current selection, whose cockpit template is missing or not `V2Materialised` | Every garage reply failed with "Garage server action failed. Please try again." | Vehicle left out of `VehicleSummaries`; `Performance` omitted for the current selection; one `warn` | GS10b, CP1 |')
    out.append('| Owned vehicle with an installed module whose template is missing | Module left out of the stats, nothing logged | Module left out of the stats, one `warn` per category/module pair per server | GS10a, GS10b |')
    out.append('| `OwnedGarageDisplay` when PIERCER is not the first child of `Categories` | "bruiser" resolved to whichever folder was first | "bruiser" resolves to the folder with `CategoryId="bruiser"` | OD1 |')
    out.append('')
    out.append('## Additions beyond INTERFACE.md\n')
    out.append('Each is opt-in or unreachable with Piercer data. The integrator and the `delivery-reviewer` accept or drop each one before APPLY.\n')
    out.append('| Hunk | Addition | Why |')
    out.append('|---|---|---|')
    out.append('| GL3 | `moduleLockedMessage` looks the source cockpit up in the module\'s own category | GS9 can resolve a module outside `profile.CurrentCategory`; the lock message would otherwise show the raw cockpit id |')
    out.append('| GC5, GC5b | The cached catalogue is rebuilt under a new revision when the on/off state of a flagged category changes | The snapshot is cached for the life of the server. In production the first flag read comes before the ConfigService snapshot and returns the default (off), so without the rebuild a category could never appear |')
    out.append('| GS1, GS11, GC1 | `GarageServer` passes one gate function to `GarageCatalogService`. If the field is missing the service warns once and hides every flagged category (review round 1) | One definition of the flag read; an out-of-step install or rollback of the two sources cannot break `GetInitial` for Piercer |')
    out.append('| GS7 | A sent `CategoryId` that is not the cockpit\'s own category gets `"Cockpit not found."`; a cockpit without the attribute takes its category folder\'s id (review round 1) | INTERFACE step (2) fixes the rule but not the reply text or the no-attribute case |')
    out.append('| GS6b | On a cockpit with new-slot defaults, a granted slot\'s `profile.NeonOwned` mirror entry is set to false (review round 1) | Closes free neon on the granted Exotic defaults. No new field; Piercer cockpits never take the branch |')
    out.append('')
    out.append('## Findings not fixed\n')
    out.append('Out of scope under INTERFACE "Not in scope", or a contract decision. Each exists in the before-source unless stated.\n')
    out.append('| Finding | Why it is left |')
    out.append('|---|---|')
    out.append('| Neon inheritance on the four legacy slots of a Piercer. After `BuyCockpitInstance` the session mirror `profile.NeonOwned` still holds the previously selected vehicle\'s values, and the next `CaptureAll` copies them into the new vehicle\'s default engine, stabiliser and boost instances (live Piercer engines have buyable neon, `NeonPrice` 5000). | Fixing it changes the `NeonOwned` block of a Piercer `BuyCockpitInstance` reply. The fix is to drop the `next(optionalSlots) ~= nil` test in GS6b, once approved. |')
    out.append('| Root cause of the above: `buyCockpitInstance` never resyncs the session mirror (`InstalledModules`, `ModuleColors`, `NeonOwned`) to the new vehicle. Entries for slots the new cockpit has no default for stay, and the previous vehicle\'s module colours are captured into the new instances (colours are free). After an Exotic then a Piercer purchase the reply lists `FrontBody` / `RearBody` Exotic ids in `InstalledModules` under `CurrentCategory="bruiser"` until the next select. Server code skips them (`findModule` is nil). | The clean fix is `syncLegacyFromCurrentVehicle` at the end of the purchase, which changes Piercer replies. The client areas should tolerate the extra keys. |')
    out.append('| Legacy-slot re-grant loop (gaps.md Q3): an emptied Engine1/Engine2/Stabilisers/Boost slot is refilled with a new free default on the next select. It now applies to Exotic vehicles too. | INTERFACE: "Legacy-slot grant logic is unchanged". |')
    out.append('| Flag off for a player who owns an Exotic: the category is not in the catalogue (INTERFACE), so the garage UI has no slots, modules or cockpit names for that vehicle. Server actions on the owned vehicle still work. `stage_a/client/CHANGES.md` ("Flag off with an owned Exotic") asks for a server half: keep the category in the payload with `PurchaseDisabled=true`. | New with this delivery. Not built: it contradicts the INTERFACE `FeatureFlag` row ("left out of the server catalogue") and needs a contract decision. If approved it is one more GC4 edit and a changed catalogue test. Until then the flag must not be turned off once a profile owns an Exotic. |')
    out.append('| CP1 sends a profile without `Performance` when the current cockpit template is missing or not `V2Materialised`. | New with this delivery and intended (INTERFACE: skip, never throw). The client areas must tolerate a nil `Performance`; not checked from this folder beyond a text search. |')
    out.append('| Retired or hidden modules can still be bought by id (`RetiredFromCatalog`, `HiddenFromCatalog`). | INTERFACE "Not in scope". |')
    out.append('')
    out.append('## Tests\n')
    out.append('`tests.lua` (28 tests with `options.liveCategoriesRoot`, 24 without) and the runner `run_tests.lua`. '
               'Run in Studio Edit; read-only. Old-versus-new parity is checked on fake Piercer data and on the live Piercer templates '
               '(fixed action sequence, all six cockpits, all 116 modules, the built catalogue).\n')
    out.append('Review round 1 (2026-10-02, Studio Edit, place 133417340424236, `run_tests.lua`): 28 of 28 pass. '
               'Control run of the same `tests.lua` against the after-sources as they were before the review fixes: 5 of 24 fail, one per review finding '
               '(category from the folder, neon mirror, missing gate, missing module template warning, empty id in `OwnedGarageDisplay`).\n')
    current = None
    for h in HUNKS:
        if h['script'] != current:
            current = h['script']
            out.append('## %s\n' % current)
        out.append('### %s. %s\n' % (h['id'], h['title']))
        if h.get('before_line'):
            out.append('Before-source line %d.\n' % h['before_line'])
        out.append('Before:\n')
        out.append(fence(h['before']))
        out.append('After:\n')
        out.append(fence(h['after']))
        out.append('Why: ' + h['why'] + '\n')
        out.append('Piercer unchanged: ' + h['piercer'] + '\n')
    (HERE / 'CHANGES.md').write_bytes('\n'.join(out).encode('utf8'))


if __name__ == '__main__':
    main()
