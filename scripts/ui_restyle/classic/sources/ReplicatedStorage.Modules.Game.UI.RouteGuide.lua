-- Canonical feature implementation; the free-roam HUD owners host it (no startup of its own).
-- Client-only GPS route guide (Street Life design 10.2). Owns the free-roam route
-- destination and its road route; both HUD owners call Update and their MapRenderer
-- from their existing render callbacks. No remotes, saved data, loops or camera writes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modules = ReplicatedStorage:WaitForChild("Modules")
local Signal = require(modules:WaitForChild("Core"):WaitForChild("Signal"))
local RoadRouting = require(modules:WaitForChild("Game"):WaitForChild("World"):WaitForChild("RoadRouting"))
local graphData = require(modules.Game.World:WaitForChild("RoadGraphData"))
local config = ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("RouteGuide")

local RouteGuide = {}
RouteGuide.Changed = Signal.new() -- (activeDestination or nil)
RouteGuide.Arrived = Signal.new() -- (destination)

local function number(name, fallback, minimum, maximum)
	local value = tonumber(config:GetAttribute(name))
	if value == nil or value ~= value then value = fallback end
	return math.clamp(value, minimum, maximum)
end

local function colour(name, fallback)
	local value = config:GetAttribute(name)
	return typeof(value) == "Color3" and value or fallback
end

local graph
local function roads()
	if not graph then graph = RoadRouting.LoadGraph(graphData) end
	return graph
end

local requests = {} -- sourceId -> destination
local active -- highest-priority destination
local route -- { Points, Cumulative, Length, Version }
local routeVersion = 0
local progress = { Segment = 1, Point = nil, Remaining = 0, OffSince = nil }
local lastPlan, lastProgress = -math.huge, -math.huge

local function flat(position)
	return Vector2.new(position.X, position.Z)
end

local function choose()
	local best
	for _, request in pairs(requests) do
		if not best or request.Priority > best.Priority or (request.Priority == best.Priority and request.Stamp > best.Stamp) then
			best = request
		end
	end
	if best ~= active then
		active = best
		route = nil
		progress = { Segment = 1, Point = nil, Remaining = 0, OffSince = nil }
		lastPlan = -math.huge
		RouteGuide.Changed:Fire(active)
	end
end

local stamp = 0
-- options: { Label = string, Priority = number (default 10), Kind = "FreeRoam" | "Activity" }
function RouteGuide.SetDestination(sourceId, position, options)
	assert(type(sourceId) == "string" and sourceId ~= "", "RouteGuide source id required")
	assert(typeof(position) == "Vector3", "RouteGuide destination must be a Vector3")
	options = options or {}
	stamp += 1
	requests[sourceId] = {
		Source = sourceId,
		Position = position,
		Label = string.upper(tostring(options.Label or "WAYPOINT")),
		Priority = tonumber(options.Priority) or 10,
		Kind = options.Kind == "Activity" and "Activity" or "FreeRoam",
		Stamp = stamp,
	}
	active = nil -- force a fresh route even when the same source re-targets
	choose()
end

function RouteGuide.Clear(sourceId)
	if sourceId == nil then
		table.clear(requests)
	else
		requests[sourceId] = nil
	end
	choose()
end

function RouteGuide.GetActive()
	return active
end

