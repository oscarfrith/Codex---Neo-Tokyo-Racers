-- Pure tests for RaceSession.QueueClient: the headless queue model driven by bindable and RaceQueueEvent fixtures with
-- a fake remote. start() is never called here (it claims the surface, creates a ScreenGui and connects the bindable).
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

	local function keys(payload)
		local list = {}
		for key in pairs(payload) do
			table.insert(list, key)
		end
		table.sort(list)
		return table.concat(list, ",")
	end

	local function harness()
		local log = { calls = {}, fires = {}, delays = {}, defers = {}, streams = {}, attributes = {}, writes = {}, replies = {},
			renders = 0, order = {} }
		local request = {}
		function request:InvokeServer(action, payload)
			table.insert(log.calls, { action = action, payload = payload })
			table.insert(log.order, "call:" .. action)
			if log.duringCall then
				log.duringCall()
			end
			local reply = log.replies[action]
			if reply == "error" then
				error("remote failed")
			end
			return reply
		end
		local bindables = {}
		for _, name in ipairs({ "FreeRoamHudPresentationMode", "FreeRoamVehicleSpawned" }) do
			local fake = {}
			function fake:Fire(payload)
				table.insert(log.fires, { name = name, payload = payload })
			end
			bindables[name] = fake
		end
		local model = M._new({
			Request = request,
			Bindable = function(name)
				return bindables[name]
			end,
			SetAttribute = function(name, value)
				log.attributes[name] = value
				table.insert(log.writes, name)
				table.insert(log.order, "attribute:" .. name)
			end,
			GetAttribute = function(name)
				return log.attributes[name]
			end,
			Stream = function(routeId, index)
				table.insert(log.streams, { routeId = routeId, index = index })
			end,
			Defer = function(fn, ...)
				table.insert(log.defers, { fn = fn, args = { ... } })
			end,
			Delay = function(seconds, fn)
				table.insert(log.delays, { seconds = seconds, fn = fn })
			end,
			Render = function()
				log.renders += 1
			end,
		})
		local function fired(name)
			local list = {}
			for _, entry in ipairs(log.fires) do
				if entry.name == name then
					table.insert(list, entry.payload)
				end
			end
			return list
		end
		return model, log, fired
	end

	case("owner shape: start exists and nothing ran at require", function()
		expect(type(M) == "table" and type(M.start) == "function", "start")
		expect(M.Controller == nil, "no Controller before start")
	end)

	case("start request: attributes first, then JoinQueue with the Classic keys", function()
		local model, log, fired = harness()
		log.replies.JoinQueue = { Ok = true }
		local seen = nil
		log.duringCall = function()
			seen = { status = model.View().Status, visible = model.View().Visible }
		end
		model.Start({ EventId = "canal", VehicleId = "seraph", DisplayName = "Shifted Canal Sprint" })
		expect(table.concat(log.order, " ") == "attribute:LastRacingEventId attribute:LastRacingVehicleId call:JoinQueue",
			table.concat(log.order, " "))
		expect(log.attributes.LastRacingEventId == "canal" and log.attributes.LastRacingVehicleId == "seraph", "attribute values")
		expect(#log.calls == 1 and keys(log.calls[1].payload) == "EventId,VehicleId", keys(log.calls[1].payload))
		expect(log.calls[1].payload.EventId == "canal" and log.calls[1].payload.VehicleId == "seraph", "payload values")
		expect(seen.status == "JOINING QUEUE" and seen.visible == true, "the banner shows JOINING QUEUE before the call returns")
		expect(model.View().Title == "SHIFTED CANAL SPRINT" and model.Queued(), "title")
		local mode = fired("FreeRoamHudPresentationMode")
		expect(#mode == 1 and mode[1].Owner == "RaceQueue" and mode[1].Active == true and mode[1].KeepTelemetry == true, "owner")
		expect(keys(mode[1]) == "Active,KeepTelemetry,Owner", keys(mode[1]))
		expect(#log.delays == 0, "no failure timer")
	end)

	case("start request: a payload that is not a table writes empty ids, as Classic", function()
		local model, log = harness()
		log.replies.JoinQueue = { Ok = true }
		model.Start(nil)
		expect(log.attributes.LastRacingEventId == "" and log.attributes.LastRacingVehicleId == "", "empty strings")
		expect(model.View().Title == "RACE QUEUE", model.View().Title)
		expect(next(log.calls[1].payload) == nil, "no keys with nil values")
	end)

	case("join failure: message, then hidden after 2 s unless the server has queued the player", function()
		local model, log, fired = harness()
		log.replies.JoinQueue = { Ok = false, Message = "Vehicle not allowed" }
		model.Start({ EventId = "canal", VehicleId = "seraph" })
		expect(model.View().Status == "VEHICLE NOT ALLOWED" and model.View().Visible, model.View().Status)
		expect(#log.delays == 1 and log.delays[1].seconds == 2, "2 s")
		log.delays[1].fn()
		expect(model.View().Visible == false and not model.Queued(), "hidden")
		local mode = fired("FreeRoamHudPresentationMode")
		expect(#mode == 2 and mode[2].Active == false, "owner released once")

		local kept, keptLog = harness()
		keptLog.replies.JoinQueue = "error"
		kept.Start({ EventId = "canal", VehicleId = "seraph" })
		expect(kept.View().Visible and string.find(kept.View().Status, "REMOTE FAILED", 1, true) ~= nil, kept.View().Status)
		keptLog.attributes.RaceQueueActive = true
		keptLog.delays[1].fn()
		expect(kept.View().Visible == true, "RaceQueueActive keeps the banner")

		local silent, silentLog = harness()
		silentLog.replies.JoinQueue = {}
		silent.Start({})
		expect(silent.View().Status == "QUEUE FAILED", silent.View().Status)
	end)

	case("queue events: update text, hide kinds, presentation owner fired on change only", function()
		local model, log, fired = harness()
		model.Handle({ Type = "QueueJoined", EventId = "canal", DisplayName = "Shifted Canal Sprint", Count = 1, MinPlayers = 2,
			MaxPlayers = 6, SecondsRemaining = 0, Message = "Waiting for players" })
		local view = model.View()
		expect(view.Visible and view.Title == "SHIFTED CANAL SPRINT" and view.Status == "WAITING FOR PLAYERS", "joined")
		expect(view.Players == "1 / 6" and view.Starts == "0s", view.Players .. " " .. view.Starts)
		model.Handle({ Type = "QueueUpdate", Count = 2, MaxPlayers = 6, SecondsRemaining = 25 })
		expect(view.Players == "2 / 6" and view.Starts == "25s", "update")
		expect(view.Title == "SHIFTED CANAL SPRINT", "the name is kept when an update has none")
		expect(view.Status == "WAITING FOR RACERS", "the Classic default status")
		expect(#fired("FreeRoamHudPresentationMode") == 1, "one fire for two shows")
		for _, kind in ipairs({ "QueueLeft", "RaceQueueError", "RaceStaged", "RaceFinished", "RaceDNF", "RaceEnded", "RaceExitedToStart" }) do
			local other, _, otherFired = harness()
			other.Handle({ Type = "QueueUpdate", Count = 1, MaxPlayers = 6 })
			other.Handle({ Type = kind })
			expect(other.View().Visible == false and not other.Queued(), kind)
			local mode = otherFired("FreeRoamHudPresentationMode")
			expect(#mode == 2 and mode[2].Active == false and mode[2].Owner == "RaceQueue" and mode[2].KeepTelemetry == true, kind)
			other.Handle({ Type = kind })
			expect(#otherFired("FreeRoamHudPresentationMode") == 2, kind .. ": a second hide fires nothing")
		end
		local idle, _, idleFired = harness()
		idle.Handle({ Type = "RaceStaged" })
		idle.Handle(nil)
		idle.Handle({ Type = "RacePositionUpdate" })
		expect(#idleFired("FreeRoamHudPresentationMode") == 0, "hiding a hidden banner fires nothing")
		expect(log.renders > 0, "rendered")
	end)

	case("race started: hide, stream the first gate, driving hand-off now and after 0.25 s", function()
		local model, log, fired = harness()
		model.Handle({ Type = "QueueUpdate", Count = 2, MaxPlayers = 6 })
		model.Handle({ Type = "RaceStarted", RouteId = "canal_route", NextGateIndex = 3 })
		expect(model.View().Visible == false, "hidden")
		expect(#log.defers == 2 and #log.delays == 1 and log.delays[1].seconds == 0.25, "two deferred, one delayed")
		expect(#fired("FreeRoamVehicleSpawned") == 0, "nothing fired before the defer")
		for _, entry in ipairs(log.defers) do
			entry.fn(table.unpack(entry.args))
		end
		expect(#log.streams == 1 and log.streams[1].routeId == "canal_route" and log.streams[1].index == 3, "stream request")
		expect(#fired("FreeRoamVehicleSpawned") == 1, "hand-off")
		log.delays[1].fn()
		expect(#fired("FreeRoamVehicleSpawned") == 2, "hand-off again")
		local second, secondLog = harness()
		second.Handle({ Type = "RaceStarted", RouteId = "canal_route" })
		secondLog.defers[1].fn(table.unpack(secondLog.defers[1].args))
		expect(secondLog.streams[1].index == 1, "gate 1 when the payload has no index")
	end)

	case("leave: only while queued, LeaveQueue with an empty payload, button disabled during the call", function()
		local model, log = harness()
		model.Leave()
		expect(#log.calls == 0, "not queued: nothing sent")
		model.Handle({ Type = "QueueUpdate", Count = 2, MaxPlayers = 6 })
		local seen = nil
		log.duringCall = function()
			seen = { enabled = model.View().LeaveEnabled, status = model.View().Status }
		end
		log.replies.LeaveQueue = { Ok = true }
		model.Leave()
		expect(#log.calls == 1 and log.calls[1].action == "LeaveQueue" and next(log.calls[1].payload) == nil, "call")
		expect(seen.enabled == false and seen.status == "LEAVING QUEUE", "during the call")
		expect(model.View().LeaveEnabled == true, "enabled again")
		expect(model.View().Visible == true, "the banner stays until the server says QueueLeft (Classic)")
		log.replies.LeaveQueue = { Ok = false, Message = "Too late" }
		model.Leave()
		expect(model.View().Status == "TOO LATE", model.View().Status)
		log.replies.LeaveQueue = { Success = false }
		model.Leave()
		expect(model.View().Status == "LEAVE FAILED", model.View().Status)
	end)

	case("view: mounts on a detached stage at R1080 and C844; render twice creates nothing", function()
		local Metrics = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Metrics")
		local Layers = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Layers")
		for _, spec in ipairs({ { Size = Vector2.new(1920, 1080), TouchEnabled = false }, { Size = Vector2.new(844, 390), TouchEnabled = true } }) do
			local stage = env.Detached("Frame")
			stage.Size = UDim2.fromOffset(spec.Size.X, spec.Size.Y)
			local ctx = Metrics.Fixed(spec)
			Metrics.Bind(stage, ctx)
			local layer = Layers.Stage(stage, ctx, "Hud")
			local scope = env.Scope()
			local pressed = 0
			local view = M._mountView(layer, scope, { OnLeave = function()
				pressed += 1
			end })
			expect(view.Instance.Name == "QueueBanner", "the Classic banner name")
			local state = { Visible = true, Title = "THE LONGEST EVENT NAME IN THE CATALOGUE", Status = "JOINING QUEUE", Players = "16 / 16",
				Starts = "120s", LeaveEnabled = true }
			view.Render(state)
			expect(layer.Root.Visible == true, "shown")
			local count = #view.Instance:GetDescendants()
			view.Render(state)
			state.LeaveEnabled = false
			state.Status = "LEAVING QUEUE"
			view.Render(state)
			expect(#view.Instance:GetDescendants() == count, "no instance created or destroyed")
			expect(view.Instance:FindFirstChild("Leave", true) ~= nil, "the leave button")
			view.Render({ Visible = false })
			expect(layer.Root.Visible == false, "hidden through the layer")
			view.Destroy()
			view.Destroy()
			scope:destroy()
			layer.Destroy()
		end
	end)

	return results
end
