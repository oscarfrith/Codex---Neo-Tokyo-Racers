local Controller = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LOCAL_PLAYER = Players.LocalPlayer
local MPH_PER_STUD = 0.626
local HOVER_HEIGHT = 3
local SENSOR_START = 2
local SENSOR_LENGTH = 26
local REVERSE_MAX_MPH = 20

local state = {
	Vehicle = nil,
	Controls = nil,
	Connection = nil,
	Boost = 100,
	Yaw = 0,
	Bank = 0,
	GamepadSteer = 0,
	GamepadAccel = 0,
	GamepadBrake = 0,
	GamepadBoost = false,
	GamepadDrift = false,
	Hud = nil,
	MphLabel = nil,
	BoostFill = nil,
}

local function character()
	return LOCAL_PLAYER and LOCAL_PLAYER.Character
end

local function humanoid()
	local c = character()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function vehiclesRoot()
	local world = Workspace:FindFirstChild("HOVER_RACING_V2_WORLD")
	return world and world:FindFirstChild("PLAYER_VEHICLES_Runtime")
end

local function getPlayerVehicle()
	local root = vehiclesRoot()
	if not LOCAL_PLAYER or not root then return nil end
	for _, vehicle in ipairs(root:GetChildren()) do
		if vehicle:GetAttribute("OwnerUserId") == LOCAL_PLAYER.UserId then
			local primary = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
			if primary then
				vehicle.PrimaryPart = primary
				return vehicle
			end
		end
	end
	return nil
end

local function waitForVehicle(timeout)
	local startTime = os.clock()
	repeat
		local vehicle = getPlayerVehicle()
		if vehicle and vehicle.PrimaryPart then return vehicle end
		task.wait(0.05)
	until os.clock() - startTime > (timeout or 6)
	return nil
end

local function stat(vehicle, name, fallback)
	if not vehicle then return fallback end
	local attr = vehicle:GetAttribute(name)
	if typeof(attr) == "number" then return attr end
	local statsFolder = vehicle:FindFirstChild("TOTAL_STATS_Runtime")
	local value = statsFolder and statsFolder:FindFirstChild(name)
	if value and value:IsA("NumberValue") then return value.Value end
	return fallback
end

local function snapshot(vehicle)
	local weight = math.clamp(stat(vehicle, "Weight", 118), 60, 260)
	return {
		MaxMph = math.clamp(stat(vehicle, "TopSpeed", 126), 40, 260),
		Acceleration = math.max(stat(vehicle, "Acceleration", 42), 8) * math.clamp(118 / weight, 0.58, 1.25),
		Handling = math.max(stat(vehicle, "Handling", 48), 10) * math.clamp(125 / weight, 0.62, 1.22),
		Drift = math.max(stat(vehicle, "Drift", 46), 10) * math.clamp(122 / weight, 0.65, 1.2),
		Braking = math.max(stat(vehicle, "Braking", 44), 16) * math.clamp(115 / weight, 0.68, 1.15),
		Boost = math.max(stat(vehicle, "Boost", 0), 0),
		BoostDuration = math.max(stat(vehicle, "BoostDuration", 2), 1),
		BoostRecharge = math.max(stat(vehicle, "BoostRecharge", 9), 4),
	}
end

local function cleanup(root)
	if not root then return end
	for _, child in ipairs(root:GetChildren()) do
		if string.find(child.Name, "V61_", 1, true) or string.find(child.Name, "V60_", 1, true) or string.find(child.Name, "V59_", 1, true) or string.find(child.Name, "Drive_", 1, true) then
			child:Destroy()
		end
	end
end

local function attachment(parent, name, position)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position or Vector3.zero
	a.Parent = parent
	return a
end

