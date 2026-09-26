-- Pure map maths shared by MapIconLayer and FullMapUI (map-markers contract, Agent F).
-- No services, instances or requires, so scripts/map_ui/tests.lua can loadstring it.
-- Conventions match the free-roam HUD owners and RouteGuide's map renderer:
--   map studs:  mx = dx*cos - dz*sin, mz = dx*sin + dz*cos (after optional X/Z flips)
--   map units:  u = 0.5 + mx / FullStuds, v = 0.5 + mz / FullStuds (0..1 across the 4-tile canvas)
--   headings:   screen degrees clockwise from up.
local MapMath = {}

local function finite(value, fallback)
	value = tonumber(value)
	if value == nil or value ~= value or value == math.huge or value == -math.huge then return fallback end
	return value
end
MapMath.Finite = finite

-- values: MapPixels, MapCalibrationPixels, MapCalibrationStuds, MapWorldCenterX, MapWorldCenterZ,
--         MapCoordinateRotationDegrees, MapFlipX, MapFlipZ (the HUD Layout/Defaults names).
function MapMath.Calibration(values)
	values = values or {}
	local pixels = math.max(1, finite(values.MapPixels, 2048))
	local calibrationPixels = math.max(1, finite(values.MapCalibrationPixels, 207))
	local calibrationStuds = math.max(1, finite(values.MapCalibrationStuds, 2850))
	local radians = math.rad(finite(values.MapCoordinateRotationDegrees, 90))
	return {
		FullStuds = pixels * calibrationStuds / calibrationPixels,
		CenterX = finite(values.MapWorldCenterX, 0),
		CenterZ = finite(values.MapWorldCenterZ, 0),
		Radians = radians,
		Cos = math.cos(radians),
		Sin = math.sin(radians),
		FlipX = values.MapFlipX == true,
		FlipZ = values.MapFlipZ == true,
	}
end

-- World delta (studs) -> map-oriented delta (studs).
function MapMath.MapDelta(cal, dx, dz)
	if cal.FlipX then dx = -dx end
	if cal.FlipZ then dz = -dz end
	return dx * cal.Cos - dz * cal.Sin, dx * cal.Sin + dz * cal.Cos
end

-- Inverse of MapDelta.
function MapMath.WorldDelta(cal, mx, mz)
	local dx = mx * cal.Cos + mz * cal.Sin
	local dz = -mx * cal.Sin + mz * cal.Cos
	if cal.FlipX then dx = -dx end
	if cal.FlipZ then dz = -dz end
	return dx, dz
end

function MapMath.WorldToUnit(cal, x, z)
	local mx, mz = MapMath.MapDelta(cal, x - cal.CenterX, z - cal.CenterZ)
	return 0.5 + mx / cal.FullStuds, 0.5 + mz / cal.FullStuds
end

function MapMath.UnitToWorld(cal, u, v)
	local dx, dz = MapMath.WorldDelta(cal, (u - 0.5) * cal.FullStuds, (v - 0.5) * cal.FullStuds)
	return cal.CenterX + dx, cal.CenterZ + dz
end

-- Heading of a world look vector on the map (degrees clockwise from up), nil when vertical.
function MapMath.Heading(cal, lookX, lookZ)
	local mx, mz = MapMath.MapDelta(cal, lookX, lookZ)
	if mx * mx + mz * mz < 1e-6 then return nil end
	return math.deg(math.atan2(mx, -mz))
end

-- Rotating minimap: pixel position of a world delta inside a square map of side `size`
-- centred on the subject (same maths as FreeRoamMapPlayerMarkers:Step).
function MapMath.MinimapPoint(cal, dx, dz, uiPerStud, rotationDegrees, size)
	local mx, mz = MapMath.MapDelta(cal, dx, dz)
	local r = math.rad(rotationDegrees or 0)
	local c, s = math.cos(r), math.sin(r)
	local half = size * 0.5
	return half + (mx * c - mz * s) * uiPerStud, half + (mx * s + mz * c) * uiPerStud
end

-- Keeps a point inside a w x h box (inset from the rim) along the ray from the box centre,
-- so an off-map marker sits on the rim in its true direction. Returns x, y, clamped.
function MapMath.ClampToRect(x, y, w, h, inset)
	local cx, cy = w * 0.5, h * 0.5
	local hx, hy = math.max(0, cx - inset), math.max(0, cy - inset)
	local ox, oy = x - cx, y - cy
	if math.abs(ox) <= hx and math.abs(oy) <= hy then return x, y, false end
	local scale = math.huge
	if math.abs(ox) > 1e-9 then scale = math.min(scale, hx / math.abs(ox)) end
	if math.abs(oy) > 1e-9 then scale = math.min(scale, hy / math.abs(oy)) end
	if scale == math.huge then scale = 0 end
	return cx + ox * scale, cy + oy * scale, true
