-- Owns the Pulse data displays (CashChip, StatusCluster, SegmentedBar, DeltaChip, StatPanel, FactList) and the one Pulse door to the shared money formatters and cash binding; it does not own Cash, prices, affordability, any remote or any screen layout.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.Data. Requires: Tokens, Metrics, Text, Surface, Input, Collections (and ResponsiveUIFoundation, lazily, API2 3.5).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(script.Parent.Tokens)
local Metrics = require(script.Parent.Metrics)
local Text = require(script.Parent.Text)
local Surface = require(script.Parent.Surface)
local Input = require(script.Parent.Input)
local Collections = require(script.Parent.Collections)

local Data = {}

local Space = Tokens.Space
local Opacity = Tokens.Opacity
local Type = Tokens.Type

-- Design ratios and counts (not pixels). Every length below is a token, or a token times one of these.
local COMPACT_UNIT = Space.TouchGap / Space.Pad -- general 1080 px to Compact dp factor (8 / 22)
local HALF = 0.5
local CHIP_INSET = 0.8 -- side padding of the cash chip and the status strip against the panel padding
local CASH_WARM = 0.15 -- how far the right end of the cash gradient leans from Yellow towards Pink
local PLUS_RATIO = 0.6 -- plus button side against the strip height
local RANK_RATIO = 0.8 -- rank ring against the strip height
local DIVIDER_RATIO = 0.6 -- status divider against the strip height
local FACT_ICON_RATIO = 0.45 -- fact row icon against the row height
local LABEL_COLUMN = 0.32 -- stat label column against the panel content width (Regular)
local LABEL_COLUMN_COMPACT = 0.45
local DEFAULT_SEGMENTS = 16
local COMPACT_SEGMENTS = 8
local DEFAULT_STAT_MAX = 100
local MAX_PASSES = 4 -- a render that re-triggers itself settles within this many passes
local SUB_LINES = 2
-- A UIGradient multiplies the background colour, so a gradient frame is pure white underneath.
local GRADIENT_BASE = Color3.new(1, 1, 1)

local FOUNDATION_PATH = { "Modules", "Game", "UI", "ResponsiveUIFoundation" }

---------------------------------------------------------------------------------------------------
-- Shared helpers (the block Kit.Collections and Kit.Controls carry)
---------------------------------------------------------------------------------------------------

local function put(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function colourOf(role)
	local value = Tokens.Colour[role]
	if value == nil then
		error("[Pulse.Data] unknown colour role " .. tostring(role), 3)
	end
	return value
end

local function isCompact(ctx)
	return ctx.Class == "Compact"
end

local function unit(ctx, design)
	if isCompact(ctx) then
		return design * COMPACT_UNIT
	end
	return design
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
		if type(props) ~= "table" then
			error(string.format("[Pulse.Data] %s: props must be a table", kind), 3)
		end
		for key, value in pairs(props) do
			if not keys[key] then
				error(string.format("[Pulse.Data] %s: unknown key %s", kind, tostring(key)), 3)
			end
			state[key] = value
		end
	end
	return state
end

local function checkPatch(kind, keys, patch)
	if type(patch) ~= "table" then
		error(string.format("[Pulse.Data] %s.Set expects a table", kind), 3)
	end
	for key in pairs(patch) do
		if not keys[key] then
			error(string.format("[Pulse.Data] %s: unknown key %s", kind, tostring(key)), 3)
		end
	end
end

-- Returns true when a value differs. The patch has been checked.
local function mergePatch(state, patch)
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

local function onLayout(scope, bag, ctx, callback)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, function(change)
			if type(change) == "table" and change.Layout == false then
				return
			end
			callback()
		end)
	end
end

-- A marked root keeps the name Input.Mark gave it unless the screen names it.
local function applyName(root, state, default, marked)
	if state.Name ~= nil then
		put(root, "Name", state.Name)
	elseif not marked then
		put(root, "Name", default)
	end
end

local function applyCommon(root, state, default, marked)
	applyName(root, state, default, marked)
	put(root, "LayoutOrder", state.LayoutOrder or 0)
	put(root, "Visible", state.Visible ~= false)
end

-- Wraps a draw function so that a draw which re-triggers itself (a text bound or a child size
-- changing while it runs) runs again afterwards instead of nesting.
local function guarded(draw)
	local running = false
	local again = false
	return function()
		if running then
			again = true
			return
		end
		running = true
		local passes = 0
		repeat
			again = false
			passes = passes + 1
			local ok, problem = pcall(draw)
			if not ok then
				running = false
				error(problem, 0)
			end
		until not again or passes >= MAX_PASSES
		running = false
	end
end

local function newFrame(parent, name)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function newText(parent, name, role, ctx)
	local label = Text.RawLabel(parent, role, ctx)
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = ""
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	return label
end

-- Layout time only (it looks the size lock up by name).
local function face(label, role, ctx)
	local textSize = Text.SizeFor(role, ctx)
	put(label, "FontFace", Text.Font(role))
	put(label, "TextSize", textSize)
	local lock = label:FindFirstChild("SizeLock")
	if lock ~= nil then
		put(lock, "MaxTextSize", textSize)
	end
	return textSize
end

local function textWidth(label)
	return math.ceil(label.TextBounds.X)
end

local function baselineShift(textSize)
	return math.floor(Type.BaselineShift * textSize + HALF)
end

local function centred(outer, inner)
	return math.floor((outer - inner) * HALF)
end

-- True when the parent has a width of its own. A slot anchor (zero size) has none.
local function hasWidth(parent)
	local size = parent.Size
	return size.X.Scale ~= 0 or size.X.Offset ~= 0
end

local function isTier(value)
	return type(value) == "string" and Tokens.Tier[value] ~= nil
end

-- Creates, updates or hides the TierBadge kept in slot.Badge. A rating cannot be cleared through
-- Set, so a badge that loses its rating is rebuilt.
local function syncBadge(slot, parent, scope, bag, tier, rating, size, onResize)
	if tier == nil then
		if slot.Badge ~= nil then
			slot.Badge.Set({ Visible = false })
		end
		return nil
	end
	if slot.Badge ~= nil and slot.Rated and rating == nil then
		slot.Connection:Disconnect()
		slot.Badge.Destroy()
		slot.Badge = nil
	end
	if slot.Badge == nil then
		slot.Badge = Collections.TierBadge(parent, { Tier = tier, Rating = rating, Size = size }, scope)
		table.insert(bag, slot.Badge)
		slot.Connection = listen(scope, bag, slot.Badge.Instance:GetPropertyChangedSignal("Size"), onResize)
	else
		slot.Badge.Set({ Tier = tier, Rating = rating, Size = size, Visible = true })
	end
	slot.Rated = rating ~= nil
	return slot.Badge
end

