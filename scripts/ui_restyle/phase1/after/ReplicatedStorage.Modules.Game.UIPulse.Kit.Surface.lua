-- Owns the Pulse flat surfaces: Panel, Hairline, Scrim, Glow and Icon; does not own text, input, focus or any screen layout.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Kit.Surface. Requires: Tokens, Metrics.
local Tokens = require(script.Parent.Tokens)
local Metrics = require(script.Parent.Metrics)

local Colour = Tokens.Colour
local Opacity = Tokens.Opacity
local Space = Tokens.Space

local Surface = {}

-- A UIGradient multiplies the background colour, so a gradient frame is pure white underneath.
local GRADIENT_BASE = Color3.new(1, 1, 1)
-- Style sheet, scene treatment: the garage tint covers the left 38% of the screen.
local GARAGE_FADE_END = 0.38

local GLOW_KINDS = {
	Tile = { Asset = "GlowSoft", Radius = "GlowTileRadius", Opacity = "GlowTile" },
	Button = { Asset = "GlowTight", Radius = "GlowButtonRadius", Opacity = "GlowButton" },
	Line = { Asset = "GlowLine", Radius = "GlowRingRadius", Opacity = "GlowRing" },
	Ring = { Asset = "GlowTight", Radius = "GlowRingRadius", Opacity = "GlowRing" },
}
local SCRIM_KINDS = { Menu = true, Confirm = true, Garage = true }
local EDGES = { Top = true, Bottom = true }

local function keySet(names)
	local keys = { Name = true, LayoutOrder = true, Visible = true }
	for _, name in names do
		keys[name] = true
	end
	return keys
end

local PANEL_KEYS = keySet({ "Pad", "Hairlines", "Width", "Height" })
local HAIRLINE_KEYS = keySet({ "Edge", "Colour", "Opacity" })
local SCRIM_KEYS = keySet({ "Kind" })
local GLOW_KEYS = keySet({ "Kind", "Colour" })
local ICON_KEYS = keySet({ "Icon", "Colour", "Size" })

