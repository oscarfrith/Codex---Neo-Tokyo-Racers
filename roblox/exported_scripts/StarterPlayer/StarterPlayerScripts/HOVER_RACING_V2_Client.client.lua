local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local kit = ReplicatedStorage:WaitForChild("HOVER_RACING_V2_KIT")
local invoke = kit:WaitForChild("REMOTES_DoNotRename"):WaitForChild("GarageInvoke")
local categoriesRoot = kit:WaitForChild("VEHICLE_CATEGORIES")
local driveWorld = Workspace:WaitForChild("HOVER_RACING_V2_WORLD")
local vehiclesRoot = driveWorld:WaitForChild("PLAYER_VEHICLES_Runtime")
local themeFolder = kit:WaitForChild("UI_THEME_DoNotRename", 5)
local V22Modules = {
	VehicleVFXController = require(kit:WaitForChild("CLIENT_MODULES"):WaitForChild("VFX"):WaitForChild("VehicleVFXController")),
	VehicleStatsCache = require(kit:WaitForChild("SHARED_MODULES"):WaitForChild("VehicleStatsCache")),
	ReentryThrottle = require(kit:WaitForChild("CLIENT_MODULES"):WaitForChild("Controllers"):WaitForChild("ReentryThrottle")),
	UIPool = require(kit:WaitForChild("CLIENT_MODULES"):WaitForChild("UI"):WaitForChild("UIPool")),
}

local DefaultTheme = {
	Panel = Color3.fromRGB(5, 9, 7),
	PanelSoft = Color3.fromRGB(12, 20, 17),
	Card = Color3.fromRGB(24, 35, 42),
	CardHot = Color3.fromRGB(36, 118, 82),
	Text = Color3.fromRGB(218, 255, 231),
	Muted = Color3.fromRGB(145, 178, 160),
	Accent = Color3.fromRGB(172, 255, 197),
	Cash = Color3.fromRGB(255, 193, 50),
	Danger = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),
	Disabled = Color3.fromRGB(62, 72, 73),
	PanelTransparency = 0.12,
	ButtonTransparency = 0.08,
	PanelStrokeTransparency = 0.2,
	ButtonStrokeTransparency = 0.62,
	StrokeWidth = 1,
	PanelCornerRadius = 5,
	ButtonCornerRadius = 4,
	FontFamily = "rbxasset://fonts/families/Michroma.json",
}

local Theme = {}

local function readThemeColor(name, fallback, alternateName)
	local item = themeFolder and (themeFolder:FindFirstChild(name) or (alternateName and themeFolder:FindFirstChild(alternateName)))
	return item and item:IsA("Color3Value") and item.Value or fallback
end

local function readThemeNumber(name, fallback)
	local item = themeFolder and themeFolder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function readThemeString(name, fallback)
	local item = themeFolder and themeFolder:FindFirstChild(name)
	return item and item:IsA("StringValue") and item.Value or fallback
end

local function refreshThemeFromValues()
	Theme.Panel = readThemeColor("Panel", DefaultTheme.Panel)
	Theme.PanelSoft = readThemeColor("PanelSoft", DefaultTheme.PanelSoft)
	Theme.Card = readThemeColor("Card", DefaultTheme.Card)
	Theme.CardHot = readThemeColor("Selected", DefaultTheme.CardHot, "CardHot")
	Theme.Text = readThemeColor("Text", DefaultTheme.Text)
	Theme.Muted = readThemeColor("Muted", DefaultTheme.Muted)
	Theme.Accent = readThemeColor("Accent", DefaultTheme.Accent)
	Theme.Cash = readThemeColor("Cash", DefaultTheme.Cash)
	Theme.Danger = readThemeColor("Danger", DefaultTheme.Danger)
	Theme.Buy = readThemeColor("Buy", DefaultTheme.Buy)
	Theme.Disabled = readThemeColor("Disabled", DefaultTheme.Disabled)
	Theme.PanelTransparency = math.clamp(readThemeNumber("PanelTransparency", DefaultTheme.PanelTransparency), 0, 1)
	Theme.ButtonTransparency = math.clamp(readThemeNumber("ButtonTransparency", DefaultTheme.ButtonTransparency), 0, 1)
	Theme.PanelStrokeTransparency = math.clamp(readThemeNumber("PanelStrokeTransparency", DefaultTheme.PanelStrokeTransparency), 0, 1)
	Theme.ButtonStrokeTransparency = math.clamp(readThemeNumber("ButtonStrokeTransparency", DefaultTheme.ButtonStrokeTransparency), 0, 1)
	Theme.StrokeWidth = math.max(0, readThemeNumber("StrokeWidth", DefaultTheme.StrokeWidth))
	Theme.PanelCornerRadius = math.max(0, readThemeNumber("PanelCornerRadius", DefaultTheme.PanelCornerRadius))
	Theme.ButtonCornerRadius = math.max(0, readThemeNumber("ButtonCornerRadius", DefaultTheme.ButtonCornerRadius))
	Theme.FontFamily = readThemeString("FontFamily", DefaultTheme.FontFamily)
end

refreshThemeFromValues()

local State = {
	Stage = "CockpitShop",
	ModuleMode = "Slots",
	CustomizeMode = "Overview",
	Catalog = nil,
	Profile = nil,
	CategoryId = "bruiser",
	SelectedCockpit = "bruiser_01",
	SelectedSlot = nil,
	SelectedModuleId = nil,
	CustomizeTarget = "ALL",
	ColorChannel = "Primary",
	Hue = 0.52,
	Saturation = 0.9,
	Brightness = 0.9,
	PreviewModules = {},
	GarageCameraActive = true,
	CameraFocus = Vector3.new(860, 104, -1749),
	TargetFocus = Vector3.new(860, 104, -1749),
	CameraYaw = math.rad(180),
	TargetYaw = math.rad(180),
	CameraPitch = math.rad(-12),
	TargetPitch = math.rad(-12),
	CameraDistance = 24.3,
	TargetDistance = 24.3,
	Dragging = false,
	LastPointer = nil,
}

local UI = {}
local Preview = {}
local ButtonPools = {}
local pickerConnections = {}
local arrowConnections = {}

local BOTTOM_HEIGHT = 108
local BOTTOM_MARGIN = 18

local currentVehicle = nil
local cachedDriveStats = nil
local vehicleVFX = nil
local controls = nil
local driveConnection = nil
local rayParams = nil
local isDriving = false
local throttle = 0
local steer = 0
local driftHeld = false
local gamepadSteer = 0
local gamepadAccel = 0
local gamepadBrake = 0
local gamepadBoostHeld = false
local mobileThrottle = 0
local mobileSteer = 0
local mobileBoostHeld = false
local mobileDriftActive = false
local boost = 100
local driftCharge = 0
local driftBlend = 0
local miniBoostTimer = 0
local yawHeading = 0
local currentBank = 0
local reentryCooldown = 0
local reentryProbe = V22Modules.ReentryThrottle.new(0.15)
local savedJumpPower = nil
local savedJumpHeight = nil
local savedAutoJump = nil
local savedJumpEnabled = nil

local REVERSE_MAX_MPH = 20
local HOVER_HEIGHT = 3
local SENSOR_START_HEIGHT = 2
local SENSOR_LENGTH = 24
local MPH_PER_STUD = 0.625

local driveGui = nil
local driveHud = nil
local mphLabel = nil
local boostFill = nil
local driftLabel = nil
local driveMenu = nil
local mobileControls = nil

local function cloneArray(list)
	local copy = {}
	for i, value in ipairs(list or {}) do
		copy[i] = value
	end
	return copy
end

local function font()
	local ok, result = pcall(function()
		return Font.new(Theme.FontFamily or DefaultTheme.FontFamily, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	end)
	return ok and result or Font.fromEnum(Enum.Font.GothamBold)
end

local function new(className, props, parent)
	local object = Instance.new(className)
	for key, value in pairs(props or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") and not child:IsA("UIScale") and not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
end

local function corner(object, radius)
	new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.ButtonCornerRadius or 4) }, object)
end

local function stroke(object, color, transparency, thickness)
	new("UIStroke", {
		Color = color or Theme.Accent,
		Transparency = transparency ~= nil and transparency or 0.25,
		Thickness = thickness or Theme.StrokeWidth or 1,
	}, object)
end

local function pad(object, amount)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, amount),
		PaddingRight = UDim.new(0, amount),
		PaddingTop = UDim.new(0, amount),
		PaddingBottom = UDim.new(0, amount),
	}, object)
end

local function label(parent, text, size, position, textSize, align)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position or UDim2.fromScale(0, 0),
		FontFace = font(),
		Text = text or "",
		TextColor3 = Theme.Text,
		TextSize = UserInputService.TouchEnabled and (textSize or 12) or math.max(textSize or 12, 13),
		TextWrapped = true,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

local function button(parent, text, size, position, color)
	local b = new("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = color or Theme.Card,
		BackgroundTransparency = Theme.ButtonTransparency or 0.08,
		BorderSizePixel = 0,
		Size = size,
		Position = position or UDim2.fromScale(0, 0),
		FontFace = font(),
		Text = string.upper(text or ""),
		TextColor3 = Theme.Text,
		TextSize = UserInputService.TouchEnabled and 11 or 13,
		TextWrapped = true,
		ClipsDescendants = false,
	}, parent)
	corner(b, Theme.ButtonCornerRadius or 4)
	stroke(b, Theme.Accent, Theme.ButtonStrokeTransparency, Theme.StrokeWidth)
	return b
end

local function panel(parent, name, size, position, anchor)
	local p = new("Frame", {
		Name = name,
		AnchorPoint = anchor or Vector2.zero,
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = Theme.PanelTransparency or 0.12,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Size = size,
		Position = position,
	}, parent)
	corner(p, Theme.PanelCornerRadius or 5)
	stroke(p, Theme.Accent, Theme.PanelStrokeTransparency, Theme.StrokeWidth)
	return p
end

local function buttonPool(name, parent)
	local pool = ButtonPools[name]
	if not pool then
		pool = V22Modules.UIPool.new(parent)
		ButtonPools[name] = pool
	else
		pool:SetContainer(parent)
	end
	return pool
end

local function clearPooledDynamicChildren(object)
	for _, child in ipairs(object:GetChildren()) do
		if child:GetAttribute("PooledDynamic") == true then
			child:Destroy()
		end
	end
end

local function pooledButton(pool, text, size, position, color)
	local b = pool:Acquire(function()
		return button(pool.Container, text, size, position, color)
	end)
	clearPooledDynamicChildren(b)
	b.Text = string.upper(text or "")
	b.Size = size
	b.Position = position or UDim2.fromScale(0, 0)
	b.BackgroundColor3 = color or Theme.Card
	b.BackgroundTransparency = Theme.ButtonTransparency or 0.08
	b.TextColor3 = Theme.Text
	b.Visible = true
	return b
end

local function pooledLabel(parent, text, size, position, textSize, align)
	local l = label(parent, text, size, position, textSize, align)
	l:SetAttribute("PooledDynamic", true)
	return l
end

local function callServer(action, args)
	local ok, result = pcall(function()
		return invoke:InvokeServer(action, args or {})
	end)
	if ok and typeof(result) == "table" then
		if result.Profile then State.Profile = result.Profile end
		return result
	end
	return { Success = false, Message = "Garage server did not respond." }
end

local function disconnectPickerInputs()
	for _, connection in ipairs(pickerConnections) do
		connection:Disconnect()
	end
	pickerConnections = {}
end

local function getCategory()
	for _, category in ipairs((State.Catalog and State.Catalog.Categories) or {}) do
		if category.CategoryId == State.CategoryId then return category end
	end
end

local function sortedSlots()
	local category = getCategory()
	local slots = cloneArray(category and category.Slots)
	table.sort(slots, function(a, b) return (a.Order or 99) < (b.Order or 99) end)
	return slots
end

local function getSlot(slotId)
	for _, slot in ipairs(sortedSlots()) do
		if slot.SlotId == slotId then return slot end
	end
end

local function getCockpit(cockpitId)
	local category = getCategory()
	for _, cockpit in ipairs((category and category.Cockpits) or {}) do
		if cockpit.CockpitId == cockpitId then return cockpit end
	end
end

local function getModule(moduleId)
	local category = getCategory()
	for _, list in pairs((category and category.Modules) or {}) do
		for _, module in ipairs(list) do
			if module.ModuleId == moduleId then return module end
		end
	end
end

local function modulesForSlot(slotId)
	local slot = getSlot(slotId)
	local category = getCategory()
	local result = {}
	if not slot or not category then return result end
	local list = (category.Modules and category.Modules[slot.ModuleType]) or {}
	for _, module in ipairs(list) do
		if not slot.AllowedModuleFolder or slot.AllowedModuleFolder == "" or module.ModuleFolder == slot.AllowedModuleFolder then
			table.insert(result, module)
		end
	end
	local owned = (State.Profile and State.Profile.OwnedModules) or {}
	table.sort(result, function(a, b)
		local ao, bo = owned[a.ModuleId] == true, owned[b.ModuleId] == true
		if ao ~= bo then return not ao end
		return tostring(a.DisplayName or "") < tostring(b.DisplayName or "")
	end)
	return result
end

local function slotDisplayName(slot)
	local slotId = typeof(slot) == "table" and slot.SlotId or tostring(slot or "")
	if slotId == "Engine1" then return "Front Engine" end
	if slotId == "Engine2" then return "Rear Engine" end
	if typeof(slot) == "table" then return slot.DisplayName or slot.SlotId end
	return slotId
end

local function showTop(title, subtitle)
	UI.Title.Text = string.upper(title or "NEON HOVER RACING")
	UI.Subtitle.Text = subtitle or ""
	UI.Cash.Text = "$" .. tostring((State.Profile and State.Profile.Cash) or 0)
end

local function setNextText(text)
	UI.Next.Text = string.upper(text or "NEXT")
end

local function previewRoot()
	if Preview.Root and Preview.Root.Parent then return Preview.Root end
	local existing = Workspace:FindFirstChild("HOVER_RACING_V2_LOCAL_PREVIEW")
	if existing then existing:Destroy() end
	local root = Instance.new("Folder")
	root.Name = "HOVER_RACING_V2_LOCAL_PREVIEW"
	root.Parent = Workspace
	Preview.Root = root
	return root
