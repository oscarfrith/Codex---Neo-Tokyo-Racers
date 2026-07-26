-- NTR_UI_PERFORMANCE_HARDENING_PHASE2_V1
-- Neo Tokyo Racers ProfileService foundation.
-- NTR_PROFILE_SERVICE_OWNED_GARAGE_COMMAND_OWNER_V1
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
local ownedGarageCommandRuntime = require(services:WaitForChild("Garage"):WaitForChild("OwnedGarageAuthoritativeCommandRuntime"))
local playerServices = ensureFolder(services, "Player")
local stateRoot = ensureFolder(serverRoot, "State")
local runtimeProfilesFolder = ensureFolder(stateRoot, "RuntimeProfiles")
local bindings = ensureFolder(playerServices, "ProfileServiceBindings")

local getProfileBinding = ensureBindableFunction(bindings, "GetProfile")
local getSummaryBinding = ensureBindableFunction(bindings, "GetSummary")
local markDirtyBinding = ensureBindableFunction(bindings, "MarkDirty")
local saveNowBinding = ensureBindableFunction(bindings, "SaveNow")
local importProfileSnapshotBinding = ensureBindableFunction(bindings, "ImportProfileSnapshot")
local executeOwnedGarageCommandBinding = ensureBindableFunction(bindings, "ExecuteOwnedGarageCommand")
local executeOnboardingCommandBinding = ensureBindableFunction(bindings, "ExecuteOnboardingCommand") -- NTR_PROFILE_SERVICE_ONBOARDING_COMMAND_OWNER_V1
local garageCleanupTransactionBinding = ensureBindableFunction(bindings, "GarageModuleInventoryCleanupTransaction") -- NTR_GARAGE_MODULE_INVENTORY_IMPORT_LOCK_V1
local isLoadedBinding = ensureBindableFunction(bindings, "IsLoaded")

local sessions = {}
local ownedGarageCommandLocks = {}
local garageCleanupTransactions = {}
local profileLoadsInFlight = {} -- NTR_PROFILE_SERVICE_SINGLE_FLIGHT_LOAD_V1
local profileLoadGenerations = {} -- NTR_PROFILE_SERVICE_LIFECYCLE_GENERATION_V1
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
	if cleanupTransaction
		and cleanupTransaction.Player == player
		and cleanupTransaction.PinnedSession
		and cleanupTransaction.PinnedSession.Player == player then
		return cleanupTransaction.PinnedSession
	end
	local session = sessions[userId]
	if session and session.Player == player then
		return session
	end
	return nil
end -- NTR_PROFILE_SERVICE_SESSION_OWNERSHIP_HARDENING_V1

local function updateRuntimeMarker(player, session)
	local marker = runtimeProfilesFolder:FindFirstChild(tostring(player.UserId))
	if not marker then
		marker = Instance.new("Folder")
		marker.Name = tostring(player.UserId)
		marker.Parent = runtimeProfilesFolder
	end
	marker:SetAttribute("PlayerName", player.Name)
	marker:SetAttribute("SessionGeneration", session.SessionGeneration)
	marker:SetAttribute("SessionId", session.SessionId)
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

-- NTR Studio vehicle sandbox: authoritative in-memory profile mutation with a hard no-save guard.
local function studioVehicleSandboxConfig()
	if not RunService:IsStudio() then return nil end
	local runtime = ntr:FindFirstChild("Config") and ntr.Config:FindFirstChild("Runtime")
	local onboarding = runtime and runtime:FindFirstChild("Onboarding_EditAttributes")
	if not onboarding or onboarding:GetAttribute("StudioVehicleSandboxEveryPlay") ~= true then return nil end
	return onboarding
end

local function clearVehicleReferences(spaces)
	if type(spaces) ~= "table" then return end
	for key, space in pairs(spaces) do
		if type(space) == "table" then
			space.VehicleId = nil
		elseif space ~= nil then
			spaces[key] = false
		end
	end
end

local function applyStudioVehicleSandbox(player, profile)
	local onboarding = studioVehicleSandboxConfig()
	if not onboarding then
		player:SetAttribute("NTR_StudioVehicleSandboxActive", nil)
		return false
	end
	profile.Vehicles = {}
	profile.OwnedCockpitInstances = {}
	profile.OwnedModuleInstances = {}
	profile.CurrentVehicleId = nil
	profile.OwnedCockpits = {}
	profile.OwnedModules = {}
	profile.InstalledModules = {}
	profile.ModuleColors = {}
	profile.NeonOwned = {}
	profile.ModuleUpgradeLevels = {}
	clearVehicleReferences(profile.GarageDisplaySpaces)
	if type(profile.Garage) == "table" then clearVehicleReferences(profile.Garage.DisplaySpaces) end
	if type(profile.OwnedGarage) == "table" and type(profile.OwnedGarage.Properties) == "table" then
		for _, property in pairs(profile.OwnedGarage.Properties) do
			if type(property) == "table" then clearVehicleReferences(property.DisplaySpaces) end
		end
	end
	local testCash = math.max(0, tonumber(onboarding:GetAttribute("StudioVehicleSandboxCash")) or 1000000)
	profile.Cash = math.max(tonumber(profile.Cash) or 0, testCash)
	player:SetAttribute("NTR_StudioVehicleSandboxActive", true)
	log("STUDIO VEHICLE SANDBOX active player=" .. player.Name .. " saves suppressed")
	return true
