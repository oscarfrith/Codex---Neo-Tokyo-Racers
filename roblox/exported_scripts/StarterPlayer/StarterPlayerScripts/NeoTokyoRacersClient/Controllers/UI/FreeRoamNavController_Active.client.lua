-- NTR Free Roam Map Stack Phase 2
-- NTR_FREEROAM_CAR_MENU_PHASE3_OWNED_COCKPIT_CARDS
-- NTR_FREEROAM_CAR_MENU_PHASE4_CARD_SCALING_SORT_FUTURE_SPAWN
-- NTR_FREEROAM_CAR_MENU_PHASE5_IMAGE_FIT_BORDER_PADDING
-- NTR_FREEROAM_CAR_MENU_PHASE6_CARD_SURFACE_ROOT_FIX
-- NTR_FREEROAM_CAR_MENU_PHASE7_BORDERLESS_CARD_FRAMES_COMPACT_WIDTH

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local touch = UserInputService.TouchEnabled

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local remotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage")
local garageInvoke = remotes:WaitForChild("GarageInvoke")
local interiorInvoke = remotes:FindFirstChild("GarageInteriorInvoke")
local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("FreeRoamNav")
local mobileInputState
pcall(function()
	mobileInputState = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("MobileDriveInputState")
	mobileInputState = require(mobileInputState)
end)

local defaultTheme = {
	Panel = Color3.fromRGB(5, 9, 7),
	PanelSoft = Color3.fromRGB(12, 20, 17),
	Card = Color3.fromRGB(24, 35, 42),
	Selected = Color3.fromRGB(36, 118, 82),
	Text = Color3.fromRGB(218, 255, 231),
	Muted = Color3.fromRGB(145, 178, 160),
	Accent = Color3.fromRGB(172, 255, 197),
	Buy = Color3.fromRGB(8, 145, 112),
	Back = Color3.fromRGB(24, 35, 42),
	Exit = Color3.fromRGB(175, 70, 68),
	Warn = Color3.fromRGB(255, 180, 105),
	PanelTransparency = 0.12,
	ButtonTransparency = 0.08,
	FontFamily = "rbxasset://fonts/families/Michroma.json",
}

local theme = table.clone(defaultTheme)
local gui
local stack
local mapFrame
local mapImage
local mapPlaceholder
local carButton
local actionGrid
local statusToast
local actionPanel
local actionTitle
local actionBody
local activePanel = nil
local cachedProfile = nil
local cachedCatalog = nil
local lastProfileRead = 0

local function readColor(folder, name, fallback, alternate)
	local item = folder and (folder:FindFirstChild(name) or (alternate and folder:FindFirstChild(alternate)))
	return item and item:IsA("Color3Value") and item.Value or fallback
end

