-- Neo Tokyo Racers - Persistence Phase 4
-- Guarded bridge patch for mirroring the active V56 garage session profile into ProfileService.
--
-- This script uses fragile exact source replacement against:
-- ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
--
-- It intentionally does not make ProfileService the source of truth yet.
-- Current garage/dealership UI responses still come from the existing V56 profile.

local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 4"

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
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before making another persistence bridge patch.")
	end
	local second = string.find(source, oldText, first + #oldText, true)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting.")
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, first + #oldText)
end

local garage = waitPath(ServerScriptService, "NeoTokyoRacers", "Services", "Garage", "GarageActionController_Shadow_Disabled")
if not garage:IsA("Script") then
	error("GarageActionController_Shadow_Disabled must be a Script")
end

local source = garage.Source
if string.find(source, "NTR_PERSISTENCE_PHASE4_SESSION_MIRROR", 1, true) then
	info("Phase 4 session mirror patch is already installed.")
	return
end

local profileService = waitPath(ServerScriptService, "NeoTokyoRacers", "Services", "Player", "ProfileService_Active")
local bridgeService = waitPath(ServerScriptService, "NeoTokyoRacers", "Services", "Player", "LegacyGarageProfileBridge_Active")
if not profileService:IsA("Script") or profileService.Disabled then
	error("ProfileService_Active must be installed and enabled before Phase 4.")
end
if not bridgeService:IsA("Script") or bridgeService.Disabled then
	error("LegacyGarageProfileBridge_Active must be installed and enabled before Phase 4.")
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

	-- NTR_PERSISTENCE_PHASE4_SESSION_MIRROR
	local V80_persistenceBindings = nil
	local V80_mutatingActions = {
		BuyCockpit = true,
		SetCockpitColor = true,
		BuyModule = true,
		SetModuleColor = true,
		UpgradeModule = true,
		Upgrade = true,
		BuyNeon = true,
		SetThrustColor = true,
		SpawnVehicle = false,
		ExitVehicle = false,
		ReEnterVehicle = false,
		GetInitial = false,
	}

	local function V80_countDictionary(dictionary)
		local count = 0
		for _ in pairs(dictionary or {}) do
			count += 1
		end
		return count
	end

	local function V80_replaceTableContents(target, source)
		for key in pairs(target) do
			target[key] = nil
		end
		for key, value in pairs(source or {}) do
			target[key] = value
		end
	end

	local function V80_getPersistenceBindings()
		if V80_persistenceBindings then
			return V80_persistenceBindings
		end
		local servicesRoot = script.Parent and script.Parent.Parent
		local playerServices = servicesRoot and servicesRoot:FindFirstChild("Player")
		local profileBindings = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
		local bridgeBindings = playerServices and playerServices:FindFirstChild("LegacyGarageProfileBridgeBindings")
		local getProfile = profileBindings and profileBindings:FindFirstChild("GetProfile")
		local markDirty = profileBindings and profileBindings:FindFirstChild("MarkDirty")
		local convert = bridgeBindings and bridgeBindings:FindFirstChild("ConvertLegacyProfile")
		if getProfile and markDirty and convert then
			V80_persistenceBindings = {
				GetProfile = getProfile,
				MarkDirty = markDirty,
				ConvertLegacyProfile = convert,
			}
		end
		return V80_persistenceBindings
	end

	local function V80_mirrorLegacyProfileToPersistence(player, profile, action, markDirty)
		local bindings = V80_getPersistenceBindings()
		if not bindings then
			return
		end
		local okConvert, converted = pcall(function()
			return bindings.ConvertLegacyProfile:Invoke(profile, { PreserveLegacyCapacity = true })
		end)
		if not okConvert or typeof(converted) ~= "table" then
			warn("[NTR Persistence Phase 4] Legacy profile conversion failed: " .. tostring(converted))
			return
		end
		local okProfile, persistenceProfile = pcall(function()
			return bindings.GetProfile:Invoke(player)
		end)
		if not okProfile or typeof(persistenceProfile) ~= "table" then
			warn("[NTR Persistence Phase 4] ProfileService profile unavailable: " .. tostring(persistenceProfile))
			return
		end
		V80_replaceTableContents(persistenceProfile, converted)
		player:SetAttribute("NTR_PersistenceMirrorLastAction", tostring(action or "Unknown"))
		player:SetAttribute("NTR_PersistenceMirrorVehicleCount", V80_countDictionary(converted.Vehicles))
		player:SetAttribute("NTR_PersistenceMirrorModuleInstanceCount", V80_countDictionary(converted.OwnedModuleInstances))
		if markDirty then
			pcall(function()
				bindings.MarkDirty:Invoke(player, "GarageAction:" .. tostring(action or "Unknown"))
			end)
		end
	end
]]

local oldGetInitial = [[			if action == "GetInitial" then
				V56_setLeaderstats(player, profile)
				return { Success = true, Catalog = V56_catalog(), Profile = V56_profileForClient(profile) }
]]

local newGetInitial = [[			if action == "GetInitial" then
				V56_setLeaderstats(player, profile)
				V80_mirrorLegacyProfileToPersistence(player, profile, action, false)
				return { Success = true, Catalog = V56_catalog(), Profile = V56_profileForClient(profile) }
]]

local oldFinalReturn = [[			return { Success = ok == true, Message = message, Profile = V56_profileForClient(profile) }
]]

local newFinalReturn = [[			if ok == true then
				V80_mirrorLegacyProfileToPersistence(player, profile, action, V80_mutatingActions[action] == true)
			end
			return { Success = ok == true, Message = message, Profile = V56_profileForClient(profile) }
]]

source = replaceOnce(source, oldAfterGetProfile, newAfterGetProfile, "Phase 4 mirror helper")
source = replaceOnce(source, oldGetInitial, newGetInitial, "Phase 4 GetInitial mirror call")
source = replaceOnce(source, oldFinalReturn, newFinalReturn, "Phase 4 final response mirror call")

garage.Source = source

info("Installed guarded session mirror patch in GarageActionController_Shadow_Disabled.")
info("Current garage profile remains the live source of truth; ProfileService receives converted snapshots only.")
info("Run scripts/roblox_persistence_phase4_garage_session_mirror_server_audit.lua from the SERVER Command Bar in Play mode.")
info("Then run scripts/roblox_persistence_phase4_garage_session_mirror_client_smoke.lua from the CLIENT Command Bar in Play mode.")
