-- Owns the onboarding state machine (saved progress, pages, cards, objectives, locks, first drive, gates) and its two remote calls; owns no GuiObject, no target lookup and no world art.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Shell.OnboardingModel. Requires: none (everything arrives through deps).

-- Line numbers in comments are ReplicatedStorage.Modules.Game.UI.OnboardingClient (Classic), the source this is carried from.
local Model = {}
Model.__index = Model

-- 37-71. Player-facing copy, unchanged.
Model.Copy = table.freeze({
	G1 = "Vehicle categories group cars into families. Cars in the same category can share compatible modules.",
	G4 = "Tier shows the vehicle's performance class. Overall rating gives a quick summary of its total performance.",
	A2 = "You have limited vehicle space. Buy more garages to increase your capacity.",
	G2 = "Select a vehicle to preview it. Buy it to add it to your collection.",
	J1 = "Buy and equip modules in each vehicle slot. Modules can be swapped between vehicles in the same category.",
	J2 = "Upgrade the modules fitted to your vehicle. Each module has several upgrade paths and a limited point budget.",
	J3 = "Change your vehicle's paint and lighting per module. You can also customise thrust, neon and underglow.",
	K1 = "Choose a module location. Buy and swap modules from your different owned vehicles.",
	L1 = "Choose an equipped module to see its upgrades. Different modules offer different upgrade paths.",
	L2 = "Each module has a limited upgrade-point budget. Spending points on one upgrade leaves fewer for the others.",
	M1 = "Choose which part of the vehicle you want to customise. You can edit the whole vehicle, cockpit, effects or individual modules.",
	D7 = "Use the drift arrows while turning to slide around corners. Drifting helps with tighter turns.",
	D8 = "Hold Boost for a burst of speed. The boost meter shows how much energy remains.",
	B2 = "Open My Vehicles to spawn, switch or despawn your cars. New vehicles appear here after you buy them.",
	B4 = "Open the Race Browser to find events around the city. Events can support races, time trials or both.",
	N1 = "Select an event to view its route and details.",
	N6 = "Teleport to the selected event's starting area.",
	O1 = "Choose Race to compete against other players. Choose Time Trial to race against target times.",
	Q1 = "Choose a vehicle class for the time trial. Each class has separate target times, records and eligible vehicles.",
	Q5 = "This shows your selected class and the best available reward. Higher tiers have greater rewards.",
	Q8 = "Beat these target times to earn medals and cash. Faster times award higher medals.",
	Q4 = "Choose how many timed laps you want to run. Your best completed lap is used for the result.",
	P1 = "This shows the route, lap count and player limit. Multiplayer races use an open vehicle category.",
	B3 = "Open My Garages to view your owned properties. Each garage can display vehicles and has its own customisation.",
	X1 = "Choose one of your owned garage properties. Each card shows how many display spaces it contains.",
	X3 = "Enter the selected garage. You can manage its vehicles, assets and appearance from inside.",
	Z1 = "Choose which owned vehicles are displayed in your garage. Each vehicle is assigned to a physical display space.",
	Z2 = "Buy and equip different walls, floors, ceilings, decorations and lighting.",
	Z3 = "Customise the assets already equipped in your garage. Change their colours, materials and lighting.",
	AA1 = "Choose a display space to manage. Empty spaces can receive a vehicle, while occupied spaces can be changed.",
	AB1 = "Choose Structure, Decorations or Lighting. Build adds new assets; Style changes the look of equipped assets.",
	AC1 = "Choose which section of the garage you want to rebuild. The selected style is previewed in that location.",
	AD1 = "Choose where you want to place a decoration. Each location has its own compatible asset options.",
})

