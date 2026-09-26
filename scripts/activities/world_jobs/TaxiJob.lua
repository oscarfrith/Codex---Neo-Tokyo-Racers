-- Canonical feature implementation; startup is owned by the composition root (ServerBase).
-- World taxi fares (map-markers-contract "World jobs"). Registers the "Taxi" activity kind and the Taxi
-- provider with JobBoard, which owns offers, JobAccept, the trip engine and the payout. This module owns
-- the fare NPCs: a rig stands on the pavement facing the road (spawned only while a player is within
-- StreamRadius), hails, walks to the car on accept, rides in the PassengerSeat (PassengerService.SeatNpc)
-- and walks back to the pavement at the drop-off before despawning.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local TaxiJob = {}

local KIND = "Taxi"
local state = "idle"
local ActivityService, PassengerService, JobBoard, TaxiRules, FeatureFlags
local rng = Random.new()

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

local function config()
	local folder = ActivityService.Config(KIND)
	return TaxiRules.ReadConfig(function(key) return folder and folder:GetAttribute(key) end)
end

local function enabled()
	local folder = ActivityService.Config(KIND)
	return FeatureFlags.IsEnabled("EnableSkyTaxi", true) and folder ~= nil and folder:GetAttribute("Enabled") ~= false
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

local function passengerSeat(vehicle)
	local seat = vehicle and vehicle:FindFirstChild("PassengerSeat", true)
	return (seat and seat:IsA("Seat")) and seat or nil
end

-- Rigs ----------------------------------------------------------------------------------------------

local function setAnchoredRoot(rig, anchored)
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = anchored and part.Name == "HumanoidRootPart"
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

local function startHail(rig, animationId)
	if animationId == "" then return end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	if not ok or not track then return end
	rig:SetAttribute("Hailing", true)
	task.spawn(function()
		task.wait(rng:NextNumber(0.2, 2))
		while rig.Parent and rig:GetAttribute("Hailing") == true do
			pcall(function() track:Play(0.2) end)
			task.wait(rng:NextNumber(4, 7))
		end
		pcall(function() track:Stop(0.2) end)
	end)
end

local function stopHail(rig)
	if rig then rig:SetAttribute("Hailing", false) end
end

-- R15 rig standing on the pavement at `position` (ground), facing the road (`facing`).
local function buildRig(offerId, position, facing, animationId)
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
	rig.Name = "TaxiFare_" .. offerId
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if not (humanoid and hrp) then rig:Destroy() return nil end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = 12
	rig.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	setAnchoredRoot(rig, true) -- root anchored; limbs on Motor6Ds so the hail animation plays
	rig.PrimaryPart = hrp
	local height = humanoid.HipHeight + hrp.Size.Y / 2
	local look = typeof(facing) == "Vector3" and facing.Magnitude > 0.1 and facing.Unit or Vector3.zAxis
	local standAt = position + Vector3.new(0, height, 0)
	rig:PivotTo(CFrame.lookAt(standAt, standAt + look))
	rig:SetAttribute("JobOfferId", offerId)
	rig.Parent = npcFolder()
	startHail(rig, animationId)
	return rig
end

-- Unanchor and let the server walk the rig somewhere, then remove it.
local function walkAway(rig, target, seconds)
	if not (rig and rig.Parent) then return end
	stopHail(rig)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if humanoid and hrp then
		for _, part in ipairs(rig:GetDescendants()) do
			if part:IsA("BasePart") then part.Anchored = false end
		end
		pcall(function() hrp:SetNetworkOwner(nil) end)
		if typeof(target) == "Vector3" then humanoid:MoveTo(target) end
	end
	task.delay(seconds or 5, function()
		if rig.Parent then rig:Destroy() end
	end)
end

-- Provider -------------------------------------------------------------------------------------------

local provider = {
	Reason = "TaxiFare", -- replaced by TaxiRules.REASON at start
	PayLabel = "Taxi fare",
	Boards = true,
}

function provider.ReadConfig()
	return config()
end

function provider.Enabled()
	return enabled()
end

function provider.CanAccept(_player, vehicle)
	local seat = passengerSeat(vehicle)
	if not seat then return false, "Your car has no passenger seat." end
	if seat.Occupant or PassengerService.GetOccupant(vehicle) then return false, "Your passenger seat is taken." end
	return true
end

-- Called on its own thread (building a rig may yield); the offer can change meanwhile.
function provider.OfferNear(offer, near)
	if near then
		if (offer.Rig and offer.Rig.Parent) or offer.Building then return end
		offer.Building = true
		local rig = buildRig(offer.Id, offer.Position, offer.Facing, config().HailAnimationId)
		offer.Building = false
		if rig and (offer.Removed or not offer.Near) then
			rig:Destroy()
			return
		end
		offer.Rig = rig
	elseif offer.Rig then
		offer.Rig:Destroy()
		offer.Rig = nil
	end
