-- Pure tests for Dev.Fixtures.Garage: the list shape the gallery reads, the required states, and that the fake
-- model reaches nothing outside its own tables.
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

	case("items: unique ids, Scene frame, a Mount, at least one state, every state names a known page", function()
		local seen = {}
		expect(#M >= 9, "one item per screen and per modal")
		for _, item in ipairs(M) do
			expect(type(item.Id) == "string" and not seen[item.Id], "id " .. tostring(item.Id))
			seen[item.Id] = true
			expect(item.Frame == "Scene" and item.Slot == nil and type(item.Mount) == "function", item.Id .. " shape")
			expect(#item.States >= 1, item.Id .. " states")
			for _, state in ipairs(item.States) do
				expect(type(M._pages[state.Props.Page]) == "function", item.Id .. "/" .. state.Id .. " page")
				expect(state.Props.Modal == nil or type(M._modals[state.Props.Modal]) == "function", item.Id .. "/" .. state.Id .. " modal")
			end
		end
	end)

	case("states: empty, loading, error line, locked, unaffordable and the longest strings are present", function()
		local pages = M._pages
		expect(#pages.DealershipEmpty().Items == 0 and pages.DealershipEmpty().Stats.Empty ~= nil, "empty")
		expect(pages.DealershipLoading().Selected == nil, "loading: nothing selected yet")
		expect(type(pages.DealershipError().Message) == "string", "error line")
		local unaffordable, locked, long = false, false, 0
		for _, item in ipairs(pages.Dealership().Items) do
			unaffordable = unaffordable or item.Status == "Unaffordable"
			long = math.max(long, #item.Title)
		end
		for _, item in ipairs(pages.PartsShop().Items) do
			locked = locked or item.Status == "Locked"
		end
		expect(unaffordable and locked and long >= 30, "unaffordable, locked, long name")
		expect(pages.PartsOwnedNone().Source.OwnedLocked == true, "Owned locked")
		expect(pages.UpgradesNoData().EmptyMessage ~= nil and pages.PaintColour().Paint ~= nil and pages.PostPaint().Tab == nil, "other pages")
	end)

	case("fake model: getters and intents only; a tile press moves the selection and fires Changed", function()
		local model = M._fakeModel({ Page = "PartsShop" })
		local fired = 0
		model.Changed:Connect(function()
			fired += 1
		end)
		expect(model.Showing() == "Workspace" and model.Page().Selected == "M:sp2", "canned page")
		model.SelectItem("M:sp1")
		expect(model.Page().Selected == "M:sp1" and model.Page().Action.Amount == 3000 and fired == 1, "selection moved")
		model.Action()
		model.Drive()
		model.PaintColour("Primary")
		expect(#model.Calls == 4, "intents are recorded, nothing else happens")
		expect(M._fakeModel({ Page = "Dealership" }).Showing() == "Browser", "dealership shows the browser page")
		expect(M._fakeModel({ Page = "Dealership", Modal = "BuyVehicle" }).Modal().Kind == "BuyVehicle", "modal state")
	end)

	return results
end
