-- Neo Tokyo Racers - Dealership / Customisation Split Phase 10
-- Responsive layout polish after Phase 9.
--
-- This is a guarded source patch against the active client bootstrap and the
-- isolated FreeRoamNavController_Active. It expects Phase 9 to be installed.
-- If an anchor is missing, refresh the Studio mirror before creating another patch.

local PHASE = "NTR Dealership/Customisation Phase 10 Responsive Layout Polish"
local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE10_RESPONSIVE_LAYOUT_POLISH"
local PHASE9_MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE9_BADGE_OVERLAY_TIGHT_CARDS"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")

local function info(message)
	print("[" .. PHASE .. "] " .. message)
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function replaceOnce(source, old, new, label)
	local nextSource, count = string.gsub(source, old:gsub("([^%w])", "%%%1"), new, 1)
	assert(count == 1, "Could not replace " .. label)
	return nextSource
end

local function replaceBetween(source, startNeedle, endNeedle, replacement, label)
	local startA, startB = string.find(source, startNeedle, 1, true)
	assert(startA, "Could not find start anchor for " .. label)
	local endA = string.find(source, endNeedle, startB + 1, true)
	assert(endA, "Could not find end anchor for " .. label)
	return string.sub(source, 1, startA - 1) .. replacement .. string.sub(source, endA)
end

local function ensureChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, parent:GetFullName() .. "." .. name .. " is " .. existing.ClassName .. ", expected " .. className)
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

local function ensureNumber(parent, name, value, force)
	local item = parent:FindFirstChild(name)
	if not item then
		item = Instance.new("NumberValue")
		item.Name = name
		item.Value = value
		item.Parent = parent
	elseif item:IsA("NumberValue") and force then
		item.Value = value
	end
	assert(item:IsA("NumberValue"), parent:GetFullName() .. "." .. name .. " must be a NumberValue")
	return item
end

local function ensureBool(parent, name, value, force)
	local item = parent:FindFirstChild(name)
	if not item then
		item = Instance.new("BoolValue")
		item.Name = name
		item.Value = value
		item.Parent = parent
	elseif item:IsA("BoolValue") and force then
		item.Value = value
	end
	assert(item:IsA("BoolValue"), parent:GetFullName() .. "." .. name .. " must be a BoolValue")
	return item
end

local function activeBootstrap()
	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local root = playerScripts:WaitForChild("NeoTokyoRacersClient")
	local scriptObject = root:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
	assert(scriptObject:IsA("LocalScript"), "Active bootstrap path is not a LocalScript.")
	return scriptObject
end

local function activeFreeRoamNav()
	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local root = playerScripts:WaitForChild("NeoTokyoRacersClient")
	local controllers = root:WaitForChild("Controllers")
	local ui = controllers:WaitForChild("UI")
	local scriptObject = ui:WaitForChild("FreeRoamNavController_Active")
	assert(scriptObject:IsA("LocalScript"), "FreeRoamNavController_Active path is not a LocalScript.")
	return scriptObject
end

local function ensureConfig()
	local configRoot = ensureChild(kit, "Folder", "Config")
	local uiRoot = ensureChild(configRoot, "Folder", "UI")
	local cards = ensureChild(uiRoot, "Folder", "CockpitMenuCards")

	ensureBool(cards, "UseResponsiveGridWidth", true, true)
	ensureBool(cards, "ResponsiveCardScaleEnabled", true)
	ensureBool(cards, "FreeRoamUsesCockpitMenuImage", false, true)

	ensureNumber(cards, "FreeRoamCarIconScale", 0.48, true)
	ensureNumber(cards, "DesktopNameTextSize", 12, true)
	ensureNumber(cards, "MobileNameTextSize", 10, true)
	ensureNumber(cards, "DesktopNameHeight", 18, true)
	ensureNumber(cards, "MobileNameHeight", 16, true)
	ensureNumber(cards, "DesktopCardScaleMax", 1.35, true)
	ensureNumber(cards, "MobileCardScaleMax", 1.12, true)

	ensureNumber(cards, "MobileStatsPanelWidth", 230, true)
	ensureNumber(cards, "DesktopStatsPanelWidth", 270, true)
	ensureNumber(cards, "ExitPanelVerticalPadding", 9, true)
	ensureNumber(cards, "PanelActionBottomPadding", 8, true)

	info("Ensured Phase 10 responsive layout config values.")
end

