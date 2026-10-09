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

	case("host: the desk attaches to the Pulse garage layer's root, and says why when it cannot", function()
		local function gui(name, style, rootName, rootIsGui)
			local item = { Name = name }
			function item:GetAttribute(key) return key == "UIStyle" and style or nil end
			function item:FindFirstChild(wanted)
				if wanted ~= rootName then return nil end
				return { Name = rootName, IsA = function(_, class) return class == "GuiObject" and rootIsGui end }
			end
			return item
		end
		local canvas, reason = M._hostOf({ gui("Other", "Pulse", "CanonicalCanvas", true), gui("CanonicalGarageGui", nil, "CanonicalCanvas", true),
			gui("CanonicalGarageGui", "Pulse", "CanonicalCanvas", true) })
		expect(canvas ~= nil and canvas.Name == "CanonicalCanvas" and reason == nil, "the Pulse layer wins over a same-named gui before it")
		canvas, reason = M._hostOf({})
		expect(canvas == nil and string.find(reason, "does not exist yet", 1, true), "no gui: a reason")
		canvas, reason = M._hostOf({ gui("CanonicalGarageGui", "Classic", "CanonicalCanvas", true) })
		expect(canvas == nil and string.find(reason, "none is the Pulse layer", 1, true), "not Pulse: a reason")
		canvas, reason = M._hostOf({ gui("CanonicalGarageGui", "Pulse", "Root", true) })
		expect(canvas == nil and string.find(reason, "has no CanonicalCanvas", 1, true), "no root: a reason")
		canvas, reason = M._hostOf({ gui("CanonicalGarageGui", "Pulse", "CanonicalCanvas", false) })
		expect(canvas == nil and type(reason) == "string", "a root that is not a GuiObject is not a host")
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

	case("button list: only the showing buttons, in desk order, so the row ends at its slot", function()
		local list, key = M._buttonList({ Exit = "EXIT", Back = "BACK" })
		expect(#list == 2 and list[1].Id == "Back" and list[2].Id == "Exit", "Back then Exit; Next and Action left out")
		expect(list[1].Icon == "back" and list[2].Text == "EXIT" and key == "Back=BACK|Exit=EXIT", "specs and signature")
		local all = M._buttonList({ Back = "BACK", Exit = "EXIT", Next = "SAVE", Action = "BUY" })
		expect(#all == 4 and all[3].Variant == "Main" and all[4].Id == "Action", "all four")
		local none, emptyKey = M._buttonList({})
		expect(#none == 0 and emptyKey == "", "none")
	end)

	case("rail selection: emptied first only when the rail holds a card the fork no longer selects", function()
		expect(M._railNeedsClear("Lighting", nil, true) == true, "held, not wanted, still listed: the rail would keep it")
		expect(M._railNeedsClear("Lighting", nil, false) == false, "a key that left the list is dropped by the rail itself")
		expect(M._railNeedsClear("Lighting", "Lighting", true) == false and M._railNeedsClear("Lighting", "Floor", true) == false, "a wanted card is selected over it")
		expect(M._railNeedsClear(nil, nil, false) == false and M._railNeedsClear(nil, "Floor", false) == false, "nothing held, nothing to drop")
	end)

	return results
end
