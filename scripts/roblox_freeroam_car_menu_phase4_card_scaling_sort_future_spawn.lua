-- Neo Tokyo Racers - Free Roam Car Menu Phase 4
-- Card scaling, ordering, and future spawn/despawn preparation.
--
-- This is a guarded source patch against the isolated
-- FreeRoamNavController_Active LocalScript. It expects Free Roam Car Menu
-- Phase 3 to be installed in Studio.

local PHASE = "NTR Free Roam Car Menu Phase 4 Card Scaling"
local MARKER = "NTR_FREEROAM_CAR_MENU_PHASE4_CARD_SCALING_SORT_FUTURE_SPAWN"
local PHASE3_MARKER = "NTR_FREEROAM_CAR_MENU_PHASE3_OWNED_COCKPIT_CARDS"

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

local function ensureString(parent, name, value)
	local item = parent:FindFirstChild(name)
	if not item then
		item = Instance.new("StringValue")
		item.Name = name
		item.Value = value
		item.Parent = parent
	end
	assert(item:IsA("StringValue"), item:GetFullName() .. " must be a StringValue")
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

	ensureNumber(nav, "CarPanelWidthDesktop", 600, true)
	ensureNumber(nav, "CarPanelWidthTouch", 330, true)
	ensureNumber(nav, "CarPanelMinWidthDesktop", 430, true)
	ensureNumber(nav, "CarPanelMinWidthTouch", 270, true)
	ensureNumber(nav, "CarPanelDesktopColumns", 3, true)
	ensureNumber(nav, "CarPanelMobileColumns", 2, true)
	ensureNumber(nav, "CarPanelMaxCardWidthDesktop", 190, true)
	ensureNumber(nav, "CarPanelMaxCardWidthTouch", 160, true)
	ensureNumber(nav, "CarPanelImageZoom", 1.28, true)
	ensureNumber(nav, "CarPanelCardGap", 8, false)
	ensureNumber(nav, "CarPanelPadding", 8, false)
	ensureNumber(nav, "CarPanelImageToTextGap", 6, false)
	ensureString(nav, "CarPanelClickAction", "PreviewOnly")

	info("Updated FreeRoamNav car-panel tuning values for 3 desktop columns, 2 mobile columns, and larger cockpit imagery.")
end

ensureConfig()

local scriptObject = activeFreeRoamNav()
local source = scriptObject.Source

if findPlain(source, MARKER) then
	info("Phase 4 marker already present; config values were refreshed.")
	return
end

assert(findPlain(source, PHASE3_MARKER), "Expected Free Roam Car Menu Phase 3 marker before applying Phase 4.")

source = replaceOnce(source, "-- " .. PHASE3_MARKER, "-- " .. PHASE3_MARKER .. "\n-- " .. MARKER, "Phase 4 marker")

local sortOld = [=[
	table.sort(rows, function(a, b)
		if a.Selected ~= b.Selected then
			return a.Selected
		end
		if a.SortRating ~= b.SortRating then
			return a.SortRating > b.SortRating
		end
		if a.Name == b.Name then
			return tostring(a.VehicleId) < tostring(b.VehicleId)
		end
		return a.Name < b.Name
	end)
]=]

local sortNew = [=[
	table.sort(rows, function(a, b)
		if a.SortRating ~= b.SortRating then
			return a.SortRating > b.SortRating
		end
		if a.Name == b.Name then
			return tostring(a.VehicleId) < tostring(b.VehicleId)
		end
		return a.Name < b.Name
	end)
]=]

source = replaceOnce(source, sortOld, sortNew, "rating-only vehicle sort")

local cardAttrOld = [=[
	card.ClipsDescendants = true
	card.Size = UDim2.fromOffset(width, cardH)
	card.ZIndex = parent.ZIndex + 1
	card.Parent = parent
	corner(card, 6)
	stroke(card, row.Selected and carPanelTierColor(row.Tier) or readColor(config, "ButtonOutline", Color3.fromRGB(230, 88, 205)), row.Selected and 0.05 or 0.45, row.Selected and 1.6 or 1)
]=]

