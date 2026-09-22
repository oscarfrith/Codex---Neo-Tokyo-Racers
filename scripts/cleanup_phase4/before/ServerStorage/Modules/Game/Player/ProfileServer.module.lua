-- Canonical feature implementation; startup is owned by the composition root.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
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
	print("[" .. PHASE .. "] " .. message)
end

local function warnLine(message)
	warn("[" .. PHASE .. "] " .. message)
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

local ntr = game:GetService("ReplicatedStorage")
local schema = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Player"):WaitForChild("PlayerProfileSchema"))

local config = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Player"):WaitForChild("Persistence")

local serverRoot = game:GetService("ServerStorage"):WaitForChild("Runtime")
local services = game:GetService("ServerStorage"):WaitForChild("Runtime")
local ownedGarageCommandRuntime = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("OwnedGarageAuthoritativeCommand"))
local playerServices = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Player")
local stateRoot = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Player")
local runtimeProfilesFolder = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Player"):WaitForChild("RuntimeProfiles")
local bindings = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Player"):WaitForChild("ProfileServiceBindings")

local getProfileBinding = ensureBindableFunction(bindings, "GetProfile")
local getSummaryBinding = ensureBindableFunction(bindings, "GetSummary")
local markDirtyBinding = ensureBindableFunction(bindings, "MarkDirty")
local saveNowBinding = ensureBindableFunction(bindings, "SaveNow")
local importProfileSnapshotBinding = ensureBindableFunction(bindings, "ImportProfileSnapshot")
local executeOwnedGarageCommandBinding = ensureBindableFunction(bindings, "ExecuteOwnedGarageCommand")
local executeOnboardingCommandBinding = ensureBindableFunction(bindings, "ExecuteOnboardingCommand") -- NTR_PROFILE_SERVICE_ONBOARDING_COMMAND_OWNER_V1
local executeEconomyCommandBinding = ensureBindableFunction(bindings, "ExecuteEconomyCommand") -- NTR_PROFILE_SERVICE_ECONOMY_COMMAND_OWNER_V1
local economyCashCommittedEvent = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Player"):WaitForChild("ProfileServiceBindings"):FindFirstChild("EconomyCashCommitted")
if economyCashCommittedEvent and not economyCashCommittedEvent:IsA("BindableEvent") then
	error(economyCashCommittedEvent:GetFullName() .. " must be a BindableEvent")
end
if not economyCashCommittedEvent then
	economyCashCommittedEvent = Instance.new("BindableEvent")
	economyCashCommittedEvent.Name = "EconomyCashCommitted"
	economyCashCommittedEvent.Parent = bindings
end
local garageCleanupTransactionBinding = ensureBindableFunction(bindings, "GarageModuleInventoryCleanupTransaction") -- NTR_GARAGE_MODULE_INVENTORY_IMPORT_LOCK_V1
local isLoadedBinding = ensureBindableFunction(bindings, "IsLoaded")

