-- Neo Tokyo Racers - Racing Phase 3 Entry Menu, Vehicle Select, Staging
-- Installs the next isolated Racing phase on top of the confirmed Phase 2
-- solo time-trial MVP.
--
-- This script does not patch the register-limited main client bootstrap,
-- garage server source, driving physics, VFX, dealership, or customisation UI.
-- It canonically replaces only the isolated Racing service/client scripts.
--
-- Usage:
--   MODE = "INSTALL" installs the phase.
--   MODE = "AUDIT" checks expected objects without changing anything.

local MODE = "INSTALL" -- "INSTALL" or "AUDIT"
local PHASE = "NTR Racing Phase 3"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
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

local ROUTE_DEFINITION_SOURCE = [==[
-- Neo Tokyo Racers - RaceRouteDefinition
-- NTR_RACING_PHASE3_ROUTE_DEFINITION

local Workspace = game:GetService("Workspace")

local RouteDefinition = {}

local function numberAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	return typeof(value) == "number" and value or fallback
end

local function stringAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	return typeof(value) == "string" and value or fallback
end

local function indexedNameFallback(instance, fallback)
	local text = instance and instance.Name or ""
	local digits = string.match(text, "(%d+)$")
	return digits and tonumber(digits) or fallback
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

local function mediaSummary(route)
	local media = route and route:FindFirstChild("Media")
	local trackImage = stringAttribute(route, "TrackImage", "")
	local mapImage = stringAttribute(route, "MapImage", "")
	if media then
		local trackValue = media:FindFirstChild("TrackImage")
		local mapValue = media:FindFirstChild("MapImage")
		if trackImage == "" and trackValue and trackValue:IsA("StringValue") then
			trackImage = trackValue.Value
		end
		if mapImage == "" and mapValue and mapValue:IsA("StringValue") then
			mapImage = mapValue.Value
		end
	end
	return {
		TrackImage = trackImage,
		MapImage = mapImage,
	}
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
			CFrame = finishPart.CFrame,
			Size = finishPart.Size,
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

	local startZones = collectStartZones(route)
	local spawnGrid = collectSpawnGrid(route)
	return {
		RouteId = stringAttribute(route, "RouteId", tostring(routeId)),
		DisplayName = stringAttribute(route, "DisplayName", tostring(routeId)),
		SourceType = stringAttribute(route, "SourceType", "Official"),
		CreatorUserId = numberAttribute(route, "CreatorUserId", 0),
		Version = numberAttribute(route, "Version", 1),
		Folder = route,
		StartZones = startZones,
		SpawnGrid = spawnGrid,
		Checkpoints = checkpoints,
		FinishLine = finish,
		Gates = orderedGates,
		ArrowMarkers = collectArrowMarkers(route),
		Media = mediaSummary(route),
		ValidationSummary = {
			CheckpointCount = #checkpoints,
			HasFinish = finish ~= nil,
			GateCount = #orderedGates,
			SpawnCount = #spawnGrid,
			StartZoneCount = #startZones,
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

function RouteDefinition.GetFirstSpawnCFrame(routeDefinition)
	local grid = routeDefinition and routeDefinition.SpawnGrid
	if grid and grid[1] and grid[1].Part then
		return grid[1].Part.CFrame
	end
	local zones = routeDefinition and routeDefinition.StartZones
	if zones and zones[1] and zones[1].Part then
		return zones[1].Part.CFrame
	end
	local gate = RouteDefinition.GetGate(routeDefinition, 1)
	if gate and gate.Part then
		return gate.Part.CFrame
	end
	return CFrame.new()
end

return RouteDefinition
]==]

local CONFIG_READER_SOURCE = [==[
-- Neo Tokyo Racers - RaceConfigReader
-- NTR_RACING_PHASE3_CONFIG_READER

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

local function findInCatalog(catalogName, eventId)
	local catalog = racingConfig():FindFirstChild(catalogName)
	local event = catalog and catalog:FindFirstChild(tostring(eventId or ""))
	if not event then
		for _, candidate in ipairs(catalog and catalog:GetChildren() or {}) do
			if stringAttribute(candidate, "EventId", "") == tostring(eventId or "") then
				event = candidate
				break
			end
		end
	end
	return event
end

function Reader.GetTimeTrialEvent(eventId)
	local event = findInCatalog("TimeTrialCatalog", eventId)
	if not event then
		return nil, "Time trial event not found: " .. tostring(eventId)
	end
	return event
end

function Reader.GetRaceEvent(eventId)
	local event = findInCatalog("RaceCatalog", eventId)
	if not event then
		return nil, "Race event not found: " .. tostring(eventId)
	end
	return event
end

function Reader.GetEvent(mode, eventId)
	if tostring(mode or "TimeTrial") == "Race" then
		return Reader.GetRaceEvent(eventId)
	end
	return Reader.GetTimeTrialEvent(eventId)
end

function Reader.GetRouteForEvent(eventId, mode)
	local event, eventError = Reader.GetEvent(mode or "TimeTrial", eventId)
	if not event then
		return nil, eventError
	end
	local routeId = stringAttribute(event, "RouteId", "")
	if routeId == "" then
		return nil, "Event has no RouteId: " .. tostring(eventId)
	end
	return RouteDefinition.GetRouteDefinition(routeId)
end

function Reader.GetEventSummary(eventId, mode)
	local event, eventError = Reader.GetEvent(mode or "TimeTrial", eventId)
	if not event then
		return nil, eventError
	end
	local routeId = stringAttribute(event, "RouteId", "")
	local route = routeId ~= "" and RouteDefinition.GetRouteDefinition(routeId) or nil
	local media = route and route.Media or {}
	return {
		EventId = stringAttribute(event, "EventId", tostring(eventId)),
		DisplayName = stringAttribute(event, "DisplayName", event.Name),
		Mode = stringAttribute(event, "Mode", mode or "TimeTrial"),
		RouteId = routeId,
		RouteDisplayName = route and route.DisplayName or routeId,
		AllowedVehicleTiers = stringAttribute(event, "AllowedVehicleTiers", "E,D,C,B,A,S"),
		RecommendedTier = stringAttribute(event, "RecommendedTier", "D"),
		BaseReward = numberAttribute(event, "BaseReward", 0),
		Laps = numberAttribute(event, "Laps", 1),
		MinPlayers = numberAttribute(event, "MinPlayers", 1),
		MaxPlayers = numberAttribute(event, "MaxPlayers", 1),
		TrackImage = stringAttribute(event, "TrackImage", media.TrackImage or ""),
		MapImage = stringAttribute(event, "MapImage", media.MapImage or ""),
		CheckpointCount = route and route.ValidationSummary.CheckpointCount or 0,
		GateCount = route and RouteDefinition.GetGateCount(route) or 0,
		ArrowCount = route and #(route.ArrowMarkers or {}) or 0,
	}
end

function Reader.GetTimeTrialMedals(eventId, tier)
	local event = Reader.GetTimeTrialEvent(eventId)
	if not event then
		return {}
	end
	tier = string.upper(tostring(tier or "D"))
	return {
		Bronze = numberAttribute(event, tier .. "_BronzeSeconds", numberAttribute(event, "BronzeSeconds", 0)),
		Silver = numberAttribute(event, tier .. "_SilverSeconds", numberAttribute(event, "SilverSeconds", 0)),
		Gold = numberAttribute(event, tier .. "_GoldSeconds", numberAttribute(event, "GoldSeconds", 0)),
		Platinum = numberAttribute(event, tier .. "_PlatinumSeconds", numberAttribute(event, "PlatinumSeconds", 0)),
	}
end

return Reader
]==]

local TIME_TRIAL_SERVICE_SOURCE = [==[
-- Neo Tokyo Racers - Racing Phase 3 Staged Time Trial Service
-- NTR_RACING_PHASE3_TIME_TRIAL_SERVICE

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

local PHASE = "NTR Racing Phase 3"
local OLD_PROMPT_NAME = "NTR_TimeTrialStartPrompt"
local PROMPT_NAME = "NTR_RaceEntryPrompt"
local COUNTDOWN_SECONDS = 3

local activeRuns = {}
local activeRunsById = {}
local gateConnections = {}

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function warnLine(message)
	warn("[" .. PHASE .. "] " .. tostring(message))
end

local function worldRoot()
	return Workspace:FindFirstChild("NeoTokyoRacersWorld")
end

local function runtimeVehiclesRoot()
	local world = worldRoot()
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

local function raceInstancesRoot()
	local world = worldRoot()
	if not world then return nil end
	local root = world:FindFirstChild("RaceInstances")
	if not root then
		root = Instance.new("Folder")
		root.Name = "RaceInstances"
		root.Parent = world
	end
	return root
end

local function vehicleRootPart(vehicle)
	if not vehicle then return nil end
	local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function vehicleSeat(vehicle)
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	if seat and seat:IsA("VehicleSeat") then
		return seat
	end
	for _, descendant in ipairs(vehicle and vehicle:GetDescendants() or {}) do
		if descendant:IsA("VehicleSeat") then
			return descendant
		end
	end
	return nil
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
		return nil, "Choose/spawn a vehicle first."
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
	local root = vehicleRootPart(vehicle)
	return root and root.Position or nil
end

local function fire(player, payload)
	raceEvent:FireClient(player, payload)
end

local function fireVisibility(run, active)
	local participants = {}
	if run and run.Player then
		table.insert(participants, run.Player.UserId)
	end
	raceEvent:FireAllClients({
		Type = "RaceVisibilityUpdate",
		Active = active == true,
		RunId = run and run.RunId or "",
		Participants = participants,
	})
end

local function createSessionFolder(run)
	local root = raceInstancesRoot()
	if not root then return nil end
	local existing = root:FindFirstChild(run.RunId)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = run.RunId
	folder:SetAttribute("EventId", run.EventId)
	folder:SetAttribute("RouteId", run.RouteId)
	folder:SetAttribute("Mode", "TimeTrial")
	folder:SetAttribute("OwnerUserId", run.Player.UserId)
	folder.Parent = root
	local assets = Instance.new("Folder")
	assets.Name = "SessionAssets"
	assets.Parent = folder
	return folder
end

local function clearSessionFolder(run)
	local folder = run and run.SessionFolder
	if folder and folder.Parent then
		folder:Destroy()
	end
end

local function setVehicleFrozen(vehicle, frozen)
	local root = vehicleRootPart(vehicle)
	if not root then return end
	for _, descendant in ipairs(vehicle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
	vehicle:SetAttribute("NTR_RaceFrozen", frozen == true)
	vehicle:SetAttribute("DriveReady", frozen ~= true)
	root.Anchored = frozen == true
end

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

local function stageVehicle(player, vehicle, route)
	local root = vehicleRootPart(vehicle)
	if not root then
		return false, "Vehicle root missing."
	end
	local stageCFrame = RouteDefinition.GetFirstSpawnCFrame(route)
	vehicle.PrimaryPart = root
	vehicle:PivotTo(stageCFrame + Vector3.new(0, 4, 0))
	vehicle:SetAttribute("ParkedShowcase", nil)
	vehicle:SetAttribute("DriverUserId", player.UserId)
	seatPlayer(player, vehicle)
	task.wait(0.08)
	setVehicleFrozen(vehicle, true)
	return true
end

local function endRun(player, reason)
	local run = activeRuns[player]
	if not run then return end
	activeRuns[player] = nil
	activeRunsById[run.RunId] = nil
	if run.Vehicle then
		setVehicleFrozen(run.Vehicle, false)
		run.Vehicle:SetAttribute("NTR_RaceRunId", nil)
		run.Vehicle:SetAttribute("NTR_RaceParticipant", nil)
		run.Vehicle:SetAttribute("NTR_RaceMode", nil)
	end
	fireVisibility(run, false)
	clearSessionFolder(run)
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
	activeRunsById[run.RunId] = nil
	if run.Vehicle then
		setVehicleFrozen(run.Vehicle, false)
		run.Vehicle:SetAttribute("NTR_RaceRunId", nil)
		run.Vehicle:SetAttribute("NTR_RaceParticipant", nil)
		run.Vehicle:SetAttribute("NTR_RaceMode", nil)
		run.Vehicle:SetAttribute("DriveReady", true)
	end
	fireVisibility(run, false)
	clearSessionFolder(run)
	fire(player, {
		Type = "TimeTrialFinished",
		EventId = run.EventId,
		RouteId = run.RouteId,
		DisplayName = run.DisplayName,
		Elapsed = elapsed,
		GateCount = run.GateCount,
		Message = "Finished. Medals/rewards come next.",
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
		if gate.Part and not gateConnections[gate.Part] then
			gate.Part.CanTouch = true
			gate.Part.CanQuery = true
			gate.Part.CanCollide = false
			gateConnections[gate.Part] = gate.Part.Touched:Connect(function(hit)
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

local function resolveTimeTrialEventId(eventId)
	-- NTR_RACING_PHASE3D_EVENT_PAIRING
	eventId = tostring(eventId or "shifted_canal_sprint_tt")
	local direct = RaceConfigReader.GetTimeTrialEvent(eventId)
	if direct then
		return eventId
	end

	local raceSummary = RaceConfigReader.GetEventSummary(eventId, "Race")
	local raceRouteId = raceSummary and raceSummary.RouteId or ""
	local config = kit:FindFirstChild("Config")
	local racing = config and config:FindFirstChild("Racing")
	local catalog = racing and racing:FindFirstChild("TimeTrialCatalog")
	if raceRouteId ~= "" and catalog then
		for _, candidate in ipairs(catalog:GetChildren()) do
			local routeId = tostring(candidate:GetAttribute("RouteId") or "")
			if routeId == raceRouteId then
				local paired = tostring(candidate:GetAttribute("EventId") or candidate.Name)
				if paired ~= "" then
					return paired
				end
			end
		end
	end

	if eventId:sub(-5) == "_race" then
		return eventId:sub(1, -6) .. "_tt"
	end
	return "shifted_canal_sprint_tt"
end

local function beginStagedTimeTrial(player, eventId, vehicleId)
	eventId = resolveTimeTrialEventId(eventId)
	if activeRuns[player] then
		return false, "Already in a race/time trial."
	end
	local vehicle, vehicleError = currentVehicleForPlayer(player)
	if not vehicle then
		return false, vehicleError
	end
	local route, routeError = RaceConfigReader.GetRouteForEvent(eventId, "TimeTrial")
	if not route then
		return false, routeError
	end
	if RouteDefinition.GetGateCount(route) < 2 then
		return false, "Route needs checkpoints and a finish line."
	end
	local summary = RaceConfigReader.GetEventSummary(eventId, "TimeTrial") or {}
	local tier = tostring(vehicle:GetAttribute("PerformanceTier") or "")
	local index = tonumber(vehicle:GetAttribute("PerformanceIndex")) or tonumber(vehicle:GetAttribute("PerformanceScore")) or 0
	local runId = "TT_" .. tostring(player.UserId) .. "_" .. tostring(math.floor(os.clock() * 1000))
	local run = {
		State = "Staging",
		RunId = runId,
		Player = player,
		EventId = eventId,
		RouteId = route.RouteId,
		DisplayName = summary.DisplayName or route.DisplayName,
		Route = route,
		Vehicle = vehicle,
		SelectedVehicleId = tostring(vehicleId or ""),
		VehicleTier = tier,
		VehicleIndex = index,
		NextGateIndex = 1,
		GateCount = RouteDefinition.GetGateCount(route),
	}
	activeRuns[player] = run
	activeRunsById[runId] = run
	run.SessionFolder = createSessionFolder(run)
	vehicle:SetAttribute("NTR_RaceRunId", runId)
	vehicle:SetAttribute("NTR_RaceParticipant", true)
	vehicle:SetAttribute("NTR_RaceMode", "TimeTrial")

	local staged, stageError = stageVehicle(player, vehicle, route)
	if not staged then
		endRun(player, stageError)
		return false, stageError
	end

	connectRouteTouches(route)
	fireVisibility(run, true)
	fire(player, {
		Type = "TimeTrialStaged",
		RunId = runId,
		EventId = eventId,
		RouteId = route.RouteId,
		DisplayName = run.DisplayName,
		Countdown = COUNTDOWN_SECONDS,
		GateCount = run.GateCount,
		NextGateIndex = 1,
		VehicleTier = tier,
		VehicleIndex = index,
		Medals = RaceConfigReader.GetTimeTrialMedals(eventId, tier),
	})

	task.spawn(function()
		for seconds = COUNTDOWN_SECONDS, 1, -1 do
			local live = activeRuns[player]
			if not (live and live.RunId == runId and live.State == "Staging") then return end
			fire(player, {
				Type = "TimeTrialCountdown",
				RunId = runId,
				EventId = eventId,
				RouteId = route.RouteId,
				DisplayName = run.DisplayName,
				Countdown = seconds,
				GateCount = run.GateCount,
				NextGateIndex = 1,
			})
			task.wait(1)
		end
		local live = activeRuns[player]
		if not (live and live.RunId == runId and live.State == "Staging") then return end
		local currentVehicle, currentError = currentVehicleForPlayer(player)
		if currentVehicle ~= vehicle then
			endRun(player, currentError or "Vehicle changed before start.")
			return
		end
		live.State = "Running"
		live.StartClock = os.clock()
		live.LastTouchClock = 0
		prepareVehicleForDriving(player, vehicle)
		fire(player, {
			Type = "TimeTrialStarted",
			RunId = runId,
			EventId = eventId,
			RouteId = route.RouteId,
			DisplayName = run.DisplayName,
			StartServerClock = live.StartClock,
			GateCount = run.GateCount,
			NextGateIndex = 1,
		})
	end)

	return true, "Staging time trial."
end

local function eventIdForZone(zone)
	if not zone then return "shifted_canal_sprint_tt" end
	local eventId = zone:GetAttribute("EventId")
	if typeof(eventId) == "string" and eventId ~= "" then
		return eventId
	end
	if tostring(zone:GetAttribute("Mode") or "TimeTrial") == "Race" then
		return "shifted_canal_sprint_race"
	end
	return "shifted_canal_sprint_tt"
end

local function modeForZone(zone)
	local mode = tostring(zone and zone:GetAttribute("Mode") or "TimeTrial")
	if mode == "Race" then return "Race" end
	return "TimeTrial"
end

local function sendEntryMenu(player, zone)
	local mode = modeForZone(zone)
	local eventId = eventIdForZone(zone)
	local summary = RaceConfigReader.GetEventSummary(eventId, mode)
	local pos = nil
	local vehicle = currentVehicleForPlayer(player)
	if vehicle then
		pos = vehiclePosition(vehicle)
	end
	if zone and pos and not isPointInside(zone, pos) then
		fire(player, {
			Type = "TimeTrialError",
			Message = "Move the vehicle into the start zone.",
		})
		return
	end
	fire(player, {
		Type = "OpenRaceEntry",
		EventId = eventId,
		TimeTrialEventId = resolveTimeTrialEventId(eventId),
		Mode = mode,
		Summary = summary,
		Message = mode == "Race" and "Race matchmaking is coming soon. Time trial is available now." or "",
	})
end

local function ensurePrompt(zone, forceRecreate)
	-- NTR_RACING_PHASE3B_PROMPT_REPAIR
	if not (zone and zone:IsA("BasePart")) then return end
	local oldPrompt = zone:FindFirstChild(OLD_PROMPT_NAME)
	if oldPrompt then
		oldPrompt:Destroy()
	end
	local mode = modeForZone(zone)
	local prompt = zone:FindFirstChild(PROMPT_NAME)
	if prompt and forceRecreate == true then
		prompt:Destroy()
		prompt = nil
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 24
		prompt.RequiresLineOfSight = false
		prompt.Parent = zone
		prompt.Triggered:Connect(function(player)
			info("Race entry prompt triggered by " .. player.Name .. " at " .. zone:GetFullName())
			sendEntryMenu(player, zone)
		end)
	end
	prompt.ActionText = "Open Race Menu"
	prompt.ObjectText = mode == "Race" and "Race" or "Time Trial"
	prompt.Enabled = zone:GetAttribute("Enabled") ~= false
end

local function ensureAllPrompts(forceRecreate)
	local routesRoot = RouteDefinition.GetRoutesRoot()
	if not routesRoot then return end
	for _, route in ipairs(routesRoot:GetChildren()) do
		local startZones = route:FindFirstChild("StartZones")
		if startZones then
			for _, zone in ipairs(startZones:GetChildren()) do
				ensurePrompt(zone, forceRecreate)
			end
		end
	end
end

raceRequest.OnServerInvoke = function(player, action, payload)
	payload = typeof(payload) == "table" and payload or {}
	if action == "GetEntryDetails" then
		local mode = tostring(payload.Mode or "TimeTrial")
		local eventId = tostring(payload.EventId or (mode == "Race" and "shifted_canal_sprint_race" or "shifted_canal_sprint_tt"))
		local summary, summaryError = RaceConfigReader.GetEventSummary(eventId, mode)
		if not summary then
			return { Ok = false, Message = summaryError or "Event unavailable." }
		end
		return { Ok = true, Summary = summary }
	elseif action == "StartStagedTimeTrial" then
		local eventId = tostring(payload.EventId or "shifted_canal_sprint_tt")
		local ok, message = beginStagedTimeTrial(player, eventId, payload.VehicleId)
		return { Ok = ok, Success = ok, Message = message }
	elseif action == "StartTimeTrial" then
		local eventId = tostring(payload.EventId or "shifted_canal_sprint_tt")
		local ok, message = beginStagedTimeTrial(player, eventId, payload.VehicleId)
		return { Ok = ok, Success = ok, Message = message }
	elseif action == "CancelTimeTrial" then
		endRun(player, "Cancelled")
		return { Ok = true, Success = true, Message = "Cancelled" }
	elseif action == "GetRouteSummary" then
		local route, routeError = RaceConfigReader.GetRouteForEvent(tostring(payload.EventId or "shifted_canal_sprint_tt"), "TimeTrial")
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
	endRun(player, "Player left")
end)

ensureAllPrompts(true)
task.spawn(function()
	while true do
		ensureAllPrompts(false)
		task.wait(3)
	end
end)

info("Entry menu/staged time-trial service active.")
]==]

local RACE_ENTRY_CLIENT_SOURCE = [==[
-- Neo Tokyo Racers - Racing Phase 3 Entry Menu, Vehicle Select, HUD
-- NTR_RACING_PHASE3_ENTRY_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local remotes = shared:WaitForChild("Remotes")
local racingRemotes = remotes:WaitForChild("Racing")
local raceRequest = racingRemotes:WaitForChild("RaceRequest")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local garageInvoke = nil
local racingModules = shared:WaitForChild("Modules"):WaitForChild("Racing")
local RouteDefinition = require(racingModules:WaitForChild("RaceRouteDefinition"))

print("[NTR Racing Phase 3 Client] booted " .. script:GetFullName())

local function getGarageInvoke()
	-- NTR_RACING_PHASE3C_CLIENT_EVENT_REPAIR
	if garageInvoke and garageInvoke.Parent then
		return garageInvoke
	end
	local garageRemotes = remotes:FindFirstChild("Garage") or remotes:WaitForChild("Garage", 5)
	if not garageRemotes then
		warn("[NTR Racing Phase 3 Client] Garage remotes missing; vehicle picker will wait until garage is ready.")
		return nil
	end
	garageInvoke = garageRemotes:FindFirstChild("GarageInvoke") or garageRemotes:WaitForChild("GarageInvoke", 5)
	if not garageInvoke then
		warn("[NTR Racing Phase 3 Client] GarageInvoke missing; vehicle picker cannot load yet.")
	end
	return garageInvoke
end

local touch = UserInputService.TouchEnabled
local state = {
	Entry = nil,
	Profile = nil,
	Catalog = nil,
	SelectedRow = nil,
	ActiveRun = nil,
	Visibility = nil,
}

local function themeFolder()
	local config = kit:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	return ui and ui:FindFirstChild("Theme")
end

local function themeColor(name, fallback)
	local folder = themeFolder()
	local value = folder and folder:FindFirstChild(name)
	if value and value:IsA("Color3Value") then
		return value.Value
	end
	return fallback
end

local theme = {
	Panel = themeColor("Panel", Color3.fromRGB(6, 10, 13)),
	Card = themeColor("Card", Color3.fromRGB(14, 20, 26)),
	CardHot = themeColor("CardHot", Color3.fromRGB(31, 52, 54)),
	Text = themeColor("Text", Color3.fromRGB(240, 255, 249)),
	Muted = themeColor("Muted", Color3.fromRGB(145, 170, 165)),
	Accent = themeColor("Accent", Color3.fromRGB(70, 255, 190)),
	Selected = themeColor("Selected", Color3.fromRGB(255, 68, 196)),
	Buy = themeColor("Buy", Color3.fromRGB(35, 200, 125)),
	Exit = themeColor("Exit", Color3.fromRGB(230, 74, 116)),
}

local function applyFont(label, bold)
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	end)
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 7)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or theme.Accent
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.25
	s.Parent = parent
	return s
end

local function label(parent, text, size, position, textSize, color, bold)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Size = size
	item.Position = position
	item.Text = text or ""
	item.TextColor3 = color or theme.Text
	item.TextSize = textSize or 13
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	applyFont(item, bold)
	item.Parent = parent
	return item
end

local function button(parent, text, size, position, color)
	local item = Instance.new("TextButton")
	item.AutoButtonColor = true
	item.BorderSizePixel = 0
	item.Size = size
	item.Position = position
	item.Text = text or ""
	item.TextColor3 = Color3.fromRGB(245, 255, 250)
	item.TextSize = touch and 11 or 13
	item.TextWrapped = true
	item.BackgroundColor3 = color or theme.Card
	applyFont(item, true)
	item.Parent = parent
	corner(item, 6)
	stroke(item, theme.Accent, 1, 0.45)
	return item
end

local function callGarage(action, payload)
	local invoke = getGarageInvoke()
	if not invoke then
		return { Success = false, Ok = false, Message = "Garage is still loading.", Error = "GarageInvoke missing" }
	end
	local ok, result = pcall(function()
		return invoke:InvokeServer(action, payload or {})
	end)
	if ok and type(result) == "table" then
		return result
	end
	return { Success = false, Ok = false, Message = tostring(result), Error = tostring(result) }
end

local function callRace(action, payload)
	local ok, result = pcall(function()
		return raceRequest:InvokeServer(action, payload or {})
	end)
	if ok and type(result) == "table" then
		return result
	end
	return { Success = false, Ok = false, Message = tostring(result), Error = tostring(result) }
end

local function refreshProfile()
	local result = callGarage("GetInitial", {})
	state.Profile = result.Profile or result
	state.Catalog = result.Catalog or state.Catalog
	return state.Profile
end

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_RaceEntry"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 78
gui.Enabled = true
gui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.32
overlay.BorderSizePixel = 0
overlay.Size = UDim2.fromScale(1, 1)
overlay.Visible = false
overlay.Parent = gui

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.52)
root.Size = touch and UDim2.new(0.94, 0, 0.76, 0) or UDim2.fromOffset(860, 560)
root.BackgroundColor3 = theme.Panel
root.BackgroundTransparency = 0.08
root.BorderSizePixel = 0
root.Visible = false
root.Parent = overlay
corner(root, 8)
stroke(root, theme.Accent, 1.5, 0.2)

local title = label(root, "RACE MENU", UDim2.new(1, -28, 0, 34), UDim2.fromOffset(14, 12), touch and 15 or 18, theme.Text, true)
local subtitle = label(root, "", UDim2.new(1, -28, 0, 24), UDim2.fromOffset(14, 45), touch and 10 or 12, theme.Muted, false)

local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(14, 82)
content.Size = UDim2.new(1, -28, 1, -154)
content.Parent = root

local actionRail = Instance.new("Frame")
actionRail.Name = "ActionRail"
actionRail.BackgroundTransparency = 1
actionRail.Position = UDim2.new(0, 14, 1, -58)
actionRail.Size = UDim2.new(1, -28, 0, 44)
actionRail.Parent = root

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		child:Destroy()
	end
	for _, child in ipairs(actionRail:GetChildren()) do
		child:Destroy()
	end
end

local function setOpen(open)
	overlay.Visible = open
	root.Visible = open
end

local function statusText(text, good)
	subtitle.Text = text or ""
	subtitle.TextColor3 = good and theme.Accent or theme.Muted
end

local function tierColor(tier)
	tier = string.upper(tostring(tier or ""))
	if tier == "S" then return Color3.fromRGB(224, 78, 255) end
	if tier == "A" then return Color3.fromRGB(178, 92, 255) end
	if tier == "B" then return Color3.fromRGB(79, 139, 238) end
	if tier == "C" then return Color3.fromRGB(71, 195, 202) end
	if tier == "D" then return Color3.fromRGB(93, 202, 126) end
	if tier == "E" then return Color3.fromRGB(145, 162, 171) end
	return theme.Accent
end

local function cockpitIdForVehicle(profile, vehicle)
	if not vehicle then return "" end
	if vehicle.CockpitId then return tostring(vehicle.CockpitId) end
	local cockpitInstance = vehicle.CockpitInstanceId and profile and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
	return cockpitInstance and tostring(cockpitInstance.TemplateId or "") or ""
end

local function catalogCockpit(cockpitId)
	for _, category in ipairs((state.Catalog and state.Catalog.Categories) or {}) do
		for _, cockpit in ipairs((category and category.Cockpits) or {}) do
			if tostring(cockpit.CockpitId or cockpit.Id or "") == tostring(cockpitId) then
				return cockpit
			end
		end
	end
	return nil
end

local function cockpitName(cockpitId, cockpit)
	return tostring((cockpit and (cockpit.DisplayName or cockpit.Name)) or cockpitId or "Vehicle")
end

local function cockpitImage(cockpitId, cockpit)
	local image = cockpit and (cockpit.MenuImage or cockpit.Image or cockpit.Icon or cockpit.Thumbnail)
	if typeof(image) == "string" and image ~= "" then
		return image
	end
	local assets = kit:FindFirstChild("Assets")
	local vehicles = assets and assets:FindFirstChild("Vehicles")
	local categories = vehicles and vehicles:FindFirstChild("Categories")
	for _, category in ipairs(categories and categories:GetChildren() or {}) do
		local cockpitRoot = category:FindFirstChild("COCKPITS_ReplaceAssetsHere")
		for _, model in ipairs(cockpitRoot and cockpitRoot:GetChildren() or {}) do
			if model:IsA("Model") and (model.Name == cockpitId or tostring(model:GetAttribute("CockpitId") or "") == cockpitId) then
				local attr = model:GetAttribute("MenuImage")
				if typeof(attr) == "string" and attr ~= "" then return attr end
			end
		end
	end
	return ""
end

local function vehicleRatingParts(profile, vehicleId)
	local summary = profile and profile.VehicleSummaries and profile.VehicleSummaries[vehicleId]
	local overall = summary and summary.Overall or {}
	local tier = tostring(overall.Tier or "--")
	local index = tonumber(overall.PerformanceIndex)
	return tier, (index and tostring(math.floor(index)) or "---"), index or -math.huge
end

local function timeTrialEventIdForStart()
	-- NTR_RACING_PHASE3D_CLIENT_PAIRING
	local entry = state.Entry or {}
	local paired = tostring(entry.TimeTrialEventId or "")
	if paired ~= "" then
		return paired
	end
	local eventId = tostring(entry.EventId or "shifted_canal_sprint_tt")
	if eventId:sub(-5) == "_race" then
		return eventId:sub(1, -6) .. "_tt"
	end
	return eventId ~= "" and eventId or "shifted_canal_sprint_tt"
end

local function ownedRows()
	local profile = refreshProfile() or {}
	local rows = {}
	for vehicleId, vehicle in pairs((profile and profile.Vehicles) or {}) do
		local cockpitId = cockpitIdForVehicle(profile, vehicle)
		if cockpitId ~= "" then
			local cockpit = catalogCockpit(cockpitId)
			local tier, ratingIndex, sortRating = vehicleRatingParts(profile, vehicleId)
			table.insert(rows, {
				VehicleId = tostring(vehicleId),
				CockpitId = cockpitId,
				Cockpit = cockpit,
				Name = cockpitName(cockpitId, cockpit),
				Image = cockpitImage(cockpitId, cockpit),
				Tier = tier,
				RatingIndex = ratingIndex,
				SortRating = sortRating,
				Selected = tostring(vehicleId) == tostring(profile and profile.CurrentVehicleId or ""),
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.SortRating ~= b.SortRating then
			return a.SortRating > b.SortRating
		end
		if a.Name == b.Name then
			return a.VehicleId < b.VehicleId
		end
		return a.Name < b.Name
	end)
	return rows
end

local function placeholder(parent, text)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(10, 15, 20)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 6)
	stroke(frame, theme.Selected, 1, 0.4)
	local t = label(frame, text, UDim2.new(1, -16, 1, -16), UDim2.fromOffset(8, 8), touch and 11 or 13, theme.Muted, true)
	t.TextXAlignment = Enum.TextXAlignment.Center
	return frame
end

local function imageOrPlaceholder(parent, image, text)
	local holder = placeholder(parent, text)
	if typeof(image) == "string" and image ~= "" then
		local imageLabel = Instance.new("ImageLabel")
		imageLabel.BackgroundTransparency = 1
		imageLabel.BorderSizePixel = 0
		imageLabel.Size = UDim2.new(1, -10, 1, -10)
		imageLabel.Position = UDim2.fromOffset(5, 5)
		imageLabel.ScaleType = Enum.ScaleType.Fit
		imageLabel.Image = image
		imageLabel.Parent = holder
	end
	return holder
end

local showEntry

local function showVehicleSelect(mode)
	clearContent()
	state.SelectedRow = nil
	title.Text = mode == "Race" and "CHOOSE RACE VEHICLE" or "CHOOSE TIME TRIAL VEHICLE"
	statusText("Pick one of your owned vehicles. The server will validate it before staging.", true)

	local rows = ownedRows()
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.Parent = content

	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.CellSize = touch and UDim2.fromOffset(146, 184) or UDim2.fromOffset(182, 222)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	if #rows == 0 then
		local empty = label(scroll, "No owned vehicles found yet.", UDim2.fromOffset(420, 40), UDim2.fromOffset(0, 0), 14, theme.Muted, true)
		empty.LayoutOrder = 1
	end

	local function redrawSelection()
		for _, card in ipairs(scroll:GetChildren()) do
			if card:IsA("TextButton") then
				local selected = state.SelectedRow and card:GetAttribute("VehicleId") == state.SelectedRow.VehicleId
				card.BackgroundColor3 = selected and theme.CardHot or theme.Card
				local s = card:FindFirstChildOfClass("UIStroke")
				if s then
					s.Color = selected and theme.Selected or theme.Accent
					s.Transparency = selected and 0.05 or 0.35
				end
			end
		end
	end

	for index, row in ipairs(rows) do
		local card = Instance.new("TextButton")
		card.Name = "Vehicle_" .. row.VehicleId
		card.LayoutOrder = index
		card.Text = ""
		card.AutoButtonColor = true
		card.BorderSizePixel = 0
		card.BackgroundColor3 = row.Selected and theme.CardHot or theme.Card
		card:SetAttribute("VehicleId", row.VehicleId)
		card:SetAttribute("CockpitId", row.CockpitId)
		card.Parent = scroll
		corner(card, 6)
		stroke(card, row.Selected and theme.Selected or theme.Accent, 1.2, row.Selected and 0.05 or 0.35)

		local imageBox = Instance.new("Frame")
		imageBox.BackgroundColor3 = Color3.fromRGB(8, 12, 17)
		imageBox.BorderSizePixel = 0
		imageBox.Position = UDim2.fromOffset(10, 10)
		imageBox.Size = UDim2.new(1, -20, 0, touch and 104 or 136)
		imageBox.Parent = card
		corner(imageBox, 5)
		if row.Image ~= "" then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.new(1, -8, 1, -8)
			img.Position = UDim2.fromOffset(4, 4)
			img.ScaleType = Enum.ScaleType.Fit
			img.Image = row.Image
			img.Parent = imageBox
		else
			local p = label(imageBox, "NO IMAGE", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 11, theme.Muted, true)
			p.TextXAlignment = Enum.TextXAlignment.Center
		end

		local badge = Instance.new("Frame")
		badge.BackgroundColor3 = tierColor(row.Tier)
		badge.BorderSizePixel = 0
		badge.Position = UDim2.new(1, touch and -74 or -86, 0, 16)
		badge.Size = touch and UDim2.fromOffset(58, 18) or UDim2.fromOffset(70, 22)
		badge.Parent = card
		corner(badge, 4)
		local badgeText = label(badge, row.Tier .. " " .. row.RatingIndex, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), touch and 8 or 9, Color3.fromRGB(255, 255, 255), true)
		badgeText.TextXAlignment = Enum.TextXAlignment.Center

		label(card, row.Name, UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, touch and 120 or 154), touch and 10 or 12, theme.Text, true)
		label(card, row.CockpitId, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, touch and 154 or 190), touch and 9 or 10, theme.Muted, false)

		card.MouseButton1Click:Connect(function()
			state.SelectedRow = row
			redrawSelection()
			statusText("Selected " .. row.Name .. " (" .. row.Tier .. " " .. row.RatingIndex .. ")", true)
		end)
		if row.Selected and not state.SelectedRow then
			state.SelectedRow = row
		end
	end
	redrawSelection()

	local back = button(actionRail, "BACK", UDim2.new(0.25, -8, 1, 0), UDim2.fromScale(0, 0), theme.Card)
	local start = button(actionRail, mode == "Race" and "START RACE" or "START TIME TRIAL", UDim2.new(0.5, -8, 1, 0), UDim2.new(0.25, 4, 0, 0), theme.Buy)
	local exit = button(actionRail, "EXIT", UDim2.new(0.25, -8, 1, 0), UDim2.new(0.75, 8, 0, 0), theme.Exit)

	back.MouseButton1Click:Connect(function()
		if state.Entry then
			showEntry({ Type = "OpenRaceEntry", EventId = state.Entry.EventId, Mode = mode, Summary = state.Entry.Summary })
		end
	end)
	exit.MouseButton1Click:Connect(function()
		setOpen(false)
	end)
	start.MouseButton1Click:Connect(function()
		if mode == "Race" then
			statusText("Multiplayer matchmaking is coming after the time-trial entry flow is stable.", false)
			return
		end
		local row = state.SelectedRow
		if not row then
			statusText("Choose a vehicle first.", false)
			return
		end
		local timeTrialEventId = timeTrialEventIdForStart()
		local eventCheck = callRace("GetEntryDetails", {
			EventId = timeTrialEventId,
			Mode = "TimeTrial",
		})
		if eventCheck.Ok ~= true and eventCheck.Success ~= true then
			statusText(eventCheck.Message or "Time trial event is not available.", false)
			return
		end
		statusText("Spawning selected vehicle...", true)
		local spawn = callGarage("SpawnOwnedVehicleFromFreeRoam", {
			VehicleId = row.VehicleId,
			CockpitId = row.CockpitId,
		})
		if spawn.Success ~= true and spawn.Ok ~= true then
			local selectResult = callGarage("SelectVehicleInstance", {
				VehicleId = row.VehicleId,
				CockpitId = row.CockpitId,
			})
			if selectResult.Success ~= true and selectResult.Ok ~= true then
				statusText(selectResult.Message or selectResult.Error or spawn.Message or "Could not select vehicle.", false)
				return
			end
			spawn = callGarage("SpawnVehicle", {})
			if spawn.Success ~= true and spawn.Ok ~= true then
				statusText(spawn.Message or spawn.Error or "Could not spawn selected vehicle.", false)
				return
			end
		end
		local clientRoot = script.Parent.Parent
		local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
		local spawnedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleSpawned")
		if spawnedEvent and spawnedEvent:IsA("BindableEvent") then
			spawnedEvent:Fire()
		end
		task.wait(0.35)
		statusText("Staging at start line...", true)
		local startResult = callRace("StartStagedTimeTrial", {
			EventId = timeTrialEventId,
			VehicleId = row.VehicleId,
		})
		if startResult.Ok ~= true and startResult.Success ~= true then
			statusText(startResult.Message or "Could not start time trial.", false)
			return
		end
		setOpen(false)
	end)
end

function showEntry(payload)
	clearContent()
	local summary = payload.Summary or {}
	state.Entry = {
		EventId = payload.EventId or summary.EventId or "shifted_canal_sprint_tt",
		TimeTrialEventId = payload.TimeTrialEventId,
		Mode = payload.Mode or summary.Mode or "TimeTrial",
		Summary = summary,
	}
	title.Text = tostring(summary.DisplayName or "RACE MENU")
	statusText(payload.Message or "Review the track, then choose a mode.", true)

	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(0.48, -8, 1, 0)
	left.Parent = content
	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(0.48, 8, 0, 0)
	right.Size = UDim2.new(0.52, -8, 1, 0)
	right.Parent = content

	local track = imageOrPlaceholder(left, summary.TrackImage, "TRACK IMAGE")
	track.Size = UDim2.new(1, 0, 0.55, -6)
	track.Position = UDim2.fromScale(0, 0)
	local map = imageOrPlaceholder(left, summary.MapImage, "TRACK MAP")
	map.Size = UDim2.new(1, 0, 0.45, -6)
	map.Position = UDim2.new(0, 0, 0.55, 6)

	label(right, tostring(summary.RouteDisplayName or summary.RouteId or "Route"), UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 0), touch and 14 or 18, theme.Text, true)
	label(right, "Recommended tier: " .. tostring(summary.RecommendedTier or "--"), UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 42), touch and 11 or 13, theme.Accent, true)
	label(right, "Allowed tiers: " .. tostring(summary.AllowedVehicleTiers or "All"), UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 72), touch and 10 or 12, theme.Muted, false)
	label(right, "Checkpoints: " .. tostring(summary.CheckpointCount or 0) .. "   Route gates: " .. tostring(summary.GateCount or 0), UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 102), touch and 10 or 12, theme.Muted, false)
	label(right, "Base reward: $" .. tostring(summary.BaseReward or 0), UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 132), touch and 10 or 12, theme.Muted, false)
	label(right, "Time trials are solo and staged away from free-roam clutter. Multiplayer race matchmaking will use the same menu after the solo flow is stable.", UDim2.new(1, 0, 0, 120), UDim2.fromOffset(0, 176), touch and 10 or 12, theme.Text, false)

	local startRace = button(actionRail, "START RACE", UDim2.new(0.333, -8, 1, 0), UDim2.fromScale(0, 0), theme.Card)
	local startTT = button(actionRail, "START TIME TRIAL", UDim2.new(0.334, -8, 1, 0), UDim2.new(0.333, 4, 0, 0), theme.Buy)
	local exit = button(actionRail, "EXIT", UDim2.new(0.333, -8, 1, 0), UDim2.new(0.667, 8, 0, 0), theme.Exit)

	startRace.MouseButton1Click:Connect(function()
		statusText("Race matchmaking is coming next. Time trial is available now.", false)
	end)
	startTT.MouseButton1Click:Connect(function()
		showVehicleSelect("TimeTrial")
	end)
	exit.MouseButton1Click:Connect(function()
		setOpen(false)
	end)

	setOpen(true)
