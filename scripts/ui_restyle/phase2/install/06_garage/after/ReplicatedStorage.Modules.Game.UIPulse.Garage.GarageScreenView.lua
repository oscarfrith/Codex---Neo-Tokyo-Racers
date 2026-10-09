-- Owns the dealership and customise screens as kit components (header and tabs, tile rail, Shop / Owned switch, slot and area picker, stat panel, button row, status strip) for Regular and Compact; it does not own state, remotes, attributes, bindables, prices or the 3D preview.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.GarageScreenView. Requires: Tokens, Contracts, Layers, Text, Surface, Controls, Collections, Data, Input, GarageRoutes, PaintView, GarageModals.
--
-- Draws model.Page() (the table the model built when it last drew a page). A page is built the first time it shows
-- and patched afterwards: a selection, a tab change or a Cash change creates and destroys nothing. Only one of the
-- two pages is kept (going from the dealership to customise, or back, releases the other), and secondary parts (the
-- stat panel of customise, the Shop / Owned switch, the picker, the upgrade budget, the paint controls, the
-- modals) are built on first use.
--
-- Names other scripts read (API2 5.7): under the layer root (CanonicalCanvas) the dealership page is
-- CanonicalGarageBrowser and the customise page is CanonicalGarageWorkspace; inside them the onboarding targets are
-- applied through Kit.Input.Mark only (Text.Dealership, Categories, Stats, Capacity, VehicleScroller,
-- TutorialCardScroller, UpgradeBudget, Card, Card.<id>, Page.<id>).
local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Contracts = require(Kit.Contracts)
local Layers = require(Kit.Layers)
local Text = require(Kit.Text)
local Surface = require(Kit.Surface)
local Controls = require(Kit.Controls)
local Collections = require(Kit.Collections)
local Data = require(Kit.Data)
local Input = require(Kit.Input)
local Routes = require(script.Parent.GarageRoutes)
local PaintView = require(script.Parent.PaintView)
local GarageModals = require(script.Parent.GarageModals)

local View = {}

local TEXT = Routes.Text
local Space = Tokens.Space
local DOT = " \u{00B7} "
local FIELD = "\30"
local ROW = "\31"

-- Pure. The mark key of a tutorial card: Card.<slot id> when the generated contract has one, else Card.
function View._cardMark(item: any): string
	local key = item.SlotId ~= nil and ("Card." .. tostring(item.SlotId)) or nil
	if key and Contracts.Marks[key] ~= nil then
		return key
	end
	return "Card"
end

-- Pure. A model item as Collections.Tile props (plus Key). money(amount, compact) is Kit.Data.Money.
function View._tileProps(item: any, compact: boolean, money: (any, boolean) -> string): any
	local price = item.PriceText
	if price == nil and item.PriceAmount ~= nil then
		price = money(item.PriceAmount, compact)
	end
	local sub = item.Sub
	if item.Kind == "Module" and item.Rating ~= nil then
		-- The tile badge needs a tier; a module rating has none, so it joins the status line.
		sub = ((sub ~= nil and sub ~= "") and (tostring(sub) .. DOT) or "") .. tostring(item.Rating)
	end
	local icon = item.Icon
	local image = (item.Image ~= nil and item.Image ~= "") and item.Image or nil
	if image == nil and icon == nil then
		icon = item.Kind == "Vehicle" and "car" or (item.Kind == "Upgrade" and "upgrade" or "customise")
	end
	return {
		Key = item.Key,
		Title = tostring(item.Title or ""),
		Sub = sub,
		State = item.Selected and "Selected" or "Default",
		Status = item.Status or "None",
		ChipLeft = item.ChipLeft,
		ChipRight = item.ChipRight,
		ChipRightKind = item.ChipRight ~= nil and item.ChipRightKind or nil,
		Price = price,
		Image = image,
		Icon = icon,
		Tier = item.Tier,
		Rating = item.Tier ~= nil and item.Rating or nil,
		Selectable = item.Selectable,
		MarkKey = item.Card and View._cardMark(item) or nil,
	}
