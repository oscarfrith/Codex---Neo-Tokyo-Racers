-- Neo Tokyo Racers - Dealership / Customisation Split Phase 9
-- Badge overlay, tighter cockpit cards, and free-roam car icon restore.
--
-- This is a guarded source patch against the active Studio client bootstrap and
-- the isolated FreeRoamNavController_Active. It expects Phase 8 to be installed.
-- If an anchor is missing, refresh the Studio mirror before creating another patch.

local PHASE = "NTR Dealership/Customisation Phase 9 Badge Overlay Tight Cards"
local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE9_BADGE_OVERLAY_TIGHT_CARDS"
local PHASE8_MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE8_COMPACT_COCKPIT_CARDS"

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

	ensureNumber(cards, "DesktopColumns", 4)
	ensureNumber(cards, "MobileColumns", 3)
	ensureNumber(cards, "DesktopMaxCardWidth", 1000, true)
	ensureNumber(cards, "MobileMaxCardWidth", 1000, true)

	ensureNumber(cards, "CardOuterPadding", 8, true)
	ensureNumber(cards, "ImageInnerPadding", 4)
	ensureNumber(cards, "ImageZoom", 1)
	ensureNumber(cards, "ImageToTextGap", 5, true)
	ensureNumber(cards, "NameHeight", 16, true)
	ensureNumber(cards, "NameTextSize", 10, true)
	ensureNumber(cards, "PriceLineGap", 2, true)
	ensureNumber(cards, "CardBottomPadding", 6, true)

	ensureNumber(cards, "RatingBadgeWidth", 58, true)
	ensureNumber(cards, "RatingBadgeHeight", 20, true)
	ensureNumber(cards, "RatingBadgeTopInset", 6, true)
	ensureNumber(cards, "RatingBadgeRightInset", 6, true)
	ensureNumber(cards, "RatingTextSize", 10, true)
	ensureNumber(cards, "BadgeCornerRadius", 4)

	info("Ensured Phase 9 cockpit-card config values.")
end

local gridHelpers = [=[
function NTR_phase8CardScaleForWidth(width)
	return math.clamp((tonumber(width) or NTR_phase6RawConfigNumber("CardWidth", 118)) / math.max(1, NTR_phase6RawConfigNumber("CardWidth", 118)), 0.85, 1.25)
end

function NTR_phase8ScaledNumber(name, fallback, width)
	return math.max(0, math.floor(NTR_phase6RawConfigNumber(name, fallback) * NTR_phase8CardScaleForWidth(width) + 0.5))
end

function NTR_phase8CardLayout(width)
	width = tonumber(width) or tonumber(NTR_phase6CurrentCardWidth) or NTR_phase6RawConfigNumber("CardWidth", 118)
	local pad = math.max(4, NTR_phase8ScaledNumber("CardOuterPadding", 8, width))
	local imageSize = math.max(1, width - pad * 2)
	local nameY = pad + imageSize + NTR_phase8ScaledNumber("ImageToTextGap", 5, width)
	local nameH = math.max(12, NTR_phase8ScaledNumber("NameHeight", 16, width))
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
	return math.max(7, NTR_phase8ScaledNumber(name, fallback, layout.Width))
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
		local icon = ensureImageIcon(carButton, cockpitMenuCardConfigNumber("FreeRoamCarIconScale", 0.72))
		if icon then
			icon.Image = imageId
			icon.Visible = true
			icon:SetAttribute("NTRIconScale", cockpitMenuCardConfigNumber("FreeRoamCarIconScale", 0.72))
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
	assert(findPlain(source, "-- " .. PHASE8_MARKER) or findPlain(source, "-- " .. MARKER), "Phase 8 cockpit-card marker is missing from the active bootstrap. Run Phase 8 first, or refresh the Studio mirror before patching.")

	if findPlain(source, "-- " .. PHASE8_MARKER) then
		source = replaceOnce(source, "-- " .. PHASE8_MARKER, "-- " .. MARKER, "Phase 9 marker")
	end

	source = replaceBetween(
		source,
		"function NTR_phase8CardScaleForWidth(width)",
		"function NTR_phase6CockpitCardSize()",
		gridHelpers,
		"Phase 9 compact grid helpers"
	)
	source = replaceBetween(
		source,
		"function NTR_phase6CockpitCardSize()",
		"applyDealershipLayout = function()",
		renderHelpers,
		"Phase 9 card render helpers"
	)

	bootstrap.Source = source
	assert(bootstrap.Source:find(MARKER, 1, true), "Phase 9 marker was not installed.")
	assert(bootstrap.Source:find("function NTR_phase9RenderImageRatingBadge", 1, true), "Phase 9 image badge renderer was not installed.")
	assert(bootstrap.Source:find("dealershipStatsWithIncludedDefaults", 1, true), "Phase 9 dealership rating path was not installed.")
	info("Patched dealership/customisation cockpit cards.")
end

local function patchFreeRoam()
	local nav = activeFreeRoamNav()
	local source = nav.Source
	assert(findPlain(source, "local function updateCarButtonImage()"), "FreeRoamNavController_Active has no updateCarButtonImage helper; inspect the live source before patching free-roam icon behavior.")
	assert(findPlain(source, "local function attachIcon(button, iconValueName, fallbackText, iconScale)"), "FreeRoamNavController_Active does not have the expected attachIcon anchor.")
	source = replaceBetween(
		source,
		"local function updateCarButtonImage()",
		"local function attachIcon(button, iconValueName, fallbackText, iconScale)",
		freeRoamUpdate,
		"Phase 9 free-roam car icon restore"
	)
	nav.Source = source
	assert(nav.Source:find("FreeRoamUsesCockpitMenuImage", 1, true), "Free-roam cockpit-image toggle was not installed.")
	info("Patched free-roam car button to use FreeRoamNav.CarIcon by default.")
end

ensureConfig()
patchBootstrap()
patchFreeRoam()

info("PASS. Restart Play and verify image-overlay badges, tighter card gaps, correct dealership ratings, and restored free-roam car icon.")
