-- Neo Tokyo Racers - Free Roam Car Menu Phase 5
-- Image fit, border consistency, and Despawn padding polish.
--
-- This is a guarded source patch against the isolated
-- FreeRoamNavController_Active LocalScript. It expects Free Roam Car Menu
-- Phase 4 to be installed in Studio.

local PHASE = "NTR Free Roam Car Menu Phase 5 Image Fit"
local MARKER = "NTR_FREEROAM_CAR_MENU_PHASE5_IMAGE_FIT_BORDER_PADDING"
local PHASE4_MARKER = "NTR_FREEROAM_CAR_MENU_PHASE4_CARD_SCALING_SORT_FUTURE_SPAWN"

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

	ensureNumber(nav, "CarPanelImageZoom", 1, true)
	ensureNumber(nav, "CarPanelImageFitScale", 1, true)
	ensureNumber(nav, "CarPanelImageInnerPadding", 5, true)
	ensureNumber(nav, "CarPanelBottomPadding", 8, true)
	ensureNumber(nav, "CarPanelPadding", 8, false)

	info("Updated FreeRoamNav car-panel image fit and padding values.")
end

ensureConfig()

local scriptObject = activeFreeRoamNav()
local source = scriptObject.Source

if findPlain(source, MARKER) then
	info("Phase 5 marker already present; config values were refreshed.")
	return
end

assert(findPlain(source, PHASE4_MARKER), "Expected Free Roam Car Menu Phase 4 marker before applying Phase 5.")

source = replaceOnce(source, "-- " .. PHASE4_MARKER, "-- " .. PHASE4_MARKER .. "\n-- " .. MARKER, "Phase 5 marker")

source = replaceIfPresent(
	source,
	"stroke(imageBox, theme.Accent, 0.75, 1)",
	"stroke(imageBox, readColor(config, \"ButtonOutline\", Color3.fromRGB(230, 88, 205)), 0.35, 1)",
	"image-box border colour"
)

source = replaceIfPresent(
	source,
	"stroke(card, row.Selected and carPanelTierColor(row.Tier) or readColor(config, \"ButtonOutline\", Color3.fromRGB(230, 88, 205)), row.Selected and 0.05 or 0.45, row.Selected and 1.6 or 1)",
	"stroke(card, readColor(config, \"ButtonOutline\", Color3.fromRGB(230, 88, 205)), row.Selected and 0.12 or 0.45, row.Selected and 1.6 or 1)",
	"legacy selected card border colour"
)

local imageBlockOld = [=[
		local inset = carPanelCardConfigNumber("ImageInnerPadding", 4)
		local zoom = math.clamp(carPanelNumber("CarPanelImageZoom", carPanelCardConfigNumber("ImageZoom", 1.18)), 0.5, 2)
		local image = Instance.new("ImageLabel")
		image.Name = "CockpitImage"
		image.BackgroundTransparency = 1
		image.Image = row.Image
		image.ScaleType = string.lower(tostring(readString(config, "CarPanelImageScaleType", "Fit"))) == "crop" and Enum.ScaleType.Crop or Enum.ScaleType.Fit
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.new(zoom, -inset * 2, zoom, -inset * 2)
		image.ZIndex = imageBox.ZIndex + 1
		image.Parent = imageBox
]=]

local imageBlockNew = [=[
		local inset = math.max(0, carPanelNumber("CarPanelImageInnerPadding", carPanelCardConfigNumber("ImageInnerPadding", 5)))
		local imageScale = math.clamp(carPanelNumber("CarPanelImageFitScale", 1), 0.8, 1)
		local image = Instance.new("ImageLabel")
		image.Name = "CockpitImage"
		image.BackgroundTransparency = 1
		image.Image = row.Image
		image.ScaleType = Enum.ScaleType.Fit
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.new(imageScale, -inset * 2, imageScale, -inset * 2)
		image.ZIndex = imageBox.ZIndex + 1
		image.Parent = imageBox
]=]

source = replaceOnce(source, imageBlockOld, imageBlockNew, "non-clipping fitted cockpit image block")

local scrollLayoutOld = [=[
	scroll.Position = UDim2.fromOffset(pad, 0)
	scroll.Size = UDim2.fromOffset(math.max(1, panelW - pad * 2), math.max(1, panelH - buttonH - bottomPad * 2))
]=]

local scrollLayoutNew = [=[
	scroll.Position = UDim2.fromOffset(pad, pad)
	scroll.Size = UDim2.fromOffset(math.max(1, panelW - pad * 2), math.max(1, panelH - buttonH - bottomPad * 3))
]=]

source = replaceOnce(source, scrollLayoutOld, scrollLayoutNew, "car card scroll top/bottom padding")

local chromeOld = [=[
	actionBody.Position = enabled and UDim2.fromOffset(0, 8) or UDim2.fromOffset(0, 42)
	actionBody.Size = enabled and UDim2.new(1, 0, 1, -14) or UDim2.new(1, 0, 1, -48)
]=]

local chromeNew = [=[
	actionBody.Position = enabled and UDim2.fromOffset(0, 0) or UDim2.fromOffset(0, 42)
	actionBody.Size = enabled and UDim2.new(1, 0, 1, 0) or UDim2.new(1, 0, 1, -48)
]=]

source = replaceOnce(source, chromeOld, chromeNew, "car panel action body full-height layout")

assert(findPlain(source, MARKER), "Phase 5 marker was not installed.")
assert(findPlain(source, "CarPanelImageInnerPadding"), "Image inner padding source was not installed.")
assert(findPlain(source, "image.ScaleType = Enum.ScaleType.Fit"), "Image Fit source was not installed.")
assert(findPlain(source, "scroll.Position = UDim2.fromOffset(pad, pad)"), "Scroll padding source was not installed.")

scriptObject.Source = source

info("Installed Phase 5 free-roam car menu image/border/padding polish.")
info("Verify: cockpit images fit inside their frames with an even inset, card/image borders use the same pink outline style, and Despawn bottom padding matches side padding.")
