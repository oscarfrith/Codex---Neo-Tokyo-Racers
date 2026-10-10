-- Owns the gallery fixtures for the dealership and customise garage (every page and modal over a fake model); it does not own the gallery, the real model, a remote, a profile or a player attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Garage. Requires: Layers, GarageRoutes, GarageScreenView.
local pulse = script.Parent.Parent.Parent
local Layers = require(pulse.Kit.Layers)
local Routes = require(pulse.Garage.GarageRoutes)
local View = require(pulse.Garage.GarageScreenView)

local TEXT = Routes.Text
local LONG_NAME = "Meridian Grand Tourer Evoluzione" -- the longest strings a tile and the stat header must hold
local LONG_LINE = "Not enough Cash for this purchase. Earn more by racing, then come back."

local function signal()
	local handlers = {}
	local object = {}
	function object:Connect(handler)
		local entry = { handler }
		table.insert(handlers, entry)
		return {
			Disconnect = function()
				local index = table.find(handlers, entry)
				if index then
					table.remove(handlers, index)
				end
			end,
		}
	end
	function object:Fire(...)
		for _, entry in ipairs(table.clone(handlers)) do
			entry[1](...)
		end
	end
	return object
end

-- Example data only, in the shape GarageModel builds. Amounts are numbers, as the model passes them.
local function stats(title, tier, rating, preview)
	local values = { Speed = 80, Acceleration = 74, Handling = 63, Drift = 61, Braking = 62, Boost = 61 }
	local rows = {}
	for _, name in ipairs({ "Speed", "Acceleration", "Handling", "Drift", "Braking", "Boost" }) do
		local row = { Id = name, Label = name == "Acceleration" and "ACCEL" or string.upper(name), Value = values[name], Max = 180 }
		if preview and preview[name] then
			row.Preview = values[name] + preview[name]
		end
		table.insert(rows, row)
	end
	return { Title = title, Tier = tier, Rating = rating, Sub = { TEXT.Performance }, Rows = rows }
end

local function vehicles()
	return {
		{ Key = "C:stinger", Kind = "Vehicle", Title = "Stinger", Sub = "Exotic", Tier = "E", Rating = 220, PriceAmount = 84000, Status = "Owned", Card = true },
		{ Key = "C:zephyr", Kind = "Vehicle", Title = "Zephyr", Sub = "Exotic", Tier = "D", Rating = 390, PriceAmount = 150000, Status = "None", Card = true,
			Action = { Text = TEXT.Buy, Amount = 150000, Kind = "Buy" } },
		{ Key = "C:aurora", Kind = "Vehicle", Title = "Aurora", Sub = "Exotic", Tier = "C", Rating = 540, PriceAmount = 440000, Status = "None", Card = true,
			Action = { Text = TEXT.Buy, Amount = 440000, Kind = "Buy" } },
		{ Key = "C:endura", Kind = "Vehicle", Title = "Endura", Sub = "Exotic", Tier = "B", Rating = 675, PriceAmount = 1400000, Status = "Unaffordable", Card = true,
			Action = { Text = TEXT.Buy, Amount = 1400000, Kind = "Buy" } },
		{ Key = "C:rosso", Kind = "Vehicle", Title = "Rosso", Sub = "Exotic", Tier = "A", Rating = 800, PriceAmount = 4400000, Status = "Unaffordable", Card = true,
			Action = { Text = TEXT.Buy, Amount = 4400000, Kind = "Buy" } },
		{ Key = "C:long", Kind = "Vehicle", Title = LONG_NAME, Sub = "Piercer", Tier = "S", Rating = 936, PriceAmount = 12000000, Status = "Unaffordable", Card = true,
			Action = { Text = TEXT.Buy, Amount = 12000000, Kind = "Buy" } },
	}
end

local function selectIn(page, key)
	page.Selected = nil
	page.Action = nil
	for _, item in ipairs(page.Items) do
		item.Selected = item.Key == key
		if item.Selected then
			page.Selected = key
			page.Action = item.Action
		end
	end
	return page
