-- Pure tests for MapMath (world <-> map transforms, minimap placement, edge clamp, zoom/pan maths).
-- Run in Studio Edit with scripts/ served on 127.0.0.1:8767; no game module require, no instances.
local Http = game:GetService("HttpService")
local MapMath = assert(loadstring(Http:GetAsync("http://127.0.0.1:8767/map_ui/MapMath.lua")))()
local results, failures = {}, 0
local function check(name, ok, detail)
	if not ok then failures += 1 end
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function near(a, b, tolerance) return math.abs(a - b) <= (tolerance or 1e-4) end
local function nearV(a, b, tolerance) return near(a.X, b.X, tolerance) and near(a.Y, b.Y, tolerance) end

-- Calibration (live values: 2048 px, 207 px = 2850 studs, 90 degrees, centre 0,0, no flips)
local live = MapMath.Calibration({ MapPixels = 2048, MapCalibrationPixels = 207, MapCalibrationStuds = 2850, MapCoordinateRotationDegrees = 90 })
check("full map studs", near(live.FullStuds, 2048 * 2850 / 207, 1e-6), live.FullStuds)
check("defaults match live layout", near(MapMath.Calibration({}).FullStuds, live.FullStuds, 1e-6))
check("bad numbers fall back", near(MapMath.Calibration({ MapPixels = 0 / 0, MapCalibrationPixels = math.huge }).FullStuds, live.FullStuds, 1e-6))

-- World -> map units
local u, v = MapMath.WorldToUnit(live, 0, 0)
check("world centre is canvas centre", near(u, 0.5) and near(v, 0.5))
u, v = MapMath.WorldToUnit(live, 1000, 0)
check("+X maps down at 90 degrees", near(u, 0.5) and near(v, 0.5 + 1000 / live.FullStuds))
u, v = MapMath.WorldToUnit(live, 0, -1000)
check("-Z maps right at 90 degrees", near(u, 0.5 + 1000 / live.FullStuds) and near(v, 0.5))

-- Same formula as RouteGuide's renderer toCanvas
local function routeGuideCanvas(cal, x, z)
	local dx, dz = x - cal.CenterX, z - cal.CenterZ
	if cal.FlipX then dx = -dx end
	if cal.FlipZ then dz = -dz end
	return 0.5 + (dx * cal.Cos - dz * cal.Sin) / cal.FullStuds, 0.5 + (dx * cal.Sin + dz * cal.Cos) / cal.FullStuds
end
local odd = MapMath.Calibration({ MapCoordinateRotationDegrees = 37, MapWorldCenterX = 120, MapWorldCenterZ = -80, MapFlipX = true, MapFlipZ = false })
local ru, rv = routeGuideCanvas(odd, 731.3, -1747.9)
u, v = MapMath.WorldToUnit(odd, 731.3, -1747.9)
check("matches RouteGuide canvas transform", near(u, ru, 1e-9) and near(v, rv, 1e-9))

-- Round trips across rotations and flips
local worst = 0
for _, degrees in ipairs({ 0, 90, 180, 270, 37 }) do
	for _, flips in ipairs({ { false, false }, { true, false }, { false, true }, { true, true } }) do
		local cal = MapMath.Calibration({ MapCoordinateRotationDegrees = degrees, MapWorldCenterX = 55, MapWorldCenterZ = -20, MapFlipX = flips[1], MapFlipZ = flips[2] })
		for _, point in ipairs({ { 731.3, -1747.9 }, { 1580.8, -1841.7 }, { -250, 550 }, { 2600, -4150 } }) do
			local x, z = MapMath.UnitToWorld(cal, MapMath.WorldToUnit(cal, point[1], point[2]))
			worst = math.max(worst, math.abs(x - point[1]), math.abs(z - point[2]))
			local mx, mz = MapMath.MapDelta(cal, point[1], point[2])
			local dx, dz = MapMath.WorldDelta(cal, mx, mz)
			worst = math.max(worst, math.abs(dx - point[1]), math.abs(dz - point[2]))
		end
	end
end
check("unit/world and delta round trips", worst < 1e-6, worst)

-- Heading (same results as FreeRoamMapPlayerMarkers.MapHeading)
check("+X heading 180", near(MapMath.Heading(live, 1, 0), 180))
check("-Z heading 90", near(MapMath.Heading(live, 0, -1), 90))
check("vertical heading nil", MapMath.Heading(live, 0, 0) == nil)

-- Minimap placement (FreeRoamMapPlayerMarkers:Step maths)
local size, uiPerStud = 245, 245 / 2850
local x, y = MapMath.MinimapPoint(live, 0, 0, uiPerStud, 33, size)
check("subject sits at minimap centre", near(x, 122.5) and near(y, 122.5))
x, y = MapMath.MinimapPoint(live, 0, -100, uiPerStud, 0, size)
check("north-up: -Z is right of centre", near(x, 122.5 + 100 * uiPerStud) and near(y, 122.5))
x, y = MapMath.MinimapPoint(live, 0, -100, uiPerStud, 90, size)
check("rotation 90 turns right into down", near(x, 122.5) and near(y, 122.5 + 100 * uiPerStud))
local function playerModule(dx, dz, rotation)
	local mappedX, mappedZ = dx * live.Cos - dz * live.Sin, dx * live.Sin + dz * live.Cos
	local r = math.rad(rotation)
	return size / 2 + (mappedX * math.cos(r) - mappedZ * math.sin(r)) * uiPerStud, size / 2 + (mappedX * math.sin(r) + mappedZ * math.cos(r)) * uiPerStud
end
local px, py = playerModule(310, -45, -127)
x, y = MapMath.MinimapPoint(live, 310, -45, uiPerStud, -127, size)
check("matches player-marker transform", near(x, px, 1e-9) and near(y, py, 1e-9))