local drawBarSource = [=[
function NTRVehiclePhaseAO.drawBar(parent, name, value, baseValue, y)
	label(parent, name, UDim2.new(0.43, 0, 0, 18), UDim2.fromOffset(0, y), 9, Enum.TextXAlignment.Left)
	local bar = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(39, 48, 49),
		BorderSizePixel = 0,
		Size = UDim2.new(0.54, 0, 0, 10),
		Position = UDim2.new(0.45, 0, 0, y + 4),
	}, parent)
	corner(bar, 3)
	local amount = math.clamp((tonumber(value) or 0) / 100, 0, 1)
	local baseAmount = math.clamp((tonumber(baseValue) or tonumber(value) or 0) / 100, 0, 1)
	local fill = new("Frame", {
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(math.min(amount, baseAmount), 1),
	}, bar)
	corner(fill, 3)
	if amount > baseAmount + 0.002 then
		local delta = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(84, 255, 126),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(baseAmount, 0),
			Size = UDim2.fromScale(amount - baseAmount, 1),
		}, bar)
		corner(delta, 3)
	elseif amount < baseAmount - 0.002 then
		local delta = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(230, 64, 74),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(amount, 0),
			Size = UDim2.fromScale(baseAmount - amount, 1),
		}, bar)
		corner(delta, 3)
	else
		fill.Size = UDim2.fromScale(amount, 1)
	end
	local valueLabel = label(bar, tostring(math.floor((tonumber(value) or 0) + 0.5)), UDim2.new(1, -6, 1, 0), UDim2.fromOffset(4, 0), 8, Enum.TextXAlignment.Left)
	valueLabel.TextColor3 = Color3.fromRGB(8, 10, 12)
	valueLabel.ZIndex = bar.ZIndex + 4
end

]=]

local gridHelpers = [=[
function NTR_phase8CardScaleForWidth(width)
	local base = math.max(1, NTR_phase6RawConfigNumber("CardWidth", 118))
	local maxScale = UserInputService.TouchEnabled and NTR_phase6RawConfigNumber("MobileCardScaleMax", 1.12) or NTR_phase6RawConfigNumber("DesktopCardScaleMax", 1.35)
	return math.clamp((tonumber(width) or base) / base, 0.85, maxScale)
end

function NTR_phase8ScaledNumber(name, fallback, width)
	return math.max(0, math.floor(NTR_phase6RawConfigNumber(name, fallback) * NTR_phase8CardScaleForWidth(width) + 0.5))
end

function NTR_phase10DeviceNumber(desktopName, mobileName, fallback)
	local key = UserInputService.TouchEnabled and mobileName or desktopName
	return NTR_phase6RawConfigNumber(key, fallback)
end

function NTR_phase8CardLayout(width)
	width = tonumber(width) or tonumber(NTR_phase6CurrentCardWidth) or NTR_phase6RawConfigNumber("CardWidth", 118)
	local pad = math.max(4, NTR_phase8ScaledNumber("CardOuterPadding", 8, width))
	local imageSize = math.max(1, width - pad * 2)
	local nameY = pad + imageSize + NTR_phase8ScaledNumber("ImageToTextGap", 5, width)
	local nameKey = UserInputService.TouchEnabled and "MobileNameHeight" or "DesktopNameHeight"
	local nameFallback = NTR_phase10DeviceNumber("DesktopNameHeight", "MobileNameHeight", 16)
	local nameH = math.max(12, NTR_phase8ScaledNumber(nameKey, nameFallback, width))
	local priceY = nameY + nameH + NTR_phase8ScaledNumber("PriceLineGap", 2, width)
	local cardH = priceY + nameH + NTR_phase8ScaledNumber("CardBottomPadding", 6, width)
	return {
		Width = width,
		Padding = pad,
		ImageSize = imageSize,
		ImageY = pad,
		NameY = nameY,
		NameHeight = nameH,
		PriceY = priceY,
		Height = cardH,
	}
end

function NTR_phase6GridCellSize(defaultWidth, availableWidth)
	local columns = NTR_phase6GridColumns()
	local gap = NTR_phase6RawConfigNumber("GridCellPadding", 10)
	local widthAvailable = tonumber(availableWidth) or 0
	if widthAvailable <= 0 and UI and UI.CockpitGrid then
		widthAvailable = UI.CockpitGrid.AbsoluteSize.X
	end
	if widthAvailable <= 0 then
		widthAvailable = (tonumber(defaultWidth) or NTR_phase6RawConfigNumber("CardWidth", 118)) * columns + gap * (columns - 1)
	end
	local rawWidth = math.floor((math.max(1, widthAvailable) - gap * (columns - 1)) / columns)
	local minKey = UserInputService.TouchEnabled and "MobileMinCardWidth" or "DesktopMinCardWidth"
	local maxKey = UserInputService.TouchEnabled and "MobileMaxCardWidth" or "DesktopMaxCardWidth"
	local width = math.clamp(rawWidth, NTR_phase6RawConfigNumber(minKey, 70), NTR_phase6RawConfigNumber(maxKey, 1000))
	NTR_phase6CurrentCardWidth = width
	NTR_phase6CurrentCardHeight = NTR_phase8CardLayout(width).Height
	return UDim2.fromOffset(width, NTR_phase6CurrentCardHeight)
end

]=]

