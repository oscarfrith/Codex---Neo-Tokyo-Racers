-- Canonical feature implementation; startup is owned by the composition root (ServerBase).
-- Sky Taxi job (Street Life design 4.7). Server owner of taxi duty, NPC fares (one per driver) and
-- player taxi requests. Positions, speeds, distances, stars and pay are all decided here from
-- server-side samples; clients only send intents. Pay goes through ActivityPayout.Pay (TaxiFare,
-- JobCeiling). Player rides are game-funded bonuses to the driver; the rider is never charged.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local TaxiJob = {}

local KIND = "Taxi"
local TICK = 0.1
local SAMPLE_KEEP = 0.6

local state = "idle"
local ActivityService, ActivityPayout, PassengerService, TaxiRules, FeatureFlags, RoadRouting
local RaceIntegrity -- optional: shared speed limit for anti-teleport checks
local rng = Random.new()

local drivers = {} -- [player] = driver state (see onDuty)
local requests = {} -- [requesterUserId] = request
local lastRequestAt = {} -- [userId] = os.clock
local pairPaidAt = {} -- [pairKey] = os.clock

-- NPC body palettes (character body colours, not UI colours): { skin, top, bottom }.
local PALETTES = {
	{ Color3.fromRGB(234, 184, 146), Color3.fromRGB(39, 70, 135), Color3.fromRGB(27, 42, 53) },
	{ Color3.fromRGB(204, 142, 105), Color3.fromRGB(196, 40, 28), Color3.fromRGB(99, 95, 98) },
	{ Color3.fromRGB(160, 95, 53), Color3.fromRGB(245, 205, 48), Color3.fromRGB(17, 17, 17) },
	{ Color3.fromRGB(124, 92, 70), Color3.fromRGB(13, 105, 172), Color3.fromRGB(91, 93, 105) },
	{ Color3.fromRGB(255, 204, 153), Color3.fromRGB(75, 151, 75), Color3.fromRGB(105, 64, 40) },
	{ Color3.fromRGB(86, 66, 54), Color3.fromRGB(170, 0, 170), Color3.fromRGB(27, 42, 53) },
	{ Color3.fromRGB(215, 197, 154), Color3.fromRGB(242, 243, 243), Color3.fromRGB(39, 70, 135) },
	{ Color3.fromRGB(175, 148, 131), Color3.fromRGB(4, 175, 236), Color3.fromRGB(52, 58, 64) },
}

local function cfg()
	local folder = ActivityService.Config("Taxi")
	return TaxiRules.ResolveConfig(function(key) return folder and folder:GetAttribute(key) end)
end

local function enabled()
	local folder = ActivityService.Config("Taxi")
	return FeatureFlags.IsEnabled("EnableSkyTaxi", true) and folder ~= nil and folder:GetAttribute("Enabled") ~= false
end

local function passengersEnabled()
	local folder = ActivityService.Config("Passengers")
	return FeatureFlags.IsEnabled("EnablePassengers", true) and folder ~= nil and folder:GetAttribute("Enabled") ~= false
end

-- NewId is unique per server; a short GUID suffix keeps payout CommandIds unique across servers.
local function uniqueId(prefix)
	return ActivityService.NewId(prefix) .. "-" .. string.sub(HttpService:GenerateGUID(false), 1, 8)
end

local function rootOf(vehicle)
	return vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
end

local function flatDistance(a, b)
	return TaxiRules.Flat(a.X, a.Z, b.X, b.Z)
end

-- Plausible top speed in studs/s: RaceIntegrity.limitMph() when available, else config fallback.
local function limitStudsPerSecond(config)
	local mph = config.FallbackLimitMph
	if RaceIntegrity then
		local ok, value = pcall(RaceIntegrity.limitMph)
		if ok and tonumber(value) and value > 0 then mph = value end
	end
	return mph / TaxiRules.MPH_PER_STUD
end

