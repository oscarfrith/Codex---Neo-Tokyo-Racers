-- Owns the gallery fixtures for Kit.Collections (Tile, Rail, ListRow, Chip, TierBadge); it does not own the gallery, any screen or any game data.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Collections. Requires: Collections.
local Collections = require(script.Parent.Parent.Parent.Kit.Collections)

local function nothing() end

-- Example data only. Prices are already formatted, as the shared money formatter would return them.
local VEHICLES = {
	{ Key = "stinger", Title = "Stinger", Sub = "Exotic", Tier = "D", Rating = 316, Price = "$84,000", Icon = "car" },
	{ Key = "zephyr", Title = "Zephyr", Sub = "Exotic", Tier = "D", Rating = 390, Price = "$150,000", Icon = "car" },
	{ Key = "aurora", Title = "Aurora", Sub = "Exotic", Tier = "C", Rating = 540, Price = "$440,000", Icon = "car" },
	{ Key = "endura", Title = "Endura", Sub = "Exotic", Tier = "B", Rating = 675, Price = "$1.40M", Icon = "car" },
	{ Key = "rosso", Title = "Rosso", Sub = "Exotic", Tier = "A", Rating = 800, Price = "$4.40M", Icon = "car", Status = "Unaffordable" },
	{ Key = "seraph", Title = "Seraph", Sub = "Exotic", Tier = "S", Rating = 939, Price = "$9.80M", Icon = "car", Status = "Unaffordable" },
}

local OWNED = {
	{ Key = "seraph", Title = "Seraph", Sub = "Tier C only", Tier = "S", Rating = 939, Icon = "car", Status = "Locked" },
	{ Key = "endura", Title = "Endura", Sub = "Tier C only", Tier = "B", Rating = 675, Icon = "car", Status = "Locked" },
	{ Key = "aurora", Title = "Aurora", Sub = "Exotic", Tier = "C", Rating = 540, Icon = "car" },
	{ Key = "zephyr", Title = "Zephyr", Sub = "Exotic", Tier = "C", Rating = 498, Icon = "car" },
	{ Key = "rosso", Title = "Rosso", Sub = "Tier C only", Tier = "A", Rating = 800, Icon = "car", Status = "Locked" },
	{ Key = "stinger", Title = "Stinger", Sub = "Tier C only", Tier = "D", Rating = 316, Icon = "car", Status = "Locked" },
}

local SLOTS = {
	{ Key = "front_body", Title = "Front body", Sub = "Standard", ChipLeft = "01", Status = "Fitted", Icon = "car", Compact7 = true },
	{ Key = "rear_body", Title = "Rear body", Sub = "Standard", ChipLeft = "02", Status = "Fitted", Icon = "car", Compact7 = true },
	{ Key = "front_engine", Title = "Front engine", Sub = "Standard", ChipLeft = "03", Status = "Fitted", Icon = "gauge", Compact7 = true },
	{ Key = "rear_engine", Title = "Rear engine", Sub = "Standard", ChipLeft = "04", Status = "Fitted", Icon = "gauge", Compact7 = true },
	{ Key = "drift_thrusters", Title = "Drift thrusters", Sub = "Standard", ChipLeft = "05", Status = "Fitted", Icon = "drift", Compact7 = true },
	{ Key = "overdrive", Title = "Overdrive", Sub = "Standard", ChipLeft = "06", Status = "Fitted", Icon = "boost", Compact7 = true },
	{ Key = "wing", Title = "Wing", Sub = "Nothing fitted", ChipLeft = "07", ChipRight = "Empty", Icon = "upgrade", Compact7 = true },
}

local WINGS = {
	{ Key = "spine_std", Title = "Spine wing", Sub = "Spine \u{00B7} D 316", ChipLeft = "Std", Status = "Fitted", Icon = "upgrade" },
	{ Key = "spine_evo", Title = "Spine wing", Sub = "Spine \u{00B7} D 321", ChipLeft = "Evo", Status = "Owned", ChipRight = "Owned x2", Icon = "upgrade" },
	{ Key = "bridge_gt", Title = "Bridge wing", Sub = "Bridge \u{00B7} D 318", ChipLeft = "GT", Price = "$6,000", Icon = "upgrade" },
	{ Key = "blade_std", Title = "Blade wing", Sub = "Buy Zephyr to unlock", ChipLeft = "Std", Price = "$84,000", Icon = "upgrade", Status = "Locked" },
}

local function mountTile(parent, props, scope, _ctx)
	return Collections.Tile(parent, props, scope)
end

local function mountListRow(parent, props, scope, _ctx)
	return Collections.ListRow(parent, props, scope)
end

local function mountChip(parent, props, scope, _ctx)
	return Collections.Chip(parent, props, scope)
end

local function mountBadge(parent, props, scope, _ctx)
	return Collections.TierBadge(parent, props, scope)
end

