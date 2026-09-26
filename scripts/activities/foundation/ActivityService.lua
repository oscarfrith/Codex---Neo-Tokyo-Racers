-- Canonical feature implementation; startup is owned by the composition root.
-- Street Life activity core (docs/architecture/activities-contract.md): one activity per player with
-- cleanup on leaving the vehicle, despawn, garages, races, death and leaving; the ActivityInvoke remote
-- (Core.Net guarded) dispatching to registered features; passenger-access setting; shared helpers
-- (vehicles, config, road points). Features register from their own start().
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("Signal"))

local Service = {}
Service.Signals = { Ended = Signal.new() } -- (player, record, outcome)
local state

local modules = ServerStorage:WaitForChild("Modules")
local Net = require(modules:WaitForChild("Core"):WaitForChild("Net"))
local ProfileServer = require(modules:WaitForChild("Game"):WaitForChild("Player"):WaitForChild("ProfileServer"))
local configRoot = ReplicatedStorage:WaitForChild("Config"):WaitForChild("Activities")
local coreConfig = configRoot:WaitForChild("Core")

local ACCESS = { Friends = true, Anyone = true, Nobody = true }
local ACTIONS = {
	GetState = true, Cancel = true, SetPassengerAccess = true,
	CourierGoToHub = true, CourierStart = true,
	Ride = true, LeaveRide = true,
	TaxiSetDuty = true, TaxiRequest = true, TaxiCancelRequest = true, TaxiAcceptRequest = true,
	DuelChallenge = true, DuelRespond = true,
}

local registry = {} -- kind -> handlers
local actionOwner = {} -- action -> kind
local records = {} -- player -> record
local exitSince = {} -- player -> os.clock() when the driver left their car
local idCounter = 0
local activityEvent
local graph

function Service.Config(name)
	return configRoot:WaitForChild(name)
end

function Service.Number(folder, key, default, minimum, maximum)
	local value = tonumber(folder and folder:GetAttribute(key))
	if value == nil or value ~= value or math.abs(value) == math.huge then value = default end
	return math.clamp(value, minimum or -math.huge, maximum or math.huge)
end

function Service.NewId(prefix)
	idCounter += 1
	return tostring(prefix) .. "_" .. idCounter .. "_" .. string.sub(HttpService:GenerateGUID(false), 1, 8)
end

local function playerVehicles()
	local world = workspace:FindFirstChild("World")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

function Service.GetVehicle(player)
	local folder = playerVehicles()
	if not folder then return nil end
	for _, vehicle in ipairs(folder:GetChildren()) do
		if vehicle:IsA("Model") and tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId then return vehicle end
	end
	return nil
end