end

function provider.OfferRemoved(offer, taken)
	if not taken and offer.Rig then
		offer.Rig:Destroy()
		offer.Rig = nil
	end
end

local function board(player, trip, vehicle)
	local cfg = trip.Config
	local rig = trip.Rig
	local humanoid = rig and rig:FindFirstChildOfClass("Humanoid")
	local hrp = rig and rig:FindFirstChild("HumanoidRootPart")
	local seat = passengerSeat(vehicle)
	if humanoid and hrp and seat and cfg.BoardSeconds > 0 then
		stopHail(rig)
		setAnchoredRoot(rig, false)
		pcall(function() hrp:SetNetworkOwner(nil) end)
		local started = os.clock()
		while not trip.Closed and rig.Parent and seat.Parent do
			local goal = TaxiRules.BoardingPoint(seat.Position, seat.CFrame.RightVector, 6)
			humanoid:MoveTo(goal)
			if TaxiRules.BoardingDone((hrp.Position - goal).Magnitude, os.clock() - started, cfg) then break end
			task.wait(0.15)
		end
	end
	if trip.Closed then
		if rig and rig.Parent then rig:Destroy() end
		return
	end
	local ok = rig and rig.Parent and PassengerService.SeatNpc(vehicle, rig)
	if trip.Closed then
		if ok then PassengerService.UnseatNpc(vehicle) end
		if rig and rig.Parent then rig:Destroy() end
		return
	end
	if not ok then
		if rig and rig.Parent then rig:Destroy() end
		JobBoard.FailTrip(player, trip, "Your fare couldn't get in.")
		return
	end
	trip.Vehicle = vehicle
	JobBoard.StartDriving(trip)
end

function provider.OnAccept(player, trip, offer, vehicle)
	local rig = offer.Rig
	offer.Rig = nil
	if not (rig and rig.Parent) then
		rig = buildRig(offer.Id, offer.Position, offer.Facing, "")
	end
	if not rig then error("could not build the fare") end
	trip.Rig = rig
	task.spawn(board, player, trip, vehicle)
end

function provider.OnEnd(_player, trip, outcome)
	local rig = trip.Rig
	trip.Rig = nil
	if not rig then return end
	local vehicle = trip.Vehicle
	local seated = vehicle and PassengerService.GetOccupant(vehicle) == rig
	local seat = seated and passengerSeat(vehicle)
	local seatCFrame = seat and seat.CFrame
	if seated then PassengerService.UnseatNpc(vehicle) end
	if not rig.Parent then return end
	if outcome == "Complete" and seatCFrame then
		-- Out on the kerb side and walk to the drop-off spot on the pavement.
		rig:PivotTo(seatCFrame * CFrame.new(-6, 2.5, 0))
		walkAway(rig, trip.Destination, trip.Config.ExitWalkSeconds)
	elseif seatCFrame then
		rig:PivotTo(seatCFrame * CFrame.new(-6, 2.5, 0))
		local hrp = rig:FindFirstChild("HumanoidRootPart")
		walkAway(rig, hrp and (hrp.Position - seatCFrame.RightVector * 10) or nil, 3)
	else
		rig:Destroy()
	end
end

-- A fare that leaves the seat mid-trip (seat knocked loose, vehicle race flag, etc.) ends the trip.
local function onOccupantChanged(vehicle, occupant, previous)
	if occupant ~= nil or typeof(previous) ~= "Instance" or not previous:IsA("Model") then return end
	local trip = JobBoard.FindTripByRig(previous)
	if trip and not trip.Closed and trip.Phase == "Driving" and trip.Vehicle == vehicle then
		JobBoard.FailTrip(trip.Player, trip, "Your fare got out.")
	end
end

function TaxiJob.start()
	if state ~= "idle" then return end
	state = "starting"
	local ok, message = xpcall(function()
		local activities = ServerStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Activities")
		ActivityService = require(activities:WaitForChild("ActivityService"))
		PassengerService = require(activities:WaitForChild("PassengerService"))
		JobBoard = require(activities:WaitForChild("JobBoard"))
		TaxiRules = require(activities:WaitForChild("TaxiRules"))
		FeatureFlags = require(ServerStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("FeatureFlags"))
		provider.Reason = TaxiRules.REASON

		ActivityService.Register(KIND, {
			Actions = {},
			OnCancel = function(player, record, reason) JobBoard.HandleCancel(player, record, reason) end,
			RequiresVehicle = true,
		})
		JobBoard.RegisterProvider(KIND, provider)
		PassengerService.OccupantChanged:Connect(onOccupantChanged)
	end, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

return TaxiJob
