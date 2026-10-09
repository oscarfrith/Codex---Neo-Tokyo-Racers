-- Pure tests for ReplicatedFirst.Loading.StartScreenPulse. Run() is the start-screen flow itself (it calls the loading
-- runtime, writes StartScreenActive and waits): a Play check. Covered here: the module shape and the menu builder that
-- replaces Classic lines 113-229, on a detached SafeRoot. The fork's kept lines are checked offline by build_shell.py.
return function(M, env)
	local results = {}
	local KIT = "ReplicatedStorage.Modules.Game.UIPulse.Kit."

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local function kit()
		return { Tokens = env.Load(KIT .. "Tokens"), Metrics = env.Load(KIT .. "Metrics"), Layers = env.Load(KIT .. "Layers"),
			Text = env.Load(KIT .. "Text"), Input = env.Load(KIT .. "Input"), Controls = env.Load(KIT .. "Controls") }
	end

	case("module shape: Run and the two seams; nothing ran at require", function()
		expect(type(M) == "table" and type(M.Run) == "function", "Run is a function")
		expect(type(M._buildMenu) == "function" and type(M._kit) == "function", "seams")
	end)

	local PRESETS = {
		{ Name = "R1080", Spec = { Size = Vector2.new(1920, 1080) } },
		{ Name = "C844", Spec = { Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch" } },
	}
	for _, preset in ipairs(PRESETS) do
		case(preset.Name .. ": menu builds with Play and Shop as real buttons and survives the kept release steps", function()
			local k = kit()
			local ctx = k.Metrics.Fixed(preset.Spec)
			local safeRoot = env.Detached("Frame")
			local scope = env.Scope()
			local built = M._buildMenu(k, safeRoot, ctx, scope, { Play = "PLAY", Shop = "SHOP" })
			local menu = built.Menu
			expect(menu.Parent == safeRoot and menu.Name == "StartScreenActions", "menu root on SafeRoot, Classic name")
			local play, shop = built.Play.Instance, built.Shop.Instance
			expect(play:IsA("GuiButton") and shop:IsA("GuiButton") and play ~= shop, "two real buttons")
			expect(play:IsDescendantOf(menu) and shop:IsDescendantOf(menu), "inside the menu")
			expect(play.Active == true and shop.Active == true and play.Selectable == true and shop.Selectable == true, "usable and focusable")
			-- the kept handlers connect to Activated, as Classic 306 and 312 do
			local connection = play.Activated:Connect(function() end)
			connection:Disconnect()

			built.SetBusy(true, "ENTERING", "SHOP")
			expect(play.Active == false and shop.Active == false, "busy: neither can be pressed (Classic 285-286)")
			built.SetBusy(false, "PLAY", "SHOP - TRY AGAIN")
			expect(play.Active == true and shop.Active == true, "usable again after a failed Shop")

			-- Classic release() 294-303: disconnect layoutConnections (here: the kit scope), hide, then destroy the menu.
			scope:destroy()
			menu.Visible = false
			menu:Destroy()
			expect(#safeRoot:GetChildren() == 0, "nothing left on SafeRoot")
		end)
	end

	return results
end
