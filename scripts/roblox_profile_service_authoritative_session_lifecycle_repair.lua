-- Neo Tokyo Racers - authoritative ProfileService lifecycle repair
-- NTR_PROFILE_SERVICE_AUTHORITATIVE_SESSION_LIFECYCLE_REPAIR_INSTALL_V1_1
-- Run once in Studio Edit mode after the owned garage Phase 6 V1.1 baseline.
-- Source-sensitive: exact refreshed-mirror anchors, projected compile, atomic audit, rollback.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PREFIX = "[NTR Profile Ownership Repair] "
local PROFILE_MARKER = "NTR_PROFILE_SERVICE_LIFECYCLE_GENERATION_V1"
local GARAGE_MARKER = "NTR_PROFILE_SERVICE_READ_ONLY_IMPORT_GUARD_V1"
local PROFILE_RUNTIME_MARKER = "NTR_OWNED_GARAGE_PROFILE_IDENTITY_STABILITY_V1"

if RunService:IsRunning() then
	error(PREFIX .. "Stop Play and run this installer in Edit mode.", 0)
end

local function child(parent, name)
	return parent and parent:FindFirstChild(name)
end

local ntr = child(ServerScriptService, "NeoTokyoRacers")
local services = child(ntr, "Services")
local playerServices = child(services, "Player")
local garageServices = child(services, "Garage")
local profileService = child(playerServices, "ProfileService_Active")
local garageAction = child(garageServices, "GarageActionController_Shadow_Disabled")
local ownedGarageProfile = child(garageServices, "OwnedGarageProfileRuntime")

if not (profileService and profileService:IsA("LuaSourceContainer")) then
	error(PREFIX .. "ProfileService_Active is missing.", 0)
end
if not (garageAction and garageAction:IsA("LuaSourceContainer")) then
	error(PREFIX .. "GarageActionController_Shadow_Disabled is missing.", 0)
end
if not (ownedGarageProfile and ownedGarageProfile:IsA("LuaSourceContainer")) then
	error(PREFIX .. "OwnedGarageProfileRuntime is missing.", 0)
end

local function contains(source, text)
	return string.find(source, text, 1, true) ~= nil
end

local function replaceOnce(source, anchor, replacement, label)
	local first, last = string.find(source, anchor, 1, true)
	if not first then error(PREFIX .. "Missing source anchor: " .. label, 0) end
	if string.find(source, anchor, last + 1, true) then
		error(PREFIX .. "Source anchor is not unique: " .. label, 0)
	end
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last + 1)
end

local function compile(name, source)
	local compiled, problem = loadstring(source, "=" .. name)
	if not compiled then error(PREFIX .. name .. " projected compile failed: " .. tostring(problem), 0) end
end

local originalProfileSource = profileService.Source
local originalGarageSource = garageAction.Source
local originalOwnedGarageProfileSource = ownedGarageProfile.Source
local profileAlreadyInstalled = contains(originalProfileSource, PROFILE_MARKER)
local garageAlreadyInstalled = contains(originalGarageSource, GARAGE_MARKER)
local profileRuntimeAlreadyInstalled = contains(originalOwnedGarageProfileSource, PROFILE_RUNTIME_MARKER)

if profileAlreadyInstalled ~= garageAlreadyInstalled then
	error(PREFIX .. "Partial repair markers found. Refresh the Studio mirror and repair this canonical installer before rerunning.", 0)
end

local requiredProfileMarkers = {
	"NTR_PROFILE_SERVICE_SINGLE_FLIGHT_LOAD_V1",
	"NTR_PROFILE_SERVICE_SESSION_OWNERSHIP_HARDENING_V1",
	"NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT",
}
for _, marker in ipairs(requiredProfileMarkers) do
	if not contains(originalProfileSource, marker) then
		error(PREFIX .. "ProfileService baseline marker missing: " .. marker, 0)
	end
end
if not contains(originalGarageSource, "NTR_OWNED_GARAGE_PHASE6_PERSISTENCE_PRESERVE_V1") then
	error(PREFIX .. "Owned garage Phase 6 persistence baseline marker is missing.", 0)
