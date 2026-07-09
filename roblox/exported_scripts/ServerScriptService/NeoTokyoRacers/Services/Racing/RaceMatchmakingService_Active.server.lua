-- Neo Tokyo Racers - Racing Phase 8 Open-Category Matchmaking Service
-- NTR_RACING_PHASE8_MATCHMAKING_SERVICE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ServerScriptService = game:GetService("ServerScriptService")
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
	local base = item and item.Part and item.Part.CFrame or RouteDefinition.GetFirstSpawnCFrame(route) * CFrame.new((index - 1) * 10, 0, 0)
	local gate = RouteDefinition.GetGate(route, 1)
	if gate and gate.Part then
		local position = base.Position
		local target = Vector3.new(gate.Part.Position.X, position.Y, gate.Part.Position.Z)
		if (target - position).Magnitude > 1 then
			return CFrame.lookAt(position, target)
		end
	end
	return base
end

local function callSessionAssetService(action, payload)
	-- NTR_RACING_PHASE10A_SESSION_ASSET_BRIDGE
	local bindings = script.Parent:FindFirstChild("RaceSessionAssetBindings")
	local binding = bindings and bindings:FindFirstChild("SessionAssets")
	if not (binding and binding:IsA("BindableFunction")) then
		return nil
	end
	local ok, result = pcall(function()
		return binding:Invoke(action, payload or {})
	end)
	if ok then
		return result
	end
	warn("[NTR Racing Phase 10A] Session asset service failed: " .. tostring(result))
	return nil
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
	callSessionAssetService("CreateForRun", {
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		Route = race.Route,
		RouteFolder = race.Route and race.Route.Folder,
		SessionFolder = folder,
		Mode = "Race",
		Participants = race.Participants,
	})
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
		callSessionAssetService("ClearForRun", { RunId = race.RunId })
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
-- NTR_RACING_PHASE8C_SESSION_CONTROL_HELPERS
local function zeroModelVelocity(model)
	for _, descendant in ipairs(model and model:GetDescendants() or {}) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function flatLookCFrame(baseCFrame, targetPosition)
	local position = baseCFrame.Position
	if typeof(targetPosition) ~= "Vector3" then
		return baseCFrame
	end
	local target = Vector3.new(targetPosition.X, position.Y, targetPosition.Z)
	if (target - position).Magnitude < 1 then
		return baseCFrame
	end
	return CFrame.lookAt(position, target)
end

local function firstBasePart(folder)
	for _, item in ipairs(folder and folder:GetChildren() or {}) do
		if item:IsA("BasePart") then
			return item
		end
	end
	return nil
end

local function routeTeleportPoint(route, mode)
	local folder = route and route.Folder
	local points = folder and folder:FindFirstChild("TeleportPoints")
	if not points then return nil end
	mode = tostring(mode or "Race")
	local preferred = points:FindFirstChild(mode .. "TeleportPoint")
		or points:FindFirstChild(mode .. "StartTeleport")
		or points:FindFirstChild("RaceBrowserTeleportPoint")
		or points:FindFirstChild("StartTeleportPoint")
	if preferred and preferred:IsA("BasePart") then
		return preferred
	end
	return firstBasePart(points)
end

local function startCFrameForRoute(route, gateIndex)
	local base = RouteDefinition.GetFirstSpawnCFrame(route)
	local gate = RouteDefinition.GetGate(route, gateIndex or 1)
	if gate and gate.Part then
		return flatLookCFrame(base, gate.Part.Position)
	end
	return base
end

local function returnCFrameForRoute(route, mode)
	local point = routeTeleportPoint(route, mode)
	if point then
		return point.CFrame * CFrame.new(0, 4, 0)
	end
	return startCFrameForRoute(route, 1) * CFrame.new(0, 4, 0)
end

local function resetCFrameForEntry(race, entry)
	-- NTR_RACING_PHASE8D_CHECKPOINT_FACING
	-- Completed-checkpoint resets should use the checkpoint part's authored facing.
	local completedGateIndex = tonumber(entry and entry.LastCompletedGateIndex) or 0
	if completedGateIndex <= 0 then
		return spawnCFrameForIndex(race.Route, entry.GridIndex or 1) * CFrame.new(0, 4, 0)
	end
	local gate = RouteDefinition.GetGate(race.Route, completedGateIndex)
	if gate and gate.Part then
		return gate.Part.CFrame * CFrame.new(0, 4, 0)
	end
	return spawnCFrameForIndex(race.Route, entry.GridIndex or 1) * CFrame.new(0, 4, 0)
