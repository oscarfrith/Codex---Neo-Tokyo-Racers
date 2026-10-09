-- Owns the Pulse flat surfaces: Panel, Hairline, Divider, Scrim, Glow, Icon, MapIcon, TitleMark and KeyCap; does not own text roles, input, focus or any screen layout.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.Surface. Requires: Tokens, Sprites, Metrics.
local Tokens = require(script.Parent.Tokens)
local Sprites = require(script.Parent.Sprites)
local Metrics = require(script.Parent.Metrics)

local Colour = Tokens.Colour
local Opacity = Tokens.Opacity
local Space = Tokens.Space
local Type = Tokens.Type

local Surface = {}

local HALF = 0.5

-- A UIGradient multiplies the background colour, so a gradient frame is pure white underneath.
local GRADIENT_BASE = Color3.new(1, 1, 1)
-- Style sheet, scene treatment: the garage tint covers the left 38% of the screen.
local GARAGE_FADE_END = 0.38
-- and the bottom 40%; in play a soft dark band may sit behind the top and bottom 20%.
local GARAGE_BOTTOM_FADE = 0.4
local HUD_FADE = 0.2

local GLOW_KINDS = {
	Tile = { Asset = "GlowSoft", Radius = "GlowTileRadius", Opacity = "GlowTile" },
	Button = { Asset = "GlowTight", Radius = "GlowButtonRadius", Opacity = "GlowButton" },
	Line = { Asset = "GlowLine", Radius = "GlowRingRadius", Opacity = "GlowRing" },
	Ring = { Asset = "GlowTight", Radius = "GlowRingRadius", Opacity = "GlowRing" },
}
local SCRIM_KINDS = { Menu = true, Confirm = true, Garage = true, Hud = true }
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
local ICON_KEYS = keySet({ "Icon", "Colour", "Size", "Opacity" })
local MAP_ICON_KEYS = keySet({ "Icon", "Colour", "Size", "Tint" })
local TITLE_MARK_KEYS = keySet({ "Height" })
local KEY_CAP_KEYS = keySet({ "Text", "Icon", "Size" })
local DIVIDER_KEYS = keySet({ "Vertical", "Opacity" })

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
	local root, render, extra = def.Build(ctx, state, scope)
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
-- Menu: vertical gradient ScrimTop to ScrimBottom. Confirm: flat Black at ConfirmScrim. Garage: ScrimTop fading
-- out over the left 38%, plus a child fading in over the bottom 40%, so the car stays bright. Hud: one gradient,
-- dark over the top and bottom 20% and clear between.
local function transparencyRamp(points)
	local keys = {}
	for index, point in points do
		keys[index] = NumberSequenceKeypoint.new(point[1], point[2])
	end
	return NumberSequence.new(keys)
end

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
		local bottom = nil

		local function render()
			local kind = state.Kind
			if kind ~= "Garage" and bottom then
				bottom:Destroy()
				bottom = nil
			end
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
			elseif kind == "Hud" then
				gradient.Rotation = 90
				gradient.Color = ColorSequence.new(Colour.ScrimTop)
				gradient.Transparency = transparencyRamp({
					{ 0, 1 - Opacity.ScrimBottom },
					{ HUD_FADE, 1 },
					{ 1 - HUD_FADE, 1 },
					{ 1, 1 - Opacity.ScrimBottom },
				})
			else
				gradient.Rotation = 0
				gradient.Color = ColorSequence.new(Colour.ScrimTop)
				gradient.Transparency = transparencyRamp({
					{ 0, 1 - Opacity.ScrimTop },
					{ GARAGE_FADE_END, 1 },
					{ 1, 1 },
				})
				if not bottom then
					bottom = plainFrame("Bottom")
					bottom.Active = false
					bottom.Size = UDim2.fromScale(1, 1)
					bottom.BackgroundColor3 = GRADIENT_BASE
					bottom.BackgroundTransparency = 0
					local fade = Instance.new("UIGradient")
					fade.Name = "Gradient"
					fade.Rotation = 90
					fade.Color = ColorSequence.new(Colour.ScrimTop)
					fade.Transparency = transparencyRamp({
						{ 0, 1 },
						{ 1 - GARAGE_BOTTOM_FADE, 1 },
						{ 1, 1 - Opacity.ScrimBottom },
					})
					fade.Parent = bottom
					bottom.Parent = root
				end
			end
		end

		return root, render
	end,
}

function Surface.Scrim(parent, props, scope)
	return make(parent, props, scope, SCRIM)
end

