-- Pure tests for Garage.GarageClient. start() is never called here: it claims the surface, waits for the runtime
-- folders and remotes and creates two ScreenGuis, which is a Play check (API2 5.7 gates).
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
		expect(type(M) == "table" and type(M.start) == "function", "start is a function")
		expect(M.Controller == nil, "no Controller before start")
	end)

	case("entries: the three Classic events and their modes, one each", function()
		local wanted = {
			OpenGarageFromIntro = "Dealership",
			OpenOwnedCockpitCustomisation = "Customisation",
			OpenDrivingVehicleCustomisation = "DriveIn",
		}
		expect(#M._entries == 3, "three entries")
		local seen = {}
		for _, entry in ipairs(M._entries) do
			expect(wanted[entry.Event] == entry.Mode, entry.Event .. " -> " .. tostring(entry.Mode))
			expect(not seen[entry.Event], "duplicate " .. entry.Event)
			seen[entry.Event] = true
		end
	end)

	case("intro event: created with the Classic name and class when missing", function()
		local folder = env.Detached("Folder")
		local event = M._introEvent(folder, "OpenGarageFromIntro")
		expect(event.ClassName == "BindableEvent" and event.Name == "OpenGarageFromIntro" and event.Parent == folder, "created")
		expect(#folder:GetChildren() == 1, "one child")
	end)

	case("intro event: an existing one is adopted with its connections, not duplicated", function()
		local folder = env.Detached("Folder")
		local existing = Instance.new("BindableEvent")
		existing.Name = "OpenOwnedCockpitCustomisation"
		existing.Parent = folder
		expect(M._introEvent(folder, "OpenOwnedCockpitCustomisation") == existing, "adopted")
		expect(M._introEvent(folder, "OpenOwnedCockpitCustomisation") == existing and #folder:GetChildren() == 1, "still one")
	end)

	case("intro event: an instance of the wrong class is replaced, as Classic does", function()
		local folder = env.Detached("Folder")
		local wrong = Instance.new("Folder")
		wrong.Name = "OpenDrivingVehicleCustomisation"
		wrong.Parent = folder
		local event = M._introEvent(folder, "OpenDrivingVehicleCustomisation")
		expect(event:IsA("BindableEvent") and wrong.Parent == nil and #folder:GetChildren() == 1, "replaced")
	end)

	case("protected draw: a clean render reports nothing and starts no recovery", function()
		local reports, recoveries, seen = 0, 0, nil
		local draw = M._protect(function(reason)
			seen = reason
		end, function()
			reports += 1
		end, function()
			recoveries += 1
		end)
		expect(draw("render") == true and seen == "render", "rendered with the reason")
		expect(reports == 0 and recoveries == 0, "quiet")
	end)

	case("protected draw: a fault is reported with its error and recovery runs once until it says done", function()
		local reports, recoveries, finish = {}, 0, nil
		local fail = true
		local draw = M._protect(function()
			if fail then
				error("unknown prop Colour", 0)
			end
		end, function(message)
			table.insert(reports, tostring(message))
		end, function(done)
			recoveries += 1
			finish = done
		end)
		expect(draw("render") == false, "fault returns false, does not throw")
		expect(#reports == 1 and reports[1] == "unknown prop Colour", "error text passed on")
		expect(recoveries == 1, "recovery started")
		expect(draw("render") == false and recoveries == 1 and #reports == 2, "a fault during recovery (the closing draw) starts no second one")
		finish()
		expect(draw("render") == false and recoveries == 2, "the next session's fault recovers again")
		finish()
		fail = false
		expect(draw("render") == true and recoveries == 2, "a clean draw afterwards")
	end)

	return results
end
