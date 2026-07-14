-- NTR_PC_FREEROAM_UI_PHASE4A_DEALERSHIP_TELEPORT
-- NTR_RACING_UI_PHASE16D_PRESENTATION_PERFORMANCE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local desktopInputEligible = UserInputService.KeyboardEnabled or UserInputService.MouseEnabled
if UserInputService.TouchEnabled and not desktopInputEligible then
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("DesktopFreeRoamHud")
local racingPerformanceConfig = kit:WaitForChild("Config"):WaitForChild("Racing"):WaitForChild("PresentationPerformance")
local colours = config:WaitForChild("Colours")
local layoutConfig = config:WaitForChild("Layout")
local assetConfig = config:WaitForChild("Assets")
local defaults = config:WaitForChild("Defaults")
local typography = config:WaitForChild("Typography")
local effects = config:WaitForChild("Effects")
local garageRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage")
local garageInvoke = garageRemotes:WaitForChild("GarageInvoke")
local teleportInvoke = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI"):WaitForChild("FreeRoamHudTeleportInvoke")
local interiorInvoke = garageRemotes:FindFirstChild("GarageInteriorInvoke")
local categoriesRoot = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local mobileDriveInputState = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("MobileDriveInputState"))

local FONT = Enum.Font.Michroma
local BODY_FONT = Enum.Font.Michroma
local gui
local root
local rootScale
local actionBar
local leftCluster
local moneyLabel
local minimap
local mapCanvas
local playerMarker
local northArrow
local mapMissingLabel
local displayedMapPosition
local displayedPlayerHeading
local bottomActions
local controlsButton
local exitButton
local telemetry
local mphLabel
local boostIconBox
local boostIconImage
local boostTrack
local boostFill
local displayedBoostAlpha = 1
local gaugeSegments = {}
local carPanel
local carScroll
local carContent
local carGrid
local carButton
local categoryButton
local sortButton
local despawnButton
local modalLayer
local modalBackdrop
local modalPanels = {}
local choiceList
local choiceAnchor
local toast
local racingPresentationActive = false -- NTR_PC_FREEROAM_RACING_PRESENTATION_BRIDGE
local racingTelemetryOnly = false
local presentationOwners = {} -- NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP
local activeModal
local selectedCategory = "ALL"
local selectedSort = "RATING"
local cachedInitial
local cachedProfile
local cachedCatalog
local lastProfileRead = 0
local profileReadPending = false
local majorMenuOpen = false
local nextVisibilityScan = 0
local busy = false
local lastViewport = Vector2.zero

local function readValue(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item.Value ~= nil and item.Value or fallback
end

local function C(name, fallback)
	return readValue(colours, name, fallback)
end

local function L(name, fallback)
	return tonumber(readValue(layoutConfig, name, fallback)) or fallback
end

local function T(name, fallback)
	return tonumber(readValue(typography, name, fallback)) or fallback
end

local function E(name, fallback)
	return tonumber(readValue(effects, name, fallback)) or fallback
end

local function B(folder, name, fallback)
	local value = readValue(folder, name, fallback)
	return value == true
end

FONT = Enum.Font[tostring(readValue(typography, "PrimaryFont", "Michroma"))] or Enum.Font.Michroma
BODY_FONT = Enum.Font[tostring(readValue(typography, "BodyFont", "Michroma"))] or FONT

local function fontFace(font, role)
	local base = Font.fromEnum(font or FONT)
	local weight = B(typography, role .. "Bold", false) and Enum.FontWeight.Bold or Enum.FontWeight.Regular
	local style = B(typography, role .. "Italic", false) and Enum.FontStyle.Italic or Enum.FontStyle.Normal
	return Font.new(base.Family, weight, style)
end

local function roleForSize(textSize)
	for _, role in ipairs({ "Heading", "Body", "Caption", "Metric", "MetricUnit", "CashMetric" }) do
		if textSize == T(role, -1) then return role end
	end
	return "Body"
end

local function asset(name)
	local text = tostring(readValue(assetConfig, name, "") or "")
	if text == "" then return "" end
	if tonumber(text) then return "rbxassetid://" .. text end
	return text
end

local function new(className, props, parent)
	local item = Instance.new(className)
	for key, value in pairs(props or {}) do item[key] = value end
	item.Parent = parent
	return item
end

local function corner(parent, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function stroke(parent, color, thickness, transparency, name)
	return new("UIStroke", {
		Name = name or "Stroke",
		Color = color or C("Outline", Color3.fromRGB(244, 46, 151)),
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function surfaceGradient(parent, topColor, bottomColor, rotation)
	return new("UIGradient", {
		Name = "SurfaceGradient",
		Color = ColorSequence.new(topColor, bottomColor),
		Transparency = NumberSequence.new(E("GradientTransparency", 0.12)),
		Rotation = rotation or 90,
	}, parent)
end

local function addGlow(parent, color)
	return stroke(parent, color, 4, E("GlowTransparency", 0.82), "GlowStroke")
end

local function buttonGradient(parent)
	local strength = math.clamp(E("ButtonGradientStrength", 0.10), 0, 0.35)
	local overlay = new("Frame", {
		Name = "GradientOverlay", Active = false, BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1 - strength, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = parent.ZIndex,
	}, parent)
	corner(overlay, 6)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(95, 95, 95)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.20), NumberSequenceKeypoint.new(0.52, 0.70),
			NumberSequenceKeypoint.new(1, 0.28),
		}), Rotation = E("ButtonGradientRotation", 90),
	}, overlay)
	return overlay
end

local function setAccent(parent, color)
	local main = parent:FindFirstChild("Stroke")
	local glow = parent:FindFirstChild("GlowStroke")
	if main and main:IsA("UIStroke") then main.Color = color end
	if glow and glow:IsA("UIStroke") then glow.Color = color end
end

local function addFacetPattern(parent)
	local pattern = new("Frame", {
		Name = "FacetPattern", BackgroundTransparency = 1, BorderSizePixel = 0,
		ClipsDescendants = true, Size = UDim2.fromScale(1, 1), ZIndex = parent.ZIndex,
	}, parent)
	for index = 1, 3 do
		new("Frame", {
			Name = "Facet" .. index,
			BackgroundColor3 = C("OutlineSoft"),
			BackgroundTransparency = math.clamp(E("PatternTransparency", 0.94) + index * 0.012, 0, 1),
			BorderSizePixel = 0,
			Position = UDim2.new(-0.15 + index * 0.28, 0, 0.12 + index * 0.18, 0),
			Size = UDim2.new(0.52, 0, 0, 2), Rotation = -18, ZIndex = parent.ZIndex,
		}, pattern)
	end
	return pattern
end

local function label(parent, name, text, size, position, textSize, color, alignment, font, role)
	local item = new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = size,
		Position = position,
		Text = text,
		TextColor3 = color or C("Text", Color3.new(1, 1, 1)),
		TextSize = textSize or 12,
		TextXAlignment = alignment or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		FontFace = fontFace(font or FONT, role or roleForSize(textSize)),
		ZIndex = parent.ZIndex + 1,
	}, parent)
	return item
end

local function button(parent, name, text, size, position, fill, outline)
	local item = new("TextButton", {
		Name = name,
		AutoButtonColor = false,
		BackgroundColor3 = fill or C("Panel", Color3.fromRGB(15, 19, 24)),
		BackgroundTransparency = E("ButtonTransparency", 0.08),
		BorderSizePixel = 0,
		Size = size,
		Position = position,
		Text = text or "",
		TextColor3 = C("Text", Color3.new(1, 1, 1)),
		TextSize = T("Button", 13),
		FontFace = fontFace(FONT, "Button"),
		ZIndex = parent.ZIndex + 1,
	}, parent)
	corner(item, 6)
	buttonGradient(item)
	local itemStroke = stroke(item, outline or C("Outline", Color3.fromRGB(244, 46, 151)), 1.4, 0.08)
	local glow = addGlow(item, outline or C("Outline"))
	item.MouseEnter:Connect(function()
		item.BackgroundTransparency = math.max(0, E("ButtonTransparency", 0.08) - 0.05)
		itemStroke.Transparency = 0
		glow.Transparency = math.max(0.55, E("GlowTransparency", 0.82) - 0.12)
	end)
	item.MouseLeave:Connect(function()
		item.BackgroundTransparency = E("ButtonTransparency", 0.08)
		itemStroke.Transparency = 0.08
		glow.Transparency = E("GlowTransparency", 0.82)
	end)
	return item, itemStroke
