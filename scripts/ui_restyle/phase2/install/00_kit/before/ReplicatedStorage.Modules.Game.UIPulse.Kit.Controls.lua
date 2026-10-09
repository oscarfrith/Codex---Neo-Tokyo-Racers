-- Owns the Pulse Button, ButtonRow and Tabs components; it does not own focus rules, text metrics, tokens or any screen's layout.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Kit.Controls. Requires: Tokens, Metrics, Text, Surface, Input.
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

local function fadeIcon(component, transparency)
	local instance = component.Instance
	if instance:IsA("ImageLabel") then
		put(instance, "ImageTransparency", transparency)
	end
end

---------------------------------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------------------------------

local BUTTON_KEYS = keySet({ "Variant", "Text", "Icon", "Disabled", "Locked", "Size", "MinWidth", "MarkKey", "OnActivated" })
local BUTTON_DEFAULTS = { Variant = "Default", Size = "Menu" }

-- Pure. flags: Disabled, Locked, Inactive (Active switched off from outside), Hover, Pressed, Focused.
function Controls._resolveButton(variant, flags)
	local look = { Fill = "Slate", FillOpacity = Opacity.Panel, Ink = "White", Gradient = false, Glow = false, Active = true, Opacity = 1 }
	if variant == "Main" then
		look.Fill = "White"
		look.FillOpacity = 1
		look.Gradient = true
		look.Glow = true
	elseif variant == "Buy" then
		look.Fill = "Yellow"
		look.FillOpacity = 1
		look.Ink = "Ink"
	elseif variant == "Danger" then
		look.Fill = "Danger"
		look.FillOpacity = 1
	elseif variant ~= "Default" and variant ~= "Icon" then
		error("[Pulse.Controls] Button: unknown Variant " .. tostring(variant), 2)
	end
	if flags.Disabled then
		look.Active = false
		look.Opacity = Opacity.Disabled
		look.Glow = false
	elseif flags.Locked or flags.Inactive then
		look.Active = false
		look.Opacity = Opacity.Locked
		look.Glow = false
	elseif flags.Pressed then
		look.Fill = "TextSecondary"
		look.FillOpacity = 1
		look.Ink = "Ink"
		look.Gradient = false
	elseif flags.Hover or flags.Focused then
		look.Fill = "White"
		look.FillOpacity = 1
		look.Ink = "Ink"
		look.Gradient = false
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
	elseif size == "Menu" then
		return strong and "MenuButtonMain" or "MenuButton"
	end
	error("[Pulse.Controls] Button: unknown Size " .. tostring(size), 3)
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
	local gradient = nil
	local glow = nil
	local icon = nil

	local function layout()
		local variant = state.Variant
		local compact = isCompact(ctx)
		local role = buttonRole(variant, state.Size)
		local large = state.Size == "Large"
		local strong = variant == "Main" or variant == "Buy"
		local iconOnly = variant == "Icon"

		if variant == "Main" and gradient == nil then
			gradient = Instance.new("UIGradient")
			gradient.Name = "Gradient"
			gradient.Color = ColorSequence.new(colourOf("Pink"), colourOf("Violet"))
			gradient.Parent = fill
			glow = Surface.Glow(fill, { Name = "Glow", Kind = "Button", Colour = "Pink" }, scope)
			table.insert(bag, glow)
		end

		local drawnDesign
		if iconOnly then
			drawnDesign = compact and Space.CompactButtonDrawn or Space.IconButton
		elseif compact then
			drawnDesign = large and Space.TouchMin or Space.CompactButtonDrawn
		else
			drawnDesign = large and Space.ButtonHeightLarge or Space.ButtonHeight
		end
		local drawn = ctx.Px(drawnDesign)
		local hit = ctx.Touch(drawnDesign)

		local textSize = face(label, role, ctx)
		local caption = Controls._caption(variant, state.Text)
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

		put(root, "Size", UDim2.fromOffset(hitWidth, hit))
		put(fill, "Position", UDim2.fromOffset(math.floor((hitWidth - fillWidth) * HALF), math.floor((hit - drawn) * HALF)))
		put(fill, "Size", UDim2.fromOffset(fillWidth, drawn))

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
		})
		put(fill, "BackgroundColor3", colourOf(look.Fill))
		put(fill, "BackgroundTransparency", 1 - look.FillOpacity * look.Opacity)
		if gradient ~= nil then
			put(gradient, "Enabled", look.Gradient)
		end
		put(label, "TextColor3", colourOf(look.Ink))
		put(label, "TextTransparency", 1 - look.Opacity)
		if icon ~= nil then
			icon.Set({ Colour = look.Ink })
			fadeIcon(icon, 1 - look.Opacity)
		end
		if glow ~= nil then
			glow.Set({ Visible = look.Glow })
		end
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

local ROW_KEYS = keySet({ "Buttons", "Align", "Size" })
local ROW_DEFAULTS = { Align = "Right", Size = "Menu" }
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
		Size = size,
	}
end