end

local function findTemplateByAttribute(root, attr, value)
	for _, item in ipairs(root:GetDescendants()) do
		if item:GetAttribute(attr) == value then return item end
	end
end

local PAINT_CHANNEL_FOLDERS = {
	PRIMARY_ReplaceWithPrimaryMeshes = "Primary",
	SECONDARY_ReplaceWithSecondaryMeshes = "Secondary",
	DETAIL_ReplaceWithDetailMeshes = "Detail",
	NEON_OptionalLights = "Neon",
	THRUST_COLOR_WhiteByDefault = "ThrustColor",
}

local function resolvePaintChannel(part)
	local current = part
	while current do
		local folderChannel = PAINT_CHANNEL_FOLDERS[current.Name]
		if folderChannel then return folderChannel end
		current = current.Parent
	end

	current = part
	while current do
		local attr = current:GetAttribute("PaintChannel")
		if typeof(attr) == "string" and attr ~= "" then return attr end
		current = current.Parent
	end

	current = part
	while current do
		local lower = string.lower(current.Name)
		if string.find(lower, "thrust_color", 1, true) then return "ThrustColor" end
		if string.find(lower, "primary", 1, true) then return "Primary" end
		if string.find(lower, "secondary", 1, true) then return "Secondary" end
		if string.find(lower, "detail", 1, true) then return "Detail" end
		if string.find(lower, "neon", 1, true) then return "Neon" end
		current = current.Parent
	end
end

local function isChannelMatch(part, channel)
	return resolvePaintChannel(part) == channel
end


local function pathHas(object, text)
	text = string.lower(text)
	local current = object
	while current do
		if string.find(string.lower(current.Name), text, 1, true) then return true end
		current = current.Parent
	end
	return false
end

local function applyColors(model, colors, neonVisible)
	colors = colors or {}
	local frontLight = colors.FrontLights or Color3.fromRGB(252, 250, 255)
	local rearLight = colors.RearLights or Color3.fromRGB(255, 116, 116)
	local neonColor = colors.Neon or Color3.fromRGB(255, 255, 255)
	local thrustColor = colors.ThrustColor or (State.Profile and State.Profile.ThrustColor) or Color3.fromRGB(255, 255, 255)

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if part:GetAttribute("TemplateRole") == "FixedSlotMount" then
				part.Transparency = 1
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			elseif isChannelMatch(part, "ThrustColor") then
				part.Color = thrustColor
				part.Material = Enum.Material.Neon
				part.Transparency = 0
			elseif isChannelMatch(part, "Neon") then
				local lightColor = neonColor
				if pathHas(part, "cockpit") then
					if pathHas(part, "front") then
						lightColor = frontLight
					elseif pathHas(part, "rear") or pathHas(part, "back") then
						lightColor = rearLight
					end
				end
				part.Color = lightColor
				part.Material = Enum.Material.Neon
				part.Transparency = neonVisible and 0 or 1
			elseif isChannelMatch(part, "Primary") then
				part.Color = colors.Primary or part.Color
			elseif isChannelMatch(part, "Secondary") then
				part.Color = colors.Secondary or part.Color
			elseif isChannelMatch(part, "Detail") then
				part.Color = colors.Detail or part.Color
			end
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
end


local function getSlotMount(vehicle, slotId)
	local root = vehicle:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename", true)
	local slot = root and root:FindFirstChild("SLOT_" .. slotId)
	return slot and slot:FindFirstChild("Mount_DoNotRename")
end

local function pivotModuleToSlot(moduleClone, mount)
	local root = moduleClone.PrimaryPart or moduleClone:FindFirstChild("ModuleRoot_DoNotRename", true)
	if root then moduleClone.PrimaryPart = root end
	local moduleAttachment = moduleClone:FindFirstChild("MountAttachment", true)
	local mountAttachment = mount and mount:FindFirstChild("MountAttachment")
	if moduleAttachment and mountAttachment then
		moduleClone:PivotTo(mountAttachment.WorldCFrame * moduleAttachment.CFrame:Inverse())
	elseif mount then
		moduleClone:PivotTo(mount.CFrame)
	end
end

local function moduleColors(slotId)
	local profile = State.Profile or {}
	local cockpitColors = profile.CockpitColors or {}
	local moduleSet = profile.ModuleColors and profile.ModuleColors[slotId] or {}
	return {
		Primary = moduleSet.Primary or cockpitColors.Primary or Color3.fromRGB(18, 202, 224),
		Secondary = moduleSet.Secondary or cockpitColors.Secondary or Color3.fromRGB(252, 250, 255),
		Detail = moduleSet.Detail or cockpitColors.Detail or Color3.fromRGB(38, 47, 55),
		Neon = moduleSet.Neon or Color3.fromRGB(255, 255, 255),
		ThrustColor = profile.ThrustColor or moduleSet.ThrustColor or Color3.fromRGB(255, 255, 255),
	}
end


local function clearPreviewModules()
	State.PreviewModules = {}
	State.SelectedModuleId = nil
end

local function setCameraSection(slotId)
	local yawBySlot = {
		FrontBumper = math.rad(180),
		RearBumper = math.rad(0),
		RearSpoiler = math.rad(0),
		Boost = math.rad(0),
		Engine1 = math.rad(135),
		Engine2 = math.rad(45),
		SidePods = math.rad(90),
		Stabilisers = math.rad(90),
	}
	State.TargetYaw = yawBySlot[slotId] or math.rad(180)
	State.TargetPitch = math.rad(-12)
	State.TargetDistance = 33
end


local function buildPreview()
	local root = previewRoot()
	root:ClearAllChildren()

	local cockpitId = State.SelectedCockpit or (State.Profile and State.Profile.CurrentCockpit) or "bruiser_01"
	local template = findTemplateByAttribute(categoriesRoot, "CockpitId", cockpitId)
	if not template then return end

	local vehicle = template:Clone()
	vehicle.Name = "LOCAL_PREVIEW_" .. cockpitId
	vehicle.Parent = root
	Preview.Vehicle = vehicle
	local primary = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
	if primary then vehicle.PrimaryPart = primary end

	local previewPosition = State.Catalog and State.Catalog.PreviewPosition or Vector3.new(860, 104, -1749)
	vehicle:PivotTo(CFrame.new(previewPosition))
	State.TargetFocus = previewPosition
	local cockpitColors = (State.Profile and State.Profile.CockpitColors) or {}
	cockpitColors.FrontLights = cockpitColors.FrontLights or Color3.fromRGB(252, 250, 255)
	cockpitColors.RearLights = cockpitColors.RearLights or Color3.fromRGB(255, 116, 116)
	applyColors(vehicle, cockpitColors, true)

	root:SetAttribute("ThrustColor", (State.Profile and State.Profile.ThrustColor) or Color3.fromRGB(255, 255, 255))
	root:SetAttribute("ForceThrustPreview", State.ThrustPreviewActive == true)
	vehicle:SetAttribute("ThrustColor", (State.Profile and State.Profile.ThrustColor) or Color3.fromRGB(255, 255, 255))

	local installedRoot = vehicle:FindFirstChild("INSTALLED_MODULES_Runtime") or Instance.new("Folder")
	installedRoot.Name = "INSTALLED_MODULES_Runtime"
	installedRoot.Parent = vehicle
	installedRoot:ClearAllChildren()

	local modulesToShow = {}
	for slotId, moduleId in pairs((State.Profile and State.Profile.InstalledModules) or {}) do
		modulesToShow[slotId] = moduleId
	end
	for slotId, moduleId in pairs(State.PreviewModules or {}) do
		modulesToShow[slotId] = moduleId
	end

	for slotId, moduleId in pairs(modulesToShow) do
		local moduleTemplate = findTemplateByAttribute(categoriesRoot, "ModuleId", moduleId)
		local mount = getSlotMount(vehicle, slotId)
		if moduleTemplate and mount then
			local clone = moduleTemplate:Clone()
			clone.Name = "PREVIEW_" .. slotId .. "_" .. moduleTemplate.Name
			clone.Parent = installedRoot
			pivotModuleToSlot(clone, mount)
			local neonOwned = (State.Profile and State.Profile.NeonOwned) or {}
			local previewNeon = State.PreviewNeonSlot == slotId
			applyColors(clone, moduleColors(slotId), neonOwned[slotId] == true or previewNeon)
		end
	end
end


local function wrapAngle(angle)
	return math.atan2(math.sin(angle), math.cos(angle))
end

local function lerpAngle(a, b, t)
	return a + wrapAngle(b - a) * t
end

local function updateCamera(dt)
	if isDriving or State.GarageCameraActive == false or not UI.Gui or UI.Gui.Enabled == false then return end
	if not camera then camera = Workspace.CurrentCamera end
	if not camera then return end
	camera.CameraType = Enum.CameraType.Scriptable
	local t = math.clamp(dt * 7, 0, 1)
	State.CameraFocus = State.CameraFocus:Lerp(State.TargetFocus, t)
	State.CameraYaw = lerpAngle(State.CameraYaw, State.TargetYaw, t)
	State.CameraPitch = State.CameraPitch + (State.TargetPitch - State.CameraPitch) * t
	State.CameraDistance = State.CameraDistance + (State.TargetDistance - State.CameraDistance) * t
	local offset = CFrame.Angles(0, State.CameraYaw, 0) * CFrame.Angles(State.CameraPitch, 0, 0) * Vector3.new(0, 0, State.CameraDistance)
	camera.CFrame = CFrame.lookAt(State.CameraFocus + offset, State.CameraFocus)
end

local function renderStatsOnly(parent, stats, baseStats)
	clear(parent)
	label(parent, "Vehicle Stats", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 0), 15, Enum.TextXAlignment.Center)
	local order = { "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost" }
	for i, stat in ipairs(order) do
		local y = 31 + (i - 1) * 25
		label(parent, stat, UDim2.new(0.42, 0, 0, 18), UDim2.fromOffset(0, y), 10, Enum.TextXAlignment.Left)
		local bar = new("Frame", { BackgroundColor3 = Color3.fromRGB(39, 48, 49), BorderSizePixel = 0, Size = UDim2.new(0.55, 0, 0, 10), Position = UDim2.new(0.43, 0, 0, y + 5) }, parent)
		corner(bar, 3)
		local divisor = stat == "Weight" and 180 or 180
		local value = stats[stat] or 0
		local baseValue = baseStats and baseStats[stat] or value
		local amount = math.clamp(value / divisor, 0, 1)
		local baseAmount = math.clamp(baseValue / divisor, 0, 1)
		local fill = new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(math.min(amount, baseAmount), 1) }, bar)
		corner(fill, 3)
		if amount > baseAmount + 0.005 then
			local delta = new("Frame", { BackgroundColor3 = Color3.fromRGB(84, 255, 126), BorderSizePixel = 0, Size = UDim2.fromScale(amount - baseAmount, 1), Position = UDim2.fromScale(baseAmount, 0) }, bar)
			corner(delta, 3)
		elseif amount < baseAmount - 0.005 then
			local delta = new("Frame", { BackgroundColor3 = Color3.fromRGB(230, 64, 74), BorderSizePixel = 0, Size = UDim2.fromScale(baseAmount - amount, 1), Position = UDim2.fromScale(amount, 0) }, bar)
			corner(delta, 3)
		elseif amount > 0 then
			fill.Size = UDim2.fromScale(amount, 1)
		end
		label(bar, tostring(math.floor(value)), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 8, Enum.TextXAlignment.Center)
	end
end

local function getUpgrade(upgradeId)
	local category = getCategory()
	for _, upgrade in ipairs((category and category.Upgrades) or {}) do
		if upgrade.UpgradeId == upgradeId or upgrade.Id == upgradeId then return upgrade end
	end
end

local function currentStats()
	if State.Stage == "CockpitShop" then
		return getCockpit(State.SelectedCockpit) or {}
	end
	local base = (State.Profile and State.Profile.TotalStats) or getCockpit(State.SelectedCockpit) or {}
	if State.Stage == "ModuleShop" and State.ModuleMode == "Options" and State.SelectedSlot and State.SelectedModuleId then
		local preview = {}
		for key, value in pairs(base) do
			if typeof(value) == "number" then preview[key] = value end
		end
		local installedId = State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[State.SelectedSlot]
		local installed = installedId and getModule(installedId)
		local selected = getModule(State.SelectedModuleId)
		for _, stat in ipairs({ "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost" }) do
			preview[stat] = preview[stat] or 0
			if installed then preview[stat] -= installed[stat] or 0 end
			if selected then preview[stat] += selected[stat] or 0 end
		end
		return preview, base
	end
	if State.Stage == "Customise" and State.PreviewUpgradeId then
		local preview = {}
		for key, value in pairs(base) do
			if typeof(value) == "number" then preview[key] = value end
		end
		local upgrade = getUpgrade(State.PreviewUpgradeId)
		if upgrade then
			local stat = upgrade.Stat or upgrade.StatName or upgrade.UpgradeStat
			local amount = upgrade.Amount or upgrade.Value or upgrade.Increment or 0
			if stat and typeof(amount) == "number" then
				preview[stat] = (preview[stat] or 0) + amount
			end
		end
		return preview, base
	end
	return base
end


local applyDealershipLayout

local function renderStatsPanel()
	if UI.StatsPanel then
		if State.Stage == "CockpitShop" then
			applyDealershipLayout()
		else
			UI.StatsPanel.AnchorPoint = Vector2.zero
			UI.StatsPanel.Position = UDim2.new(1, -292, 0, 112)
			UI.StatsPanel.Size = UDim2.fromOffset(270, 238)
		end
		local stats, baseStats = currentStats()
		renderStatsOnly(UI.StatsPanel, stats, baseStats)
	end
end