end

local function neutralSurface(parent, name, size, position, anchor, z)
	local item = new("Frame", {
		Name = name, BackgroundColor3 = C("PanelSoft"),
		BackgroundTransparency = E("DropdownTransparency", 0.06), BorderSizePixel = 0,
		ClipsDescendants = true, Size = size, Position = position,
		AnchorPoint = anchor or Vector2.zero, ZIndex = z or 30,
	}, parent)
	corner(item, 7)
	surfaceGradient(item, C("PanelSoft"), C("Panel"), 90)
	return item
end

local function panel(parent, name, size, position, anchor, z)
	local item = new("Frame", {
		Name = name,
		BackgroundColor3 = C("PanelDeep", Color3.fromRGB(9, 12, 16)),
		BackgroundTransparency = E("PanelTransparency", 0.10),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Size = size,
		Position = position,
		AnchorPoint = anchor or Vector2.zero,
		ZIndex = z or 5,
	}, parent)
	corner(item, 8)
	surfaceGradient(item, C("PanelSoft"), C("PanelDeep"), 110)
	stroke(item, C("Outline", Color3.fromRGB(244, 46, 151)), 1.5, 0.05)
	addGlow(item, C("Outline"))
	addFacetPattern(item)
	return item
end

local function formatCash(value)
	local number = math.max(0, math.floor(tonumber(value) or 0))
	local text = tostring(number)
	repeat
		local replaced
		text, replaced = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
	until replaced == 0
	return "$" .. text
end

local function callGarage(action, payload)
	local ok, result = pcall(function()
		return garageInvoke:InvokeServer(action, payload or {})
	end)
	if ok and typeof(result) == "table" then return result end
	return { Success = false, Ok = false, Message = tostring(result), Error = tostring(result) }
end

local function readInitial(force)
	local interval = L("ProfileRefreshSeconds", 2)
	if not force and cachedInitial and os.clock() - lastProfileRead < interval then return cachedInitial end
	local ok, result = pcall(function()
		return garageInvoke:InvokeServer("GetInitial", {})
	end)
	lastProfileRead = os.clock()
	if ok and typeof(result) == "table" then
		cachedInitial = result
		cachedProfile = result.Profile or result
		cachedCatalog = result.Catalog or cachedCatalog
	end
	return cachedInitial
end

local function showToast(text, positive)
	toast.Text = tostring(text or "")
	toast.TextColor3 = positive and C("Telemetry", Color3.fromRGB(43, 225, 218)) or C("Text", Color3.new(1, 1, 1))
	toast.Visible = true
	local stamp = os.clock()
	toast:SetAttribute("Stamp", stamp)
	task.delay(2.2, function()
		if toast and toast.Parent and toast:GetAttribute("Stamp") == stamp then toast.Visible = false end
	end)
end

local function actuallyVisible(object, stopAt)
	local current = object
	while current and current ~= stopAt do
		if current:IsA("GuiObject") and not current.Visible then return false end
		current = current.Parent
	end
	return true
end

local function isMajorMenuOpen()
	for _, screen in ipairs(playerGui:GetChildren()) do
		if screen:IsA("ScreenGui") and screen ~= gui and screen.Enabled then
			if screen.Name == "HOVER_RACING_V2_GarageUI" then
				return true
			end
			local rootObject = screen:FindFirstChild("GarageRoot", true)
				or screen:FindFirstChild("DealershipRoot", true)
				or screen:FindFirstChild("CustomisationRoot", true)
				or screen:FindFirstChild("CustomizationRoot", true)
			if rootObject and rootObject:IsA("GuiObject")
				and rootObject.Visible
				and actuallyVisible(rootObject, screen) then
				return true
			end
		end
	end
	return false
end

local function ownedVehicleSeat()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then return nil, nil end
	local current = seat
	while current do
		if current:IsA("Model") and tonumber(current:GetAttribute("OwnerUserId")) == player.UserId then
			return seat, current
		end
		current = current.Parent
	end
	return nil, nil
end

local function fireUiEvent(name)
	local event = script.Parent:FindFirstChild(name)
	if event and event:IsA("BindableEvent") then event:Fire(); return true end
	return false
end

local function suppressLegacyDesktop() end -- NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP
local function closeChoiceList()
	if choiceList then choiceList:Destroy(); choiceList = nil end
	choiceAnchor = nil
end

local function closeModal()
	activeModal = nil
	modalLayer.Visible = false
	for _, item in pairs(modalPanels) do item.Visible = false end
end

local function openModal(name)
	closeChoiceList()
	activeModal = name
	modalLayer.Visible = true
	for key, item in pairs(modalPanels) do item.Visible = key == name end
end

local function modalShell(name, titleText, width, height)
	local shell = panel(modalLayer, name, UDim2.fromOffset(width, height), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 44)
	shell.Visible = false
	label(shell, "Title", titleText, UDim2.new(1, -40, 0, 54), UDim2.fromOffset(20, 8), T("Heading", 22), C("Text"), Enum.TextXAlignment.Center)
	modalPanels[name] = shell
	return shell
end

