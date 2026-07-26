-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1
-- Neo Tokyo Racers - Racing Phase 11O Time Trial PB Board V2
-- NTR_RACING_PHASE11O_TIME_TRIAL_PB_BOARD_V2_MENU_CLOSE_SYNC

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local Foundation = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ResponsiveUIFoundation"))
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceRequest = racingRemotes:WaitForChild("RaceRequest")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")

local touch = UserInputService.TouchEnabled
local tiers = { "E", "D", "C", "B", "A", "S" }
local cache = {}
local currentEventId = ""
local lastOpenToken = 0
local visibleFromEntryMenu = false

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
}

local function applyFont(label, bold)
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	end)
end

local function corner(parent, radius)
	return Foundation.Corner(parent,radius or 7)
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
	stroke(item, theme.Accent, Foundation.StrokeWidth("Structural"), 0.5)
	return item
end

local function formatTime(seconds)
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then
		return "--"
	end
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%d:%06.3f", minutes, rest)
end

local function cacheKey(eventId, tier)
	return tostring(eventId or "") .. "::" .. string.upper(tostring(tier or ""))
end

local function callPB(eventId, tier)
	local key = cacheKey(eventId, tier)
	if cache[key] ~= nil then
		return cache[key]
	end
	local ok, result = pcall(function()
		return raceRequest:InvokeServer("GetTimeTrialPersonalBest", {
			EventId = tostring(eventId or ""),
			VehicleTier = string.upper(tostring(tier or "")),
		})
	end)
	if ok and type(result) == "table" then
		cache[key] = result
	else
		cache[key] = { Ok = false, Found = false, Message = tostring(result) }
	end
	return cache[key]
end

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_TimeTrialPersonalBestBoard"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 80
gui.Enabled = true
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = touch and UDim2.new(0, 10, 0.5, 0) or UDim2.new(0, 18, 0.5, 0)
panel.Size = touch and UDim2.fromOffset(238, 258) or UDim2.fromOffset(274, 286)
panel.BackgroundColor3 = theme.Panel
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 7)
stroke(panel, theme.Selected, Foundation.StrokeWidth("Emphasis"), 0.18)

local title = label(panel, "MY TIME TRIAL BESTS", UDim2.new(1, -48, 0, 26), UDim2.fromOffset(12, 10), touch and 11 or 13, theme.Text, true)
local close = button(panel, "X", UDim2.fromOffset(28, 24), UDim2.new(1, -38, 0, 10), theme.Exit)
local subtitle = label(panel, "", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 40), touch and 9 or 10, theme.Muted, false)
local rowsFrame = Instance.new("Frame")
rowsFrame.BackgroundTransparency = 1
rowsFrame.Position = UDim2.fromOffset(12, 82)
rowsFrame.Size = UDim2.new(1, -24, 1, -96)
rowsFrame.Parent = panel

local rows = {}
for index, tier in ipairs(tiers) do
	local row = Instance.new("Frame")
	row.Name = "Tier_" .. tier
	row.BackgroundColor3 = theme.Card
	row.BackgroundTransparency = 0.12
	row.BorderSizePixel = 0
	row.Position = UDim2.new(0, 0, 0, (index - 1) * (touch and 28 or 31))
	row.Size = UDim2.new(1, 0, 0, touch and 24 or 27)
	row.Parent = rowsFrame
	corner(row, 5)
	stroke(row, theme.Accent, Foundation.StrokeWidth("Structural"), 0.62)
	local tierLabel = label(row, tier, UDim2.fromOffset(34, row.Size.Y.Offset), UDim2.fromOffset(8, 0), touch and 10 or 11, theme.Accent, true)
	tierLabel.TextXAlignment = Enum.TextXAlignment.Center
	local valueLabel = label(row, "PB --", UDim2.new(1, -52, 1, 0), UDim2.fromOffset(48, 0), touch and 9 or 10, theme.Text, true)
	rows[tier] = valueLabel
end

