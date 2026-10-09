-- Owns the map canvas of one map surface (tile set, pan, zoom, rotation, culling) and the shared view maths; not the map state, the icons, the route line or any ScreenGui.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Map.MapCanvas. Requires: none at load (UI.MapMath and UI.MapTileSet lazily through seams).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapCanvas = {}

local warned = {}
local function warnOnce(message)
	if warned[message] then
		return
	end
	warned[message] = true
	warn("[Pulse.MapCanvas] " .. message)
end

-- The shared, look-free Classic map modules (API2 5.4). FindFirstChild only: never yields on a missing module.
local function sharedModule(name)
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local gameFolder = modules and modules:FindFirstChild("Game")
	local ui = gameFolder and gameFolder:FindFirstChild("UI")
	local module = ui and ui:FindFirstChild(name)
	assert(module, "[Pulse.MapCanvas] ReplicatedStorage.Modules.Game.UI." .. name .. " is missing")
	return require(module)
end

-- Test seams: a pure test replaces these with fakes and puts them back.
MapCanvas._math = function()
	return sharedModule("MapMath")
end
MapCanvas._tiles = function()
	return sharedModule("MapTileSet")
end
MapCanvas._hudConfig = function()
	local config = ReplicatedStorage:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	return ui and ui:FindFirstChild("DesktopFreeRoamHud")
end

local Math
local function math2()
	if not Math then
		Math = MapCanvas._math()
	end
	return Math
end
-- Loads UI.MapMath once. Every New and Calibration calls it, so the step functions below read the upvalue only.
MapCanvas._load = math2
MapCanvas._reset = function()
	Math = nil
	MapCanvas._calibration = nil
end

