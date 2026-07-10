-- NTR_PC_FREEROAM_UI_PHASE1_VISUAL_SHELL

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

if UserInputService.TouchEnabled then
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("DesktopFreeRoamHud")
local colours = config:WaitForChild("Colours")
local layoutConfig = config:WaitForChild("Layout")
local assetConfig = config:WaitForChild("Assets")
local defaults = config:WaitForChild("Defaults")
local garageRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage")
local garageInvoke = garageRemotes:WaitForChild("GarageInvoke")
local interiorInvoke = garageRemotes:FindFirstChild("GarageInteriorInvoke")
local categoriesRoot = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")

local FONT = Enum.Font.Michroma
local BODY_FONT = Enum.Font.GothamMedium
local gui
local root
local rootScale
local actionBar
local leftCluster
local moneyLabel
local minimap
local bottomActions
local exitButton
local telemetry
local mphLabel
local boostFill
local gaugeSegments = {}
local carPanel
local carScroll
local carGrid
local carButton
local categoryButton
local sortButton
local despawnButton
local modalLayer
local modalBackdrop
local modalPanels = {}
local choiceList
local toast
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

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color or C("Outline", Color3.fromRGB(244, 46, 151)),
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function label(parent, name, text, size, position, textSize, color, alignment, font)
	return new("TextLabel", {
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
		Font = font or FONT,
		ZIndex = parent.ZIndex + 1,
	}, parent)
end

local function button(parent, name, text, size, position, fill, outline)
	local item = new("TextButton", {
		Name = name,
		AutoButtonColor = false,
		BackgroundColor3 = fill or C("Panel", Color3.fromRGB(15, 19, 24)),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Size = size,
		Position = position,
		Text = text or "",
		TextColor3 = C("Text", Color3.new(1, 1, 1)),
		TextSize = 12,
		Font = FONT,
		ZIndex = parent.ZIndex + 1,
	}, parent)
	corner(item, 6)
	local itemStroke = stroke(item, outline or C("Outline", Color3.fromRGB(244, 46, 151)), 1.4, 0.08)
	item.MouseEnter:Connect(function()
		item.BackgroundTransparency = 0
		itemStroke.Transparency = 0
	end)
	item.MouseLeave:Connect(function()
		item.BackgroundTransparency = 0.08
		itemStroke.Transparency = 0.08
	end)
	return item, itemStroke
end

local function panel(parent, name, size, position, anchor, z)
	local item = new("Frame", {
		Name = name,
		BackgroundColor3 = C("PanelDeep", Color3.fromRGB(9, 12, 16)),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Size = size,
		Position = position,
		AnchorPoint = anchor or Vector2.zero,
		ZIndex = z or 5,
	}, parent)
	corner(item, 8)
	stroke(item, C("Outline", Color3.fromRGB(244, 46, 151)), 1.5, 0.05)
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

local function screenHasVisibleContent(screen)
	for _, descendant in ipairs(screen:GetDescendants()) do
		if descendant:IsA("GuiObject")
			and descendant.Visible
			and descendant.AbsoluteSize.X > 80
			and descendant.AbsoluteSize.Y > 40
			and actuallyVisible(descendant, screen) then
			return true
		end
	end
	return false
end

local function isMajorMenuOpen()
	for _, screen in ipairs(playerGui:GetChildren()) do
		if screen:IsA("ScreenGui") and screen ~= gui and screen.Enabled then
			local lower = string.lower(screen.Name)
			local isMajorName = string.find(lower, "dealership", 1, true)
				or string.find(lower, "garageui", 1, true)
				or string.find(lower, "customisation", 1, true)
				or string.find(lower, "customization", 1, true)
			if isMajorName and screenHasVisibleContent(screen) then
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

