-- Owns the Pulse toast stack, confirmation and modal components; not the toast bindable, the owner's start-up or what a caller does with a result.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Kit.Overlay. Requires: Tokens, Metrics, Layers, Text, Surface, Input, Controls.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Tokens = require(script.Parent.Tokens)
local Metrics = require(script.Parent.Metrics)
local Layers = require(script.Parent.Layers)
local Text = require(script.Parent.Text)
local Surface = require(script.Parent.Surface)
local Input = require(script.Parent.Input)
local Controls = require(script.Parent.Controls)

local Overlay = {}

local Space = Tokens.Space

-- Toast timing. The three duration values are the Classic controller's.
local TOAST_DEFAULT_SECONDS = 2.5
local TOAST_MIN_SECONDS = 0.5
local TOAST_MAX_SECONDS = 10
local TOAST_FADE_SECONDS = 0.12
local TOAST_ROLE = "Body"

-- Confirmation contract values (the Classic confirmation's).
local CONFIRM_OVERLAY_NAME = "SharedConfirmationOverlay"
local CONFIRM_SHADE_NAME = "SharedConfirmation"
local CONFIRM_EXIT_PRIORITY = 10000
local TITLE_ROLE = "SectionHead"
local BODY_ROLE = "Body"

local TOAST_KEYS = { Name = true, LayoutOrder = true, Visible = true, MaxCards = true }
local MODAL_KEYS = { Name = true, LayoutOrder = true, Visible = true, Title = true, Width = true, Height = true,
	Build = true, OnClose = true }

local warned = {}
local function warnOnce(key, message)
	if warned[key] then return end
	warned[key] = true
	warn("[Pulse.Overlay] " .. message)
end

local function checkKeys(component, allowed, patch)
	if type(patch) ~= "table" then error(component .. " expects a table of props", 3) end
	for key in pairs(patch) do
		if not allowed[key] then error(string.format("%s: unknown key '%s'", component, tostring(key)), 3) end
	end
end

local function layoutChanged(change)
	return type(change) ~= "table" or change.Layout ~= false
end

local function evenDown(value)
	local whole = math.floor(value)
	return whole - whole % 2
end

local function evenUp(value)
	local whole = math.ceil(value)
	return whole + whole % 2
end

-- A private scope with the Core.ConnectionScope shape. A component keeps everything it builds in one of these and
-- adds a single release function to the caller's scope, so Destroy can release without reaching into that scope.
-- Confirm has no scope argument (its signature is the Classic one), so this is also its only scope.
local function release(item)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then task.cancel(item) end
	elseif kind == "table" then
		local method = item.destroy or item.Destroy or item.Disconnect
		if method then method(item) end
	end
end

local function newScope()
	local items = {}
	local destroyed = false
	local scope = {}
	function scope.connect(_, signal, callback)
		assert(not destroyed, "Cannot bind a destroyed scope")
		local connection = signal:Connect(callback)
		table.insert(items, connection)
		return connection
	end
	function scope.add(_, item)
		assert(not destroyed, "Cannot add to a destroyed scope")
		assert(item ~= nil, "Cannot add nil to a scope")
		table.insert(items, item)
		return item
	end
	function scope.task(self, callback, ...)
		return self:add(task.spawn(callback, ...))
	end
	function scope.destroy(_)
		if destroyed then return end
		destroyed = true
		local held = items
		items = {}
		for index = #held, 1, -1 do
			local ok, err = pcall(release, held[index])
			if not ok then warnOnce("ScopeCleanup", "cleanup failed: " .. tostring(err)) end
		end
	end
	return scope
end

-- Places `child` (AnchorPoint 0,0) in the middle of `container` on whole pixels. Sizes are read as logical values:
-- when an ancestor carries a UIScale (the gallery stage only) the absolute sizes are divided by the observed ratio.
local function centre(child, container, fallback)
	local outer = container.AbsoluteSize
	local inner = child.AbsoluteSize
	local logicalWidth = child.Size.X.Offset
	local ratio = 1
	if logicalWidth > 0 and inner.X > 0 then
		ratio = inner.X / logicalWidth
		if math.abs(ratio - 1) < 0.02 then ratio = 1 end
	end
	local outerX, outerY = outer.X / ratio, outer.Y / ratio
	if outer.X < 1 or outer.Y < 1 then
		outerX, outerY = fallback.X, fallback.Y
	end
	local width = if logicalWidth > 0 then logicalWidth else inner.X / ratio
	local height = inner.Y / ratio
	child.Position = UDim2.fromOffset(
		math.max(0, math.floor((outerX - width) / 2)),
		math.max(0, math.floor((outerY - height) / 2))
	)
end

local function titleHeight(ctx)
	local textSize, holderScale = Text.SizeFor(TITLE_ROLE, ctx)
	return math.ceil(textSize * (holderScale or 1))
end

------------------------------------------------------------------------------------------------------------------------
-- Toast
------------------------------------------------------------------------------------------------------------------------

-- Pure. Text handling as the Classic controller: upper-cased tostring; nil and false become the empty string.
local function toastText(message)
	return string.upper(tostring(message or ""))
end

-- Pure. Duration clamp as the Classic controller.
local function toastDuration(duration)
	return math.clamp(tonumber(duration) or TOAST_DEFAULT_SECONDS, TOAST_MIN_SECONDS, TOAST_MAX_SECONDS)
end

-- Pure. `cards` is a list of {Showing: boolean, Text: string, Serial: number}. Returns the index to use and why:
-- "Duplicate" (a showing card already carries this text), "Free" (the least recently used idle card) or "Oldest"
-- (every card is showing; the one shown first is reused).
local function toastPick(cards, text)
	local free, oldest
	for index, card in ipairs(cards) do
		if card.Showing then
			if card.Text == text then return index, "Duplicate" end
			if not oldest or card.Serial < cards[oldest].Serial then oldest = index end
		elseif not free or card.Serial < cards[free].Serial then
			free = index
		end
	end
	if free then return free, "Free" end
	return oldest, "Oldest"
end

Overlay._toastText = toastText
Overlay._toastDuration = toastDuration
Overlay._toastPick = toastPick
-- The display timer's scheduler. Exposed so the pure tests can replace it with a recorder.
Overlay._toastDelay = task.delay

function Overlay.Toast(parent, props, scope)
	assert(typeof(parent) == "Instance" and parent:IsA("GuiObject"), "Toast requires a GuiObject parent")
	assert(type(scope) == "table", "Toast requires a scope")
	props = props or {}
	checkKeys("Toast", TOAST_KEYS, props)

	local ctx = Metrics.Of(parent)
	local own = newScope()
	local destroyed = false
	local state = {
		Name = props.Name or "Stack",
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
		MaxCards = props.MaxCards or Space.ToastMaxCards,
	}
	local panelTransparency = 1 - Tokens.Opacity.Panel
	local geometry = {}
	local cards = {}
	local serial = 0

	local root = Instance.new("Frame")
	root.Name = state.Name
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.LayoutOrder = state.LayoutOrder
	root.Visible = state.Visible

	local list = Instance.new("UIListLayout")
	list.Name = "Layout"
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = root

	-- Widths are kept even so a card centred in the stack lands on whole pixels.
	local function computeGeometry()
		local compact = ctx.Class == "Compact"
		local margin = ctx.Px(if compact then Space.CompactMargin else Space.HudMargin)
		local widest = ctx.Px(if compact then Space.CompactToastMaxWidth else Space.ToastMaxWidth)
		local maxWidth = math.max(2, evenDown(math.min(widest, ctx.Size.X - margin * 2)))
		local minWidth = evenUp(ctx.Px(if compact then Space.CompactTileMinWidth else Space.ButtonMainMinWidth))
		geometry.MaxWidth = maxWidth
		geometry.MinWidth = math.min(minWidth, maxWidth)
		geometry.PadX = ctx.Px(if compact then Space.CompactMargin else Space.Pad)
		geometry.PadY = ctx.Px(if compact then Space.TouchGap else Space.Gap)
		geometry.Edge = ctx.Px(Space.TabUnderline)
		geometry.MinHeight = ctx.Px(if compact then Space.CompactButtonDrawn else Space.ButtonHeight)
		geometry.TextSize = (Text.SizeFor(TOAST_ROLE, ctx))
		geometry.MaxText = math.max(1, maxWidth - geometry.Edge - geometry.PadX * 2)
	end

	local function styleCard(card)
		local inset = geometry.Edge + geometry.PadX
		card.Edge.Size = UDim2.new(0, geometry.Edge, 1, 0)
		card.Label.Position = UDim2.fromOffset(inset, 0)
		card.Label.Size = UDim2.new(1, -(inset + geometry.PadX), 1, 0)
		card.Label.TextSize = geometry.TextSize
		card.Label.FontFace = Text.Font(TOAST_ROLE)
	end

	local function applySize(card, textWidth, textHeight)
		local wanted = evenUp(math.ceil(textWidth) + geometry.Edge + geometry.PadX * 2)
		local width = math.clamp(wanted, geometry.MinWidth, geometry.MaxWidth)
		local height = math.max(geometry.MinHeight, math.ceil(textHeight) + geometry.PadY * 2)
		card.Width = width
		card.Height = height
		card.Frame.Size = UDim2.fromOffset(width, height)
	end

	-- The engine enlarges ordinary text under the player's Text Size setting, which Text.Measure cannot see. When the
	-- rendered bounds are taller than the card allows, the card grows (it never shrinks while it is showing).
	local function fit(card)
		if destroyed or not card.Showing or not card.Fitted then return end
		local label = card.Label
		if label.Text ~= card.Text then return end
		local needed = math.ceil(label.TextBounds.Y) + geometry.PadY * 2
		if needed > card.Height then
			card.Height = needed
			card.Frame.Size = UDim2.fromOffset(card.Width, needed)
		end
	end

	local function reveal(card)
		card.Frame.Visible = true
		for _, tween in ipairs(card.FadeIn) do tween:Play() end
	end

	local function hide(card)
		if destroyed then return end
		card.Showing = false
		for _, tween in ipairs(card.FadeOut) do tween:Play() end
	end

	-- A hidden card is not visible and carries no text. The pool keeps its cards (Classic destroyed them), and a
	-- search of PlayerGui by name and text must never match a card that is not on screen.
	local function conceal(card)
		card.Frame.Visible = false
		card.Label.Text = ""
	end

	-- Instantly clears a card that is about to carry a new message.
	local function blank(card)
		for _, tween in ipairs(card.FadeIn) do tween:Cancel() end
		for _, tween in ipairs(card.FadeOut) do tween:Cancel() end
		conceal(card)
		card.Frame.BackgroundTransparency = 1
		card.Edge.BackgroundTransparency = 1
		card.Label.TextTransparency = 1
	end

	local function startTimer(card, seconds)
		if card.Timer then task.cancel(card.Timer) end
		card.Timer = Overlay._toastDelay(seconds, function()
			card.Timer = nil
			hide(card)
		end)
	end

	-- Runs in its own thread: Text.Measure yields (for at most the ready limit; after it the bounds are an estimate and
	-- Text.ReadyChanged brings a relayout when the face arrives). `token` drops a result that a newer message or
	-- relayout replaced. The display timer starts here, when the card becomes visible, so a slow first measure cannot
	-- use up a toast's time; `card.Seconds` is set only while a message waits for its first reveal.
	local function measure(card, token)
		local ok, bounds = pcall(Text.Measure, card.Text, TOAST_ROLE, ctx, geometry.MaxText)
		if destroyed or card.Layout ~= token or not card.Showing then return end
		if not ok or typeof(bounds) ~= "Vector2" then
			warnOnce("ToastMeasure", "Text.Measure failed; toast drawn at full width: " .. tostring(bounds))
			bounds = Vector2.new(geometry.MaxText, geometry.TextSize)
		end
		applySize(card, bounds.X, bounds.Y)
		local label = card.Label
		local sameText = label.Text == card.Text
		label.Text = card.Text
		card.Fitted = true
		if sameText then fit(card) end
		reveal(card)
		if card.Seconds then
			local seconds = card.Seconds
			card.Seconds = nil
			startTimer(card, seconds)
		end
	end

	local function buildCard(index)
		local frame = Instance.new("Frame")
		frame.Name = "Card" .. index
		frame.BackgroundColor3 = Tokens.Colour.Slate
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Visible = false

		local edge = Instance.new("Frame")
		edge.Name = "Edge"
		edge.BackgroundColor3 = Tokens.Colour.White
		edge.BackgroundTransparency = 1
		edge.BorderSizePixel = 0
		edge.Parent = frame

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Text = ""
		label.TextColor3 = Tokens.Colour.White
		label.TextTransparency = 1
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Parent = frame

		local card = { Index = index, Frame = frame, Edge = edge, Label = label, Text = "", Showing = false,
			Fitted = false, Serial = 0, Layout = 0, Width = 0, Height = 0, Timer = nil, Seconds = nil }
		local info = TweenInfo.new(TOAST_FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		card.FadeIn = {
			TweenService:Create(frame, info, { BackgroundTransparency = panelTransparency }),
			TweenService:Create(edge, info, { BackgroundTransparency = 0 }),
			TweenService:Create(label, info, { TextTransparency = 0 }),
		}
		card.FadeOut = {
			TweenService:Create(frame, info, { BackgroundTransparency = 1 }),
			TweenService:Create(edge, info, { BackgroundTransparency = 1 }),
			TweenService:Create(label, info, { TextTransparency = 1 }),
		}
		card.Connections = {
			card.FadeOut[1].Completed:Connect(function(playbackState)
				if playbackState == Enum.PlaybackState.Completed and not card.Showing then conceal(card) end
			end),
			label:GetPropertyChangedSignal("TextBounds"):Connect(function()
				fit(card)
			end),
		}
		styleCard(card)
		frame.Parent = root
		return card
	end

	local function destroyCard(card)
		card.Showing = false
		card.Layout += 1
		if card.Timer then
			task.cancel(card.Timer)
			card.Timer = nil
		end
		for _, connection in ipairs(card.Connections) do connection:Disconnect() end
		for _, tween in ipairs(card.FadeIn) do
			tween:Cancel()
			tween:Destroy()
		end
		for _, tween in ipairs(card.FadeOut) do
			tween:Cancel()
			tween:Destroy()
		end
		card.Frame:Destroy()
	end

	local function resizePool()
		local wanted = math.max(1, math.floor(tonumber(state.MaxCards) or Space.ToastMaxCards))
		for index = #cards + 1, wanted do
			cards[index] = buildCard(index)
		end
		for index = #cards, wanted + 1, -1 do
			destroyCard(cards[index])
			cards[index] = nil
		end
	end

	-- In a slot (zero size) this is 0,0. Under a full-size parent it is the top centre.
	local function place()
		if destroyed then return end
		root.Position = UDim2.fromOffset(math.floor(parent.AbsoluteSize.X / 2), 0)
	end

	local function relayout()
		if destroyed then return end
		computeGeometry()
		root.Size = UDim2.fromOffset(geometry.MaxWidth, 0)
		list.Padding = UDim.new(0, ctx.Px(Space.ToastGap))
		place()
		for _, card in ipairs(cards) do
			styleCard(card)
			if card.Showing then
				card.Layout += 1
				task.spawn(measure, card, card.Layout)
			end
		end
	end

	local function show(message, duration)
		if destroyed then return end
		local text = toastText(message)
		if text == "" then return end
		local seconds = toastDuration(duration)
		local index, kind = toastPick(cards, text)
		local card = cards[index]
		if kind == "Duplicate" then
			-- Not yet visible: the latest duration is the one its timer starts with.
			if card.Seconds then card.Seconds = seconds else startTimer(card, seconds) end
			return
		end
		serial += 1
		blank(card)
		if card.Timer then
			task.cancel(card.Timer)
			card.Timer = nil
		end
		card.Serial = serial
		card.Text = text
		card.Showing = true
		card.Fitted = false
		card.Seconds = seconds
		card.Frame.LayoutOrder = serial
		card.Layout += 1
		task.spawn(measure, card, card.Layout)
	end

	local function count()
		local showing = 0
		for _, card in ipairs(cards) do
			if card.Showing then showing += 1 end
		end
		return showing
	end

	local apply = {
		Name = function(value) root.Name = value end,
		LayoutOrder = function(value) root.LayoutOrder = value end,
		Visible = function(value) root.Visible = value end,
		MaxCards = function() resizePool() end,
	}

	local function set(patch)
		checkKeys("Toast", TOAST_KEYS, patch)
		if destroyed then return end
		for key, value in pairs(patch) do
			if state[key] ~= value then
				state[key] = value
				apply[key](value)
			end
		end
	end

	local function destroy()
		if destroyed then return end
		destroyed = true
		for index = #cards, 1, -1 do
			destroyCard(cards[index])
			cards[index] = nil
		end
		own:destroy()
		root:Destroy()
	end

	computeGeometry()
	root.Size = UDim2.fromOffset(geometry.MaxWidth, 0)
	list.Padding = UDim.new(0, ctx.Px(Space.ToastGap))
	resizePool()
	place()
	root.Parent = parent

	if ctx.Changed then
		own:connect(ctx.Changed, function(change)
			if layoutChanged(change) then relayout() end
		end)
	end
	if Text.ReadyChanged then own:connect(Text.ReadyChanged, relayout) end
	own:connect(parent:GetPropertyChangedSignal("AbsoluteSize"), place)
	scope:add(destroy)

	return { Instance = root, Set = set, Destroy = destroy, Show = show, Count = count, Relayout = relayout }
end

------------------------------------------------------------------------------------------------------------------------
-- Confirm
------------------------------------------------------------------------------------------------------------------------

-- Open confirmations by their watched instance (the ScreenGui, or the shade when a Host is given).
local openConfirms = setmetatable({}, { __mode = "k" })
local confirmSerial = 0

local function titleMark(parent)
	local asset = Tokens.Asset("TitleMark")
	local mark
	if asset then
		mark = Instance.new("ImageLabel")
		mark.BackgroundTransparency = 1
		mark.Image = asset
		mark.ScaleType = Enum.ScaleType.Fit
	else
		mark = Instance.new("Frame")
		mark.BackgroundColor3 = Tokens.Colour.Pink
	end
	mark.Name = "Mark"
	mark.BorderSizePixel = 0
	mark.Parent = parent
	return mark
end

function Overlay.Confirm(root, options)
	options = options or {}
	assert(typeof(root) == "Instance" and root:IsA("GuiObject"), "Confirmation requires a GuiObject root")
	assert(type(options) == "table", "Confirmation options must be a table")
	local host = options.Host
	local playerGui
	if host ~= nil then
		assert(typeof(host) == "Instance" and host:IsA("GuiObject"), "Confirmation Host must be a GuiObject")
	else
		local sourceGui = root:FindFirstAncestorOfClass("ScreenGui")
		playerGui = sourceGui and sourceGui.Parent
		assert(playerGui and playerGui:IsA("PlayerGui"), "Confirmation root must belong to PlayerGui")
	end

	-- An existing confirmation is removed first. A Pulse one is cancelled (once, through its own close).
	local previous
	if host then
		previous = host:FindFirstChild(CONFIRM_SHADE_NAME)
	else
		previous = playerGui:FindFirstChild(CONFIRM_OVERLAY_NAME)
	end
	if previous then
		local closePrevious = openConfirms[previous]
		if closePrevious then
			local ok, err = pcall(closePrevious, false)
			if not ok then warnOnce("ConfirmReplace", "the replaced confirmation's cancel failed: " .. tostring(err)) end
		end
		if previous.Parent then previous:Destroy() end
	end

	local oldSelection = GuiService.SelectedObject
	local layer, container, ctx
	if host then
		container = host
		ctx = Metrics.Of(host)
	else
		layer = Layers.Create(CONFIRM_OVERLAY_NAME, { Frame = "Bare" })
		container = layer.Root
		ctx = layer.Metrics
	end

	local own = newScope()
	local closed = false
	local close
	confirmSerial += 1
	local exitAction = "Pulse_ConfirmExit_" .. confirmSerial

	local shade = Instance.new("Frame")
	shade.Name = CONFIRM_SHADE_NAME
	shade.Active = true
	shade.BackgroundTransparency = 1
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)

	local parts
	local built, buildError = xpcall(function()
		Surface.Scrim(shade, { Kind = "Confirm" }, own)

		local panel = Instance.new("Frame")
		panel.Name = "Panel"
		panel.Active = true
		panel.AutomaticSize = Enum.AutomaticSize.Y
		panel.BackgroundColor3 = Tokens.Colour.Slate
		panel.BackgroundTransparency = 1 - Tokens.Opacity.Panel
		panel.BorderSizePixel = 0
		panel.Parent = shade
		Surface.Hairline(panel, { Edge = "Top" }, own)
		Surface.Hairline(panel, { Edge = "Bottom" }, own)

		local content = Instance.new("Frame")
		content.Name = "Content"
		content.AutomaticSize = Enum.AutomaticSize.Y
		content.BackgroundTransparency = 1
		content.BorderSizePixel = 0
		content.Parent = panel

		local padding = Instance.new("UIPadding")
		padding.Name = "Padding"
		padding.Parent = content

		local list = Instance.new("UIListLayout")
		list.Name = "Layout"
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = Enum.HorizontalAlignment.Left
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = content

		local titleRow = Instance.new("Frame")
		titleRow.Name = "TitleRow"
		titleRow.BackgroundTransparency = 1
		titleRow.BorderSizePixel = 0
		titleRow.LayoutOrder = 1
		titleRow.Parent = content
		local mark = titleMark(titleRow)
		local title = Text.Label(titleRow, {
			Name = "Title",
			Text = options.Title or "CONFIRM",
			Role = TITLE_ROLE,
			Colour = "White",
			Align = "Left",
			MaxWidth = Space.ConfirmWidth - Space.Pad * 3 - Space.Gap,
		}, own)

		local body = Instance.new("TextLabel")
		body.Name = "Body"
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.BackgroundTransparency = 1
		body.BorderSizePixel = 0
		body.LayoutOrder = 2
		body.Text = options.Body or "Continue?"
		body.TextColor3 = Tokens.Colour.TextSecondary
		body.TextWrapped = true
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.Parent = content

		local buttons = Instance.new("Frame")
		buttons.Name = "Buttons"
		buttons.AutomaticSize = Enum.AutomaticSize.Y
		buttons.BackgroundTransparency = 1
		buttons.BorderSizePixel = 0
		buttons.LayoutOrder = 3
		buttons.Parent = content

		local buttonList = Instance.new("UIListLayout")
		buttonList.Name = "Layout"
		buttonList.FillDirection = Enum.FillDirection.Horizontal
		buttonList.HorizontalAlignment = Enum.HorizontalAlignment.Right
		buttonList.VerticalAlignment = Enum.VerticalAlignment.Center
		buttonList.SortOrder = Enum.SortOrder.LayoutOrder
		buttonList.Parent = buttons

		-- NO on the left, YES on the right.
		local buttonMinWidth = Space.ButtonHeight * 2
		local no = Controls.Button(buttons, {
			Name = "No",
			Variant = "Default",
			Text = options.CancelText or "NO",
			MinWidth = buttonMinWidth,
			LayoutOrder = 1,
			OnActivated = function() close(false) end,
		}, own)
		local yes = Controls.Button(buttons, {
			Name = "Yes",
			Variant = "Main",
			Text = options.ConfirmText or "YES",
			MinWidth = buttonMinWidth,
			LayoutOrder = 2,
			OnActivated = function() close(true) end,
		}, own)

		parts = { Panel = panel, Content = content, Padding = padding, List = list, TitleRow = titleRow, Mark = mark,
			Title = title.Instance, Body = body, Buttons = buttons, ButtonList = buttonList,
			No = no.Instance, Yes = yes.Instance }
	end, debug.traceback)
	if not built then
		own:destroy()
		shade:Destroy()
		if layer then pcall(layer.Destroy) end
		error(buildError, 0)
	end

	local noButton, yesButton = parts.No, parts.Yes
	noButton.Selectable = true
	yesButton.Selectable = true
	noButton.NextSelectionRight = yesButton
	yesButton.NextSelectionLeft = noButton

	local watched = if layer then layer.Gui else shade

	local function place()
		if closed then return end
		centre(parts.Panel, container, ctx.Size)
	end

	local function relayout()
		if closed then return end
		local compact = ctx.Class == "Compact"
		local pad = ctx.Px(Space.Pad)
		local gap = ctx.Px(Space.Gap)
		local margin = ctx.Px(if compact then Space.CompactMargin else Space.Pad)
		local width = math.max(1, math.min(ctx.Px(Space.ConfirmWidth), ctx.Size.X - margin * 2))
		local inner = math.max(1, width - pad * 2)
		local rowHeight = titleHeight(ctx)
		local markWidth = ctx.Px(Space.Pad)
		parts.Panel.Size = UDim2.fromOffset(width, 0)
		parts.Content.Size = UDim2.fromOffset(width, 0)
		parts.Padding.PaddingLeft = UDim.new(0, pad)
		parts.Padding.PaddingRight = UDim.new(0, pad)
		parts.Padding.PaddingTop = UDim.new(0, pad)
		parts.Padding.PaddingBottom = UDim.new(0, pad)
		parts.List.Padding = UDim.new(0, pad)
		parts.TitleRow.Size = UDim2.fromOffset(inner, rowHeight)
		parts.Mark.Size = UDim2.fromOffset(markWidth, rowHeight)
		parts.Title.Position = UDim2.fromOffset(markWidth + gap, 0)
		parts.Body.Size = UDim2.fromOffset(inner, 0)
		parts.Body.FontFace = Text.Font(BODY_ROLE)
		parts.Body.TextSize = (Text.SizeFor(BODY_ROLE, ctx))
		parts.Buttons.Size = UDim2.fromOffset(inner, 0)
		parts.ButtonList.Padding = UDim.new(0, gap)
		place()
	end

	-- `external` is true when someone else is already destroying the overlay (a Classic confirmation replacing it by
	-- name, or the gallery host going away): the instance is left to that destroy and the cancel still runs once.
	close = function(confirmed, external)
		if closed then return end
		closed = true
		openConfirms[watched] = nil
		ContextActionService:UnbindAction(exitAction)
		local selected = GuiService.SelectedObject
		if selected == noButton or selected == yesButton then
			local restored = pcall(function() GuiService.SelectedObject = oldSelection end)
			if not restored then GuiService.SelectedObject = nil end
		end
		own:destroy()
		if layer then
			if external then
				task.defer(function() pcall(layer.Destroy) end)
			else
				layer.Destroy()
			end
		elseif not external then
			shade:Destroy()
		end
		if confirmed then
			if options.OnConfirm then options.OnConfirm() end
		elseif options.OnCancel then
			options.OnCancel()
		end
	end

	relayout()
	shade.Parent = container
	place()
	openConfirms[watched] = close

	ContextActionService:BindActionAtPriority(exitAction, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then close(false) end
		return Enum.ContextActionResult.Sink
	end, false, CONFIRM_EXIT_PRIORITY, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)

	own:connect(watched.Destroying, function() close(false, true) end)
	own:connect(container:GetPropertyChangedSignal("AbsoluteSize"), place)
	own:connect(parts.Panel:GetPropertyChangedSignal("AbsoluteSize"), place)
	if ctx.Changed then
		own:connect(ctx.Changed, function(change)
			if layoutChanged(change) then relayout() end
		end)
	end
	if Text.ReadyChanged then own:connect(Text.ReadyChanged, relayout) end

	task.defer(function()
		if closed or not noButton.Parent or not noButton:IsDescendantOf(game) then return end
		local lastInput = UserInputService:GetLastInputType()
		if lastInput == Enum.UserInputType.Keyboard or string.find(lastInput.Name, "Gamepad", 1, true) then
			GuiService.SelectedObject = noButton
		end
	end)

	return {
		Root = watched,
		Cancel = function() close(false) end,
		Confirm = function() close(true) end,
		Relayout = relayout,
	}
end

------------------------------------------------------------------------------------------------------------------------
-- Modal
------------------------------------------------------------------------------------------------------------------------

function Overlay.Modal(parent, props, scope)
	assert(typeof(parent) == "Instance" and parent:IsA("GuiObject"), "Modal requires a GuiObject parent")
	assert(type(scope) == "table", "Modal requires a scope")
	props = props or {}
	checkKeys("Modal", MODAL_KEYS, props)
	assert(type(props.Width) == "number", "Modal requires a Width")

	local ctx = Metrics.Of(parent)
	local own = newScope()
	local destroyed = false
	local open = false
	local built
	local session
	local component = {}
	local state = {
		Name = props.Name or "Modal",
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
		Title = props.Title or "",
		Width = props.Width,
		Height = props.Height,
		Build = props.Build,
		OnClose = props.OnClose,
	}

	-- The only instance that exists before the first Open. Active, so a click on the dimmed scene goes nowhere.
	local root = Instance.new("Frame")
	root.Name = state.Name
	root.Active = true
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.LayoutOrder = state.LayoutOrder
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = parent

	local function place()
		if destroyed or not built then return end
		centre(built.Panel.Instance, root, ctx.Size)
	end

	local function relayout()
		if destroyed or not built then return end
		local rowHeight = titleHeight(ctx)
		local offset = rowHeight + ctx.Px(Space.Pad)
		built.TitleRow.Size = UDim2.new(1, 0, 0, rowHeight)
		built.Body.Position = UDim2.fromOffset(0, offset)
		if state.Height then
			built.Body.AutomaticSize = Enum.AutomaticSize.None
			built.Body.Size = UDim2.new(1, 0, 1, -offset)
		else
			built.Body.AutomaticSize = Enum.AutomaticSize.Y
			built.Body.Size = UDim2.new(1, 0, 0, 0)
		end
		place()
	end

	local function build()
		Surface.Scrim(root, { Kind = "Confirm" }, own)
		local panel = Surface.Panel(root, { Name = "Panel", Width = state.Width, Height = state.Height }, own)
		panel.Instance.AnchorPoint = Vector2.zero
		local holder = panel.Content

		local titleRow = Instance.new("Frame")
		titleRow.Name = "TitleRow"
		titleRow.BackgroundTransparency = 1
		titleRow.BorderSizePixel = 0
		titleRow.Parent = holder
		local title = Text.Label(titleRow, { Name = "Title", Text = state.Title, Role = TITLE_ROLE, Colour = "White",
			Align = "Left" }, own)

		local body = Instance.new("Frame")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.BorderSizePixel = 0
		body.Parent = holder

		built = { Panel = panel, TitleRow = titleRow, Title = title, Body = body }
		component.Content = body
		own:connect(panel.Instance:GetPropertyChangedSignal("AbsoluteSize"), place)
		relayout()
		if state.Build then state.Build(body, own) end
	end

	local function closeModal(silent)
		if not open then return end
		open = false
		root.Visible = false
		local current = session
		session = nil
		if current then
			current.Group.Leave()
			current.Scope:destroy()
		end
		if not silent and state.OnClose then state.OnClose() end
	end

	local function openModal()
		if destroyed or open then return end
		if not built then build() end
		open = true
		-- One scope per opening: the focus trap and the back binding are released at Close.
		local live = newScope()
		local group = Input.FocusGroup(live, { Trap = true })
		for _, item in ipairs(built.Body:GetDescendants()) do
			if item:IsA("GuiButton") and item.Selectable then group.Add(item) end
		end
		Input.BindBack(live, function() closeModal(false) end)
		session = { Scope = live, Group = group }
		root.Visible = state.Visible
		place()
		group.Enter(nil)
	end

	local apply = {
		Name = function(value) root.Name = value end,
		LayoutOrder = function(value) root.LayoutOrder = value end,
		Visible = function(value) root.Visible = open and value end,
		Title = function(value)
			if built then built.Title.Set({ Text = value }) end
		end,
		Width = function(value)
			if built then
				built.Panel.Set({ Width = value })
				relayout()
			end
		end,
		Height = function(value)
			if built then
				built.Panel.Set({ Height = value })
				relayout()
			end
		end,
		Build = function() end,
		OnClose = function() end,
	}

	local function set(patch)
		checkKeys("Modal", MODAL_KEYS, patch)
		if destroyed then return end
		for key, value in pairs(patch) do
			if state[key] ~= value then
				state[key] = value
				apply[key](value)
			end
		end
	end

	local function destroy()
		if destroyed then return end
		closeModal(true)
		destroyed = true
		component.Content = nil
		own:destroy()
		root:Destroy()
	end

	if ctx.Changed then
		own:connect(ctx.Changed, function(change)
			if layoutChanged(change) then relayout() end
		end)
	end
	own:connect(root:GetPropertyChangedSignal("AbsoluteSize"), place)
	scope:add(destroy)

	component.Instance = root
	component.Set = set
	component.Destroy = destroy
	component.Open = openModal
	component.Close = function() closeModal(false) end
	component.IsOpen = function() return open end
	return component
end

return Overlay
