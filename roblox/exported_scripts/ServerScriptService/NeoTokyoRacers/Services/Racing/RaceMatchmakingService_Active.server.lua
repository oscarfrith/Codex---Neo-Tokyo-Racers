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
