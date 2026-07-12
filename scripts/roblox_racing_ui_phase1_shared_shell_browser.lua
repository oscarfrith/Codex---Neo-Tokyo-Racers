-- Neo Tokyo Racers - Racing UI Phase 1 Shared Shell + Race Browser
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- Canonically replaces only the isolated RaceBrowserClient_Active LocalScript.
-- Creates Config.UI.Racing semantic values and one reusable UI module.
-- Does not patch the bootstrap, entry client, rewards, PBs, matchmaking,
-- reset, route guide, transition, or finish lifecycle.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Racing UI Phase 1 Shared Shell Browser"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function ensure(parent, className, name)
	local item = parent:FindFirstChild(name)
	if item then
		assert(item:IsA(className), item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. className)
		return item
	end
	item = Instance.new(className)
	item.Name = name
	item.Parent = parent
	return item
end

local function value(parent, className, name, default)
	local item = parent:FindFirstChild(name)
	if item then
		assert(item:IsA(className), item:GetFullName() .. " has unexpected class " .. item.ClassName)
		return item
	end
	item = Instance.new(className)
	item.Name = name
	item.Value = default
	item.Parent = parent
	return item
end

local function moduleSource()
	return [====[
-- Neo Tokyo Racers - Shared Racing UI Components
-- NTR_RACING_UI_PHASE1_SHARED_COMPONENTS

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = {}

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Racing")
local colours = config:WaitForChild("Colours")
local layout = config:WaitForChild("Layout")
local typography = config:WaitForChild("Typography")
local assets = config:WaitForChild("Assets")

local function read(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA("ValueBase") then return item.Value end
	return fallback
end

function Components.Colour(name, fallback)
	return read(colours, name, fallback or Color3.new(1, 1, 1))
end

function Components.Layout(name, fallback)
	return read(layout, name, fallback or 0)
end

function Components.Type(name, fallback)
	return read(typography, name, fallback or 12)
end

function Components.AssetValue(name, fallback)
	return read(assets, name, fallback or "")
end

function Components.Asset(value)
	local text = tostring(value or "")
	if text == "" then return "" end
	if string.find(text, "rbxassetid://", 1, true) or string.find(text, "rbxthumb://", 1, true) then return text end
	if tonumber(text) then return "rbxassetid://" .. text end
	return text
end

function Components.Font(object, role)
	local bold = role == "Heading" or role == "Button" or role == "Metric"
	object.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	local family = read(typography, "FontFamily", "rbxasset://fonts/families/Michroma.json")
	if family ~= "" then
		pcall(function()
			object.FontFace = Font.new(family, bold and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
		end)
	end
end

function Components.Corner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Components.Layout("CornerRadius", 5))
	corner.Parent = parent
	return corner
end

function Components.Stroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Components.Colour("Outline")
	stroke.Thickness = thickness or Components.Layout("StrokeWidth", 1.5)
	stroke.Transparency = transparency == nil and 0.18 or transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Components.Label(parent, properties)
	properties = properties or {}
	local item = Instance.new("TextLabel")
	item.Name = properties.Name or "Label"
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Position = properties.Position or UDim2.fromOffset(0, 0)
	item.Size = properties.Size or UDim2.fromScale(1, 1)
	item.Text = tostring(properties.Text or "")
	item.TextColor3 = properties.Color or Components.Colour("Text")
	item.TextSize = properties.TextSize or Components.Type("Body", 14)
	item.TextWrapped = properties.Wrapped == true
	item.TextTruncate = properties.Truncate or Enum.TextTruncate.AtEnd
	item.TextXAlignment = properties.XAlignment or Enum.TextXAlignment.Left
	item.TextYAlignment = properties.YAlignment or Enum.TextYAlignment.Center
	Components.Font(item, properties.Role or "Body")
	item.Parent = parent
	return item
end

function Components.Panel(parent, properties)
	properties = properties or {}
	local item = Instance.new("Frame")
	item.Name = properties.Name or "Panel"
	item.BorderSizePixel = 0
	item.BackgroundColor3 = properties.Color or Components.Colour("Panel")
	item.BackgroundTransparency = properties.Transparency == nil and Components.Layout("PanelTransparency", 0.08) or properties.Transparency
	item.Position = properties.Position or UDim2.fromOffset(0, 0)
	item.Size = properties.Size or UDim2.fromScale(1, 1)
	item.ClipsDescendants = properties.Clips == true
	item.Parent = parent
	Components.Corner(item, properties.Radius)
	if properties.NoStroke ~= true then
		local borderColor = properties.StrokeColor or Components.Colour("Outline")
		local stroke = Components.Stroke(item, borderColor, properties.StrokeWidth, properties.StrokeTransparency)
		stroke.Name = "Stroke"
		if properties.NoGlow ~= true then
			local glow = Components.Stroke(item, borderColor, properties.GlowWidth or 4, properties.GlowTransparency == nil and 0.82 or properties.GlowTransparency)
			glow.Name = "GlowStroke"
		end
	end
	return item
end

function Components.Button(parent, properties)
	properties = properties or {}
	local item = Instance.new("TextButton")
	item.Name = properties.Name or "Button"
	item.AutoButtonColor = false
	item.BorderSizePixel = 0
	item.BackgroundColor3 = properties.Color or Components.Colour("PanelSoft")
	item.BackgroundTransparency = properties.Transparency == nil and 0.08 or properties.Transparency
	item.Position = properties.Position or UDim2.fromOffset(0, 0)
	item.Size = properties.Size or UDim2.fromOffset(160, 48)
	item.Text = tostring(properties.Text or "")
	item.TextColor3 = properties.TextColor or Components.Colour("Text")
	item.TextSize = properties.TextSize or Components.Type("Button", 14)
	item.ZIndex = properties.ZIndex or parent.ZIndex + 2
	Components.Font(item, "Button")
	item.Parent = parent
	Components.Corner(item, properties.Radius)
	local overlay = Instance.new("Frame")
	overlay.Name = "GradientOverlay"
	overlay.Active = false
	overlay.BackgroundColor3 = Color3.new(1, 1, 1)
	overlay.BackgroundTransparency = 0.9
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = item.ZIndex
	overlay.Parent = item
	Components.Corner(overlay, properties.Radius)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "NeutralOverlay"
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(95, 95, 95))
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.52, 0.7),
		NumberSequenceKeypoint.new(1, 0.28),
	})
	gradient.Parent = overlay
	local normal = properties.StrokeColor or Components.Colour("Outline")
	local focus = properties.FocusColor or Components.Colour("Telemetry")
	local stroke = Components.Stroke(item, normal, properties.StrokeWidth, properties.StrokeTransparency)
	stroke.Name = "Stroke"
	local glow = Components.Stroke(item, normal, 4, 0.82)
	glow.Name = "GlowStroke"
	item.MouseEnter:Connect(function()
		if item.Active then
			item.BackgroundColor3 = properties.FocusFill or Components.Colour("PanelSoft")
			stroke.Color = focus
			glow.Color = focus
			stroke.Transparency = 0.02
			glow.Transparency = 0.7
		end
	end)
	item.MouseLeave:Connect(function()
		item.BackgroundColor3 = properties.Color or Components.Colour("PanelSoft")
		stroke.Color = normal
		glow.Color = normal
		stroke.Transparency = properties.StrokeTransparency == nil and 0.12 or properties.StrokeTransparency
		glow.Transparency = 0.82
	end)
	return item, stroke
