-- Neo Tokyo Racers - Free Roam Vehicle Spawn Phase 4C
-- Stops local driving/HUD/camera on parked exit, keeps the vehicle hovering
-- without drive input, and hides the car menu after a successful spawn.
--
-- Run in Roblox Studio Command Bar while the place is open.

local StarterPlayer = game:GetService("StarterPlayer")

local EXIT_STOP_MARKER = "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4C_EXIT_STOP"
local MENU_HIDE_MARKER = "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4C_HIDE_CAR_MENU"
local EXIT_CLIENT_NAME = "FreeRoamVehicleExitButton_Active"
local PARKED_HOVER_NAME = "FreeRoamParkedHoverController_Active"

local function info(message)
	print("[NTR Free Roam Vehicle Spawn Phase 4C] " .. tostring(message))
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function replaceOnce(source, oldText, newText, label)
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	assert(startIndex, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before creating another patch.")
	return string.sub(source, 1, startIndex - 1) .. newText .. string.sub(source, endIndex + 1)
end

local function clientRoot()
	return StarterPlayer
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("NeoTokyoRacersClient")
end

local function controllersRoot()
	return clientRoot():WaitForChild("Controllers")
end

local function uiFolder()
	return controllersRoot():WaitForChild("UI")
end

local function runtimeFolder()
	local folder = controllersRoot():FindFirstChild("Runtime")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Runtime"
		folder.Parent = controllersRoot()
	end
	return folder
end

local function activeFreeRoamNav()
	return uiFolder():WaitForChild("FreeRoamNavController_Active")
end

local function activeBootstrap()
	return clientRoot():WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
end

local EXIT_CLIENT_SOURCE = [=[
-- Neo Tokyo Racers - driving-only parked exit button
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_EXIT_CLIENT
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4B_EXIT_CLIENT_REPAIR
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4C_EXIT_EVENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local garageInvoke = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage"):WaitForChild("GarageInvoke")

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_FreeRoamVehicleExitButton"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 82
gui.Enabled = true
gui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "ExitVehicleButton"
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, UserInputService.TouchEnabled and -70 or -46)
button.Size = UDim2.fromOffset(UserInputService.TouchEnabled and 132 or 148, UserInputService.TouchEnabled and 38 or 34)
button.BackgroundColor3 = Color3.fromRGB(176, 70, 66)
button.BackgroundTransparency = 0.04
button.BorderSizePixel = 0
button.AutoButtonColor = true
button.Text = "EXIT VEHICLE"
button.TextColor3 = Color3.fromRGB(255, 226, 249)
button.TextSize = UserInputService.TouchEnabled and 10 or 11
button.TextStrokeTransparency = 0.25
button.Font = Enum.Font.GothamBold
button.Visible = false
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 5)
corner.Parent = button

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

local function ownedVehicleSeat()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then
		return nil
	end
	local vehicle = ownerVehicleFromInstance(seat)
	if vehicle and tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId then
		return seat, vehicle
	end
	return nil
end

local function fireExited()
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local ui = controllers and controllers:FindFirstChild("UI")
	local event = ui and ui:FindFirstChild("FreeRoamVehicleExited")
	if event and event:IsA("BindableEvent") then
		event:Fire()
	end
end

local busy = false
local function exitVehicle()
	if busy then return end
	local _, parkedVehicle = ownedVehicleSeat()
	if not parkedVehicle then return end
	busy = true
	fireExited()
	local ok = pcall(function()
		garageInvoke:InvokeServer("ExitVehicle", {})
	end)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
	end
	task.delay(0.15, function()
		if parkedVehicle and parkedVehicle.Parent then
			parkedVehicle:SetAttribute("DriveReady", true)
			parkedVehicle:SetAttribute("DriverUserId", nil)
			parkedVehicle:SetAttribute("ParkedShowcase", true)
		end
		fireExited()
	end)
	busy = false
	if not ok then
		warn("[NTR] ExitVehicle request failed.")
	end
end

button.MouseButton1Click:Connect(exitVehicle)

RunService.RenderStepped:Connect(function()
	button.Visible = ownedVehicleSeat() ~= nil
end)
]=]