local function readNumber(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function readBool(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("BoolValue") and item.Value or fallback
end

local function readString(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("StringValue") and item.Value or fallback
end

local function assetImage(value)
	local text = tostring(value or "")
	if text == "" then return "" end
	if string.find(text, "rbxassetid://", 1, true) or string.find(text, "rbxthumb://", 1, true) then
		return text
	end
	if tonumber(text) then
		return "rbxassetid://" .. text
	end
	return text
end

local function refreshTheme()
	local themeFolder = kit:FindFirstChild("Config") and kit.Config:FindFirstChild("UI") and kit.Config.UI:FindFirstChild("Theme")
	theme.Panel = readColor(themeFolder, "Panel", defaultTheme.Panel)
	theme.PanelSoft = readColor(themeFolder, "PanelSoft", defaultTheme.PanelSoft)
	theme.Card = readColor(themeFolder, "Card", defaultTheme.Card)
	theme.Selected = readColor(themeFolder, "Selected", defaultTheme.Selected, "CardHot")
	theme.Text = readColor(themeFolder, "Text", defaultTheme.Text)
	theme.Muted = readColor(themeFolder, "Muted", defaultTheme.Muted, "MutedText")
	theme.Accent = readColor(themeFolder, "Accent", defaultTheme.Accent)
	theme.Buy = readColor(themeFolder, "Buy", defaultTheme.Buy)
	theme.Back = readColor(themeFolder, "Back", defaultTheme.Back, "BackButton")
	theme.Exit = readColor(themeFolder, "Exit", defaultTheme.Exit, "ExitButton")
	theme.PanelTransparency = readNumber(themeFolder, "PanelTransparency", defaultTheme.PanelTransparency)
	theme.ButtonTransparency = readNumber(themeFolder, "ButtonTransparency", defaultTheme.ButtonTransparency)
	theme.FontFamily = readString(themeFolder, "FontFamily", defaultTheme.FontFamily)
end

local function applyFont(object)
	if theme.FontFamily and theme.FontFamily ~= "" then
		pcall(function()
			object.FontFace = Font.new(theme.FontFamily, Enum.FontWeight.Bold)
		end)
	end
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 5)
	c.Parent = parent
	return c
end

local function stroke(parent, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or theme.Accent
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.2
	if parent:IsA("GuiButton") or parent:IsA("Frame") then
		pcall(function()
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		end)
	end
	s.Parent = parent
	return s
end

local function addTextGlow(object)
	if not readBool(config, "TextGlowEnabled", true) then return end
	local s = Instance.new("UIStroke")
	s.Name = "TextGlow"
	s.Color = readColor(config, "TextGlowColor", Color3.fromRGB(255, 120, 235))
	s.Thickness = readNumber(config, "TextGlowThickness", 1.4)
	s.Transparency = readNumber(config, "TextGlowTransparency", 0.25)
	pcall(function()
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	end)
	s.Parent = object
end

local function bevel(parent)
	local top = Instance.new("Frame")
	top.Name = "TopHighlight"
	top.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	top.BackgroundTransparency = 0.78
	top.BorderSizePixel = 0
	top.Size = UDim2.new(1, -14, 0, 2)
	top.Position = UDim2.fromOffset(7, 5)
	top.ZIndex = (parent.ZIndex or 1) + 1
	top.Parent = parent
	local bottom = Instance.new("Frame")
	bottom.Name = "BottomShadow"
	bottom.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bottom.BackgroundTransparency = 0.55
	bottom.BorderSizePixel = 0
	bottom.Size = UDim2.new(1, -14, 0, 2)
	bottom.Position = UDim2.new(0, 7, 1, -7)
	bottom.ZIndex = (parent.ZIndex or 1) + 1
	bottom.Parent = parent
end

local function makeLabel(parent, name, text, size, position, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Text = text
	label.TextColor3 = color or theme.Text
	label.TextSize = textSize or 12
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Font = Enum.Font.GothamBold
	if parent and parent:IsA("GuiObject") then
		label.ZIndex = parent.ZIndex + 1
	end
	applyFont(label)
	addTextGlow(label)
	label.Parent = parent
	return label
end

local function setStatus(message, good)
	if not statusToast then return end
	statusToast.Text = tostring(message or "")
	statusToast.TextColor3 = good and theme.Accent or theme.Warn
	statusToast.Visible = true
	local stamp = os.clock()
	statusToast:SetAttribute("Stamp", stamp)
	task.delay(2.4, function()
		if statusToast and statusToast:GetAttribute("Stamp") == stamp then
			statusToast.Visible = false
		end
	end)
end

local function callGarage(action, payload)
	local ok, result = pcall(function()
		return garageInvoke:InvokeServer(action, payload or {})
	end)
	if ok and type(result) == "table" then return result end
	return { Success = false, Ok = false, Message = tostring(result), Error = tostring(result) }
end

local function callInterior(action, payload)
	if not interiorInvoke then
		return { Ok = false, Error = "GarageInteriorInvoke missing" }
	end
	local ok, result = pcall(function()
		return interiorInvoke:InvokeServer(action, payload or {})
	end)
	if ok and type(result) == "table" then return result end
	return { Ok = false, Error = tostring(result) }
end

local function readProfile()
	if cachedProfile and os.clock() - lastProfileRead < 2 then
		return cachedProfile
	end
	local ok, result = pcall(function()
		return garageInvoke:InvokeServer("GetInitial", {})
	end)
	lastProfileRead = os.clock()
	if ok and type(result) == "table" then
		cachedProfile = result.Profile or result
		cachedCatalog = result.Catalog or cachedCatalog
		return cachedProfile
	end
	return nil
end

local function openDealership()
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local intro = controllers and controllers:FindFirstChild("Intro")
	local event = intro and intro:FindFirstChild("OpenGarageFromIntro")
	if event and event:IsA("BindableEvent") then
		event:Fire()
		setStatus("OPENING SHOP", true)
	else
		setStatus("SHOP HOOK NOT READY", false)
	end
end

local function exitVehicle()
	local result = callGarage("ExitVehicle", {})
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.Sit = false end
	setStatus((result.Success == false and result.Message) or "EXIT VEHICLE SENT", result.Success ~= false)
end


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
local function isGuiActuallyVisible(object, stopAt)
	local current = object
	while current and current ~= stopAt do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return true
end

local function isDealershipOpen()
	for _, guiObject in ipairs(playerGui:GetChildren()) do
		if guiObject:IsA("ScreenGui") and guiObject.Enabled and guiObject ~= gui then
			local lowerName = string.lower(guiObject.Name)
			local isMenuName = string.find(lowerName, "garage", 1, true) ~= nil
				or string.find(lowerName, "dealership", 1, true) ~= nil
				or string.find(lowerName, "custom", 1, true) ~= nil
			local rootObject = guiObject:FindFirstChild("GarageRoot", true)
				or guiObject:FindFirstChild("DealershipRoot", true)
				or guiObject:FindFirstChild("CustomisationRoot", true)
				or guiObject:FindFirstChild("CustomizationRoot", true)
			if rootObject and rootObject:IsA("GuiObject") and rootObject.Visible == true and isGuiActuallyVisible(rootObject, guiObject) then
				return true
			end
			if isMenuName then
				for _, descendant in ipairs(guiObject:GetDescendants()) do
					if descendant:IsA("GuiObject") and descendant.Visible and descendant.AbsoluteSize.X > 80 and descendant.AbsoluteSize.Y > 40 and isGuiActuallyVisible(descendant, guiObject) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function suppressLegacyUi()
	if readBool(config, "HideLegacyDriveMenu", true) then
		local driveGui = playerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD")
		local driveMenu = driveGui and driveGui:FindFirstChild("DriveMenu", true)
		if driveMenu and driveMenu:IsA("GuiObject") then
			driveMenu.Visible = false
		end
	end
	if readBool(config, "HideLegacyGarageAccessUI", true) then
		local legacy = playerGui:FindFirstChild("NTR_GarageAccessUI")
		if legacy and legacy:IsA("ScreenGui") then
			legacy.Enabled = false
		end
	end
end

local function looksDrivingForTouch()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
		return true
	end
	local driveGui = playerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD")
	return driveGui and driveGui.Enabled == true
end

local function shouldShowMapStack()
	if isDealershipOpen() then
		return false
	end
	return true
end

local function keepMobileDriveControls()
	if not touch or isDealershipOpen() then return end
	local driving = looksDrivingForTouch()
	if typeof(mobileInputState) == "table" then
		if driving then
			mobileInputState.IsDriving = true
		elseif not driving and mobileInputState.IsDriving == true then
			mobileInputState.IsDriving = false
		end
	end
	local driveGui = playerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD")
	if driving and driveGui and driveGui:IsA("ScreenGui") then
		local desktopHud = driveGui:FindFirstChild("DriveHUD", true)
		if desktopHud and desktopHud:IsA("GuiObject") then
			desktopHud.Visible = false
		end
		local driveMenu = driveGui:FindFirstChild("DriveMenu", true)
		if driveMenu and driveMenu:IsA("GuiObject") then
			driveMenu.Visible = false
		end
	end
	local mobileGui = playerGui:FindFirstChild("HOVER_RACING_V67_MobileDriveControlsUI")
	local root = mobileGui and mobileGui:FindFirstChild("Root")
	if driving and mobileGui and mobileGui:IsA("ScreenGui") then
		mobileGui.Enabled = true
	end
end

local function styleButton(button)
	button.AutoButtonColor = true
	button.BackgroundColor3 = readColor(config, "ButtonBaseColor", theme.Card)
	button.BackgroundTransparency = readNumber(config, "ButtonBaseTransparency", theme.ButtonTransparency)
	button.BorderSizePixel = 0
	button.Text = ""
	button.ClipsDescendants = true
	corner(button, 7)
	stroke(button, readColor(config, "ButtonOutline", Color3.fromRGB(230, 88, 205)), readNumber(config, "ButtonOutlineTransparency", 0), readNumber(config, "ButtonOutlineThickness", 2.4))
	local inset = readNumber(config, "ButtonFillInset", 2)
	local fill = Instance.new("Frame")
	fill.Name = "ButtonFill"
	fill.BackgroundColor3 = readColor(config, "ButtonGradientTopLeft", Color3.fromRGB(35, 48, 58))
	fill.BackgroundTransparency = theme.ButtonTransparency
	fill.BorderSizePixel = 0
	fill.Position = UDim2.fromOffset(inset, inset)
	fill.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
	fill.ZIndex = button.ZIndex + 1
	fill.Parent = button
	corner(fill, math.max(3, 7 - inset))
	local gradient = Instance.new("UIGradient")
	gradient.Name = "NTRButtonGradient"
	gradient.Rotation = readNumber(config, "ButtonGradientRotation", 135)
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, readColor(config, "ButtonGradientTopLeft", Color3.fromRGB(35, 48, 58))),
		ColorSequenceKeypoint.new(1, readColor(config, "ButtonGradientBottomRight", Color3.fromRGB(9, 18, 20))),
	})
	gradient.Parent = fill
	local hover = Instance.new("Frame")
	hover.Name = "ButtonHoverOverlay"
	hover.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	hover.BackgroundTransparency = 1
	hover.BorderSizePixel = 0
	hover.Position = UDim2.fromOffset(inset, inset)
	hover.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
	hover.ZIndex = button.ZIndex + 2
	hover.Parent = button
	corner(hover, math.max(3, 7 - inset))
	button.MouseEnter:Connect(function()
		hover.BackgroundTransparency = readNumber(config, "ButtonHoverOverlayTransparency", 0.82)
	end)
	button.MouseLeave:Connect(function()
		hover.BackgroundTransparency = 1
	end)
	button.MouseButton1Down:Connect(function()
		hover.BackgroundTransparency = math.max(0, readNumber(config, "ButtonHoverOverlayTransparency", 0.82) - 0.08)
	end)
	button.MouseButton1Up:Connect(function()
		hover.BackgroundTransparency = readNumber(config, "ButtonHoverOverlayTransparency", 0.82)
	end)
end


-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_FREE_ROAM_IMAGE_LOOKUP
local function currentCockpitMenuImage()
	local profile = readProfile() or {}
	local cockpitId = ""
	if profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId] then
		local vehicle = profile.Vehicles[profile.CurrentVehicleId]
		if vehicle.CockpitId then
			cockpitId = tostring(vehicle.CockpitId)
		elseif vehicle.CockpitInstanceId and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId] then
			cockpitId = tostring(profile.OwnedCockpitInstances[vehicle.CockpitInstanceId].TemplateId or "")
		end
	end
	if cockpitId == "" then
		cockpitId = tostring(profile.CurrentCockpit or profile.SelectedCockpit or "")
	end
	if cockpitId == "" then return "" end

	local function imageFromValue(value)
		return assetImage(value)
	end

	local function readImageObject(object)
		if not object then return "" end
		local names = { "MenuImage", "CockpitImage", "ThumbnailImage", "ImageId", "Image" }
		for _, name in ipairs(names) do
			local image = imageFromValue(object:GetAttribute(name))
			if image ~= "" then return image end
			local child = object:FindFirstChild(name)
			if child then
				if child:IsA("StringValue") then
					image = imageFromValue(child.Value)
				elseif child:IsA("Decal") or child:IsA("Texture") then
					image = imageFromValue(child.Texture)
				elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
					image = imageFromValue(child.Image)
				end
				if image ~= "" then return image end
			end
		end
		for _, child in ipairs(object:GetDescendants()) do
			local lower = string.lower(child.Name)
			if string.find(lower, "menuimage", 1, true) or string.find(lower, "cockpitimage", 1, true) or string.find(lower, "thumbnail", 1, true) then
				local image = ""
				if child:IsA("StringValue") then
					image = imageFromValue(child.Value)
				elseif child:IsA("Decal") or child:IsA("Texture") then
					image = imageFromValue(child.Texture)
				elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
					image = imageFromValue(child.Image)
				end
				if image ~= "" then return image end
			end
		end
		return ""
	end

	local vehicles = kit:FindFirstChild("Assets") and kit.Assets:FindFirstChild("Vehicles")
	local categories = vehicles and vehicles:FindFirstChild("Categories")
	if not categories then return "" end
	for _, category in ipairs(categories:GetChildren()) do
		local root = category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS")
		if root then
			for _, cockpit in ipairs(root:GetDescendants()) do
				if cockpit:IsA("Model") and tostring(cockpit:GetAttribute("CockpitId") or cockpit.Name) == cockpitId then
					local image = readImageObject(cockpit)
					if image ~= "" then return image end
					local current = cockpit.Parent
					while current and current ~= categories do
						image = readImageObject(current)
						if image ~= "" then return image end
						current = current.Parent
					end
					return ""
				end
			end
		end
	end
	return ""
