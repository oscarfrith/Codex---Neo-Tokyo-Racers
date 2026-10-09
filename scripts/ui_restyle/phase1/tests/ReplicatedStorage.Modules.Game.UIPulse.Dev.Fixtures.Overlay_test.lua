-- Pure tests for Dev.Fixtures.Overlay: the registration shape of API.md section 10. Nothing is mounted here; the
-- gallery mounts every state at every preset (CONTRACT 7.5 U8).
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
	local SLOTS = { TopLeft = true, TopRight = true, TopCentre = true, RightColumn = true, BottomRail = true,
		BottomRight = true, BottomCentre = true, PromptStack = true }

	case("returns a list of items", function()
		expect(type(M) == "table" and #M >= 3, "at least three items")
	end)

	case("every public Overlay constructor has an item", function()
		local seen = {}
		for _, item in ipairs(M) do seen[item.Id] = true end
		for _, id in ipairs({ "Overlay.Toast", "Overlay.Confirm", "Overlay.Modal" }) do
			expect(seen[id], id .. " is registered")
		end
	end)

	case("item shape", function()
		local ids = {}
		for _, item in ipairs(M) do
			expect(type(item.Id) == "string" and item.Id ~= "", "Id")
			expect(not ids[item.Id], "duplicate item id " .. item.Id)
			ids[item.Id] = true
			expect(FRAMES[item.Frame], item.Id .. ": Frame")
			expect(item.Slot == nil or SLOTS[item.Slot], item.Id .. ": Slot")
			expect(type(item.Mount) == "function", item.Id .. ": Mount")
			expect(type(item.States) == "table" and #item.States >= 1, item.Id .. ": States")
			local stateIds = {}
			for _, state in ipairs(item.States) do
				expect(type(state.Id) == "string" and state.Id ~= "", item.Id .. ": state Id")
				expect(not string.find(state.Id, "[|,%s]"), item.Id .. ": state Id has no separator or space")
				expect(not stateIds[state.Id], item.Id .. ": duplicate state " .. state.Id)
				stateIds[state.Id] = true
				expect(type(state.Props) == "table", item.Id .. "." .. state.Id .. ": Props")
			end
		end
	end)

	case("toast states cover a stack, a long message, a duplicate and an overflow", function()
		local toast
		for _, item in ipairs(M) do
			if item.Id == "Overlay.Toast" then toast = item end
		end
		expect(toast ~= nil and toast.Frame == "Hud" and toast.Slot == "TopCentre", "toast in Hud, TopCentre")
		local byId = {}
		for _, state in ipairs(toast.States) do byId[state.Id] = state.Props end
		expect(byId.Stack and #byId.Stack.Messages == 3, "Stack has three messages")
		expect(byId.Overflow and #byId.Overflow.Messages == 4, "Overflow has four messages")
		expect(byId.Duplicate and #byId.Duplicate.Messages >= 2, "Duplicate repeats a message")
		local longest = 0
		for _, message in ipairs(byId.Long.Messages) do longest = math.max(longest, #message) end
		expect(longest > 120, "Long carries a message that must wrap")
	end)

	return results
end