-- A rail state carries its items and first selection beside the Rail props.
local function mountRail(parent, props, scope, _ctx)
	local railProps = {}
	for key, value in pairs(props) do
		if key ~= "Items" and key ~= "Select" then
			railProps[key] = value
		end
	end
	local rail = Collections.Rail(parent, railProps, scope)
	rail.SetItems(props.Items or {})
	if props.Select ~= nil then
		rail.Select(props.Select)
	end
	return rail
end

local tileItem = {
	Id = "Collections.Tile",
	Frame = "Bare",
	Slot = nil,
	Mount = mountTile,
	States = {
		{ Id = "Default", Props = { Title = "Aurora", Sub = "Exotic", Tier = "C", Rating = 540, Price = "$440,000", Icon = "car", OnActivated = nothing } },
		{ Id = "Selected", Props = { Title = "Zephyr", Sub = "Exotic", Tier = "D", Rating = 390, Price = "$150,000", Icon = "car", State = "Selected", OnActivated = nothing } },
		{ Id = "Owned", Props = { Title = "Stinger", Sub = "Exotic", Tier = "E", Rating = 220, Status = "Owned", Icon = "car", OnActivated = nothing } },
		{ Id = "OwnedSelected", Props = { Title = "Stinger", Sub = "Exotic", Tier = "E", Rating = 220, Status = "Owned", Icon = "car", State = "Selected", OnActivated = nothing } },
		{ Id = "Fitted", Props = { Title = "Spine wing", Sub = "Spine \u{00B7} D 316", ChipLeft = "Std", Status = "Fitted", Icon = "upgrade", OnActivated = nothing } },
		{ Id = "OwnedCount", Props = { Title = "Spine wing", Sub = "Spine \u{00B7} D 321", ChipLeft = "Evo", Status = "Owned", ChipRight = "Owned x2", Icon = "upgrade", State = "Selected", OnActivated = nothing } },
		{ Id = "Locked", Props = { Title = "Bridge wing", Sub = "Buy Zephyr to unlock", ChipLeft = "GT", Price = "$84,000", Status = "Locked", Icon = "upgrade", OnActivated = nothing } },
		{ Id = "LockedVehicle", Props = { Title = "Seraph", Sub = "Tier C only", Tier = "S", Rating = 939, Status = "Locked", Icon = "car", OnActivated = nothing } },
		{ Id = "Unaffordable", Props = { Title = "Rosso", Sub = "Exotic", Tier = "A", Rating = 800, Price = "$4.40M", Status = "Unaffordable", Icon = "car", OnActivated = nothing } },
		{ Id = "NoImage", Props = { Title = "Endura", Sub = "Exotic", Tier = "B", Rating = 675, Price = "$1.40M", OnActivated = nothing } },
		{ Id = "NoImageSelected", Props = { Title = "Endura", Sub = "Exotic", Tier = "B", Rating = 675, Price = "$1.40M", State = "Selected", OnActivated = nothing } },
		{ Id = "EmptyImageId", Props = { Title = "Seraph", Sub = "Exotic", Tier = "S", Rating = 939, Price = "$9.80M", Image = "", OnActivated = nothing } },
		{ Id = "SevenSlot", Props = { Title = "Front engine", Sub = "Standard", ChipLeft = "03", Status = "Fitted", Icon = "gauge", Compact7 = true, OnActivated = nothing } },
		{ Id = "SevenTwoLineSelected", Props = { Title = "Drift thrusters", Sub = "Standard", ChipLeft = "05", Status = "Fitted", Icon = "drift", Compact7 = true, State = "Selected", OnActivated = nothing } },
		{ Id = "SevenEmptySlot", Props = { Title = "Wing", Sub = "Nothing fitted", ChipLeft = "07", ChipRight = "Empty", Compact7 = true, OnActivated = nothing } },
		{ Id = "LongestStrings", Props = { Title = "Shifted canal sprint", Sub = "In use by Zephyr \u{00B7} circuit \u{00B7} 3 laps", Tier = "S", Rating = 936, Price = "$3,613,709", Icon = "route", OnActivated = nothing } },
		{ Id = "TitleOnly", Props = { Title = "Stinger", OnActivated = nothing } },
	},
}

local railItem = {
	Id = "Collections.Rail",
	Frame = "Scene",
	Slot = "BottomRail",
	Mount = mountRail,
	States = {
		{ Id = "Dealership", Props = { Heading = "Exotic", Count = "2/6", Items = VEHICLES, Select = "zephyr", OnSelected = nothing } },
		{ Id = "RaceEntryVehicles", Props = { Heading = "Tier C", Count = "3/6", Items = OWNED, Select = "aurora", OnSelected = nothing } },
		{ Id = "PartsSeven", Props = { Heading = "Parts", Count = "3/7", CellWidth = 236, Items = SLOTS, Select = "front_engine", OnSelected = nothing } },
		{ Id = "ModuleShop", Props = { Heading = "Wing", Count = "2/4", Items = WINGS, Select = "spine_evo", OnSelected = nothing } },
		{ Id = "NothingSelected", Props = { Heading = "Exotic", Count = "0/6", Items = VEHICLES, OnSelected = nothing } },
		{ Id = "NoHeading", Props = { Items = VEHICLES, Select = "aurora", OnSelected = nothing } },
		{ Id = "Empty", Props = { Heading = "Owned", Count = "0/0", Items = {}, OnSelected = nothing } },
	},
}

