-- Owns the Pulse owned-garage browser screen (the OwnedGarageBrowser layer, its view and its wiring to Garage.OwnedGarageBrowserModel); not the browser's state or remote calls (the model), nor the desk, the interior HUD or the entrance prompts.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.OwnedGarageBrowserUI. Requires: Kit.Layers, Kit.Tokens, Kit.Text, Kit.Surface, Kit.Controls, Kit.Collections, Kit.Data, Kit.Overlay, Kit.Input, Kit.Presence, Garage.OwnedGarageBrowserModel, Garage.GarageCompat, Core.ConnectionScope.
-- Public API kept from Classic UI.OwnedGarageBrowserUI: Start() -> (ok, message), Close(reason), IsOpen(). Started by Garage.OwnedGarageClient.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LAYER_NAME = "OwnedGarageBrowser"
local PRESENCE_SURFACE = "OwnedGarageBrowser"
local TAB_MINE = "Mine"
local TAB_VISIT = "Visit"
local HALF = 0.5
local DESCRIPTION_LINES = 3 -- the most lines of description the Compact detail panel shows

local Controller = {}
local started = false
local closeCurrent = function() end
local isOpenCurrent = function()
	return false
end

function Controller.Close(reason)
	closeCurrent(reason)
end

function Controller.IsOpen()
	return isOpenCurrent()
end

-- Pure. The footer row: EXIT, then the main action while the model shows it. A hidden button is left out of the
-- list (a ButtonRow keeps the width of a button that is only hidden, which left EXIT standing beside a gap).
function Controller._footerButtons(enter, onExit, onEnter)
	local list = { { Id = "Exit", Variant = "Default", Text = "EXIT", Icon = "exit", OnActivated = onExit } }
	if type(enter) == "table" and enter.Visible then
		table.insert(list, {
			Id = "Enter",
			Variant = "Main",
			Text = tostring(enter.Text or "ENTER GARAGE"),
			Icon = "garage",
			Disabled = not enter.Enabled,
			MarkKey = "Enter",
			OnActivated = onEnter,
		})
	end
	return list
end

-- Pure. The Compact detail: ONE panel holding the name band (district and name, over the picture when there is
-- one), the description and the facts. All values are real px. `input`:
--   Available  height the panel may take (the height of the list beside it)
--   Width      content width of the panel (inside its padding)
--   Pad, Gap   panel padding and the gap between the parts
--   Labels     height of the district and name lines
--   Facts      height of the fact rows (0 when there are none)
--   FactsWidth, TextWidth  the width of a facts column and the least width of a description column beside it
--   Line, Lines, MaxLines  the description's line pitch, the lines it needs and the most that are shown
--   Picture    true when the band shows a picture: the band then takes the height that is left
-- Wide (both columns fit): description left, facts right, under the band. Else the three are stacked. The
-- description gives up lines, then the facts are cut, before anything passes Available.
-- Returns { Wide, Band, About, AboutWidth, AboutY, FactsX, FactsY, FactsWidth, FactsHeight, Height }.
function Controller._compactPlan(input)
	local gap, labels, facts = input.Gap, input.Labels, input.Facts
	local line = math.max(1, input.Line)
	local inside = math.max(0, input.Available - 2 * input.Pad)
	local wanted = math.max(0, math.min(input.Lines, input.MaxLines))
	local wide = facts > 0 and input.Width >= input.TextWidth + gap + input.FactsWidth
	local plan = { Wide = wide }
	local lower
	if wide then
		local room = math.max(0, inside - labels - gap)
		plan.About = math.ceil(math.min(wanted, math.floor(room / line)) * line)
		plan.AboutWidth = input.Width - gap - input.FactsWidth
		plan.FactsWidth = input.FactsWidth
		plan.FactsHeight = math.min(facts, room)
		lower = math.max(plan.About, plan.FactsHeight)
	else
		local factsBlock = facts > 0 and facts + gap or 0
		local room = math.max(0, inside - labels - gap - factsBlock)
		plan.About = math.ceil(math.min(wanted, math.floor(room / line)) * line)
		plan.AboutWidth = input.Width
		plan.FactsWidth = input.Width
		local aboutBlock = plan.About > 0 and plan.About + gap or 0
		plan.FactsHeight = math.min(facts, math.max(0, inside - labels - gap - aboutBlock))
		lower = plan.About + ((plan.About > 0 and plan.FactsHeight > 0) and gap or 0) + plan.FactsHeight
	end
	local under = lower > 0 and gap + lower or 0
	plan.Band = input.Picture and math.max(labels, inside - under) or labels
	plan.AboutY = plan.Band + gap
	plan.FactsX = wide and input.Width - input.FactsWidth or 0
	plan.FactsY = (wide or plan.About == 0) and plan.AboutY or plan.AboutY + plan.About + gap
	plan.Height = 2 * input.Pad + plan.Band + under
	return plan