end

local function loadProfile(player)
	local userId = player.UserId
	local existingSession = sessions[userId]
	if existingSession then
		if existingSession.Player == player then
			log("PROFILE LOAD REUSED existing session player=" .. player.Name)
			return existingSession
		end
		warnLine("PROFILE LOAD BLOCKED by a different player lifecycle userId=" .. tostring(userId))
		return nil
	end
	if profileLoadsInFlight[userId] then
		warnLine("DUPLICATE PROFILE LOAD SUPPRESSED player=" .. player.Name)
		return nil
	end

	local generation = (profileLoadGenerations[userId] or 0) + 1
	profileLoadGenerations[userId] = generation
	local loadTicket = {Player = player, Generation = generation}
	profileLoadsInFlight[userId] = loadTicket

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

	-- NTR_PROFILE_SERVICE_PLAYER_LIFECYCLE_GUARD_V1
	local activeSession = sessions[userId]
	local ownsTicket = profileLoadsInFlight[userId] == loadTicket
	local generationIsCurrent = profileLoadGenerations[userId] == generation
	if player.Parent ~= Players or not ownsTicket or not generationIsCurrent or activeSession then
		if ownsTicket then profileLoadsInFlight[userId] = nil end
		warnLine("LATE PROFILE LOAD DISCARDED player=" .. player.Name)
		if activeSession and activeSession.Player == player then return activeSession end
		return nil
	end

	local profile = schema.FromDataStore(loadedData, startingCash())
	local studioVehicleSandbox = applyStudioVehicleSandbox(player, profile)
	local session = {
		Player = player,
		SessionGeneration = generation,
		SessionId = HttpService:GenerateGUID(false),
		Profile = profile,
		Loaded = true,
		Dirty = false,
		LastDirtyReason = "",
		LastSaveUnix = 0,
		LastError = loadError,
		DataStoreEnabledAtLoad = dataStoreEnabled(),
		StudioVehicleSandbox = studioVehicleSandbox,
		NoSave = studioVehicleSandbox,
	}
	sessions[userId] = session
	profileLoadsInFlight[userId] = nil
	player:SetAttribute("NTR_ProfileServiceLoaded", true)
	player:SetAttribute("NTR_ProfileSchemaVersion", schema.SchemaVersion)
	player:SetAttribute("NTR_ProfileDataStoreEnabled", dataStoreEnabled())
	player:SetAttribute("NTR_ProfileSessionGeneration", generation)
	player:SetAttribute("NTR_ProfileSessionId", session.SessionId)
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

local function reconcileTableIdentity(target, source, visited)
	-- Preserve all existing authoritative table identities while adopting normalized values.
	if target == source then return end
	visited = visited or {}
	if visited[target] == source then return end
	visited[target] = source
	for key in pairs(target) do
		if source[key] == nil then target[key] = nil end
	end
	for key, sourceValue in pairs(source) do
		local targetValue = target[key]
		if typeof(targetValue) == "table" and typeof(sourceValue) == "table" then
			reconcileTableIdentity(targetValue, sourceValue, visited)
		else
			target[key] = sourceValue
		end
	end
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
	local normalized = schema.Normalize(snapshot, startingCash())
	-- Generic garage/racing snapshots do not own authoritative onboarding state.
	normalized.Onboarding = session.Profile.Onboarding -- NTR_PROFILE_SERVICE_ONBOARDING_IMPORT_PROTECTION_V1
	if normalized ~= session.Profile then
		reconcileTableIdentity(session.Profile, normalized)
	end
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
	if session.NoSave == true then
		session.Dirty = false
		session.LastSaveUnix = os.time()
		session.LastError = "Studio vehicle sandbox; save suppressed."
		updateRuntimeMarker(player, session)
		return true, "Studio vehicle sandbox; save suppressed."
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

