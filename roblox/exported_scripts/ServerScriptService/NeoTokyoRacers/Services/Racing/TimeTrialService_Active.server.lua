-- NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP
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
-- NTR_RACING_PHASE6_REWARD_HELPERS
local function getRaceRewardBinding()
	local serverRoot = game:GetService("ServerScriptService"):FindFirstChild("NeoTokyoRacers")
	local services = serverRoot and serverRoot:FindFirstChild("Services")
	local racing = services and services:FindFirstChild("Racing")
	local bindings = racing and racing:FindFirstChild("RaceRewardBindings")
	local grant = bindings and bindings:FindFirstChild("GrantTimeTrialReward")
	if grant and grant:IsA("BindableFunction") then
		return grant
	end
	return nil
end

local function grantTimeTrialReward(player, run, elapsed, medal, isPersonalBest)
	local grant = getRaceRewardBinding()
	if not grant then
		return { Ok = false, Granted = false, Amount = 0, Message = "Reward service unavailable." }
	end
	local ok, result = pcall(function()
		return grant:Invoke("GrantTimeTrialReward", {
			Player = player,
			RunId = run.RunId,
			EventId = run.EventId,
			RouteId = run.RouteId,
			DisplayName = run.DisplayName,
			VehicleTier = run.VehicleTier,
			VehicleIndex = run.VehicleIndex,
			SelectedVehicleId = run.SelectedVehicleId,
			Elapsed = elapsed,
			Medal = medal,
			IsPersonalBest = isPersonalBest == true,
		})
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Granted = false, Amount = 0, Message = "Reward grant failed: " .. tostring(result) }
end

-- NTR_RACING_PHASE11M_PERSISTENT_PB_HELPERS
local function getPersonalBestBinding(name)
	local bindings = script.Parent:FindFirstChild("RacePersonalBestBindings")
	local binding = bindings and bindings:FindFirstChild(name)
	if binding and binding:IsA("BindableFunction") then
		return binding
	end
	return nil
end

-- NTR_RACING_UI_PHASE9A_PB_TO_GLOBAL_BRIDGE
local function globalLeaderboardBinding(name)
	local folder = script.Parent:FindFirstChild("GlobalTimeTrialLeaderboardBindings")
	local binding = folder and folder:FindFirstChild(name)
	return binding and binding:IsA("BindableFunction") and binding or nil
end

local function recordPersistentPersonalBest(player, run, elapsed, medal)
	local binding = getPersonalBestBinding("RecordTimeTrialBest")
	if not binding then return nil end
	local ok, result = pcall(function()
		return binding:Invoke(player, { RunId = run.RunId, EventId = run.EventId, RouteId = run.RouteId, DisplayName = run.DisplayName, VehicleTier = run.VehicleTier, VehicleIndex = run.VehicleIndex, SelectedVehicleId = run.SelectedVehicleId, Elapsed = elapsed, Medal = medal })
	end)
	if ok and typeof(result) == "table" then
		if result.IsPersonalBest == true then
			local global = globalLeaderboardBinding("RecordTimeTrialBest")
			if global then task.spawn(function() pcall(function() global:Invoke(player, { EventId = run.EventId, VehicleTier = run.VehicleTier, BestSeconds = result.PersonalBestSeconds or elapsed, VehicleId = result.PersonalBestVehicleId or run.SelectedVehicleId, VehicleName = tostring(run.Vehicle and (run.Vehicle:GetAttribute("DisplayName") or run.Vehicle:GetAttribute("CockpitId") or run.Vehicle.Name) or "") }) end) end) end
		end
		return result
	end
	return { Ok = false, Message = "Persistent PB service failed: " .. tostring(result) }
end