end

function MapMath.Inside(x, y, w, h, overscan)
	overscan = overscan or 0
	return x >= -overscan and y >= -overscan and x <= w + overscan and y <= h + overscan
end

-- Zoom is expressed as the studs visible across the view's shorter side.
function MapMath.ClampVisibleStuds(visible, minimum, maximum)
	minimum = math.max(1, finite(minimum, 500))
	maximum = math.max(minimum, finite(maximum, 9000))
	return math.clamp(finite(visible, minimum), minimum, maximum)
end

-- Pixel side of the full 4-tile canvas for a view whose shorter side is `shortSide` px.
function MapMath.CanvasSide(fullStuds, shortSide, visibleStuds)
	return fullStuds * shortSide / math.max(1, visibleStuds)
end

-- Full map view: `pan` (Vector2 map units) is the map point at the view centre `centre` (px).
function MapMath.ScreenToUnit(pan, point, centre, side)
	return pan + (point - centre) / side
end

function MapMath.UnitToScreen(pan, unit, centre, side)
	return centre + (unit - pan) * side
end

-- New pan after changing canvas side from oldSide to newSide while the map point under
-- `anchor` (px) stays under the anchor.
function MapMath.ZoomAbout(pan, oldSide, newSide, anchor, centre)
	local unit = MapMath.ScreenToUnit(pan, anchor, centre, oldSide)
	return unit - (anchor - centre) / newSide
end

-- World rectangle -> map-unit bounding box, intersected with the canvas [0, 1].
function MapMath.BoundsToUnits(cal, minX, maxX, minZ, maxZ)
	local umin, umax, vmin, vmax = math.huge, -math.huge, math.huge, -math.huge
	for _, corner in ipairs({ { minX, minZ }, { minX, maxZ }, { maxX, minZ }, { maxX, maxZ } }) do
		local u, v = MapMath.WorldToUnit(cal, corner[1], corner[2])
		umin, umax = math.min(umin, u), math.max(umax, u)
		vmin, vmax = math.min(vmin, v), math.max(vmax, v)
	end
	umin, vmin = math.max(0, umin), math.max(0, vmin)
	umax, vmax = math.min(1, umax), math.min(1, vmax)
	if umax < umin then umin, umax = 0, 1 end
	if vmax < vmin then vmin, vmax = 0, 1 end
	return { UMin = umin, UMax = umax, VMin = vmin, VMax = vmax }
end

-- Keeps the view covered by the bounds; centres an axis when the bounds are smaller than the view.
function MapMath.ClampPan(pan, side, viewW, viewH, bounds)
	local hx, hy = viewW * 0.5 / side, viewH * 0.5 / side
	local function axis(value, low, high, half)
		if high - low <= half * 2 then return (low + high) * 0.5 end
		return math.clamp(value, low + half, high - half)
	end
	return Vector2.new(axis(pan.X, bounds.UMin, bounds.UMax, hx), axis(pan.Y, bounds.VMin, bounds.VMax, hy))
end

-- Largest visible-studs value at which the bounds still cover the view (so zooming out stops at the bounds).
function MapMath.MaxStudsForBounds(cal, bounds, viewW, viewH)
	local shortSide = math.max(1, math.min(viewW, viewH))
	local spanU = (bounds.UMax - bounds.UMin) * cal.FullStuds
	local spanV = (bounds.VMax - bounds.VMin) * cal.FullStuds
	return math.min(spanU * shortSide / math.max(1, viewW), spanV * shortSide / math.max(1, viewH))
end

-- Exponential approach used for animated pans (centre on player, legend focus).
function MapMath.Approach(current, target, response, dt)
	if response <= 0 then return target end
	local alpha = 1 - math.exp(-response * math.max(0, dt or 0))
	return current + (target - current) * alpha
end

-- points: { { Id, X, Y, Priority } }; returns the id of the closest point within radius
-- (higher priority wins ties within 2 px).
function MapMath.PickNearest(points, x, y, radius)
	local bestId, bestDistance, bestPriority = nil, math.huge, -math.huge
	for _, point in ipairs(points) do
		local distance = math.sqrt((point.X - x) ^ 2 + (point.Y - y) ^ 2)
		if distance <= radius then
			local priority = point.Priority or 0
			if distance < bestDistance - 2 or (math.abs(distance - bestDistance) <= 2 and priority > bestPriority) then
				bestId, bestDistance, bestPriority = point.Id, distance, priority
			end
		end
	end
	return bestId
end

return MapMath