-- 72-78. Page ids are saved, server allow-listed state: never renamed.
Model.Pages = table.freeze({
	Dealership = table.freeze({ "G1", "G4", "A2", "G2" }),
	CustomisationHome = table.freeze({ "J1", "J2", "J3" }),
	AddModules = table.freeze({ "K1" }),
	UpgradeModules = table.freeze({ "L1", "L2" }),
	PaintShop = table.freeze({ "M1" }),
	MobileDriving = table.freeze({ "D7", "D8" }),
	VehicleShortcut = table.freeze({ "B2" }),
	RaceShortcut = table.freeze({ "B4" }),
	RaceBrowser = table.freeze({ "N1", "N6" }),
	EventMode = table.freeze({ "O1" }),
	TimeTrialSetup = table.freeze({ "Q1", "Q5", "Q8", "Q4" }),
	RaceSetup = table.freeze({ "P1" }),
	GarageShortcut = table.freeze({ "B3" }),
	GarageBrowser = table.freeze({ "X1", "X3" }),
	GarageHome = table.freeze({ "Z1", "Z2", "Z3" }),
	DisplayCars = table.freeze({ "AA1" }),
	GarageAssetFamilies = table.freeze({ "AB1" }),
	BuildStructure = table.freeze({ "AC1" }),
	BuildDecorations = table.freeze({ "AD1" }),
})
-- 79-80.
Model.ActionSteps = table.freeze({ N6 = true, X3 = true })
-- Pulse: a card whose target can sit on another sub-page of the same screen than the page root. The Compact race
-- menu shows TeleportToStart on its detail page, where the list (the RaceBrowser root, CardContent) is hidden. While
-- such a card's own target shows, the page is not treated as closed.
Model.OffRoot = table.freeze({ N6 = true })
Model.Placement = table.freeze({
	B2 = "Below", B3 = "Below", B4 = "Below", G4 = "Left", O1 = "Below", L2 = "Above",
	Z1 = "Above", Z2 = "Above", Z3 = "Above", AA1 = "Above", AB1 = "Above",
})
-- 223.
Model.PageOrder = table.freeze({
	"Dealership", "CustomisationHome", "AddModules", "UpgradeModules", "PaintShop", "MobileDriving", "VehicleShortcut",
	"GarageShortcut", "GarageBrowser", "GarageHome", "DisplayCars", "GarageAssetFamilies", "BuildStructure",
	"BuildDecorations", "RaceShortcut", "RaceBrowser", "EventMode", "TimeTrialSetup", "RaceSetup",
})
-- The one page id that is not a callout page (695-697); it is saved and allow-listed like the other 19.
Model.FirstDrivePage = "PCDriving"

-- 189-201. Helper and Literals are the Classic resolver call (checked against classic/contracts/_onboarding_targets.json);
-- Kind and Keys are how the Pulse target finder reads the same thing from Kit.Input marks.
--   Group         first showing instance per key                 (Classic group / named)
--   Cards         every showing button per key                   (Classic cardGroup)
--   ScrollerCards showing tutorial cards inside the Scroller key (Classic visibleScrollerCards)
--   Text          the button that carries each text mark         (Classic textGroup)
local function target(helper, kind, literals, keys, extra)
	local entry = { Helper = helper, Kind = kind, Literals = table.freeze(literals), Keys = table.freeze(keys) }
	for name, value in pairs(extra or {}) do
		entry[name] = value
	end
	return table.freeze(entry)
end
local function group(...)
	return target("group", "Group", { ... }, { ... })
end
local function cards(...)
	local keys = {}
	for index, id in ipairs({ ... }) do
		keys[index] = "Card." .. id
	end
	return target("cardGroup", "Cards", { ... }, keys)
end
local function scrollerCards(scroller)
	return target("visibleScrollerCards", "ScrollerCards", { scroller }, { "Card" }, { Scroller = scroller })
end

Model.Targets = table.freeze({
	G1 = group("Categories"), G4 = group("Stats"), A2 = group("Capacity"), G2 = scrollerCards("VehicleScroller"),
	J1 = cards("AddModules"), J2 = cards("UpgradeModules"), J3 = cards("PaintShop"),
	K1 = scrollerCards("TutorialCardScroller"), L1 = group("Categories"), L2 = group("UpgradeBudget"), M1 = group("Categories"),
	D7 = group("DriftLeft", "DriftRight", "DriftLeftButton", "DriftRightButton"), D8 = group("Boost", "BoostButton"),
	B2 = group("Car"), B3 = group("Garage"), B4 = group("Race"),
	N1 = group("CardContent"), N6 = group("TeleportToStart"),
	O1 = target("textGroup", "Text", { "TIME TRIAL", "RACE" }, { "Text.TimeTrial", "Text.Race" }),
	Q1 = group("TierE", "TierD", "TierC", "TierB", "TierA", "TierS"), Q5 = group("PrizeSummary"),
	Q8 = group("MedalTargets"), Q4 = group("LapSelector"),
	-- 197: group(root,"RaceFormat") or group(root,"DetailColumn").
	P1 = target("group", "Group", { "RaceFormat", "DetailColumn" }, { "RaceFormat" }, { Fallback = table.freeze({ "DetailColumn" }) }),
	X1 = group("GarageList"), X3 = group("Enter"),
	Z1 = cards("DisplayCars"), Z2 = cards("BuildGarage"), Z3 = cards("StyleGarage"),
	AA1 = scrollerCards("TutorialCardScroller"), AB1 = cards("Structure", "Decorations", "Lighting"),
	AC1 = group("Categories"), AD1 = group("Categories"),
})

