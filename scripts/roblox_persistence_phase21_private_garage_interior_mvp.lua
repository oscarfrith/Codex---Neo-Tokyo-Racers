-- NTR Persistence Phase 21 Private Garage Interior MVP
-- Dual-mode Studio Command Bar script.
--
-- Edit mode:
--   Installs a private owner-only garage interior runtime, remotes, a lightweight client
--   streaming/fade helper, and a small elevator prompt near the dealership exit.
--
-- Play mode, CLIENT Command Bar:
--   Enters the private garage through the new remote, waits briefly, then returns to city.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local TAG = "[NTR Persistence Phase 21 Private Garage Interior MVP]"

local function info(message)
	print(TAG .. " " .. tostring(message))
end

local function waitForPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		current = current:WaitForChild(name)
	end
	return current
end

local function findPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function ensureChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, existing:GetFullName() .. " is " .. existing.ClassName .. ", expected " .. className)
		return existing
	end
	local child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

if RunService:IsRunning() then
	local player = Players.LocalPlayer
	assert(player, "Run this smoke from the CLIENT Command Bar during Play.")

	local remotes = waitForPath(ReplicatedStorage, { "NeoTokyoRacers", "Shared", "Remotes", "Garage" })
	local invoke = remotes:WaitForChild("GarageInteriorInvoke")

	local enter = invoke:InvokeServer("EnterOwnGarage", { Smoke = true })
	assert(type(enter) == "table" and enter.Ok == true, "EnterOwnGarage failed: " .. tostring(enter and enter.Error))
	info("EnterOwnGarage OK. interior=" .. tostring(enter.InteriorId) .. " owner=" .. tostring(enter.OwnerUserId))

	task.wait(1.25)

	local state = invoke:InvokeServer("GetState", {})
	assert(type(state) == "table" and state.Ok == true, "GetState failed: " .. tostring(state and state.Error))
	info("State InGarage=" .. tostring(state.InGarage) .. " interior=" .. tostring(state.InteriorId) .. " streamOk=" .. tostring(player:GetAttribute("NTR_Phase21LastStreamOk")))

	local returned = invoke:InvokeServer("ReturnToCity", { Smoke = true })
	assert(type(returned) == "table" and returned.Ok == true, "ReturnToCity failed: " .. tostring(returned and returned.Error))
	info("ReturnToCity OK. returnSource=" .. tostring(returned.ReturnSource))
	info("Expected: character briefly enters a simple private garage, client streaming helper runs, then character returns to the dealership/city fallback.")
	return
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local remotesRoot = shared:WaitForChild("Remotes")
local garageRemotes = ensureChild(remotesRoot, "Folder", "Garage")
local interiorInvoke = ensureChild(garageRemotes, "RemoteFunction", "GarageInteriorInvoke")
local transitionEvent = ensureChild(garageRemotes, "RemoteEvent", "GarageInteriorTransition")
interiorInvoke:SetAttribute("PersistencePhase21PrivateGarageInteriorMVP", true)
transitionEvent:SetAttribute("PersistencePhase21PrivateGarageInteriorMVP", true)

local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
local interactives = ensureChild(world, "Folder", "Interactives")
local interiors = ensureChild(world, "Folder", "Interiors")
local garageInstances = ensureChild(interiors, "Folder", "GarageInstances")
garageInstances:SetAttribute("PersistencePhase21PrivateGarageInteriorMVP", true)
garageInstances:SetAttribute("InteriorBasePosition", Vector3.new(0, 1200, 0))
garageInstances:SetAttribute("InteriorSlotSpacing", 260)

local exitSpawn = findPath(world, { "Dealership", "Spawn", "VehicleExitSpawnPoint" })
local fallbackSpawn = findPath(world, { "SpawnPoints", "VehicleSpawnPoint" })
local referencePart = (exitSpawn and exitSpawn:IsA("BasePart") and exitSpawn) or (fallbackSpawn and fallbackSpawn:IsA("BasePart") and fallbackSpawn) or nil
local elevator = ensureChild(interactives, "Part", "GarageInteriorElevatorMVP")
elevator.Anchored = true
elevator.CanCollide = true
elevator.Size = Vector3.new(5, 0.35, 5)
elevator.Material = Enum.Material.Neon
elevator.Color = Color3.fromRGB(195, 75, 180)
if referencePart then
	elevator.CFrame = referencePart.CFrame * CFrame.new(8, 0.2, -8)
else
	elevator.CFrame = CFrame.new(0, 6, 0)
