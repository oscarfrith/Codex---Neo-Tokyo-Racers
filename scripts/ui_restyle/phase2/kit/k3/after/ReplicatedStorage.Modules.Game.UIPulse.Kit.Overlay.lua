-- Owns the Pulse toast stack, confirmation, modal, prompt banner and prompt stack components; not the toast bindable, the prompt watcher, the owner's start-up or what a caller does with a result.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.Overlay. Requires: Tokens, Metrics, Layers, Text, Surface, Input, Controls, Presence.
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
local Presence = require(script.Parent.Presence)

local Overlay = {}

local Space = Tokens.Space

-- Toast timing. The three duration values are the Classic controller's.
local TOAST_DEFAULT_SECONDS = 2.5
local TOAST_MIN_SECONDS = 0.5
local TOAST_MAX_SECONDS = 10
local TOAST_FADE_SECONDS = 0.12
local TOAST_ROLE = "Body"
-- Edge colour role per toast kind (API2 2.11).
local TOAST_EDGE = { Neutral = "White", Good = "Cyan", Bad = "Danger" }

-- Confirmation contract values (the Classic confirmation's).
local CONFIRM_OVERLAY_NAME = "SharedConfirmationOverlay"
local CONFIRM_SHADE_NAME = "SharedConfirmation"
local CONFIRM_EXIT_PRIORITY = 10000
local TITLE_ROLE = "SectionHead"
local BODY_ROLE = "Body"

local TOAST_KEYS = { Name = true, LayoutOrder = true, Visible = true, MaxCards = true }
local MODAL_KEYS = { Name = true, LayoutOrder = true, Visible = true, Title = true, Width = true, Height = true,
	Build = true, OnClose = true, Buttons = true, Scrim = true, Side = true, CloseButton = true }
local MODAL_SCRIMS = { Menu = true, Confirm = true, None = true }
local MODAL_SIDES = { Centre = true, Left = true, Right = true }

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

local function round(value)
	return math.floor(value + 0.5)
end

local function write(instance, property, value)
	if instance[property] ~= value then instance[property] = value end
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

-- The title mark is drawn as tall as the title line. Surface.TitleMark takes a design height; its design box is
-- TitleMarkWidth by TitleMarkHeight, which gives the room the title leaves for it.
local function markDesignHeight(ctx, rowHeight)
	return rowHeight / ctx.Scale
end

local function markWidth(rowHeight)
	return math.ceil(rowHeight * Space.TitleMarkWidth / Space.TitleMarkHeight)
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

-- Pure. A message is a string (anything tostring takes) or {Text, Icon, Kind}. Returns text, kind, icon name or nil.
-- An unknown kind is Neutral.
local function toastMessage(message)
	if type(message) ~= "table" then return toastText(message), "Neutral", nil end
	local kind = message.Kind
	if type(kind) ~= "string" or TOAST_EDGE[kind] == nil then kind = "Neutral" end
	local icon = message.Icon
	if type(icon) ~= "string" or icon == "" then icon = nil end
	return toastText(message.Text), kind, icon
end

Overlay._toastText = toastText
Overlay._toastMessage = toastMessage
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
	local fadeInfo = TweenInfo.new(TOAST_FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

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
		-- The icon is twice the role's cap height, in design units for Surface.Icon and in pixels for the layout.
		geometry.IconDesign = (if compact then Tokens.Cap.Compact else Tokens.Cap.Regular)[TOAST_ROLE] * 2
		geometry.Icon = ctx.Px(geometry.IconDesign)
		geometry.IconGap = ctx.Px(if compact then Space.TouchGap else Space.Gap)
	end

	-- Width a card's icon takes from its text; 0 for a card without one.
	local function iconWidth(card)
		return if card.HasIcon then geometry.Icon + geometry.IconGap else 0
	end

	local function placeIcon(card)
		if not card.Icon then return end
		card.Icon.Instance.Position = UDim2.fromOffset(geometry.Edge + geometry.PadX,
			math.max(0, math.floor((card.Height - geometry.Icon) / 2)))
	end

	local function styleCard(card)
		local inset = geometry.Edge + geometry.PadX + iconWidth(card)
		if card.Icon then card.Icon.Set({ Size = geometry.IconDesign }) end
		card.Edge.Size = UDim2.new(0, geometry.Edge, 1, 0)
		card.Label.Position = UDim2.fromOffset(inset, 0)
		card.Label.Size = UDim2.new(1, -(inset + geometry.PadX), 1, 0)
		card.Label.TextSize = geometry.TextSize
		card.Label.FontFace = Text.Font(TOAST_ROLE)
	end

	local function applySize(card, textWidth, textHeight)
		local wanted = evenUp(math.ceil(textWidth) + geometry.Edge + geometry.PadX * 2 + iconWidth(card))
		local width = math.clamp(wanted, geometry.MinWidth, geometry.MaxWidth)
		local height = math.max(geometry.MinHeight, math.ceil(textHeight) + geometry.PadY * 2)
		card.Width = width
		card.Height = height
		card.Frame.Size = UDim2.fromOffset(width, height)
		placeIcon(card)
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
			placeIcon(card)
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
		if card.Icon then card.Icon.Instance.ImageTransparency = 1 end
	end

	local function setKind(card, kind)
		if card.Kind == kind then return end
		card.Kind = kind
		card.Edge.BackgroundColor3 = Tokens.Colour[TOAST_EDGE[kind]]
	end

	-- A card gets its icon the first time a message asks for one (so a pool of plain toasts stays at three
	-- instances a card); afterwards the icon is kept and hidden for messages without one.
	local function setIcon(card, icon)
		if icon then
			local ok, result
			if card.Icon then
				ok, result = pcall(card.Icon.Set, { Icon = icon })
			else
				ok, result = pcall(Surface.Icon, card.Frame, { Name = "Icon", Icon = icon, Colour = "White",
					Size = geometry.IconDesign }, own)
				if ok then
					card.Icon = result
					result.Instance.ImageTransparency = 1
					table.insert(card.FadeIn, TweenService:Create(result.Instance, fadeInfo, { ImageTransparency = 0 }))
					table.insert(card.FadeOut, TweenService:Create(result.Instance, fadeInfo, { ImageTransparency = 1 }))
				end
			end
			if not ok then
				warnOnce("ToastIcon:" .. icon, "toast icon '" .. icon .. "' not drawn: " .. tostring(result))
				icon = nil
			end
		end
		card.HasIcon = icon ~= nil
		if card.Icon then card.Icon.Instance.Visible = card.HasIcon end
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
		local maxText = math.max(1, geometry.MaxText - iconWidth(card))
		local ok, bounds = pcall(Text.Measure, card.Text, TOAST_ROLE, ctx, maxText)
		if destroyed or card.Layout ~= token or not card.Showing then return end
		if not ok or typeof(bounds) ~= "Vector2" then
			warnOnce("ToastMeasure", "Text.Measure failed; toast drawn at full width: " .. tostring(bounds))
			bounds = Vector2.new(maxText, geometry.TextSize)
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
			Fitted = false, Serial = 0, Layout = 0, Width = 0, Height = 0, Timer = nil, Seconds = nil,
			Kind = "Neutral", Icon = nil, HasIcon = false }
		local info = fadeInfo
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
		if card.Icon then card.Icon.Destroy() end
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
		local text, kind, icon = toastMessage(message)
		if text == "" then return end
		local seconds = toastDuration(duration)
		local index, pick = toastPick(cards, text)
		local card = cards[index]
		if pick == "Duplicate" then
			setKind(card, kind)
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
		setKind(card, kind)
		setIcon(card, icon)
		styleCard(card)
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
		local mark = Surface.TitleMark(titleRow, { Name = "Mark" }, own)
		local title = Text.Label(titleRow, {
			Name = "Title",
			Text = options.Title or "CONFIRM",
			Role = TITLE_ROLE,
			Colour = "White",
			Align = "Left",
			-- The mark is never wider than it is tall.
			MaxWidth = Space.ConfirmWidth - Space.Pad * 2 - Space.TitleMarkHeight - Space.Gap,
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
		parts.Panel.Size = UDim2.fromOffset(width, 0)
		parts.Content.Size = UDim2.fromOffset(width, 0)
		parts.Padding.PaddingLeft = UDim.new(0, pad)
		parts.Padding.PaddingRight = UDim.new(0, pad)
		parts.Padding.PaddingTop = UDim.new(0, pad)
		parts.Padding.PaddingBottom = UDim.new(0, pad)
		parts.List.Padding = UDim.new(0, pad)
		parts.TitleRow.Size = UDim2.fromOffset(inner, rowHeight)
		parts.Mark.Set({ Height = markDesignHeight(ctx, rowHeight) })
		parts.Title.Position = UDim2.fromOffset(markWidth(rowHeight) + gap, 0)
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

-- Height of the footer button row: the Compact hit box, else the menu row.
local function footerHeight(ctx)
	if ctx.Class == "Compact" then return ctx.Touch(Space.CompactButtonDrawn) end
	return ctx.Px(Space.ButtonHeight)
end

-- Buttons is a ButtonRow props table ({Buttons = {...}}); a bare list of buttons is accepted too.
local function footerButtons(spec)
	if type(spec) ~= "table" then return nil end
	if spec[1] ~= nil then return spec end
	return spec.Buttons
end

function Overlay.Modal(parent, props, scope)
	assert(typeof(parent) == "Instance" and parent:IsA("GuiObject"), "Modal requires a GuiObject parent")
	assert(type(scope) == "table", "Modal requires a scope")
	props = props or {}
	checkKeys("Modal", MODAL_KEYS, props)
	local side = props.Side or "Centre"
	assert(MODAL_SIDES[side], "Modal: unknown Side " .. tostring(side))
	local sidePanel = side ~= "Centre"
	-- A side panel fills its slot (SidePanel); only the centred form needs a width.
	assert(sidePanel or type(props.Width) == "number", "Modal requires a Width")
	local scrimKind = props.Scrim or (if sidePanel then "None" else "Confirm")
	assert(MODAL_SCRIMS[scrimKind], "Modal: unknown Scrim " .. tostring(scrimKind))

	local ctx = Metrics.Of(parent)
	local own = newScope()
	local destroyed = false
	local open = false
	local built
	local session
	local component = {}
	local closeModal
	local state = {
		Name = props.Name or "Modal",
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
		Title = props.Title or "",
		Width = props.Width,
		Height = props.Height,
		Build = props.Build,
		OnClose = props.OnClose,
		Buttons = props.Buttons,
		Scrim = scrimKind,
		Side = side,
		CloseButton = props.CloseButton == true,
	}

	-- The only instance that exists before the first Open. Active, so a click on the dimmed scene (or through the
	-- side panel) goes nowhere; a centred modal without a scrim leaves the scene clickable.
	local root = Instance.new("Frame")
	root.Name = state.Name
	root.Active = sidePanel or scrimKind ~= "None"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.LayoutOrder = state.LayoutOrder
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = parent

	local function place()
		if destroyed or not built or sidePanel then return end
		centre(built.Panel.Instance, root, ctx.Size)
	end

	local function relayout()
		if destroyed or not built then return end
		local pad = ctx.Px(Space.Pad)
		local rowHeight = titleHeight(ctx)
		local left, top = 0, 0
		if sidePanel and ctx.Class ~= "Compact" then
			-- The Regular side panel runs from the screen corner (API2 2.4): its content clears the margin and the
			-- top bar. The Compact slot is already inset.
			left = math.max(0, ctx.Px(Space.HudMargin) - pad)
			top = math.max(0, math.max(0, round(ctx.TopBarHeight - ctx.Origin.Y)) + Space.TopBarGap - pad)
		end
		local footer = if built.Footer then footerHeight(ctx) + pad else 0
		local offset = top + rowHeight + pad
		built.Mark.Set({ Height = markDesignHeight(ctx, rowHeight) })
		built.TitleRow.Position = UDim2.fromOffset(left, top)
		built.TitleRow.Size = UDim2.new(1, -left, 0, rowHeight)
		built.Title.Instance.Position = UDim2.fromOffset(markWidth(rowHeight) + ctx.Px(Space.Gap), 0)
		built.Body.Position = UDim2.fromOffset(left, offset)
		if state.Height or sidePanel then
			built.Body.AutomaticSize = Enum.AutomaticSize.None
			built.Body.Size = UDim2.new(1, -left, 1, -(offset + footer))
		else
			built.Body.AutomaticSize = Enum.AutomaticSize.Y
			built.Body.Size = UDim2.new(1, -left, 0, 0)
		end
		place()
	end

	local function buildClose()
		local close = Controls.IconButton(built.TitleRow, { Name = "CloseButton", Icon = "close", Size = "Small",
			OnActivated = function() closeModal(false) end }, own)
		close.Instance.AnchorPoint = Vector2.new(1, 0)
		close.Instance.Position = UDim2.new(1, 0, 0, 0)
		close.Instance.ZIndex = 2
		built.Close = close
	end

	-- The footer row sits on the bottom-right of the panel content; the body ends above it.
	local function applyFooter()
		if not built then return end
		local buttons = footerButtons(state.Buttons)
		if not buttons then
			if built.Footer then
				built.Footer.Destroy()
				built.Footer = nil
			end
			return
		end
		if built.Footer then
			built.Footer.Set({ Buttons = buttons })
			return
		end
		local footer = Controls.ButtonRow(built.Panel.Content, { Name = "Footer", Buttons = buttons, Align = "Right",
			Place = "None" }, own)
		footer.Instance.AnchorPoint = Vector2.new(1, 1)
		footer.Instance.Position = UDim2.new(1, 0, 1, 0)
		built.Footer = footer
	end

	local function build()
		if state.Scrim ~= "None" then Surface.Scrim(root, { Kind = state.Scrim }, own) end
		local panelProps = { Name = "Panel" }
		if not sidePanel then
			panelProps.Width = state.Width
			panelProps.Height = state.Height
		end
		local panel = Surface.Panel(root, panelProps, own)
		panel.Instance.AnchorPoint = Vector2.zero
		local holder = panel.Content

		local titleRow = Instance.new("Frame")
		titleRow.Name = "TitleRow"
		titleRow.BackgroundTransparency = 1
		titleRow.BorderSizePixel = 0
		titleRow.Parent = holder
		local mark = Surface.TitleMark(titleRow, { Name = "Mark" }, own)
		local title = Text.Label(titleRow, { Name = "Title", Text = state.Title, Role = TITLE_ROLE, Colour = "White",
			Align = "Left" }, own)

		local body = Instance.new("Frame")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.BorderSizePixel = 0
		body.Parent = holder

		built = { Panel = panel, TitleRow = titleRow, Mark = mark, Title = title, Body = body }
		component.Content = body
		if state.CloseButton then buildClose() end
		applyFooter()
		own:connect(panel.Instance:GetPropertyChangedSignal("AbsoluteSize"), place)
		relayout()
		if state.Build then state.Build(body, own) end
	end

	closeModal = function(silent)
		if not open then return end
		open = false
		root.Visible = false
		local current = session
		session = nil
		if current then
			current.Group.Leave()
			current.Scope:destroy()
			current.Release()
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
		for _, item in ipairs(built.Panel.Instance:GetDescendants()) do
			if item:IsA("GuiButton") and item.Selectable then group.Add(item) end
		end
		Input.BindBack(live, function() closeModal(false) end)
		-- Other Pulse owners see the modal through Presence while it is open (API2 3.9).
		local release = Presence.Open(state.Name, if sidePanel then "SidePanel" else "Modal")
		session = { Scope = live, Group = group, Release = release }
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
			if built and not sidePanel then
				built.Panel.Set({ Width = value })
				relayout()
			end
		end,
		Height = function(value)
			if built and not sidePanel then
				built.Panel.Set({ Height = value })
				relayout()
			end
		end,
		Build = function() end,
		OnClose = function() end,
		Buttons = function()
			if built then
				applyFooter()
				relayout()
			end
		end,
		CloseButton = function(value)
			if not built then return end
			if value == true and not built.Close then buildClose() end
			if built.Close then built.Close.Set({ Visible = value == true }) end
		end,
	}

	local function set(patch)
		checkKeys("Modal", MODAL_KEYS, patch)
		-- Scrim and Side shape the build and the slot the modal sits in; they are fixed at construction.
		if patch.Side ~= nil and patch.Side ~= state.Side then error("Modal: Side cannot change after construction", 2) end
		if patch.Scrim ~= nil and patch.Scrim ~= state.Scrim then error("Modal: Scrim cannot change after construction", 2) end
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

------------------------------------------------------------------------------------------------------------------------
-- PromptBanner
------------------------------------------------------------------------------------------------------------------------

local PROMPT_KEYS = { Name = true, LayoutOrder = true, Visible = true, Action = true, Object = true, Key = true,
	PadKey = true, Main = true, Hold = true, OnPress = true, OnRelease = true }
local PROMPT_ACTION_ROLE = "ButtonMain"
local PROMPT_OBJECT_ROLE = "Label"
-- Gamepad key name to icon-sheet glyph.
local PAD_GLYPHS = { ButtonA = "pad_a", ButtonB = "pad_b", ButtonX = "pad_x", ButtonY = "pad_y", ButtonL1 = "pad_lb",
	ButtonR1 = "pad_rb", ButtonL2 = "pad_lt", ButtonR2 = "pad_rt", ButtonSelect = "pad_select",
	ButtonStart = "pad_start", DPadUp = "dpad", DPadDown = "dpad", DPadLeft = "dpad", DPadRight = "dpad" }
local PAD_UNKNOWN = "keycap_blank"
-- Keyboard key names that are not their own cap text. Anything else: a one-letter name as it is, else three letters.
local KEY_TEXT = { Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7",
	Eight = "8", Nine = "9", Space = "SPC", Return = "ENT", LeftShift = "SHF", RightShift = "SHF",
	LeftControl = "CTL", RightControl = "CTL", Backspace = "BKS", Escape = "ESC" }

-- Pure. What the right-hand cell shows for an input class: "Key" and the cap text, "Pad" and the glyph name, or
-- "None" (touch, or no key given for that input).
local function promptCap(input, key, padKey)
	if input == "Touch" then return "None", nil end
	if input == "Gamepad" then
		if typeof(padKey) ~= "EnumItem" then return "None", nil end
		return "Pad", PAD_GLYPHS[padKey.Name] or PAD_UNKNOWN
	end
	if typeof(key) ~= "EnumItem" then return "None", nil end
	local name = key.Name
	local text = KEY_TEXT[name]
	if not text then text = if #name == 1 then name else string.upper(string.sub(name, 1, 3)) end
	return "Key", text
end

-- Pure. Banner width and height in pixels. Regular: PromptWidth by ButtonHeight, or PromptHeight for a Main banner
-- (previews r16a, r16b). Compact: CompactPromptWidth by the touch hit box. ctx.Touch keeps a touch banner at 48 dp
-- or more.
local function promptSize(ctx, main)
	local compact = ctx.Class == "Compact"
	local margin = ctx.Px(if compact then Space.CompactMargin else Space.HudMargin)
	local widest = ctx.Px(if compact then Space.CompactPromptWidth else Space.PromptWidth)
	local width = math.max(2, evenDown(math.min(widest, ctx.Size.X - margin * 2)))
	local height
	if compact then
		height = ctx.Touch(Space.CompactButtonDrawn)
		if main then height += ctx.Px(Space.TouchGap) end
	else
		height = ctx.Touch(if main then Space.PromptHeight else Space.ButtonHeight)
	end
	return width, height
end

Overlay._promptCap = promptCap
Overlay._promptSize = promptSize

function Overlay.PromptBanner(parent, props, scope)
	assert(typeof(parent) == "Instance" and parent:IsA("GuiObject"), "PromptBanner requires a GuiObject parent")
	assert(type(scope) == "table", "PromptBanner requires a scope")
	props = props or {}
	checkKeys("PromptBanner", PROMPT_KEYS, props)

	local ctx = Metrics.Of(parent)
	local own = newScope()
	local destroyed = false
	-- An optional value that is not set is held as false, so a patch can clear it.
	local state = {
		Name = props.Name or "PromptBanner",
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
		Action = props.Action or "",
		Object = props.Object or "",
		Key = props.Key or false,
		PadKey = props.PadKey or false,
		Main = props.Main == true,
		Hold = props.Hold == true,
		OnPress = props.OnPress or false,
		OnRelease = props.OnRelease or false,
	}
	local size = { Width = 0, Height = 0, Pad = 0, Gap = 0, Cap = 0 }
	local cap, capKind, capValue = nil, "None", nil
	local progress = 0
	local pressed = false
	local pressConnection

	-- Always a TextButton, because the input class changes live and a class cannot; it is Active only on touch.
	local root = Instance.new("TextButton")
	root.Name = state.Name
	root.Active = false
	root.AutoButtonColor = false
	root.BorderSizePixel = 0
	root.LayoutOrder = state.LayoutOrder
	root.Selectable = false
	root.Text = ""
	root.Visible = state.Visible

	local hairTop = Surface.Hairline(root, { Name = "HairTop", Edge = "Top" }, own)
	local hairBottom = Surface.Hairline(root, { Name = "HairBottom", Edge = "Bottom" }, own)

	local action = Text.RawLabel(root, PROMPT_ACTION_ROLE, ctx)
	action.Name = "Action"
	action.AutomaticSize = Enum.AutomaticSize.X
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextYAlignment = Enum.TextYAlignment.Center
	action.ZIndex = 2

	local object = Text.RawLabel(root, PROMPT_OBJECT_ROLE, ctx)
	object.Name = "Object"
	object.TextTruncate = Enum.TextTruncate.AtEnd
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextYAlignment = Enum.TextYAlignment.Center
	object.ZIndex = 2

	local bar = Instance.new("Frame")
	bar.Name = "Progress"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.BackgroundColor3 = Tokens.Colour.Cyan
	bar.BorderSizePixel = 0
	bar.Position = UDim2.new(0, 0, 1, 0)
	bar.Visible = false
	bar.ZIndex = 3
	bar.Parent = root

	local function endPress()
		if not pressed then return end
		pressed = false
		if pressConnection then
			pressConnection:Disconnect()
			pressConnection = nil
		end
		local callback = state.OnRelease
		if callback then callback() end
	end

	-- Returns true when the press was taken. Only a touch banner that is showing can be pressed.
	local function beginPress()
		if destroyed or pressed or ctx.Input ~= "Touch" or not state.Visible then return false end
		pressed = true
		local callback = state.OnPress
		if callback then callback() end
		return true
	end

	-- Action and object sit side by side: from the left pad (key or pad input), or centred as a pair (touch). The
	-- action's width is read back; an ancestor UIScale (the gallery stage only) is divided out.
	local function placeText()
		if destroyed then return end
		local ratio = 1
		local drawn = root.AbsoluteSize.Y
		if size.Height > 0 and drawn > 0 then
			ratio = drawn / size.Height
			if math.abs(ratio - 1) < 0.02 then ratio = 1 end
		end
		local actionWidth = math.ceil(action.AbsoluteSize.X / ratio)
		local hasObject = state.Object ~= ""
		if ctx.Input == "Touch" then
			local objectWidth = if hasObject then math.ceil(object.AbsoluteSize.X / ratio) else 0
			local total = actionWidth + (if hasObject then size.Gap + objectWidth else 0)
			local x = math.max(size.Pad, math.floor((size.Width - total) / 2))
			write(action, "Position", UDim2.fromOffset(x, 0))
			write(object, "Position", UDim2.fromOffset(x + actionWidth + size.Gap, 0))
		else
			local x = size.Pad + actionWidth + size.Gap
			local right = size.Pad + (if cap then size.Cap + size.Gap else 0)
			write(action, "Position", UDim2.fromOffset(size.Pad, 0))
			write(object, "Position", UDim2.fromOffset(x, 0))
			write(object, "Size", UDim2.fromOffset(math.max(0, size.Width - x - right), size.Height))
		end
	end

	-- The cap is rebuilt only when what it shows changes (an input switch or a new key), never per frame.
	local function renderCap()
		local kind, value = promptCap(ctx.Input, state.Key, state.PadKey)
		if kind ~= capKind or value ~= capValue then
			capKind, capValue = kind, value
			if cap then
				cap.Destroy()
				cap = nil
			end
			if kind == "Key" then
				cap = Surface.KeyCap(root, { Name = "KeyCap", Text = value, Size = Space.KeyCapSize }, own)
			elseif kind == "Pad" then
				cap = Surface.KeyCap(root, { Name = "KeyCap", Icon = value, Size = Space.KeyCapSize }, own)
			end
			if cap then cap.Instance.ZIndex = 2 end
		end
		if cap then
			write(cap.Instance, "Position", UDim2.fromOffset(size.Width - size.Pad - size.Cap,
				math.max(0, math.floor((size.Height - size.Cap) / 2))))
		end
	end

	local function renderProgress()
		local width = if state.Hold then math.floor(size.Width * progress + 0.5) else 0
		write(bar, "Size", UDim2.fromOffset(width, ctx.Px(Space.TabUnderline)))
		write(bar, "Visible", width > 0)
	end

	local function render()
		if destroyed then return end
		local compact = ctx.Class == "Compact"
		local touch = ctx.Input == "Touch"
		local width, height = promptSize(ctx, state.Main)
		size.Width, size.Height = width, height
		size.Pad = ctx.Px(if compact then Space.CompactMargin else Space.Pad)
		size.Gap = ctx.Px(if compact then Space.TouchGap else Space.Gap)
		size.Cap = ctx.Px(Space.KeyCapSize)

		-- Key or pad: a slate strip with hairlines. Touch: the whole banner is the button, White with Ink text.
		write(root, "Size", UDim2.fromOffset(width, height))
		write(root, "Active", touch)
		write(root, "BackgroundColor3", if touch then Tokens.Colour.White else Tokens.Colour.Slate)
		write(root, "BackgroundTransparency", if touch then 0 else 1 - Tokens.Opacity.Panel)
		hairTop.Set({ Visible = not touch })
		hairBottom.Set({ Visible = not touch })

		write(action, "FontFace", Text.Font(PROMPT_ACTION_ROLE))
		write(action, "TextSize", (Text.SizeFor(PROMPT_ACTION_ROLE, ctx)))
		write(action, "Text", string.upper(state.Action))
		write(action, "TextColor3", if touch then Tokens.Colour.Ink else Tokens.Colour.White)
		write(action, "Size", UDim2.fromOffset(0, height))

		write(object, "FontFace", Text.Font(PROMPT_OBJECT_ROLE))
		write(object, "TextSize", (Text.SizeFor(PROMPT_OBJECT_ROLE, ctx)))
		write(object, "Text", string.upper(state.Object))
		write(object, "TextColor3", if touch then Tokens.Colour.Ink else Tokens.Colour.TextSecondary)
		write(object, "Visible", state.Object ~= "")
		write(object, "AutomaticSize", if touch then Enum.AutomaticSize.X else Enum.AutomaticSize.None)
		if touch then write(object, "Size", UDim2.fromOffset(0, height)) end

		renderCap()
		renderProgress()
		placeText()
		if not touch then endPress() end
	end

	local function setProgress(fraction)
		if destroyed then return end
		if type(fraction) ~= "number" or fraction ~= fraction then fraction = 0 end
		progress = math.clamp(fraction, 0, 1)
		renderProgress()
	end

	local function set(patch)
		checkKeys("PromptBanner", PROMPT_KEYS, patch)
		if destroyed then return end
		local changed = false
		for key, value in pairs(patch) do
			if state[key] ~= value then
				state[key] = value
				changed = true
			end
		end
		if not changed then return end
		write(root, "Name", state.Name)
		write(root, "LayoutOrder", state.LayoutOrder)
		write(root, "Visible", state.Visible)
		if not state.Visible then endPress() end
		render()
	end

	-- A banner that goes away while held releases first, so a hold never sticks.
	local function destroy()
		if destroyed then return end
		endPress()
		destroyed = true
		if cap then cap.Destroy() end
		own:destroy()
		root:Destroy()
	end

	render()
	root.Parent = parent

	own:connect(root.InputBegan, function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then return end
		if not beginPress() then return end
		-- The release is taken from the input itself, so lifting the finger off the banner still ends the hold.
		pressConnection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			local inputState = input.UserInputState
			if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then endPress() end
		end)
	end)
	own:connect(root.InputEnded, function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then endPress() end
	end)
	own:connect(action:GetPropertyChangedSignal("AbsoluteSize"), placeText)
	own:connect(object:GetPropertyChangedSignal("AbsoluteSize"), placeText)
	own:connect(root:GetPropertyChangedSignal("AbsoluteSize"), placeText)
	-- Every change, input included: the cap follows ctx.Input live.
	if ctx.Changed then own:connect(ctx.Changed, render) end
	if Text.ReadyChanged then own:connect(Text.ReadyChanged, render) end
	scope:add(destroy)

	return {
		Instance = root,
		Set = set,
		Destroy = destroy,
		SetProgress = setProgress,
		-- Test and gallery seams: what a finger down and a finger up do.
		_press = beginPress,
		_release = endPress,
	}
end

------------------------------------------------------------------------------------------------------------------------
-- PromptStack
------------------------------------------------------------------------------------------------------------------------

local STACK_KEYS = { Name = true, LayoutOrder = true, Visible = true }
local STACK_SHOW_KEYS = { Action = true, Object = true, Key = true, PadKey = true, Main = true, Hold = true,
	OnPress = true, OnRelease = true }
local STACK_MAX_SHOWN = 3

-- Pure. `order` lists the active ids, oldest first. Returns the set of ids shown: the newest `max`.
local function promptShown(order, max)
	local shown = {}
	for index = math.max(1, #order - max + 1), #order do
		shown[order[index]] = true
	end
	return shown
end

-- Pure. The full banner patch for one Show, so a value left out returns to its default.
local function promptPatch(props)
	return {
		Action = props.Action or "",
		Object = props.Object or "",
		Key = props.Key or false,
		PadKey = props.PadKey or false,
		Main = props.Main == true,
		Hold = props.Hold == true,
		OnPress = props.OnPress or false,
		OnRelease = props.OnRelease or false,
	}
end

Overlay._promptShown = promptShown
Overlay._promptPatch = promptPatch

function Overlay.PromptStack(parent, props, scope)
	assert(typeof(parent) == "Instance" and parent:IsA("GuiObject"), "PromptStack requires a GuiObject parent")
	assert(type(scope) == "table", "PromptStack requires a scope")
	props = props or {}
	checkKeys("PromptStack", STACK_KEYS, props)

	local ctx = Metrics.Of(parent)
	local own = newScope()
	local destroyed = false
	local state = {
		Name = props.Name or "PromptStack",
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
	}
	local active = {} -- id -> banner
	local order = {} -- active ids, oldest first
	local free = {} -- idle banners, kept for reuse
	local pool = {} -- every banner built
	local serial = 0

	-- On the slot's anchor (bottom centre); the list grows upward, newest at the bottom.
	local root = Instance.new("Frame")
	root.Name = state.Name
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.LayoutOrder = state.LayoutOrder
	root.Visible = state.Visible

	local list = Instance.new("UIListLayout")
	list.Name = "Layout"
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = root

	local function relayout()
		if destroyed then return end
		local width = promptSize(ctx, false)
		write(root, "Size", UDim2.fromOffset(width, 0))
		write(list, "Padding", UDim.new(0, ctx.Px(if ctx.Class == "Compact" then Space.TouchGap else Space.Gap)))
	end

	local function refresh()
		local shown = promptShown(order, STACK_MAX_SHOWN)
		for id, banner in pairs(active) do
			banner.Set({ Visible = shown[id] == true })
		end
	end

	local function show(id, bannerProps)
		assert(type(id) == "string" and id ~= "", "PromptStack.Show requires an id")
		bannerProps = bannerProps or {}
		checkKeys("PromptStack.Show", STACK_SHOW_KEYS, bannerProps)
		if destroyed then return nil end
		local patch = promptPatch(bannerProps)
		local banner = active[id]
		if banner then
			banner.Set(patch)
			return banner
		end
		serial += 1
		patch.LayoutOrder = serial
		banner = table.remove(free)
		if banner then
			banner.Set(patch)
			banner.SetProgress(0)
		else
			patch.Name = "Banner" .. (#pool + 1)
			patch.Visible = false
			banner = Overlay.PromptBanner(root, patch, own)
			table.insert(pool, banner)
		end
		active[id] = banner
		table.insert(order, id)
		refresh()
		return banner
	end

	local function hide(id)
		local banner = active[id]
		if not banner then return end
		active[id] = nil
		local index = table.find(order, id)
		if index then table.remove(order, index) end
		-- Hidden first, so a held banner still calls its OnRelease; then the callbacks are dropped.
		banner.Set({ Visible = false })
		banner.Set({ OnPress = false, OnRelease = false })
		table.insert(free, banner)
		refresh()
	end

	local function count()
		return math.min(#order, STACK_MAX_SHOWN)
	end

	local apply = {
		Name = function(value) root.Name = value end,
		LayoutOrder = function(value) root.LayoutOrder = value end,
		Visible = function(value) root.Visible = value end,
	}

	local function set(patch)
		checkKeys("PromptStack", STACK_KEYS, patch)
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
		for index = #pool, 1, -1 do
			pool[index].Destroy()
			pool[index] = nil
		end
		table.clear(active)
		table.clear(order)
		table.clear(free)
		own:destroy()
		root:Destroy()
	end

	relayout()
	root.Parent = parent

	if ctx.Changed then
		own:connect(ctx.Changed, function(change)
			if layoutChanged(change) then relayout() end
		end)
	end
	scope:add(destroy)

	return { Instance = root, Set = set, Destroy = destroy, Show = show, Hide = hide, Count = count }
end

return Overlay