end

-- Pure. The rows of the "garage full" choice. The replacement is each row's OnActivated (click, tap, gamepad A),
-- as the Classic slot buttons were (Classic 98-103); the list has no OnSelected, because a list selects on a focus
-- move and a selection that is already set is not reported again. Building the rows calls nothing.
function Controller._replacementRows(slots, choose)
	local rows = {}
	for index, slot in ipairs(slots or {}) do
		rows[index] = {
			Key = "Slot_" .. tostring(index),
			Title = tostring(slot.DisplayName or slot.VehicleId or ""),
			Right = tostring(index),
			OnActivated = function()
				choose(index)
			end,
		}
	end
	return rows
end

-- Builds the view on `layer` over `model`. Kit components only, except the garage picture (the kit has no image
-- component; see NOTES_b). Returns {Render, Destroy}. Exposed for the gallery fixture and tests. `cashPlayer` is the
-- player whose leaderstats.Cash the status strip shows; nil (fixtures) leaves the chip unbound.
function Controller._mount(layer, model, scope, kit, cashPlayer)
	local Tokens = require(kit.Tokens)
	local Text = require(kit.Text)
	local Surface = require(kit.Surface)
	local Controls = require(kit.Controls)
	local Collections = require(kit.Collections)
	local Data = require(kit.Data)
	local Overlay = require(kit.Overlay)
	local Input = require(kit.Input)
	local Compat = require(script.Parent.GarageCompat)

	local ctx = layer.Metrics
	local space = Tokens.Space
	-- The size class is read when it is used, never kept: this view is built at start, before the screen has
	-- settled, and a class kept from then gave the Compact sizes on a desktop (capture owned_garage_browser_v1).
	local function isCompact()
		return ctx.Class == "Compact"
	end
	local function listWidth()
		return isCompact() and space.CompactSidePanelWidth or space.SidePanelWidth
	end
	local function modalWidth()
		return isCompact() and space.CompactPromptWidth or space.ConfirmWidth
	end
	local MIN_FACT_ROWS = 3 -- district, capacity, filled
	local factCount = MIN_FACT_ROWS

	local function put(instance, property, value)
		if instance[property] ~= value then
			instance[property] = value
		end
	end

	local rendering = false
	local view = {}

	if layer.ScrimRoot then
		Surface.Scrim(layer.ScrimRoot, { Kind = "Menu" }, scope)
	end

	-- Title and the MY GARAGES / VISIT tabs (Classic 20, 47, 69-72). Both stand in `head`, a zero-size frame that
	-- layout() keeps on slot TopLeft on Regular. On Compact it goes under the Roblox buttons, so the title starts on
	-- the left edge of the list and not beside the buttons, and the tabs stand on the title line, right of it
	-- (the kit header put the title 150 px in and the tabs a row lower: capture OwnedGarage.Browser | Mine).
	local topLeft = layer.Slot("TopLeft")
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.BorderSizePixel = 0
	head.Position = topLeft.Position
	head.Parent = layer.Root
	local header = Controls.Header(head, { Title = "GARAGES" }, scope)
	local tabs
	tabs = Controls.Tabs(head, {
		Tabs = {
			{ Id = TAB_MINE, Text = "MY GARAGES", Icon = "garage" },
			{ Id = TAB_VISIT, Text = "VISIT", Icon = "players" },
		},
		Selected = TAB_MINE,
		OnSelected = function(id)
			if rendering then
				return
			end
			model:SetMode(id)
			-- The kit tab has switched already; the model ignores the press while it is busy and then draws
			-- nothing, so the tab is put back on the model's mode here. Select reports nothing.
			local mode = model:Snapshot().Mode == "Visit" and TAB_VISIT or TAB_MINE
			if mode ~= id then
				tabs.Select(mode)
			end
		end,
	}, scope)

	-- The status strip of every menu: display spaces of the selected garage, and Cash from leaderstats (API2 3.5).
	local topRight = layer.Slot("TopRight")
	local cluster = Data.StatusCluster(topRight, { Mode = "Garage", Spaces = "", ShowPlus = false }, scope)
	-- TopRight is a zero-size slot: the strip stands on the slot's anchor, so it ends at the margin.
	cluster.Instance.AnchorPoint = topRight.AnchorPoint
	if cashPlayer and cluster.Cash then
		cluster.Cash.Bind(cashPlayer)
	end

	-- The garage list (Classic 22-23, reserved name GarageList; rows keep the Classic names Garage_<id>, Visit_<id>).
	local listHolder = Instance.new("Frame")
	listHolder.Name = "ListHolder"
	listHolder.BackgroundTransparency = 1
	listHolder.BorderSizePixel = 0
	listHolder.Parent = head
	local list = Collections.List(listHolder, {
		Width = listWidth(),
		OnSelected = function(key)
			if rendering then
				return
			end
			model:SelectKey(key)
		end,
	}, scope)
	Input.Mark(list.Instance, "GarageList")

	-- The detail. Regular (preview r05): picture and name across the top, description and facts side by side under
	-- it, three panels. Compact: ONE panel (the picture panel) that holds all three; layout() moves the description
	-- and facts boxes into it and hides the other two panels. The holder and its panels are sized and placed in
	-- code by layout(): the holder ends at the right margin (the right edge of slot RightColumn) and starts level
	-- with the list.
	local rightColumn = layer.Slot("RightColumn")
	local detailHolder = Instance.new("Frame")
	detailHolder.Name = "DetailHolder"
	detailHolder.BackgroundTransparency = 1
	detailHolder.BorderSizePixel = 0
	detailHolder.AnchorPoint = Vector2.new(1, 0)
	detailHolder.Position = UDim2.fromScale(1, 0)
	detailHolder.Parent = rightColumn

	local function plainBox(name, parent)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = parent
		return frame
	end

	local hero = Surface.Panel(detailHolder, { Name = "GarageImage", Width = space.ListWidth, Height = space.TileHeight }, scope)
	local heroImage = Instance.new("ImageLabel")
	heroImage.Name = "Image"
	heroImage.BackgroundTransparency = 1
	heroImage.BorderSizePixel = 0
	heroImage.Size = UDim2.fromScale(1, 1)
	heroImage.ScaleType = Enum.ScaleType.Crop
	heroImage.Visible = false
	heroImage.Parent = hero.Content
	local heroLabels = plainBox("Labels", hero.Content)
	local heroLayout = Instance.new("UIListLayout")
	heroLayout.Name = "Layout"
	heroLayout.FillDirection = Enum.FillDirection.Vertical
	heroLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	heroLayout.SortOrder = Enum.SortOrder.LayoutOrder
	heroLayout.Parent = heroLabels
	local district = Text.Label(heroLabels, { Name = "District", Text = "", Role = "Label", Colour = "TextSecondary", Align = "Left", LayoutOrder = 1 }, scope)
	local title = Text.Label(heroLabels, { Name = "GarageTitle", Text = "", Role = "SectionHead", Align = "Left", Shadow = true, LayoutOrder = 2 }, scope)

	local about = Surface.Panel(detailHolder, { Name = "About", Width = space.ListWidth, Height = space.TileHeight }, scope)
	-- Wrap with no MaxWidth: the text fills the width of its box, whatever layout() makes it. The box is the About
	-- panel's content on Regular; on Compact it is a clipped box of whole lines in the one panel.
	local aboutBox = plainBox("AboutBox", about.Content)
	local description = Text.Label(aboutBox, {
		Name = "Description",
		Text = "",
		Role = "Body",
		Colour = "TextSecondary",
		Align = "Left",
		Wrap = true,
		Upper = false,
	}, scope)

	local factsPanel = Surface.Panel(detailHolder, { Name = "Facts", Width = space.ListWidth, Height = space.TileHeight }, scope)
	local factsBox = plainBox("FactsBox", factsPanel.Content)
	local facts = Data.FactList(factsBox, { Rows = {} }, scope)
	-- What the detail last drew; layout() reads it (set by Render).
	local shown = { District = "", Title = "", Description = "", Picture = false }

	-- Footer: EXIT, then the main action (Classic 44-45; reserved names Exit and Enter).
	-- Only the buttons that show are in the row; the Enter mark is the row entry's MarkKey.
	local function onExit()
		model:Close()
	end
	local function onEnter()
		model:Enter()
	end
	local buttons = Controls.ButtonRow(layer.Slot("BottomRight"), {
		Align = "Right",
		Buttons = Controller._footerButtons({ Visible = true, Enabled = true, Text = "ENTER GARAGE" }, onExit, onEnter),
	}, scope)

	-- The status line (Classic 41, 60): Danger for a failure, Cyan for progress.
	local status = Text.Label(layer.Slot("BottomLeft"), { Name = "Status", Text = "", Role = "Label", Colour = "Danger", Align = "Left", Visible = false }, scope)
	status.Instance.AnchorPoint = Vector2.new(0, 1)

	-- The "garage full" choice (Classic 94-106), built on first open.
	local MAX_REPLACEMENT_ROWS = 5 -- rows shown before the list scrolls (the default of the kit list)
	local replacementList
	local replacementBody
	local replacementHolder
	local replacementCount = 0
	local replacementKey = nil -- the slots the open modal's focus trap was entered with
	local fitModal
	local modal
	modal = Overlay.Modal(layer.Root, {
		Title = "GARAGE FULL",
		Width = modalWidth(),
		-- An explicit height, always: with none the kit panel fills its parent and the notice was screen-tall.
		-- fitModal() replaces this start value with the height of what the panel holds.
		Height = space.StatPanelHeight,
		Scrim = "Confirm",
		Build = function(content, modalScope)
			-- The body is a plain frame: without a layout the text and the list both stood at its top-left.
			local column = Instance.new("UIListLayout")
			column.Name = "Column"
			column.FillDirection = Enum.FillDirection.Vertical
			column.SortOrder = Enum.SortOrder.LayoutOrder
			column.Padding = UDim.new(0, ctx.Px(space.Gap))
			column.Parent = content
			-- Wrap with no MaxWidth: the text fills the panel content width.
			replacementBody = Text.Label(content, {
				Name = "Body",
				Text = "Choose the display vehicle to replace. The replaced vehicle stays owned.",
				Role = "Body",
				Colour = "TextSecondary",
				Align = "Left",
				Wrap = true,
				Upper = false,
				LayoutOrder = 1,
			}, modalScope)
			-- The list fills this holder, which fitModal() sizes to the rows it shows.
			replacementHolder = Instance.new("Frame")
			replacementHolder.Name = "Slots"
			replacementHolder.BackgroundTransparency = 1
			replacementHolder.BorderSizePixel = 0
			replacementHolder.LayoutOrder = 2
			replacementHolder.Size = UDim2.new(1, 0, 0, ctx.Px(space.ListRowHeight))
			replacementHolder.Parent = content
			-- No OnSelected: see _replacementRows.
			replacementList = Collections.List(replacementHolder, {}, modalScope)
			modalScope:connect(replacementBody.Instance:GetPropertyChangedSignal("AbsoluteSize"), function()
				fitModal()
			end)
		end,
		Buttons = {
			Align = "Right",
			Buttons = {
				{
					Id = "Cancel",
					Variant = "Default",
					Text = "CANCEL",
					Icon = "close",
					OnActivated = function()
						model:CancelReplacement()
					end,
				},
			},
		},
		OnClose = function()
			if rendering then
				return
			end
			model:CancelReplacement()
		end,
	}, scope)

	-- Sizes the "garage full" panel to what it holds (title row, text, up to MAX_REPLACEMENT_ROWS rows, footer),
	-- and never taller than the screen less a margin: then the list holder shrinks and the list scrolls.
	fitModal = function()
		local content = modal.Content
		if not (content and replacementList and replacementHolder and replacementBody) then
			return
		end
		local compact = isCompact()
		local pad = ctx.Px(space.Pad)
		local gap = ctx.Px(space.Gap)
		local rowHeight = math.max(ctx.Px(compact and space.TouchMin or space.ListRowHeight), ctx.Touch(1))
		local rows = math.clamp(replacementCount, 1, MAX_REPLACEMENT_ROWS)
		local listHeight = rows * rowHeight + (rows - 1) * gap
		local textHeight = replacementBody.Instance.AbsoluteSize.Y
		if textHeight <= 0 then
			textHeight = ctx.Px(space.TouchMin) -- not laid out yet: about two lines; the signal corrects it
		end
		local footer = (compact and ctx.Touch(space.CompactButtonDrawn) or ctx.Px(space.ButtonHeight)) + pad
		local chrome = 2 * pad + content.Position.Y.Offset + textHeight + gap + footer
		local room = math.max(0, ctx.Size.Y - 2 * ctx.Px(space.CompactMargin))
		local total = math.max(chrome + rowHeight, math.min(chrome + listHeight, room))
		put(replacementHolder, "Size", UDim2.new(1, 0, 0, total - chrome))
		modal.Set({ Width = modalWidth(), Height = math.floor(total / ctx.Scale) })
	end

	-- A panel sized and placed in real pixels (Surface.Panel takes design values and writes only its Size).
	local function box(panel, x, y, width, height)
		local scale = ctx.Scale
		panel.Set({ Width = math.max(1, width) / scale, Height = math.max(1, height) / scale })
		put(panel.Instance, "Position", UDim2.fromOffset(x, y))
	end

	-- Puts a box of the detail in `parent`, at a place and size in real px, or filling it (width nil).
	local function seat(frame, parent, x, y, width, height)
		put(frame, "Parent", parent)
		put(frame, "ClipsDescendants", width ~= nil)
		put(frame, "Position", UDim2.fromOffset(x or 0, y or 0))
		put(frame, "Size", width and UDim2.fromOffset(math.max(1, width), math.max(0, height)) or UDim2.fromScale(1, 1))
	end

	-- Compact: the lines the description needs at its present width and its line pitch, both from the label's own
	-- laid-out height (a UIScale above the stage is divided out through the holder's known width).
	local function descriptionLines()
		local textSize = Text.SizeFor("Body", ctx)
		if shown.Description == "" then
			return 0, textSize
		end
		local scale = 1
		local known = detailHolder.Size.X.Offset
		if known > 0 and detailHolder.AbsoluteSize.X > 0 then
			scale = detailHolder.AbsoluteSize.X / known
		end
		local needed = description.Instance.AbsoluteSize.Y / scale
		local lines = math.max(1, math.floor(needed / textSize + 0.01))
		return lines, math.max(textSize, needed / lines)
	end

	local function place()
		local compact = isCompact()
		local gap = ctx.Px(space.Gap)
		local pad = ctx.Px(space.Pad)
		local keepGap = ctx.Px(space.CompactKeepOutGap)
		local slotX, slotY = topLeft.Position.X.Offset, topLeft.Position.Y.Offset
		local rootHeight = layer.Root.AbsoluteSize.Y
		if rootHeight <= 0 then
			rootHeight = ctx.Size.Y
		end

		-- The head: where it stands, and `top`, the distance from it to the list.
		local titleHeight = header.Height()
		local tabsSize = tabs.Instance.Size
		local headY, top, height = slotY, 0, 0
		if compact then
			-- Under the Roblox buttons. The tabs are a touch size high and their text is centred in that, so they
			-- are centred on the title line; they start clear of the Roblox buttons, because their box rises
			-- above the title.
			local barBottom = math.max(0, math.floor(ctx.TopBarHeight - ctx.Origin.Y + HALF))
			headY = math.max(slotY, barBottom + keepGap)
			local clearX = math.ceil(ctx.TopBarKeepOut.X - ctx.Origin.X) + keepGap - layer.Root.Position.X.Offset - slotX
			local tabsY = math.floor((titleHeight - tabsSize.Y.Offset) * HALF)
			put(tabs.Instance, "Position", UDim2.fromOffset(math.max(header.Instance.Size.X.Offset + pad, clearX), tabsY))
			top = titleHeight + keepGap
			if tabs.Instance.Visible then
				top = math.max(top, tabsY + tabsSize.Y.Offset)
			end
			-- The list ends at the top of the button row (a touch size high, the drawn button centred in it).
			local rowHeight = buttons.Instance.Size.Y.Offset
			height = math.max(0, math.floor(rootHeight - ctx.Px(space.CompactBottom) - rowHeight - headY - top))
			put(status.Instance, "Position", UDim2.fromOffset(0, -math.max(0, math.floor((rowHeight - status.Instance.Size.Y.Offset) * HALF))))
		else
			-- As the kit header stacks them: the title row, HeaderTabsGap, the tab row (counted when hidden too).
			local tabsY = titleHeight + ctx.Px(space.HeaderTabsGap)
			put(tabs.Instance, "Position", UDim2.fromOffset(0, tabsY))
			top = tabsY + tabsSize.Y.Offset + gap
			local reserve = ctx.Px(space.MenuBottom) + ctx.Px(space.ButtonHeight)
			height = math.max(0, math.floor(rootHeight - slotY - top - reserve - 2 * gap))
			put(status.Instance, "Position", UDim2.fromOffset(0, 0))
		end
		put(head, "Position", UDim2.fromOffset(slotX, headY))

		-- The list column: about a third of the content width on Regular (r05).
		local listPx = ctx.Px(listWidth())
		list.Set({ Width = listWidth() })
		put(listHolder, "Position", UDim2.fromOffset(0, top))
		put(listHolder, "Size", UDim2.fromOffset(listPx, height))

		-- The detail takes what is left of the content width, right of the list; it starts level with the list
		-- and never above the right column's top, which keeps it clear of the status strip.
		local contentWidth = rightColumn.Position.X.Offset - slotX
		local columnGap = compact and keepGap or (pad + pad)
		local detailWidth = math.max(0, contentWidth - listPx - columnGap)
		local listTop = headY + top
		local detailTop = math.max(0, listTop - rightColumn.Position.Y.Offset)
		local available = math.max(0, height - (rightColumn.Position.Y.Offset + detailTop - listTop))
		local rows = math.max(MIN_FACT_ROWS, factCount)
		local detailHeight
		if compact then
			-- One panel, never taller than the list beside it, which ends above the button row.
			local inner = math.max(1, detailWidth - 2 * keepGap)
			local lines, line = descriptionLines()
			local plan = Controller._compactPlan({
				Available = available,
				Width = inner,
				Pad = keepGap,
				Gap = keepGap,
				Labels = title.Instance.Size.Y.Offset + (shown.District ~= "" and district.Instance.Size.Y.Offset or 0),
				Facts = factCount > 0 and facts.Instance.Size.Y.Offset or 0,
				FactsWidth = ctx.Px(space.CompactStatPanelWidth),
				TextWidth = ctx.Px(space.CompactPromptWidth),
				Line = line,
				Lines = lines,
				MaxLines = DESCRIPTION_LINES,
				Picture = shown.Picture,
			})
			hero.Set({ Pad = space.CompactKeepOutGap, Visible = shown.Title ~= "" or shown.Description ~= "" or factCount > 0 })
			about.Set({ Visible = false })
			factsPanel.Set({ Visible = false })
			box(hero, 0, 0, detailWidth, plan.Height)
			put(heroImage, "Size", UDim2.new(1, 0, 0, plan.Band))
			put(heroLabels, "Size", UDim2.new(1, 0, 0, plan.Band))
			put(heroLabels, "ClipsDescendants", true) -- a long name ends at the panel edge
			seat(aboutBox, hero.Content, 0, plan.AboutY, plan.AboutWidth, plan.About)
			seat(factsBox, hero.Content, plan.FactsX, plan.FactsY, plan.FactsWidth, plan.FactsHeight)
			detailHeight = plan.Height
		else
			hero.Set({ Pad = space.Pad, Visible = true })
			about.Set({ Visible = true })
			factsPanel.Set({ Visible = true })
			put(heroImage, "Size", UDim2.fromScale(1, 1))
			put(heroLabels, "Size", UDim2.fromScale(1, 1))
			put(heroLabels, "ClipsDescendants", false)
			seat(aboutBox, about.Content)
			seat(factsBox, factsPanel.Content)
			-- Facts take half the width, so a long value (a district name) has room beside its label.
			local lowerHeight = rows * ctx.Px(space.FactRowHeight) + pad + pad
			local factsWidth = math.floor((detailWidth - gap) / 2)
			local heroHeight = math.clamp(available - gap - lowerHeight, ctx.Px(space.ListRowHeight), ctx.Px(space.StatPanelHeight))
			box(hero, 0, 0, detailWidth, heroHeight)
			box(about, 0, heroHeight + gap, detailWidth - gap - factsWidth, lowerHeight)
			box(factsPanel, detailWidth - factsWidth, heroHeight + gap, factsWidth, lowerHeight)
			detailHeight = heroHeight + gap + lowerHeight
		end
		put(detailHolder, "Position", UDim2.new(1, 0, 0, detailTop))
		put(detailHolder, "Size", UDim2.fromOffset(detailWidth, detailHeight))

		modal.Set({ Width = modalWidth() })
		fitModal()
	end

	-- place() moves things whose size signals call layout() again; such a call is taken up after the pass that is
	-- running, a few times at most (every write is skipped when the value is already there, so it settles).
	local MAX_PASSES = 4
	local laying, again = false, false
	local function layout()
		if laying then
			again = true
			return
		end
		laying = true
		local ok, problem = true, nil
		for _ = 1, MAX_PASSES do
			again = false
			ok, problem = xpcall(place, debug.traceback)
			if not ok or not again then
				break
			end
		end
		laying = false
		if not ok then
			error(problem, 0)
		end
	end
	layout()

	local lastImage = nil
	function view.Render(_reason)
		rendering = true
		local ok, problem = xpcall(function()
			local snapshot = model:Snapshot()

			tabs.Set({ Visible = snapshot.TabsVisible })
			if snapshot.TabsVisible then
				tabs.Select(snapshot.Mode == "Visit" and TAB_VISIT or TAB_MINE)
			end

			local items = {}
			for index, row in ipairs(snapshot.Rows) do
				items[index] = {
					Key = row.Key,
					Title = row.Title,
					Sub = row.Sub,
					Image = Compat.Asset(row.Image),
					State = row.Selected and "Selected" or "Default",
				}
			end
			list.SetItems(items)
			for _, item in ipairs(items) do
				local component = list.Row(item.Key)
				if component then
					component.Instance.Name = item.Key
				end
			end
			if snapshot.SelectedKey then
				list.Select(snapshot.SelectedKey)
			end

			local detail = snapshot.Detail
			cluster.Set({ Spaces = detail.Spaces or "" })
			title.Set({ Text = detail.Title })
			district.Set({ Text = detail.District })
			description.Set({ Text = detail.Description })
			local image = Compat.Asset(detail.Image)
			if image ~= lastImage then
				lastImage = image
				heroImage.Image = image
				heroImage.Visible = image ~= ""
			end
			local rows = {}
			for index, fact in ipairs(detail.Facts) do
				rows[index] = { Id = fact.Id, Label = fact.Label, Value = fact.Value, Kind = "Text" }
			end
			facts.SetRows(rows)
			factCount = #rows
			shown.District = tostring(detail.District or "")
			shown.Title = tostring(detail.Title or "")
			shown.Description = tostring(detail.Description or "")
			shown.Picture = image ~= ""
			layout()

			buttons.Set({ Buttons = Controller._footerButtons(snapshot.Enter, onExit, onEnter) })

			local line = snapshot.Status
			status.Set({ Visible = line.Visible, Text = line.Text, Colour = line.Good and "Cyan" or "Danger" })

			local replacement = snapshot.Replacement
			if replacement then
				if not replacementList then
					modal.Open() -- first use: Open builds the content
				end
				if replacementList then
					local rows = Controller._replacementRows(replacement.Slots, function(index)
						if not rendering then
							model:ChooseReplacement(index)
						end
					end)
					local parts = {}
					for index, row in ipairs(rows) do
						parts[index] = row.Title
					end
					local key = table.concat(parts, "\31")
					replacementCount = #rows
					replacementList.SetItems(rows)
					fitModal()
					-- The modal's focus trap lists the buttons present at Open, so it is entered after the rows
					-- exist, and again when the rows change. `rendering` is true: OnClose tells the model nothing.
					if modal.IsOpen() and key ~= replacementKey then
						modal.Close()
					end
					replacementKey = key
				end
				if not modal.IsOpen() then
					modal.Open()
				end
			else
				replacementKey = nil
				if modal.IsOpen() then
					modal.Close()
				end
			end
		end, debug.traceback)
		rendering = false
		if not ok then
			error(problem, 0)
		end
	end

	-- Deferred: the kit components and the slots answer the same signal, and layout() reads their new sizes.
	scope:connect(ctx.Changed, function(change)
		if type(change) == "table" and change.Layout then
			task.defer(layout)
		end
	end)
	scope:connect(header.Instance:GetPropertyChangedSignal("Size"), layout)
	scope:connect(tabs.Instance:GetPropertyChangedSignal("Size"), layout)
	scope:connect(buttons.Instance:GetPropertyChangedSignal("Size"), layout)
	scope:connect(rightColumn:GetPropertyChangedSignal("Position"), layout)
	-- Compact: the description's height says how many lines it needs; it changes when the text or its width does.
	scope:connect(description.Instance:GetPropertyChangedSignal("AbsoluteSize"), function()
		if isCompact() then
			layout()
		end
	end)

	function view.Destroy()
		scope:destroy()
	end
	return view
end

local function connectionScope()
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local core = modules and modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")
	return require(scopeModule)
end

function Controller.Start()
	if started then
		return true, "AlreadyStarted"
	end
	local pulse = script.Parent.Parent
	local kit = pulse.Kit
	local Layers = require(kit.Layers)
	local Presence = require(kit.Presence)
	local Model = require(script.Parent.OwnedGarageBrowserModel)
	local Scope = connectionScope()

	-- The waits Classic makes at lines 7-9, and no others.
	local player = Players.LocalPlayer
	player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("Remotes").Garage
	local remote = remotes:WaitForChild("OwnedGarageInvoke")
	local push = remotes:WaitForChild("OwnedGarageEvent")
	local runtimeUi = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI")
	local openEvent = runtimeUi:WaitForChild("OpenOwnedGarageBrowser")
	local loadingInvoke = runtimeUi:WaitForChild("LoadingTransitionInvoke")

	local layer = Layers.Create(LAYER_NAME, { Frame = "Menu", Scrim = true })
	layer.SetVisible(false)

	local scope = Scope.new()
	local view = nil
	local viewFailed = false
	local model = Model.new({
		Remotes = { OwnedGarageInvoke = remote, OwnedGarageEvent = push },
		Bindables = { LoadingTransitionInvoke = loadingInvoke },
		RuntimeUi = runtimeUi,
		Player = player,
		Workspace = Workspace,
		CanOpen = function()
			return view ~= nil
		end,
	})

	-- The view is built here, once. If a kit call fails the browser stays closed and says so, while the model keeps
	-- answering stream requests and exit prompts, which need no screen.
	local built, problem = xpcall(function()
		view = Controller._mount(layer, model, Scope.new(), kit, player)
	end, debug.traceback)
	if not built then
		view = nil
		viewFailed = true
		warn("[Pulse.OwnedGarageBrowserUI] view build failed; the browser will not open: " .. tostring(problem))
	end

	local releasePresence = nil
	local function apply(reason)
		local open = model:IsOpen()
		if open and not releasePresence then
			releasePresence = Presence.Open(PRESENCE_SURFACE, "FullMenu")
		elseif not open and releasePresence then
			releasePresence()
			releasePresence = nil
		end
		if view and (open or reason == "close") then
			local ok, renderProblem = pcall(view.Render, reason)
			if not ok and not viewFailed then
				viewFailed = true
				warn("[Pulse.OwnedGarageBrowserUI] render failed: " .. tostring(renderProblem))
			end
		end
		layer.SetVisible(open)
	end
	scope:connect(model.Changed, apply)

	closeCurrent = function(reason)
		model:Close(reason)
	end
	isOpenCurrent = function()
		return model:IsOpen()
	end

	scope:connect(openEvent.Event, function()
		model:Toggle()
	end)
	scope:connect(ProximityPromptService.PromptTriggered, function(prompt, triggeringPlayer)
		model:OnPromptTriggered(prompt, triggeringPlayer)
	end)
	scope:connect(player:GetAttributeChangedSignal("OwnedGarageInside"), function()
		model:OnInsideChanged()
	end)
	scope:connect(push.OnClientEvent, function(message)
		model:OnPush(message)
	end)

	Controller.Model = model
	Controller.Layer = layer
	started = true
	return true, "Started"
end

return Controller