end

local function cockpitMenuCardConfigNumber(name, fallback)
	local configRoot = kit:FindFirstChild("Config")
	local ui = configRoot and configRoot:FindFirstChild("UI")
	local cards = ui and ui:FindFirstChild("CockpitMenuCards")
	local item = cards and cards:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function ensureImageIcon(button, scale)
	local icon = button and button:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") then return icon end
	if not button then return nil end
	icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(32, 32)
	icon:SetAttribute("NTRIconScale", scale or cockpitMenuCardConfigNumber("FreeRoamCarIconScale", 0.72))
	icon.ZIndex = button.ZIndex + 3
	icon.Parent = button
	return icon
end

local function updateCarButtonImage()
	if not carButton then return end
	local useCockpitImage = false
	local configRoot = kit:FindFirstChild("Config")
	local ui = configRoot and configRoot:FindFirstChild("UI")
	local cards = ui and ui:FindFirstChild("CockpitMenuCards")
	local cockpitToggle = cards and cards:FindFirstChild("FreeRoamUsesCockpitMenuImage")
	if cockpitToggle and cockpitToggle:IsA("BoolValue") then
		useCockpitImage = cockpitToggle.Value
	end
	local imageId = ""
	if useCockpitImage and typeof(currentCockpitMenuImage) == "function" then
		imageId = currentCockpitMenuImage()
	end
	if imageId == "" then
		imageId = assetImage(readString(config, "CarIcon", ""))
	end
	local fallback = carButton:FindFirstChild("Fallback")
	if imageId ~= "" then
		local icon = ensureImageIcon(carButton, cockpitMenuCardConfigNumber("FreeRoamCarIconScale", 0.48))
		if icon then
			icon.Image = imageId
			icon.Visible = true
			icon:SetAttribute("NTRIconScale", cockpitMenuCardConfigNumber("FreeRoamCarIconScale", 0.48))
		end
		if fallback and fallback:IsA("GuiObject") then
			fallback.Visible = false
		end
	elseif fallback and fallback:IsA("GuiObject") then
		fallback.Visible = true
	end
end

local function attachIcon(button, iconValueName, fallbackText, iconScale)
	local imageId = assetImage(readString(config, iconValueName, ""))
	if imageId ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Image = imageId
		icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Size = UDim2.fromOffset(32, 32)
		icon:SetAttribute("NTRIconScale", iconScale or 0.52)
		icon.ZIndex = button.ZIndex + 3
		icon.Parent = button
	else
		local label = makeLabel(button, "Fallback", fallbackText, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), touch and 11 or 12, theme.Text)
		label.ZIndex = button.ZIndex + 3
	end
