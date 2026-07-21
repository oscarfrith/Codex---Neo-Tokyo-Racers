-- Neo Tokyo Racers - Loading System Phase 6 Read-Only Closure Audit
-- Run in Roblox Studio Command Bar while in Edit mode.
-- This script performs no writes, creates no Instances and requires no modules.

local RunService = game:GetService("RunService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

assert(not RunService:IsRunning(), "Run the Phase 6 audit in Studio Edit mode.")

local PREFIX = "[NTR Loading Phase 6 Audit]"
local passed, failed, warned = 0, 0, 0

local function report(kind, label, detail)
	local suffix = detail and (" - " .. tostring(detail)) or ""
	if kind == "PASS" then
		passed += 1
		print(("%s PASS: %s%s"):format(PREFIX, label, suffix))
	elseif kind == "WARN" then
		warned += 1
		warn(("%s WARN: %s%s"):format(PREFIX, label, suffix))
	else
		failed += 1
		warn(("%s FAIL: %s%s"):format(PREFIX, label, suffix))
	end
end

local function check(label, condition, detail)
	report(condition and "PASS" or "FAIL", label, detail)
	return condition
end

local function warning(label, condition, detail)
	if condition then report("PASS", label, detail) else report("WARN", label, detail) end
	return condition
end

local function find(root, path)
	local current = root
	for segment in string.gmatch(path, "[^.]+") do
		current = current and current:FindFirstChild(segment)
	end
	return current
end

local function instance(label, root, path, className)
	local object = find(root, path)
	if not check(label .. " exists", object ~= nil, path) then return nil end
	check(label .. " class", object:IsA(className), object.ClassName .. " / expected " .. className)
	return object
end

local function markerCount(source, marker)
	local count, start = 0, 1
	while true do
		local first, last = string.find(source, marker, start, true)
		if not first then return count end
		count += 1
		start = last + 1
	end
end

local function sourceContract(label, object, marker)
	if not object then return end
	local source = object.Source
	check(label .. " marker", markerCount(source, marker) == 1, marker)
	local compiled, problem = loadstring(source, "=" .. label)
	check(label .. " compiles", compiled ~= nil, problem)
end

local function directCount(root, name)
	local count = 0
	if root then
		for _, child in ipairs(root:GetChildren()) do
			if child.Name == name then count += 1 end
		end
	end
	return count
end

local kit = instance("NeoTokyoRacers root", ReplicatedStorage, "NeoTokyoRacers", "Folder")
local loadingPackage = instance("loading package", ReplicatedFirst, "NTRLoading", "Folder")
local clientModules = kit and instance("client modules", kit, "Shared.Modules.Client", "Folder")
local uiControllers = instance("UI controllers", StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI", "Folder")
local introControllers = instance("intro controllers", StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro", "Folder")
local racingControllers = instance("racing controllers", StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing", "Folder")
local racingServices = instance("racing services", ServerScriptService, "NeoTokyoRacers.Services.Racing", "Folder")
local garageServices = instance("garage services", ServerScriptService, "NeoTokyoRacers.Services.Garage", "Folder")

local initial = loadingPackage and instance("initial/start client", loadingPackage, "InitialLoadingAndStartScreenClient", "LocalScript")
local catalog = loadingPackage and instance("artwork catalog", loadingPackage, "LoadingArtworkCatalog", "ModuleScript")
local view = loadingPackage and instance("loading view", loadingPackage, "LoadingScreenView", "ModuleScript")
local runtime = loadingPackage and instance("transition runtime", loadingPackage, "LoadingTransitionRuntime", "ModuleScript")
if loadingPackage then
	check("loading package has four direct children", #loadingPackage:GetChildren() == 4, #loadingPackage:GetChildren())
	for _, name in ipairs({ "InitialLoadingAndStartScreenClient", "LoadingArtworkCatalog", "LoadingScreenView", "LoadingTransitionRuntime" }) do
		check("unique loading child " .. name, directCount(loadingPackage, name) == 1, directCount(loadingPackage, name))
	end
end
if initial then check("initial/start client enabled", initial.Disabled == false, tostring(initial.Disabled)) end

local inputGate = clientModules and instance("gameplay input gate", clientModules, "Input.GameplayInputGate", "ModuleScript")
local audioMixer = clientModules and instance("audio mixer", clientModules, "Audio.AudioMixController", "ModuleScript")
local loadingController = uiControllers and instance("loading controller", uiControllers, "LoadingTransitionController_Active", "LocalScript")
local loadingInvoke = uiControllers and instance("loading invoke", uiControllers, "LoadingTransitionInvoke", "BindableFunction")
local loadingState = uiControllers and instance("loading presentation state", uiControllers, "LoadingPresentationState", "Folder")
local loadingChanged = uiControllers and instance("loading presentation event", uiControllers, "LoadingPresentationChanged", "BindableEvent")
if loadingController then check("loading controller enabled", loadingController.Disabled == false, tostring(loadingController.Disabled)) end
if uiControllers then
	for _, name in ipairs({ "LoadingTransitionController_Active", "LoadingTransitionInvoke", "LoadingPresentationState", "LoadingPresentationChanged" }) do
		check("unique UI loading owner " .. name, directCount(uiControllers, name) == 1, directCount(uiControllers, name))
	end
end

sourceContract("initial/start client", initial, "NTR_LOADING_SYSTEM_PHASE5_INITIAL_START_SCREEN_V1_2_CONFIGURED_BUTTON_POSITION")
sourceContract("artwork catalog", catalog, "NTR_LOADING_SYSTEM_PHASE1_ARTWORK_CATALOG_V1_2")
sourceContract("loading view", view, "NTR_LOADING_SYSTEM_PHASE1_SCREEN_VIEW_V1_4_GRID_FETCH_STATUS")
sourceContract("transition runtime", runtime, "NTR_LOADING_SYSTEM_PHASE1_TRANSITION_RUNTIME_V1_2")
sourceContract("gameplay input gate", inputGate, "NTR_LOADING_SYSTEM_PHASE1_GAMEPLAY_INPUT_GATE_V1")
sourceContract("audio mixer", audioMixer, "NTR_LOADING_SYSTEM_PHASE1_AUDIO_MIXER_V1_1")
sourceContract("loading controller", loadingController, "NTR_LOADING_SYSTEM_PHASE1_CONTROLLER_V1")

local driving = clientModules and instance("driving controller", clientModules, "Controllers.DrivingControllerV47", "ModuleScript")
local desktop = uiControllers and instance("desktop HUD", uiControllers, "DesktopFreeRoamHudController_Active", "LocalScript")
local mobile = uiControllers and instance("mobile HUD", uiControllers, "MobileFreeRoamHudController_Active", "LocalScript")
local moduleShop = uiControllers and instance("module shop UI", uiControllers, "ModuleShopUIController", "ModuleScript")
local ownedBrowser = uiControllers and instance("owned garage browser", uiControllers, "OwnedGarageBrowserController", "ModuleScript")
local garageEntrance = introControllers and instance("garage entrance", introControllers, "GarageEntranceController_Active", "LocalScript")
local ownedManagement = garageServices and instance("owned garage management", garageServices, "OwnedGarageManagementRuntime", "ModuleScript")
local raceTransition = racingControllers and instance("race transition", racingControllers, "RaceTransitionClient_Active", "LocalScript")
local raceEntry = racingControllers and instance("race entry", racingControllers, "RaceEntryMenuClient_Active", "LocalScript")
local raceSession = racingControllers and instance("race session", racingControllers, "RaceSessionPresentationController_Active", "LocalScript")
local raceResults = racingControllers and instance("race results", racingControllers, "RaceTimeTrialResultCoachClient_Active", "LocalScript")
local raceCountdown = racingControllers and instance("race countdown", racingControllers, "RaceCountdownPresentationController_Active", "LocalScript")
local timeTrialService = racingServices and instance("time trial service", racingServices, "TimeTrialService_Active", "Script")
local matchmakingService = racingServices and instance("race matchmaking service", racingServices, "RaceMatchmakingService_Active", "Script")

for _, contract in ipairs({
	{ "driving input bridge", driving, "NTR_LOADING_SYSTEM_PHASE1_INPUT_GATE_V1" },
	{ "desktop dealership bridge", desktop, "NTR_LOADING_SYSTEM_PHASE1_DEALERSHIP_TELEPORT_DESKTOP_V1" },
	{ "mobile dealership bridge", mobile, "NTR_LOADING_SYSTEM_PHASE1_DEALERSHIP_TELEPORT_MOBILE_V1" },
	{ "garage entry bridge", garageEntrance, "NTR_LOADING_SYSTEM_PHASE2_GARAGE_ENTRY_V1" },
	{ "garage UI bridge", moduleShop, "NTR_LOADING_SYSTEM_PHASE2_GARAGE_UI_TRANSITIONS_V1" },
	{ "owned garage browser bridge", ownedBrowser, "NTR_LOADING_SYSTEM_PHASE3_OWNED_GARAGE_BROWSER_V1" },
	{ "owned garage result bridge", ownedManagement, "NTR_LOADING_SYSTEM_PHASE3_OWNED_GARAGE_FOOT_EXIT_RESULT_V1" },
	{ "race transition bridge", raceTransition, "NTR_LOADING_SYSTEM_PHASE4_RACE_TRANSITION_BRIDGE_V1" },
	{ "time trial start bridge", raceEntry, "NTR_LOADING_SYSTEM_PHASE4_TIME_TRIAL_START_V1" },
	{ "active race exit bridge", raceSession, "NTR_LOADING_SYSTEM_PHASE4_ACTIVE_RACE_EXIT_V1" },
	{ "results exit bridge", raceResults, "NTR_LOADING_SYSTEM_PHASE4_RESULTS_EXIT_V1" },
	{ "race transition readiness", raceTransition, "NTR_RACING_STAGING_READINESS_GATE_V1" },
	{ "race countdown readiness", raceCountdown, "NTR_RACING_STAGING_READINESS_GATE_V1" },
	{ "time trial readiness", timeTrialService, "NTR_RACING_STAGING_READINESS_GATE_V1" },
	{ "matchmaking readiness", matchmakingService, "NTR_RACING_STAGING_READINESS_GATE_V1" },
}) do
	sourceContract(contract[1], contract[2], contract[3])
end

local config = kit and instance("loading config", kit, "Config.UI.LoadingSystem", "Folder")
local function numberAttribute(name, minimum, maximum)
	if not config then return nil end
	local value = config:GetAttribute(name)
	check(name .. " number", typeof(value) == "number", typeof(value))
	if typeof(value) == "number" then check(name .. " range", value >= minimum and value <= maximum, value) end
	return value
end

local function stringAttribute(name)
	if not config then return nil end
	local value = config:GetAttribute(name)
	check(name .. " string", typeof(value) == "string", typeof(value))
	return value
end

if config then
	check("loading system enabled", config:GetAttribute("Enabled") ~= false, tostring(config:GetAttribute("Enabled")))
	numberAttribute("FadeOutSeconds", 0.05, 2)
	local minimumVisible = numberAttribute("MinimumVisibleSeconds", 0.1, 10)
	warning("approved 1.5-second minimum retained", minimumVisible == 1.5, minimumVisible)
	numberAttribute("CompletionFillSeconds", 0.05, 2)
	numberAttribute("GridPreloadAttempts", 1, 4)
	numberAttribute("GridPreloadRetrySeconds", 0, 2)
	numberAttribute("GridPromotionWaitSeconds", 0.25, 8)
	numberAttribute("StartScreenButtonYScaleDesktop", 0.5, 0.95)
	numberAttribute("StartScreenButtonYScaleLandscapePhone", 0.5, 0.95)
	numberAttribute("StartScreenButtonYScalePortrait", 0.5, 0.95)
	stringAttribute("StartScreenPlayIconAssetId")
	stringAttribute("StartScreenShopIconAssetId")
	local musicId = stringAttribute("LoadingMusicAssetId")
	warning("loading music assigned", musicId ~= nil and musicId ~= "", "blank is approved while screens remain short")
end

local artworks = config and instance("artwork root", config, "Artworks", "Folder")
local artwork = artworks and instance("default artwork", artworks, "NeoTokyoStreet01", "Folder")
if artwork then
	check("default artwork ID", artwork:GetAttribute("ArtworkId") == "NeoTokyoStreet01", tostring(artwork:GetAttribute("ArtworkId")))
	check("default artwork enabled", artwork:GetAttribute("Enabled") ~= false, tostring(artwork:GetAttribute("Enabled")))
	check("default artwork start eligible", artwork:GetAttribute("StartScreenEligible") == true, tostring(artwork:GetAttribute("StartScreenEligible")))
	check("default artwork Grid3x2", artwork:GetAttribute("Layout") == "Grid3x2", tostring(artwork:GetAttribute("Layout")))
	local fallback = artwork:GetAttribute("ImageAssetId")
	check("single-image safety fallback populated", typeof(fallback) == "string" and fallback ~= "", tostring(fallback))
	local tiles = instance("tile root", artwork, "Tiles", "Folder")
	if tiles then
		check("tile root has six children", #tiles:GetChildren() == 6, #tiles:GetChildren())
		local ids = {}
		for row = 1, 2 do
			for column = 1, 3 do
				local name = ("R%dC%d"):format(row, column)
				local tile = instance("tile " .. name, tiles, name, "Folder")
				if tile then
					check(name .. " row", tile:GetAttribute("Row") == row, tostring(tile:GetAttribute("Row")))
					check(name .. " column", tile:GetAttribute("Column") == column, tostring(tile:GetAttribute("Column")))
					local id = tile:GetAttribute("ImageAssetId")
					check(name .. " image ID", typeof(id) == "string" and id ~= "", tostring(id))
					if typeof(id) == "string" and id ~= "" then ids[id] = (ids[id] or 0) + 1 end
				end
			end
		end
		local unique = 0
		for _, count in pairs(ids) do if count == 1 then unique += 1 end end
		check("six unique tile image IDs", unique == 6, unique)
	end
end

for _, name in ipairs({ "NTR_LoadingMusic", "NTR_GameplayMusic", "NTR_Vehicle", "NTR_Ambience", "NTR_GameplaySFX", "NTR_UI" }) do
	local group = SoundService:FindFirstChild(name)
	check("audio group " .. name, group ~= nil and group:IsA("SoundGroup"), group and group.ClassName or "missing")
end

check("no persistent loading background in StarterGui", StarterGui:FindFirstChild("NTR_LoadingBackground", true) == nil)
check("no persistent loading safe content in StarterGui", StarterGui:FindFirstChild("NTR_LoadingSafeContent", true) == nil)
check("no persistent runtime loading sound", SoundService:FindFirstChild("NTR_LoadingMusic_Runtime", true) == nil)

print(("%s SUMMARY: %d PASS / %d FAIL / %d WARN"):format(PREFIX, passed, failed, warned))
if failed > 0 then
	error(("%s FAILED: resolve the reported static contract failures before Phase 6 Play verification."):format(PREFIX), 0)
end
if warned > 0 then
	warn(("%s STATIC PASS WITH WARNINGS: review the warnings, then proceed with the manual Phase 6 matrix."):format(PREFIX))
else
	print(PREFIX .. " STATIC PASS: proceed with the manual Phase 6 matrix.")
end
