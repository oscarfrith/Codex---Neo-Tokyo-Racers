-- Canonical feature implementation; startup is owned by the composition root.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
-- Neo Tokyo Racers - parked hover keeper
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DriveTuning = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("DriveTuning")) 

local player = Players.LocalPlayer
local active = {}
local lastPromptSeat = nil

local SENSOR_START_HEIGHT = 2.2
local SENSOR_LENGTH = 12
local HOVER_HEIGHT = math.clamp(DriveTuning.Read().HoverHeightStuds, 0.5, 8) 
local INTERACTION_SETTINGS = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Vehicles"):WaitForChild("Authoring"):WaitForChild("VehicleInteractions") 
local function interactionNumber(name,fallback,minimum,maximum)
	return math.clamp(tonumber(INTERACTION_SETTINGS:GetAttribute(name)) or fallback,minimum,maximum)
end
local SPRING = 48
local DAMPING = 6
local ALIGN_RESPONSIVENESS = 10

-- Parked pose: same rest height, settle and wobble family as DrivingClient (Config.Vehicles.HoverPose / HoverWobble).
local VEHICLE_CONFIG = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Vehicles")
local MPH_PER_STUD = 0.625
local poseConfig = {}
local poseConfigClock = -1
local function poseNumber(folderName, name, fallback, minimum, maximum)
	local folder = VEHICLE_CONFIG:FindFirstChild(folderName)
	local value = folder and folder:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value then value = fallback end
	return math.clamp(value, minimum, maximum)
end
local function poseBool(folderName, name, fallback)
	local folder = VEHICLE_CONFIG:FindFirstChild(folderName)
	local value = folder and folder:GetAttribute(name)
	if typeof(value) ~= "boolean" then return fallback end
	return value
end
local function refreshPoseConfig()
	local c = poseConfig
	c.SettleEnabled = poseBool("HoverPose", "SettleEnabled", true)
	c.SettleRestScale = poseNumber("HoverPose", "SettleRestScale", 0.7, 0.3, 1)
	c.SettleStartMph = poseNumber("HoverPose", "SettleStartMph", 1, 0, 40)
	c.SettleFullHeightMph = poseNumber("HoverPose", "SettleFullHeightMph", 22, 2, 200)
	c.SettleFrequencyHz = poseNumber("HoverPose", "SettleFrequencyHz", 1.3, 0.2, 4)
	c.SettleDamping = poseNumber("HoverPose", "SettleDamping", 0.3, 0.1, 2)
	c.BankLiftEnabled = poseBool("HoverPose", "BankLiftEnabled", true)
	c.BankLiftMaxStuds = poseNumber("HoverPose", "BankLiftMaxStuds", 2.4, 0, 6)
	c.BankLiftRiseHz = poseNumber("HoverPose", "BankLiftRiseHz", 4, 0.3, 6)
	c.BankLiftFallHz = poseNumber("HoverPose", "BankLiftFallHz", 1.4, 0.3, 6)
	c.MinEdgeClearanceStuds = poseNumber("HoverPose", "MinEdgeClearanceStuds", 0.25, 0, 2)
	c.LeanSpringCompensation = poseNumber("HoverPose", "LeanSpringCompensation", 1, 0, 1)
	c.ParkedExitDipStuds = poseNumber("HoverPose", "ParkedExitDipStuds", 0.1, 0, 0.6)
	c.ParkedAnchoredPresentationEnabled = poseBool("HoverPose", "ParkedAnchoredPresentationEnabled", true)
	c.WobbleEnabled = poseBool("HoverWobble", "WobbleEnabled", true) and poseBool("HoverWobble", "ParkedWobbleEnabled", true)
	c.WobbleFadeOutMph = poseNumber("HoverWobble", "WobbleFadeOutMph", 20, 1, 80)
	c.WobbleAmountDegrees = poseNumber("HoverWobble", "WobbleAmountDegrees", 1.5, 0, 8)
	c.WobbleSpeed = poseNumber("HoverWobble", "WobbleSpeed", 1.15, 0.05, 8)
	c.WobbleRandomiseAmount = poseNumber("HoverWobble", "WobbleRandomiseAmount", 0.65, 0, 2)
	c.WobblePitchMultiplier = poseNumber("HoverWobble", "WobblePitchMultiplier", 0.75, 0, 3)
	c.WobbleRollMultiplier = poseNumber("HoverWobble", "WobbleRollMultiplier", 1, 0, 3)
	c.WobbleSmoothing = poseNumber("HoverWobble", "WobbleSmoothing", 4.5, 0.25, 18)
	c.WobbleDetailAmount = poseNumber("HoverWobble", "WobbleDetailAmount", 0.6, 0, 2)
	c.WobbleBobStuds = poseNumber("HoverWobble", "WobbleBobStuds", 0.06, 0, 0.4)
	c.WobbleYawDegrees = poseNumber("HoverWobble", "WobbleYawDegrees", 0.35, 0, 4)
	c.WobbleRestBoost = poseNumber("HoverWobble", "WobbleRestBoost", 0.3, 0, 2)
	c.WobbleRestMph = poseNumber("HoverWobble", "WobbleRestMph", 4, 0.5, 40)
	c.ParkedWobbleScale = poseNumber("HoverWobble", "ParkedWobbleScale", 0.7, 0, 2)
	c.ParkedWobbleSpeedScale = poseNumber("HoverWobble", "ParkedWobbleSpeedScale", 0.85, 0.1, 3)
