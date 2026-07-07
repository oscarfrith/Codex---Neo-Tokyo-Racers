-- Neo Tokyo Racers - Racing Phase 2 Solo Time Trial MVP
-- Installs isolated Racing route-definition modules, a server-authoritative solo
-- time-trial service, and local entry/HUD/route-guide clients.
--
-- This script does not patch the main client bootstrap, driving, garage,
-- dealership, VFX, or persistence source. Rewards and multiplayer are deferred.
--
-- Usage:
--   MODE = "INSTALL" installs the isolated MVP.
--   MODE = "AUDIT" checks expected objects without changing anything.

local MODE = "INSTALL" -- "INSTALL" or "AUDIT"
local PHASE = "NTR Racing Phase 2"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function warnLine(message)
	warn("[" .. PHASE .. "] " .. tostring(message))
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		error("Cannot create Folder " .. name .. " because " .. existing:GetFullName() .. " is " .. existing.ClassName)
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemote(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function ensureScript(parent, className, name, source, disabled)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName ~= className then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		existing = Instance.new(className)
		existing.Name = name
		existing.Parent = parent
	end
	existing.Source = source
	if existing:IsA("Script") or existing:IsA("LocalScript") then
		existing.Disabled = disabled == true
	end
	return existing
end

local ROUTE_DEFINITION_SOURCE = [=[
-- Neo Tokyo Racers - RaceRouteDefinition
-- NTR_RACING_PHASE2_ROUTE_DEFINITION

local Workspace = game:GetService("Workspace")

local RouteDefinition = {}

local function numberAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	return typeof(value) == "number" and value or fallback
end

local function indexedNameFallback(instance, fallback)
	local text = instance and instance.Name or ""
	local digits = string.match(text, "(%d+)$")
	return digits and tonumber(digits) or fallback
end

local function stringAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	return typeof(value) == "string" and value or fallback
end

local function cframeFor(part)
	if part and part:IsA("BasePart") then
		return part.CFrame
	end
	return CFrame.new()
end

local function sizeFor(part)
	if part and part:IsA("BasePart") then
		return part.Size
	end
	return Vector3.new(20, 20, 20)
end

local function worldRoot()
	return Workspace:FindFirstChild("NeoTokyoRacersWorld")
end

function RouteDefinition.GetRoutesRoot()
	local world = worldRoot()
	return world and world:FindFirstChild("RaceRoutes")
end

function RouteDefinition.GetRouteFolder(routeId)
	local routes = RouteDefinition.GetRoutesRoot()
	return routes and routes:FindFirstChild(tostring(routeId or ""))
end

local function collectParts(folder, indexAttribute)
	local result = {}
	if not folder then return result end
	for _, item in ipairs(folder:GetChildren()) do
		if item:IsA("BasePart") then
			local nameIndex = indexedNameFallback(item, nil)
			local index = nameIndex or numberAttribute(item, indexAttribute, nil)
			if index ~= nil then
				table.insert(result, {
					Index = index,
					Name = item.Name,
					Part = item,
					CFrame = item.CFrame,
					Size = item.Size,
					RouteId = stringAttribute(item, "RouteId", nil),
				})
			end
		end
	end
	table.sort(result, function(a, b)
		if a.Index == b.Index then
			return a.Name < b.Name
		end
		return a.Index < b.Index
	end)
	return result
end

local function collectStartZones(route)
	local zones = {}
	local root = route and route:FindFirstChild("StartZones")
	if not root then return zones end
	for _, item in ipairs(root:GetChildren()) do
		if item:IsA("BasePart") then
			table.insert(zones, {
				Name = item.Name,
				Part = item,
				Mode = stringAttribute(item, "Mode", item.Name == "RaceStartZone" and "Race" or "TimeTrial"),
				EventId = stringAttribute(item, "EventId", nil),
				PromptActionText = stringAttribute(item, "PromptActionText", nil),
				CFrame = item.CFrame,
				Size = item.Size,
			})
		end
	end
	table.sort(zones, function(a, b)
		return a.Name < b.Name
	end)
	return zones
end

local function collectSpawnGrid(route)
	local grid = collectParts(route and route:FindFirstChild("SpawnGrid"), "GridIndex")
	for _, item in ipairs(grid) do
		item.GridIndex = item.Index
	end
	return grid
end

local function collectArrowMarkers(route)
	local arrows = collectParts(route and route:FindFirstChild("ArrowMarkers"), "ArrowIndex")
	for _, item in ipairs(arrows) do
		local part = item.Part
		item.ArrowIndex = item.Index
		item.TargetCheckpointIndex = numberAttribute(part, "TargetCheckpointIndex", item.Index)
		item.DisplayMode = stringAttribute(part, "DisplayMode", "WhenNext")
		item.ArrowStyle = stringAttribute(part, "ArrowStyle", "Chevron")
		item.ArrowAssetId = stringAttribute(part, "ArrowAssetId", "")
		item.Scale = numberAttribute(part, "Scale", 1)
		item.ColorRole = stringAttribute(part, "ColorRole", "Accent")
	end
	return arrows
end

function RouteDefinition.GetRouteDefinition(routeId)
	local route = RouteDefinition.GetRouteFolder(routeId)
	if not route then
		return nil, "Route not found: " .. tostring(routeId)
	end

	local checkpoints = collectParts(route:FindFirstChild("Checkpoints"), "CheckpointIndex")
	for _, checkpoint in ipairs(checkpoints) do
		checkpoint.IsFinish = false
	end

	local finishPart = route:FindFirstChild("FinishLine")
	local maxCheckpointIndex = 0
	for _, checkpoint in ipairs(checkpoints) do
		maxCheckpointIndex = math.max(maxCheckpointIndex, checkpoint.Index or 0)
	end
	local finishIndex = math.max(numberAttribute(finishPart, "CheckpointIndex", maxCheckpointIndex + 1), maxCheckpointIndex + 1)
	local finish = nil
	if finishPart and finishPart:IsA("BasePart") then
		finish = {
			Index = finishIndex,
			Name = finishPart.Name,
			Part = finishPart,
			CFrame = cframeFor(finishPart),
			Size = sizeFor(finishPart),
			RouteId = stringAttribute(finishPart, "RouteId", nil),
			IsFinish = true,
		}
	end

	local orderedGates = {}
	for _, checkpoint in ipairs(checkpoints) do
		table.insert(orderedGates, checkpoint)
	end
	if finish then
		table.insert(orderedGates, finish)
	end
	table.sort(orderedGates, function(a, b)
		if a.Index == b.Index then
			return tostring(a.Name) < tostring(b.Name)
		end
		return a.Index < b.Index
	end)

	return {
		RouteId = stringAttribute(route, "RouteId", tostring(routeId)),
		DisplayName = stringAttribute(route, "DisplayName", tostring(routeId)),
		SourceType = stringAttribute(route, "SourceType", "Official"),
		CreatorUserId = numberAttribute(route, "CreatorUserId", 0),
		Version = numberAttribute(route, "Version", 1),
		Folder = route,
		StartZones = collectStartZones(route),
		SpawnGrid = collectSpawnGrid(route),
		Checkpoints = checkpoints,
		FinishLine = finish,
		Gates = orderedGates,
		ArrowMarkers = collectArrowMarkers(route),
		ValidationSummary = {
			CheckpointCount = #checkpoints,
			HasFinish = finish ~= nil,
			GateCount = #orderedGates,
		},
	}
end

function RouteDefinition.GetGate(routeDefinition, gateIndex)
	if not routeDefinition then return nil end
	return routeDefinition.Gates and routeDefinition.Gates[gateIndex] or nil
end

function RouteDefinition.GetGateCount(routeDefinition)
	return routeDefinition and routeDefinition.Gates and #routeDefinition.Gates or 0
end

return RouteDefinition
]=]

local CONFIG_READER_SOURCE = [=[
-- Neo Tokyo Racers - RaceConfigReader
-- NTR_RACING_PHASE2_CONFIG_READER

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RouteDefinition = require(script.Parent:WaitForChild("RaceRouteDefinition"))

local Reader = {}

local function kit()
	return ReplicatedStorage:WaitForChild("NeoTokyoRacers")
end

local function racingConfig()
	return kit():WaitForChild("Config"):WaitForChild("Racing")
end

local function stringAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	return typeof(value) == "string" and value or fallback
end

local function numberAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	return typeof(value) == "number" and value or fallback
end

function Reader.GetTimeTrialEvent(eventId)
	local catalog = racingConfig():FindFirstChild("TimeTrialCatalog")
	local event = catalog and catalog:FindFirstChild(tostring(eventId or ""))
	if not event then
		for _, candidate in ipairs(catalog and catalog:GetChildren() or {}) do
			if stringAttribute(candidate, "EventId", "") == tostring(eventId or "") then
				event = candidate
				break
			end
		end
	end
	if not event then
		return nil, "Time trial event not found: " .. tostring(eventId)
	end
	return event
end

function Reader.GetRouteForEvent(eventId)
	local event, eventError = Reader.GetTimeTrialEvent(eventId)
	if not event then
		return nil, eventError
	end
	local routeId = stringAttribute(event, "RouteId", "")
	if routeId == "" then
		return nil, "Time trial event has no RouteId: " .. tostring(eventId)
	end
	return RouteDefinition.GetRouteDefinition(routeId)
end

function Reader.GetEventSummary(eventId)
	local event, eventError = Reader.GetTimeTrialEvent(eventId)
	if not event then
		return nil, eventError
	end
	return {
		EventId = stringAttribute(event, "EventId", tostring(eventId)),
		DisplayName = stringAttribute(event, "DisplayName", event.Name),
		Mode = stringAttribute(event, "Mode", "TimeTrial"),
		RouteId = stringAttribute(event, "RouteId", ""),
		AllowedVehicleTiers = stringAttribute(event, "AllowedVehicleTiers", "E,D,C,B,A,S"),
		RecommendedTier = stringAttribute(event, "RecommendedTier", "D"),
		BaseReward = numberAttribute(event, "BaseReward", 0),
		Laps = numberAttribute(event, "Laps", 1),
	}
end

return Reader
]=]

local TIME_TRIAL_SERVICE_SOURCE = [=[
-- Neo Tokyo Racers - Solo Time Trial Service
-- NTR_RACING_PHASE2_TIME_TRIAL_SERVICE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceRequest = racingRemotes:WaitForChild("RaceRequest")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local racingModules = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Racing")
local RouteDefinition = require(racingModules:WaitForChild("RaceRouteDefinition"))
local RaceConfigReader = require(racingModules:WaitForChild("RaceConfigReader"))

local PHASE = "NTR Racing Phase 2"
local PROMPT_NAME = "NTR_TimeTrialStartPrompt"
local COUNTDOWN_SECONDS = 3
local activeRuns = {}
local promptConnections = {}

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function warnLine(message)
	warn("[" .. PHASE .. "] " .. tostring(message))
end

local function runtimeVehiclesRoot()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

local function vehicleFromSeat(seat)
	local current = seat
	while current do
		if current:IsA("Model") and current:GetAttribute("OwnerUserId") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function currentVehicleForPlayer(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then
		return nil, "Enter with a vehicle."
	end
	local vehicle = vehicleFromSeat(seat)
	local vehiclesRoot = runtimeVehiclesRoot()
	if not (vehicle and vehiclesRoot and vehicle:IsDescendantOf(vehiclesRoot)) then
		return nil, "Vehicle is not a Neo Tokyo runtime vehicle."
	end
	if tonumber(vehicle:GetAttribute("OwnerUserId")) ~= player.UserId then
		return nil, "Use your own vehicle."
	end
	local tier = tostring(vehicle:GetAttribute("PerformanceTier") or "")
	if tier == "" then
		return nil, "Vehicle performance tier is not ready."
	end
	return vehicle, nil
end

local function isPointInside(part, position)
	if not (part and part:IsA("BasePart")) then return false end
	local localPoint = part.CFrame:PointToObjectSpace(position)
	local half = part.Size * 0.5
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

local function vehiclePosition(vehicle)
	local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function fire(player, payload)
	raceEvent:FireClient(player, payload)
end

local function endRun(player, reason)
	local run = activeRuns[player]
	if not run then return end
	activeRuns[player] = nil
	fire(player, {
		Type = "TimeTrialEnded",
		Reason = reason or "Ended",
	})
end

local function finishRun(player)
	local run = activeRuns[player]
	if not run then return end
	local elapsed = os.clock() - run.StartClock
	activeRuns[player] = nil
	fire(player, {
		Type = "TimeTrialFinished",
		EventId = run.EventId,
		RouteId = run.RouteId,
		DisplayName = run.DisplayName,
		Elapsed = elapsed,
		GateCount = run.GateCount,
		Message = "Finished. Rewards come in a later phase.",
	})
	info(player.Name .. " finished " .. tostring(run.EventId) .. " in " .. string.format("%.3f", elapsed) .. "s")
end

local function advanceCheckpoint(player, touchedPart)
	local run = activeRuns[player]
	if not (run and run.State == "Running") then return end
	local gate = RouteDefinition.GetGate(run.Route, run.NextGateIndex)
	if not (gate and gate.Part == touchedPart) then return end
	local now = os.clock()
	if now - (run.LastTouchClock or 0) < 0.12 then return end
	run.LastTouchClock = now

	if gate.IsFinish then
		finishRun(player)
		return
	end

	run.NextGateIndex += 1
	fire(player, {
		Type = "TimeTrialCheckpoint",
		EventId = run.EventId,
		RouteId = run.RouteId,
		NextGateIndex = run.NextGateIndex,
		GateCount = run.GateCount,
		CheckpointIndex = gate.Index,
		Elapsed = now - run.StartClock,
	})
end

local function connectRouteTouches(route)
	for _, gate in ipairs(route.Gates or {}) do
		if gate.Part and not promptConnections[gate.Part] then
			gate.Part.CanTouch = true
			gate.Part.CanQuery = true
			gate.Part.CanCollide = false
			promptConnections[gate.Part] = gate.Part.Touched:Connect(function(hit)
				local model = hit and hit:FindFirstAncestorOfClass("Model")
				if not model then return end
				for player, run in pairs(activeRuns) do
					if run.Vehicle == model or (run.Vehicle and model:IsDescendantOf(run.Vehicle)) then
						advanceCheckpoint(player, gate.Part)
						break
					end
				end
			end)
		end
	end
end

local function beginRunAfterCountdown(player, eventId, route, vehicle)
	local summary = RaceConfigReader.GetEventSummary(eventId) or {}
	activeRuns[player] = {
		State = "Countdown",
		EventId = eventId,
		RouteId = route.RouteId,
		DisplayName = summary.DisplayName or route.DisplayName,
		Route = route,
		Vehicle = vehicle,
		NextGateIndex = 1,
		GateCount = RouteDefinition.GetGateCount(route),
		StartRequestClock = os.clock(),
	}

	connectRouteTouches(route)
	fire(player, {
		Type = "TimeTrialCountdown",
		EventId = eventId,
		RouteId = route.RouteId,
		DisplayName = summary.DisplayName or route.DisplayName,
		Countdown = COUNTDOWN_SECONDS,
		GateCount = RouteDefinition.GetGateCount(route),
		NextGateIndex = 1,
	})

	task.delay(COUNTDOWN_SECONDS, function()
		local run = activeRuns[player]
		if not (run and run.State == "Countdown" and run.EventId == eventId) then return end
		local currentVehicle, vehicleError = currentVehicleForPlayer(player)
		if currentVehicle ~= vehicle then
			endRun(player, vehicleError or "Vehicle changed before start.")
			return
		end
		run.State = "Running"
		run.StartClock = os.clock()
		run.LastTouchClock = 0
		fire(player, {
			Type = "TimeTrialStarted",
			EventId = eventId,
			RouteId = route.RouteId,
			DisplayName = run.DisplayName,
			StartServerClock = run.StartClock,
			GateCount = run.GateCount,
			NextGateIndex = 1,
		})
	end)
end

local function startTimeTrial(player, eventId, startZone)
	if activeRuns[player] then
		return false, "Already in a time trial."
	end
	local vehicle, vehicleError = currentVehicleForPlayer(player)
	if not vehicle then
		return false, vehicleError
	end
	local pos = vehiclePosition(vehicle)
	if startZone and pos and not isPointInside(startZone, pos) then
		return false, "Move the vehicle into the start zone."
	end
	local route, routeError = RaceConfigReader.GetRouteForEvent(eventId)
	if not route then
		return false, routeError
	end
	if RouteDefinition.GetGateCount(route) < 2 then
		return false, "Route needs checkpoints and a finish line."
	end
	beginRunAfterCountdown(player, eventId, route, vehicle)
	return true, "Starting time trial."
end

local function eventIdForZone(zone)
	if not zone then return nil end
	local eventId = zone:GetAttribute("EventId")
	if typeof(eventId) == "string" and eventId ~= "" then
		return eventId
	end
	return "shifted_canal_sprint_tt"
end

local function ensurePrompt(zone)
	if not (zone and zone:IsA("BasePart")) then return end
	if tostring(zone:GetAttribute("Mode") or "TimeTrial") ~= "TimeTrial" then return end
	local prompt = zone:FindFirstChild(PROMPT_NAME)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.ActionText = tostring(zone:GetAttribute("PromptActionText") or "Start Time Trial")
		prompt.ObjectText = "Time Trial"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 24
		prompt.RequiresLineOfSight = false
		prompt.Parent = zone
		prompt.Triggered:Connect(function(player)
			local ok, message = startTimeTrial(player, eventIdForZone(zone), zone)
			if not ok then
				fire(player, {
					Type = "TimeTrialError",
					Message = message,
				})
			end
		end)
	end
	prompt.Enabled = zone:GetAttribute("Enabled") ~= false
end

local function ensureAllPrompts()
	local routesRoot = RouteDefinition.GetRoutesRoot()
	if not routesRoot then return end
	for _, route in ipairs(routesRoot:GetChildren()) do
		local startZones = route:FindFirstChild("StartZones")
		if startZones then
			for _, zone in ipairs(startZones:GetChildren()) do
				ensurePrompt(zone)
			end
		end
	end
end

raceRequest.OnServerInvoke = function(player, action, payload)
	if action == "StartTimeTrial" then
		payload = typeof(payload) == "table" and payload or {}
		local eventId = tostring(payload.EventId or "shifted_canal_sprint_tt")
		local ok, message = startTimeTrial(player, eventId, nil)
		return { Ok = ok, Message = message }
	elseif action == "CancelTimeTrial" then
		endRun(player, "Cancelled")
		return { Ok = true, Message = "Cancelled" }
	elseif action == "GetRouteSummary" then
		payload = typeof(payload) == "table" and payload or {}
		local route, routeError = RaceConfigReader.GetRouteForEvent(tostring(payload.EventId or "shifted_canal_sprint_tt"))
		if not route then
			return { Ok = false, Message = routeError }
		end
		return {
			Ok = true,
			RouteId = route.RouteId,
			DisplayName = route.DisplayName,
			GateCount = RouteDefinition.GetGateCount(route),
			CheckpointCount = route.ValidationSummary.CheckpointCount,
			ArrowCount = #(route.ArrowMarkers or {}),
		}
	end
	return { Ok = false, Message = "Unknown racing action." }
end

Players.PlayerRemoving:Connect(function(player)
	activeRuns[player] = nil
end)

ensureAllPrompts()
task.spawn(function()
	while true do
		ensureAllPrompts()
		task.wait(3)
	end
end)

info("Solo time-trial service active.")
]=]

local RACE_CLIENT_SOURCE = [=[
-- Neo Tokyo Racers - Race Entry/HUD/Route Guide Client
-- NTR_RACING_PHASE2_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local racingModules = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Racing")
local RouteDefinition = require(racingModules:WaitForChild("RaceRouteDefinition"))

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_RaceHud"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 76
gui.Enabled = true
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 68)
panel.Size = UDim2.fromOffset(360, 92)
panel.BackgroundColor3 = Color3.fromRGB(6, 10, 13)
panel.BackgroundTransparency = 0.14
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 7)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 255, 190)
stroke.Transparency = 0.22
stroke.Thickness = 1.5
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 22)
title.Text = "TIME TRIAL"
title.TextColor3 = Color3.fromRGB(255, 226, 249)
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
pcall(function()
	title.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
end)
title.Parent = panel