end

-- Pure. Everything of a tile list that reaches the screen, as one string (a render with the same string is skipped).
function View._signature(list: { any }): string
	local parts = {}
	for _, props in ipairs(list) do
		table.insert(parts, table.concat({
			props.Key, tostring(props.Title), tostring(props.Sub), tostring(props.Status), tostring(props.ChipLeft),
			tostring(props.ChipRight), tostring(props.ChipRightKind), tostring(props.Price), tostring(props.Image),
			tostring(props.Icon), tostring(props.Tier), tostring(props.Rating), tostring(props.Selectable),
		}, FIELD))
	end
	return table.concat(parts, ROW)
end

-- Pure. The count beside a rail heading: "2/6" with a selection, "6" without, nil for an empty rail.
function View._count(items: { any }, selected: string?): string?
	local total = #items
	if total == 0 then
		return nil
	end
	for index, item in ipairs(items) do
		if item.Key == selected then
			return tostring(index) .. "/" .. tostring(total)
		end
	end
	return tostring(total)
end

-- Pure. The main button's text: the action word and, for a purchase, the price the model passed through.
function View._actionText(action: any, money: (any, boolean) -> string): string
	if action.Amount ~= nil then
		return tostring(action.Text) .. " " .. money(action.Amount, false)
	end
	return tostring(action.Text)
end

-- Pure. The main button a page keeps while nothing is selected (shown disabled), so selecting a tile only
-- patches a button that already exists. nil: the page has no main action.
function View._idleAction(page: any): any
	if page.Id == "Dealership" then
		return page.Mode == "Customisation" and { Text = TEXT.Customise, Kind = "Main" } or { Text = TEXT.Buy, Kind = "Buy" }
	elseif page.Id == "Parts" and page.Source ~= nil then
		return page.Source.Selected == "Owned" and { Text = TEXT.Equip, Kind = "Main" } or { Text = TEXT.Buy, Kind = "Buy" }
	elseif page.Id == "Upgrades" and page.Budget ~= nil and #page.Items > 0 then
		return { Text = TEXT.Upgrade, Kind = "Buy" }
	elseif page.Id == "Paint" and page.Paint == nil then
		for _, item in ipairs(page.Items) do
			if item.Kind == "Action" and item.Key ~= "Paint" and item.Selectable ~= false then
				return { Text = TEXT.Buy, Kind = "Buy" }
			end
		end
	end
	return nil
end

-- Pure. The button row of a page as ButtonRow specs without callbacks: { {Id, Variant, Text, Icon, Disabled} }.
function View._buttons(page: any, money: (any, boolean) -> string): { any }
	local list = {}
	local buttons = page.Buttons or {}
	local action = page.Action
	local idle = action == nil and View._idleAction(page) or nil
	local shown = action or idle
	if buttons.Exit and buttons.Exit.Visible then
		table.insert(list, { Id = "Exit", Variant = "Default", Text = TEXT.Exit, Icon = "exit" })
	end
	if buttons.Back and buttons.Back.Visible then
		table.insert(list, { Id = "Back", Variant = "Default", Text = TEXT.Back, Icon = "back", Disabled = buttons.Back.Disabled == true })
	end
	if buttons.Drive and buttons.Drive.Visible then
		table.insert(list, { Id = "Drive", Variant = shown == nil and "Main" or "Default", Text = TEXT.Drive, Icon = "steering_wheel" })
	end
	if shown ~= nil then
		table.insert(list, {
			Id = "Action",
			Variant = shown.Kind == "Buy" and "Buy" or "Main",
			Text = View._actionText(shown, money),
			Disabled = action == nil,
		})
	end
	return list
end