local function setupControls(vehicle)
	local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
	if not root then return nil end
	vehicle.PrimaryPart = root
	cleanup(root)

	local center = attachment(root, "V61_CenterAttachment", Vector3.zero)

	local driveForce = Instance.new("VectorForce")
	driveForce.Name = "V61_ForwardForce"
	driveForce.Attachment0 = center
	driveForce.ApplyAtCenterOfMass = true
	driveForce.RelativeTo = Enum.ActuatorRelativeTo.World
	driveForce.Parent = root

	local align = Instance.new("AlignOrientation")
	align.Name = "V61_TerrainAlign"
	align.Attachment0 = center
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.MaxTorque = math.huge
	align.MaxAngularVelocity = math.huge
	align.Responsiveness = 18
	align.RigidityEnabled = false
	align.Parent = root

	local halfX = math.max(root.Size.X * 0.5, 4)
	local halfZ = math.max(root.Size.Z * 0.5, 6)
	local offsets = {
		Vector3.new(-halfX, 0, -halfZ),
		Vector3.new(halfX, 0, -halfZ),
		Vector3.new(-halfX, 0, halfZ),
		Vector3.new(halfX, 0, halfZ),
	}

	local corners = {}
	for index, offset in ipairs(offsets) do
		local a = attachment(root, "V61_HoverCornerAttachment" .. index, offset)
		local force = Instance.new("VectorForce")
		force.Name = "V61_HoverCornerForce" .. index
		force.Attachment0 = a
		force.ApplyAtCenterOfMass = false
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.Parent = root
		corners[index] = { Offset = offset, Force = force }
	end

	return { Root = root, DriveForce = driveForce, Align = align, Corners = corners }
end

local function gamepadButton(keyCode)
	local ok, result = pcall(function()
		return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, keyCode)
	end)
	return ok and result == true
end

local function updateGamepad()
	state.GamepadSteer = 0
	state.GamepadAccel = 0
	state.GamepadBrake = 0
	local ok, inputs = pcall(function()
		return UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	end)
	if ok then
		for _, input in ipairs(inputs) do
			if input.KeyCode == Enum.KeyCode.Thumbstick1 then
				state.GamepadSteer = math.abs(input.Position.X) > 0.12 and input.Position.X or 0
			elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
				state.GamepadAccel = math.clamp((input.Position.Z + 1) * 0.5, 0, 1)
			elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
				state.GamepadBrake = math.clamp((input.Position.Z + 1) * 0.5, 0, 1)
			end
		end
	end
	state.GamepadBoost = gamepadButton(Enum.KeyCode.ButtonA)
	state.GamepadDrift = gamepadButton(Enum.KeyCode.ButtonX) or gamepadButton(Enum.KeyCode.ButtonL1) or gamepadButton(Enum.KeyCode.ButtonR1)
end

local function inputValues()
	updateGamepad()
	local throttle = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then throttle += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then throttle -= 1 end
	throttle = math.clamp(throttle + state.GamepadAccel - state.GamepadBrake, -1, 1)

	local steer = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then steer -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then steer += 1 end
	steer = math.clamp(steer + state.GamepadSteer, -1, 1)

	local drift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) or state.GamepadDrift
	local boost = UserInputService:IsKeyDown(Enum.KeyCode.Space) or state.GamepadBoost
	return throttle, steer, drift, boost
end

local function groundNormal(hitPositions, normalSum, hits)
	local normal = Vector3.new(0, 1, 0)
	if hits > 0 and normalSum.Magnitude > 0.01 then normal = normalSum.Unit end
	local frontLeft, frontRight, rearLeft, rearRight = hitPositions[1], hitPositions[2], hitPositions[3], hitPositions[4]
	if frontLeft and frontRight and rearLeft and rearRight then
		local frontMid = (frontLeft + frontRight) * 0.5
		local rearMid = (rearLeft + rearRight) * 0.5
		local leftMid = (frontLeft + rearLeft) * 0.5
		local rightMid = (frontRight + rearRight) * 0.5
		local slopeForward = frontMid - rearMid
		local slopeRight = rightMid - leftMid
		if slopeForward.Magnitude > 0.05 and slopeRight.Magnitude > 0.05 then
			local planeNormal = slopeRight.Unit:Cross(slopeForward.Unit)
			if planeNormal.Y < 0 then planeNormal = -planeNormal end
			normal = planeNormal.Unit
		end
	end
	return normal
end

local function setCamera(vehicle)
	local camera = Workspace.CurrentCamera
	if not camera or not vehicle then return end
	local seat = vehicle:FindFirstChild("DriverSeat", true)
	camera.CameraType = Enum.CameraType.Custom
	if seat and seat:IsA("VehicleSeat") then
		camera.CameraSubject = seat
	else
		local h = humanoid()
		if h then camera.CameraSubject = h end
	end
end

