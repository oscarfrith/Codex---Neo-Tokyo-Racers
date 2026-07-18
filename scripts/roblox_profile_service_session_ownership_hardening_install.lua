-- Neo Tokyo Racers - ProfileService session ownership hardening installer
-- NTR_PROFILE_SERVICE_SESSION_OWNERSHIP_HARDENING_INSTALL_V1
-- Run once in Studio Edit mode after the single-flight load guard installer.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PREFIX = "[NTR ProfileService Session Ownership] "
local MARKER = "NTR_PROFILE_SERVICE_SESSION_OWNERSHIP_HARDENING_V1"
local REQUIRED_MARKER = "NTR_PROFILE_SERVICE_SINGLE_FLIGHT_LOAD_V1"

if RunService:IsRunning() then
	error(PREFIX .. "Stop Play and run this installer in Edit mode.", 0)
end

local ntr = ServerScriptService:FindFirstChild("NeoTokyoRacers")
local services = ntr and ntr:FindFirstChild("Services")
local playerServices = services and services:FindFirstChild("Player")
local profileService = playerServices and playerServices:FindFirstChild("ProfileService_Active")
if not (profileService and profileService:IsA("LuaSourceContainer")) then
	error(PREFIX .. "ProfileService_Active is missing.", 0)
end

local originalSource = profileService.Source
if not string.find(originalSource, REQUIRED_MARKER, 1, true) then
	error(PREFIX .. "Single-flight load guard marker missing; run roblox_profile_service_single_flight_load_guard_install.lua first.", 0)
end

local function replaceOnce(source, anchor, replacement, label)
	local first, last = string.find(source, anchor, 1, true)
	if not first then error(PREFIX .. "Missing source anchor: " .. tostring(label), 0) end
	if string.find(source, anchor, last + 1, true) then
		error(PREFIX .. "Source anchor is not unique: " .. tostring(label), 0)
	end
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last + 1)
end

local stagedSource = originalSource
if not string.find(stagedSource, MARKER, 1, true) then
	stagedSource = replaceOnce(
		stagedSource,
		[=[local function sessionFor(player)
	if not player then
		return nil
	end
	return sessions[player.UserId]
end]=],
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
		"session owner resolver"
	)
	stagedSource = replaceOnce(
		stagedSource,
		[=[	local session = {
		Profile = profile,
		Loaded = true,
		Dirty = false,
		LastDirtyReason = "",
		LastSaveUnix = 0,
		LastError = loadError,
		DataStoreEnabledAtLoad = dataStoreEnabled(),
	}
	sessions[player.UserId] = session
	profileLoadsInFlight[userId] = nil]=],
		[=[	local session = {
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
	profileLoadsInFlight[userId] = nil]=],
		"load commit ownership gate"
	)
	stagedSource = replaceOnce(
		stagedSource,
		[=[		garageCleanupTransactions[userId] = {BlockedCount = 0, LastBlockedReason = ""}
		return true, "Garage inventory cleanup transaction started."
	elseif mode == "End" then
		local result = garageCleanupTransactions[userId]
		garageCleanupTransactions[userId] = nil
		return true, result or {BlockedCount = 0, LastBlockedReason = ""}]=],
		[=[		local currentSession = sessions[userId]
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
		return true, result or {BlockedCount = 0, LastBlockedReason = "", ReplacedSessionDuringTransaction = false}]=],
		"cleanup session pin"
	)
end

if #stagedSource >= 195000 then
	error(PREFIX .. "Staged ProfileService source is too large: " .. tostring(#stagedSource), 0)
end

local function audit()
	local source = profileService.Source
	local failures = {}
	local function check(condition, message)
		if not condition then table.insert(failures, message) end
	end
	check(string.find(source, MARKER, 1, true) ~= nil, "session ownership marker missing")
	check(string.find(source, "LATE PROFILE LOAD DISCARDED", 1, true) ~= nil, "late-load commit gate missing")
	check(string.find(source, "PinnedSession = currentSession", 1, true) ~= nil, "cleanup session pin missing")
	check(string.find(source, "ReplacedSessionDuringTransaction", 1, true) ~= nil, "replacement diagnostic missing")
	if #failures > 0 then return false, table.concat(failures, " | ") end
	return true, "profile session ownership hardened"
end

local ok, installError = pcall(function()
	profileService.Source = stagedSource
	local auditOk, auditMessage = audit()
	if not auditOk then error(auditMessage) end
end)

if not ok then
	pcall(function() profileService.Source = originalSource end)
	error(PREFIX .. "Installation rolled back: " .. tostring(installError), 0)
end

profileService:SetAttribute("SessionOwnershipHardeningVersion", 1)
print(PREFIX .. "INSTALL PASS - late loads are discarded and cleanup pins its exact session")
print(PREFIX .. "NEXT start a fresh Play session and run the updated cleanup apply script")
