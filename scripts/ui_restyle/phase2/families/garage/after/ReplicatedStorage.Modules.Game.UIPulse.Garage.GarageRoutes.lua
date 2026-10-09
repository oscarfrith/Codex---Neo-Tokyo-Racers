-- Owns the garage navigation as data (tabs, page keys, Back steps, Shop and Owned sources, slot artwork rows, page text); it does not own state, remotes or any GuiObject.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.GarageRoutes. Requires: none.
--
-- Classic GarageUI drew a hub page with three cards and an "Owned Modules / Buy Modules" page. Pulse replaces the hub
-- with the three tabs below and the second page with a Shop / Owned switch (programme contract 8, API2 5.7). The
-- model still runs the Classic closures for every step; this table only says which closure a Pulse control runs.
local Routes = {}

-- Classic State.Stage values (GarageUI L44, L191, L199, L203, L311, L442, L620). Never renamed.
Routes.Stage = table.freeze({
	Closed = "Closed",
	Browser = "Browser",
	Paint = "Paint",
	Hub = "Hub",
	Build = "Build",
	Customise = "Customise",
})

-- Page ids the view switches on.
Routes.Page = table.freeze({
	Closed = "Closed",
	Dealership = "Dealership", -- Stage Browser (ShopMode Dealership or Customisation)
	PostPaint = "PostPaint", -- Stage Paint (after a purchase)
	Parts = "Parts", -- Stage Build
	Upgrades = "Upgrades", -- Stage Customise, CustomizeMode Upgrades
	Paint = "Paint", -- Stage Customise, CustomizeMode Colour or Overview
})

-- The three tabs. Workshop is the Classic workshop rail key (GarageUI L303-305, the same closures as the hub cards
-- L214-216). Card and PageMark are Kit.Contracts.Marks keys; TutorialPageId is the saved onboarding page id.
Routes.Tabs = table.freeze({
	table.freeze({ Id = "Parts", Text = "Parts", Icon = "customise", Workshop = "Add", Page = "Parts",
		Card = "Card.AddModules", PageMark = "Page.AddModules", TutorialPageId = "AddModules", ClassicLine = 303 }),
	table.freeze({ Id = "Upgrades", Text = "Upgrades", Icon = "upgrade", Workshop = "Upgrade", Page = "Upgrades",
		Card = "Card.UpgradeModules", PageMark = "Page.UpgradeModules", TutorialPageId = "UpgradeModules", ClassicLine = 304 }),
	table.freeze({ Id = "Paint", Text = "Paint", Icon = "paint", Workshop = "Paint", Page = "Paint",
		Card = "Card.PaintShop", PageMark = "Page.PaintShop", TutorialPageId = "PaintShop", ClassicLine = 305 }),
})

-- The tab bar stands for the Classic hub page (TutorialPageId CustomisationHome, GarageUI L205).
Routes.HomeMark = "Page.CustomisationHome"
-- Where Classic drew the hub (renderHub, L201-220) Pulse opens this tab.
Routes.HubTab = "Parts"

-- Classic ModuleOptionMode values (GarageUI L343, L344) behind the Shop / Owned switch, in display order.
Routes.Sources = table.freeze({
	table.freeze({ Id = "Buy", Text = "Shop", ClassicLine = 344 }),
	table.freeze({ Id = "Owned", Text = "Owned", ClassicLine = 343 }),
})
-- Which source the skipped "Owned Modules / Buy Modules" page resolves to. "OwnedIfAny" means Owned when the slot
-- has a compatible owned module (the Classic card read EQUIP TO UNLOCK in that case, L285), else Buy.
Routes.SourceDefault = table.freeze({ Slot = "Buy", Detour = "OwnedIfAny" })

-- Paint targets that are not module slots (GarageUI L535-538, L622, L664).
Routes.PaintAreas = table.freeze({ ALL = true, Cockpit = true, THRUST_COLOR = true, UNDERGLOW = true })