local function makeSegmented(parent, y, titleText, options, selected)
	label(parent, titleText .. "Label", titleText, UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, y), T("Caption", 11), C("Text"))
	local x = 20
	local width = math.floor((parent.Size.X.Offset - 40 - (#options - 1) * 6) / #options)
	for _, option in ipairs(options) do
		local active = option == selected
		local item = button(parent, titleText .. option, option, UDim2.fromOffset(width, 36), UDim2.fromOffset(x, y + 24), active and C("PanelBlue") or C("Panel"), active and C("Telemetry") or C("Outline"))
		item.TextSize = T("Caption", 11)
		x += width + 6
	end
end

local function buildModals()
	modalLayer = new("Frame", { Name = "ModalLayer", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 40, Visible = false }, root)
	modalBackdrop = new("TextButton", {
		Name = "Backdrop", Text = "", AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = L("ModalDimTransparency", 0.32),
		BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 40,
	}, modalLayer)
	modalBackdrop.Activated:Connect(closeModal)

	local teleport = modalShell("Teleport", "TELEPORT TO DEALERSHIP?", 650, 270)
	label(teleport, "Message", "Your current vehicle will be despawned.", UDim2.new(1, -40, 0, 44), UDim2.fromOffset(20, 88), 15, C("Text"), Enum.TextXAlignment.Center, BODY_FONT)
	local no = button(teleport, "No", "NO", UDim2.fromOffset(270, 54), UDim2.fromOffset(30, 182), C("Panel"), C("Outline"))
	local yes = button(teleport, "Yes", "YES", UDim2.fromOffset(270, 54), UDim2.fromOffset(350, 182), C("PanelBlue"), C("Telemetry"))
	no.Activated:Connect(closeModal)
	yes.Activated:Connect(function()
		if busy then return end
		busy = true
		closeModal()
		showToast("TELEPORTING...", true)
		local ok, result = pcall(function()
			return teleportInvoke:InvokeServer("TeleportToDealership")
		end)
		if ok and typeof(result) == "table" and result.Success == true then
			fireUiEvent("FreeRoamVehicleExited")
			lastProfileRead = 0
			showToast(result.Message or "TELEPORTED TO DEALERSHIP", true)
		else
			showToast((typeof(result) == "table" and (result.Message or result.Error)) or "DEALERSHIP TELEPORT FAILED", false)
		end
		busy = false
	end)

	local controls = modalShell("Controls", "CONTROLS", 900, 550)
	label(controls, "DrivingTitle", "DRIVING", UDim2.fromOffset(390, 30), UDim2.fromOffset(45, 70), 15, C("Outline"), Enum.TextXAlignment.Center)
	label(controls, "OnFootTitle", "ON FOOT", UDim2.fromOffset(390, 30), UDim2.fromOffset(465, 70), 15, C("Outline"), Enum.TextXAlignment.Center)
	new("Frame", { BackgroundColor3 = C("Muted"), BackgroundTransparency = 0.72, BorderSizePixel = 0, Position = UDim2.fromOffset(449, 104), Size = UDim2.fromOffset(1, 330), ZIndex = 46 }, controls)
	local function controlRow(x, y, key, action)
		local keycap = button(controls, "Key" .. key .. y, key, UDim2.fromOffset(key == "MOUSE" and 105 or 80, 38), UDim2.fromOffset(x, y), C("Panel"), C("Telemetry"))
		keycap.TextSize = 10
		label(controls, "Action" .. action .. y, action, UDim2.fromOffset(260, 38), UDim2.fromOffset(x + (key == "MOUSE" and 120 or 96), y), 12, C("Text"), Enum.TextXAlignment.Left)
	end
	for index, row in ipairs({ { "W", "ACCELERATE" }, { "S", "BRAKE / REVERSE" }, { "A / D", "STEER" }, { "SHIFT", "DRIFT" }, { "SPACE", "BOOST" }, { "R", "RESET VEHICLE" } }) do controlRow(55, 110 + (index - 1) * 52, row[1], row[2]) end
	for index, row in ipairs({ { "WASD", "MOVE" }, { "SHIFT", "SPRINT" }, { "SPACE", "JUMP" }, { "E", "INTERACT / ENTER VEHICLE" }, { "MOUSE", "CAMERA" } }) do controlRow(480, 110 + (index - 1) * 58, row[1], row[2]) end
	label(controls, "AutoHint", "Controls change automatically when entering a vehicle.", UDim2.new(1, -40, 0, 28), UDim2.fromOffset(20, 438), 11, C("Muted"), Enum.TextXAlignment.Center, BODY_FONT)
	local doneControls = button(controls, "Done", "DONE", UDim2.fromOffset(240, 48), UDim2.fromOffset(330, 480), C("PanelBlue"), C("Telemetry"))
	doneControls.Activated:Connect(closeModal)

	local cash = modalShell("Cash", "GET CASH", 840, 650)
	local balance = button(cash, "Balance", "BALANCE  $0", UDim2.fromOffset(310, 42), UDim2.fromOffset(265, 66), C("PanelBlue"), C("ElectricBlue"))
	balance.Name = "BalanceChip"
	local packs = { { "$10,000", "49 ROBUX" }, { "$30,000", "99 ROBUX" }, { "$75,000", "199 ROBUX" }, { "$200,000", "399 ROBUX" } }
	for index, pack in ipairs(packs) do
		local col = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local card = panel(cash, "Pack" .. index, UDim2.fromOffset(375, 215), UDim2.fromOffset(35 + col * 395, 125 + row * 230), Vector2.zero, 46)
		if index == 4 then
			local best = label(card, "Best", "BEST VALUE", UDim2.fromOffset(120, 28), UDim2.new(1, -130, 0, 10), 9, C("Text"), Enum.TextXAlignment.Center)
			best.BackgroundColor3 = C("Telemetry")
			best.BackgroundTransparency = 0.12
			corner(best, 5)
		end
		label(card, "Coins", index == 1 and "C" or "C  C  C", UDim2.new(1, -30, 0, 70), UDim2.fromOffset(15, 35), 27, C("ElectricBlue"), Enum.TextXAlignment.Center)
		label(card, "Amount", pack[1], UDim2.new(1, -30, 0, 42), UDim2.fromOffset(15, 105), 24, C("Text"), Enum.TextXAlignment.Center)
		local buy = button(card, "Buy", pack[2], UDim2.new(1, -60, 0, 42), UDim2.fromOffset(30, 160), index == 4 and C("PanelBlue") or C("Panel"), index == 4 and C("ElectricBlue") or C("Outline"))
		buy.Activated:Connect(function() showToast("CASH PRODUCTS ARE NOT ENABLED YET", false) end)
	end
	local closeCash = button(cash, "Close", "CLOSE", UDim2.fromOffset(150, 42), UDim2.fromOffset(35, 595), C("Panel"), C("Outline"))
	closeCash.Activated:Connect(closeModal)
	local secure = label(cash, "Secure", "Purchases are processed securely by Roblox.", UDim2.fromOffset(500, 42), UDim2.new(0.5, 0, 0, 595), T("Caption", 11), C("Muted"), Enum.TextXAlignment.Center, BODY_FONT)
	secure.AnchorPoint = Vector2.new(0.5, 0)

	local settings = modalShell("Settings", "SETTINGS", 980, 650)
	label(settings, "VisualTitle", "VISUAL", UDim2.fromOffset(430, 30), UDim2.fromOffset(35, 68), 15, C("Text"))
	label(settings, "InterfaceTitle", "AUDIO & INTERFACE", UDim2.fromOffset(430, 30), UDim2.fromOffset(515, 68), 15, C("Text"))
	new("Frame", { BackgroundColor3 = C("Muted"), BackgroundTransparency = 0.72, BorderSizePixel = 0, Position = UDim2.fromOffset(489, 72), Size = UDim2.fromOffset(1, 485), ZIndex = 46 }, settings)
	local left = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(15, 90), Size = UDim2.fromOffset(450, 455), ZIndex = 46 }, settings)
	local right = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(500, 90), Size = UDim2.fromOffset(465, 455), ZIndex = 46 }, settings)
	makeSegmented(left, 0, "GRAPHICS", { "POTATO", "LOW", "MEDIUM", "HIGH", "ULTRA" }, "HIGH")
	makeSegmented(left, 88, "LIGHTING", { "OFF", "LOW", "HIGH" }, "HIGH")
	makeSegmented(left, 176, "CAMERA SHAKE", { "OFF", "ON" }, "ON")
	makeSegmented(left, 264, "REDUCE FLASHES", { "OFF", "ON" }, "OFF")
	local function slider(parent, y, titleText, percent)
		label(parent, titleText .. "Label", titleText, UDim2.fromOffset(300, 22), UDim2.fromOffset(20, y), 11, C("Text"))
		label(parent, titleText .. "Value", tostring(percent) .. "%", UDim2.fromOffset(70, 22), UDim2.new(1, -90, 0, y), 11, C("Text"), Enum.TextXAlignment.Right)
		local track = new("Frame", { BackgroundColor3 = C("PanelSoft"), BorderSizePixel = 0, Position = UDim2.fromOffset(20, y + 29), Size = UDim2.new(1, -40, 0, 12), ZIndex = 47 }, parent)
		corner(track, 6)
		local fill = new("Frame", { BackgroundColor3 = C("Telemetry"), BorderSizePixel = 0, Size = UDim2.fromScale(percent / 100, 1), ZIndex = 48 }, track)
		corner(fill, 6)
	end
	slider(right, 0, "MUSIC", 65)
	slider(right, 65, "SFX", 80)
	makeSegmented(right, 130, "UI SCALE", { "85%", "100%", "115%" }, "100%")
	slider(right, 218, "HUD OPACITY", 90)
	makeSegmented(right, 283, "MINIMAP", { "ROTATE", "NORTH UP" }, "ROTATE")
	makeSegmented(right, 371, "SPEED UNIT", { "MPH", "KPH" }, "MPH")
	local reset = button(settings, "Reset", "RESET DEFAULTS", UDim2.fromOffset(230, 48), UDim2.fromOffset(35, 575), C("Panel"), C("Outline"))
	local doneSettings = button(settings, "Done", "DONE", UDim2.fromOffset(230, 48), UDim2.fromOffset(715, 575), C("PanelBlue"), C("Telemetry"))
	reset.Activated:Connect(function() showToast("DEFAULT PREVIEW VALUES RESTORED", true) end)
	doneSettings.Activated:Connect(closeModal)
	label(settings, "SaveHint", "Settings save automatically after the persistence phase.", UDim2.fromOffset(420, 48), UDim2.fromOffset(280, 575), 10, C("Muted"), Enum.TextXAlignment.Center, BODY_FONT)
