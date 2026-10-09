-- Owns the gallery items of the owned-garage half of the Garage family (browser and desk); not the real model, any remote, bindable or player attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.GarageOwned. Requires: Kit.Layers, Garage.OwnedGarageBrowserUI, Garage.OwnedGarageDeskView.
-- Half B of the family (API2 5.7). Half A owns Dev.Fixtures.Garage; this module is separate so the two cannot collide (NOTES_b).
local pulse = script.Parent.Parent.Parent
local kit = pulse.Kit
local garage = pulse.Garage

local LONG_NAME = "THE EXTRAORDINARILY LONG GARAGE NAME OF KANDA WATERFRONT"

local function noop() end

-- A fake of Garage.OwnedGarageBrowserModel: the same getters over a canned snapshot; every action does nothing.
local function fakeBrowserModel(snapshot)
	local model = {}
	function model:Snapshot()
		return snapshot
	end
	function model:IsOpen()
		return true
	end
	model.SetMode = noop
	model.SelectKey = noop
	model.Enter = noop
	model.Close = noop
	model.ChooseReplacement = noop
	model.CancelReplacement = noop
	return model
end

local function browserSnapshot(patch)
	local snapshot = {
		Open = true,
		Mode = "Mine",
		TabsVisible = true,
		Rows = {
			{ Key = "Garage_kanda", Title = "Kanda Two-Bay", Sub = "1 / 2 SPACES FILLED", Image = "", Selected = true, Muted = false },
			{ Key = "Garage_shibuya", Title = "Shibuya Loft", Sub = "0 / 4 SPACES FILLED", Image = "", Selected = false, Muted = false },
		},
		SelectedKey = "Garage_kanda",
		Detail = {
			Title = "KANDA TWO-BAY",
			District = "KANDA",
			Description = "A two-bay starter garage. Display your vehicles, build it out and style it from the garage desk.",
			Capacity = "1 / 2 DISPLAY SPACES",
			Spaces = "1 / 2",
			Image = "",
			Facts = {
				{ Id = "District", Label = "DISTRICT", Value = "KANDA" },
				{ Id = "Capacity", Label = "CAPACITY", Value = "2 SPACES" },
				{ Id = "Filled", Label = "FILLED", Value = "1 / 2" },
			},
		},
		Enter = { Visible = true, Enabled = true, Text = "ENTER GARAGE" },
		Status = { Text = "", Good = false, Visible = false },
		Replacement = nil,
	}
	for key, value in pairs(patch or {}) do
		snapshot[key] = value
	end
	-- The selected key always names a row that is present (a nil in a patch cannot clear a field).
	snapshot.SelectedKey = nil
	for _, row in ipairs(snapshot.Rows) do
		if row.Selected then
			snapshot.SelectedKey = row.Key
		end
	end
	return snapshot
end

local function emptyDetail(title, description)
	return { Title = title, District = "", Description = description, Capacity = "", Spaces = "", Image = "", Facts = {} }
end

local function mountBrowser(parent, props, scope, ctx)
	local Layers = require(kit.Layers)
	local Browser = require(garage.OwnedGarageBrowserUI)
	local layer = Layers.Stage(parent, ctx, "Menu")
	local view = Browser._mount(layer, fakeBrowserModel(props.Snapshot), scope, kit, nil)
	view.Render("fixture")
	return {
		Instance = layer.Root,
		Set = function() end,
		Destroy = function()
			view.Destroy()
			layer.Destroy()
		end,
	}
end

local function deskContext(patch)
	local context = {
		TutorialPageId = "GarageHome",
		Title = "GARAGE MANAGEMENT",
		Subtitle = "Choose how to manage your garage.",
		ShowLeft = false,
		LeftItems = {},
		Cards = {
			{ Id = "DisplayCars", DisplayName = "Display Cars", Footer = "MANAGE DISPLAY SPACES", OnSelect = noop },
			{ Id = "BuildGarage", DisplayName = "Build Garage", Footer = "BUY / EQUIP ASSETS", OnSelect = noop },
			{ Id = "StyleGarage", DisplayName = "Style Garage", Footer = "COLOUR / MATERIAL", OnSelect = noop },
		},
		Cash = 3613696,
		CapacityText = "1/2 DISPLAY SPACES",
		NextVisible = false,
		ExitVisible = true,
		ExitText = "EXIT",
		OnExit = noop,
	}
	for key, value in pairs(patch or {}) do
		context[key] = value
	end
	return context
end

local MODE_TABS = {
	{ Id = "DisplayCars", Text = "Display Cars", Selected = true, OnSelect = noop },
	{ Id = "BuildGarage", Text = "Build Garage", Selected = false, OnSelect = noop },
	{ Id = "StyleGarage", Text = "Style Garage", Selected = false, OnSelect = noop },
}

