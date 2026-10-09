-- Pure tests for RaceEntry.VehicleView (API2 6.4): mounted on a detached Layers.Stage at R1080 and C844 over the fake
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

	local STATES = Fixtures._snapshots.Vehicles

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

	local function texts(root)
		local list = {}
		for _, descendant in ipairs(root:GetDescendants()) do
			if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and shown(descendant, root) then
				table.insert(list, string.upper(descendant.Text))
			end
		end
		return list
	end

	for _, presetName in ipairs(PRESET_ORDER) do
		case(presetName .. ": no eligibility count, no drop-downs, no setup names, no mode tabs", function()
			local stage = mount(presetName, find("TimeTrial"))
			for _, text in ipairs(texts(stage.Root)) do
				expect(string.find(text, "ELIGIBLE", 1, true) == nil, "no eligibility text: " .. text)
				expect(string.find(text, "SORT BY", 1, true) == nil, "no sort control: " .. text)
				expect(text ~= "CATEGORY", "no category control")
			end
			for _, name in ipairs({ "LapSelector", "PrizeSummary", "MedalTargets", "RaceFormat", "TierE", "Category", "Sort" }) do
				expect(named(stage.Root, name) == nil, "no " .. name)
			end
			expect(buttonWithText(stage.Root, "TIME TRIAL") == nil, "no TIME TRIAL button on this page")
			expect(buttonWithText(stage.Root, "RACE") == nil, "no RACE button on this page")
			expect(countButtons(stage.Root) == 2, "two row buttons, got " .. countButtons(stage.Root))
			expect(#stage.Model.Calls == 0, "no model call at mount or render")
			unmount(stage)
		end)

		case(presetName .. ": the button row is in slot RailButtons and the rail in BottomRail", function()
			local stage = mount(presetName, find("TimeTrial"))
			expect(stage.Layer.Slot("RailButtons"):FindFirstChild("VehicleButtons") ~= nil, "VehicleButtons under the RailButtons slot")
			expect(stage.Layer.Slot("BottomRail"):FindFirstChild("VehicleRail") ~= nil, "VehicleRail under the BottomRail slot")
			unmount(stage)
		end)

		case(presetName .. ": choosing vehicles creates and destroys nothing", function()
			local stage = mount(presetName, find("Race"))
			local list = stage.Root:GetDescendants()
			for _, id in ipairs({ "v3", "v6", "v1", "v4", "v2" }) do
				stage.Model.SelectVehicle(id)
			end
			for _ = 1, 5 do
				stage.View.Render("Rapid")
			end
			local problem = churn(list, stage.Root)
			expect(problem == nil, tostring(problem))
			expect(stage.Model.SelectedVehicle() == "v2", "the last choice stands")
			expect(countButtons(stage.Root) == 2, "still two row buttons")
			unmount(stage)
		end)

		case(presetName .. ": another page hides this one", function()
			local stage = mount(presetName, find("TimeTrial"))
			local snapshot = stage.Model.Snapshot()
			snapshot.Page = "Setup"
			snapshot.Vehicles = nil
			stage.View.Render("Page")
			expect(countButtons(stage.Root) == 0, "no row of this page")
			unmount(stage)
		end)

		-- The live bindings (B / Escape, focus entry) need a ScreenGui and a running game: a Play check. A stage
		-- has no Gui, so mounting, showing and hiding here must bind nothing and call nothing on the model.
		case(presetName .. ": a stage takes no input and showing or hiding the page calls nothing on the model", function()
			local ContextActionService = game:GetService("ContextActionService")
			local function pulseBindings()
				local total = 0
				for name in pairs(ContextActionService:GetAllBoundActionInfo()) do
					if string.match(name, "^Pulse_Back_") then
						total += 1
					end
				end
				return total
			end
			local before = pulseBindings()
			local stage = mount(presetName, find("TimeTrial"))
			expect(pulseBindings() == before, "a stage bound Back")
			local snapshot = stage.Model.Snapshot()
			snapshot.Page = "Setup"
			snapshot.Vehicles = nil
			stage.View.Render("Page")
			expect(#stage.Model.Calls == 0, "showing or hiding the page called the model")
			unmount(stage)
		end)
	end

	case("focusTarget: the selected tile, else START, else BACK", function()
		expect(M._focusTarget(true, true) == "Tile", "tile first")
		expect(M._focusTarget(true, false) == "Tile", "tile first when START is disabled")
		expect(M._focusTarget(false, true) == "Start", "START when there is no usable tile")
		expect(M._focusTarget(false, false) == "Back", "BACK when nothing else can take focus")
		expect(M._focusTarget(nil, nil) == "Back", "nil is not usable")
	end)

	return results
end
