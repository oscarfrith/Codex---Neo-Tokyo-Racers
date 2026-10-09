-- Owns the race-entry Records page drawing (world record, medal targets, your record, global top 20, its header and footer); it owns no state, calls no remote, fires no bindable and writes no attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceEntry.RecordsView. Requires: Tokens, Text, Surface, Controls, Collections, Data.
local kit = script.Parent.Parent.Kit
local Tokens = require(kit.Tokens)
local Text = require(kit.Text)
local Surface = require(kit.Surface)
local Controls = require(kit.Controls)
local Collections = require(kit.Collections)
local Data = require(kit.Data)

local View = {}

local Space = Tokens.Space
local HALF = 0.5

-- The texts are the ones the marks set (Kit.Contracts.Marks "Text.TimeTrial", "Text.Race"). This page carries no
-- LapSelector and no TierE..TierS mark, so Classic onboarding never takes it for the time-trial Setup page.
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

local function panel(name, parent, scope)
	local frame = holder(name, parent)
	local surface = Surface.Panel(frame, {}, scope)
	return { Holder = frame, Panel = surface, Content = surface.Content }
end

function View.Mount(layer, model, scope)
	local ctx = layer.Metrics
	local topLeft = layer.Slot("TopLeft")
	local bottomRight = layer.Slot("BottomRight")
	local destroyed = false
	local page = nil
	local signatures = {}
	local self = {}

	local function lineOf(role)
		local size, scale = Text.SizeFor(role, ctx)
		return math.ceil(size * (scale or 1))
	end

	-- The tier row is read-only here (Classic 497): every tier but the selected one is Locked.
	local function tierItems(tiers, selected)
		local items = {}
		for index, tier in ipairs(tiers) do
			items[index] = { Id = tier.Tier, Text = tier.Tier, Tier = tier.Tier, Locked = tier.Tier ~= selected or nil }
		end
		return items
	end

	local function layout()
		if destroyed or not page or not page.Shown then
			return
		end
		local compact = ctx.Class == "Compact"
		local gap = ctx.Px(Space.Gap)
		local padDesign = compact and Space.TouchGap or Space.Pad
		local pad = ctx.Px(padDesign)
		for _, item in ipairs(page.Panels) do
			item.Panel.Set({ Pad = padDesign })
		end
		local width = math.max(0, bottomRight.Position.X.Offset - topLeft.Position.X.Offset)
		local bottom = bottomRight.Position.Y.Offset - topLeft.Position.Y.Offset
		local headerHeight = page.Header.Height()
		local tabs = page.Tiers.Instance.Size
		local tabsWidth, tabsHeight = tabs.X.Offset, tabs.Y.Offset
		local bodyTop
		if compact then
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
		local worldHeight = pad + label + gap + head + gap + label + pad
		local medalsHeight = page.MedalList.Instance.Size.Y.Offset
		if medalsHeight <= 0 then
			medalsHeight = page.MedalCount * ctx.Px(compact and Space.StatRowHeight or Space.FactRowHeight)
		end
		medalsHeight = pad + medalsHeight + pad
		local boardX
		if compact then
			local half = math.floor((width - gap - gap) * HALF)
			local quarter = math.floor((width - gap - gap - half) * HALF)
			local middle = width - gap - gap - half - quarter
			place(page.World.Holder, 0, 0, quarter, worldHeight)
			place(page.Your.Holder, 0, worldHeight + gap, quarter, bodyHeight - worldHeight - gap)
			place(page.Medals.Holder, quarter + gap, 0, middle, bodyHeight)
			boardX = quarter + gap + middle + gap
		else
			local left = math.floor((width - gap) * HALF)
			place(page.World.Holder, 0, 0, left, worldHeight)
			place(page.Medals.Holder, 0, worldHeight + gap, left, medalsHeight)
			place(page.Your.Holder, 0, worldHeight + gap + medalsHeight + gap, left, bodyHeight - worldHeight - medalsHeight - gap - gap)
			boardX = left + gap
		end
		place(page.Board.Holder, boardX, 0, width - boardX, bodyHeight)

		local badge = page.WorldBadge.Instance.Size.X.Offset
		moveTo(page.WorldLabel.Instance, badge > 0 and (badge + gap) or 0, 0)
		moveTo(page.WorldTime.Instance, 0, label + gap)
		moveTo(page.WorldName.Instance, 0, label + gap + head + gap)
		moveTo(page.YourTime.Instance, 0, label + gap)
		moveTo(page.YourVehicle.Instance, 0, label + gap + head + gap)
		put(page.YourMedal.Instance, "AnchorPoint", Vector2.new(1, 0))
		put(page.YourMedal.Instance, "Position", UDim2.new(1, 0, 0, label + gap))
		put(page.ListHolder, "Position", UDim2.fromOffset(0, label + gap))
		put(page.ListHolder, "Size", UDim2.new(1, 0, 1, -(label + gap)))
		moveTo(page.Message.Instance, 0, label + gap + head + gap)
	end

	local function watch(instance)
		scope:connect(instance:GetPropertyChangedSignal("Size"), layout)
	end

	local function build(records)
		local built = { Shown = false }
		built.Header = Controls.Header(topLeft, {
			Name = "RecordsHeader",
			Title = "RACE ENTRY",
			Count = records.PageLabel,
			Tabs = {
				Tabs = MODE_TABS,
				Selected = "TimeTrial",
				OnSelected = function(id)
					model.SelectMode(id)
					if model.Mode() ~= id then
						built.Header.Tabs.Select(model.Mode())
					end
				end,
			},
		}, scope)
		watch(built.Header.Instance)

		built.TierHolder = holder("RecordsTierRow", topLeft)
		built.Tiers = Controls.Tabs(built.TierHolder, {
			Name = "RecordsTiers",
			Tabs = tierItems(records.Tiers, model.Tier()),
			Selected = model.Tier(),
			OnSelected = function(id)
				if model.Tier() ~= id then
					built.Tiers.Select(model.Tier())
				end
			end,
		}, scope)
		watch(built.Tiers.Instance)
		built.Body = holder("Records", topLeft)

		built.World = panel("WorldRecord", built.Body, scope)
		built.WorldBadge = Collections.TierBadge(built.World.Content, { Name = "WorldTier", Tier = model.Tier(), Size = "Small" }, scope)
		built.WorldLabel = Text.Label(built.World.Content, { Name = "WorldLabel", Text = "", Role = "Label", Colour = "TextSecondary" }, scope)
		built.WorldTime = Text.Label(built.World.Content, { Name = "WorldTime", Text = "", Role = "SectionHead" }, scope)
		built.WorldName = Text.Label(built.World.Content, { Name = "WorldName", Text = "", Role = "Label" }, scope)
		watch(built.WorldBadge.Instance)

		built.Medals = panel("RecordMedalTargets", built.Body, scope)
		built.MedalList = Data.FactList(built.Medals.Content, { Name = "MedalRows", Rows = {} }, scope)
		built.MedalCount = #records.Medals
		watch(built.MedalList.Instance)

		built.Your = panel("YourRecord", built.Body, scope)
		built.YourLabel = Text.Label(built.Your.Content, { Name = "YourLabel", Text = records.YourLabel, Role = "Label", Colour = "TextSecondary" }, scope)
		built.YourTime = Text.Label(built.Your.Content, { Name = "YourTime", Text = "", Role = "SectionHead" }, scope)
		built.YourVehicle = Text.Label(built.Your.Content, { Name = "YourVehicle", Text = "", Role = "Label" }, scope)
		built.YourMedal = Text.Label(built.Your.Content, { Name = "YourMedal", Text = "", Role = "Value", Align = "Right" }, scope)

		built.Board = panel("GlobalTop20", built.Body, scope)
		built.BoardLabel = Text.Label(built.Board.Content, { Name = "BoardLabel", Text = records.BoardLabel, Role = "Label", Colour = "TextSecondary" }, scope)
		built.ListHolder = holder("LeaderboardRows", built.Board.Content)
		built.List = Collections.List(built.ListHolder, { Name = "Leaderboard", Header = records.Columns }, scope)
		built.Message = Text.Label(built.Board.Content, { Name = "Message", Text = "", Role = "Body", Colour = "TextMuted", Wrap = true, Align = "Centre", Visible = false }, scope)

		built.Panels = { built.World, built.Medals, built.Your, built.Board }
		built.Row = Controls.ButtonRow(bottomRight, {
			Name = "RecordsButtons",
			Buttons = {
				{ Id = "Back", Variant = "Default", Text = "BACK", Icon = "back", OnActivated = function()
					model.Back()
				end },
				{ Id = "Choose", Variant = "Main", Text = records.ChooseText, Icon = "car", OnActivated = function()
					model.ChooseVehicle()
				end },
			},
		}, scope)
		watch(built.Row.Instance)
		return built
	end

	local function show(visible)
		page.Shown = visible
		page.Header.Set({ Visible = visible })
		put(page.TierHolder, "Visible", visible)
		put(page.Body, "Visible", visible)
		page.Row.Set({ Visible = visible })
	end

	local function draw(records, snap)
		page.Header.Set({ Title = snap.Title, Count = records.PageLabel })
		page.Header.Tabs.Select(snap.Mode)
		if signatures.Tier ~= snap.Tier then
			signatures.Tier = snap.Tier
			page.Tiers.Set({ Tabs = tierItems(records.Tiers, snap.Tier), Selected = snap.Tier })
		end
		page.WorldBadge.Set({ Tier = snap.Tier })
		page.WorldLabel.Set({ Text = records.WorldLabel })
		page.WorldTime.Set({ Text = records.WorldTime })
		page.WorldName.Set({ Text = records.WorldName })
		page.YourTime.Set({ Text = records.Best.TimeText })
		page.YourVehicle.Set({ Text = records.Best.VehicleText })
		page.YourMedal.Set({ Text = records.Best.MedalText })

		local rows, parts = {}, {}
		for index, medal in ipairs(records.Medals) do
			rows[index] = { Id = medal.Id, Icon = "medal", Label = medal.Label, Value = medal.Time, Kind = "Text" }
			parts[index] = medal.Label .. "=" .. medal.Time
		end
		local medalSignature = table.concat(parts, "|")
		if signatures.Medals ~= medalSignature then
			signatures.Medals = medalSignature
			page.MedalCount = #rows
			page.MedalList.SetRows(rows)
		end

		local board = records.Board
		local items, boardParts = {}, {}
		for index, row in ipairs(board.Rows) do
			items[index] = { Key = row.Key, Columns = row.Columns, Accent = row.You }
			boardParts[index] = table.concat(row.Columns, "=") .. (row.You and "*" or "")
		end
		local boardSignature = table.concat(boardParts, "|")
		if signatures.Board ~= boardSignature then
			signatures.Board = boardSignature
			page.List.SetItems(items)
		end
		page.Message.Set({ Text = board.Message, Visible = board.State ~= "Rows" })

		page.Row.Button("Choose").Set({ Text = records.ChooseText, Disabled = not records.Enabled })
	end

	function self.Render(_reason)
		if destroyed then
			return
		end
		-- Fetch first, then draw; an overtaken snapshot is not drawn.
		local snap = model.Snapshot()
		if snap.Revision ~= model.Revision() then
			return
		end
		local records = (snap.Open == true and snap.Page == "Records") and snap.Records or nil
		if records and not page then
			page = build(records)
		end
		if not page then
			return
		end
		show(records ~= nil)
		if records then
			draw(records, snap)
			layout()
		end
	end

	if ctx.Changed then
		scope:connect(ctx.Changed, function(change)
			if type(change) == "table" and change.Layout == false then
				return
			end
			task.defer(layout)
		end)
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if page then
			page.Header.Destroy()
			page.Row.Destroy()
			page.TierHolder:Destroy()
			page.Body:Destroy()
		end
	end

	return self
end

return View
