-- Neo Tokyo Racers - Racing Phase 11T Isolated Time Trial Result Coach
-- Run in Roblox Studio Command Bar, Edit mode, then restart Play.
--
-- Adds a standalone local result panel for time trials without patching the
-- confirmed RaceEntryMenuClient_Active source again.
--
-- Scope:
--   Creates/replaces only RaceTimeTrialResultCoachClient_Active.
--   No reward config, route-guide config, arrows, VFX, matchmaking, driving
--   physics, DataStore, global leaderboard, or bootstrap edits.

local PHASE = "NTR Racing Phase 11T"

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		fail(item:GetFullName() .. " must be a Folder.")
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function ensureClientFolder()
	local starterPlayer = game:GetService("StarterPlayer")
	local scripts = starterPlayer:WaitForChild("StarterPlayerScripts")
	local root = ensureFolder(scripts, "NeoTokyoRacersClient")
	local controllers = ensureFolder(root, "Controllers")
	return ensureFolder(controllers, "Racing")
end

local CLIENT_SOURCE = [==[
-- Neo Tokyo Racers - Racing Phase 11T Isolated Time Trial Result Coach
-- NTR_RACING_PHASE11T_ISOLATED_TT_RESULT_COACH

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceRequest = racingRemotes:WaitForChild("RaceRequest")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")

local touch = UserInputService.TouchEnabled
local lastResult = nil
local lastToken = 0

local function themeFolder()
	local config = kit:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	return ui and ui:FindFirstChild("Theme")
end

local function themeColor(name, fallback)
	local folder = themeFolder()
	local value = folder and folder:FindFirstChild(name)
	if value and value:IsA("Color3Value") then
		return value.Value
	end
	return fallback
end

local theme = {
	Panel = themeColor("Panel", Color3.fromRGB(6, 10, 13)),
	Card = themeColor("Card", Color3.fromRGB(14, 20, 26)),
	Text = themeColor("Text", Color3.fromRGB(240, 255, 249)),
	Muted = themeColor("Muted", Color3.fromRGB(145, 170, 165)),
	Accent = themeColor("Accent", Color3.fromRGB(70, 255, 190)),
	Selected = themeColor("Selected", Color3.fromRGB(255, 68, 196)),
	Exit = themeColor("Exit", Color3.fromRGB(230, 74, 116)),
	Buy = themeColor("Buy", Color3.fromRGB(54, 219, 160)),
}

local function applyFont(label, bold)
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	end)
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 7)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or theme.Accent
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.35
	s.Parent = parent
	return s
end

local function label(parent, text, size, position, textSize, color, bold)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Size = size
	item.Position = position
	item.Text = text or ""
	item.TextColor3 = color or theme.Text
	item.TextSize = textSize or 12
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	applyFont(item, bold)
	item.Parent = parent
	return item
end

local function button(parent, text, size, position, color)
	local item = Instance.new("TextButton")
	item.AutoButtonColor = true
	item.BorderSizePixel = 0
	item.Size = size
	item.Position = position
	item.Text = text or ""
	item.TextColor3 = Color3.fromRGB(245, 255, 250)
	item.TextSize = touch and 10 or 12
	item.TextWrapped = true
	item.BackgroundColor3 = color or theme.Card
	applyFont(item, true)
	item.Parent = parent
	corner(item, 5)
	stroke(item, theme.Accent, 1, 0.5)
	return item
end

local function formatTime(seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%d:%06.3f", minutes, rest)
end

local function signedTime(prefix, seconds)
	seconds = tonumber(seconds)
	if not seconds or seconds <= 0.0005 then
		return ""
	end
	return "  (" .. tostring(prefix or "") .. formatTime(seconds) .. ")"
end

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

local function fireDrivingExitHandoff()
	local clientRoot = script.Parent.Parent
	local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
	local exitedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleExited")
	if exitedEvent and exitedEvent:IsA("BindableEvent") then
		exitedEvent:Fire()
	end
end

local function callRace(action, payload)
	local ok, result = pcall(function()
		return raceRequest:InvokeServer(action, payload or {})
	end)
	if ok and type(result) == "table" then
		return result
	end
	return { Ok = false, Success = false, Message = tostring(result) }
end

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_TimeTrialResultCoach"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 92
gui.Enabled = true
gui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.42
backdrop.BorderSizePixel = 0
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Visible = false
backdrop.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.51)
panel.Size = touch and UDim2.new(0.92, 0, 0, 430) or UDim2.fromOffset(620, 430)
panel.BackgroundColor3 = theme.Panel
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = backdrop
corner(panel, 7)
stroke(panel, theme.Selected, 1.6, 0.12)