end

local function clearActionBody()
	if not actionBody then return end
	for _, child in ipairs(actionBody:GetChildren()) do
		child:Destroy()
	end
end

local function makeActionButton(parent, name, text, y, color, callback)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, -16, 0, touch and 34 or 32)
	button.Position = UDim2.fromOffset(8, y)
	button.BackgroundColor3 = color or readColor(config, "ButtonGradientTopLeft", theme.Card)
	button.BackgroundTransparency = theme.ButtonTransparency
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = theme.Text
	button.TextSize = 10
	button.Font = Enum.Font.GothamBold
	addTextGlow(button)
	if parent and parent:IsA("GuiObject") then
		button.ZIndex = parent.ZIndex + 1
	end
	applyFont(button)
	button.Parent = parent
	corner(button, 5)
	stroke(button, readColor(config, "ButtonOutline", Color3.fromRGB(230, 88, 205)), 0.35, 1)
	button.MouseButton1Click:Connect(callback)
	return button
end


-- NTR_FREEROAM_CAR_MENU_PHASE3_HELPERS
local function carPanelNumber(name, fallback)
	return readNumber(config, name, fallback)
end

local function carPanelCardConfigNumber(name, fallback)
	local configRoot = kit:FindFirstChild("Config")
	local ui = configRoot and configRoot:FindFirstChild("UI")
	local cards = ui and ui:FindFirstChild("CockpitMenuCards")
	local item = cards and cards:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function carPanelCockpitIdForVehicle(profile, vehicle)
	local cockpitInstance = vehicle and vehicle.CockpitInstanceId and profile and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
	return cockpitInstance and tostring(cockpitInstance.TemplateId or "") or tostring((vehicle and vehicle.CockpitId) or "")
end

local function carPanelVehicleRatingParts(profile, vehicleId)
	local summary = profile and profile.VehicleSummaries and profile.VehicleSummaries[vehicleId]
	local overall = summary and summary.Overall or {}
	local tier = tostring(overall.Tier or "--")
	local index = tonumber(overall.PerformanceIndex)
	return tier, (index and tostring(math.floor(index)) or "---"), index or -math.huge
end

local function carPanelTierColor(tier)
	tier = string.upper(tostring(tier or ""))
	if tier == "S" then return Color3.fromRGB(224, 78, 255) end
	if tier == "A" then return Color3.fromRGB(178, 92, 255) end
	if tier == "B" then return Color3.fromRGB(79, 139, 238) end
	if tier == "C" then return Color3.fromRGB(71, 195, 202) end
	if tier == "D" then return Color3.fromRGB(93, 202, 126) end
	if tier == "E" then return Color3.fromRGB(145, 162, 171) end
	return theme.Accent
end

local function carPanelCatalogCockpit(cockpitId)
	cockpitId = tostring(cockpitId or "")
	if cockpitId == "" then return nil end
	for _, category in ipairs((cachedCatalog and cachedCatalog.Categories) or {}) do
		for _, cockpit in ipairs((category and category.Cockpits) or {}) do
			if tostring(cockpit.CockpitId or "") == cockpitId then
				return cockpit
			end
		end
	end
	return nil
end

local function carPanelReadImageObject(object)
	if not object then return "" end
	for _, name in ipairs({ "MenuImage", "CockpitImage", "ThumbnailImage", "ImageId", "Image" }) do
		local image = assetImage(object:GetAttribute(name))
		if image ~= "" then return image end
		local child = object:FindFirstChild(name)
		if child then
			if child:IsA("StringValue") then
				image = assetImage(child.Value)
			elseif child:IsA("Decal") or child:IsA("Texture") then
				image = assetImage(child.Texture)
			elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
				image = assetImage(child.Image)
			end
			if image ~= "" then return image end
		end
	end
	for _, child in ipairs(object:GetDescendants()) do
		local lower = string.lower(child.Name)
		if string.find(lower, "menuimage", 1, true) or string.find(lower, "cockpitimage", 1, true) or string.find(lower, "thumbnail", 1, true) then
			local image = ""
			if child:IsA("StringValue") then
				image = assetImage(child.Value)
			elseif child:IsA("Decal") or child:IsA("Texture") then
				image = assetImage(child.Texture)
			elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
				image = assetImage(child.Image)
			end
			if image ~= "" then return image end
		end
	end
	return ""
end

local function carPanelCockpitModel(cockpitId)
	cockpitId = tostring(cockpitId or "")
	if cockpitId == "" then return nil end
	local vehicles = kit:FindFirstChild("Assets") and kit.Assets:FindFirstChild("Vehicles")
	local categories = vehicles and vehicles:FindFirstChild("Categories")
	if not categories then return nil end
	for _, category in ipairs(categories:GetChildren()) do
		local root = category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS")
		if root then
			for _, cockpit in ipairs(root:GetDescendants()) do
				if cockpit:IsA("Model") then
					local candidateId = tostring(cockpit:GetAttribute("CockpitId") or cockpit.Name)
					if candidateId == cockpitId or cockpit.Name == cockpitId then
						return cockpit
					end
				end
			end
		end
	end
	return nil
end

local function carPanelCockpitImage(cockpitId, cockpit)
	local fromCatalog = assetImage(cockpit and (cockpit.MenuImage or cockpit.CockpitImage or cockpit.ThumbnailImage or cockpit.ImageId or cockpit.Image) or "")
	if fromCatalog ~= "" then return fromCatalog end
	local model = carPanelCockpitModel(cockpitId)
	local image = carPanelReadImageObject(model)
	if image ~= "" then return image end
	local current = model and model.Parent
	local vehicles = kit:FindFirstChild("Assets") and kit.Assets:FindFirstChild("Vehicles")
	local categories = vehicles and vehicles:FindFirstChild("Categories")
	while current and current ~= categories do
		image = carPanelReadImageObject(current)
		if image ~= "" then return image end
		current = current.Parent
	end
	return ""
end

local function carPanelCockpitName(cockpitId, cockpit)
	local model = carPanelCockpitModel(cockpitId)
	return tostring((cockpit and (cockpit.DisplayName or cockpit.Name or cockpit.CockpitId))
		or (model and (model:GetAttribute("DisplayName") or model.Name))
		or cockpitId
		or "Vehicle")
end