-- Pay once, then one deferred retry with the SAME CommandId (idempotent) before reporting failure.
local function payWithRetry(player, payload)
	local ok, result = pcall(ActivityPayout.Pay, player, payload)
	if ok and type(result) == "table" and result.Ok == true then return result end
	task.wait(2)
	if not player.Parent then return (ok and type(result) == "table") and result or { Ok = false } end
	local retryOk, retry = pcall(ActivityPayout.Pay, player, payload)
	if retryOk and type(retry) == "table" then return retry end
	if not retryOk then warn("[TaxiJob] payout failed:", payload.CommandId, retry) end
	return { Ok = false, Cash = 0, Xp = 0, Message = "Payout failed. It will not be charged twice." }
end

local function mphOf(root)
	local v = root.AssemblyLinearVelocity
	return TaxiRules.Mph(Vector3.new(v.X, 0, v.Z).Magnitude)
end

local function push(player, payload)
	if player and player.Parent then ActivityService.Push(player, payload) end
end

local function npcFolder()
	local runtime = Workspace:WaitForChild("World"):WaitForChild("Runtime")
	local folder = runtime:FindFirstChild("ActivityNpcs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ActivityNpcs"
		folder.Parent = runtime
	end
	return folder
end

local function routeLength(from, to)
	local ok, route = pcall(function()
		return RoadRouting.FindRoute(ActivityService.RoadGraph(), Vector2.new(from.X, from.Z), Vector2.new(to.X, to.Z))
	end)
	if ok and route and tonumber(route.Length) then return route.Length end
	return flatDistance(from, to) * 1.3
end

-- NPC rigs ---------------------------------------------------------------------------------------

local function buildRig(fareId, spot)
	local palette = PALETTES[rng:NextInteger(1, #PALETTES)]
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = palette[1]
	description.LeftArmColor = palette[1]
	description.RightArmColor = palette[1]
	description.TorsoColor = palette[2]
	description.LeftLegColor = palette[3]
	description.RightLegColor = palette[3]
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()
	if not (ok and rig) then return nil end
	rig.Name = "TaxiFare_" .. fareId
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if not (humanoid and hrp) then rig:Destroy(); return nil end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	rig.PrimaryPart = hrp
	local height = humanoid.HipHeight + hrp.Size.Y / 2
	rig:PivotTo(CFrame.new(spot + Vector3.new(0, height, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	rig:SetAttribute("TaxiFareId", fareId)
	rig:SetAttribute("StandPivot", rig:GetPivot())
	rig.Parent = npcFolder()
	return rig
end

-- Walk a few studs away from the car, then remove.
local function dismissRig(rig, awayFrom)
	if not (rig and rig.Parent) then return end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if humanoid and hrp then
		for _, part in ipairs(rig:GetDescendants()) do
			if part:IsA("BasePart") then part.Anchored = false end
		end
		pcall(function() hrp:SetNetworkOwner(nil) end)
		local direction = Vector3.new(hrp.Position.X - awayFrom.X, 0, hrp.Position.Z - awayFrom.Z)
		direction = direction.Magnitude > 0.1 and direction.Unit or Vector3.xAxis
		humanoid:MoveTo(hrp.Position + direction * 10)
	end
	task.delay(3, function()
		if rig.Parent then rig:Destroy() end
	end)
end

-- Fares -----------------------------------------------------------------------------------------

local function clearFare(driver, fare)
	fare = fare or driver.Fare
	if not fare then return end
	if driver.Fare == fare then driver.Fare = nil end
	fare.Closed = true
	if fare.Phase == "Riding" and fare.Vehicle and PassengerService.GetOccupant(fare.Vehicle) == fare.Rig then
		PassengerService.UnseatNpc(fare.Vehicle)
	end
	if fare.Rig and fare.Rig.Parent then fare.Rig:Destroy() end
end

local function fareLost(player, driver, fare, message)
	if fare.Closed then return end
	clearFare(driver, fare)
	driver.NextFareAt = os.clock() + cfg().NextFareSeconds
	push(player, { Type = "Taxi:FareLost", FareId = fare.Id, Message = message })
end

local function spawnFare(player, driver, root, config)
	if driver.Spawning then return end
	driver.Spawning = true
	task.spawn(function()
		local fareId = uniqueId("Fare")
		local spot = ActivityService.RandomRoadPoint(root.Position, config.NpcMinStuds, config.NpcMaxStuds, rng)
		local rig = spot and buildRig(fareId, spot)
		driver.Spawning = false
		if drivers[player] ~= driver or driver.Fare then
			if rig then rig:Destroy() end
			return
		end
		if not rig then
			driver.NextFareAt = os.clock() + 5
			return
		end
		driver.Fare = { Id = fareId, Phase = "Waiting", Rig = rig, Spot = spot, SpawnedAt = os.clock(), Impacts = 0 }
		push(player, { Type = "Taxi:Fare", FareId = fareId, Position = spot })
	end)
end

-- Runs on its own thread (SeatNpc waits briefly for the seat weld); the fare is "Boarding" meanwhile.
local function pickUp(player, driver, fare, vehicle, root, config)
	local destination = ActivityService.RandomRoadPoint(root.Position, config.DestMinStuds, config.DestMaxStuds, rng)
	if not destination then
		fareLost(player, driver, fare, "The fare changed their mind.")
		return
	end
	local ok = PassengerService.SeatNpc(vehicle, fare.Rig)
	if fare.Closed or driver.Fare ~= fare then
		if ok then PassengerService.UnseatNpc(vehicle) end
		return
	end
	if not ok then
		-- Put the fare back where it was standing (SeatNpc unanchored it).
		local rig = fare.Rig
		if rig and rig.Parent then
			for _, part in ipairs(rig:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.Massless = true
				end
			end
			local stand = rig:GetAttribute("StandPivot")
			if typeof(stand) == "CFrame" then rig:PivotTo(stand) end
		end
		fare.Phase = "Waiting"
		return
	end
	fare.Phase = "Riding"
	fare.Vehicle = vehicle
	fare.Pickup = root.Position
	fare.Destination = destination
	fare.Distance = routeLength(root.Position, destination)
	fare.Estimate = TaxiRules.EstimateSeconds(fare.Distance, config)
	fare.PickedAt = os.clock()
	fare.Impacts = 0
	fare.Driven = 0 -- server-counted, capped per tick (anti-teleport)
	fare.LastPosition = root.Position
	fare.LastAt = os.clock()
	push(player, {
		Type = "Taxi:PickedUp", FareId = fare.Id, Destination = destination,
		EstimateSeconds = fare.Estimate, Distance = math.floor(fare.Distance),
	})
end

local function deliver(player, driver, fare, vehicle, root, config)
	local elapsed = os.clock() - fare.PickedAt
	local plausible = TaxiRules.FarePlausible(fare.Driven, fare.Distance, elapsed, limitStudsPerSecond(config), config)
	if not plausible then
		fareLost(player, driver, fare, "Trip could not be verified, so there is no fare.")
		return
	end
	fare.Phase = "Paying"
	local stars = TaxiRules.Stars(fare.Impacts, elapsed, fare.Estimate, config)
	local cash, xp = TaxiRules.Fare(fare.Distance, stars, config)
	local seat = vehicle:FindFirstChild("PassengerSeat", true)
	local rig = PassengerService.UnseatNpc(vehicle)
	if rig and seat then
		rig:PivotTo(seat.CFrame * CFrame.new(-6, 2.5, 0))
		dismissRig(rig, root.Position)
	elseif fare.Rig and fare.Rig.Parent then
		fare.Rig:Destroy()
	end
	fare.Rig = nil
	driver.Fare = nil
	driver.NextFareAt = os.clock() + config.NextFareSeconds
	task.spawn(function()
		local result = payWithRetry(player, {
			Cash = cash, Xp = xp, Reason = "TaxiFare", JobCeiling = true, Label = "Sky Taxi fare",
			CommandId = "Taxi:" .. fare.Id .. ":" .. player.UserId,
		})
		push(player, {
			Type = "Taxi:Delivered", FareId = fare.Id, Stars = stars,
			Cash = result.Cash or 0, Xp = result.Xp or 0, Capped = result.Capped == true,
			Ok = result.Ok == true, Message = result.Message,
		})
	end)
end

-- Player requests -------------------------------------------------------------------------------

local function onDutyPlayers(except)
	local list = {}
	for player in pairs(drivers) do
		if player ~= except and player.Parent then table.insert(list, player) end
	end
	return list
end

local function requestPayload(request)
	local requester = request.Requester
	return {
		Type = "Taxi:Request", RequesterUserId = requester.UserId, Name = requester.DisplayName,
		Position = request.Position,
	}
end

-- Close a request for everyone involved. `message` goes to the requester (and driver if any).
local function closeRequest(request, message, driverMessage)
	if requests[request.Requester.UserId] ~= request then return end
	requests[request.Requester.UserId] = nil
	local driverPlayer = request.Driver
	if driverPlayer then
		PassengerService.RevokeRide(driverPlayer.UserId, request.Requester.UserId)
		local driver = drivers[driverPlayer]
		if driver and driver.PlayerRide == request then
			driver.PlayerRide = nil
			driver.NextFareAt = os.clock() + cfg().NextFareSeconds
		end
		push(driverPlayer, { Type = "Taxi:RequestEnded", Role = "Driver", RequesterUserId = request.Requester.UserId, Message = driverMessage or message })
	end
	push(request.Requester, { Type = "Taxi:RequestEnded", Role = "Rider", Message = message })
	for _, player in ipairs(onDutyPlayers(driverPlayer)) do
		push(player, { Type = "Taxi:RequestClosed", RequesterUserId = request.Requester.UserId })
	end
end

local function finishPlayerRide(request)
	local driverPlayer = request.Driver
	local config = cfg()
	local now = os.clock()
	local key = TaxiRules.PairKey(driverPlayer.UserId, request.Requester.UserId)
	local pays, why = TaxiRules.PlayerRidePays(request.Ridden, pairPaidAt[key], now, config)
	local ridden = math.floor(request.Ridden)
	if not pays then
		local message = why == "TooShort" and "Ride ended before " .. math.floor(config.PlayerMinRideStuds) .. " studs, so there is no fare bonus."
			or "Same passenger within the cooldown, so there is no fare bonus."
		closeRequest(request, "Thanks for riding!", message)
		return
	end
	pairPaidAt[key] = now
	local cash, xp = TaxiRules.PlayerFare(request.Ridden, config)
	closeRequest(request, "Thanks for riding!", "Ride complete.")
	task.spawn(function()
		local result = payWithRetry(driverPlayer, {
			Cash = cash, Xp = xp, Reason = "TaxiFare", JobCeiling = true, Label = "Sky Taxi ride",
			CommandId = "Taxi:" .. request.RideId .. ":" .. driverPlayer.UserId,
		})
		push(driverPlayer, {
			Type = "Taxi:RideComplete", Role = "Driver", Name = request.Requester.DisplayName, Distance = ridden,
			Cash = result.Cash or 0, Xp = result.Xp or 0, Capped = result.Capped == true, Ok = result.Ok == true,
		})
	end)
end

-- Duty ------------------------------------------------------------------------------------------

local function cleanupDriver(player, message, endActivity)
	local driver = drivers[player]
	if not driver then return end
	drivers[player] = nil
	clearFare(driver)
	for _, request in pairs(requests) do
		if request.Driver == player then closeRequest(request, "Your driver went off duty.", message) end
	end
	if endActivity and driver.RecordId then pcall(ActivityService.End, player, driver.RecordId, "Complete") end
	push(player, { Type = "Taxi:Duty", OnDuty = false, Message = message })
end

local function setDuty(player, args)
	local wanted, err = TaxiRules.ValidateDutyArgs(args)
	if wanted == nil then return { Ok = false, Message = err } end
	if not wanted then
		if not drivers[player] then return { Ok = true, OnDuty = false } end
		cleanupDriver(player, "Off duty.", true)
		return { Ok = true, OnDuty = false, Message = "Off duty." }
	end
	if drivers[player] then return { Ok = true, OnDuty = true } end
	if not enabled() then return { Ok = false, Message = "Sky Taxi is closed right now." } end
	local config = cfg()
	local okRank, rank = pcall(function()
		local ProgressionService = require(ServerStorage.Modules.Game.Activities.ProgressionService)
		return ProgressionService.GetRank(player)
	end)
	if okRank and tonumber(rank) and rank < config.MinRank then
		return { Ok = false, Message = "Sky Taxi unlocks at rank " .. math.floor(config.MinRank) .. "." }
	end
	if not ActivityService.GetDrivenVehicle(player) then return { Ok = false, Message = "Get in your car to go on duty." } end
	local request = requests[player.UserId]
	if request then closeRequest(request, "Request cancelled.") end
	local record, beginError = ActivityService.Begin(player, KIND, {})
	if not record then return { Ok = false, Message = beginError or "You can't start this right now." } end
	drivers[player] = { RecordId = record.Id, Samples = {}, LastImpactAt = -math.huge, NextFareAt = os.clock() + 2, SeatWarnedAt = -math.huge }
	push(player, { Type = "Taxi:Duty", OnDuty = true })
	for _, open in pairs(requests) do
		if open.Phase == "Open" and open.Requester ~= player then push(player, requestPayload(open)) end
	end
	return { Ok = true, OnDuty = true, Message = "On duty. Fares will appear on your map." }
end

local function requestTaxi(player)
	if not (enabled() and passengersEnabled()) then return { Ok = false, Message = "Sky Taxi is closed right now." } end
	if requests[player.UserId] then return { Ok = false, Message = "You already called a taxi." } end
	if drivers[player] then return { Ok = false, Message = "You are on taxi duty." } end
	local config = cfg()
	local now = os.clock()
	local wait = TaxiRules.CooldownRemaining(lastRequestAt[player.UserId], now, config.RequestCooldownSeconds)
	if wait > 0 then return { Ok = false, Message = "Wait " .. math.ceil(wait) .. " s before calling again." } end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and hrp and humanoid.Health > 0) then return { Ok = false, Message = "You can't call a taxi right now." } end
	if humanoid.SeatPart then return { Ok = false, Message = "Get out of your car to call a taxi." } end
	local busy, reason = ActivityService.IsBusy(player)
	if busy then return { Ok = false, Message = reason or "Finish what you are doing first." } end
	lastRequestAt[player.UserId] = now
	local request = { Requester = player, Position = hrp.Position, At = now, Phase = "Open" }
	requests[player.UserId] = request
	local listeners = onDutyPlayers(player)
	for _, driverPlayer in ipairs(listeners) do push(driverPlayer, requestPayload(request)) end
	push(player, { Type = "Taxi:RequestOpen", Drivers = #listeners })
	return {
		Ok = true,
		Message = #listeners > 0 and "Taxi requested. Waiting for a driver." or "Taxi requested. No drivers are on duty yet.",
	}
end

local function cancelRequest(player, args)
	local own = requests[player.UserId]
	if own then
		if own.Phase == "Riding" then return { Ok = false, Message = "Jump out to end your ride." } end
		closeRequest(own, "Request cancelled.", own.Requester.DisplayName .. " cancelled the ride.")
		return { Ok = true }
	end
	local requesterUserId = type(args) == "table" and TaxiRules.ValidateUserId(args.RequesterUserId)
	local request = requesterUserId and requests[requesterUserId]
	if request and request.Driver == player and request.Phase == "Accepted" then
		closeRequest(request, "Your driver cancelled. Call again for another taxi.", "Ride cancelled.")
		return { Ok = true }
	end
	return { Ok = false, Message = "No taxi request to cancel." }
end

local function acceptRequest(player, args)
	local driver = drivers[player]
	if not driver then return { Ok = false, Message = "Go on duty to accept rides." } end
	local requesterUserId = type(args) == "table" and TaxiRules.ValidateUserId(args.RequesterUserId)
	local request = requesterUserId and requests[requesterUserId]
	if not request or request.Phase ~= "Open" then return { Ok = false, Message = "That request was already taken." } end
	if driver.PlayerRide then return { Ok = false, Message = "Finish your current ride first." } end
	if driver.Fare and driver.Fare.Phase ~= "Waiting" then return { Ok = false, Message = "Drop off your fare first." } end
	local vehicle = ActivityService.GetDrivenVehicle(player)
	if not vehicle then return { Ok = false, Message = "Get in your car first." } end
	if PassengerService.GetOccupant(vehicle) then return { Ok = false, Message = "Your passenger seat is taken." } end
	local config = cfg()
	if driver.Fare then
		clearFare(driver)
		push(player, { Type = "Taxi:FareLost", Message = "NPC fare released for the ride request." })
	end
	request.Phase = "Accepted"
	request.Driver = player
	request.AcceptedAt = os.clock()
	request.RideId = uniqueId("TaxiRide")
	driver.PlayerRide = request
	PassengerService.AllowRide(player.UserId, request.Requester.UserId, config.AcceptWindowSeconds)
	local key = TaxiRules.PairKey(player.UserId, request.Requester.UserId)
	local bonus = TaxiRules.CooldownRemaining(pairPaidAt[key], os.clock(), config.PairCooldownSeconds) <= 0
	push(player, {
		Type = "Taxi:RequestAccepted", Role = "Driver", RequesterUserId = request.Requester.UserId,
		Name = request.Requester.DisplayName, Position = request.Position, Bonus = bonus,
	})
	push(request.Requester, {
		Type = "Taxi:RequestAccepted", Role = "Rider", DriverUserId = player.UserId, DriverName = player.DisplayName,
		Seconds = config.AcceptWindowSeconds,
	})
	for _, other in ipairs(onDutyPlayers(player)) do
		push(other, { Type = "Taxi:RequestClosed", RequesterUserId = request.Requester.UserId })
	end
	return { Ok = true, Message = "Pick up " .. request.Requester.DisplayName .. "." }
end

-- Occupant changes (from PassengerService) ------------------------------------------------------

local function onOccupantChanged(vehicle, occupant, previous, reason)
	local owner = Players:GetPlayerByUserId(tonumber(vehicle:GetAttribute("OwnerUserId")) or 0)
	local driver = owner and drivers[owner]
	if typeof(occupant) == "Instance" and occupant:IsA("Player") then
		local request = requests[occupant.UserId]
		if request and request.Driver == owner and request.Phase == "Accepted" then
			request.Phase = "Riding"
			request.Ridden = 0
			local root = rootOf(vehicle)
			request.LastPosition = root and root.Position
			request.LastAt = os.clock()
			push(owner, { Type = "Taxi:RideStarted", Role = "Driver", Name = occupant.DisplayName })
			push(occupant, { Type = "Taxi:RideStarted", Role = "Rider", DriverName = owner.DisplayName })
		end
		return
	end
	if occupant ~= nil then return end
	if typeof(previous) == "Instance" and previous:IsA("Player") then
		local request = requests[previous.UserId]
		if request and request.Phase == "Riding" and request.Driver == owner then finishPlayerRide(request) end
	elseif driver and driver.Fare and driver.Fare.Rig == previous and driver.Fare.Phase == "Riding" then
		fareLost(owner, driver, driver.Fare, "Your fare got out (" .. tostring(reason) .. ").")
	end
end

-- Main loop -------------------------------------------------------------------------------------

local function stepDriver(player, driver, now, config)
	local current = ActivityService.Current(player)
	if not current or current.Id ~= driver.RecordId then
		cleanupDriver(player, "Off duty.", false)
		return
	end
	local vehicle = ActivityService.GetDrivenVehicle(player)
	local root = rootOf(vehicle)
	if not root then return end -- exit grace: the core cancels if it runs out
	local mph = mphOf(root)
	local samples = driver.Samples
	table.insert(samples, { T = now, Mph = mph })
	while samples[1] and now - samples[1].T > SAMPLE_KEEP do table.remove(samples, 1) end

	local fare = driver.Fare
	if fare and fare.Phase == "Waiting" then
		if not (fare.Rig and fare.Rig.Parent) or now - fare.SpawnedAt > config.FareTimeoutSeconds then
			fareLost(player, driver, fare, "The fare found another ride.")
		elseif TaxiRules.IsStoppedAt(flatDistance(root.Position, fare.Spot), mph, config.PickupRadius, config.StopMph) then
			if PassengerService.GetOccupant(vehicle) or (vehicle:FindFirstChild("PassengerSeat", true) or {}).Occupant then
				if now - driver.SeatWarnedAt > 5 then
					driver.SeatWarnedAt = now
					push(player, { Type = "Taxi:Notice", Message = "Your passenger seat is taken." })
				end
			else
				fare.Phase = "Boarding"
				task.spawn(pickUp, player, driver, fare, vehicle, root, config)
			end
		end
	elseif fare and fare.Phase == "Riding" then
		fare.Driven += TaxiRules.CapStep(flatDistance(root.Position, fare.LastPosition), now - fare.LastAt, limitStudsPerSecond(config))
		fare.LastPosition = root.Position
		fare.LastAt = now
		if TaxiRules.IsImpact(samples, now, mph, config) and now - driver.LastImpactAt > config.ImpactCooldownSeconds then
			driver.LastImpactAt = now
			fare.Impacts += 1
			local stars = TaxiRules.Stars(fare.Impacts, now - fare.PickedAt, fare.Estimate, config)
			push(player, { Type = "Taxi:Impact", FareId = fare.Id, Stars = stars })
		end
		if TaxiRules.IsStoppedAt(flatDistance(root.Position, fare.Destination), mph, config.ArriveRadius, config.StopMph) then
			deliver(player, driver, fare, vehicle, root, config)
		end
	elseif not fare and not driver.PlayerRide and now >= driver.NextFareAt then
		spawnFare(player, driver, root, config)
	end
end

local function stepRequests(now, config)
	for _, request in pairs(requests) do
		if request.Phase == "Open" and now - request.At > config.RequestTimeoutSeconds then
			closeRequest(request, "No taxi took your request. Try again soon.")
		elseif request.Phase == "Accepted" and now - request.AcceptedAt > config.AcceptWindowSeconds then
			closeRequest(request, "Your taxi didn't make it. Call again.", "Pickup window expired.")
		elseif request.Phase == "Riding" then
			local root = rootOf(ActivityService.GetVehicle(request.Driver))
			if root and request.LastPosition then
				-- Cap per-tick movement so teleports never count as distance.
				local dt = now - (request.LastAt or now)
				request.Ridden += TaxiRules.CapStep(flatDistance(root.Position, request.LastPosition), dt, limitStudsPerSecond(config))
			end
			request.LastPosition = root and root.Position or request.LastPosition
			request.LastAt = now
		end
	end
end

local accumulator = 0
local function step(dt)
	accumulator += dt
	if accumulator < TICK then return end
	accumulator = 0
	if next(drivers) == nil and next(requests) == nil then return end
	local config = cfg()
	local now = os.clock()
	for player, driver in pairs(drivers) do
		local ok, err = pcall(stepDriver, player, driver, now, config)
		if not ok then warn("[TaxiJob] driver step failed:", err) end
	end
	local ok, err = pcall(stepRequests, now, config)
	if not ok then warn("[TaxiJob] request step failed:", err) end
end

-- Startup ---------------------------------------------------------------------------------------

function TaxiJob.start()
	if state ~= "idle" then return end
	state = "starting"
	local ok, message = xpcall(function()
		local Activities = ServerStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Activities")
		ActivityService = require(Activities:WaitForChild("ActivityService"))
		ActivityPayout = require(Activities:WaitForChild("ActivityPayout"))
		PassengerService = require(Activities:WaitForChild("PassengerService"))
		TaxiRules = require(Activities:WaitForChild("TaxiRules"))
		FeatureFlags = require(ServerStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("FeatureFlags"))
		local racing = ServerStorage.Modules.Game:FindFirstChild("Racing")
		local integrity = racing and racing:FindFirstChild("RaceIntegrity")
		if integrity then
			local ok, module = pcall(require, integrity)
			if ok and type(module) == "table" and type(module.limitMph) == "function" then RaceIntegrity = module end
		end
		RoadRouting = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("RoadRouting"))

		ActivityService.Register(KIND, {
			Actions = {
				TaxiSetDuty = setDuty,
				TaxiRequest = requestTaxi,
				TaxiCancelRequest = cancelRequest,
				TaxiAcceptRequest = acceptRequest,
			},
			OnCancel = function(player, _record, reason)
				cleanupDriver(player, "Off duty: " .. tostring(reason or "cancelled") .. ".", false)
			end,
		})

		PassengerService.OccupantChanged:Connect(onOccupantChanged)

		Players.PlayerRemoving:Connect(function(player)
			cleanupDriver(player, nil, false)
			local own = requests[player.UserId]
			if own then closeRequest(own, "Request closed.", own.Requester.DisplayName .. " left the game.") end
			lastRequestAt[player.UserId] = nil
		end)

		RunService.Heartbeat:Connect(step)
	end, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

return TaxiJob
