-- Owns the gallery fixtures for Kit.Data (CashChip, StatusCluster, SegmentedBar, DeltaChip, StatPanel, FactList); it does not own the gallery, any screen, Cash or any game data.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Data. Requires: Data.
local Data = require(script.Parent.Parent.Parent.Kit.Data)

local function nothing() end

-- A state may carry Amount beside the component props: a canned figure shown through SetAmount (the
-- shared formatter), never a player's Cash. Nothing here binds leaderstats.
local function split(props)
	local own = {}
	for key, value in pairs(props) do
		if key ~= "Amount" then
			own[key] = value
		end
	end
	return own, props.Amount
end

local function mountCash(parent, props, scope, _ctx)
	local own, amount = split(props)
	local chip = Data.CashChip(parent, own, scope)
	if amount ~= nil then
		chip.SetAmount(amount)
	end
	return chip
end

local function mountStatus(parent, props, scope, _ctx)
	local own, amount = split(props)
	local cluster = Data.StatusCluster(parent, own, scope)
	if amount ~= nil then
		cluster.Cash.SetAmount(amount)
	end
	return cluster
end

local function mountBar(parent, props, scope, _ctx)
	return Data.SegmentedBar(parent, props, scope)
end

local function mountDelta(parent, props, scope, _ctx)
	return Data.DeltaChip(parent, props, scope)
end

local function mountStats(parent, props, scope, _ctx)
	return Data.StatPanel(parent, props, scope)
end

local function mountFacts(parent, props, scope, _ctx)
	return Data.FactList(parent, props, scope)
end

-- Example data only.
local ZEPHYR_ROWS = {
	{ Id = "Speed", Label = "Speed", Value = 77 },
	{ Id = "Accel", Label = "Accel", Value = 74 },
	{ Id = "Handling", Label = "Handling", Value = 74 },
	{ Id = "Drift", Label = "Drift", Value = 72 },
	{ Id = "Braking", Label = "Braking", Value = 73 },
	{ Id = "Boost", Label = "Boost", Value = 72 },
}

local STINGER_PREVIEW_ROWS = {
	{ Id = "Speed", Label = "Speed", Value = 80 },
	{ Id = "Accel", Label = "Accel", Value = 74 },
	{ Id = "Handling", Label = "Handling", Value = 63, Preview = 66 },
	{ Id = "Drift", Label = "Drift", Value = 61, Preview = 63 },
	{ Id = "Braking", Label = "Braking", Value = 62 },
	{ Id = "Boost", Label = "Boost", Value = 61, Preview = 59 },
}

local EXTREME_ROWS = {
	{ Id = "Speed", Label = "Speed", Value = 100, Preview = 100 },
	{ Id = "Accel", Label = "Acceleration", Value = 0, Preview = 12 },
	{ Id = "Handling", Label = "Handling", Value = 99, Preview = 100 },
	{ Id = "Drift", Label = "Drift", Value = 1, Preview = 0 },
	{ Id = "Braking", Label = "Braking", Value = 50, Text = "N/A" },
	{ Id = "Boost", Label = "Boost", Value = 320, Max = 400, Preview = 250 },
}

local RACE_FACTS = {
	{ Id = "Route", Icon = "route", Label = "Route", Value = "Circuit" },
	{ Id = "Laps", Icon = "loop", Label = "Laps", Value = "3" },
	{ Id = "Players", Icon = "players", Label = "Players", Value = "2 to 6" },
	{ Id = "Prize", Label = "Prize", Value = "$10,000", Kind = "Prize" },
}

local LONG_FACTS = {
	{ Id = "Route", Icon = "route", Label = "Route", Value = "Shifted canal sprint reverse" },
	{ Id = "Checkpoints", Icon = "checkpoints", Label = "Checkpoints", Value = "17" },
	{ Id = "Best", Icon = "timer", Label = "Personal best", Value = "01:03.275" },
	{ Id = "Tier", Icon = "car", Label = "Vehicle tier", Value = "Tier C only" },
	{ Id = "Players", Icon = "players", Label = "Players", Value = "2 to 12" },
	{ Id = "Prize", Icon = "coin", Label = "Prize", Value = "$3,613,709", Kind = "Prize" },
}

local cashItem = {
	Id = "Data.CashChip",
	Frame = "Bare",
	Slot = nil,
	Mount = mountCash,
	States = {
		{ Id = "Full", Props = { Compact = false, Amount = 3613709 } },
		{ Id = "FullWithPlus", Props = { Compact = false, Plus = true, OnPlus = nothing, Amount = 3613696 } },
		{ Id = "ShortForm", Props = { Compact = true, Amount = 12400000 } },
		{ Id = "ShortFormUnderMillion", Props = { Compact = true, Amount = 84000 } },
		{ Id = "ClassDefault", Props = { Amount = 1000000 } },
		{ Id = "FreeRoam", Props = { Compact = false, FreeRoam = true, Amount = 3613709 } },
		{ Id = "Zero", Props = { Compact = false, Amount = 0 } },
		{ Id = "Longest", Props = { Compact = false, Plus = true, OnPlus = nothing, Amount = 2000000000 } },
		{ Id = "NotLoaded", Props = {} },
	},
}

