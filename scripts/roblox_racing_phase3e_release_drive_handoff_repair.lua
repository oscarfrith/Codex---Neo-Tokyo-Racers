-- Neo Tokyo Racers - Racing Phase 3E Release Drive Handoff Repair
-- Fixes the post-countdown handoff where the time trial starts but the vehicle
-- is not drivable and nearby world assets stream in/out after release.
--
-- This patches only isolated Racing service/client scripts. It does not touch
-- the main bootstrap, garage server, driving physics source, VFX, dealership,
-- or customisation UI.
--
-- Usage:
--   Run in Roblox Studio Command Bar in Edit mode, then restart Play.

local PHASE = "NTR Racing Phase 3E"

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 0)
end

local function replaceExact(source, needle, replacement, label)
	local startIndex, endIndex = source:find(needle, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another racing Phase 3E repair.")
	end
	return source:sub(1, startIndex - 1) .. replacement .. source:sub(endIndex + 1)
end

local function patchServer()
	local serverRoot = ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Racing")
	local service = serverRoot and serverRoot:FindFirstChild("TimeTrialService_Active")
	if not (service and service:IsA("Script")) then
		fail("Could not find TimeTrialService_Active. Run Racing Phase 3 first.")
	end

	local source = service.Source
	if source:find("NTR_RACING_PHASE3E_RELEASE_HANDOFF", 1, true) then
		info("TimeTrialService_Active already has Phase 3E release repair.")
		return
	end

	local oldBlock = [[
local function seatPlayer(player, vehicle)
	local seat = vehicleSeat(vehicle)
	if not seat then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		seat:Sit(humanoid)
	end
end
]]

	local newBlock = [[
local function seatPlayer(player, vehicle)
	local seat = vehicleSeat(vehicle)
	if not seat then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		seat:Sit(humanoid)
	end
end

local function prepareVehicleForDriving(player, vehicle)
	-- NTR_RACING_PHASE3E_RELEASE_HANDOFF
	local root = vehicleRootPart(vehicle)
	if not root then return end
	for _, descendant in ipairs(vehicle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
	vehicle:SetAttribute("NTR_RaceFrozen", false)
	vehicle:SetAttribute("DriveReady", true)
	vehicle:SetAttribute("ParkedShowcase", nil)
	vehicle:SetAttribute("DriverUserId", player.UserId)
	pcall(function()
		root:SetNetworkOwner(player)
	end)
	seatPlayer(player, vehicle)
end
]]

	source = replaceExact(source, oldBlock, newBlock, "seatPlayer/prepareVehicleForDriving")

	local oldRelease = [[
		live.State = "Running"
		live.StartClock = os.clock()
		live.LastTouchClock = 0
		setVehicleFrozen(vehicle, false)
		seatPlayer(player, vehicle)
		fire(player, {
			Type = "TimeTrialStarted",
]]

	local newRelease = [[
		live.State = "Running"
		live.StartClock = os.clock()
		live.LastTouchClock = 0
		prepareVehicleForDriving(player, vehicle)
		fire(player, {
			Type = "TimeTrialStarted",
]]

	source = replaceExact(source, oldRelease, newRelease, "countdown release")
	service.Source = source
	service.Disabled = false
	info("Patched TimeTrialService_Active release to prepare vehicle/network ownership for driving.")
end

local function patchClient()
	local playerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local racingFolder = controllers and controllers:FindFirstChild("Racing")
	local client = racingFolder and racingFolder:FindFirstChild("RaceEntryMenuClient_Active")
	if not (client and client:IsA("LocalScript")) then
		fail("Could not find RaceEntryMenuClient_Active. Run Racing Phase 3 first.")
	end

	local source = client.Source
	if source:find("NTR_RACING_PHASE3E_CLIENT_HANDOFF", 1, true) then
		info("RaceEntryMenuClient_Active already has Phase 3E client repair.")
		return
	end

	local oldHelperAnchor = [[
local function routeForActive()
	if not state.ActiveRun then return nil end
]]

	local newHelperAnchor = [[
local function fireDrivingHandoff()
	-- NTR_RACING_PHASE3E_CLIENT_HANDOFF
	local clientRoot = script.Parent.Parent
	local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
	local spawnedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleSpawned")
	if spawnedEvent and spawnedEvent:IsA("BindableEvent") then
		spawnedEvent:Fire()
	end
end

local routeForActive

local function requestStreamAroundActiveRoute()
	local route = routeForActive()
	local gate = route and RouteDefinition.GetGate(route, state.ActiveRun and state.ActiveRun.NextGateIndex or 1)
	local part = gate and gate.Part
	if part then
		pcall(function()
			Workspace:RequestStreamAroundAsync(part.Position)
		end)
	end
end

function routeForActive()
	if not state.ActiveRun then return nil end
]]

	source = replaceExact(source, oldHelperAnchor, newHelperAnchor, "client handoff helpers")

	local oldStarted = [[
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudStatus.Text = "GO"
		updateNextGate()
		startTicker()
]]

	local newStarted = [[
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudStatus.Text = "GO"
		updateNextGate()
		task.defer(requestStreamAroundActiveRoute)
		task.defer(fireDrivingHandoff)
		task.delay(0.25, fireDrivingHandoff)
		startTicker()
]]

	source = replaceExact(source, oldStarted, newStarted, "TimeTrialStarted client handoff")
	client.Source = source
	client.Disabled = false
	info("Patched RaceEntryMenuClient_Active to re-fire driving handoff and stream around route on GO.")
end

patchServer()
patchClient()

info("Installed Phase 3E release drive handoff repair.")
info("Restart Play, start a time trial, and verify the car becomes drivable after GO without map streaming flicker.")
