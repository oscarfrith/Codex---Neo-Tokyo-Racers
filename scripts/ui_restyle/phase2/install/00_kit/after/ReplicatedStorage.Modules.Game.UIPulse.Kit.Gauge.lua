-- Owns the Pulse speed gauge: ring images, the rotating-gradient reveal, the tip, the speed number, unit and boost line; not the vehicle read, the frame step or the slot.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.Gauge. Requires: Tokens, Sprites, Metrics, Text, BigNumber, Perf.
local Tokens = require(script.Parent.Tokens)
local Sprites = require(script.Parent.Sprites)
local Metrics = require(script.Parent.Metrics)
local Text = require(script.Parent.Text)
local BigNumber = require(script.Parent.BigNumber)
local Perf = require(script.Parent.Perf)

local Gauge = {}

local Space = Tokens.Space
local RING = Sprites.Rings
local GAUGE = RING.Gauge

-- Reveal (spike 06). Angles are degrees clockwise from +X in screen space; a UIGradient at Rotation r shows the
-- half-plane of angles (r + 90, r + 270), so the edge of a fill that ends at angle a is r = a + 90.
local QUANTUM = 0.5 -- degrees per write (PC 5.1 rule 5)
local SEAM = 270 -- 12 o'clock, where the two half windows meet
-- A half that is empty or full parks its mask edge this far from the seam, inside the gap the images leave empty at
-- the bottom (45 to 135 degrees), so the soft edge of the step never lies along the join.
local PARK = 20
local LEFT_EMPTY = 90 + PARK + 90
local LEFT_FULL = SEAM + PARK + 90
local RIGHT_EMPTY = -PARK
local MASK = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.499, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})

-- Layout as fractions of the gauge frame, read off preview r00 (403 px frame): centre lines below the gauge centre.
local SPEED_Y = -0.012
local UNIT_Y = 0.181
local BOOST_Y = 0.305
local SPEED_MAX = 999
local SPEED_CELLS = 3
local UNIT_ROLE = "Label"
local BOOST_ROLE = "Value"

local GAUGE_KEYS = { Name = true, LayoutOrder = true, Visible = true, Size = true, Unit = true, ShowBoostText = true }
local UNITS = { MPH = true, ["KM/H"] = true }

local function checkKeys(patch)
	if type(patch) ~= "table" then error("Gauge expects a table of props", 3) end
	for key in pairs(patch) do
		if not GAUGE_KEYS[key] then error(string.format("Gauge: unknown key '%s'", tostring(key)), 3) end
	end
end

local function checkValues(values)
	if values.Size ~= nil and (type(values.Size) ~= "number" or values.Size <= 0) then
		error("Gauge: Size must be a positive design number", 3)
	end
	if values.Unit ~= nil and not UNITS[values.Unit] then
		error("Gauge: unknown Unit " .. tostring(values.Unit), 3)
	end
end

local function write(instance, property, value)
	if instance[property] ~= value then instance[property] = value end
end

local function round(value)
	return math.floor(value + 0.5)
end

local function unitFraction(fraction)
	if type(fraction) ~= "number" or fraction ~= fraction then return 0 end
	return math.clamp(fraction, 0, 1)
end

-- Pure. Mask rotations (left half, right half) and the quantised degrees of a fill that starts at startDeg (in the
-- left half) and covers `fraction` of sweepDeg, passing 12 o'clock into the right half.
local function sweep(startDeg, sweepDeg, fraction)
	local degrees = math.floor(unitFraction(fraction) * sweepDeg / QUANTUM + 0.5) * QUANTUM
	local angle = startDeg + degrees
	local left
	if degrees <= 0 then
		left = LEFT_EMPTY
	elseif angle < SEAM then
		left = angle + 90
	else
		left = LEFT_FULL
	end
	local right = if angle > SEAM then angle - SEAM else RIGHT_EMPTY
	return left, right, degrees
end

-- Pure. Whole percent of a 0..1 fraction.
local function percent(fraction)
	return math.floor(unitFraction(fraction) * 100 + 0.5)
end