local function resolveTimeTrialEventId(payload)
	local explicit = tostring(payload.TimeTrialEventId or "")
	if explicit ~= "" then
		return explicit
	end
	local eventId = tostring(payload.EventId or "shifted_canal_sprint_tt")
	if eventId:sub(-5) == "_race" then
		return eventId:sub(1, -6) .. "_tt"
	end
	return eventId
end

local function raceEntryMenuOpen()
	local entryGui = playerGui:FindFirstChild("NTR_RaceEntry")
	if not entryGui then
		return false
	end
	local overlay = entryGui:FindFirstChild("Overlay")
	local root = overlay and overlay:FindFirstChild("Root")
	if root and root:IsA("GuiObject") then
		return root.Visible == true
	end
	if overlay and overlay:IsA("GuiObject") then
		return overlay.Visible == true
	end
	return false
end

local function resultText(result)
	if type(result) ~= "table" then
		return "PB --"
	end
	local best = tonumber(result.BestSeconds or (result.Record and result.Record.BestSeconds))
	if result.Found == true and best then
		local medal = tostring(result.BestMedal or (result.Record and result.Record.BestMedal) or "")
		return "PB " .. formatTime(best) .. (medal ~= "" and (" / " .. string.upper(medal)) or "")
	end
	if result.Ok == false and tostring(result.Message or "") ~= "" then
		return "PB unavailable"
	end
	return "PB --"
end

local function setLoading(eventId)
	for _, tier in ipairs(tiers) do
		rows[tier].Text = "Loading..."
	end
	subtitle.Text = tostring(eventId or "") .. "\nLocal PBs by vehicle tier."
end

local function refreshBoard(eventId)
	eventId = tostring(eventId or "")
	if eventId == "" then
		return
	end
	currentEventId = eventId
	local token = os.clock()
	lastOpenToken = token
	visibleFromEntryMenu = true
	panel.Visible = true
	setLoading(eventId)
	task.spawn(function()
		for _, tier in ipairs(tiers) do
			local result = callPB(eventId, tier)
			if lastOpenToken ~= token or currentEventId ~= eventId then
				return
			end
			rows[tier].Text = resultText(result)
			task.wait(0.03)
		end
	end)
end

local function rememberResult(payload)
	if type(payload) ~= "table" then return end
	local eventId = tostring(payload.EventId or "")
	local tier = string.upper(tostring(payload.VehicleTier or ""))
	local best = tonumber(payload.PersonalBestSeconds)
	if eventId == "" or tier == "" or tier == "--" or not best then
		return
	end
	cache[cacheKey(eventId, tier)] = {
		Ok = true,
		Found = true,
		BestSeconds = best,
		BestMedal = tostring(payload.PersonalBestMedal or payload.Medal or "Finished"),
		EventId = eventId,
		VehicleTier = tier,
	}
	if panel.Visible and currentEventId == eventId and rows[tier] then
		rows[tier].Text = resultText(cache[cacheKey(eventId, tier)])
	end
end

local function hide()
	panel.Visible = false
	currentEventId = ""
	lastOpenToken = os.clock()
	visibleFromEntryMenu = false
end

close.MouseButton1Click:Connect(hide)

task.spawn(function()
	while true do
		if panel.Visible and visibleFromEntryMenu and os.clock() - lastOpenToken > 0.5 and not raceEntryMenuOpen() then
			hide()
		end
		task.wait(0.15)
	end
end)

raceEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	local kind = tostring(payload.Type or "")
	if kind == "OpenRaceEntry" then
		refreshBoard(resolveTimeTrialEventId(payload))
	elseif kind == "TimeTrialFinished" then
		rememberResult(payload)
	elseif kind == "TimeTrialStaged" or kind == "TimeTrialStarted" or kind == "RaceStaged" or kind == "RaceStarted" or kind == "TimeTrialEnded" or kind == "RaceEnded" or kind == "RaceFinished" or kind == "RaceExitedToStart" then
		hide()
	end
end)

print("[NTR Racing Phase 11O Client] Time-trial PB board active with menu-close sync.")
