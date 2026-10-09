-- Owns the gallery fixtures for Kit.Controls (Button, ButtonRow, Tabs); it does not own the gallery, any screen or any game data.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Controls. Requires: Controls.
local Controls = require(script.Parent.Parent.Parent.Kit.Controls)

local function nothing() end

local function mountButton(parent, props, scope, _ctx)
	return Controls.Button(parent, props, scope)
end

local function mountRow(parent, props, scope, _ctx)
	return Controls.ButtonRow(parent, props, scope)
end

local function mountTabs(parent, props, scope, _ctx)
	return Controls.Tabs(parent, props, scope)
end

local buttonItem = {
	Id = "Controls.Button",
	Frame = "Bare",
	Slot = nil,
	Mount = mountButton,
	States = {
		{ Id = "Default", Props = { Variant = "Default", Text = "Back", Icon = "back", OnActivated = nothing } },
		{ Id = "DefaultNoIcon", Props = { Variant = "Default", Text = "No", OnActivated = nothing } },
		{ Id = "Main", Props = { Variant = "Main", Text = "Drive", Icon = "steering_wheel", OnActivated = nothing } },
		{ Id = "MainLongest", Props = { Variant = "Main", Text = "Start time trial", Icon = "race_flag", OnActivated = nothing } },
		{ Id = "Buy", Props = { Variant = "Buy", Text = "Buy $150,000", OnActivated = nothing } },
		{ Id = "Danger", Props = { Variant = "Danger", Text = "Despawn", Icon = "close", OnActivated = nothing } },
		{ Id = "Icon", Props = { Variant = "Icon", Icon = "garage", OnActivated = nothing } },
		{ Id = "Disabled", Props = { Variant = "Default", Text = "Drive", Icon = "steering_wheel", Disabled = true, OnActivated = nothing } },
		{ Id = "Locked", Props = { Variant = "Default", Text = "Set route", Icon = "set_route", Locked = true, OnActivated = nothing } },
		{ Id = "MainDisabled", Props = { Variant = "Main", Text = "Equip", Icon = "tick", Disabled = true, OnActivated = nothing } },
		{ Id = "BuyUnaffordable", Props = { Variant = "Buy", Text = "Buy $4.40M", Disabled = true, OnActivated = nothing } },
		{ Id = "DangerDisabled", Props = { Variant = "Danger", Text = "Despawn", Icon = "close", Disabled = true, OnActivated = nothing } },
		{ Id = "IconDisabled", Props = { Variant = "Icon", Icon = "settings_cog", Disabled = true, OnActivated = nothing } },
		{ Id = "Large", Props = { Variant = "Default", Size = "Large", Text = "Exit vehicle", Icon = "exit", OnActivated = nothing } },
		{ Id = "LargeMain", Props = { Variant = "Main", Size = "Large", Text = "Continue", OnActivated = nothing } },
		{ Id = "MinWidth", Props = { Variant = "Default", Text = "Yes", MinWidth = 250, OnActivated = nothing } },
	},
}

local rowItem = {
	Id = "Controls.ButtonRow",
	Frame = "Scene",
	Slot = "BottomRight",
	Mount = mountRow,
	States = {
		{
			Id = "ModuleShop",
			Props = {
				Align = "Right",
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
				Align = "Right",
				Buttons = {
					{ Id = "Exit", Variant = "Default", Text = "Exit", Icon = "exit", OnActivated = nothing },
					{ Id = "Buy", Variant = "Buy", Text = "Buy $150,000", OnActivated = nothing },
				},
			},
		},
		{
			Id = "DealershipUnaffordable",
			Props = {
				Align = "Right",
				Buttons = {
					{ Id = "Exit", Variant = "Default", Text = "Exit", Icon = "exit", OnActivated = nothing },
					{ Id = "Buy", Variant = "Buy", Text = "Buy $4.40M", Disabled = true, OnActivated = nothing },
				},
			},
		},
		{
			Id = "RaceEntryLongest",
			Props = {
				Align = "Right",
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
				Align = "Right",
				Buttons = {
					{ Id = "Back", Variant = "Default", Text = "Back", Icon = "back", OnActivated = nothing },
					{ Id = "Drive", Variant = "Main", Text = "Drive", Icon = "steering_wheel", Disabled = true, OnActivated = nothing },
				},
			},
		},
		{
			Id = "Destructive",
			Props = {
				Align = "Right",
				Buttons = {
					{ Id = "Back", Variant = "Default", Text = "Back", Icon = "back", OnActivated = nothing },
					{ Id = "Despawn", Variant = "Danger", Text = "Despawn", Icon = "close", OnActivated = nothing },
				},
			},
		},
	},
}

local rowCentreItem = {
	Id = "Controls.ButtonRowCentre",
	Frame = "Menu",
	Slot = "BottomCentre",
	Mount = mountRow,
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
			Id = "HudDriving",
			Props = {
				Align = "Centre",
				Buttons = {
					{ Id = "Controls", Variant = "Default", Text = "Controls", Icon = "gamepad", OnActivated = nothing },
					{ Id = "ExitVehicle", Variant = "Default", Text = "Exit vehicle", Icon = "exit", OnActivated = nothing },
				},
			},
		},
	},
}

local tabsItem = {
	Id = "Controls.Tabs",
	Frame = "Scene",
	Slot = "TopLeft",
	Mount = mountTabs,
	States = {
		{
			Id = "Customise",
			Props = {
				Selected = "Parts",
				Bumpers = true,
				OnSelected = nothing,
				Tabs = {
					{ Id = "Parts", Text = "Parts", Icon = "customise" },
					{ Id = "Upgrades", Text = "Upgrades", Icon = "upgrade" },
					{ Id = "Paint", Text = "Paint", Icon = "paint" },
				},
			},
		},
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
		{
			Id = "DealershipCategories",
			Props = {
				Selected = "Exotic",
				Bumpers = true,
				OnSelected = nothing,
				Tabs = {
					{ Id = "Starter", Text = "Starter" },
					{ Id = "Piercer", Text = "Piercer" },
					{ Id = "Exotic", Text = "Exotic" },
					{ Id = "Hypercar", Text = "Hypercar", Locked = true },
				},
			},
		},
		{
			Id = "RaceFilters",
			Props = {
				Selected = "All",
				OnSelected = nothing,
				Tabs = {
					{ Id = "All", Text = "All events", Icon = "race_flag" },
					{ Id = "Circuit", Text = "Circuits", Icon = "laps" },
					{ Id = "TimeTrial", Text = "Time trials", Icon = "timer" },
					{ Id = "Duel", Text = "Duels", Icon = "duel" },
				},
			},
		},
		{
			Id = "NoneSelected",
			Props = {
				OnSelected = nothing,
				Tabs = {
					{ Id = "Shop", Text = "Shop" },
					{ Id = "Owned", Text = "Owned" },
				},
			},
		},
	},
}

return { buttonItem, rowItem, rowCentreItem, tabsItem }
