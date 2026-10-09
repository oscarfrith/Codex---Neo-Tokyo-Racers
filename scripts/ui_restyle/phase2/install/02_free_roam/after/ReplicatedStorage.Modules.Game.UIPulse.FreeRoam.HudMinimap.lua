-- Owns the free-roam minimap: the Kit.Minimap frame, the shared map layers inside it and the per-frame map maths; not the full map, map data or route planning.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.HudMinimap. Requires: Kit.Tokens, Kit.Metrics, Kit.Minimap, Map.MapCanvas, Map.MapIcons, Map.MapRoute (resolved on the first mount).
--
-- Classic line references: D = DesktopFreeRoamHudUI, M = MobileFreeRoamHudUI.
-- deps (nil in the gallery: the frame alone is built, no map layer and no frame work) = {
--   Markers (the shared FreeRoamMapPlayerMarkers module), MarkersConfig (Config.UI.FreeRoamMapPlayerMarkers),
--   RouteGuide (the shared module), Player,
--   Layout = { MapVisibleStuds, MapRotationOffsetDegrees, MapSmoothing, IconRotates,
--              ZoomEnabled, ZoomStartMph, ZoomFullMph, ZoomMaxFactor, ZoomOutResponse, ZoomInResponse } }   cached at start

local Workspace = game:GetService("Workspace")

local ROUTE_REFRESH_SECONDS = 0.1 -- RouteGuide progresses at ProgressHz (10); its state is copied no more often
local MARKER_ATTRIBUTES = { "MapRotationMode", "MapNorthArrowMode", "MapRotationResponse", "MapNorthOrbitInset", "MapPanResponse" }

local HudMinimap = {}

local modulesCache
local function modules()
	if not modulesCache then
		local pulse = script.Parent.Parent
		modulesCache = {
			Tokens = require(pulse.Kit.Tokens),
			Metrics = require(pulse.Kit.Metrics),
			Minimap = require(pulse.Kit.Minimap),
			MapCanvas = require(pulse.Map.MapCanvas),
			MapIcons = require(pulse.Map.MapIcons),
			MapRoute = require(pulse.Map.MapRoute),
		}
	end
	return modulesCache
end
HudMinimap._modules = modules -- test seam: a test may replace the cache through _setModules
function HudMinimap._setModules(replacement) modulesCache = replacement end

-- Pure: half-degree quantiser used for every rotation write (PC 5.1 rule 5).
function HudMinimap._quantise(degrees)
	return math.floor(degrees * 2 + 0.5) / 2
end

-- Pure: D133-151 with the step's dt (Classic measures the same interval with os.clock, clamped to 0.25 s).
function HudMinimap._zoomStep(factor, mph, dt, layout)
	if layout.ZoomEnabled == false or mph == nil then return 1 end
	local startMph = layout.ZoomStartMph
	local fullMph = math.max(startMph + 1, layout.ZoomFullMph)
	local target = 1 + (layout.ZoomMaxFactor - 1) * math.clamp((mph - startMph) / (fullMph - startMph), 0, 1)
	local response = target > factor and layout.ZoomOutResponse or layout.ZoomInResponse
	return factor + (target - factor) * (1 - math.exp(-response * math.clamp(dt, 0, 0.25)))
end

-- Pure: the cached layout numbers with Classic's fallbacks and clamps (D143-148, D1152, D1194).
function HudMinimap._layout(raw)
	raw = raw or {}
	local startMph = tonumber(raw.ZoomStartMph) or 40
	return {
		MapVisibleStuds = math.max(100, tonumber(raw.MapVisibleStuds) or 2850),
		MapRotationOffsetDegrees = tonumber(raw.MapRotationOffsetDegrees) or 0,
		MapSmoothing = tonumber(raw.MapSmoothing) or 10,
		IconRotates = raw.IconRotates ~= false,
		ZoomEnabled = raw.ZoomEnabled ~= false,
		ZoomStartMph = startMph,
		ZoomFullMph = tonumber(raw.ZoomFullMph) or 200,
		ZoomMaxFactor = math.clamp(tonumber(raw.ZoomMaxFactor) or 1.8, 1, 4),
		ZoomOutResponse = tonumber(raw.ZoomOutResponse) or 1.6,
		ZoomInResponse = tonumber(raw.ZoomInResponse) or 0.8,
	}