local function makeHud()
	if state.Hud and state.Hud.Parent then return end
	local playerGui = LOCAL_PLAYER and LOCAL_PLAYER:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HOVER_RACING_V61_FallbackDriveHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0, 1)
	box.Position = UDim2.new(0, 18, 1, -22)
	box.Size = UDim2.fromOffset(205, 62)
	box.BackgroundColor3 = Color3.fromRGB(4, 12, 10)
	box.BackgroundTransparency = 0.16
	box.BorderSizePixel = 0
	box.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(172, 255, 197)
	stroke.Transparency = 0.2
	stroke.Thickness = 1
	stroke.Parent = box

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = box

	local mph = Instance.new("TextLabel")
	mph.BackgroundTransparency = 1
	mph.Position = UDim2.fromOffset(12, 6)
	mph.Size = UDim2.new(1, -24, 0, 24)
	mph.FontFace = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	mph.Text = "0 MPH"
	mph.TextColor3 = Color3.fromRGB(218, 255, 231)
	mph.TextSize = 16
	mph.TextXAlignment = Enum.TextXAlignment.Left
	mph.Parent = box

	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.fromOffset(12, 38)
	barBack.Size = UDim2.new(1, -24, 0, 10)
	barBack.BackgroundColor3 = Color3.fromRGB(42, 55, 52)
	barBack.BorderSizePixel = 0
	barBack.Parent = box

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(172, 255, 197)
	fill.BorderSizePixel = 0
	fill.Parent = barBack

	state.Hud = gui
	state.MphLabel = mph
	state.BoostFill = fill
end

local function setHud(speedMph)
	makeHud()
	if state.Hud then state.Hud.Enabled = true end
	if state.MphLabel then state.MphLabel.Text = tostring(math.floor(speedMph + 0.5)) .. " MPH" end
	if state.BoostFill then state.BoostFill.Size = UDim2.fromScale(math.clamp(state.Boost / 100, 0, 1), 1) end
end

function Controller.Stop()
	if state.Connection then state.Connection:Disconnect(); state.Connection = nil end
	if state.Controls and state.Controls.Root then cleanup(state.Controls.Root) end
	if state.Hud then state.Hud.Enabled = false end
	state.Vehicle = nil
	state.Controls = nil
end

function Controller.HasDriveForces()
	local vehicle = getPlayerVehicle()
	local root = vehicle and vehicle.PrimaryPart
	if not root then return false end
	return root:FindFirstChild("Drive_ForwardForce") ~= nil
		or root:FindFirstChild("V61_ForwardForce") ~= nil
		or root:FindFirstChild("V60_ForwardForce") ~= nil
		or root:FindFirstChild("V59_ForwardForce") ~= nil
end

function Controller.EnsureStarted(reason)
	if not Controller.HasDriveForces() then
		Controller.Start(reason or "No drive forces found after startDriving.")
	end
end

