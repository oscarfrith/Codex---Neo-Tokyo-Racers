-- Neo Tokyo Racers - Drive-In Customisation Phase 2
-- Repairs drive-in entry so it fully behaves like garage customisation:
-- live vehicle despawns, preview camera/vehicle are restored, player is hidden
-- and frozen, countdown is shown as a world-space prompt, and trigger VFX are
-- toggled instead of changing the trigger part transparency.
--
-- Run in Roblox Studio Command Bar while the place is open.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local CLIENT_NAME = "DriveInCustomisationZoneClient_Active"
local LOCK_SERVER_NAME = "DriveInCustomisationSessionService_Active"
local BOOTSTRAP_START = "-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP"
local BOOTSTRAP_END = "-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP_END"
local PHASE2_MARKER = "NTR_DRIVE_IN_CUSTOMISATION_PHASE2_ENTRY_HANDOFF"

local function info(message)
	print("[NTR Drive-In Customisation Phase 2] " .. tostring(message))
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function replaceRange(source, startText, endText, newText, label)
	local startIndex = string.find(source, startText, 1, true)
	assert(startIndex, "Could not find source start anchor for " .. label .. ". Refresh the Studio mirror before creating another patch.")
	local endIndex = string.find(source, endText, startIndex, true)
	assert(endIndex, "Could not find source end anchor for " .. label .. ". Run the register-limit repair first, then retry.")
	endIndex += #endText - 1
	return string.sub(source, 1, startIndex - 1) .. newText .. string.sub(source, endIndex + 1)
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

local function ensureValue(parent, className, name, value)
	local item = parent:FindFirstChild(name)
	if not item then
		item = Instance.new(className)
		item.Name = name
		item.Parent = parent
	end
	if item:IsA("ValueBase") then
		item.Value = value
	end
	return item
end

local function ensureConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = ensureFolder(kit, "Config")
	local runtime = ensureFolder(config, "Runtime")
	local ui = ensureFolder(config, "UI")
	local runtimeConfig = ensureFolder(runtime, "DriveInCustomisation")
	local uiConfig = ensureFolder(ui, "DriveInCustomisation")

	ensureValue(runtimeConfig, "BoolValue", "UseWorldPrompt", true)
	ensureValue(runtimeConfig, "BoolValue", "TriggerVfxOnlyWhileDriving", true)
	ensureValue(runtimeConfig, "NumberValue", "PromptMaxDistance", 90)
	ensureValue(runtimeConfig, "NumberValue", "PromptHeightOffset", 6)
	ensureValue(uiConfig, "StringValue", "IdleTitle", "Customisation")
	ensureValue(uiConfig, "StringValue", "IdleAction", "Drive In")
	ensureValue(uiConfig, "StringValue", "CountdownTitle", "Customisation")
	info("Ensured Phase 2 world prompt config.")
end

local function ensureHoldPoint()
	local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
	local dealership = world:FindFirstChild("Dealership") or ensureFolder(world, "Dealership")
	local customisation = dealership:FindFirstChild("Customisation") or ensureFolder(dealership, "Customisation")
	local hold = customisation:FindFirstChild("DriveInCustomisationPlayerHoldPoint")
	if not hold then
		hold = Instance.new("Part")
		hold.Name = "DriveInCustomisationPlayerHoldPoint"
		hold.Anchored = true
		hold.CanCollide = false
		hold.CanTouch = false
		hold.CanQuery = false
		hold.Transparency = 1
		hold.Size = Vector3.new(4, 1, 4)
		local trigger = customisation:FindFirstChild("DriveInCustomisationTrigger")
		local preview = customisation:FindFirstChild("Preview")
		local previewPoint = preview and preview:FindFirstChild("VehiclePreviewPoint")
		if previewPoint and previewPoint:IsA("BasePart") then
			hold.CFrame = previewPoint.CFrame * CFrame.new(0, -36, 0)
		elseif trigger and trigger:IsA("BasePart") then
			hold.CFrame = trigger.CFrame * CFrame.new(0, -36, 0)
		else
			hold.CFrame = CFrame.new(860, 70, -1713)
		end
		hold.Parent = customisation
	end
	hold.Anchored = true
	hold.CanCollide = false
	hold.CanTouch = false
	hold.CanQuery = false
	hold.Transparency = 1
	info("Ensured player hold point for drive-in customisation.")