local function carPanelOwnedRows(profile)
	local rows = {}
	for vehicleId, vehicle in pairs((profile and profile.Vehicles) or {}) do
		local cockpitId = carPanelCockpitIdForVehicle(profile, vehicle)
		if cockpitId ~= "" then
			local cockpit = carPanelCatalogCockpit(cockpitId)
			local tier, ratingIndex, sortRating = carPanelVehicleRatingParts(profile, vehicleId)
			table.insert(rows, {
				VehicleId = vehicleId,
				CockpitId = cockpitId,
				Cockpit = cockpit,
				Name = carPanelCockpitName(cockpitId, cockpit),
				Image = carPanelCockpitImage(cockpitId, cockpit),
				Tier = tier,
				RatingIndex = ratingIndex,
				SortRating = sortRating,
				Selected = tostring(vehicleId) == tostring(profile and profile.CurrentVehicleId or ""),
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.SortRating ~= b.SortRating then
			return a.SortRating > b.SortRating
		end
		if a.Name == b.Name then
			return tostring(a.VehicleId) < tostring(b.VehicleId)
		end
		return a.Name < b.Name
	end)
	return rows
end

local function carPanelLayoutForWidth(width)
	local pad = math.max(4, carPanelCardConfigNumber("CardOuterPadding", 8))
	local maxImage = touch and carPanelNumber("CarPanelMobileImageMaxSize", 88) or carPanelNumber("CarPanelDesktopImageMaxSize", 144)
	local imageSize = math.max(1, math.min((tonumber(width) or 120) - pad * 2, maxImage))
	local visualWidth = imageSize + pad * 2
	local nameH = touch and carPanelCardConfigNumber("MobileNameHeight", 16) or carPanelCardConfigNumber("DesktopNameHeight", 18)
	local nameY = pad + imageSize + carPanelNumber("CarPanelImageToTextGap", 6)
	local cardH = nameY + nameH + carPanelNumber("CarPanelCardBottomPadding", 8)
	return pad, imageSize, nameY, nameH, cardH, visualWidth
end


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
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE3_CLIENT
local function spawnOwnedVehicleFromCard(row)
	if not row or not row.VehicleId then
		setStatus("VEHICLE CARD MISSING ID", false)
		return
	end
	setStatus("SPAWNING VEHICLE...", true)
	local result = callGarage("SpawnOwnedVehicleFromFreeRoam", {
		VehicleId = tostring(row.VehicleId or ""),
		CockpitId = tostring(row.CockpitId or ""),
	})
	if result.Success == true then
		cachedProfile = result.Profile or cachedProfile
		lastProfileRead = os.clock()
		setStatus("VEHICLE SPAWNED", true)
		fireFreeRoamVehicleSpawned()
		-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4C_HIDE_CAR_MENU
		if actionPanel then
			actionPanel.Visible = false
			activePanel = nil
		end
	else
		setStatus(tostring(result.Message or "SPAWN FAILED"), false)
	end
end

local function carPanelRenderCockpitCard(parent, row, width)
	local pad, imageSize, nameY, nameH, cardH, visualWidth = carPanelLayoutForWidth(width)
	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4D_COMPACT_BORDERLESS_CARDS
	local border = 0
	local outlineColor = row.Selected and theme.Selected or theme.Card
	local card = Instance.new("TextButton")
	card.Name = "VehicleCell_" .. tostring(row.VehicleId)
	card.AutoButtonColor = true
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.Text = ""
	card.ClipsDescendants = false
	card.Size = UDim2.fromOffset(width, cardH)
	card:SetAttribute("VehicleId", tostring(row.VehicleId or ""))
	card:SetAttribute("CockpitId", tostring(row.CockpitId or ""))
	card:SetAttribute("IsCurrentVehicle", row.Selected == true)
	card:SetAttribute("FreeRoamVehicleAction", readString(config, "CarPanelClickAction", "PreviewOnly"))
	card.ZIndex = parent.ZIndex + 1
	card.Parent = parent

	local surfaceBorder = Instance.new("Frame")
	surfaceBorder.Name = "CardSurface"
	surfaceBorder.BackgroundColor3 = outlineColor
	surfaceBorder.BackgroundTransparency = row.Selected and 0.02 or theme.ButtonTransparency
	surfaceBorder.BorderSizePixel = 0
	surfaceBorder.ClipsDescendants = false
	surfaceBorder.Position = UDim2.fromOffset(0, 0)
	surfaceBorder.Size = UDim2.fromOffset(visualWidth, cardH)
	surfaceBorder.ZIndex = card.ZIndex + 1
	surfaceBorder.Parent = card
	corner(surfaceBorder, 6)

	local surface = Instance.new("Frame")
	surface.Name = "CardFill"
	surface.BackgroundColor3 = row.Selected and theme.Selected or theme.Card
	surface.BackgroundTransparency = row.Selected and 0.08 or theme.ButtonTransparency
	surface.BorderSizePixel = 0
	surface.ClipsDescendants = false
	surface.Position = UDim2.fromOffset(0, 0)
	surface.Size = UDim2.fromScale(1, 1)
	surface.ZIndex = surfaceBorder.ZIndex + 1
	surface.Parent = surfaceBorder
	corner(surface, math.max(3, 6 - border))

	local imageBorder = Instance.new("Frame")
	imageBorder.Name = "ImageBox"
	imageBorder.BackgroundColor3 = Color3.fromRGB(18, 27, 31)
	imageBorder.BackgroundTransparency = 0
	imageBorder.BorderSizePixel = 0
	imageBorder.ClipsDescendants = false
	imageBorder.Position = UDim2.fromOffset(pad, pad)
	imageBorder.Size = UDim2.fromOffset(imageSize, imageSize)
	imageBorder.ZIndex = surface.ZIndex + 1
	imageBorder.Parent = surfaceBorder
	corner(imageBorder, carPanelCardConfigNumber("ImageCornerRadius", 4))

	local imageBox = Instance.new("Frame")
	imageBox.Name = "ImageFill"
	imageBox.BackgroundColor3 = Color3.fromRGB(18, 27, 31)
	imageBox.BorderSizePixel = 0
	imageBox.ClipsDescendants = true
	imageBox.Position = UDim2.fromOffset(0, 0)
	imageBox.Size = UDim2.fromScale(1, 1)
	imageBox.ZIndex = imageBorder.ZIndex + 1
	imageBox.Parent = imageBorder
	corner(imageBox, math.max(2, carPanelCardConfigNumber("ImageCornerRadius", 4) - border))

	if row.Image ~= "" then
		local inset = math.max(0, carPanelNumber("CarPanelImageInnerPadding", carPanelCardConfigNumber("ImageInnerPadding", 5)))
		local image = Instance.new("ImageLabel")
		image.Name = "CockpitImage"
		image.BackgroundTransparency = 1
		image.Image = row.Image
		image.ScaleType = Enum.ScaleType.Fit
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
		image.ZIndex = imageBox.ZIndex + 1
		image.Parent = imageBox
	else
		local fallback = Instance.new("Frame")
		fallback.Name = "FallbackBar"
		fallback.BackgroundColor3 = theme.Accent
		fallback.BorderSizePixel = 0
		fallback.AnchorPoint = Vector2.new(0.5, 0.5)
		fallback.Position = UDim2.fromScale(0.5, 0.5)
		fallback.Size = UDim2.fromOffset(math.min(72, imageSize * 0.58), math.max(10, imageSize * 0.12))
		fallback.ZIndex = imageBox.ZIndex + 1
		fallback.Parent = imageBox
		corner(fallback, 3)
	end

	local badgeW = math.max(46, math.floor(imageSize * 0.38 + 0.5))
	local badgeH = math.max(16, math.floor(imageSize * 0.14 + 0.5))
	local badge = Instance.new("Frame")
	badge.Name = "TierRatingBadge"
	badge.BackgroundColor3 = carPanelTierColor(row.Tier)
	badge.BackgroundTransparency = 0.02
	badge.BorderSizePixel = 0
	badge.Position = UDim2.fromOffset(pad + imageSize - badgeW - 5, pad + 5)
	badge.Size = UDim2.fromOffset(badgeW, badgeH)
	badge.ZIndex = imageBorder.ZIndex + 4
	badge.Parent = surfaceBorder
	corner(badge, 4)
	local badgeText = Instance.new("TextLabel")
	badgeText.Name = "Text"
	badgeText.BackgroundTransparency = 1
	badgeText.Size = UDim2.fromScale(1, 1)
	badgeText.Position = UDim2.fromOffset(0, 0)
	badgeText.Text = tostring(row.Tier) .. " " .. tostring(row.RatingIndex)
	badgeText.TextColor3 = Color3.fromRGB(244, 250, 255)
	badgeText.TextSize = touch and 8 or 9
	badgeText.TextWrapped = false
	badgeText.TextXAlignment = Enum.TextXAlignment.Center
	badgeText.TextYAlignment = Enum.TextYAlignment.Center
	badgeText.TextStrokeTransparency = 1
	badgeText.Font = Enum.Font.GothamBold
	applyFont(badgeText)
	badgeText.ZIndex = badge.ZIndex + 1
	badgeText.Parent = badge

	local name = makeLabel(surfaceBorder, "Name", row.Name, UDim2.new(1, -pad * 2, 0, nameH), UDim2.fromOffset(pad, nameY), touch and 9 or 10, theme.Text)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextWrapped = true
	name.ZIndex = surfaceBorder.ZIndex + 4

	card.MouseButton1Click:Connect(function()
		local action = readString(config, "CarPanelClickAction", "SpawnOwnedVehicle")
		if action == "PreviewOnly" then
			setStatus(row.Selected and "CURRENT VEHICLE" or "SPAWN / SELECT COMING NEXT", row.Selected)
		else
			spawnOwnedVehicleFromCard(row)
		end
	end)
	return card
end

local function carPanelLayoutExisting()
	if not actionBody then return end
	local scroll = actionBody:FindFirstChild("VehicleCards")
	local grid = scroll and scroll:FindFirstChild("Grid")
	local despawn = actionBody:FindFirstChild("DespawnVehicle")
	if not scroll or not grid then return end
	local panelW = math.max(1, actionPanel.AbsoluteSize.X)
	local panelH = math.max(1, actionPanel.AbsoluteSize.Y)
	local pad = carPanelNumber("CarPanelPadding", 8)
	local gap = carPanelNumber("CarPanelCardGap", 8)
	local bottomPad = carPanelNumber("CarPanelBottomPadding", 8)
	local buttonH = touch and math.max(32, carPanelNumber("CarPanelDespawnHeight", 34)) or carPanelNumber("CarPanelDespawnHeight", 34)
	local columns = touch and carPanelNumber("CarPanelMobileColumns", 2) or carPanelNumber("CarPanelDesktopColumns", 3)
	columns = math.max(1, math.floor(columns + 0.5))
	local rawCardW = math.floor((panelW - pad * 2 - gap * (columns - 1)) / columns)
	local maxCard = touch and carPanelNumber("CarPanelMaxCardWidthTouch", 118) or carPanelNumber("CarPanelMaxCardWidthDesktop", 160)
	local cardW = math.max(70, math.min(maxCard, rawCardW))
	local _, _, _, _, cardH = carPanelLayoutForWidth(cardW)
	scroll.Position = UDim2.fromOffset(pad, pad)
	scroll.Size = UDim2.fromOffset(math.max(1, panelW - pad * 2), math.max(1, panelH - buttonH - pad - bottomPad - pad))
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	grid.CellSize = UDim2.fromOffset(cardW, cardH)
	if despawn and despawn:IsA("GuiObject") then
		despawn.Position = UDim2.new(0, pad, 1, -(buttonH + bottomPad))
		despawn.Size = UDim2.new(1, -pad * 2, 0, buttonH)
	end
	task.defer(function()
		if scroll and scroll.Parent and grid and grid.Parent then
			scroll.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + gap)
		end
	end)
