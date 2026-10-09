-- Owns the full map drawing (the map surface under the chrome, the legend, the controls, the key hints) for Regular and Compact; not the map state, the input bindings, a remote, an attribute or a bindable.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.WorldMap.FullMapView. Requires: Tokens, Text, Surface, Controls, Map.MapCanvas, Map.MapIcons, Map.MapRoute.
local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Text = require(Kit.Text)
local Surface = require(Kit.Surface)
local Controls = require(Kit.Controls)
local Map = script.Parent.Parent.Map
local MapCanvas = require(Map.MapCanvas)
local MapIcons = require(Map.MapIcons)
local MapRoute = require(Map.MapRoute)

local Space = Tokens.Space
local Scale = Tokens.Scale

local View = {}

-- The arrow's visibility goes through its component (Surface re-applies Visible on a layout change).
local ARROW_SHOW = { Visible = true }
local ARROW_HIDE = { Visible = false }

-- Key hints [seen r08]. Keyboard rows, the gamepad row, and the Classic touch line (FullMapUI 364).
View.KeyboardHints = {
	{ { Caps = { "W", "A", "S", "D" }, Text = "PAN" }, { Caps = { "Q", "E" }, Text = "ZOOM" }, { Caps = { "C" }, Text = "CENTRE ON ME" }, { Caps = { "F" }, Text = "WHOLE MAP" } },
	{ { Caps = { "CLICK" }, Text = "SET WAYPOINT" }, { Caps = { "BACKSPACE" }, Text = "CLEAR" }, { Caps = { "M" }, Text = "CLOSE" } },
}
View.GamepadHints = {
	{ { Icons = { "pad_a" }, Text = "WAYPOINT" }, { Icons = { "pad_x" }, Text = "CLEAR" }, { Icons = { "pad_y" }, Text = "CENTRE" }, { Icons = { "pad_lb", "pad_rb" }, Text = "ZOOM" }, { Icons = { "pad_b" }, Text = "CLOSE" } },
}
View.TouchHint = "DRAG TO PAN   PINCH TO ZOOM   TAP TO SET OR CLEAR A WAYPOINT"

-- Which hint group shows (FullMapUI 360-367). Pure.
function View.HintGroup(usingGamepad: boolean, input: string): string
	if usingGamepad then
		return "Gamepad"
	elseif input == "Touch" then
		return "Touch"
	end
	return "Keyboard"
end

-- Legend panel height in design units: every row, capped to what the reference screen leaves free. Pure.
function View.LegendHeight(rows: number, compact: boolean): number
	if compact then
		local needed = Space.Pad * 2 + rows * Space.CompactActionTile
		return math.min(needed, Scale.CompactRefHeight - Space.CompactRightColumnTop - Space.CompactTileHeight)
	end
	local needed = Space.Pad * 2 + Space.ButtonHeight + rows * Space.StatRowHeight
	return math.min(needed, Scale.RegularRefHeight - Space.RightColumnTop - Space.ButtonHeight - Space.MenuBottom - Space.Gap * 2)
end

