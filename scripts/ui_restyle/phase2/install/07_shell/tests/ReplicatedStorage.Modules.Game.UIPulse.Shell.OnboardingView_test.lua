-- Pure tests for Shell.OnboardingView: the placement rules carried from Classic, and the view mounted on a detached
-- Layers.Stage at R1080 and C844 over a fake model. Nothing is parented into the game tree; nothing yields.
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

	case("bounds: padded union of the boxes, nil for none (Classic 252-261)", function()
		expect(M._bounds({}, 6) == nil, "nil for no box")
		local x, y, right, bottom = M._bounds({ { 100, 50, 40, 20 }, { 160, 40, 30, 60 } }, 6)
		expect(x == 94 and y == 34 and right == 196 and bottom == 106, "union: " .. table.concat({ x, y, right, bottom }, ","))
	end)

	case("shade: four rectangles around the target cover the canvas and leave the target open (361-364)", function()
		local rects = M._shadeRects(100, 200, 300, 260, 1920, 1080, 8)
		expect(#rects == 4, "four")
		expect(rects[1][1] == -8 and rects[1][2] == -8 and rects[1][3] == 1936 and rects[1][4] == 208, "top")
		expect(rects[2][1] == -8 and rects[2][2] == 200 and rects[2][3] == 108 and rects[2][4] == 60, "left")
		expect(rects[3][1] == 300 and rects[3][2] == 200 and rects[3][3] == 1628 and rects[3][4] == 60, "right")
		expect(rects[4][1] == -8 and rects[4][2] == 260 and rects[4][3] == 1936 and rects[4][4] == 828, "bottom")
		-- left edge of the right shade is the target's right edge; top shade ends where the target starts
		expect(rects[1][2] + rects[1][4] == 200 and rects[2][1] + rects[2][3] == 100, "edges meet the target")
	end)

	case("mode: fixed side wins; a low target goes Above; else Auto (304)", function()
		expect(M._mode("Left", 0, 10, 0, 1000) == "Left", "fixed")
		expect(M._mode(nil, 700, 800, 0, 1000) == "Above", "low target")
		expect(M._mode(nil, 100, 200, 0, 1000) == "Auto", "auto")
		expect(M._mode(nil, 600, 640, 0, 1000) == "Auto", "exactly at 62% is not above")
	end)

	case("bubble: first candidate that fits; order per mode; clamped when none fits (304-308)", function()
		-- target near the top right of a 1920x1080 safe area (10 px margin)
		local x, y = M._placeBubble("Below", 1500, 100, 1600, 160, 590, 200, 22, 10, 70, 1910, 1070)
		expect(x == 1255 and y == 182, "below, centred: " .. x .. "," .. y)
		-- Below does not fit at the bottom edge: Above is next
		x, y = M._placeBubble("Below", 900, 1000, 1000, 1060, 590, 200, 22, 10, 70, 1910, 1070)
		expect(x == 655 and y == 778, "falls to above: " .. x .. "," .. y)
		-- Auto prefers the right side
		x, y = M._placeBubble("Auto", 100, 400, 200, 460, 590, 200, 22, 10, 70, 1910, 1070)
		expect(x == 222 and y == 330, "right side: " .. x .. "," .. y)
		-- Left
		x, y = M._placeBubble("Left", 1700, 400, 1800, 460, 590, 200, 22, 10, 70, 1910, 1070)
		expect(x == 1088 and y == 330, "left side: " .. x .. "," .. y)
		-- nothing fits: first candidate, clamped into the safe rectangle
		x, y = M._placeBubble("Above", 0, 0, 300, 380, 300, 200, 22, 10, 10, 310, 380)
		expect(x == 10 and y == 10, "clamped: " .. x .. "," .. y)
	end)

	case("bubble: a Compact candidate never covers the Roblox top-left buttons", function()
		-- 844x390, 10 px margin, buttons 120x52 plus the margin. Left of the target would land on them: Below is next.
		local x, y = M._placeBubble("Left", 430, 30, 500, 110, 300, 60, 10, 10, 10, 834, 380)
		expect(x == 120 and y == 40, "without the keep-out: " .. x .. "," .. y)
		x, y = M._placeBubble("Left", 430, 30, 500, 110, 300, 60, 10, 10, 10, 834, 380, 130, 62)
		expect(x == 315 and y == 120, "with the keep-out: " .. x .. "," .. y)
		-- a top-centre action button: Below is clear of the buttons and is kept
		x, y = M._placeBubble("Below", 360, 2, 404, 46, 300, 88, 10, 10, 10, 834, 380, 130, 62)
		expect(x == 232 and y == 56, "below a top-centre button: " .. x .. "," .. y)
		-- nothing fits and the clamp lands on the buttons: the bubble goes under them
		x, y = M._placeBubble("Above", 0, 0, 300, 300, 300, 200, 22, 10, 10, 310, 380, 130, 62)
		expect(x == 10 and y == 62, "clamped under the buttons: " .. x .. "," .. y)
	end)

	case("connector: joins the target to the bubble on the side the bubble sits (280-286)", function()
		local x, y, w, h = M._connector(100, 400, 200, 460, 222, 330, 590, 200, 2)
		expect(x == 200 and y == 430 and w == 22 and h == 2, "bubble on the right: " .. table.concat({ x, y, w, h }, ","))
		x, y, w, h = M._connector(1700, 400, 1800, 460, 1088, 330, 590, 200, 2)
		expect(x == 1678 and y == 430 and w == 22 and h == 2, "bubble on the left")
		x, y, w, h = M._connector(1500, 100, 1600, 160, 1255, 182, 590, 200, 2)
		expect(x == 1550 and y == 160 and w == 2 and h == 22, "bubble below")
		x, y, w, h = M._connector(900, 1000, 1000, 1060, 655, 778, 590, 200, 2)
		expect(x == 950 and y == 978 and w == 2 and h == 22, "bubble above")
	end)

	-- Mounted --------------------------------------------------------------------------------------------------
	local function withModules(body)
		local saved = M._modules
		local loaded = {
			Tokens = env.Load(KIT .. "Tokens"), Text = env.Load(KIT .. "Text"), Surface = env.Load(KIT .. "Surface"),
			Controls = env.Load(KIT .. "Controls"), Input = env.Load(KIT .. "Input"), Layers = env.Load(KIT .. "Layers"),
			Model = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Shell.OnboardingModel"),
		}
		M._modules = function() return loaded end
		local ok, problem = pcall(body, loaded)
		M._modules = saved
		if not ok then error(problem, 0) end
	end

	local function fakeModel(Model, target)
		local model = { GateOpen = true, ActivePage = nil, ActiveIndex = nil, ActiveObjects = nil, Order = {}, Advances = 0,
			State = { SeenPages = {}, Completed = {} } }
		function model:CardId()
			local page = self.ActivePage and Model.Pages[self.ActivePage]
			return page and page[self.ActiveIndex] or nil
		end
		function model:IsAction() return Model.ActionSteps[self:CardId() or ""] == true end
		function model:CalloutVisible() return self.GateOpen and self.ActivePage ~= nil and self.ActiveObjects ~= nil end
		function model:ObjectivesVisible() return self.GateOpen and #self.Order > 0 end
		function model:ObjectiveOrder() return self.Order end
		function model:ObjectiveHint(index) return Model.ObjectiveHint(self, index) end
		function model:Advance() self.Advances += 1 end
		function model:TargetLost() end
		function model:ActionActivated() end
		function model:Pin(pageId, index)
			self.ActivePage, self.ActiveIndex, self.ActiveObjects = pageId, index, { target }
		end
		return model
	end

	local PRESETS = {
		{ Name = "R1080", Spec = { Size = Vector2.new(1920, 1080) }, Compact = false },
		{ Name = "C844", Spec = { Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch", TopBarHeight = 52,
			TopBarKeepOut = Vector2.new(120, 52) }, Compact = true },
	}

	for _, preset in ipairs(PRESETS) do
		case(preset.Name .. ": mounts, renders every state without churn, and destroys cleanly", function()
			withModules(function(loaded)
				local Metrics = env.Load(KIT .. "Metrics")
				local ctx = Metrics.Fixed(preset.Spec)
				expect((ctx.Class == "Compact") == preset.Compact, "class")
				local stageParent = env.Detached("Frame")
				local layer = loaded.Layers.Stage(stageParent, ctx, "Bare")
				local scope = env.Scope()
				local target = Instance.new("TextButton")
				target.Name = "FixtureTarget"
				target.Parent = layer.Root
				local model = fakeModel(loaded.Model, target)
				local view = M.Mount(layer, model, scope)
				local parts = view.Parts

				expect(layer.Root.Visible == true, "the layer follows GateOpen")
				expect(parts.Bubble.Visible == false and parts.Highlight.Visible == false and parts.Catch.Visible == false, "no callout yet")
				expect(parts.Objectives.Visible == false, "no cards yet")
				for index = 1, 4 do
					expect(parts.Shades[index].Name == "Shade" .. index and parts.Shades[index].Visible == false, "shade " .. index)
				end
				expect(parts.Catch.Name == "Advance" and parts.Catch.Modal == true, "press-anywhere button")
				expect(parts.Next.Instance:IsA("GuiButton"), "NEXT is a real button")

				local count = #stageParent:GetDescendants()

				-- objective cards
				model.Order = { 2, 3 }
				view.Render("Objectives")
				expect(parts.Objectives.Visible == true, "cards show")
				expect(parts.Cards[1].Frame.Visible == false and parts.Cards[2].Frame.Visible == true, "card 2, not card 1")
				expect(parts.Cards[3].Frame.Visible == (not preset.Compact), "Compact shows the first objective only")
				model.Order = { 1 }
				view.Render("Objectives")
				expect(parts.Cards[1].Frame.Visible == true and parts.Cards[2].Frame.Visible == false, "card 1")
				model.State.Completed.FirstVehiclePurchased = true
				view.Render("Objectives")
				view.Render("Objectives")

				-- every card of every page: no error, nothing created (a detached target has no size, so the
				-- callout stays hidden; its geometry is covered by the pure cases above)
				for _, pageId in ipairs(loaded.Model.PageOrder) do
					for index in ipairs(loaded.Model.Pages[pageId]) do
						model:Pin(pageId, index)
						view.Render("Callout")
					end
				end
				expect(parts.Bubble.Visible == false, "hidden for a target with no size")
				model.ActivePage, model.ActiveIndex, model.ActiveObjects = nil, nil, nil
				view.Render("Callout")

				-- gate
				model.GateOpen = false
				view.Render("Gate")
				expect(layer.Root.Visible == false and parts.Objectives.Visible == false, "hidden by the gate")
				model.GateOpen = true
				view.Render("Gate")
				expect(layer.Root.Visible == true, "shown again")

				expect(#stageParent:GetDescendants() == count, "no instance created or destroyed by any render ("
					.. count .. " -> " .. #stageParent:GetDescendants() .. ")")

				view.Destroy()
				view.Destroy()
				view.Render("AfterDestroy")
				target:Destroy()
				layer.Destroy()
				scope:destroy()
				expect(#stageParent:GetChildren() == 0, "the stage is empty after Destroy")
			end)
		end)
	end

	return results
end
