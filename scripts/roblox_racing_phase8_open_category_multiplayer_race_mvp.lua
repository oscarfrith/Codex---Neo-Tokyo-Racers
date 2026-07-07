-- Neo Tokyo Racers - Racing Phase 8 Open-Category Multiplayer Race MVP
-- Run in Roblox Studio Command Bar in Edit mode.
--
-- Adds a first multiplayer race queue without changing reward config.
-- Source patches are guarded exact-text patches against isolated Racing clients.

local MODE = "INSTALL" -- INSTALL or SMOKE

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing.ClassName ~= className then
			error(("Existing %s is %s, expected %s"):format(existing:GetFullName(), existing.ClassName, className))
		end
		return existing
	end
	local item = Instance.new(className)
	item.Name = name
	item.Parent = parent
	return item
end

local function setValue(parent, className, name, value)
	local item = child(parent, className, name)
	item.Value = value
	return item
end

local function replaceOnce(source, old, new, label)
	local first = string.find(source, old, 1, true)
	if not first then
		error("[NTR Racing Phase 8] Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another repair.")
	end
	local second = string.find(source, old, first + #old, true)
	if second then
		error("[NTR Racing Phase 8] Source anchor is not unique: " .. label)
	end
	return string.sub(source, 1, first - 1) .. new .. string.sub(source, first + #old)
end

local function serviceSource()
	return [====[
-- Neo Tokyo Racers - Racing Phase 8 Open-Category Matchmaking Service
-- NTR_RACING_PHASE8_MATCHMAKING_SERVICE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")
local queueEvent = racingRemotes:WaitForChild("RaceQueueEvent")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local racingModules = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Racing")
local RouteDefinition = require(racingModules:WaitForChild("RaceRouteDefinition"))
local RaceConfigReader = require(racingModules:WaitForChild("RaceConfigReader"))

local config = kit:WaitForChild("Config"):WaitForChild("Racing")
local matchmakingConfig = config:WaitForChild("Matchmaking")

local queues = {}
local queuedByPlayer = {}
local activeRaceByPlayer = {}
local activeRaces = {}
local gateConnections = {}

local function numberValue(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function boolValue(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("BoolValue") and item.Value or fallback
end

local function now()
	return os.clock()
end

local function info(message)
	print("[NTR Racing Phase 8] " .. tostring(message))
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
	return root and root:IsA("BasePart") and root or nil
end

local function vehicleSeat(vehicle)
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	if seat and seat:IsA("VehicleSeat") then
		return seat
	end
	for _, item in ipairs(vehicle and vehicle:GetDescendants() or {}) do
		if item:IsA("VehicleSeat") then
			return item
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
		return nil, "Spawn and sit in your selected vehicle first."
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

local function fire(player, payload)
	queueEvent:FireClient(player, payload)
end

local function fireRace(player, payload)
	raceEvent:FireClient(player, payload)
end

local function fireVisibility(race, active)
	local participants = {}
	for _, entry in ipairs(race and race.Participants or {}) do
		if entry.Player then
			table.insert(participants, entry.Player.UserId)
		end
	end
	raceEvent:FireAllClients({
		Type = "RaceVisibilityUpdate",
		Active = active == true,
		RunId = race and race.RunId or "",
		Participants = participants,
	})
end

local function setVehicleFrozen(vehicle, frozen)
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
end

local function seatPlayer(player, vehicle)
	local seat = vehicleSeat(vehicle)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if seat and humanoid then
		seat:Sit(humanoid)
	end
end

local function prepareVehicleForDriving(player, vehicle)
	local root = vehicleRootPart(vehicle)
	if not root then return end
	for _, item in ipairs(vehicle:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.AssemblyLinearVelocity = Vector3.zero
			item.AssemblyAngularVelocity = Vector3.zero
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

local function spawnCFrameForIndex(route, index)
	local grid = route and route.SpawnGrid
	local item = grid and grid[index]
	if item and item.Part then
		return item.Part.CFrame
	end
	return RouteDefinition.GetFirstSpawnCFrame(route) * CFrame.new((index - 1) * 10, 0, 0)
end

local function createSessionFolder(race)
	local root = raceInstancesRoot()
	if not root then return nil end
	local old = root:FindFirstChild(race.RunId)
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = race.RunId
	folder:SetAttribute("EventId", race.EventId)
	folder:SetAttribute("RouteId", race.RouteId)
	folder:SetAttribute("Mode", "Race")
	folder:SetAttribute("ParticipantCount", #race.Participants)
	folder.Parent = root
	local assets = Instance.new("Folder")
	assets.Name = "SessionAssets"
	assets.Parent = folder
	return folder
end

local function cleanupRace(race, reason)
	if not race or race.Cleaned then return end
	race.Cleaned = true
	activeRaces[race.RunId] = nil
	for _, entry in ipairs(race.Participants or {}) do
		activeRaceByPlayer[entry.Player] = nil
		if entry.Vehicle then
			setVehicleFrozen(entry.Vehicle, false)
			entry.Vehicle:SetAttribute("NTR_RaceRunId", nil)
			entry.Vehicle:SetAttribute("NTR_RaceParticipant", nil)
			entry.Vehicle:SetAttribute("NTR_RaceMode", nil)
			entry.Vehicle:SetAttribute("DriveReady", true)
		end
		fire(entry.Player, {
			Type = "RaceEnded",
			RunId = race.RunId,
			Reason = reason or "Race ended",
		})
		fireRace(entry.Player, {
			Type = "RaceEnded",
			RunId = race.RunId,
			Reason = reason or "Race ended",
		})
	end
	fireVisibility(race, false)
	if race.SessionFolder and race.SessionFolder.Parent then
		race.SessionFolder:Destroy()
	end
end

local function sortedPlacements(race)
	local list = {}
	for _, entry in ipairs(race.Participants or {}) do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		if (a.Finished == true) ~= (b.Finished == true) then
			return a.Finished == true
		end
		if a.FinishPlace and b.FinishPlace then
			return a.FinishPlace < b.FinishPlace
		end
		local aGate = tonumber(a.NextGateIndex) or 1
		local bGate = tonumber(b.NextGateIndex) or 1
		if aGate ~= bGate then
			return aGate > bGate
		end
		local aElapsed = tonumber(a.LastProgressElapsed) or 0
		local bElapsed = tonumber(b.LastProgressElapsed) or 0
		return aElapsed < bElapsed
	end)
	return list
end

local function broadcastPositions(race)
	local placements = sortedPlacements(race)
	local payloadPositions = {}
	for index, entry in ipairs(placements) do
		entry.CurrentPlace = index
		table.insert(payloadPositions, {
			UserId = entry.Player.UserId,
			Name = entry.Player.DisplayName or entry.Player.Name,
			Place = index,
			Finished = entry.Finished == true,
			NextGateIndex = entry.NextGateIndex,
		})
	end
	for _, entry in ipairs(race.Participants or {}) do
		fire(entry.Player, {
			Type = "RacePositionUpdate",
			RunId = race.RunId,
			Place = entry.CurrentPlace or 1,
			ParticipantCount = #race.Participants,
			Positions = payloadPositions,
		})
	end
end

local function allFinished(race)
	for _, entry in ipairs(race.Participants or {}) do
		if entry.Finished ~= true then
			return false
		end
	end
	return true
end

local function finishEntry(race, entry)
	if entry.Finished then return end
	entry.Finished = true
	entry.FinishElapsed = now() - race.StartClock
	entry.FinishPlace = race.NextFinishPlace
	race.NextFinishPlace += 1
	if entry.Vehicle then
		prepareVehicleForDriving(entry.Player, entry.Vehicle)
	end
	fire(entry.Player, {
		Type = "RaceFinished",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		DisplayName = race.DisplayName,
		Place = entry.FinishPlace,
		ParticipantCount = #race.Participants,
		Elapsed = entry.FinishElapsed,
		GateCount = race.GateCount,
	})
	fireRace(entry.Player, {
		Type = "RaceFinished",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		NextGateIndex = race.GateCount,
		GateCount = race.GateCount,
	})
	broadcastPositions(race)
	if allFinished(race) then
		task.delay(5, function()
			cleanupRace(race, "Finished")
		end)
	end
end

local function advanceCheckpoint(race, entry, touchedPart)
	if not (race and race.State == "Running" and entry and entry.Finished ~= true) then return end
	local gate = RouteDefinition.GetGate(race.Route, entry.NextGateIndex)
	if not (gate and gate.Part == touchedPart) then return end
	local clock = now()
	if clock - (entry.LastTouchClock or 0) < 0.12 then return end
	entry.LastTouchClock = clock
	entry.LastProgressElapsed = clock - race.StartClock
	if gate.IsFinish then
		finishEntry(race, entry)
		return
	end
	entry.NextGateIndex += 1
	fire(entry.Player, {
		Type = "RaceCheckpoint",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		NextGateIndex = entry.NextGateIndex,
		GateCount = race.GateCount,
		CheckpointIndex = gate.Index,
		Elapsed = entry.LastProgressElapsed,
	})
	fireRace(entry.Player, {
		Type = "RaceCheckpoint",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		NextGateIndex = entry.NextGateIndex,
		GateCount = race.GateCount,
		CheckpointIndex = gate.Index,
		Elapsed = entry.LastProgressElapsed,
	})
	broadcastPositions(race)
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
				for _, race in pairs(activeRaces) do
					if race.Route == route and race.State == "Running" then
						for _, entry in ipairs(race.Participants) do
							if entry.Vehicle == model or (entry.Vehicle and model:IsDescendantOf(entry.Vehicle)) then
								advanceCheckpoint(race, entry, gate.Part)
								return
							end
						end
					end
				end
			end)
		end
	end
end

local function removeFromQueue(player, reason)
	local eventId = queuedByPlayer[player]
	if not eventId then
		return false, "Not queued."
	end
	local queue = queues[eventId]
	queuedByPlayer[player] = nil
	if queue then
		queue.Joined[player] = nil
		for index = #queue.Players, 1, -1 do
			if queue.Players[index] == player then
				table.remove(queue.Players, index)
			end
		end
		for _, other in ipairs(queue.Players) do
			fire(other, {
				Type = "QueueUpdate",
				EventId = eventId,
				Count = #queue.Players,
				MinPlayers = queue.MinPlayers,
				MaxPlayers = queue.MaxPlayers,
				SecondsRemaining = math.max(0, math.ceil((queue.Deadline or now()) - now())),
				Message = reason or "Queue updated.",
			})
		end
		if #queue.Players == 0 then
			queues[eventId] = nil
		end
	end
	fire(player, {
		Type = "QueueLeft",
		EventId = eventId,
		Message = reason or "Left queue.",
	})
	return true, "Left queue."
end

local function raceEventSummary(eventId)
	local summary, summaryError = RaceConfigReader.GetEventSummary(eventId, "Race")
	if not summary then
		return nil, nil, summaryError or "Race event unavailable."
	end
	local route, routeError = RaceConfigReader.GetRouteForEvent(eventId, "Race")
	if not route then
		return nil, nil, routeError or "Race route unavailable."
	end
	if RouteDefinition.GetGateCount(route) < 2 then
		return nil, nil, "Route needs checkpoints and a finish line."
	end
	return summary, route, nil
end

local function startRace(queue)
	if not queue or queue.Starting then return end
	queue.Starting = true
	queues[queue.EventId] = nil

	local participants = {}
	for _, player in ipairs(queue.Players) do
		queuedByPlayer[player] = nil
		local vehicle, vehicleError = currentVehicleForPlayer(player)
		if vehicle then
			table.insert(participants, {
				Player = player,
				Vehicle = vehicle,
				SelectedVehicleId = tostring(queue.VehicleIds[player] or ""),
				NextGateIndex = 1,
				LastTouchClock = 0,
				LastProgressElapsed = 0,
			})
		else
			fire(player, {
				Type = "RaceQueueError",
				EventId = queue.EventId,
				Message = vehicleError or "Vehicle unavailable before race start.",
			})
		end
	end

	local minPlayers = queue.MinPlayers
	if #participants < minPlayers and boolValue(matchmakingConfig, "AllowSoloRaceDebug", false) ~= true then
		for _, entry in ipairs(participants) do
			fire(entry.Player, {
				Type = "RaceQueueError",
				EventId = queue.EventId,
				Message = "Not enough eligible racers at start.",
			})
		end
		return
	end

	local runId = "RACE_" .. tostring(math.floor(now() * 1000))
	local race = {
		State = "Staging",
		RunId = runId,
		EventId = queue.EventId,
		RouteId = queue.Route.RouteId,
		DisplayName = queue.Summary.DisplayName or queue.Route.DisplayName,
		Route = queue.Route,
		GateCount = RouteDefinition.GetGateCount(queue.Route),
		Participants = participants,
		NextFinishPlace = 1,
	}
	activeRaces[runId] = race
	race.SessionFolder = createSessionFolder(race)
	connectRouteTouches(queue.Route)

	for index, entry in ipairs(participants) do
		activeRaceByPlayer[entry.Player] = race
		local root = vehicleRootPart(entry.Vehicle)
		if root then
			entry.Vehicle.PrimaryPart = root
			entry.Vehicle:PivotTo(spawnCFrameForIndex(queue.Route, index) + Vector3.new(0, 4, 0))
		end
		entry.Vehicle:SetAttribute("ParkedShowcase", nil)
		entry.Vehicle:SetAttribute("DriverUserId", entry.Player.UserId)
		entry.Vehicle:SetAttribute("NTR_RaceRunId", runId)
		entry.Vehicle:SetAttribute("NTR_RaceParticipant", true)
		entry.Vehicle:SetAttribute("NTR_RaceMode", "Race")
		seatPlayer(entry.Player, entry.Vehicle)
		task.wait(0.04)
		setVehicleFrozen(entry.Vehicle, true)
	end

	fireVisibility(race, true)
	for _, entry in ipairs(participants) do
		fire(entry.Player, {
			Type = "RaceStaged",
			RunId = runId,
			EventId = queue.EventId,
			RouteId = race.RouteId,
			DisplayName = race.DisplayName,
			ParticipantCount = #participants,
			Countdown = numberValue(matchmakingConfig, "CountdownSeconds", 3),
			GateCount = race.GateCount,
			NextGateIndex = 1,
		})
		fireRace(entry.Player, {
			Type = "RaceStaged",
			RunId = runId,
			EventId = queue.EventId,
			RouteId = race.RouteId,
			DisplayName = race.DisplayName,
			GateCount = race.GateCount,
			NextGateIndex = 1,
		})
	end
	broadcastPositions(race)

	task.spawn(function()
		local countdown = math.max(1, math.floor(numberValue(matchmakingConfig, "CountdownSeconds", 3)))
		for seconds = countdown, 1, -1 do
			if race.State ~= "Staging" then return end
			for _, entry in ipairs(participants) do
				fire(entry.Player, {
					Type = "RaceCountdown",
					RunId = runId,
					EventId = queue.EventId,
					RouteId = race.RouteId,
					DisplayName = race.DisplayName,
					Countdown = seconds,
					GateCount = race.GateCount,
					NextGateIndex = 1,
				})
				fireRace(entry.Player, {
					Type = "RaceCountdown",
					RunId = runId,
					EventId = queue.EventId,
					RouteId = race.RouteId,
					DisplayName = race.DisplayName,
					Countdown = seconds,
					GateCount = race.GateCount,
					NextGateIndex = 1,
				})
			end
			task.wait(1)
		end
		if race.State ~= "Staging" then return end
		race.State = "Running"
		race.StartClock = now()
		for _, entry in ipairs(participants) do
			prepareVehicleForDriving(entry.Player, entry.Vehicle)
			fire(entry.Player, {
				Type = "RaceStarted",
				RunId = runId,
				EventId = queue.EventId,
				RouteId = race.RouteId,
				DisplayName = race.DisplayName,
				StartServerClock = race.StartClock,
				GateCount = race.GateCount,
				NextGateIndex = 1,
				ParticipantCount = #participants,
			})
			fireRace(entry.Player, {
				Type = "RaceStarted",
				RunId = runId,
				EventId = queue.EventId,
				RouteId = race.RouteId,
				DisplayName = race.DisplayName,
				StartServerClock = race.StartClock,
				GateCount = race.GateCount,
				NextGateIndex = 1,
			})
		end
		task.delay(numberValue(matchmakingConfig, "RaceFinishTimeoutSeconds", 300), function()
			if activeRaces[runId] == race and race.State == "Running" then
				for _, entry in ipairs(participants) do
					if entry.Finished ~= true then
						fire(entry.Player, {
							Type = "RaceDNF",
							RunId = runId,
							EventId = queue.EventId,
							Message = "Race timed out.",
						})
					end
				end
				cleanupRace(race, "Timed out")
			end
		end)
	end)
	info("Started " .. runId .. " with " .. tostring(#participants) .. " racers.")
end

local function watchQueue(eventId)
	task.spawn(function()
		local queue = queues[eventId]
		while queue and queues[eventId] == queue and queue.Starting ~= true do
			local remaining = math.max(0, math.ceil((queue.Deadline or now()) - now()))
			for _, player in ipairs(queue.Players) do
				fire(player, {
					Type = "QueueUpdate",
					EventId = eventId,
					DisplayName = queue.Summary.DisplayName,
					Count = #queue.Players,
					MinPlayers = queue.MinPlayers,
					MaxPlayers = queue.MaxPlayers,
					SecondsRemaining = remaining,
					Message = #queue.Players >= queue.MinPlayers and "Race starts soon." or "Waiting for racers.",
				})
			end
			if #queue.Players >= queue.MaxPlayers or (remaining <= 0 and #queue.Players >= queue.MinPlayers) then
				startRace(queue)
				return
			end
			if remaining <= 0 and #queue.Players < queue.MinPlayers then
				for _, player in ipairs(table.clone(queue.Players)) do
					removeFromQueue(player, "Not enough racers joined.")
				end
				return
			end
			task.wait(1)
			queue = queues[eventId]
		end
	end)
end

local function joinQueue(player, eventId, vehicleId)
	if activeRaceByPlayer[player] then
		return false, "Already in a race."
	end
	if queuedByPlayer[player] then
		return false, "Already queued."
	end
	local vehicle, vehicleError = currentVehicleForPlayer(player)
	if not vehicle then
		return false, vehicleError
	end
	local summary, route, eventError = raceEventSummary(eventId)
	if not summary then
		return false, eventError
	end

	local summaryMin = tonumber(summary.MinPlayers)
	local summaryMax = tonumber(summary.MaxPlayers)
	local minPlayers = math.floor((summaryMin and summaryMin > 1 and summaryMin) or numberValue(matchmakingConfig, "DefaultMinPlayers", 2))
	local maxPlayers = math.floor((summaryMax and summaryMax > 1 and summaryMax) or numberValue(matchmakingConfig, "DefaultMaxPlayers", 6))
	minPlayers = math.max(1, minPlayers)
	maxPlayers = math.max(minPlayers, maxPlayers)
	if boolValue(matchmakingConfig, "AllowSoloRaceDebug", false) == true then
		minPlayers = 1
	end

	local queue = queues[eventId]
	if not queue then
		queue = {
			EventId = eventId,
			Summary = summary,
			Route = route,
			Players = {},
			Joined = {},
			VehicleIds = {},
			MinPlayers = minPlayers,
			MaxPlayers = maxPlayers,
			Deadline = now() + numberValue(matchmakingConfig, "QueueTimeoutSeconds", 25),
		}
		queues[eventId] = queue
		watchQueue(eventId)
	end
	if #queue.Players >= queue.MaxPlayers then
		return false, "Race queue is full."
	end
	queue.Joined[player] = true
	queue.VehicleIds[player] = tostring(vehicleId or "")
	table.insert(queue.Players, player)
	queuedByPlayer[player] = eventId
	fire(player, {
		Type = "QueueJoined",
		EventId = eventId,
		DisplayName = queue.Summary.DisplayName,
		Count = #queue.Players,
		MinPlayers = queue.MinPlayers,
		MaxPlayers = queue.MaxPlayers,
		SecondsRemaining = math.max(0, math.ceil(queue.Deadline - now())),
		Message = "Joined open-category race queue.",
	})
	for _, other in ipairs(queue.Players) do
		if other ~= player then
			fire(other, {
				Type = "QueueUpdate",
				EventId = eventId,
				DisplayName = queue.Summary.DisplayName,
				Count = #queue.Players,
				MinPlayers = queue.MinPlayers,
				MaxPlayers = queue.MaxPlayers,
				SecondsRemaining = math.max(0, math.ceil(queue.Deadline - now())),
				Message = player.DisplayName .. " joined the queue.",
			})
		end
	end
	if #queue.Players >= queue.MaxPlayers then
		startRace(queue)
	end
	return true, "Joined queue."
end

queueRequest.OnServerInvoke = function(player, action, payload)
	payload = typeof(payload) == "table" and payload or {}
	if action == "JoinQueue" then
		local eventId = tostring(payload.EventId or "shifted_canal_sprint_race")
		local ok, message = joinQueue(player, eventId, payload.VehicleId)
		return { Ok = ok, Success = ok, Message = message }
	elseif action == "LeaveQueue" then
		local ok, message = removeFromQueue(player, "Left queue.")
		return { Ok = ok, Success = ok, Message = message }
	elseif action == "GetQueueStatus" then
		local eventId = queuedByPlayer[player]
		if not eventId then
			return { Ok = true, Queued = false }
		end
		local queue = queues[eventId]
		return {
			Ok = true,
			Queued = queue ~= nil,
			EventId = eventId,
			Count = queue and #queue.Players or 0,
			MinPlayers = queue and queue.MinPlayers or 0,
			MaxPlayers = queue and queue.MaxPlayers or 0,
			SecondsRemaining = queue and math.max(0, math.ceil((queue.Deadline or now()) - now())) or 0,
		}
	end
	return { Ok = false, Message = "Unknown queue action." }
end

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player, "Player left.")
	local race = activeRaceByPlayer[player]
	if race then
		for _, entry in ipairs(race.Participants) do
			if entry.Player == player then
				entry.Finished = true
				entry.DNF = true
			end
		end
		if allFinished(race) then
			cleanupRace(race, "All racers left.")
		else
			broadcastPositions(race)
		end
	end
end)

info("Open-category matchmaking service active.")
]====]
end

local function queueClientSource()
	return [====[
-- Neo Tokyo Racers - Racing Phase 8 Queue Client
-- NTR_RACING_PHASE8_QUEUE_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local racingRemotes = shared:WaitForChild("Remotes"):WaitForChild("Racing")
local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")
local queueEvent = racingRemotes:WaitForChild("RaceQueueEvent")
local RouteDefinition = require(shared:WaitForChild("Modules"):WaitForChild("Racing"):WaitForChild("RaceRouteDefinition"))

local racingFolder = script.Parent
local startQueueEvent = racingFolder:WaitForChild("StartRaceQueueRequest")

local themeFolder = kit:FindFirstChild("Config") and kit.Config:FindFirstChild("UI") and kit.Config.UI:FindFirstChild("Theme")

local function colorAttr(name, fallback)
	local value = themeFolder and themeFolder:GetAttribute(name)
	return typeof(value) == "Color3" and value or fallback
end

local theme = {
	Panel = colorAttr("Panel", Color3.fromRGB(12, 15, 18)),
	Text = colorAttr("Text", Color3.fromRGB(240, 250, 255)),
	Muted = colorAttr("Muted", Color3.fromRGB(165, 180, 190)),
	Accent = colorAttr("Accent", Color3.fromRGB(67, 255, 210)),
	Selected = colorAttr("Selected", Color3.fromRGB(255, 111, 220)),
	Exit = colorAttr("Exit", Color3.fromRGB(210, 72, 72)),
	Buy = colorAttr("Buy", Color3.fromRGB(67, 255, 165)),
}

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius or 7)
	item.Parent = parent
	return item
end

local function stroke(parent, color, thickness, transparency)
	local item = Instance.new("UIStroke")
	item.Color = color
	item.Thickness = thickness or 1
	item.Transparency = transparency or 0.2
	item.Parent = parent
	return item
end

local function label(parent, text, size, position, textSize, color, bold)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Text = text or ""
	item.Size = size
	item.Position = position
	item.TextColor3 = color or theme.Text
	item.TextSize = textSize or 13
	item.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.TextWrapped = true
	item.Parent = parent
	return item
end

local function button(parent, name, text, size, position, color)
	local item = Instance.new("TextButton")
	item.Name = name
	item.AutoButtonColor = true
	item.BackgroundColor3 = color or theme.Panel
	item.BackgroundTransparency = 0.06
	item.BorderSizePixel = 0
	item.Text = text
	item.TextColor3 = theme.Text
	item.TextSize = 12
	item.Font = Enum.Font.GothamBold
	item.Size = size
	item.Position = position
	item.Parent = parent
	corner(item, 6)
	stroke(item, theme.Selected, 1.2, 0.25)
	return item
end

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_RaceQueue_Phase8"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 88
gui.Enabled = true
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 74)
panel.Size = UDim2.fromOffset(430, 132)
panel.BackgroundColor3 = theme.Panel
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 7)
stroke(panel, theme.Selected, 1.5, 0.18)

local title = label(panel, "OPEN RACE QUEUE", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 10), 14, theme.Text, true)
title.TextXAlignment = Enum.TextXAlignment.Center
local status = label(panel, "Waiting for racers.", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 38), 12, theme.Accent, true)
status.TextXAlignment = Enum.TextXAlignment.Center
local details = label(panel, "", UDim2.new(1, -148, 0, 48), UDim2.fromOffset(12, 72), 11, theme.Muted, false)
local leave = button(panel, "LeaveQueue", "LEAVE", UDim2.fromOffset(112, 38), UDim2.new(1, -124, 1, -50), theme.Exit)

local state = {
	Queued = false,
	ActiveRun = nil,
	StartLocalClock = nil,
}

local ticker = nil

local function formatTime(seconds)
	return string.format("%.3f", math.max(0, tonumber(seconds) or 0))
end

local function setVisible(visible)
	panel.Visible = visible == true
end

local function setQueueText(payload)
	title.Text = tostring(payload.DisplayName or "OPEN RACE QUEUE")
	status.Text = tostring(payload.Message or "Waiting for racers.")
	details.Text = "Open category  |  " .. tostring(payload.Count or 0) .. "/" .. tostring(payload.MaxPlayers or 0) .. " racers\nMin players: " .. tostring(payload.MinPlayers or 0) .. "  |  Starts in: " .. tostring(payload.SecondsRemaining or 0) .. "s"
	setVisible(true)
end

local function stopTicker()
	if ticker then
		ticker:Disconnect()
		ticker = nil
	end
end

local function startTicker()
	stopTicker()
	ticker = RunService.Heartbeat:Connect(function()
		if state.ActiveRun and state.StartLocalClock then
			status.Text = "RACE LIVE  |  " .. formatTime(os.clock() - state.StartLocalClock)
		end
	end)
end

local function invokeQueue(action, payload)
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
end

startQueueEvent.Event:Connect(function(payload)
	payload = typeof(payload) == "table" and payload or {}
	state.Queued = true
	title.Text = tostring(payload.DisplayName or "OPEN RACE QUEUE")
	status.Text = "Joining race queue..."
	details.Text = "Open category matchmaking."
	setVisible(true)
	local result = invokeQueue("JoinQueue", {
		EventId = payload.EventId,
		VehicleId = payload.VehicleId,
	})
	if result.Ok ~= true and result.Success ~= true then
		state.Queued = false
		status.Text = tostring(result.Message or "Could not join race queue.")
		task.delay(3, function()
			if state.Queued ~= true and not state.ActiveRun then
				setVisible(false)
			end
		end)
	end
end)

leave.MouseButton1Click:Connect(function()
	local result = invokeQueue("LeaveQueue", {})
	state.Queued = false
	status.Text = tostring(result.Message or "Left queue.")
	task.delay(1.2, function()
		if state.Queued ~= true and not state.ActiveRun then
			setVisible(false)
		end
	end)
end)

queueEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = payload.Type
	if kind == "QueueJoined" or kind == "QueueUpdate" then
		state.Queued = true
		state.ActiveRun = nil
		stopTicker()
		setQueueText(payload)
	elseif kind == "QueueLeft" then
		state.Queued = false
		status.Text = tostring(payload.Message or "Left queue.")
		task.delay(1.2, function()
			if state.Queued ~= true and not state.ActiveRun then
				setVisible(false)
			end
		end)
	elseif kind == "RaceQueueError" then
		state.Queued = false
		state.ActiveRun = nil
		stopTicker()
		status.Text = tostring(payload.Message or "Race queue unavailable.")
		setVisible(true)
	elseif kind == "RaceStaged" then
		state.Queued = false
		state.ActiveRun = payload
		state.StartLocalClock = nil
		title.Text = tostring(payload.DisplayName or "RACE")
		status.Text = "STAGING"
		details.Text = "Racers: " .. tostring(payload.ParticipantCount or "?") .. "  |  Checkpoints: " .. tostring(payload.GateCount or "?")
		setVisible(true)
	elseif kind == "RaceCountdown" then
		title.Text = tostring(payload.DisplayName or "RACE")
		status.Text = tostring(payload.Countdown or 3)
		details.Text = "Get ready."
		setVisible(true)
	elseif kind == "RaceStarted" then
		state.ActiveRun = payload
		state.StartLocalClock = os.clock()
		title.Text = tostring(payload.DisplayName or "RACE")
		details.Text = "Position updates appear at checkpoints."
		setVisible(true)
		task.defer(requestStreamAroundRoute, payload.RouteId, payload.NextGateIndex or 1)
		task.defer(fireDrivingHandoff)
		task.delay(0.25, fireDrivingHandoff)
		startTicker()
	elseif kind == "RaceCheckpoint" then
		details.Text = "Checkpoint " .. tostring((payload.NextGateIndex or 1) - 1) .. "/" .. tostring(payload.GateCount or "?")
	elseif kind == "RacePositionUpdate" then
		status.Text = "POSITION  " .. tostring(payload.Place or "?") .. "/" .. tostring(payload.ParticipantCount or "?")
	elseif kind == "RaceFinished" then
		stopTicker()
		state.ActiveRun = nil
		title.Text = tostring(payload.DisplayName or "RACE COMPLETE")
		status.Text = "FINISHED  P" .. tostring(payload.Place or "?") .. "/" .. tostring(payload.ParticipantCount or "?")
		details.Text = "Time: " .. formatTime(payload.Elapsed) .. "\nRace rewards are deferred to the guarded reward phase."
		setVisible(true)
	elseif kind == "RaceDNF" then
		stopTicker()
		state.ActiveRun = nil
		status.Text = "DNF"
		details.Text = tostring(payload.Message or "Race ended.")
	elseif kind == "RaceEnded" then
		stopTicker()
		state.Queued = false
		state.ActiveRun = nil
		task.delay(4, function()
			if state.Queued ~= true and not state.ActiveRun then
				setVisible(false)
			end
		end)
	end
end)

