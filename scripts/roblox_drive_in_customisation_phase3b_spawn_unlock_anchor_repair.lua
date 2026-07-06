-- Neo Tokyo Racers - Drive-In Customisation Phase 3B
-- Repairs the Phase 3 bootstrap unlock patch if Phase 3 installed the
-- countdown-only client but stopped with:
-- "Could not find exact Start Driving SpawnVehicle block."
--
-- Root cause: the first Phase 3 installer used string.gsub with a multi-line
-- Lua pattern instead of plain source matching. This script uses plain
-- line-window matching and only inserts the unlock before the existing
-- Customise -> SpawnVehicle call.
--
-- Run in Roblox Studio Command Bar while the place is open.

local StarterPlayer = game:GetService("StarterPlayer")

local MARKER = "NTR_DRIVE_IN_CUSTOMISATION_PHASE3_UNLOCK_BEFORE_SPAWN"

local function info(message)
	print("[NTR Drive-In Customisation Phase 3B] " .. tostring(message))
end

local function patchBootstrapSpawnUnlock()
	local clientRoot = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient")
	local scriptObject = clientRoot:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
	local source = scriptObject.Source
	if string.find(source, MARKER, 1, true) then
		info("Bootstrap unlock-before-spawn patch already present.")
		return
	end

	local branchNeedle = 'elseif State.Stage == "Customise" then'
	local spawnNeedle = 'local result = callServer("SpawnVehicle", {})'
	local branchIndex = nil
	local spawnIndex = nil
	local searchFrom = 1

	while true do
		local candidate = string.find(source, branchNeedle, searchFrom, true)
		if not candidate then
			break
		end
		local candidateSpawn = string.find(source, spawnNeedle, candidate, true)
		if candidateSpawn and candidateSpawn - candidate < 700 then
			branchIndex = candidate
			spawnIndex = candidateSpawn
			break
		end
		searchFrom = candidate + #branchNeedle
	end

	assert(branchIndex and spawnIndex, "Could not find Customise Start Driving SpawnVehicle branch. Refresh the Studio mirror and paste the line window around SpawnVehicle before another patch.")

	local beforeSpawn = string.sub(source, 1, spawnIndex)
	local reversed = string.reverse(beforeSpawn)
	local reverseNewline = string.find(reversed, "\n", 1, true)
	local lineStart = reverseNewline and (spawnIndex - reverseNewline + 2) or spawnIndex
	local indent = string.match(string.sub(source, lineStart, spawnIndex - 1), "^(%s*)") or "\t\t\t"

	local unlockBlock = indent .. "-- " .. MARKER .. "\n"
		.. indent .. 'if player:GetAttribute("NTR_DriveInCustomisationActive") == true then' .. "\n"
		.. indent .. '\tplayer:SetAttribute("NTR_DriveInCustomisationActive", false)' .. "\n"
		.. indent .. "\ttask.wait(0.1)" .. "\n"
		.. indent .. "end" .. "\n"

	scriptObject.Source = string.sub(source, 1, spawnIndex - 1) .. unlockBlock .. string.sub(source, spawnIndex)
	info("Patched Start Driving to release drive-in hold before SpawnVehicle.")
end

patchBootstrapSpawnUnlock()
info("Phase 3B repair complete. Restart Play before testing.")