end
elevator:SetAttribute("PersistencePhase21PrivateGarageInteriorMVP", true)
elevator:SetAttribute("Purpose", "Temporary private garage entry prompt for Phase 21 MVP.")

local prompt = ensureChild(elevator, "ProximityPrompt", "EnterPrivateGaragePrompt")
prompt.ActionText = "Enter Garage"
prompt.ObjectText = "Private Garage"
prompt.HoldDuration = 0.25
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt:SetAttribute("PersistencePhase21PrivateGarageInteriorMVP", true)

local services = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services")
local garageServices = services:WaitForChild("Garage")
local phase20Module = garageServices:FindFirstChild("GarageProfileRuntime")
assert(phase20Module and phase20Module:IsA("ModuleScript"), "Expected Phase 20 GarageProfileRuntime before Phase 21.")

local serverScript = ensureChild(garageServices, "Script", "GarageInteriorService_Active")
serverScript.Disabled = false
serverScript:SetAttribute("PersistencePhase21PrivateGarageInteriorMVP", true)
serverScript.Source = [=[-- NTR Persistence Phase 21 Private Garage Interior MVP

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TAG = "[NTR Persistence Phase 21 GarageInteriorService]"

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local garageRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage")
local invoke = garageRemotes:WaitForChild("GarageInteriorInvoke")
local transition = garageRemotes:WaitForChild("GarageInteriorTransition")

local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
local interiors = world:WaitForChild("Interiors")
local garageRoot = interiors:WaitForChild("GarageInstances")
local interactives = world:WaitForChild("Interactives")

local activeSlotsByUserId = {}
local returnCFramesByUserId = {}
local promptConnections = {}

local function findPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function ensureChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function setPartDefaults(part)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function makePart(parent, name, size, cframe, color, material)
	local part = ensureChild(parent, "Part", name)
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	setPartDefaults(part)
	return part
end

local function slotIndexFor(player)
	local userId = player.UserId
	if activeSlotsByUserId[userId] then
		return activeSlotsByUserId[userId]
	end
	local used = {}
	for _, index in pairs(activeSlotsByUserId) do
		used[index] = true
	end
	local index = 1
	while used[index] do
		index += 1
	end
	activeSlotsByUserId[userId] = index
	return index
end

local function interiorBaseCFrame(player)
	local basePosition = garageRoot:GetAttribute("InteriorBasePosition")
	if typeof(basePosition) ~= "Vector3" then
		basePosition = Vector3.new(0, 1200, 0)
	end
	local spacing = tonumber(garageRoot:GetAttribute("InteriorSlotSpacing")) or 260
	return CFrame.new(basePosition + Vector3.new((slotIndexFor(player) - 1) * spacing, 0, 0))
end

local function getCharacterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function fallbackCityCFrame(player)
	local dealershipExit = findPath(world, { "Dealership", "Spawn", "VehicleExitSpawnPoint" })
	if dealershipExit and dealershipExit:IsA("BasePart") then
		return dealershipExit.CFrame * CFrame.new(0, 4, -6), "DealershipExit"
	end
	local vehicleSpawn = findPath(world, { "SpawnPoints", "VehicleSpawnPoint" })
	if vehicleSpawn and vehicleSpawn:IsA("BasePart") then
		return vehicleSpawn.CFrame * CFrame.new(0, 4, -8), "VehicleSpawnPoint"
	end
	local root = getCharacterRoot(player)
	if root then
		return root.CFrame, "CurrentCharacter"
	end
	return CFrame.new(0, 12, 0), "WorldOrigin"
end

local function connectReturnPrompt(player, model)
	local prompt = model:FindFirstChild("ReturnToCityPrompt", true)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	if promptConnections[prompt] then
		return
	end
	promptConnections[prompt] = prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer == player then
			local ok, err = pcall(function()
				invoke.OnServerInvoke(triggeringPlayer, "ReturnToCity", { Source = "Prompt" })
			end)
			if not ok then
				warn(TAG .. " Return prompt failed: " .. tostring(err))
			end
		end
	end)
end

local function ensureInterior(player)
	local name = "GarageInterior_" .. tostring(player.UserId)
	local model = garageRoot:FindFirstChild(name)
	if model and model:IsA("Model") then
		connectReturnPrompt(player, model)
		return model
	end

	model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("AccessMode", "Private")
	model:SetAttribute("PersistencePhase21PrivateGarageInteriorMVP", true)
	model.Parent = garageRoot

	local base = interiorBaseCFrame(player)
	local floor = makePart(model, "Floor", Vector3.new(80, 1, 54), base * CFrame.new(0, 0, 0), Color3.fromRGB(18, 24, 30), Enum.Material.Metal)
	model.PrimaryPart = floor
	makePart(model, "BackWall", Vector3.new(80, 18, 1), base * CFrame.new(0, 9, 27), Color3.fromRGB(29, 36, 46), Enum.Material.Metal)
	makePart(model, "LeftWall", Vector3.new(1, 18, 54), base * CFrame.new(-40, 9, 0), Color3.fromRGB(25, 31, 40), Enum.Material.Metal)
	makePart(model, "RightWall", Vector3.new(1, 18, 54), base * CFrame.new(40, 9, 0), Color3.fromRGB(25, 31, 40), Enum.Material.Metal)
	makePart(model, "CeilingLight", Vector3.new(42, 0.4, 3), base * CFrame.new(0, 15, 0), Color3.fromRGB(210, 80, 190), Enum.Material.Neon)
	makePart(model, "VehicleDisplayPad", Vector3.new(24, 0.35, 16), base * CFrame.new(0, 0.8, 2), Color3.fromRGB(45, 75, 88), Enum.Material.Neon)

	local spawn = makePart(model, "GarageSpawnPoint", Vector3.new(4, 0.4, 4), base * CFrame.new(-28, 1.05, -18), Color3.fromRGB(100, 255, 170), Enum.Material.Neon)
	spawn.Transparency = 0.25
	spawn:SetAttribute("Purpose", "Character spawn inside private garage.")

	local returnPad = makePart(model, "ReturnToCityPad", Vector3.new(7, 0.4, 7), base * CFrame.new(28, 1.05, -18), Color3.fromRGB(255, 110, 210), Enum.Material.Neon)
	local prompt = ensureChild(returnPad, "ProximityPrompt", "ReturnToCityPrompt")
	prompt.ActionText = "Return"
	prompt.ObjectText = "City Elevator"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false

	connectReturnPrompt(player, model)
	return model
end

local function teleportCharacter(player, cframe)
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return false, "MissingHumanoidRootPart"
	end
	character:PivotTo(cframe)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function enterOwnGarage(player)
	local root = getCharacterRoot(player)
	if root then
		returnCFramesByUserId[player.UserId] = root.CFrame
	else
		returnCFramesByUserId[player.UserId] = fallbackCityCFrame(player)
	end

	local model = ensureInterior(player)
	local spawn = model:FindFirstChild("GarageSpawnPoint", true)
	if not spawn or not spawn:IsA("BasePart") then
		return { Ok = false, Error = "MissingGarageSpawnPoint" }
	end

	transition:FireClient(player, { Step = "FadeOut", Label = "Entering garage" })
	task.wait(0.15)
	local targetCFrame = spawn.CFrame * CFrame.new(0, 4, 0)
	local ok, err = teleportCharacter(player, targetCFrame)
	if not ok then
		return { Ok = false, Error = err }
	end

	player:SetAttribute("NTR_Phase21InPrivateGarage", true)
	player:SetAttribute("NTR_Phase21GarageInteriorId", model.Name)
	player:SetAttribute("NTR_Phase21GarageAccessMode", "Private")
	player:SetAttribute("NTR_Phase21GarageInteriorMVP", true)
	transition:FireClient(player, { Step = "Stream", Label = "Loading garage", Position = spawn.Position })

	return {
		Ok = true,
		InteriorId = model.Name,
		OwnerUserId = player.UserId,
		SpawnPosition = spawn.Position,
		AccessMode = "Private",
	}
end

local function returnToCity(player)
	local cframe = returnCFramesByUserId[player.UserId]
	local source = "SavedReturnCFrame"
	if typeof(cframe) ~= "CFrame" then
		cframe, source = fallbackCityCFrame(player)
	end

	transition:FireClient(player, { Step = "FadeOut", Label = "Returning to city" })
	task.wait(0.15)
	local ok, err = teleportCharacter(player, cframe)
	if not ok then
		return { Ok = false, Error = err }
	end

	player:SetAttribute("NTR_Phase21InPrivateGarage", false)
	transition:FireClient(player, { Step = "Stream", Label = "Loading city", Position = cframe.Position })

	return {
		Ok = true,
		ReturnSource = source,
	}
end

local function getState(player)
	local interiorId = player:GetAttribute("NTR_Phase21GarageInteriorId")
	local model = interiorId and garageRoot:FindFirstChild(tostring(interiorId)) or nil
	return {
		Ok = true,
		InGarage = player:GetAttribute("NTR_Phase21InPrivateGarage") == true,
		InteriorId = interiorId,
		InteriorExists = model ~= nil,
		AccessMode = player:GetAttribute("NTR_Phase21GarageAccessMode"),
	}
end

local function connectEntryPrompt()
	local elevator = interactives:FindFirstChild("GarageInteriorElevatorMVP")
	local prompt = elevator and elevator:FindFirstChild("EnterPrivateGaragePrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	if promptConnections[prompt] then
		return
	end
	promptConnections[prompt] = prompt.Triggered:Connect(function(player)
		enterOwnGarage(player)
	end)
end

invoke.OnServerInvoke = function(player, action, payload)
	if action == "EnterOwnGarage" then
		return enterOwnGarage(player)
	elseif action == "ReturnToCity" then
		return returnToCity(player)
	elseif action == "GetState" then
		return getState(player)
	end
	return { Ok = false, Error = "UnknownAction" }
end

Players.PlayerRemoving:Connect(function(player)
	returnCFramesByUserId[player.UserId] = nil
	activeSlotsByUserId[player.UserId] = nil
	local model = garageRoot:FindFirstChild("GarageInterior_" .. tostring(player.UserId))
	if model then
		model:Destroy()
	end
end)

connectEntryPrompt()
print(TAG .. " ready.")
]=]

local starterScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientRoot = starterScripts:WaitForChild("NeoTokyoRacersClient")
local controllers = ensureChild(clientRoot, "Folder", "Controllers")
local worldControllers = ensureChild(controllers, "Folder", "World")
local clientScript = ensureChild(worldControllers, "LocalScript", "GarageInteriorClient_Active")
clientScript.Disabled = false
clientScript:SetAttribute("PersistencePhase21PrivateGarageInteriorMVP", true)
clientScript.Source = [=[-- NTR Persistence Phase 21 Private Garage Interior MVP client helper

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local garageRemotes = ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage")
local transition = garageRemotes:WaitForChild("GarageInteriorTransition")

local gui
local shade
local label

local function ensureGui()
	if gui and gui.Parent then
		return
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "NTR_GarageInteriorTransition"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 1
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = gui

	label = Instance.new("TextLabel")
	label.Name = "LoadingLabel"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromOffset(420, 44)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 190, 240)
	label.TextScaled = true
	label.Text = "Loading"
	label.Parent = shade
end

local function fadeTo(transparency, duration)
	ensureGui()
	gui.Enabled = true
	local tween = TweenService:Create(shade, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = transparency,
	})
	tween:Play()
	tween.Completed:Wait()
	if transparency >= 1 then
		gui.Enabled = false
	end