-- 202-222. Literals are the string literals of the Classic page signal (same contract file). All: every key must have a
-- showing instance; Any: one of them. Gate is the state rule Classic tests before it looks.
-- Three Classic signals look for a ScreenGui by name or by a walk (Dealership, RaceBrowser, GarageBrowser); a ScreenGui
-- cannot carry a mark, so Pulse reads the mark the owning family puts on that screen (API2 5.2, 5.7).
local function signal(literals, spec)
	spec.Literals = table.freeze(literals)
	if spec.All then table.freeze(spec.All) end
	if spec.Any then table.freeze(spec.Any) end
	return table.freeze(spec)
end
local function workspacePage(pageId)
	return signal({ pageId }, { All = { "Page." .. pageId } })
end
Model.PageSignals = table.freeze({
	Dealership = signal({}, { All = { "Text.Dealership" } }),
	CustomisationHome = workspacePage("CustomisationHome"),
	AddModules = workspacePage("AddModules"),
	UpgradeModules = workspacePage("UpgradeModules"),
	PaintShop = workspacePage("PaintShop"),
	MobileDriving = signal({ "DriftLeft", "DriftLeftButton" }, { Any = { "DriftLeft", "DriftLeftButton" }, Gate = "Touch" }),
	VehicleShortcut = signal({ "Car" }, { All = { "Car" }, Gate = "Stage2" }),
	RaceShortcut = signal({ "Race" }, { All = { "Race" }, Gate = "SeenGarageShortcut" }),
	RaceBrowser = signal({ "RaceBrowser" }, { All = { "CardContent" } }),
	EventMode = signal({ "RaceEntryPresentation", "TIME TRIAL", "RACE" }, { All = { "Text.TimeTrial", "Text.Race" } }),
	TimeTrialSetup = signal({ "TierE", "LapSelector" }, { All = { "TierE", "LapSelector" } }),
	RaceSetup = signal({ "RaceFormat" }, { All = { "RaceFormat" } }),
	GarageShortcut = signal({ "Garage" }, { All = { "Garage" }, Gate = "SeenVehicleShortcut" }),
	GarageBrowser = signal({ "OwnedGarageBrowser" }, { All = { "GarageList" } }),
	GarageHome = workspacePage("GarageHome"),
	DisplayCars = workspacePage("DisplayCars"),
	GarageAssetFamilies = workspacePage("GarageAssetFamilies"),
	BuildStructure = workspacePage("BuildStructure"),
	BuildDecorations = workspacePage("BuildDecorations"),
})

-- 479-483.
Model.ObjectiveContent = table.freeze({
	table.freeze({ Title = "BUY AND CUSTOMISE A CAR" }),
	table.freeze({ Title = "EXPLORE YOUR GARAGE", Hint = "Enter your garage and open customisation." }),
	table.freeze({ Title = "ENTER AN EVENT", Hint = "Join a race or start a time trial." }),
})
-- 667: the three HUD shortcut buttons and the page that unlocks each.
Model.LockPages = table.freeze({ Car = "VehicleShortcut", Race = "RaceShortcut", Garage = "GarageShortcut" })

local ADVANCE_DEBOUNCE = 0.18 -- 442
local RESOLVE_DELAY = 0.08 -- 411
local RESOLVE_DELAY_MAX = 0.64 -- Pulse: the retry backs off instead of running at 0.08 s for as long as a target is missing
local GET_STATE_ATTEMPTS = 60 -- 748
local TARGET_GIVE_UP_SECONDS = 10 -- Pulse: a target missing this long on an open page releases the HUD shortcut locks
local FIRST_DRIVE_WATCHDOG_SECONDS = 3 -- Pulse: the controls modal must have opened by then, or the pending flag is cleared
local SHORTCUT_PAGES = table.freeze({ VehicleShortcut = true, RaceShortcut = true, GarageShortcut = true }) -- 643

