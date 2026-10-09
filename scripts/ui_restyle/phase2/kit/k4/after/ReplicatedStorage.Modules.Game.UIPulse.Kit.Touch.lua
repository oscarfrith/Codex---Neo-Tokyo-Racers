-- Owns the look of the on-screen drive controls (accelerate, brake, turn, drift, boost and the boost charge ring); it connects no input, reads no input state, writes no attribute and places nothing on the screen.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.Touch. Requires: Tokens, Sprites, Metrics.
local Tokens = require(script.Parent.Tokens)
local Sprites = require(script.Parent.Sprites)
local Metrics = require(script.Parent.Metrics)

local Touch = {}

local Space = Tokens.Space
local Opacity = Tokens.Opacity

local HALF = 0.5
local ART_PIXELS = 512 -- source size of every touch_*.png (touch.json "size"); used only to mirror
local RING_SCALE = 1.02 -- charge ring frame against the boost art frame (API2 3.8)
local CHARGE_ASSET = "RankArc"
local FULL_TURN = 360
local HALF_TURN = 180
local PERCENT = 100

-- Where the plate sits in the hit box (touch.json "anchor"); the others are centred.
local PLATE_ANCHOR = {
	Accelerate = { 1, 1 },
	Brake = { HALF, 1 },
}
local CENTRED = { HALF, HALF }
local CLASSES = { TextButton = true, ImageButton = true }

local KEYS = {
	Name = true, LayoutOrder = true, Visible = true,
	Control = true, Mirror = true, Class = true, Pressed = true, Disabled = true, Charge = true,
}

