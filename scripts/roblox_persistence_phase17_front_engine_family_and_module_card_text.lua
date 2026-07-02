-- Persistence Phase 17 front-engine family + module card text repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- This is a narrow follow-up to the Phase 17 module picker:
-- 1. Retires the old flat front engine templates such as Engine V1-V4 from the
--    buy catalogue without deleting them.
-- 2. Makes the Phase AK Bruiser family front engines explicit catalog entries,
--    matching the rear-engine setup.
-- 3. Updates module option cards so the top line is "[Cockpit] / [Variant]",
--    the middle line is the green price, and the bottom line is "Owned xN".
--
-- The client UI part uses guarded exact-source replacement against the active
-- bootstrap. If it aborts, refresh the Studio mirror before another UI patch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Front Engine Family + Card Text"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 card-text patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another Phase 17 card-text patch.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before)
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
	return moduleType == "Engine" or string.find(moduleId, "ENGINE", 1, true) ~= nil or string.find(string.upper(item.Name), "ENGINE", 1, true) ~= nil
end

local function moduleIdOf(item)
	return tostring(item:GetAttribute("ModuleId") or item.Name or "")
end

local function displayNameOf(item)
	return tostring(item:GetAttribute("DisplayName") or item.Name or "")
end

local function cockpitNumberFromModuleId(moduleId)
	return string.match(moduleId, "BRUISER_(%d+)")
end

local function sourceCockpitIdFromModuleId(moduleId)
	local number = cockpitNumberFromModuleId(moduleId)
	if not number then
		return nil
	end
	return "bruiser_" .. number
end

local function variantFromModuleId(moduleId)
	if string.find(moduleId, "LIGHTWEIGHT", 1, true) then
		return "Lightweight", 2
	end
	if string.find(moduleId, "POWER", 1, true) then
		return "Power", 3
	end
	if string.find(moduleId, "STANDARD", 1, true) then
		return "Standard", 1
	end
	return nil, nil
end

local cockpitDisplayById = {}
for _, cockpit in ipairs(cockpitRoot:GetDescendants()) do
	if cockpit:IsA("Model") then
		local cockpitId = cockpit:GetAttribute("CockpitId")
		if cockpitId then
			cockpitDisplayById[tostring(cockpitId)] = tostring(cockpit:GetAttribute("DisplayName") or cockpit.Name)
		end
	end
end

local function isPhaseAkFrontFamilyEngine(item)
	local moduleId = moduleIdOf(item)
	return string.find(moduleId, "MODULE_ENGINE_BRUISER_", 1, true) ~= nil
		and string.find(moduleId, "MODULE_ENGINE_B_BRUISER_", 1, true) == nil
end

local function isOldFlatFrontEngine(item)
	if item.Parent == frontRoot and isEngineModel(item) then
		return true
	end
	local moduleId = moduleIdOf(item)
	local name = string.lower(displayNameOf(item) .. " " .. item.Name)
	if string.find(name, "engine v", 1, true) then
		return true
	end
	if string.match(moduleId, "^MODULE_ENGINE_[ABCD]$") then
		return true
	end
	return false
end

local activeFrontFamily = 0
local retiredOldFront = 0
local activeRearFamily = 0

