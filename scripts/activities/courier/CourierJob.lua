-- Courier job (Street Life design 4.6), server authority. Started by ServerBase; registers the
-- "Courier" activity with ActivityService. The server owns hubs, drop, timer, impacts, delivery,
-- pay and chain; clients send intents only (CourierGoToHub, CourierStart). All maths lives in the
-- pure CourierRules module. One throttled Heartbeat loop serves every active run and disconnects
-- when no runs remain.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local serverModules = ServerStorage:WaitForChild("Modules")
local activities = serverModules:WaitForChild("Game"):WaitForChild("Activities")
local ActivityService = require(activities:WaitForChild("ActivityService"))
local ActivityPayout = require(activities:WaitForChild("ActivityPayout"))
local ProgressionService = require(activities:WaitForChild("ProgressionService"))
local CourierRules = require(activities:WaitForChild("CourierRules"))
local FeatureFlags = require(serverModules:WaitForChild("Core"):WaitForChild("FeatureFlags"))
local raceIntegrity = nil
do
	local racing = serverModules.Game:FindFirstChild("Racing")
	local module = racing and racing:FindFirstChild("RaceIntegrity")
	if module then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type(result.limitMph) == "function" then raceIntegrity = result end
	end
end
local RoadRouting = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("RoadRouting"))

local KIND = "Courier"
local FLAG = "EnableCourier"
local FLAG_DEFAULT = true
local HUB_TAG = "CourierHub"

local CourierJob = {}
local state = "idle"

local runs = {} -- [Player] = run
local chains = {} -- [Player] = { Chain, CompletedAt }
local loopConnection = nil
local accumulator = 0
local tickSeconds = 0.1

local function readConfig()
	local folder = ActivityService.Config(KIND)
	return CourierRules.ReadConfig(function(key)
		return folder and folder:GetAttribute(key)
	end)
end

local function enabled(config)
	return config.Enabled and FeatureFlags.IsEnabled(FLAG, FLAG_DEFAULT)
end

local function hubs()
	local list = {}
	for _, part in ipairs(CollectionService:GetTagged(HUB_TAG)) do
		if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
			local id = part:GetAttribute("HubId")
			if type(id) == "string" and id ~= "" then
				table.insert(list, {
					Id = id,
					DisplayName = tostring(part:GetAttribute("DisplayName") or id),
					Position = part.Position,
				})
			end
		end
	end
	return list
end

local function findHub(hubId)
	for _, hub in ipairs(hubs()) do
		if hub.Id == hubId then return hub end
	end
	return nil
end

local function playerPosition(player)
	local vehicle = ActivityService.GetVehicle(player)
	local root = vehicle and vehicle.PrimaryPart
	if root then return root.Position end
	local character = player.Character
	local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
	return humanoidRoot and humanoidRoot.Position or nil
end

local function routedDistance(from, to)
	local ok, route = pcall(function()
		return RoadRouting.FindRoute(ActivityService.RoadGraph(), Vector2.new(from.X, from.Z), Vector2.new(to.X, to.Z))
	end)
	return ok and route and route.Length or nil
end

local PAY_RETRY_SECONDS = 3

local function limitMph(config)
	local raceLimit = nil
	if raceIntegrity then
		local ok, value = pcall(raceIntegrity.limitMph)
		if ok then raceLimit = value end
	end
	return CourierRules.LimitMph(raceLimit, config)
end

local function stopLoopIfIdle()
	if next(runs) == nil and loopConnection then
		loopConnection:Disconnect()
		loopConnection = nil
	end
end

local function fail(player, run, reason)
	if runs[player] ~= run then return end
	runs[player] = nil
	chains[player] = nil
	stopLoopIfIdle()
	ActivityService.End(player, run.Id, "Failed")
	ActivityService.Push(player, { Type = "Courier:Failed", RunId = run.RunId, Reason = reason })
end

