-- Pure tests for Dev.Fixtures.Shell: the registration shape the gallery reads (API1 section 10). Mounting is done by
-- the gallery; the views themselves are mounted in their own test files.
return function(M, _env)
	local results = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local FRAMES = { Hud = true, Menu = true, Scene = true, Bare = true }

	case("registration: three items with unique ids, a frame, states and a Mount function", function()
		expect(type(M) == "table" and #M == 3, "three items")
		local ids = {}
		for _, item in ipairs(M) do
			expect(type(item.Id) == "string" and string.sub(item.Id, 1, 6) == "Shell." and not ids[item.Id], "id " .. tostring(item.Id))
			ids[item.Id] = true
			expect(FRAMES[item.Frame] == true, item.Id .. " frame")
			expect(type(item.Mount) == "function", item.Id .. " Mount")
			expect(type(item.States) == "table" and #item.States >= 1, item.Id .. " states")
			local stateIds = {}
			for _, state in ipairs(item.States) do
				expect(type(state.Id) == "string" and not stateIds[state.Id], item.Id .. " state id " .. tostring(state.Id))
				stateIds[state.Id] = true
				expect(type(state.Props) == "table", item.Id .. "." .. state.Id .. " props")
			end
		end
		expect(ids["Shell.Onboarding"] and ids["Shell.Loading"] and ids["Shell.StartScreen"], "the three Shell screens")
	end)

	case("states: the onboarding states name real pages and cards; loading states cover the Classic status texts", function()
		local pages = { GarageShortcut = 1, PaintShop = 1, TimeTrialSetup = 4, RaceBrowser = 2, GarageHome = 3, Dealership = 4 }
		for _, state in ipairs(M[1].States) do
			local props = state.Props
			if props.Page then
				expect(pages[props.Page] ~= nil, state.Id .. " page " .. tostring(props.Page))
				expect((props.Index or 1) <= pages[props.Page], state.Id .. " card index")
			end
			for _, index in ipairs(props.Order or {}) do
				expect(index >= 1 and index <= 3, state.Id .. " objective index")
			end
		end
		local statuses = {}
		for _, state in ipairs(M[2].States) do
			statuses[state.Props.Status] = true
			expect(state.Props.Progress >= 0 and state.Props.Progress <= 1, state.Id .. " progress")
		end
		expect(statuses["LOADING PULSE RACERS"] and statuses["LOADING WORLD"] and statuses["READY"], "status texts")
	end)

	return results
end
