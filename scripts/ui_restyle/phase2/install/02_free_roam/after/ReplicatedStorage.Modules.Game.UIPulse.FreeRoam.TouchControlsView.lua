-- Owns the look and placement of the touch drive controls (builders over Kit.Touch); not the input handlers, the MobileDriveInputState writes, the mode logic or any attribute, which stay in the TouchControlsClient fork.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.TouchControlsView. Requires: Tokens, Sprites, Text, Controls, Input, Touch.
local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Sprites = require(Kit.Sprites)
local Text = require(Kit.Text)
local Controls = require(Kit.Controls)
local Input = require(Kit.Input)
local Touch = require(Kit.Touch)

local Space = Tokens.Space
local Colour = Tokens.Colour
local Opacity = Tokens.Opacity

local View = {}

-- The Classic control names (MobileDriveControlsClient 82-88, 101), the Kit.Touch control that draws each, and the
-- onboarding mark where one exists. Every root is a TextButton, as every Classic control was (Classic line 54).
local CONTROLS = table.freeze({
	table.freeze({ Name = "TurnLeft", Control = "Turn" }),
	table.freeze({ Name = "TurnRight", Control = "Turn", Mirror = true }),
	table.freeze({ Name = "DriftLeft", Control = "Drift", Mark = "DriftLeft" }),
	table.freeze({ Name = "DriftRight", Control = "Drift", Mirror = true, Mark = "DriftRight" }),
	table.freeze({ Name = "Accelerator", Control = "Accelerate" }),
	table.freeze({ Name = "Brake", Control = "Brake" }),
	table.freeze({ Name = "Boost", Control = "Boost", Mark = "Boost" }),
})
View._controls = CONTROLS

-- The kept Classic thumbstick code writes thumbKnob.Position as a scale of the outer ring around its centre
-- (Classic 135, 139), so the knob keeps a centre anchor. This is the one centre anchor in this module.
local KNOB_ANCHOR = Vector2.new(0.5, 0.5)
local KNOB_REST = UDim2.fromScale(0.5, 0.5)

-- Pure. Real pixels in the layer root (the safe area). `s` holds real-pixel sizes:
-- { M, B, Gap, Turn = {w, h}, Drift = {w, h}, Boost = {w, h}, Brake = {w, h}, Accelerate = {w, h}, Stick }.
-- Classic arrangement (176-192): turn pair bottom-left, drift pair above it, boost above the cluster centre;
-- brake then accelerate bottom-right; the thumbstick and the tilt group share the bottom-left corner.
function View._place(width, height, s)
	local columnWidth = math.max(s.Turn[1], s.Drift[1])
	local clusterWidth = columnWidth * 2 + s.Gap
	local left = s.M
	local floorY = height - s.B
	local turnY = floorY - s.Turn[2]
	local driftY = turnY - s.Gap - s.Drift[2]
	local boostY = driftY - s.Gap - s.Boost[2]
	local turnInset = math.floor((columnWidth - s.Turn[1]) / 2)
	local driftInset = math.floor((columnWidth - s.Drift[1]) / 2)
	local acceleratorX = width - s.M - s.Accelerate[1]
	return {
		TurnLeft = Vector2.new(left + turnInset, turnY),
		TurnRight = Vector2.new(left + columnWidth + s.Gap + turnInset, turnY),
		DriftLeft = Vector2.new(left + driftInset, driftY),
		DriftRight = Vector2.new(left + columnWidth + s.Gap + driftInset, driftY),
		Boost = Vector2.new(left + math.floor((clusterWidth - s.Boost[1]) / 2), boostY),
		Accelerator = Vector2.new(acceleratorX, floorY - s.Accelerate[2]),
		Brake = Vector2.new(acceleratorX - s.Gap - s.Brake[1], floorY - s.Brake[2]),
		ThumbstickHit = Vector2.new(left, floorY - s.Stick),
		TiltGroup = Vector2.new(left, floorY),
	}
end

-- Pure. The real-pixel sizes _place needs, from tokens and the generated sprite data.
function View._sizes(ctx)
	local compact = ctx.Class == "Compact"
	local function hit(control)
		local dp = Sprites.Touch[control].HitDp
		return { ctx.Dp(dp[1]), ctx.Dp(dp[2]) }
	end
	local sizes = {
		M = ctx.Px(compact and Space.CompactMargin or Space.HudMargin),
		B = ctx.Px(compact and Space.CompactBottom or Space.HudBottom),
		Gap = ctx.Dp(Space.TouchGap),
		Turn = hit("Turn"),
		Drift = hit("Drift"),
		Boost = hit("Boost"),
		Brake = hit("Brake"),
		Accelerate = hit("Accelerate"),
	}
	-- The thumbstick pad is as tall as the arrow cluster it replaces, so Boost sits above either.
	local clusterHeight = sizes.Turn[2] + sizes.Gap + sizes.Drift[2]
	local clusterWidth = math.max(sizes.Turn[1], sizes.Drift[1]) * 2 + sizes.Gap
	sizes.Stick = math.max(clusterHeight, clusterWidth)
	sizes.Knob = ctx.Dp(Space.CompactHudButton)
	return sizes