end

local hudGui = Instance.new("ScreenGui")
hudGui.Name = "NTR_RaceHud_Phase3"
hudGui.IgnoreGuiInset = true
hudGui.ResetOnSpawn = false
hudGui.DisplayOrder = 76
hudGui.Enabled = true
hudGui.Parent = playerGui

local hud = Instance.new("Frame")
hud.Name = "Panel"
hud.AnchorPoint = Vector2.new(0.5, 0)
hud.Position = UDim2.new(0.5, 0, 0, 68)
hud.Size = UDim2.fromOffset(380, 98)
hud.BackgroundColor3 = theme.Panel
hud.BackgroundTransparency = 0.12
hud.BorderSizePixel = 0
hud.Visible = false
hud.Parent = hudGui
corner(hud, 7)
stroke(hud, theme.Accent, 1.5, 0.22)

local hudTitle = label(hud, "TIME TRIAL", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 8), 13, theme.Text, true)
local hudTimer = label(hud, "0.000", UDim2.new(0.5, -12, 0, 30), UDim2.fromOffset(12, 34), 24, theme.Accent, true)
local hudProgress = label(hud, "CHECKPOINT 1/1", UDim2.new(0.5, -12, 0, 22), UDim2.new(0.5, 0, 0, 39), 12, theme.Text, true)
hudProgress.TextXAlignment = Enum.TextXAlignment.Right
local hudStatus = label(hud, "", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 70), 11, theme.Muted, false)

