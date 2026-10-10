-- Owns the gallery fixtures for Kit.Collections (Tile, Rail, ListRow, List, Chip, TierBadge); it does not own the gallery, any screen or any game data.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Collections. Requires: Surface, Controls, Collections.
local Kit = script.Parent.Parent.Parent.Kit
local Surface = require(Kit.Surface)
local Controls = require(Kit.Controls)
local Collections = require(Kit.Collections)

local function nothing() end

-- The gallery stage is near black, where a Slate plate cannot be told from the background. On the stage centre
-- frame (not on a zero-size slot) a menu scrim goes behind the component, as a screen would have behind it.
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

-- Example data only. Prices are already formatted, as the shared money formatter would return them.
local VEHICLES = {
	{ Key = "stinger", Title = "Stinger", Sub = "Exotic", Tier = "E", Rating = 220, Status = "Owned", Icon = "car" },
	{ Key = "zephyr", Title = "Zephyr", Sub = "Exotic", Tier = "D", Rating = 390, Price = "$150,000", Icon = "car" },
	{ Key = "aurora", Title = "Aurora", Sub = "Exotic", Tier = "C", Rating = 540, Price = "$440,000", Icon = "car" },
	{ Key = "endura", Title = "Endura", Sub = "Exotic", Tier = "B", Rating = 675, Price = "$1.40M", Icon = "car" },
	{ Key = "rosso", Title = "Rosso", Sub = "Exotic", Tier = "A", Rating = 800, Price = "$4.40M", Icon = "car", Status = "Unaffordable" },
	{ Key = "seraph", Title = "Seraph", Sub = "Exotic", Tier = "S", Rating = 936, Price = "$9.80M", Icon = "car", Status = "Unaffordable" },
}

-- Mobile pass (A7): the longest names, a full price beside a tier badge and rating, and a locked tile. On Compact
-- every tile is one width, the name ends in an ellipsis and the top row drops the rating before anything overlaps.
local LONG_NAMES = {
	{ Key = "standard", Title = "Exotic Stinger standard", Tier = "E", Rating = 220, Status = "Owned", Icon = "car" },
	{ Key = "evo", Title = "Exotic Stinger evo", Tier = "D", Rating = 390, Price = "$150,000", Icon = "car" },
	{ Key = "meridian", Title = "Meridian grand tourer evoluzione GT", Tier = "S", Rating = 936, Price = "$12,000,000", Icon = "car", Status = "Unaffordable" },
	{ Key = "locked", Title = "Exotic Zephyr standard", Price = "$42,000", Icon = "upgrade", Status = "Locked" },
	{ Key = "fitted", Title = "Injectors level 2", Status = "Fitted", Icon = "upgrade" },
	{ Key = "tick", Title = "Front engine", ChipRightKind = "Tick", Icon = "gauge" },
}

-- The race-entry rail shows locked cars; they cannot be chosen (Locked, Selectable left unset).
local OWNED = {
	{ Key = "seraph", Title = "Seraph", Sub = "Tier C only", Tier = "S", Rating = 939, Icon = "car", Status = "Locked" },
	{ Key = "endura", Title = "Endura", Sub = "Tier C only", Tier = "B", Rating = 675, Icon = "car", Status = "Locked" },
	{ Key = "aurora", Title = "Aurora", Sub = "Exotic", Tier = "C", Rating = 540, Icon = "car" },
	{ Key = "kestrel", Title = "Kestrel", Sub = "Piercer", Tier = "C", Rating = 512, Icon = "car" },
	{ Key = "zephyr", Title = "Zephyr", Sub = "Exotic", Tier = "C", Rating = 498, Icon = "car" },
	{ Key = "stinger", Title = "Stinger", Sub = "Tier C only", Tier = "D", Rating = 316, Icon = "car", Status = "Locked" },
}