end

local function categoryForVehicle(vehicle, cockpitId)
	local explicit = tostring(vehicle and (vehicle.CategoryId or vehicle.Category) or "")
	if explicit ~= "" then return string.upper(explicit) end
	return string.upper(string.match(tostring(cockpitId or ""), "^([^_]+)") or "OTHER")
end

local function cockpitModel(cockpitId)
	local target = string.lower(tostring(cockpitId or ""))
	if target == "" then return nil end
	for _, item in ipairs(categoriesRoot:GetDescendants()) do
		if item:IsA("Model") then
			local id = string.lower(tostring(item:GetAttribute("CockpitId") or item:GetAttribute("TemplateId") or item.Name))
			local compact = string.gsub(id, "^cockpit_", "")
			if id == target or compact == target or string.find(id, target, 1, true) then return item end
		end
	end
	return nil
end

local function rowsFromProfile()
	readInitial(false)
	local profile = cachedProfile or {}
	local rows = {}
	for vehicleId, vehicle in pairs(profile.Vehicles or {}) do
		local cockpitId = tostring(vehicle.CockpitId or "")
		if cockpitId == "" and vehicle.CockpitInstanceId and profile.OwnedCockpitInstances then
			local instance = profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
			cockpitId = tostring(instance and instance.TemplateId or "")
		end
		local model = cockpitModel(cockpitId)
		local summary = profile.VehicleSummaries and profile.VehicleSummaries[vehicleId]
		local overall = summary and summary.Overall or {}
		local rating = tonumber(overall.PerformanceIndex) or 0
		local tier = tostring(overall.Tier or "E")
		local displayName = tostring(model and model:GetAttribute("DisplayName") or cockpitId ~= "" and cockpitId or "Vehicle")
		displayName = string.upper(string.gsub(displayName, "_", " "))
		local image = tostring(model and (model:GetAttribute("MenuImage") or model:GetAttribute("CockpitImage")) or "")
		if tonumber(image) then image = "rbxassetid://" .. image end
		table.insert(rows, {
			VehicleId = tostring(vehicleId), CockpitId = cockpitId, Category = categoryForVehicle(vehicle, cockpitId),
			Name = displayName, Image = image, Tier = tier, Rating = rating,
			Price = tonumber(model and model:GetAttribute("Price")) or 0,
			Selected = tostring(profile.CurrentVehicleId or "") == tostring(vehicleId),
		})
	end
	return rows
end

local function tierColor(tier)
	return ({
		E = Color3.fromRGB(132, 142, 145), D = Color3.fromRGB(105, 190, 129),
		C = Color3.fromRGB(74, 204, 211), B = Color3.fromRGB(82, 137, 235),
		A = Color3.fromRGB(244, 188, 65), S = Color3.fromRGB(236, 92, 168),
	})[string.upper(tostring(tier or ""))] or C("Outline")
end