local function write(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function checkKeys(values, keys, name)
	if type(values) ~= "table" then
		error(name .. ": props must be a table", 3)
	end
	for key in values do
		if not keys[key] then
			error(name .. ": unknown key " .. tostring(key), 3)
		end
	end
end

local function checkColour(name, value, required)
	if value == nil then
		if required then
			error(name .. ": Colour is required", 4)
		end
	elseif Colour[value] == nil then
		error(name .. ": unknown colour role " .. tostring(value), 4)
	end
end

local function checkNumber(name, key, value, required)
	if value == nil then
		if required then
			error(name .. ": " .. key .. " is required", 4)
		end
	elseif type(value) ~= "number" then
		error(name .. ": " .. key .. " must be a design number", 4)
	end
end

local function checkChoice(name, key, value, choices, required)
	if value == nil then
		if required then
			error(name .. ": " .. key .. " is required", 4)
		end
	elseif type(value) ~= "string" or choices[value] == nil then
		error(name .. ": unknown " .. key .. " " .. tostring(value), 4)
	end
end

local function plainFrame(name)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 1
	return frame
end

-- Shared component shell. def.Validate(values, initial) checks the keys present (and the required ones when
-- initial). def.Build(ctx, state) returns the root, a render function and optional extra component fields.
local function make(parent, props, scope, def)
	props = props or {}
	checkKeys(props, def.Keys, def.Name)
	def.Validate(props, true)

	local ctx = Metrics.Of(parent)
	local state = table.clone(props)
	local root, render, extra = def.Build(ctx, state)
	local destroyed = false
	local changedConnection = nil

	local function apply()
		write(root, "Name", state.Name or def.Root)
		if state.LayoutOrder ~= nil then
			write(root, "LayoutOrder", state.LayoutOrder)
		end
		write(root, "Visible", state.Visible ~= false)
		render()
	end
	apply()

	if ctx.Changed then
		changedConnection = scope:connect(ctx.Changed, function(change)
			if destroyed or (type(change) == "table" and change.Layout == false) then
				return
			end
			apply()
		end)
	end

	local component = { Instance = root }
	if extra then
		for key, value in extra do
			component[key] = value
		end
	end

	function component.Set(patch)
		checkKeys(patch, def.Keys, def.Name)
		def.Validate(patch, false)
		if destroyed then
			return
		end
		local changed = false
		for key, value in patch do
			if state[key] ~= value then
				state[key] = value
				changed = true
			end
		end
		if changed then
			apply()
		end
	end

	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if changedConnection then
			changedConnection:Disconnect()
			changedConnection = nil
		end
		root:Destroy()
	end

	root.Parent = parent
	return component
end

-- Panel -------------------------------------------------------------------------------------------------
-- Width or Height nil fills the parent on that axis. Screens parent into component.Content.
local PANEL = {
	Name = "Surface.Panel",
	Root = "Panel",
	Keys = PANEL_KEYS,
	Validate = function(values)
		checkNumber("Surface.Panel", "Pad", values.Pad, false)
		checkNumber("Surface.Panel", "Width", values.Width, false)
		checkNumber("Surface.Panel", "Height", values.Height, false)
	end,
	Build = function(ctx, state)
		local root = plainFrame("Panel")
		root.Active = true
		root.BackgroundColor3 = Colour.Slate
		root.BackgroundTransparency = 1 - Opacity.Panel

		local hairTop = plainFrame("HairTop")
		hairTop.BackgroundColor3 = Colour.White
		hairTop.BackgroundTransparency = 1 - Opacity.HairTop
		hairTop.ZIndex = 2
		hairTop.Parent = root

		local hairBottom = plainFrame("HairBottom")
		hairBottom.BackgroundColor3 = Colour.White
		hairBottom.BackgroundTransparency = 1 - Opacity.HairBottom
		hairBottom.AnchorPoint = Vector2.new(0, 1)
		hairBottom.Position = UDim2.new(0, 0, 1, 0)
		hairBottom.ZIndex = 2
		hairBottom.Parent = root

		local content = plainFrame("Content")
		content.Parent = root

		local function render()
			local pad = ctx.Px(state.Pad or Space.Pad)
			local hair = ctx.Hair(Space.Hairline)
			local hairlines = state.Hairlines ~= false
			local width = state.Width and UDim.new(0, ctx.Px(state.Width)) or UDim.new(1, 0)
			local height = state.Height and UDim.new(0, ctx.Px(state.Height)) or UDim.new(1, 0)

			write(root, "Size", UDim2.new(width, height))
			write(hairTop, "Size", UDim2.new(1, 0, 0, hair))
			write(hairTop, "Visible", hairlines)
			write(hairBottom, "Size", UDim2.new(1, 0, 0, hair))
			write(hairBottom, "Visible", hairlines)
			write(content, "Position", UDim2.fromOffset(pad, pad))
			write(content, "Size", UDim2.new(1, -pad - pad, 1, -pad - pad))
		end

		return root, render, { Content = content }
	end,
}

function Surface.Panel(parent, props, scope)
	return make(parent, props, scope, PANEL)
end

-- Hairline ----------------------------------------------------------------------------------------------
local HAIRLINE = {
	Name = "Surface.Hairline",
	Root = "Hairline",
	Keys = HAIRLINE_KEYS,
	Validate = function(values, initial)
		checkChoice("Surface.Hairline", "Edge", values.Edge, EDGES, initial)
		checkColour("Surface.Hairline", values.Colour, false)
		checkNumber("Surface.Hairline", "Opacity", values.Opacity, false)
	end,
	Build = function(ctx, state)
		local root = plainFrame("Hairline")

		local function render()
			local bottom = state.Edge == "Bottom"
			local opacity = state.Opacity
			if opacity == nil then
				opacity = bottom and Opacity.HairBottom or Opacity.HairTop
			end
			write(root, "BackgroundColor3", Colour[state.Colour or "White"])
			write(root, "BackgroundTransparency", 1 - opacity)
			write(root, "AnchorPoint", Vector2.new(0, bottom and 1 or 0))
			write(root, "Position", UDim2.new(0, 0, bottom and 1 or 0, 0))
			write(root, "Size", UDim2.new(1, 0, 0, ctx.Hair(Space.Hairline)))
		end

		return root, render
	end,
}

function Surface.Hairline(parent, props, scope)
	return make(parent, props, scope, HAIRLINE)
end

-- Scrim -------------------------------------------------------------------------------------------------
-- Menu: vertical gradient ScrimTop to ScrimBottom. Confirm: flat Black at ConfirmScrim. Garage: ScrimTop
-- fading out left to right, so the car stays bright.
local SCRIM = {
	Name = "Surface.Scrim",
	Root = "Scrim",
	Keys = SCRIM_KEYS,
	Validate = function(values, initial)
		checkChoice("Surface.Scrim", "Kind", values.Kind, SCRIM_KINDS, initial)
	end,
	Build = function(_ctx, state)
		local root = plainFrame("Scrim")
		root.Active = false
		root.Size = UDim2.fromScale(1, 1)
		local gradient = nil

		local function render()
			local kind = state.Kind
			if kind == "Confirm" then
				if gradient then
					gradient:Destroy()
					gradient = nil
				end
				write(root, "BackgroundColor3", Colour.Black)
				write(root, "BackgroundTransparency", 1 - Opacity.ConfirmScrim)
				return
			end

			if not gradient then
				gradient = Instance.new("UIGradient")
				gradient.Name = "Gradient"
				gradient.Parent = root
			end
			write(root, "BackgroundColor3", GRADIENT_BASE)
			write(root, "BackgroundTransparency", 0)
			if kind == "Menu" then
				gradient.Rotation = 90
				gradient.Color = ColorSequence.new(Colour.ScrimTop, Colour.ScrimBottom)
				gradient.Transparency = NumberSequence.new(1 - Opacity.ScrimTop, 1 - Opacity.ScrimBottom)
			else
				gradient.Rotation = 0
				gradient.Color = ColorSequence.new(Colour.ScrimTop)
				gradient.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1 - Opacity.ScrimTop),
					NumberSequenceKeypoint.new(GARAGE_FADE_END, 1),
					NumberSequenceKeypoint.new(1, 1),
				})
			end
		end

		return root, render
	end,
}