end

local CATEGORIES = { { Id = "__ALL", Text = TEXT.AllCategories }, { Id = "C:exotic", Text = "Exotic" }, { Id = "C:muscle", Text = "Muscle" }, { Id = "C:piercer", Text = "Piercer" } }

local function dealership(selected)
	local page = {
		Id = "Dealership", Mode = "Dealership", Token = 1, Title = TEXT.DealershipTitle, Sub = TEXT.DealershipSub,
		Cash = 1000000, Spaces = "1 / 2", CapacityText = "1/2 Spaces", Heading = "Exotic",
		Categories = { Selected = "C:exotic", Items = CATEGORIES },
		Items = vehicles(), Buttons = { Exit = { Visible = true } },
		Stats = stats("Zephyr", "D", 390),
	}
	return selectIn(page, selected)
end

local function workspace(pageId, tabId, key, title)
	local back = key and Routes.Back[key]
	return {
		Id = pageId, Tab = tabId, Token = 1, Title = title or TEXT.CustomiseTitle, Sub = "",
		Tabs = { Selected = tabId, Items = Routes.Tabs },
		Cash = 3613696, Spaces = "3 / 4", CapacityText = "3/4 Spaces", Items = {},
		Buttons = {
			Back = { Visible = back ~= nil, Disabled = back ~= nil and not back.Available },
			Drive = { Visible = pageId ~= "PostPaint" },
			Next = { Visible = pageId == "PostPaint" },
		},
	}
end

local function slotOptions()
	return {
		{ Id = "Engine1", Text = "Front Engine" }, { Id = "Engine2", Text = "Rear Engine" }, { Id = "Stabilisers", Text = "Stabilisers" },
		{ Id = "Boost", Text = "Boost" }, { Id = "RearSpoiler", Text = "Spoiler", Muted = true },
	}
end

local PAGES = {}

function PAGES.Dealership()
	return dealership("C:zephyr")
end

function PAGES.DealershipUnaffordable()
	return dealership("C:long")
end

function PAGES.DealershipLoading()
	-- Just opened: the first row is selected on the next step.
	return dealership(nil)
end

function PAGES.DealershipEmpty()
	local page = dealership(nil)
	page.Items = {}
	page.Heading = "Muscle"
	page.Stats = { Empty = TEXT.NoVehicles, Title = "", Rows = {} }
	return page
end

function PAGES.DealershipError()
	local page = dealership("C:endura")
	page.Message = LONG_LINE
	return page
end

function PAGES.CustomisationPick()
	local page = dealership(nil)
	page.Mode = "Customisation"
	page.Title = TEXT.CustomisationTitle
	page.Sub = TEXT.CustomisationSub
	page.Items = {
		{ Key = "V:1", Kind = "Vehicle", Title = "Stinger", Sub = "Exotic", Tier = "D", Rating = 321, Status = "Owned", Card = true, Action = { Text = TEXT.Customise, Kind = "Main" } },
		{ Key = "V:2", Kind = "Vehicle", Title = "Zephyr", Sub = "Exotic", Tier = "D", Rating = 390, Status = "Owned", Card = true, Action = { Text = TEXT.Customise, Kind = "Main" } },
	}
	return selectIn(page, "V:1")
end

function PAGES.PostPaint()
	local page = workspace("PostPaint", nil, nil, TEXT.PostPaintTitle)
	page.Sub = TEXT.PostPaintSub
	page.Stats = stats("Zephyr", "D", 390)
	page.Paint = { Target = "WholeVehicle", Channels = { "Primary", "Secondary", "Detail" }, Selected = "Primary", Colours = {} }
	page.Action = { Text = TEXT.Customise, Kind = "Main", IsNext = true }
	return page
end

