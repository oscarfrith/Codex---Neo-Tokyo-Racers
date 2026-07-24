-- NTR_AUDIO_STATE_SERVICE_V2_CUES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local audioConfig = kit:WaitForChild("Config"):WaitForChild("Audio")
local global = audioConfig:WaitForChild("Global")
local profiles = audioConfig:WaitForChild("VehicleProfiles")
local Contract = require(kit.Shared.Modules.Common.Audio:WaitForChild("VehicleAudioStateContract"))
local remote = kit.Shared.Remotes.Audio:WaitForChild("VehicleAudioState")

local records = setmetatable({}, { __mode = "k" })
local rate = {}

local function vehiclesRoot()
	local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
	local runtime = world:WaitForChild("Runtime")
	return runtime:WaitForChild("PlayerVehicles")
end

local root = vehiclesRoot()

local function validProfileId(raw)
	local value = tostring(raw or "")
	return value ~= "" and profiles:FindFirstChild(value) ~= nil and value or nil
end

local function stampProfile(vehicle)
	local fallback = validProfileId(global:GetAttribute("FallbackProfileId")) or "GENERIC_STANDARD_AUDIO"
	local resolved = validProfileId(vehicle:GetAttribute("ResolvedAudioProfileId"))
	local standard = validProfileId(vehicle:GetAttribute("StandardAudioProfileId")) or fallback
	if not resolved then
		vehicle:SetAttribute("ResolvedAudioProfileId", standard)
		vehicle:SetAttribute("AudioProfileSource", "Standard")
		vehicle:SetAttribute("AudioProfileRevision", math.max(1, tonumber(vehicle:GetAttribute("AudioProfileRevision")) or 0))
	end
end

local function resetState(vehicle, running)
	vehicle:SetAttribute("NTRAudioIgnition", running and "Running" or "Off")
	vehicle:SetAttribute("NTRAudioDrive", "Idle")
	vehicle:SetAttribute("NTRAudioDrift", "None")
	vehicle:SetAttribute("NTRAudioBoost", "Off")
	vehicle:SetAttribute("NTRAudioCue", "")
	vehicle:SetAttribute("NTRAudioStateRevision", (tonumber(vehicle:GetAttribute("NTRAudioStateRevision")) or 0) + 1)
end

local function driverSeated(player, vehicle)
	if not player or not vehicle then return false end
	if tonumber(vehicle:GetAttribute("DriverUserId")) ~= player.UserId then return false end
	local character = player.Character
	local seat = vehicle:FindFirstChild("DriverSeat", true)
	return character ~= nil and seat ~= nil and seat:IsA("VehicleSeat") and seat.Occupant ~= nil and seat.Occupant.Parent == character
end

local function refreshOccupancy(vehicle)
	local driverId = tonumber(vehicle:GetAttribute("DriverUserId"))
	local player = driverId and Players:GetPlayerByUserId(driverId)
	resetState(vehicle, player ~= nil and driverSeated(player, vehicle))
end

local function cleanup(vehicle)
	local record = records[vehicle]
	if not record then return end
	for _, connection in ipairs(record.Connections) do connection:Disconnect() end
	records[vehicle] = nil
end

local function bindSeat(vehicle, seat)
	local record = records[vehicle]
	if not record or not (seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat") or record.Seat == seat then return end
	if record.SeatConnection then record.SeatConnection:Disconnect() end
	record.Seat = seat
	record.SeatConnection = seat:GetPropertyChangedSignal("Occupant"):Connect(function() refreshOccupancy(vehicle) end)
	table.insert(record.Connections, record.SeatConnection)
	refreshOccupancy(vehicle)
end

local function register(vehicle)
	if records[vehicle] or not vehicle:IsA("Model") then return end
	stampProfile(vehicle)
	local record = { Connections = {}, LastClientRevision = 0 }
	records[vehicle] = record
	table.insert(record.Connections, vehicle:GetAttributeChangedSignal("DriverUserId"):Connect(function() refreshOccupancy(vehicle) end))
	local seat = vehicle:FindFirstChild("DriverSeat", true)
	if seat and seat:IsA("VehicleSeat") then bindSeat(vehicle, seat) end
	table.insert(record.Connections, vehicle.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "DriverSeat" and descendant:IsA("VehicleSeat") then bindSeat(vehicle, descendant) end
	end))
	table.insert(record.Connections, vehicle.Destroying:Connect(function() cleanup(vehicle) end))
	refreshOccupancy(vehicle)
end

local function withinRate(player)
	local now = os.clock()
	local record = rate[player]
	if not record or now - record.WindowStarted >= 1 then
		record = { WindowStarted = now, Count = 0 }
		rate[player] = record
	end
	record.Count += 1
	return record.Count <= math.max(4, tonumber(global:GetAttribute("StateRateLimitPerSecond")) or 20)
end

remote.OnServerEvent:Connect(function(player, vehicle, payload)
	if global:GetAttribute("AudioSystemEnabled") ~= true or global:GetAttribute("VehicleAudioEnabled") == false then return end
	if not withinRate(player) then return end
	if not (vehicle and vehicle:IsA("Model") and vehicle.Parent == root and records[vehicle]) then return end
	if tonumber(vehicle:GetAttribute("OwnerUserId")) ~= player.UserId then return end
	if not driverSeated(player, vehicle) then return end
	local ok, stateOrReason = Contract.Validate(payload)
	if not ok then return end
	local record = records[vehicle]
	if stateOrReason.Revision <= record.LastClientRevision then return end
	record.LastClientRevision = stateOrReason.Revision
	vehicle:SetAttribute("NTRAudioIgnition", stateOrReason.Ignition)
	vehicle:SetAttribute("NTRAudioDrive", stateOrReason.Drive)
	vehicle:SetAttribute("NTRAudioDrift", stateOrReason.Drift)
	vehicle:SetAttribute("NTRAudioBoost", stateOrReason.Boost)
	if stateOrReason.Cue ~= "" then
		vehicle:SetAttribute("NTRAudioCue", stateOrReason.Cue)
		vehicle:SetAttribute("NTRAudioCueRevision", (tonumber(vehicle:GetAttribute("NTRAudioCueRevision")) or 0) + 1)
	end
	vehicle:SetAttribute("NTRAudioStateRevision", (tonumber(vehicle:GetAttribute("NTRAudioStateRevision")) or 0) + 1)
end)

root.ChildAdded:Connect(function(child) task.defer(register, child) end)
root.ChildRemoved:Connect(cleanup)
Players.PlayerRemoving:Connect(function(player) rate[player] = nil end)
for _, vehicle in ipairs(root:GetChildren()) do register(vehicle) end

print("[NTR Audio Phase 1] VehicleAudioStateService active.")