end
local function currentPoseConfig()
	if os.clock() - poseConfigClock > 0.25 or poseConfig.SettleRestScale == nil then
		poseConfigClock = os.clock()
		refreshPoseConfig()
	end
	return poseConfig
end
local function poseSmoothstep(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function newPose(root)
	return {
		Time = 0, Pitch = 0, Roll = 0, Yaw = 0, Bob = 0, RollTerm = 0, PitchTerm = 0,
		SeedX = math.random() * 1000, SeedY = math.random() * 1000, SeedZ = math.random() * 1000,
		Settle = nil, SettleVelocity = 0, SeedScale = nil, Lift = 0, LiftVelocity = 0, Normal = Vector3.yAxis,
		Underside = root.Size.Y * 0.5, HalfWidth = root.Size.X * 0.5, HalfLength = root.Size.Z * 0.5,
	}
end
-- Once per parked start: lowest point, and the half-width and half-length of the low parts, in root space.
local function measureBody(vehicle, root)
	local rootHalf = root.Size * 0.5
	local underside, halfWidth, halfLength = rootHalf.Y, rootHalf.X, rootHalf.Z
	local inverse = root.CFrame:Inverse()
	for _, part in ipairs(vehicle:GetDescendants()) do
		if part:IsA("BasePart") and part ~= root and part.Transparency < 0.99 then
			local rel = inverse * part.CFrame
			local half = part.Size * 0.5
			local r, u, l = rel.RightVector, rel.UpVector, rel.LookVector
			local extentX = math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z
			local extentY = math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z
			local extentZ = math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
			local y = rel.Position.Y - extentY
			if y == y and y < 0.5 then
				underside = math.max(underside, math.min(-y, rootHalf.Y + 1.5))
				local x = math.min(math.abs(rel.Position.X) + extentX, rootHalf.X + 6)
				local z = math.min(math.abs(rel.Position.Z) + extentZ, rootHalf.Z + 12)
				if x == x then halfWidth = math.max(halfWidth, x) end
				if z == z then halfLength = math.max(halfLength, z) end
			end
		end
	end
	return underside, halfWidth, halfLength
end
-- Per frame for the one parked car: wobble angles into pose.Pitch/Yaw/Roll, returns the ride height.
local function updatePose(pose, root, dt)
	local c = currentPoseConfig()
	local speedMph = root.AssemblyLinearVelocity.Magnitude * MPH_PER_STUD
	if speedMph ~= speedMph then speedMph = 0 end
	local steps = math.clamp(math.ceil(dt * 60 - 0.001), 1, 6)
	local stepTime = dt / steps

	local strength = 0
	if c.WobbleEnabled then
		local restBoost = 1 + c.WobbleRestBoost * (1 - poseSmoothstep(speedMph / c.WobbleRestMph))
		strength = (1 - math.clamp(speedMph / c.WobbleFadeOutMph, 0, 1)) * restBoost * c.ParkedWobbleScale
	end
	pose.Time += dt * c.WobbleSpeed * c.ParkedWobbleSpeedScale
	local t = pose.Time
	local seedX, seedY, seedZ = pose.SeedX, pose.SeedY, pose.SeedZ
	local randomise = c.WobbleRandomiseAmount
	local detail = c.WobbleDetailAmount
	local slowPitch = math.noise(seedX, t, 0) + math.noise(seedX + 17.3, t * 2.31, 0.5) * 0.45 * detail
	local slowRoll = math.noise(seedZ, 0, t * 1.13) + math.noise(seedZ + 41.9, 0.5, t * 2.57) * 0.45 * detail
	local radians = math.rad(c.WobbleAmountDegrees) * strength
	local targetPitch = (slowPitch + math.sin(t * 2.7 + seedX) * 0.22 * randomise) * radians * c.WobblePitchMultiplier
	local targetRoll = (slowRoll + math.sin(t * 2.1 + seedZ) * 0.22 * randomise) * radians * c.WobbleRollMultiplier
	local targetYaw = (math.noise(seedY, t * 0.71, 3.3) + math.sin(t * 0.83 + seedY) * 0.3 * randomise) * math.rad(c.WobbleYawDegrees) * strength
	local targetBob = (math.sin(t * 1.57 + seedY) * 0.6 + math.noise(seedY + 9.1, t * 0.9, 7.7) * 0.9) * c.WobbleBobStuds * strength
	local alpha = 1 - math.exp(-c.WobbleSmoothing * dt)
	pose.Pitch += (targetPitch - pose.Pitch) * alpha
	pose.Roll += (targetRoll - pose.Roll) * alpha
	pose.Yaw += (targetYaw - pose.Yaw) * alpha
	pose.Bob += (targetBob - pose.Bob) * alpha
	if pose.Pitch ~= pose.Pitch or pose.Roll ~= pose.Roll or pose.Yaw ~= pose.Yaw or pose.Bob ~= pose.Bob then
		pose.Pitch, pose.Roll, pose.Yaw, pose.Bob = 0, 0, 0, 0
	end

	local settle = 1
	if c.SettleEnabled then
		local curve = poseSmoothstep((speedMph - c.SettleStartMph) / math.max(c.SettleFullHeightMph - c.SettleStartMph, 1))
		local target = c.SettleRestScale + (1 - c.SettleRestScale) * curve
		local omega = c.SettleFrequencyHz * 2 * math.pi
		if pose.Settle == nil then
			-- continue from the height the driving controller left the car at, with a small power-down dip
			pose.Settle = math.clamp(pose.SeedScale or target, c.SettleRestScale, 1.3)
			pose.SettleVelocity = -(c.ParkedExitDipStuds / HOVER_HEIGHT) * omega / 0.65
		end
		local position, velocity = pose.Settle, pose.SettleVelocity
		for _ = 1, steps do
			velocity += (omega * omega * (target - position) - 2 * c.SettleDamping * omega * velocity) * stepTime
			position += velocity * stepTime
		end
		if position ~= position or velocity ~= velocity then
			position, velocity = target, 0
		end
		pose.Settle = math.clamp(position, 0.3, 1.5)
		pose.SettleVelocity = math.clamp(velocity, -20, 20)
		settle = pose.Settle
	else
		pose.Settle = nil
		pose.SettleVelocity = 0
	end

	local base = HOVER_HEIGHT * settle + pose.Bob
	local lift = 0
	if c.BankLiftEnabled and c.MinEdgeClearanceStuds > 0 then
		-- no bank when parked: only keep the lowest point clear at the rest height. Same sum as the driving
		-- controller (commanded wobble roll and pitch), so both rest at the same height on flat ground; the
		-- car's real tilt against the ground only counts beyond 2 degrees (the driving bank just after an
		-- exit while steering, or a base the server left tilted)
		local normal = pose.Normal
		local frame = root.CFrame
		local rollAngle = math.abs(pose.Roll)
		local pitchAngle = math.abs(pose.Pitch)
		local realRoll = math.asin(math.clamp(math.abs(frame.RightVector:Dot(normal)), 0, 1))
		local realPitch = math.asin(math.clamp(math.abs(frame.LookVector:Dot(normal)), 0, 1))
		if realRoll == realRoll then rollAngle += math.max(realRoll - rollAngle - 0.035, 0) end
		if realPitch == realPitch then pitchAngle += math.max(realPitch - pitchAngle - 0.035, 0) end
		local drop = pose.HalfWidth * math.sin(math.min(rollAngle, 0.6)) + pose.HalfLength * math.sin(math.min(pitchAngle, 0.5))
		local want = math.clamp(c.MinEdgeClearanceStuds + pose.Underside + drop - base, 0, c.BankLiftMaxStuds)
		local position, velocity = pose.Lift, pose.LiftVelocity
		for _ = 1, steps do
			local omega = (want > position and c.BankLiftRiseHz or c.BankLiftFallHz) * 2 * math.pi
			velocity += (omega * omega * (want - position) - 2 * omega * velocity) * stepTime
			position += velocity * stepTime
		end
		if position ~= position or velocity ~= velocity then
			position, velocity = want, 0
		end
		pose.Lift = math.clamp(position, 0, c.BankLiftMaxStuds)
		pose.LiftVelocity = math.clamp(velocity, -40, 40)
		lift = pose.Lift
	else
		pose.Lift = 0
		pose.LiftVelocity = 0
	end
	pose.RollTerm = math.sin(pose.Roll) * math.cos(pose.Pitch) * c.LeanSpringCompensation
	pose.PitchTerm = math.sin(pose.Pitch) * c.LeanSpringCompensation
	return math.clamp(base + lift, math.min(0.5, HOVER_HEIGHT), math.min(HOVER_HEIGHT * 2, SENSOR_LENGTH - SENSOR_START_HEIGHT - 1))