local title = label(panel, "TIME TRIAL COMPLETE", UDim2.new(1, -28, 0, 26), UDim2.fromOffset(14, 12), touch and 13 or 16, theme.Text, true)
title.TextXAlignment = Enum.TextXAlignment.Center
local medal = label(panel, "FINISHED", UDim2.new(1, -28, 0, 44), UDim2.fromOffset(14, 44), touch and 22 or 30, theme.Accent, true)
medal.TextXAlignment = Enum.TextXAlignment.Center
local time = label(panel, "0:00.000", UDim2.new(1, -28, 0, 34), UDim2.fromOffset(14, 91), touch and 18 or 24, theme.Text, true)
time.TextXAlignment = Enum.TextXAlignment.Center
local pb = label(panel, "PERSONAL BEST  --", UDim2.new(1, -36, 0, 34), UDim2.fromOffset(18, 132), touch and 10 or 12, theme.Accent, true)
pb.TextXAlignment = Enum.TextXAlignment.Center
local nextMedal = label(panel, "", UDim2.new(1, -36, 0, 38), UDim2.fromOffset(18, 169), touch and 10 or 12, theme.Muted, false)
nextMedal.TextXAlignment = Enum.TextXAlignment.Center
local prize = label(panel, "", UDim2.new(1, -36, 0, 28), UDim2.fromOffset(18, 211), touch and 11 or 13, theme.Accent, true)
prize.TextXAlignment = Enum.TextXAlignment.Center
local splits = label(panel, "", UDim2.new(1, -36, 0, 74), UDim2.fromOffset(18, 247), touch and 10 or 11, theme.Text, false)
splits.TextYAlignment = Enum.TextYAlignment.Top
splits.TextXAlignment = Enum.TextXAlignment.Center
local status = label(panel, "", UDim2.new(1, -36, 0, 26), UDim2.fromOffset(18, 326), touch and 10 or 11, theme.Muted, false)
status.TextXAlignment = Enum.TextXAlignment.Center

local retry = button(panel, "RETRY", UDim2.new(0.5, -18, 0, 46), UDim2.new(0, 14, 1, -60), theme.Buy)
local exit = button(panel, "EXIT TO START", UDim2.new(0.5, -18, 0, 46), UDim2.new(0.5, 4, 1, -60), theme.Exit)

local function hideLegacyResultPanel()
	local legacyGui = playerGui:FindFirstChild("NTR_RaceResults_Phase4")
	local legacyPanel = legacyGui and legacyGui:FindFirstChild("Panel")
	if legacyPanel and legacyPanel:IsA("GuiObject") then
		legacyPanel.Visible = false
	end
end

local function keepLegacyHidden(token)
	for _, delaySeconds in ipairs({ 0, 0.05, 0.2, 0.5 }) do
		task.delay(delaySeconds, function()
			if lastToken == token and panel.Visible then
				hideLegacyResultPanel()
			end
		end)
	end
end

local function hide()
	lastResult = nil
	lastToken += 1
	panel.Visible = false
	backdrop.Visible = false
	status.Text = ""
end

local function resultTitle(payload)
	if tostring(payload.FinishReason or "") == "Quit" then
		return tostring(payload.DisplayName or "TIME TRIAL SESSION")
	end
	if tostring(payload.RouteType or "") == "Circuit" and tonumber(payload.CompletedLapCount) and tonumber(payload.CompletedLapCount) > 1 then
		return tostring(payload.DisplayName or "BEST LAP")
	end
	return tostring(payload.DisplayName or "TIME TRIAL COMPLETE")
end

local function splitText(payload)
	if payload.LapTimes and #payload.LapTimes > 0 then
		local lines = {}
		for _, lap in ipairs(payload.LapTimes) do
			if #lines >= 4 then break end
			table.insert(lines, "LAP " .. tostring(lap.Lap or "?") .. "   " .. formatTime(lap.Elapsed))
		end
		return table.concat(lines, "\n")
	end
	local lines = {}
	for _, split in ipairs(payload.Splits or {}) do
		if #lines >= 4 then break end
		table.insert(lines, "CP " .. tostring(split.CheckpointIndex or "?") .. "   " .. formatTime(split.Elapsed))
	end
	if #lines == 0 then
		return "Splits will appear after the first checkpoint."
	end
	return table.concat(lines, "\n")
end

