-- Pure tests for RaceSession.ResultsClient. start() is never called here: it claims the surface, waits for PlayerGui
-- and the racing remotes and creates the UnifiedRaceResults ScreenGuis, which is a Play check (NOTES.md).
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

	case("owner shape: start exists and nothing ran at require", function()
		expect(type(M) == "table" and type(M.start) == "function", "start")
		expect(M.Controller == nil, "no Controller before start")
	end)

	case("_bindable: found under the Classic folder, only a BindableEvent, nil when absent", function()
		local runtime = env.Detached("Folder")
		local racing = Instance.new("Folder")
		racing.Name = "Racing"
		racing.Parent = runtime
		local ui = Instance.new("Folder")
		ui.Name = "UI"
		ui.Parent = runtime
		expect(M._bindable(runtime, "StartRaceQueueRequest") == nil, "absent")
		local start = Instance.new("BindableEvent")
		start.Name = "StartRaceQueueRequest"
		start.Parent = racing
		local exited = Instance.new("BindableEvent")
		exited.Name = "FreeRoamVehicleExited"
		exited.Parent = ui
		local wrong = Instance.new("Folder")
		wrong.Name = "FreeRoamHudPresentationMode"
		wrong.Parent = ui
		expect(M._bindable(runtime, "StartRaceQueueRequest") == start, "Runtime.Racing")
		expect(M._bindable(runtime, "FreeRoamVehicleExited") == exited, "Runtime.UI")
		expect(M._bindable(runtime, "FreeRoamHudPresentationMode") == nil, "not a BindableEvent")
		expect(M._bindable(runtime, "RaceTransitionRequest") == nil, "absent in its folder")
		expect(M._bindable(runtime, "SomethingElse") == nil, "a name this owner does not use")
	end)

	case("the four bindables and their folders", function()
		local folders = M._bindableFolders
		expect(folders.RaceTransitionRequest == "Racing" and folders.StartRaceQueueRequest == "Racing", "Racing")
		expect(folders.FreeRoamHudPresentationMode == "UI" and folders.FreeRoamVehicleExited == "UI", "UI")
		local count = 0
		for _ in pairs(folders) do
			count += 1
		end
		expect(count == 4, "no other bindable")
	end)

	return results
end