-- Back, per page key, as the ordered Classic steps it runs:
--   OptionsToSources  L364-368   SourcesBack  L369-370 (returns from the empty-slot detour, else the slot list)
--   Hub               L372-373, L477, L664, L666-667 (buildPreview, renderHub: Pulse opens HubTab)
--   PaintOverview     L664 (a slot target in Colour mode goes back to its Overview cards)
-- Available = false: the step lands on the page the player is already on (Classic's hub had no Back, L209).
Routes.Back = table.freeze({
	["Parts.Slots"] = table.freeze({ Steps = table.freeze({ "Hub" }), Available = false }),
	["Parts.Sources"] = table.freeze({ Steps = table.freeze({ "SourcesBack" }), Available = true }),
	["Parts.Options"] = table.freeze({ Steps = table.freeze({ "OptionsToSources", "SourcesBack" }), Available = true }),
	["Upgrades"] = table.freeze({ Steps = table.freeze({ "Hub" }), Available = true }),
	["Paint.Overview"] = table.freeze({ Steps = table.freeze({ "Hub" }), Available = true }),
	["Paint.Colour.Area"] = table.freeze({ Steps = table.freeze({ "Hub" }), Available = true }),
	["Paint.Colour.Slot"] = table.freeze({ Steps = table.freeze({ "PaintOverview" }), Available = true }),
})

-- Pure. The page key of a Classic state, or nil when no Back applies (Closed, Browser, post-purchase paint, Hub).
function Routes.PageKey(state: any, paintTarget: string?): string?
	local stage = state.Stage
	if stage == "Build" then
		return "Parts." .. tostring(state.ModuleMode)
	elseif stage == "Customise" then
		if state.CustomizeMode == "Upgrades" then
			return "Upgrades"
		elseif state.CustomizeMode == "Colour" then
			local target = paintTarget or state.CustomizeTarget or "ALL"
			return Routes.PaintAreas[target] and "Paint.Colour.Area" or "Paint.Colour.Slot"
		end
		return "Paint.Overview"
	end
	return nil
end

-- Pure. The tab record a Classic state shows as selected, or nil.
function Routes.TabFor(state: any): any
	local wanted = nil
	if state.Stage == "Build" then
		wanted = "Parts"
	elseif state.Stage == "Customise" then
		wanted = state.CustomizeMode == "Upgrades" and "Upgrades" or "Paint"
	end
	for _, tab in ipairs(Routes.Tabs) do
		if tab.Id == wanted then
			return tab
		end
	end
	return nil
end

function Routes.Tab(id: string): any
	for _, tab in ipairs(Routes.Tabs) do
		if tab.Id == id then
			return tab
		end
	end
	return nil
end

-- Pure. The page id for a Classic state.
function Routes.PageFor(state: any): string
	local stage = state.Stage
	if stage == "Browser" then
		return "Dealership"
	elseif stage == "Paint" then
		return "PostPaint"
	end
	local tab = Routes.TabFor(state)
	return tab and tab.Page or "Closed"
end

-- Slot and paint-target rows. Copied from GarageWorkspaceUI L11-25 (the fallback table its ArtworkDefinitions uses
-- when a Config.UI.GarageReplacement.ModuleArtwork folder is missing); the config folders override every field.
Routes.Artwork = table.freeze({
	table.freeze({ Name = "All", DisplayName = "All", TargetId = "ALL", SortOrder = 10, ShowInBuild = false, ShowInCustomise = true }),
	table.freeze({ Name = "Cockpit", DisplayName = "Cockpit", TargetId = "Cockpit", SortOrder = 20, ShowInBuild = false, ShowInCustomise = true }),
	table.freeze({ Name = "ThrustColour", DisplayName = "Thrust Colour", TargetId = "THRUST_COLOR", SortOrder = 30, ShowInBuild = false, ShowInCustomise = true }),
	table.freeze({ Name = "FrontEngine", DisplayName = "Front Engine", TargetId = "Engine1", SortOrder = 40, ShowInBuild = true, ShowInCustomise = true }),
	table.freeze({ Name = "RearEngine", DisplayName = "Rear Engine", TargetId = "Engine2", SortOrder = 50, ShowInBuild = true, ShowInCustomise = true }),
	table.freeze({ Name = "Stabilisers", DisplayName = "Stabilisers", TargetId = "Stabilisers", SortOrder = 60, ShowInBuild = true, ShowInCustomise = true }),
	table.freeze({ Name = "Boost", DisplayName = "Boost", TargetId = "Boost", SortOrder = 70, ShowInBuild = true, ShowInCustomise = true }),
	table.freeze({ Name = "FrontBody", DisplayName = "Front Body", TargetId = "FrontBody", SortOrder = 72, ShowInBuild = true, ShowInCustomise = true }),
	table.freeze({ Name = "RearBody", DisplayName = "Rear Body", TargetId = "RearBody", SortOrder = 74, ShowInBuild = true, ShowInCustomise = true }),
	table.freeze({ Name = "FrontBumper", DisplayName = "Front Bumper", TargetId = "FrontBumper", SortOrder = 80, ShowInBuild = true, ShowInCustomise = true }),
	table.freeze({ Name = "RearBumper", DisplayName = "Rear Bumper", TargetId = "RearBumper", SortOrder = 90, ShowInBuild = true, ShowInCustomise = true }),
	table.freeze({ Name = "SidePods", DisplayName = "Side Pods", TargetId = "SidePods", SortOrder = 100, ShowInBuild = true, ShowInCustomise = true }),
	table.freeze({ Name = "Spoiler", DisplayName = "Spoiler", TargetId = "RearSpoiler", SortOrder = 110, ShowInBuild = true, ShowInCustomise = true }),
})

-- Pure apart from attribute reads on the folders it is given. GarageWorkspaceUI L27-32 (Artwork.ForPage).
-- artworkRoot is Config.UI.GarageReplacement.ModuleArtwork, or nil.
function Routes.ArtworkForPage(artworkRoot: any, page: string, categoryId: any): { any }
	local result = {}
	for _, definition in ipairs(Routes.Artwork) do
		local folder = artworkRoot and artworkRoot:FindFirstChild(definition.Name)
		local function flag(name: string, fallback: boolean): boolean
			if not folder then
				return fallback
			end
			local value = folder:GetAttribute(name)
			if value == nil then
				return fallback
			end
			return value == true
		end
		local categoryImage = nil
		if folder and categoryId ~= nil then
			local value = folder:GetAttribute("Image_" .. tostring(categoryId))
			if value ~= nil and value ~= "" then
				categoryImage = value
			end
		end
		local item = {
			Name = definition.Name,
			DisplayName = tostring(folder and folder:GetAttribute("DisplayName") or definition.DisplayName),
			TargetId = tostring(folder and folder:GetAttribute("TargetId") or definition.TargetId),
			SortOrder = tonumber(folder and folder:GetAttribute("SortOrder")) or definition.SortOrder,
			ShowInBuild = flag("ShowInBuild", definition.ShowInBuild),
			ShowInCustomise = flag("ShowInCustomise", definition.ShowInCustomise),
			Image = tostring(categoryImage or (folder and folder:GetAttribute("Image")) or ""),
			Hidden = folder ~= nil and categoryId ~= nil and folder:GetAttribute("Hidden_" .. tostring(categoryId)) == true,
		}
		if not item.Hidden and ((page == "Build" and item.ShowInBuild) or (page == "Customise" and item.ShowInCustomise)) then
			table.insert(result, item)
		end
	end
	table.sort(result, function(a, b)
		return a.SortOrder < b.SortOrder
	end)
	return result
end

-- Player-facing text. Copied from the Classic source at the cited GarageUI or GarageBrowserUI line unless marked
-- Pulse (a preview frame changed it; each of those is listed under "added" in contract_a.json).
Routes.Text = table.freeze({
	DealershipTitle = "DEALERSHIP", -- GarageBrowserUI L114 (applied through the Text.Dealership mark)
	CustomisationTitle = "CUSTOMISATION", -- GarageBrowserUI L114
	DealershipSub = "Choose a vehicle category, then pick a cockpit.", -- GarageBrowserUI L114
	CustomisationSub = "Choose one of your owned cockpits to customise.", -- GarageBrowserUI L114
	CustomiseTitle = "Customise", -- Pulse (previews r02, r03): one title for the three tabs
	PostPaintTitle = "Paint Vehicle", -- L199
	PostPaintSub = "Choose a whole-vehicle colour, then continue to your garage.", -- L199
	PartsSlotsSub = "Choose a fixed module slot.", -- L316
	PartsOptionsSub = "Preview, then buy or equip.", -- L316
	UpgradesSub = "Choose an installed module location, then invest its upgrade points.", -- L455
	PaintColourSub = "Choose a paint channel and colour.", -- L630
	PaintOverviewSub = "Choose a vehicle area to paint or light.", -- L630
	PartsHeading = "Parts", -- Pulse (preview c12)
	AllCategories = "ALL", -- GarageBrowserUI L115
	Exit = "Exit", -- GarageBrowserUI L39
	Back = "Back", -- GarageWorkspaceUI L172
	Drive = "Drive", -- L210
	Customise = "Customise", -- L199 (button), GarageBrowserUI L122
	Buy = "Buy", -- GarageBrowserUI L122, L358, L557, L589
	BuyAnother = "Buy another", -- GarageBrowserUI L122
	Equip = "Equip", -- L352
	Upgrade = "Upgrade", -- L437
	Equipped = "EQUIPPED", -- L337
	Empty = "EMPTY", -- Pulse (preview c12)
	InUse = "IN USE", -- Pulse (preview r03); the Classic "IN USE BY <vehicle>" line stays as the tile sub-line
	Owned = "OWNED", -- L585
	Level = "LEVEL ", -- L437
	MaxLevel = "MAX LEVEL", -- L434
	LimitReached = "LIMIT REACHED", -- L434
	EquipToUnlock = "EQUIP TO UNLOCK", -- L285
	BuyToUnlock = "BUY TO UNLOCK", -- L285
	Paint = "Paint", -- L568
	NeonLights = "Neon Lights", -- L576, L584
	NeonUnavailable = "NOT AVAILABLE FOR THIS MODULE", -- L576
	CosmeticUnavailable = "NOT AVAILABLE FOR THIS VEHICLE", -- L555
	UpgradeDataMissing = "UPGRADE DATA UNAVAILABLE FOR THIS MODULE", -- L408
	UpgradePoints = "Upgrade Points", -- L406
	Used = " USED", -- GarageWorkspaceUI L234
	Thrust = "Thrust", -- L546
	Underglow = "Underglow", -- L548
	ModulePicker = "Module", -- Pulse: label of the slot picker that replaces the left card rail
	AreaPicker = "Area", -- Pulse (mockup 06): label of the paint target picker
	Performance = "PERFORMANCE", -- GarageComponents L212
	NoPerformance = "NO PERFORMANCE DATA", -- GarageComponents L209
	NoVehicles = "NO VEHICLES AVAILABLE", -- GarageBrowserUI L74
	DriveBlocked = "Equip one engine, stabilisers, and boost before driving.", -- L180
	ModuleBought = "Module purchased and equipped.", -- L358
	ColourNotSaved = "Colour could not be saved.", -- L123
	PurchaseFailed = "Purchase could not be completed.", -- L559
	SelectFailed = "Could not select vehicle.", -- L194
	LeaveGarageFailed = "Could not leave garage.", -- L195
	LeaveCustomisationFailed = "Could not leave customisation.", -- L184
	SpawnFailed = "Vehicle spawn failed", -- L186
	Busy = "Please wait.", -- L23
	NoReply = "Garage server did not respond.", -- L25
	SessionNoReply = "Garage session did not respond.", -- L36
	AccessUnavailable = "Customisation access is unavailable.", -- L680
	DataUnavailable = "Garage data unavailable", -- L689
	OwnVehicleReason = "OWN A VEHICLE TO CUSTOMISE", -- L683 (compared with the server's reply, never shown by us)
	MoveTitle = "MOVE EQUIPPED MODULE", -- L164
	MoveBodyA = "Equipping this module will remove it from ", -- L165
	MoveBodyB = ". Would you like to continue?", -- L165
	No = "NO", -- L166
	Yes = "YES", -- L167
	CashTitle = "GET MORE CASH", -- L171
	CashBody = "Cash packs are not configured yet.", -- L171
	PropertiesTitle = "GARAGE PROPERTIES", -- L173
	AnotherVehicle = "ANOTHER VEHICLE", -- L250
	BuyVehicleTitleA = "BUY ", -- Pulse (preview c15)
	BuyVehicleTitleB = "?", -- Pulse (preview c15)
	Price = "PRICE", -- Pulse (preview c15)
	Cancel = "CANCEL", -- Pulse (preview c15)
	Spaces = " Spaces", -- L178
})

-- Loading transition texts and destinations (GarageUI L50-51, L181-195, L675, L689, L693). Never changed.
Routes.Loading = table.freeze({
	DestinationDealership = "Dealership",
	DestinationDriveIn = "DriveInCustomisation",
	DestinationCustomisation = "Customisation",
	StatusEnteringDealership = "ENTERING DEALERSHIP",
	StatusEnteringCustomisation = "ENTERING CUSTOMISATION",
	DestinationDrive = "FreeRoamDrive",
	StatusPreparing = "PREPARING VEHICLE",
	StatusReturning = "RETURNING",
	StatusReadyToDrive = "READY TO DRIVE",
	DestinationExit = "DealershipExterior",
	StatusLeaving = "LEAVING GARAGE",
	StatusReady = "READY",
})

return Routes