end

local stagedProfileSource = originalProfileSource
local stagedGarageSource = originalGarageSource
local stagedOwnedGarageProfileSource = originalOwnedGarageProfileSource

if not profileAlreadyInstalled then
	stagedProfileSource = replaceOnce(
		stagedProfileSource,
		"local profileLoadsInFlight = {} -- NTR_PROFILE_SERVICE_SINGLE_FLIGHT_LOAD_V1\nlocal shuttingDown = false",
		"local profileLoadsInFlight = {} -- NTR_PROFILE_SERVICE_SINGLE_FLIGHT_LOAD_V1\nlocal profileLoadGenerations = {} -- NTR_PROFILE_SERVICE_LIFECYCLE_GENERATION_V1\nlocal shuttingDown = false",
		"lifecycle generation owner"
	)

	stagedProfileSource = replaceOnce(
		stagedProfileSource,
		[=[local function sessionFor(player)
	if not player then
		return nil
	end
	local userId = player.UserId
	local cleanupTransaction = garageCleanupTransactions[userId]
	if cleanupTransaction and cleanupTransaction.PinnedSession then
		return cleanupTransaction.PinnedSession
	end
	return sessions[userId]
end -- NTR_PROFILE_SERVICE_SESSION_OWNERSHIP_HARDENING_V1]=],
		[=[local function sessionFor(player)
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
end -- NTR_PROFILE_SERVICE_SESSION_OWNERSHIP_HARDENING_V1]=],
		"exact player session resolver"
	)

	stagedProfileSource = replaceOnce(
		stagedProfileSource,
		[=[	marker:SetAttribute("PlayerName", player.Name)
	marker:SetAttribute("Loaded", session.Loaded == true)]=],
		[=[	marker:SetAttribute("PlayerName", player.Name)
	marker:SetAttribute("SessionGeneration", session.SessionGeneration)
	marker:SetAttribute("SessionId", session.SessionId)
	marker:SetAttribute("Loaded", session.Loaded == true)]=],
		"runtime session identity"
	)

	local oldLoadProfile = [=[local function loadProfile(player)
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
end]=]

	local newLoadProfile = [=[local function loadProfile(player)
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
end]=]
	stagedProfileSource = replaceOnce(stagedProfileSource, oldLoadProfile, newLoadProfile, "generation-owned profile load")

	stagedProfileSource = replaceOnce(
		stagedProfileSource,
		"local function importProfileSnapshot(player, snapshot, reason, dirty)\n\t-- NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT",
		[=[local function reconcileTableIdentity(target, source, visited)
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
	-- NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT]=],
		"identity-preserving import helper"
	)

	stagedProfileSource = replaceOnce(
		stagedProfileSource,
		"\tsession.Profile = schema.Normalize(snapshot, startingCash())\n\tsession.LastImportReason = tostring(reason or \"unspecified\")",
		[=[	local normalized = schema.Normalize(snapshot, startingCash())
	if normalized ~= session.Profile then
		reconcileTableIdentity(session.Profile, normalized)
	end
	session.LastImportReason = tostring(reason or "unspecified")]=],
		"in-place profile import"
	)

	local oldCleanupBinding = [=[garageCleanupTransactionBinding.OnInvoke = function(player, mode)
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
end]=]

	local newCleanupBinding = [=[garageCleanupTransactionBinding.OnInvoke = function(player, mode)
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
end]=]
	stagedProfileSource = replaceOnce(stagedProfileSource, oldCleanupBinding, newCleanupBinding, "cleanup lifecycle ownership")

	stagedProfileSource = replaceOnce(
		stagedProfileSource,
		[=[Players.PlayerRemoving:Connect(function(player)
	saveProfile(player, true)
	sessions[player.UserId] = nil
	local marker = runtimeProfilesFolder:FindFirstChild(tostring(player.UserId))
	if marker then
		marker:Destroy()
	end
end)]=],
		[=[Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
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
end)]=],
		"player removal lifecycle invalidation"
	)

	stagedGarageSource = replaceOnce(
		stagedGarageSource,
		[=[			if action == "GetInitial" then
				V56_setLeaderstats(player, profile)
				-- NTR_GARAGE_LEGACY_TO_INSTANCE_SYNC_RETIRED_V1
				V80_mirrorLegacyProfileToPersistence(player, profile, action, false)
				return { Success = true, Catalog = V56_catalog(), Profile = V56_profileForClient(profile) }]=],
		[=[			if action == "GetInitial" then
				-- NTR_PROFILE_SERVICE_READ_ONLY_IMPORT_GUARD_V1
				V56_setLeaderstats(player, profile)
				return { Success = true, Catalog = V56_catalog(), Profile = V56_profileForClient(profile) }]=],
		"read-only GetInitial import guard"
	)
