-- Pure tests for RaceSession.CountdownClient: the kind table, the schedule maths and the headless controller driven by
-- payload fixtures with a fake server clock. start() is never called here (it claims the surface and creates a ScreenGui).
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

	local function harness(times)
		local log = { renders = {}, delays = {}, waits = {}, spawned = {}, config = {} }
		local index = 0
		local controller = M._new({
			Now = function()
				index += 1
				return times and times[math.min(index, #times)] or 0
			end,
			Spawn = function(fn)
				table.insert(log.spawned, fn)
			end,
			Delay = function(seconds, fn)
				table.insert(log.delays, { seconds = seconds, fn = fn })
			end,
			Wait = function(seconds)
				table.insert(log.waits, seconds)
			end,
			Config = function(name, fallback)
				local value = log.config[name]
				if value ~= nil then
					return value
				end
				return fallback
			end,
			Render = function(view)
				table.insert(log.renders, { Visible = view.Visible, Heading = view.Heading, Text = view.Text, Go = view.Go })
			end,
		})
		return controller, log
	end

	case("owner shape: start exists and nothing ran at require", function()
		expect(type(M) == "table" and type(M.start) == "function", "start")
		expect(M.Controller == nil, "no Controller before start")
	end)

	case("_kind: exactly the kinds Classic handles (lines 55 to 59)", function()
		local expected = {
			TimeTrialStaged = "hide", RaceStaged = "hide", TimeTrialCountdownReveal = "hide", RaceCountdownReveal = "hide",
			TimeTrialCountdownScheduled = "schedule", RaceCountdownScheduled = "schedule",
			TimeTrialCountdown = "show", RaceCountdown = "show",
			TimeTrialStarted = "go", RaceStarted = "go",
			TimeTrialFinished = "hide", TimeTrialEnded = "hide", TimeTrialError = "hide", RaceFinished = "hide", RaceDNF = "hide",
			RaceEnded = "hide", RaceExitedToStart = "hide", RaceQueueError = "hide",
		}
		for kind, action in pairs(expected) do
			expect(M._kind(kind) == action, kind)
		end
		for _, kind in ipairs({ "RaceCheckpoint", "RacePositionUpdate", "QueueUpdate", "TimeTrialReset", "" }) do
			expect(M._kind(kind) == nil, kind .. " is not handled")
		end
	end)

	case("_maximum and _seconds", function()
		expect(M._maximum(5, 3) == 5 and M._maximum(nil, 3) == 3 and M._maximum("4", 3) == 4, "source")
		expect(M._maximum(0, 3) == 1 and M._maximum(2.9, 3) == 2, "at least one, floored")
		expect(M._seconds(4.2, 5) == 5 and M._seconds(4.0, 5) == 4 and M._seconds(0.01, 5) == 1, "ceil")
		expect(M._seconds(9, 5) == 5, "never above the maximum")
	end)

	case("schedule: counts down against the server clock and stops at GO time", function()
		-- remaining: 4.5, 4.5, 3.9, 3.0, 0.2, then past the start
		local controller, log = harness({ 995.5, 995.5, 996.1, 997.0, 999.8, 1000.5 })
		controller.Handle({ Type = "RaceCountdownScheduled", GoAtServerTime = 1000, Countdown = 5 })
		expect(#log.spawned == 1 and #log.renders == 0, "the loop runs in its own task")
		log.spawned[1]()
		local texts = {}
		for _, render in ipairs(log.renders) do
			expect(render.Visible == true and render.Heading == "GET READY" and render.Go == false, "a number frame")
			table.insert(texts, render.Text)
		end
		expect(table.concat(texts, ",") == "5,4,3,1", table.concat(texts, ","))
		expect(#log.waits == 5 and log.waits[1] == 0.03, "one 0.03 s wait per pass")
	end)

	case("schedule: a later event stops the loop (token)", function()
		local controller, log = harness({ 995.5 })
		controller.Handle({ Type = "TimeTrialCountdownScheduled", GoAtServerTime = 1000, Countdown = 5 })
		controller.Handle({ Type = "TimeTrialEnded" })
		local before = #log.renders
		log.spawned[1]()
		expect(#log.renders == before and #log.waits == 0, "the stale loop draws nothing")
		expect(log.renders[before].Visible == false, "hidden")
	end)

	case("schedule: no GoAtServerTime shows the maximum (payload, then config, then 5)", function()
		local controller, log = harness()
		controller.Handle({ Type = "RaceCountdownScheduled", Countdown = 3 })
		expect(#log.spawned == 0 and log.renders[#log.renders].Text == "3", "payload")
		controller.Handle({ Type = "RaceCountdownScheduled" })
		expect(log.renders[#log.renders].Text == "5", "fallback")
		log.config.CountdownSeconds = 7
		controller.Handle({ Type = "RaceCountdownScheduled" })
		expect(log.renders[#log.renders].Text == "7", "config")
	end)

	case("GO: shown in the go state and hidden after GoDuration unless something newer happened", function()
		local controller, log = harness()
		controller.Handle({ Type = "RaceStarted" })
		local last = log.renders[#log.renders]
		expect(last.Visible and last.Go == true and last.Text == "GO!" and last.Heading == "", "GO frame")
		expect(#log.delays == 1 and log.delays[1].seconds == 0.85, "0.85 s")
		log.delays[1].fn()
		expect(log.renders[#log.renders].Visible == false, "hidden after the delay")

		local second, secondLog = harness()
		secondLog.config.GoDuration = 2
		second.Handle({ Type = "TimeTrialStarted" })
		expect(secondLog.delays[1].seconds == 2, "config duration")
		second.Handle({ Type = "TimeTrialCountdownScheduled", Countdown = 5 })
		local before = #secondLog.renders
		secondLog.delays[1].fn()
		expect(#secondLog.renders == before, "an old GO timer does not hide a newer countdown")
	end)

	case("hide kinds and bad payloads", function()
		local controller, log = harness()
		controller.Handle({ Type = "RaceStarted" })
		controller.Handle({ Type = "RaceFinished" })
		expect(log.renders[#log.renders].Visible == false, "hidden")
		local before = #log.renders
		controller.Handle(nil)
		controller.Handle("RaceStarted")
		controller.Handle({ Type = "RaceCheckpoint" })
		expect(#log.renders == before, "ignored")
		controller.Handle({ Type = "RaceCountdown", Countdown = 2 })
		expect(log.renders[#log.renders].Text == "2" and log.renders[#log.renders].Go == false, "the dead Classic kind still works")
	end)

	case("view: mounts on a detached stage, shows the number, then GO, then hides", function()
		local Metrics = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Metrics")
		local Layers = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Layers")
		for _, spec in ipairs({ { Size = Vector2.new(1920, 1080), TouchEnabled = false }, { Size = Vector2.new(844, 390), TouchEnabled = true } }) do
			local stage = env.Detached("Frame")
			stage.Size = UDim2.fromOffset(spec.Size.X, spec.Size.Y)
			local ctx = Metrics.Fixed(spec)
			Metrics.Bind(stage, ctx)
			local layer = Layers.Stage(stage, ctx, "Hud")
			local scope = env.Scope()
			local view = M._mountView(layer, scope)
			expect(view.Instance.Name == "CountdownCard", "the Classic card name")
			view.Render({ Visible = true, Heading = "GET READY", Text = "3", Go = false })
			local count = #view.Instance:GetDescendants()
			expect(layer.Root.Visible == true, "shown")
			view.Render({ Visible = true, Heading = "GET READY", Text = "3", Go = false })
			view.Render({ Visible = true, Heading = "GET READY", Text = "2", Go = false })
			view.Render({ Visible = true, Heading = "", Text = "GO!", Go = true })
			expect(#view.Instance:GetDescendants() == count, "no instance created or destroyed between frames")
			view.Render({ Visible = false, Heading = "", Text = "GO!", Go = true })
			expect(layer.Root.Visible == false, "hidden through the layer")
			view.Destroy()
			view.Destroy()
			scope:destroy()
			layer.Destroy()
		end
	end)

	return results
end