local ProfileStore = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Player"):WaitForChild("ProfileStore"))
local Compatibility = require(game.ServerStorage.Modules.Game.Player.ProfileCompatibility)
local sessions = {}
local ownedGarageCommandLocks = {}
local garageCleanupTransactions = {}
local profileLoadsInFlight = {} -- NTR_PROFILE_SERVICE_SINGLE_FLIGHT_LOAD_V1
local profileLoadGenerations = {} -- NTR_PROFILE_SERVICE_LIFECYCLE_GENERATION_V1
local shuttingDown = false
local economyCommandLocks = {} -- NTR_PROFILE_SERVICE_ECONOMY_COMMAND_OWNER_V1

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
	local active = sessions[userId]
	if active and (active.Closing or active.Released or not active.Loaded
		or not active.NoSave and (active.LeaseUntil or 0) <= os.time()) then return nil end
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
	local runtime = game:GetService("ReplicatedStorage"):FindFirstChild("Config") and game:GetService("ReplicatedStorage"):FindFirstChild("Config")
	local onboarding = runtime and game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Player"):FindFirstChild("Onboarding")
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
		player:SetAttribute("StudioVehicleSandboxActive", nil)
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
	player:SetAttribute("StudioVehicleSandboxActive", true)
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

	local loadedData, loadError
	local token = HttpService:GenerateGUID(false)
	local enabledAtLoad = dataStoreEnabled()
	local noSave = not enabledAtLoad or studioVehicleSandboxConfig() ~= nil
	local transport = ProfileStore.new(enabledAtLoad and getStore() or nil)
	local loadDeadline = os.clock() + 25
	local leaseUntil = 0
	local function currentLoad()
		return not shuttingDown and player.Parent == Players and profileLoadsInFlight[userId] == loadTicket
			and profileLoadGenerations[userId] == generation and os.clock() < loadDeadline
	end
	if enabledAtLoad then
		local ok, result, info
		if noSave then
			ok, result = pcall(function() return getStore():GetAsync(profileKey(player)) end)
		else
			ok, result, info = transport:acquire(profileKey(player), token,
				schema.ToDataStore(schema.FromDataStore(nil, startingCash())), currentLoad)
		end
		if ok then
			loadedData = result
			local metadata = info and info:GetMetadata()
			leaseUntil = metadata and metadata.NTRSessionLeaseUntil or 0
		else loadError = tostring(result) end
	end
	if not noSave and (loadError or not currentLoad()) then
		-- Release a successful but late acquisition without replacing its data.
		if not loadError then transport:write(profileKey(player), token, nil, true) end
		if profileLoadsInFlight[userId] == loadTicket then profileLoadsInFlight[userId] = nil end
		player:SetAttribute("ProfileServiceLoaded", false)
		warnLine("Profile unavailable player=" .. player.Name .. " reason=" .. tostring(loadError or "Cancelled"))
		if player.Parent == Players then player:Kick("Your data is temporarily unavailable or still open in another server. Please rejoin shortly.") end
		return nil
	end
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
		SessionId = token,
		Key = profileKey(player),
		Transport = transport,
		LeaseUntil = leaseUntil,
		Revision = 0,
		Profile = profile,
		Loaded = true,
		Dirty = false,
		LastDirtyReason = "",
		LastSaveUnix = 0,
		LastError = loadError,
		DataStoreEnabledAtLoad = enabledAtLoad,
		StudioVehicleSandbox = studioVehicleSandbox,
		NoSave = noSave,
	}
	sessions[userId] = session
	profileLoadsInFlight[userId] = nil
	player:SetAttribute("ProfileServiceLoaded", true)
	player:SetAttribute("ProfileSchemaVersion", schema.SchemaVersion)
	player:SetAttribute("ProfileDataStoreEnabled", dataStoreEnabled())
	player:SetAttribute("ProfileSessionGeneration", generation)
	player:SetAttribute("ProfileSessionId", session.SessionId)
	updateRuntimeMarker(player, session)
	return session
end

local function markDirty(player, reason)
	local session = sessionFor(player)
	if not session then
		return false, "Profile is not loaded."
	end
	session.Dirty = true
	session.Revision += 1
	session.LastDirtyReason = tostring(reason or "unspecified")
	updateRuntimeMarker(player, session)
	return true, "Marked dirty."
end

local function importProfileSnapshot()
	return false, "Whole-profile import retired; use the authoritative feature command."
end

Service.get_profile = function(player)
	local session=sessionFor(player)
	return session and session.Profile or nil
end
Service.get_garage_profile = function(player, hydrate)
	local session=sessionFor(player)
	if not session then return nil end
	if not session.GarageViewReady then
		Compatibility.attach(session.Profile, hydrate(session.Profile))
		session.GarageViewReady=true
	end
	return session.Profile
end
Service.commit_garage = function(player, profile, reason, dirty)
	local session=sessionFor(player)
	if not session or session.Profile~=profile then return false, "Profile session changed." end
	Compatibility.commit(profile)
	if dirty then return markDirty(player, reason) end
	return true
end
Service.mark_dirty = function(player, profile, reason)
	local session=sessionFor(player)
	if not session or session.Profile~=profile then return false, "Profile session changed." end
	return markDirty(player, reason)
end

