-- Pure tests for RaceEntry.SetupView (API2 6.4): mounted on a detached Layers.Stage at R1080 and C844 over the fake
-- model of Dev.Fixtures.RaceEntry. Nothing is parented into the game tree and nothing yields.
return function(M, env)
	local results = {}
	local UIP = "ReplicatedStorage.Modules.Game.UIPulse."
	local Metrics = env.Load(UIP .. "Kit.Metrics")
	local Layers = env.Load(UIP .. "Kit.Layers")
	local Fixtures = env.Load(UIP .. "Dev.Fixtures.RaceEntry")

	local BUDGET = 220 -- programme contract 5.2, race entry page
	local PRESET_ORDER = { "R1080", "C844" }
	local PRESETS = {
		R1080 = { Size = Vector2.new(1920, 1080), TouchEnabled = false, Input = "KeyboardAndMouse", TopBarHeight = 58, TopBarKeepOut = Vector2.new(208, 58) },
		C844 = { Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch", TopBarHeight = 52, TopBarKeepOut = Vector2.new(120, 52) },
	}
	local PROPERTIES = { "Name", "Visible", "Position", "Size", "AnchorPoint", "Text", "Image", "BackgroundTransparency", "BackgroundColor3",
		"TextColor3", "TextTransparency", "ImageTransparency", "ImageColor3", "Active", "ZIndex", "LayoutOrder" }

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = (not ok) and tostring(detail) or nil })
	end

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function mount(preset, snapshot)
		local parent = env.Detached("Frame")
		local ctx = Metrics.Fixed(PRESETS[preset])
		parent.Size = UDim2.fromOffset(ctx.Size.X, ctx.Size.Y)
		Metrics.Bind(parent, ctx)
		local layer = Layers.Stage(parent, ctx, "Menu")
		local scope = env.Scope()
		local model = Fixtures._fakeModel(snapshot)
		local view = M.Mount(layer, model, scope)
		scope:connect(model.Changed, function(reason)
			view.Render(reason)
		end)
		view.Render("Test")
		return { Root = layer.Root, Layer = layer, Model = model, View = view, Scope = scope }
	end

	local function unmount(stage)
		stage.View.Destroy()
		stage.Scope:destroy()
		stage.Layer.Destroy()
	end

	local function underGlow(instance, root)
		local current = instance
		while current ~= nil and current ~= root do
			if current.Name == "Glow" then
				return true
			end
			current = current.Parent
		end
		return false
	end

	-- Descendants of the layer root, excluding glows and text-size constraints (API1 section 7).
	local function budget(root)
		local total = 0
		for _, descendant in ipairs(root:GetDescendants()) do
			if not descendant:IsA("UITextSizeConstraint") and not underGlow(descendant, root) then
				total += 1
			end
		end
		return total
	end

	local function capture(root)
		local list = root:GetDescendants()
		local values = {}
		for _, instance in ipairs(list) do
			local row = {}
			for _, property in ipairs(PROPERTIES) do
				local ok, value = pcall(function()
					return instance[property]
				end)
				if ok then
					row[property] = value
				end
			end
			values[instance] = row
		end
		return list, values
	end

	-- nil when nothing differs; otherwise a description of the first difference.
	local function difference(beforeList, beforeValues, root)
		local afterList, afterValues = capture(root)
		if #afterList ~= #beforeList then
			return "descendant count " .. #beforeList .. " -> " .. #afterList
		end
		for _, instance in ipairs(afterList) do
			local before = beforeValues[instance]
			if before == nil then
				return "created " .. instance:GetFullName()
			end
			for property, value in pairs(afterValues[instance]) do
				if before[property] ~= value then
					return instance:GetFullName() .. "." .. property .. " changed"
				end
			end
		end
		return nil
	end

	-- nil when the same instances exist; otherwise what was created or destroyed.
	local function churn(beforeList, root)
		local seen = {}
		for _, instance in ipairs(beforeList) do
			seen[instance] = true
		end
		for _, instance in ipairs(root:GetDescendants()) do
			if not seen[instance] then
				return "created " .. instance:GetFullName()
			end
			seen[instance] = nil
		end
		local gone = next(seen)
		if gone ~= nil then
			return "destroyed " .. tostring(gone)
		end
		return nil
	end

	local function shown(instance, root)
		local current = instance
		while current ~= nil and current ~= root do
			if current:IsA("GuiObject") and not current.Visible then
				return false
			end
			current = current.Parent
		end
		return true
	end

	local function named(root, name)
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant.Name == name and shown(descendant, root) then
				return descendant
			end
		end
		return nil
	end

	-- The Classic onboarding rule (OnboardingClient 123-131): a shown text object with this text, inside a button.
	local function buttonWithText(root, text)
		for _, descendant in ipairs(root:GetDescendants()) do
			if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and shown(descendant, root) and string.upper(descendant.Text) == text then
				local current = descendant
				while current ~= nil and current ~= root.Parent do
					if current:IsA("GuiButton") then
						return current
					end
					current = current.Parent
				end
			end
		end
		return nil
	end

	-- The shown buttons of a Kit.Controls.ButtonRow (it names them "Button<Id>").
	local function countButtons(root)
		local total = 0
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("GuiButton") and shown(descendant, root) and string.sub(descendant.Name, 1, 6) == "Button" then
				total += 1
			end
		end
		return total
	end

	local STATES = Fixtures._snapshots.Setup

	local function find(id)
		for _, state in ipairs(STATES) do
			if state.Id == id then
				return state.Snapshot
			end
		end
		error("no fixture state " .. id)
	end

	for _, presetName in ipairs(PRESET_ORDER) do
		for _, state in ipairs(STATES) do
			case(presetName .. " " .. state.Id .. ": mounts within budget; a second render changes nothing", function()
				local stage = mount(presetName, state.Snapshot)
				local used = budget(stage.Root)
				expect(used <= BUDGET, "budget " .. used .. " > " .. BUDGET)
				expect(used > 0, "something was built")
				local list, values = capture(stage.Root)
				stage.View.Render("Again")
				stage.View.Render("Again")
				local changed = difference(list, values, stage.Root)
				expect(changed == nil, tostring(changed))
				unmount(stage)
			end)
		end
	end

	for _, presetName in ipairs(PRESET_ORDER) do
		case(presetName .. " time trial: onboarding names and texts", function()
			local stage = mount(presetName, find("TimeTrial"))
			for _, tier in ipairs({ "E", "D", "C", "B", "A", "S" }) do
				local button = named(stage.Root, "Tier" .. tier)
				expect(button ~= nil, "Tier" .. tier .. " is shown")
				expect(button:IsA("GuiButton"), "Tier" .. tier .. " is a button")
			end
			expect(named(stage.Root, "LapSelector") ~= nil, "LapSelector")
			expect(named(stage.Root, "PrizeSummary") ~= nil, "PrizeSummary")
			expect(named(stage.Root, "MedalTargets") ~= nil, "MedalTargets")
			expect(named(stage.Root, "RaceFormat") == nil, "no RaceFormat on the time-trial page")
			expect(buttonWithText(stage.Root, "TIME TRIAL") ~= nil, "a button with the text TIME TRIAL")
			expect(buttonWithText(stage.Root, "RACE") ~= nil, "a button with the text RACE")
			expect(countButtons(stage.Root) == 3, "three footer buttons, got " .. countButtons(stage.Root))
			expect(#stage.Model.Calls == 0, "no model call at mount or render")
			unmount(stage)
		end)

		case(presetName .. " race: onboarding names and texts", function()
			local stage = mount(presetName, find("Race"))
			expect(named(stage.Root, "RaceFormat") ~= nil, "RaceFormat")
			expect(named(stage.Root, "LapSelector") == nil, "no LapSelector on the race page")
			expect(named(stage.Root, "TierE") == nil, "no tier buttons on the race page")
			expect(buttonWithText(stage.Root, "TIME TRIAL") ~= nil, "a button with the text TIME TRIAL")
			expect(buttonWithText(stage.Root, "RACE") ~= nil, "a button with the text RACE")
			expect(countButtons(stage.Root) == 2, "two footer buttons, got " .. countButtons(stage.Root))
			unmount(stage)
		end)

		case(presetName .. ": tier and lap changes create and destroy nothing", function()
			local stage = mount(presetName, find("TimeTrial"))
			local list = stage.Root:GetDescendants()
			for _, tier in ipairs({ "D", "S", "A", "C" }) do
				stage.Model.SelectTier(tier)
			end
			for _, lap in ipairs({ 4, 10, 1, 3 }) do
				stage.Model.SetLap(lap)
			end
			for _ = 1, 5 do
				stage.View.Render("Rapid")
			end
			local problem = churn(list, stage.Root)
			expect(problem == nil, tostring(problem))
			expect(countButtons(stage.Root) == 3, "still three footer buttons")
			unmount(stage)
		end)

		case(presetName .. ": another page or a closed screen hides this page", function()
			local stage = mount(presetName, find("TimeTrial"))
			local snapshot = stage.Model.Snapshot()
			snapshot.Page = "Records"
			snapshot.Setup = nil
			stage.View.Render("Page")
			expect(named(stage.Root, "LapSelector") == nil, "hidden on another page")
			expect(named(stage.Root, "TierE") == nil, "tier buttons hidden on another page")
			expect(countButtons(stage.Root) == 0, "no footer of this page")
			expect(buttonWithText(stage.Root, "RACE") == nil, "tabs hidden with the page")
			unmount(stage)

			local closed = mount(presetName, find("TimeTrial"))
			closed.Model.Snapshot().Open = false
			closed.View.Render("Close")
			expect(countButtons(closed.Root) == 0, "hidden while closed")
			unmount(closed)
		end)

		case(presetName .. ": an overtaken snapshot is not drawn", function()
			local stage = mount(presetName, find("TimeTrial"))
			local list, values = capture(stage.Root)
			local real = stage.Model.Snapshot
			stage.Model.Snapshot = function()
				local copy = table.clone(real())
				copy.Revision = copy.Revision - 1
				copy.Title = "STALE"
				copy.Page = "Records"
				return copy
			end
			stage.View.Render("Stale")
			local changed = difference(list, values, stage.Root)
			expect(changed == nil, tostring(changed))
			unmount(stage)
		end)

		case(presetName .. ": time trial to race and back builds each page once", function()
			local stage = mount(presetName, find("TimeTrial"))
			local trial = stage.Model.Snapshot()
			local race = table.clone(find("Race"))
			local state = { Current = trial }
			stage.Model.Snapshot = function()
				return state.Current
			end
			stage.Model.Revision = function()
				return state.Current.Revision
			end
			state.Current = race
			stage.View.Render("Mode")
			expect(named(stage.Root, "RaceFormat") ~= nil, "race page shown")
			expect(named(stage.Root, "LapSelector") == nil, "time-trial page hidden")
			expect(countButtons(stage.Root) == 2, "the race footer only, got " .. countButtons(stage.Root))
			local list = stage.Root:GetDescendants()
			for _ = 1, 3 do
				state.Current = trial
				stage.View.Render("Mode")
				expect(countButtons(stage.Root) == 3, "the time-trial footer only, got " .. countButtons(stage.Root))
				state.Current = race
				stage.View.Render("Mode")
				expect(countButtons(stage.Root) == 2, "the race footer only, got " .. countButtons(stage.Root))
			end
			local problem = churn(list, stage.Root)
			expect(problem == nil, tostring(problem))
			unmount(stage)
		end)
	end

	case("LabelWidth: a one-line label stops at its panel", function()
		expect(M.LabelWidth(175, 7, 0, 0.9) * 0.9 > 160.99 and M.LabelWidth(175, 7, 0, 0.9) * 0.9 < 161.01, "844x390 column: 161 px")
		expect(M.LabelWidth(132, 7, 25, 0.85) * 0.85 > 92.99 and M.LabelWidth(132, 7, 25, 0.85) * 0.85 < 93.01, "568x320 with a badge: 93 px")
		expect(M.LabelWidth(10, 7, 0, 1) == 1, "never under one pixel")
		expect(M.LabelWidth(100, 10, nil, 0) == 80, "a zero scale is ignored")
	end)

	return results
end