local function put(instance: any, property: string, value: any)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function pageFrame(name: string, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Active = false -- a full-screen frame must not block the preview camera's orbit
	frame.Size = UDim2.fromScale(1, 1)
	frame.Visible = false
	frame.Parent = parent
	return frame
end

-- A component in a zero-size slot stands on the slot's anchor; in a sized slot it fills from the top-left.
local function seat(instance: GuiObject, slot: GuiObject)
	local size = slot.Size
	if size.X.Scale == 0 and size.X.Offset == 0 then
		instance.AnchorPoint = slot.AnchorPoint
	end
end

--[[ View.Mount(layer, model, scope, opts)
	layer  the static garage layer (Layers.Create("CanonicalGarageGui", {RootName = "CanonicalCanvas", ...})) or a stage
	model  Garage.GarageModel, or a fake with the same getters and intents (gallery, tests)
	opts   { Live: Layer?, ConfirmHost: GuiObject? }  Live: the layer the status strip (Cash) sits on; default layer
	Returns { Render(reason?), Destroy(), BindCash(player) }.
]]
function View.Mount(layer: any, model: any, scope: any, opts: any)
	opts = opts or {}
	local ctx = layer.Metrics
	local live = opts.Live or layer
	local destroyed = false
	local built: any = nil
	local modals: any = nil
	local cashPlayer: any = nil
	local layerShown: boolean? = nil
	local own = {}

	local function money(amount: any, compact: boolean): string
		return Data.Money(tonumber(amount) or 0, compact)
	end

	-- The static layer root (CanonicalCanvas) is never hidden here: the owned-garage desk mounts its own root in
	-- it and shows without a dealership or customise session. This view hides its two pages, its scrim and the
	-- live layer instead.
	local scrim: any = nil
	if layer.ScrimRoot then
		scrim = Surface.Scrim(layer.ScrimRoot, { Kind = "Garage", Visible = false }, scope)
		table.insert(own, scrim)
	end

	local function track(b: any, item: any): any
		table.insert(b.Bag, item)
		return item
	end

	local function release(bag: { any })
		for index = #bag, 1, -1 do
			local item = bag[index]
			bag[index] = nil
			if typeof(item) == "Instance" then
				item:Destroy()
			elseif typeof(item) == "RBXScriptConnection" then
				item:Disconnect()
			elseif type(item) == "table" and item.Destroy then
				item.Destroy()
			elseif type(item) == "table" and item.Disconnect then
				item:Disconnect()
			end
		end
	end

	local function buttonSpecs(page: any, callbacks: any): ({ any }, string)
		local list = View._buttons(page, money)
		local parts = {}
		for _, spec in ipairs(list) do
			table.insert(parts, table.concat({ spec.Id, spec.Variant, spec.Text, tostring(spec.Disabled) }, FIELD))
			spec.OnActivated = callbacks[spec.Id]
		end
		return list, table.concat(parts, ROW)
	end

	----------------------------------------------------------------------------------------------------------------
	-- Build (once per size class).
	----------------------------------------------------------------------------------------------------------------
	local function build(): any
		local b: any = { Class = ctx.Class, Compact = ctx.Class == "Compact", Bag = {} }

		b.Callbacks = {
			Exit = function()
				model.Exit()
			end,
			Back = function()
				model.Back()
			end,
			Drive = function()
				model.Drive()
			end,
			Action = function()
				model.Action()
			end,
		}
		b.OnCategory = function(id)
			model.SelectCategory(id)
		end
		b.OnTab = function(id)
			model.SelectTab(id)
		end

		return b
	end

	-- Status strip (garage spaces with its plus, Cash with its plus), on the live layer: Cash counts there. Built
	-- when a page first shows, never at start: the Cash chip reaches the shared money formatter (API2 3.5).
	local function ensureCluster(b: any)
		if b.Cluster then
			return
		end
		local statusSlot = live.Slot("TopRight")
		b.Cluster = track(b, Data.StatusCluster(statusSlot, {
			Name = "Status",
			Mode = "Garage",
			Spaces = "0 / 0",
			ShowPlus = true,
			Visible = false,
			OnSpacesPlus = function()
				model.ShowProperties() -- GarageUI L178 OnCapacity
			end,
			OnCashPlus = function()
				model.ShowCash() -- GarageUI L178 OnCash
			end,
		}, scope))
		seat(b.Cluster.Instance, statusSlot)
		if cashPlayer ~= nil then
			b.Cluster.Cash.Bind(cashPlayer)
		end
	end

	-- A page's parts live in their own bag, so the page can be released as a whole.
	local function keep(page: any, item: any): any
		table.insert(page.Bag, item)
		return item
	end

	-- Dealership page.
	local function ensureBrowser(b: any): any
		if b.BrowserPage then
			return b.BrowserPage
		end
		local page: any = { Bag = {}, Mem = {}, RailMem = {} }
		b.BrowserPage = page
		b.Browser = keep(page, pageFrame("CanonicalGarageBrowser", layer.Root))
		local browserStage = keep(page, Layers.Stage(b.Browser, ctx, "Scene"))
		b.BrowserHeader = keep(page, Controls.Header(browserStage.Slot("TopLeft"), {
			Title = TEXT.DealershipTitle,
			Sub = "",
			MarkKey = "Text.Dealership",
			Shadow = true,
			Tabs = {
				Tabs = { { Id = "__ALL", Text = TEXT.AllCategories } },
				Selected = "__ALL",
				Bumpers = true,
				OnSelected = b.OnCategory,
			},
		}, scope))
		Input.Mark(b.BrowserHeader.Tabs.Instance, "Categories")
		local browserColumn = browserStage.Slot("RightColumn")
		b.BrowserStats = keep(page, Data.StatPanel(browserColumn, { Title = "", Rows = {} }, scope))
		seat(b.BrowserStats.Instance, browserColumn)
		Input.Mark(b.BrowserStats.Instance, "Stats")
		-- The strip itself is on the live layer; this empty frame of the same box is what the Capacity mark names
		-- inside the dealership page (Classic onboarding looks under CanonicalGarageBrowser).
		local proxySlot = browserStage.Slot("TopRight")
		b.CapacityProxy = pageFrame("CapacityBox", proxySlot)
		b.CapacityProxy.Visible = true
		b.CapacityProxy.Size = b.Cluster.Instance.Size
		seat(b.CapacityProxy, proxySlot)
		Input.Mark(b.CapacityProxy, "Capacity")
		b.BrowserRail = keep(page, Collections.Rail(browserStage.Slot("BottomRail"), {
			Heading = "",
			SelectOn = "Activate", -- a tile here previews a purchase or navigates: gamepad focus only highlights
			OnSelected = function(key)
				page.RailMem.Selected = key
				model.SelectItem(key)
			end,
		}, scope))
		Input.Mark(b.BrowserRail.Instance, "VehicleScroller")
		b.BrowserButtons = keep(page, Controls.ButtonRow(browserStage.Slot("RailButtons"), { Buttons = {} }, scope))
		return page
	end

	-- Customise page: a body (the current tab's tutorial page) under a shell (header, stats, buttons, paint).
	local function ensureWorkspace(b: any): any
		if b.WorkspacePage then
			return b.WorkspacePage
		end
		local page: any = { Bag = {}, Mem = {}, RailMem = {} }
		b.WorkspacePage = page
		b.Workspace = keep(page, pageFrame("CanonicalGarageWorkspace", layer.Root))
		b.Body = pageFrame("Body", b.Workspace)
		b.BodyStage = keep(page, Layers.Stage(b.Body, ctx, "Scene"))
		b.Shell = keep(page, Layers.Stage(b.Workspace, ctx, "Scene"))
		local tabSpecs = {}
		for _, tab in ipairs(Routes.Tabs) do
			table.insert(tabSpecs, { Id = tab.Id, Text = tab.Text, Icon = tab.Icon, MarkKey = tab.Card })
		end
		b.Header = keep(page, Controls.Header(b.Shell.Slot("TopLeft"), {
			Title = TEXT.CustomiseTitle,
			Sub = "",
			Shadow = true,
			Tabs = { Tabs = tabSpecs, Selected = Routes.HubTab, Bumpers = true, OnSelected = b.OnTab },
		}, scope))
		Input.Mark(b.Header.Tabs.Instance, Routes.HomeMark)
		b.Buttons = keep(page, Controls.ButtonRow(b.Shell.Slot("RailButtons"), { Buttons = {} }, scope))
		b.Rail = keep(page, Collections.Rail(b.BodyStage.Slot("BottomRail"), {
			Heading = "",
			SelectOn = "Activate", -- a tile here previews a purchase or navigates: gamepad focus only highlights
			OnSelected = function(key)
				page.RailMem.Selected = key
				model.SelectItem(key)
			end,
		}, scope))
		Input.Mark(b.Rail.Instance, "TutorialCardScroller")
		local emptySlot = b.BodyStage.Slot("BottomLeft")
		b.Empty = keep(page, Text.Label(emptySlot, { Name = "EmptyLine", Text = "", Role = "Label", Colour = "TextSecondary", Visible = false }, scope))
		seat(b.Empty.Instance, emptySlot)
		return page
	end

	-- Releases one page and everything built for it (the other page is about to show).
	local PAGE_FIELDS = {
		BrowserPage = { "Browser", "BrowserHeader", "BrowserStats", "CapacityProxy", "BrowserRail", "BrowserButtons" },
		WorkspacePage = { "Workspace", "Body", "BodyStage", "Shell", "Header", "Stats", "Buttons", "Rail", "Empty", "Segment",
			"Picker", "BudgetText", "BudgetBar", "Paint" },
	}
	local function releasePage(b: any, name: string)
		local page = b[name]
		if not page then
			return
		end
		b[name] = nil
		release(page.Bag)
		for _, field in ipairs(PAGE_FIELDS[name]) do
			b[field] = nil
		end
	end

	-- The customise stat panel (the paint shop shows none, GarageUI L631).
	local function ensureStats(b: any)
		if b.Stats then
			return
		end
		local column = b.Shell.Slot("RightColumn")
		b.Stats = keep(b.WorkspacePage, Data.StatPanel(column, { Title = "", Rows = {} }, scope))
		seat(b.Stats.Instance, column)
	end

	-- The Shop / Owned switch, on the rail's heading line (preview r03). Triggers switch it.
	local function ensureSegment(b: any)
		if b.Segment then
			return
		end
		b.Segment = keep(b.WorkspacePage, Controls.Tabs(b.Rail.HeadingRight, {
			Name = "Source",
			Style = "Segment",
			Triggers = true,
			LayoutOrder = 1,
			Tabs = { { Id = "Buy", Text = "Shop" }, { Id = "Owned", Text = "Owned" } },
			Selected = "Buy",
			OnSelected = function(id)
				model.SelectSource(id)
			end,
		}, scope))
	end

	-- The slot picker (Upgrades) and area picker (Paint): the Classic left rail of cards as one dropdown.
	local function ensurePicker(b: any)
		if b.Picker then
			return
		end
		b.Picker = keep(b.WorkspacePage, Controls.Dropdown(b.BodyStage.Slot("TopLeft"), {
			Name = "Picker",
			Label = TEXT.ModulePicker,
			Options = {},
			Selected = "",
			OnSelected = function(id)
				model.SelectPicker(id)
			end,
		}, scope))
		Input.Mark(b.Picker.Instance, "Categories")
	end

	-- Upgrade points, on the rail's heading line (preview r02).
	local function ensureBudget(b: any)
		if b.BudgetText then
			return
		end
		b.BudgetText = keep(b.WorkspacePage, Text.Label(b.Rail.HeadingRight, { Name = "BudgetText", Text = "", Role = "Label", LayoutOrder = 2 }, scope))
		Input.Mark(b.BudgetText.Instance, "UpgradeBudget")
		b.BudgetBar = keep(b.WorkspacePage, Data.SegmentedBar(b.Rail.HeadingRight, { Name = "BudgetBar", Value = 0, Segments = 10, LayoutOrder = 3 }, scope))
	end

	local function ensurePaint(b: any)
		if b.Paint then
			return
		end
		b.Paint = keep(b.WorkspacePage, PaintView.New(b.Shell.Slot("TopLeft"), b.Shell.Slot("BottomRail"), {
			OnChannel = function(channel)
				model.PaintChannel(channel)
			end,
			OnColour = function(channel, colour, commit)
				model.PaintColour(channel, colour, commit)
			end,
		}, scope, ctx))
	end

	----------------------------------------------------------------------------------------------------------------
	-- Patch helpers. Each keeps what it last wrote and writes only on a change.
	----------------------------------------------------------------------------------------------------------------
	local function syncRail(rail: any, mem: any, items: { any }, selected: string?, compact: boolean)
		local list = {}
		for _, item in ipairs(items) do
			table.insert(list, View._tileProps(item, compact, money))
		end
		local signature = View._signature(list)
		if mem.Signature == signature and mem.Selected == selected then
			return
		end
		if selected == nil and mem.Selected ~= nil then
			-- The kit rail keeps its own selection while the key stays in the list and has no deselect; an empty
			-- list drops it. The pool stays, so nothing is created or destroyed.
			rail.SetItems({})
		end
		rail.SetItems(list)
		if selected ~= nil then
			rail.Select(selected)
		end
		mem.Signature = signature
		mem.Selected = selected
	end

	local function syncStats(panel: any, mem: any, name: string, stats: any, price: string?)
		if stats == nil then
			panel.Set({ Visible = false })
			return
		end
		local parts = { tostring(stats.Empty), tostring(stats.Title), tostring(stats.Tier), tostring(stats.Rating), tostring(price) }
		for _, row in ipairs(stats.Rows or {}) do
			table.insert(parts, row.Id .. ":" .. tostring(row.Value) .. ":" .. tostring(row.Preview) .. ":" .. tostring(row.Max))
		end
		local signature = table.concat(parts, FIELD)
		if mem[name] ~= signature then
			mem[name] = signature
			panel.SetHeader({
				Title = tostring(stats.Empty or stats.Title or ""),
				Tier = stats.Tier,
				Rating = stats.Rating,
				Sub = stats.Empty == nil and stats.Sub or nil,
				Price = price,
			})
			panel.SetRows(stats.Rows or {})
		end
		panel.Set({ Visible = true })
	end

	local function syncButtons(row: any, mem: any, name: string, page: any, callbacks: any)
		local list, signature = buttonSpecs(page, callbacks)
		if mem[name] ~= signature then
			mem[name] = signature
			row.Set({ Buttons = list })
		end
	end

	local function syncHeader(header: any, mem: any, name: string, title: string, sub: string)
		local signature = title .. FIELD .. sub
		if mem[name] ~= signature then
			mem[name] = signature
			header.Set({ Title = title, Sub = sub })
		end
	end

	local function setLayerVisible(visible: boolean)
		if layerShown == visible then
			return
		end
		layerShown = visible
		if scrim then
			scrim.Set({ Visible = visible })
		end
		if live ~= layer then
			live.SetVisible(visible)
		end
	end

	----------------------------------------------------------------------------------------------------------------
	-- Dealership.
	----------------------------------------------------------------------------------------------------------------
	local function renderBrowser(b: any, page: any)
		local mem = b.BrowserPage.Mem
		syncHeader(b.BrowserHeader, mem, "BrowserHeader", tostring(page.Title), tostring(page.Message or page.Sub or ""))

		local specs, parts = {}, {}
		for _, item in ipairs(page.Categories.Items) do
			table.insert(specs, { Id = item.Id, Text = item.Text })
			table.insert(parts, item.Id .. FIELD .. tostring(item.Text))
		end
		local signature = table.concat(parts, ROW)
		if mem.Categories ~= signature then
			mem.Categories = signature
			b.BrowserHeader.Set({ Tabs = { Tabs = specs, Selected = page.Categories.Selected, Bumpers = true, OnSelected = b.OnCategory } })
		else
			b.BrowserHeader.Tabs.Set({ Selected = page.Categories.Selected })
		end

		syncRail(b.BrowserRail, b.BrowserPage.RailMem, page.Items, page.Selected, b.Compact)
		b.BrowserRail.SetHeading(tostring(page.Heading or ""), View._count(page.Items, page.Selected))

		-- The Compact stat panel carries the price row (preview c11): the catalogue price of the selected vehicle.
		local price = nil
		if page.Action ~= nil and page.Action.Amount ~= nil then
			price = money(page.Action.Amount, false)
		end
		syncStats(b.BrowserStats, mem, "BrowserStats", page.Stats, price)
		syncButtons(b.BrowserButtons, mem, "BrowserButtons", page, b.Callbacks)
		b.Cluster.Set({ Spaces = tostring(page.Spaces or "") })
		put(b.CapacityProxy, "Size", b.Cluster.Instance.Size)
	end

	----------------------------------------------------------------------------------------------------------------
	-- Customise (Parts, Upgrades, Paint) and post-purchase paint.
	----------------------------------------------------------------------------------------------------------------
	local function renderWorkspace(b: any, page: any)
		local mem = b.WorkspacePage.Mem
		local compact = b.Compact
		local tabPage = page.Tab ~= nil
		local colour = page.Paint ~= nil
		local gap = ctx.Px(Space.Gap)

		syncHeader(b.Header, mem, "Header", tostring(page.Title), tostring(page.Message or page.Sub or ""))
		b.Header.Tabs.Set({ Visible = tabPage })
		if tabPage then
			b.Header.Tabs.Set({ Selected = page.Tab })
		end

		-- The body carries the current tab's tutorial page; post-purchase paint has none, so the body is hidden.
		put(b.Body, "Visible", tabPage)
		if tabPage and mem.BodyMark ~= page.Tab then
			mem.BodyMark = page.Tab
			Input.Mark(b.Body, Routes.Tab(page.Tab).PageMark)
		end

		if page.Stats ~= nil then
			ensureStats(b)
		end
		if b.Stats then
			syncStats(b.Stats, mem, "Stats", page.Stats, nil)
		end
		syncButtons(b.Buttons, mem, "Buttons", page, b.Callbacks)
		b.Cluster.Set({ Spaces = tostring(page.Spaces or "") })

		-- Tile rail: every customise page except the colour controls.
		local railShown = tabPage and not colour
		b.Rail.Set({ Visible = railShown })
		if railShown then
			syncRail(b.Rail, b.WorkspacePage.RailMem, page.Items, page.Selected, compact)
			b.Rail.SetHeading(tostring(page.Heading or ""), View._count(page.Items, page.Selected))
		end
		local emptyText = (railShown and #page.Items == 0 and page.EmptyMessage) or ""
		b.Empty.Set({ Text = emptyText, Visible = emptyText ~= "" })

		-- Shop / Owned.
		if railShown and page.Source ~= nil then
			ensureSegment(b)
			local locked = page.Source.OwnedLocked == true
			if mem.SegmentLocked ~= locked then
				mem.SegmentLocked = locked
				local specs = {}
				for _, source in ipairs(page.Source.Items) do
					table.insert(specs, { Id = source.Id, Text = source.Text, Locked = source.Id == "Owned" and locked })
				end
				b.Segment.Set({ Tabs = specs, Selected = page.Source.Selected })
			end
			b.Segment.Set({ Selected = page.Source.Selected, Visible = true })
		elseif b.Segment then
			b.Segment.Set({ Visible = false })
		end

		-- Upgrade points.
		if railShown and page.Budget ~= nil then
			ensureBudget(b)
			local budget = page.Budget
			local capacity = math.max(0, tonumber(budget.Capacity) or 0)
			local used = math.clamp(tonumber(budget.Used) or 0, 0, capacity)
			b.BudgetText.Set({
				Text = string.upper(tostring(budget.Label)) .. " " .. tostring(used) .. "/" .. tostring(capacity) .. TEXT.Used,
				Visible = true,
			})
			b.BudgetBar.Set({ Value = capacity > 0 and used / capacity or 0, Segments = math.max(1, capacity), Visible = true })
		elseif b.BudgetText then
			b.BudgetText.Set({ Visible = false })
			b.BudgetBar.Set({ Visible = false })
		end

		-- Slot or area picker.
		local top = b.Header.Height() + gap
		if tabPage and page.Picker ~= nil then
			ensurePicker(b)
			local options, parts = {}, {}
			for _, option in ipairs(page.Picker.Options) do
				local text = tostring(option.Text) .. (option.Muted and (DOT .. TEXT.Empty) or "")
				table.insert(options, { Id = option.Id, Text = text })
				table.insert(parts, option.Id .. FIELD .. text)
			end
			local signature = tostring(page.Picker.Label) .. ROW .. table.concat(parts, ROW)
			if mem.Picker ~= signature then
				mem.Picker = signature
				b.Picker.Set({ Label = tostring(page.Picker.Label), Options = options, Selected = page.Picker.Selected })
			end
			b.Picker.Set({ Selected = page.Picker.Selected, Visible = true })
			put(b.Picker.Instance, "Position", UDim2.fromOffset(0, top))
			top = top + b.Picker.Instance.Size.Y.Offset + gap
		elseif b.Picker then
			b.Picker.Set({ Visible = false })
		end

		-- Paint controls and presets.
		if colour then
			ensurePaint(b)
			b.Paint.Show(page.Paint, page.Token)
			put(b.Paint.Controls, "Position", UDim2.fromOffset(0, top))
		elseif b.Paint then
			b.Paint.Hide()
		end
	end

	----------------------------------------------------------------------------------------------------------------
	-- Render.
	----------------------------------------------------------------------------------------------------------------
	local function render(_reason: string?)
		if destroyed then
			return
		end
		if built == nil or built.Class ~= ctx.Class then
			if built ~= nil then
				releasePage(built, "BrowserPage")
				releasePage(built, "WorkspacePage")
				release(built.Bag)
			end
			built = build()
		end
		local b = built
		local page = model.Page()
		local showing = model.Showing()
		setLayerVisible(showing ~= nil)
		if showing ~= nil then
			ensureCluster(b)
		end
		if showing == "Browser" then
			releasePage(b, "WorkspacePage")
			ensureBrowser(b)
		elseif showing == "Workspace" then
			releasePage(b, "BrowserPage")
			ensureWorkspace(b)
		end
		if b.Browser then
			put(b.Browser, "Visible", showing == "Browser")
		end
		if b.Workspace then
			put(b.Workspace, "Visible", showing == "Workspace")
		end
		if b.Cluster then
			b.Cluster.Set({ Visible = showing ~= nil })
		end
		if showing == "Browser" and page.Id == "Dealership" then
			renderBrowser(b, page)
		elseif showing == "Workspace" and page.Tabs ~= nil then
			renderWorkspace(b, page)
		end
		if modals == nil and model.Modal() ~= nil then
			modals = GarageModals.Mount(layer.Root, model, scope, { Host = opts.ConfirmHost })
		end
		if modals ~= nil then
			modals.Sync()
		end
	end

	if ctx.Changed ~= nil then
		table.insert(own, scope:connect(ctx.Changed, function()
			if not destroyed and built ~= nil and built.Class ~= ctx.Class then
				render("class")
			end
		end))
	end

	local self = {}
	self.Render = render

	-- API2 3.5: binds the Cash chip to leaderstats.Cash through the shared presenter. May yield once; the client
	-- calls it in its own task, never from start().
	function self.BindCash(player: any)
		cashPlayer = player
		if built ~= nil and built.Cluster ~= nil then
			built.Cluster.Cash.Bind(player)
		end
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if modals ~= nil then
			modals.Destroy()
			modals = nil
		end
		if built ~= nil then
			releasePage(built, "BrowserPage")
			releasePage(built, "WorkspacePage")
			release(built.Bag)
			built = nil
		end
		release(own)
	end

	built = build()
	return self
end

return View
