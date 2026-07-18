-- Neo Tokyo Racers - ProfileService single-flight player load guard installer
-- NTR_PROFILE_SERVICE_SINGLE_FLIGHT_LOAD_INSTALL_V1
-- Run once in Studio Edit mode. This changes no player data.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PREFIX = "[NTR ProfileService Single-Flight Load] "
local MARKER = "NTR_PROFILE_SERVICE_SINGLE_FLIGHT_LOAD_V1"

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
		"local sessions = {}\nlocal garageCleanupTransactions = {}",
		"local sessions = {}\nlocal garageCleanupTransactions = {}\nlocal profileLoadsInFlight = {} -- " .. MARKER,
		"profile session state"
	)
	stagedSource = replaceOnce(
		stagedSource,
		"local function loadProfile(player)\n\tlocal loadedData = nil",
		[=[local function loadProfile(player)
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

	local loadedData = nil]=],
		"loadProfile entry"
	)
	stagedSource = replaceOnce(
		stagedSource,
		"sessions[player.UserId] = session\n\tplayer:SetAttribute(\"NTR_ProfileServiceLoaded\", true)",
		"sessions[player.UserId] = session\n\tprofileLoadsInFlight[userId] = nil\n\tplayer:SetAttribute(\"NTR_ProfileServiceLoaded\", true)",
		"loadProfile commit"
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
	check(string.find(source, MARKER, 1, true) ~= nil, "single-flight marker missing")
	check(string.find(source, "DUPLICATE PROFILE LOAD SUPPRESSED", 1, true) ~= nil, "duplicate-load gate missing")
	check(string.find(source, "profileLoadsInFlight[userId] = nil", 1, true) ~= nil, "load commit release missing")
	if #failures > 0 then return false, table.concat(failures, " | ") end
	return true, "single-flight profile loading installed"
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

profileService:SetAttribute("SingleFlightProfileLoadVersion", 1)
print(PREFIX .. "INSTALL PASS - duplicate player loads can no longer replace an active session")
print(PREFIX .. "NEXT start a fresh Play session and run the cleanup apply script")
