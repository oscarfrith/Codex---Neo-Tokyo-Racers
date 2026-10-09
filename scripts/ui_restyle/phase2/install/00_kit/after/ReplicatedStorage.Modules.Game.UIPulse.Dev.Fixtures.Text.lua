-- Owns the gallery fixtures for Kit.Text; does not own the gallery, its stage or any game data.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Text. Requires: Tokens, Text.
local Kit = script.Parent.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Text = require(Kit.Text)

local Space = Tokens.Space

local ROLES = {
	"ScreenTitle", "SectionHead", "ButtonMain", "Button", "MenuButtonMain", "MenuButton", "TileName",
	"TileNameSmall", "Status", "Tab", "Value", "Label", "Body",
}
local LONG_SENTENCE = "Buy Zephyr to unlock this part. Fitted modules stay with the vehicle when it is parked, "
	.. "and every stat shown here already includes them."
local TILE_TEXT_WIDTH = Space.TileWidth - Space.Pad - Space.Pad

-- One state per role first (the default is the screen title), then the box rules and the long strings.
local labelStates = {
	{ Id = "ScreenTitle", Props = { Text = "Customise", Role = "ScreenTitle", Shadow = true } },
	{ Id = "SectionHead", Props = { Text = "Wing 2/4", Role = "SectionHead", Shadow = true } },
	{ Id = "ButtonMain", Props = { Text = "Choose vehicle", Role = "ButtonMain" } },
	{ Id = "Button", Props = { Text = "View records", Role = "Button" } },
	{ Id = "MenuButtonMain", Props = { Text = "Choose vehicle", Role = "MenuButtonMain" } },
	{ Id = "MenuButton", Props = { Text = "View records", Role = "MenuButton" } },
	{ Id = "TileName", Props = { Text = "Shifted Canal Sprint", Role = "TileName" } },
	{ Id = "TileNameSmall", Props = { Text = "Drift Thrusters", Role = "TileNameSmall" } },
	{ Id = "Status", Props = { Text = "$3,613,696", Role = "Status", Colour = "Yellow" } },
	{ Id = "Tab", Props = { Text = "Upgrades", Role = "Tab", Colour = "TextMuted" } },
	{ Id = "Value", Props = { Text = "01:02.000", Role = "Value" } },
	{ Id = "Label", Props = { Text = "Spine - D 321", Role = "Label", Colour = "TextSecondary", Upper = true } },
	{ Id = "Body", Props = { Text = "Spine Wing Standard", Role = "Body", Colour = "TextSecondary" } },
	{ Id = "Truncated", Props = { Text = "Shifted Canal Sprint Reverse Extended", Role = "TileName",
		MaxWidth = TILE_TEXT_WIDTH } },
	{ Id = "WrappedName", Props = { Text = "Drift Thrusters Evolution", Role = "TileNameSmall", Wrap = true,
		MaxWidth = TILE_TEXT_WIDTH } },
	{ Id = "WrappedBody", Props = { Text = LONG_SENTENCE, Role = "Body", Colour = "TextSecondary", Wrap = true,
		MaxWidth = Space.StatPanelWidth } },
	{ Id = "RightAligned", Props = { Text = "+0.6", Role = "Value", Colour = "Cyan", Align = "Right",
		MaxWidth = Space.ButtonMainMinWidth } },
	{ Id = "Centred", Props = { Text = "Race complete", Role = "SectionHead", Align = "Centre",
		MaxWidth = Space.ConfirmWidth } },
	{ Id = "LowerCase", Props = { Text = "Mixed Case kept", Role = "Button", Upper = false } },
	{ Id = "Unfixed", Props = { Text = "Grows with Text Size", Role = "Value", Fixed = false } },
	{ Id = "ValueFixedByDefault", Props = { Text = "01:03.275", Role = "Value" } },
	{ Id = "LabelGrowsByDefault", Props = { Text = "Fitted wing", Role = "Label", Colour = "TextSecondary", Upper = true } },
	{ Id = "LabelFixed", Props = { Text = "Owned x2", Role = "Label", Fixed = true, Upper = true } },
	{ Id = "ShadowOverScene", Props = { Text = "Showroom loop", Role = "ScreenTitle", Shadow = true } },
	{ Id = "ShadowBody", Props = { Text = "Select a vehicle to spawn it", Role = "Body", Shadow = true } },
	{ Id = "Danger", Props = { Text = "Despawn", Role = "Button", Colour = "Danger" } },
	{ Id = "Empty", Props = { Text = "", Role = "TileName" } },
}

-- Every role in one column, so sizes and faces can be compared in a single capture.
local ROLES_KEYS = { Sample = true, Colour = true, Shadow = true, Name = true, LayoutOrder = true, Visible = true }