local function complete(player, run, elapsed)
	if runs[player] ~= run then return end
	local result = CourierRules.Settle(run, elapsed, run.Config)
	if not result.Ok then
		fail(player, run, result.Reason)
		return
	end
	-- Leave the busy state before paying so a cancel cannot race the (possibly yielding) payout;
	-- the per-run CommandId keeps the grant idempotent.
	runs[player] = nil
	stopLoopIfIdle()
	chains[player] = { Chain = run.Chain, CompletedAt = os.clock() }
	ActivityService.End(player, run.Id, "Complete")
	task.spawn(function()
		local request = {
			Cash = result.Cash,
			Xp = result.Xp,
			Reason = "JobPayout",
			CommandId = "Courier:" .. run.RunId .. ":" .. player.UserId,
			Label = "Courier delivery",
			JobCeiling = true,
		}
		local ok, payout = pcall(ActivityPayout.Pay, player, table.clone(request))
		if not ok or type(payout) ~= "table" or not payout.Ok then
			-- One deferred retry with the SAME CommandId (Pay is idempotent per CommandId).
			warn("[CourierJob] payout attempt 1 failed; retrying", run.RunId, ok and type(payout) == "table" and payout.Message or payout)
			task.wait(PAY_RETRY_SECONDS)
			if not player.Parent then return end
			ok, payout = pcall(ActivityPayout.Pay, player, table.clone(request))
		end
		if not player.Parent then return end
		if not ok or type(payout) ~= "table" or not payout.Ok then
			warn("[CourierJob] payout failed", run.RunId, ok and type(payout) == "table" and payout.Message or payout)
			ActivityService.Push(player, {
				Type = "Courier:Failed",
				RunId = run.RunId,
				Reason = (ok and type(payout) == "table" and payout.Message) or "Payout failed; please try again later",
			})
			return
		end
		ActivityService.Push(player, {
			Type = "Courier:Completed",
			RunId = run.RunId,
			Cash = payout.Cash,
			Xp = payout.Xp,
			Stars = result.Stars,
			Chain = run.Chain,
			Capped = payout.Capped == true,
			Impacts = run.Impacts,
			Variant = run.Variant,
		})
	end)
end

local function stepRun(player, run, now)
	local current = ActivityService.Current(player)
	if not current or current.Id ~= run.Id then
		-- Core ended the record without OnCancel (should not happen); drop local state quietly.
		runs[player] = nil
		stopLoopIfIdle()
		return
	end
	local config = run.Config
	local elapsed = now - run.StartedAt
	if elapsed > run.TimeLimit then
		fail(player, run, "Out of time")
		return
	end
	local vehicle = ActivityService.GetVehicle(player)
	local root = vehicle and vehicle.PrimaryPart
	if not root then return end -- core cancels on despawn / exit grace (RequiresVehicle)
	local position = root.Position
	local speed = CourierRules.Mph(root.AssemblyLinearVelocity.Magnitude)

	-- Teleport guard over SegmentSeconds windows.
	if now - run.SegmentAt >= config.SegmentSeconds then
		local moved = CourierRules.FlatDistance(position, run.SegmentPosition)
		if not CourierRules.SegmentAllowed(moved, now - run.SegmentAt, run.LimitMph, config) then
			run.Invalid = run.Invalid or "implausible movement"
		end
		run.SegmentAt, run.SegmentPosition = now, position
	end

	if run.Variant == "Fragile" and CourierRules.RecordSpeed(run.Samples, now, speed, run.LastImpactAt, config) then
		run.Impacts += 1
		run.LastImpactAt = now
		ActivityService.Push(player, { Type = "Courier:Impact", RunId = run.RunId, Impacts = run.Impacts })
	end

	if CourierRules.Delivered(CourierRules.FlatDistance(position, run.Drop), speed, config)
		and ActivityService.GetDrivenVehicle(player) == vehicle then
		complete(player, run, elapsed)
	end
end

local function onHeartbeat(dt)
	accumulator += dt
	if accumulator < tickSeconds then return end
	accumulator = 0
	local now = os.clock()
	for player, run in pairs(runs) do
		local ok, message = pcall(stepRun, player, run, now)
		if not ok then
			warn("[CourierJob] run step failed", run.RunId, message)
			fail(player, run, "Courier run error")
		end
	end
end

local function ensureLoop(config)
	tickSeconds = 1 / config.TickHz
	if not loopConnection then
		accumulator = 0
		loopConnection = RunService.Heartbeat:Connect(onHeartbeat)
	end
end

local function goToHub(player)
	local config = readConfig()
	if not enabled(config) then return { Ok = false, Message = "Courier jobs are closed right now." } end
	local position = playerPosition(player)
	if not position then return { Ok = false, Message = "Spawn in first." } end
	local hub = CourierRules.NearestHub(hubs(), position)
	if not hub then return { Ok = false, Message = "No courier hubs are open." } end
	return { Ok = true, HubId = hub.Id, DisplayName = hub.DisplayName, Position = hub.Position }