local markerRoot = Workspace:FindFirstChild("_NTR_ClientOnly")
if not markerRoot then
	markerRoot = Instance.new("Folder")
	markerRoot.Name = "_NTR_ClientOnly"
	markerRoot.Parent = Workspace
end

local marker = nil
local markerGui = nil
local ticker = nil

local function formatTime(seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	return string.format("%.3f", seconds)
end

local function clearMarker()
	if marker then marker:Destroy(); marker = nil end
	if markerGui then markerGui:Destroy(); markerGui = nil end
end

local function ensureMarker(part, isFinish)
	clearMarker()
	if not (part and part:IsA("BasePart")) then return end
	marker = Instance.new("SelectionBox")
	marker.Name = "RaceNextGateSelection"
	marker.Adornee = part
	marker.Color3 = isFinish and Color3.fromRGB(255, 226, 80) or theme.Accent
	marker.LineThickness = 0.08
	marker.SurfaceTransparency = 0.88
	marker.Parent = markerRoot

	markerGui = Instance.new("BillboardGui")
	markerGui.Name = "RaceNextGateBillboard"
	markerGui.Adornee = part
	markerGui.AlwaysOnTop = true
	markerGui.Size = UDim2.fromOffset(170, 44)
	markerGui.StudsOffset = Vector3.new(0, math.max(7, part.Size.Y * 0.5 + 5), 0)
	markerGui.Parent = markerRoot
	local l = label(markerGui, isFinish and "FINISH" or "CHECKPOINT", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 15, isFinish and Color3.fromRGB(255, 226, 80) or theme.Accent, true)
	l.BackgroundColor3 = theme.Panel
	l.BackgroundTransparency = 0.16
	l.TextXAlignment = Enum.TextXAlignment.Center
	corner(l, 6)
end

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
	local route, routeError = RouteDefinition.GetRouteDefinition(state.ActiveRun.RouteId)
	if not route then
		warn("[NTR Racing Phase 3 Client] " .. tostring(routeError))
	end
	return route
end

local function updateNextGate()
	local route = routeForActive()
	local gate = route and RouteDefinition.GetGate(route, state.ActiveRun.NextGateIndex or 1)
	if gate then
		ensureMarker(gate.Part, gate.IsFinish)
		local gateLabel = gate.IsFinish and "FINISH" or "CHECKPOINT"
		hudProgress.Text = string.format("%s %d/%d", gateLabel, state.ActiveRun.NextGateIndex or 1, state.ActiveRun.GateCount or 1)
	else
		clearMarker()
	end
end

local function startTicker()
	if ticker then ticker:Disconnect(); ticker = nil end
	ticker = RunService.Heartbeat:Connect(function()
		if not state.ActiveRun or not state.ActiveRun.StartLocalClock then return end
		hudTimer.Text = formatTime(os.clock() - state.ActiveRun.StartLocalClock)
	end)
end

local function stopTicker()
	if ticker then ticker:Disconnect(); ticker = nil end
end

local function showHudError(message)
	hud.Visible = true
	hudTitle.Text = "RACING"
	hudTimer.Text = "--"
	hudProgress.Text = ""
	hudStatus.Text = tostring(message or "Race unavailable.")
	task.delay(2.2, function()
		if not state.ActiveRun then
			hud.Visible = false
			hudStatus.Text = ""
		end
	end)
end

local function toSet(list)
	local set = {}
	for _, userId in ipairs(list or {}) do
		set[tonumber(userId)] = true
	end
	return set
end

local function setModelHidden(model, hidden)
	for _, descendant in ipairs(model and model:GetDescendants() or {}) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function applyVisibility()
	local visibility = state.Visibility
	if not (visibility and visibility.Active) then
		for _, other in ipairs(Players:GetPlayers()) do
			if other.Character then setModelHidden(other.Character, false) end
		end
		local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
		local runtime = world and world:FindFirstChild("Runtime")
		local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
		for _, vehicle in ipairs(vehicles and vehicles:GetChildren() or {}) do
			setModelHidden(vehicle, false)
		end
		return
	end
	local participants = toSet(visibility.Participants)
	local localIsParticipant = participants[player.UserId] == true
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			local otherIsParticipant = participants[other.UserId] == true
			setModelHidden(other.Character, localIsParticipant and not otherIsParticipant or (not localIsParticipant and otherIsParticipant))
		end
	end
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
	for _, vehicle in ipairs(vehicles and vehicles:GetChildren() or {}) do
		local owner = tonumber(vehicle:GetAttribute("OwnerUserId"))
		local vehicleIsParticipant = owner and participants[owner] == true
		setModelHidden(vehicle, localIsParticipant and not vehicleIsParticipant or (not localIsParticipant and vehicleIsParticipant))
	end
end

task.spawn(function()
	while true do
		applyVisibility()
		task.wait(0.5)
	end
end)

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = payload.Type
	print("[NTR Racing Phase 3 Client] received event " .. tostring(kind))
	if kind == "OpenRaceEntry" then
		local ok, err = pcall(function()
			showEntry(payload)
		end)
		if not ok then
			warn("[NTR Racing Phase 3 Client] showEntry failed: " .. tostring(err))
		end
	elseif kind == "TimeTrialError" then
		showHudError(payload.Message)
	elseif kind == "TimeTrialStaged" then
		state.ActiveRun = {
			RunId = payload.RunId,
			EventId = payload.EventId,
			RouteId = payload.RouteId,
			DisplayName = payload.DisplayName,
			NextGateIndex = payload.NextGateIndex or 1,
			GateCount = payload.GateCount or 1,
		}
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudTimer.Text = tostring(payload.Countdown or 3)
		hudStatus.Text = "STAGED"
		updateNextGate()
	elseif kind == "TimeTrialCountdown" then
		state.ActiveRun = state.ActiveRun or {}
		state.ActiveRun.RunId = payload.RunId
		state.ActiveRun.EventId = payload.EventId
		state.ActiveRun.RouteId = payload.RouteId
		state.ActiveRun.DisplayName = payload.DisplayName
		state.ActiveRun.NextGateIndex = payload.NextGateIndex or 1
		state.ActiveRun.GateCount = payload.GateCount or 1
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudTimer.Text = tostring(payload.Countdown or 3)
		hudStatus.Text = "GET READY"
		updateNextGate()
	elseif kind == "TimeTrialStarted" then
		state.ActiveRun = state.ActiveRun or {}
		state.ActiveRun.RunId = payload.RunId
		state.ActiveRun.EventId = payload.EventId
		state.ActiveRun.RouteId = payload.RouteId
		state.ActiveRun.DisplayName = payload.DisplayName
		state.ActiveRun.NextGateIndex = payload.NextGateIndex or 1
		state.ActiveRun.GateCount = payload.GateCount or 1
		state.ActiveRun.StartLocalClock = os.clock()
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudStatus.Text = "GO"
		updateNextGate()
		task.defer(requestStreamAroundActiveRoute)
		task.defer(fireDrivingHandoff)
		task.delay(0.25, fireDrivingHandoff)
		startTicker()
	elseif kind == "TimeTrialCheckpoint" then
		if not state.ActiveRun then return end
		state.ActiveRun.NextGateIndex = payload.NextGateIndex or state.ActiveRun.NextGateIndex
		state.ActiveRun.GateCount = payload.GateCount or state.ActiveRun.GateCount
		hudStatus.Text = "CHECKPOINT " .. tostring(payload.CheckpointIndex or "")
		updateNextGate()
	elseif kind == "TimeTrialFinished" then
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudTimer.Text = formatTime(payload.Elapsed)
		hudProgress.Text = "FINISHED"
		hudStatus.Text = tostring(payload.Message or "Finished")
	elseif kind == "TimeTrialEnded" then
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = false
	elseif kind == "RaceVisibilityUpdate" then
		state.Visibility = {
			Active = payload.Active == true,
			RunId = payload.RunId,
			Participants = payload.Participants or {},
		}
		applyVisibility()
	end
end)