local SLOTS = {
	{ Key = "front_body", Title = "Front body", Sub = "Standard", ChipLeft = "01", ChipRightKind = "Tick", Icon = "car", Compact7 = true },
	{ Key = "rear_body", Title = "Rear body", Sub = "Standard", ChipLeft = "02", ChipRightKind = "Tick", Icon = "car", Compact7 = true },
	{ Key = "front_engine", Title = "Front engine", Sub = "Standard", ChipLeft = "03", ChipRightKind = "Tick", Icon = "gauge", Compact7 = true },
	{ Key = "rear_engine", Title = "Rear engine", Sub = "Standard", ChipLeft = "04", ChipRightKind = "Tick", Icon = "gauge", Compact7 = true },
	{ Key = "drift_thrusters", Title = "Drift thrusters", Sub = "Standard", ChipLeft = "05", ChipRightKind = "Tick", Icon = "drift", Compact7 = true },
	{ Key = "overdrive", Title = "Overdrive", Sub = "Standard", ChipLeft = "06", ChipRightKind = "Tick", Icon = "boost", Compact7 = true },
	{ Key = "wing", Title = "Wing", Sub = "Nothing fitted", ChipLeft = "07", ChipRight = "Empty", ChipRightKind = "Pink", Icon = "upgrade", Compact7 = true },
}

local WINGS = {
	{ Key = "spine_std", Title = "Spine wing", Sub = "Spine \u{00B7} D 316", ChipLeft = "Std", Status = "Fitted", Icon = "upgrade" },
	{ Key = "spine_evo", Title = "Spine wing", Sub = "Spine \u{00B7} D 321", ChipLeft = "Evo", Status = "Owned", ChipRight = "Owned x2", Icon = "upgrade" },
	{ Key = "bridge_gt", Title = "Bridge wing", Sub = "Bridge \u{00B7} D 318", ChipLeft = "GT", Status = "Owned", ChipRight = "Owned x1", Icon = "upgrade" },
	{ Key = "blade_std", Title = "Blade wing", Sub = "In use by Zephyr", ChipLeft = "Std", ChipRight = "In use", Icon = "upgrade", Selectable = false },
}

local WING_SHOP = {
	{ Key = "spine_std", Title = "Spine wing", Sub = "Spine \u{00B7} D 316", ChipLeft = "Std", Status = "Fitted", Icon = "upgrade" },
	{ Key = "bridge_gt", Title = "Bridge wing", Sub = "Bridge \u{00B7} D 318", ChipLeft = "GT", Price = "$6,000", Icon = "upgrade" },
	{ Key = "blade_evo", Title = "Blade wing", Sub = "Blade \u{00B7} D 324", ChipLeft = "Evo", Price = "$84,000", Icon = "upgrade", Status = "Unaffordable" },
	{ Key = "bridge_std", Title = "Bridge wing", Sub = "Buy Zephyr to unlock", ChipLeft = "Std", Price = "$84,000", Icon = "upgrade", Status = "Locked" },
}

local MY_VEHICLES = {
	{ Key = "buy_more", Title = "Buy more", Icon = "plus" },
	{ Key = "seraph", Title = "Seraph", Tier = "S", Icon = "car" },
	{ Key = "rosso", Title = "Rosso", Tier = "A", Icon = "car" },
	{ Key = "endura", Title = "Endura", Tier = "B", Icon = "car" },
	{ Key = "aurora", Title = "Aurora", Tier = "C", Icon = "car" },
	{ Key = "zephyr", Title = "Zephyr", Tier = "D", Icon = "car" },
	{ Key = "stinger", Title = "Stinger", Tier = "E", Icon = "car" },
	{ Key = "kestrel", Title = "Kestrel", Tier = "C", Icon = "car" },
}

local SEGMENT = {
	Style = "Segment",
	Triggers = true,
	Selected = "Owned",
	OnSelected = nothing,
	Tabs = { { Id = "Shop", Text = "Shop" }, { Id = "Owned", Text = "Owned" } },
}

-- A rail state carries its items, its first selection and what goes in HeadingRight beside the Rail props.
local RAIL_EXTRAS = { Items = true, Select = true, Segment = true }