-- A small square plus button: a transparent hit box holding an Ink plate with the glyph. Hover and
-- focus turn the plate White.
local function newPlus(parent, name, ctx, scope, bag, activated)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Text = ""
	button.TextTransparency = 1
	button.ZIndex = 2
	button.Parent = parent

	local icon = Surface.Icon(button, { Name = "Glyph", Icon = "plus", Colour = "White", Size = Space.BadgeSmall }, scope)
	table.insert(bag, icon)

	local plus = { Button = button, Hover = false, Focus = false }

	local function look()
		local hot = plus.Hover or plus.Focus
		put(icon.Instance, "BackgroundColor3", colourOf(hot and "White" or "Ink"))
		put(icon.Instance, "BackgroundTransparency", 0)
		icon.Set({ Colour = hot and "Ink" or "White" })
	end

	-- left, top: the drawn square's top-left in the parent; boxHeight: the height it is centred in.
	function plus.Layout(sideDesign, left, top, boxHeight)
		local side = ctx.Px(sideDesign)
		local hit = math.max(side, ctx.Touch(sideDesign))
		local inset = centred(hit, side)
		icon.Set({ Size = sideDesign })
		put(icon.Instance, "Position", UDim2.fromOffset(inset, inset))
		put(button, "Size", UDim2.fromOffset(hit, hit))
		put(button, "Position", UDim2.fromOffset(left - inset, top + centred(boxHeight, hit)))
		look()
		return side
	end

	listen(scope, bag, button.MouseEnter, function()
		plus.Hover = true
		look()
	end)
	listen(scope, bag, button.MouseLeave, function()
		plus.Hover = false
		look()
	end)
	listen(scope, bag, button.Activated, function()
		activated()
	end)
	Input.Focusable(button, {
		OnFocus = function(focused)
			plus.Focus = focused
			look()
		end,
	})
	look()
	return plus
end

---------------------------------------------------------------------------------------------------
-- Cash and money (API2 3.5): the shared formatters, presenter and binding, reused unchanged
---------------------------------------------------------------------------------------------------

local foundationModule = nil

-- May yield once, on the first call (the Classic module waits for Config.UI.Theme). Never called at
-- module load, from a constructor or from a frame step.
local function foundation()
	if foundationModule == nil then
		local node = ReplicatedStorage
		for _, name in ipairs(FOUNDATION_PATH) do
			node = node and node:FindFirstChild(name)
		end
		if node == nil then
			error("[Pulse.Data] ReplicatedStorage." .. table.concat(FOUNDATION_PATH, ".") .. " was not found", 2)
		end
		foundationModule = require(node)
	end
	return foundationModule
end

-- Test seam: a function returning the Foundation table. Everything below calls it through this field.
Data._foundation = foundation

-- The only money formatting in Pulse.
function Data.Money(amount, compact)
	local shared = Data._foundation()
	if compact then
		return shared.FormatCompactMoney(amount)
	end
	return shared.FormatFullMoney(amount)
end

function Data.FreeRoamMoney(amount)
	return Data._foundation().FormatFreeRoamMoney(amount)
end

-- Pure. {Cash, Used, Capacity} from a server reply; the projection Classic uses, unchanged.
function Data.ProjectEconomy(response, fallback)
	return Data._foundation().ProjectEconomy(response, fallback)
end

---------------------------------------------------------------------------------------------------
-- SegmentedBar
---------------------------------------------------------------------------------------------------

local BAR_KEYS = keySet({ "Value", "Preview", "Segments", "PreviewColour" })
local BAR_DEFAULTS = { Value = 0 }
local PREVIEW_COLOURS = { Cyan = true, Pink = true }

local function segmentPitch(ctx)
	return ctx.Px(unit(ctx, Space.SegmentWidth + Space.SegmentGap))
end

local function segmentHeight(ctx)
	return ctx.Px(unit(ctx, Space.SegmentHeight))
end

-- Pure. Whole segments: white fill count, first previewed segment (zero-based), previewed count and
-- "Gain", "Loss" or nil. A preview that differs from the value always shows at least one segment.
function Data._segments(value, preview, count)
	local function whole(fraction)
		return math.clamp(math.floor((tonumber(fraction) or 0) * count + HALF), 0, count)
	end
	local now = whole(value)
	if type(preview) ~= "number" or type(value) ~= "number" or count < 1 then
		return now, now, 0, nil
	end
	local after = whole(preview)
	if after == now and preview ~= value then
		if preview > value then
			if now == count then
				now = count - 1
			else
				after = now + 1
			end
		elseif now == 0 then
			now = 1
		else
			after = now - 1
		end
	end
	if after > now then
		return now, now, after - now, "Gain"
	elseif after < now then
		return after, after, now - after, "Loss"
	end
	return now, now, 0, nil
end

local function checkBar(values)
	if values.Value ~= nil and type(values.Value) ~= "number" then
		error("[Pulse.Data] SegmentedBar: Value must be a number from 0 to 1", 3)
	end
	if values.Preview ~= nil and values.Preview ~= false and type(values.Preview) ~= "number" then
		error("[Pulse.Data] SegmentedBar: Preview must be a number from 0 to 1 (false clears it)", 3)
	end
	if values.Segments ~= nil and (type(values.Segments) ~= "number" or values.Segments < 1) then
		error("[Pulse.Data] SegmentedBar: Segments must be at least 1", 3)
	end
	if values.PreviewColour ~= nil and not PREVIEW_COLOURS[values.PreviewColour] then
		error("[Pulse.Data] SegmentedBar: PreviewColour must be Cyan or Pink", 3)
	end
end

local function newStrip(parent, name)
	local strip = Instance.new("ImageLabel")
	strip.Name = name
	strip.BorderSizePixel = 0
	strip.BackgroundTransparency = 1
	strip.ScaleType = Enum.ScaleType.Tile
	strip.Parent = parent
	return strip
end

-- With no strip image the layer is a plain bar of the same colour (flat state).
local function paintStrip(strip, image, tile, role, opacity)
	local colour = colourOf(role)
	put(strip, "Image", image)
	put(strip, "TileSize", tile)
	put(strip, "ImageColor3", colour)
	put(strip, "ImageTransparency", 1 - opacity)
	put(strip, "BackgroundColor3", colour)
	put(strip, "BackgroundTransparency", image == "" and 1 - opacity or 1)
end

function Data.SegmentedBar(parent, props, scope)
	local state = readProps("SegmentedBar", BAR_KEYS, BAR_DEFAULTS, props)
	checkBar(state)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	local empty = newStrip(root, "Empty")
	local fill = newStrip(root, "Fill")
	local gain = newStrip(root, "Gain")

	local function render()
		if destroyed then
			return
		end
		local count = math.floor(state.Segments or DEFAULT_SEGMENTS)
		local pitch = segmentPitch(ctx)
		local height = segmentHeight(ctx)
		local image = Tokens.Asset("SegmentStrip") or ""
		local tile = UDim2.new(0, pitch, 1, 0)
		local filled, from, previewed, kind = Data._segments(state.Value, state.Preview, count)
		local gainRole = state.PreviewColour or (kind == "Loss" and "Pink" or "Cyan")

		put(root, "Size", UDim2.fromOffset(count * pitch, height))
		paintStrip(empty, image, tile, "White", Opacity.SegmentEmpty)
		put(empty, "Size", UDim2.fromOffset(count * pitch, height))
		paintStrip(fill, image, tile, "White", 1)
		put(fill, "Size", UDim2.fromOffset(filled * pitch, height))
		put(fill, "Visible", filled > 0)
		paintStrip(gain, image, tile, gainRole, 1)
		put(gain, "Position", UDim2.fromOffset(from * pitch, 0))
		put(gain, "Size", UDim2.fromOffset(previewed * pitch, height))
		put(gain, "Visible", previewed > 0)
	end

	onLayout(scope, bag, ctx, render)
	applyCommon(root, state, "SegmentedBar", false)
	render()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		checkPatch("SegmentedBar", BAR_KEYS, patch)
		checkBar(patch)
		if destroyed or not mergePatch(state, patch) then
			return
		end
		applyCommon(root, state, "SegmentedBar", false)
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
-- DeltaChip
---------------------------------------------------------------------------------------------------