local statusItem = {
	Id = "Data.StatusCluster",
	Frame = "Hud",
	Slot = "TopRight",
	Mount = mountStatus,
	States = {
		{ Id = "Driving", Props = { Mode = "Vehicle", Tier = "S", Rating = 939, Rank = 6, Amount = 3613709 } },
		{ Id = "DrivingLowTier", Props = { Mode = "Vehicle", Tier = "E", Rating = 220, Rank = 1, Amount = 1234 } },
		{ Id = "OnFoot", Props = { Mode = "Vehicle", Label = "On foot", Rank = 6, Amount = 3613696 } },
		{ Id = "Garage", Props = { Mode = "Garage", Spaces = "3 / 4", Rank = 6, ShowPlus = true, OnSpacesPlus = nothing, OnCashPlus = nothing, Amount = 3613696 } },
		{ Id = "GarageNoPlus", Props = { Mode = "Garage", Spaces = "1 / 2", Rank = 1, Amount = 1000000 } },
		{ Id = "GarageFull", Props = { Mode = "Garage", Spaces = "12 / 12", Rank = 100, ShowPlus = true, OnSpacesPlus = nothing, OnCashPlus = nothing, Amount = 2000000000 } },
		{ Id = "NoRank", Props = { Mode = "Vehicle", Tier = "C", Rating = 540, Amount = 440000 } },
		{ Id = "CashOnly", Props = { Mode = "CashOnly", Amount = 3613709 } },
		{ Id = "CashNotLoaded", Props = { Mode = "Vehicle", Tier = "D", Rating = 390, Rank = 2 } },
	},
}

local barItem = {
	Id = "Data.SegmentedBar",
	Frame = "Bare",
	Slot = nil,
	Mount = mountBar,
	States = {
		{ Id = "Value", Props = { Value = 0.77 } },
		{ Id = "Gain", Props = { Value = 0.63, Preview = 0.66 } },
		{ Id = "Loss", Props = { Value = 0.61, Preview = 0.59 } },
		{ Id = "Empty", Props = { Value = 0 } },
		{ Id = "Full", Props = { Value = 1 } },
		{ Id = "GainFromEmpty", Props = { Value = 0, Preview = 1 } },
		{ Id = "LossToEmpty", Props = { Value = 1, Preview = 0, PreviewColour = "Pink" } },
		{ Id = "EightSegments", Props = { Value = 0.58, Segments = 8 } },
		{ Id = "SmallestGain", Props = { Value = 0.5, Preview = 0.505 } },
	},
}

local deltaItem = {
	Id = "Data.DeltaChip",
	Frame = "Bare",
	Slot = nil,
	Mount = mountDelta,
	States = {
		{ Id = "Gain", Props = { Delta = 3 } },
		{ Id = "Loss", Props = { Delta = -2 } },
		{ Id = "GainLongest", Props = { Delta = 100 } },
		{ Id = "Fraction", Props = { Delta = 1.5, Suffix = "%" } },
		{ Id = "Zero", Props = { Delta = 0 } },
	},
}

local statItem = {
	Id = "Data.StatPanel",
	Frame = "Menu",
	Slot = "RightColumn",
	Mount = mountStats,
	States = {
		{ Id = "Dealership", Props = { Title = "Zephyr", Tier = "D", Rating = 390, Sub = { "Exotic \u{00B7} Performance" }, Rows = ZEPHYR_ROWS, Price = "$150,000" } },
		{ Id = "PartPreview", Props = { Title = "Stinger", Tier = "D", Rating = 321, Sub = { "Fitted wing  Spine Wing Standard", "Previewing  Spine Wing EVO" }, Rows = STINGER_PREVIEW_ROWS } },
		{ Id = "Extremes", Props = { Title = "Seraph", Tier = "S", Rating = 939, Sub = { "Exotic \u{00B7} Performance" }, Rows = EXTREME_ROWS, Price = "$9.8M" } },
		{ Id = "LongestStrings", Props = { Title = "Shifted canal sprint", Tier = "A", Rating = 1000, Sub = { "Fitted drift thrusters  Twin vector standard", "Previewing  Twin vector evolution" }, Rows = STINGER_PREVIEW_ROWS, Price = "$3,613,709" } },
		{ Id = "NoBadge", Props = { Title = "Garage", Sub = { "Akane district" }, Rows = ZEPHYR_ROWS } },
		{ Id = "Loading", Props = { Title = "", Rows = {} } },
		{ Id = "Unaffordable", Props = { Title = "Rosso", Tier = "A", Rating = 800, Sub = { "Exotic \u{00B7} Performance" }, Rows = ZEPHYR_ROWS, Price = "$4.4M" } },
	},
}

local factItem = {
	Id = "Data.FactList",
	Frame = "Bare",
	Slot = nil,
	Mount = mountFacts,
	States = {
		{ Id = "RaceEntry", Props = { Rows = RACE_FACTS } },
		{ Id = "LongestStrings", Props = { Rows = LONG_FACTS } },
		{ Id = "NoIcons", Props = { Rows = { { Id = "Laps", Label = "Laps", Value = "3" }, { Id = "Prize", Label = "Prize", Value = "$25,000", Kind = "Prize" } } } },
		{ Id = "Wide", Props = { Rows = RACE_FACTS, Width = 560 } },
		{ Id = "Empty", Props = { Rows = {} } },
	},
}

return { cashItem, statusItem, barItem, deltaItem, statItem, factItem }
