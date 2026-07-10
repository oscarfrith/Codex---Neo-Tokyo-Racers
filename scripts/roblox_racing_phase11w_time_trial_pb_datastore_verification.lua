-- Neo Tokyo Racers - Racing Phase 11W V2 Time Trial PB DataStore Verification
-- Run in Roblox Studio Command Bar.
--
-- Default MODE = "AUDIT" is read-only.
-- Optional modes:
--   MODE = "ENABLE_DATASTORE_TEST"  -> enables Config.Racing.PersonalBests.DataStoreEnabled
--                                     and optionally points the store at a Studio test name.
--   MODE = "DISABLE_DATASTORE_TEST" -> disables DataStore writes again.
--
-- Scope:
--   Config/audit helper only. No gameplay source, UI, rewards, route-guide,
--   arrows, driving, VFX, matchmaking, or bootstrap edits.

local MODE = "AUDIT"
local USE_STUDIO_TEST_STORE_NAME = true
local STUDIO_TEST_STORE_NAME = "NTR_TimeTrialPersonalBests_StudioTest_v1"
local SAMPLE_EVENT_ID = "shifted_canal_sprint_tt"
local SAMPLE_TIERS = { "E", "D", "C", "B", "A", "S" }

local PHASE = "NTR Racing Phase 11W V2 PB DataStore Verification"

local results = {
	pass = 0,
	warn = 0,
	fail = 0,
	info = 0,
}

local function log(kind, message)
	kind = tostring(kind or "INFO")
	results[string.lower(kind)] = (results[string.lower(kind)] or 0) + 1
	local line = "[" .. PHASE .. "] " .. kind .. " " .. tostring(message)
	if kind == "FAIL" or kind == "WARN" then
		warn(line)
	else
		print(line)
	end
end

local function child(parent, name, className, required)
	local item = parent and parent:FindFirstChild(name)
	if not item then
		log(required and "FAIL" or "WARN", "Missing " .. tostring(name) .. " under " .. (parent and parent:GetFullName() or "nil"))
		return nil
	end
	if className and not item:IsA(className) then
		log("FAIL", item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. className)
		return item
	end
	log("PASS", "Found " .. item:GetFullName())
	return item
end

local function ensureFolder(parent, name)
	local item = parent and parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		error("[" .. PHASE .. "] " .. item:GetFullName() .. " must be a Folder.", 2)
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
		log("INFO", "Created " .. item:GetFullName())
	end
	return item
end

local function ensureValue(parent, className, name, value)
	local item = parent and parent:FindFirstChild(name)
	if item and not item:IsA(className) then
		error("[" .. PHASE .. "] " .. item:GetFullName() .. " must be a " .. className .. ".", 2)
	end
	if not item then
		item = Instance.new(className)
		item.Name = name
		item.Value = value
		item.Parent = parent
		log("INFO", "Created " .. item:GetFullName() .. " = " .. tostring(value))
	end
	return item
end

local function sourceHas(scriptObject, marker, label, severity)
	if not scriptObject then
		log(severity or "FAIL", tostring(label or marker) .. " source owner unavailable")
		return false
	end
	local ok, source = pcall(function()
		return scriptObject.Source
	end)
	if not ok or type(source) ~= "string" then
		log(severity or "WARN", tostring(label or marker) .. " source unreadable in this context")
		return false
	end
	if string.find(source, marker, 1, true) then
		log("PASS", tostring(label or marker))
		return true
	end
	log(severity or "FAIL", "Missing marker/text: " .. tostring(label or marker))
	return false
end

local function valueText(valueObject)
	if not valueObject then
		return "<missing>"
	end
	return tostring(valueObject.Value)
end

local replicatedStorage = game:GetService("ReplicatedStorage")
local serverScriptService = game:GetService("ServerScriptService")
local players = game:GetService("Players")
local runService = game:GetService("RunService")

log("INFO", "Context IsClient=" .. tostring(runService:IsClient()) .. " IsServer=" .. tostring(runService:IsServer()) .. " IsEdit=" .. tostring(runService:IsEdit()) .. " MODE=" .. tostring(MODE))

