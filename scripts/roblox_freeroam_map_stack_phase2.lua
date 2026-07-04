-- Neo Tokyo Racers - Free Roam Map Stack Phase 2
-- Dual-mode Studio Command Bar script.
--
-- Edit mode:
--   Replaces only the isolated FreeRoamNavController_Active source with a
--   top-right minimap placeholder + free-roam action stack. It does not patch
--   the large dealership bootstrap.
--
-- Play mode, CLIENT Command Bar:
--   Smoke-checks the top-right map stack shell, button layout, old free-roam UI
--   suppression, garage remotes, and dealership open hook presence.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local TAG = "[NTR Free Roam Map Stack Phase 2]"

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

if RunService:IsRunning() then
	local player = Players.LocalPlayer
	assert(player, "Run this smoke from the CLIENT Command Bar during Play.")

	local kit = waitForPath(ReplicatedStorage, { "NeoTokyoRacers" })
	local config = waitForPath(kit, { "Config", "UI", "FreeRoamNav" })
	assert(config:FindFirstChild("MapStackEnabled"), "FreeRoamNav.MapStackEnabled config value is missing.")

	local gui = player:WaitForChild("PlayerGui"):WaitForChild("NTR_FreeRoamLeftNav", 8)
	assert(gui and gui:IsA("ScreenGui"), "NTR_FreeRoamLeftNav did not appear in PlayerGui.")
	local stack = gui:WaitForChild("MapStack", 4)
	local map = stack:WaitForChild("MapFrame", 4)
	local car = stack:WaitForChild("CarButton", 4)
	local grid = stack:WaitForChild("ActionGrid", 4)
	assert(stack and stack:IsA("Frame"), "MapStack missing.")
	assert(map and map:IsA("Frame"), "MapFrame missing.")
	assert(car and car:IsA("TextButton"), "CarButton missing.")
	assert(grid and grid:IsA("Frame"), "ActionGrid missing.")
	assert(grid:FindFirstChild("ShopButton"), "ShopButton missing.")
	assert(grid:FindFirstChild("RaceButton"), "RaceButton missing.")
	assert(grid:FindFirstChild("HomeButton"), "HomeButton missing.")
	assert(grid:FindFirstChild("SettingsButton"), "SettingsButton missing.")
	assert(player:GetAttribute("NTR_FreeRoamMapStackReady") == true, "Map stack ready attribute was not set.")
	info("Map stack shell OK. map=" .. tostring(map.AbsoluteSize.X) .. "x" .. tostring(map.AbsoluteSize.Y))

	local remotes = waitForPath(kit, { "Shared", "Remotes", "Garage" })
	local garageInvoke = remotes:WaitForChild("GarageInvoke")
	local initial = garageInvoke:InvokeServer("GetInitial", {})
	assert(type(initial) == "table" and initial.Profile ~= nil, "Garage GetInitial failed.")
	info("Garage GetInitial OK for free-roam action stack.")

	local interiorInvoke = remotes:FindFirstChild("GarageInteriorInvoke")
	assert(interiorInvoke and interiorInvoke:IsA("RemoteFunction"), "GarageInteriorInvoke missing; Home button cannot enter garages.")
	info("GarageInteriorInvoke present.")

	local playerScripts = player:WaitForChild("PlayerScripts")
	local intro = playerScripts:FindFirstChild("NeoTokyoRacersClient")
		and playerScripts.NeoTokyoRacersClient:FindFirstChild("Controllers")
		and playerScripts.NeoTokyoRacersClient.Controllers:FindFirstChild("Intro")
	local openEvent = intro and intro:FindFirstChild("OpenGarageFromIntro")
	assert(openEvent and openEvent:IsA("BindableEvent"), "OpenGarageFromIntro BindableEvent missing; Shop button cannot reuse the existing dealership flow.")
	info("Dealership open hook present.")

	if game:GetService("UserInputService").TouchEnabled then
		local mobileGui = player:WaitForChild("PlayerGui"):FindFirstChild("HOVER_RACING_V67_MobileDriveControlsUI")
		local mobileRoot = mobileGui and mobileGui:FindFirstChild("Root")
		local driveGui = player.PlayerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD")
		local garageVisible = false
		for _, guiObject in ipairs(player.PlayerGui:GetChildren()) do
			if guiObject:IsA("ScreenGui") and guiObject.Enabled then
				local rootObject = guiObject:FindFirstChild("GarageRoot", true) or guiObject:FindFirstChild("DealershipRoot", true)
				if rootObject and rootObject:IsA("GuiObject") and rootObject.Visible then
					garageVisible = true
					break
				end
			end
		end
		local mobileState
		pcall(function()
			mobileState = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("MobileDriveInputState"))
		end)
		if type(mobileState) == "table" and driveGui and driveGui.Enabled == true and not garageVisible then
			mobileState.IsDriving = true
			task.wait(0.15)
		end
		info("Mobile diagnostic: IsDriving=" .. tostring(type(mobileState) == "table" and mobileState.IsDriving)
			.. " mobileGuiEnabled=" .. tostring(mobileGui and mobileGui.Enabled)
			.. " mobileRootVisible=" .. tostring(mobileRoot and mobileRoot.Visible)
			.. " driveGuiEnabled=" .. tostring(driveGui and driveGui.Enabled)
			.. " garageVisible=" .. tostring(garageVisible))
	end

	info("Expected: top-right square map placeholder, full-width car button, 2x2 Shop/Race/Home/Settings buttons, and no old top-right DriveMenu or old NTR_GarageAccessUI toggle.")
	return
