-- Owns the gallery fixtures for Kit.Surface; does not own the gallery, its stage or any game data.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Surface. Requires: Tokens, Sprites, Text, Surface.
local Kit = script.Parent.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Sprites = require(Kit.Sprites)
local Text = require(Kit.Text)
local Surface = require(Kit.Surface)

local Colour = Tokens.Colour
local Opacity = Tokens.Opacity
local Space = Tokens.Space

-- A fixture-only stand-in for the element a Hairline or Glow belongs to. The slate is a child named Fill, so
-- a Glow (ZIndex one below the host) draws underneath it, as it does under a tile's fill.
local function newHost(parent, ctx, name, width, height)
	local host = Instance.new("Frame")
	host.Name = name
	host.BackgroundTransparency = 1
	host.BorderSizePixel = 0
	host.Size = UDim2.fromOffset(ctx.Px(width), ctx.Px(height))

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Colour.Slate
	fill.BackgroundTransparency = 1 - Opacity.Panel
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = host

	host.Parent = parent
	return host
end

-- The gallery sees the host as the component; Set goes to the surface inside it.
local function hosted(host, inner, extras)
	local component = { Instance = host }
	local destroyed = false

	function component.Set(patch)
		if not destroyed then
			inner.Set(patch)
		end
	end

	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if extras then
			for _, extra in extras do
				extra.Destroy()
			end
		end
		inner.Destroy()
		host:Destroy()
	end

	return component
end

local function mountPanel(parent, props, scope, _ctx)
	local panel = Surface.Panel(parent, props, scope)
	Text.Label(panel.Content, { Name = "Sample", Text = "Stinger", Role = "SectionHead" }, scope)
	return panel
end

local function mountHairline(parent, props, scope, ctx)
	local host = newHost(parent, ctx, "HairlineHost", Space.ListWidth, Space.ButtonHeight)
	return hosted(host, Surface.Hairline(host, props, scope))
end

local GLOW_HOSTS = {
	Tile = { Width = Space.TileWidth, Height = Space.TileHeight },
	Button = { Width = Space.ButtonMainMinWidth, Height = Space.ButtonHeight },
	Line = { Width = Space.TileWidth, Height = Space.TileBaseLine },
	Ring = { Width = Space.IconButton, Height = Space.IconButton },
}

local function mountGlow(parent, props, scope, ctx)
	local size = GLOW_HOSTS[props.Kind] or GLOW_HOSTS.Tile
	local host = newHost(parent, ctx, "GlowHost", size.Width, size.Height)
	return hosted(host, Surface.Glow(host, props, scope))
end

local function mountIcon(parent, props, scope, ctx)
	local host = newHost(parent, ctx, "IconHost", props.Size, props.Size)
	return hosted(host, Surface.Icon(host, props, scope))
end

local function mountMapIcon(parent, props, scope, ctx)
	local host = newHost(parent, ctx, "MapIconHost", props.Size, props.Size)
	local icon = Surface.MapIcon(host, props, scope)
	-- A map icon anchors on its centre or its pin tip; the host cell shows where that point is.
	icon.Instance.Position = UDim2.fromScale(0.5, 0.5)
	return hosted(host, icon)
end

local function mountOn(constructor, name, width, height)
	return function(parent, props, scope, ctx)
		local host = newHost(parent, ctx, name, width, height)
		return hosted(host, constructor(host, props, scope))
	end
end

-- Every glyph on a sheet in name order, each in its own slate cell so the boxes show with no sheet uploaded.
-- Map = true shows the map sheet (Surface.MapIcon) instead of the icon sheet.
local SHEET_KEYS = { Colour = true, Size = true, Map = true }