-- Icon --------------------------------------------------------------------------------------------------
-- A glyph of the white icon sheet, tinted by role. With no sheet the ImageLabel draws nothing and keeps its box.
local ICON = {
	Name = "Surface.Icon",
	Root = "Icon",
	Keys = ICON_KEYS,
	Validate = function(values, initial)
		if values.Icon ~= nil then
			if type(values.Icon) ~= "string" or Sprites.Icons.Glyphs[values.Icon] == nil then
				error("Surface.Icon: unknown icon " .. tostring(values.Icon), 3)
			end
		elseif initial then
			error("Surface.Icon: Icon is required", 3)
		end
		checkColour("Surface.Icon", values.Colour, initial)
		checkNumber("Surface.Icon", "Size", values.Size, initial)
		checkNumber("Surface.Icon", "Opacity", values.Opacity, false)
	end,
	Build = function(ctx, state)
		local root = Instance.new("ImageLabel")
		root.Name = "Icon"
		root.BorderSizePixel = 0
		root.BackgroundTransparency = 1
		root.ScaleType = Enum.ScaleType.Stretch

		local function render()
			local sheet = Sprites.Icons
			local cell = sheet.Cell
			local glyph = sheet.Glyphs[state.Icon]
			local size = ctx.Px(state.Size)
			write(root, "Image", Tokens.Asset(sheet.Asset) or "")
			write(root, "ImageRectOffset", Vector2.new(glyph[1] * cell, glyph[2] * cell))
			write(root, "ImageRectSize", Vector2.new(cell, cell))
			write(root, "ImageColor3", Colour[state.Colour])
			write(root, "ImageTransparency", 1 - (state.Opacity or 1))
			write(root, "Size", UDim2.fromOffset(size, size))
		end

		return root, render
	end,
}

function Surface.Icon(parent, props, scope)
	return make(parent, props, scope, ICON)
end

-- MapIcon -----------------------------------------------------------------------------------------------
-- A glyph of the white map sheet. Pin glyphs anchor on their tip, the others on their centre. Tint is the named
-- colour exception for map markers (PC 2.3) and is accepted by this constructor only.
local MAP_ICON = {
	Name = "Surface.MapIcon",
	Root = "MapIcon",
	Keys = MAP_ICON_KEYS,
	Validate = function(values, initial)
		if values.Icon ~= nil then
			if type(values.Icon) ~= "string" or Sprites.MapIcons.Glyphs[values.Icon] == nil then
				error("Surface.MapIcon: unknown icon " .. tostring(values.Icon), 3)
			end
		elseif initial then
			error("Surface.MapIcon: Icon is required", 3)
		end
		checkColour("Surface.MapIcon", values.Colour, false)
		checkNumber("Surface.MapIcon", "Size", values.Size, initial)
		if values.Tint ~= nil and typeof(values.Tint) ~= "Color3" then
			error("Surface.MapIcon: Tint must be a Color3", 3)
		end
	end,
	Build = function(ctx, state)
		local root = Instance.new("ImageLabel")
		root.Name = "MapIcon"
		root.BorderSizePixel = 0
		root.BackgroundTransparency = 1
		root.ScaleType = Enum.ScaleType.Stretch

		local function render()
			local sheet = Sprites.MapIcons
			local cell = sheet.Cell
			local glyph = sheet.Glyphs[state.Icon]
			local size = ctx.Px(state.Size)
			local pin = sheet.Pins[state.Icon] == true
			write(root, "Image", Tokens.Asset(sheet.Asset) or "")
			write(root, "ImageRectOffset", Vector2.new(glyph[1] * cell, glyph[2] * cell))
			write(root, "ImageRectSize", Vector2.new(cell, cell))
			write(root, "ImageColor3", state.Tint or Colour[state.Colour or "White"])
			write(root, "AnchorPoint", Vector2.new(HALF, pin and sheet.PinTipY or HALF))
			write(root, "Size", UDim2.fromOffset(size, size))
		end

		return root, render
	end,
}

function Surface.MapIcon(parent, props, scope)
	return make(parent, props, scope, MAP_ICON)
end

-- TitleMark ---------------------------------------------------------------------------------------------
-- The baked pink slash before a title: never tinted. Height is the image height; the width follows the aspect
-- of the art. With no asset it is a Pink block of the same box.
local TITLE_MARK = {
	Name = "Surface.TitleMark",
	Root = "TitleMark",
	Keys = TITLE_MARK_KEYS,
	Validate = function(values)
		checkNumber("Surface.TitleMark", "Height", values.Height, false)
	end,
	Build = function(ctx, state)
		local root = Instance.new("ImageLabel")
		root.Name = "TitleMark"
		root.BorderSizePixel = 0
		root.BackgroundColor3 = Colour.Pink
		root.ScaleType = Enum.ScaleType.Stretch

		local function render()
			local art = Sprites.Rings.TitleSlash.Size
			local height = ctx.Px(state.Height or Space.TitleMarkHeight)
			local width = math.max(1, math.floor(height * art[1] / art[2] + HALF))
			local asset = Tokens.Asset("TitleSlash")
			write(root, "Image", asset or "")
			write(root, "BackgroundTransparency", asset and 1 or 0)
			write(root, "Size", UDim2.fromOffset(width, height))
		end

		return root, render
	end,
}

function Surface.TitleMark(parent, props, scope)
	return make(parent, props, scope, TITLE_MARK)
end