end

local function pivotVehicleForRace(player, vehicle, targetCFrame, frozen)
	-- NTR_RACING_PHASE8H_RESPAWN_RESET
	local vehiclesRoot = runtimeVehiclesRoot()
	local root = vehicleRootPart(vehicle)
	if not (vehiclesRoot and vehicle and vehicle.Parent and root) then
		return false, "Vehicle root missing."
	end

	local oldName = vehicle.Name
	local oldArchivable = vehicle.Archivable
	vehicle.Archivable = true
	local replacement = vehicle:Clone()
	vehicle.Archivable = oldArchivable
	if not replacement then
		return false, "Could not clone race vehicle."
	end

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid.PlatformStand = false
	end
	vehicle:SetAttribute("DriverUserId", nil)
	vehicle:SetAttribute("DriveReady", false)
	vehicle:Destroy()

	replacement.Name = oldName
	replacement.Parent = vehiclesRoot
	local replacementRoot = vehicleRootPart(replacement)
	if not replacementRoot then
		replacement:Destroy()
		return false, "Replacement vehicle root missing."
	end
	replacement.PrimaryPart = replacementRoot
	replacement:SetAttribute("NTR_RaceFrozen", false)
	replacement:SetAttribute("DriveReady", false)
	replacement:SetAttribute("DriverUserId", player.UserId)
	replacement:PivotTo(targetCFrame)
	zeroModelVelocity(replacement)
	seatPlayer(player, replacement)
	task.wait(0.08)
	if frozen == true then
		setVehicleFrozen(replacement, true)
		zeroModelVelocity(replacement)
	else
		prepareVehicleForDriving(player, replacement)
		task.delay(0.08, function()
			if replacement and replacement.Parent then
				zeroModelVelocity(replacement)
			end
		end)
		task.delay(0.24, function()
			if replacement and replacement.Parent then
				zeroModelVelocity(replacement)
			end
		end)
	end
	return true, "Vehicle respawned.", replacement