end

local function ensureChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, existing:GetFullName() .. " must be a " .. className)
		return existing
	end
	local child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function ensureBool(parent, name, value)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("BoolValue"), existing:GetFullName() .. " must be a BoolValue")
		return existing
	end
	local item = Instance.new("BoolValue")
	item.Name = name
	item.Value = value
	item.Parent = parent
	return item
end

local function ensureNumber(parent, name, value)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("NumberValue"), existing:GetFullName() .. " must be a NumberValue")
		return existing
	end
	local item = Instance.new("NumberValue")
	item.Name = name
	item.Value = value
	item.Parent = parent
	return item
end

local function ensureColor3(parent, name, value)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Color3Value"), existing:GetFullName() .. " must be a Color3Value")
		return existing
	end
	local item = Instance.new("Color3Value")
	item.Name = name
	item.Value = value
	item.Parent = parent
	return item
end

local function ensureString(parent, name, value)
	local item = ensureChild(parent, "StringValue", name)
	if item.Value == "" then
		item.Value = value
	end
	return item
end

local kit = waitForPath(ReplicatedStorage, { "NeoTokyoRacers" })
local configRoot = ensureChild(kit, "Folder", "Config")
local uiConfig = ensureChild(configRoot, "Folder", "UI")
local navConfig = ensureChild(uiConfig, "Folder", "FreeRoamNav")
navConfig:SetAttribute("InstalledBy", "roblox_freeroam_map_stack_phase2")

ensureBool(navConfig, "Enabled", true)
ensureBool(navConfig, "MapStackEnabled", true)
ensureBool(navConfig, "HideLegacyDriveMenu", true)
ensureBool(navConfig, "HideLegacyGarageAccessUI", true)
ensureBool(navConfig, "ShowMapPlaceholderText", true)
ensureNumber(navConfig, "MapStackMaxWidthDesktop", 234)
ensureNumber(navConfig, "MapStackMaxWidthTouch", 148)
ensureNumber(navConfig, "MapStackMinWidth", 124)
ensureNumber(navConfig, "MapStackScreenWidthFractionDesktop", 0.188)
ensureNumber(navConfig, "MapStackScreenWidthFractionTouch", 0.165)
ensureNumber(navConfig, "MapStackTopMarginDesktop", 18)
ensureNumber(navConfig, "MapStackTopMarginTouch", 8)
ensureNumber(navConfig, "MapStackRightMarginDesktop", 18)
ensureNumber(navConfig, "MapStackRightMarginTouch", 8)
ensureNumber(navConfig, "MapStackGap", 6)
ensureNumber(navConfig, "MapCarRowHeightDesktop", 46)
ensureNumber(navConfig, "MapCarRowHeightTouch", 34)
ensureNumber(navConfig, "MapGridRowHeightDesktop", 46)
ensureNumber(navConfig, "MapGridRowHeightTouch", 34)
ensureNumber(navConfig, "ButtonGradientRotation", 135)
ensureNumber(navConfig, "ButtonFillInset", 2)
ensureNumber(navConfig, "ButtonBaseTransparency", 0.08)
ensureNumber(navConfig, "ButtonOutlineThickness", 2.4)
ensureNumber(navConfig, "ButtonOutlineTransparency", 0)
ensureNumber(navConfig, "ButtonHoverOverlayTransparency", 0.82)
ensureColor3(navConfig, "ButtonBaseColor", Color3.fromRGB(21, 31, 37))
ensureColor3(navConfig, "ButtonGradientTopLeft", Color3.fromRGB(62, 35, 58))
ensureColor3(navConfig, "ButtonGradientBottomRight", Color3.fromRGB(6, 16, 18))
ensureColor3(navConfig, "ButtonOutline", Color3.fromRGB(230, 88, 205))
ensureBool(navConfig, "TextGlowEnabled", true)
ensureNumber(navConfig, "TextGlowTransparency", 0.25)
ensureNumber(navConfig, "TextGlowThickness", 1.4)
ensureColor3(navConfig, "TextGlowColor", Color3.fromRGB(255, 120, 235))
ensureString(navConfig, "UploadNote", "Upload assets/ui/icons/freeroam_nav_plain/freeroam_plain_*.png to Roblox, then paste rbxassetid:// IDs into the matching *Icon values.")
ensureString(navConfig, "CarIcon", "")
ensureString(navConfig, "RaceIcon", "")
ensureString(navConfig, "GarageIcon", "")
ensureString(navConfig, "SettingsIcon", "")
ensureString(navConfig, "DealershipIcon", "")
ensureString(navConfig, "MapImage", "")

local starterScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientRoot = ensureChild(starterScripts, "Folder", "NeoTokyoRacersClient")
local controllers = ensureChild(clientRoot, "Folder", "Controllers")
local uiControllers = ensureChild(controllers, "Folder", "UI")
local scriptObject = ensureChild(uiControllers, "LocalScript", "FreeRoamNavController_Active")

scriptObject.Source = [=[-- NTR Free Roam Map Stack Phase 2

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

local function showActionPanel(kind)
	if activePanel == kind and actionPanel.Visible then
		actionPanel.Visible = false
		activePanel = nil
		return
	end
	activePanel = kind
	actionPanel.Visible = true
	clearActionBody()
	if kind == "Car" then
		actionTitle.Text = "CAR"
		local profile = readProfile() or {}
		local vehicleId = tostring(profile.CurrentVehicleId or profile.SelectedVehicleId or profile.CurrentCockpit or profile.SelectedCockpit or "CURRENT BUILD")
		makeLabel(actionBody, "Current", vehicleId, UDim2.new(1, -16, 0, 42), UDim2.fromOffset(8, 0), 10, theme.Text)
		makeActionButton(actionBody, "ExitVehicle", "EXIT VEHICLE", 50, theme.Exit, exitVehicle)
		makeActionButton(actionBody, "Customise", "CUSTOMISE", 88, theme.Buy, openDealership)
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
		showActionPanel("Race")
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

	local panelW = math.max(touch and 164 or 190, math.min(touch and 212 or 244, stackW * 0.98))
	actionPanel.Position = UDim2.new(1, -(rightMargin + stackW + 8), 0, topMargin)
	actionPanel.Size = UDim2.fromOffset(panelW, totalH)

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
]=]

scriptObject.Disabled = false
scriptObject:SetAttribute("FreeRoamMapStackPhase2", true)
scriptObject:SetAttribute("FreeRoamLeftNavPhase1", false)
scriptObject:SetAttribute("InstalledBy", "roblox_freeroam_map_stack_phase2")