-- Hard step: the first half of the gradient shows, the second half hides (spike 06).
local STEP = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.499, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local function put(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function checkKeys(values)
	if type(values) ~= "table" then
		error("[Pulse.Touch] props must be a table", 3)
	end
	for key in pairs(values) do
		if not KEYS[key] then
			error("[Pulse.Touch] unknown key " .. tostring(key), 3)
		end
	end
end

-- Checks only the keys that are present, so it serves both props and a Set patch.
local function checkValues(values)
	if values.Control ~= nil and Sprites.Touch[values.Control] == nil then
		error("[Pulse.Touch] unknown Control " .. tostring(values.Control), 3)
	end
	if values.Class ~= nil and not CLASSES[values.Class] then
		error("[Pulse.Touch] Class must be TextButton or ImageButton", 3)
	end
	if values.Name ~= nil and type(values.Name) ~= "string" then
		error("[Pulse.Touch] Name must be a string", 3)
	end
	if values.Charge ~= nil and type(values.Charge) ~= "number" then
		error("[Pulse.Touch] Charge must be a number", 3)
	end
end

-- Pure. Whole percent of a charge fraction.
function Touch._percent(fraction)
	if fraction ~= fraction then
		return 0
	end
	return math.floor(math.clamp(fraction, 0, 1) * PERCENT + HALF)
end

-- Pure. Rotations of the right and left mask gradients for a charge percent: the fill grows clockwise
-- from 12 o'clock (270 degrees in the ring convention).
function Touch._chargeAngles(percent)
	local degrees = percent * FULL_TURN / PERCENT
	return math.min(degrees, HALF_TURN), HALF_TURN + math.max(degrees - HALF_TURN, 0)
end

-- Pure. Sizes in real pixels for a control: hit box, art frame and the art's top-left in the hit box.
function Touch._geometry(control, ctx)
	local sprite = Sprites.Touch[control]
	if sprite == nil then
		error("[Pulse.Touch] unknown Control " .. tostring(control), 2)
	end
	local least = ctx.Dp(Space.TouchMin)
	local hitW = math.max(ctx.Dp(sprite.HitDp[1]), least)
	local hitH = math.max(ctx.Dp(sprite.HitDp[2]), least)
	local plateW = ctx.Dp(sprite.PlateDp[1])
	local plateH = ctx.Dp(sprite.PlateDp[2])
	local frameW = ctx.Dp(sprite.FrameDp[1])
	local frameH = ctx.Dp(sprite.FrameDp[2])
	local anchor = PLATE_ANCHOR[control] or CENTRED
	-- The plate is centred in the art frame, so the art is centred on the plate.
	local plateX = math.floor((hitW - plateW) * anchor[1] + HALF)
	local plateY = math.floor((hitH - plateH) * anchor[2] + HALF)
	local artX = plateX + math.floor((plateW - frameW) * HALF + HALF)
	local artY = plateY + math.floor((plateH - frameH) * HALF + HALF)
	return {
		Hit = Vector2.new(hitW, hitH),
		Frame = Vector2.new(frameW, frameH),
		Art = Vector2.new(artX, artY),
	}
end

local function newImage(parent, name)
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ScaleType = Enum.ScaleType.Stretch
	image.Parent = parent
	return image
end

-- One half of the charge fill: a clipping window over its half of the ring, holding the whole ring
-- image with a rotating step gradient.
local function newHalf(parent, name)
	local window = Instance.new("Frame")
	window.Name = name
	window.BackgroundTransparency = 1
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.Parent = parent
	local image = newImage(window, "Fill")
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Mask"
	gradient.Transparency = STEP
	gradient.Parent = image
	return window, image, gradient
end

function Touch.Button(parent, props, scope)
	props = props or {}
	checkKeys(props)
	checkValues(props)
	if props.Control == nil then
		error("[Pulse.Touch] Control is required", 2)
	end
	if props.Name == nil then
		error("[Pulse.Touch] Name is required (the fork passes the Classic name)", 2)
	end

	local state = table.clone(props)
	local ctx = Metrics.Of(parent)
	local className = state.Class or "TextButton"
	local isBoost = state.Control == "Boost"
	local destroyed = false
	local changedConnection = nil

	local root = Instance.new(className)
	root.Name = state.Name
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Active = true
	if className == "TextButton" then
		root.Text = ""
		root.TextTransparency = 1
	end

	local art = newImage(root, "Art")
	art.ZIndex = 2

	local track, rightWindow, rightFill, rightMask, leftWindow, leftFill, leftMask
	if isBoost then
		track = newImage(root, "ChargeTrack")
		rightWindow, rightFill, rightMask = newHalf(root, "ChargeRight")
		leftWindow, leftFill, leftMask = newHalf(root, "ChargeLeft")
	end

	local shownPercent = nil

	local function applyCharge()
		if not isBoost then
			return
		end
		local percent = Touch._percent(state.Charge or 0)
		if percent == shownPercent then
			return
		end
		shownPercent = percent
		local right, left = Touch._chargeAngles(percent)
		put(rightMask, "Rotation", right)
		put(leftMask, "Rotation", left)
	end

	local function applyLook()
		local sprite = Sprites.Touch[state.Control]
		local key = state.Pressed == true and sprite.Pressed or sprite.Idle
		local dim = state.Disabled == true and Opacity.TouchDisabled or 1
		put(art, "Image", Tokens.Asset(key) or "")
		put(art, "ImageTransparency", 1 - dim)
		if state.Mirror == true then
			put(art, "ImageRectOffset", Vector2.new(ART_PIXELS, 0))
			put(art, "ImageRectSize", Vector2.new(-ART_PIXELS, ART_PIXELS))
		else
			put(art, "ImageRectOffset", Vector2.zero)
			put(art, "ImageRectSize", Vector2.zero)
		end
		if isBoost then
			local ring = Tokens.Asset(CHARGE_ASSET) or ""
			put(track, "Image", ring)
			put(track, "ImageTransparency", 1 - Opacity.RankTrackImage * dim)
			put(rightFill, "Image", ring)
			put(rightFill, "ImageTransparency", 1 - dim)
			put(leftFill, "Image", ring)
			put(leftFill, "ImageTransparency", 1 - dim)
		end
	end

	local function layout()
		local geometry = Touch._geometry(state.Control, ctx)
		put(root, "Size", UDim2.fromOffset(geometry.Hit.X, geometry.Hit.Y))
		put(art, "Position", UDim2.fromOffset(geometry.Art.X, geometry.Art.Y))
		put(art, "Size", UDim2.fromOffset(geometry.Frame.X, geometry.Frame.Y))
		if isBoost then
			local side = math.floor(geometry.Frame.X * RING_SCALE + HALF)
			local half = math.floor(side * HALF)
			local x = geometry.Art.X + math.floor((geometry.Frame.X - side) * HALF + HALF)
			local y = geometry.Art.Y + math.floor((geometry.Frame.Y - side) * HALF + HALF)
			local full = UDim2.fromOffset(side, side)
			put(track, "Position", UDim2.fromOffset(x, y))
			put(track, "Size", full)
			put(leftWindow, "Position", UDim2.fromOffset(x, y))
			put(leftWindow, "Size", UDim2.fromOffset(half, side))
			put(leftFill, "Size", full)
			put(rightWindow, "Position", UDim2.fromOffset(x + half, y))
			put(rightWindow, "Size", UDim2.fromOffset(side - half, side))
			put(rightFill, "Position", UDim2.fromOffset(-half, 0))
			put(rightFill, "Size", full)
		end
	end

	local function applyCommon()
		put(root, "Name", state.Name)
		put(root, "LayoutOrder", state.LayoutOrder or 0)
		put(root, "Visible", state.Visible ~= false)
	end

	applyCommon()
	layout()
	applyLook()
	applyCharge()

	if ctx.Changed ~= nil then
		changedConnection = scope:connect(ctx.Changed, function(change)
			if destroyed or (type(change) == "table" and change.Layout == false) then
				return
			end
			layout()
		end)
	end

	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		checkKeys(patch)
		checkValues(patch)
		if patch.Control ~= nil and patch.Control ~= state.Control then
			error("[Pulse.Touch] Control cannot change after build", 2)
		end
		if patch.Class ~= nil and patch.Class ~= className then
			error("[Pulse.Touch] Class cannot change after build", 2)
		end
		if destroyed then
			return
		end
		local changed = false
		for key, value in pairs(patch) do
			if state[key] ~= value then
				state[key] = value
				changed = true
			end
		end
		if changed then
			applyCommon()
			applyLook()
			applyCharge()
		end
	end

	-- Swaps the art between the idle and pressed images; nothing is layered.
	function self.SetPressed(pressed)
		pressed = pressed == true
		if destroyed or (state.Pressed == true) == pressed then
			return
		end
		state.Pressed = pressed
		applyLook()
	end

	function self.SetDisabled(disabled)
		disabled = disabled == true
		if destroyed or (state.Disabled == true) == disabled then
			return
		end
		state.Disabled = disabled
		applyLook()
	end

	-- Boost only; a no-op on the other controls. Writes when the whole percent changes.
	function self.SetCharge(fraction)
		if destroyed or type(fraction) ~= "number" then
			return
		end
		state.Charge = fraction
		applyCharge()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if changedConnection ~= nil then
			changedConnection:Disconnect()
			changedConnection = nil
		end
		root:Destroy()
	end

	return self
end

return Touch
