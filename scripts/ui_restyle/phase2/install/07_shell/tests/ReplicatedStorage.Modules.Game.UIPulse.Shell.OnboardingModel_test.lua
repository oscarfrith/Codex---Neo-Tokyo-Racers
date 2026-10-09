-- Pure tests for Shell.OnboardingModel: the page and stage state machine against sequences read from the Classic
-- source, with fake deps (no remote, no instance, no yield). EXPECTED is generated from
-- classic/contracts/_onboarding_targets.json by build_shell.py (the Studio harness cannot read the JSON).
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local function same(a, b)
		if #a ~= #b then return false end
		for index, value in ipairs(a) do
			if b[index] ~= value then return false end
		end
		return true
	end

	-- BEGIN GENERATED EXPECTED
	local EXPECTED = {
		PageOrder = { "Dealership", "CustomisationHome", "AddModules", "UpgradeModules", "PaintShop", "MobileDriving", "VehicleShortcut", "GarageShortcut", "GarageBrowser", "GarageHome", "DisplayCars", "GarageAssetFamilies", "BuildStructure", "BuildDecorations", "RaceShortcut", "RaceBrowser", "EventMode", "TimeTrialSetup", "RaceSetup" },
		Pages = {
			Dealership = { Cards = { "G1", "G4", "A2", "G2" }, Signal = {} },
			CustomisationHome = { Cards = { "J1", "J2", "J3" }, Signal = { "CustomisationHome" } },
			AddModules = { Cards = { "K1" }, Signal = { "AddModules" } },
			UpgradeModules = { Cards = { "L1", "L2" }, Signal = { "UpgradeModules" } },
			PaintShop = { Cards = { "M1" }, Signal = { "PaintShop" } },
			MobileDriving = { Cards = { "D7", "D8" }, Signal = { "DriftLeft", "DriftLeftButton" } },
			VehicleShortcut = { Cards = { "B2" }, Signal = { "Car" } },
			GarageShortcut = { Cards = { "B3" }, Signal = { "Garage" } },
			GarageBrowser = { Cards = { "X1", "X3" }, Signal = { "OwnedGarageBrowser" } },
			GarageHome = { Cards = { "Z1", "Z2", "Z3" }, Signal = { "GarageHome" } },
			DisplayCars = { Cards = { "AA1" }, Signal = { "DisplayCars" } },
			GarageAssetFamilies = { Cards = { "AB1" }, Signal = { "GarageAssetFamilies" } },
			BuildStructure = { Cards = { "AC1" }, Signal = { "BuildStructure" } },
			BuildDecorations = { Cards = { "AD1" }, Signal = { "BuildDecorations" } },
			RaceShortcut = { Cards = { "B4" }, Signal = { "Race" } },
			RaceBrowser = { Cards = { "N1", "N6" }, Signal = { "RaceBrowser" } },
			EventMode = { Cards = { "O1" }, Signal = { "RaceEntryPresentation", "TIME TRIAL", "RACE" } },
			TimeTrialSetup = { Cards = { "Q1", "Q5", "Q8", "Q4" }, Signal = { "TierE", "LapSelector" } },
			RaceSetup = { Cards = { "P1" }, Signal = { "RaceFormat" } },
		},
		Cards = {
			G1 = { Page = "Dealership", Helper = "group", Literals = { "Categories" }, Action = false, Placement = nil, Copy = "Vehicle categories group cars into families. Cars in the same category can share compatible modules." },
			G4 = { Page = "Dealership", Helper = "group", Literals = { "Stats" }, Action = false, Placement = "Left", Copy = "Tier shows the vehicle's performance class. Overall rating gives a quick summary of its total performance." },
			A2 = { Page = "Dealership", Helper = "group", Literals = { "Capacity" }, Action = false, Placement = nil, Copy = "You have limited vehicle space. Buy more garages to increase your capacity." },
			G2 = { Page = "Dealership", Helper = "visibleScrollerCards", Literals = { "VehicleScroller" }, Action = false, Placement = nil, Copy = "Select a vehicle to preview it. Buy it to add it to your collection." },
			J1 = { Page = "CustomisationHome", Helper = "cardGroup", Literals = { "AddModules" }, Action = false, Placement = nil, Copy = "Buy and equip modules in each vehicle slot. Modules can be swapped between vehicles in the same category." },
			J2 = { Page = "CustomisationHome", Helper = "cardGroup", Literals = { "UpgradeModules" }, Action = false, Placement = nil, Copy = "Upgrade the modules fitted to your vehicle. Each module has several upgrade paths and a limited point budget." },
			J3 = { Page = "CustomisationHome", Helper = "cardGroup", Literals = { "PaintShop" }, Action = false, Placement = nil, Copy = "Change your vehicle's paint and lighting per module. You can also customise thrust, neon and underglow." },
			K1 = { Page = "AddModules", Helper = "visibleScrollerCards", Literals = { "TutorialCardScroller" }, Action = false, Placement = nil, Copy = "Choose a module location. Buy and swap modules from your different owned vehicles." },
			L1 = { Page = "UpgradeModules", Helper = "group", Literals = { "Categories" }, Action = false, Placement = nil, Copy = "Choose an equipped module to see its upgrades. Different modules offer different upgrade paths." },
			L2 = { Page = "UpgradeModules", Helper = "group", Literals = { "UpgradeBudget" }, Action = false, Placement = "Above", Copy = "Each module has a limited upgrade-point budget. Spending points on one upgrade leaves fewer for the others." },
			M1 = { Page = "PaintShop", Helper = "group", Literals = { "Categories" }, Action = false, Placement = nil, Copy = "Choose which part of the vehicle you want to customise. You can edit the whole vehicle, cockpit, effects or individual modules." },
			D7 = { Page = "MobileDriving", Helper = "group", Literals = { "DriftLeft", "DriftRight", "DriftLeftButton", "DriftRightButton" }, Action = false, Placement = nil, Copy = "Use the drift arrows while turning to slide around corners. Drifting helps with tighter turns." },
			D8 = { Page = "MobileDriving", Helper = "group", Literals = { "Boost", "BoostButton" }, Action = false, Placement = nil, Copy = "Hold Boost for a burst of speed. The boost meter shows how much energy remains." },
			B2 = { Page = "VehicleShortcut", Helper = "group", Literals = { "Car" }, Action = false, Placement = "Below", Copy = "Open My Vehicles to spawn, switch or despawn your cars. New vehicles appear here after you buy them." },
			B4 = { Page = "RaceShortcut", Helper = "group", Literals = { "Race" }, Action = false, Placement = "Below", Copy = "Open the Race Browser to find events around the city. Events can support races, time trials or both." },
			N1 = { Page = "RaceBrowser", Helper = "group", Literals = { "CardContent" }, Action = false, Placement = nil, Copy = "Select an event to view its route and details." },
			N6 = { Page = "RaceBrowser", Helper = "group", Literals = { "TeleportToStart" }, Action = true, Placement = nil, Copy = "Teleport to the selected event's starting area." },
			O1 = { Page = "EventMode", Helper = "textGroup", Literals = { "TIME TRIAL", "RACE" }, Action = false, Placement = "Below", Copy = "Choose Race to compete against other players. Choose Time Trial to race against target times." },
			Q1 = { Page = "TimeTrialSetup", Helper = "group", Literals = { "TierE", "TierD", "TierC", "TierB", "TierA", "TierS" }, Action = false, Placement = nil, Copy = "Choose a vehicle class for the time trial. Each class has separate target times, records and eligible vehicles." },
			Q5 = { Page = "TimeTrialSetup", Helper = "group", Literals = { "PrizeSummary" }, Action = false, Placement = nil, Copy = "This shows your selected class and the best available reward. Higher tiers have greater rewards." },
			Q8 = { Page = "TimeTrialSetup", Helper = "group", Literals = { "MedalTargets" }, Action = false, Placement = nil, Copy = "Beat these target times to earn medals and cash. Faster times award higher medals." },
			Q4 = { Page = "TimeTrialSetup", Helper = "group", Literals = { "LapSelector" }, Action = false, Placement = nil, Copy = "Choose how many timed laps you want to run. Your best completed lap is used for the result." },
			P1 = { Page = "RaceSetup", Helper = "group", Literals = { "RaceFormat", "DetailColumn" }, Action = false, Placement = nil, Copy = "This shows the route, lap count and player limit. Multiplayer races use an open vehicle category." },
			B3 = { Page = "GarageShortcut", Helper = "group", Literals = { "Garage" }, Action = false, Placement = "Below", Copy = "Open My Garages to view your owned properties. Each garage can display vehicles and has its own customisation." },
			X1 = { Page = "GarageBrowser", Helper = "group", Literals = { "GarageList" }, Action = false, Placement = nil, Copy = "Choose one of your owned garage properties. Each card shows how many display spaces it contains." },
			X3 = { Page = "GarageBrowser", Helper = "group", Literals = { "Enter" }, Action = true, Placement = nil, Copy = "Enter the selected garage. You can manage its vehicles, assets and appearance from inside." },
			Z1 = { Page = "GarageHome", Helper = "cardGroup", Literals = { "DisplayCars" }, Action = false, Placement = "Above", Copy = "Choose which owned vehicles are displayed in your garage. Each vehicle is assigned to a physical display space." },
			Z2 = { Page = "GarageHome", Helper = "cardGroup", Literals = { "BuildGarage" }, Action = false, Placement = "Above", Copy = "Buy and equip different walls, floors, ceilings, decorations and lighting." },
			Z3 = { Page = "GarageHome", Helper = "cardGroup", Literals = { "StyleGarage" }, Action = false, Placement = "Above", Copy = "Customise the assets already equipped in your garage. Change their colours, materials and lighting." },
			AA1 = { Page = "DisplayCars", Helper = "visibleScrollerCards", Literals = { "TutorialCardScroller" }, Action = false, Placement = "Above", Copy = "Choose a display space to manage. Empty spaces can receive a vehicle, while occupied spaces can be changed." },
			AB1 = { Page = "GarageAssetFamilies", Helper = "cardGroup", Literals = { "Structure", "Decorations", "Lighting" }, Action = false, Placement = "Above", Copy = "Choose Structure, Decorations or Lighting. Build adds new assets; Style changes the look of equipped assets." },
			AC1 = { Page = "BuildStructure", Helper = "group", Literals = { "Categories" }, Action = false, Placement = nil, Copy = "Choose which section of the garage you want to rebuild. The selected style is previewed in that location." },
			AD1 = { Page = "BuildDecorations", Helper = "group", Literals = { "Categories" }, Action = false, Placement = nil, Copy = "Choose where you want to place a decoration. Each location has its own compatible asset options." },
		},
	}
	-- END GENERATED EXPECTED

	local function attributes(initial)
		local object = { Values = initial or {}, Writes = {} }
		function object:GetAttribute(name)
			return self.Values[name]
		end
		function object:SetAttribute(name, value)
			self.Values[name] = value
			table.insert(self.Writes, { Name = name, Value = value })
		end
		return object
	end

	-- A model over fakes. Time is h.Now; h.Step(seconds) runs deferred functions and due timers in order.
	local function harness(options)
		options = options or {}
		local h = { Now = 100, Timers = {}, Deferred = {}, Prints = {}, Warns = {}, Calls = {}, Emits = {}, Fires = {}, Waits = {},
			Reasons = {}, Touch = options.Touch == true, Driving = nil, HasControlsEvent = true, PresenceAny = false,
			AllPages = options.AllPages == true, PageRoots = {}, MissingCards = {}, FailGetState = options.FailGetState or 0 }
		h.Server = { Stage = options.Stage or 1, SeenPages = options.SeenPages or {}, Completed = options.Completed or {} }
		h.Player = attributes()
		h.PlayerGui = attributes()
		h.LoadingState = attributes()
		h.Config = attributes()
		local function snapshot()
			return { Success = true, Stage = h.Server.Stage, SeenPages = table.clone(h.Server.SeenPages),
				Completed = table.clone(h.Server.Completed) }
		end
		h.Snapshot = snapshot
		h.Remote = {}
		function h.Remote:InvokeServer(action, payload)
			table.insert(h.Calls, { Action = action, Payload = payload })
			if h.Reply then
				return h.Reply(action, payload)
			end
			if action == "GetState" then
				if h.FailGetState > 0 then
					h.FailGetState -= 1
					error("profile is still loading")
				end
				return snapshot()
			end
			h.Server.SeenPages[payload.PageId] = true
			return snapshot()
		end
		local controlsEvent = {}
		function controlsEvent:Fire(payload)
			table.insert(h.Fires, payload)
		end
		h.Model = M.new({
			Remotes = { OnboardingInvoke = h.Remote },
			Bindables = { OpenDrivingControls = function() return h.HasControlsEvent and controlsEvent or nil end },
			Player = h.Player, PlayerGui = h.PlayerGui, LoadingState = h.LoadingState, Config = h.Config,
			Presence = { Any = function() return h.PresenceAny end },
			Audio = { Emit = function(cue, payload) table.insert(h.Emits, { Cue = cue, Payload = payload }) end },
			Targets = {
				Page = function(pageId) return h.PageRoots[pageId] or (h.AllPages and { Page = pageId }) or nil end,
				Alive = function(root) return root.Dead ~= true end,
				Card = function(cardId, _spec, _root)
					if h.MissingCards[cardId] then return nil end
					return { cardId }
				end,
			},
			TouchEnabled = function() return h.Touch end,
			ActivelyDriving = function() return h.Driving end,
			Clock = function() return h.Now end,
			Spawn = function(fn, ...) fn(...) end,
			Defer = function(fn) table.insert(h.Deferred, fn) end,
			Delay = function(seconds, fn) table.insert(h.Timers, { At = h.Now + seconds, Fn = fn }) end,
			Wait = function(seconds) table.insert(h.Waits, seconds) end,
			Print = function(text) table.insert(h.Prints, text) end,
			Warn = function(text) table.insert(h.Warns, text) end,
		})
		h.Model.Changed:Connect(function(reason) table.insert(h.Reasons, reason) end)
		function h.Flush()
			while #h.Deferred > 0 do
				table.remove(h.Deferred, 1)()
			end
		end
		function h.Step(seconds)
			h.Flush()
			local target = h.Now + seconds
			while true do
				local best, bestIndex = nil, nil
				for index, timer in ipairs(h.Timers) do
					if timer.At <= target and (best == nil or timer.At < best.At) then
						best, bestIndex = timer, index
					end
				end
				if not best then break end
				table.remove(h.Timers, bestIndex)
				h.Now = math.max(h.Now, best.At)
				best.Fn()
				h.Flush()
			end
			h.Now = target
		end
		function h.Open()
			h.Model:Start()
			h.Model:RefreshGate()
			h.Step(0.01)
		end
		function h.Count(list, text)
			local count = 0
			for _, item in ipairs(list) do
				if item == text then count += 1 end
			end
			return count
		end
		function h.MarkSeenCalls()
			local pages = {}
			for _, call in ipairs(h.Calls) do
				if call.Action == "MarkSeen" then table.insert(pages, call.Payload.PageId) end
			end
			return pages
		end
		return h
	end

	local ALL_PAGES = {}
	for _, pageId in ipairs(M.PageOrder) do ALL_PAGES[pageId] = true end
	ALL_PAGES[M.FirstDrivePage] = true
	local ALL_DONE = { FirstVehiclePurchased = true, FirstVehicleDriven = true, GarageManagementEntered = true, FirstEventEntered = true }

	-- Static tables against the generated contract -----------------------------------------------------------
	case("contract: 19 pages in the Classic order, 33 cards, the same cards per page", function()
		expect(same(M.PageOrder, EXPECTED.PageOrder), "PageOrder")
		expect(#M.PageOrder == 19, "19 pages")
		local pageCount, cardCount = 0, 0
		for pageId, cards in pairs(M.Pages) do
			pageCount += 1
			expect(EXPECTED.Pages[pageId] ~= nil, "unknown page " .. pageId)
			expect(same(cards, EXPECTED.Pages[pageId].Cards), "cards of " .. pageId)
			expect(table.find(M.PageOrder, pageId) ~= nil, pageId .. " is in PageOrder")
		end
		for _ in pairs(M.Targets) do cardCount += 1 end
		expect(pageCount == 19, "19 pages in Pages, got " .. pageCount)
		expect(cardCount == 33, "33 cards in Targets, got " .. cardCount)
		expect(M.FirstDrivePage == "PCDriving", "PCDriving")
	end)

	case("contract: every card has the Classic helper, literals, copy, placement and action flag", function()
		for cardId, wanted in pairs(EXPECTED.Cards) do
			local spec = M.Targets[cardId]
			expect(spec ~= nil, "no target for " .. cardId)
			expect(spec.Helper == wanted.Helper, cardId .. " helper " .. tostring(spec.Helper))
			expect(same(spec.Literals, wanted.Literals), cardId .. " literals")
			expect(M.Copy[cardId] == wanted.Copy, cardId .. " copy")
			expect(M.Placement[cardId] == wanted.Placement, cardId .. " placement")
			expect((M.ActionSteps[cardId] == true) == wanted.Action, cardId .. " action step")
			expect(table.find(M.Pages[wanted.Page], cardId) ~= nil, cardId .. " is on page " .. wanted.Page)
		end
	end)

	case("contract: every page signal carries the Classic literals", function()
		for pageId, wanted in pairs(EXPECTED.Pages) do
			local spec = M.PageSignals[pageId]
			expect(spec ~= nil, "no signal for " .. pageId)
			expect(same(spec.Literals, wanted.Signal), pageId .. " signal literals")
			expect(spec.All ~= nil or spec.Any ~= nil, pageId .. " has keys")
		end
	end)

	case("contract: every mark key exists in Kit.Contracts and follows from the Classic literal", function()
		local Contracts = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Contracts")
		local function known(key, where)
			expect(Contracts.Marks[key] ~= nil, where .. ": mark key '" .. tostring(key) .. "' is not in Contracts.Marks")
		end
		for cardId, spec in pairs(M.Targets) do
			for _, key in ipairs(spec.Keys) do known(key, cardId) end
			for _, key in ipairs(spec.Fallback or {}) do known(key, cardId) end
			if spec.Kind == "Cards" then
				for index, literal in ipairs(spec.Literals) do
					expect(spec.Keys[index] == "Card." .. literal, cardId .. " card key")
					expect(Contracts.Marks[spec.Keys[index]].Attributes.CanonicalGarageCardId == literal, cardId .. " card id attribute")
				end
			elseif spec.Kind == "ScrollerCards" then
				expect(spec.Scroller == spec.Literals[1], cardId .. " scroller")
				known(spec.Scroller, cardId)
				expect(Contracts.Marks[spec.Scroller].Name == spec.Literals[1], cardId .. " scroller name")
				expect(#spec.Keys == 1 and spec.Keys[1] == "Card", cardId .. " uses the Card mark")
			elseif spec.Kind == "Text" then
				for index, literal in ipairs(spec.Literals) do
					expect(Contracts.Marks[spec.Keys[index]].Text == literal, cardId .. " text mark")
				end
			else
				local names = {}
				for _, key in ipairs(spec.Keys) do table.insert(names, Contracts.Marks[key].Name) end
				for _, key in ipairs(spec.Fallback or {}) do table.insert(names, Contracts.Marks[key].Name) end
				expect(same(names, spec.Literals), cardId .. " names equal the Classic literals")
			end
		end
		for pageId, spec in pairs(M.PageSignals) do
			for _, key in ipairs(spec.All or {}) do known(key, pageId) end
			for _, key in ipairs(spec.Any or {}) do known(key, pageId) end
		end
		for key, pageId in pairs(M.LockPages) do
			known(key, "lock")
			expect(M.Pages[pageId] ~= nil, "lock page " .. pageId)
		end
	end)

	-- Sequences ----------------------------------------------------------------------------------------------
	case("fresh profile: every page begins and completes once, in order, with one MarkSeen each", function()
		local h = harness({ Touch = true, Stage = 2, AllPages = true })
		h.Open()
		for _, pageId in ipairs(M.PageOrder) do
			h.Model:Poll()
			h.Step(0.2)
			expect(h.Model.ActivePage == pageId, "expected page " .. pageId .. ", got " .. tostring(h.Model.ActivePage))
			for index, cardId in ipairs(M.Pages[pageId]) do
				expect(h.Model.ActiveIndex == index and h.Model:CardId() == cardId, pageId .. " card " .. cardId)
				expect(h.Model.ActiveObjects ~= nil and h.Model.ActiveObjects[1] == cardId, cardId .. " is pinned")
				expect(h.Model:CalloutVisible(), cardId .. " callout shows")
				expect(h.Model:IsAction() == (M.ActionSteps[cardId] == true), cardId .. " action flag")
				h.Model:Advance()
				h.Step(0.2)
			end
			expect(h.Model.State.SeenPages[pageId] == true, pageId .. " is seen")
		end
		expect(h.Model.ActivePage == nil, "no page left active")
		h.Model:Poll()
		h.Step(0.2)
		expect(h.Model.ActivePage == nil, "nothing begins again")
		expect(same(h.MarkSeenCalls(), M.PageOrder), "MarkSeen once per page, in page order")
		for _, pageId in ipairs(M.PageOrder) do
			expect(h.Count(h.Prints, "[Tutorial] begin " .. pageId .. " " .. M.Pages[pageId][1]) == 1, pageId .. " begins once")
			expect(h.Count(h.Prints, "[Tutorial] complete " .. pageId) == 1, pageId .. " completes once")
		end
		expect(#h.Fires == 0, "no first-drive modal on touch")
	end)

	case("remote calls: only GetState {} and MarkSeen {PageId}", function()
		local h = harness({ Touch = true, Stage = 2, AllPages = true })
		h.Open()
		h.Step(0.2)
		h.Model:Advance()
		h.Step(0.2)
		for _, call in ipairs(h.Calls) do
			local keys = {}
			for key in pairs(call.Payload) do table.insert(keys, key) end
			if call.Action == "GetState" then
				expect(#keys == 0, "GetState payload is empty")
			else
				expect(call.Action == "MarkSeen", "unexpected action " .. tostring(call.Action))
				expect(#keys == 1 and keys[1] == "PageId" and type(call.Payload.PageId) == "string", "MarkSeen payload")
			end
		end
		expect(h.Calls[1].Action == "GetState", "GetState first")
	end)

	case("returning player: saved progress, no page, no card, no trail, buttons unlocked", function()
		local h = harness({ Stage = 4, SeenPages = table.clone(ALL_PAGES), Completed = table.clone(ALL_DONE), AllPages = true, FailGetState = 2 })
		h.Model:RefreshGate()
		h.Step(0.01)
		h.Model:Poll()
		h.Step(0.2)
		expect(h.Model.ActivePage == nil, "no page before the saved progress arrives")
		expect(h.Model:Trail() == nil, "no trail before the saved progress arrives")
		expect(h.Model:ObjectivesVisible() == false, "no cards before the saved progress arrives")
		local locked = h.Model:Locks()
		expect(locked.Car == false and locked.Race == false and locked.Garage == false, "locked until the state arrives (Classic)")

		h.Model:Start()
		expect(h.Model.Ready, "ready after the third attempt")
		expect(#h.Calls == 3 and #h.Waits == 2 and h.Waits[1] == 0.5 and h.Waits[2] == 1, "retry waits 0.5 s then 1 s")
		h.Model:Poll()
		h.Step(5)
		expect(h.Model.ActivePage == nil, "no page for a returning player")
		expect(#h.Model:ObjectiveOrder() == 0, "no objective cards")
		expect(h.Model:Trail() == nil, "no trail")
		expect(h.Model:Finished(), "finished")
		local locks = h.Model:Locks()
		expect(locks.Car and locks.Race and locks.Garage, "all three unlocked")
		expect(#h.MarkSeenCalls() == 0, "nothing marked")
		expect(#h.Fires == 0 and #h.Emits == 0, "no modal, no sound")
	end)

	case("GetState: gives up after 60 attempts with the Classic waits", function()
		local h = harness({ FailGetState = 1000 })
		h.Model:Start()
		expect(not h.Model.Ready, "not ready")
		expect(#h.Calls == 60 and #h.Waits == 60, "60 attempts")
		expect(h.Waits[9] == 4.5 and h.Waits[10] == 5 and h.Waits[60] == 5, "wait is min(5, 0.5 x attempt)")
	end)

	case("untrusted replies: a wrong shape never replaces the state or errors", function()
		local h = harness({ Touch = true, Stage = 2, AllPages = true })
		h.Reply = function(action)
			if action == "GetState" then return { Success = true } end
			return "nope"
		end
		h.Open()
		expect(h.Model.Ready and type(h.Model.State.SeenPages) == "table" and type(h.Model.State.Completed) == "table", "tables supplied")
		h.Step(0.2)
		for _ = 1, #M.Pages.Dealership do
			h.Model:Advance()
			h.Step(0.2)
		end
		expect(h.Model.State.SeenPages.Dealership == true, "kept the local seen flag after a bad MarkSeen reply")
		h.Model:Accept(nil)
		h.Model:Accept({ Success = false })
		expect(h.Model.State.SeenPages.Dealership == true, "a failed state is ignored")
	end)

	case("advance: debounced at 0.18 s", function()
		local h = harness({ Touch = true, Stage = 2 })
		h.PageRoots.Dealership = {}
		h.Open()
		h.Step(0.2)
		expect(h.Model:CardId() == "G1", "G1")
		h.Model:Advance()
		h.Model:Advance()
		h.Step(0.1)
		expect(h.Model:CardId() == "G4", "one step, got " .. tostring(h.Model:CardId()))
		h.Model:Advance()
		expect(h.Model:CardId() == "G4", "still inside the debounce")
		h.Step(0.1)
		h.Model:Advance()
		expect(h.Model:CardId() == "A2", "advances after the debounce")
	end)

	case("action step: the highlighted button advances it, once", function()
		local h = harness({ Touch = true, Stage = 2, SeenPages = { Dealership = true } })
		h.PageRoots.GarageBrowser = {}
		h.Open()
		h.Step(0.2)
		expect(h.Model.ActivePage == "GarageBrowser" and h.Model:CardId() == "X1", "X1")
		h.Model:ActionActivated()
		h.Flush()
		expect(h.Model:CardId() == "X1", "a non-action card ignores the button")
		h.Model:Advance()
		h.Step(0.2)
		expect(h.Model:CardId() == "X3" and h.Model:IsAction(), "X3 is an action step")
		h.Model:ActionActivated()
		h.Model:ActionActivated()
		h.Step(0.2)
		expect(h.Model.ActivePage == nil and h.Model.State.SeenPages.GarageBrowser == true, "page complete")
		expect(h.Count(h.MarkSeenCalls(), "GarageBrowser") == 1, "one MarkSeen")
	end)

	case("page closed early: abandoned after PageAbandonSeconds, not marked, begins again later", function()
		local h = harness({ Touch = true, Stage = 2 })
		local root = {}
		h.PageRoots.Dealership = root
		h.Open()
		h.Step(0.2)
		expect(h.Model.ActiveObjects ~= nil, "pinned")
		root.Dead = true
		h.PageRoots.Dealership = nil
		h.Model:TargetLost()
		expect(h.Model.ActiveObjects == nil and not h.Model:CalloutVisible(), "hidden at once")
		h.Step(2.5)
		expect(h.Model.ActivePage == "Dealership", "still waiting inside 3 s")
		h.Step(1.5)
		expect(h.Model.ActivePage == nil, "abandoned")
		expect(h.Model.State.SeenPages.Dealership ~= true and #h.MarkSeenCalls() == 0, "not marked seen")
		expect(h.Count(h.Prints, "[Tutorial] page closed before completion: Dealership") == 1, "printed once")
		expect(table.find(h.Reasons, "PageEnded") ~= nil, "PageEnded fired")
		h.PageRoots.Dealership = {}
		h.Model:Poll()
		h.Step(0.2)
		expect(h.Model.ActivePage == "Dealership" and h.Model:CardId() == "G1", "begins again from the first card")
	end)

	case("missing target: keeps the page, warns once, pins when the target appears", function()
		local h = harness({ Touch = true, Stage = 2 })
		h.PageRoots.Dealership = {}
		h.MissingCards.G1 = true
		h.Open()
		h.Step(4)
		expect(h.Model.ActivePage == "Dealership" and h.Model.ActiveObjects == nil, "waiting")
		expect(#h.Warns == 1, "one warning, got " .. #h.Warns)
		h.MissingCards.G1 = nil
		h.Step(1)
		expect(h.Model.ActiveObjects ~= nil, "pinned once the target shows")
	end)

	case("stage rules: shortcut pages wait for their gate", function()
		local h = harness({ Stage = 1, AllPages = false })
		h.PageRoots.VehicleShortcut = {}
		h.PageRoots.GarageShortcut = {}
		h.PageRoots.RaceShortcut = {}
		h.PageRoots.MobileDriving = {}
		h.Open()
		h.Step(0.2)
		expect(h.Model.ActivePage == nil, "stage 1, no touch: nothing")
		h.Server.Stage = 2
		h.Server.SeenPages.PCDriving = true
		h.Model:Accept(h.Snapshot())
		h.Model:Poll()
		h.Step(0.2)
		expect(h.Model.ActivePage == "VehicleShortcut", "VehicleShortcut at stage 2")
		h.Model:Advance()
		h.Step(0.2)
		h.Model:Poll()
		h.Step(0.2)
		expect(h.Model.ActivePage == "GarageShortcut", "GarageShortcut after VehicleShortcut")
		h.Model:Advance()
		h.Step(0.2)
		h.Model:Poll()
		h.Step(0.2)
		expect(h.Model.ActivePage == "RaceShortcut", "RaceShortcut after GarageShortcut")
		local locks = h.Model:Locks()
		expect(locks.Car == true and locks.Garage == true and locks.Race == false, "locks follow the seen pages")
	end)

	case("loading gate: nothing shows or begins while loading or the map is open", function()
		local h = harness({ Touch = true, Stage = 2 })
		h.PageRoots.Dealership = {}
		h.Player.Values.StartScreenActive = true
		h.Open()
		h.Step(0.5)
		expect(h.Model.GateOpen == false and h.Model.ActivePage == nil, "closed during the start screen")
		h.Player.Values.StartScreenActive = false
		h.Model:RefreshGate()
		h.Step(0.2)
		expect(h.Model.GateOpen and h.Model.ActivePage == "Dealership" and h.Model:CalloutVisible(), "opens and begins")
		h.Player.Values.FullMapOpen = true
		h.Model:RefreshGate()
		expect(h.Model.GateOpen == false and not h.Model:CalloutVisible(), "hidden with the map")
		h.Player.Values.FullMapOpen = false
		h.Model:RefreshGate()
		h.Step(0.2)
		expect(h.Model:CalloutVisible() and h.Model:CardId() == "G1", "the same card returns")
		h.LoadingState.Values.Active = true
		expect(h.Model:Blocked() and not h.Model:CalloutVisible(), "blocked by the loading state")
	end)

	case("first drive (PC): one modal request, one PCDriving mark", function()
		local h = harness({ Stage = 2 })
		h.Open()
		h.Model:Poll()
		expect(#h.Fires == 0, "not driving, no spawn signal: nothing")
		h.Driving = { RaceDriving = true }
		h.Model:Poll()
		expect(#h.Fires == 0, "not in a race vehicle")
		h.Driving = { RaceDriving = false }
		h.Model:Poll()
		expect(#h.Fires == 1 and h.Fires[1].FirstDrive == true, "OpenDrivingControlsFromOnboarding {FirstDrive = true}")
		expect(h.Player.Values.FirstDrivePresentationPending == true, "FirstDrivePresentationPending written")
		expect(h.Count(h.MarkSeenCalls(), "PCDriving") == 1, "PCDriving marked")
		h.Model:Poll()
		h.Model:VehicleSpawned()
		expect(#h.Fires == 1, "never twice")
	end)

	case("first drive: spawn signal during a FreeRoamDrive loading screen; missing bindable clears the flag", function()
		local h = harness({ Stage = 2 })
		h.Open()
		h.LoadingState.Values.Active = true
		h.LoadingState.Values.Destination = "FreeRoamDrive"
		h.Model:VehicleSpawned()
		expect(#h.Fires == 1, "direct spawn opens the controls")

		local g = harness({ Stage = 2 })
		g.Open()
		g.HasControlsEvent = false
		g.Driving = { RaceDriving = false }
		g.Model:Poll()
		expect(#g.Fires == 0, "no event, no fire")
		expect(g.Player.Writes[1] ~= nil and g.Player.Writes[1].Name == "FirstDrivePresentationPending"
			and g.Player.Writes[1].Value == false, "flag cleared")
		expect(#g.MarkSeenCalls() == 0, "not marked")

		local t = harness({ Stage = 2, Touch = true })
		t.Open()
		t.Driving = { RaceDriving = false }
		t.Model:VehicleSpawned()
		t.Model:Poll()
		expect(#t.Fires == 0, "never on touch")
	end)

	case("objectives: order, hints, visibility and one completion sound each", function()
		local h = harness({ Stage = 1 })
		h.Open()
		expect(same(h.Model:ObjectiveOrder(), { 1 }), "objective 1 only")
		expect(h.Model:ObjectiveHint(1) == "Follow the trail to the dealership.", "hint before purchase")
		expect(h.Model:ObjectivesVisible(), "cards show")
		expect(h.Model:Trail() == "Dealership", "trail to the dealership")
		h.PresenceAny = true
		expect(not h.Model:ObjectivesVisible(), "hidden behind a menu")
		h.PresenceAny = false
		h.Model:PresentationMode({ Owner = "RaceBrowser", Active = true })
		expect(not h.Model:ObjectivesVisible(), "hidden for a presentation owner")
		h.Model:PresentationMode({ Owner = "RaceBrowser", Active = false })
		expect(h.Model:ObjectivesVisible(), "back")

		h.Server.Completed.FirstVehiclePurchased = true
		h.Model:Accept(h.Snapshot())
		expect(h.Model:ObjectiveHint(1) == "Start driving your new vehicle.", "hint after purchase")
		expect(h.Model:Trail() == nil, "no dealership trail after the purchase")
		expect(#h.Emits == 0, "no sound yet")

		h.Server.Completed.FirstVehicleDriven = true
		h.Server.SeenPages.VehicleShortcut = true
		h.Server.SeenPages.GarageShortcut = true
		h.Server.Stage = 2
		h.Model:Accept(h.Snapshot())
		expect(#h.Emits == 1 and h.Emits[1].Cue == "Objective.Complete" and h.Emits[1].Payload.Key == "Objective:1"
			and h.Emits[1].Payload.ObjectiveIndex == 1, "objective 1 sound")
		expect(same(h.Model:ObjectiveOrder(), { 2 }), "objective 2")
		h.Model:Accept(h.Snapshot())
		expect(#h.Emits == 1, "not repeated")

		h.Player.Values.OwnedGarageInside = true
		expect(h.Model:Trail() == "GarageDesk", "trail to the garage desk")
		h.PlayerGui.Values.OwnedGarageManagementOpen = true
		expect(h.Model:Trail() == nil, "no trail while the desk is open")

		h.Server.SeenPages.RaceShortcut = true
		h.Model:Accept(h.Snapshot())
		expect(same(h.Model:ObjectiveOrder(), { 2, 3 }), "objectives 2 and 3")
		h.Server.Completed.GarageManagementEntered = true
		h.Server.Completed.FirstEventEntered = true
		h.Model:Accept(h.Snapshot())
		expect(#h.Emits == 3, "three sounds in all")
		expect(#h.Model:ObjectiveOrder() == 0 and not h.Model:ObjectivesVisible(), "no cards left")
	end)

	return results
end
