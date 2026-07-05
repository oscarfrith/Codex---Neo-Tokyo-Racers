-- Neo Tokyo Racers - Free Roam Car Menu Phase 7
-- Borderless card frames and compact 3/2-column panel width.
--
-- This is a guarded source patch against the isolated
-- FreeRoamNavController_Active LocalScript. It expects Free Roam Car Menu
-- Phase 6 to be installed in Studio.

local PHASE = "NTR Free Roam Car Menu Phase 7 Borderless Frames"
local MARKER = "NTR_FREEROAM_CAR_MENU_PHASE7_BORDERLESS_CARD_FRAMES_COMPACT_WIDTH"
local PHASE6_MARKER = "NTR_FREEROAM_CAR_MENU_PHASE6_CARD_SURFACE_ROOT_FIX"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function escapePattern(text)
	return text:gsub("([^%w])", "%%%1")
end

local function replaceOnce(source, old, new, label)
	local nextSource, count = string.gsub(source, escapePattern(old), new, 1)
	assert(count == 1, "Could not replace " .. label)
	return nextSource
end

local function replaceIfPresent(source, old, new, label)
	local nextSource, count = string.gsub(source, escapePattern(old), new, 1)
	if count > 0 then
		info("Replaced " .. label .. ".")
		return nextSource
	end
	return source
end