local function mountDesk(parent, props, _scope, _ctx)
	local DeskView = require(garage.OwnedGarageDeskView)
	local view = DeskView.new({ Fixture = true })
	view.Root.Parent = parent
	view:Show(props.Context)
	if props.Message then
		view:Message(props.Message)
	end
	return {
		Instance = view.Root,
		Set = function() end,
		Destroy = function()
			view:Destroy()
		end,
	}
end

return {
	{
		Id = "OwnedGarage.Browser",
		Frame = "Menu",
		Slot = nil,
		States = {
			{ Id = "Mine", Props = { Snapshot = browserSnapshot() } },
			{ Id = "Loading", Props = { Snapshot = browserSnapshot({
				TabsVisible = false,
				Rows = {},
				Detail = emptyDetail("", ""),
				Status = { Text = "LOADING GARAGES...", Good = true, Visible = true },
			}) } },
			{ Id = "Empty", Props = { Snapshot = browserSnapshot({
				TabsVisible = false,
				Rows = {},
				Detail = emptyDetail("NO GARAGES", "No owned garage properties are available."),
				Enter = { Visible = false, Enabled = true, Text = "ENTER GARAGE" },
			}) } },
			{ Id = "Inside", Props = { Snapshot = browserSnapshot({ Enter = { Visible = true, Enabled = true, Text = "RETURN TO CITY" } }) } },
			{ Id = "Error", Props = { Snapshot = browserSnapshot({ Status = { Text = "Garage service unavailable.", Good = false, Visible = true } }) } },
			{ Id = "LongStrings", Props = { Snapshot = browserSnapshot({
				Rows = {
					{ Key = "Garage_long", Title = LONG_NAME, Sub = "12 / 24 SPACES FILLED", Image = "", Selected = true, Muted = false },
				},
				Detail = {
					Title = LONG_NAME,
					District = "KANDA WATERFRONT INDUSTRIAL DISTRICT",
					Description = "A very long description that has to wrap over several lines inside the about panel without pushing the facts panel or the footer buttons out of place on any preset, including the smallest phone.",
					Capacity = "12 / 24 DISPLAY SPACES",
					Spaces = "12 / 24",
					Image = "",
					Facts = {
						{ Id = "District", Label = "DISTRICT", Value = "KANDA WATERFRONT INDUSTRIAL DISTRICT" },
						{ Id = "Capacity", Label = "CAPACITY", Value = "24 SPACES" },
						{ Id = "Filled", Label = "FILLED", Value = "12 / 24" },
					},
				},
			}) } },
			{ Id = "Visit", Props = { Snapshot = browserSnapshot({
				Mode = "Visit",
				Rows = {
					{ Key = "Visit_11", Title = "AYA", Sub = "1/6", Image = "", Selected = true, Muted = false },
					{ Key = "Visit_12", Title = "BEN", Sub = "6/6", Image = "", Selected = false, Muted = true },
				},
				Detail = {
					Title = "AYA'S LOFT",
					District = "HOSTED BY AYA",
					Description = "Open to everyone in this server.",
					Capacity = "1 / 6 VISITORS",
					Spaces = "",
					Image = "",
					Facts = { { Id = "Host", Label = "HOST", Value = "AYA" }, { Id = "Visitors", Label = "VISITORS", Value = "1 / 6" } },
				},
				Enter = { Visible = true, Enabled = true, Text = "VISIT" },
			}) } },
			{ Id = "VisitLocked", Props = { Snapshot = browserSnapshot({
				Mode = "Visit",
				Rows = { { Key = "Visit_12", Title = "BEN", Sub = "6/6", Image = "", Selected = true, Muted = true } },
				Detail = {
					Title = "BEN'S BAY",
					District = "HOSTED BY BEN",
					Description = "Open to the owner's friends. FULL",
					Capacity = "6 / 6 VISITORS",
					Spaces = "",
					Image = "",
					Facts = { { Id = "Host", Label = "HOST", Value = "BEN" }, { Id = "Visitors", Label = "VISITORS", Value = "6 / 6" } },
				},
				Enter = { Visible = true, Enabled = false, Text = "EXIT YOUR CAR TO VISIT" },
			}) } },
			{ Id = "VisitNone", Props = { Snapshot = browserSnapshot({
				Mode = "Visit",
				Rows = {},
				Detail = emptyDetail("NO OPEN GARAGES", "Garages appear here while their owner is inside and has opened them to you."),
				Enter = { Visible = false, Enabled = true, Text = "LEAVE GARAGE" },
			}) } },
			{ Id = "GarageFull", Props = { Snapshot = browserSnapshot({
				Status = { Text = "", Good = false, Visible = false },
				Replacement = { Slots = { { SlotId = "Bay1", DisplayName = "Kestrel GT" }, { SlotId = "Bay2", DisplayName = "Vanta Exotic Long Name Edition" } } },
			}) } },
		},
		Mount = mountBrowser,
	},
	{
		Id = "OwnedGarage.Desk",
		Frame = "Scene",
		Slot = nil,
		States = {
			{ Id = "Home", Props = { Context = deskContext() } },
			{ Id = "Loading", Props = { Context = deskContext({ TutorialPageId = "", Subtitle = "Loading garage management...", Cards = {} }), Message = "LOADING GARAGE..." } },
			{ Id = "DisplaySpaces", Props = { Context = deskContext({
				TutorialPageId = "DisplayCars",
				Subtitle = "Choose a display space to manage.",
				ShowLeft = true,
				LeftItems = MODE_TABS,
				Cards = {
					{ Id = "Bay1", CardKind = "Vehicle", DisplayName = "Kestrel GT", Badge = "A 412", Selected = true, Footer = "DISPLAYED", OnSelect = noop },
					{ Id = "Bay2", CardKind = "Vehicle", DisplayName = "EMPTY DISPLAY SPACE", Footer = "ADD VEHICLE", EmptyPlus = true, OnSelect = noop },
				},
				BackVisible = true,
				BackText = "BACK",
				OnBack = noop,
				SelectedAction = { RowId = "Bay1", Text = "CHANGE VEHICLE", OnActivate = noop },
			}) } },
			{ Id = "DisplayVehiclesEmpty", Props = { Context = deskContext({
				TutorialPageId = "",
				Subtitle = "Choose a vehicle for this display space.",
				ShowLeft = true,
				LeftItems = MODE_TABS,
				Cards = {},
				EmptyMessage = "NO OWNED VEHICLES AVAILABLE",
				BackVisible = true,
				OnBack = noop,
			}) } },
			{ Id = "BuildStructure", Props = { Context = deskContext({
				TutorialPageId = "BuildStructure",
				Subtitle = "Choose a structure option for Front Wall.",
				ShowLeft = true,
				LeftItems = {
					{ Id = "FrontWall", Text = "Front Wall", Selected = true, OnSelect = noop },
					{ Id = "BackWall", Text = "Back Wall", OnSelect = noop },
					{ Id = "Floor", Text = "Floor", OnSelect = noop },
					{ Id = "Ceiling", Text = "Ceiling With A Long Location Name", OnSelect = noop },
				},
				Cards = {
					{ Id = "wall-a", CardKind = "Listing", VehicleName = "Front Wall", DisplayName = "Plain Concrete", Footer = "CURRENT", SemanticState = "Equipped", OnSelect = noop },
					{ Id = "wall-b", CardKind = "Listing", VehicleName = "Front Wall", DisplayName = "Neon Panels", Footer = "OWNED", SemanticState = "Available", OnSelect = noop },
					{ Id = "wall-c", CardKind = "Listing", VehicleName = "Front Wall", DisplayName = "Carbon Weave", Price = 48000, Footer = "", SemanticState = "Available", Selected = true, OnSelect = noop },
					{ Id = "wall-d", CardKind = "Listing", VehicleName = "Front Wall", DisplayName = "Gold Leaf", Price = 9500000, PriceColor = true, Footer = "", SemanticState = "Available", OnSelect = noop },
					{ Id = "wall-e", CardKind = "Listing", VehicleName = "GARAGE STYLE", DisplayName = "Colour", Footer = "NO COLOUR CHANNELS", SemanticState = "Locked", OnSelect = noop },
				},
				BackVisible = true,
				OnBack = noop,
				SelectedAction = { RowId = "wall-c", Text = "BUY", OnActivate = noop },
			}), Message = "Not enough Cash." } },
			{ Id = "Materials", Props = { Context = deskContext({
				TutorialPageId = "",
				Subtitle = "Choose a material for Primary.",
				ShowLeft = true,
				LeftItems = MODE_TABS,
				Cards = {
					{ Id = "Metal", DisplayName = "Metal", Footer = "SELECTED", Selected = true, OnSelect = noop },
					{ Id = "Concrete", DisplayName = "Concrete", Footer = "", OnSelect = noop },
				},
				MaterialChannels = { "Primary", "Secondary" },
				SelectedChannel = "Primary",
				OnChannel = noop,
				NextVisible = true,
				NextText = "SAVE",
				OnNext = noop,
				BackVisible = true,
				OnBack = noop,
			}) } },
			{ Id = "Colour", Props = { Context = deskContext({
				TutorialPageId = "",
				Subtitle = "Adjust structure colours.",
				ShowLeft = true,
				LeftItems = MODE_TABS,
				Cards = {},
				ColorChannels = { "Primary", "Secondary", "Accent" },
				SelectedChannel = "Secondary",
				Colors = {},
				OnChannel = noop,
				OnColor = noop,
				NextVisible = true,
				NextText = "SAVE",
				OnNext = noop,
				BackVisible = true,
				OnBack = noop,
			}) } },
		},
		Mount = mountDesk,
	},
}