local function newSignal()
	local handlers = {}
	local signalObject = {}
	function signalObject.Connect(_, handler)
		local connection = { Connected = true }
		handlers[connection] = handler
		function connection.Disconnect()
			connection.Connected = false
			handlers[connection] = nil
		end
		connection.disconnect = connection.Disconnect
		return connection
	end
	function signalObject.Fire(_, ...)
		for connection, handler in pairs(table.clone(handlers)) do
			if connection.Connected then
				handler(...)
			end
		end
	end
	return signalObject
end

-- The one remote call site. OnboardingInvoke: ("GetState", {}) and ("MarkSeen", {PageId = pageId}).
local function call(remote, action, payload)
	return remote:InvokeServer(action, payload)
end

-- deps:
--   Remotes   = {OnboardingInvoke}                       RemoteFunction (InvokeServer)
--   Bindables = {OpenDrivingControls = () -> BindableEvent?}   looked up at use, as Classic 686
--   Player, PlayerGui, LoadingState, Config              objects answering GetAttribute (Player also SetAttribute)
--   Presence  = Kit.Presence                             Any()
--   Audio     = PresentationAudioBridge                  Emit(cue, payload)
--   Targets   = {Page = (pageId, spec) -> root?, Card = (cardId, spec, root) -> {object}?, Alive = (root) -> boolean}
--   TouchEnabled = () -> boolean, ActivelyDriving = () -> {RaceDriving: boolean}?
--   Clock, Spawn, Defer, Delay, Wait, Print, Warn        os.clock, task.spawn, task.defer, task.delay, task.wait, print, warn
function Model.new(deps)
	assert(type(deps) == "table", "OnboardingModel.new: deps required")
	local self = setmetatable({}, Model)
	self._deps = deps
	self.State = { Stage = 1, SeenPages = {}, Completed = {} } -- 26
	self.Ready = false -- 27
	self.GateOpen = false
	self.ActivePage = nil
	self.ActiveIndex = nil
	self.ActiveRoot = nil
	self.ActiveObjects = nil
	self.Changed = newSignal()
	self._owners = {} -- 30
	self._resolveGeneration = 0
	self._gateGeneration = 0
	self._resolveDelay = RESOLVE_DELAY
	self._rootMissingAt = nil
	self._targetMissingAt = nil
	self._warnedMissingTarget = false
	-- Pulse: pages completed here whose MarkSeen reply has not arrived. A state that arrives meanwhile (another reply,
	-- OnboardingStateChanged) keeps them seen, so a page never begins twice and a shortcut never locks again.
	self._pendingSeen = {}
	-- Pulse: true once a fallback released the Car, Race and Garage locks for this session (see _releaseLocks).
	self.LocksReleased = false
	self._lastAdvance = 0
	self._awaitClose = false -- 677
	self._spawnPending = false -- 678
	self._spawnDirect = false -- 679
	self._requestInFlight = false -- 680
	self._completion = nil -- 484
	return self
end

function Model:_fire(reason)
	self.Changed:Fire(reason)
end

function Model:_setting(name, fallback)
	local value = self._deps.Config:GetAttribute(name)
	if value == nil then
		return fallback
	end
	return value
end

-- 329-341 ------------------------------------------------------------------------------------------------
function Model:LoadingActive()
	local deps = self._deps
	return deps.Player:GetAttribute("StartScreenActive") == true or deps.LoadingState:GetAttribute("Active") == true
end

function Model:FullMapOpen()
	return self._deps.Player:GetAttribute("FullMapOpen") == true
end

function Model:Blocked()
	local player = self._deps.Player
	return self:LoadingActive()
		or self:FullMapOpen()
		or player:GetAttribute("FirstDrivePresentationPending") == true
		or player:GetAttribute("DrivingControlsOpen") == true
end

-- Getters for the view --------------------------------------------------------------------------------------
function Model:CardId()
	local page = self.ActivePage and Model.Pages[self.ActivePage]
	return page and page[self.ActiveIndex] or nil
end

function Model:IsAction()
	return Model.ActionSteps[self:CardId() or ""] == true
end

function Model:CalloutVisible()
	return self.GateOpen and self.ActivePage ~= nil and self.ActiveObjects ~= nil and not self:Blocked()
end