print("[NTR Racing Phase 3 Client] Race entry menu/HUD active.")
]==]

local function ensureRaceConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = ensureFolder(kit, "Config")
	local racing = ensureFolder(config, "Racing")
	local ui = ensureFolder(racing, "UI")
	if ui:GetAttribute("Phase3EntryMenuReady") ~= true then
		ui:SetAttribute("Phase3EntryMenuReady", true)
		ui:SetAttribute("CountdownSeconds", 3)
		ui:SetAttribute("UseThemedPlaceholders", true)
	end
	local route = Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("RaceRoutes"):FindFirstChild("ShiftedCanalSprint")
	if route then
		local media = route:FindFirstChild("Media") or Instance.new("Folder")
		media.Name = "Media"
		media.Parent = route
		if not media:FindFirstChild("TrackImage") then
			local value = Instance.new("StringValue")
			value.Name = "TrackImage"
			value.Value = ""
			value.Parent = media
		end
		if not media:FindFirstChild("MapImage") then
			local value = Instance.new("StringValue")
			value.Name = "MapImage"
			value.Value = ""
			value.Parent = media
		end
		if not route:FindFirstChild("SessionAssetTemplates") then
			local folder = Instance.new("Folder")
			folder.Name = "SessionAssetTemplates"
			folder.Parent = route
		end
	end
	local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
	ensureFolder(world, "RaceInstances")