end

if not profileRuntimeAlreadyInstalled then
	stagedOwnedGarageProfileSource = replaceOnce(
		stagedOwnedGarageProfileSource,
		[=[local function clone(value)
	if type(value)~="table" then return value end
	local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy
end]=],
		[=[local function clone(value)
	if type(value)~="table" then return value end
	local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy
end
-- NTR_OWNED_GARAGE_PROFILE_IDENTITY_STABILITY_V1
local function reconcile(target,source)
	if target==source then return target end
	for key in pairs(target) do if source[key]==nil then target[key]=nil end end
	for key,sourceValue in pairs(source) do
		local targetValue=target[key]
		if type(targetValue)=="table" and type(sourceValue)=="table" then reconcile(targetValue,sourceValue) else target[key]=clone(sourceValue) end
	end
	return target
end]=],
		"owned garage identity reconciler"
	)
	stagedOwnedGarageProfileSource = replaceOnce(
		stagedOwnedGarageProfileSource,
		'\tif reset==true or type(profile.OwnedGarage)~="table" or tonumber(profile.OwnedGarage.SchemaVersion)~=Runtime.SchemaVersion then profile.OwnedGarage=Runtime.DefaultGarage() end',
		[=[	if reset==true or type(profile.OwnedGarage)~="table" or tonumber(profile.OwnedGarage.SchemaVersion)~=Runtime.SchemaVersion then
		local replacement=Runtime.DefaultGarage()
		if type(profile.OwnedGarage)=="table" then reconcile(profile.OwnedGarage,replacement) else profile.OwnedGarage=replacement end
	end]=],
		"owned garage in-place schema reset"
	)
	stagedOwnedGarageProfileSource = replaceOnce(
		stagedOwnedGarageProfileSource,
		'function Runtime.Restore(profile,snapshot) profile.OwnedGarage=clone(snapshot) end',
		'function Runtime.Restore(profile,snapshot) local garage=Runtime.Ensure(profile,false); reconcile(garage,clone(snapshot)) end',
		"owned garage in-place rollback"
	)
end

compile(profileService.Name, stagedProfileSource)
compile(garageAction.Name, stagedGarageSource)
compile(ownedGarageProfile.Name, stagedOwnedGarageProfileSource)