function PAGES.PartsSlots()
	local page = workspace("Parts", "Parts", "Parts.Slots")
	page.Sub = TEXT.PartsSlotsSub
	page.Mode = "Slots"
	page.Heading = TEXT.PartsHeading
	page.Stats = stats("Stinger", "D", 321)
	for _, option in ipairs(slotOptions()) do
		table.insert(page.Items, {
			Key = option.Id, Kind = "Slot", SlotId = option.Id, Title = option.Text, Card = true,
			Status = option.Muted and "None" or "Fitted",
			ChipRight = option.Muted and TEXT.Empty or TEXT.Equipped,
			ChipRightKind = option.Muted and "Pink" or "Tick",
		})
	end
	return page
end

local function partsOptions(source)
	local page = workspace("Parts", "Parts", "Parts.Options")
	page.Sub = TEXT.PartsOptionsSub
	page.Mode = "Options"
	page.Heading = "Spoiler"
	page.Source = { Selected = source, Items = Routes.Sources, OwnedLocked = false }
	page.Stats = stats("Stinger", "D", 321, { Handling = 3, Drift = 2, Boost = -2 })
	page.Lists = {
		Buy = {
			{ Key = "M:sp1", Kind = "Module", Title = "Exotic Stinger", Sub = "OWNED x1", ChipLeft = "Standard", Rating = 316, PriceAmount = 3000, Status = "None", Selectable = true, Card = true,
				Action = { Text = TEXT.Buy, Amount = 3000, Kind = "Buy" } },
			{ Key = "M:sp2", Kind = "Module", Title = "Exotic Stinger", Sub = "OWNED x0", ChipLeft = "EVO", Rating = 321, PriceAmount = 6000, Status = "None", Selectable = true, Card = true,
				Action = { Text = TEXT.Buy, Amount = 6000, Kind = "Buy" } },
			{ Key = "M:sp3", Kind = "Module", Title = "Exotic Zephyr", Sub = "BUY EXOTIC ZEPHYR TO UNLOCK", ChipLeft = "Standard", Rating = 318, PriceAmount = 42000, Status = "Locked", Selectable = true, Card = true },
			{ Key = "M:sp4", Kind = "Module", Title = LONG_NAME, Sub = "BUY " .. string.upper(LONG_NAME) .. " TO UNLOCK", ChipLeft = "GT", PriceAmount = 1200000, Status = "Locked", Selectable = true, Card = true },
		},
		Owned = {
			{ Key = "I:1", Kind = "Module", Title = "Exotic Stinger", Sub = "EQUIPPED", ChipLeft = "Standard", Rating = 316, Status = "Fitted", ChipRight = TEXT.Equipped, ChipRightKind = "Tick", Card = true },
			{ Key = "I:2", Kind = "Module", Title = "Exotic Stinger", Sub = "AVAILABLE", ChipLeft = "EVO", Rating = 321, Status = "Owned", Card = true, Action = { Text = TEXT.Equip, Kind = "Main" } },
			{ Key = "I:3", Kind = "Module", Title = "Exotic Zephyr", Sub = "IN USE BY ZEPHYR", ChipLeft = "Standard", Rating = 318, Status = "Owned", ChipRight = TEXT.InUse, ChipRightKind = "Neutral", Card = true,
				Action = { Text = TEXT.Equip, Kind = "Main" } },
		},
	}
	page.Items = page.Lists[source]
	return page
end

function PAGES.PartsShop()
	return selectIn(partsOptions("Buy"), "M:sp2")
end

function PAGES.PartsShopLocked()
	return selectIn(partsOptions("Buy"), "M:sp3")
end

function PAGES.PartsOwned()
	return selectIn(partsOptions("Owned"), "I:2")
end

function PAGES.PartsOwnedNone()
	local page = partsOptions("Buy")
	page.Source.OwnedLocked = true
	page.Message = TEXT.ModuleBought
	return selectIn(page, nil)
end