end

-- Pure. Whole percent 0..100 from MobileDriveInputState.BoostPercent.
function View._wholePercent(value)
	local number = tonumber(value) or 0
	if number ~= number then
		number = 0
	end
	return math.clamp(math.floor(number + 0.5), 0, 100)
end

local function plain(name, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new()
	frame.Parent = parent
	return frame
end

local function put(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

-- View.Mount(layer, model, scope). `model` is unused: the fork is the model. The returned table carries what the
-- kept Classic ranges read (API2 5.3): Root, Buttons, ThumbHit, ThumbOuter, ThumbKnob, OuterStroke, TiltStatus,
-- Pressed, Layout; plus SetBoostPercent, Render and Destroy.
function View.Mount(layer, _model, scope)
	local ctx = layer.Metrics
	local bag = {}
	local destroyed = false

	local root = plain("DriveRoot", nil)
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false

	local anchors = {}
	local components = {}
	local byInstance = {}
	local buttons = {}

	local function anchor(name)
		local frame = plain("Anchor" .. name, root)
		anchors[name] = frame
		return frame
	end

	for _, spec in ipairs(CONTROLS) do
		local component = Touch.Button(anchor(spec.Name), {
			Name = spec.Name,
			Control = spec.Control,
			Mirror = spec.Mirror == true,
		}, scope)
		if spec.Mark then
			Input.Mark(component.Instance, spec.Mark)
		end
		components[spec.Name] = component
		byInstance[component.Instance] = component
		buttons[spec.Name] = component.Instance
		table.insert(bag, component)
	end

	-- Thumbstick. Kit.Touch has no thumbstick art, so this is flat kit colour: a slate pad with two hairlines and a
	-- square knob. ThumbstickHit is the Classic name and class (Classic 95).
	local thumbHit = Instance.new("TextButton")
	thumbHit.Name = "ThumbstickHit"
	thumbHit.Text = ""
	thumbHit.AutoButtonColor = false
	thumbHit.BackgroundTransparency = 1
	thumbHit.BorderSizePixel = 0
	thumbHit.Active = true
	thumbHit.Selectable = false
	thumbHit.Parent = anchor("ThumbstickHit")

	local thumbOuter = plain("OuterDriftRing", thumbHit)
	thumbOuter.Size = UDim2.fromScale(1, 1)
	thumbOuter.BackgroundColor3 = Colour.Slate
	thumbOuter.BackgroundTransparency = 1 - Opacity.Panel

	local hairTop = plain("HairTop", thumbOuter)
	hairTop.BackgroundTransparency = 0
	hairTop.BackgroundColor3 = Colour.Pink
	local hairBottom = plain("HairBottom", thumbOuter)
	hairBottom.BackgroundTransparency = 0
	hairBottom.BackgroundColor3 = Colour.Pink
	hairBottom.AnchorPoint = Vector2.new(0, 1)
	hairBottom.Position = UDim2.new(0, 0, 1, 0)

	local thumbKnob = plain("Knob", thumbOuter)
	thumbKnob.AnchorPoint = KNOB_ANCHOR
	thumbKnob.Position = KNOB_REST
	thumbKnob.BackgroundTransparency = 0
	thumbKnob.BackgroundColor3 = Colour.Cyan
	thumbKnob.ZIndex = 2

	local driftLabelAnchor = plain("AnchorDriftLabel", thumbOuter)
	local driftLabel = Text.Label(driftLabelAnchor, { Name = "DriftLabel", Text = "DRIFT", Role = "Label", Colour = "Pink" }, scope)
	table.insert(bag, driftLabel)

	-- The kept thumbstick code writes outerStroke.Color (Classic 136, 139). Pulse has no stroke: the write recolours
	-- the two hairlines, and only when the colour changes.
	local strokeColour = Colour.Pink
	local outerStroke = setmetatable({}, {
		__index = function(_, key)
			if key == "Color" then
				return strokeColour
			end
			error("[Pulse.TouchControlsView] outerStroke has no field " .. tostring(key), 2)
		end,
		__newindex = function(_, key, value)
			if key ~= "Color" then
				error("[Pulse.TouchControlsView] outerStroke has no field " .. tostring(key), 2)
			end
			if value ~= strokeColour then
				strokeColour = value
				hairTop.BackgroundColor3 = value
				hairBottom.BackgroundColor3 = value
			end
		end,
	})

	-- Tilt group: status line, RECENTER, the tilt drift button, stacked upward from the bottom-left corner.
	local tiltGroup = anchor("TiltGroup")
	tiltGroup.AnchorPoint = Vector2.new(0, 1)
	tiltGroup.AutomaticSize = Enum.AutomaticSize.XY
	local tiltList = Instance.new("UIListLayout")
	tiltList.Name = "Stack"
	tiltList.FillDirection = Enum.FillDirection.Vertical
	tiltList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	tiltList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	tiltList.SortOrder = Enum.SortOrder.LayoutOrder
	tiltList.Parent = tiltGroup

	local statusText = "TILT STEERING"
	local statusVisible = true
	local status = Text.Label(tiltGroup, {
		Name = "TiltStatus", Text = statusText, Role = "Label", Colour = "TextMuted", Shadow = true, LayoutOrder = 1,
	}, scope)
	table.insert(bag, status)
	-- The kept mode and calibration code writes tiltStatus.Text and tiltStatus.Visible (Classic 149, 169).
	local tiltStatus = setmetatable({}, {
		__index = function(_, key)
			if key == "Text" then
				return statusText
			elseif key == "Visible" then
				return statusVisible
			end
			error("[Pulse.TouchControlsView] tiltStatus has no field " .. tostring(key), 2)
		end,
		__newindex = function(_, key, value)
			if key == "Text" then
				statusText = tostring(value)
				status.Set({ Text = statusText })
			elseif key == "Visible" then
				statusVisible = value == true
				status.Set({ Visible = statusVisible })
			else
				error("[Pulse.TouchControlsView] tiltStatus has no field " .. tostring(key), 2)
			end
		end,
	})

	local recenter = Controls.Button(tiltGroup, {
		Name = "TiltRecenter", Variant = "Default", Text = "RECENTER", Size = "Hud", LayoutOrder = 2,
		OnActivated = function() end,
	}, scope)
	table.insert(bag, recenter)
	buttons.TiltRecenter = recenter.Instance

	local tiltDrift = Touch.Button(tiltGroup, { Name = "TiltDrift", Control = "Drift", LayoutOrder = 3 }, scope)
	table.insert(bag, tiltDrift)
	components.TiltDrift = tiltDrift
	byInstance[tiltDrift.Instance] = tiltDrift
	buttons.TiltDrift = tiltDrift.Instance

	root.Parent = layer.Root

	-- Layout. The kept render step calls this every frame (Classic 197); it returns after three comparisons unless
	-- the root size or the metrics changed.
	local lastSize = nil
	local lastScale = nil
	local lastClass = nil
	local function layout()
		if destroyed then
			return
		end
		local size = layer.Root.AbsoluteSize
		if size == lastSize and ctx.Scale == lastScale and ctx.Class == lastClass then
			return
		end
		lastSize, lastScale, lastClass = size, ctx.Scale, ctx.Class
		local width, height = math.floor(size.X), math.floor(size.Y)
		if width <= 0 or height <= 0 then
			width, height = math.floor(ctx.Size.X), math.floor(ctx.Size.Y)
		end
		local sizes = View._sizes(ctx)
		local places = View._place(width, height, sizes)
		for name, position in pairs(places) do
			put(anchors[name], "Position", UDim2.fromOffset(position.X, position.Y))
		end
		local hair = ctx.Hair(Space.Hairline)
		local gap = sizes.Gap
		put(thumbHit, "Size", UDim2.fromOffset(sizes.Stick, sizes.Stick))
		put(thumbKnob, "Size", UDim2.fromOffset(sizes.Knob, sizes.Knob))
		put(hairTop, "Size", UDim2.new(1, 0, 0, hair))
		put(hairBottom, "Size", UDim2.new(1, 0, 0, hair))
		local line = Text.SizeFor("Label", ctx)
		put(driftLabelAnchor, "Position", UDim2.new(0, gap, 1, -(gap + line)))
		put(tiltList, "Padding", UDim.new(0, gap))
	end
	layout()

	if ctx.Changed then
		scope:connect(ctx.Changed, function(change)
			if type(change) == "table" and change.Layout == false then
				return
			end
			lastSize = nil
			layout()
		end)
	end

	local lastPercent = nil
	local view = {
		Root = root,
		Buttons = buttons,
		ThumbHit = thumbHit,
		ThumbOuter = thumbOuter,
		ThumbKnob = thumbKnob,
		OuterStroke = outerStroke,
		TiltStatus = tiltStatus,
		Layout = layout,
	}

	-- pressed(b, on) of the Classic source: the art swaps to its pressed image.
	function view.Pressed(button, on)
		local component = byInstance[button]
		if component then
			component.SetPressed(on == true)
		end
	end

	-- The boost charge ring (API2 3.8). Writes only when the whole percent changes.
	function view.SetBoostPercent(value)
		local percent = View._wholePercent(value)
		if percent ~= lastPercent then
			lastPercent = percent
			components.Boost.SetCharge(percent / 100)
		end
	end

	function view.Render() end

	function view.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		for index = #bag, 1, -1 do
			bag[index].Destroy()
		end
		root:Destroy()
	end

	return view
end

return View
