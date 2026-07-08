-- Neo Tokyo Racers - Racing Phase 7 Free-Roam Race Browser
-- NTR_RACING_PHASE7_RACE_BROWSER

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local touch = UserInputService.TouchEnabled

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local racingModules = shared:WaitForChild("Modules"):WaitForChild("Racing")
local RaceConfigReader = require(racingModules:WaitForChild("RaceConfigReader"))
local RouteDefinition = require(racingModules:WaitForChild("RaceRouteDefinition"))

local controllers = script.Parent.Parent
local uiFolder = controllers:WaitForChild("UI")
local openEvent = uiFolder:WaitForChild("OpenRaceBrowser")
local raceBrowserTeleportInvoke = shared:WaitForChild("Remotes"):WaitForChild("Racing"):WaitForChild("RaceBrowserTeleportInvoke")
-- NTR_RACING_PHASE7B_TELEPORT_CLIENT

local config = kit:WaitForChild("Config")
local racingConfig = config:WaitForChild("Racing")
local uiConfig = config:WaitForChild("UI")
local browserConfig = uiConfig:WaitForChild("RaceBrowser")

local defaultTheme = {
	Panel = Color3.fromRGB(6, 10, 13),
	PanelSoft = Color3.fromRGB(10, 15, 20),
	Card = Color3.fromRGB(18, 27, 31),
	Text = Color3.fromRGB(240, 255, 249),
	Muted = Color3.fromRGB(145, 170, 165),
	Accent = Color3.fromRGB(70, 255, 190),
	Selected = Color3.fromRGB(255, 68, 196),
	Buy = Color3.fromRGB(35, 200, 125),
	Back = Color3.fromRGB(24, 35, 42),
	Exit = Color3.fromRGB(230, 74, 116),
}

local activeTab = "TimeTrial"
local selectedRow = nil
local teleportBusy = false
local setOpen = nil -- NTR_RACING_PHASE7B_CLOSE_ON_TELEPORT

local gui, overlay, root, title, subtitle, tabRail, list, detail, closeButton

local function readColor(folder, name, fallback, alternate)
	local item = folder and (folder:FindFirstChild(name) or (alternate and folder:FindFirstChild(alternate)))
	return item and item:IsA("Color3Value") and item.Value or fallback
end

