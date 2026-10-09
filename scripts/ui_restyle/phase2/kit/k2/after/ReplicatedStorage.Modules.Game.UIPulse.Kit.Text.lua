-- Owns Pulse text: faces, the cap-height to TextSize rule, font readiness, measurement, the Label component and the plain label helpers; does not own colours, scale, or any layout outside a label's own box.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.Text. Requires: Tokens, Metrics.
local TextService = game:GetService("TextService")

local Tokens = require(script.Parent.Tokens)
local Metrics = require(script.Parent.Metrics)

local Type = Tokens.Type
local Space = Tokens.Space

local Text = {}

-- Faces are not config (API 3.4). Every role not listed here is a display role.
local FACES = {
	Display = { Weight = Enum.FontWeight.ExtraBold, Style = Enum.FontStyle.Italic },
	Label = { Weight = Enum.FontWeight.SemiBold, Style = Enum.FontStyle.Italic },
	Body = { Weight = Enum.FontWeight.Medium, Style = Enum.FontStyle.Normal },
}
local HOLDER_ROLES = { ScreenTitle = true, SectionHead = true }
-- Only these follow the player's Text Size setting; display roles and Value are Fixed (API2 2.6).
local GROWS = { Label = true, Body = true }
local ALIGN = {
	Left = Enum.TextXAlignment.Left,
	Centre = Enum.TextXAlignment.Center,
	Right = Enum.TextXAlignment.Right,
}
local LABEL_KEYS = {
	Name = true, LayoutOrder = true, Visible = true,
	Text = true, Role = true, Colour = true, Align = true, Wrap = true, MaxWidth = true,
	Upper = true, Shadow = true, Fixed = true,
}
local PROBE_TEXT = "PULSE 0123456789"
local MEASURE_CACHE_LIMIT = 512
local ESTIMATE_GLYPH_RATIO = 0.6 -- width of an average capital over TextSize; used only if measuring fails

local usingFallback = false
local preloadStarted = false
local fontCache = {}
local measureCache = {}
local measureCacheCount = 0
local warned = {}

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn("[Pulse.Text] " .. message)
end

local function round(value)
	return math.floor(value + 0.5)
end

local function write(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

-- A plain Luau signal, so requiring this module creates no instance. Connections expose Disconnect, which is
-- all Core.ConnectionScope needs to release them.
local function newSignal()
	local connections = {}
	local signal = {}

	function signal:Connect(callback)
		local connection = { Connected = true }
		function connection:Disconnect()
			if not self.Connected then
				return
			end
			self.Connected = false
			local index = table.find(connections, self)
			if index then
				table.remove(connections, index)
			end
		end
		connection.Callback = callback
		table.insert(connections, connection)
		return connection
	end

	function signal:Once(callback)
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			callback(...)
		end)
		return connection
	end

	function signal:Wait()
		local thread = coroutine.running()
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread, ...)
			end
		end)
		return coroutine.yield()
	end

	local function fire(...)
		for _, connection in table.clone(connections) do
			if connection.Connected then
				task.spawn(connection.Callback, ...)
			end
		end
	end

	return signal, fire
end

local readyChanged, fireReadyChanged = newSignal()

Text.Ready = false
Text.ReadyChanged = readyChanged

local function isRole(role)
	return type(role) == "string" and Tokens.Cap.Regular[role] ~= nil
end

local function assertRole(role)
	if not isRole(role) then
		error("Text: unknown role " .. tostring(role), 3)
	end
end

local function faceOf(role)
	return FACES[role] or FACES.Display
end

local function isDisplay(role)
	return FACES[role] == nil
end

local function capOf(role, ctx)
	local caps = ctx.Class == "Compact" and Tokens.Cap.Compact or Tokens.Cap.Regular
	return caps[role]
end

local function family()
	return usingFallback and Type.FallbackFamily or Type.Family
end

local function capRatio()
	return usingFallback and Type.FallbackCapRatio or Type.CapRatio
end

function Text.Font(role)
	local font = fontCache[role]
	if not font then
		assertRole(role)
		local face = faceOf(role)
		font = Font.new(family(), face.Weight, face.Style)
		fontCache[role] = font
	end
	return font
end

-- Pure: textSize, holderScale (API 3.4).
function Text.SizeFor(role, ctx)
	assertRole(role)
	local raw = round(capOf(role, ctx) * ctx.Scale / capRatio())
	local textSize = math.clamp(raw, Type.MinTextSize, Type.MaxTextSize)
	local holderScale = 1
	if raw > Type.MaxTextSize and HOLDER_ROLES[role] then
		holderScale = raw / Type.MaxTextSize
	end
	return textSize, holderScale
end

