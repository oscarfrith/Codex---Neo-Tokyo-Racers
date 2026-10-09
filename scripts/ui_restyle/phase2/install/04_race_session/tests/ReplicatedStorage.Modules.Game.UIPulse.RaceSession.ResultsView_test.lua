-- Pure tests for RaceSession.ResultsView: the view mounted on a detached Layers.Stage at R1080 and C844 over the canned
-- fixture model (Dev.Fixtures.RaceSession), for every result state. No real model, remote or player attribute.
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local Metrics = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Metrics")
	local Data = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Data")
	local Fixtures = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.RaceSession")

	local PRESETS = {
		R1080 = { Size = Vector2.new(1920, 1080), TouchEnabled = false, TopBarHeight = 58, TopBarKeepOut = Vector2.new(208, 58) },
		C844 = { Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch", TopBarHeight = 52, TopBarKeepOut = Vector2.new(120, 52) },
	}

	local function item(id)
		for _, entry in ipairs(Fixtures) do
			if entry.Id == id then
				return entry
			end
		end
		error("fixture item missing: " .. id)
	end

	-- Money goes through Kit.Data, whose Classic formatter is replaced here so nothing in the place is required.
	local function withMoney(body)
		local original = Data._foundation
		local function format(value)
			local text = tostring(math.floor((tonumber(value) or 0) + 0.5))
			local changed
			repeat
				text, changed = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
			until changed == 0
			return "$" .. text
		end
		Data._foundation = function()
			return {
				FormatFullMoney = format,
				FormatFreeRoamMoney = format,
				FormatCompactMoney = function(value)
					value = tonumber(value) or 0
					if value >= 1000000 then
						return string.format("$%.1fM", value / 1000000)
					end
					return format(value)
				end,
			}
		end
		local ok, detail = pcall(body)
		Data._foundation = original
		if not ok then
			error(detail, 0)
		end
	end

	local function mount(entry, props, preset)
		local stage = env.Detached("Frame")
		stage.Name = "Stage"
		stage.Size = UDim2.fromOffset(PRESETS[preset].Size.X, PRESETS[preset].Size.Y)
		local ctx = Metrics.Fixed(PRESETS[preset])
		Metrics.Bind(stage, ctx)
		local scope = env.Scope()
		local component = entry.Mount(stage, props, scope, ctx)
		return stage, component, scope
	end

	-- Everything a render could have changed, as one string.
	local function snapshot(root)
		local lines = {}
		for _, instance in ipairs(root:GetDescendants()) do
			local line = instance.ClassName .. ":" .. instance:GetFullName()
			if instance:IsA("GuiObject") then
				line ..= "|" .. tostring(instance.Visible) .. "|" .. tostring(instance.Size) .. "|" .. tostring(instance.Position)
					.. "|" .. tostring(instance.BackgroundTransparency) .. "|" .. tostring(instance.BackgroundColor3)
			end
			if instance:IsA("TextLabel") or instance:IsA("TextButton") then
				line ..= "|" .. instance.Text .. "|" .. tostring(instance.TextColor3)
			end
			if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
				line ..= "|" .. instance.Image .. "|" .. tostring(instance.ImageRectOffset) .. "|" .. tostring(instance.ImageColor3)
			end
			table.insert(lines, line)
		end
		return table.concat(lines, "\n")
	end

	-- Budget count (API1 7): descendants, without glows and text-size locks.
	local function budget(root)
		local count = 0
		for _, instance in ipairs(root:GetDescendants()) do
			if not instance:IsA("UITextSizeConstraint") and instance.Name ~= "Glow" then
				count += 1
			end
		end
		return count
	end

	local resultsItem = item("RaceSession.Results")
	-- The stage layer adds its own Root and slot frames; they are not part of the results budget of 150.
	local STAGE_ALLOWANCE = 40

	case("helpers: _signature, _stripText, _xpText", function()
		local a = M._signature({ { Key = "row1", Columns = { "1", "A" }, You = false } })
		expect(a == M._signature({ { Key = "row1", Columns = { "1", "A" }, You = false } }), "stable")
		expect(a ~= M._signature({ { Key = "row1", Columns = { "1", "A" }, You = true } }), "own row")
		local text = M._stripText({ { Label = "FINISH", Value = "2ND PLACE", Kind = "Text" }, { Label = "", Value = "CHIP", Kind = "Chip" },
			{ Label = "", Value = "GOLD", Kind = "Text" } })
		expect(text == "FINISH 2ND PLACE" .. M.STRIP_SEPARATOR .. "GOLD", text)
		local label, number = M._xpText({ State = "Xp", Gain = 120 })
		expect(label == "DRIVER XP" and number == "+120", tostring(label) .. " " .. tostring(number))
		label, number = M._xpText({ State = "Rank", Rank = 12, RankGain = 1 })
		expect(label == "RANK UP" and number == "12", "rank")
		expect(M._xpText({ State = "Pending" }) == nil and M._xpText({ State = "Hidden" }) == nil, "nothing to show")
	end)

	for _, preset in ipairs({ "R1080", "C844" }) do
		for _, state in ipairs(resultsItem.States) do
			case(preset .. " " .. state.Id .. ": mounts, within budget, a second render changes nothing, destroy is clean", function()
				withMoney(function()
					local stage, component, scope = mount(resultsItem, state.Props, preset)
					local count = budget(stage)
					expect(count <= 150 + STAGE_ALLOWANCE, "results budget 150: " .. tostring(count))
					local before = snapshot(stage)
					local instances = #stage:GetDescendants()
					component.Set({})
					component.Set(state.Props)
					expect(#stage:GetDescendants() == instances, "a second render creates and destroys nothing")
					expect(snapshot(stage) == before, "a second render changes no property")
					expect(pcall(component.Set, { NoSuchKey = true }) == false, "an unknown key errors")
					component.Destroy()
					scope:destroy()
				end)
			end)
		end

		case(preset .. ": every state through one mounted view; a state change creates and destroys nothing", function()
			withMoney(function()
				local stage, component, scope = mount(resultsItem, resultsItem.States[1].Props, preset)
				-- The pooled table and fact list grow to their largest state first; after that nothing is created.
				for _, state in ipairs(resultsItem.States) do
					if state.Props.Open ~= false then
						component.Set(state.Props)
					end
				end
				local instances = #stage:GetDescendants()
				for _, state in ipairs(resultsItem.States) do
					if state.Props.Open ~= false then
						component.Set(state.Props)
						expect(#stage:GetDescendants() == instances, state.Id .. ": instance count changed")
					end
				end
				component.Destroy()
				scope:destroy()
			end)
		end)
	end

	case("the two buttons exist while the leaderboard is loading, with the Classic texts", function()
		withMoney(function()
			local loading
			for _, state in ipairs(resultsItem.States) do
				if state.Id == "TimeTrialLoadingBoard" then
					loading = state
				end
			end
			local stage, component, scope = mount(resultsItem, loading.Props, "R1080")
			local footer = stage:FindFirstChild("Footer", true)
			expect(footer ~= nil, "footer row")
			local exit, again = false, false
			for _, instance in ipairs(footer:GetDescendants()) do
				if instance:IsA("TextLabel") or instance:IsA("TextButton") then
					exit = exit or string.find(instance.Text, "EXIT TO START", 1, true) ~= nil
					again = again or string.find(instance.Text, "TRY AGAIN", 1, true) ~= nil
				end
			end
			expect(exit and again, "EXIT TO START and TRY AGAIN are drawn")
			component.Destroy()
			scope:destroy()
		end)
	end)

	case("the hidden state hides the layer root; a race with no XP hides the secondary number", function()
		withMoney(function()
			local stage, component, scope = mount(resultsItem, { Open = false }, "R1080")
			expect(component.Instance.Visible == false, "hidden")
			for _, state in ipairs(resultsItem.States) do
				if state.Id == "RaceNoXp" then
					component.Set(state.Props)
					component.Set({ Open = true })
				end
			end
			expect(component.Instance.Visible == true, "shown")
			expect(stage:FindFirstChild("Secondary", true).Visible == false, "no XP: the driver XP number is hidden")
			component.Set({ Xp = { State = "Xp", Gain = 120 } })
			expect(stage:FindFirstChild("Secondary", true).Visible == true, "XP arrived: shown")
			component.Destroy()
			scope:destroy()
		end)
	end)

	-- The view mounted directly over a hand-written model, so a test can make any part of it fail.
	local Layers = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Layers")
	local function mountOver(model, preset)
		local stage = env.Detached("Frame")
		stage.Name = "Stage"
		stage.Size = UDim2.fromOffset(PRESETS[preset].Size.X, PRESETS[preset].Size.Y)
		local ctx = Metrics.Fixed(PRESETS[preset])
		Metrics.Bind(stage, ctx)
		local layer = Layers.Stage(stage, ctx, "Menu")
		local scope = env.Scope()
		local view = M.Mount(layer, model, scope, { NoPresence = true })
		return stage, layer, view, scope
	end
	local function footerTexts(stage)
		local texts = {}
		local footer = stage:FindFirstChild("Footer", true)
		for _, instance in ipairs(footer and footer:GetDescendants() or {}) do
			if instance:IsA("TextLabel") then
				table.insert(texts, instance.Text)
			end
		end
		return table.concat(texts, "|")
	end
	local function plainModel(overrides)
		local model = {
			IsOpen = function()
				return true
			end,
			Mode = function()
				return "TimeTrial"
			end,
			Busy = function()
				return false
			end,
			Title = function()
				return "TIME TRIAL COMPLETE"
			end,
			SubTitle = function()
				return "SHOWROOM LOOP"
			end,
			RewardAmount = function()
				return 1500
			end,
			BestLapText = function()
				return "1:11.250"
			end,
			AgainText = function()
				return "TRY AGAIN"
			end,
			ExitText = function()
				return "EXIT TO START"
			end,
			Xp = function()
				return { State = "Hidden" }
			end,
			Strip = function()
				return { { Label = "", Value = "FINISHED", Kind = "Text" } }
			end,
			Facts = function()
				return "SESSION LAPS", { { Id = "fact1", Label = "01", Value = "1:11.250  BEST", Kind = "Text" } }
			end,
			Table = function()
				return { Heading = "GLOBAL TOP 20", Header = { "POS", "PLAYER", "TIME", "VEHICLE" }, Rows = {}, Message = "" }
			end,
			Exit = function() end,
			Again = function() end,
		}
		for key, value in pairs(overrides or {}) do
			model[key] = value
		end
		return model
	end

	case("helpers: _money falls back when the Classic formatter is missing; _columns cuts for Compact", function()
		local original = Data._foundation
		Data._foundation = function()
			error("ResponsiveUIFoundation was not found")
		end
		local ok, detail = pcall(function()
			expect(M._money(1234567, false) == "$1,234,567", M._money(1234567, false))
			expect(M._money(nil, false) == "$0" and M._money(-5, true) == "$0", "nil and negative")
		end)
		Data._foundation = original
		expect(ok, tostring(detail))
		local cut = M._columns({ "1", "OSCAR", "3:08.400", "SERAPH" }, M.COMPACT_COLUMNS)
		expect(#cut == 3 and cut[3] == "3:08.400", "position, player, time")
		local whole = { "1", "OSCAR" }
		expect(M._columns(whole, math.huge) == whole, "untouched when it fits")
		expect(M._guard("test part", function()
			error("expected by the test")
		end) == false, "a failed part is reported, not raised")
	end)

	for _, preset in ipairs({ "R1080", "C844" }) do
		case(preset .. ": every optional part failing still shows the layer with both buttons set", function()
			local function fail()
				error("expected by the test")
			end
			local original = Data._foundation
			Data._foundation = fail
			local ok, detail = pcall(function()
				local stage, layer, view, scope = mountOver(plainModel({ Title = fail, SubTitle = fail, RewardAmount = fail,
					BestLapText = fail, Xp = fail, Strip = fail, Facts = fail, Table = fail }), preset)
				view.Render("test")
				expect(layer.Root.Visible == true, "shown")
				local texts = footerTexts(stage)
				expect(string.find(texts, "EXIT TO START", 1, true) ~= nil, "exit button: " .. texts)
				expect(string.find(texts, "TRY AGAIN", 1, true) ~= nil, "again button: " .. texts)
				local exit = view._parts().Buttons.Button("exit")
				expect(exit ~= nil and exit.Instance.Active == true, "the exit button is live")
				view.Destroy()
				scope:destroy()
				layer.Destroy()
			end)
			Data._foundation = original
			expect(ok, tostring(detail))
		end)
	end

	case("the player's row keeps one list key, so the selection follows it between results", function()
		withMoney(function()
			local rows = {
				{ Key = "row1", Columns = { "6", "VANTA", "1:00.027", "ENDURA" }, You = false },
				{ Key = "row2", Columns = { "7", "OSCAR", "1:01.842", "AURORA" }, You = true },
				{ Key = "row3", Columns = { "8", "LOWLIGHT", "1:02.618", "AURORA" }, You = false },
			}
			local stage, layer, view, scope = mountOver(plainModel({ Table = function()
				return { Heading = "GLOBAL TOP 20", Header = { "POS", "PLAYER", "TIME", "VEHICLE" }, Rows = rows, Message = "" }
			end }), "R1080")
			view.Render("test")
			local list = view._parts().Table
			expect(list.Row(M.YOU_KEY) ~= nil and list.Row("row2") == nil, "own row under the one key")
			-- A later race result where the player is first: the old selection must not stay on the second row.
			rows = {
				{ Key = "row1", Columns = { "1", "OSCAR", "3:08.400", "SERAPH" }, You = true },
				{ Key = "row2", Columns = { "2", "VANTA", "RACING", "ENDURA" }, You = false },
			}
			view.Render("test")
			local own, other = list.Row(M.YOU_KEY), list.Row("row2")
			expect(own ~= nil and other ~= nil, "both rows")
			expect(own.Instance.Position.Y.Offset < other.Instance.Position.Y.Offset, "own row is the first row")
			expect(stage ~= nil, "stage")
			view.Destroy()
			scope:destroy()
			layer.Destroy()
		end)
	end)

	case("Compact draws three table columns (position, player, time); Regular draws four", function()
		withMoney(function()
			for _, spec in ipairs({ { "C844", 3 }, { "R1080", 4 } }) do
				local stage, layer, view, scope = mountOver(plainModel({ Table = function()
					return { Heading = "RACE RESULTS", Header = { "POS", "PLAYER", "FINISH TIME", "VEHICLE" }, Rows = {
						{ Key = "row1", Columns = { "1", "OSCAR", "3:08.400", "SERAPH" }, You = true },
					}, Message = "" }
				end }), spec[1])
				view.Render("test")
				local header = stage:FindFirstChild("Header", true)
				local list = stage:FindFirstChild("List", true)
				expect(list ~= nil, "list")
				header = list:FindFirstChild("Header")
				local shownColumns = 0
				for _, label in ipairs(header:GetChildren()) do
					if label:IsA("TextLabel") and label.Visible then
						shownColumns += 1
					end
				end
				expect(shownColumns == spec[2], spec[1] .. " header columns: " .. tostring(shownColumns))
				view.Destroy()
				scope:destroy()
				layer.Destroy()
			end
		end)
	end)

	return results
end
