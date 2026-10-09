-- Owns the look of the Pulse onboarding: the dimmer, highlight frame, connector and callout bubble, and the objective cards; no remote, attribute write, bindable or target lookup (the model hands it the pinned objects).
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Shell.OnboardingView. Requires: Tokens, Text, Surface, Controls, Input, Layers, Shell.OnboardingModel (static tables only; resolved on the first mount).

-- Line numbers in comments are ReplicatedStorage.Modules.Game.UI.OnboardingClient (Classic).
local View = {}

local HALF = 0.5
local ABOVE_SPLIT = 0.62 -- 304: a target in the lower part of the safe area gets its bubble above
local HEADER_FORMAT = "GETTING STARTED \u{00B7} STEP %d OF 3"
local TIP_FORMAT = "TIP %d OF %d"
local NEXT_TEXT = "NEXT" -- 93

local cache
local function modules()
	if not cache then
		local pulse = script.Parent.Parent
		local kit = pulse.Kit
		cache = {
			Tokens = require(kit.Tokens),
			Text = require(kit.Text),
			Surface = require(kit.Surface),
			Controls = require(kit.Controls),
			Input = require(kit.Input),
			Layers = require(kit.Layers),
			Model = require(script.Parent.OnboardingModel),
		}
	end
	return cache
end
-- Test and gallery seam: a function returning the same table.
View._modules = modules

-- Pure. boxes = {{x, y, width, height}} in canvas space. -> x, y, right, bottom padded (252-261), or nil.
function View._bounds(boxes, pad)
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	for _, box in ipairs(boxes) do
		minX = math.min(minX, box[1])
		minY = math.min(minY, box[2])
		maxX = math.max(maxX, box[1] + box[3])
		maxY = math.max(maxY, box[2] + box[4])
	end
	if minX == math.huge then
		return nil
	end
	return math.floor(minX - pad), math.floor(minY - pad), math.ceil(maxX + pad), math.ceil(maxY + pad)
end

-- Pure. The four dimmer rectangles around the target rectangle (361-364): {x, y, width, height} each.
function View._shadeRects(x, y, right, bottom, width, height, overscan)
	return {
		{ -overscan, -overscan, width + overscan * 2, y + overscan },
		{ -overscan, y, x + overscan, bottom - y },
		{ right, y, width - right + overscan, bottom - y },
		{ -overscan, bottom, width + overscan * 2, height - bottom + overscan },
	}
end

-- Pure. 304: the fixed side for a card, or Above for a target low on the screen, else Auto.
function View._mode(fixed, y, bottom, safeTop, safeBottom)
	if fixed then
		return fixed
	end
	if (y + bottom) * HALF > safeTop + (safeBottom - safeTop) * ABOVE_SPLIT then
		return "Above"
	end
	return "Auto"
end

-- Pure. 304-308: first candidate that fits the safe rectangle, else the first candidate clamped into it.
function View._placeBubble(mode, x, y, right, bottom, bubbleWidth, bubbleHeight, offset, safeLeft, safeTop, safeRight, safeBottom)
	local targetWidth, targetHeight = right - x, bottom - y
	local above = { x + (targetWidth - bubbleWidth) * HALF, y - bubbleHeight - offset }
	local below = { x + (targetWidth - bubbleWidth) * HALF, bottom + offset }
	local left = { x - bubbleWidth - offset, y + (targetHeight - bubbleHeight) * HALF }
	local rightSide = { right + offset, y + (targetHeight - bubbleHeight) * HALF }
	local candidates
	if mode == "Above" then
		candidates = { above, below, left, rightSide }
	elseif mode == "Below" then
		candidates = { below, above, left, rightSide }
	elseif mode == "Left" then
		candidates = { left, below, above, rightSide }
	else
		candidates = { rightSide, left, above, below }
	end
	local bubbleX, bubbleY = nil, nil
	for _, candidate in ipairs(candidates) do
		if candidate[1] >= safeLeft and candidate[2] >= safeTop and candidate[1] + bubbleWidth <= safeRight
			and candidate[2] + bubbleHeight <= safeBottom then
			bubbleX, bubbleY = candidate[1], candidate[2]
			break
		end
	end
	bubbleX = math.clamp(bubbleX or candidates[1][1], safeLeft, math.max(safeLeft, safeRight - bubbleWidth))
	bubbleY = math.clamp(bubbleY or candidates[1][2], safeTop, math.max(safeTop, safeBottom - bubbleHeight))
	return math.floor(bubbleX), math.floor(bubbleY)