function PAGES.Upgrades()
	local page = workspace("Upgrades", "Upgrades", "Upgrades")
	page.Sub = TEXT.UpgradesSub
	page.Heading = "Front Engine"
	page.Picker = { Label = TEXT.ModulePicker, Options = slotOptions(), Selected = "Engine1" }
	page.Budget = { Label = TEXT.UpgradePoints, Used = 4, Capacity = 10 }
	page.Stats = stats("Stinger", "D", 321, { Speed = 3, Acceleration = 4 })
	page.Items = {
		{ Key = "u1", Kind = "Upgrade", Title = "Intake", ChipLeft = "LEVEL 1", PriceAmount = 8000, Sub = "+2 TOP SPEED", Status = "Fitted", Selectable = true, Card = true,
			Action = { Text = TEXT.Upgrade, Amount = 8000, Kind = "Buy" } },
		{ Key = "u2", Kind = "Upgrade", Title = "Injectors", ChipLeft = "LEVEL 2", PriceAmount = 12000, Sub = "+3 ENGINE OUTPUT", Status = "Fitted", Selectable = true, Card = true,
			Action = { Text = TEXT.Upgrade, Amount = 12000, Kind = "Buy" } },
		{ Key = "u3", Kind = "Upgrade", Title = "Exhaust", ChipLeft = "LEVEL 0", PriceAmount = 18000, Sub = "-0.25 DRAG", Status = "None", Selectable = true, Card = true,
			Action = { Text = TEXT.Upgrade, Amount = 18000, Kind = "Buy" } },
		{ Key = "u4", Kind = "Upgrade", Title = "Turbine", ChipLeft = "LEVEL 3", PriceText = TEXT.MaxLevel, Status = "Fitted", Selectable = true, Card = true },
	}
	return selectIn(page, "u2")
end

function PAGES.UpgradesLimit()
	local page = PAGES.Upgrades()
	page.Budget.Used = 10
	for _, item in ipairs(page.Items) do
		if item.PriceAmount then
			item.PriceAmount = nil
			item.PriceText = TEXT.LimitReached
			item.Sub = nil
			item.Action = nil
			item.Status = item.Status == "None" and "Locked" or item.Status
		end
	end
	return selectIn(page, "u3")
end

function PAGES.UpgradesUnlock()
	local page = workspace("Upgrades", "Upgrades", "Upgrades")
	page.Sub = TEXT.UpgradesSub
	page.Heading = "Spoiler"
	page.Picker = { Label = TEXT.ModulePicker, Options = slotOptions(), Selected = "RearSpoiler" }
	page.Stats = stats("Stinger", "D", 321)
	page.Items = { { Key = "__MODULE_UNLOCK", Kind = "Unlock", Title = TEXT.BuyToUnlock, Icon = "plus", Status = "None", Card = true } }
	return page
end

function PAGES.UpgradesNoData()
	local page = PAGES.UpgradesUnlock()
	page.Items = {}
	page.Budget = { Label = TEXT.UpgradePoints, Used = 0, Capacity = 0 }
	page.EmptyMessage = TEXT.UpgradeDataMissing
	return page
end

local function paintOptions()
	local options = { { Id = "ALL", Text = "All" }, { Id = "Cockpit", Text = "Cockpit" }, { Id = "THRUST_COLOR", Text = TEXT.Thrust }, { Id = "UNDERGLOW", Text = TEXT.Underglow } }
	for _, option in ipairs(slotOptions()) do
		table.insert(options, option)
	end
	return options
end

function PAGES.PaintColour()
	local page = workspace("Paint", "Paint", "Paint.Colour.Area")
	page.Sub = TEXT.PaintColourSub
	page.Mode = "Colour"
	page.PaintTarget = "ALL"
	page.Heading = "All"
	page.Picker = { Label = TEXT.AreaPicker, Options = paintOptions(), Selected = "ALL" }
	page.Paint = { Target = "ALL", Channels = { "Primary", "Secondary", "Detail", "Neon" }, Selected = "Primary", Colours = {} }
	return page
end

function PAGES.PaintCockpit()
	local page = PAGES.PaintColour()
	page.PaintTarget = "Cockpit"
	page.Picker.Selected = "Cockpit"
	page.Paint = { Target = "Cockpit", Channels = { "Primary", "Secondary", "Detail", "FrontLights", "RearLights" }, Selected = "FrontLights", Colours = {} }
	return page