local ntr = child(replicatedStorage, "NeoTokyoRacers", "Folder", true)
local config = child(ntr, "Config", "Folder", true)
local racingConfig = child(config, "Racing", "Folder", true)
local personalBests = ensureFolder(racingConfig, "PersonalBests")
local dataStoreEnabled = ensureValue(personalBests, "BoolValue", "DataStoreEnabled", false)
local dataStoreName = ensureValue(personalBests, "StringValue", "DataStoreName", "NTR_TimeTrialPersonalBests_v1")
local saveDebounce = ensureValue(personalBests, "NumberValue", "SaveDebounceSeconds", 6)

if MODE == "ENABLE_DATASTORE_TEST" then
	dataStoreEnabled.Value = true
	if USE_STUDIO_TEST_STORE_NAME then
		dataStoreName.Value = STUDIO_TEST_STORE_NAME
	end
	log("WARN", "DataStore PB test mode ENABLED. Studio API Services must be enabled, and Play must be restarted so the PB service reloads with this config.")
elseif MODE == "DISABLE_DATASTORE_TEST" then
	dataStoreEnabled.Value = false
	log("WARN", "DataStore PB test mode DISABLED. Restart Play so the PB service returns to session-only mode.")
elseif MODE ~= "AUDIT" then
	log("FAIL", "Unknown MODE `" .. tostring(MODE) .. "`. Use AUDIT, ENABLE_DATASTORE_TEST, or DISABLE_DATASTORE_TEST.")
end

log("INFO", "PersonalBests.DataStoreEnabled=" .. valueText(dataStoreEnabled))
log("INFO", "PersonalBests.DataStoreName=" .. valueText(dataStoreName))
log("INFO", "PersonalBests.SaveDebounceSeconds=" .. valueText(saveDebounce))

if dataStoreEnabled.Value == true then
	log("WARN", "PB DataStore writes are currently enabled. Use DISABLE_DATASTORE_TEST after the save/rejoin smoke if this is only prototype testing.")
else
	log("PASS", "PB DataStore writes are currently disabled/session-only.")
	log("INFO", "Saved PBs will not survive rejoin until you run this script once with MODE = ENABLE_DATASTORE_TEST, then restart Play.")
end

local shared = child(ntr, "Shared", "Folder", true)
local remotes = child(shared, "Remotes", "Folder", true)
local racingRemotes = child(remotes, "Racing", "Folder", true)
local raceRequest = child(racingRemotes, "RaceRequest", "RemoteFunction", true)

local serverRoot = serverScriptService:FindFirstChild("NeoTokyoRacers")
local services = serverRoot and serverRoot:FindFirstChild("Services")
local racingServices = services and services:FindFirstChild("Racing")
local runningFromPlayClient = runService:IsClient() and not runService:IsEdit()
local editContext = runService:IsEdit()
local getBinding = nil
local saveBinding = nil

if runningFromPlayClient and not racingServices then
	log("WARN", "Skipping ServerScriptService source/binding checks from Play client; server scripts are not replicated here.")
else
	local pbService = child(racingServices, "RacePersonalBestService_Active", "Script", true)
	local bindings = child(racingServices, "RacePersonalBestBindings", "Folder", not editContext)
	if bindings then
		child(bindings, "RecordTimeTrialBest", "BindableFunction", not editContext)
		getBinding = child(bindings, "GetTimeTrialBest", "BindableFunction", not editContext)
		saveBinding = child(bindings, "SavePlayer", "BindableFunction", not editContext)
	elseif editContext then
		log("WARN", "RacePersonalBestBindings are created by RacePersonalBestService during Play. Missing bindings in Edit mode are expected before runtime services start.")
	end
	local timeTrialService = child(racingServices, "TimeTrialService_Active", "Script", true)

	sourceHas(pbService, "NTR_RACING_PHASE11M_PERSONAL_BEST_SERVICE", "Phase 11M PB service marker")
	sourceHas(pbService, "DataStoreEnabled", "PB service reads DataStoreEnabled config")
	sourceHas(pbService, "DataStore skipped for non-production UserId.", "PB service protects Studio negative UserIds")
	sourceHas(timeTrialService, "RecordTimeTrialBest", "TimeTrialService records PBs")
	sourceHas(timeTrialService, "GetTimeTrialPersonalBest", "TimeTrialService exposes PB lookup action")
end