-- Pure. The integer the number shows.
local function wholeSpeed(value)
	if type(value) ~= "number" or value ~= value then return 0 end
	return math.clamp(math.floor(value + 0.5), 0, SPEED_MAX)
end

-- Pure. Whole-pixel offset of the tip from the gauge centre for a fill of `degrees`, on a circle of `radius` px.
local function tipOffset(degrees, radius)
	local angle = math.rad(GAUGE.StartDeg + degrees)
	return round(math.cos(angle) * radius), round(math.sin(angle) * radius)
end

function Gauge.Angles(fraction)
	local left, right = sweep(GAUGE.StartDeg, GAUGE.SweepDeg, fraction)
	return left, right
end

Gauge._sweep = sweep
Gauge._percent = percent
Gauge._wholeSpeed = wholeSpeed
Gauge._tipOffset = tipOffset

local function ringImage(name, assetKey, zIndex, parent)
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = Tokens.Asset(assetKey) or ""
	image.ScaleType = Enum.ScaleType.Stretch
	image.ZIndex = zIndex
	image.Parent = parent
	return image
end

local function halfWindow(name, zIndex, parent)
	local window = Instance.new("Frame")
	window.Name = name
	window.BackgroundTransparency = 1
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.ZIndex = zIndex
	window.Parent = parent
	return window
end

