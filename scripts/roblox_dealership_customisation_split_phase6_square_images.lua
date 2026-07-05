-- Neo Tokyo Racers - Dealership / Customisation Split Phase 6
-- Square configurable cockpit thumbnails and more robust image lookup.
--
-- Run in Roblox Studio Command Bar while in Edit mode.
--
-- This is a guarded follow-up to Phase 5. It patches the active
-- dealership/customisation bootstrap plus the isolated free-roam nav controller.

local PHASE = "NTR Dealership/Customisation Phase 6"
local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_SQUARE_COCKPIT_IMAGES"

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function replaceOnce(source, old, new, label)
	local startIndex, endIndex = string.find(source, old, 1, true)
	assert(startIndex, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another patch.")
	return string.sub(source, 1, startIndex - 1) .. new .. string.sub(source, endIndex + 1)
end

local function replaceBetween(source, startNeedle, endNeedle, replacement, label)
	local startIndex = string.find(source, startNeedle, 1, true)
	assert(startIndex, "Could not find start anchor for " .. label .. ".")
	local endIndex = string.find(source, endNeedle, startIndex, true)
	assert(endIndex, "Could not find end anchor for " .. label .. ".")
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")

local function ensureChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, existing:GetFullName() .. " must be a " .. className)
		return existing
	end
	local item = Instance.new(className)
	item.Name = name
	item.Parent = parent
	return item
end

local function ensureNumber(parent, name, value)
	local item = parent:FindFirstChild(name)
	if item then
		assert(item:IsA("NumberValue"), item:GetFullName() .. " must be a NumberValue")
		return item
	end
	item = Instance.new("NumberValue")
	item.Name = name
	item.Value = value
	item.Parent = parent
	return item
end

local function ensureBool(parent, name, value)
	local item = parent:FindFirstChild(name)
	if item then
		assert(item:IsA("BoolValue"), item:GetFullName() .. " must be a BoolValue")
		return item
	end
	item = Instance.new("BoolValue")
	item.Name = name
	item.Value = value
	item.Parent = parent
	return item
end

local function ensureString(parent, name, value)
	local item = parent:FindFirstChild(name)
	if item then
		assert(item:IsA("StringValue"), item:GetFullName() .. " must be a StringValue")
		if item.Value == "" and value ~= "" then item.Value = value end
		return item
	end
	item = Instance.new("StringValue")
	item.Name = name
	item.Value = value
	item.Parent = parent
	return item
end

local function ensureConfig()
	local configRoot = ensureChild(kit, "Folder", "Config")
	local uiRoot = ensureChild(configRoot, "Folder", "UI")
	local cards = ensureChild(uiRoot, "Folder", "CockpitMenuCards")
	ensureString(cards, "README", "Cockpit menu thumbnails read each cockpit model's MenuImage first, then child StringValues/Decals/ImageLabels named MenuImage, CockpitImage, ThumbnailImage, ImageId, or Image.")
	ensureNumber(cards, "CardWidth", 118)
	ensureNumber(cards, "CardHeight", 176)
	ensureBool(cards, "UseResponsiveGridWidth", false)
	ensureNumber(cards, "GridCellPadding", 10)
	ensureNumber(cards, "ImageBoxX", 9)
	ensureNumber(cards, "ImageBoxY", 9)
	ensureNumber(cards, "ImageBoxSize", 100)
	ensureNumber(cards, "ImageInnerPadding", 4)
	ensureNumber(cards, "ImageCornerRadius", 4)
	ensureString(cards, "ImageScaleType", "Fit")
	ensureNumber(cards, "FallbackBarWidth", 72)
	ensureNumber(cards, "FallbackBarHeight", 18)
	ensureNumber(cards, "NameX", 7)
	ensureNumber(cards, "NameY", 116)
	ensureNumber(cards, "NameHeight", 26)
	ensureNumber(cards, "NameTextSize", 9)
	ensureNumber(cards, "PriceY", 142)
	ensureNumber(cards, "RatingY", 142)
	ensureNumber(cards, "TierBadgeX", 7)
	ensureNumber(cards, "TierBadgeY", 142)
	ensureNumber(cards, "TierBadgeWidth", 26)
	ensureNumber(cards, "TierBadgeHeight", 18)
	ensureNumber(cards, "RatingX", 38)
	ensureNumber(cards, "FreeRoamCarIconScale", 0.72)
	info("Ensured ReplicatedStorage.NeoTokyoRacers.Config.UI.CockpitMenuCards values.")
end

