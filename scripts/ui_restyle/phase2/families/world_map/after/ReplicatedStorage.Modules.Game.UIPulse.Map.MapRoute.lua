-- Owns the Pulse route line of one map surface (at most 64 pooled segments clipped to the view, the distance chip, the minimap edge pip); not the route itself (UI.RouteGuide owns it and its Update), the canvas or the icons.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Map.MapRoute. Requires: Tokens, Metrics, Collections, Map.MapCanvas (UI.MapMath lazily through MapCanvas).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Metrics = require(Kit.Metrics)
local Collections = require(Kit.Collections)
local MapCanvas = require(script.Parent.MapCanvas)

local MapRoute = {}

MapRoute.MaxSegments = 64
local MARGIN = 1.5 -- the clip box is this much larger than the view, so a small pan re-clips nothing
local DEFAULT_STUDS_PER_MILE = 5760 -- RouteGuide 395

-- Test seam: Config.UI.RouteGuide (StudsPerMile, ChipEnabled, Enabled), read once per New.
MapRoute._config = function()
	local config = ReplicatedStorage:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	return ui and ui:FindFirstChild("RouteGuide")
end

-- RoadRouting.FormatDistance, copied (that module is not on the shared list). Pure.
function MapRoute.FormatDistance(studs: number, studsPerMile: number?): string
	local miles = math.max(0, studs) / math.max(1, studsPerMile or DEFAULT_STUDS_PER_MILE)
	if miles < 0.1 then
		return "<0.1 MI"
	end
	return string.format("%.1f MI", miles)
end

local function overlaps(us, vs, a, b, uMin, uMax, vMin, vMax)
	local u0, u1, v0, v1 = us[a], us[b], vs[a], vs[b]
	if u0 > u1 then
		u0, u1 = u1, u0
	end
	if v0 > v1 then
		v0, v1 = v1, v0
	end
	return u1 >= uMin and u0 <= uMax and v1 >= vMin and v0 <= vMax
end

local function pass(us, vs, count, first, uMin, uMax, vMin, vMax, stride, out)
	local n = 0
	local index = first
	while index < count do
		local nextIndex = math.min(index + stride, count)
		if overlaps(us, vs, index, nextIndex, uMin, uMax, vMin, vMax) then
			n += 1
			if out then
				out[n * 2 - 1], out[n * 2] = index, nextIndex
			end
		end
		index = nextIndex
	end
	return n
end

-- Chooses the segments to draw: those from point `first` on whose box overlaps the clip box. When more than
-- `maxSegments` qualify, every 2nd, 4th ... point is used instead, so the whole visible route is still drawn.
-- us, vs: the route in map units. out receives pairs (from index, to index). Returns the pair count. Pure.
function MapRoute.Clip(us: { number }, vs: { number }, count: number, first: number, uMin: number, uMax: number, vMin: number, vMax: number, maxSegments: number, out: { number }): number
	if count < 2 or maxSegments < 1 then
		return 0
	end
	first = math.clamp(first, 1, count - 1)
	local stride = 1
	local n = pass(us, vs, count, first, uMin, uMax, vMin, vMax, stride, nil)
	while n > maxSegments do
		stride *= 2
		n = pass(us, vs, count, first, uMin, uMax, vMin, vMax, stride, nil)
	end
	return pass(us, vs, count, first, uMin, uMax, vMin, vMax, stride, out)
end