-- NTR_RACING_PHASE11N_PB_READOUT_SERVER
local function getPersistentPersonalBest(player, eventId, vehicleTier)
	local binding = getPersonalBestBinding("GetTimeTrialBest")
	if not binding then
		return { Ok = false, Found = false, Message = "Personal best service unavailable." }
	end
	local ok, result = pcall(function()
		return binding:Invoke(player, {
			EventId = tostring(eventId or ""),
			VehicleTier = tostring(vehicleTier or ""),
		})
	end)
	if ok and typeof(result) == "table" then
		result.EventId = tostring(eventId or "")
		result.VehicleTier = tostring(vehicleTier or "")
		return result
	end
	return { Ok = false, Found = false, Message = "Personal best lookup failed: " .. tostring(result), EventId = tostring(eventId or ""), VehicleTier = tostring(vehicleTier or "") }
end


local PHASE = "NTR Racing Phase 3"
local OLD_PROMPT_NAME = "NTR_TimeTrialStartPrompt"
local PROMPT_NAME = "NTR_RaceEntryPrompt"
local flowUI=kit.Config.Racing:WaitForChild("FlowUI")
local countdownValue=flowUI:WaitForChild("CountdownSeconds")
local COUNTDOWN_SECONDS=math.max(1,math.floor(tonumber(countdownValue.Value) or 5))
local STAGING_READY_TIMEOUT_SECONDS = 18 -- NTR_RACING_STAGING_READINESS_GATE_V1
local COUNTDOWN_VISIBLE_TIMEOUT_SECONDS = 8

local activeRuns = {}
local activeRunsById = {}
local finishedRunsByPlayer = {} -- NTR_RACING_PHASE11K_TT_FINISHED_EXIT_CLEANUP
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
	callSessionAssetService("CreateForRun", {
		RunId = run.RunId,
		EventId = run.EventId,
		RouteId = run.RouteId,
		Route = run.Route,
		RouteFolder = run.Route and run.Route.Folder,
		SessionFolder = folder,
		Mode = "TimeTrial",
		Participants = {
			{ Player = run.Player, Vehicle = run.Vehicle },
		},
	})
	return folder
end

local function clearSessionFolder(run)
	local folder = run and run.SessionFolder
	if folder and folder.Parent then
		callSessionAssetService("ClearForRun", { RunId = run.RunId })
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
	mode = tostring(mode or "TimeTrial")
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

local function resetCFrameForRun(run)
	-- NTR_RACING_PHASE8D_CHECKPOINT_FACING
	-- Completed-checkpoint resets should use the checkpoint part's authored facing.
	local completedGateIndex = tonumber(run and run.LastCompletedGateIndex) or 0
	if completedGateIndex <= 0 then
		return startCFrameForRoute(run.Route, 1) * CFrame.new(0, 4, 0)
	end
	local gate = RouteDefinition.GetGate(run.Route, completedGateIndex)
	if gate and gate.Part then
		return gate.Part.CFrame * CFrame.new(0, 4, 0)
	end
	return startCFrameForRoute(run.Route, 1) * CFrame.new(0, 4, 0)
end

local function pivotVehicleForSession(player, vehicle, targetCFrame, frozen)
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
	vehicle:SetAttribute("NTR_RaceFinishedPendingExit", nil) -- NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY
	unseatPlayer(player)
	task.wait(0.08)
	if vehicle and vehicle.Parent then
		vehicle:Destroy()
	end
end

local function cleanupPendingFinishedVehiclesForPlayer(player)
	-- NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY
	local root = runtimeVehiclesRoot()
	local cleaned = 0
	for _, vehicle in ipairs(root and root:GetChildren() or {}) do
		local ownerMatches = tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId
		local pendingFinished = vehicle:GetAttribute("NTR_RaceFinishedPendingExit") == true
		local orphanGridVehicle = vehicle:GetAttribute("NTR_RaceGridSpawned") == true
			and vehicle:GetAttribute("NTR_RaceRunId") == nil
			and vehicle:GetAttribute("NTR_RaceParticipant") ~= true
		if ownerMatches and (pendingFinished or orphanGridVehicle) then
			cleaned += 1
			destroyVehicleAfterUnseat(player, vehicle)
		end
	end
	return cleaned
