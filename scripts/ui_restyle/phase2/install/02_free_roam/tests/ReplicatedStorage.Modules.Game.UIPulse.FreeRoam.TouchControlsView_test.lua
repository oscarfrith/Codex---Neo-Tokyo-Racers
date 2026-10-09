-- Pure tests for FreeRoam.TouchControlsView: placement rules, reserved names, the proxies the kept Classic code
-- writes through, and a mount on a detached stage. Input handling is the fork's and is checked in Play.
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
	local function newScope()
		if env.Scope then return env.Scope() end
		local items = {}
		local scope = {}
		function scope:connect(signal, callback) local c = signal:Connect(callback); table.insert(items, c); return c end
		function scope:add(item) table.insert(items, item); return item end
		function scope:destroy() for _, c in ipairs(items) do if type(c) == "table" or typeof(c) == "RBXScriptConnection" then c:Disconnect() end end end
		return scope
	end

	local SIZES = { M = 12, B = 8, Gap = 8, Turn = { 52, 60 }, Drift = { 52, 52 }, Boost = { 52, 52 }, Brake = { 80, 64 }, Accelerate = { 96, 112 }, Stick = 120 }
	local BOXES = { TurnLeft = "Turn", TurnRight = "Turn", DriftLeft = "Drift", DriftRight = "Drift", Boost = "Boost", Brake = "Brake", Accelerator = "Accelerate" }

	case("_place: Classic arrangement at 844 x 390", function()
		local p = M._place(844, 390, SIZES)
		expect(p.TurnLeft == Vector2.new(12, 322), "TurnLeft " .. tostring(p.TurnLeft))
		expect(p.TurnRight == Vector2.new(72, 322), "TurnRight " .. tostring(p.TurnRight))
		expect(p.DriftLeft == Vector2.new(12, 262), "DriftLeft " .. tostring(p.DriftLeft))
		expect(p.DriftRight == Vector2.new(72, 262), "DriftRight " .. tostring(p.DriftRight))
		expect(p.Boost == Vector2.new(42, 202), "Boost " .. tostring(p.Boost))
		expect(p.Accelerator == Vector2.new(736, 270), "Accelerator " .. tostring(p.Accelerator))
		expect(p.Brake == Vector2.new(648, 318), "Brake " .. tostring(p.Brake))
		expect(p.ThumbstickHit == Vector2.new(12, 262), "ThumbstickHit " .. tostring(p.ThumbstickHit))
		expect(p.TiltGroup == Vector2.new(12, 382), "TiltGroup " .. tostring(p.TiltGroup))
	end)

	case("_place: hit boxes stay on screen, do not overlap, and keep the gap", function()
		for _, size in ipairs({ Vector2.new(844, 390), Vector2.new(568, 320), Vector2.new(1180, 820) }) do
			local p = M._place(size.X, size.Y, SIZES)
			local rects = {}
			for name, control in pairs(BOXES) do
				local box = SIZES[control]
				local rect = { name = name, x0 = p[name].X, y0 = p[name].Y, x1 = p[name].X + box[1], y1 = p[name].Y + box[2] }
				expect(rect.x0 >= 0 and rect.y0 >= 0 and rect.x1 <= size.X and rect.y1 <= size.Y, name .. " leaves the screen")
				table.insert(rects, rect)
			end
			for i = 1, #rects do
				for j = i + 1, #rects do
					local a, b = rects[i], rects[j]
					local apart = a.x1 + SIZES.Gap <= b.x0 or b.x1 + SIZES.Gap <= a.x0 or a.y1 + SIZES.Gap <= b.y0 or b.y1 + SIZES.Gap <= a.y0
					expect(apart, a.name .. " and " .. b.name .. " are closer than the gap")
				end
			end
		end
	end)

	case("_wholePercent: rounds, clamps, survives junk", function()
		expect(M._wholePercent(64.4) == 64, "64.4")
		expect(M._wholePercent(64.5) == 65, "64.5")
		expect(M._wholePercent(-3) == 0, "negative")
		expect(M._wholePercent(250) == 100, "over")
		expect(M._wholePercent(nil) == 0, "nil")
		expect(M._wholePercent(0 / 0) == 0, "nan")
	end)

	case("_controls: the seven Classic names, three of them onboarding marks", function()
		local names, marks = {}, {}
		for _, spec in ipairs(M._controls) do
			names[spec.Name] = spec.Control
			if spec.Mark then marks[spec.Mark] = spec.Name end
		end
		for _, name in ipairs({ "TurnLeft", "TurnRight", "DriftLeft", "DriftRight", "Accelerator", "Brake", "Boost" }) do
			expect(names[name] ~= nil, "missing " .. name)
		end
		expect(marks.DriftLeft == "DriftLeft" and marks.DriftRight == "DriftRight" and marks.Boost == "Boost", "marks")
	end)

	local function mount(size)
		local Metrics = env.Load(KIT .. "Metrics")
		local Layers = env.Load(KIT .. "Layers")
		local ctx = Metrics.Fixed({ Size = size, TouchEnabled = true, Input = "Touch" })
		local stage = env.Detached("Frame")
		stage.Size = UDim2.fromOffset(size.X, size.Y)
		Metrics.Bind(stage, ctx)
		local layer = Layers.Stage(stage, ctx, "Bare")
		local scope = newScope()
		return M.Mount(layer, nil, scope), layer, scope
	end

	for _, size in ipairs({ Vector2.new(844, 390), Vector2.new(1180, 820) }) do
		local tag = " at " .. size.X .. " x " .. size.Y
		case("Mount: every name the kept Classic code and onboarding read exists" .. tag, function()
			local view, layer, scope = mount(size)
			expect(view.Root.Parent == layer.Root and view.Root.Visible == false, "DriveRoot under the layer root, hidden")
			for _, name in ipairs({ "TurnLeft", "TurnRight", "DriftLeft", "DriftRight", "Accelerator", "Brake", "Boost", "TiltDrift", "TiltRecenter" }) do
				local button = view.Buttons[name]
				expect(typeof(button) == "Instance" and button:IsA("GuiButton"), name .. " is a GuiButton")
				expect(button.Name == name, name .. " keeps its name, got " .. button.Name)
				expect(button:IsDescendantOf(view.Root), name .. " is under DriveRoot")
			end
			expect(view.ThumbHit.Name == "ThumbstickHit" and view.ThumbHit:IsA("TextButton"), "ThumbstickHit")
			expect(view.ThumbKnob.Parent == view.ThumbOuter, "the knob is a child of the outer pad")
			expect(view.ThumbKnob.AnchorPoint == Vector2.new(0.5, 0.5), "the knob is centre anchored for the kept code")
			expect(view.Root:FindFirstChild("TiltStatus", true) ~= nil, "TiltStatus")
			view.Destroy()
			view.Destroy()
			scope:destroy()
		end)

		case("Mount: Pressed, the stroke proxy, the status proxy and the boost ring take the kept code's writes" .. tag, function()
			local view, _layer, scope = mount(size)
			for _, button in pairs(view.Buttons) do
				view.Pressed(button, true)
				view.Pressed(button, false)
			end
			view.Pressed(view.ThumbHit, true) -- not a control: ignored
			local Tokens = env.Load(KIT .. "Tokens")
			view.OuterStroke.Color = Tokens.Colour.Cyan
			expect(view.OuterStroke.Color == Tokens.Colour.Cyan, "stroke colour reads back")
			view.TiltStatus.Text = "TILT CALIBRATED"
			view.TiltStatus.Visible = false
			expect(view.TiltStatus.Text == "TILT CALIBRATED" and view.TiltStatus.Visible == false, "status proxy")
			expect(not pcall(function() view.TiltStatus.Size = UDim2.new() end), "unknown status field errors")
			view.SetBoostPercent(64)
			view.SetBoostPercent(64.2)
			view.SetBoostPercent("junk")
			view.Destroy()
			scope:destroy()
		end)

		case("Mount: a second Layout with nothing changed writes nothing" .. tag, function()
			local view, _layer, scope = mount(size)
			view.Layout()
			local writes = 0
			local connections = {}
			for _, item in ipairs(view.Root:GetDescendants()) do
				table.insert(connections, item.Changed:Connect(function() writes += 1 end))
			end
			view.Layout()
			view.Render()
			for _, connection in ipairs(connections) do connection:Disconnect() end
			expect(writes == 0, writes .. " property writes on an unchanged layout")
			view.Destroy()
			scope:destroy()
		end)
	end

	return results
end