local function patchMobileDriveControls()
	local runtimeControllers = controllers:FindFirstChild("Runtime")
	local mobileScript = runtimeControllers and runtimeControllers:FindFirstChild("MobileDriveControlsController_Active")
	if not (mobileScript and mobileScript:IsA("LocalScript")) then
		info("MobileDriveControlsController_Active was not found; skipped mobile control polish.")
		return
	end

	local source = mobileScript.Source
	local oldTheme = [[local HUD_PANEL = Color3.fromRGB(5, 9, 7)
local HUD_PANEL_SOFT = Color3.fromRGB(13, 25, 21)
local HUD_TEXT = Color3.fromRGB(218, 255, 231)
local HUD_ACCENT = Color3.fromRGB(172, 255, 197)
local HUD_RED = Color3.fromRGB(194, 67, 62)]]
	local newTheme = [[local function themeColor(name, fallback, alternate)
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local themeFolder = kit and kit:FindFirstChild("Config") and kit.Config:FindFirstChild("UI") and kit.Config.UI:FindFirstChild("Theme")
	local item = themeFolder and (themeFolder:FindFirstChild(name) or (alternate and themeFolder:FindFirstChild(alternate)))
	return item and item:IsA("Color3Value") and item.Value or fallback
end

local HUD_PANEL = themeColor("Panel", Color3.fromRGB(5, 9, 7))
local HUD_PANEL_SOFT = themeColor("Card", Color3.fromRGB(24, 35, 42))
local HUD_TEXT = themeColor("Text", Color3.fromRGB(218, 255, 231))
local HUD_ACCENT = themeColor("Accent", Color3.fromRGB(172, 255, 197))
local HUD_RED = themeColor("Exit", Color3.fromRGB(194, 67, 62), "Danger")
local HUD_PINK = themeColor("Selected", Color3.fromRGB(230, 88, 205), "CardHot")]]
	if source:find(oldTheme, 1, true) then
		source = source:gsub(oldTheme:gsub("([^%w])", "%%%1"), newTheme, 1)
	end

	local oldShouldShow = [[local function shouldShow()
	return TOUCH and M.IsDriving == true and not findGarageVisible()
end]]
	local newShouldShow = [[local function playerLooksDriving()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
		return true
	end
	local driveGui = playerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD")
	return driveGui and driveGui.Enabled == true
end

local function shouldShow()
	return TOUCH and (M.IsDriving == true or playerLooksDriving()) and not findGarageVisible()
end]]
	if source:find(oldShouldShow, 1, true) then
		source = source:gsub(oldShouldShow:gsub("([^%w])", "%%%1"), newShouldShow, 1)
	end

	local missingHudHelpers = source:find("local function findDriveHudCandidates()", 1, true) == nil
		and source:find("local hiddenDesktop = {}", 1, true) ~= nil
	if missingHudHelpers then
		local hudInsertAt = source:find("local hiddenDesktop = {}", 1, true)
		local hudHelpers = [[local function lowerText(value)
	return string.lower(tostring(value or ""))
end

local function isOwnMobileUi(item)
	return item == gui or item == root or item:IsDescendantOf(root) or item:IsDescendantOf(gui)
end

local function textLooksLikeDesktopDriveHud(item)
	if not (item:IsA("TextLabel") or item:IsA("TextButton")) then return false end
	local text = lowerText(item.Text)
	if text == "" then return false end
	return string.find(text, "wasd", 1, true) ~= nil
		or string.find(text, "shift", 1, true) ~= nil
		or string.find(text, "space", 1, true) ~= nil
		or string.find(text, "speed", 1, true) ~= nil
		or string.find(text, "drift", 1, true) ~= nil
		or string.find(text, "mph", 1, true) ~= nil
end

local function nameLooksLikeDesktopDriveHud(item)
	local name = lowerText(item.Name)
	return string.find(name, "desktopdrive", 1, true) ~= nil
		or string.find(name, "drivepanel", 1, true) ~= nil
		or string.find(name, "speedpanel", 1, true) ~= nil
		or string.find(name, "boostpanel", 1, true) ~= nil
		or string.find(name, "speedhud", 1, true) ~= nil
		or string.find(name, "boosthud", 1, true) ~= nil
		or string.find(name, "controlshint", 1, true) ~= nil
end

local function descendantLooksLikeDesktopDriveHud(item)
	for _, descendant in ipairs(item:GetDescendants()) do
		if descendant:IsA("GuiObject") and not isOwnMobileUi(descendant) then
			local name = lowerText(descendant.Name)
			if nameLooksLikeDesktopDriveHud(descendant)
				or string.find(name, "speedlabel", 1, true) ~= nil
				or string.find(name, "driftlabel", 1, true) ~= nil
				or textLooksLikeDesktopDriveHud(descendant) then
				return true
			end
		end
	end
	return false
end

local function nearestSmallDesktopPanel(item)
	local current = item
	local best = item
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not isOwnMobileUi(current) then
			local name = lowerText(current.Name)
			if name ~= "drivehud" and name ~= "root" then
				best = current
			end
			if current:IsA("Frame") and name ~= "drivehud" and name ~= "root" then
				local styled = current.BackgroundTransparency < 1
					or current:FindFirstChildOfClass("UICorner") ~= nil
					or current:FindFirstChildOfClass("UIStroke") ~= nil
				if styled then
					return current
				end
			end
		end
		current = current.Parent
	end
	return best
end

local function findDriveHudCandidates()
	local results = {}
	local seen = {}
	local function add(item)
		if item and item:IsA("GuiObject") and not isOwnMobileUi(item) and not seen[item] then
			seen[item] = true
			table.insert(results, item)
		end
	end

	for _, item in ipairs(playerGui:GetDescendants()) do
		if item:IsA("GuiObject") and not isOwnMobileUi(item) then
			if nameLooksLikeDesktopDriveHud(item) then
				add(item)
			elseif textLooksLikeDesktopDriveHud(item) then
				add(nearestSmallDesktopPanel(item))
			elseif item:IsA("Frame") and descendantLooksLikeDesktopDriveHud(item) then
				add(item)
			end
		end
	end

	return results
end

]]
		source = source:sub(1, hudInsertAt - 1) .. hudHelpers .. source:sub(hudInsertAt)
	end

	local newGarageVisible = [[local function findGarageVisible()
	for _, guiObject in ipairs(playerGui:GetChildren()) do
		if guiObject:IsA("ScreenGui") and guiObject.Enabled then
			local name = string.lower(guiObject.Name)
			if name ~= "ntr_freeroamleftnav"
				and name ~= "hover_racing_v2_drivehud"
				and name ~= "hover_racing_v67_mobiledrivecontrolsui" then
				local rootObject = guiObject:FindFirstChild("GarageRoot", true) or guiObject:FindFirstChild("DealershipRoot", true)
				if rootObject and rootObject:IsA("GuiObject") and rootObject.Visible then
					return true
				end
			end
		end
	end
	return false
end
]]
	local oldGarageVisible = [[local function findGarageVisible()
	for _, guiObject in ipairs(playerGui:GetChildren()) do
		if guiObject:IsA("ScreenGui") and guiObject.Enabled then
			local name = string.lower(guiObject.Name)
			if string.find(name, "garage", 1, true) or string.find(name, "dealership", 1, true) then
				return true
			end
			local rootObject = guiObject:FindFirstChild("GarageRoot", true) or guiObject:FindFirstChild("DealershipRoot", true)
			if rootObject and rootObject:IsA("GuiObject") and rootObject.Visible then
				return true
			end
		end
	end
	return false
end
]]
	if source:find(oldGarageVisible, 1, true) then
		source = source:gsub(oldGarageVisible:gsub("([^%w])", "%%%1"), newGarageVisible, 1)
	elseif not source:find(newGarageVisible, 1, true) then
		error("Could not find a safe MobileDriveControlsController garage visibility block.")
	end

	local layoutStart = source:find("local function layout()", 1, true)
	local layoutEnd = source:find("\nlocal cameraConnection", layoutStart or 1, true)
	assert(layoutStart and layoutEnd, "Could not find MobileDriveControlsController layout block.")
	local newLayout = [[local function layout()
	local camera = Workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local width = math.max(size.X, 1)
	local height = math.max(size.Y, 1)
	local tiny = width < 740 or height < 430
	local edge = tiny and 8 or 10
	local gap = tiny and 5 or 7

	local navConfig = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
		and ReplicatedStorage.NeoTokyoRacers:FindFirstChild("Config")
		and ReplicatedStorage.NeoTokyoRacers.Config:FindFirstChild("UI")
		and ReplicatedStorage.NeoTokyoRacers.Config.UI:FindFirstChild("FreeRoamNav")
	local mapRightEdge = edge
	if navConfig then
		local item = navConfig:FindFirstChild("MapStackRightMarginTouch")
		if item and item:IsA("NumberValue") then
			mapRightEdge = math.max(0, item.Value)
		end
	end

	local configuredSize = configNumber("ThumbstickSizePixels", 118, 82, 180)
	local innerScale = configNumber("ThumbstickInnerScale", 1.4, 1, 1.6)
	local thumbSize = math.floor(math.clamp(configuredSize * innerScale * (tiny and 0.72 or 0.9), 92, 190) + 0.5)
	local knobSize = math.floor(thumbSize * 0.42 + 0.5)
	local outerScale = configNumber("ThumbstickOuterRingScale", 1.5, 1.25, 1.75)
	local outerSize = math.floor(thumbSize * outerScale + 0.5)
	thumbTravelPixels = math.max((outerSize - knobSize) * 0.5, 1)
	thumbDriftThreshold = math.clamp(configNumber("DriftEnterThreshold", 0.90, 0.65, 0.98), 0.05, 0.98)
	local hitMultiplier = configNumber("TouchHitAreaMultiplier", 1.05, 1, 1.2)
	local hitSize = math.floor(outerSize * hitMultiplier + 0.5)

	leftPanel.Position = UDim2.fromOffset(0, 0)
	leftPanel.Size = UDim2.fromOffset(width, height)

	local boostW = math.floor(math.clamp(width * (tiny and 0.17 or 0.15), 94, 142) + 0.5)
	local boostH = tiny and 32 or 38
	local mphH = tiny and 18 or 22
	local boostX = math.floor((width - boostW) * 0.5)
	local boostY = height - edge - boostH

	mphLabel.Position = UDim2.fromOffset(boostX, boostY - mphH - 3)
	mphLabel.Size = UDim2.fromOffset(boostW, mphH)
	mphLabel.TextSize = tiny and 12 or 14
	boostButton.Position = UDim2.fromOffset(boostX, boostY)
	boostButton.Size = UDim2.fromOffset(boostW, boostH)
	boostButton.BackgroundColor3 = HUD_PANEL_SOFT
	boostText.TextSize = tiny and 10 or 11

	thumbHitArea.Position = UDim2.fromOffset(edge, height - edge - hitSize)
	thumbHitArea.Size = UDim2.fromOffset(hitSize, hitSize)
	thumbOuterRing.Size = UDim2.fromOffset(outerSize, outerSize)
	thumbBase.Size = UDim2.fromOffset(thumbSize, thumbSize)
	thumbKnob.Size = UDim2.fromOffset(knobSize, knobSize)
	driftText.TextSize = tiny and 8 or 9
	setThumbVisual(M.Steer or 0, M.Drift == true)

	local pedalScale = configNumber("PedalScale", 1.275, 1, 1.75)
	local baseAccelW = math.clamp(width * 0.088, tiny and 46 or 56, tiny and 64 or 78)
	local baseAccelH = math.clamp(height * 0.17, tiny and 76 or 96, tiny and 108 or 132)
	local accelW = math.floor(math.min(baseAccelW * pedalScale, width * 0.14) + 0.5)
	local accelH = math.floor(math.min(baseAccelH * pedalScale, height * 0.31) + 0.5)
	local brakeW = math.floor(accelW * 0.82 + 0.5)
	local brakeH = math.floor(accelH * 0.82 + 0.5)
	local pedalW = accelW + brakeW + gap

	rightPanel.Position = UDim2.fromOffset(width - mapRightEdge - pedalW, height - edge - accelH)
	rightPanel.Size = UDim2.fromOffset(pedalW, accelH)
	brake.Position = UDim2.fromOffset(0, accelH - brakeH)
	brake.Size = UDim2.fromOffset(brakeW, brakeH)
	accel.Position = UDim2.fromOffset(brakeW + gap, 0)
	accel.Size = UDim2.fromOffset(accelW, accelH)

	local accelPad = accel:FindFirstChild("RubberPad")
	if accelPad then
		local s = accelPad:FindFirstChild("HUDStroke")
		if s then s.Color = HUD_PINK end
	end
	local brakePad = brake:FindFirstChild("RubberPad")
	if brakePad then
		local s = brakePad:FindFirstChild("HUDStroke")
		if s then s.Color = HUD_PINK end
	end
end]]
	source = source:sub(1, layoutStart - 1) .. newLayout .. source:sub(layoutEnd)
	mobileScript.Source = source
	mobileScript:SetAttribute("FreeRoamMapStackPhase22MobilePolish", true)
	mobileScript:SetAttribute("FreeRoamMapStackPhase24MobileVisibility", true)
	mobileScript:SetAttribute("FreeRoamMapStackPhase25MobileHelperRepair", true)
	info("Patched MobileDriveControlsController_Active for edge layout, themed colours, centre boost, visible-root menu gating, and helper repair.")
end

patchMobileDriveControls()

info("Installed top-right map stack layout in isolated FreeRoamNavController_Active.")
info("The map is a placeholder only. Later, set FreeRoamNav.MapImage and calibration values in a minimap phase.")
info("In Play, run this same script from the CLIENT Command Bar for the smoke check.")
