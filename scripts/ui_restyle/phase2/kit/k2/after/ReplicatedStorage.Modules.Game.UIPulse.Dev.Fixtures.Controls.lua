-- Owns the gallery fixtures for Kit.Controls (Button, ButtonRow, Tabs, Header, IconButton, Switch, Stepper, Dropdown, Slider, Swatch); it does not own the gallery, any screen or any game data.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Controls. Requires: Surface, Controls.
local Kit = script.Parent.Parent.Parent.Kit
local Surface = require(Kit.Surface)
local Controls = require(Kit.Controls)

local function nothing() end

-- The gallery stage is near black, where a Slate plate cannot be told from the background. On the stage centre
-- frame (not on a zero-size slot) a menu scrim goes behind the control, as a screen would have behind it.
local function backdrop(parent, scope)
	local size = parent.Size
	if size.X.Offset > 0 and size.Y.Offset > 0 then
		local scrim = Surface.Scrim(parent, { Name = "FixtureBackdrop", Kind = "Menu" }, scope)
		scrim.Instance.ZIndex = 0
	end
end

local function mounter(constructor)
	return function(parent, props, scope, _ctx)
		backdrop(parent, scope)
		return constructor(parent, props, scope)
	end
end

-- Example paint ramp and swatch colours for the two named colour exceptions (Slider.Gradient, Swatch.Colour).
local HUE_RAMP = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
	ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
	ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
	ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
	ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
	ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
})
local PAINT_ORANGE = Color3.fromHSV(0.08, 0.9, 1)
local PAINT_TEAL = Color3.fromHSV(0.5, 0.8, 0.8)
local PAINT_WHITE = Color3.fromHSV(0, 0, 0.95)
local PAINT_BLACK = Color3.fromHSV(0, 0, 0.06)

local CUSTOMISE_TABS = {
	Selected = "Parts",
	Bumpers = true,
	OnSelected = nothing,
	Tabs = {
		{ Id = "Parts", Text = "Parts", Icon = "customise" },
		{ Id = "Upgrades", Text = "Upgrades", Icon = "upgrade" },
		{ Id = "Paint", Text = "Paint", Icon = "paint" },
	},
}
local DEALERSHIP_TABS = {
	Selected = "Exotic",
	Bumpers = true,
	OnSelected = nothing,
	Tabs = {
		{ Id = "All", Text = "All" },
		{ Id = "Exotic", Text = "Exotic" },
		{ Id = "Piercer", Text = "Piercer" },
		{ Id = "Muscle", Text = "Muscle", Locked = true },
	},
}

local buttonItem = {
	Id = "Controls.Button",
	Frame = "Bare",
	Slot = nil,
	Mount = mounter(Controls.Button),
	States = {
		{ Id = "Default", Props = { Variant = "Default", Text = "Back", Icon = "back", OnActivated = nothing } },
		{ Id = "DefaultNoIcon", Props = { Variant = "Default", Text = "No", OnActivated = nothing } },
		{ Id = "Main", Props = { Variant = "Main", Text = "Drive", Icon = "steering_wheel", OnActivated = nothing } },
		{ Id = "MainLongest", Props = { Variant = "Main", Text = "Start time trial", Icon = "race_flag", OnActivated = nothing } },
		{ Id = "Buy", Props = { Variant = "Buy", Text = "Buy $150,000", OnActivated = nothing } },
		{ Id = "Danger", Props = { Variant = "Danger", Text = "Despawn", Icon = "close", OnActivated = nothing } },
		{ Id = "Icon", Props = { Variant = "Icon", Icon = "garage", OnActivated = nothing } },
		{ Id = "Selected", Props = { Variant = "Default", Text = "Controls", Icon = "gamepad", Selected = true, OnActivated = nothing } },
		{ Id = "Disabled", Props = { Variant = "Default", Text = "Drive", Icon = "steering_wheel", Disabled = true, OnActivated = nothing } },
		{ Id = "Locked", Props = { Variant = "Default", Text = "Set route", Icon = "set_route", Locked = true, OnActivated = nothing } },
		{ Id = "MainDisabled", Props = { Variant = "Main", Text = "Equip", Icon = "tick", Disabled = true, OnActivated = nothing } },
		{ Id = "BuyUnaffordable", Props = { Variant = "Buy", Text = "Buy $4.40M", Disabled = true, OnActivated = nothing } },
		{ Id = "DangerDisabled", Props = { Variant = "Danger", Text = "Despawn", Icon = "close", Disabled = true, OnActivated = nothing } },
		{ Id = "IconDisabled", Props = { Variant = "Icon", Icon = "settings_cog", Disabled = true, OnActivated = nothing } },
		{ Id = "Hud", Props = { Variant = "Default", Size = "Hud", Text = "Exit vehicle", Icon = "exit", OnActivated = nothing } },
		{ Id = "HudMain", Props = { Variant = "Main", Size = "Hud", Text = "Set route", Icon = "set_route", OnActivated = nothing } },
		{ Id = "HudIconOnly", Props = { Variant = "Default", Size = "Hud", Icon = "map", IconOnly = true, OnActivated = nothing } },
		{ Id = "HudIconOnlySelected", Props = { Variant = "Default", Size = "Hud", Icon = "map", IconOnly = true, Selected = true, OnActivated = nothing } },
		{ Id = "Large", Props = { Variant = "Default", Size = "Large", Text = "Exit vehicle", Icon = "exit", OnActivated = nothing } },
		{ Id = "LargeMain", Props = { Variant = "Main", Size = "Large", Text = "Continue", OnActivated = nothing } },
		{ Id = "MinWidth", Props = { Variant = "Default", Text = "Yes", MinWidth = 250, OnActivated = nothing } },
	},
}

