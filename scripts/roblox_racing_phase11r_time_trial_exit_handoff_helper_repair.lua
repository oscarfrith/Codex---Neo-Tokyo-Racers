-- Neo Tokyo Racers - Racing Phase 11R Time Trial Exit Handoff Helper Repair
-- Run in Roblox Studio Command Bar, Edit mode, then restart Play.
--
-- Phase 11Q was confirmed working by the user, but the refreshed mirror showed
-- its helper marker and `local clientRoot` collapsed onto one comment line:
--
--   -- NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF local clientRoot = ...
--
-- That means the helper may fail to find `FreeRoamVehicleExited` in future edge
-- cases. This script only fixes that malformed helper text in the isolated
-- RaceEntryMenuClient_Active source. It does not change gameplay logic.

local PHASE = "NTR Racing Phase 11R"
local MARKER = "NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF"

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function findPath(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(token)
		if not current then
			return nil
		end
	end
	return current
end

local function replaceOnce(source, old, new, label)
	local startIndex, endIndex = string.find(source, old, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. tostring(label))
	end
	return string.sub(source, 1, startIndex - 1) .. new .. string.sub(source, endIndex + 1)
end

local function patchRaceEntryMenuClient()
	local scriptObject = findPath("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active")
	if not scriptObject or not scriptObject:IsA("LocalScript") then
		fail("Could not find RaceEntryMenuClient_Active LocalScript.")
	end

	local source = scriptObject.Source
	local goodHelper = [[local function fireDrivingExitHandoff()
	-- NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF
	local clientRoot = script.Parent.Parent
	local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
	local exitedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleExited")
	if exitedEvent and exitedEvent:IsA("BindableEvent") then
		exitedEvent:Fire()
	end
end]]

	if string.find(source, goodHelper, 1, true) then
		print("[" .. PHASE .. "] Exit handoff helper already has the correct source shape.")
		return false
	end

	local malformedHelper = [[local function fireDrivingExitHandoff()
	-- NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF	local clientRoot = script.Parent.Parent
	local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
	local exitedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleExited")
	if exitedEvent and exitedEvent:IsA("BindableEvent") then
		exitedEvent:Fire()
	end
end]]

	source = replaceOnce(source, malformedHelper, goodHelper, "malformed Phase 11Q exit handoff helper")
	scriptObject.Source = source
	print("[" .. PHASE .. "] Repaired Phase 11Q exit handoff helper source shape.")
	return true
end

local changed = patchRaceEntryMenuClient()
print("[" .. PHASE .. "] Complete. changed=" .. tostring(changed))
print("[" .. PHASE .. "] Restart Play, finish a time trial, exit results, and confirm vehicle HUD clears plus re-entry/teleport still work.")