local function boundsOf(text, font, textSize, width)
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = font
	params.Size = textSize
	if width > 0 then
		params.Width = width
	end
	return TextService:GetTextBoundsAsync(params)
end

-- Non-blocking and idempotent. GetTextBoundsAsync returns once the face is usable (Phase 0 spike 01).
function Text.Preload()
	if preloadStarted then
		return
	end
	preloadStarted = true

	local fonts = {}
	for _, face in FACES do
		table.insert(fonts, Font.new(Type.Family, face.Weight, face.Style))
	end
	local pending = #fonts

	local function finish(ok, message)
		pending -= 1
		if not ok and not usingFallback then
			usingFallback = true
			table.clear(fontCache)
			table.clear(measureCache)
			measureCacheCount = 0
			warnOnce("fallback", "font family did not load; using the fallback family: " .. tostring(message))
		end
		if pending == 0 then
			Text.Ready = true
			fireReadyChanged()
		end
	end

	for _, font in fonts do
		task.spawn(function()
			local ok, message = pcall(boundsOf, PROBE_TEXT, font, Type.MinTextSize, 0)
			finish(ok, message)
		end)
	end
end

-- YIELDS up to timeout (default Tokens.Type.ReadyTimeout). Returns Text.Ready.
function Text.WaitReady(timeout)
	if Text.Ready then
		return true
	end
	Text.Preload()
	if Text.Ready then
		return true
	end

	local thread = coroutine.running()
	local settled = false
	local connection
	local function settle(value)
		if settled then
			return
		end
		settled = true
		connection:Disconnect()
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, value)
		end
	end
	connection = readyChanged:Connect(function()
		if Text.Ready then
			settle(true)
		end
	end)
	task.delay(timeout or Type.ReadyTimeout, settle, false)
	return coroutine.yield()
end

local function remember(key, bounds)
	if measureCache[key] ~= nil then
		return
	end
	if measureCacheCount >= MEASURE_CACHE_LIMIT then
		table.clear(measureCache)
		measureCacheCount = 0
	end
	measureCache[key] = bounds
	measureCacheCount += 1
end

-- Pure. Bounds from the average glyph width, for when the face cannot be measured (in time): one line, or
-- `width` wide and as many lines as the run needs.
local function estimate(text, textSize, width)
	local run = #text * textSize * ESTIMATE_GLYPH_RATIO
	if width > 0 and run > width then
		return Vector2.new(width, math.ceil(run / width) * textSize)
	end
	return Vector2.new(run, textSize)
end

-- YIELDS for at most `limit` seconds while `call` runs in its own thread. Returns ok, result as pcall does, or
-- false, nil, true once the limit has passed; `call` still runs to its end and its late result is dropped here.
local function bounded(limit, call, ...)
	local thread = coroutine.running()
	local settled = false
	local ok, result, timedOut = false, nil, false
	local timer = nil
	task.spawn(function(...)
		local okCall, value = pcall(call, ...)
		if settled then
			return
		end
		settled = true
		ok, result = okCall, value
		if timer then
			task.cancel(timer)
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread)
			end
		end
	end, ...)
	if not settled then
		timer = Text._delay(limit, function()
			if settled then
				return
			end
			settled = true
			timedOut = true
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread)
			end
		end)
		coroutine.yield()
	end
	return ok, result, timedOut
end

-- Exposed for the pure tests only; `_delay` is the timer `bounded` uses, replaced there by a recorder.
Text._delay = task.delay
Text._estimate = estimate
Text._bounded = bounded

-- YIELDS for at most Tokens.Type.ReadyTimeout. Bounds of the text itself in real pixels (a Label root is wider by
-- its italic padding). maxWidth is the wrap width in real pixels; nil measures one line. A face that has not
-- arrived by the limit gives an estimate; the real bounds are cached when they come and ReadyChanged (Preload is
-- started here if nobody did) tells the caller to lay out again.
function Text.Measure(text, role, ctx, maxWidth)
	local textSize, holderScale = Text.SizeFor(role, ctx)
	local font = Text.Font(role)
	local width = 0
	if maxWidth then
		width = math.max(1, math.floor(maxWidth / holderScale))
	end

	local key = table.concat({ font.Family, role, tostring(textSize), tostring(width), text }, "|")
	local bounds = measureCache[key]
	if not bounds then
		local ok, result, timedOut = bounded(Type.ReadyTimeout, function()
			local measured = boundsOf(text, font, textSize, width)
			remember(key, measured)
			return measured
		end)
		if ok then
			bounds = result
		else
			if timedOut then
				warnOnce("measureWait", "GetTextBoundsAsync passed the ready limit; using an estimate until the face arrives")
				Text.Preload()
			else
				warnOnce("measure", "GetTextBoundsAsync failed; using an estimate: " .. tostring(result))
			end
			bounds = estimate(text, textSize, width)
		end
	end
	return Vector2.new(math.ceil(bounds.X * holderScale), math.ceil(bounds.Y * holderScale))
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