local function makeArrowScroller(parent, scroller, axis, step)
	step = step or 320
	scroller.ScrollBarThickness = 0
	scroller.ScrollBarImageTransparency = 1
	local prev = button(parent, axis == "X" and "<" or "^", axis == "X" and UDim2.fromOffset(28, 44) or UDim2.fromOffset(44, 24), axis == "X" and UDim2.new(0, 4, 0.5, 0) or UDim2.new(0.5, 0, 0, 4), Theme.PanelSoft)
	prev.AnchorPoint = axis == "X" and Vector2.new(0, 0.5) or Vector2.new(0.5, 0)
	prev.ZIndex = 30
	local next = button(parent, axis == "X" and ">" or "v", axis == "X" and UDim2.fromOffset(28, 44) or UDim2.fromOffset(44, 24), axis == "X" and UDim2.new(1, -4, 0.5, 0) or UDim2.new(0.5, 0, 1, -4), Theme.PanelSoft)
	next.AnchorPoint = axis == "X" and Vector2.new(1, 0.5) or Vector2.new(0.5, 1)
	next.ZIndex = 30

	local function maxCanvas()
		if axis == "X" then
			return math.max(0, scroller.AbsoluteCanvasSize.X - scroller.AbsoluteWindowSize.X)
		end
		return math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y)
	end
	local function update()
		local max = maxCanvas()
		scroller.ScrollingEnabled = max > 2
		if axis == "X" then
			if scroller.CanvasPosition.X > max then scroller.CanvasPosition = Vector2.new(max, scroller.CanvasPosition.Y) end
			prev.Visible = parent.Visible and max > 2 and scroller.CanvasPosition.X > 2
			next.Visible = parent.Visible and max > 2 and scroller.CanvasPosition.X < max - 2
		else
			if scroller.CanvasPosition.Y > max then scroller.CanvasPosition = Vector2.new(scroller.CanvasPosition.X, max) end
			prev.Visible = parent.Visible and max > 2 and scroller.CanvasPosition.Y > 2
			next.Visible = parent.Visible and max > 2 and scroller.CanvasPosition.Y < max - 2
		end
	end
	prev.MouseButton1Click:Connect(function()
		local p = scroller.CanvasPosition
		if axis == "X" then
			scroller.CanvasPosition = Vector2.new(math.max(0, p.X - step), p.Y)
		else
			scroller.CanvasPosition = Vector2.new(p.X, math.max(0, p.Y - step))
		end
		update()
	end)
	next.MouseButton1Click:Connect(function()
		local p = scroller.CanvasPosition
		local max = maxCanvas()
		if axis == "X" then
			scroller.CanvasPosition = Vector2.new(math.min(max, p.X + step), p.Y)
		else
			scroller.CanvasPosition = Vector2.new(p.X, math.min(max, p.Y + step))
		end
		update()
	end)
	table.insert(arrowConnections, RunService.RenderStepped:Connect(update))
	update()
end

local function updateNav()
	local showNav = State.Stage ~= "CockpitShop"
	UI.NextPanel.Visible = showNav
	if State.Stage == "ModuleShop" then
		setNextText("Customise Modules")
	elseif State.Stage == "Customise" then
		setNextText("Start Driving")
	else
		setNextText("Next")
	end
end

local function showStage(stage)
	State.Stage = stage
	UI.CockpitShop.Visible = stage == "CockpitShop"
	UI.CockpitPaint.Visible = stage == "CockpitPaint"
	UI.ModuleShop.Visible = stage == "ModuleShop"
	UI.Customise.Visible = stage == "Customise"
	updateNav()
	renderStatsPanel()
	buildPreview()
end

local renderCockpitShop
local renderCockpitPaint
local renderModuleShop
local renderCustomise

applyDealershipLayout = function()
	if not UI.CockpitShop or not camera then return end
	local scale = UI.Scale and UI.Scale.Scale or 1
	local viewport = camera.ViewportSize
	local vw = viewport.X / math.max(scale, 0.1)
	local vh = viewport.Y / math.max(scale, 0.1)
	local margin = 18
	local gap = 16
	local topY = 112
	local leftW = 190
	local rightW = 270
	local bottomY = vh - BOTTOM_MARGIN
	local leftCashTop = vh - BOTTOM_MARGIN - BOTTOM_HEIGHT
	local categoryH = math.max(1, leftCashTop - gap - topY)
	local centerX = margin + leftW + gap
	local rightLeft = vw - margin - rightW
	local centerW = math.max(300, rightLeft - gap - centerX)
	local centerH = math.max(240, bottomY - topY)
	local statsH = math.min(520, math.max(1, bottomY - topY))

	if UI.CategoryPanel then
		UI.CategoryPanel.Position = UDim2.fromOffset(margin, topY)
		UI.CategoryPanel.Size = UDim2.fromOffset(leftW, categoryH)
	end
	if UI.CockpitGridPanel then
		UI.CockpitGridPanel.AnchorPoint = Vector2.new(0, 1)
		UI.CockpitGridPanel.Position = UDim2.fromOffset(centerX, bottomY)
		UI.CockpitGridPanel.Size = UDim2.fromOffset(centerW, centerH)
	end
	if UI.StatsPanel and State.Stage == "CockpitShop" then
		UI.StatsPanel.AnchorPoint = Vector2.new(1, 0)
		UI.StatsPanel.Position = UDim2.fromOffset(vw - margin, topY)
		UI.StatsPanel.Size = UDim2.fromOffset(rightW, statsH)
	end
	if UI.CockpitGridLayout then
		local innerW = math.max(1, centerW - 20)
		local innerH = math.max(1, centerH - 20)
		local minCard = UserInputService.TouchEnabled and 82 or 128
		local maxCard = UserInputService.TouchEnabled and 132 or 178
		local cardSize = math.floor(math.clamp(math.min((innerW - 20) / 3, (innerH - 20) / 3), minCard, maxCard))
		UI.CockpitGridLayout.CellPadding = UDim2.fromOffset(10, 10)
		UI.CockpitGridLayout.CellSize = UDim2.fromOffset(cardSize, cardSize)
	end
end

local function showCashShop()
	UI.CashShop.Visible = true
	clear(UI.CashShopBody)
	label(UI.CashShopBody, "Cash Shop", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 0), 18, Enum.TextXAlignment.Center)
	label(UI.CashShopBody, "Add Developer Product IDs to these buttons later.", UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 38), 11, Enum.TextXAlignment.Center)
	for i, amount in ipairs({ 25000, 75000, 200000 }) do
		local b = button(UI.CashShopBody, "$" .. tostring(amount), UDim2.new(1, -28, 0, 44), UDim2.fromOffset(14, 78 + (i - 1) * 54), Theme.Buy)
		b:SetAttribute("ProductId", 0)
		b.MouseButton1Click:Connect(function()
			local productId = b:GetAttribute("ProductId")
			if typeof(productId) == "number" and productId > 0 then
				MarketplaceService:PromptProductPurchase(player, productId)
			else
				UI.Subtitle.Text = "Set this cash button's ProductId attribute first."
			end
		end)
	end
end

local function renderDealershipPanel()
	if not UI.StatsPanel then return end
	applyDealershipLayout()
	clear(UI.StatsPanel)
	local cockpit = getCockpit(State.SelectedCockpit) or {}
	renderStatsOnly(UI.StatsPanel, cockpit)
	label(UI.StatsPanel, "Module Slots", UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 238), 12, Enum.TextXAlignment.Left)
	local y = 268
	local counts = { Engine = 0, Stabilisers = 0, Boost = 0, BodyKit = 0 }
	for _, slot in ipairs(sortedSlots()) do
		local slotId = slot.SlotId or ""
		local moduleType = slot.ModuleType or ""
		if moduleType == "Engine" then
			counts.Engine += 1
		elseif moduleType == "Stabilisers" or moduleType == "Stabiliser" or slotId == "Stabilisers" then
			counts.Stabilisers += 1
		elseif moduleType == "Boost" then
			counts.Boost += 1
		elseif moduleType == "FrontBumper" or moduleType == "RearBumper" or moduleType == "RearSpoiler" or moduleType == "SidePods" or string.find(slotId, "Bumper", 1, true) or string.find(slotId, "Spoiler", 1, true) or string.find(slotId, "SidePods", 1, true) then
			counts.BodyKit += 1
		end
	end
	for _, item in ipairs({ { "Engine", counts.Engine }, { "Stabilisers", counts.Stabilisers }, { "Boost", counts.Boost }, { "Body Kit", counts.BodyKit } }) do
		local count = item[2] or 0
		if count > 0 then
			label(UI.StatsPanel, item[1] .. " x" .. tostring(count), UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, y), 10, Enum.TextXAlignment.Left)
			y += 22
		end
	end
	local owned = State.Profile and State.Profile.OwnedCockpits and State.Profile.OwnedCockpits[State.SelectedCockpit]
	local text = owned and "Select" or ("Buy $" .. tostring(cockpit.Price or 0))
	local selectButton = button(UI.StatsPanel, text, UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), owned and Theme.CardHot or Theme.Buy)
	selectButton.MouseButton1Click:Connect(function()
		local result = callServer("BuyCockpit", { CockpitId = State.SelectedCockpit })
		if result.Success then
			showStage("CockpitPaint")
			renderCockpitPaint()
		else
			UI.Subtitle.Text = result.Message or "Could not buy cockpit."
		end
	end)
end

renderCockpitShop = function()
	showTop("Dealership", "Choose a vehicle category, then pick a cockpit.")
	updateNav()
	local categoryPool = buttonPool("CategoryList", UI.CategoryList)
	local cockpitPool = buttonPool("CockpitGrid", UI.CockpitGrid)
	categoryPool:Begin()
	cockpitPool:Begin()
	UI.CockpitGrid.CanvasPosition = Vector2.zero
	applyDealershipLayout()
	renderDealershipPanel()

	for _, category in ipairs((State.Catalog and State.Catalog.Categories) or {}) do
		local b = pooledButton(categoryPool, category.DisplayName or category.CategoryId, UDim2.new(1, 0, 0, 54), UDim2.fromScale(0, 0), category.CategoryId == State.CategoryId and Theme.CardHot or Theme.Card)
		categoryPool:Connect(b, b.MouseButton1Click, function()
			State.CategoryId = category.CategoryId
			renderCockpitShop()
		end)
	end

	local category = getCategory()
	for _, cockpit in ipairs((category and category.Cockpits) or {}) do
		local card = pooledButton(cockpitPool, "", UDim2.fromOffset(118, 118), UDim2.fromScale(0, 0), cockpit.CockpitId == State.SelectedCockpit and Theme.CardHot or Theme.Card)
		local icon = new("Frame", { BackgroundColor3 = Color3.fromRGB(18, 27, 31), Size = UDim2.new(1, -18, 0, 42), Position = UDim2.fromOffset(9, 9), BorderSizePixel = 0 }, card)
		icon:SetAttribute("PooledDynamic", true)
		corner(icon, 4)
		stroke(icon, Theme.Accent, 0.75, 1)
		local carShape = new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.fromOffset(72, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55) }, icon)
		corner(carShape, 3)
		pooledLabel(card, cockpit.DisplayName or cockpit.CockpitId, UDim2.new(1, -14, 0, 30), UDim2.fromOffset(7, 55), 9, Enum.TextXAlignment.Left)
		pooledLabel(card, "$" .. tostring(cockpit.Price or 0), UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 86), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Cash
		cockpitPool:Connect(card, card.MouseButton1Click, function()
			State.SelectedCockpit = cockpit.CockpitId
			buildPreview()
			renderCockpitShop()
		end)
	end
	categoryPool:End()
	cockpitPool:End()
	applyDealershipLayout()
end

local function toHSV(color)
	local ok, h, s, v = pcall(function() return color:ToHSV() end)
	if ok then return h, s, v end
	return Color3.toHSV(color)
end

local function syncPicker(color)
	local h, s, v = toHSV(color)
	State.Hue, State.Saturation, State.Brightness = h, s, v
end

local function pickerColor()
	return Color3.fromHSV(State.Hue, State.Saturation, State.Brightness)
end