end

local SERVER_SOURCE = [=[
-- Neo Tokyo Racers - Drive-In Customisation Session Service
-- NTR_DRIVE_IN_CUSTOMISATION_PHASE2_SESSION_SERVICE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:FindFirstChild("Shared") or Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = kit
local remotes = shared:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = shared
local uiRemotes = remotes:FindFirstChild("UI") or Instance.new("Folder")
uiRemotes.Name = "UI"
uiRemotes.Parent = remotes

local remote = uiRemotes:FindFirstChild("DriveInCustomisationSession")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DriveInCustomisationSession"
	remote.Parent = uiRemotes
end

local saved = {}

local function holdPoint()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local dealership = world and world:FindFirstChild("Dealership")
	local customisation = dealership and dealership:FindFirstChild("Customisation")
	local point = customisation and customisation:FindFirstChild("DriveInCustomisationPlayerHoldPoint")
	return point and point:IsA("BasePart") and point or nil
end

local function characterParts(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function lockPlayer(player)
	local _, humanoid, root = characterParts(player)
	if not humanoid or not root then return end
	if not saved[player] then
		saved[player] = {
			WalkSpeed = humanoid.WalkSpeed,
			JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight,
			AutoRotate = humanoid.AutoRotate,
			RootAnchored = root.Anchored,
		}
	end
	humanoid.Sit = false
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	local point = holdPoint()
	if point then
		root.CFrame = point.CFrame + Vector3.new(0, 3, 0)
	end
	root.Anchored = true
	player:SetAttribute("NTR_DriveInServerLocked", true)
end

local function unlockPlayer(player)
	local _, humanoid, root = characterParts(player)
	local state = saved[player]
	if humanoid and state then
		humanoid.WalkSpeed = state.WalkSpeed or 16
		humanoid.JumpPower = state.JumpPower or humanoid.JumpPower
		humanoid.JumpHeight = state.JumpHeight or humanoid.JumpHeight
		humanoid.AutoRotate = state.AutoRotate ~= false
	end
	if root then
		root.Anchored = state and state.RootAnchored == true or false
	end
	saved[player] = nil
	player:SetAttribute("NTR_DriveInServerLocked", false)
end

remote.OnServerEvent:Connect(function(player, locked)
	if locked == true then
		lockPlayer(player)
	else
		unlockPlayer(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saved[player] = nil
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if player:GetAttribute("NTR_DriveInServerLocked") == true then
			lockPlayer(player)
		end
	end)
end)
]=]

local CLIENT_SOURCE = [=[
-- Neo Tokyo Racers - Drive-In Customisation Zone Client
-- NTR_DRIVE_IN_CUSTOMISATION_PHASE2_WORLD_PROMPT

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TAG = "NTR_DriveCustomisationZone"
local OPEN_EVENT_NAME = "OpenDrivingVehicleCustomisation"
local LOCK_ATTR = "NTR_DriveInCustomisationActive"

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local runtimeConfig = kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("DriveInCustomisation")
local uiConfig = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("DriveInCustomisation")
local lockRemote = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI"):WaitForChild("DriveInCustomisationSession")

local billboard = Instance.new("BillboardGui")
billboard.Name = "NTR_DriveInCustomisationWorldPrompt"
billboard.AlwaysOnTop = true
billboard.LightInfluence = 0
billboard.ResetOnSpawn = false
billboard.Size = UDim2.fromOffset(250, 92)
billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
billboard.MaxDistance = 90
billboard.Enabled = false
billboard.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "PromptRoot"
root.BackgroundColor3 = Color3.fromRGB(6, 10, 13)
root.BackgroundTransparency = 0.18
root.BorderSizePixel = 0
root.Size = UDim2.fromScale(1, 1)
root.Parent = billboard

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = root

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Transparency = 0.22
stroke.Color = Color3.fromRGB(230, 88, 205)
stroke.Parent = root

local key = Instance.new("Frame")
key.Name = "KeyCircle"
key.AnchorPoint = Vector2.new(0, 0.5)
key.Position = UDim2.new(0, 18, 0.5, 0)
key.Size = UDim2.fromOffset(54, 54)
key.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
key.BackgroundTransparency = 0.78
key.BorderSizePixel = 0
key.Parent = root

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(1, 0)
keyCorner.Parent = key

local keyStroke = Instance.new("UIStroke")
keyStroke.Thickness = 2
keyStroke.Transparency = 0.16
keyStroke.Color = Color3.fromRGB(255, 255, 255)
keyStroke.Parent = key

local keyText = Instance.new("TextLabel")
keyText.BackgroundTransparency = 1
keyText.Size = UDim2.fromScale(1, 1)
keyText.Text = "AUTO"
keyText.TextColor3 = Color3.fromRGB(255, 255, 255)
keyText.TextSize = 12
keyText.TextStrokeTransparency = 0.55
keyText.Font = Enum.Font.GothamBold
pcall(function()
	keyText.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
end)
keyText.Parent = key

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(88, 12)
title.Size = UDim2.new(1, -104, 0, 24)
title.Text = "Customisation"
title.TextColor3 = Color3.fromRGB(255, 226, 249)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextStrokeTransparency = 0.38
title.Font = Enum.Font.GothamBold
pcall(function()
	title.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
end)
title.Parent = root

local action = Instance.new("TextLabel")
action.Name = "Action"
action.BackgroundTransparency = 1
action.Position = UDim2.fromOffset(88, 38)
action.Size = UDim2.new(1, -104, 0, 32)
action.Text = "Drive In"
action.TextColor3 = Color3.fromRGB(255, 255, 255)
action.TextSize = 19
action.TextXAlignment = Enum.TextXAlignment.Left
action.TextStrokeTransparency = 0.28
action.Font = Enum.Font.GothamBold
pcall(function()
	action.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
end)
action.Parent = root

local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
divider.BackgroundTransparency = 0.58
divider.BorderSizePixel = 0
divider.Position = UDim2.fromOffset(86, 39)
divider.Size = UDim2.new(1, -104, 0, 1)
divider.Parent = root

local function readBool(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("BoolValue") and item.Value or fallback
end

local function readNumber(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function readString(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("StringValue") and item.Value or fallback
end

local function readColor(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("Color3Value") and item.Value or fallback
end

local function applyUiConfig()
	root.BackgroundColor3 = readColor(uiConfig, "PanelColor", Color3.fromRGB(6, 10, 13))
	root.BackgroundTransparency = readNumber(uiConfig, "PanelTransparency", 0.18)
	title.TextColor3 = readColor(uiConfig, "TextColor", Color3.fromRGB(255, 226, 249))
	stroke.Color = readColor(uiConfig, "AccentColor", Color3.fromRGB(230, 88, 205))
	billboard.MaxDistance = readNumber(runtimeConfig, "PromptMaxDistance", 90)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, readNumber(runtimeConfig, "PromptHeightOffset", 6), 0)
end

local function taggedZone()
	for _, object in ipairs(CollectionService:GetTagged(TAG)) do
		if object:IsA("BasePart") and object:IsDescendantOf(Workspace) then
			return object
		end
	end
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local dealership = world and world:FindFirstChild("Dealership")
	local customisation = dealership and dealership:FindFirstChild("Customisation")
	local trigger = customisation and customisation:FindFirstChild("DriveInCustomisationTrigger")
	return trigger and trigger:IsA("BasePart") and trigger or nil
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

local function drivingVehicle()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then
		return nil
	end
	local vehicle = ownerVehicleFromInstance(seat)
	if vehicle and tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId and tonumber(vehicle:GetAttribute("DriverUserId")) == player.UserId then
		return vehicle, seat
	end
	return nil
end

local function vehiclePosition(vehicle, seat)
	local rootPart = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.Position
	end
	if seat then
		return seat.Position
	end
	return nil
end

local function pointInsideZone(zone, point)
	if not zone or not point then return false end
	local localPoint = zone.CFrame:PointToObjectSpace(point)
	local half = zone.Size * 0.5
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

local function garageUiVisible()
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child.Enabled then
			local garageRoot = child:FindFirstChild("GarageRoot", true)
				or child:FindFirstChild("CockpitShop", true)
				or child:FindFirstChild("ModuleShop", true)
				or child:FindFirstChild("Customise", true)
			if garageRoot and garageRoot:IsA("GuiObject") and garageRoot.Visible then
				return true
			end
		end
	end
	return false
end

local function garageGuiEnabled()
	local gui = playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	return gui and gui:IsA("ScreenGui") and gui.Enabled == true
end

local function openEvent()
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local intro = controllers and controllers:FindFirstChild("Intro")
	local event = intro and intro:FindFirstChild(OPEN_EVENT_NAME)
	return event and event:IsA("BindableEvent") and event or nil
end

local function setTriggerVfx(zone, enabled)
	if not zone or readBool(runtimeConfig, "TriggerVfxOnlyWhileDriving", true) == false then return end
	for _, object in ipairs(zone:GetDescendants()) do
		if object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") or object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
			object.Enabled = enabled
		end
	end
end

local locked = false
local hiddenParts = {}
local original = nil
local lockGraceUntil = 0
local countdownActive = false
local cooldownUntil = 0
local lastPulse = 0

local function hideCharacter(hidden)
	local character = player.Character
	if not character then return end
	if hidden then
		for _, object in ipairs(character:GetDescendants()) do
			if object:IsA("BasePart") then
				if hiddenParts[object] == nil then
					hiddenParts[object] = object.LocalTransparencyModifier
				end
				object.LocalTransparencyModifier = 1
			end
		end
	else
		for part, value in pairs(hiddenParts) do
			if part and part.Parent then
				part.LocalTransparencyModifier = value or 0
			end
		end
		table.clear(hiddenParts)
	end
end

local function setLocalLocked(enabled)
	if locked == enabled then return end
	locked = enabled
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if enabled then
		if humanoid and not original then
			original = {
				WalkSpeed = humanoid.WalkSpeed,
				JumpPower = humanoid.JumpPower,
				JumpHeight = humanoid.JumpHeight,
				AutoRotate = humanoid.AutoRotate,
			}
		end
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
			humanoid.AutoRotate = false
		end
		hideCharacter(true)
		lockRemote:FireServer(true)
	else
		if humanoid and original then
			humanoid.WalkSpeed = original.WalkSpeed or 16
			humanoid.JumpPower = original.JumpPower or humanoid.JumpPower
			humanoid.JumpHeight = original.JumpHeight or humanoid.JumpHeight
			humanoid.AutoRotate = original.AutoRotate ~= false
		end
		original = nil
		hideCharacter(false)
		lockRemote:FireServer(false)
	end
end

local function setPrompt(zone, visible, activeText)
	billboard.Adornee = zone
	billboard.Enabled = visible == true and readBool(runtimeConfig, "UseWorldPrompt", true) == true
	if not billboard.Enabled then return end
	title.Text = activeText and readString(uiConfig, "CountdownTitle", "Customisation") or readString(uiConfig, "IdleTitle", "Customisation")
	action.Text = activeText or readString(uiConfig, "IdleAction", "Drive In")
	keyText.Text = activeText and "..." or "AUTO"
end

local function beginCountdown(zone)
	if countdownActive or os.clock() < cooldownUntil then return end
	countdownActive = true
	local duration = tonumber(zone:GetAttribute("CountdownSeconds")) or readNumber(runtimeConfig, "CountdownSeconds", 3)
	duration = math.max(0.5, duration)
	local started = os.clock()
	while countdownActive do
		local vehicle, seat = drivingVehicle()
		local inside = vehicle and pointInsideZone(zone, vehiclePosition(vehicle, seat)) and not garageUiVisible()
		if not inside or zone:GetAttribute("Enabled") == false or readBool(runtimeConfig, "Enabled", true) == false then
			break
		end
		local remaining = math.max(0, duration - (os.clock() - started))
		local shown = math.max(1, math.ceil(remaining))
		local prefix = string.upper(tostring(zone:GetAttribute("PromptPrefix") or readString(uiConfig, "PromptPrefix", "ENTERING CUSTOMISATION IN")))
		setPrompt(zone, true, prefix .. " " .. tostring(shown))
		if remaining <= 0 then
			local event = openEvent()
			if event then
				event:Fire()
				cooldownUntil = os.clock() + readNumber(runtimeConfig, "CooldownSeconds", 2)
			else
				warn("[NTR Drive-In Customisation] OpenDrivingVehicleCustomisation event was not available.")
			end
			break
		end
		task.wait(0.05)
	end
	countdownActive = false
end

player:GetAttributeChangedSignal(LOCK_ATTR):Connect(function()
	if player:GetAttribute(LOCK_ATTR) == true then
		lockGraceUntil = os.clock() + 3
	end
	setLocalLocked(player:GetAttribute(LOCK_ATTR) == true)
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if player:GetAttribute(LOCK_ATTR) == true and now > lockGraceUntil and not garageGuiEnabled() then
		player:SetAttribute(LOCK_ATTR, false)
		setLocalLocked(false)
	end
	if now - lastPulse < readNumber(runtimeConfig, "PollSeconds", 0.1) then return end
	lastPulse = now
	applyUiConfig()
	local zone = taggedZone()
	local vehicle, seat = drivingVehicle()
	local canShow = zone ~= nil and vehicle ~= nil and not garageUiVisible() and readBool(runtimeConfig, "Enabled", true) == true and zone:GetAttribute("Enabled") ~= false
	setTriggerVfx(zone, canShow)
	if not canShow or os.clock() < cooldownUntil then
		if not countdownActive then
			setPrompt(zone, false)
		end
		return
	end
	setPrompt(zone, true)
	if pointInsideZone(zone, vehiclePosition(vehicle, seat)) then
		task.spawn(beginCountdown, zone)
	end
end)
]=]

local function installServer()
	local services = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services")
	local garage = services:FindFirstChild("Garage") or ensureFolder(services, "Garage")
	local scriptObject = garage:FindFirstChild(LOCK_SERVER_NAME)
	if not scriptObject then
		scriptObject = Instance.new("Script")
		scriptObject.Name = LOCK_SERVER_NAME
		scriptObject.Parent = garage
	end
	scriptObject.Disabled = false
	scriptObject.Source = SERVER_SOURCE
	info("Installed drive-in session lock service.")
end

local function installClient()
	local clientRoot = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient")
	local controllers = clientRoot:WaitForChild("Controllers")
	local intro = controllers:FindFirstChild("Intro") or ensureFolder(controllers, "Intro")
	local scriptObject = intro:FindFirstChild(CLIENT_NAME)
	if not scriptObject then
		scriptObject = Instance.new("LocalScript")
		scriptObject.Name = CLIENT_NAME
		scriptObject.Parent = intro
	end
	scriptObject.Disabled = false
	scriptObject.Source = CLIENT_SOURCE
	info("Replaced drive-in client with world prompt and VFX toggler.")
end

local function patchBootstrap()
	local clientRoot = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient")
	local scriptObject = clientRoot:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
	local source = scriptObject.Source
	if findPlain(source, PHASE2_MARKER) then
		info("Bootstrap Phase 2 drive-in entry handoff already present.")
		return
	end
	assert(findPlain(source, BOOTSTRAP_START), "Drive-in bootstrap marker missing. Run Phase 1 and the register-limit repair first.")
	assert(findPlain(source, BOOTSTRAP_END), "Drive-in bootstrap end marker missing. Run the register-limit repair before Phase 2.")

	local newBlock = [=[
-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP
-- NTR_DRIVE_IN_CUSTOMISATION_PHASE2_ENTRY_HANDOFF
_G.NTRDriveInCustomisationPhase1 = _G.NTRDriveInCustomisationPhase1 or {}
_G.NTRDriveInCustomisationPhase1.OpenEventName = "OpenDrivingVehicleCustomisation"

function _G.NTRDriveInCustomisationPhase1.RefreshProfile()
	local result = callServer("GetInitial", {})
	if result.Success ~= false then
		if result.Catalog then State.Catalog = result.Catalog end
		if result.Profile then State.Profile = result.Profile end
	end
	return result
end

function _G.NTRDriveInCustomisationPhase1.OpenDrivenVehicleModuleShop()
	local selectedVehicleId = State.Profile and State.Profile.CurrentVehicleId
	local refresh = _G.NTRDriveInCustomisationPhase1.RefreshProfile()
	if refresh.Profile and refresh.Profile.CurrentVehicleId then
		selectedVehicleId = refresh.Profile.CurrentVehicleId
	end
	if not selectedVehicleId or selectedVehicleId == "" then
		warn("[NTR Drive-In Customisation] No current vehicle id available; opening owned customisation picker instead.")
		NTR_openOwnedCockpitCustomisation()
		return
	end

	callServer("DespawnVehicle", {})
	stopDriving()
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.Sit = false
	end
	player:SetAttribute("NTR_DriveInCustomisationActive", true)

	NTR_openGarageWithMode("Customisation")
	task.spawn(function()
		for _ = 1, 100 do
			if UI and UI.Gui and typeof(showStage) == "function" and typeof(renderModuleShop) == "function" and typeof(sortedSlots) == "function" and typeof(buildPreview) == "function" then
				break
			end
			task.wait(0.05)
		end

		local getResult = _G.NTRDriveInCustomisationPhase1.RefreshProfile()
		if getResult.Profile and getResult.Profile.CurrentVehicleId then
			selectedVehicleId = getResult.Profile.CurrentVehicleId
		end
		local selectResult = callServer("SelectVehicleInstance", { VehicleId = selectedVehicleId })
		if selectResult.Success == false then
			player:SetAttribute("NTR_DriveInCustomisationActive", false)
			if UI and UI.Subtitle then
				UI.Subtitle.Text = selectResult.Message or "Could not open build modules."
			end
			NTR_openOwnedCockpitCustomisation()
			return
		end

		State.ShopMode = "Customisation"
		State.ModuleMode = "Slots"
		State.SelectedModuleId = nil
		State.SelectedModuleInstanceId = nil
		State.CustomizeTarget = "ALL"
		State.CustomizeMode = "Colour"
		State.NoPreviewYet = false
		State.GarageCameraActive = true
		State.Phase5PreviewOrbitInitialized = false
		State.PreviewModules = {}
		local firstSlot = sortedSlots()[1]
		State.SelectedSlot = firstSlot and firstSlot.SlotId or State.SelectedSlot or "Engine1"
		if UI and UI.Gui then
			UI.Gui.Enabled = true
		end
		buildPreview()
		NTR_phase4ApplyGaragePreviewCamera()
		setCameraSection(State.SelectedSlot or "Engine1")
		showStage("ModuleShop")
		renderModuleShop()
	end)
end
-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP_END
]=]

	source = replaceRange(source, BOOTSTRAP_START, BOOTSTRAP_END, newBlock, "drive-in customisation Phase 2 bootstrap block")
	scriptObject.Source = source
	info("Patched bootstrap drive-in handoff to enter real garage preview mode.")
end

ensureConfig()
ensureHoldPoint()
installServer()
installClient()
patchBootstrap()

info("Phase 2 install complete. Restart Play and test the drive-in customisation bay.")