end

local function clearFinishedRunForPlayer(player)
	finishedRunsByPlayer[player] = nil
end

local function storeFinishedRunForExit(player, run)
	if not (player and run) then return end
	finishedRunsByPlayer[player] = run
end

local function exitFinishedTimeTrial(player)
	-- NTR_RACING_PHASE11K_TT_FINISHED_EXIT_CLEANUP
	-- NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY
	local run = finishedRunsByPlayer[player]
	if not run then
		local cleaned = cleanupPendingFinishedVehiclesForPlayer(player)
		if cleaned > 0 then
			fire(player, {
				Type = "TimeTrialEnded",
				Reason = "Recovered stale finished time trial",
			})
		end
		return {
			Ok = true,
			Success = true,
			Message = cleaned > 0 and "Recovered stale finished time trial cleanup." or "No finished time trial cleanup pending.",
		}
	end
	finishedRunsByPlayer[player] = nil
	fireVisibility(run, false)
	clearSessionFolder(run)
	local target = returnCFrameForRoute(run.Route, "TimeTrial")
	destroyVehicleAfterUnseat(player, run.Vehicle)
	local ok, message = teleportCharacterTo(player, target)
	fire(player, {
		Type = "TimeTrialEnded",
		RunId = run.RunId,
		EventId = run.EventId,
		RouteId = run.RouteId,
		Reason = "Exited results",
	})
	return {
		Ok = ok == true,
		Success = ok == true,
		Message = ok and "Exited to race start." or tostring(message or "Exit cleanup failed."),
	}
end

local function resetActiveTimeTrial(player)
	local run = activeRuns[player]
	if not run then
		return { Ok = false, Success = false, Message = "No active time trial." }
	end
	if not (run.State == "Running" or run.State == "Staging") then
		return { Ok = false, Success = false, Message = "Time trial cannot reset right now." }
	end
	if os.clock() - (run.LastResetClock or 0) < 1.5 then
		return { Ok = false, Success = false, Message = "Reset is cooling down." }
	end
	run.LastResetClock = os.clock()
	local ok, message, replacementVehicle = pivotVehicleForSession(player, run.Vehicle, resetCFrameForRun(run), run.State == "Staging")
	if ok and replacementVehicle then
		run.Vehicle = replacementVehicle
	end
	if ok then
		-- NTR_RACING_PHASE10A_RESET_COLLISION_REAPPLY
		callSessionAssetService("ApplyParticipants", {
			RunId = run.RunId,
			Participants = {
				{ Player = player, Vehicle = run.Vehicle },
			},
		})

		-- NTR_RACING_PHASE10B_RESET_SEGMENT_UPDATE
		callSessionAssetService("UpdateParticipantSegment", {
			RunId = run.RunId,
			UserId = player.UserId,
			CurrentSegment = math.max(0, (tonumber(run.NextGateIndex) or 1) - 1),
		})		fire(player, {
			Type = "TimeTrialReset",
			RunId = run.RunId,
			EventId = run.EventId,
			RouteId = run.RouteId,
			NextGateIndex = run.NextGateIndex,
			GateCount = run.GateCount,
			ResetCFrame = resetCFrameForRun(run), -- NTR_RACING_PHASE8D_RESET_CFRAME_PAYLOAD
			Message = "Reset to last checkpoint.",
		})
	end
	return { Ok = ok, Success = ok, Message = message }
end