end

-- NTR_RACING_UI_SHARED_RESPONSIVE_SCALE_V1
function Components.AttachResponsiveScale(shell)
	local scale = shell:FindFirstChild("ResponsiveScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "ResponsiveScale"
		scale.Parent = shell
	end
	local function resize()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local edgeX = math.max(48, viewport.X * Components.Layout("DesktopEdgeBufferXRatio", 0.10))
		local edgeY = math.max(48, viewport.Y * Components.Layout("DesktopEdgeBufferYRatio", 0.08))
		local fitX = (viewport.X - edgeX * 2) / Components.Layout("ShellWidth", 1200)
		local fitY = (viewport.Y - edgeY * 2) / Components.Layout("ShellHeight", 720)
		scale.Scale = math.clamp(math.min(fitX, fitY), Components.Layout("ResponsiveScaleMin", 0.55), Components.Layout("ScaleMax", 1.15))
	end
	resize()
	local camera = workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
	return scale
end

return Components
]====]
end

local function browserSource()
	return [====[
-- Neo Tokyo Racers - Racing UI Phase 1 Race Browser
-- NTR_RACING_UI_PHASE1_SHARED_SHELL_BROWSER
-- NTR_RACING_UI_PHASE1B_BROWSER_VISUAL_REFINEMENT
-- NTR_RACING_UI_PHASE1C_CARD_INSET_BUTTON_LAYER_REPAIR
-- NTR_RACING_UI_PHASE1D_FOOTER_BUTTON_STYLE_SPACING
-- NTR_RACING_UI_PHASE1E_HEADER_CARD_GRADIENT_POLISH
-- NTR_RACING_UI_PHASE1G_DETAIL_ICONS_EVENT_MEDIA
-- NTR_RACING_UI_PHASE1H_ATLAS_FRAME_GLOW_FOCUS
-- NTR_RACING_UI_PHASE1I_DETAIL_ALIGNMENT_BACKGROUND_GUARD
-- NTR_RACING_UI_PHASE1J_OPTICAL_OFFSETS_DEFAULT_SELECTION
-- NTR_RACING_UI_PHASE1K_DETAIL_PRIZE_POLISH
-- NTR_RACING_PHASE7B_TELEPORT_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local touch = UserInputService.TouchEnabled

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local modules = shared:WaitForChild("Modules")
local racingModules = modules:WaitForChild("Racing")
local uiModules = modules:WaitForChild("UI")
local RaceConfigReader = require(racingModules:WaitForChild("RaceConfigReader"))
local UI = require(uiModules:WaitForChild("RacingUIComponents"))

local controllers = script.Parent.Parent
local uiControllers = controllers:WaitForChild("UI")
local openEvent = uiControllers:WaitForChild("OpenRaceBrowser")
local racingRemotes = shared:WaitForChild("Remotes"):WaitForChild("Racing")
local teleportInvoke = racingRemotes:WaitForChild("RaceBrowserTeleportInvoke")
local racingConfig = kit:WaitForChild("Config"):WaitForChild("Racing")

local gui
local overlay
local shell
local content
local list
local detail
local status
local exitButton
local teleportButton
local selected
local teleportBusy = false
local rows = {}
local suppressedGuis = {}
local suppressionHeartbeat
local suppressionChildAdded

local C = function(name) return UI.Colour(name) end
local L = function(name, fallback) return UI.Layout(name, fallback) end
local T = function(name, fallback) return UI.Type(name, fallback) end

local function clear(parent)
	for _, child in ipairs(parent:GetChildren()) do child:Destroy() end
end

local function formatMoney(amount)
	local text = tostring(math.floor((tonumber(amount) or 0) + 0.5))
	repeat
		local changed
		text, changed = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
	until changed == 0
	return "$" .. text
end

local function catalogEvents(name)
	local catalog = racingConfig:FindFirstChild(name)
	local result = {}
	for _, event in ipairs(catalog and catalog:GetChildren() or {}) do
		if event:IsA("Folder") or event:IsA("Configuration") then table.insert(result, event) end
	end
	return result
end

local function addMode(byRoute, mode, catalog)
	for _, event in ipairs(catalogEvents(catalog)) do
		local eventId = tostring(event:GetAttribute("EventId") or event.Name)
		local ok, summary = pcall(function() return RaceConfigReader.GetEventSummary(eventId, mode) end)
		if ok and type(summary) == "table" then
			local key = tostring(summary.RouteId or eventId)
			local row = byRoute[key]
			if not row then
				row = { Key = key, DisplayName = tostring(summary.DisplayName or summary.RouteDisplayName or key) }
				byRoute[key] = row
			end
			row[mode] = summary
			if mode == "TimeTrial" or not row.Primary then row.Primary = summary end
		end
	end
end

local function buildRows()
	local byRoute = {}
	addMode(byRoute, "TimeTrial", "TimeTrialCatalog")
	addMode(byRoute, "Race", "RaceCatalog")
	rows = {}
	for _, row in pairs(byRoute) do table.insert(rows, row) end
	table.sort(rows, function(a, b) return string.lower(a.DisplayName) < string.lower(b.DisplayName) end)
	-- Rebuilt row tables must never retain a stale selected-table reference.
	-- The browser intentionally opens on the first sorted event every time.
	selected = rows[1]
end

local function imageSlot(parent, name, image, position, size, placeholder, noStroke)
	local frame = UI.Panel(parent, {
		Name = name,
		Position = position,
		Size = size,
		Color = C("PanelDeep"),
		Transparency = 0.08,
		StrokeColor = C("Outline"),
		StrokeTransparency = 0.2,
		Clips = true,
		NoStroke = noStroke == true,
	})
	image = UI.Asset(image)
	if image ~= "" then
		local picture = Instance.new("ImageLabel")
		picture.Name = "Image"
		picture.BackgroundTransparency = 1
		local inset = noStroke == true and 0 or 2
		picture.Position = UDim2.fromOffset(inset, inset)
		picture.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
		picture.Image = image
		picture.ScaleType = Enum.ScaleType.Crop
		UI.Corner(picture, math.max(1, L("CornerRadius", 5) - 1))
		picture.Parent = frame
	else
		local text = UI.Label(frame, {
			Text = placeholder,
			Size = UDim2.fromScale(1, 1),
			Color = C("Muted"),
			TextSize = T("Caption", 11),
			Role = "Heading",
			XAlignment = Enum.TextXAlignment.Center,
		})
		text.TextTransparency = 0.25
	end
	return frame
end

local ICON_CELLS = {
	-- Optical offsets are measured at the 33 px desktop reference size.
	-- They scale with the rendered icon, then the shell UIScale handles viewport scaling.
	Circuit = { Cell = Vector2.new(2, 0), X = 1.0, Y = -4.5 },
	PointToPoint = { Cell = Vector2.new(3, 0), X = 3.8, Y = -4.3 },
	Laps = { Cell = Vector2.new(0, 1), X = -2.6, Y = -5.3 },
	Checkpoints = { Cell = Vector2.new(1, 1), X = -0.9, Y = -5.0 },
	Players = { Cell = Vector2.new(2, 1), X = 1.2, Y = -5.8 },
	Prize = { Cell = Vector2.new(0, 2), X = -2.7, Y = -6.6 },
}

local function detailIcon(parent, name, position, size)
	local atlas = UI.Asset(UI.AssetValue("RacingIconAtlas", ""))
	if atlas == "" then return nil end
	local spec = ICON_CELLS[name]
	if not spec then return nil end
	local cellSize = math.max(1, tonumber(UI.AssetValue("RacingIconCellSize", "256")) or 256)
	local renderSize = math.max(1, size.X.Offset)
	local opticalScale = renderSize / 33
	local icon = Instance.new("ImageLabel")
	icon.Name = name .. "Icon"
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Position = position + UDim2.fromOffset(spec.X * opticalScale, spec.Y * opticalScale)
	icon.Size = size
	icon.Image = atlas
	icon.ImageRectOffset = Vector2.new(spec.Cell.X * cellSize, spec.Cell.Y * cellSize)
	icon.ImageRectSize = Vector2.new(cellSize, cellSize)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = parent.ZIndex + 2
	icon.Parent = parent
	return icon
end

local function mediaFor(row, field)
	local raceValue = row.Race and tostring(row.Race[field] or "") or ""
	if raceValue ~= "" then return raceValue end
	local timeTrialValue = row.TimeTrial and tostring(row.TimeTrial[field] or "") or ""
	if timeTrialValue ~= "" then return timeTrialValue end
	return row.Primary and tostring(row.Primary[field] or "") or ""
end

local function availabilityText(row)
	local modes = {}
	if row.TimeTrial then table.insert(modes, "TIME TRIAL") end
	if row.Race then table.insert(modes, "RACE") end
	return table.concat(modes, "  •  ")
end

local function routeDescriptor(row)
	local summary = row.Race or row.TimeTrial or row.Primary
	local routeType = string.upper(tostring(summary.RouteType or "CIRCUIT"))
	if routeType == "CIRCUIT" then
		return "CIRCUIT  •  " .. tostring(summary.Laps or 1) .. " LAPS"
	end
	return "POINT-TO-POINT  •  " .. tostring(summary.CheckpointCount or 0) .. " CHECKPOINTS"
end

local function cardGradient(parent)
	local overlay = Instance.new("Frame")
	overlay.Name = "GradientOverlay"
	overlay.Active = false
	overlay.BackgroundColor3 = Color3.new(1, 1, 1)
	overlay.BackgroundTransparency = 0.9
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = parent.ZIndex
	overlay.Parent = parent
	UI.Corner(overlay, L("CornerRadius", 5))
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(95, 95, 95))
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.52, 0.7),
		NumberSequenceKeypoint.new(1, 0.28),
	})
	gradient.Rotation = 90
	gradient.Parent = overlay