local function replaceBetween(source, startNeedle, endNeedle, replacement, label)
	local startA = string.find(source, startNeedle, 1, true)
	assert(startA, "Could not find start anchor for " .. label)
	local endA = string.find(source, endNeedle, startA + #startNeedle, true)
	assert(endA, "Could not find end anchor for " .. label)
	return string.sub(source, 1, startA - 1) .. replacement .. string.sub(source, endA)
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

local function ensureNumber(parent, name, value, force)
	local item = parent:FindFirstChild(name)
	if not item then
		item = Instance.new("NumberValue")
		item.Name = name
		item.Parent = parent
	end
	assert(item:IsA("NumberValue"), item:GetFullName() .. " must be a NumberValue")
	if force then
		item.Value = value
	end
	return item
end

local function activeFreeRoamNav()
	local starterScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local root = starterScripts:WaitForChild("NeoTokyoRacersClient")
	local controllers = root:WaitForChild("Controllers")
	local ui = controllers:WaitForChild("UI")
	local scriptObject = ui:WaitForChild("FreeRoamNavController_Active")
	assert(scriptObject:IsA("LocalScript"), "FreeRoamNavController_Active path is not a LocalScript.")
	return scriptObject
end

local function ensureConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local configRoot = ensureChild(kit, "Folder", "Config")
	local uiRoot = ensureChild(configRoot, "Folder", "UI")
	local nav = ensureChild(uiRoot, "Folder", "FreeRoamNav")

	ensureNumber(nav, "CarPanelWidthDesktop", 512, true)
	ensureNumber(nav, "CarPanelWidthTouch", 260, true)
	ensureNumber(nav, "CarPanelMinWidthDesktop", 430, true)
	ensureNumber(nav, "CarPanelMinWidthTouch", 240, true)
	ensureNumber(nav, "CarPanelDesktopColumns", 3, true)
	ensureNumber(nav, "CarPanelMobileColumns", 2, true)
	ensureNumber(nav, "CarPanelMaxCardWidthDesktop", 160, true)
	ensureNumber(nav, "CarPanelMaxCardWidthTouch", 118, true)
	ensureNumber(nav, "CarPanelDesktopImageMaxSize", 144, true)
	ensureNumber(nav, "CarPanelMobileImageMaxSize", 88, true)
	ensureNumber(nav, "CarPanelBorderThickness", 2, true)
	ensureNumber(nav, "CarPanelImageInnerPadding", 5, true)
	ensureNumber(nav, "CarPanelCardBottomPadding", 8, true)
	ensureNumber(nav, "CarPanelImageToTextGap", 6, true)
	ensureNumber(nav, "CarPanelPadding", 8, false)
	ensureNumber(nav, "CarPanelCardGap", 8, false)
	ensureNumber(nav, "CarPanelBottomPadding", 8, false)

	info("Updated FreeRoamNav compact 3/2-column car-panel sizing values.")
end

ensureConfig()

local scriptObject = activeFreeRoamNav()
local source = scriptObject.Source

if findPlain(source, MARKER) then
	info("Phase 7 marker already present; config values were refreshed.")
	return
end

assert(findPlain(source, PHASE6_MARKER), "Expected Free Roam Car Menu Phase 6 marker before applying Phase 7.")

source = replaceOnce(source, "-- " .. PHASE6_MARKER, "-- " .. PHASE6_MARKER .. "\n-- " .. MARKER, "Phase 7 marker")

local replacement = [=[
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

local function carPanelRenderCockpitCard(parent, row, width)
	local pad, imageSize, nameY, nameH, cardH, visualWidth = carPanelLayoutForWidth(width)
	local border = math.max(1, math.floor(carPanelNumber("CarPanelBorderThickness", 2) + 0.5))
	local outlineColor = readColor(config, "ButtonOutline", Color3.fromRGB(230, 88, 205))
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
	surfaceBorder.BackgroundTransparency = row.Selected and 0.08 or 0.18
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
	surface.Position = UDim2.fromOffset(border, border)
	surface.Size = UDim2.new(1, -border * 2, 1, -border * 2)
	surface.ZIndex = surfaceBorder.ZIndex + 1
	surface.Parent = surfaceBorder
	corner(surface, math.max(3, 6 - border))

	local imageBorder = Instance.new("Frame")
	imageBorder.Name = "ImageBox"
	imageBorder.BackgroundColor3 = outlineColor
	imageBorder.BackgroundTransparency = 0.18
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
	imageBox.Position = UDim2.fromOffset(border, border)
	imageBox.Size = UDim2.new(1, -border * 2, 1, -border * 2)
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
		local action = readString(config, "CarPanelClickAction", "PreviewOnly")
		if action == "PreviewOnly" then
			setStatus(row.Selected and "CURRENT VEHICLE" or "SPAWN / SELECT COMING NEXT", row.Selected)
		else
			setStatus("READY FOR " .. string.upper(action), true)
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

]=]

source = replaceBetween(source, "local function carPanelLayoutForWidth(width)\n", "local function carPanelRender()\n", replacement, "borderless car-panel layout/render block")

source = replaceIfPresent(source,
	[[local desiredW = touch and carPanelNumber("CarPanelWidthTouch", 330) or carPanelNumber("CarPanelWidthDesktop", 600)]],
	[[local desiredW = touch and carPanelNumber("CarPanelWidthTouch", 260) or carPanelNumber("CarPanelWidthDesktop", 512)]],
	"Phase 4/6 car panel desired width defaults"
)
source = replaceIfPresent(source,
	[[local desiredW = touch and carPanelNumber("CarPanelWidthTouch", 290) or carPanelNumber("CarPanelWidthDesktop", 600)]],
	[[local desiredW = touch and carPanelNumber("CarPanelWidthTouch", 260) or carPanelNumber("CarPanelWidthDesktop", 512)]],
	"Phase 6 car panel desired width defaults"
)
source = replaceIfPresent(source,
	[[local minPanelW = touch and carPanelNumber("CarPanelMinWidthTouch", 270) or carPanelNumber("CarPanelMinWidthDesktop", 430)]],
	[[local minPanelW = touch and carPanelNumber("CarPanelMinWidthTouch", 240) or carPanelNumber("CarPanelMinWidthDesktop", 430)]],
	"Phase 4 min panel width defaults"
)
source = replaceIfPresent(source,
	[[local minPanelW = touch and carPanelNumber("CarPanelMinWidthTouch", 260) or carPanelNumber("CarPanelMinWidthDesktop", 430)]],
	[[local minPanelW = touch and carPanelNumber("CarPanelMinWidthTouch", 240) or carPanelNumber("CarPanelMinWidthDesktop", 430)]],
	"Phase 6 min panel width defaults"
)

assert(findPlain(source, MARKER), "Phase 7 marker was not installed.")
assert(findPlain(source, "CardFill"), "Filled card border source was not installed.")
assert(findPlain(source, "ImageFill"), "Filled image border source was not installed.")
assert(not findPlain(source, "stroke(surface"), "UIStroke surface border still present in car cards.")
assert(not findPlain(source, "stroke(imageBox"), "UIStroke image border still present in car cards.")

scriptObject.Source = source

info("Installed Phase 7 free-roam car menu borderless frame polish.")
info("Verify: no clipped card/image border, panel width fits 3 compact desktop cards or 2 mobile cards, and Despawn still works.")