local function readNumber(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function readString(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("StringValue") and item.Value or fallback
end

local function assetImage(value)
	local text = tostring(value or "")
	if text == "" then return "" end
	if string.find(text, "rbxassetid://", 1, true) or string.find(text, "rbxthumb://", 1, true) then
		return text
	end
	if tonumber(text) then
		return "rbxassetid://" .. text
	end
	return text
end

local function themeFolder()
	return uiConfig and uiConfig:FindFirstChild("Theme")
end

local function theme()
	local folder = themeFolder()
	return {
		Panel = readColor(folder, "Panel", defaultTheme.Panel),
		PanelSoft = readColor(folder, "PanelSoft", defaultTheme.PanelSoft),
		Card = readColor(folder, "Card", defaultTheme.Card),
		Text = readColor(folder, "Text", defaultTheme.Text),
		Muted = readColor(folder, "Muted", defaultTheme.Muted, "MutedText"),
		Accent = readColor(folder, "Accent", defaultTheme.Accent),
		Selected = readColor(folder, "Selected", defaultTheme.Selected, "CardHot"),
		Buy = readColor(folder, "Buy", defaultTheme.Buy),
		Back = readColor(folder, "Back", defaultTheme.Back, "BackButton"),
		Exit = readColor(folder, "Exit", defaultTheme.Exit, "ExitButton"),
		FontFamily = readString(folder, "FontFamily", "rbxasset://fonts/families/Michroma.json"),
		PanelTransparency = readNumber(folder, "PanelTransparency", 0.08),
	}
end

local function applyFont(object, bold)
	object.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	local family = theme().FontFamily
	if family and family ~= "" then
		pcall(function()
			object.FontFace = Font.new(family, bold and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
		end)
	end
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 7)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.25
	s.Parent = parent
	return s
end

local function label(parent, text, size, position, textSize, color, bold)
	local t = theme()
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Position = position or UDim2.fromOffset(0, 0)
	item.Size = size or UDim2.fromScale(1, 1)
	item.Text = tostring(text or "")
	item.TextColor3 = color or t.Text
	item.TextSize = textSize or 12
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	applyFont(item, bold)
	item.Parent = parent
	return item
end

local function button(parent, name, text, color)
	local t = theme()
	local item = Instance.new("TextButton")
	item.Name = name
	item.AutoButtonColor = true
	item.BackgroundColor3 = color or t.Card
	item.BackgroundTransparency = 0.05
	item.BorderSizePixel = 0
	item.Text = text or ""
	item.TextColor3 = Color3.fromRGB(245, 255, 250)
	item.TextSize = touch and 10 or 12
	item.TextWrapped = true
	applyFont(item, true)
	item.Parent = parent
	corner(item, 6)
	stroke(item, t.Accent, 1, 0.45)
	return item
end

local function clear(parent)
	for _, child in ipairs(parent:GetChildren()) do
		child:Destroy()
	end
end

local function eventChildren(catalogName)
	local folder = racingConfig:FindFirstChild(catalogName)
	local rows = {}
	for _, event in ipairs(folder and folder:GetChildren() or {}) do
		if event:IsA("Folder") or event:IsA("Configuration") then
			table.insert(rows, event)
		end
	end
	table.sort(rows, function(a, b)
		local aName = tostring(a:GetAttribute("DisplayName") or a.Name)
		local bName = tostring(b:GetAttribute("DisplayName") or b.Name)
		return aName < bName
	end)
	return rows
end

local function distanceTo(part)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not (rootPart and part) then return math.huge end
	return (rootPart.Position - part.Position).Magnitude
end

local function startZoneFor(summary, mode)
	local route = nil
	pcall(function()
		route = RouteDefinition.GetRouteDefinition(summary.RouteId)
	end)
	if not route then return nil end
	local eventId = tostring(summary.EventId or "")
	local fallback = nil
	for _, zone in ipairs(route.StartZones or {}) do
		local zoneMode = tostring(zone.Mode or "")
		local zoneEvent = tostring(zone.EventId or "")
		if not fallback and zoneMode == mode then
			fallback = zone.Part
		end
		if zoneEvent ~= "" and zoneEvent == eventId then
			return zone.Part
		end
	end
	return fallback or ((route.StartZones and route.StartZones[1] and route.StartZones[1].Part) or nil)
end

local function makeRows(mode)
	local rows = {}
	local catalogName = mode == "Race" and "RaceCatalog" or "TimeTrialCatalog"
	for _, event in ipairs(eventChildren(catalogName)) do
		local eventId = tostring(event:GetAttribute("EventId") or event.Name)
		local ok, summary = pcall(function()
			return RaceConfigReader.GetEventSummary(eventId, mode)
		end)
		if ok and type(summary) == "table" then
			local zone = startZoneFor(summary, mode)
			summary.Mode = mode
			table.insert(rows, {
				Event = event,
				Summary = summary,
				StartZone = zone,
				Distance = distanceTo(zone),
			})
		end
	end
	table.sort(rows, function(a, b)
		local aDist = a.Distance or math.huge
		local bDist = b.Distance or math.huge
		if math.abs(aDist - bDist) > 8 then
			return aDist < bDist
		end
		return tostring(a.Summary.DisplayName) < tostring(b.Summary.DisplayName)
	end)
	return rows
end

local function formatMoney(value)
	value = math.floor((tonumber(value) or 0) + 0.5)
	local text = tostring(value)
	while true do
		local nextText, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = nextText
		if count == 0 then break end
	end
	return "$" .. text
end

local function formatDistance(studs)
	if not studs or studs == math.huge then return "--" end
	return tostring(math.floor(studs + 0.5)) .. " studs"
end

local function recommendedMedals(summary)
	if summary.Mode ~= "TimeTrial" then
		return "Placement rewards: Gold 1st, Silver 2nd, Bronze 3rd."
	end
	local tier = tostring(summary.RecommendedTier or "D")
	local medals = RaceConfigReader.GetTimeTrialMedals(summary.EventId, tier)
	local parts = {}
	for _, name in ipairs({ "Bronze", "Silver", "Gold", "Platinum" }) do
		local value = tonumber(medals[name])
		if value and value > 0 then
			table.insert(parts, name .. " " .. string.format("%.1fs", value))
		end
	end
	if #parts == 0 then
		return "No medal targets configured for tier " .. tier .. " yet."
	end
	return tier .. " targets: " .. table.concat(parts, "  ")
end

local function fireFreeRoamVehicleExited()
	local ui = controllers and controllers:FindFirstChild("UI")
	local event = ui and ui:FindFirstChild("FreeRoamVehicleExited")
	if event and event:IsA("BindableEvent") then
		event:Fire()
	end
end
local function fireRaceTransition(step, payload)
	-- NTR_RACING_PHASE8D_BROWSER_TELEPORT_FADE
	local event = script.Parent and script.Parent:FindFirstChild("RaceTransitionRequest")
	if event and event:IsA("BindableEvent") then
		payload = payload or {}
		payload.Step = step
		event:Fire(payload)
	end
end

local function teleportToStart(row)
	if teleportBusy then
		return
	end
	if not row then
		subtitle.Text = "Select an event first."
		return
	end
	teleportBusy = true
	subtitle.Text = "Teleporting and clearing your current vehicle..."
	fireRaceTransition("FadeOut", { Reason = "BrowserTeleport", Label = "TELEPORTING" })
	task.wait(0.25)
	local ok, result = pcall(function()
		return raceBrowserTeleportInvoke:InvokeServer("TeleportToRaceStart", {
			EventId = row.Summary.EventId,
			Mode = row.Summary.Mode,
		})
	end)
	teleportBusy = false
	if not ok or typeof(result) ~= "table" or (result.Ok ~= true and result.Success ~= true) then
		fireRaceTransition("FadeIn", { Reason = "BrowserTeleportFailed", Delay = 0.08 })
		subtitle.Text = (typeof(result) == "table" and tostring(result.Message or result.Error)) or "Teleport failed."
		return
	end
	fireFreeRoamVehicleExited()
	if setOpen then
		setOpen(false)
	end
	fireRaceTransition("RestoreCamera", { Reason = "BrowserTeleport" })
	fireRaceTransition("FadeIn", { Reason = "BrowserTeleport", Delay = 0.3 })
	subtitle.Text = "Teleported. Enter the start zone and press E / tap to open the entry menu."
end

local function renderDetail(row)
	clear(detail)
	local t = theme()
	if not row then
		label(detail, "Select a race or time trial.", UDim2.new(1, -20, 0, 48), UDim2.fromOffset(10, 10), 13, t.Muted, true)
		return
	end
	local summary = row.Summary
	local image = assetImage(summary.TrackImage)
	local media = Instance.new("Frame")
	media.Name = "TrackMedia"
	media.BackgroundColor3 = Color3.fromRGB(8, 12, 17)
	media.BorderSizePixel = 0
	media.Position = UDim2.fromOffset(10, 10)
	media.Size = UDim2.new(1, -20, 0, touch and 104 or 140)
	media.Parent = detail
	corner(media, 6)
	stroke(media, t.Selected, 1, 0.45)
	if image ~= "" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = image
		img.ScaleType = Enum.ScaleType.Fit
		img.Size = UDim2.new(1, -10, 1, -10)
		img.Position = UDim2.fromOffset(5, 5)
		img.Parent = media
	else
		local noImage = label(media, "TRACK IMAGE", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 13, t.Muted, true)
		noImage.TextXAlignment = Enum.TextXAlignment.Center
	end

	local y = touch and 126 or 166
	label(detail, tostring(summary.DisplayName or summary.EventId), UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, y), touch and 13 or 16, t.Text, true)
	y += 36
	label(detail, "Route: " .. tostring(summary.RouteDisplayName or summary.RouteId), UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, y), 11, t.Muted, false)
	y += 26
	local category = summary.Mode == "Race" and "Open category race" or ("Tiered time trial. Recommended " .. tostring(summary.RecommendedTier or "--"))
	label(detail, category, UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, y), 11, t.Accent, true)
	y += 26
	label(detail, "Checkpoints: " .. tostring(summary.CheckpointCount or 0) .. "   Arrows: " .. tostring(summary.ArrowCount or 0) .. "   Base reward: " .. formatMoney(summary.BaseReward), UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, y), 10, t.Muted, false)
	y += 34
	label(detail, recommendedMedals(summary), UDim2.new(1, -20, 0, 74), UDim2.fromOffset(10, y), touch and 10 or 11, t.Text, false)

	local track = button(detail, "TrackStart", "TELEPORT TO START", t.Buy)
	track.Position = UDim2.new(0, 10, 1, -50)
	track.Size = UDim2.new(1, -20, 0, 40)
	track.MouseButton1Click:Connect(function()
		teleportToStart(row)
	end)
