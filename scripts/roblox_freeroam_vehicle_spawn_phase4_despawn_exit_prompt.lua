-- Neo Tokyo Racers - Free Roam Vehicle Spawn Phase 4
-- Fixes the free-roam DESPAWN button, adds a driving-only EXIT VEHICLE button,
-- and installs an owner-only ProximityPrompt for re-entering parked vehicles.
--
-- Run in Roblox Studio Command Bar while the place is open.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerScriptService = game:GetService("ServerScriptService")

local SERVER_MARKER = "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_SERVER"
local CLIENT_MARKER = "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_CLIENT"
local PROMPT_SERVICE_NAME = "VehicleAccessPromptService_Active"
local EXIT_CLIENT_NAME = "FreeRoamVehicleExitButton_Active"

local function info(message)
	print("[NTR Free Roam Vehicle Spawn Phase 4] " .. tostring(message))
end

local function assertChild(parent, name)
	local child = parent and parent:FindFirstChild(name)
	assert(child, "Missing " .. tostring(name) .. " under " .. (parent and parent:GetFullName() or "nil"))
	return child
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function replaceOnce(source, oldText, newText, label)
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	assert(startIndex, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before creating another patch.")
	local before = string.sub(source, 1, startIndex - 1)
	local after = string.sub(source, endIndex + 1)
	return before .. newText .. after
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function activeGarageServer()
	return assertChild(ServerScriptService, "NeoTokyoRacers")
		:WaitForChild("Services")
		:WaitForChild("Garage")
		:WaitForChild("GarageActionController_Shadow_Disabled")
end

local function activeFreeRoamNav()
	return StarterPlayer
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("NeoTokyoRacersClient")
		:WaitForChild("Controllers")
		:WaitForChild("UI")
		:WaitForChild("FreeRoamNavController_Active")
end

local function patchServer()
	local scriptObject = activeGarageServer()
	local source = scriptObject.Source
	if findPlain(source, SERVER_MARKER) then
		info("Garage server already has Phase 4 patch.")
		return
	end

	if not findPlain(source, "DespawnVehicle = false") then
		source = replaceOnce(source, "\t\tExitVehicle = false,\n", "\t\tExitVehicle = false,\n\t\tDespawnVehicle = false,\n", "garage mutating action map")
	end

	if not findPlain(source, "seat.CanTouch = false") then
		source = replaceOnce(
			source,
			[=[			seat.CanCollide = false
			seat.CanQuery = false
			seat.Massless = true
			return seat
]=],
			[=[			seat.CanCollide = false
			seat.CanQuery = false
			seat.CanTouch = false
			seat.Massless = true
			return seat
]=],
			"existing driver seat touch disable"
		)
		source = replaceOnce(
			source,
			[=[		seat.CanCollide = false
		seat.CanQuery = false
		seat.Massless = true
		seat.Anchored = false
]=],
			[=[		seat.CanCollide = false
		seat.CanQuery = false
		seat.CanTouch = false
		seat.Massless = true
		seat.Anchored = false
]=],
			"new driver seat touch disable"
		)
	end

	local oldExit = [=[	local function V56_exitVehicle(player)
		local vehicle
		for _, candidate in ipairs(V56_vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId") == player.UserId then vehicle = candidate; break end
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
		local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
		if humanoid then humanoid.Sit = false end
		if humanoidRoot and root then humanoidRoot.CFrame = root.CFrame * CFrame.new(-14, 3, 0) end
		if vehicle then
			vehicle:SetAttribute("DriveReady", false)
			vehicle:SetAttribute("DriverUserId", nil)
		end
		return true, "Exited vehicle."
	end
]=]

	local newExit = [=[	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_SERVER
	local function V92_playerVehicle(player)
		for _, candidate in ipairs(V56_vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId") == player.UserId then
				return candidate
			end
		end
		return nil
	end

	local function V92_vehicleExitCFrame(vehicle)
		if not vehicle then return nil end
		local seat = vehicle:FindFirstChild("DriverSeat", true)
		if seat and seat:IsA("VehicleSeat") then
			return seat.CFrame * CFrame.new(-10, 3, 0)
		end
		local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
		if root and root:IsA("BasePart") then
			return root.CFrame * CFrame.new(-10, 3, 0)
		end
		return nil
	end

	local function V92_unseatAndMovePlayer(player, vehicle)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
		local exitCFrame = V92_vehicleExitCFrame(vehicle)
		if humanoid then
			humanoid.Sit = false
		end
		if humanoidRoot and exitCFrame then
			humanoidRoot.CFrame = exitCFrame
		end
	end

	local function V56_exitVehicle(player)
		local vehicle = V92_playerVehicle(player)
		V92_unseatAndMovePlayer(player, vehicle)
		if vehicle then
			vehicle:SetAttribute("DriveReady", true)
			vehicle:SetAttribute("DriverUserId", nil)
			vehicle:SetAttribute("ParkedShowcase", true)
			vehicle:SetAttribute("EngineVFXActive", true)
		end
		return true, "Exited vehicle."
	end

	local function V92_despawnVehicle(player)
		local vehicle = V92_playerVehicle(player)
		if not vehicle then
			return false, "No vehicle to despawn."
		end
		V92_unseatAndMovePlayer(player, vehicle)
		vehicle:Destroy()
		return true, "Vehicle despawned."
	end
]=]

	source = replaceOnce(source, oldExit, newExit, "parked exit/despawn server block")

	source = replaceOnce(
		source,
		[=[			elseif action == "ExitVehicle" then
				ok, message = V56_exitVehicle(player)
]=],
		[=[			elseif action == "DespawnVehicle" then
				ok, message = V92_despawnVehicle(player)
			elseif action == "ExitVehicle" then
				ok, message = V56_exitVehicle(player)
]=],
		"despawn action branch"
	)

	scriptObject.Source = source
	assert(findPlain(scriptObject.Source, SERVER_MARKER), "Server Phase 4 marker missing after patch.")
	info("Patched garage server with parked exit and true despawn.")
end

local function patchFreeRoamClient()
	local scriptObject = activeFreeRoamNav()
	local source = scriptObject.Source
	if findPlain(source, CLIENT_MARKER) then
		info("Free-roam UI already has Phase 4 patch.")
		return
	end

	local helper = [=[

-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_CLIENT
local function despawnVehicle()
	local result = callGarage("DespawnVehicle", {})
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
	end
	if result.Success == true then
		cachedProfile = result.Profile or cachedProfile
		lastProfileRead = os.clock()
	end
	setStatus((result.Success == false and result.Message) or "VEHICLE DESPAWNED", result.Success ~= false)
end
]=]

	source = replaceOnce(
		source,
		[=[
local function isGuiActuallyVisible(object, stopAt)
]=],
		helper .. [=[
local function isGuiActuallyVisible(object, stopAt)
]=],
		"free-roam despawn client helper"
	)

	source = replaceOnce(
		source,
		[=[	makeActionButton(actionBody, "DespawnVehicle", "DESPAWN", 0, theme.Exit, exitVehicle)
]=],
		[=[	makeActionButton(actionBody, "DespawnVehicle", "DESPAWN", 0, theme.Exit, despawnVehicle)
]=],
		"free-roam DESPAWN button callback"
	)

	scriptObject.Source = source
	assert(findPlain(scriptObject.Source, CLIENT_MARKER), "Client Phase 4 marker missing after patch.")
	info("Patched free-roam DESPAWN button to call DespawnVehicle.")
end

local PROMPT_SERVICE_SOURCE = [=[
-- Neo Tokyo Racers - owner vehicle enter prompt service
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_PROMPT_SERVICE

local Workspace = game:GetService("Workspace")

local PROMPT_NAME = "NTR_EnterVehiclePrompt"
local PROMPT_DISTANCE = 12
local REFRESH_SECONDS = 0.35

local function vehiclesRoot()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
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

local EXIT_CLIENT_SOURCE = [=[
-- Neo Tokyo Racers - driving-only parked exit button
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_EXIT_CLIENT

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

local function ownedVehicleSeat()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then
		return nil
	end
	local current = seat
	local vehicle = nil
	while current do
		if current:IsA("Model") and current:GetAttribute("OwnerUserId") ~= nil then
			vehicle = current
			break
		end
		current = current.Parent
	end
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

local function installPromptService()
	local services = assertChild(assertChild(ServerScriptService, "NeoTokyoRacers"), "Services")
	local vehicleFolder = ensureFolder(services, "Vehicle")
	local scriptObject = vehicleFolder:FindFirstChild(PROMPT_SERVICE_NAME)
	if not scriptObject then
		scriptObject = Instance.new("Script")
		scriptObject.Name = PROMPT_SERVICE_NAME
		scriptObject.Parent = vehicleFolder
	end
	scriptObject.Disabled = false
	scriptObject.Source = PROMPT_SERVICE_SOURCE
	info("Installed owner-only vehicle enter prompt service.")
end

local function installExitClient()
	local uiFolder = StarterPlayer
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("NeoTokyoRacersClient")
		:WaitForChild("Controllers")
		:WaitForChild("UI")
	local scriptObject = uiFolder:FindFirstChild(EXIT_CLIENT_NAME)
	if not scriptObject then
		scriptObject = Instance.new("LocalScript")
		scriptObject.Name = EXIT_CLIENT_NAME
		scriptObject.Parent = uiFolder
	end
	scriptObject.Disabled = false
	scriptObject.Source = EXIT_CLIENT_SOURCE
	info("Installed driving-only exit button client.")
end

patchServer()
patchFreeRoamClient()
installPromptService()
installExitClient()

info("Phase 4 install complete. Test DESPAWN from the car menu, EXIT VEHICLE while driving, and E/tap prompt re-entry.")
