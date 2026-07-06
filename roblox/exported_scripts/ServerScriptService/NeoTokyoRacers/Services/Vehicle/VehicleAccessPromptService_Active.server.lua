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
	if seat.Occupant ~= nil then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function enterVehicle(player, vehicle, seat)
	if not canEnter(player, vehicle, seat) then return end
	local root = findRoot(vehicle)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		vehicle.PrimaryPart = root
		pcall(function()
			root:SetNetworkOwner(player)
		end)
	end
	vehicle:SetAttribute("DriveReady", true)
	vehicle:SetAttribute("DriverUserId", player.UserId)
	vehicle:SetAttribute("ParkedShowcase", false)
	if humanoidRoot then
		humanoidRoot.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
	end
	if humanoid then
		task.wait(0.05)
		seat:Sit(humanoid)
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
	prompt.Enabled = seat.Occupant == nil
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
