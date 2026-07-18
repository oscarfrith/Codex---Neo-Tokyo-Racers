-- NTR_UI_PERFORMANCE_HARDENING_PHASE2_V1
-- Neo Tokyo Racers ProfileService foundation.
-- Persistence Phase 2. Session profile lifecycle plus optional DataStore plumbing.
-- DataStoreEnabled defaults to false through Persistence_EditAttributes.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
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
local importProfileSnapshotBinding = ensureBindableFunction(bindings, "ImportProfileSnapshot")
local garageCleanupTransactionBinding = ensureBindableFunction(bindings, "GarageModuleInventoryCleanupTransaction") -- NTR_GARAGE_MODULE_INVENTORY_IMPORT_LOCK_V1
local isLoadedBinding = ensureBindableFunction(bindings, "IsLoaded")

local sessions = {}
local garageCleanupTransactions = {}
local profileLoadsInFlight = {} -- NTR_PROFILE_SERVICE_SINGLE_FLIGHT_LOAD_V1
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
	local userId = player.UserId
	local cleanupTransaction = garageCleanupTransactions[userId]
	if cleanupTransaction and cleanupTransaction.PinnedSession then
		return cleanupTransaction.PinnedSession
	end
	return sessions[userId]
end -- NTR_PROFILE_SERVICE_SESSION_OWNERSHIP_HARDENING_V1

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
	local userId = player.UserId
	local existingSession = sessions[userId]
	if existingSession then
		log("PROFILE LOAD REUSED existing session player=" .. player.Name)
		return existingSession
	end
	if profileLoadsInFlight[userId] then
		warnLine("DUPLICATE PROFILE LOAD SUPPRESSED player=" .. player.Name)
		return nil
	end
	profileLoadsInFlight[userId] = true

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
	local activeSession = sessions[userId]
	if activeSession then
		profileLoadsInFlight[userId] = nil
		warnLine("LATE PROFILE LOAD DISCARDED player=" .. player.Name)
		return activeSession
	end
	sessions[userId] = session
	profileLoadsInFlight[userId] = nil
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

local function importProfileSnapshot(player, snapshot, reason, dirty)
	-- NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT
	local cleanupTransaction = player and garageCleanupTransactions[player.UserId]
	if cleanupTransaction then
		cleanupTransaction.BlockedCount += 1
		cleanupTransaction.LastBlockedReason = tostring(reason or "unspecified")
		warnLine("PROFILE IMPORT BLOCKED during garage inventory cleanup player=" .. player.Name
			.. " reason=" .. cleanupTransaction.LastBlockedReason)
		return false, "Profile import blocked during garage inventory cleanup transaction."
	end
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
	if not force and not session.Dirty then
		return true, "No changes to save."
	end
	local now = os.time()
	if not force and session.LastSaveAttemptUnix and now - session.LastSaveAttemptUnix < saveDebounceSeconds() then
		return true, "Save debounce active."
	end
	session.LastSaveAttemptUnix = now

	local encodeStarted = os.clock()
	local converted, encodedOrError = pcall(schema.ToDataStore, session.Profile)
	local encoded = converted and encodedOrError or nil
	local safe, jsonOrError = false, encodedOrError
	if converted then safe, jsonOrError = pcall(function() return HttpService:JSONEncode(encoded) end) end
	local encodeMilliseconds = (os.clock() - encodeStarted) * 1000
	if encodeMilliseconds >= math.max(1, tonumber(getAttr("ProfileEncodeWarnMilliseconds", 16)) or 16) then warnLine("PROFILE ENCODE SLOW " .. string.format("%.1f", encodeMilliseconds) .. "ms player=" .. player.Name .. " reason=" .. tostring(session.LastDirtyReason or "unknown")) end
	if not safe then
		session.LastError = tostring(jsonOrError)
		updateRuntimeMarker(player, session)
		return false, "Profile is not DataStore-safe: " .. tostring(jsonOrError)
	end

	if not dataStoreEnabled() then
		session.Dirty = false
		session.LastSaveUnix = now
		session.LastError = "DataStore disabled; dry-run save only."
		updateRuntimeMarker(player, session)
		return true, "DataStore disabled; dry-run save only."
	end

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

importProfileSnapshotBinding.OnInvoke = function(player, snapshot, reason, dirty)
	return importProfileSnapshot(player, snapshot, reason, dirty)
end

garageCleanupTransactionBinding.OnInvoke = function(player, mode)
	if not player then return false, "Player is required." end
	local userId = player.UserId
	if mode == "Begin" then
		if garageCleanupTransactions[userId] then
			return false, "A garage inventory cleanup transaction is already active."
		end
		local currentSession = sessions[userId]
		if not currentSession then
			return false, "Profile is not loaded."
		end
		garageCleanupTransactions[userId] = {
			BlockedCount = 0,
			LastBlockedReason = "",
			PinnedSession = currentSession,
		}
		return true, "Garage inventory cleanup transaction started."
	elseif mode == "End" then
		local result = garageCleanupTransactions[userId]
		if result and result.PinnedSession then
			result.ReplacedSessionDuringTransaction = sessions[userId] ~= result.PinnedSession
			sessions[userId] = result.PinnedSession
			result.PinnedSession = nil
		end
		garageCleanupTransactions[userId] = nil
		return true, result or {BlockedCount = 0, LastBlockedReason = "", ReplacedSessionDuringTransaction = false}
	end
	return false, "Unknown garage inventory cleanup transaction mode."
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

log("ProfileService foundation active. DataStoreEnabled=" .. tostring(dataStoreEnabled()) .. " AutosaveSeconds=" .. tostring(autosaveSeconds()) .. " EncodeWarnMs=" .. tostring(getAttr("ProfileEncodeWarnMilliseconds",16))) 