local function mountRail(parent, props, scope, _ctx)
	backdrop(parent, scope)
	local railProps = {}
	for key, value in pairs(props) do
		if not RAIL_EXTRAS[key] then
			railProps[key] = value
		end
	end
	local rail = Collections.Rail(parent, railProps, scope)
	rail.SetItems(props.Items or {})
	if props.Select ~= nil then
		rail.Select(props.Select)
	end
	if props.Segment ~= nil then
		Controls.Tabs(rail.HeadingRight, props.Segment, scope)
	end
	return rail
end

-- A list state carries its items and first selection beside the List props.
local function mountList(parent, props, scope, _ctx)
	backdrop(parent, scope)
	local listProps = {}
	for key, value in pairs(props) do
		if key ~= "Items" and key ~= "Select" then
			listProps[key] = value
		end
	end
	local list = Collections.List(parent, listProps, scope)
	list.SetItems(props.Items or {})
	if props.Select ~= nil then
		list.Select(props.Select)
	end
	return list
end

local tileItem = {
	Id = "Collections.Tile",
	Frame = "Bare",
	Slot = nil,
	Mount = mounter(Collections.Tile),
	States = {
		{ Id = "Default", Props = { Title = "Aurora", Sub = "Exotic", Tier = "C", Rating = 540, Price = "$440,000", Icon = "car", OnActivated = nothing } },
		{ Id = "Selected", Props = { Title = "Zephyr", Sub = "Exotic", Tier = "D", Rating = 390, Price = "$150,000", Icon = "car", State = "Selected", OnActivated = nothing } },
		{ Id = "Owned", Props = { Title = "Stinger", Sub = "Exotic", Tier = "E", Rating = 220, Status = "Owned", Icon = "car", OnActivated = nothing } },
		{ Id = "OwnedSelected", Props = { Title = "Stinger", Sub = "Exotic", Tier = "E", Rating = 220, Status = "Owned", Icon = "car", State = "Selected", OnActivated = nothing } },
		{ Id = "Fitted", Props = { Title = "Spine wing", Sub = "Spine \u{00B7} D 316", ChipLeft = "Std", Status = "Fitted", Icon = "upgrade", OnActivated = nothing } },
		{ Id = "OwnedCount", Props = { Title = "Spine wing", Sub = "Spine \u{00B7} D 321", ChipLeft = "Evo", Status = "Owned", ChipRight = "Owned x2", Icon = "upgrade", State = "Selected", OnActivated = nothing } },
		{ Id = "Locked", Props = { Title = "Bridge wing", Sub = "Buy Zephyr to unlock", ChipLeft = "GT", Price = "$84,000", Status = "Locked", Icon = "upgrade", OnActivated = nothing } },
		{ Id = "LockedVehicle", Props = { Title = "Seraph", Sub = "Tier C only", Tier = "S", Rating = 939, Status = "Locked", Icon = "car", OnActivated = nothing } },
		{ Id = "LockedSelectable", Props = { Title = "Seraph", Sub = "Tier C only", Tier = "S", Rating = 939, Status = "Locked", Selectable = true, Icon = "car", OnActivated = nothing } },
		{ Id = "Unaffordable", Props = { Title = "Rosso", Sub = "Exotic", Tier = "A", Rating = 800, Price = "$4.40M", Status = "Unaffordable", Icon = "car", OnActivated = nothing } },
		{ Id = "UnaffordableSelected", Props = { Title = "Rosso", Sub = "Exotic", Tier = "A", Rating = 800, Price = "$4.40M", Status = "Unaffordable", Icon = "car", State = "Selected", OnActivated = nothing } },
		{ Id = "NotSelectable", Props = { Title = "Blade wing", Sub = "In use by Zephyr", ChipLeft = "Std", ChipRight = "In use", Icon = "upgrade", Selectable = false, OnActivated = nothing } },
		{ Id = "NoImage", Props = { Title = "Endura", Sub = "Exotic", Tier = "B", Rating = 675, Price = "$1.40M", OnActivated = nothing } },
		{ Id = "NoImageSelected", Props = { Title = "Endura", Sub = "Exotic", Tier = "B", Rating = 675, Price = "$1.40M", State = "Selected", OnActivated = nothing } },
		{ Id = "EmptyImageId", Props = { Title = "Seraph", Sub = "Exotic", Tier = "S", Rating = 939, Price = "$9.80M", Image = "", OnActivated = nothing } },
		{ Id = "SevenSlot", Props = { Title = "Front engine", Sub = "Standard", ChipLeft = "03", Status = "Fitted", Icon = "gauge", Compact7 = true, OnActivated = nothing } },
		{ Id = "SevenTwoLineSelected", Props = { Title = "Drift thrusters", Sub = "Standard", ChipLeft = "05", Status = "Fitted", Icon = "drift", Compact7 = true, State = "Selected", OnActivated = nothing } },
		{ Id = "SevenEmptySlotPink", Props = { Title = "Wing", Sub = "Nothing fitted", ChipLeft = "07", ChipRight = "Empty", ChipRightKind = "Pink", Compact7 = true, OnActivated = nothing } },
		{ Id = "TickCorner", Props = { Title = "Front body", Sub = "Standard", ChipLeft = "01", ChipRightKind = "Tick", Icon = "car", Compact7 = true, OnActivated = nothing } },
		{ Id = "TickCornerSelected", Props = { Title = "Front engine", Sub = "Standard", ChipLeft = "03", ChipRightKind = "Tick", Icon = "gauge", Compact7 = true, State = "Selected", OnActivated = nothing } },
		{ Id = "CyanChip", Props = { Title = "Spine wing", Sub = "Spine \u{00B7} D 321", ChipLeft = "Evo", ChipRight = "New", ChipRightKind = "Cyan", Icon = "upgrade", OnActivated = nothing } },
		{ Id = "LongestStrings", Props = { Title = "Shifted canal sprint", Sub = "In use by Zephyr \u{00B7} circuit \u{00B7} 3 laps", Tier = "S", Rating = 936, Price = "$3,613,709", Icon = "route", OnActivated = nothing } },
		{ Id = "TitleOnly", Props = { Title = "Stinger", OnActivated = nothing } },
	},
}