local function mountRoles(parent, props, scope, ctx)
	for key in props do
		if not ROLES_KEYS[key] then
			error("Fixtures.Text.Roles: unknown key " .. tostring(key), 2)
		end
	end

	local root = Instance.new("Frame")
	root.Name = props.Name or "TextRoles"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.Visible = props.Visible ~= false
	if props.LayoutOrder ~= nil then
		root.LayoutOrder = props.LayoutOrder
	end

	local list = Instance.new("UIListLayout")
	list.Name = "List"
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, ctx.Px(Space.Gap))
	list.Parent = root

	local labels = {}
	for index, role in ROLES do
		labels[index] = Text.Label(root, {
			Name = role,
			LayoutOrder = index,
			Text = role .. " " .. (props.Sample or ""),
			Role = role,
			Colour = props.Colour,
			Shadow = props.Shadow,
		}, scope)
	end

	local component = { Instance = root }
	local destroyed = false

	function component.Set(patch)
		for key in patch do
			if not ROLES_KEYS[key] then
				error("Fixtures.Text.Roles: unknown key " .. tostring(key), 2)
			end
		end
		if destroyed then
			return
		end
		if patch.Name ~= nil then
			root.Name = patch.Name
		end
		if patch.LayoutOrder ~= nil then
			root.LayoutOrder = patch.LayoutOrder
		end
		if patch.Visible ~= nil then
			root.Visible = patch.Visible
		end
		for index, role in ROLES do
			local labelPatch = {}
			if patch.Sample ~= nil then
				labelPatch.Text = role .. " " .. patch.Sample
			end
			if patch.Colour ~= nil then
				labelPatch.Colour = patch.Colour
			end
			if patch.Shadow ~= nil then
				labelPatch.Shadow = patch.Shadow
			end
			labels[index].Set(labelPatch)
		end
	end

	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		for _, label in labels do
			label.Destroy()
		end
		root:Destroy()
	end

	root.Parent = parent
	return component
end

-- Text.RawLabel: the plain label kit modules build inside budgeted components. One per role in a column; the
-- fixture writes the text, as a kit module would.
local RAW_KEYS = { Sample = true, Colour = true, Name = true, LayoutOrder = true, Visible = true }

local function mountRaw(parent, props, scope, ctx)
	for key in props do
		if not RAW_KEYS[key] then
			error("Fixtures.Text.RawLabel: unknown key " .. tostring(key), 2)
		end
	end

	local root = Instance.new("Frame")
	root.Name = props.Name or "RawLabels"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.Visible = props.Visible ~= false

	local list = Instance.new("UIListLayout")
	list.Name = "List"
	list.FillDirection = Enum.FillDirection.Vertical
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, ctx.Px(Space.Gap))
	list.Parent = root

	local labels = {}
	local function paint(sample, colour)
		for index, role in ROLES do
			local label = labels[index]
			label.Text = string.upper(role .. " " .. sample)
			if colour ~= nil then
				label.TextColor3 = Tokens.Colour[colour]
			end
		end
	end
	for index, role in ROLES do
		local label = Text.RawLabel(root, role, ctx)
		label.Name = role
		label.LayoutOrder = index
		labels[index] = label
	end
	paint(props.Sample or "", props.Colour)

	local component = { Instance = root }
	local destroyed = false

	function component.Set(patch)
		for key in patch do
			if not RAW_KEYS[key] then
				error("Fixtures.Text.RawLabel: unknown key " .. tostring(key), 2)
			end
		end
		if destroyed then
			return
		end
		if patch.Visible ~= nil then
			root.Visible = patch.Visible
		end
		if patch.Sample ~= nil or patch.Colour ~= nil then
			props.Sample = patch.Sample or props.Sample
			props.Colour = patch.Colour or props.Colour
			paint(props.Sample or "", props.Colour)
		end
	end

	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		root:Destroy()
	end

	root.Parent = parent
	return component
end

return {
	{
		Id = "Text.RawLabel",
		Frame = "Bare",
		States = {
			{ Id = "Default", Props = { Sample = "Spine Wing 0123456789" } },
			{ Id = "Money", Props = { Sample = "$3,613,696", Colour = "Yellow" } },
			{ Id = "Longest", Props = { Sample = "Shifted Canal Sprint Reverse 9,999,999", Colour = "TextSecondary" } },
		},
		Mount = mountRaw,
	},
	{
		Id = "Text.Label",
		Frame = "Bare",
		States = labelStates,
		Mount = function(parent, props, scope, _ctx)
			return Text.Label(parent, props, scope)
		end,
	},
	{
		Id = "Text.Roles",
		Frame = "Bare",
		States = {
			{ Id = "Default", Props = { Sample = "Spine Wing 0123456789" } },
			{ Id = "Shadow", Props = { Sample = "Spine Wing 0123456789", Shadow = true } },
			{ Id = "Secondary", Props = { Sample = "$3,613,696 - 01:02.000", Colour = "TextSecondary" } },
			{ Id = "Longest", Props = { Sample = "Shifted Canal Sprint Reverse 9,999,999" } },
		},
		Mount = mountRoles,
	},
}