function Surface.Scrim(parent, props, scope)
	return make(parent, props, scope, SCRIM)
end

-- Icon --------------------------------------------------------------------------------------------------
-- With no sheet uploaded the ImageLabel has no image: it draws nothing and keeps its box.
local ICON = {
	Name = "Surface.Icon",
	Root = "Icon",
	Keys = ICON_KEYS,
	Validate = function(values, initial)
		if values.Icon ~= nil then
			if type(values.Icon) ~= "string" or Tokens.Icons.Glyphs[values.Icon] == nil then
				error("Surface.Icon: unknown icon " .. tostring(values.Icon), 3)
			end
		elseif initial then
			error("Surface.Icon: Icon is required", 3)
		end
		checkColour("Surface.Icon", values.Colour, initial)
		checkNumber("Surface.Icon", "Size", values.Size, initial)
	end,
	Build = function(ctx, state)
		local root = Instance.new("ImageLabel")
		root.Name = "Icon"
		root.BorderSizePixel = 0
		root.BackgroundTransparency = 1
		root.ScaleType = Enum.ScaleType.Stretch

		local function render()
			local cell = Tokens.Icons.Cell
			local glyph = Tokens.Icons.Glyphs[state.Icon]
			local size = ctx.Px(state.Size)
			write(root, "Image", Tokens.Asset("IconSheet") or "")
			write(root, "ImageRectOffset", Vector2.new(glyph[1] * cell, glyph[2] * cell))
			write(root, "ImageRectSize", Vector2.new(cell, cell))
			write(root, "ImageColor3", Colour[state.Colour])
			write(root, "Size", UDim2.fromOffset(size, size))
		end

		return root, render
	end,
}