local PARKED_HOVER_SOURCE = [=[
-- Neo Tokyo Racers - parked hover keeper
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4C_PARKED_HOVER

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local active = {}
local lastPromptSeat = nil

local SENSOR_START_HEIGHT = 2.2
local SENSOR_LENGTH = 12
local HOVER_HEIGHT = 3
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

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { vehicle, player.Character }
	local yawForward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if yawForward.Magnitude < 0.05 then yawForward = Vector3.new(0, 0, -1) else yawForward = yawForward.Unit end

	local state = { Root = root, Align = align, Corners = corners }
	active[vehicle] = state
	state.Connection = RunService.Heartbeat:Connect(function()
		if not shouldHover(vehicle) or not root.Parent then
			cleanup(vehicle)
			return
		end
		local mass = math.max(root.AssemblyMass, 1)
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
]=]

local function installExitClient()
	local scriptObject = uiFolder():FindFirstChild(EXIT_CLIENT_NAME)
	if not scriptObject then
		scriptObject = Instance.new("LocalScript")
		scriptObject.Name = EXIT_CLIENT_NAME
		scriptObject.Parent = uiFolder()
	end
	scriptObject.Disabled = false
	scriptObject.Source = EXIT_CLIENT_SOURCE
	info("Replaced exit-button client with local stop-driving event fire.")
end

local function installParkedHover()
	local scriptObject = runtimeFolder():FindFirstChild(PARKED_HOVER_NAME)
	if not scriptObject then
		scriptObject = Instance.new("LocalScript")
		scriptObject.Name = PARKED_HOVER_NAME
		scriptObject.Parent = runtimeFolder()
	end
	scriptObject.Disabled = false
	scriptObject.Source = PARKED_HOVER_SOURCE
	info("Installed parked hover keeper client.")
end

local function patchFreeRoamNav()
	local scriptObject = activeFreeRoamNav()
	local source = scriptObject.Source
	if findPlain(source, MENU_HIDE_MARKER) then
		info("Free-roam spawn menu auto-hide already present.")
		return
	end
	assert(findPlain(source, "fireFreeRoamVehicleSpawned()"), "Phase 4B spawn handoff is missing. Run Phase 4B before Phase 4C.")
	source = replaceOnce(
		source,
		[=[		fireFreeRoamVehicleSpawned()
]=],
		[=[		fireFreeRoamVehicleSpawned()
		-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4C_HIDE_CAR_MENU
		if actionPanel then
			actionPanel.Visible = false
			activePanel = nil
		end
]=],
		"hide free-roam car menu after successful spawn"
	)
	scriptObject.Source = source
	info("Patched free-roam car menu to hide after successful spawn.")
end

local function patchBootstrap()
	local scriptObject = activeBootstrap()
	local source = scriptObject.Source
	if findPlain(source, EXIT_STOP_MARKER) then
		info("Bootstrap exit stop handoff already present.")
		return
	end
	assert(findPlain(source, "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4B_DRIVE_HANDOFF"), "Phase 4B drive handoff is missing. Run Phase 4B before Phase 4C.")
	local block = [=[

-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4C_EXIT_STOP
local function V94_freeRoamVehicleExitedEvent()
	local clientRoot = script.Parent
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local uiFolder = controllers and controllers:FindFirstChild("UI")
	if not uiFolder then return nil end
	local event = uiFolder:FindFirstChild("FreeRoamVehicleExited")
	if event and not event:IsA("BindableEvent") then
		warn("[NTR Phase 4C] FreeRoamVehicleExited exists but is " .. event.ClassName .. ", expected BindableEvent.")
		return nil
	end
	if not event then
		event = Instance.new("BindableEvent")
		event.Name = "FreeRoamVehicleExited"
		event.Parent = uiFolder
	end
	return event
end

local V94_exitedEvent = V94_freeRoamVehicleExitedEvent()
if V94_exitedEvent then
	V94_exitedEvent.Event:Connect(function()
		local vehicle = currentVehicle
		if vehicle then
			vehicle:SetAttribute("ParkedShowcase", true)
			vehicle:SetAttribute("DriverUserId", nil)
			vehicle:SetAttribute("DriveReady", true)
		end
		stopDriving()
		local humanoid = getHumanoid()
		if humanoid then
			humanoid.Sit = false
		end
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end)
end
]=]
	source = replaceOnce(
		source,
		[=[
RunService.Heartbeat:Connect(function()
	local now = os.clock()
]=],
		block .. [=[
RunService.Heartbeat:Connect(function()
	local now = os.clock()
]=],
		"main bootstrap exit stop listener"
	)
	scriptObject.Source = source
	info("Patched main bootstrap to stop controls/HUD/camera on free-roam exit.")
end

installExitClient()
installParkedHover()
patchFreeRoamNav()
patchBootstrap()

info("Phase 4C install complete. Restart Play before testing exit, parked hover, and car-menu auto-hide.")