end

local function renderDetail()
	clear(detail)
	if not selected then
		UI.Label(detail, { Text = "NO EVENTS AVAILABLE", Position = UDim2.fromOffset(16, 16), Size = UDim2.new(1, -32, 0, 40), Color = C("Muted"), Role = "Heading" })
		teleportButton.Active = false
		teleportButton.TextColor3 = C("Disabled")
		return
	end
	teleportButton.Active = true
	teleportButton.TextColor3 = C("Text")
	local summary = selected.Primary
	local heroHeight = touch and 104 or 240
	imageSlot(detail, "TrackImage", mediaFor(selected, "TrackImage"), UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, heroHeight), "TRACK IMAGE")
	UI.Label(detail, {
		Text = string.upper(selected.DisplayName),
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 30),
		TextSize = touch and 13 or T("Heading", 20),
		Role = "Heading",
	})

	local lowerY = heroHeight + L("Gap", 16)
	local lowerH = -lowerY
	local mapWidth = touch and 0.48 or 0.56
	imageSlot(detail, "TrackMap", mediaFor(selected, "MapImage"), UDim2.fromOffset(0, lowerY), UDim2.new(mapWidth, -8, 1, lowerH), "TRACK MAP")
	local info = UI.Panel(detail, {
		Name = "EventDetails",
		Position = UDim2.new(mapWidth, 8, 0, lowerY),
		Size = UDim2.new(1 - mapWidth, -8, 1, lowerH),
		Color = C("Panel"),
		Transparency = 0.04,
		StrokeColor = C("Outline"),
		StrokeTransparency = 0.2,
	})
	cardGradient(info)
	local detailsHeading = UI.Label(info, { Text = "EVENT DETAILS", Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, touch and 22 or 30), Color = C("Text"), TextSize = touch and 12 or 16, Role = "Heading" })
	detailsHeading.ZIndex = info.ZIndex + 3
	local raceSummary = selected.Race or summary
	local facts = {
		{ Icon = string.upper(tostring(summary.RouteType or "CIRCUIT")) == "CIRCUIT" and "Circuit" or "PointToPoint", Text = string.upper(tostring(summary.RouteType or "CIRCUIT")) },
		{ Icon = "Laps", Text = tostring(raceSummary.Laps or 1) .. " LAPS" },
		{ Icon = "Checkpoints", Text = tostring(summary.CheckpointCount or 0) .. " CHECKPOINTS" },
		{ Icon = "Players", Text = tostring(raceSummary.MinPlayers or 1) .. "-" .. tostring(raceSummary.MaxPlayers or 1) .. " PLAYERS" },
		{ Icon = "Prize", Text = "PRIZE", Amount = formatMoney(raceSummary.BaseReward or summary.BaseReward), Prize = true },
	}
	for index, fact in ipairs(facts) do
		local rowHeight = touch and 30 or 40
		local iconSize = touch and 24 or 33
		local y = (touch and 48 or 60) + (index - 1) * rowHeight
		local factRow = Instance.new("Frame")
		factRow.Name = fact.Icon .. "Row"
		factRow.BackgroundTransparency = 1
		factRow.BorderSizePixel = 0
		factRow.Position = UDim2.fromOffset(0, y)
		factRow.Size = UDim2.new(1, 0, 0, rowHeight)
		factRow.ZIndex = info.ZIndex + 2
		factRow.Parent = info
		local icon = detailIcon(factRow, fact.Icon, UDim2.new(0, touch and 25 or 29, 0.5, 0), UDim2.fromOffset(iconSize, iconSize))
		if icon then icon.AnchorPoint = Vector2.new(0.5, 0.5) end
		local textX = touch and 45 or 54
		local factLabel = UI.Label(factRow, {
			Text = fact.Text,
			Position = UDim2.fromOffset(textX, 0),
			Size = fact.Prize and UDim2.fromOffset(touch and 45 or 56, rowHeight) or UDim2.new(1, touch and -53 or -66, 1, 0),
			TextSize = touch and 10 or T("Body", 14),
			Color = C("Text"),
			Role = "Heading",
		})
		factLabel.ZIndex = factRow.ZIndex + 1
		if fact.Prize then
			local amountX = textX + (touch and 47 or 60)
			local amountLabel = UI.Label(factRow, {
				Name = "PrizeAmount",
				Text = fact.Amount,
				Position = UDim2.fromOffset(amountX, 0),
				Size = UDim2.new(1, -(amountX + 8), 1, 0),
				TextSize = touch and 10 or T("Body", 14),
				Color = C("Telemetry"),
				Role = "Metric",
			})
			amountLabel.ZIndex = factRow.ZIndex + 2
			local amountGlow = Instance.new("UIStroke")
			amountGlow.Name = "TextGlow"
			amountGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			amountGlow.Color = C("Telemetry")
			amountGlow.Thickness = touch and 1 or 1.5
			amountGlow.Transparency = 0.62
			amountGlow.Parent = amountLabel
		end
	end