local function suppressLegacyDesktop()
	local oldNav = playerGui:FindFirstChild("NTR_FreeRoamLeftNav")
	if oldNav and oldNav:IsA("ScreenGui") then oldNav.Enabled = false end
	local oldExit = playerGui:FindFirstChild("NTR_FreeRoamVehicleExitButton")
	if oldExit and oldExit:IsA("ScreenGui") then oldExit.Enabled = false end
	local oldDrive = playerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD")
	if oldDrive then
		local oldHud = oldDrive:FindFirstChild("DriveHUD", true)
		local oldMenu = oldDrive:FindFirstChild("DriveMenu", true)
		if oldHud and oldHud:IsA("GuiObject") then oldHud.Visible = false end
		if oldMenu and oldMenu:IsA("GuiObject") then oldMenu.Visible = false end
	end
end

local function closeChoiceList()
	if choiceList then choiceList:Destroy(); choiceList = nil end
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
	label(shell, "Title", titleText, UDim2.new(1, -40, 0, 54), UDim2.fromOffset(20, 8), 23, C("Text"), Enum.TextXAlignment.Center)
	modalPanels[name] = shell
	return shell
end

local function makeSegmented(parent, y, titleText, options, selected)
	label(parent, titleText .. "Label", titleText, UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, y), 11, C("Text"))
	local x = 20
	local width = math.floor((parent.Size.X.Offset - 40 - (#options - 1) * 6) / #options)
	for _, option in ipairs(options) do
		local active = option == selected
		local item = button(parent, titleText .. option, option, UDim2.fromOffset(width, 36), UDim2.fromOffset(x, y + 24), active and C("PanelBlue") or C("Panel"), active and C("Telemetry") or C("Outline"))
		item.TextSize = 10
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
		closeModal()
		showToast("TELEPORT SERVICE INSTALLS IN A LATER PHASE", false)
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
	label(cash, "Secure", "Purchases are processed securely by Roblox.", UDim2.fromOffset(540, 42), UDim2.fromOffset(210, 595), 10, C("Muted"), Enum.TextXAlignment.Center, BODY_FONT)

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
	closeChoiceList()
	choiceList = panel(root, "ChoiceList", UDim2.fromOffset(anchor.AbsoluteSize.X / rootScale.Scale, #options * 34 + 10), UDim2.fromOffset(anchor.AbsolutePosition.X / rootScale.Scale, (anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y + 4) / rootScale.Scale), Vector2.zero, 30)
	for index, option in ipairs(options) do
		local item = button(choiceList, "Choice" .. index, option, UDim2.new(1, -10, 0, 30), UDim2.fromOffset(5, 5 + (index - 1) * 34), C("Panel"), C("OutlineSoft"))
		item.TextSize = 9
		item.Activated:Connect(function() closeChoiceList(); onPick(option) end)
	end
end

local function refreshDropdownText()
	categoryButton.Text = "CATEGORY\n" .. selectedCategory .. "  v"
	sortButton.Text = "SORT\n" .. selectedSort .. "  v"
end

local renderCars

local function makeCarCard(parent, row, order)
	local card, cardStroke = button(parent, "VehicleCard", "", UDim2.fromOffset(216, 190), UDim2.fromOffset(0, 0), C("Panel"), row.Selected and C("Telemetry") or C("Outline"))
	card.LayoutOrder = order
	card:SetAttribute("VehicleId", row.VehicleId)
	cardStroke.Thickness = row.Selected and 2 or 1.3
	if row.Image ~= "" then
		new("ImageLabel", { Name = "Image", BackgroundTransparency = 1, BorderSizePixel = 0, Image = row.Image, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -24, 1, -62), ZIndex = card.ZIndex + 1 }, card)
	else
		label(card, "Fallback", "HOVERCAR", UDim2.new(1, -24, 1, -62), UDim2.fromOffset(12, 22), 15, C("Muted"), Enum.TextXAlignment.Center)
	end
	local badge = label(card, "Badge", string.format("%s %d", row.Tier, math.floor(row.Rating)), UDim2.fromOffset(78, 27), UDim2.new(1, -88, 0, 9), 9, C("Text"), Enum.TextXAlignment.Center)
	badge.BackgroundColor3 = tierColor(row.Tier)
	badge.BackgroundTransparency = 0.05
	corner(badge, 5)
	label(card, "Name", row.Name, UDim2.new(1, -16, 0, 34), UDim2.new(0, 8, 1, -40), 9, C("Text"), Enum.TextXAlignment.Center)
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
	for _, item in ipairs(carScroll:GetChildren()) do
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
	local buyMore = button(carScroll, "BuyMore", "+\n\nBUY MORE", UDim2.fromOffset(216, 190), UDim2.fromOffset(0, 0), C("Panel"), C("Outline"))
	buyMore.LayoutOrder = 1
	buyMore.TextColor3 = C("Telemetry")
	buyMore.TextSize = 18
	buyMore.Activated:Connect(function() openModal("Teleport") end)
	for index, row in ipairs(filtered) do makeCarCard(carScroll, row, index + 1) end
	task.defer(function()
		if carGrid and carGrid.Parent then carScroll.CanvasSize = UDim2.fromOffset(0, carGrid.AbsoluteContentSize.Y + 12) end
	end)
	local categoryOptions = {}
	for name in pairs(categories) do table.insert(categoryOptions, name) end
	table.sort(categoryOptions, function(a, b) if a == "ALL" then return true elseif b == "ALL" then return false end return a < b end)
	categoryButton:SetAttribute("Options", table.concat(categoryOptions, "|"))
	refreshDropdownText()
end

local function buildCarPanel()
	carPanel = panel(root, "CarPanel", UDim2.fromOffset(L("CarPanelWidth", 500), 900), UDim2.fromOffset(L("EdgeMargin", 20), L("CarPanelTop", 76)), Vector2.zero, 12)
	carPanel.Visible = false
	label(carPanel, "Title", "MY VEHICLES", UDim2.new(1, -30, 0, 44), UDim2.fromOffset(15, 8), 19, C("Text"))
	categoryButton = button(carPanel, "Category", "CATEGORY\nALL  v", UDim2.fromOffset(222, 55), UDim2.fromOffset(15, 61), C("PanelSoft"), C("OutlineSoft"))
	sortButton = button(carPanel, "Sort", "SORT\nRATING  v", UDim2.fromOffset(222, 55), UDim2.fromOffset(253, 61), C("PanelSoft"), C("OutlineSoft"))
	categoryButton.TextXAlignment = Enum.TextXAlignment.Left
	sortButton.TextXAlignment = Enum.TextXAlignment.Left
	categoryButton.TextSize = 9
	sortButton.TextSize = 9
	categoryButton.Activated:Connect(function()
		local options = string.split(tostring(categoryButton:GetAttribute("Options") or "ALL"), "|")
		showChoice(categoryButton, options, function(option) selectedCategory = option; renderCars() end)
	end)
	sortButton.Activated:Connect(function()
		showChoice(sortButton, { "RATING", "PRICE", "A-Z" }, function(option) selectedSort = option; renderCars() end)
	end)
	carScroll = new("ScrollingFrame", {
		Name = "VehicleGrid", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(15, 130), Size = UDim2.new(1, -30, 1, -205),
		CanvasSize = UDim2.fromOffset(0, 0), ScrollBarThickness = 4,
		ScrollBarImageColor3 = C("Muted"), ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 13,
	}, carPanel)
	carGrid = new("UIGridLayout", {
		CellSize = UDim2.fromOffset(216, 190), CellPadding = UDim2.fromOffset(12, 12),
		FillDirectionMaxCells = 2, SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top,
	}, carScroll)
	despawnButton = button(carPanel, "Despawn", "DESPAWN", UDim2.new(1, -30, 0, 50), UDim2.new(0, 15, 1, -65), C("Danger"), C("Outline"))
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
end

local function actionIcon(action, iconName, fallback, callback)
	local item, itemStroke = button(actionBar, action, "", UDim2.fromOffset(54, 54), UDim2.fromOffset(0, 0), C("Panel"), C("Outline"))
	local image = asset(iconName)
	if image ~= "" then
		new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, BorderSizePixel = 0, Image = image, ImageColor3 = C("Text"), ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(13, 13), Size = UDim2.fromOffset(28, 28), ZIndex = item.ZIndex + 1 }, item)
	else
		label(item, "Fallback", fallback, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 12, C("Text"), Enum.TextXAlignment.Center)
	end
	item.Activated:Connect(callback)
	return item, itemStroke
end

local function buildMainHud()
	actionBar = new("Frame", { Name = "ActionBar", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(302, 54), ZIndex = 10 }, root)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }, actionBar)
	local carStroke
	carButton, carStroke = actionIcon("Car", "CarIcon", "CAR", function()
		closeChoiceList()
		carPanel.Visible = not carPanel.Visible
		leftCluster.Visible = not carPanel.Visible
		carStroke.Color = carPanel.Visible and C("Telemetry") or C("Outline")
		if carPanel.Visible then renderCars() end
	end)
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

	leftCluster = new("Frame", { Name = "LeftCluster", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(L("MinimapSize", 245), L("MinimapSize", 245) + 48), AnchorPoint = Vector2.new(0, 1), ZIndex = 8 }, root)
	local money = panel(leftCluster, "Money", UDim2.fromOffset(L("CashWidth", 210), L("CashHeight", 40)), UDim2.fromOffset(0, 0), Vector2.zero, 9)
	money.BackgroundColor3 = C("PanelBlue")
	stroke(money, C("ElectricBlue"), 1.5, 0)
	moneyLabel = label(money, "Amount", "$0", UDim2.new(1, -48, 1, 0), UDim2.fromOffset(10, 0), 15, C("Text"))
	local plus = button(money, "Plus", "+", UDim2.fromOffset(30, 30), UDim2.new(1, -35, 0, 5), C("PanelBlue"), C("Outline"))
	plus.TextSize = 18
	plus.Activated:Connect(function() openModal("Cash") end)

	local mapSize = L("MinimapSize", 245)
	minimap = new("Frame", { Name = "Minimap", BackgroundColor3 = C("PanelDeep"), BackgroundTransparency = 0.34, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 48), Size = UDim2.fromOffset(mapSize, mapSize), ClipsDescendants = true, ZIndex = 8 }, leftCluster)
	corner(minimap, 9)
	for index, road in ipairs({
		{ 22, 45, 200, 5, 22 }, { 8, 120, 220, 6, -13 }, { 65, 10, 5, 220, 7 },
		{ 150, 18, 5, 210, -18 }, { 34, 178, 180, 5, 35 }, { 95, 70, 110, 4, -42 },
	}) do
		local r = new("Frame", { Name = "Road" .. index, BackgroundColor3 = C("Muted"), BackgroundTransparency = 0.35, BorderSizePixel = 0, Position = UDim2.fromOffset(road[1], road[2]), Size = UDim2.fromOffset(road[3], road[4]), Rotation = road[5], ZIndex = 9 }, minimap)
		corner(r, 3)
	end
	local arrow = label(minimap, "PlayerArrow", "^", UDim2.fromOffset(34, 34), UDim2.new(0.5, -17, 0.5, -17), 25, C("Telemetry"), Enum.TextXAlignment.Center)
	arrow.ZIndex = 12
	local feather = new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.45, 0.05), NumberSequenceKeypoint.new(1, 0.5) }), Rotation = 45 }, minimap)
	feather.Name = "PreviewFeather"

	bottomActions = new("Frame", { Name = "BottomActions", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(360, 36), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 9 }, root)
	local controlsButton = button(bottomActions, "Controls", "CONTROLS", UDim2.fromOffset(150, 30), UDim2.fromOffset(10, 3), C("PanelDeep"), C("OutlineSoft"))
	controlsButton.BackgroundTransparency = 0.55
	controlsButton.TextTransparency = 0.22
	exitButton = button(bottomActions, "Exit", "EXIT VEHICLE", UDim2.fromOffset(170, 30), UDim2.fromOffset(180, 3), C("PanelDeep"), C("OutlineSoft"))
	exitButton.BackgroundTransparency = 0.55
	exitButton.TextTransparency = 0.22
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

	telemetry = new("Frame", { Name = "Telemetry", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(390, 220), AnchorPoint = Vector2.new(1, 1), ZIndex = 8 }, root)
	label(telemetry, "BoostLabel", "BOOST  >", UDim2.fromOffset(100, 26), UDim2.fromOffset(15, 42), 12, C("Text"), Enum.TextXAlignment.Right)
	local boostBack = new("Frame", { BackgroundColor3 = C("PanelSoft"), BorderSizePixel = 0, Position = UDim2.fromOffset(125, 48), Size = UDim2.fromOffset(190, 12), ZIndex = 9 }, telemetry)
	corner(boostBack, 6)
	boostFill = new("Frame", { Name = "BoostFill", BackgroundColor3 = C("Telemetry"), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 10 }, boostBack)
	corner(boostFill, 6)
	mphLabel = label(telemetry, "Mph", "0", UDim2.fromOffset(200, 82), UDim2.fromOffset(110, 78), 49, C("Text"), Enum.TextXAlignment.Center)
	label(telemetry, "Unit", "MPH", UDim2.fromOffset(200, 28), UDim2.fromOffset(110, 148), 12, C("Text"), Enum.TextXAlignment.Center)
	local center = Vector2.new(310, 132)
	for index = 1, 14 do
		local angle = math.rad(-72 + (index - 1) * 9.5)
		local radius = 92
		local segment = new("Frame", { Name = "GaugeSegment" .. index, BackgroundColor3 = C("Disabled"), BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.fromOffset(center.X + math.cos(angle) * radius, center.Y + math.sin(angle) * radius), Size = UDim2.fromOffset(10, 25), Rotation = math.deg(angle) + 90, ZIndex = 9 }, telemetry)
		corner(segment, 3)
		table.insert(gaugeSegments, segment)
	end

	toast = label(root, "Toast", "", UDim2.fromOffset(420, 34), UDim2.new(0.5, -210, 0, 80), 11, C("Text"), Enum.TextXAlignment.Center)
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
	root = new("Frame", { Name = "DesignRoot", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(1920, 1080), ZIndex = 1 }, gui)
	rootScale = new("UIScale", { Scale = 1 }, root)
	buildMainHud()
	buildCarPanel()
	buildModals()
