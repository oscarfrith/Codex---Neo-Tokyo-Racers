-- Pure tests for Dev.Fixtures.RaceSession: the registration shape, and the countdown, queue and wrong-way items mounted
-- in every state at R1080 and C844 (the HUD and results items are exercised by the two view tests).
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
	local Fixtures = M

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


	case("registration: five items with unique ids, a frame, states and a mount function", function()
		expect(type(M) == "table" and #M == 5, "five items")
		local seen = {}
		for _, entry in ipairs(M) do
			expect(type(entry.Id) == "string" and not seen[entry.Id], "unique id " .. tostring(entry.Id))
			seen[entry.Id] = true
			expect(entry.Frame == "Hud" or entry.Frame == "Menu", entry.Id .. " frame")
			expect(type(entry.Mount) == "function", entry.Id .. " mount")
			expect(type(entry.States) == "table" and #entry.States >= 2, entry.Id .. " states")
			local stateIds = {}
			for _, state in ipairs(entry.States) do
				expect(type(state.Id) == "string" and not stateIds[state.Id], entry.Id .. " state id")
				stateIds[state.Id] = true
				expect(type(state.Props) == "table", entry.Id .. "." .. state.Id .. " props")
			end
		end
		for _, id in ipairs({ "RaceSession.RaceHud", "RaceSession.Countdown", "RaceSession.QueueBanner", "RaceSession.WrongWay",
			"RaceSession.Results" }) do
			expect(seen[id], id)
		end
	end)

	case("results fixtures cover every result state (API2 5.5 gate)", function()
		local ids = {}
		for _, state in ipairs(item("RaceSession.Results").States) do
			ids[state.Id] = true
		end
		for _, id in ipairs({ "RaceXp", "RaceXpPending", "RaceNoXp", "RaceRankUp", "RaceNoReward", "RaceExiting", "RaceExitFailed",
			"TimeTrialPersonalBest", "TimeTrialFinished", "TimeTrialQuit", "TimeTrialLoadingBoard", "TimeTrialEmptyBoard",
			"TimeTrialBoardUnavailable", "TimeTrialTryAgainBusy", "Longest", "Hidden" }) do
			expect(ids[id], id)
		end
	end)

	case("HUD fixtures cover race, time trial, the exit confirmation, the button labels and hidden", function()
		local ids = {}
		for _, state in ipairs(item("RaceSession.RaceHud").States) do
			ids[state.Id] = true
		end
		for _, id in ipairs({ "Race", "RaceStagedNoPosition", "RaceSlowerLap", "RaceLongest", "TimeTrial", "TimeTrialEndless",
			"TimeTrialNoBest", "ResetDone", "ExitConfirmRace", "ExitConfirmTimeTrial", "Hidden" }) do
			expect(ids[id], id)
		end
	end)

	for _, id in ipairs({ "RaceSession.Countdown", "RaceSession.QueueBanner", "RaceSession.WrongWay" }) do
		for _, preset in ipairs({ "R1080", "C844" }) do
			case(id .. " " .. preset .. ": every state mounts, Set is stable, unknown keys error, destroy is clean", function()
				local entry = item(id)
				for _, state in ipairs(entry.States) do
					local stage, component, scope = mount(entry, state.Props, preset)
					local before = snapshot(stage)
					component.Set(state.Props)
					expect(snapshot(stage) == before, state.Id .. ": Set with the same props changes nothing")
					expect(pcall(component.Set, { NoSuchKey = true }) == false, state.Id .. ": unknown key")
					component.Destroy()
					component.Destroy()
					scope:destroy()
				end
			end)
		end
	end

	return results
end