local function showChoice(anchor, options, onPick)
	if choiceList and choiceAnchor == anchor then
		closeChoiceList()
		return
	end
	closeChoiceList()
	choiceAnchor = anchor
	local scale = rootScale.Scale
	local logicalPosition = (anchor.AbsolutePosition - root.AbsolutePosition) / scale
	choiceList = neutralSurface(root, "ChoiceList", UDim2.fromOffset(anchor.AbsoluteSize.X / scale, #options * 38 + 10), UDim2.fromOffset(logicalPosition.X, logicalPosition.Y + anchor.AbsoluteSize.Y / scale + L("DropdownGap", 6)), Vector2.zero, 30)
	for index, option in ipairs(options) do
		local item = new("TextButton", {
			Name = "Choice" .. index, AutoButtonColor = false,
			BackgroundColor3 = C("Panel"), BackgroundTransparency = 0.12, BorderSizePixel = 0,
			Size = UDim2.new(1, -10, 0, 34), Position = UDim2.fromOffset(5, 5 + (index - 1) * 38),
			Text = option, TextColor3 = C("Text"), TextSize = T("Button", 13),
			FontFace = fontFace(FONT, "Button"), ZIndex = choiceList.ZIndex + 1,
		}, choiceList)
		corner(item, 5)
		buttonGradient(item)
		item.MouseEnter:Connect(function() item.TextColor3 = C("Telemetry"); item.BackgroundTransparency = 0.03 end)
		item.MouseLeave:Connect(function() item.TextColor3 = C("Text"); item.BackgroundTransparency = 0.12 end)
		item.Activated:Connect(function() closeChoiceList(); onPick(option) end)
	end
end

local function dropdownButton(parent, name, labelText)
	local item = button(parent, name, "", UDim2.fromOffset(220, 64), UDim2.fromOffset(0, 0), C("PanelSoft"), C("OutlineSoft"))
	label(item, "FieldLabel", labelText, UDim2.new(1, -36, 0, 22), UDim2.fromOffset(10, 5), T("Caption", 11), C("Muted"))
	label(item, "Value", "", UDim2.new(1, -42, 0, 30), UDim2.fromOffset(10, 27), T("Body", 14), C("Text"))
	label(item, "Chevron", "v", UDim2.fromOffset(26, 30), UDim2.new(1, -34, 0, 27), T("Caption", 11), C("Telemetry"), Enum.TextXAlignment.Center)
	return item
end

local function refreshDropdownText()
	local categoryValue = categoryButton and categoryButton:FindFirstChild("Value")
	local sortValue = sortButton and sortButton:FindFirstChild("Value")
	if categoryValue then categoryValue.Text = selectedCategory end
	if sortValue then sortValue.Text = selectedSort end
end

local renderCars

local function makeCarCard(parent, row, order)
	local card, cardStroke = button(parent, "VehicleCard", "", UDim2.fromOffset(220, 194), UDim2.fromOffset(0, 0), C("Panel"), row.Selected and C("Telemetry") or C("Outline"))
	card.LayoutOrder = order
	card:SetAttribute("VehicleId", row.VehicleId)
	cardStroke.Thickness = row.Selected and 2.2 or 1.3
	if row.Image ~= "" then
		new("ImageLabel", { Name = "Image", BackgroundTransparency = 1, BorderSizePixel = 0, Image = row.Image, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 1, -78), ZIndex = card.ZIndex + 2 }, card)
	else
		label(card, "Fallback", "HOVERCAR", UDim2.new(1, -24, 1, -78), UDim2.fromOffset(12, 28), T("Body", 14), C("Muted"), Enum.TextXAlignment.Center)
	end
	local badge = label(card, "Badge", string.format("%s  %d", row.Tier, math.floor(row.Rating)), UDim2.fromOffset(92, 30), UDim2.new(1, -102, 0, 10), T("Caption", 11), C("Text"), Enum.TextXAlignment.Center)
	badge.BackgroundColor3 = tierColor(row.Tier)
	badge.BackgroundTransparency = 0.04
	badge.ZIndex = card.ZIndex + 4
	corner(badge, 5)
	local nameLabel = label(card, "Name", row.Name, UDim2.new(1, -18, 0, 48), UDim2.new(0, 9, 1, -54), T("Body", 14), C("Text"), Enum.TextXAlignment.Center)
	nameLabel.TextWrapped = true
	nameLabel.ZIndex = card.ZIndex + 3
	card.Activated:Connect(function()
		if busy then return end
		busy = true
		showToast("SPAWNING VEHICLE...", true)
		local result = callGarage("SpawnOwnedVehicleFromFreeRoam", { VehicleId = row.VehicleId, CockpitId = row.CockpitId })
		if result.Success == true then
			cachedProfile = result.Profile or cachedProfile
			lastProfileRead = 0
			fireUiEvent("FreeRoamVehicleSpawned")
			carPanel.Visible = false
			leftCluster.Visible = true
			showToast("VEHICLE SPAWNED", true)
		else
			showToast(result.Message or result.Error or "VEHICLE SPAWN FAILED", false)
		end
		busy = false
	end)
end

renderCars = function()
	for _, item in ipairs(carContent:GetChildren()) do
		if item ~= carGrid then item:Destroy() end
	end
	local rows = rowsFromProfile()
	local categories = { ALL = true }
	for _, row in ipairs(rows) do categories[row.Category] = true end
	local filtered = {}
	for _, row in ipairs(rows) do
		if selectedCategory == "ALL" or row.Category == selectedCategory then table.insert(filtered, row) end
	end
	table.sort(filtered, function(a, b)
		if selectedSort == "PRICE" then
			if a.Price ~= b.Price then return a.Price < b.Price end
		elseif selectedSort == "A-Z" then
			if a.Name ~= b.Name then return a.Name < b.Name end
		else
			if a.Rating ~= b.Rating then return a.Rating > b.Rating end
		end
		return a.Name < b.Name
	end)
	local buyMore = button(carContent, "BuyMore", "", UDim2.fromOffset(220, 194), UDim2.fromOffset(0, 0), C("Panel"), C("Outline"))
	buyMore.LayoutOrder = 1
	local plusLabel = label(buyMore, "PlusMark", "+", UDim2.new(1, 0, 0, 82), UDim2.fromOffset(0, 30), 36, C("Telemetry"), Enum.TextXAlignment.Center)
	plusLabel.ZIndex = buyMore.ZIndex + 3
	local buyLabel = label(buyMore, "Name", "BUY MORE", UDim2.new(1, -18, 0, 42), UDim2.new(0, 9, 1, -54), 15, C("Text"), Enum.TextXAlignment.Center)
	buyLabel.ZIndex = buyMore.ZIndex + 3
	buyMore.Activated:Connect(function() openModal("Teleport") end)
	for index, row in ipairs(filtered) do makeCarCard(carContent, row, index + 1) end
	task.defer(function()
		if carGrid and carGrid.Parent then
			local contentHeight = carGrid.AbsoluteContentSize.Y
			carContent.Size = UDim2.new(1, 0, 0, contentHeight)
			carScroll.CanvasSize = UDim2.fromOffset(0, L("CardTopSafePadding", 8) + contentHeight + 12)
		end
	end)
	local categoryOptions = {}
	for name in pairs(categories) do table.insert(categoryOptions, name) end
	table.sort(categoryOptions, function(a, b) if a == "ALL" then return true elseif b == "ALL" then return false end return a < b end)
	categoryButton:SetAttribute("Options", table.concat(categoryOptions, "|"))
	refreshDropdownText()
end

local function buildCarPanel()
	carPanel = panel(root, "CarPanel", UDim2.fromOffset(L("CarPanelWidth", 500), 900), UDim2.fromOffset(L("EdgeMargin", 20), L("CarPanelTop", 88)), Vector2.zero, 12)
	carPanel.Visible = false
	label(carPanel, "Title", "MY VEHICLES", UDim2.new(1, -36, 0, 46), UDim2.fromOffset(18, 10), T("Heading", 22), C("Text"))
	categoryButton = dropdownButton(carPanel, "Category", "CATEGORY")
	sortButton = dropdownButton(carPanel, "Sort", "SORT")
	categoryButton.Activated:Connect(function()
		local options = string.split(tostring(categoryButton:GetAttribute("Options") or "ALL"), "|")
		showChoice(categoryButton, options, function(option) selectedCategory = option; renderCars() end)
	end)
	sortButton.Activated:Connect(function()
		showChoice(sortButton, { "RATING", "PRICE", "A-Z" }, function(option) selectedSort = option; renderCars() end)
	end)
	carScroll = new("ScrollingFrame", {
		Name = "VehicleGrid", BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
		Position = UDim2.fromOffset(13, L("CarHeaderHeight", 154)), Size = UDim2.new(1, -26, 1, -(L("CarHeaderHeight", 154) + 78)),
		CanvasSize = UDim2.fromOffset(0, 0), ScrollBarThickness = 5,
		ScrollBarImageColor3 = C("Telemetry"), ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 13,
	}, carPanel)
	carContent = new("Frame", {
		Name = "CardContent", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, L("CardTopSafePadding", 8)),
		Size = UDim2.new(1, 0, 0, 0), ZIndex = 13,
	}, carScroll)
	carGrid = new("UIGridLayout", {
		CellSize = UDim2.fromOffset(220, 194), CellPadding = UDim2.fromOffset(L("CardGap", 12), L("CardGap", 12)),
		FillDirectionMaxCells = 2, SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Top,
	}, carContent)
	despawnButton = button(carPanel, "Despawn", "DESPAWN", UDim2.new(1, -36, 0, 50), UDim2.new(0, 18, 1, -64), C("Danger"), C("Outline"))
	despawnButton.TextSize = T("Button", 13)
	despawnButton.Activated:Connect(function()
		if busy then return end
		busy = true
		fireUiEvent("FreeRoamVehicleExited")
		local result = callGarage("DespawnVehicle", {})
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.Sit = false end
		lastProfileRead = 0
		showToast(result.Success == false and (result.Message or "DESPAWN FAILED") or "VEHICLE DESPAWNED", result.Success ~= false)
		busy = false
	end)
	refreshDropdownText()
end

local function actionIcon(action, iconName, fallback, callback, width)
	local buttonSize = L("ActionButtonSize", 54)
	local item, itemStroke = button(actionBar, action, "", UDim2.fromOffset(width or buttonSize, buttonSize), UDim2.fromOffset(0, 0), C("Panel"), C("Outline"))
	local image = asset(iconName)
	if image ~= "" then
		local icon = new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, BorderSizePixel = 0, Image = image, ImageColor3 = C("Text"), ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), ZIndex = item.ZIndex + 2 }, item)
		icon:SetAttribute("SemanticAction", action)
	else
		label(item, "Fallback", fallback, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), T("Caption", 11), C("Text"), Enum.TextXAlignment.Center)
	end
	item.Activated:Connect(callback)
	return item, itemStroke
end

