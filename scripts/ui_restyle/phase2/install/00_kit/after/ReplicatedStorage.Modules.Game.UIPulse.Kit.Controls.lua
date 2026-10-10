-- Owns the Pulse Button, ButtonRow, Tabs, Header, IconButton, Switch, Stepper, Slider, Swatch and Dropdown components; it does not own focus rules, text metrics, tokens or any screen's layout.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.Controls. Requires: Tokens, Metrics, Text, Surface, Input.
local UserInputService = game:GetService("UserInputService")

local Tokens = require(script.Parent.Tokens)
local Metrics = require(script.Parent.Metrics)
local Text = require(script.Parent.Text)
local Surface = require(script.Parent.Surface)
local Input = require(script.Parent.Input)

local Controls = {}

local Space = Tokens.Space
local Opacity = Tokens.Opacity
local Type = Tokens.Type

-- Design ratios (not pixels). Every length below is a token, or a token times one of these.
local COMPACT_UNIT = Space.TouchGap / Space.Pad -- general 1080 px to Compact dp factor (8 / 22)
local ICON_PER_CAP = 1.5 -- icon box against the cap height of the text beside it
local ICON_ONLY = 0.55 -- icon box against the side of an Icon button
local HALF = 0.5
local CHEVRONS = " \u{00BB}" -- trailing chevrons of the Main and Buy buttons

---------------------------------------------------------------------------------------------------
-- Shared helpers (Kit.Collections carries the same block; the two modules may not require each other)
---------------------------------------------------------------------------------------------------