end

local function renderList()
	clear(list)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, touch and 8 or 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for index, row in ipairs(rows) do
		local isSelected = selected == row
		local card = UI.Panel(list, {
			Name = "Event_" .. row.Key,
			Size = UDim2.new(1, 0, 0, touch and 82 or 126),
			Color = isSelected and C("Telemetry") or C("Panel"),
			Transparency = isSelected and 0.82 or 0.1,
			StrokeColor = isSelected and C("Telemetry") or C("Outline"),
			StrokeWidth = isSelected and 2 or 1.2,
			StrokeTransparency = isSelected and 0 or 0.22,
		})
		card.LayoutOrder = index
		cardGradient(card)
		local click = Instance.new("TextButton")
		click.Name = "Select"
		click.BackgroundTransparency = 1
		click.Text = ""
		click.Size = UDim2.fromScale(1, 1)
		click.ZIndex = 8
		click.Parent = card
		local thumbW = touch and 102 or 162
		local cardMap = mediaFor(row, "MapImage")
		local cardImage = cardMap ~= "" and cardMap or mediaFor(row, "TrackImage")
		imageSlot(card, "Thumbnail", cardImage, UDim2.fromOffset(0, 0), UDim2.fromOffset(thumbW, touch and 82 or 126), "", true)
		UI.Label(card, {
			Text = string.upper(row.DisplayName),
			Position = UDim2.fromOffset(thumbW + 14, 9),
			Size = UDim2.new(1, -(thumbW + 24), 0, touch and 18 or 26),
			TextSize = touch and 10 or T("Body", 14),
			Role = "Heading",
		})
		UI.Label(card, {
			Text = availabilityText(row),
			Position = UDim2.fromOffset(thumbW + 14, touch and 31 or 42),
			Size = UDim2.new(1, -(thumbW + 28), 0, touch and 18 or 24),
			Color = C("Muted"),
			TextSize = touch and 10 or T("Body", 14),
			Role = "Body",
		})
		UI.Label(card, {
			Text = routeDescriptor(row),
			Position = UDim2.fromOffset(thumbW + 14, touch and 55 or 78),
			Size = UDim2.new(1, -(thumbW + 24), 0, touch and 16 or 26),
			Color = C("Telemetry"),
			TextSize = touch and 10 or T("Body", 14),
			Role = "Metric",
		})
		click.MouseButton1Click:Connect(function()
			selected = row
			renderList()
			renderDetail()
		end)
	end