local timer = Instance.new("TextLabel")
timer.Name = "Timer"
timer.BackgroundTransparency = 1
timer.Position = UDim2.fromOffset(12, 34)
timer.Size = UDim2.new(0.5, -12, 0, 28)
timer.Text = "0.000"
timer.TextColor3 = Color3.fromRGB(70, 255, 190)
timer.TextSize = 24
timer.TextXAlignment = Enum.TextXAlignment.Left
timer.Font = Enum.Font.GothamBold
timer.Parent = panel

local progress = Instance.new("TextLabel")
progress.Name = "Progress"
progress.BackgroundTransparency = 1
progress.Position = UDim2.new(0.5, 0, 0, 38)
progress.Size = UDim2.new(0.5, -12, 0, 22)
progress.Text = "CHECKPOINT 1/1"
progress.TextColor3 = Color3.fromRGB(255, 226, 249)
progress.TextSize = 12
progress.TextXAlignment = Enum.TextXAlignment.Right
progress.Font = Enum.Font.GothamBold
progress.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(12, 66)
status.Size = UDim2.new(1, -24, 0, 18)
status.Text = ""
status.TextColor3 = Color3.fromRGB(195, 221, 213)
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Font = Enum.Font.Gotham
status.Parent = panel

local markerRoot = Workspace:FindFirstChild("_NTR_ClientOnly")
if not markerRoot then
	markerRoot = Instance.new("Folder")
	markerRoot.Name = "_NTR_ClientOnly"
	markerRoot.Parent = Workspace