local function buildMainHud()
	local buttonSize = L("ActionButtonSize", 54)
	local actionGap = L("ActionGap", 8)
	local carWidth = buttonSize * 2 + actionGap
	local actionWidth = carWidth + buttonSize * 4 + actionGap * 4
	actionBar = new("Frame", { Name = "ActionBar", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(actionWidth, buttonSize), ZIndex = 10 }, root)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, actionGap), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }, actionBar)
	local carStroke
	carButton, carStroke = actionIcon("Car", "CarIcon", "CAR", function()
		closeChoiceList()
		carPanel.Visible = not carPanel.Visible
		leftCluster.Visible = not carPanel.Visible
		setAccent(carButton, carPanel.Visible and C("Telemetry") or C("Outline"))
		if carPanel.Visible then renderCars() end
	end, carWidth)
	carButton.LayoutOrder = 1
	local garageAction = actionIcon("Garage", "GarageIcon", "HOME", function()
		if not interiorInvoke then showToast("GARAGE SERVICE NOT READY", false); return end
		local ok, result = pcall(function() return interiorInvoke:InvokeServer("VisitGarage", { OwnerUserId = player.UserId }) end)
		showToast(ok and result and result.Ok and "ENTERED GARAGE" or "GARAGE ENTRY FAILED", ok and result and result.Ok == true)
	end)
	garageAction.LayoutOrder = 2
	local raceAction = actionIcon("Race", "RaceIcon", "RACE", function()
		if not fireUiEvent("OpenRaceBrowser") then showToast("RACE BROWSER NOT READY", false) end
	end)
	raceAction.LayoutOrder = 3
	local dealershipAction = actionIcon("Dealership", "DealershipIcon", "SHOP", function() openModal("Teleport") end)
	dealershipAction.LayoutOrder = 4
	local settingsAction = actionIcon("Settings", "SettingsIcon", "SET", function() openModal("Settings") end)
	settingsAction.LayoutOrder = 5

	local mapSize = L("MinimapSize", 245)
	local cashHeight = L("CashHeight", 40)
	leftCluster = new("Frame", { Name = "LeftCluster", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(mapSize, mapSize + cashHeight + 8), AnchorPoint = Vector2.new(0, 1), ZIndex = 8 }, root)
	local money = panel(leftCluster, "Money", UDim2.fromOffset(mapSize, cashHeight), UDim2.fromOffset(0, 0), Vector2.zero, 9)
	money.BackgroundColor3 = C("PanelBlue")
	local moneyGradient = money:FindFirstChild("SurfaceGradient")
	if moneyGradient and moneyGradient:IsA("UIGradient") then
		moneyGradient.Color = ColorSequence.new(C("ElectricBlue"):Lerp(C("PanelBlue"), 0.72), C("PanelBlue"))
		moneyGradient.Rotation = 0
	end
	stroke(money, C("ElectricBlue"), 1.7, 0, "CashStroke")
	moneyLabel = label(money, "Amount", "$0", UDim2.new(1, -52, 1, 0), UDim2.fromOffset(12, 0), T("CashMetric", 18), C("Text"))
	moneyLabel.TextStrokeColor3 = C("ElectricBlue")
	moneyLabel.TextStrokeTransparency = 0.72
	local plus = button(money, "Plus", "+", UDim2.fromOffset(32, 30), UDim2.new(1, -38, 0.5, -15), C("PanelBlue"), C("ElectricBlue"))
	plus.TextSize = 19
	plus.Activated:Connect(function() openModal("Cash") end)

	minimap = new("Frame", { Name = "Minimap", BackgroundColor3 = C("PanelDeep"), BackgroundTransparency = 0.28, BorderSizePixel = 0, Position = UDim2.fromOffset(0, cashHeight + 8), Size = UDim2.fromOffset(mapSize, mapSize), ClipsDescendants = true, ZIndex = 8 }, leftCluster)
	corner(minimap, 9)
	mapCanvas = new("Frame", { Name = "MapCanvas", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(mapSize * 0.5, mapSize * 0.5), Size = UDim2.fromOffset(mapSize, mapSize), ZIndex = 9 }, minimap)
	local tileNames = { "MapTileTopLeft", "MapTileTopRight", "MapTileBottomLeft", "MapTileBottomRight" }
	local tilePositions = { UDim2.fromScale(0, 0), UDim2.fromScale(0.5, 0), UDim2.fromScale(0, 0.5), UDim2.fromScale(0.5, 0.5) }
	local completeTiles = true
	for index, tileName in ipairs(tileNames) do
		local image = asset(tileName)
		if image == "" then completeTiles = false end
		new("ImageLabel", { Name = tileName, BackgroundTransparency = 1, BorderSizePixel = 0, Image = image, ImageTransparency = 0, ScaleType = Enum.ScaleType.Stretch, Position = tilePositions[index], Size = UDim2.fromScale(0.5, 0.5), ZIndex = 9 }, mapCanvas)
	end
	mapMissingLabel = label(minimap, "MapMissing", "ADD 4 MAP TILE IDS", UDim2.new(1, -24, 0, 32), UDim2.new(0, 12, 0.5, -16), T("Caption", 11), C("Muted"), Enum.TextXAlignment.Center)
	mapMissingLabel.Visible = not completeTiles
	mapMissingLabel.ZIndex = 12
	local markerSize = math.max(8, L("MapPlayerIconSize", 22))
	playerMarker = new("ImageLabel", { Name = "PlayerMarker", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Image = asset("MapPlayerIcon"), ImageColor3 = C("Text"), ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(markerSize, markerSize), ZIndex = 15 }, minimap)
	local northSize = math.max(8, L("MapNorthArrowSize", 28))
	local northMargin = math.max(0, L("MapNorthArrowMargin", 10))
	northArrow = new("ImageLabel", { Name = "NorthArrow", AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Image = asset("MapNorthArrow"), ImageColor3 = C("Text"), ScaleType = Enum.ScaleType.Fit, Position = UDim2.new(1, -northMargin, 1, -northMargin), Size = UDim2.fromOffset(northSize, northSize), ZIndex = 15 }, minimap)
	local function edgeFade(name, position, size, rotation)
		local edge = new("Frame", { Name = name, BackgroundColor3 = C("PanelDeep"), BackgroundTransparency = 0, BorderSizePixel = 0, Position = position, Size = size, ZIndex = 14 }, minimap)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - E("MinimapEdgeOpacity", 0.82)), NumberSequenceKeypoint.new(1, 1) }), Rotation = rotation }, edge)
	end
	edgeFade("EdgeLeft", UDim2.fromScale(0, 0), UDim2.new(0, 48, 1, 0), 0)
	edgeFade("EdgeRight", UDim2.new(1, -48, 0, 0), UDim2.new(0, 48, 1, 0), 180)
	edgeFade("EdgeTop", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 48), 90)
	edgeFade("EdgeBottom", UDim2.new(0, 0, 1, -48), UDim2.new(1, 0, 0, 48), -90)
	-- Intentionally borderless: the directional fade overlays define the map edge.

	bottomActions = new("Frame", { Name = "BottomActions", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(360, 38), AnchorPoint = Vector2.new(0.5, 1), Visible = false, ZIndex = 9 }, root)
	controlsButton = button(bottomActions, "Controls", "CONTROLS", UDim2.fromOffset(150, 32), UDim2.fromOffset(10, 3), C("PanelDeep"), C("OutlineSoft"))
	controlsButton.BackgroundTransparency = 0.48
	controlsButton.TextTransparency = 0.12
	exitButton = button(bottomActions, "Exit", "EXIT VEHICLE", UDim2.fromOffset(170, 32), UDim2.fromOffset(180, 3), C("PanelDeep"), C("OutlineSoft"))
	exitButton.BackgroundTransparency = 0.48
	exitButton.TextTransparency = 0.12
	controlsButton.Activated:Connect(function() openModal("Controls") end)
	exitButton.Activated:Connect(function()
		if busy then return end
		local seat = ownedVehicleSeat()
		if not seat then return end
		busy = true
		fireUiEvent("FreeRoamVehicleExited")
		callGarage("ExitVehicle", {})
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.Sit = false end
		showToast("VEHICLE PARKED", true)
		busy = false
	end)

	telemetry = new("Frame", { Name = "Telemetry", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(420, 250), AnchorPoint = Vector2.new(1, 1), Visible = false, ZIndex = 8 }, root)
	boostIconBox = new("Frame", { Name = "BoostIconContainer", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(32, 32), ZIndex = 9 }, telemetry)
	boostIconImage = new("ImageLabel", { Name = "BoostIcon", BackgroundTransparency = 1, BorderSizePixel = 0, Image = asset("BoostIcon"), ImageColor3 = C("Text"), ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), ZIndex = 10 }, boostIconBox)
	local boostFallback = label(boostIconBox, "Fallback", "⚡", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 18, C("Telemetry"), Enum.TextXAlignment.Center)
	boostFallback.Visible = boostIconImage.Image == ""
	boostTrack = new("Frame", { Name = "BoostTrack", BackgroundColor3 = C("PanelSoft"), BorderSizePixel = 0, Position = UDim2.fromOffset(140, 53), Size = UDim2.fromOffset(180, 12), ZIndex = 9 }, telemetry)
	corner(boostTrack, 8)
	boostFill = new("Frame", { Name = "BoostFill", BackgroundColor3 = C("Telemetry"), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 10 }, boostTrack)
	corner(boostFill, 6)
	surfaceGradient(boostFill, C("ElectricBlue"), C("Telemetry"), 0)
	mphLabel = label(telemetry, "Mph", "0", UDim2.fromOffset(200, 94), UDim2.fromOffset(102, 82), T("Metric", 64), C("Text"), Enum.TextXAlignment.Center)
	mphLabel.TextStrokeColor3 = C("Telemetry")
	mphLabel.TextStrokeTransparency = 0.80
	label(telemetry, "Unit", "MPH", UDim2.fromOffset(200, 30), UDim2.fromOffset(102, 163), T("MetricUnit", 15), C("Text"), Enum.TextXAlignment.Center)
	local center = Vector2.new(302, 133)
	local segmentCount = 16
	for index = 1, segmentCount do
		local alpha = (index - 1) / (segmentCount - 1)
		local angle = math.rad(92 + (-70 - 92) * alpha)
		local radius = 92
		local segment = new("Frame", { Name = "GaugeSegment" .. index, BackgroundColor3 = C("Disabled"), BackgroundTransparency = 0.42, BorderSizePixel = 0, Position = UDim2.fromOffset(center.X + math.cos(angle) * radius - 5, center.Y + math.sin(angle) * radius - 13), Size = UDim2.fromOffset(10, 26), Rotation = math.deg(angle) + 90, ZIndex = 9 }, telemetry)
		corner(segment, 3)
		table.insert(gaugeSegments, segment)
	end

	toast = label(root, "Toast", "", UDim2.fromOffset(420, 36), UDim2.new(0.5, -210, 0, 82), T("Caption", 11), C("Text"), Enum.TextXAlignment.Center)
	toast.BackgroundColor3 = C("PanelDeep")
	toast.BackgroundTransparency = 0.12
	toast.BorderSizePixel = 0
	toast.Visible = false
	toast.ZIndex = 60
	corner(toast, 6)
	stroke(toast, C("Outline"), 1.2, 0.2)
