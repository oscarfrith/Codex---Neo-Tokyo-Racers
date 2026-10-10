-- Owns the drawing of the race and time-trial results (hero numbers, strip, laps or highlights, pooled table, two buttons) over a results model; no remote, bindable or attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceSession.ResultsView. Requires: Tokens, Text, Surface, Controls, Collections, Data, BigNumber, Input, Presence.
--
-- View.Mount(layer, model, scope, options?) -> { Render, Destroy }
--   layer    UnifiedRaceResults (Menu frame, with a scrim gui); options = { NoPresence: boolean? }
-- Regular (r15a, r15b): one centred column from the top, buttons bottom centre.
-- Compact (c10): header and hero numbers top left, the table top right, buttons bottom right.
-- The two buttons are built first and set first; every other part is optional and guarded, so a part that fails to
-- build or draw is skipped with a warning and the player still has EXIT TO START.
local GuiService = game:GetService("GuiService")

local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Text = require(Kit.Text)
local Surface = require(Kit.Surface)
local Controls = require(Kit.Controls)
local Collections = require(Kit.Collections)
local Data = require(Kit.Data)
local BigNumber = require(Kit.BigNumber)
local Input = require(Kit.Input)
local Presence = require(Kit.Presence)

local Space = Tokens.Space

local View = {}

View.TABLE_ROWS = 6 -- r15a and r15b show six rows; the window follows the local player (budget: results 150)
View.TABLE_ROWS_COMPACT = 5 -- a Compact row is a touch target high, so five fit above the buttons
View.COMPACT_COLUMNS = 3 -- c10: position, player, time; a fourth column cuts the times short at this width
View.YOU_KEY = "you" -- the list key of the local player's row, so the list's selection follows the player
View.FACT_ROWS = 4
View.COMPACT_MONEY_FROM = 1000000 -- the secondary number has eight cells: "$999,999", then "$1.2M"
View.STRIP_SEPARATOR = "     "

