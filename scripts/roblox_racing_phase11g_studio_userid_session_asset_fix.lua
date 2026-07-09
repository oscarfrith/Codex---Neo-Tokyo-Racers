-- Neo Tokyo Racers - Racing Phase 11G Studio UserId Session Asset Fix
-- Run in Roblox Studio Command Bar in Edit mode, then restart Play.
--
-- Root cause:
-- Roblox local server test players use negative UserIds such as -1 and -2.
-- RaceSessionAssetService accepted those IDs during ApplyParticipants, but rejected
-- them during UpdateParticipantSegment and RemoveParticipant. That left local
-- multiplayer racers stuck at segment 0 and kept race arrow/barrier proxies on
-- the first checkpoint window.
--
-- This patch accepts any non-zero numeric UserId. Production player UserIds remain
-- positive, so this only fixes Studio/local-server parity.

local PHASE = "NTR Racing Phase 11G"

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function child(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	if not item then
		fail("Missing " .. tostring(name) .. " under " .. (parent and parent:GetFullName() or "nil"))
	end
	if className and not item:IsA(className) then
		fail(item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. className)
	end
	return item
end

local function findScript(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		if current == game then
			local ok, service = pcall(function()
				return game:GetService(token)
			end)
			current = ok and service or current:FindFirstChild(token)
		else
			current = child(current, token)
		end
	end
	if not (current:IsA("Script") or current:IsA("LocalScript") or current:IsA("ModuleScript")) then
		fail(path .. " is not a script")
	end
	return current
end

local function replaceOnce(source, needle, replacement, label)
	local startIndex, endIndex = string.find(source, needle, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label)
	end
	local second = string.find(source, needle, endIndex + 1, true)
	if second then
		fail("Source anchor is not unique: " .. label)
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex + 1)
end

local function patchRaceSessionAssetService()
	local scriptObj = findScript("ServerScriptService.NeoTokyoRacers.Services.Racing.RaceSessionAssetService_Active")
	local source = scriptObj.Source
	if string.find(source, "NTR_RACING_PHASE11G_STUDIO_USERID_FIX", 1, true) then
		info("RaceSessionAssetService already has Phase 11G Studio UserId fix.")
		return
	end

	source = replaceOnce(source, [==[	if userId > 0 then
		state.ParticipantSegments[userId] = nil
	end
]==], [==[	if userId ~= 0 then
		state.ParticipantSegments[userId] = nil
	end -- NTR_RACING_PHASE11G_STUDIO_USERID_FIX
]==], "removeParticipant should allow negative Studio test UserIds")

	source = replaceOnce(source, [==[	if userId <= 0 then return { Ok = false, Message = "Missing UserId." } end
	state.ParticipantSegments[userId] = math.max(0, math.floor(tonumber(payload.CurrentSegment) or 0))
]==], [==[	if userId == 0 then return { Ok = false, Message = "Missing UserId." } end
	state.ParticipantSegments[userId] = math.max(0, math.floor(tonumber(payload.CurrentSegment) or 0))
]==], "updateParticipantSegment should allow negative Studio test UserIds")

	scriptObj.Source = source
	info("Patched RaceSessionAssetService to accept non-zero Studio/local-server test UserIds.")
end

patchRaceSessionAssetService()

info("Install complete. Restart Play, run a 2-player local race, and confirm ArrowBarrierProxies.ParticipantSegments advances from -1:0/-2:0 as checkpoints are passed.")
