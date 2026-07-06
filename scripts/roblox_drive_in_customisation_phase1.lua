-- Neo Tokyo Racers - Drive-In Customisation Phase 1
-- Adds a driving-only customisation zone with a 3 second countdown, then opens
-- Build Modules for the vehicle instance currently being driven.
--
-- Run in Roblox Studio Command Bar while the place is open.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local TAG = "NTR_DriveCustomisationZone"
local CLIENT_NAME = "DriveInCustomisationZoneClient_Active"
local BOOTSTRAP_MARKER = "NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP"
local OPEN_EVENT_NAME = "OpenDrivingVehicleCustomisation"

local function info(message)
	print("[NTR Drive-In Customisation Phase 1] " .. tostring(message))
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function replaceOnce(source, oldText, newText, label)
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	assert(startIndex, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before creating another patch.")
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

local function setupConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = ensureFolder(kit, "Config")
	local runtime = ensureFolder(config, "Runtime")
	local ui = ensureFolder(config, "UI")
	local runtimeConfig = ensureFolder(runtime, "DriveInCustomisation")
	local uiConfig = ensureFolder(ui, "DriveInCustomisation")

	ensureValue(runtimeConfig, "BoolValue", "Enabled", true)
	ensureValue(runtimeConfig, "NumberValue", "CountdownSeconds", 3)
	ensureValue(runtimeConfig, "NumberValue", "PollSeconds", 0.1)
	ensureValue(runtimeConfig, "NumberValue", "CooldownSeconds", 2)
	ensureValue(runtimeConfig, "NumberValue", "ReenterBufferStuds", 4)
	ensureValue(uiConfig, "StringValue", "PromptPrefix", "ENTERING CUSTOMISATION IN")
	ensureValue(uiConfig, "Color3Value", "PanelColor", Color3.fromRGB(6, 10, 13))
	ensureValue(uiConfig, "Color3Value", "TextColor", Color3.fromRGB(255, 226, 249))
	ensureValue(uiConfig, "Color3Value", "AccentColor", Color3.fromRGB(230, 88, 205))
	ensureValue(uiConfig, "Color3Value", "ZoneColor", Color3.fromRGB(230, 88, 205))
	ensureValue(uiConfig, "NumberValue", "PanelTransparency", 0.12)
	ensureValue(uiConfig, "NumberValue", "ZoneTransparency", 0.62)
	info("Ensured DriveInCustomisation runtime/UI config.")
end

local function setupMarker()
	local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
	local dealership = world:FindFirstChild("Dealership") or ensureFolder(world, "Dealership")
	local customisation = dealership:FindFirstChild("Customisation") or ensureFolder(dealership, "Customisation")
	local trigger = customisation:FindFirstChild("DriveInCustomisationTrigger")
	if not trigger then
		trigger = Instance.new("Part")
		trigger.Name = "DriveInCustomisationTrigger"
		trigger.Anchored = true
		trigger.CanCollide = false
		trigger.CanTouch = false
		trigger.CanQuery = false
		trigger.Transparency = 1
		trigger.Size = Vector3.new(34, 12, 34)
		local desk = customisation:FindFirstChild("CustomisationDeskTrigger")
		if desk and desk:IsA("BasePart") then
			trigger.CFrame = desk.CFrame * CFrame.new(0, 0, -44)
		else
			trigger.CFrame = CFrame.new(860, 106, -1713)
		end
		trigger.Parent = customisation
	end
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CanTouch = false
	trigger.CanQuery = false
	trigger.Transparency = 1
	trigger:SetAttribute("Enabled", true)
	trigger:SetAttribute("CountdownSeconds", 3)
	trigger:SetAttribute("PromptPrefix", "ENTERING CUSTOMISATION IN")
	if not CollectionService:HasTag(trigger, TAG) then
		CollectionService:AddTag(trigger, TAG)
	end
	info("Ensured DriveInCustomisationTrigger. Move/resize it in Studio as needed.")
end

local CLIENT_SOURCE = [=[
-- Neo Tokyo Racers - Drive-In Customisation Zone Client
-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_CLIENT

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

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local runtimeConfig = kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("DriveInCustomisation")
local uiConfig = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("DriveInCustomisation")

local visualRoot = Workspace:FindFirstChild("_NTR_ClientOnly")
if not visualRoot then
	visualRoot = Instance.new("Folder")
	visualRoot.Name = "_NTR_ClientOnly"
	visualRoot.Parent = Workspace
end

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_DriveInCustomisationCountdown"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 84
gui.Enabled = true
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 86)
panel.Size = UDim2.fromOffset(430, 54)
panel.BackgroundColor3 = Color3.fromRGB(6, 10, 13)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Name = "Accent"
stroke.Thickness = 1
stroke.Transparency = 0.18
stroke.Color = Color3.fromRGB(230, 88, 205)
stroke.Parent = panel

local text = Instance.new("TextLabel")
text.Name = "Countdown"
text.BackgroundTransparency = 1
text.Size = UDim2.fromScale(1, 1)
text.Text = ""
text.TextColor3 = Color3.fromRGB(255, 226, 249)
text.TextSize = 16
text.TextStrokeTransparency = 0.22
text.TextXAlignment = Enum.TextXAlignment.Center
text.TextYAlignment = Enum.TextYAlignment.Center
text.Font = Enum.Font.GothamBold
pcall(function()
	text.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
end)
text.Parent = panel

local visual = Instance.new("Part")
visual.Name = "DriveInCustomisationZoneVisual"
visual.Anchored = true
visual.CanCollide = false
visual.CanTouch = false
visual.CanQuery = false
visual.Material = Enum.Material.Neon
visual.Color = Color3.fromRGB(230, 88, 205)
visual.Transparency = 1
visual.Parent = visualRoot

local visualSelection = Instance.new("SelectionBox")
visualSelection.Name = "Outline"
visualSelection.Adornee = visual
visualSelection.Color3 = Color3.fromRGB(230, 88, 205)
visualSelection.LineThickness = 0.04
visualSelection.SurfaceTransparency = 0.86
visualSelection.Transparency = 1
visualSelection.Parent = visual

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
	panel.BackgroundColor3 = readColor(uiConfig, "PanelColor", Color3.fromRGB(6, 10, 13))
	panel.BackgroundTransparency = readNumber(uiConfig, "PanelTransparency", 0.12)
	text.TextColor3 = readColor(uiConfig, "TextColor", Color3.fromRGB(255, 226, 249))
	stroke.Color = readColor(uiConfig, "AccentColor", Color3.fromRGB(230, 88, 205))
	visual.Color = readColor(uiConfig, "ZoneColor", Color3.fromRGB(230, 88, 205))
	visual.Transparency = readNumber(uiConfig, "ZoneTransparency", 0.62)
	visualSelection.Color3 = visual.Color
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
	local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
	if root and root:IsA("BasePart") then
		return root.Position
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
		if child:IsA("ScreenGui") and child.Enabled and child ~= gui then
			local root = child:FindFirstChild("GarageRoot", true)
				or child:FindFirstChild("DealershipRoot", true)
				or child:FindFirstChild("CustomisationRoot", true)
				or child:FindFirstChild("CustomizationRoot", true)
			if root and root:IsA("GuiObject") and root.Visible then
				return true
			end
		end
	end
	return false
end

local function openEvent()
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local intro = controllers and controllers:FindFirstChild("Intro")
	local event = intro and intro:FindFirstChild(OPEN_EVENT_NAME)
	return event and event:IsA("BindableEvent") and event or nil
end

local countdownActive = false
local cooldownUntil = 0
local lastPulse = 0

local function setCountdownVisible(visible)
	if panel.Visible == visible then return end
	panel.Visible = visible
	if visible then
		panel.BackgroundTransparency = 1
		TweenService:Create(panel, TweenInfo.new(0.12), { BackgroundTransparency = readNumber(uiConfig, "PanelTransparency", 0.12) }):Play()
	end
end

local function updateVisual(zone, driving)
	if zone and driving and readBool(runtimeConfig, "Enabled", true) and zone:GetAttribute("Enabled") ~= false then
		visual.CFrame = zone.CFrame
		visual.Size = zone.Size
		visual.Transparency = readNumber(uiConfig, "ZoneTransparency", 0.62)
		visualSelection.Transparency = 0
	else
		visual.Transparency = 1
		visualSelection.Transparency = 1
	end
end

local function beginCountdown(zone)
	if countdownActive or os.clock() < cooldownUntil then return end
	countdownActive = true
	local duration = tonumber(zone:GetAttribute("CountdownSeconds")) or readNumber(runtimeConfig, "CountdownSeconds", 3)
	duration = math.max(0.5, duration)
	local started = os.clock()
	setCountdownVisible(true)
	while countdownActive do
		local vehicle, seat = drivingVehicle()
		local inside = vehicle and pointInsideZone(zone, vehiclePosition(vehicle, seat)) and not garageUiVisible()
		if not inside or zone:GetAttribute("Enabled") == false or readBool(runtimeConfig, "Enabled", true) == false then
			break
		end
		local remaining = math.max(0, duration - (os.clock() - started))
		local shown = math.max(1, math.ceil(remaining))
		text.Text = string.upper(tostring(zone:GetAttribute("PromptPrefix") or readString(uiConfig, "PromptPrefix", "ENTERING CUSTOMISATION IN"))) .. " " .. tostring(shown)
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
	setCountdownVisible(false)
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastPulse < readNumber(runtimeConfig, "PollSeconds", 0.1) then return end
	lastPulse = now
	applyUiConfig()
	local zone = taggedZone()
	local vehicle, seat = drivingVehicle()
	updateVisual(zone, vehicle ~= nil)
	if not zone or not vehicle or garageUiVisible() or os.clock() < cooldownUntil then
		if not countdownActive then setCountdownVisible(false) end
		return
	end
	if zone:GetAttribute("Enabled") == false or readBool(runtimeConfig, "Enabled", true) == false then return end
	if pointInsideZone(zone, vehiclePosition(vehicle, seat)) then
		task.spawn(beginCountdown, zone)
	end
end)
]=]

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
	info("Installed isolated drive-in countdown client.")
