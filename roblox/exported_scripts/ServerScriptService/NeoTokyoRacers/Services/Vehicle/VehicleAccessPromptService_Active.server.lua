-- Neo Tokyo Racers - owner vehicle enter prompt service
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_PROMPT_SERVICE
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4B_PROMPT_REPAIR

local Workspace = game:GetService("Workspace")

local PROMPT_NAME = "NTR_EnterVehiclePrompt"
local PROMPT_DISTANCE = 12
local REFRESH_SECONDS = 0.35

local function vehiclesRoot()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

local function vehicleFromInstance(instance)
	local current = instance
	while current do
		if current:IsA("Model") and current:GetAttribute("OwnerUserId") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function findSeat(vehicle)
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	if seat and seat:IsA("VehicleSeat") then
		return seat
	end
	if not vehicle then return nil end
	for _, descendant in ipairs(vehicle:GetDescendants()) do
		if descendant:IsA("VehicleSeat") then
			return descendant
		end
	end
	return nil
end

local function findRoot(vehicle)
	if not vehicle then return nil end
	return vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
end

local function canEnter(player, vehicle, seat)
	if not player or not vehicle or not seat then return false end
	if tonumber(vehicle:GetAttribute("OwnerUserId")) ~= player.UserId then return false end
	if vehicle:GetAttribute("NTR_ExitCoasting")==true then return false end -- NTR_VEHICLE_COAST_PROMPT_GUARD_V1_1
	if seat.Occupant ~= nil then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function enterVehicle(player, vehicle, seat)
	if not canEnter(player,vehicle,seat) then return end
	local root=findRoot(vehicle)
	local character=player.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local humanoidRoot=character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then return end
	vehicle.PrimaryPart=root
	root.Anchored=false -- NTR_VEHICLE_FIXED_PROMPT_REENTRY_V1
	root.AssemblyLinearVelocity=Vector3.zero
	root.AssemblyAngularVelocity=Vector3.zero
	vehicle:SetAttribute("NTR_ParkedFixed",nil)
	vehicle:SetAttribute("ParkedShowcase",false)
	vehicle:SetAttribute("DriveReady",true)
	vehicle:SetAttribute("DriverUserId",player.UserId)
	pcall(function() root:SetNetworkOwner(player) end)
	if humanoidRoot then humanoidRoot.CFrame=seat.CFrame+Vector3.new(0,2,0) end
	if humanoid then
		task.wait(0.05)
		if canEnter(player,vehicle,seat) then seat:Sit(humanoid) end
	end
end

local function ensurePrompt(vehicle)
	if not vehicle or not vehicle:IsA("Model") then return nil end
	local seat = findSeat(vehicle)
	if not seat then return nil end
	local prompt = seat:FindFirstChild(PROMPT_NAME)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.ActionText = "Enter"
		prompt.ObjectText = "Vehicle"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = PROMPT_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.Parent = seat
		prompt.Triggered:Connect(function(player)
			local currentVehicle = vehicleFromInstance(prompt)
			local currentSeat = prompt.Parent
			if currentVehicle and currentSeat and currentSeat:IsA("VehicleSeat") then
				enterVehicle(player, currentVehicle, currentSeat)
			end
		end)
	end
	prompt.Enabled = seat.Occupant == nil and vehicle:GetAttribute("NTR_ExitCoasting")~=true -- NTR_VEHICLE_COAST_PROMPT_VISIBILITY_V1_1
	return prompt
end

local function refreshAll()
	local root = vehiclesRoot()
	if not root then return end
	for _, vehicle in ipairs(root:GetChildren()) do
		ensurePrompt(vehicle)
	end
end

local root = vehiclesRoot()
if root then
	root.ChildAdded:Connect(function(child)
		task.defer(function()
			ensurePrompt(child)
		end)
	end)
end

task.spawn(function()
	while true do
		refreshAll()
		task.wait(REFRESH_SECONDS)
	end
end)