-- 465-478. The PlayerGui walks become Presence (every Pulse full screen, modal and side panel registers there);
-- the attributes and the presentation owners are read as Classic reads them.
function Model:MajorMenuOpen()
	for _, active in pairs(self._owners) do
		if active then
			return true
		end
	end
	local deps = self._deps
	if deps.Presence.Any() then
		return true
	end
	local player = deps.Player
	return deps.PlayerGui:GetAttribute("OwnedGarageManagementOpen") == true
		or (player:GetAttribute("GarageSessionActive") == true and player:GetAttribute("GarageSessionMode") ~= "Dealership")
		or player:GetAttribute("RaceSessionActive") == true
		or player:GetAttribute("MobileFreeRoamCarMenuOpen") == true
		or player:GetAttribute("MobileMajorMenuOpen") == true
		or player:GetAttribute("DrivingControlsOpen") == true
end

-- 486-504 ------------------------------------------------------------------------------------------------
function Model:ObjectiveComplete(index)
	local state = self.State
	if index == 1 then
		return state.Completed.FirstVehiclePurchased == true and state.Completed.FirstVehicleDriven == true
			and state.SeenPages.VehicleShortcut == true
	end
	if index == 2 then
		return state.Completed.GarageManagementEntered == true
	end
	return state.Completed.FirstEventEntered == true
end

function Model:ObjectiveDesired(index)
	if index == 1 then
		return not self:ObjectiveComplete(1)
	end
	if index == 2 then
		return self:ObjectiveComplete(1) and self.State.SeenPages.GarageShortcut == true and not self:ObjectiveComplete(2)
	end
	return self.State.SeenPages.RaceShortcut == true and not self:ObjectiveComplete(3)
end

function Model:ObjectiveHint(index)
	if index == 1 then
		return self.State.Completed.FirstVehiclePurchased == true and "Start driving your new vehicle."
			or "Follow the trail to the dealership."
	end
	return Model.ObjectiveContent[index].Hint
end

function Model:ObjectiveOrder()
	local result = {}
	for index = 1, 3 do
		if self:ObjectiveDesired(index) then
			table.insert(result, index)
		end
	end
	return result
end

-- 644.
function Model:ObjectivesVisible()
	return self.Ready and self.GateOpen and #self:ObjectiveOrder() > 0 and not self:Blocked() and not self:MajorMenuOpen()
		and (self.ActivePage == nil or SHORTCUT_PAGES[self.ActivePage] == true)
end

-- 597-611 without the card tweens: the completion sound and the snapshot it is judged against.
function Model:SyncObjectives()
	if not self.Ready then
		return
	end
	local nextCompletion = { self:ObjectiveComplete(1), self:ObjectiveComplete(2), self:ObjectiveComplete(3) }
	local previous = self._completion
	if previous then
		for index = 1, 3 do
			if previous[index] ~= true and nextCompletion[index] == true then
				self._deps.Audio.Emit("Objective.Complete", { Key = "Objective:" .. tostring(index), ObjectiveIndex = index })
			end
		end
	end
	self._completion = nextCompletion
	self:_fire("Objectives")
end

-- 667: Car, Race and Garage are usable once their shortcut page has been seen, or once a fallback released them.
function Model:Locks()
	local seen = self.State.SeenPages
	local result = {}
	for name, pageId in pairs(Model.LockPages) do
		result[name] = self.LocksReleased == true or seen[pageId] == true
	end
	return result
end

-- Pulse: the player is never left with dead HUD buttons. Called when the saved progress never arrived or when an open
-- page could not find its target. Warns once; the callouts still play when their pages show.
function Model:_releaseLocks(reason)
	if self.LocksReleased then
		return
	end
	self.LocksReleased = true
	self._deps.Warn("[Onboarding] HUD shortcuts unlocked without their callouts: " .. tostring(reason))
	self:_fire("State")
end

-- 657-665: which desk the world trail leads to. "Dealership", "GarageDesk" or nil (no trail).
function Model:Trail()
	if not self.Ready or self:Blocked() then
		return nil
	end
	local deps = self._deps
	if self.State.Completed.FirstVehiclePurchased ~= true then
		return "Dealership"
	end
	if deps.Player:GetAttribute("OwnedGarageInside") == true and self.State.Completed.GarageManagementEntered ~= true
		and deps.PlayerGui:GetAttribute("OwnedGarageManagementOpen") ~= true then
		return "GarageDesk"
	end
	return nil
end

