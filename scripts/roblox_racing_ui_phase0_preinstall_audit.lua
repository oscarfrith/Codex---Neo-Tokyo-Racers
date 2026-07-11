-- Neo Tokyo Racers - Racing UI Phase 0 Pre-Install Audit
-- Run in Roblox Studio Command Bar in Edit mode.
-- READ-ONLY: does not create, modify, move, disable, or delete anything.

local PHASE = "NTR Racing UI Phase 0 Pre-Install Audit"
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local count = { pass = 0, warn = 0, fail = 0 }

local function log(kind, message)
	kind = string.lower(kind)
	count[kind] += 1
	local output = string.format("[%s] %s %s", PHASE, string.upper(kind), tostring(message))
	if kind == "warn" or kind == "fail" then warn(output) else print(output) end
end

local function get(parent, name, className, required)
	local item = parent and parent:FindFirstChild(name)
	if not item then
		log(required and "fail" or "warn", "Missing " .. name .. " under " .. (parent and parent:GetFullName() or "nil"))
		return nil
	end
	if className and not item:IsA(className) then
		log("fail", item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. className)
		return item
	end
	log("pass", "Found " .. item:GetFullName())
	return item
end

local function marker(object, text, label, severity)
	if not object or not object:IsA("LuaSourceContainer") then return end
	local ok, source = pcall(function() return object.Source end)
	if not ok then log("warn", label .. " source unreadable in this context") return end
	if string.find(source, text, 1, true) then
		log("pass", label .. " marker: " .. text)
	else
		log(severity or "fail", label .. " missing marker/text: " .. text)
	end
end

local function enabled(object, expected, label)
	if not object or not object:IsA("BaseScript") then return end
	if object.Enabled == expected then
		log("pass", label .. " Enabled=" .. tostring(expected))
	else
		log("fail", label .. " Enabled=" .. tostring(object.Enabled) .. ", expected " .. tostring(expected))
	end
end

print("[" .. PHASE .. "] INFO IsEdit=" .. tostring(RunService:IsEdit()) .. " IsClient=" .. tostring(RunService:IsClient()))
print("[" .. PHASE .. "] INFO Read-only audit; no Instances or source will change.")

local ntr = get(ReplicatedStorage, "NeoTokyoRacers", "Folder", true)
local shared = get(ntr, "Shared", "Folder", true)
local remotes = get(shared, "Remotes", "Folder", true)
local raceRemotes = get(remotes, "Racing", "Folder", true)
get(raceRemotes, "RaceRequest", "RemoteFunction", true)
get(raceRemotes, "RaceEvent", "RemoteEvent", true)
get(raceRemotes, "RaceQueueRequest", "RemoteFunction", true)
get(raceRemotes, "RaceQueueEvent", "RemoteEvent", true)
get(raceRemotes, "RaceBrowserTeleportInvoke", "RemoteFunction", true)

local config = get(ntr, "Config", "Folder", true)
local uiConfig = get(config, "UI", "Folder", true)
get(uiConfig, "Theme", "Folder", true)
local desktopHud = get(uiConfig, "DesktopFreeRoamHud", "Folder", true)
local colours = get(desktopHud, "Colours", "Folder", true)
for _, name in ipairs({ "PanelDeep", "Panel", "PanelSoft", "Outline", "OutlineSoft", "Telemetry", "ElectricBlue", "Danger", "Text", "Muted", "Disabled" }) do
	get(colours, name, "Color3Value", true)
end
if uiConfig and uiConfig:FindFirstChild("Racing") then
	log("warn", "Config.UI.Racing already exists; inspect and preserve edited values")
else
	log("pass", "No existing Config.UI.Racing conflicts with planned config")
end

local raceConfig = get(config, "Racing", "Folder", true)
local rewardConfig = get(raceConfig, "Rewards", "Folder", true)
get(rewardConfig, "TimeTrial", "Folder", true)
get(rewardConfig, "Race", "Folder", true)
get(raceConfig, "PersonalBests", "Folder", true)
get(raceConfig, "RouteGuide", "Folder", true)
get(raceConfig, "Matchmaking", "Folder", true)

local starterScripts = get(StarterPlayer, "StarterPlayerScripts", nil, true)
local clientRoot = get(starterScripts, "NeoTokyoRacersClient", nil, true)
local controllers = get(clientRoot, "Controllers", "Folder", true)
local racing = get(controllers, "Racing", "Folder", true)
local ui = get(controllers, "UI", "Folder", true)