end

local function carPanelRender()
	if not actionBody then return end
	local profile = readProfile() or {}
	local rows = carPanelOwnedRows(profile)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "VehicleCards"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = touch and 3 or 4
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.ZIndex = actionBody.ZIndex + 1
	scroll.Parent = actionBody
	local grid = Instance.new("UIGridLayout")
	grid.Name = "Grid"
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.Parent = scroll

	if #rows == 0 then
		local empty = makeLabel(scroll, "Empty", "NO OWNED VEHICLES", UDim2.new(1, -8, 0, 40), UDim2.fromOffset(4, 6), touch and 9 or 10, theme.Muted)
		empty.LayoutOrder = 1
	else
		for index, row in ipairs(rows) do
			local card = carPanelRenderCockpitCard(scroll, row, 120)
			card.LayoutOrder = index
		end
	end

	makeActionButton(actionBody, "DespawnVehicle", "DESPAWN", 0, theme.Exit, despawnVehicle)
	carPanelLayoutExisting()
end

local function carPanelSetChrome(enabled)
	if not actionTitle or not actionBody or not actionPanel then return end
	actionTitle.Visible = not enabled
	actionBody.Position = enabled and UDim2.fromOffset(0, 0) or UDim2.fromOffset(0, 42)
	actionBody.Size = enabled and UDim2.new(1, 0, 1, 0) or UDim2.new(1, 0, 1, -48)
	for _, name in ipairs({ "TopHighlight", "BottomShadow" }) do
		local item = actionPanel:FindFirstChild(name)
		if item and item:IsA("GuiObject") then
			item.Visible = not enabled
		end
	end
end