end

transition.OnClientEvent:Connect(function(payload)
	payload = typeof(payload) == "table" and payload or {}
	local step = tostring(payload.Step or "")
	label = label or nil
	ensureGui()
	label.Text = tostring(payload.Label or "Loading")

	if step == "FadeOut" then
		fadeTo(0, 0.16)
	elseif step == "Stream" then
		local ok = true
		if typeof(payload.Position) == "Vector3" then
			ok = pcall(function()
				Workspace:RequestStreamAroundAsync(payload.Position)
			end)
		end
		player:SetAttribute("NTR_Phase21LastStreamOk", ok == true)
		task.wait(0.15)
		fadeTo(1, 0.22)
	else
		fadeTo(1, 0.16)
	end
end)

player:SetAttribute("NTR_Phase21GarageInteriorClientReady", true)
]=]

serverScript:SetAttribute("PersistencePhase21PrivateGarageInteriorMVP", true)
clientScript:SetAttribute("PersistencePhase21PrivateGarageInteriorMVP", true)
kit:SetAttribute("PersistencePhase21PrivateGarageInteriorMVP", true)

assert(garageInstances:FindFirstChild("GarageInterior_" .. tostring(0)) == nil, "Unexpected design-time owner interior found.")
assert(interiorInvoke:IsA("RemoteFunction"), "GarageInteriorInvoke was not installed.")
assert(transitionEvent:IsA("RemoteEvent"), "GarageInteriorTransition was not installed.")
assert(serverScript.Source:find("NTR Persistence Phase 21", 1, true), "Server source marker missing.")
assert(clientScript.Source:find("RequestStreamAroundAsync", 1, true), "Client streaming helper missing.")

info("PASS: installed private garage interior MVP runtime, remotes, client streaming helper, and elevator prompt.")
info("Next: restart Play and run this same script from the CLIENT Command Bar. Expected EnterOwnGarage OK, InGarage=true, streamOk=true, ReturnToCity OK.")
