-- Pure tests for Shell.OnboardingClient. start() is never called here (it claims the surface, waits for PlayerGui and
-- creates a ScreenGui: a Play check). Covered: the mark-based target finder, the locks, the trail config overlay and
-- the path follower, on detached instances.
return function(M, env)
	local results = {}
	local PULSE = "ReplicatedStorage.Modules.Game.UIPulse."

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local Input = env.Load(PULSE .. "Kit.Input")
	local Contracts = env.Load(PULSE .. "Kit.Contracts")
	local Model = env.Load(PULSE .. "Shell.OnboardingModel")

	-- The mark registry is shared by every case, so each case sees only the instances it made.
	local function finder()
		local live = {}
		local targets = M._targets(Input, Contracts, function(object) return live[object] == true end)
		local function make(className, key, parent)
			local object = env.Detached(className)
			if parent then object.Parent = parent end
			Input.Mark(object, key)
			live[object] = true
			return object
		end
		return targets, make, live
	end

	case("owner shape: start exists and nothing ran at require", function()
		expect(type(M) == "table" and type(M.start) == "function", "start is a function")
		expect(M.Controller == nil, "no Controller before start")
	end)

	case("visible: a detached object is never showing", function()
		local playerGui = env.Detached("Folder")
		local visible = M._visibleUnder(playerGui)
		expect(visible(env.Detached("Frame")) == false, "detached")
		expect(visible(nil) == false and visible("x") == false, "not an instance")
	end)

	case("trail config: Pulse colour for TutorialGold, Classic config for everything else", function()
		local asked = {}
		local config = {}
		function config:GetAttribute(name)
			table.insert(asked, name)
			return name == "GuideTrailSpacing" and 9 or (name == "TutorialGold" and "classic gold" or nil)
		end
		local colour = Color3.new(0, 1, 1)
		local overlay = M._trailConfig(config, colour)
		expect(overlay:GetAttribute("TutorialGold") == colour, "Pulse colour")
		expect(#asked == 0, "the Classic colour is never read")
		expect(overlay:GetAttribute("GuideTrailSpacing") == 9, "falls through")
		expect(overlay:GetAttribute("GuideTrailChevronTexture") == nil and #asked == 2, "falls through for a missing one")
	end)

	case("page signal: every key of All must show; the root remembers its key", function()
		local targets, make, live = finder()
		local spec = Model.PageSignals.TimeTrialSetup
		expect(targets.Page("TimeTrialSetup", spec) == nil, "nothing marked")
		local tier = make("TextButton", "TierE")
		expect(targets.Page("TimeTrialSetup", spec) == nil, "TierE alone is the Records page, not Setup")
		make("Frame", "LapSelector")
		local root = targets.Page("TimeTrialSetup", spec)
		expect(root ~= nil and root.Object == tier and root.Key == "TierE", "root is the first key's instance")
		expect(targets.Alive(root), "alive")
		live[tier] = nil
		expect(not targets.Alive(root) and targets.Page("TimeTrialSetup", spec) == nil, "gone when hidden")
	end)

	case("page signal: Any (touch drift buttons) and the dealership title text", function()
		local targets, make = finder()
		expect(targets.Page("MobileDriving", Model.PageSignals.MobileDriving) == nil, "none")
		local drift = make("ImageButton", "DriftLeft")
		expect(targets.Page("MobileDriving", Model.PageSignals.MobileDriving).Object == drift, "DriftLeft")

		local title = make("TextLabel", "Text.Dealership")
		expect(title.Text == "DEALERSHIP", "the mark sets the text")
		local root = targets.Page("Dealership", Model.PageSignals.Dealership)
		expect(root ~= nil and root.Object == title, "dealership found by its title mark")
		title.Text = "CUSTOMISE"
		expect(not targets.Alive(root), "a changed title is no longer the dealership")
	end)

	case("page signal: a shared page body re-marked for another tab leaves the old page", function()
		local targets, make = finder()
		local body = make("Frame", "Page.CustomisationHome")
		expect(targets.Page("CustomisationHome", Model.PageSignals.CustomisationHome) ~= nil, "home")
		local homeRoot = targets.Page("CustomisationHome", Model.PageSignals.CustomisationHome)
		Input.Mark(body, "Page.AddModules")
		expect(targets.Page("CustomisationHome", Model.PageSignals.CustomisationHome) == nil, "home page is over")
		expect(not targets.Alive(homeRoot), "its root is no longer alive")
		expect(targets.Page("AddModules", Model.PageSignals.AddModules).Object == body, "the same body is now AddModules")
	end)

	case("card targets: Group takes one per key, with the Classic fallback", function()
		local targets, make = finder()
		expect(targets.Card("D7", Model.Targets.D7, nil) == nil, "none")
		local left = make("ImageButton", "DriftLeft")
		local right = make("ImageButton", "DriftRight")
		make("ImageButton", "DriftRight")
		local found = targets.Card("D7", Model.Targets.D7, nil)
		expect(#found == 2 and found[1] == left and found[2] == right, "one per key, in key order")

		expect(targets.Card("P1", Model.Targets.P1, nil) == nil, "no race format")
		local detail = make("Frame", "DetailColumn")
		expect(targets.Card("P1", Model.Targets.P1, nil)[1] == detail, "fallback DetailColumn")
		local format = make("Frame", "RaceFormat")
		expect(targets.Card("P1", Model.Targets.P1, nil)[1] == format, "RaceFormat first")
	end)

	case("card targets: Cards are buttons with the card id; Text gives the button that carries the text", function()
		local targets, make = finder()
		make("Frame", "Card.AddModules")
		expect(targets.Card("J1", Model.Targets.J1, nil) == nil, "a frame is not a card button")
		local tab = make("TextButton", "Card.AddModules")
		make("TextButton", "Card.PaintShop")
		local found = targets.Card("J1", Model.Targets.J1, nil)
		expect(#found == 1 and found[1] == tab, "only the AddModules button")
		local three = targets.Card("AB1", Model.Targets.AB1, nil)
		expect(three == nil, "no structure cards")

		local textTargets, makeText, textLive = finder()
		local holder = env.Detached("TextButton")
		textLive[holder] = true
		local label = makeText("TextLabel", "Text.Race", holder)
		local timeTrial = makeText("TextButton", "Text.TimeTrial")
		local both = textTargets.Card("O1", Model.Targets.O1, nil)
		expect(#both == 2 and both[1] == timeTrial and both[2] == holder, "the button itself, and the button above the RACE label")
		expect(label.Text == "RACE" and timeTrial.Text == "TIME TRIAL", "texts from the marks")
	end)

	case("card targets: ScrollerCards needs its scroller and cards inside it", function()
		local targets, make = finder()
		expect(targets.Card("G2", Model.Targets.G2, nil) == nil, "no scroller")
		local scroller = make("ScrollingFrame", "VehicleScroller")
		make("TextButton", "Card", scroller)
		-- Detached instances have no size, so no card intersects the scroller: nil, and no error.
		expect(targets.Card("G2", Model.Targets.G2, nil) == nil, "no card on screen")
	end)

	case("locks: only marked buttons are written, with the three Classic properties", function()
		local targets, make = finder()
		local car = make("TextButton", "Car")
		local garage = make("ImageButton", "Garage")
		local frame = make("Frame", "Race")
		local other = env.Detached("TextButton")
		other.Name = "Car"
		targets.ApplyLocks({ Car = false, Garage = true, Race = false })
		expect(car.Active == false and car.Selectable == false and car.AutoButtonColor == false, "Car locked")
		expect(garage.Active == true and garage.Selectable == true and garage.AutoButtonColor == true, "Garage open")
		expect(other.Active == true, "an unmarked button named Car is left alone")
		expect(frame.Name == "Race", "a marked frame is not a button and is skipped")
		targets.ApplyLocks({ Car = true, Garage = true, Race = true })
		expect(car.Active == true and car.Selectable == true and car.AutoButtonColor == true, "Car unlocked")
		car.Name = "Renamed"
		targets.ApplyLocks({ Car = false, Garage = true, Race = true })
		expect(car.Active == true, "an instance that no longer carries the mark is left alone")
	end)

	case("follow path: resolves a path that exists, reports nil for one that does not", function()
		local scope = env.Scope()
		local root = env.Detached("Folder")
		local world = Instance.new("Folder")
		world.Name = "World"
		world.Parent = root
		local desk = Instance.new("Part")
		desk.Name = "Desk"
		desk.Parent = world
		local seen = {}
		local get = M._followPath(scope, root, { "World", "Desk" }, function(found) table.insert(seen, found or false) end)
		expect(#seen == 1 and seen[1] == desk and get() == desk, "found at once")
		local missing = {}
		local getMissing = M._followPath(scope, root, { "World", "Runtime", "PlayerVehicles" }, function(found)
			table.insert(missing, found or false)
		end)
		expect(#missing == 1 and missing[1] == false and getMissing() == nil, "nil for a path that is not there")
		scope:destroy()
	end)

	return results
end