end

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
	local oldClient = racingClients:FindFirstChild("RaceClient_Active")
	if oldClient and oldClient:IsA("LocalScript") then
		oldClient.Disabled = true
	end
	ensureScript(racingClients, "LocalScript", "RaceEntryMenuClient_Active", RACE_ENTRY_CLIENT_SOURCE, false)

	ensureRaceConfig()
	info("Installed Phase 3 race entry menu/staging/session layer. Restart Play before testing.")
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
	local instances = Workspace:FindFirstChild("NeoTokyoRacersWorld") and Workspace.NeoTokyoRacersWorld:FindFirstChild("RaceInstances")

	info("Audit:")
	info("  Remotes.Racing=" .. tostring(racingRemotes ~= nil))
	info("  RaceRequest=" .. tostring(racingRemotes and racingRemotes:FindFirstChild("RaceRequest") ~= nil))
	info("  RaceEvent=" .. tostring(racingRemotes and racingRemotes:FindFirstChild("RaceEvent") ~= nil))
	info("  RaceRouteDefinition=" .. tostring(racingModules and racingModules:FindFirstChild("RaceRouteDefinition") ~= nil))
	info("  RaceConfigReader=" .. tostring(racingModules and racingModules:FindFirstChild("RaceConfigReader") ~= nil))
	info("  TimeTrialService_Active=" .. tostring(serverRoot and serverRoot:FindFirstChild("TimeTrialService_Active") ~= nil))
	info("  RaceEntryMenuClient_Active=" .. tostring(clientRoot and clientRoot:FindFirstChild("RaceEntryMenuClient_Active") ~= nil))
	info("  Old RaceClient_Active disabled=" .. tostring(clientRoot and clientRoot:FindFirstChild("RaceClient_Active") and clientRoot.RaceClient_Active.Disabled == true))
	info("  ShiftedCanalSprint route=" .. tostring(route ~= nil))
	info("  Route Media folder=" .. tostring(route and route:FindFirstChild("Media") ~= nil))
	info("  SessionAssetTemplates folder=" .. tostring(route and route:FindFirstChild("SessionAssetTemplates") ~= nil))
	info("  RaceInstances folder=" .. tostring(instances ~= nil))
	if route and route:FindFirstChild("StartZones") then
		for _, zone in ipairs(route.StartZones:GetChildren()) do
			if zone:IsA("BasePart") then
				info("  Prompt " .. zone.Name .. "=" .. tostring(zone:FindFirstChild("NTR_RaceEntryPrompt") ~= nil))
			end
		end
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