local function put(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function colourOf(role)
	local value = Tokens.Colour[role]
	if value == nil then
		error("[Pulse.Controls] unknown colour role " .. tostring(role), 3)
	end
	return value
end

local function tierColour(tier)
	local value = Tokens.Tier[tier]
	if value == nil then
		error("[Pulse.Controls] unknown tier " .. tostring(tier), 3)
	end
	return value
end

local function isCompact(ctx)
	return ctx.Class == "Compact"
end

local function isTouchy(ctx)
	return ctx.Class == "Compact" or ctx.Input == "Touch"
end

local function unit(ctx, design)
	if isCompact(ctx) then
		return design * COMPACT_UNIT
	end
	return design
end

local function capOf(ctx, role)
	local caps = isCompact(ctx) and Tokens.Cap.Compact or Tokens.Cap.Regular
	return caps[role]
end

local function textOf(value)
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local COMMON_KEYS = { "Name", "LayoutOrder", "Visible" }

local function keySet(list)
	local set = {}
	for _, key in ipairs(COMMON_KEYS) do
		set[key] = true
	end
	for _, key in ipairs(list) do
		set[key] = true
	end
	return set
end

local function readProps(kind, keys, defaults, props)
	local state = {}
	for key, value in pairs(defaults) do
		state[key] = value
	end
	if props ~= nil then
		for key, value in pairs(props) do
			if not keys[key] then
				error(string.format("[Pulse.Controls] %s: unknown key %s", kind, tostring(key)), 3)
			end
			state[key] = value
		end
	end
	return state
end

-- Validates the whole patch before anything is stored. Returns true when a value differs.
local function mergePatch(kind, keys, state, patch)
	if type(patch) ~= "table" then
		error(string.format("[Pulse.Controls] %s.Set expects a table", kind), 3)
	end
	for key in pairs(patch) do
		if not keys[key] then
			error(string.format("[Pulse.Controls] %s: unknown key %s", kind, tostring(key)), 3)
		end
	end
	local changed = false
	for key, value in pairs(patch) do
		if state[key] ~= value then
			state[key] = value
			changed = true
		end
	end
	return changed
end

local function listen(scope, bag, signal, callback)
	local connection = scope:connect(signal, callback)
	table.insert(bag, connection)
	return connection
end

-- A bag holds connections and child components (tables with a Destroy function).
local function release(bag)
	for index = #bag, 1, -1 do
		local item = bag[index]
		bag[index] = nil
		if typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		elseif type(item) == "table" and type(item.Destroy) == "function" then
			item.Destroy()
		elseif type(item) == "table" and type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

local function applyCommon(root, state)
	put(root, "LayoutOrder", state.LayoutOrder or 0)
	put(root, "Visible", state.Visible ~= false)
end

-- A TextLabel or TextButton with no background and a size lock (the text does not follow the player's
-- Text Size setting; these all sit in fixed boxes).
local function newText(className, parent, name)
	local object = Instance.new(className)
	object.Name = name
	object.BackgroundTransparency = 1
	object.BorderSizePixel = 0
	object.Text = ""
	object.TextWrapped = false
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextYAlignment = Enum.TextYAlignment.Center
	local lock = Instance.new("UITextSizeConstraint")
	lock.Name = "SizeLock"
	lock.MinTextSize = 1
	lock.Parent = object
	object.Parent = parent
	return object
end

local function face(object, role, ctx)
	local textSize = Text.SizeFor(role, ctx)
	put(object, "FontFace", Text.Font(role))
	put(object, "TextSize", textSize)
	put(object.SizeLock, "MaxTextSize", textSize)
	return textSize
end

local function textWidth(object)
	return math.ceil(object.TextBounds.X)
end

local function baselineShift(textSize)
	return math.floor(Type.BaselineShift * textSize + HALF)
end

local function italicPad(ctx, role)
	return ctx.Px(Type.ItalicPad * capOf(ctx, role))
end

local function newFrame(parent, name)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function newButton(name)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Text = ""
	button.TextTransparency = 1
	return button
end

-- True when the parent has a width of its own. A slot anchor (zero size) has none.
local function hasWidth(parent)
	local size = parent.Size
	return size.X.Scale ~= 0 or size.X.Offset ~= 0
end

-- Kit.Layers names its slot frames Slot<Name>; a child of one copies its anchor (API1 8).
local function isSlot(parent)
	return string.sub(parent.Name, 1, 4) == "Slot"
end

-- The glow of a plate. A child always draws over its parent, so the 9-slice cannot sit inside the plate it
-- lights: it goes in a Frame named Glow, a sibling under the plate, which the caller keeps on the plate's box.
local function newGlow(root, scope, bag, kind)
	local box = newFrame(root, "Glow")
	box.Active = false
	box.ZIndex = 0
	box.Visible = false
	table.insert(bag, Surface.Glow(box, { Name = "Image", Kind = kind, Colour = "Pink" }, scope))
	return box
end

-- A scope the kit owns for one drag, one focus or one opening; it is always destroyed by its component.
local function miniScope()
	local items = {}
	local scope = {}
	function scope:connect(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(items, connection)
		return connection
	end
	function scope:add(item)
		table.insert(items, item)
		return item
	end
	function scope:destroy()
		for index = #items, 1, -1 do
			local item = items[index]
			items[index] = nil
			if typeof(item) == "RBXScriptConnection" then
				item:Disconnect()
			elseif type(item) == "function" then
				item()
			elseif type(item) == "table" and type(item.Destroy) == "function" then
				item.Destroy()
			elseif type(item) == "table" and type(item.Disconnect) == "function" then
				item:Disconnect()
			end
		end
	end
	return scope
end

-- Hover, press and focus flags of a control, each change followed by `refresh`.
local function watchPointer(scope, bag, button, ctx, flags, refresh)
	listen(scope, bag, button.MouseEnter, function()
		if ctx.Input ~= "Touch" then
			flags.Hover = true
			refresh()
		end
	end)
	listen(scope, bag, button.MouseLeave, function()
		flags.Hover = false
		flags.Pressed = false
		refresh()
	end)
	listen(scope, bag, button.MouseButton1Down, function()
		flags.Pressed = true
		refresh()
	end)
	listen(scope, bag, button.MouseButton1Up, function()
		flags.Pressed = false
		refresh()
	end)
	Input.Focusable(button, {
		OnFocus = function(focused)
			flags.Focused = focused == true
			refresh()
		end,
	})
end

---------------------------------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------------------------------

local BUTTON_KEYS = keySet({
	"Variant", "Text", "Icon", "Disabled", "Locked", "Size", "MinWidth", "MarkKey", "OnActivated", "IconOnly", "Selected",
})
local BUTTON_DEFAULTS = { Variant = "Default", Size = "Menu" }

-- Pure. flags: Disabled, Locked, Inactive (Active switched off from outside), Hover, Pressed, Focused, Selected.
-- Hair: the plate hairlines show. BaseLine: false, or the role colour a filled variant keeps as a base line
-- while its fill is white (preview r20b), so the role survives focus.
function Controls._resolveButton(variant, flags)
	local look = {
		Fill = "Slate",
		FillOpacity = Opacity.ButtonPlate,
		Ink = "White",
		Gradient = false,
		Glow = false,
		Active = true,
		Opacity = 1,
		Hair = true,
		BaseLine = false,
	}
	local role = false
	if variant == "Main" then
		look.Fill = "White"
		look.FillOpacity = 1
		look.Gradient = true
		look.Glow = true
		look.Hair = false
		role = "Pink"
	elseif variant == "Buy" then
		look.Fill = "Yellow"
		look.FillOpacity = 1
		look.Ink = "Ink"
		look.Hair = false
		role = "Yellow"
	elseif variant == "Danger" then
		look.Fill = "Danger"
		look.FillOpacity = 1
		look.Hair = false
		role = "Danger"
	elseif variant ~= "Default" and variant ~= "Icon" then
		error("[Pulse.Controls] Button: unknown Variant " .. tostring(variant), 2)
	end
	if flags.Disabled then
		look.Active = false
		look.Opacity = Opacity.Disabled
		look.Glow = false
		look.Hair = false
	elseif flags.Locked or flags.Inactive then
		look.Active = false
		look.Opacity = Opacity.Locked
		look.Glow = false
	elseif flags.Pressed then
		look.Fill = "TextSecondary"
		look.FillOpacity = 1
		look.Ink = "Ink"
		look.Gradient = false
		look.Hair = false
		look.BaseLine = role
	elseif flags.Hover or flags.Focused or flags.Selected then
		look.Fill = "White"
		look.FillOpacity = 1
		look.Ink = "Ink"
		look.Gradient = false
		look.Hair = false
		look.BaseLine = role
	end
	return look
end

-- Pure. The text a button shows.
function Controls._caption(variant, text)
	if variant == "Icon" or text == nil or text == false or text == "" then
		return ""
	end
	local caption = string.upper(tostring(text))
	if variant == "Main" or variant == "Buy" then
		caption = caption .. CHEVRONS
	end
	return caption
end

local function buttonRole(variant, size)
	local strong = variant == "Main" or variant == "Buy"
	if size == "Large" then
		return strong and "ButtonMain" or "Button"
	elseif size == "Menu" or size == "Hud" then
		return strong and "MenuButtonMain" or "MenuButton"
	end
	error("[Pulse.Controls] Button: unknown Size " .. tostring(size), 3)
end

-- Pure. The drawn height of a button in the units of its class (design px on Regular, dp on Compact).
function Controls._buttonHeight(compact, variant, size)
	if compact then
		if variant == "Icon" then
			return Space.CompactButtonDrawn
		elseif size == "Hud" then
			return Space.CompactHudButton
		elseif size == "Large" then
			return Space.TouchMin
		end
		return Space.CompactButtonDrawn
	end
	if variant == "Icon" then
		return Space.IconButton
	elseif size == "Hud" then
		return Space.HudButtonHeight
	elseif size == "Large" then
		return Space.ButtonHeightLarge
	end
	return Space.ButtonHeight
end

function Controls.Button(parent, props, scope)
	local state = readProps("Button", BUTTON_KEYS, BUTTON_DEFAULTS, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local flags = { Hover = false, Pressed = false, Focused = false, Inactive = false }
	local wroteActive = true
	local destroyed = false
	local marked = nil

	local root = Instance.new("TextButton")
	Metrics.Bind(root, ctx) -- parts built before the root is parented take this context, not the screen's
	root.Name = state.Name or "Button"
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Text = ""
	root.TextTransparency = 1

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Parent = root

	local label = newText("TextLabel", fill, "Label")
	local hairTop = newFrame(fill, "HairTop")
	hairTop.BackgroundColor3 = colourOf("White")
	local hairBottom = newFrame(fill, "HairBottom")
	hairBottom.AnchorPoint = Vector2.new(0, 1)
	hairBottom.Position = UDim2.new(0, 0, 1, 0)
	local gradient = nil
	local glow = nil
	local icon = nil

	local function layout()
		local variant = state.Variant
		local compact = isCompact(ctx)
		local role = buttonRole(variant, state.Size)
		local strong = variant == "Main" or variant == "Buy"
		local iconOnly = variant == "Icon" or state.IconOnly == true

		if variant == "Main" and gradient == nil then
			gradient = Instance.new("UIGradient")
			gradient.Name = "Gradient"
			gradient.Color = ColorSequence.new(colourOf("Pink"), colourOf("Violet"))
			gradient.Parent = fill
			glow = newGlow(root, scope, bag, "Button")
		end

		local drawnDesign = Controls._buttonHeight(compact, variant, state.Size)
		local drawn = ctx.Px(drawnDesign)
		local hit = ctx.Touch(drawnDesign)

		local textSize = face(label, role, ctx)
		local caption = iconOnly and "" or Controls._caption(variant, state.Text)
		put(label, "Text", caption)

		local iconName = textOf(state.Icon)
		local iconDesign = iconOnly and drawnDesign * ICON_ONLY or capOf(ctx, role) * ICON_PER_CAP
		local iconPx = 0
		if iconName then
			iconPx = ctx.Px(iconDesign)
			if icon == nil then
				icon = Surface.Icon(fill, { Name = "Icon", Icon = iconName, Colour = "White", Size = iconDesign }, scope)
				table.insert(bag, icon)
			else
				icon.Set({ Icon = iconName, Size = iconDesign, Visible = true })
			end
		elseif icon ~= nil then
			icon.Set({ Visible = false })
		end

		local textPx = 0
		if caption ~= "" then
			textPx = textWidth(label) + italicPad(ctx, role)
		end
		local gap = 0
		if iconPx > 0 and textPx > 0 then
			gap = ctx.Px(unit(ctx, Space.Gap))
		end
		local group = iconPx + gap + textPx

		local fillWidth, hitWidth
		if iconOnly then
			fillWidth = drawn
			hitWidth = hit
		else
			local pad = ctx.Px(unit(ctx, Space.ButtonPadX + (strong and Space.Gap or 0)))
			local minimum = state.MinWidth or ((strong and not compact) and Space.ButtonMainMinWidth or 0)
			fillWidth = math.max(group + pad + pad, ctx.Px(minimum))
			hitWidth = fillWidth
		end

		local fillPosition = UDim2.fromOffset(math.floor((hitWidth - fillWidth) * HALF), math.floor((hit - drawn) * HALF))
		local fillSize = UDim2.fromOffset(fillWidth, drawn)
		put(root, "Size", UDim2.fromOffset(hitWidth, hit))
		put(fill, "Position", fillPosition)
		put(fill, "Size", fillSize)
		if glow ~= nil then
			put(glow, "Position", fillPosition)
			put(glow, "Size", fillSize)
		end
		put(hairTop, "Size", UDim2.new(1, 0, 0, ctx.Hair(unit(ctx, Space.Hairline))))

		local x = math.floor((fillWidth - group) * HALF)
		if icon ~= nil and iconName then
			put(icon.Instance, "Position", UDim2.fromOffset(x, math.floor((drawn - iconPx) * HALF)))
		end
		put(label, "Position", UDim2.fromOffset(x + iconPx + gap, -baselineShift(textSize)))
		put(label, "Size", UDim2.fromOffset(textPx, drawn))
		put(label, "Visible", textPx > 0)
	end

	local function paint()
		local look = Controls._resolveButton(state.Variant, {
			Disabled = state.Disabled == true,
			Locked = state.Locked == true,
			Inactive = flags.Inactive,
			Hover = flags.Hover,
			Pressed = flags.Pressed,
			Focused = flags.Focused,
			Selected = state.Selected == true,
		})
		put(fill, "BackgroundColor3", colourOf(look.Fill))
		put(fill, "BackgroundTransparency", 1 - look.FillOpacity * look.Opacity)
		if gradient ~= nil then
			put(gradient, "Enabled", look.Gradient)
		end
		put(label, "TextColor3", colourOf(look.Ink))
		put(label, "TextTransparency", 1 - look.Opacity)
		if icon ~= nil then
			icon.Set({ Colour = look.Ink, Opacity = look.Opacity })
		end
		if glow ~= nil then
			put(glow, "Visible", look.Glow)
		end

		local base = look.BaseLine
		local thickness = ctx.Hair(unit(ctx, base and Space.TileBaseLine or Space.Hairline))
		put(hairTop, "BackgroundTransparency", 1 - Opacity.HairButtonTop * look.Opacity)
		put(hairTop, "Visible", look.Hair)
		put(hairBottom, "BackgroundColor3", colourOf(base or "White"))
		put(hairBottom, "BackgroundTransparency", base and 0 or 1 - Opacity.HairButtonBottom * look.Opacity)
		put(hairBottom, "Size", UDim2.new(1, 0, 0, thickness))
		put(hairBottom, "Visible", look.Hair or base ~= false)

		wroteActive = look.Active
		put(root, "Active", look.Active)
	end

	local function mark()
		local key = textOf(state.MarkKey)
		if key and key ~= marked then
			marked = key
			Input.Mark(root, key)
		end
	end

	local function refresh()
		if destroyed then
			return
		end
		layout()
		paint()
	end

	listen(scope, bag, root.MouseEnter, function()
		if ctx.Input ~= "Touch" then
			flags.Hover = true
			refresh()
		end
	end)
	listen(scope, bag, root.MouseLeave, function()
		flags.Hover = false
		flags.Pressed = false
		refresh()
	end)
	listen(scope, bag, root.MouseButton1Down, function()
		flags.Pressed = true
		refresh()
	end)
	listen(scope, bag, root.MouseButton1Up, function()
		flags.Pressed = false
		refresh()
	end)
	listen(scope, bag, root.Activated, function()
		local callback = state.OnActivated
		if callback and root.Active then
			callback()
		end
	end)
	-- A script outside the kit may switch Active off (Classic onboarding does); show the locked look then.
	listen(scope, bag, root:GetPropertyChangedSignal("Active"), function()
		if root.Active ~= wroteActive then
			flags.Inactive = not root.Active
			refresh()
		end
	end)
	listen(scope, bag, label:GetPropertyChangedSignal("TextBounds"), refresh)
	listen(scope, bag, Text.ReadyChanged, refresh)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, refresh)
	end
	Input.Focusable(root, {
		OnFocus = function(focused)
			flags.Focused = focused == true
			refresh()
		end,
	})

	applyCommon(root, state)
	refresh()
	mark()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		if destroyed then
			return
		end
		if not mergePatch("Button", BUTTON_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil and marked == nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		refresh()
		mark()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		release(bag)
		root:Destroy()
	end

	return self
end

---------------------------------------------------------------------------------------------------
-- ButtonRow
---------------------------------------------------------------------------------------------------

local ROW_KEYS = keySet({ "Buttons", "Align", "Size", "Place" })
local ROW_DEFAULTS = { Align = "Right", Size = "Menu", Place = "Slot" }
local ROW_BUTTON_KEYS = {
	Id = true,
	Variant = true,
	Text = true,
	Icon = true,
	Disabled = true,
	Locked = true,
	MinWidth = true,
	MarkKey = true,
	OnActivated = true,
	IconOnly = true,
	Selected = true,
}

-- Pure. The full Button patch for one row entry, so a value dropped from the entry returns to its default.
function Controls._rowPatch(spec, size)
	if type(spec) ~= "table" or type(spec.Id) ~= "string" or spec.Id == "" then
		error("[Pulse.Controls] ButtonRow: every button needs a string Id", 3)
	end
	for key in pairs(spec) do
		if not ROW_BUTTON_KEYS[key] then
			error("[Pulse.Controls] ButtonRow: unknown button key " .. tostring(key), 3)
		end
	end
	return {
		Name = "Button" .. spec.Id,
		Variant = spec.Variant or "Default",
		Text = spec.Text or "",
		Icon = spec.Icon or "",
		Disabled = spec.Disabled == true,
		Locked = spec.Locked == true,
		MinWidth = spec.MinWidth or false,
		MarkKey = spec.MarkKey or "",
		OnActivated = spec.OnActivated or false,
		IconOnly = spec.IconOnly == true,
		Selected = spec.Selected == true,
		Size = size,
	}
end

-- Pure. Does this button give up its text when a Compact row is too wide? Only a secondary button that has an
-- icon to stand for it: never Main or Buy, never one that is icon-only already.
function Controls._rowCollapses(patch)
	return patch.Variant ~= "Main" and patch.Variant ~= "Buy" and patch.Variant ~= "Icon"
		and patch.IconOnly ~= true and textOf(patch.Icon) ~= nil
end

-- Pure. Where a row sits in its parent: the anchor fractions on each axis. In a Layers slot (a Frame named
-- Slot<Name>) the row copies the slot's anchor; in any other parent Align decides, as in Phase 1 (Right: the
-- bottom-right corner; Centre: bottom centre).
function Controls._rowAnchor(parentIsSlot, parentAnchor, align)
	if align ~= "Right" and align ~= "Centre" then
		error("[Pulse.Controls] ButtonRow: unknown Align " .. tostring(align), 2)
	end
	if parentIsSlot then
		return parentAnchor.X, parentAnchor.Y
	elseif align == "Centre" then
		return HALF, 1
	end
	return 1, 1
end

function Controls.ButtonRow(parent, props, scope)
	local state = readProps("ButtonRow", ROW_KEYS, ROW_DEFAULTS, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local entries = {}
	local byId = {}
	local group = nil
	local destroyed = false
	local collapsed = false -- Compact only: the row was wider than the safe area, so its secondary buttons show their icon alone

	local root = Instance.new("Frame")
	root.Name = state.Name or "ButtonRow"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	-- The buttons are built before the row is parented, so they must resolve the row's context, not the screen's.
	Metrics.Bind(root, ctx)

	-- The patch a button is given: its own, or, in a collapsed row, the icon-only form of a secondary button.
	local function shownPatch(patch)
		if collapsed and Controls._rowCollapses(patch) then
			local copy = table.clone(patch)
			copy.IconOnly = true
			return copy
		end
		return patch
	end

	local function layout()
		if destroyed then
			return
		end
		local place = state.Place
		if place ~= "Slot" and place ~= "None" then
			error("[Pulse.Controls] ButtonRow: unknown Place " .. tostring(place), 2)
		end
		local anchorX, anchorY = Controls._rowAnchor(isSlot(parent), parent.AnchorPoint, state.Align)

		local gap = ctx.Px(unit(ctx, Space.Gap))
		if isTouchy(ctx) then
			gap = math.max(gap, Space.TouchGap)
		end
		-- Every Regular row is ButtonHeight high; a shorter (Hud) button sits on the row's bottom edge.
		local height = isCompact(ctx) and 0 or ctx.Px(Space.ButtonHeight)
		for _, entry in ipairs(entries) do
			height = math.max(height, entry.Button.Instance.Size.Y.Offset)
		end
		local x = 0
		for index, entry in ipairs(entries) do
			local instance = entry.Button.Instance
			local size = instance.Size
			if index > 1 then
				x = x + gap
			end
			put(instance, "Position", UDim2.fromOffset(x, height - size.Y.Offset))
			x = x + size.X.Offset
		end
		-- Compact: a row wider than the safe area inside its margins collapses once (it opens again when the
		-- buttons or the screen change). The main button always keeps its text.
		if isCompact(ctx) and not collapsed and ctx.Size ~= nil and ctx.Size.X > 0 then
			local margin = ctx.Px(Space.CompactMargin)
			if x > ctx.Size.X - margin - margin then
				local any = false
				for _, entry in ipairs(entries) do
					any = any or Controls._rowCollapses(entry.Patch)
				end
				if any then
					collapsed = true
					for _, entry in ipairs(entries) do
						entry.Button.Set(shownPatch(entry.Patch))
					end
					layout()
					return
				end
			end
		end
		put(root, "Size", UDim2.fromOffset(x, height))
		if place == "None" then
			return
		end
		-- A half anchor is written as an offset, so the row stays on whole pixels.
		local centredX, centredY = anchorX == HALF, anchorY == HALF
		put(root, "AnchorPoint", Vector2.new(centredX and 0 or anchorX, centredY and 0 or anchorY))
		put(root, "Position", UDim2.new(
			anchorX, centredX and -math.floor(x * HALF) or 0,
			anchorY, centredY and -math.floor(height * HALF) or 0
		))
	end

	local function clear()
		for index = #entries, 1, -1 do
			local entry = entries[index]
			entries[index] = nil
			entry.Connection:Disconnect()
			entry.Button.Destroy()
		end
		byId = {}
		if group ~= nil then
			group.Destroy()
			group = nil
		end
	end

	local function sync()
		local list = state.Buttons or {}
		local patches = {}
		local seen = {}
		for index, spec in ipairs(list) do
			patches[index] = Controls._rowPatch(spec, state.Size)
			if seen[spec.Id] then
				error("[Pulse.Controls] ButtonRow: duplicate Id " .. spec.Id, 2)
			end
			seen[spec.Id] = true
		end
		local same = #list == #entries
		if same then
			for index, spec in ipairs(list) do
				if entries[index].Id ~= spec.Id then
					same = false
					break
				end
			end
		end
		if same then
			for index, patch in ipairs(patches) do
				entries[index].Patch = patch
				entries[index].Button.Set(shownPatch(patch))
			end
		else
			clear()
			collapsed = false
			group = Input.FocusGroup(scope, nil)
			for index, spec in ipairs(list) do
				local button = Controls.Button(root, patches[index], scope)
				local entry = { Id = spec.Id, Button = button, Patch = patches[index] }
				entry.Connection = scope:connect(button.Instance:GetPropertyChangedSignal("Size"), layout)
				entries[index] = entry
				byId[spec.Id] = button
				group.Add(button.Instance, index)
			end
		end
		layout()
	end

	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, function()
			if collapsed then
				-- A new screen size or class: open the row and let layout decide again.
				collapsed = false
				for _, entry in ipairs(entries) do
					entry.Button.Set(entry.Patch)
				end
			end
			layout()
		end)
	end

	applyCommon(root, state)
	sync()
	root.Parent = parent

	local self = { Instance = root }

	function self.Button(id)
		return byId[id]
	end

	function self.Set(patch)
		if destroyed then
			return
		end
		if not mergePatch("ButtonRow", ROW_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		if patch.Buttons ~= nil or patch.Size ~= nil then
			sync()
		else
			layout()
		end
	end

	function self.Destroy()
		if destroyed then
			return
		end
		clear()
		destroyed = true
		release(bag)
		root:Destroy()
	end

	return self
end

---------------------------------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------------------------------

local TABS_KEYS = keySet({ "Tabs", "Selected", "Bumpers", "Triggers", "Style", "OnSelected", "MaxWidth" })
local TAB_KEYS = { Id = true, Text = true, Icon = true, Locked = true, MarkKey = true, Tier = true, Count = true }

-- Pure. flags: Selected, Locked, Hover, Focused, Tier (a tier button). TierInk: the letter is drawn in the
-- tier colour. TierFill: the cell is filled with it (Ink letter). A tier button always shows its base line.
function Controls._resolveTab(flags)
	local tier = flags.Tier == true
	local look = {
		Ink = "TextMuted",
		Fill = false,
		Underline = flags.Selected == true or tier,
		Opacity = 1,
		Active = true,
		TierInk = false,
		TierFill = false,
	}
	if flags.Locked then
		look.Opacity = Opacity.TabLocked
		look.Active = false
		if flags.Selected and tier then
			look.TierFill = true
			look.Ink = "Ink"
		elseif flags.Selected then
			look.Ink = "White"
		elseif tier then
			look.TierInk = true
		end
	elseif flags.Focused then
		look.Ink = "Ink"
		look.Fill = true
	elseif flags.Selected and tier then
		look.TierFill = true
		look.Ink = "Ink"
	elseif tier then
		look.TierInk = true
	elseif flags.Selected or flags.Hover then
		look.Ink = "White"
	end
	return look
end

-- Pure. The next tab that is not locked, walking from `current` by `direction` (-1 or 1); nil when none.
function Controls._stepTab(list, current, direction)
	local from = nil
	for index, spec in ipairs(list) do
		if spec.Id == current then
			from = index
			break
		end
	end
	if from == nil then
		from = direction > 0 and 0 or (#list + 1)
	end
	local index = from + direction
	while index >= 1 and index <= #list do
		if list[index].Locked ~= true then
			return list[index].Id
		end
		index = index + direction
	end
	return nil
end

-- Pure. The text a tab shows: its name, then its count.
function Controls._tabCaption(spec)
	local caption = string.upper(tostring(spec.Text or ""))
	local count = textOf(spec.Count)
	if count then
		if caption == "" then
			return count
		end
		return caption .. " " .. count
	end
	return caption
end

-- Pure. Where a tab of `width` goes when the pen is at (x, y): on the same line, or at the start of the next
-- line (`lineStep` lower) when it would pass `limit`. The first tab of a line never wraps.
function Controls._tabWrap(x, y, width, lineStep, limit)
	if x > 0 and x + width > limit then
		return 0, y + lineStep
	end
	return x, y
end

local function isShown(instance)
	local current = instance
	while current ~= nil and current:IsA("GuiObject") do
		if not current.Visible then
			return false
		end
		current = current.Parent
	end
	return current ~= nil
end

function Controls.Tabs(parent, props, scope)
	local state = readProps("Tabs", TABS_KEYS, {}, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local entries = {}
	local byId = {}
	local group = nil
	local destroyed = false
	local bumpersBound = false
	local triggersBound = false
	local tierFill = nil -- the selected tier's fill where the hit box is taller than the drawn box

	local root = Instance.new("Frame")
	Metrics.Bind(root, ctx) -- parts built before the root is parented take this context, not the screen's
	root.Name = state.Name or "Tabs"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0

	local function render()
		if destroyed then
			return
		end
		local style = state.Style or "Tabs"
		if style ~= "Tabs" and style ~= "Segment" then
			error("[Pulse.Controls] Tabs: unknown Style " .. tostring(style), 2)
		end
		local segment = style == "Segment"
		local underline = ctx.Hair(unit(ctx, Space.TabUnderline))
		local gap = ctx.Px(unit(ctx, Space.Gap))
		local between = ctx.Px(unit(ctx, segment and Space.SwitchGap or Space.TabGap))
		if isTouchy(ctx) then
			between = math.max(between, Space.TouchGap)
		end
		local iconDesign = capOf(ctx, "Tab") * ICON_PER_CAP
		local iconPx = ctx.Px(iconDesign)
		local textSize = Text.SizeFor("Tab", ctx)
		local drawnDesign = segment and Space.BadgeMedium or Space.BadgeLarge
		local drawn = math.max(ctx.Px(unit(ctx, drawnDesign)), textSize + underline + underline)
		local hit = math.max(drawn, ctx.Touch(1))
		local top = math.floor((hit - drawn) * HALF)
		-- Touch only: each tab is at least the touch size wide, and a row wider than the safe area wraps.
		local touchy = isTouchy(ctx)
		local minWidth = touchy and ctx.Touch(1) or 0
		local limit = (touchy and ctx.Size ~= nil and ctx.Size.X > 0) and ctx.Size.X or math.huge
		if limit ~= math.huge and isCompact(ctx) then
			-- A Compact row starts at the screen margin, so it must wrap a margin short of each edge.
			limit = math.max(minWidth, limit - ctx.Px(Space.CompactMargin) * 2)
		end
		-- MaxWidth (design px, opt-in, any class): the row wraps at that width, for tabs inside a panel.
		if state.MaxWidth ~= nil then
			if type(state.MaxWidth) ~= "number" or state.MaxWidth <= 0 then
				error("[Pulse.Controls] Tabs: MaxWidth must be a positive design number", 2)
			end
			limit = math.min(limit, ctx.Px(state.MaxWidth))
		end

		-- The selected tier's fill covers the drawn box only. Where the hit box is taller (touch), it is one
		-- Frame `Fill` of the root, drawn under the buttons, so it lines up with the other tiers' base lines;
		-- where they are the same box (mouse and gamepad) the button's own background is the fill. It is made
		-- with the row, never on a selection change.
		local inset = top > 0
		if inset and tierFill == nil then
			for _, entry in ipairs(entries) do
				if textOf(entry.Spec.Tier) then
					tierFill = newFrame(root, "Fill")
					tierFill.Active = false
					tierFill.ZIndex = 0
					tierFill.Visible = false
					break
				end
			end
		end
		local filled = false

		local x, y, widest = 0, 0, 0
		for _, entry in ipairs(entries) do
			local spec = entry.Spec
			local button = entry.Button
			local tier = textOf(spec.Tier)
			local tint = tier and tierColour(tier) or nil
			local look = Controls._resolveTab({
				Selected = spec.Id == state.Selected,
				Locked = spec.Locked == true,
				Hover = entry.Flags.Hover,
				Focused = entry.Flags.Focused,
				Tier = tier ~= nil,
			})
			face(button, "Tab", ctx)
			put(button, "Text", Controls._tabCaption(spec))

			-- Icons belong to the Tabs style; a Segment and a tier button are text only.
			local iconName = (not segment and tier == nil) and textOf(spec.Icon) or nil
			local lead = 0
			if iconName then
				lead = iconPx + gap
				if entry.Icon == nil then
					entry.Icon = Surface.Icon(button, { Name = "Icon", Icon = iconName, Colour = look.Ink, Size = iconDesign }, scope)
				else
					entry.Icon.Set({ Icon = iconName, Size = iconDesign, Visible = true })
				end
				entry.Icon.Set({ Colour = look.Ink, Opacity = look.Opacity })
				put(entry.Icon.Instance, "Position", UDim2.fromOffset(0, math.floor((hit - iconPx) * HALF)))
			elseif entry.Icon ~= nil then
				entry.Icon.Set({ Visible = false })
			end

			local width = lead + textWidth(button)
			if tier then
				width = math.max(drawn, textWidth(button) + gap + gap)
			end
			local widened = width < minWidth
			width = math.max(width, minWidth)
			x, y = Controls._tabWrap(x, y, width, hit + between, limit)
			local centred = tier ~= nil or (widened and iconName == nil)
			put(button, "TextXAlignment", centred and Enum.TextXAlignment.Center or Enum.TextXAlignment.Right)
			put(button, "Position", UDim2.fromOffset(x, y))
			put(button, "Size", UDim2.fromOffset(width, hit))
			put(button, "TextColor3", look.TierInk and tint or colourOf(look.Ink))
			put(button, "TextTransparency", 1 - look.Opacity)
			if look.TierFill and inset and tierFill ~= nil then
				filled = true
				put(tierFill, "BackgroundColor3", tint)
				put(tierFill, "BackgroundTransparency", 1 - look.Opacity)
				put(tierFill, "Position", UDim2.fromOffset(x, y + top))
				put(tierFill, "Size", UDim2.fromOffset(width, drawn))
				put(button, "BackgroundTransparency", 1)
			elseif look.TierFill then
				put(button, "BackgroundColor3", tint)
				put(button, "BackgroundTransparency", 1 - look.Opacity)
			else
				put(button, "BackgroundColor3", colourOf("White"))
				put(button, "BackgroundTransparency", look.Fill and 0 or 1)
			end
			put(button, "Active", look.Active)

			put(entry.Underline, "BackgroundColor3", tint or colourOf("Pink"))
			put(entry.Underline, "Position", UDim2.fromOffset(0, top + drawn - underline))
			put(entry.Underline, "Size", UDim2.fromOffset(width, underline))
			put(entry.Underline, "BackgroundTransparency", 1 - look.Opacity)
			put(entry.Underline, "Visible", look.Underline)

			widest = math.max(widest, x + width)
			x = x + width + between
		end
		if tierFill ~= nil then
			put(tierFill, "Visible", filled)
		end
		put(root, "Size", UDim2.fromOffset(widest, y + hit))
	end

	local function choose(id, notify)
		local entry = byId[id]
		if entry == nil or entry.Spec.Locked == true or state.Selected == id then
			return
		end
		state.Selected = id
		render()
		local callback = state.OnSelected
		if notify and callback then
			callback(id)
		end
	end

	local function step(direction, switch)
		if destroyed or state[switch] ~= true or not isShown(root) then
			return
		end
		local nextId = Controls._stepTab(state.Tabs or {}, state.Selected, direction)
		if nextId ~= nil then
			choose(nextId, true)
		end
	end

	local function clear()
		for index = #entries, 1, -1 do
			local entry = entries[index]
			entries[index] = nil
			release(entry.Bag)
			if entry.Icon ~= nil then
				entry.Icon.Destroy()
			end
			entry.Button:Destroy()
		end
		byId = {}
		if group ~= nil then
			group.Destroy()
			group = nil
		end
	end

	local function createEntry(spec)
		local entry = { Spec = spec, Flags = { Hover = false, Focused = false }, Bag = {}, Icon = nil }
		local button = newText("TextButton", root, "Tab" .. spec.Id)
		button.AutoButtonColor = false
		button.TextXAlignment = Enum.TextXAlignment.Right
		local underline = Instance.new("Frame")
		underline.Name = "Underline"
		underline.BorderSizePixel = 0
		underline.BackgroundColor3 = colourOf("Pink")
		underline.Parent = button
		entry.Button = button
		entry.Underline = underline

		listen(scope, entry.Bag, button.Activated, function()
			choose(entry.Spec.Id, true)
		end)
		listen(scope, entry.Bag, button.MouseEnter, function()
			if ctx.Input ~= "Touch" then
				entry.Flags.Hover = true
				render()
			end
		end)
		listen(scope, entry.Bag, button.MouseLeave, function()
			entry.Flags.Hover = false
			render()
		end)
		listen(scope, entry.Bag, button:GetPropertyChangedSignal("TextBounds"), render)
		Input.Focusable(button, {
			OnFocus = function(focused)
				entry.Flags.Focused = focused == true
				render()
			end,
		})
		return entry
	end

	local function sync()
		local list = state.Tabs or {}
		local seen = {}
		for _, spec in ipairs(list) do
			if type(spec) ~= "table" or type(spec.Id) ~= "string" or spec.Id == "" then
				error("[Pulse.Controls] Tabs: every tab needs a string Id", 2)
			end
			for key in pairs(spec) do
				if not TAB_KEYS[key] then
					error("[Pulse.Controls] Tabs: unknown tab key " .. tostring(key), 2)
				end
			end
			if seen[spec.Id] then
				error("[Pulse.Controls] Tabs: duplicate Id " .. spec.Id, 2)
			end
			seen[spec.Id] = true
		end
		local same = #list == #entries
		if same then
			for index, spec in ipairs(list) do
				if entries[index].Spec.Id ~= spec.Id then
					same = false
					break
				end
			end
		end
		if same then
			for index, spec in ipairs(list) do
				entries[index].Spec = spec
			end
		else
			clear()
			group = Input.FocusGroup(scope, nil)
			for index, spec in ipairs(list) do
				local entry = createEntry(spec)
				entries[index] = entry
				byId[spec.Id] = entry
				group.Add(entry.Button, index)
			end
		end
		render()
		if not same then
			for _, entry in ipairs(entries) do
				local key = textOf(entry.Spec.MarkKey)
				if key then
					Input.Mark(entry.Button, key)
				end
			end
		end
		if state.Bumpers == true and not bumpersBound then
			bumpersBound = true
			Input.BindBumpers(scope, function()
				step(-1, "Bumpers")
			end, function()
				step(1, "Bumpers")
			end)
		end
		if state.Triggers == true and not triggersBound then
			triggersBound = true
			Input.BindTriggers(scope, function()
				step(-1, "Triggers")
			end, function()
				step(1, "Triggers")
			end)
		end
	end

	listen(scope, bag, Text.ReadyChanged, render)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, render)
	end

	applyCommon(root, state)
	sync()
	root.Parent = parent

	local self = { Instance = root }

	function self.Select(id)
		if destroyed then
			return
		end
		if byId[id] == nil then
			error("[Pulse.Controls] Tabs.Select: unknown tab " .. tostring(id), 2)
		end
		if state.Selected ~= id then
			state.Selected = id
			render()
		end
	end

	function self.Set(patch)
		if destroyed then
			return
		end
		if not mergePatch("Tabs", TABS_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		sync()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		clear()
		destroyed = true
		release(bag)
		root:Destroy()
	end

	return self
end

---------------------------------------------------------------------------------------------------
-- Header
---------------------------------------------------------------------------------------------------

local HEADER_KEYS = keySet({ "Title", "Sub", "Count", "Tabs", "MarkKey", "Shadow", "SubMaxWidth", "MaxWidth" })
local HEADER_DEFAULTS = { Title = "" }

-- MaxWidth (design px, opt-in): the title is cut to that width with an ellipsis.
local function checkHeader(values)
	if values.MaxWidth ~= nil and (type(values.MaxWidth) ~= "number" or values.MaxWidth <= 0) then
		error("[Pulse.Controls] Header: MaxWidth must be a positive design number", 3)
	end
end

-- Pure, real px in the slot's own space. Keep-out rule 2 (API2 2.4): on Compact, when the slot starts above
-- the bottom of the Roblox bar, the title row sits beside the Roblox buttons, centred on the bar row, and what
-- follows starts under the bar. Returns the title row's x and y and the top of what follows (before its gap).
-- keepOutX: TopBarKeepOut.X less the safe-area origin. The slot x is taken as the distance from the left of the
-- safe area, so a narrower Menu root only moves the title further from the buttons, never into them.
function Controls._headerPlace(compact, slotX, slotY, barBottom, keepOutX, keepOutGap, rowHeight)
	if not compact or slotY >= barBottom then
		return 0, 0, rowHeight
	end
	local x = math.max(0, keepOutX + keepOutGap - slotX)
	local y = math.max(0, math.floor((barBottom - rowHeight) * HALF) - slotY)
	return x, y, math.max(barBottom - slotY, y + rowHeight)
end

function Controls.Header(parent, props, scope)
	local state = readProps("Header", HEADER_KEYS, HEADER_DEFAULTS, props)
	checkHeader(state)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false
	local marked = nil
	local height = 0
	local busy = false

	local root = Instance.new("Frame")
	Metrics.Bind(root, ctx) -- parts built before the root is parented take this context, not the screen's
	root.Name = state.Name or "Header"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0

	local self = { Instance = root }

	-- The mark is as tall against the title cap on Compact as it is on Regular.
	local function markDesign()
		return capOf(ctx, "ScreenTitle") * Space.TitleMarkHeight / Tokens.Cap.Regular.ScreenTitle
	end

	local titleMark = Surface.TitleMark(root, { Name = "TitleMark", Height = markDesign() }, scope)
	table.insert(bag, titleMark)
	local title = Text.Label(root, {
		Name = "Title",
		Text = tostring(state.Title),
		Role = "ScreenTitle",
		Shadow = state.Shadow == true,
		MaxWidth = state.MaxWidth,
	}, scope)
	table.insert(bag, title)
	local sub, count = nil, nil

	local layout

	local function watch(component)
		table.insert(bag, component)
		listen(scope, bag, component.Instance:GetPropertyChangedSignal("Size"), function()
			layout()
		end)
	end

	-- The drawn width and line height of a Text.Label (its holder scale included).
	local function labelBox(component, role)
		local textSize, holderScale = Text.SizeFor(role, ctx)
		return math.ceil(component.Instance.Size.X.Offset * holderScale), math.ceil(textSize * holderScale)
	end

	layout = function()
		if destroyed or busy then
			return
		end
		busy = true
		local compact = isCompact(ctx)
		local gap = ctx.Px(unit(ctx, Space.Gap))
		titleMark.Set({ Height = markDesign() })
		local markSize = titleMark.Instance.Size
		local markWidth, markHeight = markSize.X.Offset, markSize.Y.Offset

		local slot = parent.Position
		local barBottom = math.max(0, math.floor(ctx.TopBarHeight - ctx.Origin.Y + HALF))
		local keepOutX = math.ceil(ctx.TopBarKeepOut.X - ctx.Origin.X)
		local keepOutGap = compact and ctx.Px(Space.CompactKeepOutGap) or 0
		local x, y, below = Controls._headerPlace(compact, slot.X.Offset, slot.Y.Offset, barBottom, keepOutX, keepOutGap, markHeight)

		-- The capital letters stand on the bottom edge of the mark.
		local floorY = y + markHeight
		local titleWidth, titleLine = labelBox(title, "ScreenTitle")
		if state.MaxWidth ~= nil then
			-- The title box is then exactly MaxWidth wide (Text.Label); the count and the root follow the drawn
			-- text, so a short title is laid out as it is without MaxWidth. Unmeasured text keeps the whole box.
			local inner = title.Instance:FindFirstChild("Label")
			local bounds = inner and inner.TextBounds.X or 0
			if bounds > 0 then
				local _, holderScale = Text.SizeFor("ScreenTitle", ctx)
				titleWidth = math.min(titleWidth, math.ceil(bounds * holderScale) + italicPad(ctx, "ScreenTitle"))
			end
		end
		local capPx = ctx.Px(capOf(ctx, "ScreenTitle"))
		local titleX = x + markWidth + gap
		put(titleMark.Instance, "Position", UDim2.fromOffset(x, y))
		put(title.Instance, "Position", UDim2.fromOffset(titleX, floorY - math.floor((titleLine + capPx) * HALF)))
		local right = titleX + titleWidth

		local countText = textOf(state.Count)
		if countText then
			if count == nil then
				count = Text.Label(root, { Name = "Count", Text = countText, Role = "Status", Colour = "TextMuted", Shadow = state.Shadow == true }, scope)
				watch(count)
			else
				count.Set({ Text = countText, Shadow = state.Shadow == true, Visible = true })
			end
			local countWidth, countLine = labelBox(count, "Status")
			local countCap = ctx.Px(capOf(ctx, "Status"))
			put(count.Instance, "Position", UDim2.fromOffset(right + gap, floorY - math.floor((countLine + countCap) * HALF)))
			right = right + gap + countWidth
		elseif count ~= nil then
			count.Set({ Visible = false })
		end

		local cursor = below
		local subText = textOf(state.Sub)
		if subText then
			if sub == nil then
				-- SubMaxWidth (design px, opt-in): the line is exactly that wide and ends in an ellipsis.
				sub = Text.Label(root, { Name = "Sub", Text = subText, Role = "Tab", Shadow = state.Shadow == true,
					MaxWidth = state.SubMaxWidth }, scope)
				watch(sub)
			else
				sub.Set({ Text = subText, Shadow = state.Shadow == true, Visible = true, MaxWidth = state.SubMaxWidth })
			end
			local subWidth, subLine = labelBox(sub, "Tab")
			cursor = cursor + (compact and keepOutGap or gap)
			put(sub.Instance, "Position", UDim2.fromOffset(0, cursor))
			cursor = cursor + subLine
			right = math.max(right, subWidth)
		elseif sub ~= nil then
			sub.Set({ Visible = false })
		end

		-- A hidden Tabs (Tabs = { Visible = false }) takes no room: neither its gap nor its height.
		local tabs = self.Tabs
		if tabs ~= nil and tabs.Instance.Visible then
			local size = tabs.Instance.Size
			cursor = cursor + (compact and keepOutGap or ctx.Px(Space.HeaderTabsGap))
			put(tabs.Instance, "Position", UDim2.fromOffset(0, cursor))
			cursor = cursor + size.Y.Offset
			right = math.max(right, size.X.Offset)
		end

		height = cursor
		put(root, "Size", UDim2.fromOffset(right, height))
		busy = false
	end

	local function syncTabs()
		local tabsProps = state.Tabs
		if type(tabsProps) ~= "table" then
			return
		end
		if self.Tabs == nil then
			self.Tabs = Controls.Tabs(root, tabsProps, scope)
			watch(self.Tabs)
			listen(scope, bag, self.Tabs.Instance:GetPropertyChangedSignal("Visible"), function()
				layout()
			end)
		else
			self.Tabs.Set(tabsProps)
		end
	end

	local function mark()
		local key = textOf(state.MarkKey)
		if key and key ~= marked then
			marked = key
			local label = title.Instance:FindFirstChild("Label")
			if label then
				Input.Mark(label, key)
			end
		end
	end

	listen(scope, bag, title.Instance:GetPropertyChangedSignal("Size"), function()
		layout()
	end)
	do
		-- With MaxWidth the title box does not change with its text; the drawn text does.
		local inner = title.Instance:FindFirstChild("Label")
		if inner ~= nil then
			listen(scope, bag, inner:GetPropertyChangedSignal("TextBounds"), function()
				if state.MaxWidth ~= nil then
					layout()
				end
			end)
		end
	end
	listen(scope, bag, parent:GetPropertyChangedSignal("Position"), function()
		layout()
	end)
	listen(scope, bag, Text.ReadyChanged, function()
		layout()
	end)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, function()
			layout()
		end)
	end

	applyCommon(root, state)
	syncTabs()
	layout()
	mark()
	root.Parent = parent

	-- Real px from the slot's top to the bottom of the header, so a screen can stack a body under it.
	function self.Height()
		return height
	end

	function self.Set(patch)
		if type(patch) == "table" then
			checkHeader(patch)
		end
		if destroyed or not mergePatch("Header", HEADER_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		title.Set({ Text = tostring(state.Title), Shadow = state.Shadow == true, MaxWidth = state.MaxWidth })
		if patch.Tabs ~= nil then
			syncTabs()
		end
		layout()
		mark()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		release(bag)
		root:Destroy()
	end

	return self
end

---------------------------------------------------------------------------------------------------
-- IconButton (the action-bar tile)
---------------------------------------------------------------------------------------------------

local ICON_BUTTON_KEYS = keySet({ "Icon", "Selected", "Disabled", "Size", "MarkKey", "OnActivated" })
local ICON_BUTTON_DEFAULTS = { Size = "Action" }

-- Pure. Drawn width and height in the units of the class (design px on Regular, dp on Compact).
function Controls._iconButtonSize(compact, size)
	if size == "Action" then
		if compact then
			return Space.CompactActionTile, Space.CompactActionTile
		end
		return Space.ActionTileWidth, Space.ActionTileHeight
	elseif size == "Small" then
		if compact then
			return Space.CompactStatusHeight, Space.CompactStatusHeight
		end
		return Space.KeyCapSize, Space.KeyCapSize
	end
	error("[Pulse.Controls] IconButton: unknown Size " .. tostring(size), 2)
end

function Controls.IconButton(parent, props, scope)
	local state = readProps("IconButton", ICON_BUTTON_KEYS, ICON_BUTTON_DEFAULTS, props)
	if textOf(state.Icon) == nil then
		error("[Pulse.Controls] IconButton: Icon is required", 2)
	end
	local ctx = Metrics.Of(parent)
	local bag = {}
	local flags = { Hover = false, Pressed = false, Focused = false }
	local destroyed = false
	local marked = nil

	local root = newButton(state.Name or "IconButton")
	Metrics.Bind(root, ctx) -- parts built before the root is parented take this context, not the screen's
	local fill = newFrame(root, "Fill")
	local hairBottom = newFrame(fill, "HairBottom")
	hairBottom.AnchorPoint = Vector2.new(0, 1)
	hairBottom.Position = UDim2.new(0, 0, 1, 0)
	hairBottom.BackgroundColor3 = colourOf("White")
	hairBottom.BackgroundTransparency = 1 - Opacity.HairButtonBottom
	local designWidth, designHeight = Controls._iconButtonSize(isCompact(ctx), state.Size)
	local icon = Surface.Icon(fill, { Name = "Icon", Icon = state.Icon, Colour = "White", Size = designHeight * ICON_ONLY }, scope)
	table.insert(bag, icon)

	local function render()
		if destroyed then
			return
		end
		designWidth, designHeight = Controls._iconButtonSize(isCompact(ctx), state.Size)
		local look = Controls._resolveButton("Icon", {
			Disabled = state.Disabled == true,
			Hover = flags.Hover,
			Pressed = flags.Pressed,
			Focused = flags.Focused,
			Selected = state.Selected == true,
		})
		local width, height = ctx.Px(designWidth), ctx.Px(designHeight)
		local hitWidth, hitHeight = ctx.Touch(designWidth), ctx.Touch(designHeight)
		local iconDesign = designHeight * ICON_ONLY
		local iconPx = ctx.Px(iconDesign)
		put(root, "Size", UDim2.fromOffset(hitWidth, hitHeight))
		put(fill, "Position", UDim2.fromOffset(math.floor((hitWidth - width) * HALF), math.floor((hitHeight - height) * HALF)))
		put(fill, "Size", UDim2.fromOffset(width, height))
		put(fill, "BackgroundColor3", colourOf(look.Fill))
		put(fill, "BackgroundTransparency", 1 - look.FillOpacity * look.Opacity)
		put(hairBottom, "Size", UDim2.new(1, 0, 0, ctx.Hair(unit(ctx, Space.Hairline))))
		put(hairBottom, "Visible", look.Hair)
		icon.Set({ Icon = state.Icon, Colour = look.Ink, Size = iconDesign, Opacity = look.Opacity })
		put(icon.Instance, "Position", UDim2.fromOffset(math.floor((width - iconPx) * HALF), math.floor((height - iconPx) * HALF)))
		put(root, "Active", look.Active)
	end

	local function mark()
		local key = textOf(state.MarkKey)
		if key and key ~= marked then
			marked = key
			Input.Mark(root, key)
		end
	end

	watchPointer(scope, bag, root, ctx, flags, render)
	listen(scope, bag, root.Activated, function()
		local callback = state.OnActivated
		if callback and root.Active then
			callback()
		end
	end)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, render)
	end

	applyCommon(root, state)
	render()
	mark()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		if destroyed or not mergePatch("IconButton", ICON_BUTTON_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil and marked == nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		render()
		mark()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		release(bag)
		root:Destroy()
	end

	return self
end

---------------------------------------------------------------------------------------------------
-- Switch (two cells; the active one is White with Ink text)
---------------------------------------------------------------------------------------------------

local SWITCH_KEYS = keySet({ "On", "LabelOn", "LabelOff", "Disabled", "OnChanged" })
local SWITCH_DEFAULTS = { On = false }

function Controls.Switch(parent, props, scope)
	local state = readProps("Switch", SWITCH_KEYS, SWITCH_DEFAULTS, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local flags = { Hover = false, Pressed = false, Focused = false }
	local destroyed = false

	local root = newButton(state.Name or "Switch")
	-- The On cell is the left one (preview r20b: ROTATE | NORTH UP).
	local cellOn = newText("TextLabel", root, "CellOn")
	local cellOff = newText("TextLabel", root, "CellOff")
	local line = newFrame(root, "BaseLine")
	line.BackgroundColor3 = colourOf("Pink")
	line.BackgroundTransparency = 0

	local function render()
		if destroyed then
			return
		end
		local disabled = state.Disabled == true
		local opacity = disabled and Opacity.Disabled or 1
		local drawnDesign = isCompact(ctx) and Space.CompactButtonDrawn or Space.HudButtonHeight
		local drawn, hit = ctx.Px(drawnDesign), ctx.Touch(drawnDesign)
		local top = math.floor((hit - drawn) * HALF)
		local pad = ctx.Px(unit(ctx, Space.ButtonPadX))
		local on = state.On == true

		put(cellOn, "Text", string.upper(tostring(state.LabelOn or "On")))
		put(cellOff, "Text", string.upper(tostring(state.LabelOff or "Off")))
		face(cellOn, "MenuButton", ctx)
		face(cellOff, "MenuButton", ctx)
		local cell = math.max(textWidth(cellOn), textWidth(cellOff)) + pad + pad

		for index, label in ipairs({ cellOn, cellOff }) do
			local active = (index == 1) == on
			put(label, "TextXAlignment", Enum.TextXAlignment.Center)
			put(label, "Position", UDim2.fromOffset((index - 1) * cell, top))
			put(label, "Size", UDim2.fromOffset(cell, drawn))
			put(label, "BackgroundColor3", colourOf("White"))
			put(label, "BackgroundTransparency", 1 - (active and 1 or Opacity.ChipNeutral) * opacity)
			put(label, "TextColor3", colourOf(active and "Ink" or "TextMuted"))
			put(label, "TextTransparency", 1 - opacity)
		end

		local thickness = ctx.Hair(unit(ctx, Space.TabUnderline))
		put(line, "Position", UDim2.fromOffset(0, top + drawn - thickness))
		put(line, "Size", UDim2.fromOffset(cell + cell, thickness))
		put(line, "Visible", (flags.Hover or flags.Focused) and not disabled)
		put(root, "Size", UDim2.fromOffset(cell + cell, hit))
		put(root, "Active", not disabled)
	end

	watchPointer(scope, bag, root, ctx, flags, render)
	listen(scope, bag, root.Activated, function()
		if destroyed or not root.Active then
			return
		end
		state.On = state.On ~= true
		render()
		local callback = state.OnChanged
		if callback then
			callback(state.On)
		end
	end)
	listen(scope, bag, cellOn:GetPropertyChangedSignal("TextBounds"), render)
	listen(scope, bag, cellOff:GetPropertyChangedSignal("TextBounds"), render)
	listen(scope, bag, Text.ReadyChanged, render)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, render)
	end

	applyCommon(root, state)
	render()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		if destroyed or not mergePatch("Switch", SWITCH_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		render()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		release(bag)
		root:Destroy()
	end

	return self
end

---------------------------------------------------------------------------------------------------
-- Stepper (minus, value, plus; tap only)
---------------------------------------------------------------------------------------------------

local STEPPER_KEYS = keySet({ "Value", "Min", "Max", "Step", "Format", "OnChanged", "MarkKey" })
local STEPPER_DEFAULTS = { Value = 0 }

-- Pure. The value one step along, held inside Min and Max (either may be absent).
function Controls._stepValue(value, minimum, maximum, step, direction)
	local nextValue = value + direction * (step or 1)
	if type(minimum) == "number" and nextValue < minimum then
		nextValue = minimum
	end
	if type(maximum) == "number" and nextValue > maximum then
		nextValue = maximum
	end
	return nextValue
end

function Controls.Stepper(parent, props, scope)
	local state = readProps("Stepper", STEPPER_KEYS, STEPPER_DEFAULTS, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false
	local marked = nil

	local root = Instance.new("Frame")
	Metrics.Bind(root, ctx) -- parts built before the root is parented take this context, not the screen's
	root.Name = state.Name or "Stepper"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	local plate = newFrame(root, "Plate")
	plate.BackgroundColor3 = colourOf("Slate")
	plate.BackgroundTransparency = 1 - Opacity.ButtonPlate
	local hairTop = newFrame(plate, "HairTop")
	hairTop.BackgroundColor3 = colourOf("White")
	hairTop.BackgroundTransparency = 1 - Opacity.HairButtonTop
	local hairBottom = newFrame(plate, "HairBottom")
	hairBottom.BackgroundColor3 = colourOf("White")
	hairBottom.BackgroundTransparency = 1 - Opacity.HairButtonBottom
	hairBottom.AnchorPoint = Vector2.new(0, 1)
	hairBottom.Position = UDim2.new(0, 0, 1, 0)
	local value = newText("TextLabel", plate, "Value")
	value.TextXAlignment = Enum.TextXAlignment.Center

	local render

	local function newSide(name, glyph, direction)
		local side = { Flags = { Hover = false, Pressed = false, Focused = false }, Direction = direction }
		side.Button = newButton(name)
		side.Icon = Surface.Icon(side.Button, { Name = "Icon", Icon = glyph, Colour = "White", Size = Space.BadgeSmall }, scope)
		table.insert(bag, side.Icon)
		watchPointer(scope, bag, side.Button, ctx, side.Flags, function()
			render()
		end)
		listen(scope, bag, side.Button.Activated, function()
			if destroyed or not side.Button.Active then
				return
			end
			local nextValue = Controls._stepValue(state.Value, state.Min, state.Max, state.Step, direction)
			if nextValue ~= state.Value then
				state.Value = nextValue
				render()
				local callback = state.OnChanged
				if callback then
					callback(nextValue)
				end
			end
		end)
		side.Button.Parent = root
		return side
	end

	local minus = newSide("Minus", "minus", -1)
	local plus = newSide("Plus", "plus", 1)

	render = function()
		if destroyed then
			return
		end
		local compact = isCompact(ctx)
		local drawnDesign = compact and Space.CompactButtonDrawn or Space.ButtonHeight
		local drawn, hit = ctx.Px(drawnDesign), ctx.Touch(drawnDesign)
		local top = math.floor((hit - drawn) * HALF)
		local hair = ctx.Hair(unit(ctx, Space.Hairline))
		local gap = ctx.Px(unit(ctx, Space.Gap))
		local iconDesign = drawnDesign * ICON_ONLY
		local iconPx = ctx.Px(iconDesign)

		local format = state.Format
		local shown = format and format(state.Value) or tostring(state.Value)
		put(value, "Text", string.upper(tostring(shown)))
		local textSize = face(value, "MenuButtonMain", ctx)
		local width = math.max(ctx.Px(unit(ctx, Space.StepperWidth)), hit + hit + textWidth(value) + gap + gap)

		put(root, "Size", UDim2.fromOffset(width, hit))
		put(plate, "Position", UDim2.fromOffset(0, top))
		put(plate, "Size", UDim2.fromOffset(width, drawn))
		put(hairTop, "Size", UDim2.new(1, 0, 0, hair))
		put(hairBottom, "Size", UDim2.new(1, 0, 0, hair))
		put(value, "Position", UDim2.fromOffset(hit, -baselineShift(textSize)))
		put(value, "Size", UDim2.fromOffset(math.max(0, width - hit - hit), drawn))
		put(value, "TextColor3", colourOf("White"))

		for _, side in ipairs({ minus, plus }) do
			local atEnd = Controls._stepValue(state.Value, state.Min, state.Max, state.Step, side.Direction) == state.Value
			local look = Controls._resolveButton("Icon", {
				Disabled = atEnd,
				Hover = side.Flags.Hover,
				Pressed = side.Flags.Pressed,
				Focused = side.Flags.Focused,
			})
			local white = look.Ink == "Ink"
			put(side.Button, "Position", UDim2.fromOffset(side.Direction < 0 and 0 or width - hit, 0))
			put(side.Button, "Size", UDim2.fromOffset(hit, hit))
			put(side.Button, "BackgroundColor3", colourOf(look.Fill))
			put(side.Button, "BackgroundTransparency", white and 0 or 1)
			put(side.Button, "Active", look.Active)
			side.Icon.Set({ Colour = look.Ink, Size = iconDesign, Opacity = look.Opacity })
			put(side.Icon.Instance, "Position", UDim2.fromOffset(math.floor((hit - iconPx) * HALF), math.floor((hit - iconPx) * HALF)))
		end
	end

	local function mark()
		local key = textOf(state.MarkKey)
		if key and key ~= marked then
			marked = key
			Input.Mark(root, key)
		end
	end

	listen(scope, bag, value:GetPropertyChangedSignal("TextBounds"), function()
		render()
	end)
	listen(scope, bag, Text.ReadyChanged, function()
		render()
	end)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, function()
			render()
		end)
	end

	applyCommon(root, state)
	render()
	mark()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		if destroyed or not mergePatch("Stepper", STEPPER_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil and marked == nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		render()
		mark()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		release(bag)
		root:Destroy()
	end

	return self
end

---------------------------------------------------------------------------------------------------
-- Slider
---------------------------------------------------------------------------------------------------

local SLIDER_KEYS = keySet({ "Value", "Label", "ValueText", "Gradient", "OnChanged", "OnReleased" })
local SLIDER_DEFAULTS = { Value = 0 }
local SLIDER_FINE = 1 / 100 -- one key or pad step
local SLIDER_COARSE = 1 / 20 -- the same with a bumper held
local sliderActions = 0

-- Pure. The value one key step along, snapped to the step grid and held in 0..1.
function Controls._slideValue(value, direction, coarse)
	local step = coarse and SLIDER_COARSE or SLIDER_FINE
	local snapped = math.floor(value / step + HALF) + direction
	return math.clamp(snapped * step, 0, 1)
end

function Controls.Slider(parent, props, scope)
	local state = readProps("Slider", SLIDER_KEYS, SLIDER_DEFAULTS, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local flags = { Hover = false, Pressed = false, Focused = false, Dragging = false }
	local destroyed = false
	local dragScope = nil
	local focusScope = nil
	local pending = false
	local handleWidth = 0
	local handleTop = 0

	-- Active, so a drag on the slider never reaches the camera orbit behind it.
	local root = newButton(state.Name or "Slider")
	root.Active = true
	local label = newText("TextLabel", root, "Label")
	local valueText = newText("TextLabel", root, "ValueText")
	valueText.TextXAlignment = Enum.TextXAlignment.Right
	local track = newFrame(root, "Track")
	local filled = newFrame(root, "Fill")
	filled.BackgroundColor3 = colourOf("White")
	filled.BackgroundTransparency = 0
	local handle = newFrame(root, "Handle")
	handle.BackgroundTransparency = 0
	local gradient = nil

	local function value01()
		return math.clamp(tonumber(state.Value) or 0, 0, 1)
	end

	-- The only writes while dragging: the filled part, the handle and the value text.
	local function renderValue()
		local value = value01()
		put(filled, "Size", UDim2.new(value, 0, 0, track.Size.Y.Offset))
		put(handle, "Position", UDim2.new(value, -math.floor(handleWidth * HALF), 0, handleTop))
		put(valueText, "Text", string.upper(tostring(state.ValueText or "")))
	end

	local function paint()
		local lit = flags.Hover or flags.Focused or flags.Dragging
		put(handle, "BackgroundColor3", colourOf(lit and "Pink" or "White"))
	end

	local function render()
		if destroyed then
			return
		end
		local compact = isCompact(ctx)
		local gap = ctx.Px(unit(ctx, Space.Gap))
		local band = ctx.Touch(compact and Space.TouchMin or Space.SliderHeight)
		local thickness = ctx.Hair(unit(ctx, Space.TileBaseLine))
		if compact then
			-- dp, not the scaled-down Regular sizes: a 2 px line with a 4 by 12 handle cannot be seen under a thumb.
			thickness = ctx.Px(Space.Hairline + Space.Hairline)
		end

		local caption = textOf(state.Label)
		local shown = textOf(state.ValueText)
		local textBand = 0
		put(label, "Text", string.upper(caption or ""))
		local labelSize = face(label, "Label", ctx)
		local valueSize = face(valueText, "Value", ctx)
		if caption or shown then
			textBand = math.max(labelSize, valueSize)
		end
		put(label, "Visible", caption ~= nil)
		put(label, "TextColor3", colourOf("TextSecondary"))
		put(label, "Position", UDim2.fromOffset(0, -baselineShift(labelSize)))
		put(label, "Size", UDim2.new(1, 0, 0, textBand))
		put(valueText, "Visible", shown ~= nil)
		put(valueText, "TextColor3", colourOf("White"))
		put(valueText, "Position", UDim2.fromOffset(0, -baselineShift(valueSize)))
		put(valueText, "Size", UDim2.new(1, 0, 0, textBand))

		if hasWidth(parent) then
			put(root, "Size", UDim2.new(1, 0, 0, textBand + band))
		else
			put(root, "Size", UDim2.fromOffset(ctx.Px(unit(ctx, Space.ListWidth)), textBand + band))
		end

		local trackTop = textBand + math.floor((band - thickness) * HALF)
		put(track, "Position", UDim2.fromOffset(0, trackTop))
		put(track, "Size", UDim2.new(1, 0, 0, thickness))
		put(filled, "Position", UDim2.fromOffset(0, trackTop))

		-- The paint exception: the track shows the caller's colour ramp and the filled part is hidden.
		local ramp = state.Gradient
		if ramp ~= nil then
			if gradient == nil then
				gradient = Instance.new("UIGradient")
				gradient.Name = "Gradient"
				gradient.Parent = track
			end
			gradient.Color = ramp
			put(gradient, "Enabled", true)
		elseif gradient ~= nil then
			put(gradient, "Enabled", false)
		end
		put(track, "BackgroundColor3", colourOf("White"))
		put(track, "BackgroundTransparency", ramp ~= nil and 0 or 1 - Opacity.SegmentEmpty)
		put(filled, "Visible", ramp == nil)

		local handleHeight = math.min(band, ctx.Px(unit(ctx, Space.BadgeSmall)))
		handleWidth = ctx.Px(unit(ctx, Space.Gap))
		if compact then
			handleHeight = math.min(band, ctx.Px(Space.CompactStatusHeight))
			handleWidth = ctx.Px(Space.Gap)
		end
		handleTop = textBand + math.floor((band - handleHeight) * HALF)
		put(handle, "Size", UDim2.fromOffset(handleWidth, handleHeight))
		renderValue()
		paint()
	end

	local function notify()
		if pending then
			return
		end
		pending = true
		-- Deferred, so the input events of one frame give one OnChanged.
		task.defer(function()
			pending = false
			local callback = state.OnChanged
			if callback and not destroyed then
				callback(value01())
			end
		end)
	end

	local function setValue(value)
		if value ~= state.Value then
			state.Value = value
			renderValue()
			notify()
		end
	end

	local function released()
		local callback = state.OnReleased
		if callback and not destroyed then
			callback(value01())
		end
	end

	local function valueAt(screenX)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return value01()
		end
		return math.clamp((screenX - track.AbsolutePosition.X) / width, 0, 1)
	end

	local function endDrag()
		if dragScope == nil then
			return
		end
		dragScope:destroy()
		dragScope = nil
		flags.Dragging = false
		paint()
		released()
	end

	listen(scope, bag, root.InputBegan, function(input)
		local kind = input.UserInputType
		local mouse = kind == Enum.UserInputType.MouseButton1
		if destroyed or dragScope ~= nil or not (mouse or kind == Enum.UserInputType.Touch) then
			return
		end
		dragScope = miniScope()
		flags.Dragging = true
		setValue(valueAt(input.Position.X))
		paint()
		dragScope:connect(UserInputService.InputChanged, function(changed)
			if changed == input or (mouse and changed.UserInputType == Enum.UserInputType.MouseMovement) then
				setValue(valueAt(changed.Position.X))
			end
		end)
		dragScope:connect(UserInputService.InputEnded, function(ended)
			if ended == input or (mouse and ended.UserInputType == Enum.UserInputType.MouseButton1) then
				endDrag()
			end
		end)
	end)

	local function onKey(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local key = input.KeyCode
		local direction = (key == Enum.KeyCode.Left or key == Enum.KeyCode.DPadLeft) and -1 or 1
		local pad = Enum.UserInputType.Gamepad1
		local coarse = UserInputService:IsGamepadButtonDown(pad, Enum.KeyCode.ButtonL1)
			or UserInputService:IsGamepadButtonDown(pad, Enum.KeyCode.ButtonR1)
		setValue(Controls._slideValue(value01(), direction, coarse))
		released()
		return Enum.ContextActionResult.Sink
	end

	local function setFocus(focused)
		flags.Focused = focused
		if focusScope ~= nil then
			focusScope:destroy()
			focusScope = nil
		end
		if focused and not destroyed then
			-- Left and right move the value, not the selection, while the slider holds focus.
			focusScope = miniScope()
			sliderActions += 1
			Input.BindAction(focusScope, "Pulse_Slider_" .. sliderActions, onKey, nil,
				Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight)
		end
		paint()
	end

	listen(scope, bag, root.MouseEnter, function()
		if ctx.Input ~= "Touch" then
			flags.Hover = true
			paint()
		end
	end)
	listen(scope, bag, root.MouseLeave, function()
		flags.Hover = false
		paint()
	end)
	Input.Focusable(root, {
		OnFocus = function(focused)
			setFocus(focused == true)
		end,
	})
	listen(scope, bag, Text.ReadyChanged, render)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, render)
	end

	applyCommon(root, state)
	render()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		if destroyed or not mergePatch("Slider", SLIDER_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		render()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if dragScope ~= nil then
			dragScope:destroy()
			dragScope = nil
		end
		if focusScope ~= nil then
			focusScope:destroy()
			focusScope = nil
		end
		release(bag)
		root:Destroy()
	end

	return self
end

---------------------------------------------------------------------------------------------------
-- Swatch (the paint named exception: the one control that takes a Color3)
---------------------------------------------------------------------------------------------------

local SWATCH_KEYS = keySet({ "Colour", "Selected", "OnActivated" })

function Controls.Swatch(parent, props, scope)
	local state = readProps("Swatch", SWATCH_KEYS, {}, props)
	if typeof(state.Colour) ~= "Color3" then
		error("[Pulse.Controls] Swatch: Colour must be a Color3", 2)
	end
	local ctx = Metrics.Of(parent)
	local bag = {}
	local flags = { Hover = false, Pressed = false, Focused = false }
	local destroyed = false

	-- The root is the hit box and, when selected, the White frame around the colour cell.
	local root = newButton(state.Name or "Swatch")
	root.BackgroundColor3 = colourOf("White")
	local cell = newFrame(root, "Colour")
	cell.BackgroundTransparency = 0
	local line = newFrame(root, "BaseLine")
	line.BackgroundColor3 = colourOf("Pink")
	line.BackgroundTransparency = 0
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.new(0, 0, 1, 0)

	local function render()
		if destroyed then
			return
		end
		if typeof(state.Colour) ~= "Color3" then
			error("[Pulse.Controls] Swatch: Colour must be a Color3", 2)
		end
		local selected = state.Selected == true or flags.Focused
		local framed = selected or flags.Hover
		local side = ctx.Touch(unit(ctx, Space.IconButton))
		local border = framed and ctx.Hair(unit(ctx, Space.TabUnderline)) or 0
		put(root, "Size", UDim2.fromOffset(side, side))
		put(root, "BackgroundTransparency", framed and 0 or 1)
		put(cell, "BackgroundColor3", state.Colour)
		put(cell, "Position", UDim2.fromOffset(border, border))
		put(cell, "Size", UDim2.fromOffset(side - border - border, side - border - border))
		put(line, "Size", UDim2.new(1, 0, 0, ctx.Hair(unit(ctx, Space.TileBaseLine))))
		put(line, "Visible", selected)
	end

	watchPointer(scope, bag, root, ctx, flags, render)
	listen(scope, bag, root.Activated, function()
		local callback = state.OnActivated
		if callback and root.Active then
			callback()
		end
	end)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, render)
	end

	applyCommon(root, state)
	render()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		if destroyed or not mergePatch("Swatch", SWATCH_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		render()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		release(bag)
		root:Destroy()
	end

	return self
end

---------------------------------------------------------------------------------------------------
-- Dropdown
---------------------------------------------------------------------------------------------------

local DROPDOWN_KEYS = keySet({ "Label", "Options", "Selected", "OnSelected", "MaxRows" })
local DROPDOWN_DEFAULTS = { Label = "", Selected = "" }
local DROPDOWN_ROWS = 6 -- rows shown before the list scrolls, when MaxRows is not given

-- Pure, real px in the host. Where the open list goes and how tall it is: under the control; above it when it
-- does not fit under and does fit above; and when it fits on neither side (a phone), on the roomier side with as
-- many whole rows as fit there (the list scrolls). The list never leaves the host's right edge.
function Controls._dropdownPlace(left, top, bottom, width, rows, rowHeight, hostWidth, hostHeight)
	local listHeight = rows * rowHeight
	local x, y = left, bottom
	if hostHeight > 0 and bottom + listHeight > hostHeight then
		local below, above = hostHeight - bottom, top
		if above >= listHeight then
			y = top - listHeight
		else
			local fit = math.max(1, math.floor(math.max(below, above) / rowHeight))
			listHeight = math.min(rows, fit) * rowHeight
			if above > below then
				y = top - listHeight
			end
		end
	end
	if hostWidth > 0 and x + width > hostWidth then
		x = math.max(0, math.floor(hostWidth - width))
	end
	return x, y, listHeight
end

-- The frame the open list is built in: the top GuiObject above the control (the layer's Root).
local function layerRootOf(instance)
	local top = nil
	local current = instance
	while current ~= nil and current:IsA("GuiObject") do
		top = current
		current = current.Parent
	end
	return top
end

local function checkOptions(list)
	local seen = {}
	for _, option in ipairs(list) do
		if type(option) ~= "table" or type(option.Id) ~= "string" or option.Id == "" then
			error("[Pulse.Controls] Dropdown: every option needs a string Id", 3)
		end
		if seen[option.Id] then
			error("[Pulse.Controls] Dropdown: duplicate Id " .. option.Id, 3)
		end
		seen[option.Id] = true
	end
end

function Controls.Dropdown(parent, props, scope)
	local state = readProps("Dropdown", DROPDOWN_KEYS, DROPDOWN_DEFAULTS, props)
	checkOptions(state.Options or {})
	local ctx = Metrics.Of(parent)
	local bag = {}
	local flags = { Hover = false, Pressed = false, Focused = false }
	local destroyed = false
	local built = nil -- { Catcher, List, Rows, Bag }: the open list, kept between openings
	local stale = false -- Options changed since the list was built
	local session = nil -- the scope of one opening: focus trap and back binding

	local root = newButton(state.Name or "Dropdown")
	Metrics.Bind(root, ctx) -- parts built before the root is parented take this context, not the screen's
	local fill = newFrame(root, "Fill")
	local label = newText("TextLabel", fill, "Label")
	local value = newText("TextLabel", fill, "Value")
	local chevron = Surface.Icon(fill, { Name = "Chevron", Icon = "chevron_down", Colour = "White", Size = Space.BadgeSmall }, scope)
	table.insert(bag, chevron)

	local function selectedText()
		for _, option in ipairs(state.Options or {}) do
			if option.Id == state.Selected then
				return string.upper(tostring(option.Text or option.Id))
			end
		end
		return ""
	end

	local function rowHeight()
		return ctx.Touch(isCompact(ctx) and Space.CompactButtonDrawn or Space.DropdownRowHeight)
	end

	local function render()
		if destroyed then
			return
		end
		local drawnDesign = isCompact(ctx) and Space.CompactButtonDrawn or Space.DropdownRowHeight
		local drawn, hit = ctx.Px(drawnDesign), ctx.Touch(drawnDesign)
		local pad = ctx.Px(unit(ctx, Space.ButtonPadX))
		local gap = ctx.Px(unit(ctx, Space.Gap))
		local iconDesign = capOf(ctx, "MenuButton") * ICON_PER_CAP
		local iconPx = ctx.Px(iconDesign)
		local white = flags.Hover or flags.Focused or session ~= nil

		put(label, "Text", string.upper(tostring(state.Label)))
		put(value, "Text", selectedText())
		local textSize = face(label, "MenuButton", ctx)
		face(value, "MenuButton", ctx)
		local labelWidth = textWidth(label)
		local valueWidth = textWidth(value) + italicPad(ctx, "MenuButton")
		local lead = labelWidth > 0 and labelWidth + gap or 0
		local width = pad + lead + valueWidth + gap + iconPx + pad

		put(root, "Size", UDim2.fromOffset(width, hit))
		put(fill, "Position", UDim2.fromOffset(0, math.floor((hit - drawn) * HALF)))
		put(fill, "Size", UDim2.fromOffset(width, drawn))
		put(fill, "BackgroundColor3", colourOf(white and "White" or "Slate"))
		put(fill, "BackgroundTransparency", white and 0 or 1 - Opacity.ButtonPlate)
		put(label, "Position", UDim2.fromOffset(pad, -baselineShift(textSize)))
		put(label, "Size", UDim2.fromOffset(labelWidth, drawn))
		put(label, "TextColor3", colourOf(white and "Ink" or "TextMuted"))
		put(value, "Position", UDim2.fromOffset(pad + lead, -baselineShift(textSize)))
		put(value, "Size", UDim2.fromOffset(valueWidth, drawn))
		put(value, "TextColor3", colourOf(white and "Ink" or "White"))
		chevron.Set({ Colour = white and "Ink" or "White", Size = iconDesign })
		put(chevron.Instance, "Position", UDim2.fromOffset(width - pad - iconPx, math.floor((drawn - iconPx) * HALF)))
	end

	local function paintRows()
		if built == nil then
			return
		end
		local thin = ctx.Hair(unit(ctx, Space.Hairline))
		local thick = ctx.Hair(unit(ctx, Space.TabUnderline))
		for _, row in ipairs(built.Rows) do
			local chosen = row.Id == state.Selected
			local white = row.Flags.Hover or row.Flags.Focused
			put(row.Button, "BackgroundColor3", colourOf("White"))
			put(row.Button, "BackgroundTransparency", white and 0 or 1)
			put(row.Button, "TextColor3", colourOf(white and "Ink" or (chosen and "White" or "TextSecondary")))
			put(row.Line, "BackgroundColor3", colourOf(chosen and "Pink" or "White"))
			put(row.Line, "BackgroundTransparency", chosen and 0 or 1 - Opacity.HairBottom)
			put(row.Line, "Size", UDim2.new(1, 0, 0, chosen and thick or thin))
		end
	end

	local close

	local function choose(id)
		close()
		if id ~= state.Selected then
			state.Selected = id
			render()
			local callback = state.OnSelected
			if callback then
				callback(id)
			end
		end
	end

	local function destroyList()
		if built ~= nil then
			release(built.Bag)
			built.Catcher:Destroy()
			built = nil
		end
	end

	-- Built on the first opening, inside the layer root: a full-size catcher (an outside press closes) holding
	-- the list. Two instances per option: the row button and its line.
	local function buildList(host)
		local catcher = newButton("DropdownCatcher")
		catcher.Size = UDim2.fromScale(1, 1)
		catcher.Selectable = false
		catcher.Visible = false
		local order = 0
		for _, sibling in ipairs(host:GetChildren()) do
			if sibling:IsA("GuiObject") then
				order = math.max(order, sibling.ZIndex)
			end
		end
		catcher.ZIndex = order + 1

		local list = Instance.new("ScrollingFrame")
		list.Name = "List"
		list.Active = true
		list.BorderSizePixel = 0
		list.BackgroundColor3 = colourOf("Slate")
		list.BackgroundTransparency = 0
		list.ScrollingDirection = Enum.ScrollingDirection.Y
		list.ScrollBarThickness = ctx.Hair(unit(ctx, Space.TabUnderline))
		list.ScrollBarImageColor3 = colourOf("Cyan")
		list.Selectable = false
		list.Parent = catcher

		local made = { Catcher = catcher, List = list, Rows = {}, Bag = {} }
		for index, option in ipairs(state.Options or {}) do
			local row = { Id = option.Id, Flags = { Hover = false, Pressed = false, Focused = false } }
			row.Button = newText("TextButton", list, "Option" .. option.Id)
			row.Button.AutoButtonColor = false
			row.Button.TextXAlignment = Enum.TextXAlignment.Center
			row.Button.Text = string.upper(tostring(option.Text or option.Id))
			row.Line = newFrame(row.Button, "Line")
			row.Line.AnchorPoint = Vector2.new(0, 1)
			row.Line.Position = UDim2.new(0, 0, 1, 0)
			watchPointer(scope, made.Bag, row.Button, ctx, row.Flags, paintRows)
			listen(scope, made.Bag, row.Button.Activated, function()
				choose(row.Id)
			end)
			made.Rows[index] = row
		end
		listen(scope, made.Bag, catcher.Activated, function()
			close()
		end)
		catcher.Parent = host
		return made
	end

	local function placeList(host)
		local height = rowHeight()
		local rows = #built.Rows
		local shown = math.max(1, math.min(rows, state.MaxRows or DROPDOWN_ROWS))
		-- A static UIScale above the host (the gallery stage) scales AbsolutePosition; divide it out.
		local scale = 1
		local hostSize = host.Size
		if hostSize.X.Scale == 0 and hostSize.X.Offset > 0 and host.AbsoluteSize.X > 0 then
			scale = host.AbsoluteSize.X / hostSize.X.Offset
		end
		local origin = (fill.AbsolutePosition - host.AbsolutePosition) / scale
		local hostWidth = host.AbsoluteSize.X / scale
		local hostHeight = host.AbsoluteSize.Y / scale
		local width = math.max(fill.Size.X.Offset, ctx.Px(unit(ctx, Space.StepperWidth)))
		local top = math.floor(origin.Y + HALF)
		local x, y, listHeight = Controls._dropdownPlace(math.floor(origin.X + HALF), top, top + fill.Size.Y.Offset,
			width, shown, height, hostWidth, hostHeight)
		put(built.List, "Position", UDim2.fromOffset(x, y))
		put(built.List, "Size", UDim2.fromOffset(width, listHeight))
		put(built.List, "CanvasSize", UDim2.fromOffset(0, rows * height))
		for index, row in ipairs(built.Rows) do
			face(row.Button, "MenuButton", ctx)
			put(row.Button, "Position", UDim2.fromOffset(0, (index - 1) * height))
			put(row.Button, "Size", UDim2.new(1, 0, 0, height))
		end
	end

	close = function()
		if session == nil then
			return
		end
		local live = session
		session = nil
		live:destroy()
		if built ~= nil then
			put(built.Catcher, "Visible", false)
		end
		render()
	end

	local function open()
		if destroyed or session ~= nil or not root.Active then
			return
		end
		local host = layerRootOf(root)
		if host == nil or host == root then
			return
		end
		if built ~= nil and (stale or built.Catcher.Parent ~= host) then
			destroyList()
		end
		stale = false
		if built == nil then
			built = buildList(host)
		end
		placeList(host)
		paintRows()
		put(built.Catcher, "Visible", true)

		session = miniScope()
		local group = Input.FocusGroup(session, { Trap = true })
		local preferred = nil
		for index, row in ipairs(built.Rows) do
			group.Add(row.Button, index)
			if row.Id == state.Selected then
				preferred = row.Button
			end
		end
		Input.BindBack(session, function()
			close()
		end)
		group.Enter(preferred)
		render()
	end

	watchPointer(scope, bag, root, ctx, flags, render)
	listen(scope, bag, root.Activated, function()
		if session ~= nil then
			close()
		else
			open()
		end
	end)
	listen(scope, bag, label:GetPropertyChangedSignal("TextBounds"), render)
	listen(scope, bag, value:GetPropertyChangedSignal("TextBounds"), render)
	listen(scope, bag, Text.ReadyChanged, render)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, function()
			close()
			render()
		end)
	end

	applyCommon(root, state)
	render()
	root.Parent = parent

	local self = { Instance = root }

	self.Open = open
	self.Close = function()
		close()
	end

	function self.IsOpen()
		return session ~= nil
	end

	function self.Set(patch)
		if destroyed then
			return
		end
		if type(patch) == "table" and patch.Options ~= nil then
			checkOptions(patch.Options)
		end
		if not mergePatch("Dropdown", DROPDOWN_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil then
			put(root, "Name", patch.Name)
		end
		if patch.Options ~= nil then
			close()
			stale = true
		end
		applyCommon(root, state)
		render()
		paintRows()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		close()
		destroyed = true
		destroyList()
		release(bag)
		root:Destroy()
	end

	return self
end

return Controls
