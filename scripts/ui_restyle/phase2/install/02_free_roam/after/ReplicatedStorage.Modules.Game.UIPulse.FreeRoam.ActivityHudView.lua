-- Owns the drawing of the activity HUD (job strip, offer card, countdown, rank-up card) and the kit-backed Button and Label handed to the shared activity views; not the activity state, the remote, the bindables, the world beacons or the design-pixel root, which belong to ActivityHudClient.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.ActivityHudView. Requires: Tokens, Text, Surface, Controls, Collections, BigNumber, Data, Perf.
local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Text = require(Kit.Text)
local Surface = require(Kit.Surface)
local Controls = require(Kit.Controls)
local Collections = require(Kit.Collections)
local BigNumber = require(Kit.BigNumber)
local Data = require(Kit.Data)
local Perf = require(Kit.Perf)

local Space = Tokens.Space
local Colour = Tokens.Colour
local Opacity = Tokens.Opacity

local View = {}

local OFFER_BODY_LINES = 3 -- lines of body text the offer card reserves (Classic: 50 px at TextSize 12)
local COUNTDOWN_CELLS = 2
local COUNTDOWN_MAX = 99
local GO_SECONDS = 0.9 -- Classic ActivityClient 207: "GO!" stays for 0.9 s after zero

-- Pure helpers ---------------------------------------------------------------------------------------------

-- The shared views pass meaning as theme colours (the activity theme is a named exception, PC 2.3). The kit takes
-- roles, so a colour is mapped back by value. Unknown or nil gives `default`.
function View._roleOf(theme, colour, default)
	if typeof(colour) == "Color3" then
		if colour == theme.HighSpeed then
			return "Pink"
		elseif colour == theme.Telemetry then
			return "Cyan"
		elseif colour == theme.ElectricBlue then
			return "Violet"
		end
	end
	return default
end

-- Offer buttons: Telemetry accent = the confirming action (main button); HighSpeed accent = a cash stake (Buy).
function View._variantOf(theme, accent)
	if typeof(accent) == "Color3" then
		if accent == theme.Telemetry then
			return "Main"
		elseif accent == theme.HighSpeed then
			return "Buy"
		end
	end
	return "Default"
end

-- Row order for the kit: every button in the order given, except that main buttons go last (right-most).
-- Index is the position in the offer's own list, which is what the model's PressOffer takes.
function View._orderButtons(theme, buttons)
	local first, last = {}, {}
	for index, definition in ipairs(buttons or {}) do
		local variant = View._variantOf(theme, definition.Accent)
		local item = {
			Index = index,
			Id = "Option" .. index,
			Variant = variant,
			Text = definition.Text,
			Disabled = definition.Enabled == false,
		}
		table.insert(variant == "Main" and last or first, item)
	end
	for _, item in ipairs(last) do
		table.insert(first, item)
	end
	return first
end

-- Classic ActivityClient 203-214. remaining = goAt - server time.
function View._countdown(remaining)
	if remaining > 0 then
		return "Number", math.min(math.ceil(remaining), COUNTDOWN_MAX)
	elseif remaining > -GO_SECONDS then
		return "Go", 0
	end
	return "Done", 0
end

-- Whole pixels of the offer timer line still showing.
function View._timerWidth(trackWidth, elapsed, timeout)
	if not (timeout and timeout > 0) then
		return 0
	end
	local fraction = math.clamp(1 - elapsed / timeout, 0, 1)
	return math.floor(trackWidth * fraction + 0.5)
end

-- Kit-backed pieces for the shared views ---------------------------------------------------------------------

-- ctx.UI.Button(parent, props) with the Classic call shape (RacingUIComponents.Button). Returns the kit button's
-- root TextButton, so the view's own writes (Text, Visible, AnchorPoint, Position) and its Activated and Destroying
-- connections keep working. Color, StrokeColor, TextColor, TextSize and Size are accepted and not used: the kit
-- sizes and colours its own button. A Text written on the root is passed to the kit label; the root itself never
-- draws text.
function View.Button(parent, props, scope)
	props = props or {}
	local component = Controls.Button(parent, {
		Name = props.Name,
		Variant = "Default",
		Text = tostring(props.Text or ""),
		Size = "Hud",
		OnActivated = function() end,
	}, scope)
	local instance = component.Instance
	scope:connect(instance:GetPropertyChangedSignal("Text"), function()
		local text = instance.Text
		if text ~= "" then
			-- Visible goes with it: the caller writes Visible on the root, and a kit Set re-applies its own value.
			component.Set({ Text = text, Visible = instance.Visible })
		end
	end)
	return instance, component