local ROW_STATES = {
	{
		Id = "ModuleShop",
		Props = {
			Buttons = {
				{ Id = "Back", Variant = "Default", Text = "Back", Icon = "back", OnActivated = nothing },
				{ Id = "Drive", Variant = "Default", Text = "Drive", Icon = "steering_wheel", OnActivated = nothing },
				{ Id = "Equip", Variant = "Main", Text = "Equip", Icon = "tick", OnActivated = nothing },
			},
		},
	},
	{
		Id = "Dealership",
		Props = {
			Buttons = {
				{ Id = "Exit", Variant = "Default", Text = "Exit", Icon = "exit", OnActivated = nothing },
				{ Id = "Buy", Variant = "Buy", Text = "Buy $150,000", OnActivated = nothing },
			},
		},
	},
	{
		Id = "DealershipUnaffordable",
		Props = {
			Buttons = {
				{ Id = "Exit", Variant = "Default", Text = "Exit", Icon = "exit", OnActivated = nothing },
				{ Id = "Buy", Variant = "Buy", Text = "Buy $4.40M", Disabled = true, OnActivated = nothing },
			},
		},
	},
	{
		Id = "RaceEntryLongest",
		Props = {
			Buttons = {
				{ Id = "Exit", Variant = "Default", Text = "Exit", Icon = "exit", OnActivated = nothing },
				{ Id = "Records", Variant = "Default", Text = "View records", Icon = "trophy", OnActivated = nothing },
				{ Id = "Start", Variant = "Main", Text = "Start time trial", Icon = "race_flag", OnActivated = nothing },
			},
		},
	},
	{
		Id = "DriveLocked",
		Props = {
			Buttons = {
				{ Id = "Back", Variant = "Default", Text = "Back", Icon = "back", OnActivated = nothing },
				{ Id = "Drive", Variant = "Main", Text = "Drive", Icon = "steering_wheel", Disabled = true, OnActivated = nothing },
			},
		},
	},
	{
		Id = "Destructive",
		Props = {
			Buttons = {
				{ Id = "Back", Variant = "Default", Text = "Back", Icon = "back", OnActivated = nothing },
				{ Id = "Despawn", Variant = "Danger", Text = "Despawn", Icon = "close", OnActivated = nothing },
			},
		},
	},
}

-- The same rows in the three places a menu row goes: each takes the anchor of its slot (Place = "Slot").
local rowItem = {
	Id = "Controls.ButtonRow",
	Frame = "Scene",
	Slot = "BottomRight",
	Mount = mounter(Controls.ButtonRow),
	States = ROW_STATES,
}

local rowRailItem = {
	Id = "Controls.ButtonRowOnRail",
	Frame = "Menu",
	Slot = "RailButtons",
	Mount = mounter(Controls.ButtonRow),
	States = ROW_STATES,
}

