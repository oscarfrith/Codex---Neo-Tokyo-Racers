-- Neo Tokyo Racers - ProfileService authoritative-session ownership audit
-- NTR_PROFILE_SERVICE_SESSION_OWNERSHIP_READONLY_AUDIT_V1_1
-- Read-only. Run once in Edit mode, then from the SERVER Command Bar in a fresh Play session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PREFIX = "[NTR Profile Ownership Audit] "
local passCount, warnCount, failCount, infoCount = 0, 0, 0, 0

local function report(kind, message)
	if kind == "PASS" then passCount += 1
	elseif kind == "WARN" then warnCount += 1
	elseif kind == "FAIL" then failCount += 1
	else infoCount += 1 end
	print(PREFIX .. kind .. " " .. tostring(message))
end

local function check(condition, message)
	report(condition and "PASS" or "FAIL", message)
	return condition
end

local function contains(source, text)
	return type(source) == "string" and string.find(source, text, 1, true) ~= nil
end

local function sourceWindow(source, firstText, lastText)
	local first = string.find(source, firstText, 1, true)
	if not first then return "" end
	local last = string.find(source, lastText, first + #firstText, true)
	if not last then return string.sub(source, first) end
	return string.sub(source, first, last + #lastText - 1)
end

local serverRoot = ServerScriptService:FindFirstChild("NeoTokyoRacers")
local services = serverRoot and serverRoot:FindFirstChild("Services")
local playerServices = services and services:FindFirstChild("Player")
local service = playerServices and playerServices:FindFirstChild("ProfileService_Active")

check(service and service:IsA("Script"), "ProfileService_Active exists as a Script")
if not (service and service:IsA("Script")) then
	print(PREFIX .. "RESULT pass=" .. passCount .. " warn=" .. warnCount .. " fail=" .. failCount .. " info=" .. infoCount)
	return
end
check(service.Disabled == false, "ProfileService_Active is enabled")
check(service:GetAttribute("SingleFlightProfileLoadVersion") == 1, "single-flight installation attribute is V1")
check(service:GetAttribute("SessionOwnershipHardeningVersion") == 1, "session-ownership installation attribute is V1")

local source = service.Source
check(contains(source, "NTR_PROFILE_SERVICE_SINGLE_FLIGHT_LOAD_V1"), "single-flight source contract exists")
check(contains(source, "NTR_PROFILE_SERVICE_SESSION_OWNERSHIP_HARDENING_V1"), "late-load/session-pin source contract exists")
check(contains(source, "DUPLICATE PROFILE LOAD SUPPRESSED"), "duplicate concurrent loads are rejected")
check(contains(source, "LATE PROFILE LOAD DISCARDED"), "late loads cannot replace an existing active session")
check(contains(source, "PinnedSession = currentSession"), "inventory cleanup pins its authoritative session")
check(contains(source, "sessions[userId] = session"), "profile commits use the normalized user ID key")

local loadCommit = sourceWindow(source, "local function loadProfile(player)", "local function markDirty")
local hasPlayerLifecycleGate = contains(loadCommit, "player.Parent ~= Players")
	or contains(loadCommit, "player.Parent == Players")
	or contains(loadCommit, "player:IsDescendantOf(Players)")
	or contains(loadCommit, "NTR_PROFILE_SERVICE_PLAYER_LIFECYCLE_GUARD_V1")
check(hasPlayerLifecycleGate, "a yielded profile load verifies the player is still present before committing")

local removal = sourceWindow(source, "Players.PlayerRemoving:Connect", "end)")
check(contains(removal, "profileLoadsInFlight[player.UserId] = nil") or contains(removal, "profileLoadsInFlight[userId] = nil"), "PlayerRemoving clears any in-flight load ownership")
check(contains(removal, "garageCleanupTransactions[player.UserId] = nil") or contains(removal, "garageCleanupTransactions[userId] = nil"), "PlayerRemoving clears any pinned cleanup transaction")

local hasGenerationContract = contains(source, "NTR_PROFILE_SERVICE_LIFECYCLE_GENERATION_V1")
	or (contains(source, "SessionGeneration") and contains(source, "SessionId"))
check(hasGenerationContract, "profile sessions expose a lifecycle generation and stable session identity")
check(contains(source, "reconcileTableIdentity(session.Profile, normalized)"), "snapshot imports preserve the authoritative profile table identity")
check(not contains(source, "session.Profile = schema.Normalize(snapshot"), "snapshot imports do not replace the authoritative profile root")

local garageServices = services and services:FindFirstChild("Garage")
local garageAction = garageServices and garageServices:FindFirstChild("GarageActionController_Shadow_Disabled")
check(garageAction and garageAction:IsA("Script"), "GarageActionController exists for read-only import auditing")
if garageAction and garageAction:IsA("Script") then
	local garageSource = garageAction.Source
	local getInitialWindow = sourceWindow(garageSource, 'if action == "GetInitial" then', 'elseif action == "SelectVehicleInstance" then')
	check(contains(getInitialWindow, "NTR_PROFILE_SERVICE_READ_ONLY_IMPORT_GUARD_V1"), "GetInitial declares the read-only persistence boundary")
	check(not contains(getInitialWindow, "V80_mirrorLegacyProfileToPersistence"), "GetInitial never imports a legacy snapshot into ProfileService")
end

local ownedGarageProfile = garageServices and garageServices:FindFirstChild("OwnedGarageProfileRuntime")
check(ownedGarageProfile and ownedGarageProfile:IsA("ModuleScript"), "OwnedGarageProfileRuntime exists for nested identity auditing")
if ownedGarageProfile and ownedGarageProfile:IsA("ModuleScript") then
	local ownedSource = ownedGarageProfile.Source
	check(contains(ownedSource, "NTR_OWNED_GARAGE_PROFILE_IDENTITY_STABILITY_V1"), "owned garage schema/reset preserves an existing table identity")
	check(not contains(ownedSource, "profile.OwnedGarage=clone(snapshot)"), "owned garage rollback does not replace the table")
end

report("INFO", "Both PlayerAdded and the existing-player startup loop call loadProfile; the single-flight gate must remain authoritative")

if not RunService:IsRunning() then
	report("INFO", "EDIT audit complete; no object, source, attribute, profile, dirty flag, or DataStore value was changed")
	print(PREFIX .. "EDIT RESULT pass=" .. passCount .. " warn=" .. warnCount .. " fail=" .. failCount .. " info=" .. infoCount)
	print(PREFIX .. (failCount == 0 and "EDIT VERDICT READY FOR FRESH PLAY-SERVER AUDIT" or "EDIT VERDICT BLOCKED - repair lifecycle ownership before Phase 7"))
	return
end

if not RunService:IsServer() then
	report("FAIL", "run the Play audit from the SERVER Command Bar, not the client")
	print(PREFIX .. "PLAY RESULT pass=" .. passCount .. " warn=" .. warnCount .. " fail=" .. failCount .. " info=" .. infoCount)
	return
end

local bindings = playerServices:FindFirstChild("ProfileServiceBindings")
check(bindings and bindings:IsA("Folder"), "ProfileServiceBindings exists in Play")
if not bindings then
	print(PREFIX .. "PLAY RESULT pass=" .. passCount .. " warn=" .. warnCount .. " fail=" .. failCount .. " info=" .. infoCount)
	return
end

local requiredBindings = {"GetProfile", "GetSummary", "IsLoaded", "MarkDirty", "SaveNow", "ImportProfileSnapshot"}
for _, name in ipairs(requiredBindings) do
	check(bindings:FindFirstChild(name) and bindings[name]:IsA("BindableFunction"), name .. " binding exists")
end

local getProfile = bindings:FindFirstChild("GetProfile")
local getSummary = bindings:FindFirstChild("GetSummary")
local isLoaded = bindings:FindFirstChild("IsLoaded")
local players = Players:GetPlayers()
check(#players > 0, "at least one player is connected for runtime sampling")

local stateRoot = ServerScriptService.NeoTokyoRacers:FindFirstChild("State")
local runtimeProfiles = stateRoot and stateRoot:FindFirstChild("RuntimeProfiles")
check(runtimeProfiles and runtimeProfiles:IsA("Folder"), "RuntimeProfiles marker folder exists")

for _, player in ipairs(players) do
	local loaded = false
	for _ = 1, 80 do
		local ok, result = pcall(function() return isLoaded:Invoke(player) end)
		if ok and result == true then loaded = true; break end
		task.wait(0.1)
	end
	check(loaded, player.Name .. " reports one loaded profile session")
	if loaded and player.Parent == Players then
		local okFirst, firstProfile = pcall(function() return getProfile:Invoke(player) end)
		check(okFirst and typeof(firstProfile) == "table", player.Name .. " GetProfile returns a table")
		local marker = runtimeProfiles and runtimeProfiles:FindFirstChild(tostring(player.UserId))
		local initialGeneration = marker and marker:GetAttribute("SessionGeneration")
		local initialSessionId = marker and marker:GetAttribute("SessionId")
		local profileAvailable = okFirst and typeof(firstProfile) == "table"
		local sessionIdentityStable = type(initialGeneration) == "number" and initialGeneration >= 1
			and type(initialSessionId) == "string" and initialSessionId ~= ""
		local summaryStable = true
		for _ = 1, 50 do
			task.wait(0.1)
			if player.Parent ~= Players then profileAvailable = false; sessionIdentityStable = false; break end
			local okProfile, candidate = pcall(function() return getProfile:Invoke(player) end)
			if not okProfile or typeof(candidate) ~= "table" then profileAvailable = false end
			local currentMarker = runtimeProfiles and runtimeProfiles:FindFirstChild(tostring(player.UserId))
			if currentMarker ~= marker
				or not currentMarker
				or currentMarker:GetAttribute("SessionGeneration") ~= initialGeneration
				or currentMarker:GetAttribute("SessionId") ~= initialSessionId then
				sessionIdentityStable = false
			end
			local okSummary, summary = pcall(function() return getSummary:Invoke(player) end)
			if not okSummary or typeof(summary) ~= "table" or summary.Loaded ~= true then summaryStable = false end
		end
		check(profileAvailable, player.Name .. " profile remains available throughout five-second sampling")
		check(sessionIdentityStable, player.Name .. " server-owned session generation and identity remain stable for five seconds")
		check(summaryStable, player.Name .. " summary remains loaded throughout sampling")
		check(player:GetAttribute("NTR_ProfileServiceLoaded") == true, player.Name .. " loaded attribute agrees with the binding")
		check(marker and marker:GetAttribute("Loaded") == true, player.Name .. " has one loaded runtime marker")
		local generation = marker and marker:GetAttribute("SessionGeneration")
		local sessionId = marker and marker:GetAttribute("SessionId")
		check(type(generation) == "number" and generation >= 1 and type(sessionId) == "string" and sessionId ~= "", player.Name .. " runtime marker exposes generation and session identity")
	end
end

if runtimeProfiles then
	local connected = {}
	for _, player in ipairs(Players:GetPlayers()) do connected[tostring(player.UserId)] = true end
	local orphanCount = 0
	for _, marker in ipairs(runtimeProfiles:GetChildren()) do
		if marker:IsA("Folder") and not connected[marker.Name] then orphanCount += 1 end
	end
	check(orphanCount == 0, "RuntimeProfiles contains no markers for departed players")
end

local config = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
config = config and config:FindFirstChild("Shared")
config = config and config:FindFirstChild("Config")
config = config and config:FindFirstChild("Persistence_EditAttributes")
report("INFO", "DataStoreEnabled=" .. tostring(config and config:GetAttribute("DataStoreEnabled")) .. "; this audit invoked no mutation or save binding")
report("INFO", "PLAY audit complete; no profile, dirty flag, DataStore value, source, hierarchy, or attribute was changed")
print(PREFIX .. "PLAY RESULT pass=" .. passCount .. " warn=" .. warnCount .. " fail=" .. failCount .. " info=" .. infoCount)
print(PREFIX .. (failCount == 0 and "PLAY VERDICT PROFILE OWNERSHIP GATE PASSED" or "PLAY VERDICT BLOCKED - repair lifecycle ownership before Phase 7"))
