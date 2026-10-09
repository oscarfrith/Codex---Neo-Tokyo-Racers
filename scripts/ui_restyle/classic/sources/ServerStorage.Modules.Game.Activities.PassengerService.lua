-- Canonical feature implementation; startup is owned by the composition root (ServerBase).
-- Street Life passenger seats (design 4.7). Owns who sits in a vehicle's "PassengerSeat" (a plain
-- Seat added by VehicleBuildService), the rider mass override while seated (massless parts) and
-- every ejection. Collision groups stay with VehicleCollisionServer (canonical owner); not written here. Driving stays keyed to OwnerUserId, so a seated
-- passenger never drives. TaxiJob uses the public API to seat NPC fares and grant taxi allowances.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("Signal"))

local PassengerService = {}
PassengerService.OccupantChanged = Signal.new() -- (vehicle, occupant: Player | Model | nil, previous, reason)

local KIND = "Passenger"
local SEAT_NAME = "PassengerSeat"
local VALID_ACCESS = { Friends = true, Anyone = true, Nobody = true }

local state = "idle"
local ActivityService, FeatureFlags

local seats = {} -- [vehicle] = { Seat, Occupant, Kind = "Player"|"Npc", Restore, Connections, RecordId }
local riders = {} -- [player] = vehicle
local allowances = {} -- ["owner:rider"] = expiry (os.clock)
local friendCache = {} -- ["a:b"] = { Value, At }
local lastRideAttempt = {} -- [player] = os.clock

local function config()
	return ActivityService.Config("Passengers")
end

local function number(key, default, minimum, maximum)
	return ActivityService.Number(config(), key, default, minimum, maximum)
end

local function enabled()
	local folder = config()
	return FeatureFlags.IsEnabled("EnablePassengers", true) and folder ~= nil and folder:GetAttribute("Enabled") ~= false
end

local function rootOf(vehicle)
	return vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
end

local function seatOf(vehicle)
	local seat = vehicle and vehicle:FindFirstChild(SEAT_NAME, true)
	if seat and seat:IsA("Seat") then return seat end
	return nil
end

local function humanoidOf(model)
	return model and model:FindFirstChildOfClass("Humanoid")
end

-- The seated model for a record: the player's character or the NPC rig.
local function modelOf(record)
	if record.Kind == "Player" then return record.Occupant.Character end
	return record.Occupant
end

local function vehicleBlocked(vehicle, owner)
	if vehicle:GetAttribute("RaceParticipant") == true or vehicle:GetAttribute("RaceRunId") ~= nil then
		return "That car is in a race."
	end
	if owner and (owner:GetAttribute("GarageSessionActive") == true or owner:GetAttribute("OwnedGarageInside") == true) then
		return "The owner is in their garage."
	end
	if owner and owner:GetAttribute("RaceQueueActive") == true then
		return "The owner is joining a race."
	end
	return nil
end

-- Mass override while seated: every BasePart massless (DrivingClient scales forces with
-- root.AssemblyMass). Originals are restored. Collision groups are not touched (VehicleCollisionServer).
local function applySeatedPhysics(model, restore)
	local function apply(part)
		if not part:IsA("BasePart") or restore[part] then return end
		restore[part] = { Massless = part.Massless }
		part.Massless = true
	end
	for _, item in ipairs(model:GetDescendants()) do apply(item) end
	return model.DescendantAdded:Connect(apply)
end

local function restorePhysics(restore)
	for part, original in pairs(restore) do
		if part.Parent then
			part.Massless = original.Massless
		end
	end
	table.clear(restore)
end

local function exitCFrame(seatCFrame)
	local side = number("ExitSideStuds", 6, 3, 12)
	return seatCFrame * CFrame.new(-side, 2.5, 0) -- the driver exits on +X, passengers on -X
end

local function placeBeside(model, seatCFrame)
	if not (model and model.Parent and seatCFrame) then return end
	model:PivotTo(exitCFrame(seatCFrame))
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
end

local function push(player, payload)
	if player and player.Parent then ActivityService.Push(player, payload) end
end