local function showActionPanel(kind)
	if activePanel == kind and actionPanel.Visible then
		actionPanel.Visible = false
		activePanel = nil
		return
	end
	activePanel = kind
	actionPanel.Visible = true
	clearActionBody()
	carPanelSetChrome(kind == "Car")
	if kind == "Car" then
		actionTitle.Text = ""
		carPanelRender()
	elseif kind == "Race" then
		actionTitle.Text = "RACE"
		makeLabel(actionBody, "RaceSoon", "Race cards and route tracking can go here next.", UDim2.new(1, -16, 0, 64), UDim2.fromOffset(8, 4), 10, theme.Text)
		makeActionButton(actionBody, "TrackRace", "TRACK RACE", 78, theme.Card, function()
			setStatus("RACE TRACKING NEXT", false)
		end)
	elseif kind == "Home" then
		actionTitle.Text = "HOME"
		makeActionButton(actionBody, "EnterMine", "ENTER GARAGE", 4, theme.Buy, function()
			local result = callInterior("VisitGarage", { OwnerUserId = player.UserId })
			setStatus(result.Ok and "ENTERED GARAGE" or ("ENTER FAILED: " .. tostring(result.Error)), result.Ok == true)
		end)
		makeActionButton(actionBody, "ReturnCity", "RETURN CITY", 42, theme.Back, function()
			local result = callInterior("ReturnToCity", { Source = "FreeRoamMapStack" })
			setStatus(result.Ok and "RETURNED TO CITY" or ("RETURN FAILED: " .. tostring(result.Error)), result.Ok == true)
		end)
	elseif kind == "Settings" then
		actionTitle.Text = "SETTINGS"
		makeLabel(actionBody, "SettingsSoon", "UI scale, audio, camera, and controls can live here later.", UDim2.new(1, -16, 0, 64), UDim2.fromOffset(8, 4), 10, theme.Text)
		makeActionButton(actionBody, "CloseSettings", "CLOSE", 78, theme.Back, function()
			actionPanel.Visible = false
			activePanel = nil
		end)
	elseif kind == "Shop" then
		actionTitle.Text = "SHOP"
		makeLabel(actionBody, "ShopText", "Open the existing dealership and customisation flow.", UDim2.new(1, -16, 0, 56), UDim2.fromOffset(8, 4), 10, theme.Text)
		makeActionButton(actionBody, "OpenShop", "OPEN SHOP", 70, theme.Buy, openDealership)
	end
end

local function makeStackButton(parent, name, iconValueName, fallbackText, callback, fullWidth)
	local button = Instance.new("TextButton")
	button.Name = name
	button.ZIndex = 8
	button.Parent = parent
	styleButton(button)
	attachIcon(button, iconValueName, fallbackText, 0.48)
	button.MouseButton1Click:Connect(callback)
	return button
end

local function ensureGui()
	if gui and gui.Parent then return end
	refreshTheme()
	gui = Instance.new("ScreenGui")
	gui.Name = "NTR_FreeRoamLeftNav"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = true
	gui.Parent = playerGui

	stack = Instance.new("Frame")
	stack.Name = "MapStack"
	stack.AnchorPoint = Vector2.new(1, 0)
	stack.BackgroundTransparency = 1
	stack.BorderSizePixel = 0
	stack.ZIndex = 7
	stack.Parent = gui

	mapFrame = Instance.new("Frame")
	mapFrame.Name = "MapFrame"
	mapFrame.BackgroundColor3 = theme.PanelSoft
	mapFrame.BackgroundTransparency = 0.04
	mapFrame.BorderSizePixel = 0
	mapFrame.ClipsDescendants = true
	mapFrame.ZIndex = 8
	mapFrame.Parent = stack
	corner(mapFrame, 7)
	stroke(mapFrame, Color3.fromRGB(230, 88, 205), 0.16, 2)
	bevel(mapFrame)

	mapImage = Instance.new("ImageLabel")
	mapImage.Name = "MapImage"
	mapImage.BackgroundTransparency = 1
	mapImage.AnchorPoint = Vector2.new(0.5, 0.5)
	mapImage.Position = UDim2.fromScale(0.5, 0.5)
	mapImage.Size = UDim2.fromScale(1.16, 1.16)
	mapImage.Image = assetImage(readString(config, "MapImage", ""))
	mapImage.ImageColor3 = theme.Muted
	mapImage.ImageTransparency = mapImage.Image == "" and 1 or 0
	mapImage.ZIndex = 9
	mapImage.Parent = mapFrame

	mapPlaceholder = makeLabel(mapFrame, "MapPlaceholder", "MAP", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), touch and 18 or 22, theme.Muted)
	mapPlaceholder.ZIndex = 10

	carButton = makeStackButton(stack, "CarButton", "CarIcon", "CAR", function()
		showActionPanel("Car")
	end, true)

	actionGrid = Instance.new("Frame")
	actionGrid.Name = "ActionGrid"
	actionGrid.BackgroundTransparency = 1
	actionGrid.BorderSizePixel = 0
	actionGrid.ZIndex = 8
	actionGrid.Parent = stack

	makeStackButton(actionGrid, "ShopButton", "DealershipIcon", "SHOP", function()
		showActionPanel("Shop")
	end)
	makeStackButton(actionGrid, "RaceButton", "RaceIcon", "RACE", function()
		local event = script.Parent:FindFirstChild("OpenRaceBrowser")
		if event and event:IsA("BindableEvent") then
			event:Fire()
		else
			showActionPanel("Race")
		end
	end)
	makeStackButton(actionGrid, "HomeButton", "GarageIcon", "HOME", function()
		showActionPanel("Home")
	end)
	makeStackButton(actionGrid, "SettingsButton", "SettingsIcon", "SET", function()
		showActionPanel("Settings")
	end)

	statusToast = makeLabel(stack, "StatusToast", "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 0), 10, theme.Accent)
	statusToast.BackgroundColor3 = theme.Panel
	statusToast.BackgroundTransparency = 0.18
	statusToast.BorderSizePixel = 0
	statusToast.Visible = false
	statusToast.ZIndex = 16
	corner(statusToast, 5)
	stroke(statusToast, theme.Accent, 0.5, 1)

	actionPanel = Instance.new("Frame")
	actionPanel.Name = "ActionPanel"
	actionPanel.AnchorPoint = Vector2.new(1, 0)
	actionPanel.BackgroundColor3 = theme.Panel
	actionPanel.BackgroundTransparency = theme.PanelTransparency
	actionPanel.BorderSizePixel = 0
	actionPanel.Visible = false
	actionPanel.ZIndex = 14
	actionPanel.Parent = gui
	corner(actionPanel, 7)
	stroke(actionPanel, Color3.fromRGB(230, 88, 205), 0.18, 2)
	bevel(actionPanel)
	actionTitle = makeLabel(actionPanel, "ActionTitle", "CAR", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 8), 12, theme.Text)
	actionTitle.ZIndex = 15
	actionBody = Instance.new("Frame")
	actionBody.Name = "ActionBody"
	actionBody.BackgroundTransparency = 1
	actionBody.Position = UDim2.fromOffset(0, 42)
	actionBody.Size = UDim2.new(1, 0, 1, -48)
	actionBody.ZIndex = 15
	actionBody.Parent = actionPanel

	player:SetAttribute("NTR_FreeRoamLeftNavReady", true)
	player:SetAttribute("NTR_FreeRoamMapStackReady", true)
