-- Neo Tokyo Racers - Remove Dealership Cockpit Module Slots Text
-- Run this whole file in the Roblox Studio Command Bar while NOT play-testing.
--
-- Removes the "Module Slots" text/list from the cockpit selection stats panel.
-- This does not change cockpit stats, included default modules, buying/selecting,
-- module gating, or the later Build Modules screen.

local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_dealership_remove_cockpit_module_slots_text"

local function requireChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	if not child then
		error(("[NTR Dealership Module Text Removal] Missing %s under %s. No changes applied.")
			:format(name, parent and parent:GetFullName() or "nil"))
	end
	if className and not child:IsA(className) then
		error(("[NTR Dealership Module Text Removal] %s is %s, expected %s. No changes applied.")
			:format(child:GetFullName(), child.ClassName, className))
	end
	return child
end

local function replaceExact(source, oldText, newText, label)
	local first, last = string.find(source, oldText, 1, true)
	if not first then
		error(("[NTR Dealership Module Text Removal] Preflight failed at %s. Refresh the Studio mirror before another patch; no changes applied.")
			:format(label))
	end
	if string.find(source, oldText, last + 1, true) then
		error(("[NTR Dealership Module Text Removal] Multiple matches at %s; no changes applied.")
			:format(label))
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, last + 1)
end

local starterScripts = requireChild(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = requireChild(starterScripts, "NeoTokyoRacersClient", "Folder")
local bootstrap = requireChild(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled", "LocalScript")

local source = bootstrap.Source
if string.find(source, "NTR_DEALERSHIP_MODULE_SLOTS_TEXT_REMOVED", 1, true) then
	print("[NTR Dealership Module Text Removal] Already installed; no source changes needed.")
	bootstrap:SetAttribute("LastUpdatedBy", SCRIPT_ID)
	bootstrap:SetAttribute("LastUpdatedAt", os.date("%Y-%m-%d %H:%M:%S"))
	return
end

source = replaceExact(source, [==[
	label(UI.StatsPanel, "Module Slots", UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 238), 12, Enum.TextXAlignment.Left)
	local y = 268
	local counts = { Engine = 0, Stabilisers = 0, Boost = 0, BodyKit = 0 }
	for _, slot in ipairs(sortedSlots()) do
		local slotId = slot.SlotId or ""
		local moduleType = slot.ModuleType or ""
		if moduleType == "Engine" then
			counts.Engine += 1
		elseif moduleType == "Stabilisers" or moduleType == "Stabiliser" or slotId == "Stabilisers" then
			counts.Stabilisers += 1
		elseif moduleType == "Boost" then
			counts.Boost += 1
		elseif moduleType == "FrontBumper" or moduleType == "RearBumper" or moduleType == "RearSpoiler" or moduleType == "SidePods" or string.find(slotId, "Bumper", 1, true) or string.find(slotId, "Spoiler", 1, true) or string.find(slotId, "SidePods", 1, true) then
			counts.BodyKit += 1
		end
	end
	for _, item in ipairs({ { "Engine", counts.Engine }, { "Stabilisers", counts.Stabilisers }, { "Boost", counts.Boost }, { "Body Kit", counts.BodyKit } }) do
		local count = item[2] or 0
		if count > 0 then
			label(UI.StatsPanel, item[1] .. " x" .. tostring(count), UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, y), 10, Enum.TextXAlignment.Left)
			y += 22
		end
	end
]==], [==[
	-- NTR_DEALERSHIP_MODULE_SLOTS_TEXT_REMOVED
]==], "cockpit module slots text block")

bootstrap.Source = source
bootstrap:SetAttribute("LastUpdatedBy", SCRIPT_ID)
bootstrap:SetAttribute("LastUpdatedAt", os.date("%Y-%m-%d %H:%M:%S"))

print("[NTR Dealership Module Text Removal] Installed.")
print("[NTR Dealership Module Text Removal] Removed cockpit module slot text/list from the dealership stats panel.")
print("[NTR Dealership Module Text Removal] Buy/select flow and Build Modules remain unchanged.")
