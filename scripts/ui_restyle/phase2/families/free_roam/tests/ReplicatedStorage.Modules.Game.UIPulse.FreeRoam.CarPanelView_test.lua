-- Pure tests for FreeRoam.CarPanelView: the row and tile builders. The mounted panel is covered by the HudView test.
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local rows = {
		{ VehicleId = "v1", Name = "SERAPH", Category = "EXOTIC", Image = "", Tier = "S", Rating = 939.7, Selected = true },
		{ VehicleId = "v2", Name = "ODD", Category = "OTHER", Image = "rbxassetid://5", Tier = "?", Rating = 0, Selected = false },
	}

	case("list items: BUY MORE first, then one row per vehicle", function()
		local items = M._listItems(rows, "BuyMore")
		expect(#items == 3 and items[1].Key == "BuyMore" and items[1].Title == "BUY MORE", "buy more first (D775)")
		expect(items[2].Key == "v1" and items[2].Title == "SERAPH" and items[2].Sub == "939  EXOTIC", "row text")
		expect(items[2].Tier == "S" and items[2].State == "Selected" and items[2].Chip == "CURRENT" and items[2].Image == nil, "current vehicle")
		expect(items[3].Tier == nil and items[3].State == "Default" and items[3].Chip == nil and items[3].Image == "rbxassetid://5", "unknown tier has no badge")
		expect(#M._listItems({}, "BuyMore") == 1, "an empty garage still offers BUY MORE")
	end)

	case("tile items (Compact): tier and rating on the tile", function()
		local items = M._tileItems(rows, "BuyMore")
		expect(#items == 3 and items[1].Icon == "plus", "buy more tile")
		expect(items[2].Rating == 939 and items[2].Status == "Owned" and items[2].State == "Selected", "owned tile")
		expect(items[3].Tier == nil, "unknown tier")
	end)

	case("every row carries its own press, the CURRENT one included (a selected row never fires OnSelected)", function()
		local pressed = {}
		local function onActivated(key) table.insert(pressed, key) end
		for _, items in ipairs({ M._listItems(rows, "BuyMore", onActivated), M._tileItems(rows, "BuyMore", onActivated) }) do
			expect(items[2].State == "Selected" and type(items[2].OnActivated) == "function", "the current row is pressable")
			items[2].OnActivated()
			items[2].OnActivated()
			items[3].OnActivated()
			items[1].OnActivated()
		end
		expect(table.concat(pressed, ",") == "v1,v1,v2,BuyMore,v1,v1,v2,BuyMore", "each press reports its own key, every time")
		expect(M._listItems(rows, "BuyMore")[2].OnActivated == nil, "no callback asked, none added")
	end)

	case("hint and despawn rule", function()
		expect(M._hint(true, 0, "ALL") == "LOADING VEHICLES...", "loading")
		expect(M._hint(false, 0, "ALL") == "NO VEHICLES OWNED YET", "an empty garage")
		expect(M._hint(false, 2, "ALL") == "SELECT A VEHICLE TO SPAWN IT", "vehicles to pick")
		expect(not M._canDespawn({ Driving = false, Vehicle = nil }), "nothing out: DESPAWN is disabled")
		expect(M._canDespawn({ Driving = true }) and M._canDespawn({ Driving = false, Vehicle = { Tier = "S" } }), "a vehicle out")
	end)

	case("category options", function()
		local options = M._options({ "ALL", "EXOTIC" })
		expect(#options == 2 and options[2].Id == "EXOTIC" and options[2].Text == "EXOTIC", "id and text")
	end)

	return results
end