local rowCentreItem = {
	Id = "Controls.ButtonRowCentre",
	Frame = "Menu",
	Slot = "BottomCentre",
	Mount = mounter(Controls.ButtonRow),
	States = {
		{
			Id = "Results",
			Props = {
				Align = "Centre",
				Buttons = {
					{ Id = "Again", Variant = "Default", Text = "Race again", Icon = "loop", OnActivated = nothing },
					{ Id = "Continue", Variant = "Main", Text = "Continue", OnActivated = nothing },
				},
			},
		},
		{
			Id = "ResultsLongest",
			Props = {
				Align = "Centre",
				Buttons = {
					{ Id = "Exit", Variant = "Default", Text = "Exit", Icon = "exit", OnActivated = nothing },
					{ Id = "Records", Variant = "Default", Text = "View records", Icon = "trophy", OnActivated = nothing },
					{ Id = "Again", Variant = "Default", Text = "Race again", Icon = "loop", OnActivated = nothing },
					{ Id = "Continue", Variant = "Main", Text = "Continue", OnActivated = nothing },
				},
			},
		},
	},
}

local rowHudItem = {
	Id = "Controls.ButtonRowHud",
	Frame = "Hud",
	Slot = "HudButtons",
	Mount = mounter(Controls.ButtonRow),
	States = {
		{
			Id = "Driving",
			Props = {
				Align = "Centre",
				Size = "Hud",
				Buttons = {
					{ Id = "Controls", Variant = "Default", Text = "Controls", Icon = "gamepad", OnActivated = nothing },
					{ Id = "ExitVehicle", Variant = "Default", Text = "Exit vehicle", Icon = "exit", OnActivated = nothing },
				},
			},
		},
		{
			Id = "DrivingIcons",
			Props = {
				Align = "Centre",
				Size = "Hud",
				Buttons = {
					{ Id = "Controls", Variant = "Default", Icon = "gamepad", IconOnly = true, OnActivated = nothing },
					{ Id = "ExitVehicle", Variant = "Default", Icon = "exit", IconOnly = true, OnActivated = nothing },
				},
			},
		},
		{
			Id = "ControlsOpen",
			Props = {
				Align = "Centre",
				Size = "Hud",
				Buttons = {
					{ Id = "Controls", Variant = "Default", Text = "Controls", Icon = "gamepad", Selected = true, OnActivated = nothing },
					{ Id = "ExitVehicle", Variant = "Default", Text = "Exit vehicle", Icon = "exit", Disabled = true, OnActivated = nothing },
				},
			},
		},
	},
}

local tabsItem = {
	Id = "Controls.Tabs",
	Frame = "Scene",
	Slot = "TopLeft",
	Mount = mounter(Controls.Tabs),
	States = {
		{ Id = "Customise", Props = CUSTOMISE_TABS },
		{
			Id = "PaintLocked",
			Props = {
				Selected = "Upgrades",
				Bumpers = true,
				OnSelected = nothing,
				Tabs = {
					{ Id = "Parts", Text = "Parts", Icon = "customise" },
					{ Id = "Upgrades", Text = "Upgrades", Icon = "upgrade" },
					{ Id = "Paint", Text = "Paint", Icon = "paint", Locked = true },
				},
			},
		},
		{ Id = "DealershipCategories", Props = DEALERSHIP_TABS },
		{
			Id = "RaceFilters",
			Props = {
				Selected = "All",
				OnSelected = nothing,
				Tabs = {
					{ Id = "All", Text = "All events", Icon = "race_flag", Count = "12" },
					{ Id = "Circuit", Text = "Circuits", Icon = "laps", Count = "5" },
					{ Id = "TimeTrial", Text = "Time trials", Icon = "timer", Count = "4" },
					{ Id = "Duel", Text = "Duels", Icon = "duel", Count = "3" },
				},
			},
		},
		{
			Id = "SegmentShopOwned",
			Props = {
				Style = "Segment",
				Triggers = true,
				Selected = "Owned",
				OnSelected = nothing,
				Tabs = {
					{ Id = "Shop", Text = "Shop" },
					{ Id = "Owned", Text = "Owned" },
				},
			},
		},
		{
			Id = "SegmentNoneSelected",
			Props = {
				Style = "Segment",
				OnSelected = nothing,
				Tabs = {
					{ Id = "Shop", Text = "Shop" },
					{ Id = "Owned", Text = "Owned", Count = "x2" },
				},
			},
		},
		{
			Id = "TierButtons",
			Props = {
				Selected = "C",
				OnSelected = nothing,
				Tabs = {
					{ Id = "E", Text = "E", Tier = "E" },
					{ Id = "D", Text = "D", Tier = "D" },
					{ Id = "C", Text = "C", Tier = "C" },
					{ Id = "B", Text = "B", Tier = "B" },
					{ Id = "A", Text = "A", Tier = "A", Locked = true },
					{ Id = "S", Text = "S", Tier = "S", Locked = true },
				},
			},
		},
		{
			Id = "TierButtonsNoneSelected",
			Props = {
				OnSelected = nothing,
				Tabs = {
					{ Id = "E", Text = "E", Tier = "E" },
					{ Id = "D", Text = "D", Tier = "D" },
					{ Id = "C", Text = "C", Tier = "C" },
					{ Id = "B", Text = "B", Tier = "B" },
					{ Id = "A", Text = "A", Tier = "A" },
					{ Id = "S", Text = "S", Tier = "S" },
				},
			},
		},
	},
}