local renderHelpers = [=[
function NTR_phase6CockpitCardSize()
	local width = tonumber(NTR_phase6CurrentCardWidth) or NTR_phase6RawConfigNumber("CardWidth", 118)
	local layout = NTR_phase8CardLayout(width)
	NTR_phase6CurrentCardWidth = layout.Width
	NTR_phase6CurrentCardHeight = layout.Height
	return UDim2.fromOffset(layout.Width, layout.Height)
end

function NTR_phase6ScaleType()
	local value = string.lower(NTR_phase6ConfigString("ImageScaleType", "Fit"))
	return value == "crop" and Enum.ScaleType.Crop or Enum.ScaleType.Fit
end

function NTR_phase9TextSize(name, fallback)
	local layout = NTR_phase8CardLayout()
	local base = fallback
	local key = name
	if name == "NameTextSize" then
		key = UserInputService.TouchEnabled and "MobileNameTextSize" or "DesktopNameTextSize"
		base = UserInputService.TouchEnabled and NTR_phase6RawConfigNumber("MobileNameTextSize", 10) or NTR_phase6RawConfigNumber("DesktopNameTextSize", 12)
	end
	return math.max(7, NTR_phase8ScaledNumber(key, base, layout.Width))
end

function NTR_phase9TierColor(tier)
	local badgeColor = Theme.Accent
	if NTRVehiclePhaseAO and typeof(NTRVehiclePhaseAO.tierColor) == "function" then
		local ok, color = pcall(function()
			return NTRVehiclePhaseAO.tierColor(tier)
		end)
		if ok and typeof(color) == "Color3" then
			badgeColor = color
		end
	end
	return badgeColor
end

function NTR_phase5RenderCockpitMenuImage(card, cockpit)
	local layout = NTR_phase8CardLayout()
	local icon = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(18, 27, 31),
		Size = UDim2.fromOffset(layout.ImageSize, layout.ImageSize),
		Position = UDim2.fromOffset(layout.Padding, layout.ImageY),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, card)
	icon:SetAttribute("PooledDynamic", true)
	corner(icon, NTR_phase6ConfigNumber("ImageCornerRadius", 4))
	stroke(icon, Theme.Accent, 0.75, 1)
	local imageId = NTR_phase5CockpitMenuImage(cockpit)
	if imageId ~= "" then
		local inset = NTR_phase6ConfigNumber("ImageInnerPadding", 4)
		local zoom = math.clamp(NTR_phase6ConfigNumber("ImageZoom", 1), 0.5, 2)
		local image = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = imageId,
			ScaleType = NTR_phase6ScaleType(),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(zoom, -inset * 2, zoom, -inset * 2),
			Position = UDim2.fromScale(0.5, 0.5),
			BorderSizePixel = 0,
		}, icon)
		image:SetAttribute("PooledDynamic", true)
	else
		local carShape = new("Frame", {
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(NTR_phase6ConfigNumber("FallbackBarWidth", 72), NTR_phase6ConfigNumber("FallbackBarHeight", 18)),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}, icon)
		carShape:SetAttribute("PooledDynamic", true)
		corner(carShape, 3)
	end
end

