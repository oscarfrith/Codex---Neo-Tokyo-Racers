local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local KIT_NAME = "HOVER_RACING_V2_KIT"
local CONFIG_ROOT_NAME = "00_EDIT_ME_FIRST"
local CONFIG_NAME = "DRIVER_SEAT_POSITION_DoNotRename"
local WORLD_NAME = "HOVER_RACING_V2_WORLD"
local VEHICLES_NAME = "PLAYER_VEHICLES_Runtime"

local hooked = {}
local scheduled = {}

local function readValue(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA("ValueBase") then
		return item.Value
	end
	return fallback
end

local function getConfig()
	local kit = ReplicatedStorage:FindFirstChild(KIT_NAME)
	local editRoot = kit and kit:FindFirstChild(CONFIG_ROOT_NAME)
	return editRoot and editRoot:FindFirstChild(CONFIG_NAME)
end

local function getOffset()
	local config = getConfig()
	return Vector3.new(
		readValue(config, "LocalX", 0),
		readValue(config, "LocalY", 1.45),
		readValue(config, "LocalZ", 7)
	)
end

local function showSeat()
	return readValue(getConfig(), "ShowSeatWhileTesting", false) == true
end

local function getRuntimeFolder()
	local world = Workspace:FindFirstChild(WORLD_NAME)
	return world and world:FindFirstChild(VEHICLES_NAME)
end

local function findVehicleFromInstance(instance)
	local runtime = getRuntimeFolder()
	local current = instance
	while current and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("OwnerUserId") then
			return current
		end
		if runtime and current.Parent == runtime and current:IsA("Model") then
			return current
		end
		current = current.Parent
	end
	return instance:FindFirstAncestorOfClass("Model")
end

local function findRoot(vehicle)
	if not vehicle then return nil end
	if vehicle.PrimaryPart and vehicle.PrimaryPart:IsA("BasePart") and vehicle.PrimaryPart.Name ~= "DriverSeat" then
		return vehicle.PrimaryPart
	end

	local cockpitRoot = vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
	if cockpitRoot and cockpitRoot:IsA("BasePart") then
		return cockpitRoot
	end

	local moduleRoot = vehicle:FindFirstChild("ModuleRoot_DoNotRename", true)
	if moduleRoot and moduleRoot:IsA("BasePart") then
		return moduleRoot
	end

	for _, item in ipairs(vehicle:GetDescendants()) do
		if item:IsA("BasePart") and item.Name ~= "DriverSeat" then
			return item
		end
	end

	return nil
end

local function removeSeatWelds(vehicle, seat)
	if not vehicle or not seat then return end
	for _, item in ipairs(vehicle:GetDescendants()) do
		if item:IsA("WeldConstraint") and (item.Part0 == seat or item.Part1 == seat) then
			item:Destroy()
		end
	end
end

local function prepSeat(seat)
	seat.Size = Vector3.new(2.2, 0.45, 2.2)
	seat.CanCollide = false
	seat.CanTouch = false
	seat.CanQuery = false
	seat.Massless = true
	seat.Disabled = false
	seat.Transparency = showSeat() and 0.45 or 1
	pcall(function() seat.HeadsUpDisplay = false end)
	pcall(function() seat.MaxSpeed = 0 end)
	pcall(function() seat.Torque = 0 end)
	pcall(function() seat.TurnSpeed = 0 end)
end

local function applySeatPosition(vehicle)
	if not vehicle or not vehicle.Parent then return false end

	local seat = vehicle:FindFirstChild("DriverSeat", true)
	if not (seat and seat:IsA("VehicleSeat")) then
		return false
	end

	local root = findRoot(vehicle)
	if not (root and root:IsA("BasePart")) then
		return false
	end

	prepSeat(seat)
	removeSeatWelds(vehicle, seat)

	local offset = getOffset()
	seat.CFrame = root.CFrame * CFrame.new(offset)
	seat:SetAttribute("DriverSeatOffsetControlled", true)
	seat:SetAttribute("DriverSeatLocalX", offset.X)
	seat:SetAttribute("DriverSeatLocalY", offset.Y)
	seat:SetAttribute("DriverSeatLocalZ", offset.Z)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "DriverSeatPositionWeld"
	weld.Part0 = root
	weld.Part1 = seat
	weld.Parent = seat

	return true
end

local function scheduleApply(vehicle)
	if not vehicle or scheduled[vehicle] then return end
	scheduled[vehicle] = true
	task.spawn(function()
		local waits = { 0, 0.05, 0.2, 0.6, 1.2 }
		for _, delayTime in ipairs(waits) do
			if delayTime > 0 then task.wait(delayTime) end
			if vehicle.Parent then
				applySeatPosition(vehicle)
			end
		end
		scheduled[vehicle] = nil
	end)
end

local function hookVehicle(vehicle)
	if not vehicle or hooked[vehicle] then return end
	hooked[vehicle] = true
	scheduleApply(vehicle)

	vehicle.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "DriverSeat" or descendant:IsA("WeldConstraint") then
			scheduleApply(vehicle)
		end
	end)
end

local function hookRuntime(runtime)
	if not runtime then return end
	for _, vehicle in ipairs(runtime:GetChildren()) do
		if vehicle:IsA("Model") then
			hookVehicle(vehicle)
		end
	end

	runtime.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			hookVehicle(child)
		end
	end)
end

local function hookConfig()
	local config = getConfig()
	if not config then return end

	local function reapplyAll()
		local runtime = getRuntimeFolder()
		if not runtime then return end
		for _, vehicle in ipairs(runtime:GetChildren()) do
			if vehicle:IsA("Model") then
				scheduleApply(vehicle)
			end
		end
	end

	for _, child in ipairs(config:GetChildren()) do
		if child:IsA("ValueBase") then
			child.Changed:Connect(reapplyAll)
		end
	end

	config.ChildAdded:Connect(function(child)
		if child:IsA("ValueBase") then
			child.Changed:Connect(reapplyAll)
		end
		reapplyAll()
	end)
end

local runtime = getRuntimeFolder()
if runtime then
	hookRuntime(runtime)
else
	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant.Name == VEHICLES_NAME then
			hookRuntime(descendant)
		elseif descendant.Name == "DriverSeat" and descendant:IsA("VehicleSeat") then
			local vehicle = findVehicleFromInstance(descendant)
			if vehicle then hookVehicle(vehicle) end
		end
	end)
end

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "DriverSeat" and descendant:IsA("VehicleSeat") then
		local vehicle = findVehicleFromInstance(descendant)
		if vehicle then hookVehicle(vehicle) end
	end
end)

hookConfig()
print("Hover Racing driver seat position keeper running.")