local railItem = {
	Id = "Collections.Rail",
	Frame = "Menu",
	Slot = "BottomRail",
	Mount = mountRail,
	States = {
		{ Id = "Dealership", Props = { Heading = "Exotic", Count = "2/6", Items = VEHICLES, Select = "zephyr", OnSelected = nothing } },
		{ Id = "RaceEntryVehicles", Props = { Heading = "Tier C", Count = "3/6", Items = OWNED, Select = "aurora", OnSelected = nothing } },
		{ Id = "PartsSeven", Props = { Heading = "Parts", Count = "3/7", CellWidth = 236, Items = SLOTS, Select = "front_engine", OnSelected = nothing } },
		{ Id = "ModuleOwned", Props = { Heading = "Wing", Count = "2/4", Items = WINGS, Select = "spine_evo", Segment = SEGMENT, OnSelected = nothing } },
		{ Id = "ModuleShop", Props = { Heading = "Wing", Count = "2/4", Items = WING_SHOP, Select = "bridge_gt", Segment = { Style = "Segment", Triggers = true, Selected = "Shop", OnSelected = nothing, Tabs = SEGMENT.Tabs }, OnSelected = nothing } },
		{ Id = "FixedWidth", Props = { Heading = "Exotic", Count = "2/6", Width = 1000, Items = VEHICLES, Select = "zephyr", OnSelected = nothing } },
		{ Id = "SelectOnActivate", Props = { Heading = "Parts", Count = "3/7", CellWidth = 236, SelectOn = "Activate", Items = SLOTS, Select = "front_engine", OnSelected = nothing } },
		{ Id = "LongNames", Props = { Heading = "Spoiler", Count = "2/6", Items = LONG_NAMES, Select = "evo", OnSelected = nothing } },
		{ Id = "LongNamesSelectedLong", Props = { Heading = "Spoiler", Count = "3/6", Items = LONG_NAMES, Select = "meridian", OnSelected = nothing } },
		{ Id = "NothingSelected", Props = { Heading = "Exotic", Count = "0/6", Items = VEHICLES, OnSelected = nothing } },
		{ Id = "NoHeading", Props = { Items = VEHICLES, Select = "aurora", OnSelected = nothing } },
		{ Id = "Empty", Props = { Heading = "Owned", Count = "0/0", Items = {}, OnSelected = nothing } },
	},
}