end

local active = nil
local marker = nil
local markerGui = nil
local heartbeatConnection = nil

local function formatTime(seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	return string.format("%.3f", seconds)
end

local function clearMarker()
	if marker then
		marker:Destroy()
		marker = nil
	end
	if markerGui then
		markerGui:Destroy()
		markerGui = nil
	end
end

local function ensureMarker(part, isFinish)
	clearMarker()
	if not (part and part:IsA("BasePart")) then return end
	marker = Instance.new("SelectionBox")
	marker.Name = "RaceNextGateSelection"
	marker.Adornee = part
	marker.Color3 = isFinish and Color3.fromRGB(255, 226, 80) or Color3.fromRGB(70, 255, 190)
	marker.LineThickness = 0.08
	marker.SurfaceTransparency = 0.88
	marker.Parent = markerRoot

	markerGui = Instance.new("BillboardGui")
	markerGui.Name = "RaceNextGateBillboard"
	markerGui.Adornee = part
	markerGui.AlwaysOnTop = true
	markerGui.Size = UDim2.fromOffset(160, 42)
	markerGui.StudsOffset = Vector3.new(0, math.max(7, part.Size.Y * 0.5 + 5), 0)
	markerGui.Parent = markerRoot

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(6, 10, 13)
	label.BackgroundTransparency = 0.16
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Text = isFinish and "FINISH" or "CHECKPOINT"
	label.TextColor3 = isFinish and Color3.fromRGB(255, 226, 80) or Color3.fromRGB(70, 255, 190)
	label.TextStrokeTransparency = 0.2
	label.TextSize = 15
	label.Font = Enum.Font.GothamBold
	label.Parent = markerGui
	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 6)
	labelCorner.Parent = label