local headerItem = {
	Id = "Controls.Header",
	Frame = "Menu",
	Slot = "TopLeft",
	Mount = mounter(Controls.Header),
	States = {
		{ Id = "Customise", Props = { Title = "Customise", Shadow = true, Tabs = CUSTOMISE_TABS } },
		{ Id = "Dealership", Props = { Title = "Dealership", Shadow = true, Tabs = DEALERSHIP_TABS, MarkKey = "Text.Dealership" } },
		{ Id = "RaceEntry", Props = { Title = "Showroom loop", Sub = "Choose time trial vehicle", Shadow = true } },
		{ Id = "MyVehicles", Props = { Title = "My vehicles", Count = "6" } },
		{ Id = "TitleOnly", Props = { Title = "Races" } },
		{ Id = "LongestTitle", Props = { Title = "Shifted canal sprint reverse", Sub = "Time trial \u{00B7} 3 laps \u{00B7} 17 checkpoints", Count = "12", Shadow = true, Tabs = CUSTOMISE_TABS } },
		{ Id = "Empty", Props = { Title = "" } },
	},
}

local iconButtonItem = {
	Id = "Controls.IconButton",
	Frame = "Bare",
	Slot = nil,
	Mount = mounter(Controls.IconButton),
	States = {
		{ Id = "Default", Props = { Icon = "car", OnActivated = nothing } },
		{ Id = "Open", Props = { Icon = "garage", Selected = true, OnActivated = nothing } },
		{ Id = "RaceFlag", Props = { Icon = "race_flag", OnActivated = nothing } },
		{ Id = "Disabled", Props = { Icon = "customise", Disabled = true, OnActivated = nothing } },
		{ Id = "Settings", Props = { Icon = "settings_cog", OnActivated = nothing } },
		{ Id = "SmallPlus", Props = { Icon = "plus", Size = "Small", OnActivated = nothing } },
		{ Id = "SmallClose", Props = { Icon = "close", Size = "Small", Selected = true, OnActivated = nothing } },
		{ Id = "SmallDisabled", Props = { Icon = "plus", Size = "Small", Disabled = true, OnActivated = nothing } },
	},
}

local switchItem = {
	Id = "Controls.Switch",
	Frame = "Bare",
	Slot = nil,
	Mount = mounter(Controls.Switch),
	States = {
		{ Id = "MapRotate", Props = { On = true, LabelOn = "Rotate", LabelOff = "North up", OnChanged = nothing } },
		{ Id = "MapNorthUp", Props = { On = false, LabelOn = "Rotate", LabelOff = "North up", OnChanged = nothing } },
		{ Id = "OnOff", Props = { On = true, OnChanged = nothing } },
		{ Id = "Units", Props = { On = false, LabelOn = "MPH", LabelOff = "KM/H", OnChanged = nothing } },
		{ Id = "Disabled", Props = { On = true, LabelOn = "Rotate", LabelOff = "North up", Disabled = true, OnChanged = nothing } },
		{ Id = "LongestLabels", Props = { On = false, LabelOn = "Automatic camera", LabelOff = "Manual camera", OnChanged = nothing } },
	},
}

local function lapText(value)
	return value == 1 and "1 lap" or (value .. " laps")
end

local stepperItem = {
	Id = "Controls.Stepper",
	Frame = "Bare",
	Slot = nil,
	Mount = mounter(Controls.Stepper),
	States = {
		{ Id = "Laps", Props = { Value = 3, Min = 1, Max = 10, Format = lapText, OnChanged = nothing } },
		{ Id = "AtMin", Props = { Value = 1, Min = 1, Max = 10, Format = lapText, OnChanged = nothing } },
		{ Id = "AtMax", Props = { Value = 10, Min = 1, Max = 10, Format = lapText, OnChanged = nothing } },
		{ Id = "Plain", Props = { Value = 50, Min = 0, Max = 100, Step = 5, OnChanged = nothing } },
		{ Id = "OneValue", Props = { Value = 2, Min = 2, Max = 2, Format = lapText, OnChanged = nothing } },
	},
}