end

local LABEL_ROLES = table.freeze({ Heading = "Status", Metric = "Value" })
local LABEL_ALIGN = table.freeze({
	[Enum.TextXAlignment.Left] = "Left",
	[Enum.TextXAlignment.Center] = "Centre",
	[Enum.TextXAlignment.Right] = "Right",
})

-- ctx.UI.Label(parent, props) with the Classic call shape. None of the five shared views calls it today. It returns
-- an object that takes the writes a caller of the Classic label could make (Text, Visible) and forwards the rest
-- to the kit label's holder.
function View.Label(parent, props, scope, theme)
	props = props or {}
	local component = Text.Label(parent, {
		Name = props.Name,
		Text = tostring(props.Text or ""),
		Role = LABEL_ROLES[props.Role] or "Label",
		Colour = View._roleOf(theme, props.Color, props.Color == theme.Muted and "TextMuted" or "White"),
		Align = LABEL_ALIGN[props.XAlignment] or "Left",
		Wrap = props.Wrapped == true,
	}, scope)
	local holder = component.Instance
	return setmetatable({}, {
		__index = function(_, key)
			return holder[key]
		end,
		__newindex = function(_, key, value)
			if key == "Text" then
				component.Set({ Text = tostring(value) })
			elseif key == "Visible" then
				component.Set({ Visible = value == true })
			elseif key == "TextColor3" then
				component.Set({ Colour = View._roleOf(theme, value, "White") })
			else
				holder[key] = value
			end
		end,
	}), component
end

-- Mount ----------------------------------------------------------------------------------------------------