end

local function routeForActive()
	if not active then return nil end
	local route, routeError = RouteDefinition.GetRouteDefinition(active.RouteId)
	if not route then
		warn("[NTR Racing Phase 2 Client] " .. tostring(routeError))
	end
	return route
end

local function updateNextGate()
	local route = routeForActive()
	local gate = route and RouteDefinition.GetGate(route, active.NextGateIndex or 1)
	if gate then
		ensureMarker(gate.Part, gate.IsFinish)
		local label = gate.IsFinish and "FINISH" or "CHECKPOINT"
		progress.Text = string.format("%s %d/%d", label, active.NextGateIndex or 1, active.GateCount or 1)
	else
		clearMarker()
	end
end

local function startTicker()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	heartbeatConnection = RunService.Heartbeat:Connect(function()
		if not active or not active.StartLocalClock then return end
		timer.Text = formatTime(os.clock() - active.StartLocalClock)
	end)
end

local function stopTicker()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

local function showError(message)
	panel.Visible = true
	title.Text = "TIME TRIAL"
	timer.Text = "--"
	progress.Text = ""
	status.Text = tostring(message or "Time trial unavailable.")
	task.delay(2.2, function()
		if not active then
			panel.Visible = false
			status.Text = ""
		end
	end)
end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = payload.Type
	if kind == "TimeTrialError" then
		showError(payload.Message)
	elseif kind == "TimeTrialCountdown" then
		active = {
			EventId = payload.EventId,
			RouteId = payload.RouteId,
			DisplayName = payload.DisplayName,
			NextGateIndex = payload.NextGateIndex or 1,
			GateCount = payload.GateCount or 1,
			CountdownUntil = os.clock() + (payload.Countdown or 3),
		}
		panel.Visible = true
		title.Text = tostring(payload.DisplayName or "TIME TRIAL")
		timer.Text = tostring(payload.Countdown or 3)
		status.Text = "GET READY"
		updateNextGate()
		task.spawn(function()
			while active and active.CountdownUntil and os.clock() < active.CountdownUntil do
				timer.Text = tostring(math.max(1, math.ceil(active.CountdownUntil - os.clock())))
				task.wait(0.1)
			end
		end)
	elseif kind == "TimeTrialStarted" then
		active = active or {}
		active.EventId = payload.EventId
		active.RouteId = payload.RouteId
		active.DisplayName = payload.DisplayName
		active.NextGateIndex = payload.NextGateIndex or 1
		active.GateCount = payload.GateCount or 1
		active.StartLocalClock = os.clock()
		active.CountdownUntil = nil
		panel.Visible = true
		title.Text = tostring(payload.DisplayName or "TIME TRIAL")
		status.Text = "RUNNING"
		updateNextGate()
		startTicker()
	elseif kind == "TimeTrialCheckpoint" then
		if not active then return end
		active.NextGateIndex = payload.NextGateIndex or active.NextGateIndex
		active.GateCount = payload.GateCount or active.GateCount
		status.Text = "CHECKPOINT " .. tostring(payload.CheckpointIndex or "")
		updateNextGate()
	elseif kind == "TimeTrialFinished" then
		stopTicker()
		clearMarker()
		active = nil
		panel.Visible = true
		title.Text = tostring(payload.DisplayName or "TIME TRIAL")
		timer.Text = formatTime(payload.Elapsed)
		progress.Text = "FINISHED"
		status.Text = tostring(payload.Message or "Finished")
	elseif kind == "TimeTrialEnded" then
		stopTicker()
		clearMarker()
		active = nil
		panel.Visible = false
	end