-- Single release path for players and NPCs. `place` moves the occupant beside the seat.
local function release(vehicle, reason, place, seatCFrame)
	local record = seats[vehicle]
	if not record then return nil end
	seats[vehicle] = nil
	for _, connection in ipairs(record.Connections) do connection:Disconnect() end
	local occupant = record.Occupant
	local model = modelOf(record)
	local humanoid = humanoidOf(model)
	local cframe = seatCFrame or (record.Seat.Parent and record.Seat.CFrame)
	if humanoid and humanoid.SeatPart == record.Seat then humanoid.Sit = false end
	local weld = record.Seat:FindFirstChild("SeatWeld")
	if weld then weld:Destroy() end
	restorePhysics(record.Restore)
	if place and model and humanoid and humanoid.Health > 0 then placeBeside(model, cframe) end
	if record.Kind == "Player" then
		riders[occupant] = nil
		if record.RecordId and reason ~= "CoreCancel" then
			pcall(ActivityService.End, occupant, record.RecordId, "Complete")
		end
		local owner = Players:GetPlayerByUserId(tonumber(vehicle:GetAttribute("OwnerUserId")) or 0)
		push(occupant, { Type = "Passenger:Left", Reason = reason })
		push(owner, { Type = "Passenger:Left", Reason = reason, RiderUserId = occupant.UserId, Name = occupant.DisplayName })
	end
	PassengerService.OccupantChanged:Fire(vehicle, nil, occupant, reason)
	return occupant
end

-- Watchers shared by player and NPC occupants: vehicle destroyed, race flags, owner garage flags.
local function watchVehicle(vehicle, record)
	local owner = Players:GetPlayerByUserId(tonumber(vehicle:GetAttribute("OwnerUserId")) or 0)
	local function check()
		if seats[vehicle] ~= record then return end
		local blocked = vehicleBlocked(vehicle, owner)
		if blocked then release(vehicle, blocked, true) end
	end
	table.insert(record.Connections, vehicle.Destroying:Connect(function()
		local cframe = record.Seat.Parent and record.Seat.CFrame
		release(vehicle, "Vehicle removed.", true, cframe)
	end))
	table.insert(record.Connections, vehicle.AncestryChanged:Connect(function()
		if not vehicle:IsDescendantOf(workspace) then release(vehicle, "Vehicle removed.", false) end
	end))
	for _, key in ipairs({ "RaceParticipant", "RaceRunId" }) do
		table.insert(record.Connections, vehicle:GetAttributeChangedSignal(key):Connect(check))
	end
	if owner then
		for _, key in ipairs({ "GarageSessionActive", "OwnedGarageInside", "RaceQueueActive" }) do
			table.insert(record.Connections, owner:GetAttributeChangedSignal(key):Connect(check))
		end
	end
	table.insert(record.Connections, record.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local model = modelOf(record)
		local humanoid = humanoidOf(model)
		if record.Seat.Occupant ~= humanoid then
			-- Jumped out (players) or knocked loose: release in place beside the car.
			task.defer(function()
				if seats[vehicle] == record and record.Seat.Occupant ~= humanoid then
					release(vehicle, "Left the seat.", record.Kind == "Player")
				end
			end)
		end
	end))
end

-- Seat a humanoid model and confirm the weld; returns true when seated.
local function sitModel(seat, model)
	local humanoid = humanoidOf(model)
	if not humanoid then return false end
	model:PivotTo(seat.CFrame + Vector3.new(0, 2, 0))
	seat:Sit(humanoid)
	local deadline = os.clock() + 1
	while seat.Occupant ~= humanoid and os.clock() < deadline do task.wait() end
	return seat.Occupant == humanoid
end

local function allowanceKey(ownerUserId, riderUserId)
	return tostring(ownerUserId) .. ":" .. tostring(riderUserId)
end

local function hasAllowance(ownerUserId, riderUserId)
	local expiry = allowances[allowanceKey(ownerUserId, riderUserId)]
	return expiry ~= nil and os.clock() < expiry
end

local function areFriends(rider, owner)
	local key = allowanceKey(math.min(rider.UserId, owner.UserId), math.max(rider.UserId, owner.UserId))
	local cached = friendCache[key]
	local ttl = number("FriendCacheSeconds", 120, 10, 3600)
	if cached and os.clock() - cached.At < ttl then return cached.Value end
	local ok, result = pcall(function() return rider:IsFriendsWith(owner.UserId) end)
	if not ok then return cached and cached.Value or false end
	friendCache[key] = { Value = result == true, At = os.clock() }
	return result == true
end

local function accessAllows(rider, owner)
	if hasAllowance(owner.UserId, rider.UserId) then return true end
	local access = owner:GetAttribute("PassengerAccess")
	if not VALID_ACCESS[access] then
		access = config() and config():GetAttribute("DefaultAccess")
		if not VALID_ACCESS[access] then access = "Friends" end
	end
	if access == "Anyone" then return true end
	if access == "Friends" then return areFriends(rider, owner) end
	return false
end

local function horizontalMph(part)
	local v = part.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude * 0.625
end