end

function PAGES.PaintOverview()
	local page = workspace("Paint", "Paint", "Paint.Overview")
	page.Sub = TEXT.PaintOverviewSub
	page.Mode = "Overview"
	page.PaintTarget = "Engine1"
	page.Heading = "Front Engine"
	page.Picker = { Label = TEXT.AreaPicker, Options = paintOptions(), Selected = "Engine1" }
	page.Items = {
		{ Key = "Paint", Kind = "Action", Title = TEXT.Paint, Icon = "paint", Status = "None", Card = true },
		{ Key = "Neon", Kind = "Action", Title = TEXT.NeonLights, Icon = "paint", PriceAmount = 5000000, Status = "Unaffordable", Card = true,
			Action = { Text = TEXT.Buy, Amount = 5000000, Kind = "Buy" } },
	}
	return selectIn(page, "Neon")
end

function PAGES.PaintUnavailable()
	local page = PAGES.PaintOverview()
	page.Items[2] = { Key = "Neon", Kind = "Action", Title = TEXT.NeonLights, Sub = TEXT.NeonUnavailable, Icon = "paint", Status = "Locked", Selectable = false, Card = true }
	return selectIn(page, nil)
end

local MODALS = {
	Cash = function()
		return { Kind = "Cash" }
	end,
	Properties = function()
		return { Kind = "Properties", Rows = {
			{ Id = "P1", DisplayName = "Kanda Lift Bay", Owned = true, PriceAmount = 50000 },
			{ Id = "P2", DisplayName = "Shibuya Twin Bay", Owned = false, PriceAmount = 125000 },
			{ Id = "P3", DisplayName = "Harbour Stack Showroom and Collector Vault", Owned = false, PriceAmount = 12500000 },
		} }
	end,
	Move = function()
		return { Kind = "Move", VehicleName = LONG_NAME }
	end,
	BuyVehicle = function()
		return { Kind = "BuyVehicle", VehicleName = "Zephyr", PriceAmount = 150000 }
	end,
}

-- A stand-in for GarageModel: the same getters and intents over canned pages. A tile press moves the selection
-- (as the model would redraw it) and fires Changed; nothing else leaves this table.
local function fakeModel(props)
	local model = { State = {}, Changed = signal(), Calls = {} }
	local page = PAGES[props.Page or "Dealership"]()
	local modal = props.Modal and MODALS[props.Modal]() or nil
	local showing = (page.Id == "Dealership") and "Browser" or "Workspace"

	function model.Page()
		return page
	end
	function model.Showing()
		return showing
	end
	function model.Modal()
		return modal
	end
	function model.IsActive()
		return true
	end
	function model.SelectItem(key)
		table.insert(model.Calls, "SelectItem:" .. tostring(key))
		selectIn(page, key)
		model.Changed:Fire("render")
	end
	function model.SetPage(name)
		page = PAGES[name]()
		showing = (page.Id == "Dealership") and "Browser" or "Workspace"
		model.Changed:Fire("render")
	end
	function model.SetModal(name)
		modal = name and MODALS[name]() or nil
		model.Changed:Fire("modal")
	end
	function model.CloseModal()
		table.insert(model.Calls, "CloseModal")
		modal = nil
		model.Changed:Fire("modal")
	end
	function model.ResolveModal(confirmed)
		table.insert(model.Calls, "ResolveModal:" .. tostring(confirmed))
		modal = nil
		model.Changed:Fire("modal")
	end
	for _, name in ipairs({ "SelectCategory", "Exit", "Action", "SelectTab", "SelectSource", "SelectPicker", "Back", "Drive",
		"PaintChannel", "PaintColour", "ShowCash", "ShowProperties", "BuyProperty", "SetReplicatedCash" }) do
		model[name] = function(argument)
			table.insert(model.Calls, name .. ":" .. tostring(argument))
		end
	end
	return model