local function makeSlider(parent, name, y, value, update)
	local short = name == "Hue" and "H" or (name == "Saturation" and "S" or (name == "Brightness" and "B" or name))
	label(parent, short, UDim2.fromOffset(18, 20), UDim2.fromOffset(0, y), 10, Enum.TextXAlignment.Left)
	local track = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.new(1, -76, 0, 15), Position = UDim2.fromOffset(26, y + 3), BorderSizePixel = 0 }, parent)
	corner(track, 5)
	stroke(track, Theme.Accent, 0.35, 1)
	local gradient = new("UIGradient", {}, track)
	local knob = new("Frame", { BackgroundColor3 = Theme.Accent, Size = UDim2.fromOffset(11, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(value, 0.5), BorderSizePixel = 0 }, track)
	corner(knob, 4)
	local valueLabel = label(parent, name == "Hue" and tostring(math.floor(value * 360)) or (tostring(math.floor(value * 100)) .. "%"), UDim2.fromOffset(46, 20), UDim2.new(1, -46, 0, y), 10, Enum.TextXAlignment.Left)
	local dragging = false
	local function setFromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		knob.Position = UDim2.fromScale(rel, 0.5)
		valueLabel.Text = name == "Hue" and tostring(math.floor(rel * 360)) or (tostring(math.floor(rel * 100)) .. "%")
		update(rel)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	local move = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	table.insert(pickerConnections, move)
	return gradient
end


local function channelTitle(channel)
	if channel == "Neon" then return "Neon" end
	if channel == "ThrustColor" then return "Thrust" end
	if channel == "FrontLights" then return "Front Lights" end
	if channel == "RearLights" then return "Rear Lights" end
	return channel
end

local function renderColourPicker(parent, channels, applyCallback)
	disconnectPickerInputs()
	clear(parent)
	channels = channels or { "Primary", "Secondary", "Detail" }
	if not table.find(channels, State.ColorChannel) then State.ColorChannel = channels[1] end

	local baseColors = State.Profile and State.Profile.CockpitColors or {}
	if State.ColorChannel == "ThrustColor" then
		baseColors = { ThrustColor = (State.Profile and State.Profile.ThrustColor) or Color3.fromRGB(255, 255, 255) }
	elseif State.Stage == "Customise" and State.CustomizeTarget and State.CustomizeTarget ~= "ALL" and State.CustomizeTarget ~= "Cockpit" and State.CustomizeTarget ~= "THRUST_COLOR" then
		local moduleColorSet = State.Profile and State.Profile.ModuleColors and State.Profile.ModuleColors[State.CustomizeTarget]
		if moduleColorSet then baseColors = moduleColorSet end
	end
	local current = baseColors[State.ColorChannel] or Color3.fromRGB(255, 255, 255)
	syncPicker(current)

	clear(UI.ColorChannelFloat)
	UI.ColorChannelFloat.Visible = true
	for _, channel in ipairs(channels) do
		local b = button(UI.ColorChannelFloat, channelTitle(channel), UDim2.fromOffset(126, 30), UDim2.fromScale(0, 0), State.ColorChannel == channel and Theme.CardHot or Theme.Card)
		b.MouseButton1Click:Connect(function()
			State.ColorChannel = channel
			renderColourPicker(parent, channels, applyCallback)
		end)
	end

	local swatchPanel = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(214, 78), Position = UDim2.fromOffset(6, 10) }, parent)
	for i, preset in ipairs((State.Catalog and State.Catalog.PaintPresets) or {}) do
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)
		local swatch = new("TextButton", { Text = "", BackgroundColor3 = preset.Color, Size = UDim2.fromOffset(35, 26), Position = UDim2.fromOffset(col * 44, row * 34), BorderSizePixel = 0 }, swatchPanel)
		corner(swatch, 4)
		stroke(swatch, Theme.Accent, 0.2, 1)
		swatch.MouseButton1Click:Connect(function()
			syncPicker(preset.Color)
			applyCallback(State.ColorChannel, preset.Color)
			renderColourPicker(parent, channels, applyCallback)
		end)
	end

	local sliderPanel = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -236, 1, -8), Position = UDim2.fromOffset(226, 5) }, parent)
	local hueGradient, satGradient, briGradient

	local function compactSlider(name, y, value, update)
		label(sliderPanel, name, UDim2.fromOffset(18, 20), UDim2.fromOffset(0, y), 10, Enum.TextXAlignment.Left)
		local track = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.new(1, -72, 0, 15), Position = UDim2.fromOffset(24, y + 3), BorderSizePixel = 0 }, sliderPanel)
		corner(track, 5)
		stroke(track, Theme.Accent, 0.35, 1)
		local gradient = new("UIGradient", {}, track)
		local knob = new("Frame", { BackgroundColor3 = Theme.Accent, Size = UDim2.fromOffset(11, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(value, 0.5), BorderSizePixel = 0 }, track)
		corner(knob, 4)
		local valueLabel = label(sliderPanel, name == "H" and tostring(math.floor(value * 360)) or (tostring(math.floor(value * 100)) .. "%"), UDim2.fromOffset(42, 20), UDim2.new(1, -42, 0, y), 10, Enum.TextXAlignment.Left)
		local dragging = false
		local function setFromX(x)
			local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			knob.Position = UDim2.fromScale(rel, 0.5)
			valueLabel.Text = name == "H" and tostring(math.floor(rel * 360)) or (tostring(math.floor(rel * 100)) .. "%")
			update(rel)
		end
		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFromX(input.Position.X)
			end
		end)
		track.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
		end)
		local move = UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFromX(input.Position.X)
			end
		end)
		table.insert(pickerConnections, move)
		return gradient
	end

	local function refreshGradients()
		if not hueGradient or not satGradient or not briGradient then return end
		hueGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
			ColorSequenceKeypoint.new(0.34, Color3.fromHSV(0.34, 1, 1)),
			ColorSequenceKeypoint.new(0.51, Color3.fromHSV(0.51, 1, 1)),
			ColorSequenceKeypoint.new(0.68, Color3.fromHSV(0.68, 1, 1)),
			ColorSequenceKeypoint.new(0.85, Color3.fromHSV(0.85, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
		})
		satGradient.Color = ColorSequence.new(Color3.fromHSV(State.Hue, 0, 1), Color3.fromHSV(State.Hue, 1, 1))
		briGradient.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromHSV(State.Hue, math.max(State.Saturation, 0.06), 1))
	end
	hueGradient = compactSlider("H", 5, State.Hue, function(v)
		State.Hue = v
		refreshGradients()
		applyCallback(State.ColorChannel, pickerColor())
	end)
	satGradient = compactSlider("S", 34, State.Saturation, function(v)
		State.Saturation = v
		refreshGradients()
		applyCallback(State.ColorChannel, pickerColor())
	end)
	briGradient = compactSlider("B", 63, State.Brightness, function(v)
		State.Brightness = v
		refreshGradients()
		applyCallback(State.ColorChannel, pickerColor())
	end)
	refreshGradients()
end


renderCockpitPaint = function()
	showTop("Paint Cockpit", "Choose primary, secondary, and detail colours.")
	UI.ColorChannelFloat.Visible = true
	State.ThrustPreviewActive = false
	renderStatsPanel()
	renderColourPicker(UI.CockpitPaintPicker, { "Primary", "Secondary", "Detail" }, function(channel, color)
		callServer("SetCockpitColor", { Channel = channel, Color = color })
		if State.Profile and State.Profile.CockpitColors then State.Profile.CockpitColors[channel] = color end
		buildPreview()
		renderStatsPanel()
	end)
end


local function renderSlotSelection()
	local slotPool = buttonPool("ModuleSlotBar", UI.ModuleSlotBar)
	slotPool:Begin()
	UI.ColorChannelFloat.Visible = false
	for _, slot in ipairs(sortedSlots()) do
		local installed = State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[slot.SlotId]
		local text = slotDisplayName(slot)
		local bg = Theme.Card
		if installed then
			text = text .. "\nequipped"
			bg = Theme.Disabled
		end
		local b = pooledButton(slotPool, text, UDim2.fromOffset(150, 72), UDim2.fromScale(0, 0), bg)
		slotPool:Connect(b, b.MouseButton1Click, function()
			clearPreviewModules()
			State.SelectedSlot = slot.SlotId
			State.ModuleMode = "Options"
			setCameraSection(slot.SlotId)
			renderModuleShop()
		end)
	end
	slotPool:End()
end

local function renderModuleOptions()
	local optionPool = buttonPool("ModuleOptions", UI.ModuleOptions)
	optionPool:Begin()
	if UI.ModulePopup then
		clear(UI.ModulePopup)
		UI.ModulePopup.Visible = false
	end
	UI.ColorChannelFloat.Visible = false
	local list = modulesForSlot(State.SelectedSlot)
	local owned = (State.Profile and State.Profile.OwnedModules) or {}
	local installed = State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[State.SelectedSlot]
	local x = 6
	for _, module in ipairs(list) do
		local isOwned = owned[module.ModuleId] == true
		local isInstalled = installed == module.ModuleId
		local card = pooledButton(optionPool, "", UDim2.fromOffset(160, 72), UDim2.fromOffset(x, 7), isInstalled and Theme.Disabled or (State.SelectedModuleId == module.ModuleId and Theme.CardHot or Theme.Card))
		card.AutoButtonColor = not isInstalled
		pooledLabel(card, module.DisplayName or module.ModuleId, UDim2.new(1, -10, 0, 30), UDim2.fromOffset(5, 12), 12, Enum.TextXAlignment.Center)
		pooledLabel(card, isOwned and (isInstalled and "equipped" or "owned") or ("$" .. tostring(module.Price or 0)), UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 41), 12, Enum.TextXAlignment.Center).TextColor3 = isOwned and Theme.Accent or Theme.Cash
		optionPool:Connect(card, card.MouseButton1Click, function()
			if isInstalled then return end
			State.SelectedModuleId = module.ModuleId
			State.PreviewModules = { [State.SelectedSlot] = module.ModuleId }
			buildPreview()
			renderModuleOptions()
		end)
		if State.SelectedModuleId == module.ModuleId and not isInstalled then
			UI.ModulePopup.Visible = true
			local popupX = math.clamp(x + 17 - UI.ModuleOptions.CanvasPosition.X, 0, math.max(0, UI.ModuleOptionsPanel.AbsoluteSize.X - 126))
			UI.ModulePopup.Position = UDim2.fromOffset(popupX, -28)
			local popup = button(UI.ModulePopup, isOwned and "Equip" or "Buy", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), isOwned and Theme.CardHot or Theme.Danger)
			popup.MouseButton1Click:Connect(function()
				local result = callServer("BuyModule", { SlotId = State.SelectedSlot, ModuleId = module.ModuleId })
				if result.Success then
					clearPreviewModules()
					State.ModuleMode = "Slots"
					buildPreview()
					renderStatsPanel()
					renderModuleShop()
				else
					UI.Subtitle.Text = result.Message or "Could not install module."
				end
			end)
		end
		x += 172
	end
	optionPool:End()
	local contentWidth = x + 6
	UI.ModuleOptions.CanvasSize = UDim2.fromOffset(math.max(contentWidth, UI.ModuleOptions.AbsoluteSize.X), 0)
	if contentWidth <= UI.ModuleOptions.AbsoluteSize.X + 2 then
		UI.ModuleOptions.CanvasPosition = Vector2.zero
	end
	renderStatsPanel()
end

renderModuleShop = function()
	showTop("Build Modules", State.ModuleMode == "Options" and "Preview, then BUY or EQUIP." or "Choose a fixed module slot.")
	setNextText("Customise Modules")
	renderStatsPanel()
	UI.ModuleSlotPanel.Visible = State.ModuleMode == "Slots"
	UI.ModuleOptionsPanel.Visible = State.ModuleMode == "Options"
	if State.ModuleMode == "Slots" then renderSlotSelection() else renderModuleOptions() end
end

local function renderCustomiseLeft()
	clear(UI.CustomiseList)
	local all = button(UI.CustomiseList, "Customise All", UDim2.new(1, 0, 0, 42), UDim2.fromScale(0, 0), State.CustomizeTarget == "ALL" and Theme.CardHot or Theme.Card)
	all.MouseButton1Click:Connect(function()
		State.CustomizeTarget = "ALL"
		State.CustomizeMode = "Colour"
		setCameraSection(nil)
		renderCustomise()
	end)

	local thrust = button(UI.CustomiseList, "Thrust Color", UDim2.new(1, 0, 0, 42), UDim2.fromScale(0, 0), State.CustomizeTarget == "THRUST_COLOR" and Theme.CardHot or Theme.Card)
	thrust.MouseButton1Click:Connect(function()
		State.CustomizeTarget = "THRUST_COLOR"
		State.CustomizeMode = "Colour"
		setCameraSection(nil)
		renderCustomise()
	end)

	local cockpit = button(UI.CustomiseList, "Cockpit", UDim2.new(1, 0, 0, 42), UDim2.fromScale(0, 0), State.CustomizeTarget == "Cockpit" and Theme.CardHot or Theme.Card)
	cockpit.MouseButton1Click:Connect(function()
		State.CustomizeTarget = "Cockpit"
		State.CustomizeMode = "Overview"
		setCameraSection(nil)
		renderCustomise()
	end)

	local installed = (State.Profile and State.Profile.InstalledModules) or {}
	for _, slot in ipairs(sortedSlots()) do
		if installed[slot.SlotId] then
			local b = button(UI.CustomiseList, slotDisplayName(slot), UDim2.new(1, 0, 0, 42), UDim2.fromScale(0, 0), State.CustomizeTarget == slot.SlotId and Theme.CardHot or Theme.Card)
			b.MouseButton1Click:Connect(function()
				State.CustomizeTarget = slot.SlotId
				State.SelectedSlot = slot.SlotId
				State.CustomizeMode = "Overview"
				setCameraSection(slot.SlotId)
				renderCustomise()
			end)
		end
	end

	for _, upgrade in ipairs({ "Brakes", "Converter", "FuelSystem" }) do
		local display = upgrade == "FuelSystem" and "Fuel System" or upgrade
		local b = button(UI.CustomiseList, display, UDim2.new(1, 0, 0, 42), UDim2.fromScale(0, 0), State.CustomizeTarget == upgrade and Theme.CardHot or Theme.Card)
		b.MouseButton1Click:Connect(function()
			State.CustomizeTarget = upgrade
			State.CustomizeMode = "Upgrade"
			setCameraSection(nil)
			renderCustomise()
		end)
	end
end


local function folderHasBuyableNeon(folder)
	if not folder then return false end
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("BasePart")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Beam")
			or descendant:IsA("Trail")
			or descendant:IsA("PointLight")
			or descendant:IsA("SpotLight")
			or descendant:IsA("SurfaceLight") then
			return true
		end
	end
	return false
end

local function templateHasChannel(template, channel)
	if not template then return false end
	if channel == "Neon" then
		return folderHasBuyableNeon(template:FindFirstChild("NEON_OptionalLights", true))
	end
	if channel == "ThrustColor" then
		return template:FindFirstChild("THRUST_COLOR_WhiteByDefault", true) ~= nil
	end
	local folderByChannel = {
		Primary = "PRIMARY_ReplaceWithPrimaryMeshes",
		Secondary = "SECONDARY_ReplaceWithSecondaryMeshes",
		Detail = "DETAIL_ReplaceWithDetailMeshes",
	}
	local folderName = folderByChannel[channel]
	if folderName and template:FindFirstChild(folderName, true) then return true end
	if channel == "FrontLights" or channel == "RearLights" then
		for _, item in ipairs(template:GetDescendants()) do
			if item:IsA("BasePart") and isChannelMatch(item, "Neon") then
				local lowerName = string.lower(item.Name)
				local parentName = item.Parent and string.lower(item.Parent.Name) or ""
				if channel == "FrontLights" and (string.find(lowerName, "front", 1, true) or string.find(parentName, "front", 1, true)) then return true end
				if channel == "RearLights" and (string.find(lowerName, "rear", 1, true) or string.find(parentName, "rear", 1, true) or string.find(lowerName, "back", 1, true) or string.find(parentName, "back", 1, true)) then return true end
			end
		end
		return false
	end
	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("BasePart") and resolvePaintChannel(descendant) == channel then return true end
	end
	return false
end