local listRowItem = {
	Id = "Collections.ListRow",
	Frame = "Bare",
	Slot = nil,
	Mount = mountListRow,
	States = {
		{ Id = "Default", Props = { Title = "Shifted canal sprint", Sub = "Circuit \u{00B7} 3 laps", OnActivated = nothing } },
		{ Id = "Selected", Props = { Title = "Showroom loop", Sub = "Circuit \u{00B7} 3 laps", State = "Selected", OnActivated = nothing } },
		{ Id = "Locked", Props = { Title = "Showroom loop", Sub = "Unavailable", Locked = true, OnActivated = nothing } },
		{ Id = "VehicleSpawned", Props = { Title = "Aurora", Sub = "Exotic", Tier = "C", Right = "Spawned", OnActivated = nothing } },
		{ Id = "VehicleParkedSelected", Props = { Title = "Seraph", Sub = "Exotic", Tier = "S", Right = "Parked", State = "Selected", OnActivated = nothing } },
		{ Id = "LiveOrder", Props = { Title = "Neonrider", Right = "-1.8", OnActivated = nothing } },
		{ Id = "LiveOrderYou", Props = { Title = "You", Right = "Seraph", State = "Selected", OnActivated = nothing } },
		{ Id = "EmptyImageId", Props = { Title = "Showroom loop", Sub = "Time trial \u{00B7} 17 checkpoints", Image = "", Right = "$25,000", OnActivated = nothing } },
		{ Id = "LongestStrings", Props = { Title = "Shifted canal sprint reverse", Sub = "Time trial \u{00B7} 3 laps \u{00B7} 17 checkpoints", Tier = "A", Right = "01:03.275", OnActivated = nothing } },
		{ Id = "LockedSelected", Props = { Title = "Endura", Sub = "Tier C only", Tier = "B", Locked = true, State = "Selected", OnActivated = nothing } },
	},
}

local chipItem = {
	Id = "Collections.Chip",
	Frame = "Bare",
	Slot = nil,
	Mount = mountChip,
	States = {
		{ Id = "Neutral", Props = { Text = "Fitted", Kind = "Neutral" } },
		{ Id = "NeutralCount", Props = { Text = "Owned x2", Kind = "Neutral" } },
		{ Id = "NeutralMuted", Props = { Text = "In use", Kind = "Neutral", Muted = true } },
		{ Id = "Price", Props = { Text = "$6,000", Kind = "Price" } },
		{ Id = "PriceLongest", Props = { Text = "$3,613,709", Kind = "Price" } },
		{ Id = "PriceUnaffordable", Props = { Text = "$84,000", Kind = "Price", Muted = true } },
		{ Id = "CyanGain", Props = { Text = "+3", Kind = "Cyan" } },
		{ Id = "PinkLoss", Props = { Text = "-2", Kind = "Pink" } },
		{ Id = "PinkEmpty", Props = { Text = "Empty", Kind = "Pink" } },
		{ Id = "YellowPrize", Props = { Text = "$25,000", Kind = "Yellow" } },
	},
}

local badgeItem = {
	Id = "Collections.TierBadge",
	Frame = "Bare",
	Slot = nil,
	Mount = mountBadge,
	States = {
		{ Id = "E", Props = { Tier = "E", Rating = 220 } },
		{ Id = "D", Props = { Tier = "D", Rating = 390 } },
		{ Id = "C", Props = { Tier = "C", Rating = 540 } },
		{ Id = "B", Props = { Tier = "B", Rating = 675 } },
		{ Id = "A", Props = { Tier = "A", Rating = 800 } },
		{ Id = "S", Props = { Tier = "S", Rating = 939 } },
		{ Id = "LetterOnly", Props = { Tier = "C" } },
		{ Id = "Medium", Props = { Tier = "D", Rating = 316, Size = "Medium" } },
		{ Id = "Small", Props = { Tier = "S", Rating = 936, Size = "Small" } },
		{ Id = "SmallLetterOnly", Props = { Tier = "S", Size = "Small" } },
		{ Id = "OnLight", Props = { Tier = "C", Rating = 540, OnLight = true } },
		{ Id = "Dim", Props = { Tier = "A", Rating = 800, Dim = true } },
	},
}

return { tileItem, railItem, listRowItem, chipItem, badgeItem }