function NTR_phase8CockpitRatingParts(cockpit)
	if NTRVehiclePhaseAK and typeof(NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults) == "function"
		and NTRVehiclePhaseAO and typeof(NTRVehiclePhaseAO.performanceModules) == "function" then
		local statsOk, stats = pcall(function()
			return NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit or {})
		end)
		local _, Calculator = NTRVehiclePhaseAO.performanceModules()
		if statsOk and Calculator and typeof(Calculator.CalculateLegacy) == "function" then
			local ok, performance = pcall(function()
				return Calculator.CalculateLegacy(stats or {})
			end)
			local overall = ok and performance and performance.Overall or nil
			if overall then
				local tier = tostring(overall.Tier or "--")
				local index = tonumber(overall.PerformanceIndex)
				return tier, (index and tostring(math.floor(index)) or "---")
			end
		end
	end
	if NTRVehiclePhaseAO and typeof(NTRVehiclePhaseAO.performanceModules) == "function" then
		local _, Calculator = NTRVehiclePhaseAO.performanceModules()
		if Calculator and typeof(Calculator.CalculateLegacy) == "function" then
			local ok, performance = pcall(function()
				return Calculator.CalculateLegacy(cockpit or {})
			end)
			local overall = ok and performance and performance.Overall or nil
			if overall then
				local tier = tostring(overall.Tier or "--")
				local index = tonumber(overall.PerformanceIndex)
				return tier, (index and tostring(math.floor(index)) or "---")
			end
		end
	end
	local tier = tostring((cockpit and (cockpit.Tier or cockpit.PerformanceTier or cockpit.RatingTier)) or "--")
	local index = tonumber(cockpit and (cockpit.PerformanceIndex or cockpit.Rating or cockpit.OverallRating))
	return tier, (index and tostring(math.floor(index)) or "---")
end

function NTR_phase9RenderImageRatingBadge(card, tier, ratingIndex)
	local layout = NTR_phase8CardLayout()
	local scale = NTR_phase8CardScaleForWidth(layout.Width)
	local badgeW = math.max(42, NTR_phase8ScaledNumber("RatingBadgeWidth", 58, layout.Width))
	local badgeH = math.max(16, NTR_phase8ScaledNumber("RatingBadgeHeight", 20, layout.Width))
	local topInset = math.max(3, NTR_phase8ScaledNumber("RatingBadgeTopInset", 6, layout.Width))
	local rightInset = math.max(3, NTR_phase8ScaledNumber("RatingBadgeRightInset", 6, layout.Width))
	local x = layout.Padding + layout.ImageSize - rightInset - badgeW
	local y = layout.ImageY + topInset
	local badge = new("Frame", {
		BackgroundColor3 = NTR_phase9TierColor(tier),
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(badgeW, badgeH),
		Position = UDim2.fromOffset(x, y),
		ZIndex = (card.ZIndex or 1) + 14,
	}, card)
	badge:SetAttribute("PooledDynamic", true)
	corner(badge, NTR_phase6ConfigNumber("BadgeCornerRadius", 4))
	local text = pooledLabel(badge, tostring(tier or "--") .. " " .. tostring(ratingIndex or "---"), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), math.max(8, math.floor(NTR_phase6RawConfigNumber("RatingTextSize", 10) * scale + 0.5)), Enum.TextXAlignment.Center)
	text.TextColor3 = Color3.fromRGB(244, 250, 255)
	text.ZIndex = badge.ZIndex + 1
end

function NTR_phase8RenderCardTitleRating(card, titleText, tier, ratingIndex)
	local layout = NTR_phase8CardLayout()
	NTR_phase9RenderImageRatingBadge(card, tier, ratingIndex)
	pooledLabel(card, titleText, UDim2.new(1, -layout.Padding * 2, 0, layout.NameHeight), UDim2.fromOffset(layout.Padding, layout.NameY), NTR_phase9TextSize("NameTextSize", 10), Enum.TextXAlignment.Left)
end

function NTR_phase8RenderCockpitTitleRating(card, cockpit)
	local tier, ratingIndex = NTR_phase8CockpitRatingParts(cockpit)
	NTR_phase8RenderCardTitleRating(card, cockpit and (cockpit.DisplayName or cockpit.CockpitId) or "", tier, ratingIndex)
end

function NTR_phase8RenderCockpitPrice(card, priceText)
	local layout = NTR_phase8CardLayout()
	pooledLabel(card, priceText, UDim2.new(1, -layout.Padding * 2, 0, layout.NameHeight), UDim2.fromOffset(layout.Padding, layout.PriceY), NTR_phase9TextSize("NameTextSize", 10), Enum.TextXAlignment.Left).TextColor3 = Theme.Cash
end

]=]