local function validateRide(rider, owner)
	if not enabled() then return nil, "Passenger seats are off right now." end
	if not owner or owner == rider then return nil, "Pick someone else's car." end
	local vehicle = ActivityService.GetVehicle(owner)
	local seat = seatOf(vehicle)
	local root = rootOf(vehicle)
	if not (vehicle and seat and root) then return nil, "That car has no passenger seat." end
	local blocked = vehicleBlocked(vehicle, owner)
	if blocked then return nil, blocked end
	if seats[vehicle] or seat.Occupant then return nil, "The passenger seat is taken." end
	local character = rider.Character
	local humanoid = humanoidOf(character)
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and hrp and humanoid.Health > 0) then return nil, "You can't ride right now." end
	if humanoid.SeatPart then return nil, "Get out of your seat first." end
	if riders[rider] then return nil, "You are already riding." end
	if (hrp.Position - seat.Position).Magnitude > number("RideRangeStuds", 18, 6, 40) then return nil, "Get closer to the car." end
	if horizontalMph(root) > number("BoardMaxMph", 12, 1, 60) then return nil, "Wait for the car to stop." end
	return vehicle, seat
end

local function ride(player, args)
	if type(args) ~= "table" then return { Ok = false, Message = "Invalid request." } end
	local now = os.clock()
	if lastRideAttempt[player] and now - lastRideAttempt[player] < 1 then return { Ok = false, Message = "Slow down." } end
	lastRideAttempt[player] = now
	local ownerUserId = tonumber(args.OwnerUserId)
	local owner = ownerUserId and Players:GetPlayerByUserId(ownerUserId)
	local vehicle, seatOrMessage = validateRide(player, owner)
	if not vehicle then return { Ok = false, Message = seatOrMessage } end
	local busy, reason = ActivityService.IsBusy(player)
	if busy then return { Ok = false, Message = reason or "Finish what you are doing first." } end
	if not accessAllows(player, owner) then
		return { Ok = false, Message = owner.DisplayName .. " isn't taking passengers." }
	end
	-- The friends lookup can yield: validate again before seating.
	vehicle, seatOrMessage = validateRide(player, owner)
	if not vehicle then return { Ok = false, Message = seatOrMessage } end
	local seat = seatOrMessage
	local activity, err = ActivityService.Begin(player, KIND, { OwnerUserId = owner.UserId })
	if not activity then return { Ok = false, Message = err or "You can't ride right now." } end

	local record = { Seat = seat, Occupant = player, Kind = "Player", Restore = {}, Connections = {}, RecordId = activity.Id }
	seats[vehicle] = record
	riders[player] = vehicle
	local character = player.Character
	table.insert(record.Connections, applySeatedPhysics(character, record.Restore))
	if not sitModel(seat, character) then
		release(vehicle, "Could not sit.", false)
		return { Ok = false, Message = "Couldn't get into the seat. Try again." }
	end
	local humanoid = humanoidOf(character)
	table.insert(record.Connections, humanoid.Died:Connect(function() release(vehicle, "Died.", false) end))
	table.insert(record.Connections, player.CharacterRemoving:Connect(function() release(vehicle, "Respawned.", false) end))
	watchVehicle(vehicle, record)
	push(player, { Type = "Passenger:Seated", OwnerUserId = owner.UserId, Name = owner.DisplayName })
	push(owner, { Type = "Passenger:Joined", RiderUserId = player.UserId, Name = player.DisplayName })
	PassengerService.OccupantChanged:Fire(vehicle, player, nil, "Seated")
	return { Ok = true, Message = "Riding with " .. owner.DisplayName .. "." }
end

local function leaveRide(player)
	local vehicle = riders[player]
	if not vehicle then return { Ok = false, Message = "You are not riding." } end
	release(vehicle, "Left the ride.", true)
	return { Ok = true }
end

-- Public API ----------------------------------------------------------------------------------

-- Let `riderUserId` ride in `ownerUserId`'s car for `seconds` regardless of PassengerAccess (taxi).
function PassengerService.AllowRide(ownerUserId, riderUserId, seconds)
	seconds = math.clamp(tonumber(seconds) or 120, 1, 1800)
	allowances[allowanceKey(ownerUserId, riderUserId)] = os.clock() + seconds
	local rider = Players:GetPlayerByUserId(riderUserId)
	if rider and ActivityService then
		push(rider, { Type = "Passenger:Allowed", OwnerUserId = ownerUserId, Seconds = seconds })
	end
end

