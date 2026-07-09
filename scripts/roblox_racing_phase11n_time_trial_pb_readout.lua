-- Neo Tokyo Racers - Racing Phase 11N Time Trial PB Readout
-- Run in Roblox Studio Command Bar, Edit mode, then restart Play.
--
-- Adds prototype-safe local personal-best readouts to the time-trial entry flow:
--   - server action GetTimeTrialPersonalBest
--   - PB text on owned vehicle cards, cached by event+tier
--   - selected-vehicle status line includes the current tier PB
--
-- Scope:
--   Patches only TimeTrialService_Active and RaceEntryMenuClient_Active.
--   No reward config, route-guide config, arrows, VFX, matchmaking, driving,
--   global OrderedDataStore leaderboard, or bootstrap edits.

local PHASE = "NTR Racing Phase 11N"

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

local function getScript(path)
	local object = findPath(path)
	if not object then
		fail("Missing " .. path)
	end
	if not (object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript")) then
		fail(path .. " is " .. object.ClassName .. ", expected script.")
	end
	return object
end

local function replaceOnce(source, needle, replacement, label)
	local startIndex, endIndex = string.find(source, needle, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label)
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex + 1)
end

local function patchTimeTrialService()
	local scriptObject = getScript("ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active")
	local source = scriptObject.Source
	if string.find(source, "NTR_RACING_PHASE11N_PB_READOUT_SERVER", 1, true) then
		print("[" .. PHASE .. "] TimeTrialService already has PB readout action.")
		return false
	end

	local helperAnchor = [[local function recordPersistentPersonalBest(player, run, elapsed, medal)
	local binding = getPersonalBestBinding("RecordTimeTrialBest")
	if not binding then
		return nil
	end
	local ok, result = pcall(function()
		return binding:Invoke(player, {
			RunId = run.RunId,
			EventId = run.EventId,
			RouteId = run.RouteId,
			DisplayName = run.DisplayName,
			VehicleTier = run.VehicleTier,
			VehicleIndex = run.VehicleIndex,
			SelectedVehicleId = run.SelectedVehicleId,
			Elapsed = elapsed,
			Medal = medal,
		})
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Message = "Persistent PB service failed: " .. tostring(result) }
end
]]
	local helperReplacement = helperAnchor .. [[

-- NTR_RACING_PHASE11N_PB_READOUT_SERVER
local function getPersistentPersonalBest(player, eventId, vehicleTier)
	local binding = getPersonalBestBinding("GetTimeTrialBest")
	if not binding then
		return { Ok = false, Found = false, Message = "Personal best service unavailable." }
	end
	local ok, result = pcall(function()
		return binding:Invoke(player, {
			EventId = tostring(eventId or ""),
			VehicleTier = tostring(vehicleTier or ""),
		})
	end)
	if ok and typeof(result) == "table" then
		result.EventId = tostring(eventId or "")
		result.VehicleTier = tostring(vehicleTier or "")
		return result
	end
	return { Ok = false, Found = false, Message = "Personal best lookup failed: " .. tostring(result), EventId = tostring(eventId or ""), VehicleTier = tostring(vehicleTier or "") }
end
]]
	source = replaceOnce(source, helperAnchor, helperReplacement, "persistent PB readout helper")

	local actionAnchor = [[	elseif action == "StartStagedTimeTrial" then
		local eventId = tostring(payload.EventId or "shifted_canal_sprint_tt")
		local ok, message = beginStagedTimeTrial(player, eventId, payload.VehicleId, payload.LapCount)
		return { Ok = ok, Success = ok, Message = message }
]]
	local actionReplacement = [[	elseif action == "GetTimeTrialPersonalBest" then
		local eventId = tostring(payload.EventId or "shifted_canal_sprint_tt")
		local vehicleTier = string.upper(tostring(payload.VehicleTier or ""))
		local summary, summaryError = RaceConfigReader.GetEventSummary(eventId, "TimeTrial")
		if not summary then
			return { Ok = false, Found = false, Message = summaryError or "Time trial event unavailable." }
		end
		if vehicleTier == "" or vehicleTier == "--" then
			return { Ok = true, Found = false, Message = "Choose a vehicle tier to view PB.", EventId = eventId, VehicleTier = vehicleTier }
		end
		return getPersistentPersonalBest(player, eventId, vehicleTier)
	elseif action == "StartStagedTimeTrial" then
		local eventId = tostring(payload.EventId or "shifted_canal_sprint_tt")
		local ok, message = beginStagedTimeTrial(player, eventId, payload.VehicleId, payload.LapCount)
		return { Ok = ok, Success = ok, Message = message }
]]
	source = replaceOnce(source, actionAnchor, actionReplacement, "GetTimeTrialPersonalBest server action")

	scriptObject.Source = source
	print("[" .. PHASE .. "] Patched TimeTrialService PB readout action.")
	return true