function Surface.Icon(parent, props, scope)
	return make(parent, props, scope, ICON)
end

-- Glow --------------------------------------------------------------------------------------------------
-- A 9-slice image parented into the element it lights, reaching one glow radius past each edge, with a
-- ZIndex one below the parent's so the parent's other children draw over it. The parent must not clip and
-- must not lay its children out. With the asset empty the root is a zero-size Frame.
local function checkGlow(values, initial)
	checkChoice("Surface.Glow", "Kind", values.Kind, GLOW_KINDS, initial)
	checkColour("Surface.Glow", values.Colour, initial)
end

function Surface.Glow(parent, props, scope)
	props = props or {}
	checkKeys(props, GLOW_KEYS, "Surface.Glow")
	checkGlow(props, true)

	local ctx = Metrics.Of(parent)
	local state = table.clone(props)
	local component = {}
	local destroyed = false
	local changedConnection = nil
	local root = nil

	local function render()
		local kind = GLOW_KINDS[state.Kind]
		local asset = Tokens.Asset(kind.Asset)
		local className = asset and "ImageLabel" or "Frame"

		-- Only a Kind change between an uploaded and an empty asset swaps the class.
		local fresh = root == nil or root.ClassName ~= className
		if fresh then
			if root then
				root:Destroy()
			end
			root = Instance.new(className)
			root.BorderSizePixel = 0
			root.BackgroundTransparency = 1
			root.Active = false
			component.Instance = root
		end

		write(root, "Name", state.Name or "Glow")
		if state.LayoutOrder ~= nil then
			write(root, "LayoutOrder", state.LayoutOrder)
		end
		write(root, "Visible", state.Visible ~= false)
		write(root, "ZIndex", parent.ZIndex - 1)

		if asset then
			local radius = ctx.Px(Space[kind.Radius])
			local slice = Tokens.Slices[kind.Asset]
			write(root, "Image", asset)
			write(root, "ImageColor3", Colour[state.Colour])
			write(root, "ImageTransparency", 1 - Opacity[kind.Opacity])
			if slice then
				-- The art's glow band is slice.Inset texture pixels deep; draw it radius pixels deep.
				write(root, "ScaleType", Enum.ScaleType.Slice)
				write(root, "SliceCenter", slice.Center)
				write(root, "SliceScale", slice.Inset > 0 and radius / slice.Inset or 1)
			else
				write(root, "ScaleType", Enum.ScaleType.Stretch)
			end
			write(root, "Position", UDim2.fromOffset(-radius, -radius))
			write(root, "Size", UDim2.new(1, radius + radius, 1, radius + radius))
		else
			write(root, "Size", UDim2.fromOffset(0, 0))
		end

		if fresh then
			root.Parent = parent
		end
	end
	render()

	if ctx.Changed then
		changedConnection = scope:connect(ctx.Changed, function(change)
			if destroyed or (type(change) == "table" and change.Layout == false) then
				return
			end
			render()
		end)
	end

	function component.Set(patch)
		checkKeys(patch, GLOW_KEYS, "Surface.Glow")
		checkGlow(patch, false)
		if destroyed then
			return
		end
		local changed = false
		for key, value in patch do
			if state[key] ~= value then
				state[key] = value
				changed = true
			end
		end
		if changed then
			render()
		end
	end

	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if changedConnection then
			changedConnection:Disconnect()
			changedConnection = nil
		end
		root:Destroy()
	end

	return component
end

return Surface