end

local function layoutGridButton(name, x, y, w, h)
	local button = actionGrid:FindFirstChild(name)
	if button and button:IsA("GuiObject") then
		button.Position = UDim2.fromOffset(x, y)
		button.Size = UDim2.fromOffset(w, h)
	end
end

local function layoutButtonIcon(button)
	if not button then return end
	local icon = button:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") then
		local scale = tonumber(icon:GetAttribute("NTRIconScale")) or 0.5
		local side = math.floor(math.min(button.AbsoluteSize.X, button.AbsoluteSize.Y) * scale + 0.5)
		icon.Size = UDim2.fromOffset(math.max(18, side), math.max(18, side))
		icon.Position = UDim2.fromScale(0.5, 0.5)
	end
end

local function updateLayout()
	if not gui then return end
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local minW = readNumber(config, "MapStackMinWidth", 124)
	local maxW = touch and readNumber(config, "MapStackMaxWidthTouch", 148) or readNumber(config, "MapStackMaxWidthDesktop", 234)
	local fraction = touch and readNumber(config, "MapStackScreenWidthFractionTouch", 0.165) or readNumber(config, "MapStackScreenWidthFractionDesktop", 0.188)
	local stackW = math.floor(math.clamp(math.min(viewport.X * fraction, viewport.Y * 0.38), minW, maxW))
	local gap = readNumber(config, "MapStackGap", 6)
	local carH = touch and readNumber(config, "MapCarRowHeightTouch", 34) or readNumber(config, "MapCarRowHeightDesktop", 46)
	local rowH = touch and readNumber(config, "MapGridRowHeightTouch", 34) or readNumber(config, "MapGridRowHeightDesktop", 46)
	local topMargin = touch and readNumber(config, "MapStackTopMarginTouch", 8) or readNumber(config, "MapStackTopMarginDesktop", 18)
	local rightMargin = touch and readNumber(config, "MapStackRightMarginTouch", 8) or readNumber(config, "MapStackRightMarginDesktop", 18)
	local totalH = stackW + gap + carH + gap + rowH * 2 + gap

	stack.Position = UDim2.new(1, -rightMargin, 0, topMargin)
	stack.Size = UDim2.fromOffset(stackW, totalH)
	mapFrame.Position = UDim2.fromOffset(0, 0)
	mapFrame.Size = UDim2.fromOffset(stackW, stackW)
	carButton.Position = UDim2.fromOffset(0, stackW + gap)
	carButton.Size = UDim2.fromOffset(stackW, carH)
	updateCarButtonImage()
	layoutButtonIcon(carButton)
	actionGrid.Position = UDim2.fromOffset(0, stackW + gap + carH + gap)
	actionGrid.Size = UDim2.fromOffset(stackW, rowH * 2 + gap)
	local cellW = math.floor((stackW - gap) / 2)
	local rightW = stackW - gap - cellW
	layoutGridButton("ShopButton", 0, 0, cellW, rowH)
	layoutGridButton("RaceButton", cellW + gap, 0, rightW, rowH)
	layoutGridButton("HomeButton", 0, rowH + gap, cellW, rowH)
	layoutGridButton("SettingsButton", cellW + gap, rowH + gap, rightW, rowH)
	layoutButtonIcon(actionGrid:FindFirstChild("ShopButton"))
	layoutButtonIcon(actionGrid:FindFirstChild("RaceButton"))
	layoutButtonIcon(actionGrid:FindFirstChild("HomeButton"))
	layoutButtonIcon(actionGrid:FindFirstChild("SettingsButton"))
	statusToast.Position = UDim2.fromOffset(0, totalH - 22)
	statusToast.Size = UDim2.fromOffset(stackW, 22)

	local defaultPanelW = math.max(touch and 164 or 190, math.min(touch and 212 or 244, stackW * 0.98))
	local panelW = defaultPanelW
	if activePanel == "Car" and actionPanel.Visible then
		local columns = touch and carPanelNumber("CarPanelMobileColumns", 2) or carPanelNumber("CarPanelDesktopColumns", 3)
		columns = math.max(1, math.floor(columns + 0.5))
		local pad = carPanelNumber("CarPanelPadding", 8)
		local gap = carPanelNumber("CarPanelCardGap", 8)
		local maxCard = touch and carPanelNumber("CarPanelMaxCardWidthTouch", 118) or carPanelNumber("CarPanelMaxCardWidthDesktop", 146)
		local fittedW = pad * 2 + columns * maxCard + gap * math.max(columns - 1, 0)
		local desiredW = touch and carPanelNumber("CarPanelWidthTouch", fittedW) or fittedW
		local minPanelW = touch and carPanelNumber("CarPanelMinWidthTouch", math.min(240, fittedW)) or fittedW
		local maxAvailableW = math.max(minPanelW, viewport.X - rightMargin - stackW - 18)
		panelW = math.floor(math.clamp(desiredW, minPanelW, maxAvailableW))
	end
	actionPanel.Position = UDim2.new(1, -(rightMargin + stackW + 8), 0, topMargin)
	actionPanel.Size = UDim2.fromOffset(panelW, totalH)
	if activePanel == "Car" and actionPanel.Visible then
		carPanelLayoutExisting()
	end

	mapImage.Image = assetImage(readString(config, "MapImage", ""))
	mapImage.ImageTransparency = mapImage.Image == "" and 1 or 0
	mapPlaceholder.Visible = readBool(config, "ShowMapPlaceholderText", true) and mapImage.Image == ""
end

local function updateVisibility()
	ensureGui()
	gui.Enabled = readBool(config, "Enabled", true) and readBool(config, "MapStackEnabled", true) and shouldShowMapStack()
	if not gui.Enabled then
		actionPanel.Visible = false
		activePanel = nil
	end
	suppressLegacyUi()
	keepMobileDriveControls()
	updateLayout()
end

ensureGui()
updateLayout()
updateVisibility()

playerGui.ChildAdded:Connect(function()
	task.defer(updateVisibility)
end)

RunService.Heartbeat:Connect(updateVisibility)
