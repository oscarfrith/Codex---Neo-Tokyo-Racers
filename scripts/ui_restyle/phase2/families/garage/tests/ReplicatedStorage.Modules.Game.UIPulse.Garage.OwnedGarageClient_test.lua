-- Pure tests for Garage.OwnedGarageClient. start() is never called here: it claims the surface and starts the four
-- parts, which is a Play check.
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
	end)

	case("start order: the Classic order, with the interior HUD in the place of GarageInteriorModeUI", function()
		local wanted = { "OwnedGarageBrowserUI", "OwnedGarageWorkspaceUI", "GarageInteriorHud", "GarageInteriorTransitionUI" }
		expect(#M._order == #wanted, "four parts")
		local seen = {}
		for index, name in ipairs(wanted) do
			expect(M._order[index] == name, "position " .. index .. ": " .. tostring(M._order[index]))
			expect(not seen[name], "duplicate " .. name)
			seen[name] = true
		end
	end)

	case("desk verdict: an open desk says nothing; every other outcome has a reason", function()
		expect(M._deskVerdict(true, true, true, nil) == nil and M._deskVerdict(false, true, true, "old") == nil, "open: nothing")
		expect(string.find(M._deskVerdict(false, false, false, nil), "sent no OpenManagement", 1, true), "no push")
		expect(string.find(M._deskVerdict(true, false, false, "cannot attach"), "desk view failed: cannot attach", 1, true), "view failure")
		expect(string.find(M._deskVerdict(true, true, false, nil), "half open", 1, true), "attribute without a view")
		expect(string.find(M._deskVerdict(true, false, false, nil), "closed again", 1, true), "closed by the fork")
	end)

	return results
end