local sendTimeTrialResult
local function exitActiveTimeTrial(player)
	-- NTR_RACING_PHASE9A_QUIT_WITH_BEST_LAP_RESULT
	local run = activeRuns[player]
	if not run then
		return { Ok = false, Success = false, Message = "No active time trial." }
	end
	activeRuns[player] = nil
	activeRunsById[run.RunId] = nil
	if run.Vehicle then
		setVehicleFrozen(run.Vehicle, false)
	end
	fireVisibility(run, false)
	clearSessionFolder(run)
	if run.BestLapSeconds then
		sendTimeTrialResult(player, run, run.BestLapSeconds, "Quit", true)
	else
		fire(player, {
			Type = "TimeTrialEnded",
			RunId = run.RunId,
			EventId = run.EventId,
			RouteId = run.RouteId,
			Reason = "Exited to start",
		})
	end
	local target = returnCFrameForRoute(run.Route, "TimeTrial")
	destroyVehicleAfterUnseat(player, run.Vehicle)
	teleportCharacterTo(player, target)
	return { Ok = true, Success = true, Message = run.BestLapSeconds and "Session complete." or "Exited to race start." }
end


local function stageVehicle(player, vehicle, route)
	local root = vehicleRootPart(vehicle)
	if not root then
		return false, "Vehicle root missing."
	end
	local stageCFrame = startCFrameForRoute(route, 1)
	vehicle.PrimaryPart = root
	vehicle:PivotTo(stageCFrame * CFrame.new(0, 4, 0))
	vehicle:SetAttribute("ParkedShowcase", nil)
	vehicle:SetAttribute("DriverUserId", player.UserId)
	seatPlayer(player, vehicle)
	task.wait(0.08)
	setVehicleFrozen(vehicle, true)
	return true
end

local function endRun(player, reason)
	clearFinishedRunForPlayer(player)
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

sendTimeTrialResult = function(player, run, elapsed, finishReason, canRetry)
	-- NTR_RACING_PHASE9A_SESSION_RESULT
	elapsed = tonumber(elapsed) or 0
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

	local persistentBest = recordPersistentPersonalBest(player, run, elapsed, medal)
	if persistentBest and persistentBest.Ok == true then
		previousBest = tonumber(persistentBest.PreviousBestSeconds)
		isPersonalBest = persistentBest.IsPersonalBest == true
		bucket.BestSeconds = tonumber(persistentBest.PersonalBestSeconds) or bucket.BestSeconds
		bucket.BestMedal = persistentBest.PersonalBestMedal or bucket.BestMedal
		bucket.BestVehicleId = persistentBest.PersonalBestVehicleId or bucket.BestVehicleId
	end

	local reward = grantTimeTrialReward(player, run, elapsed, medal, isPersonalBest)

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
		LapTimes = run.LapTimes or {},
		BestLapSeconds = run.BestLapSeconds,
		BestLapIndex = run.BestLapIndex,
		CompletedLapCount = run.CompletedLapCount or 0,
		CurrentLap = run.CurrentLap or 1,
		LapTarget = run.LapTarget or 1,
		RouteType = run.RouteType or "Circuit",
		FinishReason = finishReason or "Finished",
		CanRetry = canRetry ~= false,
		RewardGranted = reward.Granted == true,
		RewardAmount = tonumber(reward.Amount) or 0,
		RewardCash = reward.Cash,
		RewardMessage = reward.Message,
		Message = (reward.Granted == true and ("Best session result!  $" .. tostring(reward.Amount or 0) .. " earned")) or (isPersonalBest and "New personal best!" or tostring(reward.Message or "Finished.")),
	})
	info(player.Name .. " finished " .. tostring(run.EventId) .. " result=" .. string.format("%.3f", elapsed) .. "s reason=" .. tostring(finishReason or "Finished") .. " medal=" .. tostring(medal) .. " pb=" .. tostring(isPersonalBest))
end

