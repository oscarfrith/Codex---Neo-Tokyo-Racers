-- Pure tests for Kit.Presence (API2 3.9). No instance, no yield. Every case releases what it opens.
return function(M: any, env: any): { { name: string, ok: boolean, detail: string? } }
	local results = {}
	local function case(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		table.insert(results, { name = "Presence: " .. name, ok = ok, detail = (not ok) and tostring(err) or nil })
	end

	local KINDS = { "FullMenu", "Garage", "Results", "Map", "Modal", "SidePanel", "Race", "Loading" }

	-- Records Changed while fn runs; the listener is always disconnected.
	local function record(fn: () -> ()): { { any } }
		local events = {}
		local connection = M.Changed:Connect(function(surface, kind, open)
			table.insert(events, { surface, kind, open })
		end)
		local ok, err = pcall(fn)
		connection:Disconnect()
		assert(ok, err)
		return events
	end

	local function expectEvent(event: { any }?, surface: string, kind: string, open: boolean)
		assert(event ~= nil, "missing event " .. surface .. " " .. kind .. " " .. tostring(open))
		assert(event[1] == surface and event[2] == kind and event[3] == open,
			string.format("event is (%s, %s, %s)", tostring(event[1]), tostring(event[2]), tostring(event[3])))
	end

	case("nothing is open at first", function()
		assert(M.Any() == false, "Any()")
		for _, kind in ipairs(KINDS) do
			assert(M.Any(kind) == false, kind .. " is open")
		end
		assert(M.Is("RaceBrowser") == false, "Is")
	end)

	case("Open and its release set Any and Is and fire Changed once each", function()
		local release
		local events = record(function()
			release = M.Open("RaceBrowser", "FullMenu")
			assert(type(release) == "function", "Open did not return a release function")
			assert(M.Is("RaceBrowser") == true and M.Any() == true and M.Any("FullMenu") == true, "not open")
			assert(M.Any("Race") == false and M.Is("FullMap") == false, "another kind or surface is open")
			release()
			assert(M.Is("RaceBrowser") == false and M.Any() == false and M.Any("FullMenu") == false, "still open")
		end)
		assert(#events == 2, "expected 2 events, got " .. #events)
		expectEvent(events[1], "RaceBrowser", "FullMenu", true)
		expectEvent(events[2], "RaceBrowser", "FullMenu", false)
	end)

	case("the release function is repeat-safe", function()
		local other = M.Open("FullMap", "Map")
		local events = record(function()
			local release = M.Open("Garage", "Garage")
			release()
			release()
			release()
		end)
		assert(#events == 2, "a repeated release fired again: " .. #events)
		assert(M.Is("FullMap") == true and M.Any("Map") == true and M.Any() == true, "a repeated release closed another surface")
		other()
		assert(M.Any() == false, "left open")
	end)

	case("every kind is accepted; an unknown kind or a bad surface errors and opens nothing", function()
		for _, kind in ipairs(KINDS) do
			local release = M.Open("Surface" .. kind, kind)
			assert(M.Any(kind) == true and M.Is("Surface" .. kind) == true, kind)
			release()
			assert(M.Any(kind) == false, kind .. " stayed open")
		end
		assert(pcall(M.Open, "RaceBrowser", "Menu") == false, "an unknown kind was accepted")
		assert(pcall(M.Open, "RaceBrowser", nil) == false, "a nil kind was accepted")
		assert(pcall(M.Open, "", "Modal") == false, "an empty surface was accepted")
		assert(pcall(M.Open, nil, "Modal") == false, "a nil surface was accepted")
		assert(M.Any() == false and M.Is("RaceBrowser") == false, "a refused Open opened something")
	end)

	case("kinds are counted apart: Race stays open while a menu opens and closes", function()
		local race = M.Open("RaceHud", "Race")
		local modal = M.Open("Settings", "Modal")
		local panel = M.Open("CarPanel", "SidePanel")
		assert(M.Any("Race") and M.Any("Modal") and M.Any("SidePanel"), "three kinds open")
		assert(M.Any("FullMenu") == false and M.Any("Garage") == false, "a kind nobody opened")
		modal()
		assert(M.Any("Modal") == false and M.Any("Race") == true and M.Any("SidePanel") == true, "after the modal closed")
		panel()
		assert(M.Any() == true and M.Any("Race") == true, "only Race is left")
		race()
		assert(M.Any() == false, "left open")
	end)

	case("two surfaces of one kind: the kind stays open until both close", function()
		local events = record(function()
			local first = M.Open("Confirm", "Modal")
			local second = M.Open("Settings", "Modal")
			first()
			assert(M.Any("Modal") == true and M.Is("Confirm") == false and M.Is("Settings") == true, "after the first closed")
			second()
			assert(M.Any("Modal") == false, "after both closed")
		end)
		assert(#events == 4, "expected 4 events, got " .. #events)
		expectEvent(events[3], "Confirm", "Modal", false)
		expectEvent(events[4], "Settings", "Modal", false)
	end)

	case("one surface opened twice stays open until both releases; Changed fires on the edges only", function()
		local events = record(function()
			local first = M.Open("FullMap", "Map")
			local second = M.Open("FullMap", "Map")
			assert(M.Is("FullMap") == true, "open")
			first()
			assert(M.Is("FullMap") == true and M.Any("Map") == true, "closed by the first of two releases")
			first()
			assert(M.Is("FullMap") == true, "a repeated release counted twice")
			second()
			assert(M.Is("FullMap") == false and M.Any("Map") == false and M.Any() == false, "still open")
		end)
		assert(#events == 2, "expected 2 events, got " .. #events)
		expectEvent(events[1], "FullMap", "Map", true)
		expectEvent(events[2], "FullMap", "Map", false)
	end)

	-- Warns once in the output ([Pulse.Presence] ... unknown kind); that line is expected.
	case("Any with an unknown kind is false and does not error", function()
		local release = M.Open("RaceHud", "Race")
		local ok, value = pcall(M.Any, "Menu")
		release()
		assert(ok == true and value == false, "Any(unknown) gave " .. tostring(value))
		assert(M.Is(nil :: any) == false and M.Is(12 :: any) == false, "Is with a non-string")
	end)

	case("Changed is a Luau signal with Connect, Once and Wait, and no instance", function()
		assert(typeof(M.Changed) == "table", "Changed is a " .. typeof(M.Changed))
		assert(type(M.Changed.Connect) == "function" and type(M.Changed.Once) == "function" and type(M.Changed.Wait) == "function", "signal methods")
		local onceCount, liveCount = 0, 0
		local once = M.Changed:Once(function()
			onceCount += 1
		end)
		local live = M.Changed:Connect(function()
			liveCount += 1
		end)
		assert(live.Connected == true and type(live.Disconnect) == "function", "connection shape")
		local release = M.Open("Loading", "Loading")
		release()
		assert(onceCount == 1, "Once ran " .. onceCount .. " times")
		assert(liveCount == 2, "Connect ran " .. liveCount .. " times")
		live:Disconnect()
		live:Disconnect()
		assert(live.Connected == false and once.Connected == false, "connections not released")
		M.Open("Loading", "Loading")()
		assert(liveCount == 2, "a disconnected listener ran")
	end)

	return results
end
