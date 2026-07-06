-- Neo Tokyo Racers - Free Roam Vehicle Spawn Phase 4B
-- Repairs Phase 4's exit-button remote path, adds an explicit free-roam spawn
-- drive handoff, and disables the old automatic walk-up re-entry loop.
--
-- Run in Roblox Studio Command Bar while the place is open.

local StarterPlayer = game:GetService("StarterPlayer")
local ServerScriptService = game:GetService("ServerScriptService")

local HANDOFF_MARKER = "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4B_DRIVE_HANDOFF"
local CLIENT_FIRE_MARKER = "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4B_CLIENT_FIRE"
local AUTO_REENTRY_MARKER = "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4B_PROMPT_ONLY_REENTRY"
local EXIT_CLIENT_NAME = "FreeRoamVehicleExitButton_Active"
local PROMPT_SERVICE_NAME = "VehicleAccessPromptService_Active"

local function info(message)
	print("[NTR Free Roam Vehicle Spawn Phase 4B] " .. tostring(message))
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

local function uiFolder()
	return clientRoot():WaitForChild("Controllers"):WaitForChild("UI")
end

local function activeFreeRoamNav()
	return uiFolder():WaitForChild("FreeRoamNavController_Active")
end

local function activeBootstrap()
	return clientRoot():WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
end

local function vehicleServiceFolder()
	return ServerScriptService
		:WaitForChild("NeoTokyoRacers")
		:WaitForChild("Services")
		:WaitForChild("Vehicle")
end

local EXIT_CLIENT_SOURCE = [=[
-- Neo Tokyo Racers - driving-only parked exit button
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_EXIT_CLIENT
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4B_EXIT_CLIENT_REPAIR

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

local busy = false
local function exitVehicle()
	if busy then return end
	local _, parkedVehicle = ownedVehicleSeat()
	if not parkedVehicle then return end
	busy = true
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

local PROMPT_SERVICE_SOURCE = [=[
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
	info("Replaced exit-button client with repaired remote path and owner lookup.")
end

local function installPromptService()
	local scriptObject = vehicleServiceFolder():FindFirstChild(PROMPT_SERVICE_NAME)
	if not scriptObject then
		scriptObject = Instance.new("Script")
		scriptObject.Name = PROMPT_SERVICE_NAME
		scriptObject.Parent = vehicleServiceFolder()
	end
	scriptObject.Disabled = false
	scriptObject.Source = PROMPT_SERVICE_SOURCE
	info("Replaced enter prompt service with repaired owner lookup.")
end

local function patchFreeRoamNav()
	local scriptObject = activeFreeRoamNav()
	local source = scriptObject.Source
	if findPlain(source, CLIENT_FIRE_MARKER) then
		info("Free-roam spawn handoff fire hook already present.")
		return
	end

	local helper = [=[

-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4B_CLIENT_FIRE
local function fireFreeRoamVehicleSpawned()
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local uiFolder = controllers and controllers:FindFirstChild("UI")
	local event = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleSpawned")
	if event and event:IsA("BindableEvent") then
		event:Fire()
	end
end
]=]

	source = replaceOnce(
		source,
		[=[
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE3_CLIENT
local function spawnOwnedVehicleFromCard(row)
]=],
		helper .. [=[
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE3_CLIENT
local function spawnOwnedVehicleFromCard(row)
]=],
		"free-roam spawn handoff helper"
	)

	source = replaceOnce(
		source,
		[=[		setStatus("VEHICLE SPAWNED", true)
]=],
		[=[		setStatus("VEHICLE SPAWNED", true)
		fireFreeRoamVehicleSpawned()
]=],
		"free-roam spawn success handoff fire"
	)

	scriptObject.Source = source
	info("Patched free-roam spawn cards to fire drive handoff event.")
end

local function patchBootstrap()
	local scriptObject = activeBootstrap()
	local source = scriptObject.Source
	if not findPlain(source, HANDOFF_MARKER) then
		local handoffBlock = [=[

-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4B_DRIVE_HANDOFF
local function V93_freeRoamVehicleSpawnedEvent()
	local clientRoot = script.Parent
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local uiFolder = controllers and controllers:FindFirstChild("UI")
	if not uiFolder then return nil end
	local event = uiFolder:FindFirstChild("FreeRoamVehicleSpawned")
	if event and not event:IsA("BindableEvent") then
		warn("[NTR Phase 4B] FreeRoamVehicleSpawned exists but is " .. event.ClassName .. ", expected BindableEvent.")
		return nil
	end
	if not event then
		event = Instance.new("BindableEvent")
		event.Name = "FreeRoamVehicleSpawned"
		event.Parent = uiFolder
	end
	return event
end

local V93_spawnedEvent = V93_freeRoamVehicleSpawnedEvent()
if V93_spawnedEvent then
	V93_spawnedEvent.Event:Connect(function()
		task.defer(startDriving)
	end)
end
]=]

		source = replaceOnce(
			source,
			[=[
RunService.Heartbeat:Connect(function()
	local now = os.clock()
]=],
			handoffBlock .. [=[
RunService.Heartbeat:Connect(function()
	local now = os.clock()
]=],
			"main bootstrap free-roam drive handoff listener"
		)
	end

	if not findPlain(source, AUTO_REENTRY_MARKER) then
		source = replaceOnce(
			source,
			[=[	if (humanoidRoot.Position - targetPart.Position).Magnitude <= 6.5 then
]=],
			[=[	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4B_PROMPT_ONLY_REENTRY
	if false and (humanoidRoot.Position - targetPart.Position).Magnitude <= 6.5 then
]=],
			"disable automatic walk-up vehicle re-entry"
		)
	end

	scriptObject.Source = source
	info("Patched main bootstrap with explicit free-roam drive handoff and prompt-only re-entry.")
end

installExitClient()
installPromptService()
patchFreeRoamNav()
patchBootstrap()

info("Phase 4B repair complete. Restart Play before testing first-spawn driving, exit button, and E/touch re-entry.")
