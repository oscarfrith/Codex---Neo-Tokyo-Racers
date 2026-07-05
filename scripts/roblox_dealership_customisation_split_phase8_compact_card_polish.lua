-- Neo Tokyo Racers - Dealership / Customisation Split Phase 8
-- Compact responsive cockpit-card polish.
--
-- Run in Roblox Studio Command Bar while in Edit mode.
--
-- This is a guarded source patch against the active client bootstrap. It
-- expects the Phase 6/7 cockpit-card helper markers and only changes cockpit
-- card layout/rendering.

local PHASE = "NTR Dealership/Customisation Phase 8 Compact Cockpit Cards"
local PHASE6_MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_SQUARE_COCKPIT_IMAGES"
local PHASE6_REPAIR_MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_REGISTER_LIMIT_REPAIR"
local PHASE7_MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE7_RESPONSIVE_COCKPIT_GRID"
local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE8_COMPACT_COCKPIT_CARDS"

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function replaceOnce(source, needle, replacement, label)
	local index = string.find(source, needle, 1, true)
	assert(index, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before creating another patch.")
	return string.sub(source, 1, index - 1) .. replacement .. string.sub(source, index + #needle)
end

local function replaceBetween(source, startNeedle, endNeedle, replacement, label)
	local startIndex = string.find(source, startNeedle, 1, true)
	assert(startIndex, "Could not find start anchor for " .. label .. ". Refresh the Studio mirror before creating another patch.")
	local endIndex = string.find(source, endNeedle, startIndex, true)
	assert(endIndex, "Could not find end anchor for " .. label .. ". Refresh the Studio mirror before creating another patch.")
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")

local function ensureChild(parent, className, name)
	local child = parent:FindFirstChild(name)
	if child then
		assert(child.ClassName == className, child:GetFullName() .. " must be a " .. className)
		return child
	end
	child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function ensureNumber(parent, name, value, force)
	local item = parent:FindFirstChild(name)
	if item then
		assert(item:IsA("NumberValue"), item:GetFullName() .. " must be a NumberValue")
		if force then item.Value = value end
		return item
	end
	item = Instance.new("NumberValue")
	item.Name = name
	item.Value = value
	item.Parent = parent
	return item
end

local function ensureBool(parent, name, value, force)
	local item = parent:FindFirstChild(name)
	if item then
		assert(item:IsA("BoolValue"), item:GetFullName() .. " must be a BoolValue")
		if force then item.Value = value end
		return item
	end
	item = Instance.new("BoolValue")
	item.Name = name
	item.Value = value
	item.Parent = parent
	return item
end

local function activeBootstrap()
	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local root = playerScripts:WaitForChild("NeoTokyoRacersClient")
	local scriptObject = root:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
	assert(scriptObject:IsA("LocalScript"), "Active bootstrap path is not a LocalScript.")
	return scriptObject
end

local function ensureConfig()
	local configRoot = ensureChild(kit, "Folder", "Config")
	local uiRoot = ensureChild(configRoot, "Folder", "UI")
	local cards = ensureChild(uiRoot, "Folder", "CockpitMenuCards")
	ensureBool(cards, "UseResponsiveGridWidth", true, true)
	ensureBool(cards, "ResponsiveCardScaleEnabled", true)
	ensureNumber(cards, "DesktopColumns", 4)
	ensureNumber(cards, "MobileColumns", 3)
	ensureNumber(cards, "DesktopMaxCardWidth", 1000, true)
	ensureNumber(cards, "MobileMaxCardWidth", 1000, true)
	ensureNumber(cards, "CardOuterPadding", 8)
	ensureNumber(cards, "ImageInnerPadding", 4)
	ensureNumber(cards, "ImageZoom", 1)
	ensureNumber(cards, "ImageToTextGap", 7)
	ensureNumber(cards, "NameHeight", 18)
	ensureNumber(cards, "NameTextSize", 9)
	ensureNumber(cards, "PriceLineGap", 3)
	ensureNumber(cards, "CardBottomPadding", 8)
	ensureNumber(cards, "RatingTotalWidth", 48)
	ensureNumber(cards, "RatingBadgeWidth", 18)
	ensureNumber(cards, "RatingBadgeHeight", 14)
	ensureNumber(cards, "RatingGap", 3)
	ensureNumber(cards, "RatingTextSize", 8)
	info("Ensured compact cockpit-card config values.")
end

local gridHelpers = [=[
function NTR_phase8CardScaleForWidth(width)
	return math.clamp((tonumber(width) or NTR_phase6RawConfigNumber("CardWidth", 118)) / math.max(1, NTR_phase6RawConfigNumber("CardWidth", 118)), 0.55, 2)
end

function NTR_phase8ScaledNumber(name, fallback, width)
	return math.max(0, math.floor(NTR_phase6RawConfigNumber(name, fallback) * NTR_phase8CardScaleForWidth(width) + 0.5))
end

function NTR_phase8CardLayout(width)
	width = tonumber(width) or tonumber(NTR_phase6CurrentCardWidth) or NTR_phase6RawConfigNumber("CardWidth", 118)
	local pad = math.max(3, NTR_phase8ScaledNumber("CardOuterPadding", 8, width))
	local imageSize = math.max(1, width - pad * 2)
	local nameY = pad + imageSize + NTR_phase8ScaledNumber("ImageToTextGap", 7, width)
	local nameH = math.max(10, NTR_phase8ScaledNumber("NameHeight", 18, width))
	local priceY = nameY + nameH + NTR_phase8ScaledNumber("PriceLineGap", 3, width)
	local cardH = priceY + nameH + NTR_phase8ScaledNumber("CardBottomPadding", 8, width)
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

function NTR_phase8RenderCardTitleRating(card, titleText, tier, ratingIndex)
	local layout = NTR_phase8CardLayout()
	local ratingW = math.max(30, NTR_phase6ConfigNumber("RatingTotalWidth", 48))
	local badgeW = math.max(12, NTR_phase6ConfigNumber("RatingBadgeWidth", 18))
	local badgeH = math.max(10, NTR_phase6ConfigNumber("RatingBadgeHeight", 14))
	local gap = NTR_phase6ConfigNumber("RatingGap", 3)
	local ratingX = math.max(layout.Padding, layout.Width - layout.Padding - ratingW)
	local nameW = math.max(10, ratingX - layout.Padding - gap)
	pooledLabel(card, titleText, UDim2.fromOffset(nameW, layout.NameHeight), UDim2.fromOffset(layout.Padding, layout.NameY), NTR_phase6ConfigNumber("NameTextSize", 9), Enum.TextXAlignment.Left)
	local badgeColor = Theme.Accent
	if NTRVehiclePhaseAO and typeof(NTRVehiclePhaseAO.tierColor) == "function" then
		local ok, color = pcall(function()
			return NTRVehiclePhaseAO.tierColor(tier)
		end)
		if ok and typeof(color) == "Color3" then
			badgeColor = color
		end
	end
	local badge = new("Frame", {
		BackgroundColor3 = badgeColor,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(badgeW, badgeH),
		Position = UDim2.fromOffset(ratingX, layout.NameY + math.floor((layout.NameHeight - badgeH) / 2)),
	}, card)
	badge:SetAttribute("PooledDynamic", true)
	corner(badge, 3)
	pooledLabel(badge, tostring(tier or "--"), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), NTR_phase6ConfigNumber("RatingTextSize", 8), Enum.TextXAlignment.Center)
	local ratingLabel = pooledLabel(card, tostring(ratingIndex or "---"), UDim2.fromOffset(math.max(8, ratingW - badgeW - gap), layout.NameHeight), UDim2.fromOffset(ratingX + badgeW + gap, layout.NameY), NTR_phase6ConfigNumber("RatingTextSize", 8), Enum.TextXAlignment.Right)
	ratingLabel.TextColor3 = Theme.Accent
end

function NTR_phase8RenderCockpitTitleRating(card, cockpit)
	local tier, ratingIndex = NTR_phase8CockpitRatingParts(cockpit)
	NTR_phase8RenderCardTitleRating(card, cockpit and (cockpit.DisplayName or cockpit.CockpitId) or "", tier, ratingIndex)
end

function NTR_phase8RenderCockpitPrice(card, priceText)
	local layout = NTR_phase8CardLayout()
	pooledLabel(card, priceText, UDim2.new(1, -layout.Padding * 2, 0, layout.NameHeight), UDim2.fromOffset(layout.Padding, layout.PriceY), NTR_phase6ConfigNumber("NameTextSize", 9), Enum.TextXAlignment.Left).TextColor3 = Theme.Cash
end

]=]

local function markerNeedle(source)
	for _, marker in ipairs({ MARKER, PHASE7_MARKER, PHASE6_REPAIR_MARKER, PHASE6_MARKER }) do
		local needle = "-- " .. marker
		if findPlain(source, needle) then
			return needle
		end
	end
	return nil
end

local function patchResponsiveHelpers(source)
	local startNeedle = markerNeedle(source)
	assert(startNeedle, "Could not find the Phase 6/7 cockpit helper marker in the active bootstrap. Run Phase 6/7 first, or refresh the mirror if Studio changed.")
	source = replaceOnce(source, startNeedle, "-- " .. MARKER, "Phase 8 marker")
	source = replaceBetween(
		source,
		"function NTR_phase6GridCellSize(defaultWidth, availableWidth)",
		"function NTR_phase6CockpitCardSize()",
		gridHelpers,
		"compact cockpit grid sizing helpers"
	)
	source = replaceBetween(
		source,
		"function NTR_phase6CockpitCardSize()",
		"applyDealershipLayout = function()",
		renderHelpers,
		"compact cockpit card render helpers"
	)
	local oldCall = [=[UI.CockpitGridLayout.CellSize = NTR_phase6GridCellSize(cardSize)]=]
	local newCall = [=[UI.CockpitGridLayout.CellSize = NTR_phase6GridCellSize(cardSize, innerW)]=]
	if findPlain(source, oldCall) then
		source = replaceOnce(source, oldCall, newCall, "responsive cockpit grid width argument")
	end
	if findPlain(source, [=[pooledButton(cockpitPool, "", UDim2.fromOffset(118, 118)]=]) then
		source = string.gsub(source, [=[pooledButton%(cockpitPool, "", UDim2%.fromOffset%(118, 118%)]=], [=[pooledButton(cockpitPool, "", NTR_phase6CockpitCardSize()]=])
	end
	return source
end

local function patchCardText(source)
	local oldCustomPhase6 = [=[			pooledLabel(card, nameText, UDim2.new(1, -14, 0, NTR_phase6ConfigNumber("NameHeight", 26)), UDim2.fromOffset(NTR_phase6ConfigNumber("NameX", 7), NTR_phase6ConfigNumber("NameY", 116)), NTR_phase6ConfigNumber("NameTextSize", 9), Enum.TextXAlignment.Left)
			local tier, ratingIndex = vehicleRatingParts(row.VehicleId)
			local tierBadge = new("Frame", { BackgroundColor3 = tierBadgeColor(tier), BackgroundTransparency = 0.05, BorderSizePixel = 0, Size = UDim2.fromOffset(NTR_phase6ConfigNumber("TierBadgeWidth", 26), NTR_phase6ConfigNumber("TierBadgeHeight", 18)), Position = UDim2.fromOffset(NTR_phase6ConfigNumber("TierBadgeX", 7), NTR_phase6ConfigNumber("TierBadgeY", 142)) }, card)
			tierBadge:SetAttribute("PooledDynamic", true)
			corner(tierBadge, 3)
			pooledLabel(tierBadge, tier, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, ratingIndex, UDim2.new(1, -44, 0, 20), UDim2.fromOffset(NTR_phase6ConfigNumber("RatingX", 38), NTR_phase6ConfigNumber("RatingY", 142)), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Accent]=]
	local oldCustomLegacy = [=[			pooledLabel(card, nameText, UDim2.new(1, -14, 0, 30), UDim2.fromOffset(7, 55), 9, Enum.TextXAlignment.Left)
			local tier, ratingIndex = vehicleRatingParts(row.VehicleId)
			local tierBadge = new("Frame", { BackgroundColor3 = tierBadgeColor(tier), BackgroundTransparency = 0.05, BorderSizePixel = 0, Size = UDim2.fromOffset(26, 18), Position = UDim2.fromOffset(7, 86) }, card)
			tierBadge:SetAttribute("PooledDynamic", true)
			corner(tierBadge, 3)
			pooledLabel(tierBadge, tier, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, ratingIndex, UDim2.new(1, -44, 0, 20), UDim2.fromOffset(38, 86), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Accent]=]
	local newCustom = [=[			local tier, ratingIndex = vehicleRatingParts(row.VehicleId)
			NTR_phase8RenderCardTitleRating(card, nameText, tier, ratingIndex)]=]
	if findPlain(source, oldCustomPhase6) then
		source = replaceOnce(source, oldCustomPhase6, newCustom, "customisation card title/rating row")
	elseif findPlain(source, oldCustomLegacy) then
		source = replaceOnce(source, oldCustomLegacy, newCustom, "customisation card title/rating row legacy")
	elseif findPlain(source, "NTR_phase8RenderCardTitleRating(card, nameText") then
		info("Customisation card title/rating row already uses Phase 8.")
	else
		error("Could not find customisation card title/rating block.")
	end

	local oldDealershipPhase6 = [=[			pooledLabel(card, cockpit.DisplayName or cockpit.CockpitId, UDim2.new(1, -14, 0, NTR_phase6ConfigNumber("NameHeight", 26)), UDim2.fromOffset(NTR_phase6ConfigNumber("NameX", 7), NTR_phase6ConfigNumber("NameY", 116)), NTR_phase6ConfigNumber("NameTextSize", 9), Enum.TextXAlignment.Left)]=]
	local oldDealershipLegacy = [=[			pooledLabel(card, cockpit.DisplayName or cockpit.CockpitId, UDim2.new(1, -14, 0, 30), UDim2.fromOffset(7, 55), 9, Enum.TextXAlignment.Left)]=]
	local newDealership = [=[			NTR_phase8RenderCockpitTitleRating(card, cockpit)]=]
	if findPlain(source, oldDealershipPhase6) then
		source = replaceOnce(source, oldDealershipPhase6, newDealership, "dealership card title/rating row")
	elseif findPlain(source, oldDealershipLegacy) then
		source = replaceOnce(source, oldDealershipLegacy, newDealership, "dealership card title/rating row legacy")
	elseif findPlain(source, newDealership) then
		info("Dealership card title/rating row already uses Phase 8.")
	else
		error("Could not find dealership card title block.")
	end

	local oldPricePhase6 = [=[			pooledLabel(card, "$" .. tostring(cockpit.Price or 0), UDim2.new(1, -14, 0, 20), UDim2.fromOffset(NTR_phase6ConfigNumber("NameX", 7), NTR_phase6ConfigNumber("PriceY", 142)), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Cash]=]
	local oldPriceLegacy = [=[			pooledLabel(card, "$" .. tostring(cockpit.Price or 0), UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 86), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Cash]=]
	local newPrice = [=[			NTR_phase8RenderCockpitPrice(card, "$" .. tostring(cockpit.Price or 0))]=]
	if findPlain(source, oldPricePhase6) then
		source = replaceOnce(source, oldPricePhase6, newPrice, "dealership card price row")
	elseif findPlain(source, oldPriceLegacy) then
		source = replaceOnce(source, oldPriceLegacy, newPrice, "dealership card price row legacy")
	elseif findPlain(source, newPrice) then
		info("Dealership card price row already uses Phase 8.")
	else
		error("Could not find dealership card price block.")
	end

	return source
end

ensureConfig()

local bootstrap = activeBootstrap()
local source = bootstrap.Source
source = patchResponsiveHelpers(source)
source = patchCardText(source)
bootstrap.Source = source

assert(bootstrap.Source:find(MARKER, 1, true), "Phase 8 marker was not installed.")
assert(bootstrap.Source:find("function NTR_phase8CardLayout", 1, true), "Phase 8 card layout helper was not installed.")
assert(bootstrap.Source:find("NTR_phase8RenderCockpitTitleRating(card, cockpit)", 1, true), "Dealership title/rating renderer was not installed.")
assert(bootstrap.Source:find("NTR_phase8RenderCockpitPrice(card", 1, true), "Dealership price renderer was not installed.")
assert(not bootstrap.Source:find("local function NTR_phase6", 1, true), "A local Phase 6 helper remains in the bootstrap.")

info("PASS. Restart Play and verify compact cards, even image padding, inline tier/rating, and 4/3 responsive columns.")