local function put(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function holder(name, parent, direction, anchored)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.AutomaticSize = Enum.AutomaticSize.XY
	if anchored then
		frame.AnchorPoint = parent.AnchorPoint
	end
	local list = Instance.new("UIListLayout")
	list.Name = "Layout"
	list.FillDirection = direction
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	frame.Parent = parent
	return frame, list
end

-- One string that changes exactly when the rows do, so an unchanged table is not handed to the list again.
function View._signature(rows)
	local pieces = {}
	for _, row in ipairs(rows) do
		table.insert(pieces, tostring(row.Key))
		table.insert(pieces, row.You and "1" or "0")
		for _, text in ipairs(row.Columns) do
			table.insert(pieces, text)
		end
	end
	return table.concat(pieces, "\31")
end

-- The strip text: "LABEL VALUE" items in one line. Chip items are drawn by the chip, not here.
function View._stripText(items)
	local pieces = {}
	for _, item in ipairs(items) do
		if item.Kind ~= "Chip" then
			table.insert(pieces, item.Label ~= "" and (item.Label .. " " .. item.Value) or item.Value)
		end
	end
	return table.concat(pieces, View.STRIP_SEPARATOR)
end

function View._xpText(xp)
	if xp.State == "Xp" then
		return "DRIVER XP", string.format("%+d", math.round(tonumber(xp.Gain) or 0))
	elseif xp.State == "Rank" then
		return "RANK UP", tostring(xp.Rank)
	end
	return nil, nil
end

-- Runs one optional part. A part that fails is reported and skipped: it must never take the buttons with it.
function View._guard(what, body)
	local ok, problem = pcall(body)
	if not ok then
		warn("[Pulse.ResultsView] " .. what .. " failed: " .. tostring(problem))
	end
	return ok
end
local guard = View._guard

-- Kit.Data.Money needs the Classic formatter module; the results still draw the amount when it is not there.
function View._money(amount, compact)
	local ok, text = pcall(Data.Money, amount, compact)
	if ok and type(text) == "string" then
		return text
	end
	local digits = tostring(math.max(0, math.floor(tonumber(amount) or 0)))
	local changed
	repeat
		digits, changed = string.gsub(digits, "^(%d+)(%d%d%d)", "%1,%2")
	until changed == 0
	return "$" .. digits
end

-- The first `limit` columns of a row or header (Compact drops the vehicle column).
function View._columns(columns, limit)
	if #columns <= limit then
		return columns
	end
	local cut = table.create(limit)
	for index = 1, limit do
		cut[index] = columns[index]
	end
	return cut
end

function View.Mount(layer, model, scope, options)
	options = options or {}
	local ctx = layer.Metrics
	local parts = nil
	local destroyed = false
	local shown = nil
	local releasePresence = nil
	local render -- assigned below; build's title listener calls it

	local function destroyParts()
		local old = parts
		if not old then
			return
		end
		parts = nil
		for _, component in ipairs(old.Components) do
			component.Destroy()
		end
		for _, frame in ipairs(old.Frames) do
			frame:Destroy()
		end
	end

	local function build()
		local compact = ctx.Class == "Compact"
		local p = { Class = ctx.Class, Compact = compact, Components = {}, Frames = {}, Lists = {},
			Rows = compact and View.TABLE_ROWS_COMPACT or View.TABLE_ROWS,
			Columns = compact and View.COMPACT_COLUMNS or math.huge }
		-- Set before anything is built, so whatever was built can be destroyed if a later part fails.
		parts = p
		local function keep(component)
			table.insert(p.Components, component)
			return component
		end
		-- `spaced` lists take the standard gap in ApplyLayout; the hero and strip rows set their own.
		local function frame(name, parent, direction, anchored, spaced)
			local item, list = holder(name, parent, direction, anchored)
			table.insert(p.Frames, item)
			if spaced ~= false then
				table.insert(p.Lists, list)
			end
			return item, list
		end
		local centre = compact and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
		local align = compact and "Left" or "Centre"

		-- The way out is built first and outside every guard: exit left, again right and main. The buttons exist
		-- before the leaderboard reply (API2 5.5) and whatever happens to the parts below.
		p.Buttons = keep(Controls.ButtonRow(layer.Slot(compact and "BottomRight" or "BottomCentre"), {
			Name = "Footer",
			Align = compact and "Right" or "Centre",
			Place = "Slot",
			Buttons = {
				{ Id = "exit", Variant = "Default", Text = "EXIT TO START", Icon = "exit", OnActivated = function()
					model.Exit()
				end },
				{ Id = "again", Variant = "Main", Text = "RACE AGAIN", Icon = "loop", OnActivated = function()
					model.Again()
				end },
			},
		}, scope))

		guard("scrim", function()
			local scrim = keep(Surface.Scrim(layer.ScrimRoot or layer.Root, { Name = "ResultsScrim", Kind = "Menu" }, scope))
			-- On a stage there is no scrim gui: the tint shares the root with the slots and must draw under them.
			scrim.Instance.ZIndex = 0
		end)

		local column, columnList =
			frame("Results", layer.Slot(compact and "TopLeft" or "TopCentreHud"), Enum.FillDirection.Vertical, true)
		columnList.HorizontalAlignment = centre
		p.Column = column

		guard("header", function()
			if compact then
				p.Header = keep(Controls.Header(layer.Slot("TopLeft"), { Name = "Header", Title = "", Sub = "" }, scope))
			else
				local title = keep(Text.Label(column, { Name = "Title", Text = "", Role = "ScreenTitle", Align = "Centre",
					LayoutOrder = 1 }, scope))
				local sub = keep(Text.Label(column, { Name = "Sub", Text = "", Role = "Status", Colour = "TextSecondary",
					Align = "Centre", LayoutOrder = 2 }, scope))
				p.Title, p.Sub = title, sub
			end
		end)

		-- Hero numbers: primary (best lap, or cash in a race) and secondary (cash, or driver XP in a race).
		guard("hero numbers", function()
			local heroRow, heroList = frame("Hero", column, Enum.FillDirection.Horizontal, false, false)
			heroRow.LayoutOrder = 3
			heroList.VerticalAlignment = Enum.VerticalAlignment.Bottom
			local function hero(name, role, cells, order)
				local cell, cellList = frame(name, heroRow, Enum.FillDirection.Vertical, false)
				cell.LayoutOrder = order
				cellList.HorizontalAlignment = centre
				local label = keep(Text.Label(cell, { Name = "Heading", Text = "", Role = compact and "Status" or "SectionHead",
					Align = align, LayoutOrder = 1 }, scope))
				local number = keep(BigNumber.New(cell, { Name = "Value", Text = "0", Role = role, Align = align, MaxCells = cells,
					Fixed = false, LayoutOrder = 2 }, scope))
				return { Frame = cell, Label = label, Number = number }
			end
			local primary = hero("Primary", "Hero", 9, 1)
			local secondary = hero("Secondary", "Speed", 8, 2)
			p.HeroList = heroList
			p.Primary, p.Secondary = primary, secondary
		end)

		-- Strip: finish and time (race) or medal, personal-best chip and driver XP (time trial).
		guard("strip", function()
			local stripRow, stripList = frame("Strip", column, Enum.FillDirection.Horizontal, false, false)
			stripRow.LayoutOrder = 4
			stripList.VerticalAlignment = Enum.VerticalAlignment.Center
			local text = keep(Text.Label(stripRow, { Name = "Facts", Text = "", Role = "Status", Align = "Left", LayoutOrder = 1 }, scope))
			local chip = keep(Collections.Chip(stripRow, { Name = "PersonalBest", Text = "NEW PERSONAL BEST", Kind = "Pink",
				Visible = false, LayoutOrder = 2 }, scope))
			local xp = keep(Text.Label(stripRow, { Name = "DriverXp", Text = "", Role = "Status", Colour = "Pink", Align = "Left",
				Visible = false, LayoutOrder = 3 }, scope))
			p.StripList = stripList
			p.StripText, p.StripChip, p.StripXp = text, chip, xp
		end)

		-- Tables: the small fact list (Regular only) and the pooled table.
		local tableWidth = compact and Space.CompactSidePanelWidth or Space.ToastMaxWidth
		local rowHeight = compact and Space.CompactStatusHeight or Space.StatRowHeight
		local tableParent
		if compact then
			tableParent = layer.Slot("TopRight")
		else
			local tables, tablesList = frame("Tables", column, Enum.FillDirection.Horizontal, false)
			tables.LayoutOrder = 5
			tablesList.VerticalAlignment = Enum.VerticalAlignment.Top
			tableParent = tables
			guard("session laps", function()
				local facts = frame("SessionLaps", tables, Enum.FillDirection.Vertical, false)
				facts.LayoutOrder = 1
				-- Only the height follows the rows; the width is explicit (and kept in ApplyLayout).
				facts.AutomaticSize = Enum.AutomaticSize.Y
				facts.Size = UDim2.fromOffset(ctx.Px(Space.StatPanelWidth), 0)
				local heading = keep(Text.Label(facts, { Name = "Heading", Text = "", Role = "Label", Colour = "TextSecondary",
					Align = "Left", LayoutOrder = 1 }, scope))
				local list = keep(Data.FactList(facts, { Name = "Rows", Rows = {}, LayoutOrder = 2 }, scope))
				p.FactsFrame = facts
				p.FactsHeading, p.Facts = heading, list
			end)
		end
		guard("results table", function()
			local board = frame("RaceResults", tableParent, Enum.FillDirection.Vertical, compact)
			board.LayoutOrder = 2
			local heading = keep(Text.Label(board, { Name = "Heading", Text = "", Role = "Label", Colour = "TextSecondary",
				Align = "Left", LayoutOrder = 1 }, scope))
			-- The empty-state line sits under the heading, above the (then empty) rows.
			local message = keep(Text.Label(board, { Name = "Message", Text = "", Role = "Label", Colour = "TextMuted",
				Align = "Left", Visible = false, LayoutOrder = 2 }, scope))
			-- Sized before the list is built: the list fills a parent that has a height.
			local listBox = Instance.new("Frame")
			listBox.Name = "Rows"
			listBox.BackgroundTransparency = 1
			listBox.BorderSizePixel = 0
			listBox.LayoutOrder = 3
			listBox.Size = UDim2.fromOffset(ctx.Px(tableWidth), ctx.Px(rowHeight))
			listBox.Parent = board
			table.insert(p.Frames, listBox)
			local header = View._columns({ "POS", "PLAYER", "TIME", "VEHICLE" }, p.Columns)
			local list = keep(Collections.List(listBox, { Name = "List", RowHeight = rowHeight, Width = tableWidth,
				Header = header }, scope))
			p.ListBox = listBox
			p.Board = board
			p.HeaderKey = table.concat(header, "\31")
			p.TableHeading, p.Message, p.Table = heading, message, list
		end)

		function p.ApplyLayout()
			local gap = UDim.new(0, ctx.Px(Space.Gap))
			for _, list in ipairs(p.Lists) do
				put(list, "Padding", gap)
			end
			if p.HeroList then
				put(p.HeroList, "Padding", UDim.new(0, ctx.Px(Space.TabGap)))
			end
			if p.StripList then
				put(p.StripList, "Padding", UDim.new(0, ctx.Px(Space.Pad)))
			end
			if p.ListBox then
				-- A list row is never lower than a touch target (Collections.List), so the box follows that height:
				-- one row for the column header, then the rows.
				local rowPx = math.max(ctx.Px(rowHeight), ctx.Touch(1))
				if compact then
					-- Compact: as many rows as stand between the top edge and the buttons (five at 844 x 390, three
					-- at 568 x 320, where five ran under the buttons). A title long enough to reach the table (a
					-- server message) sends the table under the title row.
					local gapPx = ctx.Px(Space.Gap)
					local topRight = layer.Slot("TopRight").Position
					local drop = 0
					local title = p.Header and p.Header.Instance:FindFirstChild("Title")
					if title then
						local titleRight = layer.Slot("TopLeft").Position.X.Offset + title.Position.X.Offset + title.Size.X.Offset
						if titleRight + gapPx > topRight.X.Offset - ctx.Px(tableWidth) then
							drop = title.Position.Y.Offset + title.Size.Y.Offset + ctx.Px(Space.CompactKeepOutGap)
						end
					end
					if p.Board then
						put(p.Board, "Position", UDim2.fromOffset(0, drop))
					end
					local buttons = p.Buttons.Instance.Size.Y.Offset
					if buttons <= 0 then
						buttons = ctx.Touch(Space.CompactButtonDrawn)
					end
					local heading = Text.SizeFor("Label", ctx)
					local free = layer.Slot("BottomRight").Position.Y.Offset - buttons - gapPx
						- (topRight.Y.Offset + drop) - heading - gapPx
					p.Rows = math.clamp(math.floor(free / rowPx) - 1, 1, View.TABLE_ROWS_COMPACT)
				end
				put(p.ListBox, "Size", UDim2.fromOffset(ctx.Px(tableWidth), rowPx * (p.Rows + 1)))
			end
			if p.FactsFrame then
				put(p.FactsFrame, "Size", UDim2.fromOffset(ctx.Px(Space.StatPanelWidth), 0))
			end
			if p.Header then
				put(column, "Position", UDim2.fromOffset(0, p.Header.Height() + ctx.Px(Space.CompactKeepOutGap)))
			end
		end
		p.ApplyLayout()

		-- Compact: the title's width decides where the table starts and how many rows it has; the width arrives
		-- after the text is set, so the layout follows it and the table is drawn again when the row count changed.
		local titleLabel = compact and p.Header and p.Header.Instance:FindFirstChild("Title") or nil
		if titleLabel then
			scope:connect(titleLabel:GetPropertyChangedSignal("Size"), function()
				if destroyed or parts ~= p then
					return
				end
				local before = p.Rows
				guard("layout", p.ApplyLayout)
				if p.Rows ~= before then
					render()
				end
			end)
		end
	end

	local function buttonInstance(id)
		local button = parts and parts.Buttons and parts.Buttons.Button(id)
		return button and button.Instance or nil
	end

	local function setShown(open)
		if shown == open then
			return
		end
		shown = open
		layer.SetVisible(open)
		if not options.NoPresence then
			if open and not releasePresence then
				releasePresence = Presence.Open("RaceResults", "Results")
			elseif not open and releasePresence then
				local release = releasePresence
				releasePresence = nil
				release()
			end
		end
		local again, exit = buttonInstance("again"), buttonInstance("exit")
		if open then
			if again and again:IsDescendantOf(game) and Input.ShouldEnterFocus(ctx) then
				GuiService.SelectedObject = again
			end
		else
			local selected = GuiService.SelectedObject
			if selected ~= nil and (selected == again or selected == exit) then
				GuiService.SelectedObject = nil
			end
		end
	end

	render = function()
		if destroyed then
			return
		end
		local open = model.IsOpen()
		if not open then
			setShown(false)
			return
		end
		local p = parts

		-- The way out first: the buttons are set and the screen is shown before any optional part is drawn, so a
		-- part that fails (or waits) cannot leave the player without EXIT TO START.
		local busy = model.Busy()
		p.Buttons.Button("exit").Set({ Text = model.ExitText(), Disabled = busy })
		p.Buttons.Button("again").Set({ Text = model.AgainText(), Disabled = busy })
		setShown(true)

		local race = model.Mode() == "Race"
		local xpLabel, xpNumber = nil, nil
		guard("driver XP text", function()
			xpLabel, xpNumber = View._xpText(model.Xp())
		end)

		guard("header", function()
			if p.Header then
				p.Header.Set({ Title = model.Title(), Sub = model.SubTitle() })
			elseif p.Title then
				p.Title.Set({ Text = model.Title() })
				p.Sub.Set({ Text = model.SubTitle() })
			end
		end)
		if p.Header then
			guard("layout", p.ApplyLayout) -- before the table: it sets the Compact row count
		end

		if p.Primary then
			guard("hero numbers", function()
				local amount = model.RewardAmount()
				local cash = View._money(amount, amount >= View.COMPACT_MONEY_FROM)
				if race then
					p.Primary.Label.Set({ Text = "BANKED" })
					p.Primary.Number.Set({ Colour = "Yellow" })
					p.Primary.Number.SetText(cash)
					if xpLabel then
						p.Secondary.Label.Set({ Text = xpLabel })
						p.Secondary.Number.Set({ Colour = "Pink" })
						p.Secondary.Number.SetText(xpNumber)
					end
					put(p.Secondary.Frame, "Visible", xpLabel ~= nil)
				else
					p.Primary.Label.Set({ Text = "BEST LAP" })
					p.Primary.Number.Set({ Colour = "White" })
					p.Primary.Number.SetText(model.BestLapText())
					p.Secondary.Label.Set({ Text = "BANKED" })
					p.Secondary.Number.Set({ Colour = "Yellow" })
					p.Secondary.Number.SetText(cash)
					put(p.Secondary.Frame, "Visible", true)
				end
			end)
		end

		if p.StripText then
			guard("strip", function()
				if not race and xpLabel then
					p.StripXp.Set({ Text = xpLabel .. " " .. xpNumber, Visible = true })
				else
					p.StripXp.Set({ Visible = false })
				end
				local strip = model.Strip()
				local chip = false
				for _, item in ipairs(strip) do
					if item.Kind == "Chip" then
						chip = true
						p.StripChip.Set({ Text = item.Value })
					end
				end
				p.StripText.Set({ Text = View._stripText(strip) })
				p.StripChip.Set({ Visible = chip })
			end)
		end

		if p.Facts then
			guard("session laps", function()
				local heading, rows = model.Facts(View.FACT_ROWS)
				p.FactsHeading.Set({ Text = heading })
				local pieces = {}
				for _, row in ipairs(rows) do
					table.insert(pieces, row.Id .. "\31" .. row.Label .. "\31" .. row.Value)
				end
				local key = table.concat(pieces, "\31")
				if key ~= p.FactsKey then
					p.FactsKey = key
					p.Facts.SetRows(rows)
				end
			end)
		end

		if p.Table then
			guard("results table", function()
				local board = model.Table(p.Rows)
				p.TableHeading.Set({ Text = board.Heading })
				local header = View._columns(board.Header, p.Columns)
				local headerKey = table.concat(header, "\31")
				if headerKey ~= p.HeaderKey then
					p.HeaderKey = headerKey
					p.Table.Set({ Header = header })
				end
				local rowsKey = View._signature(board.Rows)
				if rowsKey ~= p.RowsKey then
					local items = {}
					local you = false
					for index, row in ipairs(board.Rows) do
						-- The list keeps its selection by key, so the player's row carries one key wherever it sits.
						local mine = row.You == true and not you
						you = you or mine
						items[index] = { Key = mine and View.YOU_KEY or row.Key, Columns = View._columns(row.Columns, p.Columns),
							-- Compact: the Pink bar alone marks the player's row; the White selected block is far
							-- brighter than anything else on a phone screen and nothing here is selectable.
							Accent = row.You == true, State = (mine and not p.Compact) and "Selected" or "Default" }
					end
					p.Table.SetItems(items)
					p.RowsKey = rowsKey
				end
				p.Message.Set({ Text = board.Message, Visible = board.Message ~= "" })
			end)
		end

		if p.Header then
			guard("layout", p.ApplyLayout)
		end
	end

	build()

	if ctx.Changed then
		scope:connect(ctx.Changed, function(change)
			if destroyed or (type(change) == "table" and change.Layout == false) then
				return
			end
			if parts and parts.Class ~= ctx.Class then
				destroyParts()
				build()
			elseif parts then
				parts.ApplyLayout()
			end
			render()
		end)
	end

	local view = {}
	view.Render = function(_reason)
		render()
	end
	view.Destroy = function()
		if destroyed then
			return
		end
		destroyed = true
		if releasePresence then
			local release = releasePresence
			releasePresence = nil
			release()
		end
		destroyParts()
	end
	view._parts = function()
		return parts
	end
	return view
end

return View
