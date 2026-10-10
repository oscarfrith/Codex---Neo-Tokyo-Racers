-- Owns the race menu drawing for Regular and Compact (header and filter tabs, event list, detail, action row, status line); it does not own the menu state, any remote, bindable or attribute, nor the ScreenGui (the client's Layer).
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceMenu.RaceMenuView. Requires: Tokens, Text, Surface, Controls, Collections, Data, Input.
local GuiService = game:GetService("GuiService")

local kit = script.Parent.Parent.Kit
local Tokens = require(kit.Tokens)
local Text = require(kit.Text)
local Surface = require(kit.Surface)
local Controls = require(kit.Controls)
local Collections = require(kit.Collections)
local Data = require(kit.Data)
local Input = require(kit.Input)

local View = {}

-- Strings. EXIT, SET ROUTE and the empty and placeholder texts are Classic (576, 586, 229, 254); the title,
-- the tab names, BACK and the event count are from the previews (mockup 02, c05, c06) and are listed in contract.json.
local STRINGS = table.freeze({
	Title = "RACES",
	Exit = "EXIT",
	Back = "BACK",
	SetRoute = "SET ROUTE",
	Empty = "NO EVENTS AVAILABLE",
	TrackMap = "TRACK MAP",
	Event = "EVENT",
	Events = "EVENTS",
	Of = "OF",
	Laps = "LAPS",
	Hint = "SELECT AN EVENT TO TELEPORT",
})

local TAB_TEXT = table.freeze({ All = "ALL EVENTS", TimeTrials = "TIME TRIALS", Races = "RACES" })
local TAB_ORDER = table.freeze({ "All", "TimeTrials", "Races" }) -- RaceMenuModel.Filters

-- Fact row id -> icon. The route row keeps the Classic circuit / point-to-point split (269).
local FACT_ICON = table.freeze({ Laps = "laps", Checkpoints = "checkpoints", Players = "players" })

-- Mockup 02: the event list takes a third of the body, and never less than the kit's list width (NOTES Q12).
local LIST_SHARE = 1 / 3

local warned = {}
local function warnOnce(message)
	if not warned[message] then
		warned[message] = true
		warn("[Pulse.RaceMenuView] " .. message)
	end
end

local function newFrame(name, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function newPicture(name, parent, scaleType)
	local picture = Instance.new("ImageLabel")
	picture.Name = name
	picture.BackgroundTransparency = 1
	picture.BorderSizePixel = 0
	picture.Size = UDim2.fromScale(1, 1)
	picture.ScaleType = scaleType
	picture.Image = ""
	picture.Parent = parent
	return picture
end

local function setProperty(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

function View.Mount(layer, model, scope)
	assert(type(layer) == "table" and layer.Root, "[Pulse.RaceMenuView] Mount needs a Layer")
	assert(type(model) == "table" and model.Changed, "[Pulse.RaceMenuView] Mount needs a model")
	local ctx = layer.Metrics
	local root = layer.Root

	local view = {}
	local destroyed = false
	local built = nil -- the current tree (one class)
	local shown = nil -- last value given to layer.SetVisible
	local cashPlayer = nil

	-- The scrim covers the whole screen on the live layer; a stage (gallery, tests) has no scrim gui.
	local scrim = Surface.Scrim(layer.ScrimRoot or root, { Kind = "Menu" }, scope)
	-- On a stage the tint shares the root with the slots (which were built first) and must draw under them, or the
	-- header, the cash chip and the buttons are dimmed while the body is not.
	scrim.Instance.ZIndex = 0

	-- A kit size prop is a design value; this turns a real-pixel target back into one (Px(design) == pixels).
	local function design(pixels)
		return pixels / ctx.Scale
	end

	local function slotPoint(name)
		local position = layer.Slot(name).Position
		return position.X.Offset, position.Y.Offset
	end

	-- API1 8: a child of a slot takes the slot's anchor and sits at zero.
	local function place(component, slotName)
		local slot = layer.Slot(slotName)
		component.Instance.AnchorPoint = slot.AnchorPoint
		component.Instance.Position = UDim2.new()
	end

	-- Sends a component only the props that differ from the last ones sent.
	local function patch(tree, id, component, props)
		local last = tree.Cache[id]
		if not last then
			last = {}
			tree.Cache[id] = last
		end
		local delta, any = {}, false
		for key, value in pairs(props) do
			if last[key] ~= value then
				last[key] = value
				delta[key] = value
				any = true
			end
		end
		if any then
			component.Set(delta)
		end
	end

	local function bindCash(tree)
		local player = cashPlayer
		if not player then
			return
		end
		-- Data's first Foundation read may yield once (API2 3.5), so never on the caller's thread.
		task.spawn(function()
			local ok, problem = pcall(function()
				tree.Status.Cash.Bind(player)
			end)
			if not ok then
				warnOnce("cash chip bind failed: " .. tostring(problem))
			end
		end)
	end

	-- Build: one tree per class ------------------------------------------------------------------------------------
	local function build()
		local compact = ctx.Class == "Compact"
		local tree = { Compact = compact, Cache = {}, Components = {}, Instances = {} }
		local function keep(component)
			table.insert(tree.Components, component)
			return component
		end

		local tabItems = {}
		for _, id in ipairs(TAB_ORDER) do
			table.insert(tabItems, { Id = id, Text = TAB_TEXT[id] })
		end
		-- Bumpers are bound by the client only while the menu is open, never by the tabs.
		tree.Header = keep(Controls.Header(layer.Slot("TopLeft"), {
			Title = STRINGS.Title,
			Count = "",
			Tabs = {
				Tabs = tabItems,
				Selected = model.Filter(),
				Bumpers = false,
				OnSelected = function(id)
					model.SetFilter(id)
				end,
			},
		}, scope))
		tree.Filter = model.Filter()
		if compact then
			-- Compact detail page: the title is the event name (c06). A second header, shown instead of the first.
			tree.DetailHeader = keep(Controls.Header(layer.Slot("TopLeft"), { Name = "DetailHeader", Title = "", Visible = false }, scope))
		end

		tree.Status = keep(Data.StatusCluster(layer.Slot("TopRight"), { Mode = "CashOnly" }, scope))
		place(tree.Status, "TopRight")

		local body = newFrame("MenuBody", root)
		table.insert(tree.Instances, body)
		tree.Body = body

		tree.ListHost = newFrame("EventListHost", body)
		-- The kit list calls OnSelected only when the selection changes, and on a focus move as well as a press.
		-- So it only selects; the Compact detail page opens from the row's own press (hookRows), which also works
		-- on the row that is already selected (the menu opens with the first event selected).
		local listProps = {
			OnSelected = function(key)
				model.Select(key)
			end,
		}
		tree.RowKeys = {} -- row button -> the key it shows now (rows are pooled by the kit list); strong on purpose
		tree.RowHooked = {} -- row button -> true once its press is connected
		if compact then
			listProps.RowHeight = Tokens.Space.TouchMin
		end
		tree.List = keep(Collections.List(tree.ListHost, listProps, scope))
		Input.Mark(tree.List.Instance, "CardContent") -- onboarding N1

		tree.Empty = keep(Text.Label(body, {
			Name = "EmptyState",
			Text = STRINGS.Empty,
			Role = "SectionHead",
			Colour = "TextMuted",
			Align = "Left",
			Visible = false,
		}, scope))

		tree.Hero = keep(Surface.Panel(body, { Name = "Hero", Pad = 0, Hairlines = false, Visible = false }, scope))
		tree.HeroPicture = newPicture("TrackPicture", tree.Hero.Content, Enum.ScaleType.Crop)
		-- Mockup 02: "EVENT n OF m" sits on a dark plate in the hero's top-left corner. The plate is a kit Panel
		-- that follows the label's drawn size plus the page padding on every side (set in layout). Until the label
		-- has a drawn size the plate is one padding square under the label's corner; it is never hidden, so the
		-- label's own sizing does not depend on it.
		tree.HeroIndexPlate = keep(Surface.Panel(tree.Hero.Content, {
			Name = "EventIndexPlate",
			Pad = Tokens.Space.Pad,
			Hairlines = false,
			Width = Tokens.Space.Pad,
			Height = Tokens.Space.Pad,
		}, scope))
		tree.HeroIndex = keep(Text.Label(tree.HeroIndexPlate.Content, {
			Name = "EventIndex",
			Text = "",
			Role = "Label",
			Colour = "TextSecondary",
			Align = "Left",
			Shadow = true,
		}, scope))
		tree.IndexInset = 0
		tree.FitIndexPlate = function()
			if destroyed or tree.Destroyed then
				return
			end
			local size = tree.HeroIndex.Instance.AbsoluteSize
			if size.X > 0 and size.Y > 0 then
				patch(tree, "HeroIndexPlate", tree.HeroIndexPlate, {
					Width = design(size.X + tree.IndexInset),
					Height = design(size.Y + tree.IndexInset),
				})
			end
		end
		scope:connect(tree.HeroIndex.Instance:GetPropertyChangedSignal("AbsoluteSize"), tree.FitIndexPlate)
		tree.HeroTitle = keep(Text.Label(tree.Hero.Content, {
			Name = "EventName",
			Text = "",
			Role = compact and "Status" or "SectionHead",
			Align = "Left",
			Shadow = true,
		}, scope))
		tree.HeroTitle.Instance.AnchorPoint = Vector2.new(0, 1)
		tree.HeroLine = keep(Surface.Hairline(tree.Hero.Content, { Edge = "Bottom", Colour = "Pink" }, scope))

		tree.Map = keep(Surface.Panel(body, { Name = "TrackMapPanel", Pad = 0, Visible = false }, scope))
		tree.MapPicture = newPicture("MapPicture", tree.Map.Content, Enum.ScaleType.Fit)
		tree.MapPlaceholder = keep(Text.Label(tree.Map.Content, {
			Name = "Placeholder",
			Text = STRINGS.TrackMap,
			Role = "Label",
			Colour = "TextMuted",
			Align = "Left",
		}, scope))

		tree.Facts = keep(Surface.Panel(body, { Name = "EventFacts", Visible = false }, scope))
		tree.FactList = keep(Data.FactList(tree.Facts.Content, { Rows = {} }, scope))

		tree.StatusLine = keep(Text.Label(layer.Slot("BottomLeft"), {
			Name = "StatusLine",
			Text = "",
			Role = "Label",
			Colour = "Danger",
			Align = "Left",
			Wrap = true,
			Visible = false,
		}, scope))
		place(tree.StatusLine, "BottomLeft")
		if compact then
			-- Compact list page: a row opens the event's page, which holds SET ROUTE and TELEPORT. Said in words on
			-- the button line, because nothing else on the list shows it.
			tree.Hint = keep(Text.Label(layer.Slot("BottomLeft"), {
				Name = "ListHint",
				Text = STRINGS.Hint,
				Role = "Label",
				Colour = "TextMuted",
				Align = "Left",
				Visible = false,
			}, scope))
			place(tree.Hint, "BottomLeft")
		end

		local function onTeleport()
			task.spawn(model.Teleport) -- yields (fade wait and the server call)
		end
		local function onRoute()
			model.SetRoute()
		end
		local function onExit()
			model.SetOpen(false)
		end
		local first
		if compact then
			first = { Id = "Back", Variant = "Default", Text = STRINGS.Back, Icon = "back", OnActivated = function()
				model.SetPage("List")
			end }
		else
			first = { Id = "Exit", Variant = "Default", Text = STRINGS.Exit, Icon = "exit", OnActivated = onExit }
		end
		-- Order: back or exit, secondary, main (API1 7.3).
		tree.Buttons = keep(Controls.ButtonRow(layer.Slot("BottomRight"), {
			Align = "Right",
			Visible = not compact,
			Buttons = {
				first,
				{ Id = "SetRoute", Variant = "Default", Text = STRINGS.SetRoute, Icon = "set_route", Disabled = true, OnActivated = onRoute },
				{ Id = "Teleport", Variant = "Main", Text = model.TeleportText(), Icon = "pin", Disabled = true, OnActivated = onTeleport },
			},
		}, scope))
		tree.RouteButton = tree.Buttons.Button("SetRoute")
		tree.TeleportButton = tree.Buttons.Button("Teleport")
		Input.Mark(tree.TeleportButton.Instance, "TeleportToStart") -- onboarding N6
		tree.FirstButton = tree.Buttons.Button(first.Id)
		if compact then
			-- Compact list page: EXIT alone (c05).
			tree.ListButtons = keep(Controls.ButtonRow(layer.Slot("BottomRight"), {
				Name = "ListButtons",
				Align = "Right",
				Buttons = { { Id = "Exit", Variant = "Default", Text = STRINGS.Exit, Icon = "exit", OnActivated = onExit } },
			}, scope))
			tree.FirstButton = tree.ListButtons.Button("Exit")
		end

		bindCash(tree)
		return tree
	end

	local function destroyTree(tree)
		tree.Destroyed = true
		for index = #tree.Components, 1, -1 do
			tree.Components[index].Destroy()
		end
		for _, instance in ipairs(tree.Instances) do
			instance:Destroy()
		end
		tree.Components = {}
		tree.Instances = {}
	end

	local function detailPageOf(tree)
		local item = model.Detail()
		return tree.Compact and model.Page() == "Detail" and item ~= nil
	end

	-- Layout: every number is a slot position or a ctx result; whole pixels ------------------------------------------
	local function panelRect(tree, id, component, x, y, width, height)
		setProperty(component.Instance, "Position", UDim2.fromOffset(x, y))
		patch(tree, id, component, { Width = design(width), Height = design(height) })
	end

	local function layout(tree)
		local detailPage = detailPageOf(tree)
		tree.LayoutPage = detailPage
		local left, top = slotPoint("TopLeft")
		local right, bottom = slotPoint("BottomRight")
		local gap = ctx.Px(Tokens.Space.Gap)
		local header = if detailPage then tree.DetailHeader else tree.Header
		local buttonHeight = if tree.Compact then ctx.Touch(Tokens.Space.CompactButtonDrawn) else ctx.Px(Tokens.Space.ButtonHeight)
		local bodyTop = top + header.Height() + gap
		local width = math.max(0, right - left)
		local height = math.max(0, bottom - buttonHeight - gap - bodyTop)
		setProperty(tree.Body, "Position", UDim2.fromOffset(left, bodyTop))
		setProperty(tree.Body, "Size", UDim2.fromOffset(width, height))

		local listWidth, detailX, heroWidth, heroHeight, pad
		local mapY, mapWidth, factsX, factsY, factsWidth, factsHeight
		if tree.Compact then
			-- c05: the list fills the page. c06: hero strip over the map on the left, facts on the right. An event
			-- with no map image has no map panel (it was an empty box): its track picture takes the whole column.
			local item = model.Detail()
			local hasMap = item ~= nil and item.MapImage ~= ""
			local hasTrack = item ~= nil and item.TrackImage ~= ""
			tree.LayoutMedia = (hasMap and "M" or "-") .. (hasTrack and "T" or "-")
			pad = gap
			listWidth = width
			detailX = 0
			factsWidth = math.min(ctx.Px(Tokens.Space.CompactSidePanelWidth), width)
			heroWidth = math.max(0, width - factsWidth - gap)
			heroHeight = math.min(ctx.Px(Tokens.Space.CompactTileHeight), height)
			if hasTrack and not hasMap then
				heroHeight = height
			end
			mapY = heroHeight + gap
			mapWidth = heroWidth
			factsX = heroWidth + gap
			factsY = 0
			-- The facts panel is as tall as its rows (set after the rows are, in fitFacts).
			factsHeight = tree.FactsHeight or height
			patch(tree, "FactsPad", tree.Facts, { Pad = Tokens.Space.TouchGap })
		else
			-- Mockup 02: list on the left; hero over map and facts on the right.
			pad = ctx.Px(Tokens.Space.Pad)
			listWidth = math.min(math.max(ctx.Px(Tokens.Space.ListWidth), math.floor(width * LIST_SHARE)), width)
			detailX = listWidth + gap
			heroWidth = math.max(0, width - detailX)
			heroHeight = math.max(0, math.floor((height - gap) / 2))
			mapY = heroHeight + gap
			factsWidth = math.min(ctx.Px(Tokens.Space.StatPanelWidth), heroWidth)
			mapWidth = math.max(0, heroWidth - factsWidth - gap)
			factsX = detailX + mapWidth + gap
			factsY = mapY
			factsHeight = math.max(0, height - mapY)
		end
		local mapHeight = math.max(0, height - mapY)

		setProperty(tree.ListHost, "Position", UDim2.fromOffset(0, 0))
		setProperty(tree.ListHost, "Size", UDim2.fromOffset(listWidth, height))
		setProperty(tree.Empty.Instance, "Position", UDim2.fromOffset(detailX, 0))
		panelRect(tree, "HeroRect", tree.Hero, detailX, 0, heroWidth, heroHeight)
		panelRect(tree, "MapRect", tree.Map, detailX, mapY, mapWidth, mapHeight)
		panelRect(tree, "FactsRect", tree.Facts, factsX, factsY, factsWidth, factsHeight)

		-- The label sits in the plate's content, which the plate insets by `pad` on every side.
		patch(tree, "HeroIndexPad", tree.HeroIndexPlate, { Pad = design(pad) })
		tree.IndexInset = pad + pad
		tree.FitIndexPlate()
		setProperty(tree.HeroTitle.Instance, "Position", UDim2.fromOffset(pad, heroHeight - pad))
		setProperty(tree.MapPlaceholder.Instance, "Position", UDim2.fromOffset(pad, pad))
		patch(tree, "HeroTitleWidth", tree.HeroTitle, { MaxWidth = design(math.max(1, heroWidth - pad - pad)) })
		patch(tree, "StatusWidth", tree.StatusLine, { MaxWidth = design(math.max(1, if tree.Compact then math.floor(width / 3) else listWidth)) })
		if tree.Hint then
			-- On the middle of the button line (the slot is the line's bottom edge).
			local line = Text.SizeFor("Label", ctx)
			setProperty(tree.Hint.Instance, "Position", UDim2.fromOffset(0, -math.max(0, math.floor((buttonHeight - line) / 2))))
		end
	end

	-- Compact: the facts panel ends under its last row instead of running down the page as a half-empty box.
	local function fitFacts(tree)
		if not tree.Compact then
			return
		end
		local rows = tree.FactList.Instance.Size.Y.Offset
		local pad = ctx.Px(Tokens.Space.TouchGap)
		local bodyHeight = tree.Body.Size.Y.Offset
		local height = if rows > 0 then math.min(bodyHeight, rows + pad + pad) else bodyHeight
		if tree.FactsHeight ~= height then
			tree.FactsHeight = height
			patch(tree, "FactsRect", tree.Facts, { Height = design(height) })
		end
	end

	-- Render: patches only -----------------------------------------------------------------------------------------
	local function listItems(tree)
		local result = {}
		for index, item in ipairs(model.Items()) do
			-- Route type and modes on the line over the name (a ListRow has one sub-line, above the title).
			local row = { Key = item.Key, Title = item.Title, Sub = item.TypeLine }
			if item.Thumbnail ~= "" then
				row.Image = item.Thumbnail
			end
			if tree.Compact then
				-- c05: name, type and modes, laps and players, prize chip.
				row.Right = item.Laps .. " " .. STRINGS.Laps .. "  \u{00B7}  " .. item.Players
				row.Chip = item.Prize
				row.ChipKind = "Yellow"
			end
			-- Regular (mockup 02): no chip and no right-hand text. Whatever sits on the right of a ListRow is taken
			-- off the title's width, and the route chip cut the event name short; laps are in the facts panel.
			result[index] = row
		end
		return result
	end

	-- Compact (c05 -> c06): a press on a row opens its detail page. Called after every SetItems, because the kit
	-- list hands its pooled rows to new keys.
	local function hookRows(tree)
		table.clear(tree.RowKeys)
		for _, item in ipairs(model.Items()) do
			local row = tree.List.Row(item.Key)
			local button = row and row.Instance
			if button then
				tree.RowKeys[button] = item.Key
				if not tree.RowHooked[button] then
					tree.RowHooked[button] = true
					scope:connect(button.Activated, function()
						local key = tree.RowKeys[button]
						if destroyed or tree.Destroyed or key == nil or not button.Active then
							return
						end
						if model.Select(key) then
							model.SetPage("Detail")
						end
					end)
				end
			end
		end
	end

	local function factRows(item)
		local result = {}
		for index, fact in ipairs(item.Facts) do
			local icon = FACT_ICON[fact.Id]
			if fact.Id == "Route" then
				icon = if fact.Circuit then "loop" else "route"
			end
			result[index] = { Id = fact.Id, Icon = icon, Label = fact.Label, Value = fact.Value, Kind = fact.Kind }
		end
		return result
	end

	local function focusOnOpen(tree)
		if not Input.ShouldEnterFocus(ctx) then
			return
		end
		local key = model.SelectedKey()
		local row = key and tree.List.Row(key) or nil
		local target = (row and row.Instance) or tree.FirstButton.Instance
		pcall(function()
			GuiService.SelectedObject = target
		end)
	end

	-- Compact: the page swap hides whatever held the focus, so the focus follows to the page that shows.
	local function focusOnPage(tree, detailPage)
		if not Input.ShouldEnterFocus(ctx) then
			return
		end
		local target
		if detailPage then
			target = if model.CanAct() then tree.TeleportButton.Instance else tree.Buttons.Button("Back").Instance
		else
			local key = model.SelectedKey()
			local row = key and tree.List.Row(key) or nil
			target = (row and row.Instance) or tree.FirstButton.Instance
		end
		pcall(function()
			GuiService.SelectedObject = target
		end)
	end

	local function focusOnClose()
		pcall(function()
			local current = GuiService.SelectedObject
			if current and current:IsDescendantOf(root) then
				GuiService.SelectedObject = nil
			end
		end)
	end

	local function render(_reason)
		if destroyed or not built then
			return
		end
		local tree = built
		local compact = tree.Compact
		local item, index, count = model.Detail()
		local hasDetail = item ~= nil
		local detailPage = compact and model.Page() == "Detail" and hasDetail
		local media = if compact and hasDetail then (if item.MapImage ~= "" then "M" else "-") .. (if item.TrackImage ~= "" then "T" else "-") else tree.LayoutMedia
		if tree.LayoutPage ~= detailPage or tree.LayoutMedia ~= media then
			layout(tree) -- the Compact pages have different headers, and the detail column follows the event's images
		end

		-- Header and filter tabs.
		patch(tree, "Header", tree.Header, {
			Count = tostring(count) .. " " .. (if count == 1 then STRINGS.Event else STRINGS.Events),
			Visible = not detailPage,
		})
		local filter = model.Filter()
		if tree.Filter ~= filter then
			tree.Filter = filter
			tree.Header.Tabs.Select(filter)
		end
		if compact then
			patch(tree, "DetailHeader", tree.DetailHeader, { Title = if hasDetail then item.Title else "", Visible = detailPage })
		end

		-- List: the keyed pool takes new items only when the rows changed; a selection is one Select call.
		local version = model.RowsVersion()
		if tree.RowsVersion ~= version then
			tree.RowsVersion = version
			tree.SelectedKey = nil
			tree.List.SetItems(listItems(tree))
			if compact then
				hookRows(tree)
			end
		end
		local selectedKey = model.SelectedKey()
		if tree.SelectedKey ~= selectedKey then
			tree.SelectedKey = selectedKey
			if selectedKey then
				tree.List.Select(selectedKey)
			end
		end
		setProperty(tree.ListHost, "Visible", not detailPage)

		-- Detail.
		local showDetail = hasDetail and (detailPage or not compact)
		patch(tree, "Hero", tree.Hero, { Visible = showDetail })
		-- Compact draws the map panel only for an event that has a map image.
		patch(tree, "Map", tree.Map, { Visible = showDetail and (not compact or item.MapImage ~= "") })
		patch(tree, "Facts", tree.Facts, { Visible = showDetail })
		patch(tree, "Empty", tree.Empty, { Visible = not hasDetail })
		if hasDetail then
			patch(tree, "HeroIndex", tree.HeroIndex, {
				Text = STRINGS.Event .. " " .. tostring(index) .. " " .. STRINGS.Of .. " " .. tostring(count),
			})
			patch(tree, "HeroTitle", tree.HeroTitle, { Text = if compact then item.TypeLine else item.Title })
			setProperty(tree.HeroPicture, "Image", item.TrackImage)
			setProperty(tree.MapPicture, "Image", item.MapImage)
			patch(tree, "MapPlaceholder", tree.MapPlaceholder, { Visible = item.MapImage == "" })
			if tree.FactsItem ~= item then
				tree.FactsItem = item
				tree.FactList.SetRows(factRows(item))
			end
			fitFacts(tree)
		end

		-- Actions (230-239): both disabled without a selection.
		local canAct = model.CanAct()
		patch(tree, "Teleport", tree.TeleportButton, { Disabled = not canAct, Text = model.TeleportText() })
		patch(tree, "Route", tree.RouteButton, { Disabled = not canAct })
		if compact then
			patch(tree, "Buttons", tree.Buttons, { Visible = detailPage })
			patch(tree, "ListButtons", tree.ListButtons, { Visible = not detailPage })
		end

		-- The inline error line (433, 447).
		local status = model.Status()
		patch(tree, "StatusLine", tree.StatusLine, {
			Text = status or "",
			Visible = status ~= nil and (detailPage or not compact),
		})
		if compact then
			patch(tree, "Hint", tree.Hint, { Visible = not detailPage and hasDetail })
		end

		if compact and tree.FocusPage ~= detailPage then
			local moved = tree.FocusPage ~= nil and shown == true and model.IsOpen() == true
			tree.FocusPage = detailPage
			if moved then
				focusOnPage(tree, detailPage)
			end
		end

		-- Drawn first, shown after. Root Visible only; never ScreenGui.Enabled.
		local isOpen = model.IsOpen() == true
		if shown ~= isOpen then
			shown = isOpen
			layer.SetVisible(isOpen)
			if isOpen then
				focusOnOpen(tree)
			else
				focusOnClose()
			end
		end
	end

	local function rebuild()
		if built then
			destroyTree(built)
		end
		built = build()
		layout(built)
		if not built.Compact and model.Page() ~= "List" then
			model.SetPage("List") -- the page exists on Compact only
		end
		render("Rebuild")
	end

	built = build()
	layout(built)
	render("Mount")

	scope:connect(model.Changed, function(reason)
		render(reason)
	end)
	if ctx.Changed then
		scope:connect(ctx.Changed, function(change)
			if destroyed or (type(change) == "table" and change.Layout == false) then
				return
			end
			-- Deferred so the layer has moved its slots first.
			task.defer(function()
				if destroyed or not built then
					return
				end
				if (ctx.Class == "Compact") ~= built.Compact then
					rebuild()
				else
					layout(built)
				end
			end)
		end)
	end

	view.Render = render

	-- The client hands over the player; the kit chip then reads leaderstats.Cash itself (API2 3.5).
	function view.BindCash(player)
		cashPlayer = player
		if built then
			bindCash(built)
		end
	end

	function view.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if built then
			destroyTree(built)
			built = nil
		end
		scrim.Destroy()
	end

	return view
end

return View