local function mountSheet(parent, props, scope, ctx)
	for key in props do
		if not SHEET_KEYS[key] then
			error("Fixtures.Surface.IconSheet: unknown key " .. tostring(key), 2)
		end
	end
	local map = props.Map == true

	local names = {}
	for name in (map and Sprites.MapIcons or Sprites.Icons).Glyphs do
		table.insert(names, name)
	end
	table.sort(names)

	local cell = ctx.Px(props.Size)
	local gap = ctx.Px(Space.Gap)
	local columns = math.max(1, math.ceil(math.sqrt(#names)))
	local rows = math.ceil(#names / columns)

	local root = Instance.new("Frame")
	root.Name = "IconSheet"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromOffset(columns * (cell + gap) - gap, rows * (cell + gap) - gap)

	local grid = Instance.new("UIGridLayout")
	grid.Name = "Grid"
	grid.CellSize = UDim2.fromOffset(cell, cell)
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	grid.FillDirectionMaxCells = columns
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = root

	local icons = {}
	for index, name in names do
		local slot = Instance.new("Frame")
		slot.Name = name
		slot.LayoutOrder = index
		slot.BackgroundColor3 = Colour.Slate
		slot.BackgroundTransparency = 1 - Opacity.Panel
		slot.BorderSizePixel = 0
		slot.Parent = root
		if map then
			icons[index] = Surface.MapIcon(slot, { Icon = name, Colour = props.Colour, Size = props.Size }, scope)
			icons[index].Instance.AnchorPoint = Vector2.zero
		else
			icons[index] = Surface.Icon(slot, { Icon = name, Colour = props.Colour, Size = props.Size }, scope)
		end
	end

	local component = { Instance = root }
	local destroyed = false

	function component.Set(patch)
		for key in patch do
			if not SHEET_KEYS[key] then
				error("Fixtures.Surface.IconSheet: unknown key " .. tostring(key), 2)
			end
		end
		if destroyed or patch.Colour == nil then
			return
		end
		for _, icon in icons do
			icon.Set({ Colour = patch.Colour })
		end
	end

	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		for _, icon in icons do
			icon.Destroy()
		end
		root:Destroy()
	end

	root.Parent = parent
	return component
end

return {
	{
		Id = "Surface.Panel",
		Frame = "Bare",
		States = {
			{ Id = "Default", Props = { Width = Space.StatPanelWidth, Height = Space.TileHeight } },
			{ Id = "NoHairlines", Props = { Width = Space.StatPanelWidth, Height = Space.TileHeight,
				Hairlines = false } },
			{ Id = "WidePad", Props = { Width = Space.ConfirmWidth, Height = Space.TileHeight,
				Pad = Space.Pad + Space.Pad } },
			{ Id = "NoPad", Props = { Width = Space.TileWidth, Height = Space.TileHeight, Pad = 0 } },
		},
		Mount = mountPanel,
	},
	{
		Id = "Surface.Hairline",
		Frame = "Bare",
		States = {
			{ Id = "Top", Props = { Edge = "Top" } },
			{ Id = "Bottom", Props = { Edge = "Bottom" } },
			{ Id = "PinkBase", Props = { Edge = "Bottom", Colour = "Pink", Opacity = 1 } },
			{ Id = "CyanTop", Props = { Edge = "Top", Colour = "Cyan", Opacity = 1 } },
		},
		Mount = mountHairline,
	},
	{
		Id = "Surface.Scrim",
		Frame = "Bare",
		States = {
			{ Id = "Menu", Props = { Kind = "Menu" } },
			{ Id = "Confirm", Props = { Kind = "Confirm" } },
			{ Id = "Garage", Props = { Kind = "Garage" } },
			{ Id = "Hud", Props = { Kind = "Hud" } },
		},
		Mount = function(parent, props, scope, _ctx)
			return Surface.Scrim(parent, props, scope)
		end,
	},
	{
		Id = "Surface.Glow",
		Frame = "Bare",
		States = {
			{ Id = "Tile", Props = { Kind = "Tile", Colour = "Pink" } },
			{ Id = "Button", Props = { Kind = "Button", Colour = "Pink" } },
			{ Id = "Line", Props = { Kind = "Line", Colour = "Pink" } },
			{ Id = "RingCyan", Props = { Kind = "Ring", Colour = "Cyan" } },
			{ Id = "RingPink", Props = { Kind = "Ring", Colour = "Pink" } },
		},
		Mount = mountGlow,
	},
	{
		Id = "Surface.Icon",
		Frame = "Bare",
		States = {
			{ Id = "Car", Props = { Icon = "car", Colour = "White", Size = Space.IconButton } },
			{ Id = "Lock", Props = { Icon = "lock", Colour = "TextMuted", Size = Space.IconButton } },
			{ Id = "Coin", Props = { Icon = "coin", Colour = "Ink", Size = Space.BadgeSmall } },
			{ Id = "Boost", Props = { Icon = "boost", Colour = "Cyan", Size = Space.BadgeLarge } },
			{ Id = "Chevron", Props = { Icon = "chevron_right", Colour = "Pink", Size = Space.ButtonHeightLarge } },
			{ Id = "Disabled", Props = { Icon = "steering_wheel", Colour = "White", Size = Space.IconButton, Opacity = Opacity.Disabled } },
			{ Id = "Locked", Props = { Icon = "lock", Colour = "White", Size = Space.IconButton, Opacity = Opacity.Locked } },
		},
		Mount = mountIcon,
	},
	{
		Id = "Surface.TitleMark",
		Frame = "Bare",
		States = {
			{ Id = "Default", Props = {} },
			{ Id = "Modal", Props = { Height = Space.BadgeLarge } },
			{ Id = "Small", Props = { Height = Space.BadgeSmall } },
		},
		Mount = mountOn(Surface.TitleMark, "TitleMarkHost", Space.ButtonHeightLarge, Space.ButtonHeightLarge),
	},
	{
		Id = "Surface.MapIcon",
		Frame = "Bare",
		States = {
			{ Id = "Race", Props = { Icon = "Race", Colour = "Pink", Size = Space.IconButton } },
			{ Id = "Garage", Props = { Icon = "Garage", Colour = "White", Size = Space.IconButton } },
			{ Id = "WaypointPin", Props = { Icon = "Waypoint", Colour = "Cyan", Size = Space.IconButton } },
			{ Id = "TaxiDropPin", Props = { Icon = "TaxiDrop", Colour = "Yellow", Size = Space.IconButton } },
			{ Id = "Player", Props = { Icon = "Player", Colour = "White", Size = Space.BadgeLarge } },
			{ Id = "MarkerTint", Props = { Icon = "Dealership", Size = Space.IconButton, Tint = Tokens.Tier.A } },
		},
		Mount = mountMapIcon,
	},
	{
		Id = "Surface.KeyCap",
		Frame = "Bare",
		States = {
			{ Id = "E", Props = { Text = "E" } },
			{ Id = "F", Props = { Text = "F" } },
			{ Id = "Space", Props = { Text = "Space" } },
			{ Id = "Esc", Props = { Text = "Esc" } },
			{ Id = "PadA", Props = { Icon = "pad_a" } },
			{ Id = "PadX", Props = { Icon = "pad_x" } },
			{ Id = "PadRightTrigger", Props = { Icon = "pad_rt" } },
			{ Id = "Large", Props = { Text = "M", Size = Space.ButtonHeight } },
		},
		Mount = mountOn(Surface.KeyCap, "KeyCapHost", Space.TileWidth, Space.ButtonHeightLarge),
	},
	{
		Id = "Surface.Divider",
		Frame = "Bare",
		States = {
			{ Id = "Row", Props = {} },
			{ Id = "Upright", Props = { Vertical = true } },
			{ Id = "Strong", Props = { Opacity = Opacity.HairTop } },
		},
		Mount = mountOn(Surface.Divider, "DividerHost", Space.ListWidth, Space.ButtonHeight),
	},
	{
		Id = "Surface.IconSheet",
		Frame = "Bare",
		States = {
			{ Id = "White", Props = { Colour = "White", Size = Space.IconButton } },
			{ Id = "Cyan", Props = { Colour = "Cyan", Size = Space.IconButton } },
			{ Id = "Small", Props = { Colour = "White", Size = Space.BadgeSmall } },
		},
		Mount = mountSheet,
	},
	{
		Id = "Surface.MapIconSheet",
		Frame = "Bare",
		States = {
			{ Id = "White", Props = { Colour = "White", Size = Space.IconButton, Map = true } },
			{ Id = "Pink", Props = { Colour = "Pink", Size = Space.IconButton, Map = true } },
		},
		Mount = mountSheet,
	},
}