local function show(payload)
	lastResult = payload
	lastToken += 1
	local token = lastToken
	fireDrivingExitHandoff()
	hideLegacyResultPanel()
	keepLegacyHidden(token)

	local medalName = tostring(payload.Medal or "Finished")
	local elapsed = tonumber(payload.Elapsed) or 0
	local previousBest = tonumber(payload.PreviousBestSeconds)
	local best = tonumber(payload.PersonalBestSeconds)

	title.Text = resultTitle(payload)
	medal.Text = string.upper(medalName == "" and "FINISHED" or medalName)
	medal.TextColor3 = medalColor(medalName)
	time.Text = formatTime(elapsed)

	if payload.IsPersonalBest == true then
		local delta = previousBest and elapsed > 0 and (previousBest - elapsed) or nil
		pb.Text = "NEW PERSONAL BEST  " .. formatTime(best or elapsed) .. signedTime("-", delta)
	elseif best then
		local gap = elapsed > 0 and (elapsed - best) or nil
		pb.Text = "PERSONAL BEST  " .. formatTime(best) .. signedTime("+", gap)
	else
		pb.Text = "PERSONAL BEST  --"
	end

	if payload.NextMedalName and payload.NextMedalSeconds then
		nextMedal.Text = "NEXT " .. string.upper(tostring(payload.NextMedalName)) .. "  " .. formatTime(payload.NextMedalSeconds) .. "  |  NEED -" .. formatTime(math.abs(tonumber(payload.NextMedalDelta) or 0))
	elseif medalName == "Platinum" then
		nextMedal.Text = "PLATINUM TARGET CLEARED."
	else
		nextMedal.Text = "No medal targets configured for this tier yet."
	end

	local amount = tonumber(payload.RewardAmount) or 0
	if payload.RewardGranted == true and amount > 0 then
		prize.Text = "PRIZE  $" .. tostring(math.floor(amount + 0.5))
	elseif payload.RewardMessage and payload.RewardMessage ~= "" then
		prize.Text = tostring(payload.RewardMessage)
	else
		prize.Text = "No cash prize this run."
	end

	splits.Text = splitText(payload)
	status.Text = tostring(payload.Message or "")
	retry.Visible = payload.CanRetry ~= false
	backdrop.Visible = true
	panel.Visible = true
end

retry.MouseButton1Click:Connect(function()
	local run = lastResult
	if not run then return end
	status.Text = "Retrying..."
	local result = callRace("StartStagedTimeTrial", {
		EventId = run.EventId,
		VehicleId = run.SelectedVehicleId,
	})
	if result.Ok == true or result.Success == true then
		hide()
	else
		status.Text = tostring(result.Message or "Could not retry.")
	end
end)

exit.MouseButton1Click:Connect(function()
	fireDrivingExitHandoff()
	status.Text = "Returning to start..."
	hide()
	local result = callRace("ExitFinishedTimeTrial", {})
	if result.Ok ~= true and result.Success ~= true then
		callRace("CancelTimeTrial", {})
	end
end)

raceEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	local kind = tostring(payload.Type or "")
	if kind == "TimeTrialFinished" then
		show(payload)
	elseif kind == "TimeTrialStaged" or kind == "TimeTrialStarted" or kind == "TimeTrialEnded" or kind == "TimeTrialError" or kind == "RaceStaged" or kind == "RaceStarted" or kind == "RaceFinished" or kind == "RaceEnded" or kind == "RaceExitedToStart" then
		hide()
	end
end)

print("[NTR Racing Phase 11T Client] Isolated time-trial result coach active.")
]==]

local function install()
	local folder = ensureClientFolder()
	local scriptObject = folder:FindFirstChild("RaceTimeTrialResultCoachClient_Active")
	if scriptObject and not scriptObject:IsA("LocalScript") then
		scriptObject:Destroy()
		scriptObject = nil
	end
	if not scriptObject then
		scriptObject = Instance.new("LocalScript")
		scriptObject.Name = "RaceTimeTrialResultCoachClient_Active"
		scriptObject.Parent = folder
	end
	if string.find(scriptObject.Source, "NTR_RACING_PHASE11T_ISOLATED_TT_RESULT_COACH", 1, true) then
		print("[" .. PHASE .. "] RaceTimeTrialResultCoachClient already installed.")
		return false
	end
	scriptObject.Source = CLIENT_SOURCE
	scriptObject.Disabled = false
	print("[" .. PHASE .. "] Installed RaceTimeTrialResultCoachClient_Active.")
	return true
end

local changed = install()
print("[" .. PHASE .. "] Complete. changed=" .. tostring(changed))
print("[" .. PHASE .. "] Restart Play, finish a time trial, and verify the isolated result panel handles retry/exit cleanly.")