end
local function unseatPlayer(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid.PlatformStand = false
	end
end

local function teleportCharacterTo(player, targetCFrame)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false, "Character root not ready."
	end
	local wasAnchored = root.Anchored
	root.Anchored = true
	zeroModelVelocity(character)
	character:PivotTo(targetCFrame)
	zeroModelVelocity(character)
	task.delay(0.2, function()
		if root and root.Parent then
			root.Anchored = wasAnchored
		end
	end)
	return true, "Teleported."
end

local function destroyVehicleAfterUnseat(player, vehicle)
	if not (vehicle and vehicle.Parent) then return end
	vehicle:SetAttribute("DriverUserId", nil)
	vehicle:SetAttribute("DriveReady", false)
	vehicle:SetAttribute("NTR_RaceRunId", nil)
	vehicle:SetAttribute("NTR_RaceParticipant", nil)
	vehicle:SetAttribute("NTR_RaceMode", nil)
	unseatPlayer(player)
	task.wait(0.08)
	if vehicle and vehicle.Parent then
		vehicle:Destroy()
	end
end

local function entryForPlayer(race, player)
	for _, entry in ipairs(race and race.Participants or {}) do
		if entry.Player == player then
			return entry
		end
	end
	return nil
end

local function fireActiveRaceVisibility(race)
	local participants = {}
	for _, entry in ipairs(race and race.Participants or {}) do
		if entry.Player and entry.DNF ~= true then
			table.insert(participants, entry.Player.UserId)
		end
	end
	raceEvent:FireAllClients({
		Type = "RaceVisibilityUpdate",
		Active = #participants > 0,
		RunId = race and race.RunId or "",
		Participants = participants,
	})
end

local function resetRacePlayer(player)
	local race = activeRaceByPlayer[player]
	local entry = entryForPlayer(race, player)
	if not (race and entry) then
		return { Ok = false, Success = false, Message = "No active race." }
	end
	if entry.Finished == true then
		return { Ok = false, Success = false, Message = "Race already finished." }
	end
	if not (race.State == "Running" or race.State == "Staging") then
		return { Ok = false, Success = false, Message = "Race cannot reset right now." }
	end
	if os.clock() - (entry.LastResetClock or 0) < 1.5 then
		return { Ok = false, Success = false, Message = "Reset is cooling down." }
	end
	entry.LastResetClock = os.clock()
	local ok, message, replacementVehicle = pivotVehicleForRace(player, entry.Vehicle, resetCFrameForEntry(race, entry), race.State == "Staging")
	if ok and replacementVehicle then
		entry.Vehicle = replacementVehicle
	end
	if ok then
		-- NTR_RACING_PHASE10A_RESET_COLLISION_REAPPLY
		callSessionAssetService("ApplyParticipants", {
			RunId = race.RunId,
			Participants = {
				{ Player = player, Vehicle = entry.Vehicle },
			},
		})

		-- NTR_RACING_PHASE10B_RESET_SEGMENT_UPDATE
		callSessionAssetService("UpdateParticipantSegment", {
			RunId = race.RunId,
			UserId = player.UserId,
			CurrentSegment = math.max(0, (tonumber(entry.NextGateIndex) or 1) - 1),
		})		fire(player, {
			Type = "RaceReset",
			RunId = race.RunId,
			EventId = race.EventId,
			RouteId = race.RouteId,
			NextGateIndex = entry.NextGateIndex,
			GateCount = race.GateCount,
			ResetCFrame = resetCFrameForEntry(race, entry), -- NTR_RACING_PHASE8D_RESET_CFRAME_PAYLOAD
			Message = "Reset to last checkpoint.",
		})
		fireRace(player, {
			Type = "RaceReset",
			RunId = race.RunId,
			EventId = race.EventId,
			RouteId = race.RouteId,
			NextGateIndex = entry.NextGateIndex,
			GateCount = race.GateCount,
			ResetCFrame = resetCFrameForEntry(race, entry), -- NTR_RACING_PHASE8D_RESET_CFRAME_PAYLOAD
		})
	end
	return { Ok = ok, Success = ok, Message = message }
end

local function exitRacePlayer(player)
	local race = activeRaceByPlayer[player]
	local entry = entryForPlayer(race, player)
	if not (race and entry) then
		return { Ok = false, Success = false, Message = "No active race." }
	end
	entry.Finished = true
	entry.DNF = true
	activeRaceByPlayer[player] = nil
	local target = returnCFrameForRoute(race.Route, "Race")
	fire(player, {
		Type = "RaceDNF",
		RunId = race.RunId,
		EventId = race.EventId,
		Message = "Exited race.",
	})
	fireRace(player, {
		Type = "RaceEnded",
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		Reason = "Exited race",
	})
	destroyVehicleAfterUnseat(player, entry.Vehicle)
	entry.Vehicle = nil
	teleportCharacterTo(player, target)
	fireActiveRaceVisibility(race)
	broadcastPositions(race)
	if allFinished(race) then
		cleanupRace(race, "All racers finished or exited.")
	end
	return { Ok = true, Success = true, Message = "Exited to race start." }
end


local function callRaceRewardService(action, payload)
	-- NTR_RACING_PHASE11A_RACE_REWARD_BRIDGE_CANONICAL
	local bindings = script.Parent:FindFirstChild("RaceRewardBindings")
	local binding = bindings and bindings:FindFirstChild("GrantRaceReward")
	if not (binding and binding:IsA("BindableFunction")) then
		return nil
	end
	local ok, result = pcall(function()
		return binding:Invoke(action, payload or {})
	end)
	if ok then
		return result
	end
	warn("[NTR Racing Phase 11A] Race reward service failed: " .. tostring(result))
	return nil
end


local function finishEntry(race, entry)
	-- NTR_RACING_PHASE11A_FINISH_ENTRY_CANONICAL
	if entry.Finished then return end
	entry.Finished = true
	entry.FinishElapsed = now() - race.StartClock
	entry.FinishPlace = race.NextFinishPlace
	race.NextFinishPlace += 1
	local rewardResult = callRaceRewardService("GrantRaceReward", {
		Player = entry.Player,
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		Place = entry.FinishPlace,
		ParticipantCount = #race.Participants,
		Elapsed = entry.FinishElapsed,
	}) or {}
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
		RaceMedal = rewardResult.Medal,
		RewardGranted = rewardResult.Granted == true,
		RewardAmount = tonumber(rewardResult.Amount) or 0,
		RewardMessage = tostring(rewardResult.Message or ""),
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
	entry.LastCompletedGateIndex = entry.NextGateIndex
	entry.NextGateIndex += 1

	-- NTR_RACING_PHASE10B_CHECKPOINT_SEGMENT_UPDATE
	callSessionAssetService("UpdateParticipantSegment", {
		RunId = race.RunId,
		UserId = entry.Player.UserId,
		CurrentSegment = math.max(0, (tonumber(entry.NextGateIndex) or 1) - 1),
	})	fire(entry.Player, {
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

-- NTR_RACING_PHASE11C_SERVER_GRID_SPAWN_HELPERS
-- NTR_RACING_PHASE11C_BINDING_LOOKUP_REPAIR
local function getRaceVehicleSpawner()
	local okService, serverScriptService = pcall(function()
		return game:GetService("ServerScriptService")
	end)
	if not okService or not serverScriptService then
		return nil, "ServerScriptService unavailable."
	end
	local serverRoot = serverScriptService:FindFirstChild("NeoTokyoRacers")
	if not serverRoot then
		return nil, "NeoTokyoRacers server root missing."
	end
	local services = serverRoot:FindFirstChild("Services")
	if not services then
		return nil, "NeoTokyoRacers services folder missing."
	end
	local garage = services:FindFirstChild("Garage")
	if not garage then
		return nil, "Garage services folder missing."
	end
	local action = garage:FindFirstChild("GarageActionController_Shadow_Disabled")
	if not action then
		return nil, "Garage action controller missing."
	end
	local binding = action:FindFirstChild("RaceVehicleSpawner")
	if binding and binding:IsA("BindableFunction") then
		return binding, nil
	end
	return nil, "RaceVehicleSpawner binding missing. Run Phase 11C in Edit mode, then restart Play."
end

local function invokeRaceVehicleSpawner(action, payload)
	local binding, bindingError = getRaceVehicleSpawner()
	if not binding then
		return { Ok = false, Success = false, Message = bindingError or "Race vehicle spawner is not ready." }
	end
	local ok, result = pcall(function()
		return binding:Invoke(action, payload or {})
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Success = false, Message = "Race vehicle spawner failed: " .. tostring(result) }
end

local function validateRaceVehicleForPlayer(player, vehicleId, cockpitId)
	local result = invokeRaceVehicleSpawner("ValidateForRace", {
		Player = player,
		VehicleId = vehicleId,
		CockpitId = cockpitId,
	})
	if result.Ok == true or result.Success == true then
		return true, result.Message or "Vehicle ready.", result.VehicleId
	end
	return false, result.Message or "Selected vehicle is not ready."
end

local function spawnRaceVehicleForPlayer(player, vehicleId, cockpitId, spawnCFrame)
	local result = invokeRaceVehicleSpawner("SpawnForRace", {
		Player = player,
		VehicleId = vehicleId,
		CockpitId = cockpitId,
		SpawnCFrame = spawnCFrame,
	})
	if (result.Ok == true or result.Success == true) and result.Vehicle then
		return result.Vehicle, nil, result.VehicleId
	end
	return nil, result.Message or "Could not spawn selected vehicle at grid.", result.VehicleId
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
		local gridIndex = #participants + 1
		local selectedVehicleId = tostring(queue.VehicleIds[player] or "")
		local spawnCFrame = spawnCFrameForIndex(queue.Route, gridIndex) * CFrame.new(0, 4, 0)
		local vehicle, vehicleError, spawnedVehicleId = spawnRaceVehicleForPlayer(player, selectedVehicleId, nil, spawnCFrame)
		if vehicle then
			table.insert(participants, {
				Player = player,
				Vehicle = vehicle,
				SelectedVehicleId = tostring(spawnedVehicleId or selectedVehicleId or ""),
				NextGateIndex = 1,
				LastCompletedGateIndex = 0,
				GridIndex = gridIndex,
				LastTouchClock = 0,
				LastProgressElapsed = 0,
			})
		else
			fire(player, {
				Type = "RaceQueueError",
				EventId = queue.EventId,
				Message = vehicleError or "Could not spawn selected vehicle at race grid.",
			})
		end
	end -- NTR_RACING_PHASE11C_RACE_GRID_SPAWN

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
	local selectedOk, selectedMessage, selectedVehicleId = validateRaceVehicleForPlayer(player, vehicleId, nil)
	if not selectedOk then
		return false, selectedMessage
	end
	local summary, route, eventError = raceEventSummary(eventId) -- NTR_RACING_PHASE11C_JOIN_VALIDATE_SELECTED
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
	queue.VehicleIds[player] = tostring(selectedVehicleId or vehicleId or "")
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
	elseif action == "ResetToLastCheckpoint" then
		return resetRacePlayer(player)
	elseif action == "ExitRaceToStart" then
		return exitRacePlayer(player)
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
