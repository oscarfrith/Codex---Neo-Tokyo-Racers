-- Persistence Phase 17 client slot-helper + engine metadata repair.
--
-- Run from Roblox Studio Command Bar in Edit mode if Play reports:
--
--   NeoTokyoRacersClient_Bootstrap_Shadow_Disabled:3475: attempt to call a nil value
--
-- The current Phase 17 client source can keep calls to sortedSlots/getSlot/getModule
-- while losing their local helper definitions. This repairs that small helper
-- family and reapplies explicit front/rear engine metadata to the Bruiser assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Client Slot Helpers Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function insertBeforeOnce(source, anchor, insertion, label)
	local first = findPlain(source, anchor)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 client repair.")
	local second = findPlain(source, anchor, first + #anchor)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another Phase 17 client repair.")
	return string.sub(source, 1, first - 1) .. insertion .. string.sub(source, first)
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
		local displayName = string.lower(tostring(item:GetAttribute("DisplayName") or item.Name or ""))
		local looksLikeRear = string.find(moduleId, "ENGINE_B", 1, true) ~= nil or string.find(displayName, "rear", 1, true) ~= nil
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

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, "NTR_PERSISTENCE_PHASE17_MODULE_TABS_V4") or findPlain(source, "NTR_PERSISTENCE_PHASE17_MODULE_TABS"), "Expected Phase 17 module tabs client helper to be present.")
assert(findPlain(source, "local function modulesForSlot(slotId)"), "Expected modulesForSlot anchor in client bootstrap.")
assert(findPlain(source, "local function cloneArray(list)"), "Expected cloneArray helper in client bootstrap.")

local changed = false
if not findPlain(source, "local function getCategory()") then
	local helperBlock = [=[

-- NTR_PERSISTENCE_PHASE17_CLIENT_SLOT_LOOKUP_REPAIR
local function getCategory()
	for _, category in ipairs((State.Catalog and State.Catalog.Categories) or {}) do
		if category.CategoryId == State.CategoryId then
			return category
		end
	end
	local categories = State.Catalog and State.Catalog.Categories
	if typeof(categories) == "table" and categories[1] then
		State.CategoryId = categories[1].CategoryId
		return categories[1]
	end
end

local function sortedSlots()
	local category = getCategory()
	local slots = cloneArray(category and category.Slots)
	if #slots == 0 then
		slots = {
			{ SlotId = "Engine1", DisplayName = "Front Engine", ModuleType = "Engine", AllowedModuleFolder = "Engines", EnginePosition = "Front", Order = 1 },
			{ SlotId = "Engine2", DisplayName = "Rear Engine", ModuleType = "Engine", AllowedModuleFolder = "Engines_B", EnginePosition = "Rear", Order = 2 },
			{ SlotId = "Stabilisers", DisplayName = "Stabilisers", ModuleType = "Stabilisers", Order = 3 },
			{ SlotId = "Boost", DisplayName = "Boost", ModuleType = "Boost", Order = 4 },
			{ SlotId = "FrontBumper", DisplayName = "Front Bumper", ModuleType = "FrontBumper", Order = 5 },
			{ SlotId = "RearBumper", DisplayName = "Rear Bumper", ModuleType = "RearBumper", Order = 6 },
			{ SlotId = "RearSpoiler", DisplayName = "Rear Spoiler", ModuleType = "RearSpoiler", Order = 7 },
			{ SlotId = "SidePods", DisplayName = "Side Pods", ModuleType = "SidePods", Order = 8 },
		}
	end
	table.sort(slots, function(a, b)
		return (tonumber(a.Order) or 99) < (tonumber(b.Order) or 99)
	end)
	return slots
end

local function getSlot(slotId)
	for _, slot in ipairs(sortedSlots()) do
		if slot.SlotId == slotId then
			return slot
		end
	end
end

local function getCockpit(cockpitId)
	local category = getCategory()
	for _, cockpit in ipairs((category and category.Cockpits) or {}) do
		if cockpit.CockpitId == cockpitId then
			return cockpit
		end
	end
end

local function getModule(moduleId)
	local category = getCategory()
	for _, list in pairs((category and category.Modules) or {}) do
		for _, module in ipairs(list) do
			if module.ModuleId == moduleId then
				return module
			end
		end
	end
end
]=]

	source = insertBeforeOnce(source, "local function modulesForSlot(slotId)", helperBlock, "Phase 17 client slot lookup helpers")
	changed = true
end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ClientSlotLookupRepair", true)

local finalSource = bootstrap.Source
local modulesForSlotAt = findPlain(finalSource, "local function modulesForSlot(slotId)")
local checks = {
	{ "getCategory", findPlain(finalSource, "local function getCategory()") },
	{ "sortedSlots", findPlain(finalSource, "local function sortedSlots()") },
	{ "getSlot", findPlain(finalSource, "local function getSlot(slotId)") },
	{ "getCockpit", findPlain(finalSource, "local function getCockpit(cockpitId)") },
	{ "getModule", findPlain(finalSource, "local function getModule(moduleId)") },
}

for _, check in ipairs(checks) do
	assert(check[2] and check[2] < modulesForSlotAt, "Post-repair audit failed: missing or late " .. check[1])
	info("PASS: " .. check[1] .. " exists before modulesForSlot.")
end

info("PASS: tagged " .. tostring(frontCount) .. " front engine module(s) and " .. tostring(rearCount) .. " rear engine module(s).")
info("PASS: retired " .. tostring(retiredFrontFolderRearCount) .. " rear-looking engine module(s) under the front Engines folder.")
if changed then
	info("PASS: repaired missing client slot lookup helpers.")
else
	info("PASS: client slot lookup helpers already existed; only metadata was refreshed.")
end
info("Next: stop Play, start a fresh Play session, enter the dealership, then rerun scripts/roblox_persistence_phase17_module_owned_buy_tabs_client_smoke.lua from the CLIENT Command Bar.")