function Service.GetDrivenVehicle(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat") then return nil end
	local vehicle = seat:FindFirstAncestorOfClass("Model")
	while vehicle and tonumber(vehicle:GetAttribute("OwnerUserId")) == nil do vehicle = vehicle:FindFirstAncestorOfClass("Model") end
	if vehicle and tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId and vehicle.Parent == playerVehicles() then return vehicle end
	return nil
end

local function blockedReason(player)
	if player:GetAttribute("GarageSessionActive") == true then return "Leave the garage first." end
	if player:GetAttribute("OwnedGarageInside") == true then return "Leave the garage first." end
	if player:GetAttribute("RaceQueueActive") == true then return "Leave the race queue first." end
	local vehicle = Service.GetVehicle(player)
	if vehicle and (vehicle:GetAttribute("RaceParticipant") == true or vehicle:GetAttribute("RaceRunId") ~= nil) then return "Finish your race first." end
	return nil
end

function Service.IsBusy(player)
	if records[player] then return true, "Finish your current job first." end
	local reason = blockedReason(player)
	return reason ~= nil, reason
end

function Service.Current(player)
	return records[player]
end

function Service.Push(player, payload)
	if activityEvent and typeof(player) == "Instance" and player.Parent == Players then activityEvent:FireClient(player, payload) end
end

function Service.PushAll(payload)
	if activityEvent then activityEvent:FireAllClients(payload) end
end

local function setActivityAttributes(player, record)
	player:SetAttribute("ActivityKind", record and record.Kind or "")
	player:SetAttribute("ActivityId", record and record.Id or "")
end

function Service.Register(kind, handlers)
	assert(type(kind) == "string" and kind ~= "" and not registry[kind], "Activity kind must be unique: " .. tostring(kind))
	assert(type(handlers) == "table", "Activity handlers required")
	handlers.RequiresVehicle = handlers.RequiresVehicle ~= false
	registry[kind] = handlers
	for action in pairs(handlers.Actions or {}) do
		assert(ACTIONS[action] and not actionOwner[action], "Action not in the ActivityInvoke allowlist or already owned: " .. tostring(action))
		actionOwner[action] = kind
	end
end

function Service.Begin(player, kind, data)
	assert(registry[kind], "Unregistered activity kind " .. tostring(kind))
	local busy, reason = Service.IsBusy(player)
	if busy then return nil, reason end
	local record = { Id = Service.NewId(kind), Kind = kind, StartedAt = os.clock(), Data = data or {} }
	records[player] = record
	exitSince[player] = nil
	setActivityAttributes(player, record)
	return record
end

local function finish(player, record, outcome)
	if records[player] ~= record then return false end
	records[player] = nil
	exitSince[player] = nil
	if player.Parent == Players then setActivityAttributes(player, nil) end
	Service.Signals.Ended:Fire(player, record, outcome)
	return true
end

function Service.End(player, recordId, outcome)
	local record = records[player]
	if not record or record.Id ~= recordId then return false end
	return finish(player, record, outcome or "Complete")
end

function Service.Cancel(player, reason)
	local record = records[player]
	if not record then return false end
	if not finish(player, record, "Cancelled") then return false end
	local handlers = registry[record.Kind]
	if handlers and handlers.OnCancel then
		local ok, err = pcall(handlers.OnCancel, player, record, reason or "Cancelled")
		if not ok then warn("[ActivityService] " .. record.Kind .. " OnCancel failed: " .. tostring(err)) end
	end
	return true
end

function Service.RoadGraph()
	if not graph then
		local world = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World")
		graph = require(world:WaitForChild("RoadRouting")).LoadGraph(require(world:WaitForChild("RoadGraphData")))
	end
	return graph
end

-- A road-graph node inside the Core District bounds, between minStuds and maxStuds from `from`.
function Service.RandomRoadPoint(from, minStuds, maxStuds, rng)
	rng = rng or Random.new()
	local minX = Service.Number(coreConfig, "DistrictMinX", -250)
	local maxX = Service.Number(coreConfig, "DistrictMaxX", 2600)
	local minZ = Service.Number(coreConfig, "DistrictMinZ", -4150)
	local maxZ = Service.Number(coreConfig, "DistrictMaxZ", 550)
	local origin = Vector2.new(from.X, from.Z)
	for widen = 1, 3 do
		local low, high = minStuds / widen, maxStuds * widen
		local candidates = {}
		for _, node in ipairs(Service.RoadGraph().Nodes) do
			if node.X >= minX and node.X <= maxX and node.Y >= minZ and node.Y <= maxZ then
				local distance = (node - origin).Magnitude
				if distance >= low and distance <= high then table.insert(candidates, node) end
			end
		end
		if #candidates > 0 then
			local node = candidates[rng:NextInteger(1, #candidates)]
			return Vector3.new(node.X, 101, node.Y)
		end
	end
	return nil
end

local function profileSettings(player)
	local profile = ProfileServer.get_profile(player)
	if not profile then return nil, nil end
	profile.Settings = type(profile.Settings) == "table" and profile.Settings or {}
	if not ACCESS[profile.Settings.PassengerAccess] then
		profile.Settings.PassengerAccess = tostring(Service.Config("Passengers"):GetAttribute("DefaultAccess") or "Friends")
		if not ACCESS[profile.Settings.PassengerAccess] then profile.Settings.PassengerAccess = "Friends" end
	end
	return profile, profile.Settings
end

local function coreAction(player, action, args)
	if action == "GetState" then
		local record = records[player]
		return { Ok = true, Kind = record and record.Kind or "", Id = record and record.Id or "", Rank = player:GetAttribute("Rank"), PassengerAccess = player:GetAttribute("PassengerAccess") }
	elseif action == "Cancel" then
		return { Ok = Service.Cancel(player, "Player"), Message = records[player] and "Could not cancel." or nil }
	elseif action == "SetPassengerAccess" then
		local access = type(args) == "table" and args.Access
		if not ACCESS[access] then return { Ok = false, Message = "Unknown passenger setting." } end
		local profile, settings = profileSettings(player)
		if not profile then return { Ok = false, Message = "Profile is not loaded." } end
		if settings.PassengerAccess ~= access then
			settings.PassengerAccess = access
			ProfileServer.mark_dirty(player, profile, "Settings:PassengerAccess")
		end
		player:SetAttribute("PassengerAccess", access)
		return { Ok = true, Access = access }
	end
	return nil
end

local function handleInvoke(player, action, args)
	args = type(args) == "table" and args or {}
	local core = coreAction(player, action, args)
	if core then return core end
	local kind = actionOwner[action]
	local handlers = kind and registry[kind]
	local handler = handlers and handlers.Actions and handlers.Actions[action]
	if not handler then return { Ok = false, Message = "That feature is not available yet." } end
	local result = handler(player, args)
	return type(result) == "table" and result or { Ok = result == true }
end

local function watch()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then return end
		accumulator = 0
		local grace = Service.Number(coreConfig, "ExitGraceSeconds", 10, 0, 120)
		for player, record in pairs(records) do
			local handlers = registry[record.Kind]
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local reason = blockedReason(player)
			if not reason and (not humanoid or humanoid.Health <= 0) then reason = "Died" end
			if not reason and handlers and handlers.RequiresVehicle then
				if not Service.GetVehicle(player) then
					reason = "VehicleGone"
				elseif Service.GetDrivenVehicle(player) then
					exitSince[player] = nil
				else
					exitSince[player] = exitSince[player] or os.clock()
					if os.clock() - exitSince[player] > grace then reason = "LeftVehicle" end
				end
			end
			if reason then Service.Cancel(player, reason) end
		end
	end)
end

local function track(player)
	setActivityAttributes(player, nil)
	task.spawn(function()
		for _ = 1, 120 do
			if player.Parent ~= Players then return end
			local profile, settings = profileSettings(player)
			if profile then
				player:SetAttribute("PassengerAccess", settings.PassengerAccess)
				return
			end
			task.wait(0.5)
		end
	end)
end

function Service.start()
	if state then assert(state == "ready", "Service already starting or failed"); return end
	state = "starting"
	local ok, message = xpcall(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Activities")
		activityEvent = remotes:WaitForChild("ActivityEvent")
		local invoke = remotes:WaitForChild("ActivityInvoke")
		invoke.OnServerInvoke = Net.invoke({
			name = "ActivityInvoke", actions = ACTIONS, capacity = 20, refill = 4, busy = true,
			messages = { unknown = "Unknown activity request.", rate = "Slow down a moment.", busy = "Still working on your last request." },
		}, handleInvoke)
		Players.PlayerAdded:Connect(track)
		for _, player in ipairs(Players:GetPlayers()) do track(player) end
		Players.PlayerRemoving:Connect(function(player)
			Service.Cancel(player, "Left")
			records[player] = nil
			exitSince[player] = nil
		end)
		watch()
	end, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

return Service