local function plain(name, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function list(parent, vertical, gap)
	local layout = Instance.new("UIListLayout")
	layout.Name = "Layout"
	layout.FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
	return layout
end

local function stack(name, parent, vertical, gap, anchor)
	local frame = plain(name, parent)
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.AnchorPoint = anchor
	list(frame, vertical, gap)
	return frame
end

-- extra (optional, from the client): { PlayerMarkers = shared UI.FreeRoamMapPlayerMarkers, MarkerConfig = Folder }.
function View.Mount(layer: any, model: any, scope: any, extra: any?): any
	local ctx = layer.Metrics
	local shared = extra or {}
	local white = Tokens.Colour.White
	local destroyed = false

	-- The map surface. It lives in the full-screen scrim gui, under the static chrome gui, so a pan re-renders
	-- only the map and the chrome never. A stage (gallery, tests) has no scrim root and uses the root.
	local mapParent = layer.ScrimRoot or layer.Root
	local background = Surface.Scrim(mapParent, { Name = "MapBackground", Kind = "Menu" }, scope)
	local mapView = plain("MapView", mapParent)
	mapView.Size = UDim2.fromScale(1, 1)
	mapView.ClipsDescendants = true
	mapView.Active = true -- presses on the map never reach the world
	mapView.ZIndex = 2
	local content = plain("Content", mapView)
	content.Size = UDim2.fromScale(1, 1)
	local overlay = plain("Overlay", mapView)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 5

	local compactAtMount = ctx.Class == "Compact"
	local iconSize = compactAtMount and Space.CompactActionTile or Space.BadgeLarge
	local canvas = MapCanvas.New(content, { ZIndex = 1 }, scope)
	local playersHost = plain("PlayersHost", content)
	playersHost.AnchorPoint = Vector2.new(0.5, 0.5)
	playersHost.ZIndex = 2
	local route = MapRoute.New(canvas.Canvas, overlay, { Width = Space.TileBaseLine }, scope)
	local icons = MapIcons.New(content, overlay, { IconSize = iconSize, FullMap = true }, scope)
	local arrow = Surface.MapIcon(overlay, { Name = "PlayerArrow", Icon = "Player", Tint = white, Size = iconSize, Visible = false }, scope)
	arrow.Instance.ZIndex = 4
	local crosshair = Surface.Icon(overlay, { Name = "Crosshair", Icon = "plus", Colour = "Cyan", Size = Space.BadgeSmall, Visible = false }, scope)
	crosshair.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Instance.ZIndex = 6

	local frame = {}
	local markerState = {}
	local playerMarkers
	local arrowShown, arrowX, arrowY, arrowRotation = false, nil, nil, nil
	local crosshairShown = false
	local hostSide = 0
	local arrowInset = 1

	local function onMapSize()
		local size = mapView.AbsoluteSize
		model:SetViewSize(size.X, size.Y)
		local view = model.View
		hostSide = math.max(view.W, view.H)
		local centreX, centreY = math.floor(view.W * 0.5 + 0.5), math.floor(view.H * 0.5 + 0.5)
		playersHost.Size = UDim2.fromOffset(hostSide, hostSide)
		playersHost.Position = UDim2.fromOffset(centreX, centreY)
		crosshair.Instance.Position = UDim2.fromOffset(centreX, centreY)
		arrowInset = ctx.Px(iconSize) * 0.5
	end

	-- Chrome: rebuilt only when the class changes. --------------------------------------------------------------
	local built = {} -- components and frames of the current build, destroyed together
	local rects = {} -- chrome boxes that take presses away from the map
	local parts = {}
	local legendRows = {}
	local legendSignature

	local function keep(item)
		table.insert(built, item)
		return item
	end

	local function button(parent, props)
		props.Variant = props.Variant or "Default"
		props.Size = "Hud"
		return keep(Controls.Button(parent, props, scope))
	end

	local function hintRow(parent, groups, order)
		local row = stack("Row" .. tostring(order), parent, false, ctx.Px(Space.Gap), Vector2.zero)
		row.LayoutOrder = order
		local index = 0
		for _, group in groups do
			for _, cap in group.Caps or {} do
				index += 1
				keep(Surface.KeyCap(row, { Name = "Key" .. tostring(index), Text = cap, LayoutOrder = index }, scope))
			end
			for _, glyph in group.Icons or {} do
				index += 1
				keep(Surface.KeyCap(row, { Name = "Key" .. tostring(index), Icon = glyph, LayoutOrder = index }, scope))
			end
			index += 1
			keep(Text.Label(row, { Name = "Hint" .. tostring(index), Text = group.Text, Role = "Label", Colour = "TextSecondary", LayoutOrder = index }, scope))
		end
		return row
	end

	local function buildHints(parent, order)
		local gap = ctx.Px(Space.Gap)
		local hints = stack("Hints", parent, true, gap, Vector2.zero)
		hints.LayoutOrder = order
		local keyboard = stack("Keyboard", hints, true, gap, Vector2.zero)
		for index, groups in View.KeyboardHints do
			hintRow(keyboard, groups, index)
		end
		local gamepad = stack("Gamepad", hints, true, gap, Vector2.zero)
		for index, groups in View.GamepadHints do
			hintRow(gamepad, groups, index)
		end
		local touch = stack("Touch", hints, true, gap, Vector2.zero)
		keep(Text.Label(touch, { Name = "Hint", Text = View.TouchHint, Role = "Label", Colour = "TextSecondary" }, scope))
		parts.Hints = { Keyboard = keyboard, Gamepad = gamepad, Touch = touch }
		return hints
	end

	local function destroyChrome()
		for index = #built, 1, -1 do
			local item = built[index]
			if typeof(item) == "Instance" then
				item:Destroy()
			else
				item.Destroy()
			end
		end
		table.clear(built)
		table.clear(rects)
		table.clear(legendRows)
		parts = {}
		legendSignature = nil
	end

	local function buildChrome()
		local compact = ctx.Class == "Compact"
		local gap = ctx.Px(Space.Gap)
		parts.Class = ctx.Class
		parts.Compact = compact

		local district = model:District()
		local header = keep(Controls.Header(layer.Slot("TopLeft"), { Name = "Header", Title = "MAP", Sub = district ~= "" and district or nil }, scope))
		parts.Header = header
		table.insert(rects, header.Instance)

		-- Legend: Regular in the right column, Compact under the title.
		local legend = keep(Surface.Panel(compact and layer.Slot("TopLeft") or layer.Slot("RightColumn"), {
			Name = "Legend",
			Width = compact and Space.CompactSidePanelWidth or Space.StatPanelWidth,
			Height = View.LegendHeight(1, compact),
		}, scope))
		-- RightColumn is a sized slot of exactly this width, so the panel sits at its origin (NOTES, question 4).
		if compact then
			legend.Instance.Position = UDim2.fromOffset(0, header.Height() + gap)
		end
		parts.Legend = legend
		table.insert(rects, legend.Instance)
		local legendContent = legend.Content
		local legendTitleHeight = 0
		if not compact then
			legendTitleHeight = ctx.Px(Space.ButtonHeight)
			local title = keep(Text.Label(legendContent, { Name = "Title", Text = "MAP KEY", Role = "SectionHead" }, scope))
			title.Instance.Position = UDim2.fromOffset(0, 0)
		end
		local scroller = Instance.new("ScrollingFrame")
		scroller.Name = "List"
		scroller.BackgroundTransparency = 1
		scroller.BorderSizePixel = 0
		scroller.Position = UDim2.fromOffset(0, legendTitleHeight)
		scroller.Size = UDim2.new(1, 0, 1, -legendTitleHeight)
		scroller.CanvasSize = UDim2.new()
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.ScrollingDirection = Enum.ScrollingDirection.Y
		scroller.ScrollBarThickness = ctx.Hair(Space.Hairline)
		scroller.ScrollBarImageColor3 = white
		scroller.Parent = legendContent
		list(scroller, true, 0)
		keep(scroller)
		parts.LegendList = scroller

		local function zoomButtons(parent, first)
			button(parent, { Name = "ZoomIn", Icon = "plus", IconOnly = true, LayoutOrder = first, OnActivated = function() model:ZoomStep(1) end })
			button(parent, { Name = "ZoomOut", Icon = "minus", IconOnly = true, LayoutOrder = first + 1, OnActivated = function() model:ZoomStep(-1) end })
		end

		if compact then
			-- Right-hand column [seen c16]: close, zoom, centre, legend.
			local column = keep(stack("Controls", layer.Slot("TopRight"), true, gap, Vector2.new(1, 0)))
			button(column, { Name = "Close", Icon = "close", IconOnly = true, LayoutOrder = 1, OnActivated = function() model:Close() end })
			zoomButtons(column, 2)
			button(column, { Name = "Centre", Icon = "pin", IconOnly = true, LayoutOrder = 4, OnActivated = function() model:CentreOnPlayer() end })
			parts.LegendButton = button(column, { Name = "LegendToggle", Icon = "info", IconOnly = true, LayoutOrder = 5, OnActivated = function() model:ToggleLegend() end })
			table.insert(rects, column)

			local bottom = keep(stack("BottomLeft", layer.Slot("BottomLeft"), false, gap, Vector2.new(0, 1)))
			bottom.Layout.VerticalAlignment = Enum.VerticalAlignment.Center
			parts.Clear = button(bottom, { Name = "ClearWaypoint", Text = "CLEAR WAYPOINT", Icon = "close", LayoutOrder = 1, OnActivated = function()
				if model:HasWaypoint() then model:ClearWaypoint() end
			end })
			keep(buildHints(bottom, 2))
			table.insert(rects, bottom)
		else
			-- Left stack [seen r08]: zoom, ME, ALL, then the key hints.
			local left = keep(stack("BottomLeft", layer.Slot("BottomLeft"), true, ctx.Px(Space.Pad), Vector2.new(0, 1)))
			local column = stack("Controls", left, true, gap, Vector2.zero)
			column.LayoutOrder = 1
			zoomButtons(column, 1)
			button(column, { Name = "Centre", Text = "ME", LayoutOrder = 3, OnActivated = function() model:CentreOnPlayer() end })
			button(column, { Name = "ShowAll", Text = "ALL", LayoutOrder = 4, OnActivated = function() model:ShowAll() end })
			buildHints(left, 2)
			table.insert(rects, left)

			local row = keep(Controls.ButtonRow(layer.Slot("BottomRight"), {
				Name = "Buttons",
				Align = "Right",
				Buttons = {
					{ Id = "close", Variant = "Default", Text = "CLOSE", Icon = "back", OnActivated = function() model:Close() end },
					{ Id = "legend", Variant = "Default", Text = "LEGEND", Icon = "info", OnActivated = function() model:ToggleLegend() end },
					{ Id = "clear", Variant = "Default", Text = "CLEAR WAYPOINT", Icon = "close", OnActivated = function()
						if model:HasWaypoint() then model:ClearWaypoint() end
					end },
				},
			}, scope))
			parts.LegendButton = row.Button("legend")
			parts.Clear = row.Button("clear")
			table.insert(rects, row.Instance)
		end
	end

	-- Legend rows: a pool that only grows; a changed list patches the rows in place. --------------------------------
	local function legendRow(index)
		local row = legendRows[index]
		if row then
			return row
		end
		local compact = parts.Compact
		local rowPx = ctx.Px(compact and Space.CompactActionTile or Space.StatRowHeight)
		local iconDesign = compact and Space.CompactStatusHeight or Space.BadgeSmall
		local iconPx = ctx.Px(iconDesign)
		local holder = plain("Key" .. tostring(index), parts.LegendList)
		holder.Size = UDim2.new(1, 0, 0, rowPx)
		holder.LayoutOrder = index
		local icon = Surface.MapIcon(holder, { Name = "Icon", Icon = "Player", Tint = white, Size = iconDesign }, scope)
		icon.Instance.Position = UDim2.fromOffset(math.floor(iconPx * 0.5), math.floor(rowPx * 0.5))
		local label = Text.Label(holder, { Name = "Label", Text = "", Role = "Label", Colour = "White" }, scope)
		label.Instance.AnchorPoint = Vector2.new(0, 0.5)
		label.Instance.Position = UDim2.fromOffset(iconPx + ctx.Px(Space.Gap), math.floor(rowPx * 0.5))
		local divider = Surface.Divider(holder, { Name = "Divider" }, scope)
		row = { Holder = holder, Icon = icon, Label = label, Divider = divider, Shown = true }
		legendRows[index] = row
		keep(icon)
		keep(label)
		keep(divider)
		keep(holder)
		return row
	end

	local function renderLegend()
		local open = model:LegendOpen()
		parts.Legend.Set({ Visible = open })
		parts.LegendButton.Set({ Selected = open })
		parts.Clear.Set({ Disabled = not model:HasWaypoint() })
		if not open then
			return
		end
		local entries = model:LegendEntries()
		local names = {}
		for _, entry in entries do
			table.insert(names, entry.Icon)
		end
		local signature = table.concat(names, "|")
		if signature == legendSignature then
			return
		end
		legendSignature = signature
		for index, entry in entries do
			local row = legendRow(index)
			row.Icon.Set({ Icon = MapIcons.GlyphFor(entry.Icon, entry.Kind) })
			row.Label.Set({ Text = string.upper(entry.Label) })
			if not row.Shown then
				row.Shown = true
				row.Holder.Visible = true
			end
		end
		for index = #entries + 1, #legendRows do
			local row = legendRows[index]
			if row.Shown then
				row.Shown = false
				row.Holder.Visible = false
			end
		end
		parts.Legend.Set({ Height = View.LegendHeight(#entries, parts.Compact) })
	end

	local function renderInput()
		local group = View.HintGroup(model:HintMode() == "Gamepad", ctx.Input)
		for name, frameOfGroup in parts.Hints do
			local show = name == group
			if frameOfGroup.Visible ~= show then
				frameOfGroup.Visible = show
			end
		end
		local show = group == "Gamepad" and model:IsOpen()
		if show ~= crosshairShown then
			crosshairShown = show
			crosshair.Set({ Visible = show }) -- through the component: Surface re-applies its own Visible
		end
	end

	local function setPlayerMarkers(open)
		if open and not playerMarkers and shared.PlayerMarkers and shared.MarkerConfig then
			playerMarkers = shared.PlayerMarkers.new({ Container = playersHost, Config = shared.MarkerConfig, ZIndex = 2 })
		elseif not open and playerMarkers then
			playerMarkers:Destroy()
			playerMarkers = nil
		end
	end

	local self = { Icons = icons, MapView = mapView }

	function self.Render(reason: string?)
		if destroyed then
			return
		end
		if parts.Class ~= ctx.Class then
			destroyChrome()
			buildChrome()
			reason = nil
		end
		if reason == nil or reason == "Open" or reason == "Close" then
			local open = model:IsOpen()
			setPlayerMarkers(open)
			route.SetVisible(open)
			icons.SetVisible(open)
			local district = model:District()
			if district ~= "" then
				parts.Header.Set({ Sub = district })
			end
		end
		if reason == nil or reason == "Open" or reason == "Legend" then
			renderLegend()
		end
		if reason == nil or reason == "Open" or reason == "Close" or reason == "Input" then
			renderInput()
		end
	end

	-- The view part of the render step (FullMapUI 794-840). view: the MapView table the model filled.
	-- Perf.Bind-safe: no lookups, no creation.
	function self.Step(view: any, routeState: any)
		if destroyed then
			return
		end
		canvas.Step(view)
		icons.Step(view)
		route.Step(view, routeState)

		local root = model.SubjectRoot
		local shown = false
		if root and root.Parent ~= nil then
			MapCanvas.Frame(view, frame)
			local position = root.Position
			local x, y = MapCanvas.Point(frame, view.Calibration, position.X, position.Z)
			local px, py = MapIcons.Place(x, y, view.Size.X, view.Size.Y, false, true, arrowInset, -arrowInset)
			px, py = math.floor(px + 0.5), math.floor(py + 0.5)
			if px ~= arrowX or py ~= arrowY then
				arrowX, arrowY = px, py
				arrow.Instance.Position = UDim2.fromOffset(px, py)
			end
			local look = root.CFrame.LookVector
			local heading = model:Heading(look.X, look.Z)
			if heading then
				heading = math.floor(heading * 2 + 0.5) / 2
				if heading ~= arrowRotation then
					arrowRotation = heading
					arrow.Instance.Rotation = heading
				end
			end
			shown = true
		end
		if shown ~= arrowShown then
			arrowShown = shown
			arrow.Set(shown and ARROW_SHOW or ARROW_HIDE)
		end

		if playerMarkers then
			-- FullMapUI 828-838: a square host the size of the longer side; dt = 1 switches the smoothing off.
			local calibration = view.Calibration
			markerState.MapRotationDegrees = 0
			markerState.MapVisible = true
			markerState.LocalWorldPosition = Vector3.new(view.CentreX, 0, view.CentreZ)
			markerState.MapSize = hostSide
			markerState.VisibleStuds = hostSide * calibration.FullStuds / MapCanvas.Side(view)
			markerState.CoordinateRadians = calibration.Radians
			markerState.CoordinateCosine = calibration.Cos
			markerState.CoordinateSine = calibration.Sin
			markerState.FlipX = calibration.FlipX
			markerState.FlipZ = calibration.FlipZ
			markerState.LocalMarkerSize = arrowInset * 2
			playerMarkers:Step(1, markerState)
		end
	end

	-- Screen position (the InputObject space) -> map-view pixels.
	function self.ToLocal(position: any): Vector2
		local origin = mapView.AbsolutePosition
		return Vector2.new(position.X - origin.X, position.Y - origin.Y)
	end

	-- True when a screen position is over a showing chrome block (FullMapUI 550-558 tested the zoom buttons).
	function self.OverChrome(position: any): boolean
		for _, rect in rects do
			if rect.Visible then
				local low, size = rect.AbsolutePosition, rect.AbsoluteSize
				if position.X >= low.X and position.Y >= low.Y and position.X <= low.X + size.X and position.Y <= low.Y + size.Y then
					return true
				end
			end
		end
		return false
	end

	function self.HitTest(point: Vector2): string?
		return icons.HitTest(point)
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		setPlayerMarkers(false)
		destroyChrome()
		route.Destroy()
		icons.Destroy()
		canvas.Destroy()
		arrow.Destroy()
		crosshair.Destroy()
		background.Destroy()
		mapView:Destroy()
	end

	scope:connect(mapView:GetPropertyChangedSignal("AbsoluteSize"), onMapSize)
	scope:connect(ctx.Changed, function(change)
		if type(change) == "table" and change.Layout == false then
			self.Render("Input")
		else
			onMapSize()
			legendSignature = nil
			self.Render(nil)
		end
	end)
	scope:connect(model.Changed, function(reason)
		self.Render(reason)
	end)

	onMapSize()
	buildChrome()
	self.Render(nil)
	return self
end

return View