function Controls.ButtonRow(parent, props, scope)
	local state = readProps("ButtonRow", ROW_KEYS, ROW_DEFAULTS, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local entries = {}
	local byId = {}
	local group = nil
	local destroyed = false

	local root = Instance.new("Frame")
	root.Name = state.Name or "ButtonRow"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0

	local function layout()
		if destroyed then
			return
		end
		local gap = ctx.Px(unit(ctx, Space.Gap))
		if isTouchy(ctx) then
			gap = math.max(gap, Space.TouchGap)
		end
		local x, height = 0, 0
		for index, entry in ipairs(entries) do
			local instance = entry.Button.Instance
			local size = instance.Size
			if index > 1 then
				x = x + gap
			end
			put(instance, "Position", UDim2.fromOffset(x, 0))
			x = x + size.X.Offset
			height = math.max(height, size.Y.Offset)
		end
		put(root, "Size", UDim2.fromOffset(x, height))
		if state.Align == "Centre" then
			put(root, "AnchorPoint", Vector2.new(0, 1))
			put(root, "Position", UDim2.new(HALF, -math.floor(x * HALF), 1, 0))
		elseif state.Align == "Right" then
			put(root, "AnchorPoint", Vector2.new(1, 1))
			put(root, "Position", UDim2.new(1, 0, 1, 0))
		else
			error("[Pulse.Controls] ButtonRow: unknown Align " .. tostring(state.Align), 2)
		end
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
				entries[index].Button.Set(patch)
			end
		else
			clear()
			group = Input.FocusGroup(scope, nil)
			for index, spec in ipairs(list) do
				local button = Controls.Button(root, patches[index], scope)
				local entry = { Id = spec.Id, Button = button }
				entry.Connection = scope:connect(button.Instance:GetPropertyChangedSignal("Size"), layout)
				entries[index] = entry
				byId[spec.Id] = button
				group.Add(button.Instance, index)
			end
		end
		layout()
	end

	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, layout)
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

local TABS_KEYS = keySet({ "Tabs", "Selected", "Bumpers", "OnSelected" })
local TAB_KEYS = { Id = true, Text = true, Icon = true, Locked = true, MarkKey = true }

-- Pure. flags: Selected, Locked, Hover, Focused.
function Controls._resolveTab(flags)
	local look = { Ink = "TextMuted", Fill = false, Underline = flags.Selected == true, Opacity = 1, Active = true }
	if flags.Locked then
		look.Opacity = Opacity.TabLocked
		look.Active = false
		if flags.Selected then
			look.Ink = "White"
		end
	elseif flags.Focused then
		look.Ink = "Ink"
		look.Fill = true
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

	local root = Instance.new("Frame")
	root.Name = state.Name or "Tabs"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0

	local function render()
		if destroyed then
			return
		end
		local underline = ctx.Hair(unit(ctx, Space.TabUnderline))
		local gap = ctx.Px(unit(ctx, Space.Gap))
		local between = ctx.Px(unit(ctx, Space.TabGap))
		if isTouchy(ctx) then
			between = math.max(between, Space.TouchGap)
		end
		local iconDesign = capOf(ctx, "Tab") * ICON_PER_CAP
		local iconPx = ctx.Px(iconDesign)
		local textSize = Text.SizeFor("Tab", ctx)
		local drawn = math.max(ctx.Px(unit(ctx, Space.BadgeLarge)), textSize + underline + underline)
		local hit = math.max(drawn, ctx.Touch(1))
		local top = math.floor((hit - drawn) * HALF)

		local x = 0
		for _, entry in ipairs(entries) do
			local spec = entry.Spec
			local button = entry.Button
			local look = Controls._resolveTab({
				Selected = spec.Id == state.Selected,
				Locked = spec.Locked == true,
				Hover = entry.Flags.Hover,
				Focused = entry.Flags.Focused,
			})
			face(button, "Tab", ctx)
			put(button, "Text", string.upper(tostring(spec.Text or "")))

			local iconName = textOf(spec.Icon)
			local lead = 0
			if iconName then
				lead = iconPx + gap
				if entry.Icon == nil then
					entry.Icon = Surface.Icon(button, { Name = "Icon", Icon = iconName, Colour = look.Ink, Size = iconDesign }, scope)
				else
					entry.Icon.Set({ Icon = iconName, Colour = look.Ink, Size = iconDesign, Visible = true })
				end
				put(entry.Icon.Instance, "Position", UDim2.fromOffset(0, math.floor((hit - iconPx) * HALF)))
				fadeIcon(entry.Icon, 1 - look.Opacity)
			elseif entry.Icon ~= nil then
				entry.Icon.Set({ Visible = false })
			end

			local width = lead + textWidth(button)
			put(button, "Position", UDim2.fromOffset(x, 0))
			put(button, "Size", UDim2.fromOffset(width, hit))
			put(button, "TextColor3", colourOf(look.Ink))
			put(button, "TextTransparency", 1 - look.Opacity)
			put(button, "BackgroundColor3", colourOf("White"))
			put(button, "BackgroundTransparency", look.Fill and 0 or 1)
			put(button, "Active", look.Active)

			put(entry.Underline, "Position", UDim2.fromOffset(0, top + drawn - underline))
			put(entry.Underline, "Size", UDim2.fromOffset(width, underline))
			put(entry.Underline, "BackgroundTransparency", 1 - look.Opacity)
			put(entry.Underline, "Visible", look.Underline)

			x = x + width + between
		end
		put(root, "Size", UDim2.fromOffset(math.max(0, x - between), hit))
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

	local function step(direction)
		if destroyed or state.Bumpers ~= true or not isShown(root) then
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
				step(-1)
			end, function()
				step(1)
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

return Controls
