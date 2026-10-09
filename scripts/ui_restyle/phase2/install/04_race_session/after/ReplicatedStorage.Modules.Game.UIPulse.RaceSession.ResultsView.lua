-- Owns the drawing of the race and time-trial results (hero numbers, strip, laps or highlights, pooled table, two buttons) over a results model; no remote, bindable or attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceSession.ResultsView. Requires: Tokens, Text, Surface, Controls, Collections, Data, BigNumber, Input, Presence.
--
-- View.Mount(layer, model, scope, options?) -> { Render, Destroy }
--   layer    UnifiedRaceResults (Menu frame, with a scrim gui); options = { NoPresence: boolean? }
-- Regular (r15a, r15b): one centred column from the top, buttons bottom centre.
-- Compact (c10): header and hero numbers top left, the table top right, buttons bottom right.
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
		return "DRIVER XP", string.format("%+d", xp.Gain)
	elseif xp.State == "Rank" then
		return "RANK UP", tostring(xp.Rank)
	end
	return nil, nil
end

function View.Mount(layer, model, scope, options)
	options = options or {}
	local ctx = layer.Metrics
	local parts = nil
	local destroyed = false
	local shown = nil
	local releasePresence = nil

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
		local p = { Class = ctx.Class, Compact = compact, Components = {}, Frames = {}, Lists = {} }
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

		keep(Surface.Scrim(layer.ScrimRoot or layer.Root, { Name = "ResultsScrim", Kind = "Menu" }, scope))

		local column, columnList
		if compact then
			p.Header = keep(Controls.Header(layer.Slot("TopLeft"), { Name = "Header", Title = "", Sub = "" }, scope))
			column, columnList = frame("Results", layer.Slot("TopLeft"), Enum.FillDirection.Vertical, true)
		else
			column, columnList = frame("Results", layer.Slot("TopCentreHud"), Enum.FillDirection.Vertical, true)
			p.Title = keep(Text.Label(column, { Name = "Title", Text = "", Role = "ScreenTitle", Align = "Centre", LayoutOrder = 1 }, scope))
			p.Sub = keep(Text.Label(column, { Name = "Sub", Text = "", Role = "Status", Colour = "TextSecondary", Align = "Centre",
				LayoutOrder = 2 }, scope))
		end
		columnList.HorizontalAlignment = centre
		p.Column = column

		-- Hero numbers: primary (best lap, or cash in a race) and secondary (cash, or driver XP in a race).
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
		p.Primary = hero("Primary", "Hero", 9, 1)
		p.Secondary = hero("Secondary", "Speed", 8, 2)

		-- Strip: finish and time (race) or medal, personal-best chip and driver XP (time trial).
		local stripRow, stripList = frame("Strip", column, Enum.FillDirection.Horizontal, false, false)
		stripRow.LayoutOrder = 4
		stripList.VerticalAlignment = Enum.VerticalAlignment.Center
		p.StripText = keep(Text.Label(stripRow, { Name = "Facts", Text = "", Role = "Status", Align = "Left", LayoutOrder = 1 }, scope))
		p.StripChip = keep(Collections.Chip(stripRow, { Name = "PersonalBest", Text = "NEW PERSONAL BEST", Kind = "Pink",
			Visible = false, LayoutOrder = 2 }, scope))
		p.StripXp = keep(Text.Label(stripRow, { Name = "DriverXp", Text = "", Role = "Status", Colour = "Pink", Align = "Left",
			Visible = false, LayoutOrder = 3 }, scope))

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
			local facts = frame("SessionLaps", tables, Enum.FillDirection.Vertical, false)
			facts.LayoutOrder = 1
			facts.AutomaticSize = Enum.AutomaticSize.Y
			p.FactsFrame = facts
			p.FactsHeading = keep(Text.Label(facts, { Name = "Heading", Text = "", Role = "Label", Colour = "TextSecondary",
				Align = "Left", LayoutOrder = 1 }, scope))
			p.Facts = keep(Data.FactList(facts, { Name = "Rows", Rows = {}, LayoutOrder = 2 }, scope))
		end
		local board = frame("RaceResults", tableParent, Enum.FillDirection.Vertical, compact)
		board.LayoutOrder = 2
		p.TableHeading = keep(Text.Label(board, { Name = "Heading", Text = "", Role = "Label", Colour = "TextSecondary",
			Align = "Left", LayoutOrder = 1 }, scope))
		local listBox = Instance.new("Frame")
		listBox.Name = "Rows"
		listBox.BackgroundTransparency = 1
		listBox.BorderSizePixel = 0
		listBox.LayoutOrder = 2
		listBox.Parent = board
		table.insert(p.Frames, listBox)
		p.Table = keep(Collections.List(listBox, { Name = "List", RowHeight = rowHeight, Width = tableWidth,
			Header = { "POS", "PLAYER", "TIME", "VEHICLE" } }, scope))
		p.HeaderKey = "POS\31PLAYER\31TIME\31VEHICLE"
		p.Message = keep(Text.Label(board, { Name = "Message", Text = "", Role = "Label", Colour = "TextMuted", Align = "Left",
			Visible = false, LayoutOrder = 3 }, scope))

		-- Buttons: exit left, again right and main. They exist before the leaderboard reply (API2 5.5).
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

		function p.ApplyLayout()
			local gap = UDim.new(0, ctx.Px(Space.Gap))
			for _, list in ipairs(p.Lists) do
				put(list, "Padding", gap)
			end
			put(heroList, "Padding", UDim.new(0, ctx.Px(Space.TabGap)))
			put(stripList, "Padding", UDim.new(0, ctx.Px(Space.Pad)))
			put(listBox, "Size", UDim2.fromOffset(ctx.Px(tableWidth), ctx.Px(rowHeight) * (View.TABLE_ROWS + 1)))
			if p.FactsFrame then
				put(p.FactsFrame, "Size", UDim2.fromOffset(ctx.Px(Space.StatPanelWidth), 0))
			end
			if p.Header then
				put(column, "Position", UDim2.fromOffset(0, p.Header.Height() + ctx.Px(Space.CompactKeepOutGap)))
			end
		end
		p.ApplyLayout()
		parts = p
	end

	local function buttonInstance(id)
		local button = parts and parts.Buttons.Button(id)
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

	local function render()
		if destroyed then
			return
		end
		local open = model.IsOpen()
		if not open then
			setShown(false)
			return
		end
		local p = parts
		local race = model.Mode() == "Race"
		local xp = model.Xp()
		local xpLabel, xpNumber = View._xpText(xp)

		if p.Header then
			p.Header.Set({ Title = model.Title(), Sub = model.SubTitle() })
		else
			p.Title.Set({ Text = model.Title() })
			p.Sub.Set({ Text = model.SubTitle() })
		end

		local amount = model.RewardAmount()
		local cash = Data.Money(amount, amount >= View.COMPACT_MONEY_FROM)
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
			p.StripXp.Set({ Visible = false })
		else
			p.Primary.Label.Set({ Text = "BEST LAP" })
			p.Primary.Number.Set({ Colour = "White" })
			p.Primary.Number.SetText(model.BestLapText())
			p.Secondary.Label.Set({ Text = "BANKED" })
			p.Secondary.Number.Set({ Colour = "Yellow" })
			p.Secondary.Number.SetText(cash)
			put(p.Secondary.Frame, "Visible", true)
			if xpLabel then
				p.StripXp.Set({ Text = xpLabel .. " " .. xpNumber, Visible = true })
			else
				p.StripXp.Set({ Visible = false })
			end
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

		if p.Facts then
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
		end

		local board = model.Table(View.TABLE_ROWS)
		p.TableHeading.Set({ Text = board.Heading })
		local headerKey = table.concat(board.Header, "\31")
		if headerKey ~= p.HeaderKey then
			p.HeaderKey = headerKey
			p.Table.Set({ Header = board.Header })
		end
		local rowsKey = View._signature(board.Rows)
		if rowsKey ~= p.RowsKey then
			p.RowsKey = rowsKey
			local items = {}
			for index, row in ipairs(board.Rows) do
				items[index] = { Key = row.Key, Columns = row.Columns, Accent = row.You == true,
					State = row.You and "Selected" or "Default" }
			end
			p.Table.SetItems(items)
		end
		p.Message.Set({ Text = board.Message, Visible = board.Message ~= "" })

		local busy = model.Busy()
		p.Buttons.Button("exit").Set({ Text = model.ExitText(), Disabled = busy })
		p.Buttons.Button("again").Set({ Text = model.AgainText(), Disabled = busy })

		if p.Header then
			p.ApplyLayout()
		end
		setShown(true)
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
