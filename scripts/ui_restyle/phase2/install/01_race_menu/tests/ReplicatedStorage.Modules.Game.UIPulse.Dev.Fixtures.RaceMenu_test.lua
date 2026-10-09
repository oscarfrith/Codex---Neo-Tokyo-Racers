-- Pure tests for Dev.Fixtures.RaceMenu: the registration shape the gallery reads (API1 section 10) and the state list
-- API2 6.3 asks for. Mounting every state is covered by the RaceMenuView test.
return function(M, _env)
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

	case("registration shape", function()
		expect(type(M) == "table" and #M == 1, "one gallery item")
		local item = M[1]
		expect(item.Id == "RaceMenu.Screen", "id")
		expect(item.Frame == "Menu" and item.Slot == nil, "Menu frame, mounted on the whole stage")
		expect(type(item.Mount) == "function", "Mount")
		expect(type(item.States) == "table" and #item.States > 0, "states")
	end)

	case("states: unique ids, table props, the required set", function()
		local seen = {}
		for _, state in ipairs(M[1].States) do
			expect(type(state.Id) == "string" and not seen[state.Id], "duplicate or missing state id " .. tostring(state.Id))
			expect(type(state.Props) == "table" and type(state.Props.Rows) == "table", state.Id .. " has rows")
			seen[state.Id] = true
		end
		for _, id in ipairs({ "Default", "Empty", "LongStrings", "CompactDetail", "Teleporting", "TeleportFailed", "NoRoute", "FilterTimeTrials", "FilterRaces" }) do
			expect(seen[id], "missing state " .. id)
		end
		expect(M[1].States[1].Id == "Default", "Default is first")
	end)

	case("fixture rows name no asset and follow the Classic Primary rule", function()
		for _, state in ipairs(M[1].States) do
			for _, row in ipairs(state.Props.Rows) do
				for _, mode in ipairs({ "TimeTrial", "Race" }) do
					local summary = row[mode]
					if summary then
						expect(summary.TrackImage == "" and summary.MapImage == "", state.Id .. ": fixtures name no asset")
					end
				end
				expect(row.Primary == (row.TimeTrial or row.Race), state.Id .. ": Primary is the time trial when present")
			end
		end
	end)

	return results
end
