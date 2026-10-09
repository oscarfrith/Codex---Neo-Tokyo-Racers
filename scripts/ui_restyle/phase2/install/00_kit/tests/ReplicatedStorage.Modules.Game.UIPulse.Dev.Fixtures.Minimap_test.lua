-- Pure tests for Dev.Fixtures.Minimap: the registration shape of API.md section 10. Nothing is mounted here; the
-- gallery mounts every state at every preset.
return function(M, _env)
	local results = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	case("one item, in the Hud frame and the Minimap slot", function()
		expect(type(M) == "table" and #M == 1, "one item")
		local item = M[1]
		expect(item.Id == "Minimap.Minimap" and item.Frame == "Hud" and item.Slot == "Minimap", "id, frame, slot")
		expect(type(item.Mount) == "function", "Mount")
	end)

	case("state shape", function()
		local ids = {}
		for _, state in ipairs(M[1].States) do
			expect(type(state.Id) == "string" and state.Id ~= "", "state Id")
			expect(not string.find(state.Id, "[|,%s]"), "state Id has no separator or space")
			expect(not ids[state.Id], "duplicate state " .. state.Id)
			ids[state.Id] = true
			expect(type(state.Props) == "table", state.Id .. ": Props")
		end
	end)

	case("states cover an empty and a full rank arc, three digits, a long label, no rank and the square fallback", function()
		local byId = {}
		for _, state in ipairs(M[1].States) do byId[state.Id] = state.Props end
		expect(byId.RankEmpty.Fraction == 0 and byId.RankFull.Fraction == 1, "arc ends")
		expect(byId.RankHundreds.Rank >= 100, "a three-digit rank")
		expect(#byId.LongLabel.Label > 30, "a long district name")
		expect(byId.NoLabel.Label == nil, "no label")
		expect(byId.NoRank.ShowRank == false, "rank off")
		expect(byId.Square.Round == false, "the config fallback")
		expect(byId.Empty.Roads == false, "an empty content holder")
		expect(byId.Default.Heading == 180, "the default is the r00 frame: north at the bottom")
	end)

	return results
end