end

-- Pure. 280-286: the bar joining the target rectangle to the bubble. -> x, y, width, height.
function View._connector(x, y, right, bottom, bubbleX, bubbleY, bubbleWidth, bubbleHeight, thickness)
	local bubbleRight, bubbleBottom = bubbleX + bubbleWidth, bubbleY + bubbleHeight
	if bubbleX >= right then
		return right, math.floor(math.clamp((y + bottom) * HALF, bubbleY, bubbleBottom)), math.max(thickness, bubbleX - right), thickness
	elseif bubbleRight <= x then
		return bubbleRight, math.floor(math.clamp((y + bottom) * HALF, bubbleY, bubbleBottom)), math.max(thickness, x - bubbleRight), thickness
	elseif bubbleY >= bottom then
		return math.floor(math.clamp((x + right) * HALF, bubbleX, bubbleRight)), bottom, thickness, math.max(thickness, bubbleY - bottom)
	end
	return math.floor(math.clamp((x + right) * HALF, bubbleX, bubbleRight)), bubbleBottom, thickness, math.max(thickness, y - bubbleBottom)
end

local function write(object, property, value)
	if object[property] ~= value then
		object[property] = value
	end
end

local function plain(className, name, parent)
	local object = Instance.new(className)
	object.Name = name
	object.BackgroundTransparency = 1
	object.BorderSizePixel = 0
	object.Parent = parent
	return object
end

-- Shown as far as its own tree says: every GuiObject above it is Visible and its gui is on.
local function shownOnScreen(object)
	if object.AbsoluteSize.X <= 1 or object.AbsoluteSize.Y <= 1 then
		return false
	end
	local at = object
	while at do
		if at:IsA("GuiObject") and not at.Visible then
			return false
		end
		if at:IsA("LayerCollector") then
			return at.Enabled
		end
		at = at.Parent
	end
	return true
end