end

local function ensureGui()
	local existing = playerGui:FindFirstChild("NTR_DesktopFreeRoamHud")
	if existing then existing:Destroy() end
	gui = new("ScreenGui", { Name = "NTR_DesktopFreeRoamHud", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 85, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
	gui:SetAttribute("DesktopInputEligible", desktopInputEligible)
	root = new("Frame", { Name = "DesignRoot", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(1920, 1080), ZIndex = 1 }, gui)
	rootScale = new("UIScale", { Scale = 1 }, root)
	buildMainHud()
	buildCarPanel()
	buildModals()
end

local function updateLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	lastViewport = viewport
	local baseW, baseH = L("BaseWidth", 1920), L("BaseHeight", 1080)
	local scale = math.clamp(math.min(viewport.X / baseW, viewport.Y / baseH), L("MinScale", 0.72), L("MaxScale", 1.12))
	rootScale.Scale = scale
	local logicalW, logicalH = viewport.X / scale, viewport.Y / scale
	root.Position = UDim2.fromOffset(0, 0)
	root.Size = UDim2.fromOffset(logicalW, logicalH)
	local edge, top = L("EdgeMargin", 20), L("TopMargin", 18)
	actionBar.Position = UDim2.fromOffset(logicalW - actionBar.Size.X.Offset - edge, top)
	leftCluster.Position = UDim2.fromOffset(edge, logicalH - edge)
	local markerSize = math.max(8, L("MapPlayerIconSize", 22))
	playerMarker.Size = UDim2.fromOffset(markerSize, markerSize)
	local northSize = math.max(8, L("MapNorthArrowSize", 28))
	local northMargin = math.max(0, L("MapNorthArrowMargin", 10))
	northArrow.Size = UDim2.fromOffset(northSize, northSize)
	northArrow.Position = UDim2.new(1, -northMargin, 1, -northMargin)
	bottomActions.Position = UDim2.fromOffset(logicalW * 0.5, logicalH - edge)
	telemetry.Position = UDim2.fromOffset(logicalW - edge, logicalH - edge)
	local boostX = L("BoostBarOffsetX", 90)
	local boostY = L("BoostBarOffsetY", 67)
	local boostWidth = math.max(80, L("BoostBarWidth", 210))
	local boostHeight = math.max(6, L("BoostBarHeight", 24))
	local boostIconSize = math.max(boostHeight + 2, L("BoostIconSize", 32))
	local boostIconGap = math.max(0, L("BoostIconGap", 8))
	boostTrack.Position = UDim2.fromOffset(boostX, boostY)
	boostTrack.Size = UDim2.fromOffset(boostWidth, boostHeight)
	boostIconBox.Position = UDim2.fromOffset(boostX - boostIconSize - boostIconGap, boostY + math.floor((boostHeight - boostIconSize) * 0.5))
	boostIconBox.Size = UDim2.fromOffset(boostIconSize, boostIconSize)
	local panelWidth = L("CarPanelWidth", 500)
	local panelTop = math.max(L("CarPanelTop", 88), top + L("ActionButtonSize", 54) + 16)
	local panelHeight = math.max(620, logicalH - panelTop - L("CarPanelBottomMargin", 20))
	carPanel.Size = UDim2.fromOffset(panelWidth, panelHeight)
	carPanel.Position = UDim2.fromOffset(edge, panelTop)
	local innerInset = 18
	local gap = L("CardGap", 12)
	local innerWidth = panelWidth - innerInset * 2
	local dropdownWidth = math.floor((innerWidth - gap) * 0.5)
	categoryButton.Position = UDim2.fromOffset(innerInset, 66)
	categoryButton.Size = UDim2.fromOffset(dropdownWidth, 64)
	sortButton.Position = UDim2.fromOffset(innerInset + dropdownWidth + gap, 66)
	sortButton.Size = UDim2.fromOffset(dropdownWidth, 64)
	local headerHeight = math.max(L("CarHeaderHeight", 154), 154)
	local cardStrokeSafePadding = math.max(0, L("CardStrokeSafePadding", 5))
	local cardTopSafePadding = math.max(0, L("CardTopSafePadding", 8))
	carScroll.Position = UDim2.fromOffset(innerInset - cardStrokeSafePadding, headerHeight)
	carScroll.Size = UDim2.new(1, -(innerInset - cardStrokeSafePadding) * 2, 1, -(headerHeight + 78))
	carContent.Position = UDim2.fromOffset(0, cardTopSafePadding)
	local cellWidth = math.floor((innerWidth - gap) * 0.5)
	local cellHeight = math.floor(cellWidth * 0.88)
	carGrid.CellSize = UDim2.fromOffset(cellWidth, cellHeight)
	carGrid.CellPadding = UDim2.fromOffset(gap, gap)
	task.defer(function()
		if carGrid and carGrid.Parent then
			local contentHeight = carGrid.AbsoluteContentSize.Y
			carContent.Size = UDim2.new(1, 0, 0, contentHeight)
			carScroll.CanvasSize = UDim2.fromOffset(0, cardTopSafePadding + contentHeight + gap)
		end
	end)
end

local function updateRuntime(dt)
	if racingPresentationActive and not racingTelemetryOnly then gui.Enabled=false return end
	gui.Enabled=true
	local currentCamera = Workspace.CurrentCamera
	local currentViewport = currentCamera and currentCamera.ViewportSize or lastViewport
	if currentViewport ~= lastViewport then updateLayout() end
	if os.clock() >= nextVisibilityScan then
		nextVisibilityScan = os.clock() + 0.1
		majorMenuOpen = isMajorMenuOpen()
	end
	local enabled = readValue(config, "Enabled", true) == true and not majorMenuOpen
	gui:SetAttribute("SuppressedByMajorMenu", majorMenuOpen)
	gui.Enabled = enabled
	if not enabled then closeChoiceList(); return end
	local _, vehicle = ownedVehicleSeat()
	local driving = vehicle ~= nil
	actionBar.Visible = not racingPresentationActive
	if racingPresentationActive then carPanel.Visible = false end
	leftCluster.Visible = not racingPresentationActive and not carPanel.Visible
	bottomActions.Visible = driving and not racingPresentationActive
	controlsButton.Visible = driving and not racingPresentationActive
	exitButton.Visible = driving and not racingPresentationActive
	telemetry.Visible = driving
	if not (racingPresentationActive and readValue(racingPerformanceConfig, "PauseFreeRoamMapDuringRace", true) == true) then
		local character = player.Character
		local characterRoot = character and character:FindFirstChild("HumanoidRootPart")
		local mapSubject = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)) or characterRoot
		if mapSubject and mapSubject:IsA("BasePart") then
			local mapSize = L("MinimapSize", 245)
			local mapPixels = math.max(1, L("MapPixels", 2048))
			local calibrationPixels = math.max(1, L("MapCalibrationPixels", 207))
			local calibrationStuds = math.max(1, L("MapCalibrationStuds", 2850))
			local fullMapStuds = mapPixels * calibrationStuds / calibrationPixels
			local visibleStuds = math.max(100, L("MapVisibleStuds", 2850))
			local uiPerStud = mapSize / visibleStuds
			local canvasSize = fullMapStuds * uiPerStud
			mapCanvas.Size = UDim2.fromOffset(canvasSize, canvasSize)
			local position = mapSubject.Position
			local dx = position.X - L("MapWorldCenterX", 0)
			local dz = position.Z - L("MapWorldCenterZ", 0)
			if B(defaults, "MapFlipX", false) then dx = -dx end
			if B(defaults, "MapFlipZ", false) then dz = -dz end
			local coordinateRadians = math.rad(L("MapCoordinateRotationDegrees", 90))
			local mappedX = dx * math.cos(coordinateRadians) - dz * math.sin(coordinateRadians)
			local mappedZ = dx * math.sin(coordinateRadians) + dz * math.cos(coordinateRadians)
			local look = mapSubject.CFrame.LookVector
			local lookX, lookZ = look.X, look.Z
			if B(defaults, "MapFlipX", false) then lookX = -lookX end
			if B(defaults, "MapFlipZ", false) then lookZ = -lookZ end
			local mappedLookX = lookX * math.cos(coordinateRadians) - lookZ * math.sin(coordinateRadians)
			local mappedLookZ = lookX * math.sin(coordinateRadians) + lookZ * math.cos(coordinateRadians)
			local targetHeading = math.deg(math.atan2(mappedLookX, -mappedLookZ)) + L("MapRotationOffsetDegrees", 0)
			local targetPosition = Vector2.new(mapSize * 0.5, mapSize * 0.5) - Vector2.new(mappedX * uiPerStud, mappedZ * uiPerStud)
			local smoothing = math.max(0, L("MapSmoothing", 10))
			local alpha = smoothing <= 0 and 1 or math.clamp((dt or 1 / 60) * smoothing, 0, 1)
			displayedMapPosition = displayedMapPosition and displayedMapPosition:Lerp(targetPosition, alpha) or targetPosition
			if displayedPlayerHeading == nil then displayedPlayerHeading = targetHeading end
			local headingDelta = (targetHeading - displayedPlayerHeading + 180) % 360 - 180
			displayedPlayerHeading += headingDelta * alpha
			mapCanvas.Position = UDim2.fromOffset(displayedMapPosition.X, displayedMapPosition.Y)
			mapCanvas.Rotation = 0
			playerMarker.Rotation = B(defaults, "MapPlayerIconRotates", true) and displayedPlayerHeading or 0
		end

	end
	if not driving then displayedBoostAlpha = 1 end
	despawnButton.BackgroundColor3 = vehicle and C("Danger") or C("Disabled")
	if vehicle then
		local boostTarget = math.clamp((tonumber(mobileDriveInputState.BoostPercent) or 100) / 100, 0, 1)
		local boostSmoothing = math.max(0, L("BoostBarSmoothing", 14))
		local boostStep = boostSmoothing <= 0 and 1 or math.clamp((dt or 1 / 60) * boostSmoothing, 0, 1)
		displayedBoostAlpha += (boostTarget - displayedBoostAlpha) * boostStep
		boostFill.Size = UDim2.fromScale(math.clamp(displayedBoostAlpha, 0, 1), 1)
		local rootPart = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
		local speed = rootPart and rootPart:IsA("BasePart") and rootPart.AssemblyLinearVelocity.Magnitude * 0.625 or 0
		mphLabel.Text = tostring(math.floor(speed + 0.5))
		local alpha = math.clamp(speed / L("SpeedGaugeMaxMph", 260), 0, 1)
		local activeCount = math.floor(alpha * #gaugeSegments + 0.5)
		for index, segment in ipairs(gaugeSegments) do
			segment.BackgroundColor3 = index <= activeCount and (index > #gaugeSegments * 0.82 and C("HighSpeed") or C("Telemetry")) or C("Disabled")
			segment.BackgroundTransparency = index <= activeCount and 0 or 0.42
		end
	end
	if not (racingPresentationActive and readValue(racingPerformanceConfig, "PauseFreeRoamProfileDuringRace", true) == true) and not profileReadPending and os.clock() - lastProfileRead >= L("ProfileRefreshSeconds", 2) then
		profileReadPending = true
		lastProfileRead = os.clock()
		task.spawn(function()
			readInitial(true)
			if moneyLabel and moneyLabel.Parent then
				moneyLabel.Text = formatCash(cachedProfile and cachedProfile.Cash or 0)
				local balanceChip = modalPanels.Cash and modalPanels.Cash:FindFirstChild("BalanceChip")
				if balanceChip and balanceChip:IsA("TextButton") then balanceChip.Text = "BALANCE  " .. moneyLabel.Text end
			end
			profileReadPending = false
		end)
	end
end

ensureGui()
updateLayout()
readInitial(true)
moneyLabel.Text = formatCash(cachedProfile and cachedProfile.Cash or 0)

local camera = Workspace.CurrentCamera
if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout) end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	updateLayout()
	local current = Workspace.CurrentCamera
	if current then current:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout) end
