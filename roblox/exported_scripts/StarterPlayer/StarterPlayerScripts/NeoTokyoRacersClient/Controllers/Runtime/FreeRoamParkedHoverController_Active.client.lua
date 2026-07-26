-- Neo Tokyo Racers - parked hover keeper
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4C_PARKED_HOVER

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DriveTuning = require(ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("DriveTuning")) -- NTR_DRIVING_HOVER_HEIGHT_CONFIG_BRIDGE_V1

local player = Players.LocalPlayer
local active = {}
local lastPromptSeat = nil

local SENSOR_START_HEIGHT = 2.2
local SENSOR_LENGTH = 12
local HOVER_HEIGHT = math.clamp(DriveTuning.Read().HoverHeightStuds, 0.5, 8) -- NTR_DRIVING_HOVER_HEIGHT_CONFIG_VALUE_V1
local INTERACTION_SETTINGS = ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Config"):WaitForChild("Editable"):WaitForChild("01_GAME_BALANCE_Editable"):WaitForChild("VehicleInteractions") -- NTR_VEHICLE_EXIT_COAST_DRAG_V1_1
local function interactionNumber(name,fallback,minimum,maximum)
	return math.clamp(tonumber(INTERACTION_SETTINGS:GetAttribute(name)) or fallback,minimum,maximum)
end
local SPRING = 48
local DAMPING = 6
local ALIGN_RESPONSIVENESS = 10

local function vehiclesRoot()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

local function playerVehicle()
	local root = vehiclesRoot()
	if not root then return nil end
	for _, vehicle in ipairs(root:GetChildren()) do
		if tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId then
			local primary = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
			if primary and primary:IsA("BasePart") then
				vehicle.PrimaryPart = primary
				return vehicle
			end
		end
	end
	return nil
end

local function seatOccupied(vehicle)
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	return seat and seat:IsA("VehicleSeat") and seat.Occupant ~= nil
end

local function ownerVehicleFromInstance(instance)
	local current = instance
	while current do
		if current:IsA("Model") and current:GetAttribute("OwnerUserId") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function fireSpawned()
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local ui = controllers and controllers:FindFirstChild("UI")
	local event = ui and ui:FindFirstChild("FreeRoamVehicleSpawned")
	if event and event:IsA("BindableEvent") then
		event:Fire()
	end
end

local function watchPromptReentry()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") then
		local vehicle = ownerVehicleFromInstance(seat)
		if vehicle and tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId and seat ~= lastPromptSeat then
			lastPromptSeat = seat
			vehicle:SetAttribute("ParkedShowcase", false)
			fireSpawned()
		end
	elseif lastPromptSeat ~= nil then
		lastPromptSeat = nil
	end
end

local function shouldHover(vehicle)
	if not vehicle or not vehicle.Parent or not vehicle.PrimaryPart then return false end
	if tonumber(vehicle:GetAttribute("OwnerUserId")) ~= player.UserId then return false end
	if vehicle:GetAttribute("ParkedShowcase") ~= true then return false end
	if vehicle:GetAttribute("NTR_ParkedFixed") == true or vehicle.PrimaryPart.Anchored then return false end -- NTR_VEHICLE_FIXED_PARKING_V1
	if vehicle:GetAttribute("DriverUserId") ~= nil then return false end
	if seatOccupied(vehicle) then return false end
	return true
end

local function cleanup(vehicle)
	local state = active[vehicle]
	if state and state.Connection then
		state.Connection:Disconnect()
	end
	if state and state.Root and state.Root.Parent then
		for _, child in ipairs(state.Root:GetChildren()) do
			if string.find(child.Name, "NTR_ParkedHover", 1, true) then
				child:Destroy()
			end
		end
	end
	active[vehicle] = nil
end