-- Checks only the keys that are present, so it serves both props and a Set patch.
local function checkLabelValues(values)
	if values.Role ~= nil then
		assertRole(values.Role)
	end
	if values.Text ~= nil and type(values.Text) ~= "string" then
		error("Text.Label: Text must be a string", 3)
	end
	if values.Colour ~= nil and Tokens.Colour[values.Colour] == nil then
		error("Text.Label: unknown colour role " .. tostring(values.Colour), 3)
	end
	if values.Align ~= nil and ALIGN[values.Align] == nil then
		error("Text.Label: unknown Align " .. tostring(values.Align), 3)
	end
	if values.MaxWidth ~= nil and type(values.MaxWidth) ~= "number" then
		error("Text.Label: MaxWidth must be a design number", 3)
	end
end

-- Pure: no connection, no relayout. One plain TextLabel named Label with the role's face and size, white, left
-- aligned, one line high and as wide as its text (AutomaticSize X, which a caller that sets a width may clear),
-- lifted by the baseline shift, with a SizeLock constraint when the role is Fixed. Kit modules use it inside
-- budgeted components and write Text, colour and geometry themselves; a role above 100 stops at 100 (no holder).
function Text.RawLabel(parent, role, ctx)
	assertRole(role)
	local textSize = Text.SizeFor(role, ctx)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.FontFace = Text.Font(role)
	label.TextSize = textSize
	label.TextColor3 = Tokens.Colour.White
	label.Text = ""
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, textSize)
	label.Position = UDim2.fromOffset(0, -round(Type.BaselineShift * textSize))
	if not GROWS[role] then
		local lock = Instance.new("UITextSizeConstraint")
		lock.Name = "SizeLock"
		lock.MinTextSize = 1
		lock.MaxTextSize = textSize
		lock.Parent = label
	end
	label.Parent = parent
	return label
end

-- Styles a label the kit did not build (the RaceTransitionClient seam, API2 5.5). Sized for the real screen.
function Text.StyleForeign(label, role)
	assertRole(role)
	if typeof(label) ~= "Instance" or not label:IsA("TextLabel") then
		error("Text.StyleForeign: a TextLabel is required", 2)
	end
	local textSize = Text.SizeFor(role, Metrics.Screen())
	write(label, "FontFace", Text.Font(role))
	write(label, "TextSize", textSize)
	write(label, "TextColor3", Tokens.Colour.White)
	write(label, "TextStrokeTransparency", 1)
end