for _, item in ipairs(frontRoot:GetDescendants()) do
	if isEngineModel(item) then
		local moduleId = moduleIdOf(item)
		if isPhaseAkFrontFamilyEngine(item) then
			local sourceCockpitId = item:GetAttribute("SourceCockpitId") or sourceCockpitIdFromModuleId(moduleId)
			local variantName, variantOrder = variantFromModuleId(moduleId)
			item:SetAttribute("ModuleType", "Engine")
			item:SetAttribute("ModuleFolder", "Engines")
			item:SetAttribute("EnginePosition", "Front")
			item:SetAttribute("RearEngine", false)
			item:SetAttribute("RetiredFromCatalog", false)
			item:SetAttribute("HiddenFromCatalog", false)
			item:SetAttribute("CatalogVisible", true)
			if sourceCockpitId then
				item:SetAttribute("SourceCockpitId", sourceCockpitId)
				if cockpitDisplayById[tostring(sourceCockpitId)] then
					item:SetAttribute("SourceCockpitDisplayName", cockpitDisplayById[tostring(sourceCockpitId)])
				end
			end
			if variantName then
				item:SetAttribute("VariantName", variantName)
			end
			if variantOrder then
				item:SetAttribute("VariantOrder", variantOrder)
			end
			activeFrontFamily += 1
		elseif isOldFlatFrontEngine(item) then
			item:SetAttribute("RetiredFromCatalog", true)
			item:SetAttribute("HiddenFromCatalog", true)
			item:SetAttribute("CatalogVisible", false)
			item:SetAttribute("EnginePosition", "Front")
			item:SetAttribute("RearEngine", false)
			retiredOldFront += 1
		end
	end
end

for _, item in ipairs(rearRoot:GetDescendants()) do
	if isEngineModel(item) then
		local moduleId = moduleIdOf(item)
		local sourceCockpitId = item:GetAttribute("SourceCockpitId") or sourceCockpitIdFromModuleId(moduleId)
		local variantName, variantOrder = variantFromModuleId(moduleId)
		item:SetAttribute("ModuleType", "Engine")
		item:SetAttribute("ModuleFolder", "Engines_B")
		item:SetAttribute("EnginePosition", "Rear")
		item:SetAttribute("RearEngine", true)
		if sourceCockpitId then
			item:SetAttribute("SourceCockpitId", sourceCockpitId)
			if cockpitDisplayById[tostring(sourceCockpitId)] then
				item:SetAttribute("SourceCockpitDisplayName", cockpitDisplayById[tostring(sourceCockpitId)])
			end
		end
		if variantName then
			item:SetAttribute("VariantName", variantName)
		end
		if variantOrder then
			item:SetAttribute("VariantOrder", variantOrder)
		end
		if item:GetAttribute("RetiredFromCatalog") ~= true and item:GetAttribute("HiddenFromCatalog") ~= true and item:GetAttribute("CatalogVisible") ~= false then
			activeRearFamily += 1
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
		local frontDefault = cockpit:GetAttribute("DefaultFrontEngineModuleId") or cockpit:GetAttribute("DefaultEngineModuleId")
		if frontDefault then
			cockpit:SetAttribute("DefaultFrontEngineModuleId", frontDefault)
		end
	end
end

assert(activeFrontFamily > 4, "Only " .. tostring(activeFrontFamily) .. " active family front engines were found. Expected the Phase AK Bruiser front-engine families under Engines/Bruiser_01...Bruiser_05.")
assert(activeRearFamily > 4, "Only " .. tostring(activeRearFamily) .. " active rear engines were found under Engines_B.")

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, "function NTRPersistencePhase15.CountModuleCopies(profile, moduleId)"), "Expected CountModuleCopies helper in active client bootstrap.")
assert(findPlain(source, "NTR_PERSISTENCE_PHASE17_MODULE_TABS"), "Expected Phase 17 module tab helper in active client bootstrap.")

