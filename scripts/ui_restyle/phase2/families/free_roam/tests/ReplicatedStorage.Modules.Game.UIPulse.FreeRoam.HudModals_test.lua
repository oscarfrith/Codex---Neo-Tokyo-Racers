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

	return results
end
