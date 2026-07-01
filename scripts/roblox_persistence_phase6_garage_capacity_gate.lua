-- Neo Tokyo Racers - Persistence Phase 6
-- Adds the first live garage capacity gate to cockpit purchases.
--
-- This uses guarded exact source replacement against:
-- ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
--
-- Scope:
-- - Current V56 garage profile remains the live source of truth.
-- - Buying/selecting already-owned cockpits still works.
-- - Buying a new cockpit is blocked when owned cockpit count reaches capacity.
-- - Capacity is read from Persistence_EditAttributes.StartingGarageCapacity, default 2.
-- - Does not change module ownership, DataStore behavior, UI layout, driving, VFX, or garage interiors.

local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 6"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function waitPath(root, ...)
	local item = root
	for _, name in ipairs({ ... }) do
		item = item:WaitForChild(name)
	end
	return item
end

local function replaceOnce(source, oldText, newText, label)
	local first = string.find(source, oldText, 1, true)
	if not first then
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before making another capacity patch.")
	end
	local second = string.find(source, oldText, first + #oldText, true)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting.")
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, first + #oldText)
end

local garage = waitPath(ServerScriptService, "NeoTokyoRacers", "Services", "Garage", "GarageActionController_Shadow_Disabled")
if not garage:IsA("Script") then
	error("GarageActionController_Shadow_Disabled must be a Script.")
end

local source = garage.Source
if string.find(source, "NTR_PERSISTENCE_PHASE6_GARAGE_CAPACITY_GATE", 1, true) then
	info("Phase 6 garage capacity gate is already installed.")
	return
end

local oldAfterGetProfile = [[	local function V56_getProfile(player)
		local profile = V56_profiles[player.UserId]
		if not profile then
			profile = V56_defaultProfile()
			V56_profiles[player.UserId] = profile
		end
		return V56_normalizeProfile(profile)
	end
]]

local newAfterGetProfile = oldAfterGetProfile .. [[

	-- NTR_PERSISTENCE_PHASE6_GARAGE_CAPACITY_GATE
	local function V81_garageCapacity()
		local shared = V56_kit:FindFirstChild("Shared")
		local configRoot = shared and shared:FindFirstChild("Config")
		local persistenceConfig = configRoot and configRoot:FindFirstChild("Persistence_EditAttributes")
		local capacity = persistenceConfig and persistenceConfig:GetAttribute("StartingGarageCapacity")
		if typeof(capacity) ~= "number" then
			capacity = 2
		end
		return math.max(1, math.floor(capacity))
	end

	local function V81_ownedCockpitCount(profile)
		local count = 0
		for _, owned in pairs((profile and profile.OwnedCockpits) or {}) do
			if owned == true then
				count += 1
			end
		end
		return count
	end

	local function V81_canBuyCockpit(profile, cockpitId)
		if not profile then
			return false, "Garage profile missing."
		end
		profile.OwnedCockpits = profile.OwnedCockpits or {}
		if profile.OwnedCockpits[cockpitId] == true then
			return true
		end
		local capacity = V81_garageCapacity()
		local ownedCount = V81_ownedCockpitCount(profile)
		if ownedCount >= capacity then
			return false, "Garage full. Upgrade your garage to store more vehicles."
		end
		return true
	end
]]

local oldBuyCockpit = [[					local price = V56_number(cockpit, "Price", 0)
					if not profile.OwnedCockpits[cockpitId] then
						if profile.Cash < price then ok, message = false, "Not enough cash." else
							profile.Cash -= price
							profile.OwnedCockpits[cockpitId] = true
							ok, message = true, "Cockpit selected."
						end
					else ok, message = true, "Cockpit selected." end
]]

local newBuyCockpit = [[					local price = V56_number(cockpit, "Price", 0)
					local capacityOk, capacityMessage = V81_canBuyCockpit(profile, cockpitId)
					if not capacityOk then
						ok, message = false, capacityMessage
					elseif not profile.OwnedCockpits[cockpitId] then
						if profile.Cash < price then ok, message = false, "Not enough cash." else
							profile.Cash -= price
							profile.OwnedCockpits[cockpitId] = true
							ok, message = true, "Cockpit selected."
						end
					else ok, message = true, "Cockpit selected." end
]]

source = replaceOnce(source, oldAfterGetProfile, newAfterGetProfile, "Phase 6 garage capacity helpers")
source = replaceOnce(source, oldBuyCockpit, newBuyCockpit, "Phase 6 BuyCockpit capacity gate")

garage.Source = source

info("Installed garage capacity gate in GarageActionController_Shadow_Disabled.")
info("New cockpit purchases are blocked when owned cockpit count reaches Persistence_EditAttributes.StartingGarageCapacity.")
info("Run scripts/roblox_persistence_phase6_garage_capacity_gate_audit.lua from the SERVER Command Bar in Play mode.")