-- True when nothing is left to teach: no unseen page, no objective and no trail. The client stops its re-checks then.
function Model:Finished()
	if not self.Ready or self.ActivePage ~= nil or self._spawnPending then
		return false
	end
	local seen = self.State.SeenPages
	for _, pageId in ipairs(Model.PageOrder) do
		if seen[pageId] ~= true and not (pageId == "MobileDriving" and not self._deps.TouchEnabled()) then
			return false
		end
	end
	if not self._deps.TouchEnabled() and seen[Model.FirstDrivePage] ~= true then
		return false
	end
	return #self:ObjectiveOrder() == 0 and self.State.Completed.FirstVehiclePurchased == true
		and self.State.Completed.GarageManagementEntered == true
end

-- 202-222: the state rule, then the lookup.
function Model:_signal(pageId)
	local spec = Model.PageSignals[pageId]
	local state = self.State
	local gate = spec.Gate
	if gate == "Touch" and not self._deps.TouchEnabled() then
		return nil
	elseif gate == "Stage2" and not ((tonumber(state.Stage) or 1) >= 2) then
		return nil
	elseif gate == "SeenGarageShortcut" and state.SeenPages.GarageShortcut ~= true then
		return nil
	elseif gate == "SeenVehicleShortcut" and state.SeenPages.VehicleShortcut ~= true then
		return nil
	end
	local ok, root = pcall(self._deps.Targets.Page, pageId, spec)
	if ok and root then
		return root
	end
	return nil
end

-- 390-408: the model only records the pinned objects; the view listens to them.
function Model:_pin(objects)
	self.ActiveObjects = objects
	self._rootMissingAt = nil
	self._targetMissingAt = nil
	self._warnedMissingTarget = false
	self._resolveDelay = RESOLVE_DELAY
	self:_fire("Callout")
end

-- 409-431.
function Model:_scheduleResolve()
	self._resolveGeneration += 1
	local generation = self._resolveGeneration
	self.ActiveObjects = nil
	self:_fire("Callout")
	local deps = self._deps
	local delay = self._resolveDelay
	deps.Delay(delay, function()
		if generation ~= self._resolveGeneration or self:Blocked() or not self.ActivePage then
			return
		end
		if not (self.ActiveRoot and deps.Targets.Alive(self.ActiveRoot)) then
			local newRoot = self:_signal(self.ActivePage)
			if newRoot then
				self.ActiveRoot = newRoot
				self._rootMissingAt = nil
			else
				local offRootId = Model.Pages[self.ActivePage][self.ActiveIndex]
				if Model.OffRoot[offRootId] then
					local okOffRoot, found = pcall(deps.Targets.Card, offRootId, Model.Targets[offRootId], nil)
					if okOffRoot and found then
						self:_pin(found)
						return
					end
				end
				self._rootMissingAt = self._rootMissingAt or deps.Clock()
				if deps.Clock() - self._rootMissingAt >= self:_setting("PageAbandonSeconds", 3) then
					deps.Print("[Tutorial] page closed before completion: " .. tostring(self.ActivePage))
					self.ActivePage = nil
					self.ActiveIndex = nil
					self.ActiveRoot = nil
					self._targetMissingAt = nil
					self._resolveGeneration += 1
					self._resolveDelay = RESOLVE_DELAY
					self:_fire("PageEnded")
				else
					self:_scheduleResolve()
				end
				return
			end
		end
		local id = Model.Pages[self.ActivePage][self.ActiveIndex]
		local ok, objects = pcall(deps.Targets.Card, id, Model.Targets[id], self.ActiveRoot)
		if ok and objects then
			self:_pin(objects)
		else
			if not self._warnedMissingTarget and self._rootMissingAt and deps.Clock() - self._rootMissingAt > 1 then
				self._warnedMissingTarget = true
				deps.Warn("[Tutorial] waiting for target " .. tostring(self.ActivePage) .. " " .. tostring(id))
			end
			self._rootMissingAt = self._rootMissingAt or deps.Clock()
			self._targetMissingAt = self._targetMissingAt or deps.Clock()
			if deps.Clock() - self._targetMissingAt >= self:_setting("TargetGiveUpSeconds", TARGET_GIVE_UP_SECONDS) then
				self:_releaseLocks("no target for " .. tostring(self.ActivePage) .. " " .. tostring(id))
			end
			self._resolveDelay = math.min(RESOLVE_DELAY_MAX, self._resolveDelay * 2)
			self:_scheduleResolve()
		end
	end)
end