-- FullMapUI 63-69: a ValueBase child wins, then the attribute, then the fallback.
local function readValue(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA("ValueBase") then
		return item.Value
	end
	local attribute = folder and folder:GetAttribute(name)
	if attribute ~= nil then
		return attribute
	end
	return fallback
end
MapCanvas._readValue = readValue

-- FullMapUI 96-107, cached for the session.
function MapCanvas.Calibration(): any
	if MapCanvas._calibration then
		return MapCanvas._calibration
	end
	local hud = MapCanvas._hudConfig()
	local layout = hud and hud:FindFirstChild("Layout")
	local defaults = hud and hud:FindFirstChild("Defaults")
	if not hud then
		warnOnce("Config.UI.DesktopFreeRoamHud is missing; the map uses the default calibration")
	end
	local calibration = math2().Calibration({
		MapPixels = readValue(layout, "MapPixels", nil),
		MapCalibrationPixels = readValue(layout, "MapCalibrationPixels", nil),
		MapCalibrationStuds = readValue(layout, "MapCalibrationStuds", nil),
		MapWorldCenterX = readValue(layout, "MapWorldCenterX", nil),
		MapWorldCenterZ = readValue(layout, "MapWorldCenterZ", nil),
		MapCoordinateRotationDegrees = readValue(layout, "MapCoordinateRotationDegrees", nil),
		MapFlipX = readValue(defaults, "MapFlipX", false) == true,
		MapFlipZ = readValue(defaults, "MapFlipZ", false) == true,
	})
	MapCanvas._calibration = calibration
	return calibration
end

-- Pixel side of the whole canvas for a view (MapMath.CanvasSide over the view's shorter side). Pure.
function MapCanvas.Side(view: any): number
	local short = math.max(1, math.min(view.Size.X, view.Size.Y))
	return Math.CanvasSide(view.Calibration.FullStuds, short, view.VisibleStuds)
end

-- Fills `out` with the per-frame constants of a view, so many points can be projected without repeating them.
-- Perf.Bind-safe: arithmetic only. Returns out.
function MapCanvas.Frame(view: any, out: any): any
	local side = MapCanvas.Side(view)
	local cu, cv = Math.WorldToUnit(view.Calibration, view.CentreX, view.CentreZ)
	local radians = math.rad(view.RotationDegrees or 0)
	out.Side = side
	out.CU, out.CV = cu, cv
	out.Cos, out.Sin = math.cos(radians), math.sin(radians)
	out.HalfX, out.HalfY = view.Size.X * 0.5, view.Size.Y * 0.5
	return out
end

-- World (x, z) -> view pixels with a filled frame. Same maths as MapMath.MinimapPoint (rotating map) and
-- MapMath.UnitToScreen (full map, rotation 0). Perf.Bind-safe.
function MapCanvas.Point(frame: any, calibration: any, x: number, z: number): (number, number)
	local u, v = Math.WorldToUnit(calibration, x, z)
	local mx, my = (u - frame.CU) * frame.Side, (v - frame.CV) * frame.Side
	return frame.HalfX + mx * frame.Cos - my * frame.Sin, frame.HalfY + mx * frame.Sin + my * frame.Cos
end

-- Map units -> view pixels with a filled frame (the route layer keeps its points in units).
function MapCanvas.UnitPoint(frame: any, u: number, v: number): (number, number)
	local mx, my = (u - frame.CU) * frame.Side, (v - frame.CV) * frame.Side
	return frame.HalfX + mx * frame.Cos - my * frame.Sin, frame.HalfY + mx * frame.Sin + my * frame.Cos
end

-- One-off projection (events and tests). Allocates; a frame step uses Frame and Point.
function MapCanvas.Project(view: any, x: number, z: number): (number, number)
	math2()
	return MapCanvas.Point(MapCanvas.Frame(view, {}), view.Calibration, x, z)
end

-- Half extents, in map units, of the box that covers the view. A rotated or round view uses its diagonal.
function MapCanvas.HalfExtents(view: any, side: number): (number, number)
	local w, h = view.Size.X, view.Size.Y
	if view.Round or (view.RotationDegrees or 0) ~= 0 then
		local half = 0.5 * math.sqrt(w * w + h * h) / side
		return half, half
	end
	return w * 0.5 / side, h * 0.5 / side
end

local function round(value)
	return math.floor(value + 0.5)
end

local function plain(name, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

function MapCanvas.New(content: Frame, props: { ZIndex: number? }?, scope: any): any
	assert(typeof(content) == "Instance" and content:IsA("GuiObject"), "[Pulse.MapCanvas] New needs a content GuiObject")
	local options = props or {}
	for key in options do
		if key ~= "ZIndex" then
			error("[Pulse.MapCanvas] unknown key " .. tostring(key), 2)
		end
	end
	math2()
	local zIndex = math.floor(tonumber(options.ZIndex) or 1)

	-- The rotator is a zero-size frame at the view centre; the canvas hangs from it so the map turns about the
	-- point under the view centre, as the Classic HUD rotator does.
	local rotator = plain("MapRotator", nil)
	rotator.ZIndex = zIndex
	local canvas = plain("MapCanvas", rotator)
	canvas.ZIndex = zIndex
	rotator.Parent = content

	local tiles = MapCanvas._tiles().new({ Canvas = canvas, ZIndex = zIndex })

	local frame = {}
	local lastSide, lastX, lastY, lastRotation, lastCentreX, lastCentreY
	local destroyed = false
	local self = { Canvas = canvas, Complete = tiles.Complete == true }

	function self.Step(view)
		if destroyed then
			return
		end
		MapCanvas.Frame(view, frame)
		local side = math.max(1, round(frame.Side))
		local centreX, centreY = round(frame.HalfX), round(frame.HalfY)
		if centreX ~= lastCentreX or centreY ~= lastCentreY then
			lastCentreX, lastCentreY = centreX, centreY
			rotator.Position = UDim2.fromOffset(centreX, centreY)
		end
		local rotation = round((view.RotationDegrees or 0) * 2) / 2
		if rotation ~= lastRotation then
			lastRotation = rotation
			rotator.Rotation = rotation
		end
		if side ~= lastSide then
			lastSide = side
			canvas.Size = UDim2.fromOffset(side, side)
		end
		local x, y = round(-frame.CU * frame.Side), round(-frame.CV * frame.Side)
		if x ~= lastX or y ~= lastY then
			lastX, lastY = x, y
			canvas.Position = UDim2.fromOffset(x, y)
		end
		local halfU, halfV = MapCanvas.HalfExtents(view, frame.Side)
		tiles:Cull(frame.CU - halfU, frame.CU + halfU, frame.CV - halfV, frame.CV + halfV)
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		tiles:Destroy()
		rotator:Destroy()
	end

	if scope then
		scope:add(self.Destroy)
	end
	return self
end

return MapCanvas
