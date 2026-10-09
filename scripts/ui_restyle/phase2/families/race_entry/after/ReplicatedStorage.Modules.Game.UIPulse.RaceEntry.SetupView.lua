-- Owns the race-entry Setup page drawing (time-trial setup and race setup, their header, tier row and footer); it owns no state, calls no remote, fires no bindable and writes no attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceEntry.SetupView. Requires: Tokens, Text, Surface, Controls, Collections, Data, Input.
local kit = script.Parent.Parent.Kit
local Tokens = require(kit.Tokens)
local Text = require(kit.Text)
local Surface = require(kit.Surface)
local Controls = require(kit.Controls)
local Collections = require(kit.Collections)
local Data = require(kit.Data)
local Input = require(kit.Input)

local View = {}

local Space = Tokens.Space
local HALF = 0.5

-- Classic lets a player pick a tier they do not own (the targets show and the gate is on the footer). The kit's
-- Locked tab cannot be picked, so unowned tiers are drawn unlocked. Set true to trade that for the dimmed look.
local LOCK_UNOWNED_TIERS = false

-- The two mode tabs. The texts are the ones the marks set (Kit.Contracts.Marks "Text.TimeTrial", "Text.Race").
local MODE_TABS = {
	{ Id = "TimeTrial", Text = "TIME TRIAL", MarkKey = "Text.TimeTrial" },
	{ Id = "Race", Text = "RACE", MarkKey = "Text.Race" },
}