local DELTA_KEYS = keySet({ "Delta", "Suffix" })
local DELTA_DEFAULTS = { Delta = 0 }

-- Pure. "+3", "-2", "+1.5%".
function Data._deltaText(delta, suffix)
	local magnitude = math.abs(delta)
	local body
	if magnitude == math.floor(magnitude) then
		body = string.format("%d", magnitude)
	else
		body = string.format("%.1f", magnitude)
	end
	return (delta < 0 and "-" or "+") .. body .. (textOf(suffix) or "")
end

local function checkDelta(values)
	if values.Delta ~= nil and (type(values.Delta) ~= "number" or values.Delta ~= values.Delta) then
		error("[Pulse.Data] DeltaChip: Delta must be a number", 3)
	end
	if values.Suffix ~= nil and type(values.Suffix) ~= "string" then
		error("[Pulse.Data] DeltaChip: Suffix must be a string", 3)
	end
end

function Data.DeltaChip(parent, props, scope)
	local state = readProps("DeltaChip", DELTA_KEYS, DELTA_DEFAULTS, props)
	checkDelta(state)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false

	local root = Instance.new("Frame")
	root.BorderSizePixel = 0
	local arrow = Surface.Icon(root, { Name = "Arrow", Icon = "chevron_up", Colour = "Ink", Size = Space.BadgeSmall * HALF }, scope)
	table.insert(bag, arrow)
	local label = newText(root, "Label", "Value", ctx)

	local render = guarded(function()
		if destroyed then
			return
		end
		local delta = state.Delta
		local up = delta >= 0
		local iconDesign = unit(ctx, Space.BadgeSmall) * HALF
		local iconPx = ctx.Px(iconDesign)
		local pad = ctx.Px(unit(ctx, Space.Gap))
		local gap = ctx.Px(unit(ctx, Space.ToastGap))

		applyName(root, state, "DeltaChip", false)
		put(root, "LayoutOrder", state.LayoutOrder or 0)
		-- Hidden at zero; the arrow and the sign carry the meaning with the colour.
		put(root, "Visible", state.Visible ~= false and delta ~= 0)
		put(root, "BackgroundColor3", colourOf(up and "Cyan" or "Pink"))
		put(root, "BackgroundTransparency", 0)

		put(label, "Text", Data._deltaText(delta, state.Suffix))
		local textSize = face(label, "Value", ctx)
		local height = math.max(ctx.Px(unit(ctx, Space.BadgeSmall)), textSize)
		local textPx = textWidth(label)

		arrow.Set({ Icon = up and "chevron_up" or "chevron_down", Size = iconDesign })
		put(arrow.Instance, "Position", UDim2.fromOffset(pad, centred(height, iconPx)))
		put(label, "TextColor3", colourOf("Ink"))
		put(label, "Position", UDim2.fromOffset(pad + iconPx + gap, -baselineShift(textSize)))
		put(label, "Size", UDim2.fromOffset(textPx, height))
		put(root, "Size", UDim2.fromOffset(pad + iconPx + gap + textPx + pad, height))
	end)

	listen(scope, bag, label:GetPropertyChangedSignal("TextBounds"), render)
	listen(scope, bag, Text.ReadyChanged, render)
	onLayout(scope, bag, ctx, render)
	render()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		checkPatch("DeltaChip", DELTA_KEYS, patch)
		checkDelta(patch)
		if destroyed or not mergePatch(state, patch) then
			return
		end
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
-- CashChip
---------------------------------------------------------------------------------------------------

-- OnResized (extra to API2): called after the chip's own size changes, so a holder can lay out at once.
local CASH_KEYS = keySet({ "Compact", "Plus", "OnPlus", "MarkKey", "FreeRoam", "OnResized" })

local function checkCash(values)
	if values.OnPlus ~= nil and type(values.OnPlus) ~= "function" then
		error("[Pulse.Data] CashChip: OnPlus must be a function", 3)
	end
	if values.OnResized ~= nil and type(values.OnResized) ~= "function" then
		error("[Pulse.Data] CashChip: OnResized must be a function", 3)
	end
	if values.MarkKey ~= nil and type(values.MarkKey) ~= "string" then
		error("[Pulse.Data] CashChip: MarkKey must be a string", 3)
	end
end