end

local function fireDrivingExit()
	local event = uiControllers:FindFirstChild("FreeRoamVehicleExited")
	if event and event:IsA("BindableEvent") then event:Fire() end
end

local function transition(step, payload)
	-- NTR_RACING_PHASE8D_BROWSER_TELEPORT_FADE
	local event = script.Parent:FindFirstChild("RaceTransitionRequest")
	if event and event:IsA("BindableEvent") then
		payload = payload or {}
		payload.Step = step
		event:Fire(payload)
	end
end

local function setOpen(open)
	if open then
		table.clear(suppressedGuis)
		local function suppress(child)
			if child:IsA("ScreenGui") and child ~= gui then
				if suppressedGuis[child] == nil then suppressedGuis[child] = child.Enabled end
				child.Enabled = false
			end
		end
		for _, child in ipairs(playerGui:GetChildren()) do suppress(child) end
		suppressionChildAdded = playerGui.ChildAdded:Connect(suppress)
		suppressionHeartbeat = RunService.Heartbeat:Connect(function()
			for otherGui in pairs(suppressedGuis) do
				if otherGui.Parent and otherGui.Enabled then otherGui.Enabled = false end
			end
		end)
	else
		if suppressionHeartbeat then suppressionHeartbeat:Disconnect() suppressionHeartbeat = nil end
		if suppressionChildAdded then suppressionChildAdded:Disconnect() suppressionChildAdded = nil end
		for otherGui, wasEnabled in pairs(suppressedGuis) do
			if otherGui and otherGui.Parent then otherGui.Enabled = wasEnabled end
		end
		table.clear(suppressedGuis)
	end
	overlay.Visible = open
	if open then
		buildRows()
		renderList()
		renderDetail()
		status.Visible = false
	end
end