end

-- One mount for every state. `parent` is the gallery's full-stage frame; the view needs a Layer, so a Scene stage
-- of its own is composed inside it. Confirmations build inside the same frame (no ScreenGui in the gallery).
local function mount(parent, props, scope, ctx)
	local host = Instance.new("Frame")
	host.Name = "GarageStage"
	host.BackgroundTransparency = 1
	host.BorderSizePixel = 0
	host.Size = UDim2.fromScale(1, 1)
	host.Parent = parent

	local layer = Layers.Stage(host, ctx, "Scene")
	local model = fakeModel(props)
	-- No player is bound in the gallery: the Cash chip shows the page's example amount instead of an empty chip.
	local view = View.Mount(layer, model, scope, { ConfirmHost = host, Cash = model.Page().Cash })
	local connection = model.Changed:Connect(function(reason)
		view.Render(reason)
	end)
	view.Render("render")

	local component = { Instance = host, Layer = layer, Model = model, View = view }
	local destroyed = false
	function component.Set(_patch) end
	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		connection.Disconnect()
		view.Destroy()
		layer.Destroy()
		host:Destroy()
	end
	scope:add(component)
	return component
end

local function states(list)
	local result = {}
	for _, entry in ipairs(list) do
		table.insert(result, { Id = entry[1], Props = { Page = entry[2], Modal = entry[3] } })
	end
	return result
end

local items = {
	{
		Id = "Garage.Dealership", Frame = "Scene", Slot = nil, Mount = mount,
		States = states({
			{ "Default", "Dealership" }, { "Unaffordable", "DealershipUnaffordable" }, { "Loading", "DealershipLoading" },
			{ "Empty", "DealershipEmpty" }, { "ErrorLine", "DealershipError" }, { "PickOwned", "CustomisationPick" },
		}),
	},
	{
		Id = "Garage.PostPurchasePaint", Frame = "Scene", Slot = nil, Mount = mount,
		States = states({ { "Default", "PostPaint" } }),
	},
	{
		Id = "Garage.Parts", Frame = "Scene", Slot = nil, Mount = mount,
		States = states({
			{ "Slots", "PartsSlots" }, { "Shop", "PartsShop" }, { "ShopLocked", "PartsShopLocked" }, { "Owned", "PartsOwned" },
			{ "OwnedLockedAndMessage", "PartsOwnedNone" },
		}),
	},
	{
		Id = "Garage.Upgrades", Frame = "Scene", Slot = nil, Mount = mount,
		States = states({ { "Default", "Upgrades" }, { "LimitReached", "UpgradesLimit" }, { "EmptySlot", "UpgradesUnlock" }, { "NoData", "UpgradesNoData" } }),
	},
	{
		Id = "Garage.Paint", Frame = "Scene", Slot = nil, Mount = mount,
		States = states({ { "Colour", "PaintColour" }, { "FiveChannels", "PaintCockpit" }, { "Overview", "PaintOverview" }, { "NeonUnavailable", "PaintUnavailable" } }),
	},
	{
		Id = "Garage.Modal.Cash", Frame = "Scene", Slot = nil, Mount = mount,
		States = states({ { "Default", "PartsSlots", "Cash" } }),
	},
	{
		Id = "Garage.Modal.Properties", Frame = "Scene", Slot = nil, Mount = mount,
		States = states({ { "Default", "Dealership", "Properties" } }),
	},
	{
		Id = "Garage.Modal.MoveModule", Frame = "Scene", Slot = nil, Mount = mount,
		States = states({ { "Default", "PartsOwned", "Move" } }),
	},
	{
		Id = "Garage.Modal.BuyVehicle", Frame = "Scene", Slot = nil, Mount = mount,
		States = states({ { "Default", "Dealership", "BuyVehicle" } }),
	},
}

-- Test seams (the gallery reads the list part only).
items._pages = PAGES
items._modals = MODALS
items._fakeModel = fakeModel

return items