local function sourceWindow(source, firstText, lastText)
	local first = string.find(source, firstText, 1, true)
	if not first then return "" end
	local last = string.find(source, lastText, first + #firstText, true)
	if not last then return string.sub(source, first) end
	return string.sub(source, first, last + #lastText - 1)
end

local function audit()
	local failures = {}
	local function check(condition, message)
		if not condition then table.insert(failures, message) end
	end
	local profileSource = profileService.Source
	local garageSource = garageAction.Source
	local ownedGarageProfileSource = ownedGarageProfile.Source
	local getInitialWindow = sourceWindow(garageSource, 'if action == "GetInitial" then', 'elseif action == "SelectVehicleInstance" then')
	check(contains(profileSource, PROFILE_MARKER), "lifecycle generation marker missing")
	check(contains(profileSource, "NTR_PROFILE_SERVICE_PLAYER_LIFECYCLE_GUARD_V1"), "post-yield player lifecycle gate missing")
	check(contains(profileSource, "SessionGeneration = generation"), "session generation assignment missing")
	check(contains(profileSource, "SessionId = HttpService:GenerateGUID(false)"), "stable session identity assignment missing")
	check(contains(profileSource, 'marker:SetAttribute("SessionGeneration"'), "runtime generation marker missing")
	check(contains(profileSource, 'marker:SetAttribute("SessionId"'), "runtime session marker missing")
	check(contains(profileSource, "reconcileTableIdentity(session.Profile, normalized)"), "in-place profile import missing")
	check(not contains(profileSource, "session.Profile = schema.Normalize(snapshot"), "root profile replacement remains")
	check(contains(profileSource, "profileLoadsInFlight[userId] = nil"), "in-flight cleanup missing")
	check(contains(profileSource, "garageCleanupTransactions[userId] = nil"), "cleanup transaction release missing")
	check(contains(garageSource, GARAGE_MARKER), "read-only import guard marker missing")
	check(not contains(getInitialWindow, "V80_mirrorLegacyProfileToPersistence"), "GetInitial still imports a profile snapshot")
	check(contains(ownedGarageProfileSource, PROFILE_RUNTIME_MARKER), "owned garage identity-stability marker missing")
	check(contains(ownedGarageProfileSource, "reconcile(profile.OwnedGarage,replacement)"), "owned garage schema/reset still replaces an existing table")
	check(not contains(ownedGarageProfileSource, "profile.OwnedGarage=clone(snapshot)"), "owned garage rollback still replaces the table")
	if #failures > 0 then return false, table.concat(failures, " | ") end
	return true, "lifecycle generation, identity-stable profile/OwnedGarage updates, and read-only guard are installed"
end

local originalProfileVersion = profileService:GetAttribute("AuthoritativeSessionLifecycleVersion")
local originalGarageGuardVersion = garageAction:GetAttribute("ReadOnlyProfileImportGuardVersion")
local originalOwnedGarageIdentityVersion = ownedGarageProfile:GetAttribute("ProfileIdentityStabilityVersion")

local ok, installError = pcall(function()
	if profileService.Source ~= stagedProfileSource then profileService.Source = stagedProfileSource end
	if garageAction.Source ~= stagedGarageSource then garageAction.Source = stagedGarageSource end
	if ownedGarageProfile.Source ~= stagedOwnedGarageProfileSource then ownedGarageProfile.Source = stagedOwnedGarageProfileSource end
	profileService:SetAttribute("AuthoritativeSessionLifecycleVersion", 1)
	garageAction:SetAttribute("ReadOnlyProfileImportGuardVersion", 1)
	ownedGarageProfile:SetAttribute("ProfileIdentityStabilityVersion", 1)
	local auditOk, auditMessage = audit()
	if not auditOk then error(auditMessage, 0) end
end)

if not ok then
	pcall(function() profileService.Source = originalProfileSource end)
	pcall(function() garageAction.Source = originalGarageSource end)
	pcall(function() ownedGarageProfile.Source = originalOwnedGarageProfileSource end)
	pcall(function() profileService:SetAttribute("AuthoritativeSessionLifecycleVersion", originalProfileVersion) end)
	pcall(function() garageAction:SetAttribute("ReadOnlyProfileImportGuardVersion", originalGarageGuardVersion) end)
	pcall(function() ownedGarageProfile:SetAttribute("ProfileIdentityStabilityVersion", originalOwnedGarageIdentityVersion) end)
	error(PREFIX .. "INSTALL ROLLED BACK: " .. tostring(installError), 0)
end

local auditOk, auditMessage = audit()
if not auditOk then error(PREFIX .. "POST-INSTALL AUDIT FAILED: " .. tostring(auditMessage), 0) end

print(PREFIX .. (profileAlreadyInstalled and profileRuntimeAlreadyInstalled and "ALREADY INSTALLED - AUDIT PASS" or "INSTALL PASS"))
print(PREFIX .. auditMessage)
print(PREFIX .. "NEXT run roblox_profile_service_session_ownership_readonly_audit.lua in Edit, then start fresh Play and run it from the server Command Bar")
