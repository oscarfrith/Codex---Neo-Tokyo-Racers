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

-- NTR_RACING_PHASE4_RESULTS_PACK
local personalBests = {}

local MEDAL_ORDER = { "Bronze", "Silver", "Gold", "Platinum" }
local MEDAL_RANK = {
	Finished = 0,
	Bronze = 1,
	Silver = 2,
	Gold = 3,
	Platinum = 4,
}

local function numberOrNil(value)
	value = tonumber(value)
	if value and value > 0 then
		return value
	end
	return nil
end

local function medalRank(name)
	return MEDAL_RANK[tostring(name or "Finished")] or 0
end

local function medalForElapsed(elapsed, medals)
	medals = medals or {}
	local platinum = numberOrNil(medals.Platinum)
	local gold = numberOrNil(medals.Gold)
	local silver = numberOrNil(medals.Silver)
	local bronze = numberOrNil(medals.Bronze)
	if platinum and elapsed <= platinum then
		return "Platinum", platinum
	end
	if gold and elapsed <= gold then
		return "Gold", gold
	end
	if silver and elapsed <= silver then
		return "Silver", silver
	end
	if bronze and elapsed <= bronze then
		return "Bronze", bronze
	end
	return "Finished", nil
end

local function nextMedalTarget(elapsed, medal, medals)
	medals = medals or {}
	local currentRank = medalRank(medal)
	for _, candidate in ipairs(MEDAL_ORDER) do
		local target = numberOrNil(medals[candidate])
		if target and medalRank(candidate) > currentRank then
			return candidate, target, elapsed - target
		end
	end
	if currentRank == 0 then
		local target = numberOrNil(medals.Bronze)
		if target then
			return "Bronze", target, elapsed - target
		end
	end
	return nil, nil, nil
end

local function bestBucket(player, eventId, tier)
	local userId = player.UserId
	personalBests[userId] = personalBests[userId] or {}
	local key = tostring(eventId or "") .. "::" .. string.upper(tostring(tier or ""))
	personalBests[userId][key] = personalBests[userId][key] or {}
	return personalBests[userId][key]
end

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

	local medals = RaceConfigReader.GetTimeTrialMedals(run.EventId, run.VehicleTier)
	local medal, medalTarget = medalForElapsed(elapsed, medals)
	local nextName, nextSeconds, nextDelta = nextMedalTarget(elapsed, medal, medals)
	local bucket = bestBucket(player, run.EventId, run.VehicleTier)
	local previousBest = tonumber(bucket.BestSeconds)
	local isPersonalBest = previousBest == nil or elapsed < previousBest
	if isPersonalBest then
		bucket.BestSeconds = elapsed
		bucket.BestMedal = medal
		bucket.BestVehicleId = run.SelectedVehicleId
		bucket.BestVehicleTier = run.VehicleTier
		bucket.UpdatedClock = os.clock()
	end

	fire(player, {
		Type = "TimeTrialFinished",
		EventId = run.EventId,
		RouteId = run.RouteId,
		DisplayName = run.DisplayName,
		RunId = run.RunId,
		Elapsed = elapsed,
		GateCount = run.GateCount,
		VehicleTier = run.VehicleTier,
		VehicleIndex = run.VehicleIndex,
		SelectedVehicleId = run.SelectedVehicleId,
		Medals = medals,
		Medal = medal,
		MedalRank = medalRank(medal),
		MedalTargetSeconds = medalTarget,
		NextMedalName = nextName,
		NextMedalSeconds = nextSeconds,
		NextMedalDelta = nextDelta,
		PreviousBestSeconds = previousBest,
		PersonalBestSeconds = bucket.BestSeconds,
		PersonalBestMedal = bucket.BestMedal,
		IsPersonalBest = isPersonalBest,
		Splits = run.Splits or {},
		CanRetry = true,
		Message = isPersonalBest and "New personal best!" or "Finished.",
	})
	info(player.Name .. " finished " .. tostring(run.EventId) .. " in " .. string.format("%.3f", elapsed) .. "s medal=" .. tostring(medal) .. " pb=" .. tostring(isPersonalBest))
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

	local splitElapsed = now - run.StartClock
	table.insert(run.Splits, {
		CheckpointIndex = gate.Index,
		Elapsed = splitElapsed,
	})
	run.NextGateIndex += 1
	fire(player, {
		Type = "TimeTrialCheckpoint",
		EventId = run.EventId,
		RouteId = run.RouteId,
		NextGateIndex = run.NextGateIndex,
		GateCount = run.GateCount,
		CheckpointIndex = gate.Index,
		Elapsed = splitElapsed,
		Splits = run.Splits,
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
		Splits = {},
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
	personalBests[player.UserId] = nil
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