function Data.CashChip(parent, props, scope)
	local state = readProps("CashChip", CASH_KEYS, {}, props)
	checkCash(state)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false
	local marked = false

	local root = Instance.new("Frame")
	root.BorderSizePixel = 0
	root.BackgroundColor3 = GRADIENT_BASE
	root.BackgroundTransparency = 0
	root.Active = true
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Gradient"
	gradient.Color = ColorSequence.new(colourOf("Yellow"), colourOf("Yellow"):Lerp(colourOf("Pink"), CASH_WARM))
	gradient.Parent = root
	local coin = Surface.Icon(root, { Name = "Coin", Icon = "coin", Colour = "Ink", Size = Space.StatusHeight * HALF }, scope)
	table.insert(bag, coin)
	local label = newText(root, "Amount", "Status", ctx)
	local plus = nil -- built the first time Plus is true

	-- The projection on show. Both come from the presenter, a reply field or SetAmount; nothing here
	-- adds to, subtracts from or predicts them.
	local displayed = nil
	local authoritative = nil
	local shownText = ""
	-- While the presenter counts, the text box keeps the widest width seen, so nothing beside it moves.
	local holding = false
	local heldWidth = 0
	local measuring = false
	local unbind = nil

	local function short()
		if state.Compact ~= nil then
			return state.Compact == true
		end
		return isCompact(ctx)
	end

	local function format(amount)
		if short() then
			return tostring(Data.Money(amount, true))
		elseif state.FreeRoam == true then
			return tostring(Data.FreeRoamMoney(amount))
		end
		return tostring(Data.Money(amount, false))
	end

	local layout = guarded(function()
		if destroyed or measuring then
			return
		end
		local heightDesign = isCompact(ctx) and Space.CompactStatusHeight or Space.StatusHeight
		local height = ctx.Px(heightDesign)
		local pad = ctx.Px(unit(ctx, Space.Pad) * CHIP_INSET)
		local gap = ctx.Px(unit(ctx, Space.Gap))
		local iconDesign = heightDesign * HALF
		local iconPx = ctx.Px(iconDesign)
		local textSize = face(label, "Status", ctx)
		local textPx = textWidth(label)
		if holding then
			heldWidth = math.max(heldWidth, textPx)
			textPx = heldWidth
		end

		local x = pad
		coin.Set({ Size = iconDesign })
		put(coin.Instance, "Position", UDim2.fromOffset(x, centred(height, iconPx)))
		x = x + iconPx + gap
		put(label, "TextColor3", colourOf("Ink"))
		put(label, "Position", UDim2.fromOffset(x, -baselineShift(textSize)))
		put(label, "Size", UDim2.fromOffset(textPx, height))
		x = x + textPx

		if state.Plus == true then
			if plus == nil then
				plus = newPlus(root, "Plus", ctx, scope, bag, function()
					if state.OnPlus ~= nil then
						state.OnPlus()
					end
				end)
			end
			put(plus.Button, "Visible", true)
			x = x + gap
			x = x + plus.Layout(heightDesign * PLUS_RATIO, x, 0, height)
		elseif plus ~= nil then
			put(plus.Button, "Visible", false)
		end

		local size = UDim2.fromOffset(x + pad, height)
		if root.Size ~= size then
			root.Size = size
			if state.OnResized ~= nil then
				state.OnResized()
			end
		end
	end)

	-- shown: the amount to print. target: the authoritative amount it is counting towards (equal to
	-- shown when nothing is counting). The label is written only when its text changes.
	local function renderAmount(shown, target)
		if destroyed then
			return
		end
		displayed = shown
		authoritative = target
		local text = format(shown)
		local counting = target ~= nil and target ~= shown
		if counting and not holding then
			holding = true
			heldWidth = textWidth(label)
			local targetText = format(target)
			if targetText ~= shownText then
				-- Measured once per count: the box takes the wider of the old and the final text.
				measuring = true
				label.Text = targetText
				heldWidth = math.max(heldWidth, textWidth(label))
				shownText = targetText
				measuring = false
			end
		elseif not counting then
			holding = false
			heldWidth = 0
		end
		if text ~= shownText then
			shownText = text
			label.Text = text
		end
		layout()
	end

	listen(scope, bag, label:GetPropertyChangedSignal("TextBounds"), layout)
	listen(scope, bag, Text.ReadyChanged, layout)
	onLayout(scope, bag, ctx, function()
		if displayed ~= nil and state.Compact == nil then
			-- The default form follows the class, so a class change can change the text.
			local text = format(displayed)
			if text ~= shownText then
				shownText = text
				label.Text = text
			end
		end
		layout()
	end)

	applyCommon(root, state, "CashChip", marked)
	if state.MarkKey ~= nil then
		Input.Mark(root, state.MarkKey)
		marked = true
	end
	layout()
	root.Parent = parent

	local self = { Instance = root }

	-- API2 3.5. May yield once (the first foundation call); call it from a view build.
	function self.Bind(player)
		if destroyed then
			return
		end
		if unbind ~= nil then
			unbind()
		end
		local shared = Data._foundation()
		if destroyed then
			return
		end
		local presenter = shared.CreateCashDisplayPresenter(function(shown, target)
			renderAmount(shown, target)
		end)
		-- The presenter's methods take self, so SetTarget is wrapped rather than passed bare.
		local disconnect = shared.BindReplicatedCash(player, function(value)
			presenter:SetTarget(value)
		end)
		local released = false
		local function releaseBinding()
			if released then
				return
			end
			released = true
			if type(disconnect) == "function" then
				disconnect()
			end
			presenter:Destroy()
			if unbind == releaseBinding then
				unbind = nil
			end
		end
		unbind = releaseBinding
		scope:add(releaseBinding)
	end

	-- Shows an amount the owner already holds (a server reply field, a fixture). No count.
	function self.SetAmount(amount)
		if type(amount) ~= "number" then
			error("[Pulse.Data] CashChip.SetAmount expects a number", 2)
		end
		renderAmount(amount, amount)
	end

	function self.Set(patch)
		checkPatch("CashChip", CASH_KEYS, patch)
		checkCash(patch)
		if destroyed then
			return
		end
		local previousMark = state.MarkKey
		if not mergePatch(state, patch) then
			return
		end
		if state.MarkKey ~= nil and state.MarkKey ~= previousMark then
			Input.Mark(root, state.MarkKey)
			marked = true
		end
		applyCommon(root, state, "CashChip", marked)
		if displayed ~= nil then
			local text = format(displayed)
			if text ~= shownText then
				shownText = text
				label.Text = text
			end
		end
		layout()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if unbind ~= nil then
			unbind()
		end
		release(bag)
		root:Destroy()
	end

	return self
end

---------------------------------------------------------------------------------------------------
-- StatusCluster
---------------------------------------------------------------------------------------------------

local STATUS_KEYS = keySet({
	"Mode", "Tier", "Rating", "Spaces", "Rank", "ShowPlus", "OnSpacesPlus", "OnCashPlus", "MarkKey",
	"Label", "FreeRoam",
})
local STATUS_DEFAULTS = { Mode = "Vehicle" }
local STATUS_MODES = { Vehicle = true, Garage = true, CashOnly = true }

local function checkStatus(values)
	if values.Mode ~= nil and not STATUS_MODES[values.Mode] then
		error("[Pulse.Data] StatusCluster: unknown Mode " .. tostring(values.Mode), 3)
	end
	if values.Tier ~= nil and not isTier(values.Tier) then
		error("[Pulse.Data] StatusCluster: unknown tier " .. tostring(values.Tier), 3)
	end
	if values.Rating ~= nil and type(values.Rating) ~= "number" then
		error("[Pulse.Data] StatusCluster: Rating must be a number", 3)
	end
	if values.Spaces ~= nil and type(values.Spaces) ~= "string" then
		error("[Pulse.Data] StatusCluster: Spaces must be a string", 3)
	end
	if values.Label ~= nil and type(values.Label) ~= "string" then
		error("[Pulse.Data] StatusCluster: Label must be a string", 3)
	end
	if values.Rank ~= nil and type(values.Rank) ~= "number" then
		error("[Pulse.Data] StatusCluster: Rank must be a number", 3)
	end
	if values.MarkKey ~= nil and type(values.MarkKey) ~= "string" then
		error("[Pulse.Data] StatusCluster: MarkKey must be a string", 3)
	end
end

-- Pure. What the strip shows left of the cash chip: the mode icon, whether the badge, the text, the
-- spaces plus and the rank ring show, and the text itself.
function Data._statusParts(state, compact)
	local mode = state.Mode
	if mode == "CashOnly" then
		return { Strip = false }
	end
	local parts = { Strip = true }
	if mode == "Garage" then
		parts.Icon = "garage"
		parts.Text = textOf(state.Spaces)
		parts.Plus = state.ShowPlus == true
	else
		parts.Badge = state.Tier ~= nil
		if not parts.Badge then
			parts.Text = textOf(state.Label)
		end
		parts.Icon = (not parts.Badge and parts.Text ~= nil) and "passenger" or "car"
		parts.Plus = false
	end
	-- The Compact strip has no rank ring (the rank sits on the minimap there).
	parts.Rank = state.Rank ~= nil and not compact
	return parts
end

