-- Pure tests for Dev.Fixtures.Overlay: the registration shape of API.md section 10 with the Phase 2 items. Nothing is
-- mounted here; the gallery mounts every state at every preset.
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
		BottomRight = true, BottomCentre = true, PromptStack = true, SidePanel = true }

	case("returns a list of items", function()
		expect(type(M) == "table" and #M >= 3, "at least three items")
	end)

	case("every public Overlay constructor has an item", function()
		local seen = {}
		for _, item in ipairs(M) do seen[item.Id] = true end
		for _, id in ipairs({ "Overlay.Toast", "Overlay.Confirm", "Overlay.Modal", "Overlay.ModalSide",
			"Overlay.PromptBanner", "Overlay.PromptStack" }) do
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

	local function itemOf(id)
		for _, item in ipairs(M) do
			if item.Id == id then return item end
		end
		error("no item " .. id, 2)
	end

	local function statesOf(id)
		local byId = {}
		for _, state in ipairs(itemOf(id).States) do byId[state.Id] = state.Props end
		return byId
	end

	case("toast states cover the three kinds, with and without an icon", function()
		local byId = statesOf("Overlay.Toast")
		local kinds = {}
		for _, message in ipairs(byId.Kinds.Messages) do
			expect(type(message) == "table" and type(message.Icon) == "string", "Kinds messages carry an icon")
			kinds[message.Kind] = true
		end
		expect(kinds.Good and kinds.Bad and kinds.Neutral, "Good, Bad and Neutral")
		expect(byId.KindsNoIcon ~= nil and byId.LongBad ~= nil, "kinds without an icon, and a long Bad message")
	end)

	case("modal states cover the footer, close button, scrims and the side panel", function()
		local byId = statesOf("Overlay.Modal")
		expect(byId.Footer.Footer == true and byId.CloseButton.CloseButton == true, "footer and close button")
		expect(byId.MenuScrim.Scrim == "Menu" and byId.NoScrim.Scrim == "None", "scrim kinds")
		local side = itemOf("Overlay.ModalSide")
		expect(side.Frame == "Hud" and side.Slot == "SidePanel", "the side panel sits in its slot")
		for _, state in ipairs(side.States) do
			expect(state.Props.Side == "Left" or state.Props.Side == "Right", "a side")
		end
	end)

	case("prompt states cover key cap, pad glyph, touch, Main, hold and the longest strings", function()
		local banner = itemOf("Overlay.PromptBanner")
		expect(banner.Frame == "Hud" and banner.Slot == "PromptStack", "banner in the prompt slot")
		local byId = statesOf("Overlay.PromptBanner")
		expect(byId.Keyboard.Input == "KeyboardAndMouse" and typeof(byId.Keyboard.Key) == "EnumItem", "keyboard")
		expect(byId.Gamepad.Input == "Gamepad" and typeof(byId.Gamepad.PadKey) == "EnumItem", "gamepad")
		expect(byId.Touch.Input == "Touch", "touch")
		expect(byId.Main.Main == true and byId.Hold.Hold == true and byId.Hold.Progress > 0, "Main and hold")
		expect(#byId.Long.Object > 40, "a long object text")
		expect(byId.NoObject.Object == nil and byId.NoKey.Key == nil, "without object, without key")
		local stack = statesOf("Overlay.PromptStack")
		expect(#stack.Overflow.Prompts == 4 and #stack.Empty.Prompts == 0, "overflow and empty stacks")
		local ids = {}
		for _, prompt in ipairs(stack.Overflow.Prompts) do
			expect(type(prompt.Id) == "string" and not ids[prompt.Id], "unique prompt ids")
			ids[prompt.Id] = true
		end
	end)

	return results
end