local function finishRun(player, resultElapsed, finishReason)
	-- NTR_RACING_PHASE9A_FINISH_BEST_SESSION_RESULT
	local run = activeRuns[player]
	if not run then return end
	clearFinishedRunForPlayer(player)
	local elapsed = tonumber(resultElapsed) or run.BestLapSeconds or (os.clock() - run.StartClock)
	activeRuns[player] = nil
	activeRunsById[run.RunId] = nil
	if run.Vehicle then
		-- NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY
		-- A finished time-trial vehicle is pending result-exit cleanup, not a
		-- normal free-roam car. Keep it still/unusable and unseat the player so
		-- camera, HUD, race-browser teleport, and future entry prompts recover
		-- even if the result panel exit is clicked late or twice.
		setVehicleFrozen(run.Vehicle, true)
		run.Vehicle:SetAttribute("NTR_RaceRunId", run.RunId)
		run.Vehicle:SetAttribute("NTR_RaceParticipant", true)
		run.Vehicle:SetAttribute("NTR_RaceMode", "TimeTrialFinished")
		run.Vehicle:SetAttribute("NTR_RaceFinishedPendingExit", true)
		run.Vehicle:SetAttribute("DriverUserId", nil)
		run.Vehicle:SetAttribute("DriveReady", false)
		run.Vehicle:SetAttribute("EngineVFXActive", false)
		unseatPlayer(player)
	end
	fireVisibility(run, false)
	clearSessionFolder(run)
	storeFinishedRunForExit(player, run)
	sendTimeTrialResult(player, run, elapsed, finishReason or "Finished", true)
end