-- The Compact car panel: a grid two cells across that scrolls vertically (Rows = 2), in the side panel slot.
local railGridItem = {
	Id = "Collections.RailGrid",
	Frame = "Hud",
	Slot = "SidePanel",
	Mount = mountRail,
	States = {
		{ Id = "MyVehicles", Props = { Heading = "My vehicles", Count = "7", Rows = 2, Items = MY_VEHICLES, Select = "seraph", OnSelected = nothing } },
		{ Id = "ThreeAcross", Props = { Heading = "My vehicles", Count = "7", Rows = 3, Items = MY_VEHICLES, Select = "aurora", OnSelected = nothing } },
		{ Id = "FixedWidth", Props = { Heading = "My vehicles", Count = "7", Rows = 2, Width = 220, Items = MY_VEHICLES, OnSelected = nothing } },
		{ Id = "OneVehicle", Props = { Heading = "My vehicles", Count = "1", Rows = 2, Items = { MY_VEHICLES[1], MY_VEHICLES[2] }, Select = "seraph", OnSelected = nothing } },
	},
}

local listRowItem = {
	Id = "Collections.ListRow",
	Frame = "Bare",
	Slot = nil,
	Mount = mounter(Collections.ListRow),
	States = {
		{ Id = "Default", Props = { Title = "Shifted canal sprint", Sub = "Circuit \u{00B7} 3 laps", OnActivated = nothing } },
		{ Id = "Selected", Props = { Title = "Showroom loop", Sub = "Circuit \u{00B7} 3 laps", State = "Selected", OnActivated = nothing } },
		{ Id = "Locked", Props = { Title = "Showroom loop", Sub = "Unavailable", Locked = true, OnActivated = nothing } },
		{ Id = "VehicleParked", Props = { Title = "Aurora", Sub = "Exotic", Tier = "C", Right = "Parked", Height = 120, OnActivated = nothing } },
		{ Id = "VehicleSpawnedSelected", Props = { Title = "Seraph", Sub = "Exotic", Tier = "S", Chip = "Spawned", Height = 120, State = "Selected", OnActivated = nothing } },
		{ Id = "ChipCyan", Props = { Title = "Kestrel", Sub = "Piercer", Tier = "C", Chip = "New", ChipKind = "Cyan", OnActivated = nothing } },
		{ Id = "ChipPrize", Props = { Title = "Showroom loop", Sub = "Platinum prize", Chip = "$25,000", ChipKind = "Yellow", OnActivated = nothing } },
		{ Id = "LiveOrder", Props = { Columns = { "1", "Neonrider", "-1.8" }, Height = 56, OnActivated = nothing } },
		{ Id = "LiveOrderYou", Props = { Columns = { "2", "You", "Seraph" }, Height = 56, State = "Selected", Accent = true, OnActivated = nothing } },
		{ Id = "ResultsColumns", Props = { Columns = { "3", "Cyberwave", "Aurora", "01:03.275", "+0.612" }, Height = 56, OnActivated = nothing } },
		{ Id = "AccentOnSlate", Props = { Columns = { "14", "You", "01:08.000" }, Height = 56, Accent = true, OnActivated = nothing } },
		{ Id = "EmptyImageId", Props = { Title = "Showroom loop", Sub = "Time trial \u{00B7} 17 checkpoints", Image = "", Right = "$25,000", OnActivated = nothing } },
		{ Id = "LongestStrings", Props = { Title = "Shifted canal sprint reverse", Sub = "Time trial \u{00B7} 3 laps \u{00B7} 17 checkpoints", Tier = "A", Chip = "Spawned", Right = "01:03.275", OnActivated = nothing } },
		{ Id = "LockedSelected", Props = { Title = "Endura", Sub = "Tier C only", Tier = "B", Locked = true, State = "Selected", OnActivated = nothing } },
		{ Id = "TierRight", Props = { Title = "Endura", Sub = "660  Exotic", Tier = "B", TierSide = "Right", OnActivated = nothing } },
		{ Id = "TierRightChipSelected", Props = { Title = "Seraph", Sub = "939  Exotic", Tier = "S", TierSide = "Right", Chip = "Current", ChipKind = "Cyan", State = "Selected", OnActivated = nothing } },
	},
}