local function colourChannelsForTarget(target)
	if target == "Cockpit" then
		return { "Primary", "Secondary", "Detail", "FrontLights", "RearLights" }
	elseif target == "ALL" then
		return { "Primary", "Secondary", "Detail", "Neon" }
	elseif target == "THRUST_COLOR" then
		return { "ThrustColor" }
	end
	local installedId = State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[target]
	local template = installedId and findTemplateByAttribute(categoriesRoot, "ModuleId", installedId)
	local channels = {}
	for _, channel in ipairs({ "Primary", "Secondary", "Detail" }) do
		if not template or templateHasChannel(template, channel) then table.insert(channels, channel) end
	end
	local neonOwned = State.Profile and State.Profile.NeonOwned and State.Profile.NeonOwned[target]
	if neonOwned and templateHasChannel(template, "Neon") then table.insert(channels, "Neon") end
	if #channels == 0 then table.insert(channels, "Primary") end
	return channels
end


local function renderCosmetics()
	clear(UI.CustomiseContent)
	UI.ColorChannelFloat.Visible = false
	State.PreviewUpgradeId = nil
	local target = State.CustomizeTarget
	if target == "Cockpit" or target == "ALL" or target == "THRUST_COLOR" then
		label(UI.CustomiseContent, "No purchasable cosmetics for this target.", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(6, 10), 12, Enum.TextXAlignment.Left)
		return
	end

	local installedId = State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[target]
	local template = installedId and findTemplateByAttribute(categoriesRoot, "ModuleId", installedId)
	if not templateHasChannel(template, "Neon") then
		label(UI.CustomiseContent, "This module has no optional neon.", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(6, 10), 12, Enum.TextXAlignment.Left)
		return
	end

	local neonOwned = State.Profile and State.Profile.NeonOwned and State.Profile.NeonOwned[target]
	local card = button(UI.CustomiseContent, "", UDim2.fromOffset(170, 72), UDim2.fromOffset(6, 7), neonOwned and Theme.Disabled or Theme.Card)
	label(card, "Neon Lights", UDim2.new(1, -10, 0, 26), UDim2.fromOffset(5, 11), 11, Enum.TextXAlignment.Center)
	label(card, neonOwned and "owned" or "$5000", UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 39), 11, Enum.TextXAlignment.Center).TextColor3 = neonOwned and Theme.Accent or Theme.Cash
	if not neonOwned then
		card.MouseButton1Click:Connect(function()
			State.PreviewNeonSlot = target
			buildPreview()
			clear(UI.CosmeticPopup)
			UI.CosmeticPopup.Visible = true
			UI.CosmeticPopup.Position = UDim2.fromOffset(28, -32)
			local buy = button(UI.CosmeticPopup, "Buy", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Theme.Danger)
			buy.MouseButton1Click:Connect(function()
				local result = callServer("BuyNeon", { SlotId = target })
				UI.Subtitle.Text = result.Message or ""
				State.PreviewNeonSlot = nil
				UI.CosmeticPopup.Visible = false
				buildPreview()
				renderCustomise()
			end)
		end)
	end
end


renderCustomise = function()
	showTop("Customise", "Upgrade performance, change colours, or unlock lights.")
	setNextText("Start Driving")
	renderStatsPanel()
	renderCustomiseLeft()
	clear(UI.CustomiseContent)
	clear(UI.CustomiseColourPicker)
	UI.CosmeticPopup.Visible = false

	local target = State.CustomizeTarget
	State.ThrustPreviewActive = target == "THRUST_COLOR" and State.CustomizeMode == "Colour"
	if State.CustomizeMode ~= "Upgrade" then State.PreviewUpgradeId = nil end
	if State.CustomizeMode ~= "Cosmetics" then State.PreviewNeonSlot = nil end
	buildPreview()

	if target == "ALL" or target == "THRUST_COLOR" or State.CustomizeMode == "Colour" then
		UI.CustomiseColourPicker.Visible = true
		local channels = colourChannelsForTarget(target)
		renderColourPicker(UI.CustomiseColourPicker, channels, function(channel, color)
			if target == "THRUST_COLOR" or channel == "ThrustColor" then
				if State.Profile then State.Profile.ThrustColor = color end
				callServer("SetThrustColor", { Color = color })
				local previewRootObject = Preview.Root or Workspace:FindFirstChild("HOVER_RACING_V2_LOCAL_PREVIEW")
				if previewRootObject then
					previewRootObject:SetAttribute("ThrustColor", color)
					previewRootObject:SetAttribute("ForceThrustPreview", true)
				end
			elseif target == "ALL" then
				callServer("SetModuleColor", { SlotId = "ALL", Channel = channel, Color = color })
				if channel ~= "Neon" then callServer("SetCockpitColor", { Channel = channel, Color = color }) end
			elseif target == "Cockpit" then
				callServer("SetCockpitColor", { Channel = channel, Color = color })
				if State.Profile and State.Profile.CockpitColors then State.Profile.CockpitColors[channel] = color end
			else
				callServer("SetModuleColor", { SlotId = target, Channel = channel, Color = color })
				if State.Profile and State.Profile.ModuleColors then
					State.Profile.ModuleColors[target] = State.Profile.ModuleColors[target] or {}
					State.Profile.ModuleColors[target][channel] = color
				end
			end
			buildPreview()
			renderStatsPanel()
		end)
		return
	end

	UI.CustomiseColourPicker.Visible = false
	UI.ColorChannelFloat.Visible = false
	if target == "Brakes" or target == "Converter" or target == "FuelSystem" then
		local levels = (State.Profile and State.Profile.UpgradeLevels) or {}
		local level = levels[target] or 0
		local upgradeInfo = getUpgrade(target) or {}
		local price = (upgradeInfo.PricePerLevel or 0) * (level + 1)
		local upgrade = button(UI.CustomiseContent, "UPGRADE (LVL " .. tostring(level + 1) .. ")", UDim2.fromOffset(190, 72), UDim2.fromOffset(6, 8), Theme.Buy)
		label(upgrade, "$" .. tostring(price), UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 46), 11, Enum.TextXAlignment.Center).TextColor3 = Theme.Cash
		upgrade.MouseButton1Click:Connect(function()
			State.PreviewUpgradeId = target
			renderStatsPanel()
			clear(UI.CosmeticPopup)
			UI.CosmeticPopup.Visible = true
			UI.CosmeticPopup.Position = UDim2.fromOffset(34, -32)
			local buy = button(UI.CosmeticPopup, "Buy", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Theme.Danger)
			buy.MouseButton1Click:Connect(function()
				local result = callServer("Upgrade", { UpgradeId = target })
				UI.Subtitle.Text = result.Message or ""
				State.PreviewUpgradeId = nil
				UI.CosmeticPopup.Visible = false
				renderStatsPanel()
				renderCustomise()
				buildPreview()
			end)
		end)
		return
	end

	if State.CustomizeMode == "Cosmetics" then
		renderCosmetics()
		return
	end

	local colour = button(UI.CustomiseContent, target == "Cockpit" and "Change Colour" or "Colour", UDim2.fromOffset(170, 72), UDim2.fromOffset(6, 8), Theme.Card)
	colour.MouseButton1Click:Connect(function()
		State.CustomizeMode = "Colour"
		renderCustomise()
	end)
	if target ~= "Cockpit" then
		local cosmetics = button(UI.CustomiseContent, "Cosmetics", UDim2.fromOffset(170, 72), UDim2.fromOffset(188, 8), Theme.Card)
		local upgrade = button(UI.CustomiseContent, "UPGRADE (LVL 1)", UDim2.fromOffset(190, 72), UDim2.fromOffset(370, 8), Theme.Buy)
		cosmetics.MouseButton1Click:Connect(function()
			State.CustomizeMode = "Cosmetics"
			renderCustomise()
		end)
		upgrade.MouseButton1Click:Connect(function()
			State.PreviewUpgradeId = target
			renderStatsPanel()
			clear(UI.CosmeticPopup)
			UI.CosmeticPopup.Visible = true
			UI.CosmeticPopup.Position = UDim2.fromOffset(396, -32)
			local buy = button(UI.CosmeticPopup, "Buy", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Theme.Danger)
			buy.MouseButton1Click:Connect(function()
				UI.Subtitle.Text = "Visible module upgrades are ready to expand with per-module upgrade rules."
				State.PreviewUpgradeId = nil
				UI.CosmeticPopup.Visible = false
			end)
		end)
	end
end


local function getHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function blockJumpAction()
	return Enum.ContextActionResult.Sink
end

local function setJumpLocked(locked)
	local humanoid = getHumanoid()
	if not humanoid then return end
	if locked then
		if savedJumpPower == nil then
			savedJumpPower = humanoid.JumpPower
			savedJumpHeight = humanoid.JumpHeight
			savedAutoJump = humanoid.AutoJumpEnabled
			savedJumpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
		end
		humanoid.Jump = false
		humanoid.AutoJumpEnabled = false
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		ContextActionService:BindActionAtPriority("HOVER_RACING_V2_BlockJumpWhileDriving", blockJumpAction, false, 4000, Enum.KeyCode.Space)
	else
		ContextActionService:UnbindAction("HOVER_RACING_V2_BlockJumpWhileDriving")
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, savedJumpEnabled ~= false)
		humanoid.JumpPower = savedJumpPower or 50
		humanoid.JumpHeight = savedJumpHeight or 7.2
		humanoid.AutoJumpEnabled = savedAutoJump ~= false
		humanoid.Jump = false
		savedJumpPower, savedJumpHeight, savedAutoJump, savedJumpEnabled = nil, nil, nil, nil
	end
end

local function getPlayerVehicle()
	for _, vehicle in ipairs(vehiclesRoot:GetChildren()) do
		if vehicle:GetAttribute("OwnerUserId") == player.UserId then return vehicle end
	end
end

local function waitForPlayerVehicle(timeout)
	local start = os.clock()
	repeat
		local vehicle = getPlayerVehicle()
		if vehicle and vehicle.Parent and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)) then
			local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
			vehicle.PrimaryPart = root
			return vehicle
		end
		task.wait(0.05)
	until os.clock() - start > (timeout or 5)
end

local function getStat(name, fallback)
	if cachedDriveStats and cachedDriveStats[name] ~= nil then
		return cachedDriveStats[name]
	end
	if not currentVehicle then return fallback end
	local value = currentVehicle:GetAttribute(name)
	if typeof(value) == "number" then return value end
	local statsFolder = currentVehicle:FindFirstChild("TOTAL_STATS_Runtime")
	local number = statsFolder and statsFolder:FindFirstChild(name)
	if number and number:IsA("NumberValue") then return number.Value end
	return fallback
end

local function cleanupDriveForces(root)
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("VectorForce") or child:IsA("AlignOrientation") or child:IsA("AngularVelocity") or string.find(child.Name, "Drive_", 1, true) or string.find(child.Name, "ClientHover", 1, true) then
			child:Destroy()
		end
	end
end

local function makeAttachment(parent, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position or Vector3.zero
	attachment.Parent = parent
	return attachment
end

local function setupControls(vehicle)
	local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
	if not root then return nil end
	vehicle.PrimaryPart = root
	cleanupDriveForces(root)

	local centerAttachment = makeAttachment(root, "Drive_CenterAttachment", Vector3.zero)
	local driveForce = Instance.new("VectorForce")
	driveForce.Name = "Drive_ForwardForce"
	driveForce.Attachment0 = centerAttachment
	driveForce.ApplyAtCenterOfMass = true
	driveForce.RelativeTo = Enum.ActuatorRelativeTo.World
	driveForce.Parent = root

	local align = Instance.new("AlignOrientation")
	align.Name = "Drive_TerrainYawAlign"
	align.Attachment0 = centerAttachment
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.MaxTorque = math.huge
	align.MaxAngularVelocity = math.huge
	align.Responsiveness = 22
	align.RigidityEnabled = false
	align.Parent = root

	local halfX = math.max(root.Size.X * 0.5, 4)
	local halfZ = math.max(root.Size.Z * 0.5, 6)
	local offsets = {
		Vector3.new(-halfX, 0, -halfZ),
		Vector3.new(halfX, 0, -halfZ),
		Vector3.new(-halfX, 0, halfZ),
		Vector3.new(halfX, 0, halfZ),
	}
	local corners = {}
	for index, offset in ipairs(offsets) do
		local attachment = makeAttachment(root, "Drive_HoverCornerAttachment" .. index, offset)
		local force = Instance.new("VectorForce")
		force.Name = "Drive_HoverCornerForce" .. index
		force.Attachment0 = attachment
		force.ApplyAtCenterOfMass = false
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.Parent = root
		corners[index] = { Offset = offset, Force = force }
	end
	return { Root = root, DriveForce = driveForce, Align = align, Corners = corners }
end

local function getTerrainFrame(root, hitPositions, normalSum, hits)
	local normal = hits > 0 and normalSum.Magnitude > 0.01 and normalSum.Unit or Vector3.new(0, 1, 0)
	local fl, fr, rl, rr = hitPositions[1], hitPositions[2], hitPositions[3], hitPositions[4]
	if fl and fr and rl and rr then
		local frontMid = (fl + fr) * 0.5
		local rearMid = (rl + rr) * 0.5
		local leftMid = (fl + rl) * 0.5
		local rightMid = (fr + rr) * 0.5
		local slopeForward = frontMid - rearMid
		local slopeRight = rightMid - leftMid
		if slopeForward.Magnitude > 0.05 and slopeRight.Magnitude > 0.05 then
			local planeNormal = slopeRight.Unit:Cross(slopeForward.Unit)
			if planeNormal.Y < 0 then planeNormal = -planeNormal end
			normal = planeNormal.Unit
		end
	end
	local desiredFlatForward = Vector3.new(math.sin(yawHeading), 0, math.cos(yawHeading))
	local terrainForward = desiredFlatForward - normal * desiredFlatForward:Dot(normal)
	if terrainForward.Magnitude < 0.05 then terrainForward = root.CFrame.LookVector else terrainForward = terrainForward.Unit end
	return terrainForward, normal
end

local function resetMobileDriveControls()
	mobileThrottle = 0
	mobileSteer = 0
	mobileBoostHeld = false
	if mobileDriftActive then
		mobileDriftActive = false
		driftHeld = false
	end
	local M = mobileControls
	if not M then return end
	M.State = { Accelerate = false, Brake = false, TurnLeft = false, TurnRight = false, DriftLeft = false, DriftRight = false, Boost = false }
	for _, b in ipairs(M.Buttons or {}) do
		b.BackgroundTransparency = Theme.ButtonTransparency or 0.08
		local s = b:FindFirstChildOfClass("UIStroke")
		if s then s.Transparency = 0.18 end
	end
	if M.Root then M.Root.Visible = false end
end

local function refreshMobileInput()
	local M = mobileControls
	if not M then return end
	local st = M.State
	mobileThrottle = math.clamp((st.Accelerate and 1 or 0) - (st.Brake and 1 or 0), -1, 1)
	mobileSteer = math.clamp(((st.TurnRight or st.DriftRight) and 1 or 0) - ((st.TurnLeft or st.DriftLeft) and 1 or 0), -1, 1)
	mobileBoostHeld = st.Boost == true
	local shouldDrift = st.DriftLeft or st.DriftRight
	if shouldDrift and not mobileDriftActive then
		mobileDriftActive = true
		driftHeld = true
	elseif not shouldDrift and mobileDriftActive then
		mobileDriftActive = false
		driftHeld = false
		if driftCharge > 0.75 then miniBoostTimer = math.clamp(driftCharge * 0.4, 0.25, 1) end
		driftCharge = 0
	end
end

local function setMobileAction(actionName, active)
	local M = mobileControls
	if not M or not M.State then return end
	M.State[actionName] = active == true
	refreshMobileInput()
end

local function setMobileButtonVisual(buttonObject, active)
	if not buttonObject then return end
	buttonObject.BackgroundTransparency = active and 0 or 0.08
	local s = buttonObject:FindFirstChildOfClass("UIStroke")
	if s then s.Transparency = active and 0 or 0.18 end
end

local function bindMobileButton(buttonObject, actionName)
	buttonObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setMobileButtonVisual(buttonObject, true)
			setMobileAction(actionName, true)
		end
	end)
	buttonObject.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setMobileButtonVisual(buttonObject, false)
			setMobileAction(actionName, false)
		end
	end)