local function advanceCheckpoint(player, touchedPart)
	-- NTR_RACING_PHASE9A_LAP_ADVANCE
	local run = activeRuns[player]
	if not (run and run.State == "Running") then return end
	local gate = RouteDefinition.GetGate(run.Route, run.NextGateIndex)
	if not (gate and gate.Part == touchedPart) then return end
	local now = os.clock()
	if now - (run.LastTouchClock or 0) < 0.12 then return end
	run.LastTouchClock = now

	if gate.IsFinish then
		if tostring(run.RouteType or "Circuit") == "Circuit" then
			local lapElapsed = now - (run.LapStartedClock or run.StartClock or now)
			run.CompletedLapCount = (run.CompletedLapCount or 0) + 1
			run.LapTimes = run.LapTimes or {}
			table.insert(run.LapTimes, {
				Lap = run.CompletedLapCount,
				Elapsed = lapElapsed,
			})
			if not run.BestLapSeconds or lapElapsed < run.BestLapSeconds then
				run.BestLapSeconds = lapElapsed
				run.BestLapIndex = run.CompletedLapCount
			end
			run.LastCompletedGateIndex = run.NextGateIndex
			fire(player, {
				Type = "TimeTrialLapCompleted",
				EventId = run.EventId,
				RouteId = run.RouteId,
				RunId = run.RunId,
				Lap = run.CompletedLapCount,
				NextLap = run.CompletedLapCount + 1,
				LapTarget = run.LapTarget or 1,
				InfiniteLaps = (run.LapTarget or 1) == 0,
				Elapsed = lapElapsed,
				BestLapSeconds = run.BestLapSeconds,
				BestLapIndex = run.BestLapIndex,
				GateCount = run.GateCount,
				NextGateIndex = 1,
			})
			if (run.LapTarget or 1) > 0 and run.CompletedLapCount >= run.LapTarget then
				finishRun(player, run.BestLapSeconds or lapElapsed, "LapTarget")
				return
			end
			run.CurrentLap = run.CompletedLapCount + 1
			run.LapStartedClock = now
			run.NextGateIndex = 1
			run.LastCompletedGateIndex = 0
			run.Splits = {}

			-- NTR_RACING_PHASE10B_LAP_SEGMENT_UPDATE
			callSessionAssetService("UpdateParticipantSegment", {
				RunId = run.RunId,
				UserId = player.UserId,
				CurrentSegment = 0,
			})			fire(player, {
				Type = "TimeTrialCheckpoint",
				EventId = run.EventId,
				RouteId = run.RouteId,
				NextGateIndex = run.NextGateIndex,
				GateCount = run.GateCount,
				CheckpointIndex = gate.Index,
				Elapsed = lapElapsed,
				Splits = run.Splits,
				CurrentLap = run.CurrentLap,
				LapTarget = run.LapTarget or 1,
				InfiniteLaps = (run.LapTarget or 1) == 0,
			})
			return
		end
		finishRun(player, nil, "PointToPoint")
		return
	end

	local splitElapsed = now - (run.LapStartedClock or run.StartClock or now)
	table.insert(run.Splits, {
		CheckpointIndex = gate.Index,
		Elapsed = splitElapsed,
		Lap = run.CurrentLap or 1,
	})
	run.LastCompletedGateIndex = run.NextGateIndex
	run.NextGateIndex += 1

	-- NTR_RACING_PHASE10B_CHECKPOINT_SEGMENT_UPDATE
	callSessionAssetService("UpdateParticipantSegment", {
		RunId = run.RunId,
		UserId = player.UserId,
		CurrentSegment = math.max(0, (tonumber(run.NextGateIndex) or 1) - 1),
	})	fire(player, {
		Type = "TimeTrialCheckpoint",
		EventId = run.EventId,
		RouteId = run.RouteId,
		NextGateIndex = run.NextGateIndex,
		GateCount = run.GateCount,
		CheckpointIndex = gate.Index,
		Elapsed = splitElapsed,
		Splits = run.Splits,
		CurrentLap = run.CurrentLap or 1,
		LapTarget = run.LapTarget or 1,
		InfiniteLaps = (run.LapTarget or 1) == 0,
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

local function beginStagedTimeTrial(player, eventId, vehicleId, requestedLapCount)
	-- NTR_RACING_PHASE9A_BEGIN_SESSION
	clearFinishedRunForPlayer(player)
	eventId = resolveTimeTrialEventId(eventId)
	if activeRuns[player] then
		return false, "Already in a race/time trial."
	end
	local route, routeError = RaceConfigReader.GetRouteForEvent(eventId, "TimeTrial")
	if not route then
		return false, routeError
	end
	if RouteDefinition.GetGateCount(route) < 2 then
		return false, "Route needs checkpoints and a finish line."
	end
	local summary = RaceConfigReader.GetEventSummary(eventId, "TimeTrial") or {}
	local routeType = tostring(summary.RouteType or route.RouteType or "Circuit")
	if routeType ~= "PointToPoint" then
		routeType = "Circuit"
	end
	local maxLapCount = math.clamp(tonumber(summary.MaxLapCount) or 10, 1, 10)
	local minLapCount = math.clamp(tonumber(summary.MinLapCount) or 1, 1, maxLapCount)
	local lapTarget = tonumber(requestedLapCount)
	if routeType == "PointToPoint" then
		lapTarget = 1
	elseif lapTarget == 0 and summary.AllowInfiniteLaps == true then
		lapTarget = 0
	else
		lapTarget = math.clamp(math.floor(lapTarget or tonumber(summary.DefaultLapCount) or 1), minLapCount, maxLapCount)
	end
	local stageCFrame = startCFrameForRoute(route, 1) * CFrame.new(0, 4, 0)
	local vehicle, vehicleError, selectedVehicleId = spawnRaceVehicleForPlayer(player, vehicleId, nil, stageCFrame)
	if not vehicle then
		return false, vehicleError
	end
	local tier = tostring(vehicle:GetAttribute("PerformanceTier") or "") -- NTR_RACING_PHASE11C_TT_GRID_SPAWN
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
		RouteType = routeType,
		LapTarget = lapTarget,
		CurrentLap = 1,
		CompletedLapCount = 0,
		LapTimes = {},
		Vehicle = vehicle,
		SelectedVehicleId = tostring(selectedVehicleId or vehicleId or ""),
		VehicleTier = tier,
		VehicleIndex = index,
		NextGateIndex = 1,
		LastCompletedGateIndex = 0,
		GateCount = RouteDefinition.GetGateCount(route),
		Splits = {},
		Readiness = { AssetsReady = false, CountdownVisible = false },
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
		RouteType = routeType,
		LapTarget = lapTarget,
		CurrentLap = 1,
		InfiniteLaps = lapTarget == 0,
		StreamPosition = stageCFrame.Position,
	})

	task.spawn(function()
		local assetsDeadline = os.clock() + STAGING_READY_TIMEOUT_SECONDS
		while os.clock() < assetsDeadline do
			local live = activeRuns[player]
			if not (live and live.RunId == runId and live.State == "Staging") then return end
			if live.Readiness and live.Readiness.AssetsReady == true then break end
			task.wait(0.05)
		end
		local live = activeRuns[player]
		if not (live and live.RunId == runId and live.State == "Staging") then return end
		if not (live.Readiness and live.Readiness.AssetsReady == true) then
			fire(player, { Type = "TimeTrialError", RunId = runId, EventId = eventId, Message = "Race start readiness timed out." })
			endRun(player, "Race start readiness timed out.")
			return
		end

		fire(player, {
			Type = "TimeTrialCountdownReveal",
			RunId = runId,
			EventId = eventId,
			RouteId = route.RouteId,
			DisplayName = run.DisplayName,
			Countdown = COUNTDOWN_SECONDS,
		})

		local visibleDeadline = os.clock() + COUNTDOWN_VISIBLE_TIMEOUT_SECONDS
		while os.clock() < visibleDeadline do
			live = activeRuns[player]
			if not (live and live.RunId == runId and live.State == "Staging") then return end
			if live.Readiness and live.Readiness.CountdownVisible == true then break end
			task.wait(0.05)
		end
		live = activeRuns[player]
		if not (live and live.RunId == runId and live.State == "Staging") then return end
		if not (live.Readiness and live.Readiness.CountdownVisible == true) then
			fire(player, { Type = "TimeTrialError", RunId = runId, EventId = eventId, Message = "Countdown presentation readiness timed out." })
			endRun(player, "Countdown presentation readiness timed out.")
			return
		end

		local goAt = Workspace:GetServerTimeNow() + COUNTDOWN_SECONDS
		fire(player, {
			Type = "TimeTrialCountdownScheduled",
			RunId = runId,
			EventId = eventId,
			RouteId = route.RouteId,
			DisplayName = run.DisplayName,
			Countdown = COUNTDOWN_SECONDS,
			GoAtServerTime = goAt,
		})
		while Workspace:GetServerTimeNow() < goAt do
			live = activeRuns[player]
			if not (live and live.RunId == runId and live.State == "Staging") then return end
			task.wait(0.03)
		end

		live = activeRuns[player]
		if not (live and live.RunId == runId and live.State == "Staging") then return end
		local currentVehicle, currentError = currentVehicleForPlayer(player)
		if currentVehicle ~= vehicle then
			endRun(player, currentError or "Vehicle changed before start.")
			return
		end
		live.State = "Running"
		live.StartClock = os.clock()
		live.LapStartedClock = live.StartClock
		live.LastTouchClock = 0
		prepareVehicleForDriving(player, vehicle)
		fire(player, {
			Type = "TimeTrialStarted",
			RunId = runId,
			EventId = eventId,
			RouteId = route.RouteId,
			DisplayName = run.DisplayName,
			StartServerClock = live.StartClock,
			StartServerTime = goAt,
			GateCount = run.GateCount,
			NextGateIndex = 1,
			RouteType = routeType,
			LapTarget = lapTarget,
			CurrentLap = 1,
			InfiniteLaps = lapTarget == 0,
		})
	end)

	return true, lapTarget == 0 and "Staging infinite time trial." or ("Staging " .. tostring(lapTarget) .. "-lap time trial.")
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
	-- NTR_RACING_PHASE11Y_TT_FINISH_LIFECYCLE_RECOVERY
	-- If a previous result-exit click was missed, pressing the start prompt is
	-- allowed to self-heal before opening the next entry menu.
	if finishedRunsByPlayer[player] then
		exitFinishedTimeTrial(player)
	else
		cleanupPendingFinishedVehiclesForPlayer(player)
	end
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
	if action == "AcknowledgeStagingReady" then
		local run = activeRuns[player]
		if not (run and run.State == "Staging" and tostring(payload.RunId or "") == run.RunId) then
			return { Ok = false, Success = false, Message = "Stale or invalid time-trial readiness acknowledgement." }
		end
		local phase = tostring(payload.Phase or "")
		if phase ~= "AssetsReady" and phase ~= "CountdownVisible" then
			return { Ok = false, Success = false, Message = "Invalid readiness phase." }
		end
		run.Readiness = run.Readiness or {}
		run.Readiness[phase] = true
		if payload.Degraded == true then warn(("[NTR Race Readiness] Time trial %s reported degraded %s readiness: %s"):format(run.RunId, phase, tostring(payload.Detail or ""))) end
		return { Ok = true, Success = true, RunId = run.RunId, Phase = phase }
	elseif action == "GetEntryDetails" then
		local mode = tostring(payload.Mode or "TimeTrial")
		local eventId = tostring(payload.EventId or (mode == "Race" and "shifted_canal_sprint_race" or "shifted_canal_sprint_tt"))
		local summary, summaryError = RaceConfigReader.GetEventSummary(eventId, mode)
		if not summary then
			return { Ok = false, Message = summaryError or "Event unavailable." }
		end
		return { Ok = true, Summary = summary }
	elseif action == "GetTimeTrialPersonalBest" then
		local eventId = tostring(payload.EventId or "shifted_canal_sprint_tt")
		local vehicleTier = string.upper(tostring(payload.VehicleTier or ""))
		local summary, summaryError = RaceConfigReader.GetEventSummary(eventId, "TimeTrial")
		if not summary then
			return { Ok = false, Found = false, Message = summaryError or "Time trial event unavailable." }
		end
		if vehicleTier == "" or vehicleTier == "--" then
			return { Ok = true, Found = false, Message = "Choose a vehicle tier to view PB.", EventId = eventId, VehicleTier = vehicleTier }
		end
		return getPersistentPersonalBest(player, eventId, vehicleTier)
	elseif action == "GetTimeTrialLeaderboard" then
		-- NTR_RACING_UI_PHASE9A_GLOBAL_READ_ACTION
		local binding = globalLeaderboardBinding("GetTimeTrialLeaderboard")
		if not binding then return { Ok = false, Available = false, Entries = {}, Message = "Global leaderboard service unavailable." } end
		local ok, result = pcall(function() return binding:Invoke(player, payload) end)
		return ok and typeof(result) == "table" and result or { Ok = false, Available = false, Entries = {}, Message = tostring(result) }
	elseif action == "StartStagedTimeTrial" then
		local eventId = tostring(payload.EventId or "shifted_canal_sprint_tt")
		local ok, message = beginStagedTimeTrial(player, eventId, payload.VehicleId, payload.LapCount)
		return { Ok = ok, Success = ok, Message = message }
	elseif action == "StartTimeTrial" then
		local eventId = tostring(payload.EventId or "shifted_canal_sprint_tt")
		local ok, message = beginStagedTimeTrial(player, eventId, payload.VehicleId, payload.LapCount)
		return { Ok = ok, Success = ok, Message = message }
	elseif action == "CancelTimeTrial" then
		if activeRuns[player] then
			endRun(player, "Cancelled")
			return { Ok = true, Success = true, Message = "Cancelled" }
		end
		return exitFinishedTimeTrial(player)
	elseif action == "ExitFinishedTimeTrial" then
		return exitFinishedTimeTrial(player)
	elseif action == "ResetActiveTimeTrial" then
		return resetActiveTimeTrial(player)
	elseif action == "ExitActiveTimeTrial" then
		return exitActiveTimeTrial(player)
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
	clearFinishedRunForPlayer(player)
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