end

local function updateLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local baseW, baseH = L("BaseWidth", 1920), L("BaseHeight", 1080)
	local scale = math.clamp(math.min(viewport.X / baseW, viewport.Y / baseH), L("MinScale", 0.72), L("MaxScale", 1.12))
	rootScale.Scale = scale
	local logicalW, logicalH = viewport.X / scale, viewport.Y / scale
	root.Size = UDim2.fromOffset(logicalW, logicalH)
	local edge, top = L("EdgeMargin", 20), L("TopMargin", 18)
	actionBar.Position = UDim2.fromOffset(logicalW - actionBar.Size.X.Offset - edge, top)
	leftCluster.Position = UDim2.fromOffset(edge, logicalH - edge)
	bottomActions.Position = UDim2.fromOffset(logicalW * 0.5, logicalH - edge)
	telemetry.Position = UDim2.fromOffset(logicalW - edge, logicalH - edge)
	local panelHeight = math.max(620, logicalH - L("CarPanelTop", 76) - L("CarPanelBottomMargin", 20))
	carPanel.Size = UDim2.fromOffset(L("CarPanelWidth", 500), panelHeight)
	carPanel.Position = UDim2.fromOffset(edge, L("CarPanelTop", 76))
end

local function updateRuntime()
	suppressLegacyDesktop()
	if os.clock() >= nextVisibilityScan then
		nextVisibilityScan = os.clock() + 0.1
		majorMenuOpen = isMajorMenuOpen()
	end
	local enabled = readValue(config, "Enabled", true) == true and not majorMenuOpen
	gui.Enabled = enabled
	if not enabled then closeChoiceList(); return end
	local _, vehicle = ownedVehicleSeat()
	local driving = vehicle ~= nil
	exitButton.Visible = driving
	telemetry.Visible = driving
	despawnButton.BackgroundColor3 = vehicle and C("Danger") or C("Disabled")
	if vehicle then
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
	if not profileReadPending and os.clock() - lastProfileRead >= L("ProfileRefreshSeconds", 2) then
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

RunService:BindToRenderStep("NTR_PCFreeRoamHudPhase1", 3000, function()
	updateRuntime()
end)