end

local function patchRaceEntryMenuClient()
	local scriptObject = getScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active")
	local source = scriptObject.Source
	if string.find(source, "NTR_RACING_PHASE11N_PB_READOUT_CLIENT", 1, true) then
		print("[" .. PHASE .. "] RaceEntryMenuClient already has PB readout UI.")
		return false
	end

	local helperAnchor = [[local function raceEventIdForStart()
	-- NTR_RACING_PHASE11B_RACE_EVENT_ID_PAIRING
	local entry = state.Entry or {}
	local paired = tostring(entry.RaceEventId or "")
	if paired ~= "" then
		return paired
	end
	local eventId = tostring(entry.EventId or "shifted_canal_sprint_race")
	if eventId:sub(-3) == "_tt" then
		return eventId:sub(1, -4) .. "_race"
	end
	return eventId ~= "" and eventId or "shifted_canal_sprint_race"
end
]]
	local helperReplacement = helperAnchor .. [[

-- NTR_RACING_PHASE11N_PB_READOUT_CLIENT
local pbReadoutCache = {}

local function formatPBReadoutTime(seconds)
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then
		return "--"
	end
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%d:%06.3f", minutes, rest)
end

local function pbCacheKey(eventId, tier)
	return tostring(eventId or "") .. "::" .. string.upper(tostring(tier or ""))
end

local function timeTrialPBForTier(eventId, tier)
	eventId = tostring(eventId or "")
	tier = string.upper(tostring(tier or ""))
	local key = pbCacheKey(eventId, tier)
	if pbReadoutCache[key] ~= nil then
		return pbReadoutCache[key]
	end
	if eventId == "" or tier == "" or tier == "--" then
		pbReadoutCache[key] = { Ok = true, Found = false, Message = "No tier selected." }
		return pbReadoutCache[key]
	end
	local result = callRace("GetTimeTrialPersonalBest", {
		EventId = eventId,
		VehicleTier = tier,
	})
	if type(result) ~= "table" then
		result = { Ok = false, Found = false, Message = "PB lookup failed." }
	end
	pbReadoutCache[key] = result
	return result
end

local function pbReadoutText(result, compact)
	if type(result) ~= "table" then
		return compact and "PB --" or "Personal best: --"
	end
	local best = tonumber(result.BestSeconds or (result.Record and result.Record.BestSeconds))
	if result.Found == true and best then
		local medal = tostring(result.BestMedal or (result.Record and result.Record.BestMedal) or "")
		local suffix = medal ~= "" and (" / " .. string.upper(medal)) or ""
		return (compact and "PB " or "Personal best: ") .. formatPBReadoutTime(best) .. suffix
	end
	if result.Ok == false and result.Message and result.Message ~= "" then
		return compact and "PB unavailable" or tostring(result.Message)
	end
	return compact and "PB --" or "Personal best: --"
end

local function rememberPBFromResultPayload(payload)
	if type(payload) ~= "table" then
		return
	end
	local eventId = tostring(payload.EventId or "")
	local tier = string.upper(tostring(payload.VehicleTier or ""))
	if eventId == "" or tier == "" or tier == "--" then
		return
	end
	local best = tonumber(payload.PersonalBestSeconds)
	if not best then
		return
	end
	pbReadoutCache[pbCacheKey(eventId, tier)] = {
		Ok = true,
		Found = true,
		BestSeconds = best,
		BestMedal = tostring(payload.PersonalBestMedal or payload.Medal or "Finished"),
		EventId = eventId,
		VehicleTier = tier,
	}
end
]]
	source = replaceOnce(source, helperAnchor, helperReplacement, "PB readout client helpers")

	local cardAnchor = [[		label(card, row.Name, UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, touch and 120 or 154), touch and 10 or 12, theme.Text, true)
		label(card, row.CockpitId, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, touch and 154 or 190), touch and 9 or 10, theme.Muted, false)

		card.MouseButton1Click:Connect(function()
			state.SelectedRow = row
			redrawSelection()
			statusText("Selected " .. row.Name .. " (" .. row.Tier .. " " .. row.RatingIndex .. ")", true)
		end)
]]
	local cardReplacement = [[		label(card, row.Name, UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, touch and 120 or 154), touch and 10 or 12, theme.Text, true)
		label(card, row.CockpitId, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, touch and 150 or 184), touch and 8 or 9, theme.Muted, false)
		local pbText = ""
		if mode == "TimeTrial" then
			pbText = pbReadoutText(timeTrialPBForTier(timeTrialEventIdForStart(), row.Tier), true)
		end
		local pbLabel = label(card, pbText, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, touch and 166 or 204), touch and 8 or 9, theme.Accent, true)
		pbLabel.TextXAlignment = Enum.TextXAlignment.Left

		card.MouseButton1Click:Connect(function()
			state.SelectedRow = row
			redrawSelection()
			if mode == "TimeTrial" then
				statusText("Selected " .. row.Name .. " (" .. row.Tier .. " " .. row.RatingIndex .. ")  " .. pbReadoutText(timeTrialPBForTier(timeTrialEventIdForStart(), row.Tier), false), true)
			else
				statusText("Selected " .. row.Name .. " (" .. row.Tier .. " " .. row.RatingIndex .. ")", true)
			end
		end)
]]
	source = replaceOnce(source, cardAnchor, cardReplacement, "vehicle card PB readout")

	local defaultAnchor = [[	if row.Selected and not state.SelectedRow then
			state.SelectedRow = row
		end
	end
	redrawSelection()
]]
	local defaultReplacement = [[	if row.Selected and not state.SelectedRow then
			state.SelectedRow = row
		end
	end
	redrawSelection()
	if mode == "TimeTrial" and state.SelectedRow then
		statusText("Selected " .. state.SelectedRow.Name .. " (" .. state.SelectedRow.Tier .. " " .. state.SelectedRow.RatingIndex .. ")  " .. pbReadoutText(timeTrialPBForTier(timeTrialEventIdForStart(), state.SelectedRow.Tier), false), true)
	end
]]
	source = replaceOnce(source, defaultAnchor, defaultReplacement, "default selected PB status")

	local finishAnchor = [[	elseif kind == "TimeTrialFinished" then
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudTimer.Text = formatTime(payload.Elapsed)
		hudProgress.Text = "FINISHED"
		hudStatus.Text = tostring(payload.Message or "Finished")
		showResult(payload)
]]
	local finishReplacement = [[	elseif kind == "TimeTrialFinished" then
		rememberPBFromResultPayload(payload)
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudTimer.Text = formatTime(payload.Elapsed)
		hudProgress.Text = "FINISHED"
		hudStatus.Text = tostring(payload.Message or "Finished")
		showResult(payload)
]]
	source = replaceOnce(source, finishAnchor, finishReplacement, "PB cache refresh on TimeTrialFinished")

	scriptObject.Source = source
	print("[" .. PHASE .. "] Patched RaceEntryMenuClient PB readout UI.")
	return true
end

local changedServer = patchTimeTrialService()
local changedClient = patchRaceEntryMenuClient()

print("[" .. PHASE .. "] Complete. changedServer=" .. tostring(changedServer) .. " changedClient=" .. tostring(changedClient))
print("[" .. PHASE .. "] Restart Play, open a time-trial vehicle picker, and confirm owned vehicle cards show PB text by tier.")