end

local function vehiclesRoot()
	local world = game:GetService("Workspace"):FindFirstChild("World")
	local runtime = world and game:GetService("Workspace"):WaitForChild("World"):FindFirstChild("Runtime")
	return runtime and game:GetService("Workspace"):WaitForChild("World"):WaitForChild("Runtime"):FindFirstChild("PlayerVehicles")
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
	local clientRoot = playerScripts and game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):FindFirstChild("Runtime")
	local controllers = clientRoot and game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):FindFirstChild("Runtime")
	local ui = controllers and game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):FindFirstChild("UI")
	local event = ui and game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI"):FindFirstChild("FreeRoamVehicleSpawned")
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
	if vehicle:GetAttribute("ParkedFixed") == true or vehicle.PrimaryPart.Anchored then return false end 
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
			if string.find(child.Name, "ParkedHover", 1, true) then
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
		if string.find(child.Name, "ParkedHover", 1, true) then
			child:Destroy()
		end
	end

	local center = makeAttachment(root, "ParkedHoverCenterAttachment", Vector3.zero)
	local align = Instance.new("AlignOrientation")
	align.Name = "ParkedHoverAlign"
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
		local attachment = makeAttachment(root, "ParkedHoverCornerAttachment" .. index, offset)
		local force = Instance.new("VectorForce")
		force.Name = "ParkedHoverCornerForce" .. index
		force.Attachment0 = attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = false
		force.Force = Vector3.zero
		force.Parent = root
		table.insert(corners, { Attachment = attachment, Force = force, Offset = offset })
	end

	local coastDrag = Instance.new("VectorForce")
	coastDrag.Name = "ParkedHoverCoastDrag"
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

	local pose = newPose(root)
	pose.Underside, pose.HalfWidth, pose.HalfLength = measureBody(vehicle, root)
	do
		-- one reading at start (not per frame): the height the car is at now, so the hand-over has no jump
		local sum, count = 0, 0
		for _, corner in ipairs(corners) do
			local origin = root.CFrame:PointToWorldSpace(corner.Offset) + Vector3.new(0, SENSOR_START_HEIGHT, 0)
			local result = Workspace:Raycast(origin, Vector3.new(0, -SENSOR_LENGTH, 0), rayParams)
			if result then
				sum += result.Distance - SENSOR_START_HEIGHT
				count += 1
			end
		end
		if count > 0 then pose.SeedScale = sum / count / HOVER_HEIGHT end
	end
	local state = { Root = root, Align = align, Corners = corners, CoastDrag = coastDrag, Pose = pose }
	active[vehicle] = state
	state.Connection = RunService.Heartbeat:Connect(function(dt)
		if not shouldHover(vehicle) or not root.Parent then
			cleanup(vehicle)
			return
		end
		local mass = math.max(root.AssemblyMass, 1)
		if vehicle:GetAttribute("ExitCoasting")==true then
			local velocity=root.AssemblyLinearVelocity
			local horizontal=Vector3.new(velocity.X,0,velocity.Z)
			local dragPerSecond=interactionNumber("ExitCoastDragPerSecond",0.8,0.05,3)
			coastDrag.Force=-horizontal*mass*dragPerSecond
		else
			coastDrag.Force=Vector3.zero
		end
		local rideHeight = updatePose(pose, root, math.clamp(tonumber(dt) or 1 / 60, 1 / 240, 0.1))
		local liftPerCorner = mass * Workspace.Gravity / math.max(#corners, 1)
		local normalSum = Vector3.zero
		local hits = 0
		for _, corner in ipairs(corners) do
			local origin = root.CFrame:PointToWorldSpace(corner.Offset) + Vector3.new(0, SENSOR_START_HEIGHT, 0)
			local result = Workspace:Raycast(origin, Vector3.new(0, -SENSOR_LENGTH, 0), rayParams)
			if result then
				local targetDistance = rideHeight + SENSOR_START_HEIGHT + corner.Offset.X * pose.RollTerm - corner.Offset.Z * pose.PitchTerm
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
		pose.Normal = normal
		align.CFrame = CFrame.lookAt(root.Position, root.Position + forward, normal) * CFrame.Angles(pose.Pitch, pose.Yaw, pose.Roll)
	end)
end

-- Anchored parked car (the server anchors the car on exit: ParkedFixed). Nothing simulates it, so the local
-- player's own car is posed here by writing root.CFrame: same rest height, settle and wobble as the keeper above.
-- Local only (a client write to a server-anchored part does not replicate). No forces, no constraints.
local present = { Vehicle = nil, Root = nil, Seat = nil, Base = nil, Last = nil, Pose = nil, GroundY = 0, Normal = Vector3.yAxis, RayClock = 0, RetryClock = 0, RayParams = nil }
local lastFreeVehicle, lastFreeY, lastFreeClock = nil, 0, -10

local function presentationWanted(vehicle)
	if not vehicle or not vehicle.Parent then return false end
	local root = vehicle.PrimaryPart
	if not root or not root.Anchored then return false end
	if vehicle:GetAttribute("ParkedShowcase") ~= true then return false end
	if vehicle:GetAttribute("DriverUserId") ~= nil then return false end
	return true
end

local function stopPresentation(restore)
	local root = present.Root
	if restore and root and root.Parent and root.Anchored and present.Base and present.Last then
		-- put the car back exactly where the server placed it, unless the server has moved it since
		if (root.CFrame.Position - present.Last.Position).Magnitude < 0.02 then
			root.CFrame = present.Base
		end
	end
	present.Vehicle = nil
	present.Root = nil
	present.Seat = nil
	present.Base = nil
	present.Last = nil
	present.Pose = nil
end

local function presentationGround(vehicle, position)
	local params = present.RayParams
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		present.RayParams = params
	end
	params.FilterDescendantsInstances = { vehicle, player.Character }
	return Workspace:Raycast(position + Vector3.new(0, SENSOR_START_HEIGHT, 0), Vector3.new(0, -SENSOR_LENGTH, 0), params)
end

local function updateAnchoredPresentation(vehicle, dt)
	local now = os.clock()
	if present.Vehicle then
		local seat = present.Seat
		if present.Vehicle ~= vehicle or present.Root ~= vehicle.PrimaryPart or not presentationWanted(vehicle) or (seat and seat.Occupant ~= nil) then
			stopPresentation(false)
		elseif not currentPoseConfig().ParkedAnchoredPresentationEnabled then
			stopPresentation(true)
		end
	end
	local root = vehicle and vehicle.PrimaryPart
	if not root then return end

	if not present.Vehicle then
		if not presentationWanted(vehicle) then
			-- remember where the car really is while it is driven or coasting: the anchor arrives with the
			-- server's older height, and the presentation starts from this one instead
			local y = root.Position.Y
			if y == y then
				lastFreeVehicle, lastFreeY, lastFreeClock = vehicle, y, now
			end
			return
		end
		if now < present.RetryClock then return end
		if not currentPoseConfig().ParkedAnchoredPresentationEnabled then return end
		present.RetryClock = now + 0.5
		if seatOccupied(vehicle) then return end
		local base = root.CFrame
		local basePosition = base.Position
		if basePosition.X ~= basePosition.X or basePosition.Y ~= basePosition.Y or basePosition.Z ~= basePosition.Z then return end
		local hit = presentationGround(vehicle, basePosition)
		if not hit then return end
		local baseHeight = basePosition.Y - hit.Position.Y
		if baseHeight < 0.3 or baseHeight > HOVER_HEIGHT * 2 then return end
		local keeper = active[vehicle]
		local pose = keeper and keeper.Pose
		if not pose then
			pose = newPose(root)
			pose.Underside, pose.HalfWidth, pose.HalfLength = measureBody(vehicle, root)
			pose.SeedScale = baseHeight / HOVER_HEIGHT
		end
		if lastFreeVehicle == vehicle and now - lastFreeClock < 0.5 and math.abs(lastFreeY - basePosition.Y) < 4 then
			-- continue from the height the car was last seen at on this client
			local scale = (lastFreeY - hit.Position.Y) / HOVER_HEIGHT
			if pose.Settle ~= nil then
				pose.Settle = math.clamp(scale, 0.3, 1.5)
			else
				pose.SeedScale = scale
			end
		end
		local seat = vehicle:FindFirstChild("DriverSeat", true)
		present.Vehicle = vehicle
		present.Root = root
		present.Seat = (seat and seat:IsA("VehicleSeat")) and seat or nil
		present.Base = base
		present.Last = base
		present.Pose = pose
		present.GroundY = hit.Position.Y
		present.Normal = hit.Normal
		present.RayClock = now + 1
		present.RetryClock = 0
	end

	local pose = present.Pose
	local current = root.CFrame
	local last = present.Last
	if (current.Position - last.Position).Magnitude > 0.02 or current.LookVector:Dot(last.LookVector) < 0.99999 or current.UpVector:Dot(last.UpVector) < 0.99999 then
		-- the server moved the anchored car: its new placement is the base from now on
		present.Base = current
		present.RayClock = 0
	end
	local base = present.Base
	local basePosition = base.Position
	if now >= present.RayClock then
		present.RayClock = now + 1
		local hit = presentationGround(vehicle, basePosition)
		if hit and hit.Position.Y == hit.Position.Y then
			present.GroundY = hit.Position.Y
			present.Normal = hit.Normal
		end
	end
	local baseHeight = basePosition.Y - present.GroundY
	if baseHeight < 0.3 or baseHeight > HOVER_HEIGHT * 2 then
		-- not sitting over the ground we measured (moved, or placed in the air): leave it as the server has it
		present.Last = current
		stopPresentation(true)
		present.RetryClock = now + 1
		return
	end
	pose.Normal = present.Normal
	local rideHeight = updatePose(pose, root, dt)
	local y = math.clamp(present.GroundY + rideHeight, basePosition.Y - 2, basePosition.Y + 1.5)
	local pitch = math.clamp(pose.Pitch, -0.05, 0.05)
	local yaw = math.clamp(pose.Yaw, -0.03, 0.03)
	local roll = math.clamp(pose.Roll, -0.05, 0.05)
	if y ~= y or pitch ~= pitch or yaw ~= yaw or roll ~= roll then return end
	root.CFrame = CFrame.new(basePosition.X, y, basePosition.Z) * base.Rotation * CFrame.Angles(pitch, yaw, roll)
	present.Last = root.CFrame
end

-- Keeps the remembered height current after physics (Heartbeat); the presentation itself runs before render.
local function trackFreeHeight(vehicle)
	if present.Vehicle or not vehicle then return end
	local root = vehicle.PrimaryPart
	if not root or presentationWanted(vehicle) then return end
	local y = root.Position.Y
	if y == y then
		lastFreeVehicle, lastFreeY, lastFreeClock = vehicle, y, os.clock()
	end
end

-- One connection for the module. The anchor (with the server's older CFrame) arrives through replication after
-- Heartbeat, so the pose is written here, before the frame is drawn. The springs advance once per rendered frame.
local ownVehicle = nil
RunService.PreRender:Connect(function(dt)
	local vehicle = ownVehicle
	if not vehicle and not present.Vehicle then return end
	if vehicle and not vehicle.Parent then
		vehicle = nil
		ownVehicle = nil
	end
	if not vehicle then
		if present.Vehicle then stopPresentation(false) end
		return
	end
	updateAnchoredPresentation(vehicle, math.clamp(tonumber(dt) or 1 / 60, 1 / 240, 0.1))
end)

RunService.Heartbeat:Connect(function()
	watchPromptReentry()
	local vehicle = playerVehicle()
	if vehicle and shouldHover(vehicle) then
		start(vehicle)
	end
	ownVehicle = vehicle
	trackFreeHeight(vehicle)
	for vehicleKey in pairs(active) do
		if vehicleKey ~= vehicle and (not vehicleKey.Parent or not shouldHover(vehicleKey)) then
			cleanup(vehicleKey)
		end
	end
end)

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