local function teleportSelected()
	if teleportBusy or not selected then return end
	local summary = selected.TimeTrial or selected.Race
	if not summary then return end
	teleportBusy = true
	teleportButton.Text = "TELEPORTING..."
	status.Visible = false
	transition("FadeOut", { Reason = "BrowserTeleport", Label = "TELEPORTING" })
	task.wait(0.25)
	local mode = selected.TimeTrial and "TimeTrial" or "Race"
	local ok, result = pcall(function()
		return teleportInvoke:InvokeServer("TeleportToRaceStart", { EventId = summary.EventId, Mode = mode })
	end)
	teleportBusy = false
	teleportButton.Text = "TELEPORT"
	if not ok or type(result) ~= "table" or (result.Ok ~= true and result.Success ~= true) then
		transition("FadeIn", { Reason = "BrowserTeleportFailed", Delay = 0.08 })
		status.Text = type(result) == "table" and tostring(result.Message or result.Error or "TELEPORT FAILED") or "TELEPORT FAILED"
		status.Visible = true
		return
	end
	fireDrivingExit()
	setOpen(false)
	transition("RestoreCamera", { Reason = "BrowserTeleport" })
	transition("FadeIn", { Reason = "BrowserTeleport", Delay = 0.3 })
end

local function buildGui()
	local old = playerGui:FindFirstChild("NTR_RaceBrowser")
	if old then old:Destroy() end
	gui = Instance.new("ScreenGui")
	gui.Name = "NTR_RaceBrowser"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 170
	gui.Parent = playerGui

	overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.38
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.Parent = gui

	shell = UI.Panel(overlay, {
		Name = "RacingShell",
		Color = C("PanelDeep"),
		Transparency = L("PanelTransparency", 0.08),
		StrokeColor = C("Outline"),
		StrokeWidth = L("ShellStrokeWidth", 2),
		StrokeTransparency = 0.02,
		Clips = true,
	})
	shell.AnchorPoint = Vector2.new(0.5, 0.5)
	shell.Position = UDim2.fromScale(0.5, 0.5)

	-- NTR_RACING_UI_BROWSER_SHARED_RESPONSIVE_SCALE_V1
	if touch then
		shell.Size = UDim2.new(1, -16, 1, -16)
	else
		shell.Size = UDim2.fromOffset(L("ShellWidth", 1200), L("ShellHeight", 720))
		UI.AttachResponsiveScale(shell)
	end

	local headerH = touch and 44 or L("HeaderHeight", 64)
	UI.Label(shell, {
		Name = "Title",
		Text = "RACE BROWSER",
		Position = UDim2.fromOffset(touch and 12 or 24, 0),
		Size = UDim2.new(0.45, 0, 0, headerH),
		TextSize = touch and 16 or T("Heading", 22),
		Role = "Heading",
	})
	local close = UI.Button(shell, {
		Name = "Close",
		Text = "×",
		Position = UDim2.new(1, touch and -48 or -64, 0, 0),
		Size = UDim2.fromOffset(touch and 48 or 64, headerH),
		Color = C("PanelDeep"),
		StrokeColor = C("Danger"),
		FocusColor = C("Danger"),
		TextColor = C("Danger"),
		TextSize = touch and 24 or 30,
		StrokeTransparency = 1,
	})
	close.MouseButton1Click:Connect(function() setOpen(false) end)
	local divider = Instance.new("Frame")
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = C("Outline")
	divider.BackgroundTransparency = 0.5
	divider.Position = UDim2.fromOffset(0, headerH)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Parent = shell

	local pad = touch and 12 or L("OuterPadding", 24)
	local footerH = touch and 52 or L("FooterHeight", 72)
	content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(pad, headerH + pad)
	content.Size = UDim2.new(1, -pad * 2, 1, -(headerH + footerH + pad + 8))
	content.Parent = shell

	local listFraction = touch and 0.38 or L("BrowserListFraction", 0.38)
	local gap = touch and 10 or L("Gap", 16)
	local listPanel = Instance.new("Frame")
	listPanel.Name = "AvailableEvents"
	listPanel.BackgroundTransparency = 1
	listPanel.BorderSizePixel = 0
	listPanel.Position = UDim2.fromOffset(0, 0)
	listPanel.Size = UDim2.new(listFraction, -gap / 2, 1, 0)
	listPanel.Parent = content
	local listScroller = Instance.new("ScrollingFrame")
	listScroller.Name = "EventList"
	listScroller.BackgroundTransparency = 1
	listScroller.BorderSizePixel = 0
	listScroller.Position = UDim2.fromOffset(0, 0)
	listScroller.Size = UDim2.fromScale(1, 1)
	listScroller.CanvasSize = UDim2.fromOffset(0, 0)
	listScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listScroller.ScrollBarThickness = touch and 4 or 6
	listScroller.ScrollBarImageColor3 = C("Outline")
	listScroller.Parent = listPanel
	list = Instance.new("Frame")
	list.Name = "CardContent"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(4, 4)
	list.Size = UDim2.new(1, -(touch and 12 or 16), 0, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.Parent = listScroller

	detail = Instance.new("Frame")
	detail.Name = "EventDetail"
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.new(listFraction, gap / 2, 0, 0)
	detail.Size = UDim2.new(1 - listFraction, -gap / 2, 1, 0)
	detail.Parent = content

	status = UI.Label(shell, {
		Name = "Status",
		Text = "",
		Position = UDim2.fromOffset(pad, -footerH + L("ShellHeight", 720)),
		Size = UDim2.new(1, -pad * 2, 0, touch and 0 or 18),
		Color = C("Danger"),
		TextSize = T("Caption", 11),
		Role = "Heading",
	})
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.new(0, pad, 1, -footerH + (touch and 0 or 14))
	status.Visible = false

	local buttonY = touch and -48 or -64
	exitButton = UI.Button(shell, {
		Name = "Exit",
		Text = "EXIT",
		Position = UDim2.new(0, pad, 1, buttonY),
		Size = UDim2.new(0.5, -(pad + gap / 2), 0, touch and 40 or 48),
		Color = C("PanelSoft"),
		StrokeColor = C("Outline"),
		FocusColor = C("Telemetry"),
	})
	exitButton.MouseButton1Click:Connect(function() setOpen(false) end)
	teleportButton = UI.Button(shell, {
		Name = "TeleportToStart",
		Text = "TELEPORT",
		Position = UDim2.new(0.5, gap / 2, 1, buttonY),
		Size = UDim2.new(0.5, -(pad + gap / 2), 0, touch and 40 or 48),
		Color = C("PanelBlue"),
		StrokeColor = C("Telemetry"),
		FocusColor = C("Telemetry"),
	})
	teleportButton.MouseButton1Click:Connect(teleportSelected)
end

openEvent.Event:Connect(function()
	setOpen(not overlay.Visible)
end)

buildGui()
print("[NTR Racing UI Phase 1] Shared-shell Race Browser active.")
]====]
end

