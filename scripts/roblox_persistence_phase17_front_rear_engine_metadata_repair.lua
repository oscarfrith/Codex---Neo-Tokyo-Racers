-- Persistence Phase 17 front/rear engine metadata repair.
--
-- Run from Roblox Studio Command Bar in Edit mode after Phase 16/17.
--
-- This fixes the newer owned/buy module picker foundation by making front and
-- rear engine identity explicit:
-- - Engines under the `Engines` folder become EnginePosition = "Front".
-- - Engines under the `Engines_B` folder become EnginePosition = "Rear".
-- - Engine1 slots point at Engines/front; Engine2 slots point at Engines_B/rear.
-- - The garage catalog response exposes EnginePosition and RearEngine.
-- - The Phase 17 client helper is refreshed to prefer EnginePosition.
--
-- This is still a guarded text patch for the active garage controller/client
-- bootstrap. If an anchor is missing, refresh the Studio mirror before making
-- another Phase 17 repair.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Engine Metadata Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, oldText, newText, label)
	local first = findPlain(source, oldText)
	if not first then
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 repair.")
	end
	local second = findPlain(source, oldText, first + #oldText)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting: " .. label)
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, first + #oldText)
end

local function insertBeforeOnce(source, anchor, insertText, label)
	local first = findPlain(source, anchor)
	if not first then
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 repair.")
	end
	local second = findPlain(source, anchor, first + #anchor)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting: " .. label)
	end
	return string.sub(source, 1, first - 1) .. insertText .. string.sub(source, first)
end

local function replaceRange(source, startText, endText, replacement, label)
	local startIndex = findPlain(source, startText)
	if not startIndex then
		error("Could not find start for " .. label .. ". Refresh the Studio mirror before another Phase 17 repair.")
	end
	local endIndex = findPlain(source, endText, startIndex + #startText)
	if not endIndex then
		error("Could not find end for " .. label .. ". Refresh the Studio mirror before another Phase 17 repair.")
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex)
end

local function removeAllMarkedRanges(source, markerPrefix, endText, label)
	local removed = 0
	while true do
		local startIndex = findPlain(source, markerPrefix)
		if not startIndex then
			break
		end
		local endIndex = findPlain(source, endText, startIndex + #markerPrefix)
		if not endIndex then
			error("Found start but not end while removing " .. label .. ". Refresh the Studio mirror before another Phase 17 repair.")
		end
		source = string.sub(source, 1, startIndex - 1) .. string.sub(source, endIndex)
		removed += 1
	end
	return source, removed
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local bruiser = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories"):WaitForChild("BRUISER")
local cockpitRoot = bruiser:FindFirstChild("COCKPITS_ReplaceAssetsHere") or bruiser:FindFirstChild("COCKPITS") or bruiser:FindFirstChild("Cockpits")
assert(cockpitRoot, "Could not find Bruiser cockpit root.")
local moduleRoot = bruiser:WaitForChild("MODULES_InterchangeableWithinCategory")
local frontRoot = moduleRoot:WaitForChild("Engines")
local rearRoot = moduleRoot:WaitForChild("Engines_B")

local function isEngineModel(item)
	if not item:IsA("Model") then
		return false
	end
	local moduleId = tostring(item:GetAttribute("ModuleId") or item.Name or "")
	local moduleType = tostring(item:GetAttribute("ModuleType") or "")
	return moduleType == "Engine" or string.find(moduleId, "ENGINE", 1, true) ~= nil
end

local frontCount = 0
local rearCount = 0
local retiredFrontFolderRearCount = 0

for _, item in ipairs(frontRoot:GetDescendants()) do
	if isEngineModel(item) then
		local moduleId = tostring(item:GetAttribute("ModuleId") or item.Name or "")
		local looksLikeRear = string.find(moduleId, "ENGINE_B", 1, true) ~= nil or string.find(string.lower(tostring(item:GetAttribute("DisplayName") or "")), "rear", 1, true) ~= nil
		if looksLikeRear then
			item:SetAttribute("RetiredFromCatalog", true)
			item:SetAttribute("EnginePosition", "Rear")
			item:SetAttribute("RearEngine", true)
			retiredFrontFolderRearCount += 1
		else
			item:SetAttribute("ModuleType", "Engine")
			item:SetAttribute("ModuleFolder", "Engines")
			item:SetAttribute("EnginePosition", "Front")
			item:SetAttribute("RearEngine", false)
			item:SetAttribute("RetiredFromCatalog", false)
			frontCount += 1
		end
	end
end

for _, item in ipairs(rearRoot:GetDescendants()) do
	if isEngineModel(item) then
		item:SetAttribute("ModuleType", "Engine")
		item:SetAttribute("ModuleFolder", "Engines_B")
		item:SetAttribute("EnginePosition", "Rear")
		item:SetAttribute("RearEngine", true)
		if item:GetAttribute("RetiredFromCatalog") ~= true then
			rearCount += 1
		end
	end
end

for _, cockpit in ipairs(cockpitRoot:GetDescendants()) do
	if cockpit:IsA("Model") and cockpit:GetAttribute("CockpitId") then
		local slots = cockpit:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename", true)
		if slots then
			local front = slots:FindFirstChild("SLOT_Engine1")
			if front then
				front:SetAttribute("SlotId", "Engine1")
				front:SetAttribute("DisplayName", "Front Engine")
				front:SetAttribute("ModuleType", "Engine")
				front:SetAttribute("AllowedModuleFolder", "Engines")
				front:SetAttribute("EnginePosition", "Front")
			end
			local rear = slots:FindFirstChild("SLOT_Engine2")
			if rear then
				rear:SetAttribute("SlotId", "Engine2")
				rear:SetAttribute("DisplayName", "Rear Engine")
				rear:SetAttribute("ModuleType", "Engine")
				rear:SetAttribute("AllowedModuleFolder", "Engines_B")
				rear:SetAttribute("EnginePosition", "Rear")
			end
		end
		local defaultFront = cockpit:GetAttribute("DefaultFrontEngineModuleId") or cockpit:GetAttribute("DefaultEngineModuleId")
		if defaultFront then
			cockpit:SetAttribute("DefaultFrontEngineModuleId", defaultFront)
		end
	end
end

assert(frontCount > 0, "No active front engine modules were found under Engines.")
assert(rearCount > 0, "No active rear engine modules were found under Engines_B.")

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")
assert(garage:IsA("Script"), "Expected active garage controller to be a Script.")

local serverSource = garage.Source

if not findPlain(serverSource, "NTR_PERSISTENCE_PHASE17_ENGINE_POSITION_CATALOG") then
	serverSource = replaceOnce(serverSource,
[[			ModuleFolder = V56_string(item, "ModuleFolder", V56_nearestModuleFolder(root, item)),
]],
[[			ModuleFolder = V56_string(item, "ModuleFolder", V56_nearestModuleFolder(root, item)),
			-- NTR_PERSISTENCE_PHASE17_ENGINE_POSITION_CATALOG
			EnginePosition = V56_string(item, "EnginePosition", ""),
			RearEngine = item:GetAttribute("RearEngine") == true,
]],
		"Phase 17 engine position catalog fields")
end

local serverSlotGuard = [=[

	-- NTR_PERSISTENCE_PHASE17_MODULE_SLOT_GUARD
	local function V86_moduleEnginePosition(moduleModel)
		if not moduleModel then return "" end
		local explicit = tostring(moduleModel:GetAttribute("EnginePosition") or "")
		if explicit == "Front" or explicit == "Rear" then
			return explicit
		end
		local moduleFolder = V56_string(moduleModel, "ModuleFolder", "")
		local moduleId = tostring(moduleModel:GetAttribute("ModuleId") or moduleModel.Name or "")
		local displayName = string.lower(tostring(moduleModel:GetAttribute("DisplayName") or moduleModel.Name or ""))
		if moduleModel:GetAttribute("RearEngine") == true then
			return "Rear"
		end
		if moduleFolder == "Engines_B" then
			return "Rear"
		end
		if string.find(moduleId, "ENGINE_B", 1, true) ~= nil then
			return "Rear"
		end
		if string.find(displayName, "rear", 1, true) ~= nil then
			return "Rear"
		end
		if moduleFolder == "Engines" then
			return "Front"
		end
		return ""
	end

	local function V86_moduleFitsSlot(moduleModel, slotId, allowedModuleFolder)
		if not moduleModel then return false end
		local moduleFolder = V56_string(moduleModel, "ModuleFolder", "")
		local enginePosition = V86_moduleEnginePosition(moduleModel)
		if slotId == "Engine1" then
			return enginePosition ~= "Rear"
		end
		if slotId == "Engine2" then
			return enginePosition == "Rear"
		end
		if allowedModuleFolder and allowedModuleFolder ~= "" then
			return moduleFolder == allowedModuleFolder
		end
		return true
	end
]=]

if findPlain(serverSource, "-- NTR_PERSISTENCE_PHASE17_MODULE_SLOT_GUARD") then
	serverSource = replaceRange(serverSource, "-- NTR_PERSISTENCE_PHASE17_MODULE_SLOT_GUARD", "	V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)", serverSlotGuard .. "\n\tV85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)", "Phase 17 server slot guard refresh")
else
	serverSource = insertBeforeOnce(serverSource, "	V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)", serverSlotGuard, "Phase 17 server slot guard helper")
end

garage.Source = serverSource
garage:SetAttribute("PersistencePhase17EnginePositionCatalog", true)

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local clientSource = bootstrap.Source
assert(findPlain(clientSource, "NTR_PERSISTENCE_PHASE16_MODULE_SORTING"), "Run Phase 16 before this repair.")

local removedHelpers
clientSource, removedHelpers = removeAllMarkedRanges(clientSource, "-- NTR_PERSISTENCE_PHASE17_MODULE_TABS", "local function modulesForSlot(slotId)", "old Phase 17 client helper")

local clientHelper = [=[
-- NTR_PERSISTENCE_PHASE17_MODULE_TABS_V4
function NTRPersistencePhase15.ModuleEnginePosition(moduleInfo)
	if not moduleInfo then
		return ""
	end
	local explicit = tostring(moduleInfo.EnginePosition or "")
	if explicit == "Front" or explicit == "Rear" then
		return explicit
	end
	local moduleFolder = tostring(moduleInfo.ModuleFolder or "")
	local moduleId = tostring(moduleInfo.ModuleId or "")
	local displayName = string.lower(tostring(moduleInfo.DisplayName or moduleInfo.ModuleId or ""))
	if moduleInfo.RearEngine == true then
		return "Rear"
	end
	if moduleFolder == "Engines_B" then
		return "Rear"
	end
	if string.find(moduleId, "ENGINE_B", 1, true) ~= nil then
		return "Rear"
	end
	if string.find(displayName, "rear", 1, true) ~= nil then
		return "Rear"
	end
	if moduleFolder == "Engines" then
		return "Front"
	end
	return ""
end

function NTRPersistencePhase15.ModuleIsRearEngine(moduleInfo)
	return NTRPersistencePhase15.ModuleEnginePosition(moduleInfo) == "Rear"
end

function NTRPersistencePhase15.ModuleFitsSelectedSlot(moduleInfo, slotInfo)
	if not moduleInfo or not slotInfo then
		return false
	end
	local slotId = tostring(slotInfo.SlotId or "")
	local moduleFolder = tostring(moduleInfo.ModuleFolder or "")
	local enginePosition = NTRPersistencePhase15.ModuleEnginePosition(moduleInfo)
	if slotId == "Engine1" then
		return enginePosition ~= "Rear"
	end
	if slotId == "Engine2" then
		return enginePosition == "Rear"
	end
	if slotInfo.AllowedModuleFolder and slotInfo.AllowedModuleFolder ~= "" then
		return moduleFolder == slotInfo.AllowedModuleFolder
	end
	return true
end

function NTRPersistencePhase15.ModuleMatchesSelectedSlot(moduleInfo, slotInfo)
	if not moduleInfo or not slotInfo then
		return false
	end
	if tostring(moduleInfo.ModuleType or "") ~= tostring(slotInfo.ModuleType or "") then
		return false
	end
	return NTRPersistencePhase15.ModuleFitsSelectedSlot(moduleInfo, slotInfo)
end

function NTRPersistencePhase15.OwnedModuleInstancesForSlot(profile, slotInfo, getModuleFn)
	local result = {}
	for instanceId, instanceInfo in pairs((profile and profile.OwnedModuleInstances) or {}) do
		local moduleInfo = getModuleFn(tostring(instanceInfo.TemplateId or ""))
		if NTRPersistencePhase15.ModuleMatchesSelectedSlot(moduleInfo, slotInfo) then
			table.insert(result, {
				InstanceId = instanceId,
				Instance = instanceInfo,
				Module = moduleInfo,
			})
		end
	end
	table.sort(result, function(a, b)
		local am = a.Module or {}
		local bm = b.Module or {}
		local af = tostring(am.SourceCockpitDisplayName or am.SourceCockpitId or "")
		local bf = tostring(bm.SourceCockpitDisplayName or bm.SourceCockpitId or "")
		if af ~= bf then
			return af < bf
		end
		local av = tonumber(am.VariantOrder) or 999
		local bv = tonumber(bm.VariantOrder) or 999
		if av ~= bv then
			return av < bv
		end
		local an = tostring(am.DisplayName or "")
		local bn = tostring(bm.DisplayName or "")
		if an ~= bn then
			return an < bn
		end
		return tostring(a.InstanceId) < tostring(b.InstanceId)
	end)
	return result
end

]=]
clientSource = insertBeforeOnce(clientSource, "local function modulesForSlot(slotId)", clientHelper, "Phase 17 v4 client helper methods")

local newModulesForSlot = [[local function modulesForSlot(slotId)
	local slotInfo = getSlot(slotId)
	local category = getCategory()
	local result = {}
	if not slotInfo or not category then return result end
	local list = (category.Modules and category.Modules[slotInfo.ModuleType]) or {}
	for _, moduleInfo in ipairs(list) do
		if NTRPersistencePhase15.ModuleFitsSelectedSlot(moduleInfo, slotInfo) then
			table.insert(result, moduleInfo)
		end
	end
	table.sort(result, function(a, b)
		local ag = NTRPersistencePhase15.ModuleSortGroup(State.Profile, a)
		local bg = NTRPersistencePhase15.ModuleSortGroup(State.Profile, b)
		if ag ~= bg then return ag < bg end
		local ac = tostring(a.SourceCockpitDisplayName or a.SourceCockpitId or "")
		local bc = tostring(b.SourceCockpitDisplayName or b.SourceCockpitId or "")
		if ac ~= bc then return ac < bc end
		local ap = tostring(a.EnginePosition or "")
		local bp = tostring(b.EnginePosition or "")
		if ap ~= bp then return ap < bp end
		local av = tonumber(a.VariantOrder) or 999
		local bv = tonumber(b.VariantOrder) or 999
		if av ~= bv then return av < bv end
		return tostring(a.DisplayName or "") < tostring(b.DisplayName or "")
	end)
	return result
end

]]
clientSource = replaceRange(clientSource, "local function modulesForSlot(slotId)", "local function slotDisplayName(slot)", newModulesForSlot, "Phase 17 v4 slot-filtered module list")
clientSource = string.gsub(clientSource, "State%.ModuleMode = \"Options\"\n(%s*)setCameraSection%(slot%.SlotId%)", "State.ModuleMode = \"Options\"\n%1State.ModuleOptionMode = nil\n%1setCameraSection(slot.SlotId)", 1)

bootstrap.Source = clientSource
bootstrap:SetAttribute("PersistencePhase17EnginePositionClient", true)

assert(findPlain(bootstrap.Source, "NTR_PERSISTENCE_PHASE17_MODULE_TABS_V4"), "Phase 17 v4 client marker missing after repair.")
assert(not findPlain(bootstrap.Source, "NTR_PERSISTENCE_PHASE17_MODULE_TABS_V2"), "Phase 17 v2 helper should have been removed.")
assert(not findPlain(bootstrap.Source, "NTR_PERSISTENCE_PHASE17_MODULE_TABS_V3"), "Phase 17 v3 helper should have been removed.")

info("PASS: tagged " .. tostring(frontCount) .. " front engine module(s) and " .. tostring(rearCount) .. " rear engine module(s).")
info("PASS: retired " .. tostring(retiredFrontFolderRearCount) .. " rear-looking engine module(s) found under the front Engines folder.")
info("PASS: refreshed catalog fields, server slot guard, and client slot helper. Removed old client helper block count: " .. tostring(removedHelpers))
info("Next: stop Play, start a fresh Play session, then run scripts/roblox_persistence_phase17_module_owned_buy_tabs_client_smoke.lua from the CLIENT Command Bar.")