local layoutSource = [=[
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
	local rightW = UserInputService.TouchEnabled and NTR_phase6RawConfigNumber("MobileStatsPanelWidth", 230) or NTR_phase6RawConfigNumber("DesktopStatsPanelWidth", 270)
	local bottomY = vh - BOTTOM_MARGIN
	-- NTR_PERSISTENCE_PHASE10_GARAGE_UI_LAYOUT_MODAL
	local leftPanelH = BOTTOM_HEIGHT
	local leftStackGap = 10
	local cashBottomY = bottomY
	local garageBottomY = cashBottomY - leftPanelH - leftStackGap
	local categoryBottomY = garageBottomY - leftPanelH - gap
	local categoryH = math.max(96, categoryBottomY - topY)
	local centerX = margin + leftW + gap
	local rightLeft = vw - margin - rightW
	local centerW = math.max(300, rightLeft - gap - centerX)
	local centerH = math.max(240, bottomY - topY)
	local exitButtonH = UserInputService.TouchEnabled and 48 or 42
	local exitPad = math.max(5, NTR_phase6RawConfigNumber("ExitPanelVerticalPadding", 9))
	local exitPanelH = exitButtonH + exitPad * 2
	local exitTopY = bottomY - exitPanelH
	local statsH = math.min(520, math.max(1, exitTopY - gap - topY))

	if UI.CategoryPanel then
		UI.CategoryPanel.Position = UDim2.fromOffset(margin, topY)
		UI.CategoryPanel.Size = UDim2.fromOffset(leftW, categoryH)
	end
	if UI.GarageCapacityPanel then
		UI.GarageCapacityPanel.AnchorPoint = Vector2.new(0, 1)
		UI.GarageCapacityPanel.Position = UDim2.fromOffset(margin, garageBottomY)
		UI.GarageCapacityPanel.Size = UDim2.fromOffset(leftW, leftPanelH)
	end
	if UI.CashPanel then
		UI.CashPanel.AnchorPoint = Vector2.new(0, 1)
		UI.CashPanel.Position = UDim2.fromOffset(margin, cashBottomY)
		UI.CashPanel.Size = UDim2.fromOffset(leftW, leftPanelH)
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
	if UI.DealershipExitPanel then
		UI.DealershipExitPanel.AnchorPoint = Vector2.new(1, 1)
		UI.DealershipExitPanel.Position = UDim2.fromOffset(vw - margin, bottomY)
		UI.DealershipExitPanel.Size = UDim2.fromOffset(rightW, exitPanelH)
	end
	if UI.DealershipExitButton then
		UI.DealershipExitButton.Size = UDim2.new(1, -18, 0, exitButtonH)
		UI.DealershipExitButton.Position = UDim2.new(0, 9, 1, -exitPad - exitButtonH)
	end
	if UI.CockpitGridLayout then
		local innerW = math.max(1, centerW - 20)
		local innerH = math.max(1, centerH - 20)
		local columns = NTR_phase6GridColumns()
		local cardSize = math.max(70, math.floor((innerW - NTR_phase6RawConfigNumber("GridCellPadding", 10) * (columns - 1)) / columns))
		UI.CockpitGridLayout.CellSize = NTR_phase6GridCellSize(cardSize, innerW)
		UI.CockpitGridLayout.CellPadding = UDim2.fromOffset(NTR_phase6RawConfigNumber("GridCellPadding", 10), NTR_phase6RawConfigNumber("GridCellPadding", 10))
		UI.CockpitGrid.CanvasSize = UDim2.fromOffset(0, math.max(innerH, UI.CockpitGridLayout.AbsoluteContentSize.Y + 10))
	end
end

]=]

local freeRoamUpdate = [=[
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

]=]

