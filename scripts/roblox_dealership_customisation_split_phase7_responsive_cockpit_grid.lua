-- Neo Tokyo Racers - Dealership / Customisation Split Phase 7
-- Responsive cockpit grid columns and scaled cards.
--
-- Run in Roblox Studio Command Bar while in Edit mode.
--
-- This is a guarded source patch against the active client bootstrap. It
-- replaces only the Phase 6 cockpit-card helper block and the grid-size call.

local PHASE = "NTR Dealership/Customisation Phase 7 Responsive Cockpit Grid"
local PHASE6_MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_SQUARE_COCKPIT_IMAGES"
local PHASE6_REPAIR_MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_REGISTER_LIMIT_REPAIR"
local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE7_RESPONSIVE_COCKPIT_GRID"

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
	ensureBool(cards, "UseResponsiveGridWidth", true).Value = true
	ensureBool(cards, "ResponsiveCardScaleEnabled", true)
	ensureNumber(cards, "DesktopColumns", 4)
	ensureNumber(cards, "MobileColumns", 3)
	ensureNumber(cards, "DesktopMinCardWidth", 96)
	ensureNumber(cards, "DesktopMaxCardWidth", 240)
	ensureNumber(cards, "MobileMinCardWidth", 70)
	ensureNumber(cards, "MobileMaxCardWidth", 160)
	info("Ensured responsive cockpit-grid config values.")
end

local responsiveHelperBlock = [=[
-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE7_RESPONSIVE_COCKPIT_GRID
function NTR_phase6CardConfig()
	local config = kit:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	return ui and ui:FindFirstChild("CockpitMenuCards") or nil
end

function NTR_phase6RawConfigNumber(name, fallback)
	local folder = NTR_phase6CardConfig()
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

function NTR_phase6ShouldScaleConfig(name)
	local folder = NTR_phase6CardConfig()
	local scaleFlag = folder and folder:FindFirstChild("ResponsiveCardScaleEnabled")
	if scaleFlag and scaleFlag:IsA("BoolValue") and not scaleFlag.Value then
		return false
	end
	return name == "ImageBoxX"
		or name == "ImageBoxY"
		or name == "ImageBoxSize"
		or name == "ImageInnerPadding"
		or name == "ImageCornerRadius"
		or name == "FallbackBarWidth"
		or name == "FallbackBarHeight"
		or name == "NameX"
		or name == "NameY"
		or name == "NameHeight"
		or name == "NameTextSize"
		or name == "PriceY"
		or name == "RatingY"
		or name == "RatingX"
		or name == "TierBadgeX"
		or name == "TierBadgeY"
		or name == "TierBadgeWidth"
		or name == "TierBadgeHeight"
end

function NTR_phase6CardScale()
	local baseWidth = math.max(1, NTR_phase6RawConfigNumber("CardWidth", 118))
	local currentWidth = tonumber(NTR_phase6CurrentCardWidth) or baseWidth
	return math.clamp(currentWidth / baseWidth, 0.55, 2)
end

function NTR_phase6ConfigNumber(name, fallback)
	local value = NTR_phase6RawConfigNumber(name, fallback)
	if NTR_phase6ShouldScaleConfig(name) then
		return math.max(0, math.floor(value * NTR_phase6CardScale() + 0.5))
	end
	return value
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
	for _, name in ipairs({ "MenuImage", "CockpitImage", "ThumbnailImage", "ImageId", "Image" }) do
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

function NTR_phase6GridColumns()
	local fallback = UserInputService.TouchEnabled and 3 or 4
	local key = UserInputService.TouchEnabled and "MobileColumns" or "DesktopColumns"
	return math.max(1, math.floor(NTR_phase6RawConfigNumber(key, fallback) + 0.5))
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
	local width = math.clamp(rawWidth, NTR_phase6RawConfigNumber(minKey, 70), NTR_phase6RawConfigNumber(maxKey, 240))
	local ratio = NTR_phase6RawConfigNumber("CardHeight", 176) / math.max(1, NTR_phase6RawConfigNumber("CardWidth", 118))
	NTR_phase6CurrentCardWidth = width
	return UDim2.fromOffset(width, math.floor(width * ratio + 0.5))
end

function NTR_phase6CockpitCardSize()
	return NTR_phase6GridCellSize(NTR_phase6RawConfigNumber("CardWidth", 118))
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

local function markerNeedle(source)
	for _, marker in ipairs({ MARKER, PHASE6_REPAIR_MARKER, PHASE6_MARKER }) do
		local needle = "-- " .. marker
		if findPlain(source, needle) then
			return needle
		end
	end
	return nil
end

ensureConfig()

local bootstrap = activeBootstrap()
local source = bootstrap.Source
local startNeedle = markerNeedle(source)
assert(startNeedle, "Could not find the Phase 6/7 cockpit helper marker in the active bootstrap. Run Phase 6 first, or refresh the Studio mirror if Studio changed.")

source = replaceBetween(source, startNeedle, [=[applyDealershipLayout = function()]=], responsiveHelperBlock, "responsive cockpit helper block")

local oldCall = [=[UI.CockpitGridLayout.CellSize = NTR_phase6GridCellSize(cardSize)]=]
local newCall = [=[UI.CockpitGridLayout.CellSize = NTR_phase6GridCellSize(cardSize, innerW)]=]
if findPlain(source, oldCall) then
	source = replaceOnce(source, oldCall, newCall, "responsive cockpit grid width argument")
elseif findPlain(source, newCall) then
	info("Responsive cockpit grid width argument is already installed.")
else
	error("Could not find the cockpit grid cell-size helper call. Refresh the Studio mirror before another layout patch.")
end

bootstrap.Source = source

assert(bootstrap.Source:find(MARKER, 1, true), "Phase 7 responsive marker was not installed.")
assert(bootstrap.Source:find("function NTR_phase6GridCellSize(defaultWidth, availableWidth)", 1, true), "Responsive grid helper was not installed.")
assert(bootstrap.Source:find(newCall, 1, true), "Responsive grid call was not installed.")
assert(not bootstrap.Source:find("local function NTR_phase6", 1, true), "A local Phase 6 helper remains in the bootstrap.")

info("PASS. Restart Play and verify 4 cockpit columns on desktop/laptop, 3 on mobile, with vertical scrolling for the rest.")