end

local function start(player, args)
	local config = readConfig()
	if not enabled(config) then return { Ok = false, Message = "Courier jobs are closed right now." } end
	if type(args) ~= "table" then return { Ok = false, Message = "Invalid request." } end
	local variant = CourierRules.ValidVariant(args.Variant)
	if not variant then return { Ok = false, Message = "Unknown delivery type." } end
	local hub = type(args.HubId) == "string" and findHub(args.HubId) or nil
	if not hub then return { Ok = false, Message = "Unknown courier hub." } end
	if runs[player] then return { Ok = false, Message = "You already have a delivery." } end
	if config.MinRank > 1 and ProgressionService.GetRank(player) < config.MinRank then
		return { Ok = false, Message = string.format("Courier jobs unlock at rank %d.", config.MinRank) }
	end
	local vehicle = ActivityService.GetDrivenVehicle(player)
	local root = vehicle and vehicle.PrimaryPart
	if not root then return { Ok = false, Message = "Drive your own car onto the hub pad." } end
	if not CourierRules.OnHub(root.Position, hub.Position, config) then
		return { Ok = false, Message = "Drive onto the " .. hub.DisplayName .. " pad first." }
	end
	local busy, busyReason = ActivityService.IsBusy(player)
	if busy then return { Ok = false, Message = busyReason or "You are busy right now." } end

	local drop = ActivityService.RandomRoadPoint(hub.Position, config.MinDistance, config.MaxDistance)
	if not drop then return { Ok = false, Message = "No deliveries available right now. Try another hub." } end
	local straight = CourierRules.FlatDistance(hub.Position, drop)
	local distance = CourierRules.TripDistance(straight, routedDistance(hub.Position, drop), config)
	local timeLimit = CourierRules.TimeLimit(distance, variant, config)
	local now = os.clock()
	local previous = chains[player]
	local chain = CourierRules.ChainForStart(previous and previous.Chain, previous and previous.CompletedAt, now, config)

	local record, err = ActivityService.Begin(player, KIND, { HubId = hub.Id, Variant = variant })
	if not record then return { Ok = false, Message = err or "You are busy right now." } end

	local run = {
		Id = record.Id,
		RunId = ActivityService.NewId("courier"),
		HubId = hub.Id,
		Drop = drop,
		Distance = distance,
		Straight = straight,
		TimeLimit = timeLimit,
		Variant = variant,
		Chain = chain,
		LimitMph = limitMph(config),
		Impacts = 0,
		LastImpactAt = nil,
		Samples = {},
		StartedAt = now,
		SegmentAt = now,
		SegmentPosition = root.Position,
		Config = config,
	}
	runs[player] = run
	ensureLoop(config)
	local payload = {
		Type = "Courier:Started",
		RunId = run.RunId,
		HubId = hub.Id,
		DropPosition = drop,
		TimeLimit = timeLimit,
		Variant = variant,
		Distance = math.floor(distance + 0.5),
		Chain = chain,
		ServerStartTime = workspace:GetServerTimeNow(),
	}
	ActivityService.Push(player, payload)
	return { Ok = true, RunId = run.RunId, TimeLimit = timeLimit, Variant = variant, Distance = payload.Distance }
end

local function onCancel(player, record, reason)
	local run = runs[player]
	if run and record and run.Id ~= record.Id then return end
	runs[player] = nil
	chains[player] = nil
	stopLoopIfIdle()
	ActivityService.Push(player, { Type = "Courier:Cancelled", RunId = run and run.RunId, Reason = reason or "Cancelled" })
end

function CourierJob.start()
	if state ~= "idle" then return end
	state = "starting"
	local ok, message = xpcall(function()
		ActivityService.Register(KIND, {
			Actions = {
				CourierGoToHub = function(player)
					return goToHub(player)
				end,
				CourierStart = function(player, args)
					return start(player, args)
				end,
			},
			OnCancel = onCancel,
			RequiresVehicle = true,
		})
		Players.PlayerRemoving:Connect(function(player)
			-- ActivityService cancels the record on leave; this only drops local references.
			runs[player] = nil
			chains[player] = nil
			stopLoopIfIdle()
		end)
	end, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

return CourierJob