function Data.StatusCluster(parent, props, scope)
	local state = readProps("StatusCluster", STATUS_KEYS, STATUS_DEFAULTS, props)
	checkStatus(state)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false
	local marked = false

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	-- The chip and icons are built before the root is parented, so they must resolve this context, not the screen's.
	Metrics.Bind(root, ctx)
	local plate = newFrame(root, "Plate")
	plate.BackgroundColor3 = colourOf("Slate")
	plate.BackgroundTransparency = 1 - Opacity.Panel
	plate.Active = true

	local render = nil

	local chip = Data.CashChip(root, {
		Name = "Cash",
		Plus = state.ShowPlus == true,
		FreeRoam = state.FreeRoam,
		OnPlus = function()
			if state.OnCashPlus ~= nil then
				state.OnCashPlus()
			end
		end,
		OnResized = function()
			if render ~= nil then
				render()
			end
		end,
	}, scope)
	table.insert(bag, chip)

	-- Built on first use; a mode that never shows a piece never creates it.
	local modeIcon = nil
	local badgeSlot = {}
	local info = nil
	local spacesPlus = nil
	local divider = nil
	local rankRing = nil
	local rankText = nil

	render = guarded(function()
		if destroyed then
			return
		end
		local compact = isCompact(ctx)
		local parts = Data._statusParts(state, compact)
		local heightDesign = compact and Space.CompactStatusHeight or Space.StatusHeight
		local height = ctx.Px(heightDesign)
		local pad = ctx.Px(unit(ctx, Space.StatusPad))
		local gap = ctx.Px(unit(ctx, Space.Gap))
		local inner = ctx.Px(unit(ctx, Space.Pad) * CHIP_INSET)

		chip.Set({ Plus = state.ShowPlus == true, FreeRoam = state.FreeRoam })
		local chipWidth = chip.Instance.Size.X.Offset

		if not parts.Strip then
			put(plate, "Visible", false)
			put(chip.Instance, "Position", UDim2.fromOffset(0, 0))
			put(root, "Size", UDim2.fromOffset(chipWidth, height))
		end

		-- Mode icon.
		local x = pad + inner
		if parts.Strip then
			local iconDesign = heightDesign * HALF
			local iconPx = ctx.Px(iconDesign)
			if modeIcon == nil then
				modeIcon = Surface.Icon(root, { Name = "ModeIcon", Icon = parts.Icon, Colour = "White", Size = iconDesign }, scope)
				modeIcon.Instance.ZIndex = 2
				table.insert(bag, modeIcon)
			else
				modeIcon.Set({ Icon = parts.Icon, Size = iconDesign, Visible = true })
			end
			put(modeIcon.Instance, "Position", UDim2.fromOffset(x, pad + centred(height, iconPx)))
			x = x + iconPx + gap
		elseif modeIcon ~= nil then
			modeIcon.Set({ Visible = false })
		end

		-- Tier badge (Vehicle).
		local badge = syncBadge(badgeSlot, root, scope, bag, parts.Badge and state.Tier or nil, state.Rating, "Large", render)
		if badge ~= nil then
			local size = badge.Instance.Size
			put(badge.Instance, "ZIndex", 2)
			put(badge.Instance, "Position", UDim2.fromOffset(x, pad + centred(height, size.Y.Offset)))
			x = x + size.X.Offset + gap
		end

		-- Spaces (Garage) or the on-foot label.
		if parts.Text ~= nil then
			if info == nil then
				info = newText(root, "Info", "Status", ctx)
				info.ZIndex = 2
				listen(scope, bag, info:GetPropertyChangedSignal("TextBounds"), render)
			end
			put(info, "Visible", true)
			put(info, "Text", string.upper(parts.Text))
			local textSize = face(info, "Status", ctx)
			local textPx = textWidth(info)
			put(info, "TextColor3", colourOf("White"))
			put(info, "Position", UDim2.fromOffset(x, pad - baselineShift(textSize)))
			put(info, "Size", UDim2.fromOffset(textPx, height))
			x = x + textPx + gap
		elseif info ~= nil then
			put(info, "Visible", false)
		end

		-- Spaces plus (Garage).
		if parts.Plus then
			if spacesPlus == nil then
				spacesPlus = newPlus(root, "SpacesPlus", ctx, scope, bag, function()
					if state.OnSpacesPlus ~= nil then
						state.OnSpacesPlus()
					end
				end)
			end
			put(spacesPlus.Button, "Visible", true)
			x = x + spacesPlus.Layout(heightDesign * PLUS_RATIO, x, pad, height) + gap
		elseif spacesPlus ~= nil then
			put(spacesPlus.Button, "Visible", false)
		end

		-- Divider and rank ring (Regular).
		if parts.Rank then
			local hair = ctx.Hair(unit(ctx, Space.Hairline))
			local dividerHeight = math.floor(height * DIVIDER_RATIO + HALF)
			if divider == nil then
				divider = newFrame(root, "Divider")
				divider.ZIndex = 2
				divider.BackgroundColor3 = colourOf("White")
				divider.BackgroundTransparency = 1 - Opacity.HairBottom
			end
			x = x + gap
			put(divider, "Visible", true)
			put(divider, "Position", UDim2.fromOffset(x, pad + centred(height, dividerHeight)))
			put(divider, "Size", UDim2.fromOffset(hair, dividerHeight))
			x = x + hair + gap + gap

			local ringDesign = heightDesign * RANK_RATIO
			local ringPx = ctx.Px(ringDesign)
			if rankRing == nil then
				rankRing = Surface.Icon(root, { Name = "RankRing", Icon = "keycap_blank", Colour = "TextSecondary", Size = ringDesign }, scope)
				rankRing.Instance.ZIndex = 2
				table.insert(bag, rankRing)
				rankText = newText(root, "Rank", "Value", ctx)
				rankText.ZIndex = 3
				rankText.TextXAlignment = Enum.TextXAlignment.Center
			else
				rankRing.Set({ Size = ringDesign, Visible = true })
			end
			local ringY = pad + centred(height, ringPx)
			put(rankRing.Instance, "Position", UDim2.fromOffset(x, ringY))
			put(rankText, "Visible", true)
			put(rankText, "Text", string.format("%d", math.floor(state.Rank + HALF)))
			local textSize = face(rankText, "Value", ctx)
			put(rankText, "TextColor3", colourOf("White"))
			put(rankText, "Position", UDim2.fromOffset(x, ringY - baselineShift(textSize)))
			put(rankText, "Size", UDim2.fromOffset(ringPx, ringPx))
			x = x + ringPx + gap + gap
		else
			if divider ~= nil then
				put(divider, "Visible", false)
			end
			if rankRing ~= nil then
				rankRing.Set({ Visible = false })
				put(rankText, "Visible", false)
			end
		end

		if parts.Strip then
			local full = height + pad + pad
			put(plate, "Visible", true)
			if compact then
				-- The strip ends after its content; the chip stands beside it [seen c11].
				local stripWidth = x - gap + inner
				put(plate, "Size", UDim2.fromOffset(stripWidth, full))
				put(chip.Instance, "Position", UDim2.fromOffset(stripWidth + gap, pad))
				put(root, "Size", UDim2.fromOffset(stripWidth + gap + chipWidth, full))
			else
				put(plate, "Size", UDim2.fromOffset(x + chipWidth + pad, full))
				put(chip.Instance, "Position", UDim2.fromOffset(x, pad))
				put(root, "Size", UDim2.fromOffset(x + chipWidth + pad, full))
			end
		end
	end)

	chip.Instance.ZIndex = 2
	listen(scope, bag, Text.ReadyChanged, render)
	onLayout(scope, bag, ctx, render)

	applyCommon(root, state, "StatusCluster", marked)
	if state.MarkKey ~= nil then
		Input.Mark(root, state.MarkKey)
		marked = true
	end
	render()
	root.Parent = parent

	local self = { Instance = root, Cash = chip }

	function self.Set(patch)
		checkPatch("StatusCluster", STATUS_KEYS, patch)
		checkStatus(patch)
		if destroyed then
			return
		end
		local previousMark = state.MarkKey
		if not mergePatch(state, patch) then
			return
		end
		if state.MarkKey ~= nil and state.MarkKey ~= previousMark then
			Input.Mark(root, state.MarkKey)
			marked = true
		end
		applyCommon(root, state, "StatusCluster", marked)
		render()
	end

	-- These three take nil too (Set cannot clear a key): SetVehicle() is the on-foot strip.
	function self.SetVehicle(tier, rating)
		checkStatus({ Tier = tier, Rating = rating })
		if destroyed or (state.Tier == tier and state.Rating == rating) then
			return
		end
		state.Tier = tier
		state.Rating = rating
		render()
	end

	function self.SetSpaces(spaces)
		checkStatus({ Spaces = spaces })
		if destroyed or state.Spaces == spaces then
			return
		end
		state.Spaces = spaces
		render()
	end

	function self.SetRank(rank)
		checkStatus({ Rank = rank })
		if destroyed or state.Rank == rank then
			return
		end
		state.Rank = rank
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
-- FactList
---------------------------------------------------------------------------------------------------