local function patchBootstrap()
	local bootstrap = activeBootstrap()
	local source = bootstrap.Source
	assert(findPlain(source, "-- " .. PHASE9_MARKER) or findPlain(source, "-- " .. MARKER), "Phase 9 marker is missing from the active bootstrap. Run Phase 9 first, or refresh the Studio mirror before patching.")

	if findPlain(source, "-- " .. PHASE9_MARKER) then
		source = replaceOnce(source, "-- " .. PHASE9_MARKER, "-- " .. MARKER, "Phase 10 marker")
	end

	source = replaceBetween(source, "function NTRVehiclePhaseAO.drawBar(parent, name, value, baseValue, y)", "function NTRVehiclePhaseAO.formatRaw(variableName, value)", drawBarSource, "Phase 10 stat bar renderer")
	source = replaceBetween(source, "function NTR_phase8CardScaleForWidth(width)", "function NTR_phase6CockpitCardSize()", gridHelpers, "Phase 10 card sizing helpers")
	source = replaceBetween(source, "function NTR_phase6CockpitCardSize()", "applyDealershipLayout = function()", renderHelpers, "Phase 10 card render helpers")
	source = replaceBetween(source, "applyDealershipLayout = function()", "local function renderDealershipPanel()", layoutSource, "Phase 10 dealership layout")

	local oldCategoryLabel = [=[	label(UI.CategoryPanel, "Categories", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 0), 13, Enum.TextXAlignment.Left)
	UI.CategoryList = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 1, -36), Position = UDim2.fromOffset(0, 36) }, UI.CategoryPanel)]=]
	local newCategoryLabel = [=[	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE10_CATEGORY_HEADER_REMOVED
	UI.CategoryList = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(0, 0) }, UI.CategoryPanel)]=]
	if findPlain(source, oldCategoryLabel) then
		source = replaceOnce(source, oldCategoryLabel, newCategoryLabel, "remove Categories heading")
	elseif findPlain(source, "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE10_CATEGORY_HEADER_REMOVED") then
		info("Category heading already removed.")
	else
		error("Could not find category heading block.")
	end

	local oldCustomiseButton = [=[		local customiseButton = button(UI.StatsPanel, "Customise", UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), Theme.Buy)]=]
	local newCustomiseButton = [=[		local panelActionH = UserInputService.TouchEnabled and 58 or 76
		local panelActionPad = math.max(4, NTR_phase6RawConfigNumber("PanelActionBottomPadding", 8))
		local customiseButton = button(UI.StatsPanel, "Customise", UDim2.new(1, 0, 0, panelActionH), UDim2.new(0, 0, 1, -panelActionPad - panelActionH), Theme.Buy)]=]
	if findPlain(source, oldCustomiseButton) then
		source = replaceOnce(source, oldCustomiseButton, newCustomiseButton, "customisation action button lower offset")
	elseif findPlain(source, "local panelActionH = UserInputService.TouchEnabled and 58 or 76") then
		info("Panel action button offset already patched.")
	else
		error("Could not find customisation action button block.")
	end

	local oldBuyButton = [=[	local actionButton = button(UI.StatsPanel, actionText, UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), Theme.Buy)]=]
	local newBuyButton = [=[	local panelActionH = UserInputService.TouchEnabled and 58 or 76
	local panelActionPad = math.max(4, NTR_phase6RawConfigNumber("PanelActionBottomPadding", 8))
	local actionButton = button(UI.StatsPanel, actionText, UDim2.new(1, 0, 0, panelActionH), UDim2.new(0, 0, 1, -panelActionPad - panelActionH), Theme.Buy)]=]
	if findPlain(source, oldBuyButton) then
		source = replaceOnce(source, oldBuyButton, newBuyButton, "buy action button lower offset")
	elseif findPlain(source, "local actionButton = button(UI.StatsPanel, actionText, UDim2.new(1, 0, 0, panelActionH)") then
		info("Buy action button offset already patched.")
	else
		error("Could not find buy action button block.")
	end

	bootstrap.Source = source
	assert(bootstrap.Source:find(MARKER, 1, true), "Phase 10 marker was not installed.")
	assert(bootstrap.Source:find("MobileStatsPanelWidth", 1, true), "Phase 10 mobile stats width path was not installed.")
	assert(bootstrap.Source:find("CATEGORY_HEADER_REMOVED", 1, true), "Phase 10 category heading removal was not installed.")
	assert(bootstrap.Source:find("valueLabel.TextColor3 = Color3.fromRGB(8, 10, 12)", 1, true), "Phase 10 stat bar value styling was not installed.")
	info("Patched dealership/customisation responsive layout.")
end

local function patchFreeRoam()
	local nav = activeFreeRoamNav()
	local source = nav.Source
	assert(findPlain(source, "local function updateCarButtonImage()"), "FreeRoamNavController_Active has no updateCarButtonImage helper.")
	assert(findPlain(source, "local function attachIcon(button, iconValueName, fallbackText, iconScale)"), "FreeRoamNavController_Active does not have the expected attachIcon anchor.")
	source = replaceBetween(source, "local function updateCarButtonImage()", "local function attachIcon(button, iconValueName, fallbackText, iconScale)", freeRoamUpdate, "Phase 10 free-roam car icon scale")
	nav.Source = source
	assert(nav.Source:find("FreeRoamCarIconScale\", 0.48", 1, true), "Free-roam car icon scale default was not installed.")
	info("Patched free-roam car icon scale to match the other stack icons.")
end

ensureConfig()
patchBootstrap()
patchFreeRoam()

info("PASS. Restart Play and verify mobile/right-panel spacing, category header removal, PC card text size, stat bar values, and free-roam car icon size.")
