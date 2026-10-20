-- Owns the Pulse speed gauge: ring images, the rotating-gradient reveal, the tip, the speed number, unit and boost line, and the gear readout with its shift light and punch clocks; not the vehicle read, the frame binding or the slot.
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

-- Gear readout (API2 amendment A20): one label in the empty bottom gap of the ring on Regular; on Compact it takes the
-- unit line's place while a gear shows, a little lower so its larger cap clears the speed digits. Fractions of the frame.
local GEAR_Y = 0.41
local GEAR_Y_COMPACT = 0.205
local GEAR_ROLE = "Status" -- the full Regular gauge; leaves the punch headroom under TextSize 100 up to 4K
local GEAR_ROLE_SMALL = "Value" -- the smaller Regular gauge (touch), as the speed number steps down to Timer there
local GEAR_ROLE_COMPACT = "SectionHead" -- 92 dp: a larger cap than the 9.7 dp unit line it replaces
local GEAR_MAX_CHARS = 2
-- Punch on a shift: TextSize steps up and settles back in whole steps (no UIScale; A20 records the exception to
-- "TextSize is never tweened"). A punch adds at most PUNCH_STEPS text sizes for about a fifth of a second.
local PUNCH_SCALE = 0.15
local PUNCH_SECONDS = 0.12 -- decay time constant
local PUNCH_STEPS = 3
-- Shift light: the gear text colour and the tip only; the baked images and the BigNumber are never tinted.
local FLASH_HZ = 3 -- limiter flash, the programme's flashing ceiling; phase-locked so its first frame is lit
local FLASH_DUTY = 0.5
local PULSE_HZ = 1.5 -- Overdrive: a brightness pulse, Cyan toward White and back, in PULSE_STEPS whole steps
local PULSE_STEPS = 4
local PULSE_REACH = 0.6 -- how far toward White the pulse goes
local LIGHT_WRAP = 2 -- seconds; a whole number of flash and pulse periods, so the light clock never grows
local WARN_WARM = 0.3 -- spin warning amber: Yellow taken this far toward Pink (the cash chip's warm-yellow method)

local LIGHT = table.freeze({ Off = 0, Warm = 1, Shift = 2, Limiter = 3, Spin = 4, Overdrive = 5 })
local COLOUR = Tokens.Colour
local AMBER = COLOUR.Yellow:Lerp(COLOUR.Pink, WARN_WARM)
local PULSE_COLOURS = {}
for index = 1, PULSE_STEPS do
	PULSE_COLOURS[index] = COLOUR.Cyan:Lerp(COLOUR.White, PULSE_REACH * (index - 1) / (PULSE_STEPS - 1))
end

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

-- Pure. The text the gear readout shows: a short string ("N", "R", "1".."7"), a number as its digits, nil for none.
local function gearText(value)
	if type(value) == "number" and value == value then value = tostring(math.floor(value)) end
	if type(value) ~= "string" or value == "" then return nil end
	return string.sub(value, 1, GEAR_MAX_CHARS)
end

-- Pure. A shift light level 0..5 (Gauge.Light); anything else is Off.
local function lightLevel(level)
	if type(level) ~= "number" or level ~= level then return LIGHT.Off end
	level = math.floor(level)
	if level < LIGHT.Off or level > LIGHT.Overdrive then return LIGHT.Off end
	return level
end

-- Pure. Is the limiter flash lit `elapsed` seconds after it began? Lit on its first frame.
local function flashOn(elapsed)
	return (elapsed * FLASH_HZ) % 1 < FLASH_DUTY
end

-- Pure. The Overdrive pulse step (1 = Cyan .. PULSE_STEPS = brightest) `elapsed` seconds in: a triangle wave.
local function pulseStep(elapsed)
	local phase = (elapsed * PULSE_HZ) % 1
	local wave = 1 - math.abs(2 * phase - 1)
	return math.floor(wave * (PULSE_STEPS - 1) + 0.5) + 1
end

-- Pure. The colour of the gear text and the tip for a light level, `elapsed` seconds after the level began.
local function lightColour(level, elapsed)
	if level == LIGHT.Warm then return COLOUR.Cyan end
	if level == LIGHT.Shift then return COLOUR.Pink end
	if level == LIGHT.Limiter then return if flashOn(elapsed) then COLOUR.Pink else COLOUR.White end
	if level == LIGHT.Spin then return AMBER end
	if level == LIGHT.Overdrive then return PULSE_COLOURS[pulseStep(elapsed)] end
	return COLOUR.White
end

-- Pure. The punch step (PUNCH_STEPS at the shift, 0 when settled) `elapsed` seconds after a shift.
local function punchLevel(elapsed)
	local amount = math.exp(-math.max(elapsed, 0) / PUNCH_SECONDS)
	return math.clamp(math.floor(amount * PUNCH_STEPS + 0.5), 0, PUNCH_STEPS)
end

-- Pure. TextSize of the gear at a punch step over its base size.
local function punchSize(base, level)
	return math.min(Tokens.Type.MaxTextSize, round(base * (1 + PUNCH_SCALE * level / PUNCH_STEPS)))
end

function Gauge.Angles(fraction)
	local left, right = sweep(GAUGE.StartDeg, GAUGE.SweepDeg, fraction)
	return left, right
end

-- Shift light levels for SetShiftLight (A20). HudView maps the drive state's ShiftLight 0..4 and Overdrive onto these.
Gauge.Light = LIGHT

Gauge._sweep = sweep
Gauge._percent = percent
Gauge._wholeSpeed = wholeSpeed
Gauge._tipOffset = tipOffset
Gauge._gearText = gearText
Gauge._lightLevel = lightLevel
Gauge._flashOn = flashOn
Gauge._lightColour = lightColour
Gauge._punchLevel = punchLevel
Gauge._punchSize = punchSize

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

	-- The gear follows the same steps down: Compact, then the smaller Regular gauge, then the full one.
	local function gearRole()
		if ctx.Class == "Compact" then return GEAR_ROLE_COMPACT end
		if state.Size < (Space.GaugeSize + Space.GaugeTouchSize) / 2 then return GEAR_ROLE_SMALL end
		return GEAR_ROLE
	end

	local emptyLeft, emptyRight = sweep(GAUGE.StartDeg, GAUGE.SweepDeg, 0)
	-- What is on screen now. A setter compares with these and writes only a difference.
	local shown = { Speed = 0, Left = emptyLeft, Right = emptyRight, Degrees = 0, BoostPercent = 0,
		BoostLeft = emptyLeft, BoostRight = emptyRight, BoostVisible = true, TipX = 0, TipY = 0, TipOn = false,
		Gear = nil, GearText = "", GearTextSize = 0, Punch = 0, Light = LIGHT.Off, Colour = COLOUR.White }
	local geometry = { Size = 0, Half = 0, ArcRadius = 0, GearSize = 0 }
	-- The two clocks Step advances: seconds since the last punch, and since the current light level began.
	local clocks = { Punch = 0, Light = 0 }

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

	-- One TextLabel for every gear state (N, R and digits alike). Hidden until a car sends a gear. Its roles are Fixed
	-- (API2 2.6), so it carries a SizeLock; placeGear caps it at the top punch step, the height of its box.
	local gear = Text.RawLabel(root, gearRole(), ctx)
	gear.Name = "Gear"
	gear.Text = ""
	gear.TextColor3 = COLOUR.White
	gear.TextXAlignment = Enum.TextXAlignment.Center
	gear.TextYAlignment = Enum.TextYAlignment.Center
	gear.AutomaticSize = Enum.AutomaticSize.None -- live text: placeGear sets the box
	gear.Visible = false
	gear.ZIndex = 6
	local gearLock = gear:FindFirstChild("SizeLock") -- build time only

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

	-- The gear box is as tall as the largest punch step and centred on its line, so a punch writes only TextSize. The
	-- SizeLock stops there too: the player's Text Size setting grows the gear no further than its box.
	local function placeGear()
		local role = gearRole()
		local base = (Text.SizeFor(role, ctx))
		local peak = punchSize(base, PUNCH_STEPS)
		local ratio = if ctx.Class == "Compact" then GEAR_Y_COMPACT else GEAR_Y
		local top = geometry.Half + round(geometry.Size * ratio) - math.floor(peak / 2)
		geometry.GearSize = base
		if gearLock then write(gearLock, "MaxTextSize", peak) end
		write(gear, "FontFace", Text.Font(role))
		write(gear, "Position", UDim2.fromOffset(0, top))
		write(gear, "Size", UDim2.fromOffset(geometry.Size, peak))
		shown.GearTextSize = punchSize(base, shown.Punch)
		write(gear, "TextSize", shown.GearTextSize)
	end

	-- Compact: the gear takes the unit line's place while it shows. Regular keeps the unit.
	local function unitShown()
		return not (ctx.Class == "Compact" and shown.Gear ~= nil)
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
		placeGear()
		write(unit, "Visible", unitShown())

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

	-- Gear readout, shift light and punch (A20). Safe in a frame step: every write is behind a comparison and Step
	-- does nothing while no punch runs and the light is steady.

	-- Returns the number of properties written.
	local function applyPunch(level)
		shown.Punch = level
		local size = punchSize(geometry.GearSize, level)
		if size == shown.GearTextSize then return 0 end
		shown.GearTextSize = size
		gear.TextSize = size
		return 1
	end

	-- Returns the number of properties written: the gear text colour and the tip's tint, never a baked image.
	local function paint()
		local colour = lightColour(shown.Light, clocks.Light)
		if colour == shown.Colour then return 0 end
		shown.Colour = colour
		gear.TextColor3 = colour
		tip.ImageColor3 = colour
		return 2
	end

	local function setGear(value)
		if destroyed then return end
		local text = gearText(value)
		if text == shown.Gear then return end
		local was = shown.Gear
		shown.Gear = text
		local count = 0
		if text and text ~= shown.GearText then
			shown.GearText = text
			gear.Text = text
			count += 1
		end
		if (was == nil) ~= (text == nil) then
			gear.Visible = text ~= nil
			count += 1
			local showUnit = unitShown()
			if unit.Visible ~= showUnit then
				unit.Visible = showUnit
				count += 1
			end
		end
		if text == nil and shown.Punch ~= 0 then count += applyPunch(0) end
		if count > 0 then tally(count) end
	end

	local function punchGear()
		if destroyed or shown.Gear == nil then return end
		clocks.Punch = 0
		local count = applyPunch(PUNCH_STEPS)
		if count > 0 then tally(count) end
	end

	local function setShiftLight(value)
		if destroyed then return end
		local level = lightLevel(value)
		if level == shown.Light then return end
		shown.Light = level
		clocks.Light = 0
		local count = paint()
		if count > 0 then tally(count) end
	end

	-- The owner calls this first in its frame step, so a punch or light change made later in that frame is drawn at its
	-- full value before the clock moves it on.
	local function step(dt)
		if destroyed or type(dt) ~= "number" or dt ~= dt or dt <= 0 then return end
		local count = 0
		if shown.Punch > 0 then
			clocks.Punch += dt
			count += applyPunch(punchLevel(clocks.Punch))
		end
		if shown.Light == LIGHT.Limiter or shown.Light == LIGHT.Overdrive then
			clocks.Light = (clocks.Light + dt) % LIGHT_WRAP
			count += paint()
		end
		if count > 0 then tally(count) end
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
		SetGear = setGear,
		PunchGear = punchGear,
		SetShiftLight = setShiftLight,
		Step = step,
		-- Test and probe seam: properties written by the frame setters (SetSpeed, SetBoost, SetGear, PunchGear,
		-- SetShiftLight, Step) since the build.
		_writes = function() return writes end,
	}
end

return Gauge