-- 432-435.
function Model:_beginPage(pageId, root)
	self.ActivePage = pageId
	self.ActiveIndex = 1
	self.ActiveRoot = root
	self._rootMissingAt = nil
	self._targetMissingAt = nil
	self._resolveDelay = RESOLVE_DELAY
	self._deps.Print("[Tutorial] begin " .. pageId .. " " .. Model.Pages[pageId][1])
	self:_scheduleResolve()
end

-- 436-439. The reply is an untrusted shape: it replaces the state only when it carries the two tables the state needs.
function Model:_adopt(result)
	if type(result) == "table" and result.Success then
		if type(result.SeenPages) ~= "table" then
			result.SeenPages = {}
		end
		if type(result.Completed) ~= "table" then
			result.Completed = {}
		end
		for pageId in pairs(self._pendingSeen) do
			result.SeenPages[pageId] = true
		end
		self.State = result
		return true
	end
	return false
end

function Model:_markSeen(pageId)
	local remote = self._deps.Remotes.OnboardingInvoke
	local ok, result = pcall(call, remote, "MarkSeen", { PageId = pageId })
	if ok and type(result) == "table" and result.Success then
		-- The server has it now; a refused or failed call keeps the page seen for this session only.
		self._pendingSeen[pageId] = nil
	end
	if ok and self:_adopt(result) then
		self:_fire("State")
	end
end

-- 441-450.
function Model:Advance()
	local deps = self._deps
	if not self.ActivePage or deps.Clock() - self._lastAdvance < ADVANCE_DEBOUNCE then
		return
	end
	self._lastAdvance = deps.Clock()
	self.ActiveIndex += 1
	if self.ActiveIndex > #Model.Pages[self.ActivePage] then
		local done = self.ActivePage
		self.State.SeenPages[done] = true
		self._pendingSeen[done] = true
		self.ActivePage = nil
		self.ActiveIndex = nil
		self.ActiveRoot = nil
		self.ActiveObjects = nil
		self._targetMissingAt = nil
		self._resolveGeneration += 1
		self._resolveDelay = RESOLVE_DELAY
		self:_fire("Callout")
		deps.Print("[Tutorial] complete " .. done)
		deps.Defer(function()
			self:SyncObjectives()
			self:_fire("PageEnded")
		end)
		deps.Spawn(function()
			self:_markSeen(done)
		end)
	else
		deps.Print("[Tutorial] advance " .. self.ActivePage .. " " .. Model.Pages[self.ActivePage][self.ActiveIndex])
		self._targetMissingAt = nil
		self._resolveDelay = RESOLVE_DELAY
		self:_scheduleResolve()
	end
end

-- 396-397: a pinned object was hidden or moved in the tree.
function Model:TargetLost()
	if self.ActivePage then
		self._resolveDelay = RESOLVE_DELAY
		self:_scheduleResolve()
	end
end

-- 398-404: an action step (N6, X3) advances when the player presses the highlighted button itself.
function Model:ActionActivated()
	local expectedPage, expectedIndex, expectedId = self.ActivePage, self.ActiveIndex, self:CardId()
	if not (expectedId and Model.ActionSteps[expectedId]) then
		return
	end
	self._deps.Defer(function()
		if self.ActivePage == expectedPage and self.ActiveIndex == expectedIndex and self:CardId() == expectedId then
			self:Advance()
		end
	end)
end

-- 681-699.
function Model:_tryBeginFirstDriveControls(allowSpawnSignal)
	local deps = self._deps
	local state = self.State
	if deps.TouchEnabled() or not self.Ready or (tonumber(state.Stage) or 1) < 2
		or state.SeenPages[Model.FirstDrivePage] == true or self._requestInFlight then
		return false
	end
	local driven = deps.ActivelyDriving()
	local raceDriving = driven and driven.RaceDriving == true
	if raceDriving or (not driven and not allowSpawnSignal) then
		return false
	end
	local event = deps.Bindables.OpenDrivingControls()
	if not event then
		self._spawnPending = false
		deps.Player:SetAttribute("FirstDrivePresentationPending", false)
		return false
	end
	deps.Player:SetAttribute("FirstDrivePresentationPending", true)
	self._requestInFlight = true
	self._awaitClose = true
	state.SeenPages[Model.FirstDrivePage] = true
	self._pendingSeen[Model.FirstDrivePage] = true
	event:Fire({ FirstDrive = true })
	deps.Spawn(function()
		self:_markSeen(Model.FirstDrivePage)
	end)
	-- Pulse: FirstDrivePresentationPending blocks every page (and so every unlock) until the controls modal clears it.
	-- If no listener opened the modal, nothing ever would: clear the flag here and say so.
	deps.Delay(FIRST_DRIVE_WATCHDOG_SECONDS, function()
		local player = deps.Player
		if player:GetAttribute("FirstDrivePresentationPending") == true and player:GetAttribute("DrivingControlsOpen") ~= true then
			deps.Warn("[Onboarding] first-drive controls did not open; FirstDrivePresentationPending cleared")
			player:SetAttribute("FirstDrivePresentationPending", false)
		end
	end)
	return true