function MapRoute.New(canvas: Frame, overlay: Frame, props: { Width: number }, scope: any): any
	assert(typeof(canvas) == "Instance" and canvas:IsA("GuiObject"), "[Pulse.MapRoute] New needs the canvas GuiObject")
	assert(typeof(overlay) == "Instance" and overlay:IsA("GuiObject"), "[Pulse.MapRoute] New needs an overlay GuiObject")
	assert(type(props) == "table" and type(props.Width) == "number", "[Pulse.MapRoute] New needs Width")
	for key in props do
		if key ~= "Width" then
			error("[Pulse.MapRoute] unknown key " .. tostring(key), 2)
		end
	end

	local Math = MapCanvas._load()
	local ctx = Metrics.Of(overlay)
	local cyan = Tokens.Colour.Cyan
	local config = MapRoute._config()
	local enabled = not (config and config:GetAttribute("Enabled") == false)
	local chipEnabled = not (config and config:GetAttribute("ChipEnabled") == false)
	local studsPerMile = math.clamp(tonumber(config and config:GetAttribute("StudsPerMile")) or DEFAULT_STUDS_PER_MILE, 100, 100000)

	-- Segments are placed in canvas scale units (as RouteGuide's renderer does), so a pan, a zoom and a map
	-- rotation write nothing here.
	local holder = Instance.new("Frame")
	holder.Name = "RouteLine"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = canvas.ZIndex + 1
	holder.Visible = false
	holder.Parent = canvas

	local segments = table.create(MapRoute.MaxSegments)
	for index = 1, MapRoute.MaxSegments do
		local segment = Instance.new("Frame")
		segment.Name = "Segment" .. tostring(index)
		segment.AnchorPoint = Vector2.new(0.5, 0.5)
		segment.BackgroundColor3 = cyan
		segment.BorderSizePixel = 0
		segment.Visible = false
		segment.Parent = holder
		segments[index] = segment
	end

	local pip = Instance.new("Frame")
	pip.Name = "RouteEdgePip"
	pip.AnchorPoint = Vector2.new(0.5, 0.5)
	pip.BackgroundColor3 = cyan
	pip.BorderSizePixel = 0
	pip.Rotation = 45
	pip.Visible = false
	pip.ZIndex = 4
	pip.Parent = overlay

	local chip = Collections.Chip(overlay, { Name = "RouteChip", Text = "", Kind = "Cyan", Visible = false }, scope)
	chip.Instance.AnchorPoint = Vector2.new(0.5, 0)
	chip.Instance.ZIndex = 5

	local widthPx, pipPx, gapPx = 1, 1, 1
	local us, vs, chosen = {}, {}, {}
	local fromU, fromV, toU, toV = {}, {}, {}, {}
	local segmentShown = {}
	local frame = {}
	local count, used = 0, 0
	local version, lastCalibration = nil, nil
	local boxValid, boxFirst, boxHalf = false, 0, 0
	local boxUMin, boxUMax, boxVMin, boxVMax = 0, 0, 0, 0
	local visible, layerShown = true, false
	local chipShown, chipKey, chipLabel, chipX = false, nil, nil, nil
	local pipShown, pipX, pipY = false, nil, nil
	local destroyed = false

	local function measure()
		widthPx = math.max(1, ctx.Px(props.Width))
		pipPx = math.max(1, ctx.Px(Tokens.Space.Gap))
		gapPx = ctx.Px(Tokens.Space.Gap)
		pip.Size = UDim2.fromOffset(pipPx, pipPx)
		table.clear(fromU) -- forces every shown segment to be written again with the new width
		boxValid = false
		chipX = nil
	end
	measure()

	local function place(index, au, av, bu, bv)
		if fromU[index] == au and fromV[index] == av and toU[index] == bu and toV[index] == bv then
			return
		end
		fromU[index], fromV[index], toU[index], toV[index] = au, av, bu, bv
		local du, dv = bu - au, bv - av
		local segment = segments[index]
		segment.Position = UDim2.fromScale((au + bu) * 0.5, (av + bv) * 0.5)
		segment.Size = UDim2.new(math.sqrt(du * du + dv * dv), widthPx, 0, widthPx)
		segment.Rotation = math.deg(math.atan2(dv, du))
		if not segmentShown[index] then
			segmentShown[index] = true
			segment.Visible = true
		end
	end

	local function assign(n)
		for index = 1, n do
			local a, b = chosen[index * 2 - 1], chosen[index * 2]
			place(index, us[a], vs[a], us[b], vs[b])
		end
		for index = n + 1, used do
			if segmentShown[index] then
				segmentShown[index] = false
				segments[index].Visible = false
			end
		end
		used = n
	end

	local function setLayer(show)
		if layerShown ~= show then
			layerShown = show
			holder.Visible = show
		end
		if not show then
			if chipShown then
				chipShown = false
				chip.Instance.Visible = false
			end
			if pipShown then
				pipShown = false
				pip.Visible = false
			end
		end
	end

	local self = {}

	-- routeState: RouteGuide.GetRouteState() ({Points = {Vector2 (x, z)}, Version, Segment, Point, Remaining, Active}).
	function self.Step(view, routeState)
		if destroyed then
			return
		end
		local points = routeState and routeState.Points
		local active = routeState and routeState.Active
		if not (visible and enabled and points and active and #points >= 2) then
			setLayer(false)
			return
		end
		setLayer(true)

		local calibration = view.Calibration
		if routeState.Version ~= version or calibration ~= lastCalibration then
			version, lastCalibration = routeState.Version, calibration
			count = #points
			for index = 1, count do
				local point = points[index]
				us[index], vs[index] = Math.WorldToUnit(calibration, point.X, point.Y)
			end
			boxValid = false
		end

		MapCanvas.Frame(view, frame)
		local first = math.clamp(routeState.Segment or 1, 1, math.max(1, count - 1))
		local halfU, halfV = MapCanvas.HalfExtents(view, frame.Side)
		local cu, cv = frame.CU, frame.CV
		if not boxValid or first ~= boxFirst or halfU * (MARGIN * 2) < boxHalf
			or cu - halfU < boxUMin or cu + halfU > boxUMax or cv - halfV < boxVMin or cv + halfV > boxVMax then
			boxValid, boxFirst, boxHalf = true, first, halfU * MARGIN
			boxUMin, boxUMax = cu - halfU * MARGIN, cu + halfU * MARGIN
			boxVMin, boxVMax = cv - halfV * MARGIN, cv + halfV * MARGIN
			assign(MapRoute.Clip(us, vs, count, first, boxUMin, boxUMax, boxVMin, boxVMax, MapRoute.MaxSegments, chosen))
		end

		-- The first drawn segment starts at the progress point (RouteGuide 364).
		local progress = routeState.Point
		if progress and used > 0 and chosen[1] == first then
			local pu, pv = Math.WorldToUnit(calibration, progress.X, progress.Y)
			local target = chosen[2]
			place(1, pu, pv, us[target], vs[target])
		end

		if chipEnabled then
			local remaining = math.max(0, routeState.Remaining or 0)
			local miles = remaining / studsPerMile
			local key = miles < 0.1 and -1 or math.floor(miles * 10 + 0.5)
			local label = active.Label
			if key ~= chipKey or label ~= chipLabel then
				chipKey, chipLabel = key, label
				chip.Set({ Text = tostring(label or "WAYPOINT") .. " · " .. MapRoute.FormatDistance(remaining, studsPerMile) })
			end
			local x = math.floor(frame.HalfX + 0.5)
			if x ~= chipX then
				chipX = x
				chip.Instance.Position = UDim2.fromOffset(x, gapPx)
			end
			if not chipShown then
				chipShown = true
				chip.Instance.Visible = true
			end
		end

		-- Edge pip: only on the minimap, only while the destination is outside the view (RouteGuide 370-390).
		local show = false
		if not view.FullMap then
			local gx, gy = MapCanvas.UnitPoint(frame, us[count], vs[count])
			local ox, oy = gx - frame.HalfX, gy - frame.HalfY
			local scale = 1
			if view.Round then
				local limit = math.max(1, math.min(frame.HalfX, frame.HalfY) - pipPx)
				local distance = math.sqrt(ox * ox + oy * oy)
				if distance > limit then
					scale = limit / distance
					show = true
				end
			else
				local limitX, limitY = math.max(1, frame.HalfX - pipPx), math.max(1, frame.HalfY - pipPx)
				local outside = math.max(math.abs(ox) / limitX, math.abs(oy) / limitY)
				if outside > 1 then
					scale = 1 / outside
					show = true
				end
			end
			if show then
				local x, y = math.floor(frame.HalfX + ox * scale + 0.5), math.floor(frame.HalfY + oy * scale + 0.5)
				if x ~= pipX or y ~= pipY then
					pipX, pipY = x, y
					pip.Position = UDim2.fromOffset(x, y)
				end
			end
		end
		if show ~= pipShown then
			pipShown = show
			pip.Visible = show
		end
	end

	function self.SetVisible(show: boolean)
		visible = show == true
		if not visible then
			setLayer(false)
		end
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		holder:Destroy()
		pip:Destroy()
		chip.Destroy()
	end

	scope:connect(ctx.Changed, function(change)
		if type(change) ~= "table" or change.Layout then
			measure()
		end
	end)
	scope:add(self.Destroy)
	return self
end

return MapRoute