local STANDINGS = {
	{ Key = "neon", Columns = { "1", "Neonrider", "Rosso", "02:58.104" } },
	{ Key = "you", Columns = { "2", "You", "Seraph", "+1.812" }, Accent = true },
	{ Key = "cyber", Columns = { "3", "Cyberwave", "Aurora", "+2.404" } },
	{ Key = "late", Columns = { "4", "Latebraker", "Endura", "+6.930" } },
	{ Key = "drift", Columns = { "5", "Driftqueen_2014", "Zephyr", "+9.118" } },
	{ Key = "dnf", Columns = { "6", "Slipstream", "Stinger", "DNF" }, Locked = true },
}
local GARAGE = {
	{ Key = "buy_more", Title = "Buy more", Sub = "Dealership" },
	{ Key = "seraph", Title = "Seraph", Sub = "Exotic", Tier = "S", Chip = "Spawned" },
	{ Key = "endura", Title = "Endura", Sub = "Exotic", Tier = "B", Right = "Parked" },
	{ Key = "aurora", Title = "Aurora", Sub = "Exotic", Tier = "C", Right = "Parked" },
	{ Key = "kestrel", Title = "Kestrel", Sub = "Piercer", Tier = "C", Right = "Parked" },
	{ Key = "zephyr", Title = "Zephyr", Sub = "Exotic", Tier = "D", Right = "Parked" },
	{ Key = "stinger", Title = "Stinger", Sub = "Exotic", Tier = "E", Right = "In garage", Locked = true },
}

local listItem = {
	Id = "Collections.List",
	Frame = "Bare",
	Slot = nil,
	Mount = mountList,
	States = {
		{ Id = "Results", Props = { Width = 900, RowHeight = 56, Header = { "Pos", "Driver", "Vehicle", "Time" }, Items = STANDINGS, Select = "you", OnSelected = nothing } },
		{ Id = "ResultsNoHeader", Props = { Width = 900, RowHeight = 56, Items = STANDINGS, OnSelected = nothing } },
		{ Id = "MyVehicles", Props = { Width = 536, RowHeight = 120, Items = GARAGE, Select = "seraph", OnSelected = nothing } },
		{ Id = "DefaultWidth", Props = { Items = GARAGE, Select = "aurora", OnSelected = nothing } },
		{ Id = "Empty", Props = { Width = 900, Header = { "Pos", "Driver", "Vehicle", "Time" }, Items = {}, OnSelected = nothing } },
	},
}

local chipItem = {
	Id = "Collections.Chip",
	Frame = "Bare",
	Slot = nil,
	Mount = mounter(Collections.Chip),
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
	Mount = mounter(Collections.TierBadge),
	States = {
		{ Id = "E", Props = { Tier = "E", Rating = 220 } },
		{ Id = "D", Props = { Tier = "D", Rating = 390 } },
		{ Id = "C", Props = { Tier = "C", Rating = 540 } },
		{ Id = "B", Props = { Tier = "B", Rating = 675 } },
		{ Id = "A", Props = { Tier = "A", Rating = 800 } },
		{ Id = "S", Props = { Tier = "S", Rating = 936 } },
		{ Id = "LetterOnly", Props = { Tier = "C" } },
		{ Id = "Medium", Props = { Tier = "D", Rating = 316, Size = "Medium" } },
		{ Id = "Small", Props = { Tier = "S", Rating = 936, Size = "Small" } },
		{ Id = "SmallLetterOnly", Props = { Tier = "S", Size = "Small" } },
		{ Id = "OnLight", Props = { Tier = "C", Rating = 540, OnLight = true } },
		{ Id = "Dim", Props = { Tier = "A", Rating = 800, Dim = true } },
		{ Id = "DimLetterOnly", Props = { Tier = "S", Size = "Small", Dim = true } },
	},
}

return { tileItem, railItem, railGridItem, listRowItem, listItem, chipItem, badgeItem }