function View.Mount(layer, model, scope)
	local m = View._modules()
	local Tokens, Text, Surface, Controls, Input, Layers, Model = m.Tokens, m.Text, m.Surface, m.Controls, m.Input, m.Layers, m.Model
	local Space, Colour, Opacity = Tokens.Space, Tokens.Colour, Tokens.Opacity
	local ctx = layer.Metrics
	local root = layer.Root
	local shadeRoot = layer.ScrimRoot or root

	local destroyed = false
	local components = {}
	local instances = {}
	local connections = {}
	local function keep(component)
		table.insert(components, component)
		return component
	end
	local function own(instance)
		table.insert(instances, instance)
		return instance
	end
	local function isCompact()
		return ctx.Class == "Compact"
	end

	-- Dimmer and the press-anywhere button: whole screen, under the callout layer -------------------------------
	local shades = {}
	for index = 1, 4 do
		local shade = own(plain("TextButton", "Shade" .. index, shadeRoot))
		shade.Text = ""
		shade.AutoButtonColor = false
		shade.BackgroundColor3 = Colour.Black
		shade.BackgroundTransparency = 1 - Opacity.ConfirmScrim
		shade.Active = true
		shade.Selectable = false
		shade.Visible = false
		Input.Silence(shade)
		shades[index] = shade
	end
	local catch = own(plain("TextButton", "Advance", shadeRoot))
	catch.Text = ""
	catch.AutoButtonColor = false
	catch.Size = UDim2.fromScale(1, 1)
	catch.Active = true
	catch.Selectable = false
	catch.Modal = true
	catch.Visible = false
	catch.ZIndex = 2
	Input.Silence(catch)

	-- Objective cards: a Hud stage inside the Bare layer, so they sit in the TopLeftHud slot (below chat) -------------
	local stage = Layers.Stage(root, ctx, "Hud")
	stage.Root.Name = "Objectives"
	stage.Root.Visible = false
	local slot = stage.Slot("TopLeftHud")
	local cardList = plain("Frame", "Cards", slot)
	cardList.AnchorPoint = slot.AnchorPoint
	cardList.AutomaticSize = Enum.AutomaticSize.XY
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.Name = "Layout"
	cardLayout.FillDirection = Enum.FillDirection.Vertical
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = cardList
	local header = keep(Text.Label(cardList, { Name = "Header", Text = string.format(HEADER_FORMAT, 1), Role = "Label",
		Colour = "TextSecondary", Shadow = true, LayoutOrder = 0, Visible = false }, scope))

	local cards = {}
	for index = 1, 3 do
		local card = plain("Frame", "Objective" .. index, cardList)
		card.BackgroundColor3 = Colour.Slate
		card.BackgroundTransparency = 1 - Opacity.Panel
		card.Active = true
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.LayoutOrder = index
		card.Visible = false
		local number = plain("Frame", "Number", card)
		number.BackgroundColor3 = Colour.White
		local numberLayout = Instance.new("UIListLayout")
		numberLayout.Name = "Layout"
		numberLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		numberLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		numberLayout.Parent = number
		local value = keep(Text.Label(number, { Name = "Value", Text = tostring(index), Role = "TileName", Colour = "White",
			Align = "Centre" }, scope))
		local body = plain("Frame", "Body", card)
		body.AutomaticSize = Enum.AutomaticSize.Y
		local bodyPadding = Instance.new("UIPadding")
		bodyPadding.Name = "Padding"
		bodyPadding.Parent = body
		local bodyLayout = Instance.new("UIListLayout")
		bodyLayout.Name = "Layout"
		bodyLayout.FillDirection = Enum.FillDirection.Vertical
		bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
		bodyLayout.Parent = body
		local title = keep(Text.Label(body, { Name = "Title", Text = Model.ObjectiveContent[index].Title, Role = "TileName",
			Wrap = true, LayoutOrder = 1 }, scope))
		local hint = keep(Text.Label(body, { Name = "Hint", Text = "", Role = "Body", Colour = "TextSecondary", Wrap = true,
			LayoutOrder = 2, Visible = false }, scope))
		cards[index] = { Frame = card, Number = number, Value = value, Body = body, Padding = bodyPadding, Layout = bodyLayout,
			Title = title, Hint = hint }
	end

	local function relayoutCards()
		local compact = isCompact()
		local gap = ctx.Px(compact and Space.TouchGap or Space.Gap)
		local pad = ctx.Px(compact and Space.TouchGap or Space.Pad)
		local width = ctx.Px(compact and Space.CompactStatPanelWidth or Space.StatPanelWidth)
		local cell = ctx.Px(compact and Space.CompactStatusHeight or Space.BadgeLarge)
		local bodyWidth = math.max(1, width - cell - pad - pad)
		local designWidth = bodyWidth / ctx.Scale
		write(cardLayout, "Padding", UDim.new(0, gap))
		for _, card in ipairs(cards) do
			write(card.Frame, "Size", UDim2.fromOffset(width, 0))
			write(card.Number, "Size", UDim2.new(0, cell, 1, 0))
			write(card.Body, "Position", UDim2.fromOffset(cell + pad, 0))
			write(card.Body, "Size", UDim2.fromOffset(bodyWidth, 0))
			write(card.Padding, "PaddingTop", UDim.new(0, gap))
			write(card.Padding, "PaddingBottom", UDim.new(0, gap))
			write(card.Layout, "Padding", UDim.new(0, ctx.Hair(Space.Hairline)))
			card.Title.Set({ Role = compact and "Status" or "TileName", MaxWidth = designWidth })
			card.Hint.Set({ MaxWidth = designWidth })
			card.Value.Set({ Role = compact and "Status" or "TileName" })
		end
	end
	relayoutCards()

	local function renderObjectives()
		local show = model:ObjectivesVisible() == true
		write(stage.Root, "Visible", show)
		if not show then
			return
		end
		local order = model:ObjectiveOrder()
		local compact = isCompact()
		header.Set({ Visible = not compact and order[1] ~= nil, Text = string.format(HEADER_FORMAT, order[1] or 1) })
		for index, card in ipairs(cards) do
			local position = table.find(order, index)
			local visible = position ~= nil and (not compact or position == 1)
			write(card.Frame, "Visible", visible)
			if visible then
				local expanded = position == 1 and not compact
				local hintText = model:ObjectiveHint(index) or ""
				write(card.Number, "BackgroundTransparency", expanded and 0 or 1)
				card.Value.Set({ Colour = expanded and "Ink" or "White", Text = compact and (index .. "/3") or tostring(index) })
				card.Hint.Set({ Text = hintText, Visible = expanded and hintText ~= "" })
			end
		end
	end

	-- Callout: highlight frame, connector and bubble, above the objective cards ---------------------------------
	local callout = own(plain("Frame", "Callout", root))
	callout.Size = UDim2.fromScale(1, 1)
	callout.ZIndex = 2
	local highlight = plain("Frame", "HighlightBorder", callout)
	highlight.Visible = false
	highlight.ZIndex = 2
	local edges = {}
	for _, name in ipairs({ "EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight" }) do
		local edge = plain("Frame", name, highlight)
		edge.BackgroundColor3 = Colour.White
		edge.BackgroundTransparency = 0
		edges[name] = edge
	end
	edges.EdgeBottom.AnchorPoint = Vector2.new(0, 1)
	edges.EdgeBottom.Position = UDim2.fromScale(0, 1)
	edges.EdgeRight.AnchorPoint = Vector2.new(1, 0)
	edges.EdgeRight.Position = UDim2.fromScale(1, 0)
	keep(Surface.Glow(highlight, { Kind = "Tile", Colour = "Pink" }, scope))
	local connector = plain("Frame", "Connector", callout)
	connector.BackgroundColor3 = Colour.White
	connector.BackgroundTransparency = 0
	connector.Visible = false
	connector.ZIndex = 2
	local bubble = plain("Frame", "Bubble", callout)
	bubble.Active = true
	bubble.Visible = false
	bubble.ZIndex = 3
	local panel = keep(Surface.Panel(bubble, { Name = "Panel" }, scope))
	local content = panel.Content
	local tip = keep(Text.Label(content, { Name = "Tip", Text = string.format(TIP_FORMAT, 1, 1), Role = "Label", Colour = "Pink" }, scope))
	local copy = keep(Text.Label(content, { Name = "Copy", Text = "", Role = "Body", Wrap = true,
		MaxWidth = isCompact() and Space.CompactPromptWidth or Space.PromptWidth }, scope))
	local nextButton = keep(Controls.Button(content, { Name = "Next", Variant = "Main", Text = NEXT_TEXT,
		MinWidth = isCompact() and Space.CompactTileMinWidth or Space.StepperWidth,
		OnActivated = function()
			model:Advance()
		end }, scope))
	local focus = Input.FocusGroup(scope, { Trap = true })
	focus.Add(nextButton.Instance)
	table.insert(connections, catch.Activated:Connect(function()
		model:Advance()
	end))

	local layoutKey = nil
	local calloutShown = false
	local focusedFor = nil
	local pinned = nil
	local pinConnections = {}
	local layoutQueued = false
	local renderCallout

	local function scheduleLayout()
		if layoutQueued or destroyed then
			return
		end
		layoutQueued = true
		task.defer(function()
			layoutQueued = false
			if not destroyed then
				renderCallout()
			end
		end)
	end

	local function hideCallout()
		layoutKey = nil
		if not calloutShown then
			return
		end
		calloutShown = false
		focusedFor = nil
		for _, shade in ipairs(shades) do
			write(shade, "Visible", false)
		end
		write(catch, "Visible", false)
		write(highlight, "Visible", false)
		write(connector, "Visible", false)
		write(bubble, "Visible", false)
		focus.Leave()
	end

	-- 390-408: follow the pinned objects. A move lays out again; a hide or a move in the tree asks the model to resolve
	-- again (the ancestors are watched too, because a Pulse screen closes by hiding its root).
	local function setPinned(objects)
		if objects == pinned then
			return
		end
		for _, connection in ipairs(pinConnections) do
			connection:Disconnect()
		end
		table.clear(pinConnections)
		pinned = objects
		if not objects then
			return
		end
		local action = model:IsAction() == true
		local function lost()
			model:TargetLost()
		end
		local watched = {}
		for _, object in ipairs(objects) do
			table.insert(pinConnections, object:GetPropertyChangedSignal("AbsolutePosition"):Connect(scheduleLayout))
			table.insert(pinConnections, object:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleLayout))
			table.insert(pinConnections, object.AncestryChanged:Connect(lost))
			local at = object
			while at and at:IsA("GuiObject") do
				if not watched[at] then
					watched[at] = true
					table.insert(pinConnections, at:GetPropertyChangedSignal("Visible"):Connect(lost))
				end
				at = at.Parent
			end
			if action and object:IsA("GuiButton") then
				table.insert(pinConnections, object.Activated:Connect(function()
					model:ActionActivated()
				end))
			end
		end
	end

	-- 353-369 and 288-318.
	renderCallout = function()
		if destroyed then
			return
		end
		setPinned(model.ActiveObjects)
		local id = model:CardId()
		if not (pinned and id and model:CalloutVisible()) then
			hideCallout()
			return
		end

		local origin = root.AbsolutePosition
		local canvas = root.AbsoluteSize
		local boxes = {}
		for _, object in ipairs(pinned) do
			if shownOnScreen(object) then
				local position, size = object.AbsolutePosition - origin, object.AbsoluteSize
				table.insert(boxes, { position.X, position.Y, size.X, size.Y })
			end
		end
		local x, y, right, bottom = View._bounds(boxes, ctx.Px(Space.TileBaseLine))
		if not x then
			hideCallout()
			return
		end
		x = math.clamp(x, 0, canvas.X)
		y = math.clamp(y, 0, canvas.Y)
		right = math.clamp(right, x, canvas.X)
		bottom = math.clamp(bottom, y, canvas.Y)

		local compact = isCompact()
		local action = model:IsAction() == true
		local page = Model.Pages[model.ActivePage]
		tip.Set({ Text = string.format(TIP_FORMAT, model.ActiveIndex, #page) })
		copy.Set({ Text = Model.Copy[id] })
		nextButton.Set({ Visible = not action })

		-- Sizes the kit has laid out; before the first layout pass, the token sizes.
		local pad = ctx.Px(Space.Pad)
		local gap = ctx.Px(Space.Gap)
		local margin = ctx.Px(Space.Gap)
		local hair = ctx.Hair(Space.Hairline)
		local safeLeft, safeRight, safeBottom = margin, canvas.X - margin, canvas.Y - margin
		local safeTop = margin
		if not compact then
			-- 289: the top bar is reserved on desktop only.
			safeTop = math.max(margin, math.round(ctx.TopBarHeight - ctx.Origin.Y) + margin)
		end
		local safeWidth = math.max(1, safeRight - safeLeft)
		local buttonSize = nextButton.Instance.AbsoluteSize
		local buttonWidth = buttonSize.X > 0 and buttonSize.X or ctx.Px(compact and Space.CompactTileMinWidth or Space.StepperWidth)
		local buttonHeight = buttonSize.Y > 0 and buttonSize.Y or ctx.Px(compact and Space.CompactButtonDrawn or Space.ButtonHeight)
		local bubbleWidth = math.min(safeWidth, ctx.Px(compact and Space.CompactPromptWidth or Space.PromptWidth))
		local contentWidth = math.max(1, bubbleWidth - pad - pad)
		local beside = compact and not action
		local textWidth = math.max(1, contentWidth - (beside and (gap + buttonWidth) or 0))
		copy.Set({ MaxWidth = textWidth / ctx.Scale })
		local tipHeight = tip.Instance.AbsoluteSize.Y
		if tipHeight <= 0 then
			tipHeight = (Text.SizeFor("Label", ctx))
		end
		local copyHeight = copy.Instance.AbsoluteSize.Y
		if copyHeight <= 0 then
			copyHeight = (Text.SizeFor("Body", ctx)) * 2
		end
		local contentHeight
		if beside then
			contentHeight = tipHeight + hair + math.max(copyHeight, buttonHeight)
		elseif action then
			contentHeight = tipHeight + hair + copyHeight
		else
			contentHeight = tipHeight + hair + copyHeight + gap + buttonHeight
		end
		local bubbleHeight = contentHeight + pad + pad

		local shadeOffset = root.AbsolutePosition - shadeRoot.AbsolutePosition
		local shadeCanvas = shadeRoot.AbsoluteSize
		local key = table.concat({ id, x, y, right, bottom, canvas.X, canvas.Y, shadeOffset.X, shadeOffset.Y, shadeCanvas.X,
			shadeCanvas.Y, bubbleWidth, bubbleHeight, buttonWidth, tostring(action), tostring(compact) }, ":")
		if key == layoutKey and calloutShown then
			return
		end
		layoutKey = key
		calloutShown = true

		local rects = View._shadeRects(x + shadeOffset.X, y + shadeOffset.Y, right + shadeOffset.X, bottom + shadeOffset.Y,
			shadeCanvas.X, shadeCanvas.Y, margin)
		for index, shade in ipairs(shades) do
			local rect = rects[index]
			write(shade, "Position", UDim2.fromOffset(math.floor(rect[1]), math.floor(rect[2])))
			write(shade, "Size", UDim2.fromOffset(math.max(0, math.ceil(rect[3])), math.max(0, math.ceil(rect[4]))))
			write(shade, "Visible", true)
		end
		write(catch, "Visible", not action)

		write(highlight, "Position", UDim2.fromOffset(x, y))
		write(highlight, "Size", UDim2.fromOffset(right - x, bottom - y))
		write(edges.EdgeTop, "Size", UDim2.new(1, 0, 0, hair))
		write(edges.EdgeBottom, "Size", UDim2.new(1, 0, 0, hair))
		write(edges.EdgeLeft, "Size", UDim2.new(0, hair, 1, 0))
		write(edges.EdgeRight, "Size", UDim2.new(0, hair, 1, 0))
		write(highlight, "Visible", true)

		-- 304: the three HUD shortcut callouts sit closer to their button.
		local shortcut = id == "B2" or id == "B3" or id == "B4"
		local offset = shortcut and gap or pad
		local mode = View._mode(Model.Placement[id], y, bottom, safeTop, safeBottom)
		local bubbleX, bubbleY = View._placeBubble(mode, x, y, right, bottom, bubbleWidth, bubbleHeight, offset,
			safeLeft, safeTop, safeRight, safeBottom)
		write(bubble, "Position", UDim2.fromOffset(bubbleX, bubbleY))
		write(bubble, "Size", UDim2.fromOffset(bubbleWidth, bubbleHeight))
		write(tip.Instance, "Position", UDim2.fromOffset(0, 0))
		write(copy.Instance, "Position", UDim2.fromOffset(0, tipHeight + hair))
		if beside then
			write(nextButton.Instance, "Position", UDim2.fromOffset(contentWidth - buttonWidth,
				tipHeight + hair + math.floor(math.max(0, math.max(copyHeight, buttonHeight) - buttonHeight) * HALF)))
		else
			write(nextButton.Instance, "Position", UDim2.fromOffset(contentWidth - buttonWidth, contentHeight - buttonHeight))
		end
		write(bubble, "Visible", true)

		local connectorX, connectorY, connectorWidth, connectorHeight = View._connector(x, y, right, bottom, bubbleX, bubbleY,
			bubbleWidth, bubbleHeight, hair)
		write(connector, "Position", UDim2.fromOffset(connectorX, connectorY))
		write(connector, "Size", UDim2.fromOffset(connectorWidth, connectorHeight))
		write(connector, "Visible", true)

		-- Pad and keyboard: NEXT takes focus once per card; an action step leaves focus on the screen's own button.
		if action then
			if focusedFor ~= nil then
				focusedFor = nil
				focus.Leave()
			end
		elseif focusedFor ~= id then
			focusedFor = id
			focus.Enter(nextButton.Instance)
		end
	end

	-- The kit lays text out a moment after it is set; the bubble follows its real sizes.
	for _, object in ipairs({ tip.Instance, copy.Instance, nextButton.Instance }) do
		table.insert(connections, object:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleLayout))
	end
	table.insert(connections, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleLayout))
	table.insert(connections, root:GetPropertyChangedSignal("AbsolutePosition"):Connect(scheduleLayout))

	local layerShown = nil
	local view = {}

	function view.Render(_reason)
		if destroyed then
			return
		end
		local open = model.GateOpen == true
		if open ~= layerShown then
			layerShown = open
			layer.SetVisible(open)
		end
		renderCallout()
		renderObjectives()
	end

	if ctx.Changed then
		table.insert(connections, ctx.Changed:Connect(function(change)
			if destroyed or (type(change) == "table" and change.Layout == false) then
				return
			end
			relayoutCards()
			copy.Set({ MaxWidth = isCompact() and Space.CompactPromptWidth or Space.PromptWidth })
			nextButton.Set({ MinWidth = isCompact() and Space.CompactTileMinWidth or Space.StepperWidth })
			layoutKey = nil
			view.Render("Layout")
		end))
	end

	function view.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
		for _, connection in ipairs(pinConnections) do
			connection:Disconnect()
		end
		table.clear(pinConnections)
		pinned = nil
		focus.Destroy()
		for _, component in ipairs(components) do
			component.Destroy()
		end
		for _, instance in ipairs(instances) do
			instance:Destroy()
		end
		stage.Destroy()
	end
	scope:add(view.Destroy)

	-- Test and gallery handles; nothing in the game reads them.
	view.Parts = { Shades = shades, Catch = catch, Highlight = highlight, Connector = connector, Bubble = bubble,
		Next = nextButton, Copy = copy, Tip = tip, Cards = cards, Header = header, Objectives = stage.Root }

	view.Render("Mount")
	return view
end

return View