-- Configured destinations: Config.UI.RouteGuide.Destinations.<Id> with DisplayName, Kind, Position, Order.
function RouteGuide.Destinations()
	local list = {}
	local folder = config:FindFirstChild("Destinations")
	for _, item in ipairs(folder and folder:GetChildren() or {}) do
		local position = item:GetAttribute("Position")
		if typeof(position) == "Vector3" then
			table.insert(list, {
				Id = item.Name,
				DisplayName = tostring(item:GetAttribute("DisplayName") or item.Name),
				Kind = tostring(item:GetAttribute("Kind") or "Place"),
				RouteId = item:GetAttribute("RouteId"),
				Position = position,
				Order = tonumber(item:GetAttribute("Order")) or 100,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.Order ~= b.Order then return a.Order < b.Order end
		return a.DisplayName < b.DisplayName
	end)
	return list
end

function RouteGuide.SetDestinationById(id, sourceId)
	for _, destination in ipairs(RouteGuide.Destinations()) do
		if destination.Id == id or destination.RouteId == id then
			RouteGuide.SetDestination(sourceId or "Player", destination.Position, { Label = destination.DisplayName })
			return true
		end
	end
	return false
end

local function plan(position)
	local found = RoadRouting.FindRoute(roads(), flat(position), flat(active.Position))
	lastPlan = os.clock()
	if not found then
		route = nil
		return
	end
	local points = found.Points
	local target = flat(active.Position)
	if (target - points[#points]).Magnitude > 1 then table.insert(points, target) end
	points = RoadRouting.Smooth(points, number("CornerRadius", 50, 0, 150), 8)
	routeVersion += 1
	route = { Points = points, Cumulative = RoadRouting.Cumulative(points), Version = routeVersion }
	progress = { Segment = 1, Point = points[1], Remaining = route.Cumulative[#points], OffSince = nil }
end

-- Called by the HUD owner each frame with the map subject position; throttles itself.
function RouteGuide.Update(position)
	if not active or config:GetAttribute("Enabled") == false or typeof(position) ~= "Vector3" then return end
	local now = os.clock()
	local arrive = number("ArriveStuds", 45, 5, 500)
	if (flat(position) - flat(active.Position)).Magnitude <= arrive then
		local reached = active
		RouteGuide.Clear(reached.Source)
		RouteGuide.Arrived:Fire(reached)
		return
	end
	if not route then
		if now - lastPlan >= number("ReplanMinSeconds", 1, 0.2, 10) then plan(position) end
		return
	end
	if now - lastProgress < 1 / number("ProgressHz", 10, 1, 60) then return end
	lastProgress = now
	local segment, point, offRoute, remaining = RoadRouting.Progress(route.Points, route.Cumulative, flat(position), progress.Segment, 12)
	progress.Segment, progress.Point, progress.Remaining = segment, point, remaining
	if offRoute > number("OffRouteStuds", 60, 10, 500) then
		progress.OffSince = progress.OffSince or now
		if now - progress.OffSince >= number("OffRouteSeconds", 1, 0, 10) and now - lastPlan >= number("ReplanMinSeconds", 1, 0.2, 10) then
			plan(position)
		end
	else
		progress.OffSince = nil
	end
end

-- Minimap renderer: draws the remaining route inside the HUD's map canvas so it pans,
-- rotates and clips with the map; a chip and an edge pip sit in the unrotated container.
local MapRenderer = {}
MapRenderer.__index = MapRenderer

-- options: { Canvas, Container, ZIndex, ChipZIndex, Font, Colours = { Line, Activity, Outline, ChipBackground, ChipText } }
function RouteGuide.newMapRenderer(options)
	assert(options and options.Canvas and options.Container, "RouteGuide renderer needs Canvas and Container")
	local self = setmetatable({}, MapRenderer)
	self.Canvas, self.Container = options.Canvas, options.Container
	self.ZIndex = options.ZIndex or 10
	self.Colours = options.Colours or {}
	self.Segments, self.Outlines = {}, {}
	self.Version = nil
	self.PixelScale = nil

	local layer = Instance.new("Frame")
	layer.Name = "RouteGuide"
	layer.BackgroundTransparency = 1
	layer.BorderSizePixel = 0
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = self.ZIndex
	layer.Visible = false
	layer.Parent = self.Canvas
	self.Layer = layer

	local blip = Instance.new("Frame")
	blip.Name = "DestinationBlip"
	blip.AnchorPoint = Vector2.new(0.5, 0.5)
	blip.BorderSizePixel = 0
	blip.Rotation = 45
	blip.Visible = false
	blip.ZIndex = self.ZIndex + 2
	blip.Parent = layer
	local blipStroke = Instance.new("UIStroke")
	blipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	blipStroke.Parent = blip
	self.Blip, self.BlipStroke = blip, blipStroke

	local pip = Instance.new("Frame")
	pip.Name = "RouteEdgePip"
	pip.AnchorPoint = Vector2.new(0.5, 0.5)
	pip.BorderSizePixel = 0
	pip.Rotation = 45
	pip.Size = UDim2.fromOffset(9, 9)
	pip.Visible = false
	pip.ZIndex = options.ChipZIndex or (self.ZIndex + 6)
	pip.Parent = self.Container
	local pipStroke = Instance.new("UIStroke")
	pipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pipStroke.Thickness = 1
	pipStroke.Parent = pip
	self.Pip, self.PipStroke = pip, pipStroke

	local chip = Instance.new("TextLabel")
	chip.Name = "RouteChip"
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 0, 6)
	chip.Size = UDim2.fromOffset(0, 20)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BorderSizePixel = 0
	chip.TextSize = 10
	chip.Font = options.Font or Enum.Font.Michroma
	chip.Visible = false
	chip.ZIndex = options.ChipZIndex or (self.ZIndex + 6)
	chip.Parent = self.Container
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0, 6)
	chipCorner.Parent = chip
	local chipStroke = Instance.new("UIStroke")
	chipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	chipStroke.Thickness = 1
	chipStroke.Parent = chip
	local chipPadding = Instance.new("UIPadding")
	chipPadding.PaddingLeft = UDim.new(0, 8)
	chipPadding.PaddingRight = UDim.new(0, 8)
	chipPadding.Parent = chip
	self.Chip, self.ChipStroke = chip, chipStroke
	return self
end

function MapRenderer:_colour()
	local colours = self.Colours
	if active and active.Kind == "Activity" then return colours.Activity or colour("ActivityColour", Color3.fromRGB(246, 83, 159)) end
	return colours.Line or colour("LineColour", Color3.fromRGB(43, 225, 218))
end

function MapRenderer:_segment(index)
	local line = self.Segments[index]
	if line then return line, self.Outlines[index] end
	local outline = Instance.new("Frame")
	outline.Name = "RouteOutline" .. index
	outline.AnchorPoint = Vector2.new(0.5, 0.5)
	outline.BorderSizePixel = 0
	outline.ZIndex = self.ZIndex
	outline.Parent = self.Layer
	line = Instance.new("Frame")
	line.Name = "RouteLine" .. index
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BorderSizePixel = 0
	line.ZIndex = self.ZIndex + 1
	line.Parent = self.Layer
	-- Pill-shaped segments: rounded caps overlap at each vertex, giving clean joints.
	for _, item in ipairs({ line, outline }) do
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = item
	end
	self.Segments[index], self.Outlines[index] = line, outline
	return line, outline
end

function MapRenderer:SetVisible(visible)
	if self.Layer.Visible ~= visible then self.Layer.Visible = visible end
	if not visible then
		self.Chip.Visible = false
		self.Pip.Visible = false
	end
end

-- state: { MapVisible, FullMapStuds, WorldCenter = Vector2, CoordinateCosine, CoordinateSine, FlipX, FlipZ,
--          PixelScale, MapRotationDegrees, LocalWorldPosition, MapSize, VisibleStuds }
function MapRenderer:Step(state)
	local visible = state.MapVisible == true and route ~= nil and active ~= nil and config:GetAttribute("Enabled") ~= false
	if not visible then
		self:SetVisible(false)
		return
	end
	self:SetVisible(true)
	local full = math.max(1, state.FullMapStuds)
	local centre = state.WorldCenter or Vector2.zero
	local cosine, sine = state.CoordinateCosine, state.CoordinateSine
	local function toCanvas(point)
		local dx, dz = point.X - centre.X, point.Y - centre.Y
		if state.FlipX then dx = -dx end
		if state.FlipZ then dz = -dz end
		local mx = dx * cosine - dz * sine
		local mz = dx * sine + dz * cosine
		return Vector2.new(0.5 + mx / full, 0.5 + mz / full)
	end
	local lineColour = self:_colour()
	local outlineColour = self.Colours.Outline or Color3.fromRGB(9, 12, 16)
	local pixelScale = math.max(1, state.PixelScale or 1)
	-- Widths are UI pixels; the canvas may be supersampled (PixelScale) and scaled back down.
	local width = number("LineWidth", 5, 1, 16) * pixelScale
	local outlineWidth = number("OutlineWidth", 1.5, 0, 6) * pixelScale
	local points = route.Points
	local first = math.clamp(progress.Segment or 1, 1, math.max(1, #points - 1))

	-- Full rebuild only when the route, style or scale changes; otherwise move the first segment.
	local rebuild = self.Version ~= route.Version or self.PixelScale ~= pixelScale or self.LineColour ~= lineColour
		or self.Width ~= width or self.OutlineWidth ~= outlineWidth
	local function place(index, fromPoint, toPoint)
		local line, outline = self:_segment(index)
		local a, b = toCanvas(fromPoint), toCanvas(toPoint)
		local delta = b - a
		local lengthScale = delta.Magnitude
		local mid = (a + b) / 2
		local angle = math.deg(math.atan2(delta.Y, delta.X))
		line.Position, outline.Position = UDim2.fromScale(mid.X, mid.Y), UDim2.fromScale(mid.X, mid.Y)
		line.Size = UDim2.new(lengthScale, width, 0, width)
		outline.Size = UDim2.new(lengthScale, width + 2 * outlineWidth, 0, width + 2 * outlineWidth)
		line.Rotation, outline.Rotation = angle, angle
		line.BackgroundColor3, outline.BackgroundColor3 = lineColour, outlineColour
		line.Visible, outline.Visible = true, outlineWidth > 0
	end
	if rebuild then
		self.Version, self.PixelScale, self.LineColour = route.Version, pixelScale, lineColour
		self.Width, self.OutlineWidth = width, outlineWidth
		for index = 1, #points - 1 do place(index, points[index], points[index + 1]) end
		for index = #points, #self.Segments do
			self.Segments[index].Visible = false
			self.Outlines[index].Visible = false
		end
		self.Shown = 1
	end
	if first ~= self.Shown then
		for index = 1, #points - 1 do
			local show = index >= first
			self.Segments[index].Visible, self.Outlines[index].Visible = show, show and outlineWidth > 0
		end
		if self.Shown and self.Shown > first then
			for index = first + 1, math.min(self.Shown, #points - 1) do place(index, points[index], points[index + 1]) end
		end
		self.Shown = first
	end
	if progress.Point and first <= #points - 1 then place(first, progress.Point, points[first + 1]) end

	local goal = points[#points]
	local goalCanvas = toCanvas(goal)
	self.Blip.Position = UDim2.fromScale(goalCanvas.X, goalCanvas.Y)
	local blipSize = math.max(8 * pixelScale, width + 3 * pixelScale)
	self.Blip.Size = UDim2.fromOffset(blipSize, blipSize)
	self.Blip.BackgroundColor3 = lineColour
	self.BlipStroke.Color = outlineColour
	self.BlipStroke.Thickness = pixelScale
	self.Blip.Visible = true

	-- Edge pip when the destination is outside the visible map.
	local here = state.LocalWorldPosition
	local mapSize = math.max(1, state.MapSize or 1)
	local uiPerStud = mapSize / math.max(1, state.VisibleStuds or 1)
	local dx, dz = goal.X - here.X, goal.Y - here.Z
	if state.FlipX then dx = -dx end
	if state.FlipZ then dz = -dz end
	local mx, mz = dx * cosine - dz * sine, dx * sine + dz * cosine
	local rotation = math.rad(state.MapRotationDegrees or 0)
	local rx = (mx * math.cos(rotation) - mz * math.sin(rotation)) * uiPerStud
	local rz = (mx * math.sin(rotation) + mz * math.cos(rotation)) * uiPerStud
	local limit = mapSize * 0.5 - 10
	local outside = math.max(math.abs(rx), math.abs(rz))
	if outside > limit then
		local scale = limit / outside
		self.Pip.Position = UDim2.fromScale(0.5 + rx * scale / mapSize, 0.5 + rz * scale / mapSize)
		self.Pip.BackgroundColor3 = lineColour
		self.PipStroke.Color = outlineColour
		self.Pip.Visible = true
	else
		self.Pip.Visible = false
	end

	if config:GetAttribute("ChipEnabled") ~= false then
		self.Chip.Text = active.Label .. "   " .. RoadRouting.FormatDistance(progress.Remaining or 0, number("StudsPerMile", 5760, 100, 100000))
		self.Chip.BackgroundColor3 = self.Colours.ChipBackground or outlineColour
		self.Chip.BackgroundTransparency = 0.15
		self.Chip.TextColor3 = self.Colours.ChipText or Color3.new(1, 1, 1)
		self.ChipStroke.Color = lineColour
		self.Chip.Visible = true
	else
		self.Chip.Visible = false
	end
end

function MapRenderer:Destroy()
	self.Layer:Destroy()
	self.Chip:Destroy()
	self.Pip:Destroy()
end

return RouteGuide