end

local function patchBootstrap()
	local clientRoot = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient")
	local scriptObject = clientRoot:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
	local source = scriptObject.Source
	if findPlain(source, BOOTSTRAP_MARKER) then
		info("Bootstrap drive-in customisation handoff already present.")
		return
	end
	assert(findPlain(source, "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4C_EXIT_STOP"), "Expected Phase 4C exit handoff before drive-in customisation.")
	assert(findPlain(source, "local function NTR_openOwnedCockpitCustomisation()"), "Expected customisation open hook before drive-in customisation.")

	local functionBlock = [=[

-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP
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

	if currentVehicle then
		callServer("DespawnVehicle", {})
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

	NTR_openGarageWithMode("Customisation")
	task.spawn(function()
		for _ = 1, 80 do
			if UI and UI.Gui and typeof(showStage) == "function" and typeof(renderModuleShop) == "function" and typeof(sortedSlots) == "function" then
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
		local firstSlot = sortedSlots()[1]
		State.SelectedSlot = firstSlot and firstSlot.SlotId or State.SelectedSlot or "Engine1"
		if UI and UI.Gui then
			UI.Gui.Enabled = true
		end
		setCameraSection(State.SelectedSlot or "Engine1")
		showStage("ModuleShop")
		renderModuleShop()
	end)
end
-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP_END
]=]

	source = replaceOnce(
		source,
		[=[
local function NTR_openOwnedCockpitCustomisation()
	NTR_openGarageWithMode("Customisation")
end
]=],
		[=[
local function NTR_openOwnedCockpitCustomisation()
	NTR_openGarageWithMode("Customisation")
end
]=] .. functionBlock,
		"drive-in customisation bootstrap function"
	)

	source = replaceOnce(
		source,
		[=[
	customisationEvent.Event:Connect(NTR_openOwnedCockpitCustomisation)

	script:SetAttribute("DealershipIntroGarageGateActive", true)
]=],
		[=[
	customisationEvent.Event:Connect(NTR_openOwnedCockpitCustomisation)

	_G.NTRDriveInCustomisationPhase1.Event = introFolder:FindFirstChild(_G.NTRDriveInCustomisationPhase1.OpenEventName)
	if _G.NTRDriveInCustomisationPhase1.Event and not _G.NTRDriveInCustomisationPhase1.Event:IsA("BindableEvent") then
		warn("[NTR Drive-In Customisation Phase 1] " .. _G.NTRDriveInCustomisationPhase1.Event:GetFullName() .. " exists but is " .. _G.NTRDriveInCustomisationPhase1.Event.ClassName .. ", expected BindableEvent.")
		return
	end
	if not _G.NTRDriveInCustomisationPhase1.Event then
		_G.NTRDriveInCustomisationPhase1.Event = Instance.new("BindableEvent")
		_G.NTRDriveInCustomisationPhase1.Event.Name = _G.NTRDriveInCustomisationPhase1.OpenEventName
		_G.NTRDriveInCustomisationPhase1.Event.Parent = introFolder
	end
	_G.NTRDriveInCustomisationPhase1.Event.Event:Connect(function()
		_G.NTRDriveInCustomisationPhase1.OpenDrivenVehicleModuleShop()
	end)

	script:SetAttribute("DealershipIntroGarageGateActive", true)
]=],
		"drive-in customisation bindable event hook"
	)

	scriptObject.Source = source
	info("Patched bootstrap with drive-in Build Modules handoff.")
end

setupConfig()
setupMarker()
installClient()
patchBootstrap()

info("Phase 1 install complete. Move DriveInCustomisationTrigger as needed, then test driving into it for the countdown.")