local function reportPB(playerName, tier, ok, result)
	if ok and typeof(result) == "table" and result.Ok ~= false then
		local best = tonumber(result.BestSeconds)
		if best then
			log("PASS", playerName .. " " .. SAMPLE_EVENT_ID .. " tier=" .. tier .. " PB=" .. string.format("%.3f", best) .. " medal=" .. tostring(result.BestMedal or ""))
		else
			log("PASS", playerName .. " " .. SAMPLE_EVENT_ID .. " tier=" .. tier .. " has no PB yet")
		end
	else
		log("WARN", "PB lookup failed for " .. playerName .. " tier=" .. tier .. ": " .. tostring(ok and (result and result.Message) or result))
	end
end

if editContext then
	log("WARN", "Runtime binding/player PB lookup checks skipped in Edit mode. Run AUDIT again from Play after at least one player loads.")
elseif runningFromPlayClient then
	local localPlayer = players.LocalPlayer
	if not localPlayer then
		log("WARN", "LocalPlayer unavailable for Play-client PB lookup smoke.")
	elseif not raceRequest then
		log("FAIL", "RaceRequest remote unavailable for Play-client PB lookup smoke.")
	else
		log("INFO", "Local player " .. localPlayer.Name .. " UserId=" .. tostring(localPlayer.UserId) .. " PBLoaded=" .. tostring(localPlayer:GetAttribute("NTR_TimeTrialPBLoaded")) .. " PBDataStoreEnabled=" .. tostring(localPlayer:GetAttribute("NTR_TimeTrialPBDataStoreEnabled")) .. " PBLastSaveUnix=" .. tostring(localPlayer:GetAttribute("NTR_TimeTrialPBLastSaveUnix")) .. " PBLastError=" .. tostring(localPlayer:GetAttribute("NTR_TimeTrialPBLastError")))
		for _, tier in ipairs(SAMPLE_TIERS) do
			local ok, result = pcall(function()
				return raceRequest:InvokeServer("GetTimeTrialPersonalBest", {
					EventId = SAMPLE_EVENT_ID,
					VehicleTier = tier,
				})
			end)
			reportPB(localPlayer.Name, tier, ok, result)
		end
		log("WARN", "Forced save binding check skipped from Play client. Use server/Edit Output plus leave/rejoin to verify the actual DataStore save.")
	end
elseif not (getBinding and getBinding:IsA("BindableFunction")) then
	log("FAIL", "GetTimeTrialBest binding is unavailable in Play server context.")
else
	local playerList = players:GetPlayers()
	if #playerList == 0 then
		log("WARN", "No players available for PB lookup smoke.")
	end
	for _, player in ipairs(playerList) do
		log("INFO", "Player " .. player.Name .. " UserId=" .. tostring(player.UserId) .. " PBLoaded=" .. tostring(player:GetAttribute("NTR_TimeTrialPBLoaded")) .. " PBDataStoreEnabled=" .. tostring(player:GetAttribute("NTR_TimeTrialPBDataStoreEnabled")) .. " PBLastSaveUnix=" .. tostring(player:GetAttribute("NTR_TimeTrialPBLastSaveUnix")) .. " PBLastError=" .. tostring(player:GetAttribute("NTR_TimeTrialPBLastError")))
		for _, tier in ipairs(SAMPLE_TIERS) do
			local ok, result = pcall(function()
				return getBinding:Invoke(player, {
					EventId = SAMPLE_EVENT_ID,
					VehicleTier = tier,
				})
			end)
			reportPB(player.Name, tier, ok, result)
		end
		if saveBinding and saveBinding:IsA("BindableFunction") then
			local ok, result = pcall(function()
				return saveBinding:Invoke(player, true)
			end)
			if ok and typeof(result) == "table" then
				local message = tostring(result.Message or "")
				if result.Ok == true or result.Success == true then
					log("PASS", "Forced PB save check for " .. player.Name .. ": " .. message)
				else
					log("WARN", "Forced PB save check for " .. player.Name .. " returned not-ok: " .. message)
				end
			else
				log("WARN", "Forced PB save check failed for " .. player.Name .. ": " .. tostring(result))
			end
		end
	end
end

print("[" .. PHASE .. "] SUMMARY pass=" .. tostring(results.pass) .. " warn=" .. tostring(results.warn) .. " fail=" .. tostring(results.fail))
if results.fail == 0 then
	print("[" .. PHASE .. "] RESULT PASS. For DataStore testing: ENABLE_DATASTORE_TEST in Edit, restart Play, finish a new PB, leave/rejoin, then run AUDIT in Play.")
else
	warn("[" .. PHASE .. "] RESULT FAIL. Fix failed checks before enabling saved PB verification.")
end
