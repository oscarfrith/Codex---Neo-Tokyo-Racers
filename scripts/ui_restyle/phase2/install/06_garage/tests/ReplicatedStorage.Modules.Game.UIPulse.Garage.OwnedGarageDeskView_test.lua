-- Pure tests for Garage.OwnedGarageDeskView: the decisions that need no instance. Drawing, attaching to the garage
-- layer and the failure path (close through the fork, toast) are Play checks.
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

	case("close: a view's OnExit is the close path; anything else gives none", function()
		local close = function() end
		expect(M._closeOf({ OnExit = close }) == close, "OnExit function")
		expect(M._closeOf({ OnExit = true }) == nil and M._closeOf({}) == nil, "not a function")
		expect(M._closeOf(nil) == nil and M._closeOf("view") == nil, "not a view")
	end)

	case("spaces: the fork's capacity text becomes the status strip value", function()
		expect(M._spaces("1/2 DISPLAY SPACES") == "1 / 2", "used / capacity")
		expect(M._spaces("3 / 10") == "3 / 10", "already spaced")
		expect(M._spaces("NO SPACES") == "NO SPACES" and M._spaces(nil) == "", "passes through")
	end)

	case("selected tab: the selected item, else the first, else none", function()
		expect(M._selectedTab({ { Id = "A" }, { Id = "B", Selected = true } }) == "B", "selected")
		expect(M._selectedTab({ { Id = "A" }, { Text = "B" } }) == "A", "first")
		expect(M._selectedTab({ { Text = "Only" } }) == "Only", "text when there is no id")
		expect(M._selectedTab({}) == nil and M._selectedTab(nil) == nil, "none")
	end)

	return results
end
