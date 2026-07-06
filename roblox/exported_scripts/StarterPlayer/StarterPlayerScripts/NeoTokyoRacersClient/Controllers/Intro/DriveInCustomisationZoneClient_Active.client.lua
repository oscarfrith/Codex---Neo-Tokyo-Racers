-- Neo Tokyo Racers - Drive-In Customisation Zone Client
-- NTR_DRIVE_IN_CUSTOMISATION_PHASE3_COUNTDOWN_ONLY_PROMPT

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TAG = "NTR_DriveCustomisationZone"
local OPEN_EVENT_NAME = "OpenDrivingVehicleCustomisation"
local LOCK_ATTR = "NTR_DriveInCustomisationActive"

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local runtimeConfig = kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("DriveInCustomisation")
local uiConfig = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("DriveInCustomisation")
local uiRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI")
local lockRemote = uiRemotes:WaitForChild("DriveInCustomisationSession", 5)
if not lockRemote then
	warn("[NTR Drive-In Customisation] DriveInCustomisationSession remote missing; player hold lock will be local-only.")
end

local billboard = Instance.new("BillboardGui")
billboard.Name = "NTR_DriveInCustomisationWorldPrompt"
billboard.AlwaysOnTop = true
billboard.LightInfluence = 0
billboard.ResetOnSpawn = false
billboard.Size = UDim2.fromOffset(300, 58)
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

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "Countdown"
countdownLabel.BackgroundTransparency = 1
countdownLabel.Position = UDim2.fromOffset(12, 6)
countdownLabel.Size = UDim2.new(1, -24, 1, -12)
countdownLabel.Text = ""
countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
countdownLabel.TextScaled = true
countdownLabel.TextWrapped = true
countdownLabel.TextXAlignment = Enum.TextXAlignment.Center
countdownLabel.TextYAlignment = Enum.TextYAlignment.Center
countdownLabel.TextStrokeTransparency = 0.36
countdownLabel.Font = Enum.Font.GothamBold
pcall(function()
	countdownLabel.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
end)
countdownLabel.Parent = root

local sizeConstraint = Instance.new("UITextSizeConstraint")
sizeConstraint.MinTextSize = 9
sizeConstraint.MaxTextSize = 18
sizeConstraint.Parent = countdownLabel

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
	stroke.Color = readColor(uiConfig, "AccentColor", Color3.fromRGB(230, 88, 205))
	countdownLabel.TextColor3 = readColor(uiConfig, "TextColor", Color3.fromRGB(255, 255, 255))
	sizeConstraint.MaxTextSize = readNumber(uiConfig, "CountdownTextMaxSize", 18)
	sizeConstraint.MinTextSize = readNumber(uiConfig, "CountdownTextMinSize", 9)
	billboard.Size = UDim2.fromOffset(readNumber(uiConfig, "CountdownPromptWidth", 300), readNumber(uiConfig, "CountdownPromptHeight", 58))
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
	return seat and seat.Position or nil
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
		if lockRemote then lockRemote:FireServer(true) end
	else
		if humanoid and original then
			humanoid.WalkSpeed = original.WalkSpeed or 16
			humanoid.JumpPower = original.JumpPower or humanoid.JumpPower
			humanoid.JumpHeight = original.JumpHeight or humanoid.JumpHeight
			humanoid.AutoRotate = original.AutoRotate ~= false
		end
		original = nil
		hideCharacter(false)
		if lockRemote then lockRemote:FireServer(false) end
	end
end

local function setPrompt(zone, visible, text)
	billboard.Adornee = zone
	billboard.Enabled = visible == true and text ~= nil and readBool(runtimeConfig, "UseWorldPrompt", true) == true
	if billboard.Enabled then
		countdownLabel.Text = tostring(text)
	end
end

local function countdownText(zone, shown)
	local prefix = tostring(zone:GetAttribute("PromptPrefix") or readString(uiConfig, "PromptPrefix", "Entering customisation in"))
	return prefix .. " " .. tostring(shown)
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
		setPrompt(zone, true, countdownText(zone, shown))
		if remaining <= 0 then
			local event = openEvent()
			if event then
				setPrompt(zone, false)
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
	setPrompt(zone, false)
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
	local canUse = zone ~= nil and vehicle ~= nil and not garageUiVisible() and readBool(runtimeConfig, "Enabled", true) == true and zone:GetAttribute("Enabled") ~= false
	setTriggerVfx(zone, canUse)
	if not canUse or os.clock() < cooldownUntil then
		if not countdownActive then
			setPrompt(zone, false)
		end
		return
	end
	local inside = pointInsideZone(zone, vehiclePosition(vehicle, seat))
	if inside then
		task.spawn(beginCountdown, zone)
	elseif not countdownActive then
		setPrompt(zone, false)
	end
end)