end

function Model:_trySpawnPending()
	if self._spawnPending and self:_tryBeginFirstDriveControls(self._spawnDirect) then
		self._spawnPending = false
		self._spawnDirect = false
		return true
	end
	return false
end

-- 700-712. Classic ran this five times a second; the client calls it when something may have changed.
function Model:Poll()
	if self:_trySpawnPending() then
		return
	end
	if not self.GateOpen or self:Blocked() then
		return
	end
	if self._awaitClose then
		self._awaitClose = false
		self._requestInFlight = false
	end
	if self.ActivePage then
		return
	end
	if self:_tryBeginFirstDriveControls(false) then
		return
	end
	-- Pulse: no page begins before the saved progress has arrived, so a returning player whose profile is still
	-- loading is never shown a new-player callout (Classic guarded the objectives and the trail this way, not the pages).
	if not self.Ready then
		return
	end
	local seen = self.State.SeenPages
	for _, pageId in ipairs(Model.PageOrder) do
		if seen[pageId] ~= true then
			local root = self:_signal(pageId)
			if root then
				self:_beginPage(pageId, root)
				return
			end
		end
	end
end

-- 714-719: the FreeRoamVehicleSpawned handler.
function Model:VehicleSpawned()
	local deps = self._deps
	if deps.TouchEnabled() or self.State.SeenPages[Model.FirstDrivePage] == true then
		return
	end
	self._spawnPending = true
	self._spawnDirect = self:LoadingActive() and tostring(deps.LoadingState:GetAttribute("Destination") or "") == "FreeRoamDrive"
	self:_trySpawnPending()
end

-- 720-724: GetState replies and OnboardingStateChanged.
function Model:Accept(newState)
	if self:_adopt(newState) then
		self.Ready = true
	end
	self:_trySpawnPending()
	self:SyncObjectives()
	self:_fire("State")
end

-- 727.
function Model:PresentationMode(payload)
	if type(payload) == "table" then
		self._owners[tostring(payload.Owner or "Unknown")] = payload.Active == true
		self:_fire("Objectives")
	end
end

-- 728-738. Classic waited two rendered frames before showing again; two zero-length timers stand in for them.
function Model:RefreshGate()
	self._gateGeneration += 1
	local generation = self._gateGeneration
	if self:LoadingActive() or self:FullMapOpen() then
		self.GateOpen = false
		self:_fire("Gate")
		return
	end
	local deps = self._deps
	deps.Delay(0, function()
		deps.Delay(0, function()
			if generation ~= self._gateGeneration or self:LoadingActive() or self:FullMapOpen() then
				return
			end
			self.GateOpen = true
			if self:Blocked() then
				self:_fire("Gate")
				return
			end
			if self.ActivePage then
				self._resolveDelay = RESOLVE_DELAY
				self:_scheduleResolve()
			else
				self:_fire("Gate")
				self:Poll()
			end
		end)
	end)
end

-- 745-755: GetState fails while the profile is still loading; retry until the saved progress arrives, so a returning
-- player is never shown the new-player guide. Never called from start() directly: the caller is not held.
function Model:Start()
	local deps = self._deps
	deps.Spawn(function()
		for attempt = 1, GET_STATE_ATTEMPTS do
			if self.Ready then
				return
			end
			local ok, result = pcall(call, deps.Remotes.OnboardingInvoke, "GetState", {})
			if ok then
				self:Accept(result)
			end
			if self.Ready then
				return
			end
			deps.Wait(math.min(5, 0.5 * attempt))
		end
		-- Pulse: Classic left Car, Race and Garage locked for the whole session here.
		if not self.Ready then
			self:_releaseLocks("saved progress did not arrive after " .. GET_STATE_ATTEMPTS .. " GetState attempts")
		end
	end)
end

return Model