local function ensureCockpitImageAttributes()
	local categories = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
	local count = 0
	for _, category in ipairs(categories:GetChildren()) do
		local root = category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS")
		if root then
			for _, descendant in ipairs(root:GetDescendants()) do
				if descendant:IsA("Model") and descendant:GetAttribute("CockpitId") then
					if descendant:GetAttribute("MenuImage") == nil then
						descendant:SetAttribute("MenuImage", "")
						count += 1
					end
				end
			end
		end
	end
	info("Ensured MenuImage attribute on " .. tostring(count) .. " cockpit model(s) that were missing it.")
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

local bootstrapHelper = [=[
-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_SQUARE_COCKPIT_IMAGES
function NTR_phase6CardConfig()
	local config = kit:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	return ui and ui:FindFirstChild("CockpitMenuCards") or nil
end

function NTR_phase6ConfigNumber(name, fallback)
	local folder = NTR_phase6CardConfig()
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

function NTR_phase6ConfigBool(name, fallback)
	local folder = NTR_phase6CardConfig()
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("BoolValue") and item.Value or fallback
end

function NTR_phase6ConfigString(name, fallback)
	local folder = NTR_phase6CardConfig()
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("StringValue") and item.Value or fallback
end

function NTR_phase6AssetImage(value)
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

function NTR_phase5AssetImage(value)
	return NTR_phase6AssetImage(value)
end

function NTR_phase6ReadImageObject(object)
	if not object then return "" end
	local names = { "MenuImage", "CockpitImage", "ThumbnailImage", "ImageId", "Image" }
	for _, name in ipairs(names) do
		local image = NTR_phase6AssetImage(object:GetAttribute(name))
		if image ~= "" then return image end
		local child = object:FindFirstChild(name)
		if child then
			if child:IsA("StringValue") then
				image = NTR_phase6AssetImage(child.Value)
			elseif child:IsA("Decal") or child:IsA("Texture") then
				image = NTR_phase6AssetImage(child.Texture)
			elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
				image = NTR_phase6AssetImage(child.Image)
			end
			if image ~= "" then return image end
		end
	end
	for _, child in ipairs(object:GetDescendants()) do
		local lower = string.lower(child.Name)
		if string.find(lower, "menuimage", 1, true) or string.find(lower, "cockpitimage", 1, true) or string.find(lower, "thumbnail", 1, true) then
			local image = ""
			if child:IsA("StringValue") then
				image = NTR_phase6AssetImage(child.Value)
			elseif child:IsA("Decal") or child:IsA("Texture") then
				image = NTR_phase6AssetImage(child.Texture)
			elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
				image = NTR_phase6AssetImage(child.Image)
			end
			if image ~= "" then return image end
		end
	end
	return ""
end

function NTR_phase6FindCockpitModel(cockpit)
	local cockpitId = cockpit and tostring(cockpit.CockpitId or cockpit.CockpitID or cockpit.Id or cockpit.Name or "")
	if cockpitId == "" then return nil end
	for _, category in ipairs(categoriesRoot:GetChildren()) do
		local root = category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS")
		if root then
			for _, candidate in ipairs(root:GetDescendants()) do
				if candidate:IsA("Model") then
					local candidateId = tostring(candidate:GetAttribute("CockpitId") or candidate.Name)
					if candidateId == cockpitId or candidate.Name == cockpitId then
						return candidate
					end
				end
			end
		end
	end
	return nil
end

function NTR_phase6ReadModelOrAncestors(model)
	local image = NTR_phase6ReadImageObject(model)
	if image ~= "" then return image end
	local current = model and model.Parent
	while current and current ~= categoriesRoot do
		image = NTR_phase6ReadImageObject(current)
		if image ~= "" then return image end
		current = current.Parent
	end
	return ""
end

function NTR_phase5CockpitMenuImage(cockpit)
	local fromCatalog = NTR_phase6AssetImage(cockpit and (cockpit.MenuImage or cockpit.CockpitImage or cockpit.ThumbnailImage or cockpit.ImageId or cockpit.Image) or "")
	if fromCatalog ~= "" then return fromCatalog end
	return NTR_phase6ReadModelOrAncestors(NTR_phase6FindCockpitModel(cockpit))
end

function NTR_phase6CockpitCardSize()
	return UDim2.fromOffset(NTR_phase6ConfigNumber("CardWidth", 118), NTR_phase6ConfigNumber("CardHeight", 176))
end

function NTR_phase6GridCellSize(defaultWidth)
	local width = NTR_phase6ConfigBool("UseResponsiveGridWidth", false) and defaultWidth or NTR_phase6ConfigNumber("CardWidth", defaultWidth or 118)
	local ratio = NTR_phase6ConfigNumber("CardHeight", 176) / math.max(1, NTR_phase6ConfigNumber("CardWidth", 118))
	return UDim2.fromOffset(width, math.floor(width * ratio + 0.5))
end

function NTR_phase6ScaleType()
	local value = string.lower(NTR_phase6ConfigString("ImageScaleType", "Fit"))
	return value == "crop" and Enum.ScaleType.Crop or Enum.ScaleType.Fit
end

function NTR_phase5RenderCockpitMenuImage(card, cockpit)
	local size = NTR_phase6ConfigNumber("ImageBoxSize", 100)
	local icon = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(18, 27, 31),
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromOffset(NTR_phase6ConfigNumber("ImageBoxX", 9), NTR_phase6ConfigNumber("ImageBoxY", 9)),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, card)
	icon:SetAttribute("PooledDynamic", true)
	corner(icon, NTR_phase6ConfigNumber("ImageCornerRadius", 4))
	stroke(icon, Theme.Accent, 0.75, 1)
	local imageId = NTR_phase5CockpitMenuImage(cockpit)
	if imageId ~= "" then
		local inset = NTR_phase6ConfigNumber("ImageInnerPadding", 4)
		local image = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = imageId,
			ScaleType = NTR_phase6ScaleType(),
			Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
			Position = UDim2.fromOffset(inset, inset),
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

]=]