end

local function makeMobileButton(parent, name, text, isPedal)
	local b = button(parent, text, UDim2.fromOffset(72, 64), UDim2.fromScale(0, 0), isPedal and Theme.Buy or Theme.Card)
	b.Name = name
	b.AutoButtonColor = false
	b.TextSize = isPedal and 11 or 22
	table.insert(mobileControls.Buttons, b)
	if isPedal then
		local pad = new("Frame", { BackgroundColor3 = Theme.PanelSoft, BackgroundTransparency = Theme.ButtonTransparency or 0.08, BorderSizePixel = 0, Position = UDim2.fromScale(0.16, 0.12), Size = UDim2.fromScale(0.68, 0.58) }, b)
		corner(pad, 9)
		stroke(pad, Theme.Accent, Theme.ButtonStrokeTransparency, Theme.StrokeWidth)
		for i = 1, 4 do
			local rib = new("Frame", { BackgroundColor3 = Theme.Text, BackgroundTransparency = 0.48, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.12 + i * 0.14), Size = UDim2.fromScale(0.66, 0.05) }, pad)
			corner(rib, 4)
		end
	end
	return b
end

local function layoutMobileDriveControls()
	local M = mobileControls
	if not M or not camera then return end
	local viewport = camera.ViewportSize
	local width, height = viewport.X, viewport.Y
	local tiny = width < 740
	local margin = tiny and 18 or 28
	local gap = tiny and 7 or 9
	local arrow = tiny and 50 or 58
	local boostW = arrow * 2 + gap
	local boostH = tiny and 44 or 50
	local pedalH = tiny and 96 or 112
	local accelW = tiny and 70 or 82
	local brakeW = tiny and 58 or 68
	local leftW = arrow * 4 + gap * 3
	local leftH = boostH + gap + arrow

	M.Root.Size = UDim2.fromScale(1, 1)
	M.Left.Position = UDim2.fromOffset(margin, height - margin - leftH)
	M.Left.Size = UDim2.fromOffset(leftW, leftH)
	M.Mph.Position = UDim2.fromOffset(0, -27)
	M.Mph.Size = UDim2.fromOffset(leftW, 24)
	M.BoostButton.Position = UDim2.fromOffset(math.floor((leftW - boostW) * 0.5), 0)
	M.BoostButton.Size = UDim2.fromOffset(boostW, boostH)
	M.BoostFill.Size = UDim2.fromScale(math.clamp(boost / 100, 0, 1), 1)
	for i, b in ipairs({ M.DriftLeft, M.TurnLeft, M.TurnRight, M.DriftRight }) do
		b.Position = UDim2.fromOffset((i - 1) * (arrow + gap), boostH + gap)
		b.Size = UDim2.fromOffset(arrow, arrow)
	end

	M.Right.Size = UDim2.fromOffset(accelW + gap + brakeW, pedalH)
	M.Right.Position = UDim2.fromOffset(width - margin - (accelW + gap + brakeW), height - margin - pedalH)
	M.Brake.Position = UDim2.fromOffset(0, pedalH * 0.18)
	M.Brake.Size = UDim2.fromOffset(brakeW, pedalH * 0.82)
	M.Accelerator.Position = UDim2.fromOffset(brakeW + gap, 0)
	M.Accelerator.Size = UDim2.fromOffset(accelW, pedalH)
end

local function updateMobileDriveControls()
	local M = mobileControls
	if not M then return end
	local show = UserInputService.TouchEnabled and isDriving and driveGui and driveGui.Enabled
	M.Root.Visible = show
	if driveHud then driveHud.Visible = not show end
	if show then
		layoutMobileDriveControls()
		M.Mph.Text = mphLabel and mphLabel.Text or "0 MPH"
		M.BoostFill.Size = UDim2.fromScale(math.clamp(boost / 100, 0, 1), 1)
	else
		resetMobileDriveControls()
	end
end

local function ensureMobileDriveControls()
	if mobileControls and mobileControls.Root and mobileControls.Root.Parent then return end
	mobileControls = { State = {}, Buttons = {} }
	local M = mobileControls
	M.Root = new("Frame", { Name = "MobileDriveControls", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false }, driveGui)
	M.Left = new("Frame", { Name = "SteerBoostPanel", BackgroundTransparency = 1, BorderSizePixel = 0 }, M.Root)
	M.Right = new("Frame", { Name = "PedalPanel", BackgroundTransparency = 1, BorderSizePixel = 0 }, M.Root)
	M.Mph = label(M.Left, "0 MPH", UDim2.fromOffset(200, 24), UDim2.fromOffset(0, -27), 16, Enum.TextXAlignment.Center)
	M.BoostButton = makeMobileButton(M.Left, "BoostButton", "BOOST", false)
	M.BoostFill = new("Frame", { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.52, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = M.BoostButton.ZIndex + 1 }, M.BoostButton)
	corner(M.BoostFill, 4)
	M.DriftLeft = makeMobileButton(M.Left, "DriftLeftButton", "<<", false)
	M.TurnLeft = makeMobileButton(M.Left, "TurnLeftButton", "<", false)
	M.TurnRight = makeMobileButton(M.Left, "TurnRightButton", ">", false)
	M.DriftRight = makeMobileButton(M.Left, "DriftRightButton", ">>", false)
	M.Brake = makeMobileButton(M.Right, "BrakePedal", "", true)
	M.Accelerator = makeMobileButton(M.Right, "AcceleratorPedal", "ACCEL", true)
	bindMobileButton(M.Accelerator, "Accelerate")
	bindMobileButton(M.Brake, "Brake")
	bindMobileButton(M.TurnLeft, "TurnLeft")
	bindMobileButton(M.TurnRight, "TurnRight")
	bindMobileButton(M.DriftLeft, "DriftLeft")
	bindMobileButton(M.DriftRight, "DriftRight")
	bindMobileButton(M.BoostButton, "Boost")
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutMobileDriveControls) end
	layoutMobileDriveControls()
end

local function ensureDriveHud()
	if driveGui and driveGui.Parent then return end
	driveGui = new("ScreenGui", { Name = "HOVER_RACING_V2_DriveHUD", ResetOnSpawn = false, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))
	driveHud = panel(driveGui, "DriveHUD", UDim2.fromOffset(250, 86), UDim2.new(0, 18, 1, -22), Vector2.new(0, 1))
	mphLabel = label(driveHud, "0 MPH", UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 8), 15, Enum.TextXAlignment.Left)
	local boostBack = new("Frame", { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 14), BackgroundColor3 = Color3.fromRGB(25, 32, 30), BorderSizePixel = 0 }, driveHud)
	corner(boostBack, 5)
	boostFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 }, boostBack)
	corner(boostFill, 5)
	driftLabel = label(driveHud, "SHIFT drift | SPACE boost | R reset", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 59), 10, Enum.TextXAlignment.Left)

	driveMenu = panel(driveGui, "DriveMenu", UDim2.fromOffset(96, 48), UDim2.new(1, -18, 0, 74), Vector2.new(1, 0))
	local exit = button(driveMenu, "Exit", UDim2.new(1, -12, 1, -12), UDim2.fromOffset(6, 6), Theme.Danger)
	exit.MouseButton1Click:Connect(function()
		callServer("ExitVehicle", {})
		stopDriving()
		local humanoid = getHumanoid()
		if humanoid then humanoid.Sit = false end
		if camera then camera.CameraType = Enum.CameraType.Custom end
	end)
	ensureMobileDriveControls()
end

local function refreshPolledInput()
	throttle = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then throttle += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then throttle -= 1 end
	throttle = math.clamp(throttle + gamepadAccel - gamepadBrake + mobileThrottle, -1, 1)
	steer = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then steer -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then steer += 1 end
	steer = math.clamp(steer + gamepadSteer + mobileSteer, -1, 1)
end

function stopDriving()
	isDriving = false
	if driveConnection then driveConnection:Disconnect(); driveConnection = nil end
	if controls and controls.Root then cleanupDriveForces(controls.Root) end
	if vehicleVFX then vehicleVFX:Destroy(); vehicleVFX = nil end
	controls = nil
	currentVehicle = nil
	cachedDriveStats = nil
	setJumpLocked(false)
	resetMobileDriveControls()
	if driveGui then driveGui.Enabled = false end
end

-- V57_DRIVE_START_FAILSAFE_BEGIN
local function V57_driveVehiclesRoot()
	local world = game:GetService("Workspace"):FindFirstChild("HOVER_RACING_V2_WORLD")
	return world and world:FindFirstChild("PLAYER_VEHICLES_Runtime")
end

local function V57_playerVehicle()
	local localPlayer = player or game:GetService("Players").LocalPlayer
	local root = V57_driveVehiclesRoot()
	if not root or not localPlayer then return nil end
	for _, vehicle in ipairs(root:GetChildren()) do
		if vehicle:GetAttribute("OwnerUserId") == localPlayer.UserId then
			local primary = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
			if primary then
				vehicle.PrimaryPart = primary
				return vehicle
			end
		end
	end
	return nil
end

local function V57_waitForPlayerVehicle(timeout)
	local startTime = os.clock()
	repeat
		local vehicle = V57_playerVehicle()
		if vehicle and vehicle.PrimaryPart then return vehicle end
		task.wait(0.05)
	until os.clock() - startTime > (timeout or 6)
	return nil
end

local function V57_driveNumber(vehicle, name, fallback)
	if not vehicle then return fallback end
	local attr = vehicle:GetAttribute(name)
	if typeof(attr) == "number" then return attr end
	local statsFolder = vehicle:FindFirstChild("TOTAL_STATS_Runtime")
	local value = statsFolder and statsFolder:FindFirstChild(name)
	if value and value:IsA("NumberValue") then return value.Value end
	return fallback
end

local function V57_snapshotDriveStats(vehicle)
	local module = nil
	if typeof(V22Modules) == "table" then
		module = V22Modules.VehicleStatsCache
	end
	if typeof(module) == "table" and typeof(module.Snapshot) == "function" then
		local ok, result = pcall(module.Snapshot, vehicle)
		if ok and typeof(result) == "table" then
			return result
		end
		warn("[V57] VehicleStatsCache.Snapshot failed; using local drive stat fallback.")
	end

	local stats = {
		TopSpeed = V57_driveNumber(vehicle, "TopSpeed", 126),
		Acceleration = V57_driveNumber(vehicle, "Acceleration", 42),
		Braking = V57_driveNumber(vehicle, "Braking", 44),
		Handling = V57_driveNumber(vehicle, "Handling", 48),
		Drift = V57_driveNumber(vehicle, "Drift", 46),
		Boost = V57_driveNumber(vehicle, "Boost", 0),
		BoostDuration = V57_driveNumber(vehicle, "BoostDuration", 2),
		BoostRecharge = V57_driveNumber(vehicle, "BoostRecharge", 9),
		Weight = V57_driveNumber(vehicle, "Weight", 118),
	}
	local weight = math.clamp(stats.Weight, 60, 260)
	stats.Weight = weight
	stats.MaxMph = math.clamp(stats.TopSpeed, 40, 260)
	stats.AccelerationWeighted = math.max(stats.Acceleration, 8) * math.clamp(118 / weight, 0.58, 1.25)
	stats.HandlingWeighted = math.max(stats.Handling, 10) * math.clamp(125 / weight, 0.62, 1.22)
	stats.DriftWeighted = math.max(stats.Drift, 10) * math.clamp(122 / weight, 0.65, 1.2)
	stats.BrakingWeighted = math.max(stats.Braking, 16) * math.clamp(115 / weight, 0.68, 1.15)
	stats.BoostPower = math.max(stats.Boost, 0)
	stats.BoostDuration = math.max(stats.BoostDuration, 1)
	stats.BoostRecharge = math.max(stats.BoostRecharge, 4)
	return stats
end

local function V57_optionalCall(fn, ...)
	if typeof(fn) ~= "function" then return nil end
	local ok, result = pcall(fn, ...)
	if not ok then
		warn("[V57] Optional driving helper failed: " .. tostring(result))
	end
	return result
