-- Persistence Phase 17 module popup alignment diagnostic.
--
-- Run from the Roblox Studio CLIENT Command Bar while in Play mode.
--
-- This is read-only for the live source. It watches the current PlayerGui for
-- the Build Modules carousel and visible ModulePopup, then prints the exact
-- screen-space offset between the popup and the nearest module cards.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PHASE = "Persistence Phase 17 Module Popup Alignment Diagnostic"
local SAMPLE_SECONDS = 12
local SAMPLE_INTERVAL = 0.35

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local player = Players.LocalPlayer
assert(player, "Run this from the CLIENT Command Bar in Play mode.")

local playerGui = player:WaitForChild("PlayerGui")
local garageGui = playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
assert(garageGui, "HOVER_RACING_V2_GarageUI was not found. Open the garage/customisation UI first.")

local function findDescendant(root, name)
	for _, item in ipairs(root:GetDescendants()) do
		if item.Name == name then
			return item
		end
	end
	return nil
end

local function isVisibleObject(object)
	local current = object
	while current and current ~= garageGui do
		if current:IsA("GuiObject") and current.Visible == false then
			return false
		end
		current = current.Parent
	end
	return true
end

local function centerX(object)
	return object.AbsolutePosition.X + object.AbsoluteSize.X * 0.5
end

local function centerY(object)
	return object.AbsolutePosition.Y + object.AbsoluteSize.Y * 0.5
end

local function visibleWidthInCarousel(card, carousel)
	local left = math.max(card.AbsolutePosition.X, carousel.AbsolutePosition.X)
	local right = math.min(card.AbsolutePosition.X + card.AbsoluteSize.X, carousel.AbsolutePosition.X + carousel.AbsoluteSize.X)
	return math.max(0, right - left)
end

local function collectCards(carousel)
	local cards = {}
	for _, item in ipairs(carousel:GetChildren()) do
		if item:IsA("GuiButton") and isVisibleObject(item) and item.AbsoluteSize.X >= 100 and item.AbsoluteSize.Y >= 50 then
			local visibleWidth = visibleWidthInCarousel(item, carousel)
			if visibleWidth > 1 then
				table.insert(cards, {
					Object = item,
					CenterX = centerX(item),
					CenterY = centerY(item),
					Top = item.AbsolutePosition.Y,
					Left = item.AbsolutePosition.X,
					Width = item.AbsoluteSize.X,
					Height = item.AbsoluteSize.Y,
					VisibleWidth = visibleWidth,
				})
			end
		end
	end
	return cards
end

local function describeParent(object)
	if not object or not object.Parent then
		return "nil"
	end
	local parts = {}
	local current = object.Parent
	while current and current ~= garageGui and #parts < 5 do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, ".")
end

local function sample(index)
	local carousel = findDescendant(garageGui, "ModuleOptionsScroll")
	local popup = findDescendant(garageGui, "ModulePopup")
	if not carousel or not popup then
		info("sample " .. index .. ": missing carousel=" .. tostring(carousel ~= nil) .. " popup=" .. tostring(popup ~= nil))
		return
	end
	if not popup.Visible or not isVisibleObject(popup) then
		info("sample " .. index .. ": popup hidden; click a BUY/LOCKED/EQUIP module card while this diagnostic is running.")
		return
	end

	local cards = collectCards(carousel)
	local popupCenterX = centerX(popup)
	local popupBottom = popup.AbsolutePosition.Y + popup.AbsoluteSize.Y
	table.sort(cards, function(a, b)
		local ax = math.abs(a.CenterX - popupCenterX)
		local bx = math.abs(b.CenterX - popupCenterX)
		if ax == bx then
			return a.Left < b.Left
		end
		return ax < bx
	end)

	local carouselLeft = carousel.AbsolutePosition.X
	local carouselRight = carouselLeft + carousel.AbsoluteSize.X
	info(string.format(
		"sample %02d popup center=(%.1f, %.1f) bottom=%.1f parent=%s carousel=[%.1f..%.1f] canvasX=%.1f cards=%d",
		index,
		popupCenterX,
		centerY(popup),
		popupBottom,
		describeParent(popup),
		carouselLeft,
		carouselRight,
		carousel.CanvasPosition.X,
		#cards
	))

	for rank = 1, math.min(3, #cards) do
		local card = cards[rank]
		local dx = popupCenterX - card.CenterX
		local gap = card.Top - popupBottom
		info(string.format(
			"  nearest %d: card=%s centerX=%.1f top=%.1f size=%.0fx%.0f visibleWidth=%.1f dx=%.1f gap=%.1f",
			rank,
			card.Object.Name,
			card.CenterX,
			card.Top,
			card.Width,
			card.Height,
			card.VisibleWidth,
			dx,
			gap
		))
	end
end

info("Started. Open Build Modules and click the problem BUY/LOCKED/EQUIP card now. Sampling for " .. SAMPLE_SECONDS .. " seconds.")

local elapsed = 0
local sinceSample = SAMPLE_INTERVAL
local sampleIndex = 0
local connection
connection = RunService.RenderStepped:Connect(function(dt)
	elapsed += dt
	sinceSample += dt
	if sinceSample >= SAMPLE_INTERVAL then
		sinceSample = 0
		sampleIndex += 1
		sample(sampleIndex)
	end
	if elapsed >= SAMPLE_SECONDS then
		connection:Disconnect()
		info("Done. Paste the diagnostic lines if dx is not near 0 or gap is not near 6.")
	end
end)