local function patchBootstrap()
	local scriptObject = activeBootstrap()
	local source = scriptObject.Source
	local changed = false

	if not findPlain(source, MARKER) then
		source = replaceOnce(source, [=[applyDealershipLayout = function()]=], bootstrapHelper .. [=[applyDealershipLayout = function()]=], "Phase 6 cockpit card helper insertion")
		changed = true
		info("Inserted Phase 6 cockpit card helpers before dealership layout.")
	else
		info("Phase 6 cockpit card helpers already exist.")
	end

	if findPlain(source, [=[-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE5_COCKPIT_MENU_IMAGES]=]) then
		source = replaceBetween(source, [=[-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE5_COCKPIT_MENU_IMAGES]=], [=[renderCockpitShop = function()]=], "", "remove old Phase 5 cockpit helper block")
		changed = true
		info("Removed the old Phase 5 cockpit helper block so Phase 6 helpers own image lookup.")
	end

	local oldGrid = [=[		UI.CockpitGridLayout.CellPadding = UDim2.fromOffset(10, 10)
		UI.CockpitGridLayout.CellSize = UDim2.fromOffset(cardSize, cardSize)]=]
	local newGrid = [=[		local gridGap = NTR_phase6ConfigNumber("GridCellPadding", 10)
		UI.CockpitGridLayout.CellPadding = UDim2.fromOffset(gridGap, gridGap)
		UI.CockpitGridLayout.CellSize = NTR_phase6GridCellSize(cardSize)]=]
	if findPlain(source, oldGrid) then
		source = replaceOnce(source, oldGrid, newGrid, "cockpit grid square-image cell size")
		changed = true
		info("Patched cockpit grid cell size to read CockpitMenuCards config.")
	elseif findPlain(source, [=[UI.CockpitGridLayout.CellSize = NTR_phase6GridCellSize(cardSize)]=]) then
		info("Cockpit grid cell size already uses Phase 6 config.")
	else
		error("Could not find cockpit grid cell-size block.")
	end

	local oldRatingPanelCustomise = [=[		local summary = State.Profile and State.Profile.VehicleSummaries and State.Profile.VehicleSummaries[State.SelectedVehicleId]
		local overall = summary and summary.Overall or {}
		local ratingIndex = tonumber(overall.PerformanceIndex)
		local rating = tostring(overall.Tier or "--") .. " " .. (ratingIndex and tostring(math.floor(ratingIndex)) or "---")
		local ratingText = label(UI.StatsPanel, rating, UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -104 or -116), 14, Enum.TextXAlignment.Center)
		ratingText.TextColor3 = Theme.Accent
		local customiseButton = button(UI.StatsPanel, "Customise", UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), Theme.Buy)]=]
	local oldRatingPanelBuildModules = [=[		local summary = State.Profile and State.Profile.VehicleSummaries and State.Profile.VehicleSummaries[State.SelectedVehicleId]
		local overall = summary and summary.Overall or {}
		local ratingIndex = tonumber(overall.PerformanceIndex)
		local rating = tostring(overall.Tier or "--") .. " " .. (ratingIndex and tostring(math.floor(ratingIndex)) or "---")
		local ratingText = label(UI.StatsPanel, rating, UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -104 or -116), 14, Enum.TextXAlignment.Center)
		ratingText.TextColor3 = Theme.Accent
		local customiseButton = button(UI.StatsPanel, "Build Modules", UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), Theme.Buy)]=]
	local newRatingPanel = [=[		-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_RIGHT_PANEL_RATING_REMOVED
		local customiseButton = button(UI.StatsPanel, "Customise", UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), Theme.Buy)]=]
	if findPlain(source, oldRatingPanelCustomise) then
		source = replaceOnce(source, oldRatingPanelCustomise, newRatingPanel, "remove customisation right-panel duplicate rating")
		changed = true
		info("Removed duplicate right-panel rating above the Customise button.")
	elseif findPlain(source, oldRatingPanelBuildModules) then
		source = replaceOnce(source, oldRatingPanelBuildModules, newRatingPanel, "remove customisation right-panel duplicate rating and rename button")
		changed = true
		info("Removed duplicate right-panel rating above the Customise button.")
	elseif findPlain(source, "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_RIGHT_PANEL_RATING_REMOVED") then
		info("Duplicate right-panel rating is already removed.")
	else
		error("Could not find the customisation right-panel rating block.")
	end

	local oldCardSize = [=[pooledButton(cockpitPool, "", UDim2.fromOffset(118, 118)]=]
	if findPlain(source, oldCardSize) then
		source = string.gsub(source, oldCardSize:gsub("([^%w])", "%%%1"), [=[pooledButton(cockpitPool, "", NTR_phase6CockpitCardSize()]=])
		changed = true
		info("Patched cockpit card button sizes to read CockpitMenuCards config.")
	elseif findPlain(source, [=[pooledButton(cockpitPool, "", NTR_phase6CockpitCardSize()]=]) then
		info("Cockpit card button sizes already use Phase 6 config.")
	else
		error("Could not find cockpit card size anchors.")
	end

	local oldCustomVisual = [=[			local icon = new("Frame", { BackgroundColor3 = Color3.fromRGB(18, 27, 31), Size = UDim2.new(1, -18, 0, 42), Position = UDim2.fromOffset(9, 9), BorderSizePixel = 0 }, card)
			icon:SetAttribute("PooledDynamic", true)
			corner(icon, 4)
			stroke(icon, Theme.Accent, 0.75, 1)
			local carShape = new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.fromOffset(72, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55) }, icon)
			corner(carShape, 3)]=]
	if findPlain(source, oldCustomVisual) then
		source = replaceOnce(source, oldCustomVisual, [=[			NTR_phase5RenderCockpitMenuImage(card, row.Cockpit)]=], "customisation cockpit image renderer")
		if findPlain(source, oldCustomVisual) then
			source = replaceOnce(source, oldCustomVisual, [=[			NTR_phase5RenderCockpitMenuImage(card, cockpit)]=], "dealership cockpit image renderer")
		end
		changed = true
		info("Patched any remaining old cockpit fallback renderers.")
	end

	local oldCustomName = [=[			pooledLabel(card, nameText, UDim2.new(1, -14, 0, 30), UDim2.fromOffset(7, 55), 9, Enum.TextXAlignment.Left)]=]
	local newCustomName = [=[			pooledLabel(card, nameText, UDim2.new(1, -14, 0, NTR_phase6ConfigNumber("NameHeight", 26)), UDim2.fromOffset(NTR_phase6ConfigNumber("NameX", 7), NTR_phase6ConfigNumber("NameY", 116)), NTR_phase6ConfigNumber("NameTextSize", 9), Enum.TextXAlignment.Left)]=]
	if findPlain(source, oldCustomName) then
		source = replaceOnce(source, oldCustomName, newCustomName, "customisation cockpit name position")
		changed = true
	end
	local oldDealershipName = [=[			pooledLabel(card, cockpit.DisplayName or cockpit.CockpitId, UDim2.new(1, -14, 0, 30), UDim2.fromOffset(7, 55), 9, Enum.TextXAlignment.Left)]=]
	local newDealershipName = [=[			pooledLabel(card, cockpit.DisplayName or cockpit.CockpitId, UDim2.new(1, -14, 0, NTR_phase6ConfigNumber("NameHeight", 26)), UDim2.fromOffset(NTR_phase6ConfigNumber("NameX", 7), NTR_phase6ConfigNumber("NameY", 116)), NTR_phase6ConfigNumber("NameTextSize", 9), Enum.TextXAlignment.Left)]=]
	if findPlain(source, oldDealershipName) then
		source = replaceOnce(source, oldDealershipName, newDealershipName, "dealership cockpit name position")
		changed = true
	end

	local oldBadge = [=[			local tierBadge = new("Frame", { BackgroundColor3 = tierBadgeColor(tier), BackgroundTransparency = 0.05, BorderSizePixel = 0, Size = UDim2.fromOffset(26, 18), Position = UDim2.fromOffset(7, 86) }, card)]=]
	local newBadge = [=[			local tierBadge = new("Frame", { BackgroundColor3 = tierBadgeColor(tier), BackgroundTransparency = 0.05, BorderSizePixel = 0, Size = UDim2.fromOffset(NTR_phase6ConfigNumber("TierBadgeWidth", 26), NTR_phase6ConfigNumber("TierBadgeHeight", 18)), Position = UDim2.fromOffset(NTR_phase6ConfigNumber("TierBadgeX", 7), NTR_phase6ConfigNumber("TierBadgeY", 142)) }, card)]=]
	if findPlain(source, oldBadge) then
		source = replaceOnce(source, oldBadge, newBadge, "customisation tier badge position")
		changed = true
	end
	local oldRating = [=[			pooledLabel(card, ratingIndex, UDim2.new(1, -44, 0, 20), UDim2.fromOffset(38, 86), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Accent]=]
	local newRating = [=[			pooledLabel(card, ratingIndex, UDim2.new(1, -44, 0, 20), UDim2.fromOffset(NTR_phase6ConfigNumber("RatingX", 38), NTR_phase6ConfigNumber("RatingY", 142)), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Accent]=]
	if findPlain(source, oldRating) then
		source = replaceOnce(source, oldRating, newRating, "customisation rating position")
		changed = true
	end
	local oldPrice = [=[			pooledLabel(card, "$" .. tostring(cockpit.Price or 0), UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 86), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Cash]=]
	local newPrice = [=[			pooledLabel(card, "$" .. tostring(cockpit.Price or 0), UDim2.new(1, -14, 0, 20), UDim2.fromOffset(NTR_phase6ConfigNumber("NameX", 7), NTR_phase6ConfigNumber("PriceY", 142)), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Cash]=]
	if findPlain(source, oldPrice) then
		source = replaceOnce(source, oldPrice, newPrice, "dealership price position")
		changed = true
	end

	if changed then
		scriptObject.Source = source
		info("Patched dealership/customisation cockpit image layout.")
	else
		info("Dealership/customisation bootstrap already had Phase 6 layout changes.")
	end
end

local freeRoamHelper = [=[
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
	local imageId = currentCockpitMenuImage()
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

local function patchFreeRoam()
	local scriptObject = activeFreeRoamNav()
	local source = scriptObject.Source
	local changed = false
	assert(findPlain(source, [=[local function attachIcon(button, iconValueName, fallbackText, iconScale)]=]), "FreeRoamNavController_Active does not have the expected attachIcon helper.")

	if findPlain(source, [=[-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE5_COCKPIT_MENU_IMAGES]=]) then
		source = replaceBetween(source, [=[-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE5_COCKPIT_MENU_IMAGES]=], [=[local function attachIcon(button, iconValueName, fallbackText, iconScale)]=], freeRoamHelper, "replace Phase 5 free-roam image helper")
		changed = true
		info("Replaced Phase 5 free-roam image helper with robust Phase 6 helper.")
	elseif not findPlain(source, "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_FREE_ROAM_IMAGE_LOOKUP") then
		source = replaceOnce(source, [=[local function attachIcon(button, iconValueName, fallbackText, iconScale)]=], freeRoamHelper .. [=[local function attachIcon(button, iconValueName, fallbackText, iconScale)]=], "insert Phase 6 free-roam image helper")
		changed = true
		info("Inserted Phase 6 free-roam image helper.")
	else
		info("Phase 6 free-roam image helper already exists.")
	end

	local oldRefresh = [=[	carButton.Size = UDim2.fromOffset(stackW, carH)
	layoutButtonIcon(carButton)]=]
	local newRefresh = [=[	carButton.Size = UDim2.fromOffset(stackW, carH)
	updateCarButtonImage()
	layoutButtonIcon(carButton)]=]
	if findPlain(source, oldRefresh) then
		source = replaceOnce(source, oldRefresh, newRefresh, "free-roam car image refresh hook")
		changed = true
	elseif findPlain(source, newRefresh) then
		info("Free-roam car image refresh hook already exists.")
	else
		error("Could not find free-roam car image refresh hook.")
	end

	if changed then
		scriptObject.Source = source
		info("Patched free-roam car button image lookup.")
	end
end

ensureConfig()
ensureCockpitImageAttributes()
patchBootstrap()
patchFreeRoam()

info("Install complete. Restart Play and verify cockpit images in dealership, customisation, and free roam.")
