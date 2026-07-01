-- Neo Tokyo Racers - Persistence Phase 2
-- Installs a cautious ProfileService foundation around PlayerProfileSchema.
--
-- Safe foundation phase:
-- - Does not patch GarageActionController_Shadow_Disabled.
-- - Does not change current dealership, purchase, spawn, driving, UI, or VFX behavior.
-- - DataStoreEnabled defaults to false, so the service is dry-run/session-only until deliberately enabled.
-- - Exposes BindableFunctions for future server-side garage/profile bridge phases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 2"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		error(item:GetFullName() .. " must be a Folder")
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function ensureScript(parent, name, source)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Script") then
		error(item:GetFullName() .. " must be a Script")
	end
	if not item then
		item = Instance.new("Script")
		item.Name = name
		item.Parent = parent
	end
	item.Source = source
	item.Disabled = false
	return item
end

local function setDefaultAttribute(item, name, value)
	if item:GetAttribute(name) == nil then
		item:SetAttribute(name, value)
	end
end

local profileServiceSource = [==[
-- Neo Tokyo Racers ProfileService foundation.
-- Persistence Phase 2. Session profile lifecycle plus optional DataStore plumbing.
-- DataStoreEnabled defaults to false through Persistence_EditAttributes.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "ProfileService"

local function log(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function warnLine(message)
	warn("[NTR " .. PHASE .. "] " .. message)
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		error(item:GetFullName() .. " must be a Folder")
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function ensureBindableFunction(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("BindableFunction") then
		error(item:GetFullName() .. " must be a BindableFunction")
	end
	if not item then
		item = Instance.new("BindableFunction")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local ntr = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local schema = require(ntr
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Data")
	:WaitForChild("PlayerProfileSchema"))

local config = ntr
	:WaitForChild("Shared")
	:WaitForChild("Config")
	:WaitForChild("Persistence_EditAttributes")

local serverRoot = ServerScriptService:WaitForChild("NeoTokyoRacers")
local services = ensureFolder(serverRoot, "Services")
local playerServices = ensureFolder(services, "Player")
local stateRoot = ensureFolder(serverRoot, "State")
local runtimeProfilesFolder = ensureFolder(stateRoot, "RuntimeProfiles")
local bindings = ensureFolder(playerServices, "ProfileServiceBindings")

local getProfileBinding = ensureBindableFunction(bindings, "GetProfile")
local getSummaryBinding = ensureBindableFunction(bindings, "GetSummary")
local markDirtyBinding = ensureBindableFunction(bindings, "MarkDirty")
local saveNowBinding = ensureBindableFunction(bindings, "SaveNow")
local isLoadedBinding = ensureBindableFunction(bindings, "IsLoaded")

local sessions = {}
local shuttingDown = false

local function getAttr(name, fallback)
	local value = config:GetAttribute(name)
	if value == nil then
		return fallback
	end
	return value
end

local function dataStoreEnabled()
	return getAttr("DataStoreEnabled", false) == true
end

local function dataStoreName()
	return tostring(getAttr("DataStoreName", "NTR_PlayerProfiles_v1"))
end

local function autosaveSeconds()
	return math.max(30, tonumber(getAttr("AutosaveSeconds", 90)) or 90)
end

local function saveDebounceSeconds()
	return math.max(0, tonumber(getAttr("SaveDebounceSeconds", 8)) or 8)
end

local function startingCash()
	return tonumber(ntr:GetAttribute("StartingCash")) or 140000
end

local function profileKey(player)
	return "player_" .. tostring(player.UserId)
end

local function getStore()
	return DataStoreService:GetDataStore(dataStoreName())
end

local function sessionFor(player)
	if not player then
		return nil
	end
	return sessions[player.UserId]
end

local function updateRuntimeMarker(player, session)
	local marker = runtimeProfilesFolder:FindFirstChild(tostring(player.UserId))
	if not marker then
		marker = Instance.new("Folder")
		marker.Name = tostring(player.UserId)
		marker.Parent = runtimeProfilesFolder
	end
	marker:SetAttribute("PlayerName", player.Name)
	marker:SetAttribute("Loaded", session.Loaded == true)
	marker:SetAttribute("Dirty", session.Dirty == true)
	marker:SetAttribute("LastSaveUnix", session.LastSaveUnix or 0)
	marker:SetAttribute("LastError", session.LastError or "")
	local summary = schema.Summarize(session.Profile)
	marker:SetAttribute("SchemaVersion", summary.SchemaVersion)
	marker:SetAttribute("GarageCapacity", summary.GarageCapacity)
	marker:SetAttribute("VehicleCount", summary.VehicleCount)
	marker:SetAttribute("ModuleInstanceCount", summary.ModuleInstanceCount)
	return marker
end

local function loadProfile(player)
	local loadedData = nil
	local loadError = nil
	if dataStoreEnabled() then
		local ok, result = pcall(function()
			return getStore():GetAsync(profileKey(player))
		end)
		if ok then
			loadedData = result
		else
			loadError = tostring(result)
			warnLine("DataStore load failed for " .. player.Name .. ": " .. loadError)
		end
	end

	local profile = schema.FromDataStore(loadedData, startingCash())
	local session = {
		Profile = profile,
		Loaded = true,
		Dirty = false,
		LastDirtyReason = "",
		LastSaveUnix = 0,
		LastError = loadError,
		DataStoreEnabledAtLoad = dataStoreEnabled(),
	}
	sessions[player.UserId] = session
	player:SetAttribute("NTR_ProfileServiceLoaded", true)
	player:SetAttribute("NTR_ProfileSchemaVersion", schema.SchemaVersion)
	player:SetAttribute("NTR_ProfileDataStoreEnabled", dataStoreEnabled())
	updateRuntimeMarker(player, session)
	return session
end

local function markDirty(player, reason)
	local session = sessionFor(player)
	if not session then
		return false, "Profile is not loaded."
	end
	session.Dirty = true
	session.LastDirtyReason = tostring(reason or "unspecified")
	updateRuntimeMarker(player, session)
	return true, "Marked dirty."
end

local function saveProfile(player, force)
	local session = sessionFor(player)
	if not session then
		return false, "Profile is not loaded."
	end
	if not force and not session.Dirty then
		return true, "No changes to save."
	end
	local now = os.time()
	if not force and session.LastSaveAttemptUnix and now - session.LastSaveAttemptUnix < saveDebounceSeconds() then
		return true, "Save debounce active."
	end
	session.LastSaveAttemptUnix = now

	local safe, encodedOrError = schema.AssertDataStoreSafe(session.Profile)
	if not safe then
		session.LastError = tostring(encodedOrError)
		updateRuntimeMarker(player, session)
		return false, "Profile is not DataStore-safe: " .. tostring(encodedOrError)
	end

	if not dataStoreEnabled() then
		session.Dirty = false
		session.LastSaveUnix = now
		session.LastError = "DataStore disabled; dry-run save only."
		updateRuntimeMarker(player, session)
		return true, "DataStore disabled; dry-run save only."
	end

	local encoded = schema.ToDataStore(session.Profile)
	local ok, result = pcall(function()
		return getStore():UpdateAsync(profileKey(player), function()
			return encoded
		end)
	end)
	if ok then
		session.Dirty = false
		session.LastSaveUnix = now
		session.LastError = ""
		updateRuntimeMarker(player, session)
		return true, "Saved."
	end

	session.LastError = tostring(result)
	updateRuntimeMarker(player, session)
	warnLine("DataStore save failed for " .. player.Name .. ": " .. tostring(result))
	return false, tostring(result)
end

getProfileBinding.OnInvoke = function(player)
	local session = sessionFor(player)
	return session and session.Profile or nil
end

getSummaryBinding.OnInvoke = function(player)
	local session = sessionFor(player)
	if not session then
		return nil
	end
	local summary = schema.Summarize(session.Profile)
	summary.Loaded = session.Loaded == true
	summary.Dirty = session.Dirty == true
	summary.DataStoreEnabled = dataStoreEnabled()
	summary.LastError = session.LastError
	return summary
end

markDirtyBinding.OnInvoke = function(player, reason)
	return markDirty(player, reason)
end

saveNowBinding.OnInvoke = function(player)
	return saveProfile(player, true)
end

isLoadedBinding.OnInvoke = function(player)
	local session = sessionFor(player)
	return session ~= nil and session.Loaded == true
end

Players.PlayerAdded:Connect(function(player)
	loadProfile(player)
end)

Players.PlayerRemoving:Connect(function(player)
	saveProfile(player, true)
	sessions[player.UserId] = nil
	local marker = runtimeProfilesFolder:FindFirstChild(tostring(player.UserId))
	if marker then
		marker:Destroy()
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		loadProfile(player)
	end)
end

task.spawn(function()
	while not shuttingDown do
		task.wait(autosaveSeconds())
		for _, player in ipairs(Players:GetPlayers()) do
			local session = sessionFor(player)
			if session and session.Dirty then
				saveProfile(player, false)
			end
		end
	end
end)

game:BindToClose(function()
	shuttingDown = true
	if RunService:IsStudio() then
		task.wait(0.2)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		saveProfile(player, true)
	end
end)

log("ProfileService foundation active. DataStoreEnabled=" .. tostring(dataStoreEnabled()))
]==]

local ntr = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = ensureFolder(ntr, "Shared")
local modules = ensureFolder(shared, "Modules")
local dataModules = ensureFolder(modules, "Data")
local schema = dataModules:FindFirstChild("PlayerProfileSchema")
if not schema or not schema:IsA("ModuleScript") then
	error("Run scripts/roblox_persistence_phase1_profile_schema.lua before Phase 2.")
end

local sharedConfig = ensureFolder(shared, "Config")
local persistenceConfig = ensureFolder(sharedConfig, "Persistence_EditAttributes")
setDefaultAttribute(persistenceConfig, "DataStoreEnabled", false)
setDefaultAttribute(persistenceConfig, "DataStoreName", "NTR_PlayerProfiles_v1")
setDefaultAttribute(persistenceConfig, "AutosaveSeconds", 90)
setDefaultAttribute(persistenceConfig, "SaveDebounceSeconds", 8)
setDefaultAttribute(persistenceConfig, "ProfileServicePhase", "Phase2_ProfileServiceFoundation")

local serverRoot = ensureFolder(ServerScriptService, "NeoTokyoRacers")
local services = ensureFolder(serverRoot, "Services")
local playerServices = ensureFolder(services, "Player")
local state = ensureFolder(serverRoot, "State")
ensureFolder(state, "RuntimeProfiles")

ensureScript(playerServices, "ProfileService_Active", profileServiceSource)

info("Installed ServerScriptService.NeoTokyoRacers.Services.Player.ProfileService_Active")
info("DataStoreEnabled defaults to false in Persistence_EditAttributes.")
info("No garage action, dealership UI, vehicle spawn, driving, or VFX scripts were patched.")