end)

local presentationEvent=script.Parent:FindFirstChild("FreeRoamHudPresentationMode")
if presentationEvent and presentationEvent:IsA("BindableEvent") then
	presentationEvent.Event:Connect(function(message)
		if typeof(message)=="table" then
			local owner=tostring(message.Owner or "Racing") presentationOwners[owner]=message.Active==true and {KeepTelemetry=message.KeepTelemetry==true} or nil
		else presentationOwners.Racing=tostring(message)=="Racing" and {KeepTelemetry=true} or nil end
		racingPresentationActive=next(presentationOwners)~=nil racingTelemetryOnly=racingPresentationActive
		for _,state in pairs(presentationOwners) do if not state.KeepTelemetry then racingTelemetryOnly=false break end end
		if racingPresentationActive then carPanel.Visible=false closeChoiceList() closeModal() end
		if not racingPresentationActive then gui.Enabled=true end
	end)
end

pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase1") end)
pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase2B") end)
pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase2C") end)
pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase2D") end)
pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase2E") end)
pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase2F") end)
pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase2G") end)
pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase2H") end)
pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase2I") end)
pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase3A") end)
pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase3B") end)
pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase3C") end)
pcall(function() RunService:UnbindFromRenderStep("NTR_PCFreeRoamHudPhase3D") end)
RunService:BindToRenderStep("NTR_PCFreeRoamHudPhase4A", 3000, function(dt)
	updateRuntime(dt)
end)