local function installConfig(kit)
	local ui = ensure(kit:WaitForChild("Config"), "Folder", "UI")
	local racing = ensure(ui, "Folder", "Racing")
	local colours = ensure(racing, "Folder", "Colours")
	local layout = ensure(racing, "Folder", "Layout")
	local typography = ensure(racing, "Folder", "Typography")
	local assets = ensure(racing, "Folder", "Assets")

	local freeRoamColours = ui:WaitForChild("DesktopFreeRoamHud"):WaitForChild("Colours")
	local function inherited(name, fallback)
		local item = freeRoamColours:FindFirstChild(name)
		return item and item:IsA("Color3Value") and item.Value or fallback
	end

	value(colours, "Color3Value", "PanelDeep", inherited("PanelDeep", Color3.fromRGB(9, 12, 16)))
	value(colours, "Color3Value", "Panel", inherited("Panel", Color3.fromRGB(15, 19, 24)))
	value(colours, "Color3Value", "PanelSoft", inherited("PanelSoft", Color3.fromRGB(24, 29, 36)))
	value(colours, "Color3Value", "PanelBlue", inherited("PanelBlue", Color3.fromRGB(8, 42, 84)))
	value(colours, "Color3Value", "Outline", inherited("Outline", Color3.fromRGB(244, 46, 151)))
	value(colours, "Color3Value", "OutlineSoft", inherited("OutlineSoft", Color3.fromRGB(214, 74, 175)))
	value(colours, "Color3Value", "Telemetry", inherited("Telemetry", Color3.fromRGB(43, 225, 218)))
	value(colours, "Color3Value", "ElectricBlue", inherited("ElectricBlue", Color3.fromRGB(25, 116, 255)))
	value(colours, "Color3Value", "Danger", inherited("Danger", Color3.fromRGB(196, 57, 75)))
	value(colours, "Color3Value", "Text", inherited("Text", Color3.fromRGB(246, 248, 252)))
	value(colours, "Color3Value", "Muted", inherited("Muted", Color3.fromRGB(163, 171, 184)))
	value(colours, "Color3Value", "Disabled", inherited("Disabled", Color3.fromRGB(81, 88, 99)))

	value(layout, "NumberValue", "ShellWidth", 1200)
	value(layout, "NumberValue", "ShellHeight", 720)
	value(layout, "NumberValue", "HeaderHeight", 64)
	value(layout, "NumberValue", "FooterHeight", 72)
	value(layout, "NumberValue", "OuterPadding", 24)
	value(layout, "NumberValue", "Gap", 16)
	value(layout, "NumberValue", "CornerRadius", 5)
	value(layout, "NumberValue", "StrokeWidth", 1.5)
	value(layout, "NumberValue", "ShellStrokeWidth", 2)
	value(layout, "NumberValue", "PanelTransparency", 0.08)
	value(layout, "NumberValue", "BrowserListFraction", 0.38)
	value(layout, "NumberValue", "ScaleMin", 0.72)
	value(layout, "NumberValue", "ScaleMax", 1.15)
	value(layout, "NumberValue", "DesktopEdgeBufferXRatio", 0.10)
	value(layout, "NumberValue", "DesktopEdgeBufferYRatio", 0.08)
	value(layout, "NumberValue", "ResponsiveScaleMin", 0.55)
	value(layout, "NumberValue", "MobileBreakpoint", 900)

	value(typography, "StringValue", "FontFamily", "rbxasset://fonts/families/Michroma.json")
	value(typography, "NumberValue", "Heading", 22)
	value(typography, "NumberValue", "Button", 14)
	value(typography, "NumberValue", "Body", 14)
	value(typography, "NumberValue", "Caption", 11)
	value(typography, "NumberValue", "Metric", 22)

	value(assets, "StringValue", "DefaultTrackImage", "")
	value(assets, "StringValue", "DefaultMapImage", "")
	value(assets, "StringValue", "RacingIconAtlas", "")
	local atlasSize = value(assets, "NumberValue", "RacingIconAtlasSize", 1024)
	atlasSize.Value = 1024
	local atlasCellSize = value(assets, "NumberValue", "RacingIconCellSize", 256)
	atlasCellSize.Value = 256
	value(assets, "StringValue", "PlatinumMedal", "")
	value(assets, "StringValue", "GoldMedal", "")
	value(assets, "StringValue", "SilverMedal", "")
	value(assets, "StringValue", "BronzeMedal", "")

	local racingConfig = kit:WaitForChild("Config"):WaitForChild("Racing")
	for _, catalogName in ipairs({ "RaceCatalog", "TimeTrialCatalog" }) do
		local catalog = racingConfig:FindFirstChild(catalogName)
		for _, event in ipairs(catalog and catalog:GetChildren() or {}) do
			if (event:IsA("Folder") or event:IsA("Configuration")) and event:GetAttribute("TrackImage") == nil then
				event:SetAttribute("TrackImage", "")
			end
			if (event:IsA("Folder") or event:IsA("Configuration")) and event:GetAttribute("MapImage") == nil then
				event:SetAttribute("MapImage", "")
			end
		end
	end
	return racing