local function holder(name, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function picture(parent)
	local image = Instance.new("ImageLabel")
	image.Name = "Picture"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Size = UDim2.fromScale(1, 1)
	image.ScaleType = Enum.ScaleType.Fit
	image.Visible = false
	image.Parent = parent
	return image
end

local function put(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function place(instance, x, y, width, height)
	put(instance, "Position", UDim2.fromOffset(x, y))
	put(instance, "Size", UDim2.fromOffset(math.max(0, width), math.max(0, height)))
end

local function moveTo(instance, x, y)
	put(instance, "Position", UDim2.fromOffset(x, y))
end

local function setImage(image, id)
	put(image, "Image", id)
	put(image, "Visible", id ~= "")
end

-- A holder with a Panel filling it. `markKey` renames the holder through Input.Mark (the Panel root keeps the
-- kit's own name, which the kit may write again on a relayout).
local function panel(name, parent, markKey, scope)
	local frame = holder(name, parent)
	if markKey then
		Input.Mark(frame, markKey)
	end
	local surface = Surface.Panel(frame, {}, scope)
	return { Holder = frame, Panel = surface, Content = surface.Content }
end

function View.Mount(layer, model, scope)
	local ctx = layer.Metrics
	local topLeft = layer.Slot("TopLeft")
	local bottomRight = layer.Slot("BottomRight")
	local destroyed = false
	local header, trial, race = nil, nil, nil
	local signatures = {}
	local self = {}

	local function lineOf(role)
		local size, scale = Text.SizeFor(role, ctx)
		return math.ceil(size * (scale or 1))
	end

	-- Height of a kit list whose root may be sized by scale: its own offset, else rows of the row token.
	local function listHeight(component, count, compact)
		local height = component.Instance.Size.Y.Offset
		if height <= 0 then
			height = count * ctx.Px(compact and Space.StatRowHeight or Space.FactRowHeight)
		end
		return height
	end

	local function setRows(key, list, rows)
		local parts = {}
		for index, row in ipairs(rows) do
			parts[index] = row.Id .. "=" .. row.Label .. "=" .. row.Value
		end
		local signature = table.concat(parts, "|")
		if signatures[key] ~= signature then
			signatures[key] = signature
			list.SetRows(rows)
		end
	end

	local function tierItems(tiers)
		local items = {}
		for index, tier in ipairs(tiers) do
			items[index] = {
				Id = tier.Tier,
				Text = tier.Tier,
				Tier = tier.Tier,
				MarkKey = "Tier" .. tier.Tier,
				Locked = LOCK_UNOWNED_TIERS and not tier.Owned or nil,
			}
		end
		return items
	end

	-- Layout ----------------------------------------------------------------------------------------------------
	-- One function for both classes. Every number is a slot position, a kit component's own size or a token.

	local function layoutTrial(page, width, bottom, headerHeight, compact, gap, pad)
		local tabs = page.Tiers.Instance.Size
		local tabsWidth, tabsHeight = tabs.X.Offset, tabs.Y.Offset
		local bodyTop
		if compact then
			-- The tier buttons share the tab row, at the right edge.
			place(page.TierHolder, math.max(0, width - tabsWidth), math.max(0, headerHeight - tabsHeight), tabsWidth, tabsHeight)
			bodyTop = headerHeight + gap
		else
			place(page.TierHolder, 0, headerHeight + gap, tabsWidth, tabsHeight)
			bodyTop = headerHeight + gap + tabsHeight + gap
		end
		local rowHeight = page.Row.Instance.Size.Y.Offset
		local bodyHeight = math.max(0, bottom - rowHeight - gap - bodyTop)
		place(page.Body, 0, bodyTop, width, bodyHeight)

		local label, head = lineOf("Label"), lineOf("SectionHead")
		local chipHeight = math.max(page.PrizeChip.Instance.Size.Y.Offset, label)
		local prizeHeight = pad + label + gap + chipHeight + gap + label + pad
		local bestHeight = pad + label + gap + head + pad
		local mapWidth
		if compact then
			mapWidth = math.floor((width - gap - gap) * HALF)
			local middle = math.floor((width - gap - gap - mapWidth) * HALF)
			local right = width - gap - gap - mapWidth - middle
			local middleX = mapWidth + gap
			place(page.Best.Holder, middleX, 0, middle, bestHeight)
			place(page.Medals.Holder, middleX, bestHeight + gap, middle, bodyHeight - bestHeight - gap)
			place(page.Prize.Holder, middleX + middle + gap, 0, right, bodyHeight)
		else
			mapWidth = math.floor((width - gap) * HALF)
			local rightX = mapWidth + gap
			local right = width - rightX
			place(page.Prize.Holder, rightX, 0, right, prizeHeight)
			place(page.Best.Holder, rightX, prizeHeight + gap, right, bestHeight)
			place(page.Medals.Holder, rightX, prizeHeight + gap + bestHeight + gap, right, bodyHeight - prizeHeight - bestHeight - gap - gap)
		end
		place(page.Map.Holder, 0, 0, mapWidth, bodyHeight)

		-- Inside the panels (their Content frames are already inset by the pad).
		local stepper = page.Stepper.Instance.Size
		local stepWidth = stepper.X.Offset > 0 and stepper.X.Offset or ctx.Px(Space.StepperWidth)
		local stepHeight = stepper.Y.Offset > 0 and stepper.Y.Offset or ctx.Px(Space.ButtonHeight)
		put(page.LapRow, "AnchorPoint", Vector2.new(0, 1))
		put(page.LapRow, "Position", UDim2.new(0, math.max(0, math.floor((mapWidth - pad - pad - stepWidth) * HALF)), 1, 0))
		put(page.LapRow, "Size", UDim2.fromOffset(stepWidth, stepHeight))

		moveTo(page.PrizeChip.Instance, 0, label + gap)
		moveTo(page.Bonus.Instance, 0, label + gap + chipHeight + gap)
		put(page.Badge.Instance, "AnchorPoint", Vector2.new(1, 0))
		put(page.Badge.Instance, "Position", UDim2.new(1, 0, 0, 0))
		moveTo(page.BestTime.Instance, 0, label + gap)
		put(page.BestMedal.Instance, "AnchorPoint", Vector2.new(1, 0))
		put(page.BestMedal.Instance, "Position", UDim2.new(1, 0, 0, label + gap))
	end

	local function layoutRace(page, width, bottom, headerHeight, compact, gap, pad)
		local rowHeight = page.Row.Instance.Size.Y.Offset
		local label, head = lineOf("Label"), lineOf("SectionHead")
		local bodyTop = headerHeight + gap
		put(page.Strip.Holder, "Visible", page.Shown == true and not compact)
		if not compact then
			-- The four facts in four equal columns (Classic 419-421).
			local stripHeight = pad + label + pad
			place(page.Strip.Holder, 0, bodyTop, width, stripHeight)
			local column = math.floor((width - pad - pad) / #page.Facts)
			for index, fact in ipairs(page.Facts) do
				moveTo(fact.Instance, (index - 1) * column, 0)
			end
			bodyTop = bodyTop + stripHeight + gap
		end
		local bodyHeight = math.max(0, bottom - rowHeight - gap - bodyTop)
		place(page.Body, 0, bodyTop, width, bodyHeight)

		local prizesHeight = pad + label + gap + listHeight(page.PrizeList, #page.PrizeRows, compact) + pad
		local formatHeight = pad + label + gap + head + pad
		local mapWidth
		if compact then
			mapWidth = math.floor((width - gap - gap) * HALF)
			local middle = math.floor((width - gap - gap - mapWidth) * HALF)
			local right = width - gap - gap - mapWidth - middle
			local middleX = mapWidth + gap
			place(page.Format.Holder, middleX, 0, middle, formatHeight)
			place(page.Stats.Holder, middleX, formatHeight + gap, middle, bodyHeight - formatHeight - gap)
			place(page.Prizes.Holder, middleX + middle + gap, 0, right, bodyHeight)
		else
			mapWidth = math.floor((width - gap) * HALF)
			local rightX = mapWidth + gap
			local right = width - rightX
			place(page.Format.Holder, rightX, 0, right, formatHeight)
			place(page.Prizes.Holder, rightX, formatHeight + gap, right, prizesHeight)
			place(page.Stats.Holder, rightX, formatHeight + gap + prizesHeight + gap, right, bodyHeight - formatHeight - prizesHeight - gap - gap)
		end
		place(page.Map.Holder, 0, 0, mapWidth, bodyHeight)

		moveTo(page.Name.Instance, 0, label + gap)
		moveTo(page.FormatText.Instance, 0, label + gap)
		put(page.PrizeListHolder, "Position", UDim2.fromOffset(0, label + gap))
		put(page.PrizeListHolder, "Size", UDim2.new(1, 0, 1, -(label + gap)))
	end

	local function layout()
		if destroyed or not header then
			return
		end
		local compact = ctx.Class == "Compact"
		local gap = ctx.Px(Space.Gap)
		local padDesign = compact and Space.TouchGap or Space.Pad
		local pad = ctx.Px(padDesign)
		local width = math.max(0, bottomRight.Position.X.Offset - topLeft.Position.X.Offset)
		local bottom = bottomRight.Position.Y.Offset - topLeft.Position.Y.Offset
		local headerHeight = header.Height()
		if trial and trial.Shown then
			for _, item in ipairs(trial.Panels) do
				item.Panel.Set({ Pad = padDesign })
			end
			layoutTrial(trial, width, bottom, headerHeight, compact, gap, pad)
		end
		if race and race.Shown then
			for _, item in ipairs(race.Panels) do
				item.Panel.Set({ Pad = padDesign })
			end
			layoutRace(race, width, bottom, headerHeight, compact, gap, pad)
		end
	end

	local function watch(instance)
		scope:connect(instance:GetPropertyChangedSignal("Size"), layout)
	end

	-- Builders (each runs once, on the first render that needs it) ---------------------------------------------

	local function buildHeader()
		header = Controls.Header(topLeft, {
			Name = "SetupHeader",
			Title = "RACE ENTRY",
			Tabs = {
				Tabs = MODE_TABS,
				Selected = "TimeTrial",
				OnSelected = function(id)
					model.SelectMode(id)
					if model.Mode() ~= id and header and header.Tabs then
						header.Tabs.Select(model.Mode())
					end
				end,
			},
		}, scope)
		watch(header.Instance)
	end

	local function footer(buttons)
		local row = Controls.ButtonRow(bottomRight, { Name = "SetupButtons", Buttons = buttons }, scope)
		watch(row.Instance)
		return row
	end

	local function buildTrial(setup)
		local page = { Panels = {} }
		page.TierHolder = holder("TierRow", topLeft)
		page.Tiers = Controls.Tabs(page.TierHolder, {
			Name = "TierTabs",
			Tabs = tierItems(setup.Tiers),
			Selected = model.Tier(),
			OnSelected = function(id)
				model.SelectTier(id)
				if model.Tier() ~= id then
					page.Tiers.Select(model.Tier())
				end
			end,
		}, scope)
		watch(page.Tiers.Instance)
		page.Body = holder("TimeTrialSetup", topLeft)

		page.Map = panel("TrackMap", page.Body, nil, scope)
		page.Picture = picture(page.Map.Content)
		page.Info = Text.Label(page.Map.Content, { Name = "Info", Text = "", Role = "Label", Colour = "TextSecondary" }, scope)
		page.LapRow = holder("LapRow", page.Map.Content)
		page.Stepper = Controls.Stepper(page.LapRow, {
			Value = setup.Lap,
			Min = setup.MinLap,
			Max = setup.MaxLap,
			Step = 1,
			Format = model.LapText,
			MarkKey = "LapSelector",
			OnChanged = function(value)
				model.SetLap(value)
			end,
		}, scope)
		watch(page.Stepper.Instance)

		page.Prize = panel("PrizePanel", page.Body, "PrizeSummary", scope)
		page.PrizeLabel = Text.Label(page.Prize.Content, { Name = "PrizeLabel", Text = "", Role = "Label", Colour = "TextSecondary" }, scope)
		page.PrizeChip = Collections.Chip(page.Prize.Content, { Name = "PrizeChip", Text = setup.PrizeText, Kind = "Yellow" }, scope)
		page.Bonus = Text.Label(page.Prize.Content, { Name = "Bonus", Text = "", Role = "Label", Colour = "TextMuted" }, scope)
		page.Badge = Collections.TierBadge(page.Prize.Content, { Name = "TierBadge", Tier = model.Tier(), Size = "Large" }, scope)
		watch(page.PrizeChip.Instance)

		page.Best = panel("PersonalBest", page.Body, nil, scope)
		page.BestCaption = Text.Label(page.Best.Content, { Name = "Caption", Text = "", Role = "Label", Colour = "TextSecondary" }, scope)
		page.BestTime = Text.Label(page.Best.Content, { Name = "Time", Text = "", Role = "SectionHead" }, scope)
		page.BestMedal = Text.Label(page.Best.Content, { Name = "Medal", Text = "", Role = "Value", Align = "Right" }, scope)

		page.Medals = panel("MedalPanel", page.Body, "MedalTargets", scope)
		page.MedalList = Data.FactList(page.Medals.Content, { Name = "MedalRows", Rows = {} }, scope)

		page.Panels = { page.Map, page.Prize, page.Best, page.Medals }
		page.Row = footer({
			{ Id = "Exit", Variant = "Default", Text = "EXIT", Icon = "exit", OnActivated = function()
				model.Exit()
			end },
			{ Id = "Records", Variant = "Default", Text = setup.RecordsText, Icon = "trophy", OnActivated = function()
				model.Next()
			end },
			{ Id = "Choose", Variant = "Main", Text = setup.ChooseText, Icon = "car", OnActivated = function()
				model.ChooseVehicle()
			end },
		})
		return page
	end

	local function buildRace(data)
		local page = { Panels = {}, Facts = {} }
		page.Body = holder("RaceSetup", topLeft)

		page.Strip = panel("RaceInformationStrip", topLeft, nil, scope)
		for index, text in ipairs(data.Facts) do
			page.Facts[index] = Text.Label(page.Strip.Content, {
				Name = "Fact" .. tostring(index),
				Text = text,
				Role = "Label",
				Colour = index == 1 and "Cyan" or "White",
			}, scope)
		end

		page.Map = panel("RaceTrackMap", page.Body, nil, scope)
		page.Picture = picture(page.Map.Content)
		page.MapLabel = Text.Label(page.Map.Content, { Name = "MapLabel", Text = data.MapLabel, Role = "Label", Colour = "TextSecondary" }, scope)
		page.Name = Text.Label(page.Map.Content, { Name = "RaceName", Text = "", Role = "SectionHead" }, scope)

		page.Format = panel("FormatPanel", page.Body, "RaceFormat", scope)
		page.FormatLabel = Text.Label(page.Format.Content, { Name = "FormatLabel", Text = data.FormatLabel, Role = "Label", Colour = "TextSecondary" }, scope)
		page.FormatText = Text.Label(page.Format.Content, { Name = "FormatText", Text = "", Role = "SectionHead" }, scope)

		page.Prizes = panel("PlacementPrizes", page.Body, nil, scope)
		page.PrizesLabel = Text.Label(page.Prizes.Content, { Name = "PrizesLabel", Text = data.PrizesLabel, Role = "Label", Colour = "TextSecondary" }, scope)
		page.PrizeListHolder = holder("PrizeRows", page.Prizes.Content)
		page.PrizeList = Data.FactList(page.PrizeListHolder, { Name = "PrizeList", Rows = {} }, scope)
		page.PrizeRows = data.Prizes
		watch(page.PrizeList.Instance)

		page.Stats = panel("RaceStats", page.Body, nil, scope)
		page.StatList = Data.FactList(page.Stats.Content, { Name = "StatList", Rows = {} }, scope)

		page.Panels = { page.Strip, page.Map, page.Format, page.Prizes, page.Stats }
		page.Row = footer({
			{ Id = "Exit", Variant = "Default", Text = "EXIT", Icon = "exit", OnActivated = function()
				model.Exit()
			end },
			{ Id = "Choose", Variant = "Main", Text = data.ChooseText, Icon = "car", OnActivated = function()
				model.ChooseVehicle()
			end },
		})
		return page
	end

	-- Drawing -----------------------------------------------------------------------------------------------

	local function drawTrial(page, setup, snap)
		local compact = ctx.Class == "Compact"
		if LOCK_UNOWNED_TIERS then
			local owned = {}
			for index, tier in ipairs(setup.Tiers) do
				owned[index] = tier.Owned and "1" or "0"
			end
			local signature = table.concat(owned)
			if signatures.Tiers ~= signature then
				signatures.Tiers = signature
				page.Tiers.Set({ Tabs = tierItems(setup.Tiers) })
			end
		end
		page.Tiers.Select(snap.Tier)
		page.Info.Set({ Text = compact and setup.InfoShort or setup.Info })
		setImage(page.Picture, setup.MapImage)
		page.Stepper.Set({ Value = setup.Lap, Min = setup.MinLap, Max = setup.MaxLap })
		page.PrizeLabel.Set({ Text = setup.PrizeLabel })
		page.PrizeChip.Set({ Text = setup.PrizeText })
		page.Bonus.Set({ Text = setup.BonusText })
		page.Badge.Set({ Tier = snap.Tier })
		page.BestCaption.Set({ Text = setup.BestCaption })
		page.BestTime.Set({ Text = setup.Best.TimeText })
		page.BestMedal.Set({ Text = setup.Best.MedalText })
		local rows = {}
		for index, medal in ipairs(setup.Medals) do
			rows[index] = { Id = medal.Id, Icon = "medal", Label = medal.Label, Value = medal.Time, Kind = "Text" }
		end
		setRows("Medals", page.MedalList, rows)
		page.Row.Button("Records").Set({ Text = compact and setup.RecordsShort or setup.RecordsText, Disabled = not setup.Enabled })
		page.Row.Button("Choose").Set({ Text = setup.ChooseText, Disabled = not setup.Enabled })
	end

	local function drawRace(page, data)
		for index, fact in ipairs(page.Facts) do
			fact.Set({ Text = data.Facts[index] or "" })
		end
		setImage(page.Picture, data.MapImage)
		page.Name.Set({ Text = data.Name })
		page.FormatText.Set({ Text = data.FormatText })
		local prizes = {}
		for index, prize in ipairs(data.Prizes) do
			prizes[index] = { Id = prize.Id, Icon = "trophy", Label = prize.Label, Value = prize.Text, Kind = "Prize" }
		end
		page.PrizeRows = data.Prizes
		setRows("Prizes", page.PrizeList, prizes)
		local stats = {}
		for index, stat in ipairs(data.Stats) do
			stats[index] = { Id = stat.Id, Icon = stat.Id == "Players" and "players" or "checkpoints", Label = stat.Label, Value = stat.Text, Kind = "Text" }
		end
		setRows("Stats", page.StatList, stats)
		page.Row.Button("Choose").Set({ Text = data.ChooseText, Disabled = not data.Enabled })
	end

	local function showTrial(page, visible)
		page.Shown = visible
		put(page.TierHolder, "Visible", visible)
		put(page.Body, "Visible", visible)
		page.Row.Set({ Visible = visible })
	end

	local function showRace(page, visible)
		page.Shown = visible
		put(page.Body, "Visible", visible)
		put(page.Strip.Holder, "Visible", visible and ctx.Class ~= "Compact")
		page.Row.Set({ Visible = visible })
	end

	function self.Render(_reason)
		if destroyed then
			return
		end
		-- Fetch first, then draw: the snapshot is complete before the first write, and a snapshot that was
		-- overtaken while it was built is not drawn (the newer render draws instead).
		local snap = model.Snapshot()
		if snap.Revision ~= model.Revision() then
			return
		end
		local mine = snap.Open == true and snap.Page == "Setup"
		local setup = mine and snap.Setup or nil
		local raceData = mine and snap.Race or nil
		if mine and not header then
			buildHeader()
		end
		if setup and not trial then
			trial = buildTrial(setup)
		end
		if raceData and not race then
			race = buildRace(raceData)
		end
		if header then
			if mine then
				header.Set({ Title = snap.Title, Visible = true })
				header.Tabs.Select(snap.Mode)
			else
				header.Set({ Visible = false })
			end
		end
		if trial then
			showTrial(trial, setup ~= nil)
			if setup then
				drawTrial(trial, setup, snap)
			end
		end
		if race then
			showRace(race, raceData ~= nil)
			if raceData then
				drawRace(race, raceData)
			end
		end
		if mine then
			layout()
		end
	end

	if ctx.Changed then
		scope:connect(ctx.Changed, function(change)
			if type(change) == "table" and change.Layout == false then
				return
			end
			-- After the kit's own listeners: the slots and component sizes are final by then.
			task.defer(layout)
		end)
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if trial then
			trial.Row.Destroy()
			trial.Body:Destroy()
			trial.TierHolder:Destroy()
		end
		if race then
			race.Row.Destroy()
			race.Body:Destroy()
			race.Strip.Holder:Destroy()
		end
		if header then
			header.Destroy()
		end
	end

	return self
end

return View