local cardAttrNew = [=[
	card.ClipsDescendants = true
	card.Size = UDim2.fromOffset(width, cardH)
	card:SetAttribute("VehicleId", tostring(row.VehicleId or ""))
	card:SetAttribute("CockpitId", tostring(row.CockpitId or ""))
	card:SetAttribute("IsCurrentVehicle", row.Selected == true)
	card:SetAttribute("FreeRoamVehicleAction", readString(config, "CarPanelClickAction", "PreviewOnly"))
	card.ZIndex = parent.ZIndex + 1
	card.Parent = parent
	corner(card, 6)
	stroke(card, readColor(config, "ButtonOutline", Color3.fromRGB(230, 88, 205)), row.Selected and 0.12 or 0.45, row.Selected and 1.6 or 1)
]=]

source = replaceOnce(source, cardAttrOld, cardAttrNew, "card attributes and normal outline")

local imageZoomOld = [=[
		local zoom = math.clamp(carPanelCardConfigNumber("ImageZoom", 1), 0.5, 2)
]=]

local imageZoomNew = [=[
		local zoom = math.clamp(carPanelNumber("CarPanelImageZoom", carPanelCardConfigNumber("ImageZoom", 1.18)), 0.5, 2)
]=]

source = replaceOnce(source, imageZoomOld, imageZoomNew, "car panel image zoom")

local badgeTextOld = [=[
	local badgeText = makeLabel(badge, "Text", tostring(row.Tier) .. " " .. tostring(row.RatingIndex), UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), touch and 8 or 9, Color3.fromRGB(244, 250, 255))
	badgeText.ZIndex = badge.ZIndex + 1
]=]

local badgeTextNew = [=[
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
]=]

source = replaceOnce(source, badgeTextOld, badgeTextNew, "badge text without glow")

local clickOld = [=[
	card.MouseButton1Click:Connect(function()
		setStatus(row.Selected and "CURRENT VEHICLE" or "USE CUSTOMISATION ZONE TO SELECT", row.Selected)
	end)
]=]

local clickNew = [=[
	card.MouseButton1Click:Connect(function()
		local action = readString(config, "CarPanelClickAction", "PreviewOnly")
		if action == "PreviewOnly" then
			setStatus(row.Selected and "CURRENT VEHICLE" or "SPAWN / SELECT COMING NEXT", row.Selected)
		else
			setStatus("READY FOR " .. string.upper(action), true)
		end
	end)
]=]

source = replaceOnce(source, clickOld, clickNew, "future spawn/select click hook")

local widthOld = [=[
		local desiredW = touch and carPanelNumber("CarPanelWidthTouch", 196) or carPanelNumber("CarPanelWidthDesktop", 392)
		local minPanelW = touch and carPanelNumber("CarPanelMinWidthTouch", 168) or carPanelNumber("CarPanelMinWidthDesktop", 320)
]=]

local widthNew = [=[
		local desiredW = touch and carPanelNumber("CarPanelWidthTouch", 330) or carPanelNumber("CarPanelWidthDesktop", 600)
		local minPanelW = touch and carPanelNumber("CarPanelMinWidthTouch", 270) or carPanelNumber("CarPanelMinWidthDesktop", 430)
]=]

source = replaceOnce(source, widthOld, widthNew, "car panel width defaults")

assert(findPlain(source, MARKER), "Phase 4 marker was not installed.")
assert(findPlain(source, "CarPanelImageZoom"), "Image zoom source was not installed.")
assert(findPlain(source, "SPAWN / SELECT COMING NEXT"), "Future spawn/select hook was not installed.")

scriptObject.Source = source

info("Installed Phase 4 free-roam car menu polish.")
info("Verify: desktop/laptop 3 columns, mobile 2 columns, bigger cockpit images, no badge text glow, normal pink card outlines, and rating-descending order.")