function Controller.Start(reason)
	warn("[V61] Fallback hover controller started. " .. tostring(reason or ""))
	Controller.Stop()
	local vehicle = waitForVehicle(6)
	if not vehicle or not vehicle.PrimaryPart then
		warn("[V61] Could not find spawned vehicle.")
		return false
	end

	state.Vehicle = vehicle
	state.Controls = setupControls(vehicle)
	if not state.Controls then
		warn("[V61] Could not attach hover controls.")
		return false
	end

	state.Boost = 100
	local root = state.Controls.Root
	local look = root.CFrame.LookVector
	state.Yaw = math.atan2(look.X, look.Z)
	state.Bank = 0
	setCamera(vehicle)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { vehicle, character() }

	state.Connection = RunService.Heartbeat:Connect(function(dt)
		if not state.Vehicle or not state.Vehicle.Parent or not state.Vehicle.PrimaryPart or not state.Controls then
			Controller.Stop()
			return
		end

		local h = humanoid()
		if h then h.Jump = false end

		root = state.Vehicle.PrimaryPart
		local stats = snapshot(state.Vehicle)
		local throttle, steer, driftHeld, boostHeld = inputValues()
		local mass = math.max(root.AssemblyMass, 1)
		local velocity = root.AssemblyLinearVelocity
		local forward = root.CFrame.LookVector
		local right = root.CFrame.RightVector
		local forwardSpeed = velocity:Dot(forward)
		local sideSpeed = velocity:Dot(right)
		local speedMph = velocity.Magnitude * MPH_PER_STUD

		local hitPositions = {}
		local normalSum = Vector3.zero
		local hits = 0
		local liftPerCorner = mass * Workspace.Gravity / 4
		for index, corner in ipairs(state.Controls.Corners) do
			local origin = root.CFrame:PointToWorldSpace(corner.Offset) + Vector3.new(0, SENSOR_START, 0)
			local result = Workspace:Raycast(origin, Vector3.new(0, -SENSOR_LENGTH, 0), rayParams)
			if result then
				local targetDistance = HOVER_HEIGHT + SENSOR_START
				local heightError = targetDistance - result.Distance
				local pointVelocityY = root:GetVelocityAtPosition(origin).Y
				local forceAmount = liftPerCorner + mass * (heightError * 50 - pointVelocityY * 6)
				corner.Force.Force = Vector3.new(0, math.clamp(forceAmount, 0, liftPerCorner * 4.5), 0)
				hitPositions[index] = result.Position
				normalSum += result.Normal
				hits += 1
			else
				corner.Force.Force = Vector3.new(0, liftPerCorner * 0.05, 0)
			end
		end

		local grounded = hits >= 2
		local normal = groundNormal(hitPositions, normalSum, hits)
		if forwardSpeed < -4 then steer = -steer end
		local drifting = driftHeld and forwardSpeed > 8 and speedMph > 10 and math.abs(steer) > 0.05 and grounded

		local maxForward = stats.MaxMph / MPH_PER_STUD
		local maxReverse = REVERSE_MAX_MPH / MPH_PER_STUD
		local force = Vector3.zero

		if throttle > 0 and forwardSpeed < maxForward then
			force += forward * mass * stats.Acceleration * 28 * throttle
			state.Vehicle:SetAttribute("Accelerating", true)
		elseif throttle < 0 then
			state.Vehicle:SetAttribute("Accelerating", false)
			if forwardSpeed > 4 then
				force += -forward * mass * stats.Braking * 30 * math.abs(throttle)
			elseif math.abs(forwardSpeed) < maxReverse then
				force += forward * mass * stats.Acceleration * 12 * throttle
			end
		else
			state.Vehicle:SetAttribute("Accelerating", false)
		end

		local boostActive = false
		if boostHeld and state.Boost > 0 and stats.Boost > 0 and throttle >= 0 then
			boostActive = true
			state.Boost = math.max(0, state.Boost - (100 / stats.BoostDuration) * dt)
			force += forward * mass * stats.Boost * 12
		else
			state.Boost = math.min(100, state.Boost + (100 / stats.BoostRecharge) * dt)
		end
		state.Vehicle:SetAttribute("Boosting", boostActive)
		state.Vehicle:SetAttribute("DriftingLeft", drifting and steer < -0.05)
		state.Vehicle:SetAttribute("DriftingRight", drifting and steer > 0.05)

		local grip = drifting and 1.2 or 4.2
		force += -right * sideSpeed * mass * grip
		if throttle == 0 then
			force += -forward * forwardSpeed * mass * 0.16
		end
		state.Controls.DriveForce.Force = force

		local speedFactor = math.clamp(math.abs(forwardSpeed) / 42, 0.25, 1.25)
		local turnRate = math.rad((drifting and stats.Drift or stats.Handling) * 1.15)
		state.Yaw += steer * turnRate * speedFactor * dt
		local yawForward = Vector3.new(math.sin(state.Yaw), 0, math.cos(state.Yaw))
		local terrainForward = yawForward - normal * yawForward:Dot(normal)
		if terrainForward.Magnitude < 0.05 then terrainForward = forward - normal * forward:Dot(normal) end
		terrainForward = terrainForward.Unit
		local terrainRight = terrainForward:Cross(normal).Unit
		local targetBank = math.rad(-steer * (drifting and 9 or 5))
		state.Bank += (targetBank - state.Bank) * math.clamp(dt * 5, 0, 1)
		local bankedUp = (normal * math.cos(state.Bank) + terrainRight * math.sin(state.Bank)).Unit
		local bankedRight = terrainForward:Cross(bankedUp).Unit
		state.Controls.Align.CFrame = CFrame.fromMatrix(root.Position, bankedRight, bankedUp, -terrainForward)

		setHud(speedMph)
	end)

	return true
end

return Controller