local bootstrap = get(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled", "LocalScript", true)
local browser = get(racing, "RaceBrowserClient_Active", "LocalScript", true)
local entry = get(racing, "RaceEntryMenuClient_Active", "LocalScript", true)
local oldClient = get(racing, "RaceClient_Active", "LocalScript", true)
local queue = get(racing, "RaceQueueClient_Active", "LocalScript", true)
local coach = get(racing, "RaceTimeTrialResultCoachClient_Active", "LocalScript", true)
local cleanup = get(racing, "RaceHudExitCleanupClient_Active", "LocalScript", true)
local controls = get(racing, "RaceSessionControlsClient_Active", "LocalScript", true)
local transition = get(racing, "RaceTransitionClient_Active", "LocalScript", true)
local routeGuide = get(racing, "RaceRouteGuideClient_Active", "LocalScript", true)
local assets = get(racing, "RaceSessionAssetsClient_Active", "LocalScript", true)
local visibility = get(racing, "RaceParticipantVisibilityClient_Active", "LocalScript", true)
local pbBoard = get(racing, "RacePersonalBestBoardClient_Active", "LocalScript", true)
local freeRoamHud = get(ui, "DesktopFreeRoamHudController_Active", "LocalScript", true)
get(ui, "OpenRaceBrowser", "BindableEvent", true)

enabled(browser, true, "Race browser")
enabled(entry, true, "Race entry")
enabled(oldClient, false, "Legacy RaceClient")
enabled(queue, true, "Race queue")
enabled(coach, true, "Result coach")
enabled(cleanup, true, "Narrow HUD cleanup")
enabled(freeRoamHud, true, "Phase 4A free-roam HUD")

marker(bootstrap, "V75Driving.Start", "Register-limited bootstrap")
marker(bootstrap, "FreeRoamVehicleExited", "Register-limited bootstrap")
marker(browser, "RaceBrowserTeleportInvoke", "Race browser")
marker(browser, "OpenRaceBrowser", "Race browser")
marker(entry, "StartStagedTimeTrial", "Race entry")
marker(entry, "GetTimeTrialPersonalBest", "Race entry")
marker(entry, "NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF", "Race entry")
marker(queue, "ExitRaceToStart", "Race queue")
marker(queue, "NTR_RACING_PHASE11D_FINISH_EXIT_UI", "Race queue")
marker(coach, "NTR_RACING_PHASE11T_ISOLATED_TT_RESULT_COACH", "Result coach")
marker(coach, "NTR_RACING_PHASE11Y_RESULT_COACH_CONFIRMED_EXIT", "Result coach")
marker(cleanup, "NTR_RACING_PHASE11U_TT_HUD_EXIT_CLEANUP_V2_HUD_ONLY", "HUD cleanup")
marker(controls, "ResetActiveTimeTrial", "Session controls")
marker(transition, "TimeTrialReset", "Transition")
marker(routeGuide, "NTR_RACING_PHASE5F_CHECKPOINT_PILL_LABEL", "Route guide", "warn")
marker(assets, "NTR_RACING_PHASE11L_ARROW_VISUAL_PROXY_SYNC_V2_TRANSPARENCY_RESTORE", "Session assets")
marker(visibility, "NTR_RACING_PHASE11L_MULTI_SESSION_VISIBILITY_OWNER", "Visibility")
marker(pbBoard, "NTR_RACING_PHASE11O_TIME_TRIAL_PB_BOARD_V2_MENU_CLOSE_SYNC", "PB board")

local serverRoot = get(ServerScriptService, "NeoTokyoRacers", "Folder", true)
local services = get(serverRoot, "Services", "Folder", true)
local racingServices = get(services, "Racing", "Folder", true)
local tt = get(racingServices, "TimeTrialService_Active", "Script", true)
local race = get(racingServices, "RaceMatchmakingService_Active", "Script", true)
local rewards = get(racingServices, "RaceRewardService_Active", "Script", true)
local pb = get(racingServices, "RacePersonalBestService_Active", "Script", true)
local teleport = get(racingServices, "RaceBrowserTeleportService_Active", "Script", true)
marker(tt, "NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY", "TT lifecycle")
marker(tt, "ExitFinishedTimeTrial", "TT lifecycle")
marker(tt, "RewardGranted", "TT result payload")
marker(race, "GrantRaceReward", "Race result payload")
marker(rewards, "claimedRunIds", "Reward idempotency")
marker(rewards, "GrantTimeTrialReward", "Reward service")
marker(rewards, "GrantRaceReward", "Reward service")
marker(pb, "NTR_RACING_PHASE11M_PERSONAL_BEST_SERVICE", "PB service")
marker(teleport, "TeleportToRaceStart", "Browser teleport")

local world = get(Workspace, "NeoTokyoRacersWorld", "Folder", true)
local routes = get(world, "RaceRoutes", "Folder", true)
local route = get(routes, "ShiftedCanalSprint", "Folder", true)
get(route, "Checkpoints", "Folder", true)
get(route, "ArrowMarkers", "Folder", true)
get(route, "SpawnGrid", "Folder", true)
local points = get(route, "TeleportPoints", "Folder", true)
get(points, "RaceBrowserTeleportPoint", "BasePart", true)

local instances = world and world:FindFirstChild("RaceInstances")
if instances and #instances:GetChildren() > 0 then
	log("warn", "RaceInstances has active children; rerun outside an active session")
else
	log("pass", "No active RaceInstances conflict")
end

print(string.format("[%s] SUMMARY pass=%d warn=%d fail=%d", PHASE, count.pass, count.warn, count.fail))
if count.fail == 0 then
	print("[" .. PHASE .. "] READY Paste the complete Output into Codex before the condensed shared-shell/browser-entry installer.")
else
	warn("[" .. PHASE .. "] STOP Refresh/inspect every failed live owner or marker before installation.")
end