print("[NTR Racing Phase 8 Client] Race queue client active.")
]====]
end

local function ensureConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local racing = child(kit:WaitForChild("Config"), "Folder", "Racing")
	local matchmaking = child(racing, "Folder", "Matchmaking")
	setValue(matchmaking, "NumberValue", "DefaultMinPlayers", 2)
	setValue(matchmaking, "NumberValue", "DefaultMaxPlayers", 6)
	setValue(matchmaking, "NumberValue", "QueueTimeoutSeconds", 25)
	setValue(matchmaking, "NumberValue", "CountdownSeconds", 3)
	setValue(matchmaking, "NumberValue", "RaceFinishTimeoutSeconds", 300)
	setValue(matchmaking, "BoolValue", "AllowSoloRaceDebug", false)
end

local function ensureRemotes()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local shared = kit:WaitForChild("Shared")
	local remotes = child(shared, "Folder", "Remotes")
	local racing = child(remotes, "Folder", "Racing")
	child(racing, "RemoteFunction", "RaceQueueRequest")
	child(racing, "RemoteEvent", "RaceQueueEvent")
end

local function racingClientFolder()
	local scripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	return scripts:WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing")
end

local function patchEntryMenuClient()
	local racing = racingClientFolder()
	local client = racing:WaitForChild("RaceEntryMenuClient_Active")
	if not client:IsA("LocalScript") then
		error("[NTR Racing Phase 8] RaceEntryMenuClient_Active is not a LocalScript")
	end
	local source = client.Source
	if string.find(source, "NTR_RACING_PHASE8_ENTRY_QUEUE_PATCH", 1, true) then
		return
	end
	source = replaceOnce(source,
		[[local raceEvent = racingRemotes:WaitForChild("RaceEvent")]],
		[[local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local startRaceQueueEvent = script.Parent:WaitForChild("StartRaceQueueRequest")
-- NTR_RACING_PHASE8_ENTRY_QUEUE_PATCH]],
		"queue bridge declaration")
	source = replaceOnce(source,
		[[	start.MouseButton1Click:Connect(function()
		if mode == "Race" then
			statusText("Multiplayer matchmaking is coming after the time-trial entry flow is stable.", false)
			return
		end
		local row = state.SelectedRow
		if not row then
			statusText("Choose a vehicle first.", false)
			return
		end]],
		[[	start.MouseButton1Click:Connect(function()
		local row = state.SelectedRow
		if not row then
			statusText("Choose a vehicle first.", false)
			return
		end
		if mode == "Race" then
			local raceEventId = tostring(state.Entry and state.Entry.EventId or "shifted_canal_sprint_race")
			statusText("Spawning selected vehicle for race queue...", true)
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
			startRaceQueueEvent:Fire({
				EventId = raceEventId,
				VehicleId = row.VehicleId,
				CockpitId = row.CockpitId,
				DisplayName = state.Entry and state.Entry.Summary and state.Entry.Summary.DisplayName,
			})
			setOpen(false)
			return
		end]],
		"vehicle select race queue branch")
	source = replaceOnce(source,
		[[	startRace.MouseButton1Click:Connect(function()
		statusText("Race matchmaking is coming next. Time trial is available now.", false)
	end)]],
		[[	startRace.MouseButton1Click:Connect(function()
		showVehicleSelect("Race")
	end)]],
		"entry start race button")
	client.Source = source
end

local function patchRouteGuideClient()
	local racing = racingClientFolder()
	local guide = racing:FindFirstChild("RaceRouteGuideClient_Active")
	if not (guide and guide:IsA("LocalScript")) then
		return
	end
	local source = guide.Source
	if string.find(source, "NTR_RACING_PHASE8_ROUTE_GUIDE_RACE_EVENTS", 1, true) then
		return
	end
	source = replaceOnce(source,
		[[	if kind == "TimeTrialStaged" or kind == "TimeTrialCountdown" or kind == "TimeTrialStarted" then
		setActive(payload)
	elseif kind == "TimeTrialCheckpoint" then
		setActive(payload)
	elseif kind == "TimeTrialFinished" or kind == "TimeTrialEnded" or kind == "TimeTrialError" then
		clearActive()
	end]],
		[[	if kind == "TimeTrialStaged" or kind == "TimeTrialCountdown" or kind == "TimeTrialStarted" or kind == "RaceStaged" or kind == "RaceCountdown" or kind == "RaceStarted" then
		setActive(payload)
	elseif kind == "TimeTrialCheckpoint" or kind == "RaceCheckpoint" then
		setActive(payload)
	elseif kind == "TimeTrialFinished" or kind == "TimeTrialEnded" or kind == "TimeTrialError" or kind == "RaceFinished" or kind == "RaceEnded" then
		clearActive()
	end
	-- NTR_RACING_PHASE8_ROUTE_GUIDE_RACE_EVENTS]],
		"route guide race event support")
	guide.Source = source
end

local function install()
	ensureConfig()
	ensureRemotes()

	local services = child(ServerScriptService, "Folder", "NeoTokyoRacers")
	services = child(services, "Folder", "Services")
	local racingServices = child(services, "Folder", "Racing")
	local service = child(racingServices, "Script", "RaceMatchmakingService_Active")
	service.Source = serviceSource()
	service.Disabled = false

	local racingClients = racingClientFolder()
	child(racingClients, "BindableEvent", "StartRaceQueueRequest")
	local queueClient = child(racingClients, "LocalScript", "RaceQueueClient_Active")
	queueClient.Source = queueClientSource()
	queueClient.Disabled = false

	patchEntryMenuClient()
	local routeGuideOk, routeGuideError = pcall(patchRouteGuideClient)
	if not routeGuideOk then
		warn("[NTR Racing Phase 8] Route guide race-event patch skipped: " .. tostring(routeGuideError))
	end

	print("[NTR Racing Phase 8] Installed open-category multiplayer race MVP.")
	print("[NTR Racing Phase 8] Reward config untouched; race cash rewards remain deferred.")
end

local function smoke()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
	assert(racingRemotes:FindFirstChild("RaceQueueRequest"), "RaceQueueRequest missing")
	assert(racingRemotes:FindFirstChild("RaceQueueEvent"), "RaceQueueEvent missing")
	local racingConfig = kit:WaitForChild("Config"):WaitForChild("Racing")
	assert(racingConfig:FindFirstChild("Matchmaking"), "Matchmaking config missing")
	local rewards = racingConfig:FindFirstChild("Rewards")
	assert(rewards == nil or (rewards:FindFirstChild("TimeTrial") and rewards:FindFirstChild("Race")), "Rewards folder shape looks unexpected")
	local service = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing"):FindFirstChild("RaceMatchmakingService_Active")
	assert(service and service:IsA("Script") and service.Disabled == false, "RaceMatchmakingService_Active missing/disabled")
	local racingClients = racingClientFolder()
	assert(racingClients:FindFirstChild("StartRaceQueueRequest"), "StartRaceQueueRequest missing")
	local queueClient = racingClients:FindFirstChild("RaceQueueClient_Active")
	assert(queueClient and queueClient:IsA("LocalScript") and queueClient.Disabled == false, "RaceQueueClient_Active missing/disabled")
	local entry = racingClients:FindFirstChild("RaceEntryMenuClient_Active")
	assert(entry and string.find(entry.Source, "NTR_RACING_PHASE8_ENTRY_QUEUE_PATCH", 1, true), "RaceEntry menu queue patch missing")
	print("[NTR Racing Phase 8] Smoke passed.")
end

if MODE == "INSTALL" then
	install()
	smoke()
elseif MODE == "SMOKE" then
	smoke()
else
	error("Unknown MODE: " .. tostring(MODE))
end