local function mask(image, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Mask"
	gradient.Transparency = MASK
	gradient.Rotation = rotation
	gradient.Parent = image
	return gradient
end

function Gauge.New(parent, props, scope)
	assert(typeof(parent) == "Instance" and parent:IsA("GuiObject"), "Gauge requires a GuiObject parent")
	assert(type(scope) == "table", "Gauge requires a scope")
	props = props or {}
	checkKeys(props)
	checkValues(props)

	local ctx = Metrics.Of(parent)
	local destroyed = false
	local writes = 0
	local state = {
		Name = props.Name or "Gauge",
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
		Size = props.Size or Space.GaugeSize,
		Unit = props.Unit or "MPH",
		ShowBoostText = props.ShowBoostText,
	}
	if state.ShowBoostText == nil then state.ShowBoostText = ctx.Class ~= "Compact" end

	-- The Speed cap is drawn for the full-size gauge; the smaller Regular gauge (touch) takes the next cap down.
	local function speedRole()
		if ctx.Class ~= "Compact" and state.Size < (Space.GaugeSize + Space.GaugeTouchSize) / 2 then return "Timer" end
		return "Speed"
	end

	local emptyLeft, emptyRight = sweep(GAUGE.StartDeg, GAUGE.SweepDeg, 0)
	-- What is on screen now. A setter compares with these and writes only a difference.
	local shown = { Speed = 0, Left = emptyLeft, Right = emptyRight, Degrees = 0, BoostPercent = 0,
		BoostLeft = emptyLeft, BoostRight = emptyRight, BoostVisible = true, TipX = 0, TipY = 0, TipOn = false }
	local geometry = { Size = 0, Half = 0, ArcRadius = 0 }

	local root = Instance.new("Frame")
	Metrics.Bind(root, ctx) -- parts built before the root is parented take this context, not the screen's
	root.Name = state.Name
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.LayoutOrder = state.LayoutOrder
	root.Visible = state.Visible
	-- In a slot the root sits on the slot's anchor (API1 8).
	if string.sub(parent.Name, 1, 4) == "Slot" then root.AnchorPoint = parent.AnchorPoint end

	local track = ringImage("Track", "GaugeTrack", 1, root)
	local ticks = ringImage("Ticks", "GaugeTicks", 2, root)
	-- Glow and Arc share angles, so they share one pair of windows.
	local arcLeft = halfWindow("ArcLeft", 3, root)
	local arcRight = halfWindow("ArcRight", 3, root)
	local boostLeft = halfWindow("BoostLeft", 4, root)
	local boostRight = halfWindow("BoostRight", 4, root)
	local leftImages = {
		ringImage("Glow", "GaugeGlow", 1, arcLeft),
		ringImage("Arc", "GaugeArc", 2, arcLeft),
		ringImage("BoostArc", "BoostArc", 1, boostLeft),
	}
	local rightImages = {
		ringImage("Glow", "GaugeGlow", 1, arcRight),
		ringImage("Arc", "GaugeArc", 2, arcRight),
		ringImage("BoostArc", "BoostArc", 1, boostRight),
	}
	local glowLeftMask = mask(leftImages[1], emptyLeft)
	local arcLeftMask = mask(leftImages[2], emptyLeft)
	local boostLeftMask = mask(leftImages[3], emptyLeft)
	local glowRightMask = mask(rightImages[1], emptyRight)
	local arcRightMask = mask(rightImages[2], emptyRight)
	local boostRightMask = mask(rightImages[3], emptyRight)

	local tip = ringImage("Tip", "GlowSoft", 5, root)
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.ImageColor3 = Tokens.Colour.White
	tip.Visible = false

	local speed = BigNumber.New(root, { Name = "Speed", Text = "0", Role = speedRole(), Colour = "White",
		Align = "Centre", MaxCells = SPEED_CELLS }, scope)
	speed.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
	speed.Instance.ZIndex = 6

	local unit = Text.RawLabel(root, UNIT_ROLE, ctx)
	unit.Name = "Unit"
	unit.Text = state.Unit
	unit.TextColor3 = Tokens.Colour.TextSecondary
	unit.TextXAlignment = Enum.TextXAlignment.Center
	unit.TextYAlignment = Enum.TextYAlignment.Center
	unit.ZIndex = 6

	local boostText = Text.RawLabel(root, BOOST_ROLE, ctx)
	boostText.Name = "BoostText"
	boostText.Text = "BOOST 0%"
	boostText.TextColor3 = Tokens.Colour.Cyan
	boostText.TextXAlignment = Enum.TextXAlignment.Center
	boostText.TextYAlignment = Enum.TextYAlignment.Center
	boostText.Visible = state.ShowBoostText
	boostText.ZIndex = 6

	local function tally(count)
		writes += count
		if Perf.Enabled then Perf.Count("Gauge.Writes", count) end
	end

	-- Returns the number of properties written. Safe in a frame step: no lookup, no creation.
	local function placeTip()
		local count = 0
		local on = shown.Degrees > 0
		if on then
			local dx, dy = tipOffset(shown.Degrees, geometry.ArcRadius)
			local x, y = geometry.Half + dx, geometry.Half + dy
			if x ~= shown.TipX or y ~= shown.TipY then
				shown.TipX, shown.TipY = x, y
				tip.Position = UDim2.fromOffset(x, y)
				count += 1
			end
		end
		if on ~= shown.TipOn then
			shown.TipOn = on
			tip.Visible = on
			count += 1
		end
		return count
	end

	local function placeLine(label, role, ratio)
		local textSize = (Text.SizeFor(role, ctx))
		local top = geometry.Half + round(geometry.Size * ratio) - math.floor(textSize / 2)
		write(label, "FontFace", Text.Font(role))
		write(label, "TextSize", textSize)
		write(label, "Position", UDim2.fromOffset(0, top))
		write(label, "Size", UDim2.fromOffset(geometry.Size, textSize))
	end

	local function layout()
		if destroyed then return end
		-- An even side keeps the centre, and so the join of the two halves, on a whole pixel.
		local size = ctx.Px(state.Size)
		size = math.max(2, size - size % 2)
		local half = size / 2
		geometry.Size = size
		geometry.Half = half
		geometry.ArcRadius = size * GAUGE.ArcRadius / RING.Size

		local full = UDim2.fromOffset(size, size)
		local halfSize = UDim2.fromOffset(half, size)
		local rightOrigin = UDim2.fromOffset(half, 0)
		local rightImage = UDim2.fromOffset(-half, 0)
		write(root, "Size", full)
		write(track, "Size", full)
		write(ticks, "Size", full)
		write(arcLeft, "Size", halfSize)
		write(boostLeft, "Size", halfSize)
		write(arcRight, "Position", rightOrigin)
		write(arcRight, "Size", halfSize)
		write(boostRight, "Position", rightOrigin)
		write(boostRight, "Size", halfSize)
		for _, image in ipairs(leftImages) do
			write(image, "Size", full)
		end
		for _, image in ipairs(rightImages) do
			write(image, "Position", rightImage)
			write(image, "Size", full)
		end

		local tipSize = math.max(2, round(size * GAUGE.TipFraction))
		write(tip, "Size", UDim2.fromOffset(tipSize, tipSize))
		write(speed.Instance, "Position", UDim2.fromOffset(half, half + round(size * SPEED_Y)))
		placeLine(unit, UNIT_ROLE, UNIT_Y)
		placeLine(boostText, BOOST_ROLE, BOOST_Y)

		shown.TipX, shown.TipY = -1, -1
		placeTip()
	end

	local function setSpeed(value, fraction)
		if destroyed then return end
		local count = 0
		local whole = wholeSpeed(value)
		if whole ~= shown.Speed then
			shown.Speed = whole
			speed.SetText(tostring(whole))
			count += 1
		end
		local left, right, degrees = sweep(GAUGE.StartDeg, GAUGE.SweepDeg, fraction)
		if left ~= shown.Left then
			shown.Left = left
			glowLeftMask.Rotation = left
			arcLeftMask.Rotation = left
			count += 2
		end
		if right ~= shown.Right then
			shown.Right = right
			glowRightMask.Rotation = right
			arcRightMask.Rotation = right
			count += 2
		end
		if degrees ~= shown.Degrees then
			shown.Degrees = degrees
			count += placeTip()
		end
		if count > 0 then tally(count) end
	end

	local function setBoost(fraction)
		if destroyed then return end
		local whole = percent(fraction)
		if whole == shown.BoostPercent then return end
		shown.BoostPercent = whole
		local count = 1
		boostText.Text = "BOOST " .. whole .. "%"
		local left, right = sweep(GAUGE.StartDeg, GAUGE.SweepDeg, whole / 100)
		if left ~= shown.BoostLeft then
			shown.BoostLeft = left
			boostLeftMask.Rotation = left
			count += 1
		end
		if right ~= shown.BoostRight then
			shown.BoostRight = right
			boostRightMask.Rotation = right
			count += 1
		end
		tally(count)
	end

	local function applyBoostVisible()
		write(boostLeft, "Visible", shown.BoostVisible)
		write(boostRight, "Visible", shown.BoostVisible)
		write(boostText, "Visible", shown.BoostVisible and state.ShowBoostText == true)
	end

	local function setVisibleBoost(visible)
		if destroyed then return end
		visible = visible == true
		if visible == shown.BoostVisible then return end
		shown.BoostVisible = visible
		applyBoostVisible()
	end

	local apply = {
		Name = function(value) root.Name = value end,
		LayoutOrder = function(value) root.LayoutOrder = value end,
		Visible = function(value) root.Visible = value end,
		Size = function()
			speed.Set({ Role = speedRole() })
			layout()
		end,
		Unit = function(value) unit.Text = value end,
		ShowBoostText = function() applyBoostVisible() end,
	}

	local function set(patch)
		checkKeys(patch)
		checkValues(patch)
		if destroyed then return end
		for key, value in pairs(patch) do
			if state[key] ~= value then
				state[key] = value
				apply[key](value)
			end
		end
	end

	local function setUnit(value)
		set({ Unit = value })
	end

	local changedConnection, readyConnection

	local function destroy()
		if destroyed then return end
		destroyed = true
		if changedConnection then changedConnection:Disconnect() end
		if readyConnection then readyConnection:Disconnect() end
		speed.Destroy()
		root:Destroy()
	end

	layout()
	root.Parent = parent

	if ctx.Changed then
		changedConnection = scope:connect(ctx.Changed, function(change)
			if type(change) == "table" and change.Layout == false then return end
			layout()
		end)
	end
	if Text.ReadyChanged then readyConnection = scope:connect(Text.ReadyChanged, layout) end
	scope:add(destroy)

	return {
		Instance = root,
		Set = set,
		Destroy = destroy,
		SetSpeed = setSpeed,
		SetBoost = setBoost,
		SetUnit = setUnit,
		SetVisibleBoost = setVisibleBoost,
		-- Test and probe seam: properties written by SetSpeed and SetBoost since the build.
		_writes = function() return writes end,
	}
end

return Gauge