-- Ends a taxi allowance. A rider still seated in that owner's car is ejected unless the owner's
-- PassengerAccess allows them anyway (friends check yields, so it runs on its own thread).
function PassengerService.RevokeRide(ownerUserId, riderUserId)
	allowances[allowanceKey(ownerUserId, riderUserId)] = nil
	local rider = Players:GetPlayerByUserId(riderUserId)
	if not (rider and ActivityService) then return end
	push(rider, { Type = "Passenger:Revoked", OwnerUserId = ownerUserId })
	local vehicle = riders[rider]
	if not (vehicle and tonumber(vehicle:GetAttribute("OwnerUserId")) == ownerUserId) then return end
	task.spawn(function()
		local owner = Players:GetPlayerByUserId(ownerUserId)
		local allowed = owner ~= nil and rider.Parent ~= nil and accessAllows(rider, owner)
		if not allowed and riders[rider] == vehicle then release(vehicle, "Your taxi ride ended.", true) end
	end)
end

-- Seat an NPC rig (TaxiJob). The rig must have a Humanoid; it is unanchored here.
function PassengerService.SeatNpc(vehicle, rig)
	local seat = seatOf(vehicle)
	if not (seat and rig and humanoidOf(rig)) then return false, "No seat." end
	if seats[vehicle] or seat.Occupant then return false, "The passenger seat is taken." end
	local record = { Seat = seat, Occupant = rig, Kind = "Npc", Restore = {}, Connections = {} }
	seats[vehicle] = record
	table.insert(record.Connections, applySeatedPhysics(rig, record.Restore))
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") then part.Anchored = false end
	end
	if not sitModel(seat, rig) then
		release(vehicle, "Could not sit.", false)
		return false, "Could not seat the fare."
	end
	table.insert(record.Connections, rig.AncestryChanged:Connect(function()
		if not rig:IsDescendantOf(workspace) then release(vehicle, "Fare removed.", false) end
	end))
	watchVehicle(vehicle, record)
	PassengerService.OccupantChanged:Fire(vehicle, rig, nil, "Seated")
	return true
end

-- Unseat the NPC (no placement; the caller places it). Returns the rig or nil.
function PassengerService.UnseatNpc(vehicle)
	local record = seats[vehicle]
	if not (record and record.Kind == "Npc") then return nil end
	return release(vehicle, "Dropped off.", false)
end

function PassengerService.GetOccupant(vehicle)
	local record = seats[vehicle]
	return record and record.Occupant or nil
end

function PassengerService.GetRide(player)
	return riders[player]
end

function PassengerService.Eject(vehicle, reason)
	return release(vehicle, reason or "Ejected.", true)
end

-- Startup ---------------------------------------------------------------------------------------

function PassengerService.start()
	if state ~= "idle" then return end
	state = "starting"
	local ok, message = xpcall(function()
		local Activities = ServerStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Activities")
		ActivityService = require(Activities:WaitForChild("ActivityService"))
		FeatureFlags = require(ServerStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("FeatureFlags"))

		ActivityService.Register(KIND, {
			RequiresVehicle = false,
			Actions = {
				Ride = ride,
				LeaveRide = leaveRide,
			},
			OnCancel = function(player)
				local vehicle = riders[player]
				if vehicle then release(vehicle, "CoreCancel", player.Parent ~= nil) end
			end,
		})

		Players.PlayerRemoving:Connect(function(player)
			local vehicle = riders[player]
			if vehicle then release(vehicle, "Left the game.", false) end
			for ownedVehicle in pairs(seats) do
				if tonumber(ownedVehicle:GetAttribute("OwnerUserId")) == player.UserId then
					release(ownedVehicle, "The driver left.", true)
				end
			end
			lastRideAttempt[player] = nil
			local prefix, suffix = tostring(player.UserId) .. ":", ":" .. tostring(player.UserId)
			for key in pairs(allowances) do
				if string.sub(key, 1, #prefix) == prefix or string.sub(key, -#suffix) == suffix then allowances[key] = nil end
			end
			for key in pairs(friendCache) do
				if string.sub(key, 1, #prefix) == prefix or string.sub(key, -#suffix) == suffix then friendCache[key] = nil end
			end
		end)

		-- Safety sweep: expired allowances and seats whose occupant vanished without a signal.
		task.spawn(function()
			while true do
				task.wait(2)
				local now = os.clock()
				for key, expiry in pairs(allowances) do
					if now >= expiry then allowances[key] = nil end
				end
				for vehicle, record in pairs(seats) do
					if not vehicle.Parent or not record.Seat.Parent then
						release(vehicle, "Vehicle removed.", false)
					end
				end
			end
		end)
	end, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

return PassengerService