local function plain(name, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new()
	frame.Parent = parent
	return frame
end

local function list(parent, direction, alignCentre)
	local layout = Instance.new("UIListLayout")
	layout.Name = "Flow"
	layout.FillDirection = direction
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = alignCentre and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left
	layout.Parent = parent
	return layout
end

local function put(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function attach(instance, slot)
	instance.AnchorPoint = slot.AnchorPoint
	instance.Position = UDim2.new()
	instance.Parent = slot
end

-- View.Mount(layer, model, scope, liveLayer). `layer` is the static ActivityHud layer (job strip); `liveLayer` is
-- ActivityHudLive (offer, countdown, rank-up: everything that animates or is short-lived). The gallery passes one
-- stage for both. The model is ActivityHudClient's (or a fixture's): Theme, StripEntry, Cancel, OfferState,
-- PressOffer, CountdownState, CountdownEnded, RankUpState, Clock, ServerNow.
function View.Mount(layer, model, scope, liveLayer)
	liveLayer = liveLayer or layer
	local ctx = layer.Metrics
	local theme = model.Theme
	local bag = {}
	local destroyed = false

	local function keep(component)
		table.insert(bag, component)
		return component
	end

	local function lineOf(role)
		local size, holder = Text.SizeFor(role, ctx)
		return math.ceil(size * holder)
	end

	-- Job strip (static layer): [edge | text] [X].
	local strip = plain("JobStrip", nil)
	strip.AutomaticSize = Enum.AutomaticSize.XY
	strip.Visible = false
	local stripFlow = list(strip, Enum.FillDirection.Horizontal, false)
	local plate = plain("Plate", strip)
	plate.LayoutOrder = 1
	plate.Active = true
	plate.AutomaticSize = Enum.AutomaticSize.X
	plate.BackgroundColor3 = Colour.Slate
	plate.BackgroundTransparency = 1 - Opacity.Panel
	local plateFlow = list(plate, Enum.FillDirection.Horizontal, false)
	local platePad = Instance.new("UIPadding")
	platePad.Name = "Inset"
	platePad.Parent = plate
	local edge = plain("Edge", plate)
	edge.LayoutOrder = 1
	edge.BackgroundTransparency = 0
	edge.BackgroundColor3 = Colour.Cyan
	local stripText = keep(Text.Label(plate, { Name = "Text", Text = "", Role = "Status", LayoutOrder = 2 }, scope))
	keep(Controls.IconButton(strip, {
		Name = "Cancel",
		Icon = "close",
		Size = "Small",
		LayoutOrder = 2,
		OnActivated = function()
			model.Cancel()
		end,
	}, scope))
	attach(strip, layer.Slot("TopCentreHud"))

	-- Offer card (live layer).
	local offer = plain("Offer", nil)
	offer.Visible = false
	local offerPanel = keep(Surface.Panel(offer, { Name = "Panel" }, scope))
	local offerContent = offerPanel.Content
	local titleRow = plain("TitleRow", offerContent)
	local bodyRow = plain("BodyRow", offerContent)
	bodyRow.ClipsDescendants = true
	local buttonsAnchor = plain("Buttons", offerContent)
	buttonsAnchor.AnchorPoint = Vector2.new(1, 1)
	buttonsAnchor.Position = UDim2.new(1, 0, 1, 0)
	local offerTitle = nil
	local offerBody = keep(Text.Label(bodyRow, { Name = "Body", Text = "", Role = "Body", Colour = "TextSecondary", Wrap = true }, scope))
	local timerTrack = plain("Timer", offer)
	timerTrack.AnchorPoint = Vector2.new(0, 1)
	timerTrack.Position = UDim2.new(0, 0, 1, 0)
	timerTrack.BackgroundColor3 = Colour.White
	timerTrack.BackgroundTransparency = 1 - Opacity.SegmentEmpty
	timerTrack.ZIndex = 3
	local timerFill = plain("Fill", timerTrack)
	timerFill.BackgroundTransparency = 0
	timerFill.BackgroundColor3 = Colour.Cyan
	attach(offer, liveLayer.Slot("PromptStack"))
	local offerRow = nil
	local shownOffer = nil
	local offerWidth = 0
	local lastTimerWidth = nil

	-- Countdown (live layer): label, image digits, then "GO!".
	local countdown = plain("Countdown", nil)
	countdown.AutomaticSize = Enum.AutomaticSize.XY
	countdown.Visible = false
	local countdownFlow = list(countdown, Enum.FillDirection.Vertical, true)
	local countdownLabel = keep(Text.Label(countdown, { Name = "Label", Text = "", Role = "SectionHead", Shadow = true, LayoutOrder = 1 }, scope))
	local countdownNumber = keep(BigNumber.New(countdown, {
		Name = "Number", Text = "0", Role = "Hero", Align = "Centre", MaxCells = COUNTDOWN_CELLS, LayoutOrder = 2,
	}, scope))
	local countdownGo = keep(Text.Label(countdown, {
		Name = "Go", Text = "GO!", Role = "ScreenTitle", Colour = "Cyan", Shadow = true, LayoutOrder = 3, Visible = false,
	}, scope))
	attach(countdown, liveLayer.Slot("Centre"))
	local shownCountdown = nil
	local lastKind, lastWhole = nil, nil

	-- Rank-up card (live layer).
	local rankUp = plain("RankUp", nil)
	rankUp.Visible = false
	local rankPanel = keep(Surface.Panel(rankUp, { Name = "Panel" }, scope))
	local rankContent = rankPanel.Content
	local kickerRow = plain("KickerRow", rankContent)
	local rankRow = plain("RankRow", rankContent)
	local rewardRow = plain("RewardRow", rankContent)
	rewardRow.AnchorPoint = Vector2.new(0, 1)
	rewardRow.Position = UDim2.new(0, 0, 1, 0)
	local rewardFlow = list(rewardRow, Enum.FillDirection.Horizontal, true)
	local rankKicker, rankText = nil, nil
	keep(Text.Label(rewardRow, { Name = "RewardLabel", Text = "REWARD", Role = "Label", Colour = "TextSecondary", LayoutOrder = 1 }, scope))
	local rewardChip = keep(Collections.Chip(rewardRow, { Name = "Reward", Text = "", Kind = "Yellow", LayoutOrder = 2 }, scope))
	attach(rankUp, liveLayer.Slot("Centre"))
	local shownRank = nil

	-- Labels with a MaxWidth are made in layout(), because the width they truncate or centre in is a class value.
	local builtClass = nil
	local function buildClassLabels(compact)
		if builtClass == compact then
			return
		end
		builtClass = compact
		local cardDesign = compact and Space.CompactPromptWidth or Space.ConfirmWidth
		local rankDesign = compact and Space.CompactSidePanelWidth or Space.ListWidth
		if offerTitle then
			offerTitle.Destroy()
			rankKicker.Destroy()
			rankText.Destroy()
		end
		offerTitle = Text.Label(titleRow, {
			Name = "Title", Text = shownOffer and shownOffer.Title or "", Role = "SectionHead", MaxWidth = cardDesign - Space.Pad - Space.Pad,
		}, scope)
		rankKicker = Text.Label(kickerRow, {
			Name = "Kicker", Text = "RANK UP", Role = "SectionHead", Colour = "Pink", Align = "Centre", MaxWidth = rankDesign - Space.Pad - Space.Pad,
		}, scope)
		rankText = Text.Label(rankRow, {
			Name = "Rank", Text = shownRank and shownRank.Text or "", Role = "ScreenTitle", Align = "Centre", MaxWidth = rankDesign - Space.Pad - Space.Pad,
		}, scope)
	end

	local function layout()
		if destroyed then
			return
		end
		local compact = ctx.Class == "Compact"
		buildClassLabels(compact)
		local pad = ctx.Px(Space.Pad)
		local gap = ctx.Px(Space.Gap)
		local hair = ctx.Hair(Space.Hairline)

		-- Strip. On Compact the action bar is top centre (API2 2.4), so the strip sits under it.
		local stripHeight = ctx.Px(compact and Space.CompactStatusHeight or Space.StatusHeight)
		put(strip, "Position", UDim2.fromOffset(0, compact and (ctx.Touch(Space.CompactActionTile) + ctx.Px(Space.TouchGap)) or 0))
		put(stripFlow, "Padding", UDim.new(0, hair))
		put(plate, "Size", UDim2.fromOffset(0, stripHeight))
		put(plateFlow, "Padding", UDim.new(0, gap))
		put(platePad, "PaddingRight", UDim.new(0, pad))
		put(edge, "Size", UDim2.new(0, ctx.Hair(Space.TabUnderline), 1, 0))

		-- Offer card.
		local titleLine = lineOf("SectionHead")
		local bodyLine = lineOf("Body")
		local buttonHeight = compact and ctx.Touch(Space.CompactButtonDrawn) or ctx.Px(Space.ButtonHeight)
		offerWidth = ctx.Px(compact and Space.CompactPromptWidth or Space.ConfirmWidth)
		local bodyHeight = bodyLine * OFFER_BODY_LINES
		put(offer, "Size", UDim2.fromOffset(offerWidth, pad + titleLine + gap + bodyHeight + gap + buttonHeight + pad))
		put(titleRow, "Size", UDim2.new(1, 0, 0, titleLine))
		put(bodyRow, "Position", UDim2.fromOffset(0, titleLine + gap))
		put(bodyRow, "Size", UDim2.new(1, 0, 0, bodyHeight))
		put(timerTrack, "Size", UDim2.new(1, 0, 0, ctx.Hair(Space.TabUnderline)))
		lastTimerWidth = nil

		-- Countdown.
		put(countdownFlow, "Padding", UDim.new(0, gap))

		-- Rank-up card.
		local kickerLine = titleLine
		local rankLine = lineOf("ScreenTitle")
		local rewardHeight = ctx.Px(compact and Space.CompactStatusHeight or Space.StatusHeight)
		local rankWidth = ctx.Px(compact and Space.CompactSidePanelWidth or Space.ListWidth)
		put(rankUp, "Size", UDim2.fromOffset(rankWidth, pad + kickerLine + gap + rankLine + gap + rewardHeight + pad))
		put(kickerRow, "Size", UDim2.new(1, 0, 0, kickerLine))
		put(rankRow, "Position", UDim2.fromOffset(0, kickerLine + gap))
		put(rankRow, "Size", UDim2.new(1, 0, 0, rankLine))
		put(rewardRow, "Size", UDim2.new(1, 0, 0, rewardHeight))
		put(rewardFlow, "Padding", UDim.new(0, gap))
	end
	layout()

	if ctx.Changed then
		scope:connect(ctx.Changed, function(change)
			if type(change) == "table" and change.Layout == false then
				return
			end
			layout()
		end)
	end

	-- Render: each part compares before it writes, so a repeated Render changes nothing.
	local shownStripText, shownStripRole = nil, nil
	local function renderStrip()
		local entry = model.StripEntry()
		put(strip, "Visible", entry ~= nil)
		if not entry then
			return
		end
		if entry.Text ~= shownStripText then
			shownStripText = entry.Text
			stripText.Set({ Text = entry.Text })
		end
		local role = View._roleOf(theme, entry.Colour, "Cyan")
		if role ~= shownStripRole then
			shownStripRole = role
			edge.BackgroundColor3 = Colour[role]
		end
	end

	local function clearOfferRow()
		if offerRow then
			offerRow.Destroy()
			offerRow = nil
		end
	end

	local function renderOffer()
		local record = model.OfferState()
		if record == shownOffer then
			return
		end
		shownOffer = record
		lastTimerWidth = nil
		clearOfferRow()
		if not record then
			put(offer, "Visible", false)
			return
		end
		offerTitle.Set({ Text = record.Title })
		offerBody.Set({ Text = record.Body })
		local buttons = {}
		for _, item in ipairs(View._orderButtons(theme, record.Buttons)) do
			local index = item.Index
			table.insert(buttons, {
				Id = item.Id,
				Variant = item.Variant,
				Text = item.Text,
				Disabled = item.Disabled,
				OnActivated = function()
					model.PressOffer(record, index)
				end,
			})
		end
		offerRow = Controls.ButtonRow(buttonsAnchor, { Name = "Options", Buttons = buttons, Align = "Right" }, scope)
		put(timerTrack, "Visible", record.Timeout ~= nil)
		put(timerFill, "Size", UDim2.new(1, 0, 1, 0))
		put(offer, "Visible", true)
	end

	local function renderCountdown()
		local record = model.CountdownState()
		if record == shownCountdown then
			return
		end
		shownCountdown = record
		lastKind, lastWhole = nil, nil
		if not record then
			put(countdown, "Visible", false)
			return
		end
		countdownLabel.Set({ Text = record.Label, Visible = record.Label ~= "" })
		countdownNumber.Set({ Visible = false })
		countdownGo.Set({ Visible = false })
		put(countdown, "Visible", true)
	end

	local function renderRankUp()
		local record = model.RankUpState()
		if record == shownRank then
			return
		end
		shownRank = record
		if not record then
			put(rankUp, "Visible", false)
			return
		end
		rankText.Set({ Text = record.Text })
		-- Data.Money may yield once on its first call (API2 3.5); the model calls Render for a rank-up from its own
		-- task, never from the frame step.
		local reward = ""
		if record.Cash > 0 then
			local ok, money = pcall(Data.Money, record.Cash, false)
			if ok then
				reward = "+" .. tostring(money)
			end
		end
		rewardChip.Set({ Text = reward })
		put(rewardRow, "Visible", reward ~= "")
		put(rankUp, "Visible", true)
	end

	local view = {}

	function view.Render(reason)
		if destroyed then
			return
		end
		if reason == nil or reason == "Strip" then
			renderStrip()
		end
		if reason == nil or reason == "Offer" then
			renderOffer()
		end
		if reason == nil or reason == "Countdown" then
			renderCountdown()
		end
		if reason == nil or reason == "RankUp" then
			renderRankUp()
		end
	end

	-- True while something on the live layer shows; the client shows the live layer only then.
	function view.LiveNeeded()
		return shownOffer ~= nil or shownCountdown ~= nil or shownRank ~= nil
	end

	-- The one frame step of the live layer (Perf.Bind runs it only while the live root shows). Writes on change.
	local clock = model.Clock
	local serverNow = model.ServerNow
	local function step()
		local record = shownOffer
		if record and record.Timeout then
			local width = View._timerWidth(offerWidth, clock() - record.StartedAt, record.Timeout)
			if width ~= lastTimerWidth then
				lastTimerWidth = width
				timerFill.Size = UDim2.new(0, width, 1, 0)
			end
		end
		local count = shownCountdown
		if count then
			local kind, whole = View._countdown(count.GoAt - serverNow())
			if kind == "Done" then
				model.CountdownEnded(count)
			elseif kind ~= lastKind or whole ~= lastWhole then
				if kind ~= lastKind then
					countdownNumber.Set({ Visible = kind == "Number" })
					countdownGo.Set({ Visible = kind == "Go" })
				end
				if kind == "Number" then
					countdownNumber.SetText(tostring(whole))
				end
				lastKind, lastWhole = kind, whole
			end
		end
	end
	view._step = step
	local binding = Perf.Bind("ActivityHud", liveLayer.Root, step)

	function view.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		binding.Disconnect()
		clearOfferRow()
		if offerTitle then
			offerTitle.Destroy()
			rankKicker.Destroy()
			rankText.Destroy()
		end
		for index = #bag, 1, -1 do
			bag[index].Destroy()
		end
		strip:Destroy()
		offer:Destroy()
		countdown:Destroy()
		rankUp:Destroy()
	end

	view.Render()
	return view
end

return View