local function saveProfile(player, force, release, deadline)
	local session = sessions[player.UserId]
	if not session or session.Player ~= player then return false, "Profile is not loaded." end
	if session.Closing and not release then return false, "Profile is closing." end
	if not force and os.time() - (session.LastSaveAttemptUnix or 0) < saveDebounceSeconds() then return false, "Debounced" end
	session.LastSaveAttemptUnix = os.time()
	local ok, message = session.Transport:save(session, function(profile)
		local data = schema.ToDataStore(Compatibility.persistent(profile))
		HttpService:JSONEncode(data) -- Reject non-serialisable values before any write.
		return data
	end, release, deadline)
	if message == "SessionLost" then
		session.Loaded = false
		player:SetAttribute("ProfileServiceLoaded", false)
		if player.Parent == Players then player:Kick("Your data session changed. Please rejoin.") end
	end
	if sessions[player.UserId] == session then updateRuntimeMarker(player, session) end
	if not ok and message ~= "Busy" then warnLine("Save failed player=" .. player.Name .. " reason=" .. tostring(message)) end
	return ok, message
end

local function closeProfile(player)
	local session = sessions[player.UserId]
	if not session or session.Player ~= player or session.CloseStarted then return end
	session.CloseStarted = true
	session.Closing = true
	player:SetAttribute("ProfileServiceLoaded", false)
	local deadline = os.clock() + 25
	while session.Saving and os.clock() < deadline do task.wait(0.05) end
	if not session.Saving and os.clock() < deadline then saveProfile(player, true, true, deadline) end
	session.CloseFinished = true
end

local EconomyServer = require(game.ServerStorage.Modules.Game.Player.EconomyServer)
EconomyServer.init({ntr=ntr,sessionFor=sessionFor,economyCommandLocks=economyCommandLocks,updateRuntimeMarker=updateRuntimeMarker,executeEconomyCommandBinding=executeEconomyCommandBinding,economyCashCommittedEvent=economyCashCommittedEvent,warnLine=warnLine,Players=Players})

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
	return session and Compatibility.persistent(session.Profile) or nil
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
	economyCommandLocks[userId] = nil -- NTR_PROFILE_SERVICE_ECONOMY_COMMAND_OWNER_V1
	ownedGarageCommandRuntime.ForgetPlayer(player)
	local leavingSession = sessions[userId]
	profileLoadGenerations[userId] = (profileLoadGenerations[userId] or 0) + 1
	profileLoadsInFlight[userId] = nil
	garageCleanupTransactions[userId] = nil
	if leavingSession and leavingSession.Player == player then
		closeProfile(player)
		-- A concurrent shutdown close owns final removal until its write finishes.
		while leavingSession.CloseStarted and not leavingSession.CloseFinished do task.wait(0.05) end
		if sessions[userId] == leavingSession then sessions[userId] = nil end
	end
	player:SetAttribute("ProfileServiceLoaded", nil)
	player:SetAttribute("ProfileSessionGeneration", nil)
	player:SetAttribute("ProfileSessionId", nil)
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
		task.wait(5)
		for _, session in pairs(sessions) do
			if not session.Closing and not session.Saving then
				if not session.NoSave and (session.LeaseUntil or 0) <= os.time() then
					session.Loaded = false
					session.Player:SetAttribute("ProfileServiceLoaded", false)
					session.Player:Kick("Your data connection expired. Please rejoin.")
				elseif session.Dirty and os.time() - (session.LastSaveUnix or 0) >= autosaveSeconds()
					or not session.NoSave and (session.LeaseUntil or 0) - os.time() <= 120 then
					task.spawn(saveProfile, session.Player, false)
				end
			end
		end
	end
end)

game:BindToClose(function()
	shuttingDown = true
	local pending = {}
	for _, session in pairs(sessions) do
		table.insert(pending, session)
		task.spawn(closeProfile, session.Player)
	end
	local deadline = os.clock() + 27
	while os.clock() < deadline do
		local finished = true
		for _, session in ipairs(pending) do if not session.CloseFinished then finished = false; break end end
		if finished then break end
		task.wait(0.05)
	end
end)

log("ProfileService foundation active. DataStoreEnabled=" .. tostring(dataStoreEnabled()) .. " AutosaveSeconds=" .. tostring(autosaveSeconds()) .. " EncodeWarnMs=" .. tostring(getAttr("ProfileEncodeWarnMilliseconds",16))) 

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
