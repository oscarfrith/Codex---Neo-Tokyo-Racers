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

	return results
end
