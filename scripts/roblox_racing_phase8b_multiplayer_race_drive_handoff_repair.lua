-- Neo Tokyo Racers - Racing Phase 8B Multiplayer Race Drive Handoff Repair
-- Run in Roblox Studio Command Bar in Edit mode after Phase 8.
--
-- Root cause addressed:
-- Phase 8 released the race on the server, but multiplayer RaceStarted did not
-- re-fire the existing local free-roam driving handoff or streaming request.
-- This could leave staged race vehicles visible but not hovering/drivable, with
-- nearby world streaming looking like it switched off.

local MODE = "INSTALL" -- INSTALL or SMOKE

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message)
	error("[NTR Racing Phase 8B] " .. tostring(message), 2)
end

local function replaceOnce(source, old, new, label)
	local first = string.find(source, old, 1, true)
	if not first then
		fail("Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another repair.")
	end
	local second = string.find(source, old, first + #old, true)
	if second then
		fail("Source anchor is not unique: " .. label)
	end
	return string.sub(source, 1, first - 1) .. new .. string.sub(source, first + #old)
end

local function racingClientFolder()
	local scripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	return scripts:WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing")
end

local function racingServiceFolder()
	return ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing")
end

local function patchMatchmakingService()
	local service = racingServiceFolder():WaitForChild("RaceMatchmakingService_Active")
	if not service:IsA("Script") then
		fail("RaceMatchmakingService_Active is not a Script")
	end
	local source = service.Source
	if string.find(source, "NTR_RACING_PHASE8B_ROOT_ONLY_FREEZE", 1, true) then
		return
	end
	local oldBlock = [[local function setVehicleFrozen(vehicle, frozen)
	local root = vehicleRootPart(vehicle)
	if not root then return end
	for _, item in ipairs(vehicle:GetDescendants()) do
		if item:IsA("BasePart") then
			item.AssemblyLinearVelocity = Vector3.zero
			item.AssemblyAngularVelocity = Vector3.zero
			item.Anchored = frozen == true
		end
	end
	vehicle:SetAttribute("NTR_RaceFrozen", frozen == true)
	vehicle:SetAttribute("DriveReady", frozen ~= true)
	root.Anchored = frozen == true
end]]
	local newBlock = [[local function setVehicleFrozen(vehicle, frozen)
	-- NTR_RACING_PHASE8B_ROOT_ONLY_FREEZE
	local root = vehicleRootPart(vehicle)
	if not root then return end
	for _, item in ipairs(vehicle:GetDescendants()) do
		if item:IsA("BasePart") then
			item.AssemblyLinearVelocity = Vector3.zero
			item.AssemblyAngularVelocity = Vector3.zero
			if frozen ~= true then
				item.Anchored = false
			end
		end
	end
	vehicle:SetAttribute("NTR_RaceFrozen", frozen == true)
	vehicle:SetAttribute("DriveReady", frozen ~= true)
	root.Anchored = frozen == true
end]]
	if string.find(source, oldBlock, 1, true) then
		source = replaceOnce(source, oldBlock, newBlock, "root-only staging freeze")
	elseif string.find(source, "if frozen ~= true then", 1, true) then
		source = replaceOnce(source,
			[[local function setVehicleFrozen(vehicle, frozen)
	local root = vehicleRootPart(vehicle)]],
			[[local function setVehicleFrozen(vehicle, frozen)
	-- NTR_RACING_PHASE8B_ROOT_ONLY_FREEZE
	local root = vehicleRootPart(vehicle)]],
			"mark existing root-only staging freeze")
	else
		fail("Could not find source anchor: root-only staging freeze. Refresh the Studio mirror before another repair.")
	end
	service.Source = source
end

local function patchQueueClient()
	local client = racingClientFolder():WaitForChild("RaceQueueClient_Active")
	if not client:IsA("LocalScript") then
		fail("RaceQueueClient_Active is not a LocalScript")
	end
	local source = client.Source
	if string.find(source, "NTR_RACING_PHASE8B_RACE_DRIVE_HANDOFF", 1, true) then
		return
	end
	source = replaceOnce(source,
		[[local RunService = game:GetService("RunService")]],
		[[local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")]],
		"workspace service declaration")
	source = replaceOnce(source,
		[[local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")
local queueEvent = racingRemotes:WaitForChild("RaceQueueEvent")]],
		[[local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")
local queueEvent = racingRemotes:WaitForChild("RaceQueueEvent")
local RouteDefinition = require(shared:WaitForChild("Modules"):WaitForChild("Racing"):WaitForChild("RaceRouteDefinition"))]],
		"route definition declaration")
	source = replaceOnce(source,
		[[local function invokeQueue(action, payload)
	local ok, result = pcall(function()
		return queueRequest:InvokeServer(action, payload or {})
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Success = false, Message = tostring(result or "Queue request failed.") }
end]],
		[[local function invokeQueue(action, payload)
	local ok, result = pcall(function()
		return queueRequest:InvokeServer(action, payload or {})
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Success = false, Message = tostring(result or "Queue request failed.") }
end

local function fireDrivingHandoff()
	-- NTR_RACING_PHASE8B_RACE_DRIVE_HANDOFF
	local clientRoot = script.Parent.Parent
	local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
	local spawnedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleSpawned")
	if spawnedEvent and spawnedEvent:IsA("BindableEvent") then
		spawnedEvent:Fire()
	end
end

local function requestStreamAroundRoute(routeId, nextGateIndex)
	local route = RouteDefinition.GetRouteDefinition(routeId)
	local gate = route and RouteDefinition.GetGate(route, nextGateIndex or 1)
	local part = gate and gate.Part
	if part then
		pcall(function()
			Workspace:RequestStreamAroundAsync(part.Position)
		end)
	end
end]],
		"race driving handoff helpers")
	source = replaceOnce(source,
		[[	elseif kind == "RaceStarted" then
		state.ActiveRun = payload
		state.StartLocalClock = os.clock()
		title.Text = tostring(payload.DisplayName or "RACE")
		details.Text = "Position updates appear at checkpoints."
		setVisible(true)
		startTicker()]],
		[[	elseif kind == "RaceStarted" then
		state.ActiveRun = payload
		state.StartLocalClock = os.clock()
		title.Text = tostring(payload.DisplayName or "RACE")
		details.Text = "Position updates appear at checkpoints."
		setVisible(true)
		task.defer(requestStreamAroundRoute, payload.RouteId, payload.NextGateIndex or 1)
		task.defer(fireDrivingHandoff)
		task.delay(0.25, fireDrivingHandoff)
		startTicker()]],
		"race started client handoff")
	client.Source = source
end

local function install()
	patchMatchmakingService()
	patchQueueClient()
	print("[NTR Racing Phase 8B] Installed multiplayer race drive handoff repair.")
	print("[NTR Racing Phase 8B] Root cause: RaceStarted needed the same client driving/streaming handoff as time trials.")
end

local function smoke()
	local service = racingServiceFolder():FindFirstChild("RaceMatchmakingService_Active")
	assert(service and string.find(service.Source, "NTR_RACING_PHASE8B_ROOT_ONLY_FREEZE", 1, true), "service freeze repair missing")
	local client = racingClientFolder():FindFirstChild("RaceQueueClient_Active")
	assert(client and string.find(client.Source, "NTR_RACING_PHASE8B_RACE_DRIVE_HANDOFF", 1, true), "queue client handoff repair missing")
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local rewards = kit:WaitForChild("Config"):WaitForChild("Racing"):FindFirstChild("Rewards")
	assert(rewards == nil or (rewards:FindFirstChild("TimeTrial") and rewards:FindFirstChild("Race")), "Rewards folder shape looks unexpected")
	print("[NTR Racing Phase 8B] Smoke passed.")
end

if MODE == "INSTALL" then
	install()
	smoke()
elseif MODE == "SMOKE" then
	smoke()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
