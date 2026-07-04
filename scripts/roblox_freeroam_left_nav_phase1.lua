-- Neo Tokyo Racers - Free Roam Left Navigation Phase 1
-- Dual-mode Studio Command Bar script.
--
-- Edit mode:
--   Installs ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav and an
--   isolated StarterPlayerScripts UI controller. It does not patch the large
--   dealership bootstrap.
--
-- Play mode, CLIENT Command Bar:
--   Smoke-checks the left-nav shell, config, old free-roam UI suppression,
--   garage remotes, and dealership open hook presence.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local TAG = "[NTR Free Roam Left Nav Phase 1]"

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
	assert(config:FindFirstChild("Enabled"), "FreeRoamNav.Enabled config value is missing.")

	local gui = player:WaitForChild("PlayerGui"):WaitForChild("NTR_FreeRoamLeftNav", 8)
	assert(gui and gui:IsA("ScreenGui"), "NTR_FreeRoamLeftNav did not appear in PlayerGui.")
	local rail = gui:WaitForChild("Rail", 4)
	local panel = gui:WaitForChild("Panel", 4)
	assert(rail and rail:IsA("Frame"), "Left nav rail missing.")
	assert(panel and panel:IsA("Frame"), "Left nav panel missing.")
	assert(player:GetAttribute("NTR_FreeRoamLeftNavReady") == true, "Ready attribute was not set.")
	info("Left-nav shell OK. buttons=" .. tostring(#rail:GetChildren()) .. " panel=" .. panel.Name)

	local remotes = waitForPath(kit, { "Shared", "Remotes", "Garage" })
	local garageInvoke = remotes:WaitForChild("GarageInvoke")
	local initial = garageInvoke:InvokeServer("GetInitial", {})
	assert(type(initial) == "table" and initial.Profile ~= nil, "Garage GetInitial failed.")
	info("Garage GetInitial OK for menu profile read.")

	local interiorInvoke = remotes:FindFirstChild("GarageInteriorInvoke")
	assert(interiorInvoke and interiorInvoke:IsA("RemoteFunction"), "GarageInteriorInvoke missing; garage/home menu cannot enter garages.")
	info("GarageInteriorInvoke present.")

	local playerScripts = player:WaitForChild("PlayerScripts")
	local intro = playerScripts:FindFirstChild("NeoTokyoRacersClient")
		and playerScripts.NeoTokyoRacersClient:FindFirstChild("Controllers")
		and playerScripts.NeoTokyoRacersClient.Controllers:FindFirstChild("Intro")
	local openEvent = intro and intro:FindFirstChild("OpenGarageFromIntro")
	assert(openEvent and openEvent:IsA("BindableEvent"), "OpenGarageFromIntro BindableEvent missing; Dealership button cannot reuse the existing flow.")
	info("Dealership open hook present.")

	info("Expected: left rail appears on the left, old top-right DriveMenu and old NTR_GarageAccessUI toggle are suppressed, and each button opens one themed panel.")
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
	local item = ensureChild(parent, "BoolValue", name)
	item.Value = value
	return item
end

local function ensureNumber(parent, name, value)
	local item = ensureChild(parent, "NumberValue", name)
	item.Value = value
	return item
end

local function ensureString(parent, name, value)
	local item = ensureChild(parent, "StringValue", name)
	item.Value = value
	return item
end

local kit = waitForPath(ReplicatedStorage, { "NeoTokyoRacers" })
local configRoot = ensureChild(kit, "Folder", "Config")
local uiConfig = ensureChild(configRoot, "Folder", "UI")
local navConfig = ensureChild(uiConfig, "Folder", "FreeRoamNav")
navConfig:SetAttribute("InstalledBy", "roblox_freeroam_left_nav_phase1")

ensureBool(navConfig, "Enabled", true)
ensureBool(navConfig, "HideLegacyDriveMenu", true)
ensureBool(navConfig, "HideLegacyGarageAccessUI", true)
ensureNumber(navConfig, "RailWidthDesktop", 58)
ensureNumber(navConfig, "RailWidthTouch", 64)
ensureNumber(navConfig, "PanelWidthDesktop", 304)
ensureNumber(navConfig, "PanelWidthTouch", 284)
ensureNumber(navConfig, "TopOffsetDesktop", 130)
ensureNumber(navConfig, "TopOffsetTouch", 96)
ensureString(navConfig, "UploadNote", "Upload assets/ui/icons/freeroam_nav_plain/freeroam_plain_*.png to Roblox, then paste rbxassetid:// IDs into the matching *Icon values.")
ensureString(navConfig, "CarIcon", "")
ensureString(navConfig, "RaceIcon", "")
ensureString(navConfig, "GarageIcon", "")
ensureString(navConfig, "SettingsIcon", "")
ensureString(navConfig, "DealershipIcon", "")

local starterScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientRoot = ensureChild(starterScripts, "Folder", "NeoTokyoRacersClient")
local controllers = ensureChild(clientRoot, "Folder", "Controllers")
local uiControllers = ensureChild(controllers, "Folder", "UI")
local scriptObject = ensureChild(uiControllers, "LocalScript", "FreeRoamNavController_Active")

scriptObject.Source = [=[-- NTR Free Roam Left Navigation Phase 1

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
local rail
local panel
local title
local subtitle
local body
local status
local activeMenu = nil
local cachedProfile = nil
local lastProfileRead = 0

local buttonDefs = {
	{ Id = "Car", Label = "CAR", Symbol = "CAR", IconValue = "CarIcon" },
	{ Id = "Race", Label = "RACE", Symbol = "RACE", IconValue = "RaceIcon" },
	{ Id = "Garage", Label = "GARAGE", Symbol = "HOME", IconValue = "GarageIcon" },
	{ Id = "Settings", Label = "SETTINGS", Symbol = "SET", IconValue = "SettingsIcon" },
	{ Id = "Dealership", Label = "DEALER", Symbol = "SHOP", IconValue = "DealershipIcon" },
}

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

local function stroke(parent, color, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or theme.Accent
	s.Thickness = 1
	s.Transparency = transparency or 0.2
	s.Parent = parent
	return s
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
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.GothamBold
	applyFont(label)
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, size, position, color, onClick)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or theme.Card
	button.BackgroundTransparency = theme.ButtonTransparency
	button.BorderSizePixel = 0
	button.Size = size
	button.Position = position
	button.Text = text
	button.TextColor3 = theme.Text
	button.TextSize = 11
	button.TextWrapped = true
	button.Font = Enum.Font.GothamBold
	applyFont(button)
	button.Parent = parent
	corner(button, 5)
	stroke(button, theme.Accent, 0.55)
	button.MouseButton1Click:Connect(function()
		local ok, err = pcall(onClick)
		if not ok then
			if status then
				status.TextColor3 = theme.Warn
				status.Text = tostring(err)
			end
		end
	end)
	return button
end

local function clearBody()
	if not body then return end
	for _, child in ipairs(body:GetChildren()) do
		child:Destroy()
	end
end

local function setStatus(message, good)
	if not status then return end
	status.TextColor3 = good and theme.Accent or theme.Warn
	status.Text = tostring(message or "")
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

local function isDealershipOpen()
	local garageGui = playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	return garageGui and garageGui:IsA("ScreenGui") and garageGui.Enabled
end

local function playerIsDriving()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
		return true
	end
	local driveGui = playerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD")
	return driveGui and driveGui.Enabled == true
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

local function openDealership()
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local intro = controllers and controllers:FindFirstChild("Intro")
	local event = intro and intro:FindFirstChild("OpenGarageFromIntro")
	if event and event:IsA("BindableEvent") then
		event:Fire()
		setStatus("OPENING DEALERSHIP", true)
	else
		setStatus("DEALERSHIP HOOK NOT READY", false)
	end
end

local function exitVehicle()
	local result = callGarage("ExitVehicle", {})
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.Sit = false end
	setStatus((result.Success == false and result.Message) or "EXIT VEHICLE SENT", result.Success ~= false)
end

local function renderCar()
	clearBody()
	title.Text = "CAR"
	subtitle.Text = "Your current vehicle and quick actions."
	local profile = readProfile() or {}
	local vehicleId = tostring(profile.CurrentVehicleId or profile.SelectedVehicleId or profile.CurrentCockpit or profile.SelectedCockpit or "CURRENT BUILD")
	makeLabel(body, "Current", "CURRENT: " .. vehicleId, UDim2.new(1, -16, 0, 42), UDim2.fromOffset(8, 4), 12, theme.Text)
	makeLabel(body, "Hint", "Use this menu for vehicle quick actions while driving. Full build editing still uses the dealership/customisation flow.", UDim2.new(1, -16, 0, 68), UDim2.fromOffset(8, 50), 10, theme.Muted)
	makeButton(body, "ExitVehicle", "EXIT VEHICLE", UDim2.new(1, -16, 0, 36), UDim2.fromOffset(8, 126), theme.Exit, exitVehicle)
	makeButton(body, "OpenDealership", "OPEN CUSTOMISE", UDim2.new(1, -16, 0, 36), UDim2.fromOffset(8, 170), theme.Buy, openDealership)
end

local function renderRace()
	clearBody()
	title.Text = "RACE"
	subtitle.Text = "Race finder shell for the next gameplay phase."
	makeLabel(body, "Soon", "Recommended contents: nearby races, route marker, class target, reward, entry button, and best-time panel.", UDim2.new(1, -16, 0, 84), UDim2.fromOffset(8, 4), 11, theme.Text)
	makeButton(body, "TrackNearest", "TRACK NEAREST RACE", UDim2.new(1, -16, 0, 36), UDim2.fromOffset(8, 100), theme.Card, function()
		setStatus("RACE TRACKING COMING NEXT", false)
	end)
end

local function renderGarage()
	clearBody()
	title.Text = "GARAGE / HOME"
	subtitle.Text = "Enter your garage or control access."
	local y = 6
	makeButton(body, "EnterMine", "ENTER MY GARAGE", UDim2.new(1, -16, 0, 36), UDim2.fromOffset(8, y), theme.Buy, function()
		local result = callInterior("VisitGarage", { OwnerUserId = player.UserId })
		setStatus(result.Ok and "ENTERED GARAGE" or ("ENTER FAILED: " .. tostring(result.Error)), result.Ok == true)
	end)
	y += 44
	makeButton(body, "SetPublic", "SET GARAGE PUBLIC", UDim2.new(1, -16, 0, 36), UDim2.fromOffset(8, y), theme.Selected, function()
		local result = callInterior("SetAccessMode", { AccessMode = "Public" })
		setStatus(result.Ok and "ACCESS PUBLIC" or ("ACCESS FAILED: " .. tostring(result.Error)), result.Ok == true)
	end)
	y += 44
	makeButton(body, "SetPrivate", "SET GARAGE PRIVATE", UDim2.new(1, -16, 0, 36), UDim2.fromOffset(8, y), theme.Back, function()
		local result = callInterior("SetAccessMode", { AccessMode = "Private" })
		setStatus(result.Ok and "ACCESS PRIVATE" or ("ACCESS FAILED: " .. tostring(result.Error)), result.Ok == true)
	end)
	y += 44
	makeButton(body, "ReturnCity", "RETURN TO CITY", UDim2.new(1, -16, 0, 36), UDim2.fromOffset(8, y), theme.Back, function()
		local result = callInterior("ReturnToCity", { Source = "FreeRoamLeftNav" })
		setStatus(result.Ok and "RETURNED TO CITY" or ("RETURN FAILED: " .. tostring(result.Error)), result.Ok == true)
	end)
	y += 48
	makeLabel(body, "Note", "This replaces the old right-side Garage Access MVP toggle. Rich garage property cards can move into this panel next.", UDim2.new(1, -16, 0, 62), UDim2.fromOffset(8, y), 10, theme.Muted)
end

local function renderSettings()
	clearBody()
	title.Text = "SETTINGS"
	subtitle.Text = "Player-facing preferences shell."
	makeLabel(body, "Prefs", "Good next contents: UI scale, camera assist strength, music/SFX, mobile controls visibility, and control hints.", UDim2.new(1, -16, 0, 84), UDim2.fromOffset(8, 4), 11, theme.Text)
	makeButton(body, "ClosePanel", "CLOSE MENU", UDim2.new(1, -16, 0, 36), UDim2.fromOffset(8, 100), theme.Back, function()
		activeMenu = nil
		panel.Visible = false
	end)
end

local function renderDealership()
	clearBody()
	title.Text = "DEALERSHIP"
	subtitle.Text = "Open the existing dealership/customisation flow."
	makeLabel(body, "DealerHint", "Uses the confirmed dealership intro open hook. If the desk gate blocks this later, switch this to set-route until the player reaches the dealership.", UDim2.new(1, -16, 0, 84), UDim2.fromOffset(8, 4), 11, theme.Text)
	makeButton(body, "OpenDealership", "OPEN DEALERSHIP", UDim2.new(1, -16, 0, 38), UDim2.fromOffset(8, 100), theme.Buy, openDealership)
end

local renderers = {
	Car = renderCar,
	Race = renderRace,
	Garage = renderGarage,
	Settings = renderSettings,
	Dealership = renderDealership,
}

local function selectMenu(id)
	if activeMenu == id and panel.Visible then
		activeMenu = nil
		panel.Visible = false
		return
	end
	activeMenu = id
	panel.Visible = true
	local renderer = renderers[id]
	if renderer then renderer() end
	setStatus("READY", true)
	for _, child in ipairs(rail:GetChildren()) do
		if child:IsA("TextButton") then
			child.BackgroundColor3 = child.Name == id .. "Button" and theme.Selected or theme.Card
		end
	end
end

local function makeRailButton(def, order)
	local size = touch and 54 or 48
	local button = Instance.new("TextButton")
	button.Name = def.Id .. "Button"
	button.LayoutOrder = order
	button.AutoButtonColor = true
	button.BackgroundColor3 = theme.Card
	button.BackgroundTransparency = theme.ButtonTransparency
	button.BorderSizePixel = 0
	button.Size = UDim2.fromOffset(size, size)
	button.Text = ""
	button.Parent = rail
	corner(button, 6)
	stroke(button, theme.Accent, 0.4)

	local imageId = readString(config, def.IconValue, "")
	if imageId ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Image = imageId
		icon.Size = UDim2.fromOffset(size - 14, size - 14)
		icon.Position = UDim2.fromOffset(7, 7)
		icon.Parent = button
	else
		local fallback = makeLabel(button, "Fallback", def.Symbol, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), touch and 10 or 9, theme.Accent)
		fallback.TextXAlignment = Enum.TextXAlignment.Center
	end

	button.MouseButton1Click:Connect(function()
		selectMenu(def.Id)
	end)
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
	gui.Enabled = readBool(config, "Enabled", true)
	gui.Parent = playerGui

	rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.AnchorPoint = Vector2.new(0, 0.5)
	rail.BackgroundColor3 = theme.Panel
	rail.BackgroundTransparency = theme.PanelTransparency
	rail.BorderSizePixel = 0
	rail.Parent = gui
	corner(rail, 7)
	stroke(rail, theme.Accent, 0.2)

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = rail

	for index, def in ipairs(buttonDefs) do
		makeRailButton(def, index)
	end

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = theme.Panel
	panel.BackgroundTransparency = theme.PanelTransparency
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 7)
	stroke(panel, theme.Accent, 0.18)

	title = makeLabel(panel, "Title", "CAR", UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 10), 15, theme.Text)
	subtitle = makeLabel(panel, "Subtitle", "", UDim2.new(1, -20, 0, 42), UDim2.fromOffset(10, 40), 10, theme.Muted)
	body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 88)
	body.Size = UDim2.new(1, 0, 1, -122)
	body.Parent = panel
	status = makeLabel(panel, "Status", "READY", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 1, -30), 10, theme.Accent)

	player:SetAttribute("NTR_FreeRoamLeftNavReady", true)