-- Box rules:
--   no MaxWidth, no Wrap: one line, the root hugs the text plus the italic padding;
--   MaxWidth:             the root is exactly that wide; one line truncates, Wrap grows downward;
--   Wrap, no MaxWidth:    the root fills its parent's width and grows downward.
function Text.Label(parent, props, scope)
	props = props or {}
	checkKeys(props, LABEL_KEYS, "Text.Label")
	checkLabelValues(props)
	if props.Role == nil then
		error("Text.Label: Role is required", 2)
	end

	local ctx = Metrics.Of(parent)
	local state = table.clone(props)
	local connections = {}
	local constraints = {}
	local destroyed = false
	local scaler = nil
	local shadow = nil
	local autoWidth = false
	local fitWidth = 0
	local fitPad = 0
	local line = 0

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ZIndex = 2
	label.Parent = root

	local function setConstraint(target, fixed, textSize)
		local constraint = constraints[target]
		if fixed then
			if not constraint then
				constraint = Instance.new("UITextSizeConstraint")
				constraint.Name = "FixedSize"
				constraint.Parent = target
				constraints[target] = constraint
			end
			write(constraint, "MaxTextSize", textSize)
		elseif constraint then
			constraint:Destroy()
			constraints[target] = nil
		end
	end

	-- The hugging root needs the text width plus the italic padding. The label sizes itself; this reads the
	-- result back and divides out whatever UIScale sits above (the holder's own or the gallery's), using the
	-- root's known line height as the reference.
	local function fit()
		if not autoWidth or destroyed then
			return
		end
		local rootHeight = root.AbsoluteSize.Y
		local labelWidth = label.AbsoluteSize.X
		if rootHeight <= 0 then
			return
		end
		local width = 0
		if labelWidth > 0 then
			width = math.ceil(labelWidth * line / rootHeight - 0.01) + fitPad
		end
		if width ~= fitWidth then
			fitWidth = width
			write(root, "Size", UDim2.fromOffset(fitWidth, line))
		end
	end

	local function render()
		local role = state.Role
		local textSize, holderScale = Text.SizeFor(role, ctx)
		local face = faceOf(role)
		local wrap = state.Wrap == true
		local align = ALIGN[state.Align or "Left"]

		-- Everything inside the holder is in pre-scale units; the static UIScale multiplies it back.
		local pad = 0
		if face.Style == Enum.FontStyle.Italic then
			pad = round(Type.ItalicPad * capOf(role, ctx) * ctx.Scale / holderScale)
		end
		local shift = round(Type.BaselineShift * textSize)
		local inset = align == Enum.TextXAlignment.Center and 0 or pad
		local maxWidth = nil
		if state.MaxWidth then
			maxWidth = math.max(1, round(ctx.Px(state.MaxWidth) / holderScale))
		end

		local upper = state.Upper
		if upper == nil then
			upper = isDisplay(role)
		end
		local shown = state.Text or ""
		if upper then
			shown = string.upper(shown)
		end

		local fixed = state.Fixed
		if fixed == nil then
			fixed = not GROWS[role]
		end

		line = textSize
		fitPad = pad
		autoWidth = maxWidth == nil and not wrap
		if not autoWidth then
			fitWidth = 0
		end

		local rootSize, labelSize, automatic
		if maxWidth then
			rootSize = UDim2.fromOffset(maxWidth, line)
			labelSize = UDim2.fromOffset(math.max(1, maxWidth - inset), line)
			automatic = wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None
		elseif wrap then
			rootSize = UDim2.new(1, 0, 0, line)
			labelSize = UDim2.new(1, -inset, 0, line)
			automatic = Enum.AutomaticSize.Y
		else
			rootSize = UDim2.fromOffset(fitWidth, line)
			labelSize = UDim2.fromOffset(0, line)
			automatic = Enum.AutomaticSize.X
		end

		local font = Text.Font(role)
		local truncate = Enum.TextTruncate.None
		if maxWidth and not wrap then
			truncate = Enum.TextTruncate.AtEnd
		end

		local function paint(target, offset, colour, transparency)
			write(target, "FontFace", font)
			write(target, "TextSize", textSize)
			write(target, "Text", shown)
			write(target, "TextColor3", colour)
			write(target, "TextTransparency", transparency)
			write(target, "TextXAlignment", align)
			write(target, "TextYAlignment", wrap and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center)
			write(target, "TextWrapped", wrap)
			write(target, "TextTruncate", truncate)
			write(target, "AutomaticSize", automatic)
			write(target, "Size", labelSize)
			write(target, "Position", UDim2.fromOffset(offset, offset - shift))
			setConstraint(target, fixed, textSize)
		end

		write(root, "Name", state.Name or "Label")
		if state.LayoutOrder ~= nil then
			write(root, "LayoutOrder", state.LayoutOrder)
		end
		write(root, "Visible", state.Visible ~= false)
		write(root, "AutomaticSize", automatic)
		write(root, "Size", rootSize)

		if holderScale > 1 then
			if not scaler then
				scaler = Instance.new("UIScale")
				scaler.Name = "HolderScale"
				scaler.Parent = root
			end
			write(scaler, "Scale", holderScale)
		elseif scaler then
			scaler:Destroy()
			scaler = nil
		end

		paint(label, 0, Tokens.Colour[state.Colour or "White"], 0)

		if state.Shadow then
			if not shadow then
				shadow = Instance.new("TextLabel")
				shadow.Name = "Shadow"
				shadow.BackgroundTransparency = 1
				shadow.BorderSizePixel = 0
				shadow.ZIndex = 1
				shadow.Parent = root
			end
			local drop = math.max(1, round(ctx.Px(Space.TextShadowOffset) / holderScale))
			paint(shadow, drop, Tokens.Colour.Ink, 1 - Tokens.Opacity.TextShadow)
		elseif shadow then
			constraints[shadow] = nil
			shadow:Destroy()
			shadow = nil
		end

		fit()
	end

	render()

	table.insert(connections, scope:connect(label:GetPropertyChangedSignal("AbsoluteSize"), fit))
	-- The face arriving changes the metrics (the engine re-lays the label out, fit follows); a switch to the
	-- fallback family also changes the face and the cap ratio, so render again.
	table.insert(connections, scope:connect(readyChanged, function()
		if not destroyed then
			render()
		end
	end))
	if ctx.Changed then
		table.insert(connections, scope:connect(ctx.Changed, function(change)
			if destroyed or (type(change) == "table" and change.Layout == false) then
				return
			end
			fitWidth = 0
			render()
		end))
	end

	local component = { Instance = root }

	function component.Set(patch)
		checkKeys(patch, LABEL_KEYS, "Text.Label")
		checkLabelValues(patch)
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
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		root:Destroy()
	end

	root.Parent = parent
	return component
end

return Text