end

local function renderCards()
	clear(list)
	local t = theme()
	local rows = makeRows(activeTab)
	if #rows == 0 then
		label(list, "No " .. (activeTab == "Race" and "race" or "time trial") .. " events found.", UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, 10), 12, t.Muted, true)
		selectedRow = nil
		renderDetail(nil)
		return
	end
	if not selectedRow or selectedRow.Summary.Mode ~= activeTab then
		selectedRow = rows[1]
	end
	for index, row in ipairs(rows) do
		local summary = row.Summary
		local selected = selectedRow and selectedRow.Summary.EventId == summary.EventId and selectedRow.Summary.Mode == summary.Mode
		local card = Instance.new("TextButton")
		card.Name = "Event_" .. tostring(summary.EventId)
		card.LayoutOrder = index
		card.AutoButtonColor = true
		card.Text = ""
		card.BackgroundColor3 = selected and t.Selected or t.Card
		card.BackgroundTransparency = selected and 0.02 or 0.07
		card.BorderSizePixel = 0
		card.Size = UDim2.new(1, -8, 0, touch and 84 or 94)
		card.Parent = list
		corner(card, 6)
		stroke(card, selected and t.Selected or t.Accent, 1.1, selected and 0.08 or 0.45)

		label(card, tostring(summary.DisplayName or summary.EventId), UDim2.new(1, -18, 0, 24), UDim2.fromOffset(9, 7), touch and 10 or 12, t.Text, true)
		local line2 = summary.Mode == "Race" and "OPEN RACE" or ("TT  REC " .. tostring(summary.RecommendedTier or "--"))
		label(card, line2 .. "   " .. formatMoney(summary.BaseReward), UDim2.new(1, -18, 0, 22), UDim2.fromOffset(9, 32), touch and 9 or 10, t.Accent, true)
		label(card, "Start: " .. formatDistance(row.Distance), UDim2.new(1, -18, 0, 22), UDim2.fromOffset(9, 56), touch and 9 or 10, t.Muted, false)

		card.MouseButton1Click:Connect(function()
			selectedRow = row
			renderCards()
		end)
	end
	renderDetail(selectedRow)
