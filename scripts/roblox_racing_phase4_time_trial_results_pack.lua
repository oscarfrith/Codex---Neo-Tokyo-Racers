-- Neo Tokyo Racers - Racing Phase 4 Time Trial Results Pack
-- Adds non-economy time-trial results: tier medal calculation, split payloads,
-- in-session personal bests, result UI, retry, and exit.
--
-- This script uses guarded source-text anchors against the isolated Racing
-- service/client installed by Phase 3/3E. It does not touch the register-limited
-- main client bootstrap, garage server, driving physics, VFX, dealership, or
-- customisation UI. If an anchor is missing, stop and refresh the Studio mirror
-- before writing another repair.
--
-- Usage:
--   MODE = "INSTALL" installs the phase.
--   MODE = "AUDIT" checks expected markers without changing anything.

local MODE = "INSTALL" -- "INSTALL" or "AUDIT"
local PHASE = "NTR Racing Phase 4"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 0)
end

local function replaceExact(source, needle, replacement, label)
	local startIndex, endIndex = source:find(needle, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another Racing Phase 4 repair.")
	end
	return source:sub(1, startIndex - 1) .. replacement .. source:sub(endIndex + 1)
end

local function insertAfter(source, needle, insertion, label)
	local startIndex, endIndex = source:find(needle, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another Racing Phase 4 repair.")
	end
	return source:sub(1, endIndex) .. insertion .. source:sub(endIndex + 1)
end

local function getRacingRoot()
	local root = ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Racing")
	if not root then
		fail("Could not find ServerScriptService.NeoTokyoRacers.Services.Racing. Run Racing Phase 3 first.")
	end
	return root
end

local function getRacingClient()
	local playerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local racing = controllers and controllers:FindFirstChild("Racing")
	local client = racing and racing:FindFirstChild("RaceEntryMenuClient_Active")
	if not (client and client:IsA("LocalScript")) then
		fail("Could not find RaceEntryMenuClient_Active. Run Racing Phase 3 first.")
	end
	return client
end

local function getTimeTrialService()
	local service = getRacingRoot():FindFirstChild("TimeTrialService_Active")
	if not (service and service:IsA("Script")) then
		fail("Could not find TimeTrialService_Active. Run Racing Phase 3 first.")
	end
	return service
end

local function ensureConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = kit:FindFirstChild("Config") or Instance.new("Folder")
	config.Name = "Config"
	config.Parent = kit
	local racing = config:FindFirstChild("Racing") or Instance.new("Folder")
	racing.Name = "Racing"
	racing.Parent = config
	local ui = racing:FindFirstChild("UI") or Instance.new("Folder")
	ui.Name = "UI"
	ui.Parent = racing
	ui:SetAttribute("Phase4ResultsReady", true)
	ui:SetAttribute("ShowTimeTrialResultSplits", true)
	ui:SetAttribute("EnableTimeTrialRetry", true)
end

local SERVER_HELPERS = [==[

-- NTR_RACING_PHASE4_RESULTS_PACK
local personalBests = {}

local MEDAL_ORDER = { "Bronze", "Silver", "Gold", "Platinum" }
local MEDAL_RANK = {
	Finished = 0,
	Bronze = 1,
	Silver = 2,
	Gold = 3,
	Platinum = 4,
}

local function numberOrNil(value)
	value = tonumber(value)
	if value and value > 0 then
		return value
	end
	return nil
end

local function medalRank(name)
	return MEDAL_RANK[tostring(name or "Finished")] or 0
end

local function medalForElapsed(elapsed, medals)
	medals = medals or {}
	local platinum = numberOrNil(medals.Platinum)
	local gold = numberOrNil(medals.Gold)
	local silver = numberOrNil(medals.Silver)
	local bronze = numberOrNil(medals.Bronze)
	if platinum and elapsed <= platinum then
		return "Platinum", platinum
	end
	if gold and elapsed <= gold then
		return "Gold", gold
	end
	if silver and elapsed <= silver then
		return "Silver", silver
	end
	if bronze and elapsed <= bronze then
		return "Bronze", bronze
	end
	return "Finished", nil
end

local function nextMedalTarget(elapsed, medal, medals)
	medals = medals or {}
	local currentRank = medalRank(medal)
	for _, candidate in ipairs(MEDAL_ORDER) do
		local target = numberOrNil(medals[candidate])
		if target and medalRank(candidate) > currentRank then
			return candidate, target, elapsed - target
		end
	end
	if currentRank == 0 then
		local target = numberOrNil(medals.Bronze)
		if target then
			return "Bronze", target, elapsed - target
		end
	end
	return nil, nil, nil
end

local function bestBucket(player, eventId, tier)
	local userId = player.UserId
	personalBests[userId] = personalBests[userId] or {}
	local key = tostring(eventId or "") .. "::" .. string.upper(tostring(tier or ""))
	personalBests[userId][key] = personalBests[userId][key] or {}
	return personalBests[userId][key]
end
]==]

local SERVER_FINISH_RUN = [==[
local function finishRun(player)
	local run = activeRuns[player]
	if not run then return end
	local elapsed = os.clock() - run.StartClock
	activeRuns[player] = nil
	activeRunsById[run.RunId] = nil
	if run.Vehicle then
		setVehicleFrozen(run.Vehicle, false)
		run.Vehicle:SetAttribute("NTR_RaceRunId", nil)
		run.Vehicle:SetAttribute("NTR_RaceParticipant", nil)
		run.Vehicle:SetAttribute("NTR_RaceMode", nil)
		run.Vehicle:SetAttribute("DriveReady", true)
	end
	fireVisibility(run, false)
	clearSessionFolder(run)

	local medals = RaceConfigReader.GetTimeTrialMedals(run.EventId, run.VehicleTier)
	local medal, medalTarget = medalForElapsed(elapsed, medals)
	local nextName, nextSeconds, nextDelta = nextMedalTarget(elapsed, medal, medals)
	local bucket = bestBucket(player, run.EventId, run.VehicleTier)
	local previousBest = tonumber(bucket.BestSeconds)
	local isPersonalBest = previousBest == nil or elapsed < previousBest
	if isPersonalBest then
		bucket.BestSeconds = elapsed
		bucket.BestMedal = medal
		bucket.BestVehicleId = run.SelectedVehicleId
		bucket.BestVehicleTier = run.VehicleTier
		bucket.UpdatedClock = os.clock()
	end

	fire(player, {
		Type = "TimeTrialFinished",
		EventId = run.EventId,
		RouteId = run.RouteId,
		DisplayName = run.DisplayName,
		RunId = run.RunId,
		Elapsed = elapsed,
		GateCount = run.GateCount,
		VehicleTier = run.VehicleTier,
		VehicleIndex = run.VehicleIndex,
		SelectedVehicleId = run.SelectedVehicleId,
		Medals = medals,
		Medal = medal,
		MedalRank = medalRank(medal),
		MedalTargetSeconds = medalTarget,
		NextMedalName = nextName,
		NextMedalSeconds = nextSeconds,
		NextMedalDelta = nextDelta,
		PreviousBestSeconds = previousBest,
		PersonalBestSeconds = bucket.BestSeconds,
		PersonalBestMedal = bucket.BestMedal,
		IsPersonalBest = isPersonalBest,
		Splits = run.Splits or {},
		CanRetry = true,
		Message = isPersonalBest and "New personal best!" or "Finished.",
	})
	info(player.Name .. " finished " .. tostring(run.EventId) .. " in " .. string.format("%.3f", elapsed) .. "s medal=" .. tostring(medal) .. " pb=" .. tostring(isPersonalBest))
end
]==]

local function patchServer()
	local service = getTimeTrialService()
	local source = service.Source
	if source:find("NTR_RACING_PHASE4_RESULTS_PACK", 1, true) then
		info("TimeTrialService_Active already has Phase 4 results markers.")
		return
	end
	if not source:find("NTR_RACING_PHASE3E_RELEASE_HANDOFF", 1, true) then
		fail("TimeTrialService_Active does not include Phase 3E release handoff. Run Phase 3E or the updated Phase 3 installer first.")
	end

	source = insertAfter(source, "local gateConnections = {}\n", SERVER_HELPERS, "active run tables")

	local oldFinish = [==[
local function finishRun(player)
	local run = activeRuns[player]
	if not run then return end
	local elapsed = os.clock() - run.StartClock
	activeRuns[player] = nil
	activeRunsById[run.RunId] = nil
	if run.Vehicle then
		setVehicleFrozen(run.Vehicle, false)
		run.Vehicle:SetAttribute("NTR_RaceRunId", nil)
		run.Vehicle:SetAttribute("NTR_RaceParticipant", nil)
		run.Vehicle:SetAttribute("NTR_RaceMode", nil)
		run.Vehicle:SetAttribute("DriveReady", true)
	end
	fireVisibility(run, false)
	clearSessionFolder(run)
	fire(player, {
		Type = "TimeTrialFinished",
		EventId = run.EventId,
		RouteId = run.RouteId,
		DisplayName = run.DisplayName,
		Elapsed = elapsed,
		GateCount = run.GateCount,
		Message = "Finished. Medals/rewards come next.",
	})
	info(player.Name .. " finished " .. tostring(run.EventId) .. " in " .. string.format("%.3f", elapsed) .. "s")
end
]==]
	source = replaceExact(source, oldFinish, SERVER_FINISH_RUN, "finishRun")

	source = replaceExact(source, [==[
		VehicleIndex = index,
		NextGateIndex = 1,
		GateCount = RouteDefinition.GetGateCount(route),
]==], [==[
		VehicleIndex = index,
		NextGateIndex = 1,
		GateCount = RouteDefinition.GetGateCount(route),
		Splits = {},
]==], "run split table")

	source = replaceExact(source, [==[
	run.NextGateIndex += 1
	fire(player, {
		Type = "TimeTrialCheckpoint",
		EventId = run.EventId,
		RouteId = run.RouteId,
		NextGateIndex = run.NextGateIndex,
		GateCount = run.GateCount,
		CheckpointIndex = gate.Index,
		Elapsed = now - run.StartClock,
	})
]==], [==[
	local splitElapsed = now - run.StartClock
	table.insert(run.Splits, {
		CheckpointIndex = gate.Index,
		Elapsed = splitElapsed,
	})
	run.NextGateIndex += 1
	fire(player, {
		Type = "TimeTrialCheckpoint",
		EventId = run.EventId,
		RouteId = run.RouteId,
		NextGateIndex = run.NextGateIndex,
		GateCount = run.GateCount,
		CheckpointIndex = gate.Index,
		Elapsed = splitElapsed,
		Splits = run.Splits,
	})
]==], "checkpoint split payload")

	source = replaceExact(source, [==[
Players.PlayerRemoving:Connect(function(player)
	endRun(player, "Player left")
end)
]==], [==[
Players.PlayerRemoving:Connect(function(player)
	personalBests[player.UserId] = nil
	endRun(player, "Player left")
end)
]==], "player removing personal best cleanup")

	service.Source = source
	service.Disabled = false
	info("Patched TimeTrialService_Active with medal calculation, splits, and in-session personal bests.")
end

local RESULT_UI_BLOCK = [==[

-- NTR_RACING_PHASE4_CLIENT_RESULTS
local resultGui = Instance.new("ScreenGui")
resultGui.Name = "NTR_RaceResults_Phase4"
resultGui.IgnoreGuiInset = true
resultGui.ResetOnSpawn = false
resultGui.DisplayOrder = 86
resultGui.Enabled = true
resultGui.Parent = playerGui

local resultPanel = Instance.new("Frame")
resultPanel.Name = "Panel"
resultPanel.AnchorPoint = Vector2.new(0.5, 0.5)
resultPanel.Position = UDim2.fromScale(0.5, 0.5)
resultPanel.Size = touch and UDim2.new(0.92, 0, 0, 390) or UDim2.fromOffset(560, 390)
resultPanel.BackgroundColor3 = theme.Panel
resultPanel.BackgroundTransparency = 0.06
resultPanel.BorderSizePixel = 0
resultPanel.Visible = false
resultPanel.Parent = resultGui
corner(resultPanel, 7)
stroke(resultPanel, theme.Selected, 1.6, 0.14)

local resultTitle = label(resultPanel, "TIME TRIAL COMPLETE", UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 12), touch and 14 or 18, theme.Text, true)
resultTitle.TextXAlignment = Enum.TextXAlignment.Center
local resultMedal = label(resultPanel, "FINISHED", UDim2.new(1, -28, 0, 48), UDim2.fromOffset(14, 48), touch and 24 or 34, theme.Accent, true)
resultMedal.TextXAlignment = Enum.TextXAlignment.Center
local resultTime = label(resultPanel, "0.000", UDim2.new(1, -28, 0, 36), UDim2.fromOffset(14, 98), touch and 18 or 26, theme.Text, true)
resultTime.TextXAlignment = Enum.TextXAlignment.Center
local resultBest = label(resultPanel, "", UDim2.new(1, -36, 0, 36), UDim2.fromOffset(18, 140), touch and 11 or 13, theme.Accent, true)
resultBest.TextXAlignment = Enum.TextXAlignment.Center
local resultNext = label(resultPanel, "", UDim2.new(1, -36, 0, 42), UDim2.fromOffset(18, 178), touch and 11 or 13, theme.Muted, false)
resultNext.TextXAlignment = Enum.TextXAlignment.Center
local resultSplits = label(resultPanel, "", UDim2.new(1, -36, 0, 82), UDim2.fromOffset(18, 226), touch and 10 or 12, theme.Text, false)
resultSplits.TextYAlignment = Enum.TextYAlignment.Top

local resultRetry = button(resultPanel, "RETRY", UDim2.new(0.5, -18, 0, 46), UDim2.new(0, 14, 1, -60), theme.Buy)
local resultExit = button(resultPanel, "EXIT", UDim2.new(0.5, -18, 0, 46), UDim2.new(0.5, 4, 1, -60), theme.Exit)
local lastFinishedRun = nil

local function medalColor(medal)
	medal = tostring(medal or "")
	if medal == "Platinum" then
		return Color3.fromRGB(185, 240, 255)
	elseif medal == "Gold" then
		return Color3.fromRGB(255, 220, 85)
	elseif medal == "Silver" then
		return Color3.fromRGB(210, 225, 235)
	elseif medal == "Bronze" then
		return Color3.fromRGB(220, 142, 76)
	end
	return theme.Accent
end

local function medalLabel(medal)
	medal = tostring(medal or "Finished")
	if medal == "Finished" or medal == "" then
		return "FINISHED"
	end
	return string.upper(medal)
end

local function splitSummary(splits)
	local list = {}
	for _, split in ipairs(splits or {}) do
		if #list >= 4 then
			break
		end
		table.insert(list, "CP " .. tostring(split.CheckpointIndex or "?") .. "  " .. formatTime(split.Elapsed))
	end
	if #list == 0 then
		return "Splits will appear after the first checkpoint."
	end
	return table.concat(list, "\n")
end

local function hideResult()
	resultPanel.Visible = false
	lastFinishedRun = nil
end

local function showResult(payload)
	lastFinishedRun = payload
	local medal = tostring(payload.Medal or "Finished")
	resultTitle.Text = tostring(payload.DisplayName or "TIME TRIAL COMPLETE")
	resultMedal.Text = medalLabel(medal)
	resultMedal.TextColor3 = medalColor(medal)
	resultTime.Text = formatTime(payload.Elapsed)
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
	end
	resultSplits.Text = splitSummary(payload.Splits)
	resultRetry.Visible = payload.CanRetry ~= false
	resultPanel.Visible = true
end

resultRetry.MouseButton1Click:Connect(function()
	local run = lastFinishedRun
	if not run then
		return
	end
	hideResult()
	hud.Visible = true
	hudTitle.Text = tostring(run.DisplayName or "TIME TRIAL")
	hudTimer.Text = "--"
	hudProgress.Text = "RESTAGING"
	hudStatus.Text = "Retrying..."
	local result = callRace("StartStagedTimeTrial", {
		EventId = run.EventId,
		VehicleId = run.SelectedVehicleId,
	})
	if result.Ok ~= true and result.Success ~= true then
		hudStatus.Text = tostring(result.Message or "Could not retry.")
		resultPanel.Visible = true
		lastFinishedRun = run
	end
end)

resultExit.MouseButton1Click:Connect(function()
	hideResult()
	stopTicker()
	clearMarker()
	state.ActiveRun = nil
	hud.Visible = false
	callRace("CancelTimeTrial", {})
end)
]==]

local function patchClient()
	local client = getRacingClient()
	local source = client.Source
	if source:find("NTR_RACING_PHASE4_CLIENT_RESULTS", 1, true) then
		info("RaceEntryMenuClient_Active already has Phase 4 results UI markers.")
		return
	end
	if not source:find("NTR_RACING_PHASE3E_CLIENT_HANDOFF", 1, true) then
		fail("RaceEntryMenuClient_Active does not include Phase 3E client handoff. Run Phase 3E or the updated Phase 3 installer first.")
	end

	source = insertAfter(source, [==[
local function showHudError(message)
	hud.Visible = true
	hudTitle.Text = "RACING"
	hudTimer.Text = "--"
	hudProgress.Text = ""
	hudStatus.Text = tostring(message or "Race unavailable.")
	task.delay(2.2, function()
		if not state.ActiveRun then
			hud.Visible = false
			hudStatus.Text = ""
		end
	end)
end
]==], RESULT_UI_BLOCK, "hud error/result UI")

	source = replaceExact(source, [==[
	elseif kind == "TimeTrialStaged" then
		state.ActiveRun = {
]==], [==[
	elseif kind == "TimeTrialStaged" then
		hideResult()
		state.ActiveRun = {
]==], "hide result on staged")

	source = replaceExact(source, [==[
	elseif kind == "TimeTrialStarted" then
		state.ActiveRun = state.ActiveRun or {}
]==], [==[
	elseif kind == "TimeTrialStarted" then
		hideResult()
		state.ActiveRun = state.ActiveRun or {}
]==], "hide result on started")

	source = replaceExact(source, [==[
	elseif kind == "TimeTrialFinished" then
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudTimer.Text = formatTime(payload.Elapsed)
		hudProgress.Text = "FINISHED"
		hudStatus.Text = tostring(payload.Message or "Finished")
]==], [==[
	elseif kind == "TimeTrialFinished" then
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudTimer.Text = formatTime(payload.Elapsed)
		hudProgress.Text = "FINISHED"
		hudStatus.Text = tostring(payload.Message or "Finished")
		showResult(payload)
]==], "show result on finish")

	source = replaceExact(source, [==[
	elseif kind == "TimeTrialEnded" then
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = false
]==], [==[
	elseif kind == "TimeTrialEnded" then
		hideResult()
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = false
]==], "hide result on ended")

	client.Source = source
	client.Disabled = false
	info("Patched RaceEntryMenuClient_Active with finish results UI and retry/exit buttons.")
end

local function audit()
	local service = getTimeTrialService()
	local client = getRacingClient()
	info("Audit:")
	info("  TimeTrialService_Active=" .. tostring(service ~= nil))
	info("  RaceEntryMenuClient_Active=" .. tostring(client ~= nil))
	info("  Server Phase4 marker=" .. tostring(service.Source:find("NTR_RACING_PHASE4_RESULTS_PACK", 1, true) ~= nil))
	info("  Client Phase4 marker=" .. tostring(client.Source:find("NTR_RACING_PHASE4_CLIENT_RESULTS", 1, true) ~= nil))
	info("  Server Phase3E marker=" .. tostring(service.Source:find("NTR_RACING_PHASE3E_RELEASE_HANDOFF", 1, true) ~= nil))
	info("  Client Phase3E marker=" .. tostring(client.Source:find("NTR_RACING_PHASE3E_CLIENT_HANDOFF", 1, true) ~= nil))
end

local function install()
	ensureConfig()
	patchServer()
	patchClient()
	info("Installed Phase 4 time-trial results pack. Restart Play before testing.")
	audit()
end

if MODE == "INSTALL" then
	install()
elseif MODE == "AUDIT" then
	audit()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
