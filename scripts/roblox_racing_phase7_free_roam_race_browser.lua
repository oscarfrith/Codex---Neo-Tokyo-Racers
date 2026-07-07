-- Neo Tokyo Racers - Racing Phase 7 Free-Roam Race Browser
-- Run in Roblox Studio Command Bar in Edit mode.
--
-- Installs an isolated RaceBrowserClient_Active and patches only the existing
-- free-roam Race tile click handler to fire a BindableEvent. This phase does
-- not edit Config.Racing.Rewards or any route-guide attributes.

local MODE = "INSTALL" -- INSTALL or SMOKE

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing.ClassName ~= className then
			error(("Existing %s is %s, expected %s"):format(existing:GetFullName(), existing.ClassName, className))
		end
		return existing
	end
	local item = Instance.new(className)
	item.Name = name
	item.Parent = parent
	return item
end

local function setValue(parent, className, name, value)
	local item = child(parent, className, name)
	item.Value = value
	return item
end

local function path(root, names)
	local current = root
	for _, name in ipairs(names) do
		current = current:WaitForChild(name)
	end
	return current
end

local function replaceOnce(source, old, new, label)
	local first = string.find(source, old, 1, true)
	if not first then
		error("[NTR Racing Phase 7] Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another repair.")
	end
	local second = string.find(source, old, first + #old, true)
	if second then
		error("[NTR Racing Phase 7] Source anchor is not unique: " .. label)
	end
	return string.sub(source, 1, first - 1) .. new .. string.sub(source, first + #old)
end

local function controllerSource()
	return [====[
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
local waypoint = nil
local waypointBillboard = nil
local waypointTarget = nil
local waypointTicker = 0

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

local function clearWaypoint()
	if waypoint then waypoint:Destroy() end
	waypoint = nil
	waypointBillboard = nil
	waypointTarget = nil
end

local function setWaypoint(part, summary)
	clearWaypoint()
	if not part then
		subtitle.Text = "No start zone was found for this event."
		return
	end
	local rootFolder = Workspace:FindFirstChild("_NTR_ClientOnly")
	if not rootFolder then
		rootFolder = Instance.new("Folder")
		rootFolder.Name = "_NTR_ClientOnly"
		rootFolder.Parent = Workspace
	end

	local marker = Instance.new("Part")
	marker.Name = "RaceBrowserWaypoint"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Transparency = 1
	marker.Size = Vector3.new(1, 1, 1)
	marker.CFrame = part.CFrame + Vector3.new(0, readNumber(browserConfig, "WaypointHeight", 14), 0)
	marker.Parent = rootFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RaceBrowserWaypointGui"
	billboard.Adornee = marker
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(readNumber(browserConfig, "WaypointWidth", 220), readNumber(browserConfig, "WaypointHeightPixels", 58))
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.Parent = marker

	local t = theme()
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	pill.BackgroundTransparency = readNumber(browserConfig, "WaypointBackgroundTransparency", 0.28)
	pill.BorderSizePixel = 0
	pill.Size = UDim2.fromScale(1, 1)
	pill.Parent = billboard
	corner(pill, 8)
	stroke(pill, t.Selected, 1.5, 0.15)

	local text = label(pill, tostring(summary.DisplayName or "RACE START") .. "\nENTER ZONE + PRESS E", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), touch and 10 or 12, t.Accent, true)
	text.Name = "Text"
	text.TextXAlignment = Enum.TextXAlignment.Center

	waypoint = marker
	waypointBillboard = billboard
	waypointTarget = part
	subtitle.Text = "Waypoint set. Drive to the start zone and press E / tap the prompt to open the entry menu."
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

	local track = button(detail, "TrackStart", "TRACK START", t.Buy)
	track.Position = UDim2.new(0, 10, 1, -50)
	track.Size = UDim2.new(0.55, -15, 0, 40)
	track.MouseButton1Click:Connect(function()
		setWaypoint(row.StartZone, summary)
	end)

	local clearButton = button(detail, "ClearWaypoint", "CLEAR", t.Back)
	clearButton.Position = UDim2.new(0.55, 5, 1, -50)
	clearButton.Size = UDim2.new(0.45, -15, 0, 40)
	clearButton.MouseButton1Click:Connect(function()
		clearWaypoint()
		subtitle.Text = "Waypoint cleared."
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

local function setOpen(open)
	overlay.Visible = open
	root.Visible = open
	if open then
		subtitle.Text = "Browse events, set a waypoint, then enter the start zone to open the race entry menu."
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

RunService.Heartbeat:Connect(function(dt)
	waypointTicker += dt
	if waypointTicker < 0.25 then return end
	waypointTicker = 0
	if waypoint and waypoint.Parent and waypointTarget and waypointTarget.Parent then
		waypoint.CFrame = waypointTarget.CFrame + Vector3.new(0, readNumber(browserConfig, "WaypointHeight", 14), 0)
		local pill = waypointBillboard and waypointBillboard:FindFirstChild("Pill")
		local text = pill and pill:FindFirstChild("Text")
		if text and text:IsA("TextLabel") then
			text.Text = "RACE START\n" .. formatDistance(distanceTo(waypointTarget))
		end
	end
end)

ensureGui()
print("[NTR Racing Phase 7] Race browser client active.")
]====]
end

local function install()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = kit:WaitForChild("Config")
	local uiConfig = child(config, "Folder", "UI")
	local browserConfig = child(uiConfig, "Folder", "RaceBrowser")
	setValue(browserConfig, "NumberValue", "WaypointHeight", 14)
	setValue(browserConfig, "NumberValue", "WaypointWidth", 220)
	setValue(browserConfig, "NumberValue", "WaypointHeightPixels", 58)
	setValue(browserConfig, "NumberValue", "WaypointBackgroundTransparency", 0.28)

	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local clientRoot = child(playerScripts, "Folder", "NeoTokyoRacersClient")
	local controllers = child(clientRoot, "Folder", "Controllers")
	local ui = child(controllers, "Folder", "UI")
	child(ui, "BindableEvent", "OpenRaceBrowser")
	local racing = child(controllers, "Folder", "Racing")

	local browser = child(racing, "LocalScript", "RaceBrowserClient_Active")
	browser.Source = controllerSource()
	browser.Disabled = false

	local nav = ui:FindFirstChild("FreeRoamNavController_Active")
	if not (nav and nav:IsA("LocalScript")) then
		error("[NTR Racing Phase 7] FreeRoamNavController_Active was not found under Controllers.UI")
	end
	local old = [[	makeStackButton(actionGrid, "RaceButton", "RaceIcon", "RACE", function()
		showActionPanel("Race")
	end)]]
	local new = [[	makeStackButton(actionGrid, "RaceButton", "RaceIcon", "RACE", function()
		local event = script.Parent:FindFirstChild("OpenRaceBrowser")
		if event and event:IsA("BindableEvent") then
			event:Fire()
		else
			showActionPanel("Race")
		end
	end)]]
	if not string.find(nav.Source, "OpenRaceBrowser", 1, true) then
		nav.Source = replaceOnce(nav.Source, old, new, "free-roam Race tile click handler")
	end

	print("[NTR Racing Phase 7] Installed RaceBrowserClient_Active and Race tile bridge.")
	print("[NTR Racing Phase 7] Reward config untouched; this phase only reads event BaseReward for display.")
end

local function smoke()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local rewards = kit:WaitForChild("Config"):WaitForChild("Racing"):FindFirstChild("Rewards")
	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local controllers = playerScripts:WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers")
	assert(controllers:WaitForChild("UI"):FindFirstChild("OpenRaceBrowser"), "OpenRaceBrowser BindableEvent missing")
	assert(controllers:WaitForChild("Racing"):FindFirstChild("RaceBrowserClient_Active"), "RaceBrowserClient_Active missing")
	local nav = controllers.UI:FindFirstChild("FreeRoamNavController_Active")
	assert(nav and string.find(nav.Source, "OpenRaceBrowser", 1, true), "FreeRoamNav race bridge missing")
	assert(rewards == nil or (rewards:FindFirstChild("TimeTrial") and rewards:FindFirstChild("Race")), "Rewards folder shape looks unexpected")
	print("[NTR Racing Phase 7] Smoke passed. Race browser is installed and reward config shape was not rewritten.")
end

if MODE == "INSTALL" then
	install()
	smoke()
elseif MODE == "SMOKE" then
	smoke()
else
	error("Unknown MODE: " .. tostring(MODE))
end