end

-- parent is the layer's Minimap slot. props = { Size: number (design diameter), OnActivated }.
function HudMinimap.Mount(parent, props, deps, scope)
	local m = modules()
	local ctx = m.Metrics.Of(parent)
	local compact = ctx.Class == "Compact"
	local space = m.Tokens.Space

	local frame = m.Minimap.New(parent, {
		Size = props.Size,
		ShowRank = true,
		OnActivated = props.OnActivated,
	}, scope)
	frame.Instance.AnchorPoint = parent.AnchorPoint
	frame.Instance.Position = UDim2.new()

	local self = { Component = frame, Instance = frame.Instance }
	local shownRank, shownFraction

	function self.SetRank(rank, fraction)
		if rank == shownRank and fraction == shownFraction then return end
		shownRank, shownFraction = rank, fraction
		frame.SetRank(rank, fraction)
	end

	function self.SetVisible(visible)
		frame.Set({ Visible = visible })
	end

	function self.Destroy()
		frame.Destroy()
	end

	if deps == nil then
		function self.Step() end
		function self.Idle() end
		return self
	end

	local markers = deps.Markers
	local markersConfig = deps.MarkersConfig
	local routeGuide = deps.RouteGuide
	local player = deps.Player
	local layout = HudMinimap._layout(deps.Layout)

	local mapPx = ctx.Px(props.Size)
	-- Token requests (NOTES_a): MinimapIconSize, CompactMinimapIconSize, MapRouteWidth. Until they exist the nearest
	-- existing tokens are used: Pad 22 (Classic MapPlayerIconSize 22), CompactMargin 12 dp, TabUnderline 4.
	local iconSize = compact and space.CompactMargin or space.Pad
	local calibration = m.MapCanvas.Calibration()

	local canvas = m.MapCanvas.New(frame.Content, { ZIndex = 1 }, scope)
	local route = m.MapRoute.New(canvas.Canvas, frame.Overlay, { Width = space.TabUnderline }, scope)
	local icons = m.MapIcons.New(frame.Content, frame.Overlay, { IconSize = iconSize, FullMap = false }, scope)
	local others = markers.new({ Container = frame.Content, Config = markersConfig, ZIndex = 3 })
	scope:add(function() others:Destroy() end)

	-- One table each, filled in place every step: no allocation per frame.
	local view = {
		Calibration = calibration, CentreX = 0, CentreZ = 0, VisibleStuds = layout.MapVisibleStuds, RotationDegrees = 0,
		Size = Vector2.new(mapPx, mapPx), Round = true, FullMap = false,
	}
	local markerState = {
		MapRotationDegrees = 0, MapVisible = true, LocalWorldPosition = Vector3.zero, MapSize = mapPx,
		VisibleStuds = layout.MapVisibleStuds, CoordinateRadians = calibration.Radians, CoordinateCosine = calibration.Cos,
		CoordinateSine = calibration.Sin, FlipX = calibration.FlipX, FlipZ = calibration.FlipZ,
		LocalMarkerSize = ctx.Px(iconSize),
	}

	-- D1211 and D1194 read these every frame; here they are re-read only when an input changes.
	local rotation, panResponse
	local function resolveRotation()
		rotation = markers.ResolveRotation(markersConfig, player)
		panResponse = math.max(0, tonumber(markersConfig:GetAttribute("MapPanResponse")) or layout.MapSmoothing)
	end
	resolveRotation()
	scope:connect(player:GetAttributeChangedSignal("MinimapMode"), resolveRotation)
	for _, name in ipairs(MARKER_ATTRIBUTES) do
		scope:connect(markersConfig:GetAttributeChangedSignal(name), resolveRotation)
	end

	local hasRouteState = type(routeGuide.GetRouteState) == "function"
	local routeState
	local routeDirty = true
	local routeClock = 0
	if hasRouteState then
		scope:connect(routeGuide.Changed, function() routeDirty = true end)
	end

	local centreX, centreZ
	local playerHeading
	local mapHeading
	local zoomFactor = 1
	local lastArrow, lastNorth
	local layersHidden = false

	local function hideLayers()
		if layersHidden then return end
		layersHidden = true
		others:SetVisible(false)
		icons.SetVisible(false)
		route.SetVisible(false)
	end

	-- No subject this frame (D1265-1269).
	function self.Idle()
		hideLayers()
	end

	-- part: the map subject. zoomPart: the owned vehicle root while driving, else nil (D1152). shown: the minimap is
	-- on screen. Perf.Bind-safe: no lookup, no creation; every write is behind a comparison here or in the callee.
	-- Makes the frame's one RouteGuide.Update call (D1250), also while the minimap is hidden by the car panel.
	function self.Step(dt, part, zoomPart, shown)
		local position = part.Position
		routeGuide.Update(position)
		if not shown then
			hideLayers()
			return
		end
		if layersHidden then
			layersHidden = false
			icons.SetVisible(true)
			route.SetVisible(true)
		end

		local mph
		if zoomPart then
			local velocity = zoomPart.AssemblyLinearVelocity
			mph = math.sqrt(velocity.X * velocity.X + velocity.Z * velocity.Z) * 0.625
		end
		zoomFactor = HudMinimap._zoomStep(zoomFactor, mph, dt, layout)
		local visibleStuds = layout.MapVisibleStuds * zoomFactor

		-- D1193-1199: the map centre and the player heading ease with the same response.
		local alpha = panResponse <= 0 and 1 or 1 - math.exp(-panResponse * math.max(0, dt))
		if centreX == nil then
			centreX, centreZ = position.X, position.Z
		else
			centreX += (position.X - centreX) * alpha
			centreZ += (position.Z - centreZ) * alpha
		end
		local heading = markers.MapHeading(part.CFrame.LookVector, calibration.Cos, calibration.Sin, calibration.FlipX, calibration.FlipZ)
		if heading then
			local target = heading + layout.MapRotationOffsetDegrees
			if playerHeading == nil then playerHeading = target end
			playerHeading += ((target - playerHeading + 180) % 360 - 180) * alpha
		end

		-- D1211-1222.
		local mapTarget = 0
		if rotation.Mode == "Camera" then
			local camera = Workspace.CurrentCamera
			mapTarget = camera and markers.MapHeading(camera.CFrame.LookVector, calibration.Cos, calibration.Sin, calibration.FlipX, calibration.FlipZ) or mapHeading
		elseif rotation.Mode == "Subject" then
			mapTarget = heading
		end
		mapHeading = markers.StepHeading(mapHeading, mapTarget, rotation.Response, dt)
		local mapRotation = -mapHeading

		local north = HudMinimap._quantise(mapRotation)
		if north ~= lastNorth then
			lastNorth = north
			frame.SetHeading(north)
		end
		-- D1223.
		local arrow = HudMinimap._quantise(layout.IconRotates and ((playerHeading or 0) + mapRotation) or mapRotation)
		if arrow ~= lastArrow then
			lastArrow = arrow
			frame.SetArrow(arrow)
		end

		view.CentreX = centreX
		view.CentreZ = centreZ
		view.VisibleStuds = visibleStuds
		view.RotationDegrees = mapRotation
		canvas.Step(view)
		icons.Step(view)

		if hasRouteState then
			routeClock += dt
			if routeDirty or routeClock >= ROUTE_REFRESH_SECONDS then
				routeDirty = false
				routeClock = 0
				routeState = routeGuide.GetRouteState()
			end
			route.Step(view, routeState)
		end

		markerState.MapRotationDegrees = mapRotation
		markerState.LocalWorldPosition = position
		markerState.VisibleStuds = visibleStuds
		others:Step(dt, markerState)
	end

	return self
end

return HudMinimap