end

local function renderTabs()
	clear(tabRail)
	local t = theme()
	local timeTrial = button(tabRail, "TimeTrialsTab", "TIME TRIALS", activeTab == "TimeTrial" and t.Selected or t.Card)
	timeTrial.Size = UDim2.new(0.5, -5, 1, 0)
	timeTrial.Position = UDim2.fromOffset(0, 0)
	timeTrial.MouseButton1Click:Connect(function()
		activeTab = "TimeTrial"
		selectedRow = nil
		renderTabs()
		renderCards()
	end)
	local race = button(tabRail, "RacesTab", "RACES", activeTab == "Race" and t.Selected or t.Card)
	race.Size = UDim2.new(0.5, -5, 1, 0)
	race.Position = UDim2.new(0.5, 5, 0, 0)
	race.MouseButton1Click:Connect(function()
		activeTab = "Race"
		selectedRow = nil
		renderTabs()
		renderCards()
	end)
end

setOpen = function(open)
	overlay.Visible = open
	root.Visible = open
	if open then
		subtitle.Text = "Browse events, teleport near the start, then enter the zone to open the race entry menu."
		renderTabs()
		renderCards()
	end
end

local function ensureGui()
	if gui and gui.Parent then return end
	local t = theme()
	gui = Instance.new("ScreenGui")
	gui.Name = "NTR_RaceBrowser"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 77
	gui.Enabled = true
	gui.Parent = playerGui

	overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.38
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.Parent = gui

	root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = touch and UDim2.new(0.92, 0, 0.72, 0) or UDim2.fromOffset(760, 500)
	root.BackgroundColor3 = t.Panel
	root.BackgroundTransparency = t.PanelTransparency
	root.BorderSizePixel = 0
	root.Visible = false
	root.Parent = overlay
	corner(root, 8)
	stroke(root, t.Selected, 1.6, 0.12)

	title = label(root, "RACES", UDim2.new(1, -94, 0, 30), UDim2.fromOffset(16, 12), touch and 15 or 18, t.Text, true)
	subtitle = label(root, "", UDim2.new(1, -32, 0, 40), UDim2.fromOffset(16, 42), touch and 9 or 11, t.Muted, false)

	closeButton = button(root, "Close", "EXIT", t.Exit)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 12)
	closeButton.Size = UDim2.fromOffset(72, 30)
	closeButton.MouseButton1Click:Connect(function()
		setOpen(false)
	end)

	tabRail = Instance.new("Frame")
	tabRail.Name = "Tabs"
	tabRail.BackgroundTransparency = 1
	tabRail.Position = UDim2.fromOffset(16, 88)
	tabRail.Size = UDim2.new(0.39, -24, 0, 36)
	tabRail.Parent = root

	list = Instance.new("ScrollingFrame")
	list.Name = "EventList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = touch and 3 or 5
	list.Position = UDim2.fromOffset(16, 134)
	list.Size = UDim2.new(0.39, -24, 1, -150)
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	detail = Instance.new("Frame")
	detail.Name = "EventDetail"
	detail.BackgroundColor3 = t.Card
	detail.BackgroundTransparency = 0.12
	detail.BorderSizePixel = 0
	detail.Position = UDim2.new(0.39, 8, 0, 88)
	detail.Size = UDim2.new(0.61, -24, 1, -104)
	detail.Parent = root
	corner(detail, 7)
	stroke(detail, t.Accent, 1, 0.42)
end

openEvent.Event:Connect(function()
	ensureGui()
	setOpen(not (root and root.Visible))
end)

ensureGui()
print("[NTR Racing Phase 7] Race browser client active.")