local function makeAttachment(root, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = root
	return attachment
end

local function start(vehicle)
	if active[vehicle] or not shouldHover(vehicle) then return end
	local root = vehicle.PrimaryPart
	for _, child in ipairs(root:GetChildren()) do
		if string.find(child.Name, "NTR_ParkedHover", 1, true) then
			child:Destroy()
		end
	end

	local center = makeAttachment(root, "NTR_ParkedHoverCenterAttachment", Vector3.zero)
	local align = Instance.new("AlignOrientation")
	align.Name = "NTR_ParkedHoverAlign"
	align.Attachment0 = center
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.RigidityEnabled = false
	align.MaxTorque = math.huge
	align.Responsiveness = ALIGN_RESPONSIVENESS
	align.Parent = root

	local halfX = math.max(root.Size.X * 0.42, 2.4)
	local halfZ = math.max(root.Size.Z * 0.42, 3.2)
	local corners = {}
	for index, offset in ipairs({
		Vector3.new(-halfX, 0, -halfZ),
		Vector3.new(halfX, 0, -halfZ),
		Vector3.new(-halfX, 0, halfZ),
		Vector3.new(halfX, 0, halfZ),
	}) do
		local attachment = makeAttachment(root, "NTR_ParkedHoverCornerAttachment" .. index, offset)
		local force = Instance.new("VectorForce")
		force.Name = "NTR_ParkedHoverCornerForce" .. index
		force.Attachment0 = attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = false
		force.Force = Vector3.zero
		force.Parent = root
		table.insert(corners, { Attachment = attachment, Force = force, Offset = offset })
	end

	local coastDrag = Instance.new("VectorForce")
	coastDrag.Name = "NTR_ParkedHoverCoastDrag"
	coastDrag.Attachment0 = center
	coastDrag.RelativeTo = Enum.ActuatorRelativeTo.World
	coastDrag.ApplyAtCenterOfMass = true
	coastDrag.Force = Vector3.zero
	coastDrag.Parent = root

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { vehicle, player.Character }
	local yawForward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if yawForward.Magnitude < 0.05 then yawForward = Vector3.new(0, 0, -1) else yawForward = yawForward.Unit end

	local state = { Root = root, Align = align, Corners = corners, CoastDrag = coastDrag }
	active[vehicle] = state
	state.Connection = RunService.Heartbeat:Connect(function()
		if not shouldHover(vehicle) or not root.Parent then
			cleanup(vehicle)
			return
		end
		local mass = math.max(root.AssemblyMass, 1)
		if vehicle:GetAttribute("NTR_ExitCoasting")==true then
			local velocity=root.AssemblyLinearVelocity
			local horizontal=Vector3.new(velocity.X,0,velocity.Z)
			local dragPerSecond=interactionNumber("ExitCoastDragPerSecond",0.8,0.05,3)
			coastDrag.Force=-horizontal*mass*dragPerSecond
		else
			coastDrag.Force=Vector3.zero
		end
		local liftPerCorner = mass * Workspace.Gravity / math.max(#corners, 1)
		local normalSum = Vector3.zero
		local hits = 0
		for _, corner in ipairs(corners) do
			local origin = root.CFrame:PointToWorldSpace(corner.Offset) + Vector3.new(0, SENSOR_START_HEIGHT, 0)
			local result = Workspace:Raycast(origin, Vector3.new(0, -SENSOR_LENGTH, 0), rayParams)
			if result then
				local targetDistance = HOVER_HEIGHT + SENSOR_START_HEIGHT
				local heightError = targetDistance - result.Distance
				local pointVelocityY = root:GetVelocityAtPosition(origin).Y
				local forceAmount = liftPerCorner + mass * (heightError * SPRING - pointVelocityY * DAMPING)
				corner.Force.Force = Vector3.new(0, math.clamp(forceAmount, 0, liftPerCorner * 4.25), 0)
				normalSum += result.Normal
				hits += 1
			else
				corner.Force.Force = Vector3.new(0, liftPerCorner * 0.05, 0)
			end
		end
		local normal = (hits > 0 and normalSum.Magnitude > 0.05) and normalSum.Unit or Vector3.yAxis
		local forward = yawForward - normal * yawForward:Dot(normal)
		if forward.Magnitude < 0.05 then
			forward = root.CFrame.LookVector
		else
			forward = forward.Unit
		end
		align.CFrame = CFrame.lookAt(root.Position, root.Position + forward, normal)
	end)
end

RunService.Heartbeat:Connect(function()
	watchPromptReentry()
	local vehicle = playerVehicle()
	if vehicle and shouldHover(vehicle) then
		start(vehicle)
	end
	for vehicleKey in pairs(active) do
		if vehicleKey ~= vehicle and (not vehicleKey.Parent or not shouldHover(vehicleKey)) then
			cleanup(vehicleKey)
		end
	end
end)
