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

	case("compact detail: one panel that ends inside the room beside the list", function()
		local function input(patch)
			local values = {
				Available = 242, Width = 500, Pad = 8, Gap = 8, Labels = 39, Facts = 63, FactsWidth = 176,
				TextWidth = 300, Line = 20, Lines = 3, MaxLines = 3, Picture = false,
			}
			for key, value in pairs(patch or {}) do
				values[key] = value
			end
			return values
		end
		-- 844x390: description and facts side by side under the name band.
		local plan = M._compactPlan(input())
		expect(plan.Wide == true and plan.About == 60 and plan.FactsHeight == 63, "wide: three lines beside the facts")
		expect(plan.AboutWidth == 316 and plan.FactsX == 324 and plan.FactsY == plan.AboutY, "two columns under the band")
		expect(plan.Band == 39 and plan.Height == 8 + 39 + 8 + 63 + 8, "no picture: the panel is as tall as what it holds, " .. plan.Height)
		plan = M._compactPlan(input({ Picture = true }))
		expect(plan.Height == 242 and plan.Band == 242 - 16 - 8 - 63, "a picture takes the height that is left, " .. plan.Band)
		-- 568x320: stacked, all of it inside the room.
		plan = M._compactPlan(input({ Available = 175, Width = 330, Pad = 7, Gap = 7, Labels = 32, Facts = 54, FactsWidth = 150, TextWidth = 255, Line = 17 }))
		expect(plan.Wide == false and plan.About == 51 and plan.FactsHeight == 54, "stacked: three lines, then the facts, " .. plan.About)
		expect(plan.FactsX == 0 and plan.FactsY == plan.AboutY + 51 + 7 and plan.Height <= 175, "inside the room, " .. plan.Height)
		-- Less room: the description gives up lines first, then the facts are cut; nothing passes the room.
		plan = M._compactPlan(input({ Available = 140, Width = 330, Pad = 7, Gap = 7, Labels = 32, Facts = 54, FactsWidth = 150, TextWidth = 255, Line = 17 }))
		expect(plan.About == 17 and plan.FactsHeight == 54 and plan.Height <= 140, "one line is left, " .. plan.About)
		plan = M._compactPlan(input({ Available = 90, Width = 330, Pad = 7, Gap = 7, Labels = 32, Facts = 54, FactsWidth = 150, TextWidth = 255, Line = 17 }))
		expect(plan.About == 0 and plan.FactsY == plan.AboutY and plan.FactsHeight == 37 and plan.Height == 90, "no description, facts cut, " .. plan.FactsHeight)
		-- No facts and no description (the empty states): the name band alone.
		plan = M._compactPlan(input({ Facts = 0, Lines = 0 }))
		expect(plan.Wide == false and plan.About == 0 and plan.FactsHeight == 0 and plan.Height == 8 + 39 + 8, "name only, " .. plan.Height)
	end)

	return results
end