local FACT_KEYS = keySet({ "Rows", "Width" })
local FACT_KINDS = { Text = true, Prize = true }

local function checkFactRows(rows)
	if type(rows) ~= "table" then
		error("[Pulse.Data] FactList: Rows must be a list", 4)
	end
	for index, row in ipairs(rows) do
		if type(row) ~= "table" or type(row.Label) ~= "string" or type(row.Value) ~= "string" then
			error("[Pulse.Data] FactList: row " .. index .. " needs a Label and a Value string", 4)
		end
		if row.Kind ~= nil and not FACT_KINDS[row.Kind] then
			error("[Pulse.Data] FactList: row " .. index .. " has unknown Kind " .. tostring(row.Kind), 4)
		end
		if row.Icon ~= nil and type(row.Icon) ~= "string" then
			error("[Pulse.Data] FactList: row " .. index .. " Icon must be an icon name", 4)
		end
	end
end

local function checkFacts(values)
	if values.Rows ~= nil then
		checkFactRows(values.Rows)
	end
	if values.Width ~= nil and type(values.Width) ~= "number" then
		error("[Pulse.Data] FactList: Width must be a design number", 3)
	end
end

function Data.FactList(parent, props, scope)
	local state = readProps("FactList", FACT_KEYS, {}, props)
	if state.Rows == nil then
		state.Rows = {}
	end
	checkFacts(state)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false
	local pool = {}

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0

	local render

	local function grow(index)
		local frame = newFrame(root, "Row" .. index)
		local item = {
			Frame = frame,
			Label = newText(frame, "Label", "Label", ctx),
			Value = newText(frame, "Value", "TileNameSmall", ctx),
			Divider = newFrame(frame, "Divider"),
			Icon = nil,
		}
		item.Value.AnchorPoint = Vector2.new(1, 0)
		item.Divider.AnchorPoint = Vector2.new(0, 1)
		item.Divider.BackgroundColor3 = colourOf("White")
		item.Divider.BackgroundTransparency = 1 - Opacity.HairBottom
		listen(scope, bag, item.Value:GetPropertyChangedSignal("TextBounds"), render)
		pool[index] = item
		return item
	end

	render = guarded(function()
		if destroyed then
			return
		end
		local rows = state.Rows
		local compact = isCompact(ctx)
		local rowHeight = ctx.Px(unit(ctx, Space.FactRowHeight))
		local hair = ctx.Hair(unit(ctx, Space.Hairline))
		local gap = ctx.Px(unit(ctx, Space.Gap))
		local iconDesign = unit(ctx, Space.FactRowHeight) * FACT_ICON_RATIO
		local iconPx = ctx.Px(iconDesign)

		local width
		if state.Width ~= nil then
			width = UDim.new(0, ctx.Px(state.Width))
		elseif hasWidth(parent) then
			width = UDim.new(1, 0)
		else
			width = UDim.new(0, ctx.Px(compact and Space.CompactStatPanelWidth or Space.ListWidth))
		end
		put(root, "Size", UDim2.new(width, UDim.new(0, #rows * rowHeight)))

		for index, row in ipairs(rows) do
			local item = pool[index] or grow(index)
			put(item.Frame, "Visible", true)
			put(item.Frame, "Position", UDim2.fromOffset(0, (index - 1) * rowHeight))
			put(item.Frame, "Size", UDim2.new(1, 0, 0, rowHeight))

			local labelX = 0
			if row.Icon ~= nil then
				if item.Icon == nil then
					item.Icon = Surface.Icon(item.Frame, { Name = "Icon", Icon = row.Icon, Colour = "TextSecondary", Size = iconDesign }, scope)
					table.insert(bag, item.Icon)
				else
					item.Icon.Set({ Icon = row.Icon, Size = iconDesign, Visible = true })
				end
				put(item.Icon.Instance, "Position", UDim2.fromOffset(0, centred(rowHeight, iconPx)))
				labelX = iconPx + gap + gap
			elseif item.Icon ~= nil then
				item.Icon.Set({ Visible = false })
			end

			put(item.Label, "Text", string.upper(row.Label))
			local labelSize = face(item.Label, "Label", ctx)
			put(item.Label, "TextColor3", colourOf("TextSecondary"))
			put(item.Label, "Position", UDim2.fromOffset(labelX, -baselineShift(labelSize)))
			put(item.Label, "Size", UDim2.new(1, -labelX, 0, rowHeight))

			local value = item.Value
			put(value, "Text", string.upper(row.Value))
			local valueSize = face(value, "TileNameSmall", ctx)
			if row.Kind == "Prize" then
				-- The value is a Yellow chip with Ink text.
				local chipHeight = math.max(ctx.Px(unit(ctx, Space.BadgeMedium)), valueSize)
				put(value, "BackgroundColor3", colourOf("Yellow"))
				put(value, "BackgroundTransparency", 0)
				put(value, "TextColor3", colourOf("Ink"))
				put(value, "TextXAlignment", Enum.TextXAlignment.Center)
				put(value, "Position", UDim2.new(1, 0, 0, centred(rowHeight, chipHeight)))
				put(value, "Size", UDim2.fromOffset(textWidth(value) + gap + gap, chipHeight))
			else
				put(value, "BackgroundTransparency", 1)
				put(value, "TextColor3", colourOf("White"))
				put(value, "TextXAlignment", Enum.TextXAlignment.Right)
				put(value, "Position", UDim2.new(1, 0, 0, -baselineShift(valueSize)))
				put(value, "Size", UDim2.new(1, -labelX, 0, rowHeight))
			end

			put(item.Divider, "Visible", index < #rows)
			put(item.Divider, "Position", UDim2.new(0, 0, 1, 0))
			put(item.Divider, "Size", UDim2.new(1, 0, 0, hair))
		end
		for index = #rows + 1, #pool do
			put(pool[index].Frame, "Visible", false)
		end
	end)

	listen(scope, bag, Text.ReadyChanged, render)
	onLayout(scope, bag, ctx, render)
	applyCommon(root, state, "FactList", false)
	render()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		checkPatch("FactList", FACT_KEYS, patch)
		checkFacts(patch)
		if destroyed or not mergePatch(state, patch) then
			return
		end
		applyCommon(root, state, "FactList", false)
		render()
	end

	-- Always renders: the caller may have changed the rows of the same table.
	function self.SetRows(rows)
		checkFactRows(rows)
		if destroyed then
			return
		end
		state.Rows = rows
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
-- StatPanel
---------------------------------------------------------------------------------------------------

local STAT_KEYS = keySet({ "Title", "Tier", "Rating", "Sub", "Rows", "Price", "Width", "Height" })
local HEADER_FIELDS = { "Tier", "Rating", "Sub", "Price" }

local function checkStatRows(rows)
	if type(rows) ~= "table" then
		error("[Pulse.Data] StatPanel: Rows must be a list", 4)
	end
	for index, row in ipairs(rows) do
		if type(row) ~= "table" or type(row.Label) ~= "string" or type(row.Value) ~= "number" then
			error("[Pulse.Data] StatPanel: row " .. index .. " needs a Label string and a Value number", 4)
		end
		if row.Max ~= nil and (type(row.Max) ~= "number" or row.Max <= 0) then
			error("[Pulse.Data] StatPanel: row " .. index .. " Max must be above 0", 4)
		end
		if row.Preview ~= nil and type(row.Preview) ~= "number" then
			error("[Pulse.Data] StatPanel: row " .. index .. " Preview must be a number", 4)
		end
		if row.Text ~= nil and type(row.Text) ~= "string" then
			error("[Pulse.Data] StatPanel: row " .. index .. " Text must be a string", 4)
		end
	end
end

local function checkStats(values)
	if values.Title ~= nil and type(values.Title) ~= "string" then
		error("[Pulse.Data] StatPanel: Title must be a string", 3)
	end
	if values.Tier ~= nil and not isTier(values.Tier) then
		error("[Pulse.Data] StatPanel: unknown tier " .. tostring(values.Tier), 3)
	end
	if values.Rating ~= nil and type(values.Rating) ~= "number" then
		error("[Pulse.Data] StatPanel: Rating must be a number", 3)
	end
	if values.Sub ~= nil and type(values.Sub) ~= "table" then
		error("[Pulse.Data] StatPanel: Sub must be a list of one or two strings", 3)
	end
	if values.Price ~= nil and type(values.Price) ~= "string" then
		error("[Pulse.Data] StatPanel: Price must be a formatted string (Data.Money)", 3)
	end
	if values.Width ~= nil and type(values.Width) ~= "number" then
		error("[Pulse.Data] StatPanel: Width must be a design number", 3)
	end
	if values.Height ~= nil and type(values.Height) ~= "number" then
		error("[Pulse.Data] StatPanel: Height must be a design number", 3)
	end
	if values.Rows ~= nil then
		checkStatRows(values.Rows)
	end
end

-- Pure. What one stat row shows: bar value and preview as fractions (preview false when none), the
-- value text and the delta.
function Data._statRow(row)
	local max = row.Max or DEFAULT_STAT_MAX
	local preview = row.Preview
	local shown = preview or row.Value
	local text = row.Text
	if text == nil then
		text = string.format("%d", math.floor(shown + HALF))
	end
	return {
		Value = math.clamp(row.Value / max, 0, 1),
		Preview = preview ~= nil and math.clamp(preview / max, 0, 1) or false,
		Text = text,
		Delta = preview ~= nil and preview - row.Value or 0,
	}
end

function Data.StatPanel(parent, props, scope)
	local state = readProps("StatPanel", STAT_KEYS, {}, props)
	if state.Title == nil then
		state.Title = ""
	end
	if state.Rows == nil then
		state.Rows = {}
	end
	checkStats(state)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false
	local pool = {}

	local function widthDesign()
		return state.Width or (isCompact(ctx) and Space.CompactStatPanelWidth or Space.StatPanelWidth)
	end

	-- The Panel is the root; rows and header live in its Content.
	local panel = Surface.Panel(parent, {
		Name = state.Name or "StatPanel",
		Width = widthDesign(),
		Pad = unit(ctx, Space.Pad),
	}, scope)
	table.insert(bag, panel)
	local content = panel.Content

	local title = newText(content, "Title", "SectionHead", ctx)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local subs = {}
	for index = 1, SUB_LINES do
		subs[index] = newText(content, "Sub" .. index, "Label", ctx)
	end
	local priceLabel = newText(content, "PriceLabel", "Label", ctx)
	local priceValue = newText(content, "Price", "Value", ctx)
	priceValue.AnchorPoint = Vector2.new(1, 0)
	priceValue.TextXAlignment = Enum.TextXAlignment.Center
	local badgeSlot = {}

	local render

	local function grow(index)
		local frame = newFrame(content, "Row" .. index)
		local item = {
			Frame = frame,
			Label = newText(frame, "Label", "Value", ctx),
			Bar = Data.SegmentedBar(frame, { Name = "Bar" }, scope),
			Value = newText(frame, "Value", "Status", ctx),
			Chip = Data.DeltaChip(frame, { Name = "Delta" }, scope),
		}
		item.Label.TextTruncate = Enum.TextTruncate.AtEnd
		item.Chip.Instance.AnchorPoint = Vector2.new(1, 0)
		table.insert(bag, item.Bar)
		table.insert(bag, item.Chip)
		listen(scope, bag, item.Chip.Instance:GetPropertyChangedSignal("Size"), render)
		pool[index] = item
		return item
	end

	render = guarded(function()
		if destroyed then
			return
		end
		local compact = isCompact(ctx)
		local rows = state.Rows
		local padDesign = unit(ctx, Space.Pad)
		local pad = ctx.Px(padDesign)
		local contentWidth = ctx.Px(widthDesign()) - pad - pad
		local gap = ctx.Px(unit(ctx, Space.Gap))
		local small = ctx.Px(unit(ctx, Space.ToastGap))
		local y = 0

		-- Header: name and badge. Regular: name left, Large badge right. Compact: Small badge, then name.
		local titleRole = compact and "TileName" or "SectionHead"
		put(title, "Text", string.upper(state.Title))
		local titleSize = face(title, titleRole, ctx)
		put(title, "TextColor3", colourOf("White"))
		local badge = syncBadge(badgeSlot, content, scope, bag, state.Tier, state.Rating, compact and "Small" or "Large", render)
		local badgeWidth, badgeHeight = 0, 0
		if badge ~= nil then
			badgeWidth = badge.Instance.Size.X.Offset
			badgeHeight = badge.Instance.Size.Y.Offset
		end
		local line = math.max(titleSize, badgeHeight)
		if compact then
			local titleX = badge ~= nil and badgeWidth + gap or 0
			if badge ~= nil then
				put(badge.Instance, "AnchorPoint", Vector2.new(0, 0))
				put(badge.Instance, "Position", UDim2.fromOffset(0, centred(line, badgeHeight)))
			end
			put(title, "Position", UDim2.fromOffset(titleX, centred(line, titleSize) - baselineShift(titleSize)))
			put(title, "Size", UDim2.fromOffset(math.max(1, contentWidth - titleX), titleSize))
		else
			if badge ~= nil then
				put(badge.Instance, "AnchorPoint", Vector2.new(1, 0))
				put(badge.Instance, "Position", UDim2.fromOffset(contentWidth, centred(line, badgeHeight)))
			end
			local room = badge ~= nil and contentWidth - badgeWidth - gap or contentWidth
			put(title, "Position", UDim2.fromOffset(0, centred(line, titleSize) - baselineShift(titleSize)))
			put(title, "Size", UDim2.fromOffset(math.max(1, room), titleSize))
		end
		y = line

		-- Sub-lines (Regular only; the Compact form is collapsed).
		for index = 1, SUB_LINES do
			local sub = subs[index]
			local text = not compact and type(state.Sub) == "table" and textOf(state.Sub[index]) or nil
			if text ~= nil then
				put(sub, "Visible", true)
				put(sub, "Text", text)
				local subSize = face(sub, "Label", ctx)
				put(sub, "TextColor3", colourOf("TextSecondary"))
				put(sub, "Position", UDim2.fromOffset(0, y + small - baselineShift(subSize)))
				put(sub, "Size", UDim2.fromOffset(contentWidth, subSize))
				y = y + small + subSize
			else
				put(sub, "Visible", false)
			end
		end

		-- Price row (Compact only): the price the screen already formatted, on a Yellow chip.
		local labelSize = Text.SizeFor("Value", ctx)
		local rowHeight = math.max(ctx.Px(unit(ctx, Space.StatRowHeight)), labelSize)
		local price = compact and textOf(state.Price) or nil
		if price ~= nil then
			put(priceLabel, "Visible", true)
			put(priceLabel, "Text", "PRICE")
			local priceLabelSize = face(priceLabel, "Label", ctx)
			put(priceLabel, "TextColor3", colourOf("TextSecondary"))
			put(priceLabel, "Position", UDim2.fromOffset(0, y + small - baselineShift(priceLabelSize)))
			put(priceLabel, "Size", UDim2.fromOffset(math.floor(contentWidth * HALF), rowHeight))
			put(priceValue, "Visible", true)
			put(priceValue, "Text", price)
			local priceSize = face(priceValue, "Value", ctx)
			put(priceValue, "BackgroundColor3", colourOf("Yellow"))
			put(priceValue, "BackgroundTransparency", 0)
			put(priceValue, "TextColor3", colourOf("Ink"))
			put(priceValue, "Position", UDim2.fromOffset(contentWidth, y + small))
			put(priceValue, "Size", UDim2.fromOffset(textWidth(priceValue) + gap + gap, math.max(rowHeight, priceSize)))
			y = y + small + math.max(rowHeight, priceSize)
		else
			put(priceLabel, "Visible", false)
			put(priceValue, "Visible", false)
		end

		-- Rows, pass 1: content, and the widest delta chip (the chip column exists only when one shows).
		local chipColumn = 0
		local shown = {}
		for index, row in ipairs(rows) do
			local item = pool[index] or grow(index)
			local view = Data._statRow(row)
			shown[index] = view
			item.Chip.Set({ Delta = view.Delta })
			if view.Delta ~= 0 then
				chipColumn = math.max(chipColumn, item.Chip.Instance.Size.X.Offset)
			end
		end

		-- Columns: label, bar, value cell, delta chip. The bar takes the whole segments that fit.
		local valueWidth = ctx.Px(unit(ctx, compact and Space.IconButton or Space.BadgeLarge))
		local valueHeight = compact and rowHeight or math.min(rowHeight, ctx.Px(Space.BadgeMedium))
		local labelWidth = math.floor(contentWidth * (compact and LABEL_COLUMN_COMPACT or LABEL_COLUMN))
		local valueRight = chipColumn > 0 and contentWidth - chipColumn - gap or contentWidth
		local valueLeft = valueRight - valueWidth
		local barRight = valueLeft - gap - small
		local pitch = segmentPitch(ctx)
		local most = compact and COMPACT_SEGMENTS or DEFAULT_SEGMENTS
		local segments = math.clamp(math.floor((barRight - labelWidth) / pitch), 1, most)
		local barLeft = barRight - segments * pitch
		local barHeight = segmentHeight(ctx)
		local valueRole = compact and "Value" or "Status"

		y = y + gap
		for index, row in ipairs(rows) do
			local item = pool[index]
			local view = shown[index]
			put(item.Frame, "Visible", true)
			put(item.Frame, "Position", UDim2.fromOffset(0, y + (index - 1) * rowHeight))
			put(item.Frame, "Size", UDim2.fromOffset(contentWidth, rowHeight))

			put(item.Label, "Text", string.upper(row.Label))
			local rowLabelSize = face(item.Label, "Value", ctx)
			put(item.Label, "TextColor3", colourOf("White"))
			put(item.Label, "Position", UDim2.fromOffset(0, -baselineShift(rowLabelSize)))
			put(item.Label, "Size", UDim2.fromOffset(math.max(1, barLeft - small), rowHeight))

			item.Bar.Set({ Segments = segments, Value = view.Value, Preview = view.Preview })
			put(item.Bar.Instance, "Position", UDim2.fromOffset(barLeft, centred(rowHeight, barHeight)))

			local value = item.Value
			put(value, "Text", view.Text)
			local valueSize = face(value, valueRole, ctx)
			put(value, "TextColor3", colourOf("White"))
			if compact then
				put(value, "BackgroundTransparency", 1)
				put(value, "TextXAlignment", Enum.TextXAlignment.Right)
				put(value, "Position", UDim2.fromOffset(valueLeft, -baselineShift(valueSize)))
			else
				put(value, "BackgroundColor3", colourOf("White"))
				put(value, "BackgroundTransparency", 1 - Opacity.ChipNeutral)
				put(value, "TextXAlignment", Enum.TextXAlignment.Center)
				put(value, "Position", UDim2.fromOffset(valueLeft, centred(rowHeight, valueHeight)))
			end
			put(value, "Size", UDim2.fromOffset(valueWidth, valueHeight))

			local chipHeight = item.Chip.Instance.Size.Y.Offset
			put(item.Chip.Instance, "Position", UDim2.fromOffset(contentWidth, centred(rowHeight, chipHeight)))
		end
		y = y + #rows * rowHeight
		for index = #rows + 1, #pool do
			put(pool[index].Frame, "Visible", false)
		end

		-- The panel: a given Height, the Regular token, or (Compact) the height of what it holds.
		local heightDesign = state.Height
		if heightDesign == nil then
			if compact then
				heightDesign = (y + pad + pad) / ctx.Scale
			else
				heightDesign = Space.StatPanelHeight
			end
		end
		panel.Set({
			Name = state.Name or "StatPanel",
			LayoutOrder = state.LayoutOrder or 0,
			Visible = state.Visible ~= false,
			Width = widthDesign(),
			Height = heightDesign,
			Pad = padDesign,
		})
	end)

	listen(scope, bag, priceValue:GetPropertyChangedSignal("TextBounds"), render)
	listen(scope, bag, Text.ReadyChanged, render)
	onLayout(scope, bag, ctx, render)
	render()

	local self = { Instance = panel.Instance }

	function self.Set(patch)
		checkPatch("StatPanel", STAT_KEYS, patch)
		checkStats(patch)
		if destroyed or not mergePatch(state, patch) then
			return
		end
		render()
	end

	-- Always renders: the caller may have changed the rows of the same table. Row ids that stay put
	-- create and destroy nothing; the pool only ever grows.
	function self.SetRows(rows)
		checkStatRows(rows)
		if destroyed then
			return
		end
		state.Rows = rows
		render()
	end

	-- Replaces the header: {Title, Tier, Rating, Sub, Price}. A missing Title keeps the old one; the
	-- other four are taken as given, so leaving one out clears it.
	function self.SetHeader(header)
		if type(header) ~= "table" then
			error("[Pulse.Data] StatPanel.SetHeader expects a table", 2)
		end
		checkStats({ Title = header.Title, Tier = header.Tier, Rating = header.Rating, Sub = header.Sub, Price = header.Price })
		if destroyed then
			return
		end
		if header.Title ~= nil then
			state.Title = header.Title
		end
		for _, field in ipairs(HEADER_FIELDS) do
			state[field] = header[field]
		end
		render()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		release(bag)
	end

	return self
end

return Data