end

local function updateLayout()
	if not gui then return end
	local railWidth = touch and readNumber(config, "RailWidthTouch", 64) or readNumber(config, "RailWidthDesktop", 58)
	local panelWidth = touch and readNumber(config, "PanelWidthTouch", 284) or readNumber(config, "PanelWidthDesktop", 304)
	local topOffset = touch and readNumber(config, "TopOffsetTouch", 96) or readNumber(config, "TopOffsetDesktop", 130)
	local railButtonSize = touch and 54 or 48
	local railHeight = (#buttonDefs * railButtonSize) + ((#buttonDefs - 1) * 8) + 20
	rail.Position = UDim2.new(0, 14, 0.5, math.max(0, topOffset - 180))
	rail.Size = UDim2.fromOffset(railWidth, railHeight)
	panel.Position = UDim2.new(0, 14 + railWidth + 10, 0.5, math.max(0, topOffset - 180))
	panel.Size = UDim2.fromOffset(panelWidth, touch and 322 or 338)
end

local function updateVisibility()
	ensureGui()
	gui.Enabled = readBool(config, "Enabled", true) and not isDealershipOpen()
	if not gui.Enabled then
		panel.Visible = false
	end
	suppressLegacyUi()
	updateLayout()
end

ensureGui()
updateLayout()
updateVisibility()

playerGui.ChildAdded:Connect(function()
	task.defer(updateVisibility)
end)

RunService.Heartbeat:Connect(function()
	updateVisibility()
end)
]=]

scriptObject.Disabled = false
scriptObject:SetAttribute("FreeRoamLeftNavPhase1", true)
scriptObject:SetAttribute("InstalledBy", "roblox_freeroam_left_nav_phase1")

info("Installed isolated FreeRoamNavController_Active and config at ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.")
info("Upload assets/ui/icons/freeroam_nav_plain/freeroam_plain_*.png to Roblox and paste rbxassetid:// IDs into the matching *Icon StringValues.")
info("In Play, run this same script from the CLIENT Command Bar for the smoke check.")
