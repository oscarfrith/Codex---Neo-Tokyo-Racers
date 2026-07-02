-- Persistence Phase 17 module popup absolute correction repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- Use after the runtime anchor diagnostic reports:
-- - target card/ModulePopupAnchor is correct;
-- - popup absolute centre/bottom is still offset from that anchor.
--
-- This keeps the clipped carousel + selected-card anchor system, then corrects
-- the overlay popup by measuring its actual AbsolutePosition after placement.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Module Popup Absolute Correction Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another popup patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another popup patch.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before), true
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, "NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ANCHOR_TARGET"), "Expected anchor-target popup helper before applying absolute correction repair.")
assert(findPlain(source, "anchorX - layer.AbsolutePosition.X"), "Expected anchor-to-layer positioning in active client bootstrap.")

local oldPlacement = [=[	popup.Position = UDim2.fromOffset(
		math.floor((anchorX - layer.AbsolutePosition.X) + 0.5),
		math.floor((anchorY - layer.AbsolutePosition.Y) + 0.5)
	)
	popup.ZIndex = 72]=]

local newPlacement = [=[	popup.Position = UDim2.fromOffset(
		math.floor((anchorX - layer.AbsolutePosition.X) + 0.5),
		math.floor((anchorY - layer.AbsolutePosition.Y) + 0.5)
	)
	for _ = 1, 8 do
		local currentCenterX = popup.AbsolutePosition.X + popup.AbsoluteSize.X * 0.5
		local currentBottomY = popup.AbsolutePosition.Y + popup.AbsoluteSize.Y
		local dx = anchorX - currentCenterX
		local dy = anchorY - currentBottomY
		if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then
			break
		end
		local basePosition = popup.Position
		local probe = 100
		popup.Position = UDim2.fromOffset(basePosition.X.Offset + probe, basePosition.Y.Offset + probe)
		local probedCenterX = popup.AbsolutePosition.X + popup.AbsoluteSize.X * 0.5
		local probedBottomY = popup.AbsolutePosition.Y + popup.AbsoluteSize.Y
		local scaleX = (probedCenterX - currentCenterX) / probe
		local scaleY = (probedBottomY - currentBottomY) / probe
		if math.abs(scaleX) < 0.01 then
			scaleX = 1
		end
		if math.abs(scaleY) < 0.01 then
			scaleY = 1
		end
		popup.Position = basePosition
		popup.Position = UDim2.fromOffset(
			math.floor((basePosition.X.Offset + dx / scaleX) + 0.5),
			math.floor((basePosition.Y.Offset + dy / scaleY) + 0.5)
		)
	end
	popup.ZIndex = 72]=]

local changed = false
if findPlain(source, "local probedCenterX = popup.AbsolutePosition.X + popup.AbsoluteSize.X * 0.5") then
	info("Absolute popup correction is already installed; refreshing install attribute only.")
elseif findPlain(source, "local currentCenterX = popup.AbsolutePosition.X + popup.AbsoluteSize.X * 0.5") then
	local oldBasicCorrection = [=[	popup.Position = UDim2.fromOffset(
		math.floor((anchorX - layer.AbsolutePosition.X) + 0.5),
		math.floor((anchorY - layer.AbsolutePosition.Y) + 0.5)
	)
	for _ = 1, 4 do
		local currentCenterX = popup.AbsolutePosition.X + popup.AbsoluteSize.X * 0.5
		local currentBottomY = popup.AbsolutePosition.Y + popup.AbsoluteSize.Y
		local dx = anchorX - currentCenterX
		local dy = anchorY - currentBottomY
		if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then
			break
		end
		popup.Position = UDim2.fromOffset(
			math.floor((popup.Position.X.Offset + dx) + 0.5),
			math.floor((popup.Position.Y.Offset + dy) + 0.5)
		)
	end
	popup.ZIndex = 72]=]
	source, changed = replaceOnce(source, oldBasicCorrection, newPlacement, "scale-aware absolute popup correction")
else
	source, changed = replaceOnce(source, oldPlacement, newPlacement, "absolute popup correction after anchor placement")
end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ModulePopupAbsoluteCorrectionRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "local currentCenterX = popup.AbsolutePosition.X + popup.AbsoluteSize.X * 0.5"), "Absolute centre correction was not installed.")
assert(findPlain(finalSource, "local currentBottomY = popup.AbsolutePosition.Y + popup.AbsoluteSize.Y"), "Absolute bottom correction was not installed.")
assert(findPlain(finalSource, "local probedCenterX = popup.AbsolutePosition.X + popup.AbsoluteSize.X * 0.5"), "Scale-aware correction probe was not installed.")

info("PASS: popup overlay now corrects its actual absolute centre/bottom to the selected card's ModulePopupAnchor.")
info("Next: restart Play, click a locked/buyable module card, then rerun the runtime anchor diagnostic and alignment diagnostic. Expected popup centre equals anchor X and bottom equals anchor Y; alignment dx near 0 and gap near 6.")
