-- Pure tests for FreeRoam.HudModals: which modal shows, the ModalLayer visibility and the backdrop mode.
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	case("plan: nothing open", function()
		local name, layer, backdrop = M._plan({})
		expect(name == nil and layer == false and backdrop == "Clear", "closed")
	end)

	case("plan: Settings and Cash never darken the backdrop", function()
		for _, modal in ipairs({ "Settings", "Cash" }) do
			local name, layer, backdrop = M._plan({ ActiveModal = modal, ControlsReveal = true })
			expect(name == modal and layer == true and backdrop == "Clear", modal)
		end
	end)

	case("plan: the first-drive reveal (D453-471)", function()
		local name, layer, backdrop = M._plan({ ActiveModal = "Controls", ControlsReveal = true })
		expect(name == "Controls" and layer and backdrop == "Opaque", "opaque while shown")
		name, layer, backdrop = M._plan({ ActiveModal = "Controls", ControlsReveal = true, ControlsFading = true })
		expect(name == nil and layer and backdrop == "Fading", "the Controls child hides, ModalLayer stays, the backdrop fades")
		name, layer, backdrop = M._plan({ ActiveModal = "Controls" })
		expect(name == "Controls" and layer and backdrop == "Clear", "plain controls")
	end)

	case("segments: ids keep the Classic values, text is upper case, locks pass through", function()
		local items = M._segments({ "Arrows", "Thumbstick", "Tilt" }, function(mode) return mode == "Tilt" end)
		expect(#items == 3 and items[1].Id == "Arrows" and items[1].Text == "ARROWS", "id and text")
		expect(items[3].Locked == true and items[1].Locked == nil, "locked")
	end)

	case("stack and panel height: the panel is given the height of its content, in design units", function()
		expect(M._stack({}, 10) == 0 and M._stack({ 48 }, 10) == 48 and M._stack({ 48, 48, 64 }, 10) == 180, "stack")
		-- Regular at scale 1: pad 22, title 65, content 180 -> 311 design px.
		expect(M._panelHeight(180, 65, 22, 1) == 311, "scale 1")
		-- Scaled: Surface.Panel multiplies by the scale again, giving the real pixels back.
		expect(math.abs(M._panelHeight(201, 18, 19, 0.85) * 0.85 - (19 * 3 + 18 + 201)) < 1e-6, "scale 0.85")
	end)

	case("Compact budgets: Controls, Settings (three rows) and Get Cash fit 844 x 390 and 568 x 320", function()
		-- Real pixels the builders use on a phone, per scale: { screen height, pad, title, gap, key row, list room }.
		for _, preset in ipairs({
			{ Screen = 390, Pad = 22, Title = 22, Gap = 4, KeyRow = 26 },
			{ Screen = 320, Pad = 19, Title = 18, Gap = 3, KeyRow = 22 },
		}) do
			local chrome = preset.Pad * 3 + preset.Title
			local hit = 48 -- TouchMin: a segment row, a footer button and a pack row
			local controls = M._stack({ 8 * preset.KeyRow, hit }, preset.Gap)
			local settings = M._stack({ hit, hit, hit, hit }, preset.Gap)
			local packs = M._listRoom(M._stack({ hit, hit, hit, hit }, 1), hit, preset.Screen, chrome + preset.Gap + hit)
			local cash = M._stack({ packs, hit }, preset.Gap)
			expect(chrome + controls <= preset.Screen, "controls at " .. preset.Screen)
			expect(chrome + settings <= preset.Screen, "settings at " .. preset.Screen)
			expect(chrome + cash <= preset.Screen, "cash at " .. preset.Screen)
		end
	end)

	case("list room: the whole list when it fits, else what the screen leaves, never under one row", function()
		expect(M._listRoom(195, 48, 390, 140) == 195, "fits")
		expect(M._listRoom(195, 48, 320, 126) == 194, "one pixel short scrolls")
		expect(M._listRoom(195, 48, 200, 190) == 48, "one row at least")
	end)

	return results
end