local SORTS = {
	{ Id = "Rating", Text = "Rating" },
	{ Id = "Name", Text = "Name" },
	{ Id = "Tier", Text = "Tier" },
	{ Id = "Recent", Text = "Recently driven" },
}
local CATEGORIES = {
	{ Id = "All", Text = "All" },
	{ Id = "Exotic", Text = "Exotic" },
	{ Id = "Piercer", Text = "Piercer" },
	{ Id = "Muscle", Text = "Muscle" },
	{ Id = "Starter", Text = "Starter" },
	{ Id = "Hypercar", Text = "Hypercar" },
	{ Id = "Courier", Text = "Courier" },
	{ Id = "Taxi", Text = "Taxi" },
}

-- An "Open" state key opens the list after the mount, so a capture shows it.
local function mountDropdown(parent, props, scope, _ctx)
	backdrop(parent, scope)
	local open = props.Open == true
	props.Open = nil
	local dropdown = Controls.Dropdown(parent, props, scope)
	if open then
		-- Deferred: the gallery places the root after Mount returns, and the list is placed from it.
		task.defer(dropdown.Open)
	end
	return dropdown
end

local dropdownItem = {
	Id = "Controls.Dropdown",
	Frame = "Bare",
	Slot = nil,
	Mount = mountDropdown,
	States = {
		{ Id = "Sort", Props = { Label = "Sort", Options = SORTS, Selected = "Rating", OnSelected = nothing } },
		{ Id = "SortOpen", Props = { Label = "Sort", Options = SORTS, Selected = "Rating", OnSelected = nothing, Open = true } },
		{ Id = "Category", Props = { Label = "Category", Options = CATEGORIES, Selected = "All", OnSelected = nothing } },
		{ Id = "CategoryOpenScrolls", Props = { Label = "Category", Options = CATEGORIES, Selected = "Piercer", MaxRows = 4, OnSelected = nothing, Open = true } },
		{ Id = "LongestValue", Props = { Label = "Sort", Options = SORTS, Selected = "Recent", OnSelected = nothing } },
		{ Id = "NoLabel", Props = { Options = SORTS, Selected = "Name", OnSelected = nothing } },
		{ Id = "NothingSelected", Props = { Label = "Category", Options = CATEGORIES, OnSelected = nothing } },
		{ Id = "NoOptions", Props = { Label = "Sort", Options = {}, OnSelected = nothing } },
	},
}

local sliderItem = {
	Id = "Controls.Slider",
	Frame = "Bare",
	Slot = nil,
	Mount = mounter(Controls.Slider),
	States = {
		{ Id = "PaintHue", Props = { Value = 0.58, Label = "Hue", ValueText = "209", Gradient = HUE_RAMP, OnChanged = nothing, OnReleased = nothing } },
		{ Id = "Volume", Props = { Value = 0.8, Label = "Music volume", ValueText = "80%", OnChanged = nothing, OnReleased = nothing } },
		{ Id = "Empty", Props = { Value = 0, Label = "Effects volume", ValueText = "0%", OnChanged = nothing } },
		{ Id = "Full", Props = { Value = 1, Label = "Camera sensitivity", ValueText = "100%", OnChanged = nothing } },
		{ Id = "Bare", Props = { Value = 0.35, OnChanged = nothing } },
		{ Id = "LabelOnly", Props = { Value = 0.5, Label = "Brightness", OnChanged = nothing } },
	},
}

local swatchItem = {
	Id = "Controls.Swatch",
	Frame = "Bare",
	Slot = nil,
	Mount = mounter(Controls.Swatch),
	States = {
		{ Id = "Orange", Props = { Colour = PAINT_ORANGE, OnActivated = nothing } },
		{ Id = "OrangeSelected", Props = { Colour = PAINT_ORANGE, Selected = true, OnActivated = nothing } },
		{ Id = "Teal", Props = { Colour = PAINT_TEAL, OnActivated = nothing } },
		{ Id = "WhiteSelected", Props = { Colour = PAINT_WHITE, Selected = true, OnActivated = nothing } },
		{ Id = "Black", Props = { Colour = PAINT_BLACK, OnActivated = nothing } },
	},
}

return {
	buttonItem,
	rowItem,
	rowRailItem,
	rowCentreItem,
	rowHudItem,
	tabsItem,
	headerItem,
	iconButtonItem,
	switchItem,
	stepperItem,
	dropdownItem,
	sliderItem,
	swatchItem,
}