end

local function V57_refreshDrivingCamera(vehicle)
	if not camera then return end
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	camera.CameraType = Enum.CameraType.Custom
	if seat and seat:IsA("VehicleSeat") then
		camera.CameraSubject = seat
	else
		local humanoid = nil
		if typeof(getHumanoid) == "function" then
			humanoid = getHumanoid()
		else
			local character = (player or game:GetService("Players").LocalPlayer).Character
			humanoid = character and character:FindFirstChildOfClass("Humanoid")
		end
		if humanoid then camera.CameraSubject = humanoid end
	end
end
-- V57_DRIVE_START_FAILSAFE_END

local function startDriving()
	State.GarageCameraActive = false
	if UI.Gui then UI.Gui.Enabled = false end
	if Preview.Root then
		Preview.Root:Destroy()
		Preview.Root = nil
		Preview.Vehicle = nil
	end
	if camera then camera.CameraType = Enum.CameraType.Custom end
	currentVehicle = V57_waitForPlayerVehicle(6)
	if not currentVehicle or not currentVehicle.PrimaryPart then
		warn("V22 driving could not find the spawned V2 vehicle.")
		return
	end
	cachedDriveStats = V57_snapshotDriveStats(currentVehicle)
	isDriving = true
	local seatEarly = currentVehicle:FindFirstChild("DriverSeat", true)
	if camera and seatEarly and seatEarly:IsA("VehicleSeat") then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = seatEarly
	end
	setJumpLocked(true)
	ensureDriveHud()
	driveGui.Enabled = true
	-- V52_DrivingCameraSubject
	if camera then
		local seat = currentVehicle and currentVehicle:FindFirstChild("DriverSeat", true)
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = (seat and seat:IsA("VehicleSeat") and seat) or (typeof(getHumanoid) == "function" and getHumanoid())
	end
	V57_optionalCall(updateMobileDriveControls)()
	boost = 100
	driftCharge = 0
	driftBlend = 0
	miniBoostTimer = 0
	currentBank = 0

	local root = currentVehicle.PrimaryPart
	local look = root.CFrame.LookVector
	yawHeading = math.atan2(look.X, look.Z)
	controls = setupControls(currentVehicle)
	if not controls then return end
	if vehicleVFX then vehicleVFX:Destroy() end
	local vfxModule = (typeof(V22Modules) == "table" and V22Modules.VehicleVFXController) or VehicleVFXController
	vehicleVFX = vfxModule.Attach(currentVehicle, kit:WaitForChild("VFX_TEMPLATES"), UserInputService.TouchEnabled)

	rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { currentVehicle, player.Character }
	if driveConnection then driveConnection:Disconnect() end
	driveConnection = RunService.Heartbeat:Connect(function(dt)
		if not currentVehicle or not currentVehicle.Parent or not currentVehicle.PrimaryPart or not controls then stopDriving(); return end
		local humanoid = getHumanoid()
		if humanoid then humanoid.Jump = false end
		refreshPolledInput()
		root = currentVehicle.PrimaryPart
		local mass = math.max(root.AssemblyMass, 1)
		local velocity = root.AssemblyLinearVelocity
		local forward = root.CFrame.LookVector
		local right = root.CFrame.RightVector
		local speedMph = velocity.Magnitude * MPH_PER_STUD
		local forwardSpeed = velocity:Dot(forward)
		local sideSpeed = velocity:Dot(right)

		local stats = cachedDriveStats or V57_snapshotDriveStats(currentVehicle)
		cachedDriveStats = stats
		local maxMph = stats.MaxMph
		local acceleration = stats.AccelerationWeighted
		local braking = stats.BrakingWeighted
		local handling = stats.HandlingWeighted
		local driftControl = stats.DriftWeighted
		local boostPower = stats.BoostPower
		local boostDuration = stats.BoostDuration
		local boostRecharge = stats.BoostRecharge

		local maxForwardStuds = maxMph / MPH_PER_STUD
		local maxReverseStuds = REVERSE_MAX_MPH / MPH_PER_STUD
		local hitPositions = {}
		local normalSum = Vector3.zero
		local hits = 0
		local liftPerCorner = mass * Workspace.Gravity / 4
		for index, cornerData in ipairs(controls.Corners) do
			local origin = root.CFrame:PointToWorldSpace(cornerData.Offset) + Vector3.new(0, SENSOR_START_HEIGHT, 0)
			local result = Workspace:Raycast(origin, Vector3.new(0, -SENSOR_LENGTH, 0), rayParams)
			if result then
				local targetDistance = HOVER_HEIGHT + SENSOR_START_HEIGHT
				local heightError = targetDistance - result.Distance
				local pointVelocityY = root:GetVelocityAtPosition(origin).Y
				local forceAmount = liftPerCorner + mass * (heightError * 48 - pointVelocityY * 6)
				cornerData.Force.Force = Vector3.new(0, math.clamp(forceAmount, 0, liftPerCorner * 4.25), 0)
				hitPositions[index] = result.Position
				normalSum += result.Normal
				hits += 1
			else
				cornerData.Force.Force = Vector3.new(0, liftPerCorner * 0.05, 0)
			end
		end

		local terrainForward, groundNormal = getTerrainFrame(root, hitPositions, normalSum, hits)
		local grounded = hits >= 2
		local steeringInput = steer
		if forwardSpeed < -4 then steeringInput = -steer end
		local canDrift = driftHeld and forwardSpeed > 8 and speedMph > 10 and math.abs(steeringInput) > 0 and grounded
		driftBlend += ((canDrift and 1 or 0) - driftBlend) * math.clamp(dt * 5, 0, 1)
		local drifting = driftBlend > 0.12

		local driveForce = Vector3.zero
		if throttle > 0 and forwardSpeed < maxForwardStuds then
			local speedLimiter = math.clamp(1 - (math.max(forwardSpeed, 0) / maxForwardStuds), 0.08, 1)
			driveForce += forward * mass * acceleration * 3.1 * speedLimiter
		elseif throttle < 0 and forwardSpeed > -maxReverseStuds then
			local reverseLimiter = math.clamp(1 - (math.abs(math.min(forwardSpeed, 0)) / maxReverseStuds), 0.08, 1)
			driveForce -= forward * mass * braking * 1.1 * reverseLimiter
		end
		if forwardSpeed > maxForwardStuds then
			driveForce -= forward * mass * (forwardSpeed - maxForwardStuds) * 8
		elseif forwardSpeed < -maxReverseStuds then
			local lateralVelocity = velocity - forward * forwardSpeed
			root.AssemblyLinearVelocity = lateralVelocity - forward * maxReverseStuds
			driveForce += forward * mass * (math.abs(forwardSpeed) - maxReverseStuds) * 12
		end
		local lateralGrip = 6.6 + (1.25 - 6.6) * driftBlend
		driveForce += -right * sideSpeed * mass * lateralGrip
		driveForce += -velocity * mass * 0.16
		if drifting then
			driveForce += right * (-steeringInput) * mass * 26 * driftBlend
			driftCharge = math.min(3, driftCharge + dt * (0.75 + math.abs(steeringInput)) * driftBlend)
		end
		local boostHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space) or gamepadBoostHeld or mobileBoostHeld
		if boostHeld and boost > 1 and forwardSpeed > -4 and boostPower > 0 then
			boost = math.max(0, boost - (100 / boostDuration) * dt)
			driveForce += forward * mass * (boostPower + 32) * 0.75
		elseif miniBoostTimer > 0 then
			miniBoostTimer = math.max(0, miniBoostTimer - dt)
			driveForce += forward * mass * 42 * 0.75
		else
			boost = math.min(100, boost + (100 / boostRecharge) * dt)
		end
		if vehicleVFX then
			vehicleVFX:Update(dt, {
				Throttle = math.clamp(throttle, 0, 1),
				Boost = (boostHeld and boostPower > 0 and boost > 0) and 1 or 0,
				Drift = driftBlend,
				HoverDust = grounded and math.clamp(0.18 + speedMph / 95, 0, 1) or 0,
				Brake = throttle < -0.2 and math.clamp(speedMph / 80, 0, 1) or 0,
			})
		end
		controls.DriveForce.Force = driveForce
		local speedFactor = math.clamp(math.abs(forwardSpeed) * MPH_PER_STUD / 45, 0.35, 1.35)
		local turnRate = (handling / 58) * 1.08 * speedFactor
		if drifting then turnRate *= 1.18 + (driftControl / 220) end
		yawHeading += -steeringInput * turnRate * dt
		local bankInput = forwardSpeed < -4 and -steeringInput or steeringInput
		local targetBank = math.rad(math.clamp(-bankInput * 12, -12, 12))
		if drifting then targetBank += math.rad(math.clamp(-bankInput * 5, -5, 5)) * driftBlend end
		currentBank += (targetBank - currentBank) * math.clamp(dt * 3.2, 0, 1)
		terrainForward, groundNormal = getTerrainFrame(root, hitPositions, normalSum, hits)
		controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal) * CFrame.Angles(0, 0, currentBank)

		local seat = currentVehicle:FindFirstChild("DriverSeat", true)
		if camera and seat and seat:IsA("VehicleSeat") then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = seat
		end
		if root.Position.Y < -50 then
			root.CFrame = CFrame.new(860, 106, -1713)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		if mphLabel then mphLabel.Text = tostring(math.floor(speedMph + 0.5)) .. " MPH" end
		if boostFill then boostFill.Size = UDim2.fromScale(math.clamp(boost / 100, 0, 1), 1) end
		updateMobileDriveControls()
		if driftLabel then
			if drifting then driftLabel.Text = driftCharge > 1.4 and "DRIFT CHARGED" or "DRIFT"
			elseif miniBoostTimer > 0 then driftLabel.Text = "MINI BOOST"
			else driftLabel.Text = "SHIFT drift | SPACE boost | R reset" end
		end
	end)
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if not reentryProbe:ShouldRun(now) then return end
	if isDriving or now < reentryCooldown then return end
	if UI.Gui and UI.Gui.Enabled then return end
	local character = player.Character
	local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoidRoot or not humanoid or humanoid.Sit then return end
	local vehicle = getPlayerVehicle()
	local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	local targetPart = (seat and seat:IsA("BasePart")) and seat or root
	if not targetPart then return end
	if (humanoidRoot.Position - targetPart.Position).Magnitude <= 6.5 then
		reentryCooldown = now + 1.25
		reentryProbe:Cooldown(1.25)
		local result = callServer("ReEnterVehicle", {})
		if result.Success then
			task.defer(startDriving)
		end
	end
end)

local function closeGarage()
	State.GarageCameraActive = false
	if Preview.Root then
		Preview.Root:Destroy()
		Preview.Root = nil
		Preview.Vehicle = nil
	end
	if UI.Gui then UI.Gui.Enabled = false end
	disconnectPickerInputs()
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local vehicle = getPlayerVehicle()
		local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
		local humanoid = getHumanoid()
		if seat and seat:IsA("VehicleSeat") then
			camera.CameraSubject = seat
		elseif humanoid then
			camera.CameraSubject = humanoid
		end
	end
end


local function handleDriftAction(_, inputState)
	if not isDriving then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then
		driftHeld = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		driftHeld = false
		if driftCharge > 0.75 then miniBoostTimer = math.clamp(driftCharge * 0.4, 0.25, 1) end
		driftCharge = 0
	end
	return Enum.ContextActionResult.Sink
end

local function handleBoostAction(_, inputState)
	if not isDriving then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then gamepadBoostHeld = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then gamepadBoostHeld = false end
	return Enum.ContextActionResult.Sink
end

local function handleResetAction(_, inputState)
	if not isDriving then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin and currentVehicle and currentVehicle.PrimaryPart then
		local root = currentVehicle.PrimaryPart
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 5, 0), root.Position + Vector3.new(math.sin(yawHeading), 5, math.cos(yawHeading)))
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority("HOVER_RACING_V2_Drift", handleDriftAction, false, 6000, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonB)
ContextActionService:BindActionAtPriority("HOVER_RACING_V2_Boost", handleBoostAction, false, 6000, Enum.KeyCode.ButtonA)
ContextActionService:BindActionAtPriority("HOVER_RACING_V2_Reset", handleResetAction, false, 6000, Enum.KeyCode.R, Enum.KeyCode.ButtonY)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Gamepad1 then
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then gamepadSteer = math.abs(input.Position.X) > 0.12 and input.Position.X or 0
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then gamepadAccel = math.clamp(input.Position.Z, 0, 1)
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then gamepadBrake = math.clamp(input.Position.Z, 0, 1) end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Gamepad1 then
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then gamepadSteer = 0
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then gamepadAccel = 0
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then gamepadBrake = 0
		elseif input.KeyCode == Enum.KeyCode.ButtonA then gamepadBoostHeld = false end
	end
end)