end)

print("[NTR Racing Phase 2 Client] Race HUD/guide active.")
]=]

local function install()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local shared = ensureFolder(kit, "Shared")
	local remotes = ensureFolder(shared, "Remotes")
	local racingRemotes = ensureFolder(remotes, "Racing")
	ensureRemote(racingRemotes, "RemoteFunction", "RaceRequest")
	ensureRemote(racingRemotes, "RemoteEvent", "RaceEvent")

	local modules = ensureFolder(shared, "Modules")
	local racingModules = ensureFolder(modules, "Racing")
	ensureScript(racingModules, "ModuleScript", "RaceRouteDefinition", ROUTE_DEFINITION_SOURCE)
	ensureScript(racingModules, "ModuleScript", "RaceConfigReader", CONFIG_READER_SOURCE)

	local serverRoot = ensureFolder(ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"), "Racing")
	ensureScript(serverRoot, "Script", "TimeTrialService_Active", TIME_TRIAL_SERVICE_SOURCE, false)

	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local clientRoot = ensureFolder(playerScripts, "NeoTokyoRacersClient")
	local controllers = ensureFolder(clientRoot, "Controllers")
	local racingClients = ensureFolder(controllers, "Racing")
	ensureScript(racingClients, "LocalScript", "RaceClient_Active", RACE_CLIENT_SOURCE, false)

	local route = Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("RaceRoutes"):FindFirstChild("ShiftedCanalSprint")
	if route and not route:FindFirstChild("ArrowMarkers") then
		local arrows = Instance.new("Folder")
		arrows.Name = "ArrowMarkers"
		arrows.Parent = route
		info("Created empty ArrowMarkers folder for future route guidance assets.")
	end

	info("Installed isolated solo time-trial MVP. Restart Play before testing.")
end

local function audit()
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local racingRemotes = kit and kit:FindFirstChild("Shared") and kit.Shared:FindFirstChild("Remotes") and kit.Shared.Remotes:FindFirstChild("Racing")
	local racingModules = kit and kit:FindFirstChild("Shared") and kit.Shared:FindFirstChild("Modules") and kit.Shared.Modules:FindFirstChild("Racing")
	local serverRoot = ServerScriptService:FindFirstChild("NeoTokyoRacers") and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services") and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Racing")
	local clientRoot = StarterPlayer:FindFirstChild("StarterPlayerScripts")
		and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient:FindFirstChild("Controllers")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers:FindFirstChild("Racing")
	local route = Workspace:FindFirstChild("NeoTokyoRacersWorld")
		and Workspace.NeoTokyoRacersWorld:FindFirstChild("RaceRoutes")
		and Workspace.NeoTokyoRacersWorld.RaceRoutes:FindFirstChild("ShiftedCanalSprint")

	info("Audit:")
	info("  Remotes.Racing=" .. tostring(racingRemotes ~= nil))
	info("  RaceRequest=" .. tostring(racingRemotes and racingRemotes:FindFirstChild("RaceRequest") ~= nil))
	info("  RaceEvent=" .. tostring(racingRemotes and racingRemotes:FindFirstChild("RaceEvent") ~= nil))
	info("  Modules.Racing=" .. tostring(racingModules ~= nil))
	info("  RaceRouteDefinition=" .. tostring(racingModules and racingModules:FindFirstChild("RaceRouteDefinition") ~= nil))
	info("  RaceConfigReader=" .. tostring(racingModules and racingModules:FindFirstChild("RaceConfigReader") ~= nil))
	info("  Server Racing folder=" .. tostring(serverRoot ~= nil))
	info("  TimeTrialService_Active=" .. tostring(serverRoot and serverRoot:FindFirstChild("TimeTrialService_Active") ~= nil))
	info("  Client Racing folder=" .. tostring(clientRoot ~= nil))
	info("  RaceClient_Active=" .. tostring(clientRoot and clientRoot:FindFirstChild("RaceClient_Active") ~= nil))
	info("  ShiftedCanalSprint route=" .. tostring(route ~= nil))
	info("  ArrowMarkers folder=" .. tostring(route and route:FindFirstChild("ArrowMarkers") ~= nil))
	if route and route:FindFirstChild("Checkpoints") then
		info("  Checkpoints=" .. tostring(#route.Checkpoints:GetChildren()))
	end
end

if MODE == "INSTALL" then
	install()
	audit()
elseif MODE == "AUDIT" then
	audit()
else
	error("Unknown MODE: " .. tostring(MODE))
end