local ownedBefore = [=[
			pooledLabel(card, tostring(moduleInfo and (moduleInfo.DisplayName or moduleInfo.ModuleId) or instanceInfo.TemplateId), UDim2.new(1, -10, 0, 28), UDim2.fromOffset(5, 7), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, "#" .. tostring(index) .. " / " .. tostring(moduleInfo and (moduleInfo.VariantName or "") or ""), UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 32), 9, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
			local status = "owned"
			if isInstalledHere then
				status = "equipped here"
			elseif equippedElsewhere then
				status = "in another car"
			end
			pooledLabel(card, status, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isInstalledHere and Theme.Accent or Theme.Cash
]=]

local ownedAfter = [=[
			local familyText = tostring(moduleInfo and (moduleInfo.SourceCockpitDisplayName or moduleInfo.SourceCockpitId) or "")
			local variantText = tostring(moduleInfo and (moduleInfo.VariantName or "") or "")
			local ownedCount = moduleInfo and NTRPersistencePhase15.CountModuleCopies(State.Profile, moduleInfo.ModuleId) or 1
			local bottomText = "Owned x" .. tostring(ownedCount)
			if isInstalledHere then
				bottomText = bottomText .. " / equipped"
			elseif equippedElsewhere then
				bottomText = bottomText .. " / in use"
			end
			pooledLabel(card, familyText .. " / " .. variantText, UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 7), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, "$" .. tostring(moduleInfo and (moduleInfo.Price or 0) or 0), UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 31), 10, Enum.TextXAlignment.Center).TextColor3 = Theme.Cash
			pooledLabel(card, bottomText, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isInstalledHere and Theme.Accent or Theme.Muted
]=]

local buyBefore = [=[
			pooledLabel(card, moduleInfo.DisplayName or moduleInfo.ModuleId, UDim2.new(1, -10, 0, 28), UDim2.fromOffset(5, 7), 10, Enum.TextXAlignment.Center)
			local familyText = tostring(moduleInfo.SourceCockpitDisplayName or moduleInfo.SourceCockpitId or "")
			pooledLabel(card, familyText .. " / " .. tostring(moduleInfo.VariantName or ""), UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 32), 9, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
			local statusText = "$" .. tostring(moduleInfo.Price or 0)
			if isLocked then
				statusText = lockText
			end
			pooledLabel(card, statusText, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isLocked and Theme.Danger or Theme.Cash
]=]

local buyAfter = [=[
			local familyText = tostring(moduleInfo.SourceCockpitDisplayName or moduleInfo.SourceCockpitId or "")
			local variantText = tostring(moduleInfo.VariantName or "")
			local ownedCount = NTRPersistencePhase15.CountModuleCopies(State.Profile, moduleInfo.ModuleId)
			pooledLabel(card, familyText .. " / " .. variantText, UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 7), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, "$" .. tostring(moduleInfo.Price or 0), UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 31), 10, Enum.TextXAlignment.Center).TextColor3 = Theme.Cash
			pooledLabel(card, "Owned x" .. tostring(ownedCount), UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 54), 10, Enum.TextXAlignment.Center).TextColor3 = isLocked and Theme.Danger or Theme.Muted
]=]

local changed = false
if findPlain(source, ownedBefore) then
	source = replaceOnce(source, ownedBefore, ownedAfter, "owned module card text")
	changed = true
elseif findPlain(source, "bottomText = \"Owned x\"") then
	info("Owned module card text already appears to be patched.")
else
	error("Could not find owned module card text block. Refresh the Studio mirror before another Phase 17 card-text patch.")
end

if findPlain(source, buyBefore) then
	source = replaceOnce(source, buyBefore, buyAfter, "buy module card text")
	changed = true
elseif findPlain(source, "local variantText = tostring(moduleInfo.VariantName or \"\")") and findPlain(source, "\"Owned x\" .. tostring(ownedCount)") then
	info("Buy module card text already appears to be patched.")
else
	error("Could not find buy module card text block. Refresh the Studio mirror before another Phase 17 card-text patch.")
end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17FrontEngineFamilyAndCardText", true)

info("PASS: active family front engines visible = " .. tostring(activeFrontFamily) .. ".")
info("PASS: old flat front engines retired/hidden = " .. tostring(retiredOldFront) .. ".")
info("PASS: active rear engines checked = " .. tostring(activeRearFamily) .. ".")
if changed then
	info("PASS: module card text now uses top cockpit/variant, green middle price, and bottom Owned xN.")
else
	info("PASS: module card text was already in the requested layout.")
end
info("Next: restart Play, open Build Modules, select Front Engine, and confirm the front list now matches the rear-engine family style instead of only Engine V1-V4.")