local function setupUI()
	local old = player.PlayerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	if old then old:Destroy() end
	local gui = new("ScreenGui", { Name = "HOVER_RACING_V2_GarageUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player.PlayerGui)
	UI.Gui = gui
	UI.Scale = new("UIScale", { Scale = 1 }, gui)

	UI.Top = panel(gui, "TopHUD", UDim2.fromOffset(520, 78), UDim2.new(0.5, 0, 0, 28), Vector2.new(0.5, 0))
	UI.Title = label(UI.Top, "NEON HOVER RACING", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 5), 18, Enum.TextXAlignment.Center)
	UI.Subtitle = label(UI.Top, "", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 40), 10, Enum.TextXAlignment.Center)

	UI.CashPanel = panel(gui, "CashPinnedBottomLeft", UDim2.fromOffset(190, BOTTOM_HEIGHT), UDim2.new(0, 18, 1, -BOTTOM_MARGIN), Vector2.new(0, 1))
	label(UI.CashPanel, "Available Cash", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 6), 10, Enum.TextXAlignment.Center)
	UI.Cash = label(UI.CashPanel, "$0", UDim2.new(1, -16, 0, 32), UDim2.fromOffset(8, 28), 19, Enum.TextXAlignment.Center)
	UI.Cash.TextColor3 = Theme.Cash
	local getMore = button(UI.CashPanel, "Get More", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 70), Theme.CardHot)
	getMore.MouseButton1Click:Connect(showCashShop)

	UI.NextPanel = panel(gui, "NextPinnedBottomRight", UDim2.fromOffset(178, BOTTOM_HEIGHT), UDim2.new(1, -18, 1, -BOTTOM_MARGIN), Vector2.new(1, 1))
	UI.Next = button(UI.NextPanel, "Next", UDim2.new(1, -18, 0, 42), UDim2.fromOffset(9, 9), Theme.Buy)
	UI.Back = button(UI.NextPanel, "Back", UDim2.new(1, -18, 0, 38), UDim2.fromOffset(9, 58), Theme.Card)
	local centerPanelSize = UDim2.new(1, -420, 0, BOTTOM_HEIGHT)
	local centerPanelPosition = UDim2.new(0, 216, 1, -BOTTOM_MARGIN)

	UI.StatsPanel = panel(gui, "PersistentStats", UDim2.fromOffset(270, 238), UDim2.new(1, -292, 0, 112), Vector2.zero)
	pad(UI.StatsPanel, 12)

	UI.ColorChannelFloat = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -420, 0, 32), Position = UDim2.new(0, 216, 1, -BOTTOM_MARGIN - BOTTOM_HEIGHT - 8), AnchorPoint = Vector2.new(0, 1), Visible = false }, gui)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, UI.ColorChannelFloat)

	UI.CashShop = panel(gui, "CashShopPopup", UDim2.fromOffset(340, 280), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UI.CashShop.Visible = false
	pad(UI.CashShop, 14)
	UI.CashShopBody = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, UI.CashShop)
	local closeCash = button(UI.CashShop, "X", UDim2.fromOffset(34, 30), UDim2.new(1, -36, 0, 2), Theme.Danger)
	closeCash.MouseButton1Click:Connect(function() UI.CashShop.Visible = false end)

	UI.CockpitShop = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	UI.CategoryPanel = panel(UI.CockpitShop, "Categories", UDim2.fromOffset(190, 560), UDim2.fromOffset(24, 112), Vector2.zero)
	pad(UI.CategoryPanel, 10)
	label(UI.CategoryPanel, "Categories", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 0), 13, Enum.TextXAlignment.Left)
	UI.CategoryList = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 1, -36), Position = UDim2.fromOffset(0, 36) }, UI.CategoryPanel)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, UI.CategoryList)
	makeArrowScroller(UI.CategoryPanel, UI.CategoryList, "Y", 124)

UI.CockpitGridPanel = panel(UI.CockpitShop, "CockpitGridPanel", UDim2.new(1, -590, 1, -230), UDim2.fromOffset(238, 112), Vector2.zero)
pad(UI.CockpitGridPanel, 10)
UI.CockpitGrid = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 1) }, UI.CockpitGridPanel)
UI.CockpitGridLayout = new("UIGridLayout", { CellPadding = UDim2.fromOffset(10, 10), CellSize = UDim2.fromOffset(118, 118), SortOrder = Enum.SortOrder.LayoutOrder }, UI.CockpitGrid)
makeArrowScroller(UI.CockpitGridPanel, UI.CockpitGrid, "Y", 296)

	UI.CockpitPaint = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, gui)
	UI.CockpitPaintPanel = panel(UI.CockpitPaint, "CockpitPaintPanel", centerPanelSize, centerPanelPosition, Vector2.new(0, 1))
	pad(UI.CockpitPaintPanel, 10)
	UI.CockpitPaintPicker = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, UI.CockpitPaintPanel)

	UI.ModuleShop = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, gui)
	UI.ModuleSlotPanel = panel(UI.ModuleShop, "ModuleSlotBarPanel", centerPanelSize, centerPanelPosition, Vector2.new(0, 1))
	pad(UI.ModuleSlotPanel, 10)
	UI.ModuleSlotBar = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X, Size = UDim2.new(1, 0, 0, 72), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) }, UI.ModuleSlotPanel)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, UI.ModuleSlotBar)
	makeArrowScroller(UI.ModuleSlotPanel, UI.ModuleSlotBar, "X", 316)

	UI.ModuleOptionsPanel = panel(UI.ModuleShop, "ModuleOptions", centerPanelSize, centerPanelPosition, Vector2.new(0, 1))
	pad(UI.ModuleOptionsPanel, 10)
	UI.ModuleOptions = new("ScrollingFrame", { Name = "ModuleOptionsScroll", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 78), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ClipsDescendants = true }, UI.ModuleOptionsPanel)
	makeArrowScroller(UI.ModuleOptionsPanel, UI.ModuleOptions, "X", 344)
	UI.ModulePopup = panel(UI.ModuleOptionsPanel, "ModulePopup", UDim2.fromOffset(126, 30), UDim2.fromOffset(0, -28), Vector2.zero)
	UI.ModulePopup.Visible = false

	UI.Customise = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, gui)
	UI.CustomiseLeft = panel(UI.Customise, "CustomiseLeft", UDim2.fromOffset(190, 470), UDim2.fromOffset(18, 112), Vector2.zero)
	pad(UI.CustomiseLeft, 10)
	UI.CustomiseList = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 1) }, UI.CustomiseLeft)
	new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, UI.CustomiseList)
	makeArrowScroller(UI.CustomiseLeft, UI.CustomiseList, "Y", 104)

	UI.CustomisePanel = panel(UI.Customise, "CustomisePanel", centerPanelSize, centerPanelPosition, Vector2.new(0, 1))
	pad(UI.CustomisePanel, 10)
	UI.CustomiseContent = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = false }, UI.CustomisePanel)
	UI.CustomiseColourPicker = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, UI.CustomisePanel)
	UI.CosmeticPopup = panel(UI.CustomisePanel, "CosmeticPopup", UDim2.fromOffset(126, 30), UDim2.fromOffset(0, 0), Vector2.zero)
	UI.CosmeticPopup.Visible = false

	UI.Next.MouseButton1Click:Connect(function()
		if State.Stage == "CockpitPaint" then
			clearPreviewModules()
			State.ModuleMode = "Slots"
			showStage("ModuleShop")
			renderModuleShop()
		elseif State.Stage == "ModuleShop" then
			clearPreviewModules()
			State.CustomizeTarget = "ALL"
			State.CustomizeMode = "Colour"
			showStage("Customise")
			renderCustomise()
		elseif State.Stage == "Customise" then
			local result = callServer("SpawnVehicle", {})
			if result.Success then
				closeGarage()
				task.defer(startDriving)
			else
				UI.Subtitle.Text = result.Message or "Could not spawn vehicle."
			end
		end
	end)
	UI.Back.MouseButton1Click:Connect(function()
		if State.Stage == "CockpitPaint" then
			UI.ColorChannelFloat.Visible = false
			showStage("CockpitShop")
			renderCockpitShop()
		elseif State.Stage == "ModuleShop" then
			if State.ModuleMode == "Options" then
				clearPreviewModules()
				State.ModuleMode = "Slots"
				setCameraSection(nil)
				buildPreview()
				renderModuleShop()
			else
				showStage("CockpitPaint")
				renderCockpitPaint()
			end
		elseif State.Stage == "Customise" then
			if (State.CustomizeMode == "Colour" and State.CustomizeTarget ~= "ALL") or State.CustomizeMode == "Cosmetics" then
				State.CustomizeMode = "Overview"
				UI.ColorChannelFloat.Visible = false
				renderCustomise()
			else
				State.ModuleMode = "Slots"
				UI.ColorChannelFloat.Visible = false
				showStage("ModuleShop")
				renderModuleShop()
			end
		end
	end)

	local function updateScale()
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		UI.Scale.Scale = math.clamp(math.min(viewport.X / 1600, viewport.Y / 900), 0.68, 1.02)
		applyDealershipLayout()
		local scaledH = viewport.Y / math.max(UI.Scale.Scale, 0.1)
		if UI.CustomiseLeft then
			UI.CustomiseLeft.Position = UDim2.fromOffset(18, 112)
			UI.CustomiseLeft.Size = UDim2.fromOffset(190, math.max(180, scaledH - 112 - BOTTOM_HEIGHT - BOTTOM_MARGIN - 12))
		end
		local scaledH = viewport.Y / math.max(UI.Scale.Scale, 0.1)
		if UI.CustomiseLeft then
			UI.CustomiseLeft.Position = UDim2.fromOffset(18, 112)
			UI.CustomiseLeft.Size = UDim2.fromOffset(190, math.max(180, scaledH - 112 - BOTTOM_HEIGHT - BOTTOM_MARGIN - 12))
		end
		local scaledH = viewport.Y / math.max(UI.Scale.Scale, 0.1)
		if UI.CustomiseLeft then
			UI.CustomiseLeft.Position = UDim2.fromOffset(18, 112)
			UI.CustomiseLeft.Size = UDim2.fromOffset(190, math.max(180, scaledH - 112 - BOTTOM_HEIGHT - BOTTOM_MARGIN - 12))
		end
	end
	updateScale()
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end
end

local function setupCameraInput()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or isDriving then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
			State.Dragging = true
			State.LastPointer = input.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
			State.Dragging = false
			State.LastPointer = nil
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if isDriving then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			return
		elseif State.Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			if State.LastPointer then
				local delta = input.Position - State.LastPointer
				State.TargetYaw -= delta.X * 0.006
				State.TargetPitch = math.clamp(State.TargetPitch - delta.Y * 0.004, math.rad(-45), math.rad(10))
			end
			State.LastPointer = input.Position
		end
	end)
	RunService.RenderStepped:Connect(updateCamera)
end

local function init()
	local result = callServer("GetInitial", {})
	if not result.Success then warn(result.Message or "Could not load hover garage.") return end
	State.Catalog = result.Catalog
	State.Profile = result.Profile
	State.SelectedCockpit = State.Profile.CurrentCockpit or "bruiser_01"
	local firstSlot = sortedSlots()[1]
	State.SelectedSlot = firstSlot and firstSlot.SlotId or "Engine1"
	setupUI()
	setupCameraInput()
	updateNav()
	renderCockpitShop()
	buildPreview()
end

task.defer(init)



-- V67_MOBILE_INPUT_STATE_BIND_BEGIN
local mobileInputState = require(game:GetService("ReplicatedStorage")
	:WaitForChild("HOVER_RACING_V2_KIT")
	:WaitForChild("CLIENT_MODULES")
	:WaitForChild("Controllers")
	:WaitForChild("MobileDriveInputState"))
-- V67_MOBILE_INPUT_STATE_BIND_END



-- V75_BOOST_WOBBLE_DRIVING_BEGIN
do
	local okController, V75Driving = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("HOVER_RACING_V2_KIT"):WaitForChild("CLIENT_MODULES"):WaitForChild("Controllers"):WaitForChild("DrivingControllerV47"))
	end)
	if okController and typeof(V75Driving) == "table" and typeof(V75Driving.Start) == "function" then
		local V75OriginalStopDriving = typeof(stopDriving) == "function" and stopDriving or nil
		startDriving = function()
			return V75Driving.Start({
				GetCamera = function()
					return camera or game:GetService("Workspace").CurrentCamera
				end,
				ShowDriveUi = function()
					if typeof(ensureDriveHud) == "function" then pcall(ensureDriveHud) end
					if driveGui then driveGui.Enabled = true end
					if typeof(updateMobileDriveControls) == "function" then pcall(updateMobileDriveControls) end
				end,
				UpdateDriveUi = function(speedMph, boostPercent, driftingNow, driftChargeNow, miniBoostTimerNow)
					if mphLabel then mphLabel.Text = tostring(math.floor((speedMph or 0) + 0.5)) .. " MPH" end
					if boostFill then boostFill.Size = UDim2.fromScale(math.clamp((boostPercent or 0) / 100, 0, 1), 1) end
					if driftLabel then
						if driftingNow then
							driftLabel.Text = (driftChargeNow or 0) > 1.4 and "DRIFT CHARGED" or "DRIFT"
						elseif (miniBoostTimerNow or 0) > 0 then
							driftLabel.Text = "MINI BOOST"
						else
							driftLabel.Text = "SHIFT drift | SPACE boost | R reset"
						end
					end
					if typeof(updateMobileDriveControls) == "function" then pcall(updateMobileDriveControls) end
				end,
				GetMobileInput = function()
					local throttleValue, steerValue, driftValue, boostValue = 0, 0, false, false
					if typeof(mobileInputState) == "table" then
						throttleValue = mobileInputState.Throttle or 0
						steerValue = mobileInputState.Steer or 0
						driftValue = mobileInputState.Drift == true
						boostValue = mobileInputState.Boost == true
					elseif typeof(mobileControls) == "table" and typeof(mobileControls.State) == "table" then
						local s = mobileControls.State
						throttleValue = math.clamp((s.Accelerate and 1 or 0) - (s.Brake and 1 or 0), -1, 1)
						steerValue = math.clamp(((s.TurnRight or s.DriftRight) and 1 or 0) - ((s.TurnLeft or s.DriftLeft) and 1 or 0), -1, 1)
						driftValue = s.DriftLeft == true or s.DriftRight == true
						boostValue = s.Boost == true
					end
					return throttleValue, steerValue, driftValue, boostValue
				end,
				PublishMobile = function(speedMph, boostPercent)
					if typeof(mobileInputState) == "table" then
						mobileInputState.SpeedMph = speedMph or 0
						mobileInputState.BoostPercent = math.clamp(boostPercent or 0, 0, 100)
						mobileInputState.IsDriving = true
					end
				end,
				SetMobileDriving = function(enabled)
					if typeof(mobileInputState) == "table" then
						mobileInputState.IsDriving = enabled == true
						if not enabled and typeof(mobileInputState.Reset) == "function" then mobileInputState.Reset() end
					end
				end,
			})
		end
		stopDriving = function(...)
			V75Driving.Stop()
			if V75OriginalStopDriving then
				return V75OriginalStopDriving(...)
			end
		end
		print("[V75] V47-style driving controller with boost delay and hover wobble is active.")
	else
		warn("[V75] Could not install V47-style driving controller: " .. tostring(V75Driving))
	end
end
-- V75_BOOST_WOBBLE_DRIVING_END
