-- Neo Tokyo Racers - Racing Phase 11P Time Trial Result Coach
-- Run in Roblox Studio Command Bar, Edit mode, then restart Play.
--
-- This is a guarded source patch against the isolated race entry/results client.
-- It only polishes the time-trial result panel copy:
--   - clearer personal-best delta
--   - clearer next-medal gap
--   - clearer result exit button label
--
-- Scope:
--   Patches only RaceEntryMenuClient_Active.
--   No reward config, route-guide config, arrows, VFX, matchmaking, driving,
--   DataStore, global leaderboard, or bootstrap edits.

local PHASE = "NTR Racing Phase 11P"
local MARKER = "NTR_RACING_PHASE11P_RESULT_COACH_TEXT"

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
	local before = string.sub(source, 1, startIndex - 1)
	local after = string.sub(source, endIndex + 1)
	return before .. new .. after
end

local function patchRaceEntryMenuClient()
	local scriptObject = findPath("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active")
	if not scriptObject or not scriptObject:IsA("LocalScript") then
		fail("Could not find RaceEntryMenuClient_Active LocalScript.")
	end
	local source = scriptObject.Source
	if string.find(source, MARKER, 1, true) then
		print("[" .. PHASE .. "] RaceEntryMenuClient already has Phase 11P result polish.")
		return false
	end

	local exitAnchor = [[local resultExit = button(resultPanel, "EXIT", UDim2.new(0.5, -18, 0, 46), UDim2.new(0.5, 4, 1, -60), theme.Exit)]]
	local exitReplacement = [[local resultExit = button(resultPanel, "EXIT TO START", UDim2.new(0.5, -18, 0, 46), UDim2.new(0.5, 4, 1, -60), theme.Exit)
-- ]] .. MARKER
	source = replaceOnce(source, exitAnchor, exitReplacement, "result exit button label")

	local oldResultBlock = [[	resultTime.Text = formatTime(payload.Elapsed)
	local best = tonumber(payload.PersonalBestSeconds)
	if payload.IsPersonalBest == true then
		resultBest.Text = "NEW PERSONAL BEST  " .. formatTime(best or payload.Elapsed)
	elseif best then
		resultBest.Text = "PERSONAL BEST  " .. formatTime(best)
	else
		resultBest.Text = "PERSONAL BEST  --"
	end
	if payload.NextMedalName and payload.NextMedalSeconds then
		resultNext.Text = "Next medal: " .. tostring(payload.NextMedalName) .. " at " .. formatTime(payload.NextMedalSeconds) .. "  (" .. formatTime(math.abs(tonumber(payload.NextMedalDelta) or 0)) .. " faster)"
	elseif medal == "Platinum" then
		resultNext.Text = "Platinum target cleared."
	else
		resultNext.Text = "No medal targets configured for this tier yet."
	end]]

	local newResultBlock = [[	resultTime.Text = formatTime(payload.Elapsed)
	local elapsed = tonumber(payload.Elapsed) or 0
	local previousBest = tonumber(payload.PreviousBestSeconds)
	local best = tonumber(payload.PersonalBestSeconds)
	if payload.IsPersonalBest == true then
		local delta = previousBest and elapsed > 0 and (previousBest - elapsed) or nil
		if delta and delta > 0.0005 then
			resultBest.Text = "NEW PERSONAL BEST  " .. formatTime(best or elapsed) .. "  (-" .. formatTime(delta) .. ")"
		else
			resultBest.Text = "NEW PERSONAL BEST  " .. formatTime(best or elapsed)
		end
	elseif best then
		local gap = elapsed > 0 and (elapsed - best) or nil
		if gap and gap > 0.0005 then
			resultBest.Text = "PERSONAL BEST  " .. formatTime(best) .. "  (+" .. formatTime(gap) .. ")"
		else
			resultBest.Text = "PERSONAL BEST  " .. formatTime(best)
		end
	else
		resultBest.Text = "PERSONAL BEST  --"
	end
	local nextDelta = math.abs(tonumber(payload.NextMedalDelta) or 0)
	if payload.NextMedalName and payload.NextMedalSeconds then
		resultNext.Text = "NEXT " .. string.upper(tostring(payload.NextMedalName)) .. "  " .. formatTime(payload.NextMedalSeconds) .. "  |  NEED -" .. formatTime(nextDelta)
	elseif medal == "Platinum" then
		resultNext.Text = "PLATINUM TARGET CLEARED."
	else
		resultNext.Text = "No medal targets configured for this tier yet."
	end]]

	source = replaceOnce(source, oldResultBlock, newResultBlock, "time-trial result PB and next-medal text")

	local oldRewardBlock = [[	if payload.RewardGranted == true and rewardAmount > 0 then
		resultReward.Text = "REWARD  $" .. tostring(math.floor(rewardAmount + 0.5))
	elseif payload.RewardMessage and payload.RewardMessage ~= "" then
		resultReward.Text = tostring(payload.RewardMessage)
	else
		resultReward.Text = "No cash reward this run."
	end]]

	local newRewardBlock = [[	if payload.RewardGranted == true and rewardAmount > 0 then
		resultReward.Text = "PRIZE  $" .. tostring(math.floor(rewardAmount + 0.5))
	elseif payload.RewardMessage and payload.RewardMessage ~= "" then
		resultReward.Text = tostring(payload.RewardMessage)
	else
		resultReward.Text = "No cash prize this run."
	end]]

	source = replaceOnce(source, oldRewardBlock, newRewardBlock, "time-trial result reward wording")

	scriptObject.Source = source
	print("[" .. PHASE .. "] Patched RaceEntryMenuClient_Active result panel copy.")
	return true
end

local changed = patchRaceEntryMenuClient()
print("[" .. PHASE .. "] Complete. changed=" .. tostring(changed))
print("[" .. PHASE .. "] Restart Play, finish or quit a time trial with a completed lap, and verify PB delta, next-medal gap, prize text, and EXIT TO START wording.")