-- Edge clamp
local cx, cy, clamped = MapMath.ClampToRect(100, 60, 200, 200, 10)
check("inside point unchanged", cx == 100 and cy == 60 and not clamped)
cx, cy, clamped = MapMath.ClampToRect(500, 100, 200, 200, 10)
check("far right clamps to right rim", near(cx, 190) and near(cy, 100) and clamped)
cx, cy = MapMath.ClampToRect(400, 400, 200, 200, 10)
check("diagonal clamps to the corner", near(cx, 190) and near(cy, 190))
cx, cy = MapMath.ClampToRect(100 + 300, 100 - 100, 200, 200, 10)
check("clamp keeps direction", near((cy - 100) / (cx - 100), -100 / 300) and near(cx, 190))
cx, cy = MapMath.ClampToRect(50, -900, 300, 100, 8)
check("non-square box clamps to top rim", near(cy, 8) and cx > 50 and cx < 150)
check("inside test with overscan", MapMath.Inside(-5, 50, 100, 100, 8) and not MapMath.Inside(-9, 50, 100, 100, 8))

-- Zoom clamping and canvas size
check("zoom clamps low", MapMath.ClampVisibleStuds(10, 500, 9000) == 500)
check("zoom clamps high", MapMath.ClampVisibleStuds(1e9, 500, 9000) == 9000)
check("zoom NaN falls back to minimum", MapMath.ClampVisibleStuds(0 / 0, 500, 9000) == 500)
check("zoom max never below min", MapMath.ClampVisibleStuds(700, 800, 100) == 800)
check("canvas side", near(MapMath.CanvasSide(28000, 700, 2800), 7000))

-- Screen <-> unit and zoom about an anchor
local pan, centre, side = Vector2.new(0.4, 0.6), Vector2.new(400, 300), 9000
local anchor = Vector2.new(620, 111)
local unit = MapMath.ScreenToUnit(pan, anchor, centre, side)
-- Vector2 is float32 in Roblox, so screen-space tolerances are ~1e-3 px and unit tolerances ~1e-6.
check("screen/unit round trip", nearV(MapMath.UnitToScreen(pan, unit, centre, side), anchor, 1e-3))
local newPan = MapMath.ZoomAbout(pan, side, side * 1.25, anchor, centre)
check("zoom keeps the anchored map point", nearV(MapMath.ScreenToUnit(newPan, anchor, centre, side * 1.25), unit, 1e-6))
check("zoom about centre keeps pan", nearV(MapMath.ZoomAbout(pan, side, side * 2, centre, centre), pan, 1e-6))

-- Pan bounds
local bounds = MapMath.BoundsToUnits(live, -2750, 5100, -6650, 3050)
check("bounds inside canvas", bounds.UMin >= 0 and bounds.UMax <= 1 and bounds.VMin >= 0 and bounds.VMax <= 1 and bounds.UMin < bounds.UMax and bounds.VMin < bounds.VMax)
local bu, bv = MapMath.WorldToUnit(live, 731.3, -1747.9)
check("dealership inside pan bounds", bu > bounds.UMin and bu < bounds.UMax and bv > bounds.VMin and bv < bounds.VMax)
local viewW, viewH = 1200, 700
local sideAt = MapMath.CanvasSide(live.FullStuds, 700, 2000)
local clampedPan = MapMath.ClampPan(Vector2.new(0, 0), sideAt, viewW, viewH, bounds)
check("pan clamp keeps view covered", near(clampedPan.X - viewW / 2 / sideAt, bounds.UMin, 1e-6) and near(clampedPan.Y - viewH / 2 / sideAt, bounds.VMin, 1e-6))
local inner = Vector2.new((bounds.UMin + bounds.UMax) / 2, (bounds.VMin + bounds.VMax) / 2)
check("pan inside bounds unchanged", nearV(MapMath.ClampPan(inner, sideAt, viewW, viewH, bounds), inner, 1e-12))
local tiny = { UMin = 0.49, UMax = 0.51, VMin = 0.49, VMax = 0.51 }
check("small bounds centre the view", nearV(MapMath.ClampPan(Vector2.new(0.1, 0.9), sideAt, viewW, viewH, tiny), Vector2.new(0.5, 0.5), 1e-12))
local maxStuds = MapMath.MaxStudsForBounds(live, bounds, viewW, viewH)
local limitSide = MapMath.CanvasSide(live.FullStuds, math.min(viewW, viewH), maxStuds)
local coverU = (bounds.UMax - bounds.UMin) * limitSide
local coverV = (bounds.VMax - bounds.VMin) * limitSide
check("max zoom-out still covers the view", coverU >= viewW - 1e-6 and coverV >= viewH - 1e-6 and (near(coverU, viewW, 1e-6) or near(coverV, viewH, 1e-6)))

-- Animated pan and picking
local a = Vector2.new(0, 0)
for _ = 1, 120 do a = MapMath.Approach(a, Vector2.new(1, 2), 12, 1 / 60) end
check("approach converges", nearV(a, Vector2.new(1, 2), 1e-3))
check("approach response 0 snaps", MapMath.Approach(Vector2.new(0, 0), Vector2.new(3, 4), 0, 0.01) == Vector2.new(3, 4))
local points = { { Id = "A", X = 10, Y = 10, Priority = 10 }, { Id = "B", X = 30, Y = 10, Priority = 10 }, { Id = "W", X = 11, Y = 11, Priority = 50 } }
check("pick nearest within radius", MapMath.PickNearest(points, 29, 10, 8) == "B")
check("pick none outside radius", MapMath.PickNearest(points, 100, 100, 8) == nil)
check("higher priority wins near-ties", MapMath.PickNearest(points, 10.5, 10.5, 8) == "W")

return { failures = failures, results = results }
