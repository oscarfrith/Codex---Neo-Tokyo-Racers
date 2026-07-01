-- Neo Tokyo Racers - Persistence Phase 5 Import Snapshot Binding Repair
-- Repairs the Phase 4 mirror path so GarageActionController imports converted snapshots
-- into ProfileService through an owned ProfileService binding instead of mutating a
-- table returned by GetProfile.
--
-- This uses guarded exact source replacement against:
-- - ServerScriptService.NeoTokyoRacers.Services.Player.ProfileService_Active
-- - ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled

local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 5 Import Repair"

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
		error("Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another persistence patch.")
	end
	local second = string.find(source, oldText, first + #oldText, true)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting.")
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, first + #oldText)
end

local profileService = waitPath(ServerScriptService, "NeoTokyoRacers", "Services", "Player", "ProfileService_Active")
local garage = waitPath(ServerScriptService, "NeoTokyoRacers", "Services", "Garage", "GarageActionController_Shadow_Disabled")

if not profileService:IsA("Script") then
	error("ProfileService_Active must be a Script.")
end
if not garage:IsA("Script") then
	error("GarageActionController_Shadow_Disabled must be a Script.")
end

local profileSource = profileService.Source
if not string.find(profileSource, "NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT", 1, true) then
	local oldBindings = [[local saveNowBinding = ensureBindableFunction(bindings, "SaveNow")
local isLoadedBinding = ensureBindableFunction(bindings, "IsLoaded")
]]
	local newBindings = [[local saveNowBinding = ensureBindableFunction(bindings, "SaveNow")
local importProfileSnapshotBinding = ensureBindableFunction(bindings, "ImportProfileSnapshot")
local isLoadedBinding = ensureBindableFunction(bindings, "IsLoaded")
]]

	local oldSaveProfileEnd = [[local function saveProfile(player, force)
	local session = sessionFor(player)
	if not session then
		return false, "Profile is not loaded."
	end
]]
	local newSaveProfileEnd = [[local function importProfileSnapshot(player, snapshot, reason, dirty)
	-- NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT
	local session = sessionFor(player)
	if not session then
		return false, "Profile is not loaded."
	end
	if typeof(snapshot) ~= "table" then
		return false, "Snapshot must be a table."
	end
	session.Profile = schema.Normalize(snapshot, startingCash())
	session.LastImportReason = tostring(reason or "unspecified")
	if dirty then
		session.Dirty = true
		session.LastDirtyReason = tostring(reason or "ImportProfileSnapshot")
	end
	updateRuntimeMarker(player, session)
	return true, "Imported profile snapshot."
end

local function saveProfile(player, force)
	local session = sessionFor(player)
	if not session then
		return false, "Profile is not loaded."
	end
]]

	local oldOnInvoke = [[saveNowBinding.OnInvoke = function(player)
	return saveProfile(player, true)
end

isLoadedBinding.OnInvoke = function(player)
]]
	local newOnInvoke = [[saveNowBinding.OnInvoke = function(player)
	return saveProfile(player, true)
end

importProfileSnapshotBinding.OnInvoke = function(player, snapshot, reason, dirty)
	return importProfileSnapshot(player, snapshot, reason, dirty)
end

isLoadedBinding.OnInvoke = function(player)
]]

	profileSource = replaceOnce(profileSource, oldBindings, newBindings, "ProfileService ImportProfileSnapshot binding")
	profileSource = replaceOnce(profileSource, oldSaveProfileEnd, newSaveProfileEnd, "ProfileService importProfileSnapshot function")
	profileSource = replaceOnce(profileSource, oldOnInvoke, newOnInvoke, "ProfileService ImportProfileSnapshot OnInvoke")
	profileService.Source = profileSource
	info("Patched ProfileService_Active with ImportProfileSnapshot binding.")
else
	info("ProfileService_Active already has ImportProfileSnapshot binding.")
end

local garageSource = garage.Source
if not string.find(garageSource, "NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT", 1, true) then
	local oldResolve = [[		local getProfile = profileBindings and profileBindings:FindFirstChild("GetProfile")
		local markDirty = profileBindings and profileBindings:FindFirstChild("MarkDirty")
		local convert = bridgeBindings and bridgeBindings:FindFirstChild("ConvertLegacyProfile")
		if getProfile and markDirty and convert then
			V80_persistenceBindings = {
				GetProfile = getProfile,
				MarkDirty = markDirty,
				ConvertLegacyProfile = convert,
			}
]]
	local newResolve = [[		local getProfile = profileBindings and profileBindings:FindFirstChild("GetProfile")
		local markDirty = profileBindings and profileBindings:FindFirstChild("MarkDirty")
		local importProfileSnapshot = profileBindings and profileBindings:FindFirstChild("ImportProfileSnapshot")
		local convert = bridgeBindings and bridgeBindings:FindFirstChild("ConvertLegacyProfile")
		if getProfile and markDirty and importProfileSnapshot and convert then
			V80_persistenceBindings = {
				GetProfile = getProfile,
				MarkDirty = markDirty,
				ImportProfileSnapshot = importProfileSnapshot,
				ConvertLegacyProfile = convert,
			}
]]

	local oldImportBlock = [[		local okProfile, persistenceProfile = pcall(function()
			return bindings.GetProfile:Invoke(player)
		end)
		if not okProfile or typeof(persistenceProfile) ~= "table" then
			warn("[NTR Persistence Phase 4] ProfileService profile unavailable: " .. tostring(persistenceProfile))
			return
		end
		V80_replaceTableContents(persistenceProfile, converted)
		player:SetAttribute("NTR_PersistenceMirrorLastAction", tostring(action or "Unknown"))
]]
	local newImportBlock = [[		local okImport, importOk, importMessage = pcall(function()
			-- NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT
			return bindings.ImportProfileSnapshot:Invoke(player, converted, "GarageAction:" .. tostring(action or "Unknown"), markDirty == true)
		end)
		if not okImport or importOk ~= true then
			warn("[NTR Persistence Phase 5] ProfileService snapshot import failed: " .. tostring(importOk or importMessage))
			return
		end
		player:SetAttribute("NTR_PersistenceMirrorLastAction", tostring(action or "Unknown"))
]]

	local oldMarkDirty = [[		if markDirty then
			pcall(function()
				bindings.MarkDirty:Invoke(player, "GarageAction:" .. tostring(action or "Unknown"))
			end)
		end
]]
	local newMarkDirty = [[		-- Dirty marking is owned by ImportProfileSnapshot after Phase 5.
]]

	garageSource = replaceOnce(garageSource, oldResolve, newResolve, "Garage mirror ImportProfileSnapshot binding lookup")
	garageSource = replaceOnce(garageSource, oldImportBlock, newImportBlock, "Garage mirror snapshot import")
	garageSource = replaceOnce(garageSource, oldMarkDirty, newMarkDirty, "Garage mirror old MarkDirty call")
	garage.Source = garageSource
	info("Patched GarageActionController_Shadow_Disabled to import snapshots through ProfileService.")
else
	info("GarageActionController_Shadow_Disabled already imports snapshots through ProfileService.")
end

info("Run scripts/roblox_persistence_phase5_import_snapshot_binding_audit.lua from the SERVER Command Bar in Play mode.")
info("Then rerun the Phase 4 client smoke and Phase 5 save audit.")