end

local function paths()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local modules = kit:WaitForChild("Shared"):WaitForChild("Modules")
	local uiModules = ensure(modules, "Folder", "UI")
	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local clientRoot = playerScripts:WaitForChild("NeoTokyoRacersClient")
	local racing = clientRoot:WaitForChild("Controllers"):WaitForChild("Racing")
	return kit, uiModules, racing
end

local function smoke()
	local kit, uiModules, racing = paths()
	local config = kit:WaitForChild("Config"):WaitForChild("UI"):FindFirstChild("Racing")
	assert(config and config:FindFirstChild("Colours") and config:FindFirstChild("Layout") and config:FindFirstChild("Typography"), "Config.UI.Racing incomplete")
	local components = uiModules:FindFirstChild("RacingUIComponents")
	assert(components and components:IsA("ModuleScript"), "RacingUIComponents missing")
	assert(string.find(components.Source, "NTR_RACING_UI_PHASE1_SHARED_COMPONENTS", 1, true), "Shared component marker missing")
	local browser = racing:FindFirstChild("RaceBrowserClient_Active")
	assert(browser and browser:IsA("LocalScript") and browser.Enabled, "RaceBrowserClient_Active missing or disabled")
	assert(string.find(browser.Source, "NTR_RACING_UI_PHASE1_SHARED_SHELL_BROWSER", 1, true), "Phase 1 browser marker missing")
	assert(string.find(browser.Source, "NTR_RACING_UI_PHASE1B_BROWSER_VISUAL_REFINEMENT", 1, true), "Phase 1B browser refinement marker missing")
	assert(string.find(browser.Source, "NTR_RACING_UI_PHASE1C_CARD_INSET_BUTTON_LAYER_REPAIR", 1, true), "Phase 1C browser layout repair marker missing")
	assert(string.find(browser.Source, "NTR_RACING_UI_PHASE1D_FOOTER_BUTTON_STYLE_SPACING", 1, true), "Phase 1D footer repair marker missing")
	assert(string.find(browser.Source, "NTR_RACING_UI_PHASE1E_HEADER_CARD_GRADIENT_POLISH", 1, true), "Phase 1E header/card polish marker missing")
	assert(string.find(browser.Source, "NTR_RACING_UI_PHASE1G_DETAIL_ICONS_EVENT_MEDIA", 1, true), "Phase 1G detail icon/media marker missing")
	assert(string.find(browser.Source, "NTR_RACING_UI_PHASE1H_ATLAS_FRAME_GLOW_FOCUS", 1, true), "Phase 1H atlas/frame/focus marker missing")
	assert(string.find(browser.Source, "NTR_RACING_UI_PHASE1I_DETAIL_ALIGNMENT_BACKGROUND_GUARD", 1, true), "Phase 1I detail/background marker missing")
	assert(string.find(browser.Source, "NTR_RACING_UI_PHASE1J_OPTICAL_OFFSETS_DEFAULT_SELECTION", 1, true), "Phase 1J optical/default-selection marker missing")
	assert(string.find(browser.Source, "NTR_RACING_UI_PHASE1K_DETAIL_PRIZE_POLISH", 1, true), "Phase 1K detail/prize marker missing")
	assert(string.find(browser.Source, "RaceBrowserTeleportInvoke", 1, true), "Teleport remote use missing")
	assert(string.find(browser.Source, "FreeRoamVehicleExited", 1, true), "Driving exit handoff missing")
	assert(string.find(browser.Source, "RaceTransitionRequest", 1, true), "Transition handoff missing")
	print("[" .. PHASE .. "] SMOKE PASS config, shared components, browser owner, teleport, driving-exit, and transition markers are present.")
end

local function install()
	local kit, uiModules, racing = paths()
	installConfig(kit)
	local components = ensure(uiModules, "ModuleScript", "RacingUIComponents")
	components.Source = moduleSource()
	local browser = racing:FindFirstChild("RaceBrowserClient_Active")
	assert(browser and browser:IsA("LocalScript"), "RaceBrowserClient_Active missing; stop and refresh the mirror")
	assert(string.find(browser.Source, "RaceBrowserTeleportInvoke", 1, true), "Current Race Browser lacks the confirmed teleport contract; stop")
	browser.Source = browserSource()
	browser.Enabled = true
	print("[" .. PHASE .. "] INSTALL V10 complete. Lowered detail fact rows and split PRIZE/amount styling with a restrained cyan text glow.")
	smoke()
end

if MODE == "INSTALL" then
	install()
elseif MODE == "SMOKE" then
	smoke()
else
	error("Unknown MODE: " .. tostring(MODE))
end