executeOwnedGarageCommandBinding.OnInvoke = function(player, command)
	local session = sessionFor(player)
	if not session then return {Success = false, Message = "Profile is not loaded."} end
	local userId = player.UserId
	if ownedGarageCommandLocks[userId] then return {Success = false, Message = "Owned garage command already in progress.", Busy = true} end
	ownedGarageCommandLocks[userId] = session
	local expectedGeneration = session.SessionGeneration
	local ok, result = pcall(function() return ownedGarageCommandRuntime.Execute(player, session.Profile, command, function(reason)
		local current = sessionFor(player)
		if current ~= session or current.SessionGeneration ~= expectedGeneration then return false, "Profile session changed during owned garage command." end
		return markDirty(player, reason)
	end) end)
	if ownedGarageCommandLocks[userId] == session then ownedGarageCommandLocks[userId] = nil end
	if not ok then return {Success = false, Message = "Owned garage command failed: " .. tostring(result)} end
	if type(result) == "table" then result.SessionGeneration = expectedGeneration; result.SessionId = session.SessionId end
	return result
end

-- NTR_PROFILE_SERVICE_ONBOARDING_COMMAND_OWNER_V1_3_STUDIO_VEHICLE_SANDBOX
executeOnboardingCommandBinding.OnInvoke = function(player, command)
	local session = sessionFor(player)
	if not session then return {Success=false, Message="Profile is not loaded."} end
	command = type(command) == "table" and command or {}
	local profile = session.Profile
	local firstOnboardingLoad = type(profile.Onboarding) ~= "table"
	profile.Onboarding = type(profile.Onboarding) == "table" and profile.Onboarding or {}
	local state = profile.Onboarding
	state.SeenPages = type(state.SeenPages) == "table" and state.SeenPages or {}
	state.Completed = type(state.Completed) == "table" and state.Completed or {}
	local action = tostring(command.Action or "Get")
	local changed = false
	local hasExistingVehicle = next(type(profile.Vehicles)=="table" and profile.Vehicles or {})~=nil
	if hasExistingVehicle and firstOnboardingLoad then
		state.Completed.FirstVehiclePurchased=true
		state.Completed.FirstVehicleDriven=true
		changed=true
	elseif hasExistingVehicle and state.Completed.FirstVehicleDriven==true and state.Completed.FirstVehiclePurchased~=true then
		state.Completed.FirstVehiclePurchased=true
		changed=true
	end
	if action == "MarkSeen" then
		local pageId = tostring(command.PageId or "")
		if pageId ~= "" and state.SeenPages[pageId] ~= true then state.SeenPages[pageId] = true; changed = true end
	elseif action == "RecordProgress" then
		local progressId = tostring(command.ProgressId or "")
		local allowed = {FirstVehiclePurchased=true, FirstVehicleDriven=true, FirstEventEntered=true, GarageManagementEntered=true}
		if allowed[progressId] and state.Completed[progressId] ~= true then state.Completed[progressId] = true; changed = true end
	elseif action ~= "Get" then
		return {Success=false, Message="Unknown onboarding command."}
	end
	if changed then markDirty(player, "Onboarding:" .. action) end
	local stage = (state.Completed.FirstVehiclePurchased ~= true or state.Completed.FirstVehicleDriven ~= true) and 1
		or state.Completed.GarageManagementEntered ~= true and 2
		or state.Completed.FirstEventEntered ~= true and 3
		or 4
	return {Success=true, Stage=stage, SeenPages=state.SeenPages, Completed=state.Completed, Changed=changed}
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
		if not currentSession or currentSession.Player ~= player then
			return false, "Profile is not loaded for this player lifecycle."
		end
		garageCleanupTransactions[userId] = {
			Player = player,
			SessionGeneration = currentSession.SessionGeneration,
			BlockedCount = 0,
			LastBlockedReason = "",
			PinnedSession = currentSession,
		}
		return true, "Garage inventory cleanup transaction started."
	elseif mode == "End" then
		local result = garageCleanupTransactions[userId]
		if result and result.Player ~= player then
			return false, "Cleanup transaction belongs to a different player lifecycle."
		end
		if result and result.PinnedSession then
			result.ReplacedSessionDuringTransaction = sessions[userId] ~= result.PinnedSession
			result.PinnedSession = nil
			result.Player = nil
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
	local userId = player.UserId
	ownedGarageCommandLocks[userId] = nil
	ownedGarageCommandRuntime.ForgetPlayer(player)
	local leavingSession = sessions[userId]
	profileLoadGenerations[userId] = (profileLoadGenerations[userId] or 0) + 1
	profileLoadsInFlight[userId] = nil
	garageCleanupTransactions[userId] = nil
	if leavingSession and leavingSession.Player == player then
		saveProfile(player, true)
		if sessions[userId] == leavingSession then sessions[userId] = nil end
	end
	player:SetAttribute("NTR_ProfileServiceLoaded", nil)
	player:SetAttribute("NTR_ProfileSessionGeneration", nil)
	player:SetAttribute("NTR_ProfileSessionId", nil)
	local marker = runtimeProfilesFolder:FindFirstChild(tostring(userId))
	if marker and not sessions[userId]
		and (not leavingSession or marker:GetAttribute("SessionId") == leavingSession.SessionId) then
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