-- KeyCap ------------------------------------------------------------------------------------------------
-- Text: the white 9-slice cap with an Ink letter, as wide as the text needs. Icon: a gamepad glyph of the icon
-- sheet in White, no cap. With no cap asset the cap is a flat White box. The face of the letter is built from
-- the type tokens here because Surface may not require Kit.Text (API2 2.1).
local function capTextSize(ctx)
	local caps = ctx.Class == "Compact" and Tokens.Cap.Compact or Tokens.Cap.Regular
	local raw = math.floor(caps.Value * ctx.Scale / Type.CapRatio + HALF)
	return math.clamp(raw, Type.MinTextSize, Type.MaxTextSize)
end

local KEY_CAP = {
	Name = "Surface.KeyCap",
	Root = "KeyCap",
	Keys = KEY_CAP_KEYS,
	Validate = function(values)
		if values.Text ~= nil and type(values.Text) ~= "string" then
			error("Surface.KeyCap: Text must be a string", 3)
		end
		if values.Icon ~= nil and (type(values.Icon) ~= "string" or Sprites.Icons.Glyphs[values.Icon] == nil) then
			error("Surface.KeyCap: unknown icon " .. tostring(values.Icon), 3)
		end
		checkNumber("Surface.KeyCap", "Size", values.Size, false)
	end,
	Build = function(ctx, state, scope)
		local root = Instance.new("ImageLabel")
		root.Name = "KeyCap"
		root.BorderSizePixel = 0
		root.BackgroundColor3 = Colour.White

		local letter = Instance.new("TextLabel")
		letter.Name = "Letter"
		letter.BackgroundTransparency = 1
		letter.BorderSizePixel = 0
		letter.Size = UDim2.fromScale(1, 1)
		letter.Text = ""
		letter.TextColor3 = Colour.Ink
		letter.TextXAlignment = Enum.TextXAlignment.Center
		letter.TextYAlignment = Enum.TextYAlignment.Center
		letter.FontFace = Font.new(Type.Family, Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic)
		letter.Parent = root

		local function render()
			local size = ctx.Px(state.Size or Space.KeyCapSize)
			local glyphName = state.Icon
			if glyphName ~= nil then
				local sheet = Sprites.Icons
				local cell = sheet.Cell
				local glyph = sheet.Glyphs[glyphName]
				write(root, "ScaleType", Enum.ScaleType.Stretch)
				write(root, "Image", Tokens.Asset(sheet.Asset) or "")
				write(root, "ImageRectOffset", Vector2.new(glyph[1] * cell, glyph[2] * cell))
				write(root, "ImageRectSize", Vector2.new(cell, cell))
				write(root, "ImageColor3", Colour.White)
				write(root, "BackgroundTransparency", 1)
				write(root, "Size", UDim2.fromOffset(size, size))
				write(letter, "Visible", false)
				return
			end

			local asset = Tokens.Asset("KeyCap")
			local slice = Tokens.Slices.KeyCap
			local textSize = capTextSize(ctx)
			write(letter, "Text", string.upper(state.Text or ""))
			write(letter, "TextSize", textSize)
			write(letter, "Position", UDim2.fromOffset(0, -math.floor(Type.BaselineShift * textSize + HALF)))
			write(letter, "Visible", true)
			local pad = ctx.Px(Space.Gap)
			local width = math.max(size, math.ceil(letter.TextBounds.X) + pad + pad)
			write(root, "Image", asset or "")
			write(root, "ImageRectOffset", Vector2.zero)
			write(root, "ImageRectSize", Vector2.zero)
			write(root, "ImageColor3", Colour.White)
			write(root, "BackgroundTransparency", asset and 1 or 0)
			if asset and slice then
				write(root, "ScaleType", Enum.ScaleType.Slice)
				write(root, "SliceCenter", slice.Center)
				write(root, "SliceScale", size / (slice.Center.Min.X + slice.Center.Max.X))
			else
				write(root, "ScaleType", Enum.ScaleType.Stretch)
			end
			write(root, "Size", UDim2.fromOffset(width, size))
		end

		-- A wider word (SPACE, ESC) widens the cap when its bounds arrive; the connection ends with the scope.
		scope:connect(letter:GetPropertyChangedSignal("TextBounds"), function()
			if root.Parent ~= nil and letter.Visible then
				render()
			end
		end)

		return root, render
	end,
}

function Surface.KeyCap(parent, props, scope)
	return make(parent, props, scope, KEY_CAP)
end

-- Divider -----------------------------------------------------------------------------------------------
-- One hairline Frame across its parent: between list rows, and upright in the status strip.
local DIVIDER = {
	Name = "Surface.Divider",
	Root = "Divider",
	Keys = DIVIDER_KEYS,
	Validate = function(values)
		checkNumber("Surface.Divider", "Opacity", values.Opacity, false)
	end,
	Build = function(ctx, state)
		local root = plainFrame("Divider")
		root.BackgroundColor3 = Colour.White

		local function render()
			local hair = ctx.Hair(Space.Hairline)
			write(root, "BackgroundTransparency", 1 - (state.Opacity or Opacity.HairBottom))
			if state.Vertical == true then
				write(root, "Size", UDim2.new(0, hair, 1, 0))
			else
				write(root, "Size", UDim2.new(1, 0, 0, hair))
			end
		end

		return root, render
	end,
}

function Surface.Divider(parent, props, scope)
	return make(parent, props, scope, DIVIDER)
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
