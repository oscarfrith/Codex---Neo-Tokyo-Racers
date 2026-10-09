-- Pure tests for Garage.OwnedGarageBrowserUI: the footer row and the "garage full" rows. Start() is never called
-- here (it waits for remotes and builds the layer); the mounted view is a gallery and Play check.
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

	case("owner shape: the Classic surface, and nothing ran at require", function()
		expect(type(M.Start) == "function" and type(M.Close) == "function" and type(M.IsOpen) == "function", "Start, Close, IsOpen")
		expect(M.IsOpen() == false, "closed before Start")
	end)

	case("footer: only the buttons that show are in the row", function()
		local calls = {}
		local function onExit()
			table.insert(calls, "Exit")
		end
		local function onEnter()
			table.insert(calls, "Enter")
		end
		local both = M._footerButtons({ Visible = true, Enabled = false, Text = "VISIT GARAGE" }, onExit, onEnter)
		expect(#both == 2 and both[1].Id == "Exit" and both[2].Id == "Enter", "EXIT, then the main action")
		expect(both[2].Text == "VISIT GARAGE" and both[2].Disabled == true and both[2].Variant == "Main", "the model's text and state")
		expect(both[2].MarkKey == "Enter", "the Enter mark is on the row entry")
		local alone = M._footerButtons({ Visible = false, Enabled = true, Text = "ENTER GARAGE" }, onExit, onEnter)
		expect(#alone == 1 and alone[1].Id == "Exit", "a hidden main action is left out, not hidden")
		expect(#M._footerButtons(nil, onExit, onEnter) == 1, "no Enter state: EXIT only")
		expect(#calls == 0, "building the row presses nothing")
		both[1].OnActivated()
		both[2].OnActivated()
		expect(table.concat(calls, ",") == "Exit,Enter", "each button runs its own callback")
		for _, spec in ipairs(both) do
			expect(spec.Visible == nil, "no Visible key: the row takes only what shows")
		end
	end)

	case("garage full: a replacement needs an activation; building or selecting rows calls nothing", function()
		local chosen = {}
		local rows = M._replacementRows({
			{ SlotId = "A", DisplayName = "Zephyr" },
			{ SlotId = "B", VehicleId = "V7" },
			{ SlotId = "C" },
		}, function(index)
			table.insert(chosen, index)
		end)
		expect(#chosen == 0, "building the rows replaces nothing")
		expect(#rows == 3 and rows[1].Key == "Slot_1" and rows[1].Title == "Zephyr" and rows[1].Right == "1", "row 1")
		expect(rows[2].Title == "V7" and rows[3].Title == "" and rows[3].Key == "Slot_3", "name, then vehicle id, then nothing")
		for _, row in ipairs(rows) do
			expect(type(row.OnActivated) == "function" and row.OnSelected == nil, "acts on activation, never on selection")
		end
		rows[2].OnActivated()
		rows[2].OnActivated()
		expect(table.concat(chosen, ",") == "2,2", "every press asks, also a second press on the same row: " .. table.concat(chosen, ","))
		expect(#M._replacementRows(nil, function() end) == 0, "no slots, no rows")
	end)

	case("compact detail: the stack ends inside the room beside the list", function()
		local function total(hero, about, facts, gap)
			return hero + gap + (about > 0 and about + gap or 0) + facts
		end
		local hero, about = M._compactDetail(400, 60, 94, 10, 36)
		expect(hero == 60 and about == 60, "room for all: full size")
		hero, about = M._compactDetail(202, 60, 94, 10, 36)
		expect(hero == about and hero >= 36 and total(hero, about, 94, 10) <= 202, "844x390: both shrink, " .. hero)
		hero, about = M._compactDetail(142, 51, 80, 9, 31)
		expect(about == 0 and hero >= 31 and hero <= 51 and total(hero, about, 80, 9) <= 142, "568x320: no description, picture " .. hero)
		hero, about = M._compactDetail(60, 51, 80, 9, 31)
		expect(about == 0 and hero == 31, "no room at all: the picture keeps its minimum")
	end)

	return results
end
