-- Canonical feature implementation (docs/architecture/map-markers-contract.md, owner Agent F).
-- GTA-style full-screen map. Started by the ClientBase entry "FullMapUI"; the free-roam HUD owners
-- open it from the minimap (FullMapUI.Open). Owns: the FullMap ScreenGui, the Player attribute
-- FullMapOpen (HUD owners hide while it is true), the player waypoint (RouteGuide source
-- "Waypoint" + MapMarkers "Waypoint"), M / Back toggles and, while open, RouteGuide.Update.
-- No remotes, saved data or camera writes. Pure maths lives in MapMath.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local FullMap = {}
local startState
local api -- set once started

function FullMap.Open() return api ~= nil and api.open() or false end
function FullMap.Close() if api then api.close() end end
function FullMap.Toggle() return api ~= nil and api.toggle() or false end
function FullMap.IsOpen() return api ~= nil and api.isOpen() or false end

function FullMap.start()
if startState then assert(startState == "ready", "Client startup already attempted: " .. tostring(startState)); return end
startState = "starting"
local ok, message = xpcall(function()
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local modules = ReplicatedStorage:WaitForChild("Modules")
local uiModules = modules:WaitForChild("Game"):WaitForChild("UI")
local UI = require(uiModules:WaitForChild("RacingUIComponents"))
local RouteGuide = require(uiModules:WaitForChild("RouteGuide"))
local MapMarkers = require(uiModules:WaitForChild("MapMarkers"))
local MapIconLayer = require(uiModules:WaitForChild("MapIconLayer"))
local MapMath = require(uiModules:WaitForChild("MapMath"))
local PlayerMarkers = require(uiModules:WaitForChild("FreeRoamMapPlayerMarkers"))
local InputGate = require(modules.Game:WaitForChild("Vehicles"):WaitForChild("GameplayInputGate"))
local uiConfig = ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI")
local hudConfig = uiConfig:WaitForChild("DesktopFreeRoamHud")
local layoutConfig = hudConfig:WaitForChild("Layout")
local defaultsConfig = hudConfig:WaitForChild("Defaults")
local assetConfig = hudConfig:WaitForChild("Assets")
local markerConfig = uiConfig:WaitForChild("FreeRoamMapPlayerMarkers")
local config = uiConfig:WaitForChild("FullMap", 10) -- optional: every tunable has a default
local uiFolder = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local FONT = Enum.Font.Michroma
local theme = { Font = FONT }
for name, fallback in pairs({
	Panel = Color3.fromRGB(15, 19, 24), PanelDeep = Color3.fromRGB(9, 12, 16), PanelSoft = Color3.fromRGB(24, 29, 36),
	PanelBlue = Color3.fromRGB(8, 42, 84), Outline = Color3.fromRGB(244, 46, 151), OutlineSoft = Color3.fromRGB(214, 74, 175),
	Telemetry = Color3.fromRGB(43, 225, 218), ElectricBlue = Color3.fromRGB(25, 116, 255), HighSpeed = Color3.fromRGB(246, 83, 159),
	Danger = Color3.fromRGB(196, 57, 75), Text = Color3.fromRGB(246, 248, 252), Muted = Color3.fromRGB(163, 171, 184), Disabled = Color3.fromRGB(81, 88, 99),
}) do
	local value = UI.Colour(name, fallback)
	theme[name] = typeof(value) == "Color3" and value or fallback
end

local function readValue(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA("ValueBase") then return item.Value end
	local attribute = folder and folder:GetAttribute(name)
	if attribute ~= nil then return attribute end
	return fallback
end
local function cfg(name, fallback, minimum, maximum)
	local value = MapMath.Finite(config and config:GetAttribute(name), fallback)
	return math.clamp(value, minimum or -math.huge, maximum or math.huge)
end
local function flag(name, fallback)
	local value = config and config:GetAttribute(name)
	if type(value) == "boolean" then return value end
	return fallback
end
local function asset(name)
	local text = tostring(readValue(assetConfig, name, "") or "")
	if text == "" then return "" end
	if tonumber(text) then return "rbxassetid://" .. text end
	return text
end
local function new(className, props, parent)
	local item = Instance.new(className)
	for key, value in pairs(props or {}) do item[key] = value end
	item.Parent = parent
	return item
end
local function toast(text)
	local notify = uiFolder:FindFirstChild("ShowTopNotification")
	if notify and notify:IsA("BindableEvent") then notify:Fire(tostring(text), 2.2) end
end

local function calibration()
	return MapMath.Calibration({
		MapPixels = readValue(layoutConfig, "MapPixels", 2048),
		MapCalibrationPixels = readValue(layoutConfig, "MapCalibrationPixels", 207),
		MapCalibrationStuds = readValue(layoutConfig, "MapCalibrationStuds", 2850),
		MapWorldCenterX = readValue(layoutConfig, "MapWorldCenterX", 0),
		MapWorldCenterZ = readValue(layoutConfig, "MapWorldCenterZ", 0),
		MapCoordinateRotationDegrees = readValue(layoutConfig, "MapCoordinateRotationDegrees", 90),
		MapFlipX = readValue(defaultsConfig, "MapFlipX", false) == true,
		MapFlipZ = readValue(defaultsConfig, "MapFlipZ", false) == true,
	})
end

-- GUI ----------------------------------------------------------------------------------------
local old = playerGui:FindFirstChild("FullMap")
if old then old:Destroy() end
local gui = new("ScreenGui", { Name = "FullMap", IgnoreGuiInset = true, ResetOnSpawn = false, Enabled = false,
	DisplayOrder = math.floor(cfg("DisplayOrder", 90, 1, 1000)), ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local backdrop = new("TextButton", { Name = "Backdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, gui)
local panel = UI.Panel(gui, { Name = "Panel", Color = theme.PanelDeep, Transparency = 0.04, StrokeColor = theme.Outline })
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Active = true -- presses on the panel never reach the backdrop
panel.ZIndex = 2
local openScale = new("UIScale", { Name = "OpenScale", Scale = 1 }, panel)

local title = UI.Label(panel, { Name = "Title", Text = "MAP", Role = "Heading", Color = theme.Text })
local district = UI.Label(panel, { Name = "District", Text = "", Role = "Body", Color = theme.Muted })
local legendToggle = UI.Button(panel, { Name = "LegendToggle", Text = "LEGEND", Color = theme.Panel, StrokeColor = theme.OutlineSoft })
local closeButton = UI.Button(panel, { Name = "Close", Text = "X", Color = theme.Panel, StrokeColor = theme.Danger })

local mapView = new("Frame", { Name = "MapView", BackgroundColor3 = theme.PanelSoft, BackgroundTransparency = 0, BorderSizePixel = 0,
	ClipsDescendants = true, Active = true, ZIndex = 3 }, panel)
UI.Corner(mapView, 6)
local canvas = new("Frame", { Name = "MapCanvas", BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3 }, mapView)
local completeTiles = true
for index, tileName in ipairs({ "MapTileTopLeft", "MapTileTopRight", "MapTileBottomLeft", "MapTileBottomRight" }) do
	local image = asset(tileName)
	if image == "" then completeTiles = false end
	new("ImageLabel", { Name = tileName, BackgroundTransparency = 1, BorderSizePixel = 0, Image = image, ScaleType = Enum.ScaleType.Stretch,
		Position = ({ UDim2.fromScale(0, 0), UDim2.fromScale(0.5, 0), UDim2.fromScale(0, 0.5), UDim2.fromScale(0.5, 0.5) })[index],
		Size = UDim2.fromScale(0.5, 0.5), ZIndex = 3 }, canvas)
end
local missing = UI.Label(mapView, { Name = "MapMissing", Text = "ADD 4 MAP TILE IDS", Color = theme.Muted, XAlignment = Enum.TextXAlignment.Center })
missing.Visible = not completeTiles
missing.ZIndex = 4
local routeRenderer = RouteGuide.newMapRenderer({
	Canvas = canvas, Container = mapView, ZIndex = 4, ChipZIndex = 12, Font = FONT,
	Colours = { Line = theme.Telemetry, Activity = theme.HighSpeed, Outline = theme.PanelDeep, ChipBackground = theme.PanelDeep, ChipText = theme.Text },
})
local playersHost = new("Frame", { Name = "PlayersHost", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 7 }, mapView)
local iconLayer = MapIconLayer.new({ Container = mapView, Surface = "FullMap", ZIndex = 8, Mobile = isMobile, Theme = theme, Font = FONT })
local arrowImage = asset("MapPlayerIcon")
local playerArrow
if arrowImage ~= "" then
	playerArrow = new("ImageLabel", { Name = "PlayerArrow", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0,
		Image = arrowImage, ImageColor3 = theme.Text, ScaleType = Enum.ScaleType.Fit, ZIndex = 10 }, mapView)
else
	playerArrow = UI.Label(mapView, { Name = "PlayerArrow", Text = "▲", Color = theme.Telemetry, XAlignment = Enum.TextXAlignment.Center })
	playerArrow.AnchorPoint = Vector2.new(0.5, 0.5)
	playerArrow.ZIndex = 10
end
local crosshair = new("Frame", { Name = "Crosshair", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 11 }, mapView)
UI.Corner(crosshair, 999)
UI.Stroke(crosshair, theme.Telemetry, 2, 0.05)
local controls = new("Frame", { Name = "Controls", AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 12 }, mapView)
local zoomIn = UI.Button(controls, { Name = "ZoomIn", Text = "+", Color = theme.Panel, StrokeColor = theme.OutlineSoft })
local zoomOut = UI.Button(controls, { Name = "ZoomOut", Text = "-", Color = theme.Panel, StrokeColor = theme.OutlineSoft })
local centreButton = UI.Button(controls, { Name = "Centre", Text = "ME", Color = theme.PanelBlue, StrokeColor = theme.Telemetry })
local hint = UI.Label(mapView, { Name = "Hint", Text = "", Color = theme.Muted, Wrapped = true })
hint.ZIndex = 12
hint.AnchorPoint = Vector2.new(0, 1)
hint.BackgroundColor3 = theme.PanelDeep
hint.BackgroundTransparency = 0.25

local legend = UI.Panel(panel, { Name = "Legend", Color = theme.Panel, Transparency = 0.1, StrokeColor = theme.OutlineSoft, NoGlow = true })
legend.ZIndex = 3
local legendTitle = UI.Label(legend, { Name = "Title", Text = "LEGEND", Role = "Heading", Color = theme.Text })
local legendList = new("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
	ScrollBarImageColor3 = theme.Telemetry, ZIndex = 4 }, legend)
local legendLayout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, legendList)
local clearButton = UI.Button(legend, { Name = "ClearWaypoint", Text = "CLEAR WAYPOINT", Color = theme.Panel, StrokeColor = theme.Danger })

-- State ----------------------------------------------------------------------------------------
local isOpen = false
local cal = calibration()
local function readBounds()
	return MapMath.BoundsToUnits(cal, cfg("PanMinX", -2750), cfg("PanMaxX", 5100), cfg("PanMinZ", -6650), cfg("PanMaxZ", 3050))
end
local bounds = readBounds()
local pan = Vector2.new(0.5, 0.5)
local panTarget
local visibleStuds = cfg("OpenVisibleStuds", 3600, 100, 100000)
local rememberedStuds
local view = { W = 1, H = 1, Short = 1, Centre = Vector2.new(0.5, 0.5) }
local sizes = {}
local legendOpen = true
local legendDirty = true
local legendSignature
local waypointKey
local inputToken
local playerMarkers
local closeGeneration = 0
local padStick = Vector2.zero
local usingGamepad = false
local pointers, pinch, multiTouch = {}, nil, false
local presentationOwners = {}

local function side()
	return MapMath.CanvasSide(cal.FullStuds, view.Short, visibleStuds)
end
local function studLimits()
	local minimum = cfg("MinVisibleStuds", 500, 50, 100000)
	local maximum = math.max(minimum, cfg("MaxVisibleStuds", 9000, 100, 200000))
	if bounds then maximum = math.max(minimum, math.min(maximum, MapMath.MaxStudsForBounds(cal, bounds, view.W, view.H))) end
	return minimum, maximum
end
local function clampView()
	local minimum, maximum = studLimits()
	visibleStuds = MapMath.ClampVisibleStuds(visibleStuds, minimum, maximum)
	pan = MapMath.ClampPan(pan, side(), view.W, view.H, bounds)
	if panTarget then panTarget = MapMath.ClampPan(panTarget, side(), view.W, view.H, bounds) end
end
local function zoomTo(studs, anchor)
	local minimum, maximum = studLimits()
	studs = MapMath.ClampVisibleStuds(studs, minimum, maximum)
	local before = side()
	visibleStuds = studs
	local after = side()
	anchor = anchor or view.Centre
	pan = MapMath.ZoomAbout(pan, before, after, anchor, view.Centre)
	if anchor ~= view.Centre then panTarget = nil end
	clampView()
end
local function zoomStep(steps, anchor)
	zoomTo(visibleStuds / (cfg("ZoomStep", 1.25, 1.01, 4) ^ steps), anchor)
end

local function subject()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local current = seat
	while current and current ~= Workspace do
		if current:IsA("Model") and tonumber(current:GetAttribute("OwnerUserId")) == player.UserId then
			local root = current.PrimaryPart or current:FindFirstChild("CockpitRoot_DoNotRename", true)
			if root and root:IsA("BasePart") then return root, current end
		end
		current = current.Parent
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil, nil
end
local function playerUnit()
	local root = subject()
	if not root then return nil end
	local u, v = MapMath.WorldToUnit(cal, root.Position.X, root.Position.Z)
	return Vector2.new(u, v)
end

-- Waypoint (the only player destination; a new "Player" route replaces it and vice versa) --------
local rebuildLegend
local function setWaypoint(position, labelText, key)
	RouteGuide.Clear("Player")
	RouteGuide.SetDestination("Waypoint", position, { Label = labelText or "WAYPOINT", Priority = 5 })
	MapMarkers.Set("Waypoint", { Position = position, Icon = "Waypoint", Label = labelText or "WAYPOINT", Kind = "Waypoint", Priority = 50, EdgeClamp = true })
	waypointKey = key
	legendDirty = true
end
local function clearWaypoint()
	RouteGuide.Clear("Waypoint")
	MapMarkers.Remove("Waypoint")
	waypointKey = nil
	legendDirty = true
end
RouteGuide.Changed:Connect(function(active)
	if active == nil then
		if MapMarkers.Get("Waypoint") then MapMarkers.Remove("Waypoint") end
		waypointKey = nil
		legendDirty = true
	elseif active.Source == "Player" and MapMarkers.Get("Waypoint") then
		RouteGuide.Clear("Waypoint")
		MapMarkers.Remove("Waypoint")
		waypointKey = nil
		legendDirty = true
	end
end)
RouteGuide.Arrived:Connect(function(destination)
	if destination and destination.Source == "Waypoint" then
		MapMarkers.Remove("Waypoint")
		waypointKey = nil
		legendDirty = true
	end
end)

-- Legend -------------------------------------------------------------------------------------
local KEY_LABELS = {
	Dealership = "DEALERSHIP", Garage = "MY GARAGE", Customisation = "CUSTOMISATION", Race = "RACE", TimeTrial = "TIME TRIAL",
	TaxiFare = "TAXI FARE", CourierPickup = "COURIER PICKUP", CourierDrop = "COURIER DROP-OFF", TaxiDrop = "TAXI DROP-OFF",
	Duel = "STREET DUEL", Job = "JOB",
}
local KEY_ORDER = { "Dealership", "Garage", "Customisation", "Race", "TimeTrial", "TaxiFare", "CourierPickup", "CourierDrop", "TaxiDrop", "Duel", "Job" }

local function places()
	local list, taken = {}, {}
	for id, marker in pairs(MapMarkers.All()) do
		if marker.Static and (marker.Kind == "Place" or marker.Kind == "Race") then
			table.insert(list, { Key = id, Label = marker.Label, Icon = marker.Icon, Kind = marker.Kind, Position = marker.Position, Order = marker.Order or 100 })
			if marker.DestinationId then taken[marker.DestinationId] = true end
			if marker.RouteId then taken[marker.RouteId] = true end
		end
	end
	-- Configured route destinations without a map POI still appear (moved here from the old ROUTE GUIDE modal).
	for _, destination in ipairs(RouteGuide.Destinations()) do
		local duplicate = taken[destination.Id] or (destination.RouteId and taken[destination.RouteId])
		if not duplicate then
			for _, item in ipairs(list) do
				if (Vector2.new(item.Position.X, item.Position.Z) - Vector2.new(destination.Position.X, destination.Position.Z)).Magnitude < 60 then duplicate = true break end
			end
		end
		if not duplicate then
			table.insert(list, { Key = "Destination_" .. destination.Id, Label = destination.DisplayName, Icon = destination.Kind == "Race" and "Race" or "",
				Kind = destination.Kind == "Race" and "Race" or "Place", Position = destination.Position, Order = destination.Order })
		end
	end
	table.sort(list, function(a, b)
		if a.Order ~= b.Order then return a.Order < b.Order end
		return a.Label < b.Label
	end)
	return list
end

local function keyEntries()
	local entries = {
		{ Icon = "Player", Kind = "Player", Label = "YOU" },
		{ Icon = "OtherPlayer", Kind = "Player", Label = "OTHER DRIVERS" },
		{ Icon = "Waypoint", Kind = "Waypoint", Label = "WAYPOINT" },
	}
	local present = {}
	for _, marker in pairs(MapMarkers.All()) do present[marker.Icon] = marker.Kind end
	for _, icon in ipairs(KEY_ORDER) do
		if present[icon] then table.insert(entries, { Icon = icon, Kind = present[icon], Label = KEY_LABELS[icon] }) end
	end
	return entries
end

local function selectPlace(place)
	if waypointKey == place.Key then
		clearWaypoint()
		return
	end
	local position = Vector3.new(place.Position.X, cfg("WaypointY", 101, -1000, 5000), place.Position.Z)
	setWaypoint(position, string.upper(place.Label), place.Key)
	local u, v = MapMath.WorldToUnit(cal, position.X, position.Z)
	panTarget = Vector2.new(u, v)
	clampView()
end

function rebuildLegend()
	legendDirty = false
	local placeList, keyList = places(), keyEntries()
	local hasWaypoint = MapMarkers.Get("Waypoint") ~= nil
	clearButton.Active = hasWaypoint
	clearButton.TextTransparency = hasWaypoint and 0 or 0.55
	-- Rebuild only when the rows change, so a press on a row is never destroyed mid-click.
	local parts = { tostring(waypointKey) }
	for _, place in ipairs(placeList) do table.insert(parts, place.Key .. "=" .. place.Label) end
	for _, entry in ipairs(keyList) do table.insert(parts, entry.Icon) end
	local signature = table.concat(parts, "|")
	if signature == legendSignature then return end
	legendSignature = signature
	for _, child in ipairs(legendList:GetChildren()) do
		if child ~= legendLayout then child:Destroy() end
	end
	local order = 0
	local rowHeight, iconSize, textSize = sizes.Row or 44, sizes.Icon or 26, sizes.Text or 12
	local function section(text)
		order += 1
		local item = UI.Label(legendList, { Name = "Section" .. order, Text = text, Role = "Heading", Color = theme.Muted, TextSize = sizes.Caption or 11 })
		item.Size = UDim2.new(1, -8, 0, math.floor(rowHeight * 0.75))
		item.LayoutOrder = order
		item.ZIndex = 5
	end
	local function content(parent, entry)
		local icon = MapIconLayer.CreateIcon(parent, { Icon = entry.Icon, Kind = entry.Kind, Size = iconSize, Theme = theme, Font = FONT, ZIndex = parent.ZIndex + 1 })
		icon.Position = UDim2.new(0, 8, 0.5, -iconSize / 2)
		local text = UI.Label(parent, { Name = "Label", Text = string.upper(entry.Label), TextSize = textSize, Color = theme.Text })
		text.Position = UDim2.fromOffset(iconSize + 18, 0)
		text.Size = UDim2.new(1, -(iconSize + 24), 1, 0)
		text.ZIndex = parent.ZIndex + 1
	end
	section("DESTINATIONS")
	for _, place in ipairs(placeList) do
		order += 1
		local selected = waypointKey == place.Key
		local row = UI.Button(legendList, { Name = "Place_" .. place.Key, Text = "", Size = UDim2.new(1, -8, 0, rowHeight),
			Color = selected and theme.PanelBlue or theme.Panel, StrokeColor = selected and theme.Telemetry or theme.OutlineSoft, ZIndex = 5 })
		row.LayoutOrder = order
		content(row, place)
		row.Activated:Connect(function() selectPlace(place) end)
		order += 1
		new("Frame", { Name = "Gap" .. order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 6), LayoutOrder = order }, legendList)
	end
	section("MAP KEY")
	for _, entry in ipairs(keyList) do
		order += 1
		local row = new("Frame", { Name = "Key_" .. entry.Icon, BackgroundTransparency = 1, BorderSizePixel = 0,
			Size = UDim2.new(1, -8, 0, math.floor(rowHeight * 0.8)), LayoutOrder = order, ZIndex = 5 }, legendList)
		content(row, entry)
	end
end
MapMarkers.Changed:Connect(function()
	if isOpen then legendDirty = true end
end)

-- Layout ---------------------------------------------------------------------------------------
local function refreshHint()
	if usingGamepad then
		hint.Text = "(A) WAYPOINT   (X) CLEAR   (Y) CENTRE   LB/RB ZOOM   (B) CLOSE"
	elseif isMobile then
		hint.Text = "DRAG TO PAN   PINCH TO ZOOM   TAP TO SET OR CLEAR A WAYPOINT"
	else
		hint.Text = "DRAG TO PAN   WHEEL TO ZOOM   CLICK TO SET OR CLEAR A WAYPOINT   M / ESC TO CLOSE"
	end
	crosshair.Visible = usingGamepad and isOpen
end

local function layout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local s = isMobile and math.clamp(viewport.Y / 720, 0.55, 1) or math.clamp(math.min(viewport.X / 1920, viewport.Y / 1080), 0.72, 1.12)
	local function px(value) return math.floor(value * s + 0.5) end
	local function target(value) return isMobile and math.max(44, px(value)) or px(value) end
	local margin = isMobile and math.max(8, px(16)) or px(36)
	local pad = math.max(6, px(12))
	local panelW, panelH = viewport.X - margin * 2, viewport.Y - margin * 2
	local header = target(56)
	panel.Size = UDim2.fromOffset(panelW, panelH)
	title.Position = UDim2.fromOffset(pad + px(6), 0)
	title.Size = UDim2.fromOffset(px(90), header)
	title.TextSize = px(24)
	district.Position = UDim2.fromOffset(pad + px(100), 0)
	district.Size = UDim2.fromOffset(math.max(0, panelW * 0.4), header)
	district.TextSize = px(13)
	district.Text = string.upper(tostring(config and config:GetAttribute("DistrictName") or ""))
	local buttonH = target(40)
	closeButton.Size = UDim2.fromOffset(math.max(buttonH, target(44)), buttonH)
	closeButton.Position = UDim2.new(1, -pad - closeButton.Size.X.Offset, 0, math.floor((header - buttonH) / 2))
	closeButton.TextSize = px(15)
	legendToggle.Size = UDim2.fromOffset(target(120), buttonH)
	legendToggle.Position = UDim2.new(1, -pad * 2 - closeButton.Size.X.Offset - legendToggle.Size.X.Offset, 0, math.floor((header - buttonH) / 2))
	legendToggle.TextSize = px(12)

	local legendW = legendOpen and math.clamp(target(isMobile and cfg("MobileLegendWidth", 300, 150, 600) or cfg("LegendWidth", 360, 200, 700)), 150, math.max(150, math.floor(panelW * 0.42))) or 0
	legend.Visible = legendOpen
	local mapW = panelW - pad * 2 - (legendOpen and legendW + pad or 0)
	local mapH = panelH - header - pad
	mapView.Position = UDim2.fromOffset(pad, header)
	mapView.Size = UDim2.fromOffset(mapW, mapH)
	legend.Position = UDim2.fromOffset(panelW - pad - legendW, header)
	legend.Size = UDim2.fromOffset(legendW, mapH)
	legendTitle.Position = UDim2.fromOffset(pad, 0)
	legendTitle.Size = UDim2.new(1, -pad * 2, 0, target(40))
	legendTitle.TextSize = px(16)
	local clearH = target(44)
	clearButton.Size = UDim2.new(1, -pad * 2, 0, clearH)
	clearButton.Position = UDim2.new(0, pad, 1, -pad - clearH)
	clearButton.TextSize = px(12)
	legendList.Position = UDim2.fromOffset(pad, target(40))
	legendList.Size = UDim2.new(1, -pad, 1, -(target(40) + clearH + pad * 2))

	sizes = { Row = target(44), Icon = target(26), Text = px(12), Caption = px(11) }
	local controlSize = target(44)
	controls.Size = UDim2.fromOffset(controlSize, controlSize * 3 + pad * 2)
	controls.Position = UDim2.new(1, -pad, 1, -pad)
	for index, item in ipairs({ zoomIn, zoomOut, centreButton }) do
		item.Size = UDim2.fromOffset(controlSize, controlSize)
		item.Position = UDim2.fromOffset(0, (index - 1) * (controlSize + pad))
		item.TextSize = px(index == 3 and 12 or 20)
	end
	hint.Position = UDim2.new(0, pad, 1, -pad)
	hint.Size = UDim2.new(1, -(controlSize + pad * 3), 0, target(28))
	hint.TextSize = px(11)
	missing.Size = UDim2.new(1, 0, 0, px(32))
	missing.Position = UDim2.new(0, 0, 0.5, -px(16))
	missing.TextSize = px(12)
	local arrowSize = target(isMobile and 30 or 28)
	playerArrow.Size = UDim2.fromOffset(arrowSize, arrowSize)
	if playerArrow:IsA("TextLabel") then playerArrow.TextSize = arrowSize end
	crosshair.Size = UDim2.fromOffset(px(26), px(26))

	view.W, view.H = math.max(1, mapW), math.max(1, mapH)
	view.Short = math.max(1, math.min(view.W, view.H))
	view.Centre = Vector2.new(view.W * 0.5, view.H * 0.5)
	local host = math.max(view.W, view.H)
	playersHost.Size = UDim2.fromOffset(host, host)
	bounds = readBounds()
	clampView()
	legendDirty = true
	legendSignature = nil -- sizes changed: force a rebuild
	refreshHint()
end

-- Open / close ---------------------------------------------------------------------------------
local BLOCKING = { "GarageSessionActive", "OwnedGarageInside", "RaceSessionActive", "RaceQueueActive", "DrivingControlsOpen",
	"FirstDrivePresentationPending", "MobileMajorMenuOpen", "MobileFreeRoamCarMenuOpen" }
local function blocked()
	if not flag("Enabled", true) then return true end
	for _, name in ipairs(BLOCKING) do
		if player:GetAttribute(name) == true then return true end
	end
	if playerGui:GetAttribute("OwnedGarageManagementOpen") == true then return true end
	if next(presentationOwners) ~= nil then return true end
	local _, vehicle = subject()
	if vehicle and (vehicle:GetAttribute("RaceParticipant") == true or vehicle:GetAttribute("RaceRunId") ~= nil) then return true end
	return false
end

-- Keyboard/controller opens need a showing minimap (the same place a click would open it from).
local function minimapShowing()
	for _, name in ipairs({ "DesktopFreeRoamHud", "MobileFreeRoamHud_Phase1" }) do
		local hud = playerGui:FindFirstChild(name)
		local minimap = hud and hud.Enabled and hud:FindFirstChild("Minimap", true)
		if minimap and minimap:IsA("GuiObject") then
			local current, shown = minimap, true
			while current and current ~= hud do
				if current:IsA("GuiObject") and not current.Visible then shown = false break end
				current = current.Parent
			end
			if shown then return true end
		end
	end
	return false
end

local renderStep, padAction
local function close()
	if not isOpen then return end
	isOpen = false
	closeGeneration += 1
	local generation = closeGeneration
	RunService:UnbindFromRenderStep("FullMapUI")
	ContextActionService:UnbindAction("FullMapPad")
	table.clear(pointers)
	pinch, multiTouch, padStick = nil, false, Vector2.zero
	if flag("RememberZoom", true) then rememberedStuds = visibleStuds end
	if playerMarkers then playerMarkers:Destroy(); playerMarkers = nil end
	routeRenderer:SetVisible(false)
	iconLayer:SetVisible(false)
	crosshair.Visible = false
	if inputToken then InputGate.Release(inputToken, true); inputToken = nil end
	player:SetAttribute("FullMapOpen", false)
	local seconds = cfg("CloseTweenSeconds", 0.12, 0, 1)
	TweenService:Create(backdrop, TweenInfo.new(seconds), { BackgroundTransparency = 1 }):Play()
	local shrink = TweenService:Create(openScale, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.96 })
	shrink.Completed:Once(function()
		if generation == closeGeneration and not isOpen then gui.Enabled = false end
	end)
	shrink:Play()
	if seconds <= 0 then gui.Enabled = false end
end

local function open()
	if isOpen then return true end
	if blocked() then return false end
	isOpen = true
	closeGeneration += 1
	cal = calibration()
	visibleStuds = (flag("RememberZoom", true) and rememberedStuds) or cfg("OpenVisibleStuds", 3600, 100, 100000)
	local camera = Workspace.CurrentCamera
	legendOpen = flag("LegendOpen", true) and not (isMobile and camera and camera.ViewportSize.X < cfg("MobileLegendMinViewport", 760, 0, 5000))
	layout()
	pan = playerUnit() or Vector2.new(0.5, 0.5)
	panTarget = nil
	clampView()
	player:SetAttribute("FullMapOpen", true)
	if flag("LockGameplayInput", true) and not inputToken then inputToken = InputGate.Acquire("FullMap", "V1") end
	if markerConfig:IsA("Folder") then
		playerMarkers = PlayerMarkers.new({ Container = playersHost, Config = markerConfig, ZIndex = 7 })
	end
	gui.Enabled = true
	openScale.Scale = 0.96
	local seconds = cfg("OpenTweenSeconds", 0.18, 0, 1)
	TweenService:Create(backdrop, TweenInfo.new(seconds), { BackgroundTransparency = cfg("BackdropTransparency", 0.35, 0, 1) }):Play()
	TweenService:Create(openScale, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	ContextActionService:BindActionAtPriority("FullMapPad", padAction, false, Enum.ContextActionPriority.High.Value + 50,
		Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY,
		Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.Thumbstick1)
	RunService:BindToRenderStep("FullMapUI", Enum.RenderPriority.Last.Value + 10, renderStep)
	rebuildLegend()
	refreshHint()
	return true
end

local function toggle()
	if isOpen then close() return false end
	if not minimapShowing() then return false end
	return open()
end

-- Pointer input --------------------------------------------------------------------------------
local function toView(position)
	local scale = math.max(0.01, openScale.Scale)
	return (Vector2.new(position.X, position.Y) - mapView.AbsolutePosition) / scale
end
local function overControls(point)
	local scale = math.max(0.01, openScale.Scale)
	local absolute = mapView.AbsolutePosition + point * scale
	for _, item in ipairs({ zoomIn, zoomOut, centreButton }) do
		local low, size = item.AbsolutePosition, item.AbsoluteSize
		if absolute.X >= low.X and absolute.Y >= low.Y and absolute.X <= low.X + size.X and absolute.Y <= low.Y + size.Y then return true end
	end
	return false
end

local function tap(point)
	if point.X < 0 or point.Y < 0 or point.X > view.W or point.Y > view.H then return end
	local radius = cfg(isMobile and "TouchTapRadiusPixels" or "TapRadiusPixels", isMobile and 30 or 22, 4, 120)
	local id = iconLayer:HitTest(point.X, point.Y, radius)
	local marker = id and MapMarkers.Get(id)
	if id == "Waypoint" then
		clearWaypoint()
		return
	end
	local y = cfg("WaypointY", 101, -1000, 5000)
	if marker and (marker.Kind == "Place" or marker.Kind == "Race" or marker.Kind == "Job") then
		setWaypoint(Vector3.new(marker.Position.X, y, marker.Position.Z), string.upper(marker.Label), marker.Static and id or nil)
		return
	end
	local unit = MapMath.ScreenToUnit(pan, point, view.Centre, side())
	local x, z = MapMath.UnitToWorld(cal, unit.X, unit.Y)
	setWaypoint(Vector3.new(x, y, z), "WAYPOINT", nil)
end

local function pointerCount()
	local count = 0
	for _ in pairs(pointers) do count += 1 end
	return count
end
local function beginPinch()
	local a, b
	for _, pointer in pairs(pointers) do
		if not a then a = pointer elseif not b then b = pointer end
	end
	if not (a and b) then pinch = nil return end
	local mid = (a.Last + b.Last) * 0.5
	pinch = { A = a, B = b, Distance = math.max(1, (a.Last - b.Last).Magnitude), Studs = visibleStuds,
		Unit = MapMath.ScreenToUnit(pan, mid, view.Centre, side()) }
end
local function movePointer(pointer, point)
	local delta = point - pointer.Last
	pointer.Last = point
	if not pointer.Moved and (point - pointer.Start).Magnitude >= cfg("DragThresholdPixels", 8, 1, 64) then pointer.Moved = true end
	if pinch and (pinch.A == pointer or pinch.B == pointer) then
		local distance = math.max(1, (pinch.A.Last - pinch.B.Last).Magnitude)
		local minimum, maximum = studLimits()
		visibleStuds = MapMath.ClampVisibleStuds(pinch.Studs * pinch.Distance / distance, minimum, maximum)
		local mid = (pinch.A.Last + pinch.B.Last) * 0.5
		pan = pinch.Unit - (mid - view.Centre) / side()
		clampView()
	elseif pointer.Moved and pointerCount() == 1 then
		pan -= delta / side()
		panTarget = nil
		clampView()
	end
end

-- Pointer input is read from UserInputService (the map GUI marks it processed) and accepted only
-- when it starts inside the map view and not on the zoom buttons. Header and legend are outside it.
local function insideView(point)
	return point.X >= 0 and point.Y >= 0 and point.X <= view.W and point.Y <= view.H
end
local function pointerBegan(input)
	if not isOpen then return end
	local kind = input.UserInputType
	if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
	-- A press outside the panel closes the map. This is a bounds check, not a backdrop button:
	-- a full-screen button behind the panel also received presses made on the map itself.
	local screenPoint = Vector2.new(input.Position.X, input.Position.Y)
	local panelMin, panelMax = panel.AbsolutePosition, panel.AbsolutePosition + panel.AbsoluteSize
	if screenPoint.X < panelMin.X or screenPoint.Y < panelMin.Y or screenPoint.X > panelMax.X or screenPoint.Y > panelMax.Y then
		close()
		return
	end
	local point = toView(input.Position)
	if not insideView(point) or overControls(point) then return end
	local key = kind == Enum.UserInputType.Touch and input or "Mouse"
	pointers[key] = { Start = point, Last = point, Moved = false }
	panTarget = nil
	if pointerCount() >= 2 then
		multiTouch = true
		beginPinch()
	end
end
UserInputService.InputChanged:Connect(function(input)
	if not isOpen then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local point = toView(input.Position)
		if insideView(point) then zoomStep(input.Position.Z > 0 and 1 or -1, point) end
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then
		local pointer = pointers.Mouse
		if pointer then movePointer(pointer, toView(input.Position)) end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		local pointer = pointers[input]
		if pointer then movePointer(pointer, toView(input.Position)) end
	elseif input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick1 then
		padStick = Vector2.new(input.Position.X, input.Position.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local key = input.UserInputType == Enum.UserInputType.Touch and input or (input.UserInputType == Enum.UserInputType.MouseButton1 and "Mouse" or nil)
	local pointer = key and pointers[key]
	if not pointer then return end
	pointers[key] = nil
	if pinch and (pinch.A == pointer or pinch.B == pointer) then
		pinch = nil
		for _, other in pairs(pointers) do other.Moved = true end
	end
	if isOpen and not pointer.Moved and not multiTouch then tap(pointer.Start) end
	if pointerCount() == 0 then multiTouch = false end
end)

-- Keyboard / controller ------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	pointerBegan(input)
	if input.KeyCode == Enum.KeyCode.Escape then
		if isOpen then close() end
		return
	end
	if processed or UserInputService:GetFocusedTextBox() then return end
	local code = input.KeyCode
	if code == Enum.KeyCode.M then
		toggle()
		return
	end
	if not isOpen then return end
	if code == Enum.KeyCode.E or code == Enum.KeyCode.Equals or code == Enum.KeyCode.KeypadPlus then
		zoomStep(1)
	elseif code == Enum.KeyCode.Q or code == Enum.KeyCode.Minus or code == Enum.KeyCode.KeypadMinus then
		zoomStep(-1)
	elseif code == Enum.KeyCode.C then
		panTarget = playerUnit()
	elseif code == Enum.KeyCode.Backspace or code == Enum.KeyCode.Delete then
		clearWaypoint()
	end
end)
GuiService.MenuOpened:Connect(close)

function padAction(_, inputState, input)
	if not isOpen then return Enum.ContextActionResult.Pass end
	local code = input.KeyCode
	if code == Enum.KeyCode.Thumbstick1 then
		padStick = inputState == Enum.UserInputState.End and Vector2.zero or Vector2.new(input.Position.X, input.Position.Y)
		return Enum.ContextActionResult.Sink
	end
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	if code == Enum.KeyCode.ButtonA then
		tap(view.Centre)
	elseif code == Enum.KeyCode.ButtonB then
		close()
	elseif code == Enum.KeyCode.ButtonX then
		clearWaypoint()
	elseif code == Enum.KeyCode.ButtonY then
		panTarget = playerUnit()
	elseif code == Enum.KeyCode.ButtonL1 then
		zoomStep(-1)
	elseif code == Enum.KeyCode.ButtonR1 then
		zoomStep(1)
	end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindActionAtPriority("FullMapToggle", function(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if isOpen then close() return Enum.ContextActionResult.Sink end
	if toggle() then return Enum.ContextActionResult.Sink end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonSelect)

local function updateInputKind(kind)
	local gamepad = kind and string.find(kind.Name, "Gamepad", 1, true) ~= nil
	if gamepad ~= usingGamepad then
		usingGamepad = gamepad
		refreshHint()
	end
end
UserInputService.LastInputTypeChanged:Connect(updateInputKind)
updateInputKind(UserInputService:GetLastInputType())

-- Buttons --------------------------------------------------------------------------------------
closeButton.Activated:Connect(close)
zoomIn.Activated:Connect(function() zoomStep(1) end)
zoomOut.Activated:Connect(function() zoomStep(-1) end)
centreButton.Activated:Connect(function() panTarget = playerUnit() end)
clearButton.Activated:Connect(function() if MapMarkers.Get("Waypoint") then clearWaypoint() end end)
legendToggle.Activated:Connect(function()
	legendOpen = not legendOpen
	local anchorUnit = pan
	layout()
	pan = anchorUnit
	clampView()
end)

-- Presentation owners (racing etc.) close the map, like they close the HUD modals.
local presentation = uiFolder:FindFirstChild("FreeRoamHudPresentationMode")
if presentation and presentation:IsA("BindableEvent") then
	presentation.Event:Connect(function(payload)
		if typeof(payload) == "table" then
			presentationOwners[tostring(payload.Owner or "Racing")] = payload.Active == true or nil
		else
			presentationOwners.Racing = tostring(payload) == "Racing" or nil
		end
		if next(presentationOwners) ~= nil then close() end
	end)
end

local function watchViewport(camera)
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if isOpen then layout() end end) end
end
watchViewport(Workspace.CurrentCamera)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() watchViewport(Workspace.CurrentCamera) end)

-- Render (bound only while open) ---------------------------------------------------------------
local lastLegend = 0
function renderStep(dt)
	if not isOpen then return end
	if blocked() then close() return end
	-- Continuous pan from keys and the left stick (view shorter sides per second).
	local move = Vector2.zero
	if not UserInputService:GetFocusedTextBox() then
		local function down(...) for _, code in ipairs({ ... }) do if UserInputService:IsKeyDown(code) then return true end end return false end
		if down(Enum.KeyCode.A, Enum.KeyCode.Left) then move += Vector2.new(-1, 0) end
		if down(Enum.KeyCode.D, Enum.KeyCode.Right) then move += Vector2.new(1, 0) end
		if down(Enum.KeyCode.W, Enum.KeyCode.Up) then move += Vector2.new(0, -1) end
		if down(Enum.KeyCode.S, Enum.KeyCode.Down) then move += Vector2.new(0, 1) end
		move *= cfg("KeyboardPanSpeed", 0.9, 0, 10)
	end
	if padStick.Magnitude > 0.15 then move += Vector2.new(padStick.X, -padStick.Y) * cfg("GamepadPanSpeed", 1, 0, 10) end
	if move.Magnitude > 0 then
		pan += move * dt * view.Short / side()
		panTarget = nil
	elseif panTarget then
		pan = MapMath.Approach(pan, panTarget, cfg("CentreResponse", 12, 0, 60), dt)
		if (pan - panTarget).Magnitude * side() < 0.5 then pan, panTarget = panTarget, nil end
	end
	clampView()

	local canvasSide = side()
	local topLeft = view.Centre - pan * canvasSide
	canvas.Size = UDim2.fromOffset(canvasSide, canvasSide)
	canvas.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
	local function project(position)
		local u, v = MapMath.WorldToUnit(cal, position.X, position.Z)
		local point = MapMath.UnitToScreen(pan, Vector2.new(u, v), view.Centre, canvasSide)
		return point.X, point.Y
	end

	local root = subject()
	if root then
		local position = root.Position
		local x, y = project(position)
		x, y = MapMath.ClampToRect(x, y, view.W, view.H, 14)
		playerArrow.Visible = true
		playerArrow.Position = UDim2.fromOffset(x, y)
		local heading = MapMath.Heading(cal, root.CFrame.LookVector.X, root.CFrame.LookVector.Z)
		if heading then playerArrow.Rotation = heading + MapMath.Finite(readValue(layoutConfig, "MapRotationOffsetDegrees", 0), 0) end
		RouteGuide.Update(position) -- the HUD owners do not step while the full map is open
		routeRenderer:Step({
			MapVisible = true, FullMapStuds = cal.FullStuds, WorldCenter = Vector2.new(cal.CenterX, cal.CenterZ),
			CoordinateCosine = cal.Cos, CoordinateSine = cal.Sin, FlipX = cal.FlipX, FlipZ = cal.FlipZ,
			PixelScale = cfg("RouteLineScale", 2, 1, 8), MapRotationDegrees = 0, LocalWorldPosition = position,
			-- A huge virtual minimap keeps the renderer's minimap-only edge pip hidden on the full map.
			MapSize = 1e7, VisibleStuds = 1e7,
		})
	else
		playerArrow.Visible = false
		routeRenderer:SetVisible(false)
	end

	if playerMarkers then
		local host = math.max(view.W, view.H)
		local unitCentre = pan
		local cx, cz = MapMath.UnitToWorld(cal, unitCentre.X, unitCentre.Y)
		-- dt = 1 disables the module's smoothing so markers stay glued to the map while panning.
		playerMarkers:Step(1, {
			MapRotationDegrees = 0, MapVisible = true, LocalWorldPosition = Vector3.new(cx, 0, cz),
			MapSize = host, VisibleStuds = host * cal.FullStuds / canvasSide,
			CoordinateRadians = cal.Radians, CoordinateCosine = cal.Cos, CoordinateSine = cal.Sin,
			FlipX = cal.FlipX, FlipZ = cal.FlipZ, LocalMarkerSize = sizes.Icon or 26,
		})
	end
	iconLayer:Step(dt, { MapVisible = true, Size = Vector2.new(view.W, view.H), Project = project })

	if legendDirty and os.clock() - lastLegend > 0.25 then
		lastLegend = os.clock()
		rebuildLegend()
	end
end

player:SetAttribute("FullMapOpen", false)
api = { open = open, close = close, toggle = toggle, isOpen = function() return isOpen end }
print("[FullMapUI] Full map ready (M / Back / minimap).")
end, debug.traceback)
startState = ok and "ready" or "failed"
assert(ok, message)
end

return FullMap
