-- Pure tests for Kit.Gauge. No yield, nothing parented into the game tree, every component destroyed before return.
return function(M, env)
	local results = {}
	local cleanups = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		for index = #cleanups, 1, -1 do pcall(cleanups[index]) end
		table.clear(cleanups)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local Metrics = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Metrics")
	local Tokens = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens")
	local Sprites = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Sprites")

	local REGULAR = Vector2.new(1920, 1080)
	local COMPACT = Vector2.new(844, 390)
	local START = Sprites.Rings.Gauge.StartDeg
	local SWEEP = Sprites.Rings.Gauge.SweepDeg

	local function stage(size, touch)
		local frame = env.Detached("Frame")
		Metrics.Bind(frame, Metrics.Fixed({ Size = size, TouchEnabled = touch == true,
			Input = if touch then "Touch" else "KeyboardAndMouse" }))
		return frame
	end

	-- The Core.ConnectionScope shape, without requiring a module from the place.
	local function newScope()
		local items = {}
		local scope = {}
		function scope.connect(_, signal, callback)
			local connection = signal:Connect(callback)
			table.insert(items, connection)
			return connection
		end
		function scope.add(_, item)
			table.insert(items, item)
			return item
		end
		function scope.task(self, callback, ...)
			return self:add(task.spawn(callback, ...))
		end
		function scope.destroy(_)
			for index = #items, 1, -1 do
				local item = items[index]
				local kind = typeof(item)
				if kind == "RBXScriptConnection" then item:Disconnect()
				elseif kind == "Instance" then item:Destroy()
				elseif kind == "function" then pcall(item)
				elseif kind == "thread" then
					if coroutine.status(item) ~= "dead" then pcall(task.cancel, item) end
				elseif kind == "table" then
					local method = item.destroy or item.Destroy or item.Disconnect
					if method then pcall(method, item) end
				end
			end
			table.clear(items)
		end
		table.insert(cleanups, function() scope:destroy() end)
		return scope
	end

	local function gaugeOn(size, touch, props)
		local parent = stage(size, touch)
		local scope = newScope()
		local gauge = M.New(parent, props or {}, scope)
		table.insert(cleanups, gauge.Destroy)
		return gauge, parent, scope
	end

	-- Descendants plus the root, without the text size locks the budgets leave out (API2 3).
	local function budgetOf(root)
		local total = 1
		for _, item in ipairs(root:GetDescendants()) do
			if not item:IsA("UITextSizeConstraint") then total += 1 end
		end
		return total
	end

	-- The model the reveal relies on: a mask at `rotation` shows the angles (rotation + 90, rotation + 270), that is
	-- the points whose direction has a negative component along the gradient.
	local function shows(rotation, theta)
		return math.cos(math.rad(theta - rotation)) < -1e-9
	end

	-- Whether the arc is lit at angle theta (135..405, clockwise from +X): the left window holds the angles below
	-- 270 and the right window the rest.
	local function lit(left, right, theta)
		if theta < 270 then return shows(left, theta) end
		return shows(right, theta)
	end

	------------------------------------------------------------------------------------------------------------------
	-- Pure maths
	------------------------------------------------------------------------------------------------------------------

	case("angles: the check values", function()
		local left, right = M.Angles(0)
		expect(left == 200 and right == -20, "empty: both masks parked in the bottom gap, got " .. left .. ", " .. right)
		left, right = M.Angles(0.25)
		expect(left == START + 67.5 + 90 and right == -20, "a quarter: left edge at 202.5 degrees")
		left, right = M.Angles(0.5)
		expect(left == 380 and right == -20, "half: exactly 12 o'clock, left full and parked, right still empty")
		left, right = M.Angles(0.75)
		expect(left == 380 and right == 67.5, "three quarters: right edge 67.5 past 12 o'clock")
		left, right = M.Angles(1)
		expect(left == 380 and right == 135, "full: right edge at 45 degrees")
	end)

	case("angles: quantised to half a degree, clamped, never not-a-number", function()
		for step = 0, 2000 do
			local left, right = M.Angles(step / 2000)
			expect((left * 2) % 1 == 0 and (right * 2) % 1 == 0, "half-degree values at " .. step)
		end
		local left, right = M.Angles(0.0005)
		expect(left == 200 and right == -20, "under a quarter of a degree rounds to empty")
		left = M.Angles(0.001)
		expect(left == START + 0.5 + 90, "0.27 degrees rounds to half a degree")
		local a, b = M.Angles(0.5001)
		local c, d = M.Angles(0.5004)
		expect(a == c and b == d, "two fractions inside one half-degree give the same rotations")
		left, right = M.Angles(-3)
		expect(left == 200 and right == -20, "below 0 is empty")
		left, right = M.Angles(7)
		expect(left == 380 and right == 135, "above 1 is full")
		left, right = M.Angles(0 / 0)
		expect(left == 200 and right == -20, "not a number is empty")
		left, right = M.Angles(nil)
		expect(left == 200 and right == -20, "nil is empty")
	end)

	case("reveal: the two half windows light exactly the arc up to the fill angle", function()
		for step = 0, 40 do
			local fraction = step / 40
			local left, right, degrees = M._sweep(START, SWEEP, fraction)
			local fill = START + degrees
			-- sample the arc every 1.25 degrees, off the half-degree grid and off the seam
			local theta = START + 0.3
			while theta < START + SWEEP do
				local want = theta < fill
				expect(lit(left, right, theta) == want, string.format("fraction %.3f: angle %.2f should be %s",
					fraction, theta, if want then "lit" else "dark"))
				theta += 1.25
			end
		end
	end)

	case("reveal: an empty or full half keeps its mask edge away from the seam", function()
		-- Left full and right empty must hold for a band around 12 o'clock, not just at the exact angle.
		local left, right = M.Angles(0.5)
		for _, theta in ipairs({ 250, 260, 269, 269.9 }) do
			expect(shows(left, theta), "left half lit at " .. theta)
		end
		for _, theta in ipairs({ 270.1, 271, 280, 300, 360, 404 }) do
			expect(not shows(right, theta), "right half dark at " .. theta)
		end
		-- Empty: nothing of the arc shows, including its first degrees.
		left, right = M.Angles(0)
		for _, theta in ipairs({ 120, 135, 136, 180, 269 }) do
			expect(not shows(left, theta), "left half dark at " .. theta)
		end
		-- Full: the whole left half down to before the arc's start.
		left, right = M.Angles(1)
		for _, theta in ipairs({ 120, 135, 200, 269.9 }) do
			expect(shows(left, theta), "left half lit at " .. theta)
		end
		for _, theta in ipairs({ 270.1, 300, 360, 404.5 }) do
			expect(shows(right, theta), "right half lit at " .. theta)
		end
		expect(not shows(right, 406), "nothing past the end of the sweep")
	end)

	case("percent and speed: whole numbers", function()
		expect(M._percent(0) == 0 and M._percent(1) == 100, "ends")
		expect(M._percent(0.644) == 64 and M._percent(0.646) == 65, "rounded")
		expect(M._percent(-1) == 0 and M._percent(3) == 100, "clamped")
		expect(M._percent(0 / 0) == 0 and M._percent(nil) == 0, "not a number")
		expect(M._wholeSpeed(141.4) == 141 and M._wholeSpeed(141.6) == 142, "rounded")
		expect(M._wholeSpeed(-5) == 0 and M._wholeSpeed(1200) == 999, "clamped to three digits")
		expect(M._wholeSpeed(0 / 0) == 0 and M._wholeSpeed("x") == 0, "not a number")
	end)

	case("tip: on the arc radius at the fill angle, whole pixels", function()
		local x, y = M._tipOffset(0, 100)
		expect(x == -71 and y == 71, "start of the sweep is bottom-left, got " .. x .. ", " .. y)
		x, y = M._tipOffset(135, 100)
		expect(x == 0 and y == -100, "half the sweep is 12 o'clock")
		x, y = M._tipOffset(270, 100)
		expect(x == 71 and y == 71, "the end is bottom-right")
		x, y = M._tipOffset(45, 200)
		expect(x == -200 and y == 0, "9 o'clock")
	end)

	------------------------------------------------------------------------------------------------------------------
	-- Component
	------------------------------------------------------------------------------------------------------------------

	local function maskOf(root, window, image)
		return root:FindFirstChild(window):FindFirstChild(image):FindFirstChild("Mask")
	end

	case("gauge: builds the stack on a detached parent, within budget", function()
		local gauge, parent = gaugeOn(REGULAR, false)
		local root = gauge.Instance
		expect(#parent:GetChildren() == 1 and root.Parent == parent and root.Name == "Gauge", "one root named Gauge")
		local side = Tokens.Space.GaugeSize - Tokens.Space.GaugeSize % 2
		expect(root.Size == UDim2.fromOffset(side, side), "an even square of GaugeSize at 1080")
		for _, name in ipairs({ "Track", "Ticks", "ArcLeft", "ArcRight", "BoostLeft", "BoostRight", "Tip", "Speed",
			"Unit", "BoostText" }) do
			expect(root:FindFirstChild(name) ~= nil, name .. " exists")
		end
		for _, name in ipairs({ "ArcLeft", "ArcRight", "BoostLeft", "BoostRight" }) do
			local window = root:FindFirstChild(name)
			expect(window.ClipsDescendants == true, name .. " clips")
			expect(window.Size == UDim2.fromOffset(side / 2, side), name .. " is half the frame")
			for _, image in ipairs(window:GetChildren()) do
				expect(image:IsA("ImageLabel") and image.Size == UDim2.fromOffset(side, side), "full-size image in " .. name)
				local gradient = image:FindFirstChild("Mask")
				expect(gradient ~= nil and gradient:IsA("UIGradient"), "one mask per revealed image")
				expect(#gradient.Transparency.Keypoints == 4, "a hard step")
			end
		end
		expect(root.ArcRight.Position == UDim2.fromOffset(side / 2, 0), "the right window starts on the centre line")
		expect(root.ArcRight.Arc.Position == UDim2.fromOffset(-side / 2, 0), "its image is shifted back to the frame")
		expect(root.ArcLeft:FindFirstChild("Glow") ~= nil and root.ArcLeft:FindFirstChild("Arc") ~= nil, "glow and arc share windows")
		expect(root.BoostLeft:FindFirstChild("BoostArc") ~= nil, "boost arc image")
		expect(root.Track.ZIndex < root.Ticks.ZIndex and root.Ticks.ZIndex < root.ArcLeft.ZIndex
			and root.ArcLeft.ZIndex < root.BoostLeft.ZIndex and root.BoostLeft.ZIndex < root.Tip.ZIndex
			and root.Tip.ZIndex < root.Speed.ZIndex, "stack order bottom to top")
		expect(root.Unit.Text == "MPH" and root.BoostText.Text == "BOOST 0%", "unit and boost text")
		expect(root.BoostText.Visible == true, "boost text shown on Regular")
		expect(root.Tip.Visible == false, "no tip on an empty arc")
		expect(budgetOf(root) <= 26, "budget 26, got " .. budgetOf(root))
		local left, right = M.Angles(0)
		expect(maskOf(root, "ArcLeft", "Arc").Rotation == left and maskOf(root, "ArcRight", "Arc").Rotation == right,
			"masks start empty")
	end)

	case("gauge: Compact default hides the boost text; the size is the caller's", function()
		local gauge = gaugeOn(COMPACT, true, { Size = Tokens.Space.CompactGauge })
		local root = gauge.Instance
		expect(root.Size == UDim2.fromOffset(Tokens.Space.CompactGauge, Tokens.Space.CompactGauge), "92 at 844x390")
		expect(root.BoostText.Visible == false, "no boost line on Compact")
		expect(budgetOf(root) <= 26, "budget 26")
		gauge.Set({ ShowBoostText = true })
		expect(root.BoostText.Visible == true, "ShowBoostText turns it on")
	end)

	case("gauge: in a slot the root takes the slot's anchor", function()
		local slot = stage(REGULAR, false)
		slot.Name = "SlotGauge"
		slot.AnchorPoint = Vector2.new(1, 1)
		local gauge = M.New(slot, {}, newScope())
		table.insert(cleanups, gauge.Destroy)
		expect(gauge.Instance.AnchorPoint == Vector2.new(1, 1), "bottom-right anchor copied")
	end)

	case("gauge: a parked car writes nothing", function()
		local gauge = gaugeOn(REGULAR, false)
		expect(gauge._writes() == 0, "no writes at build")
		for _ = 1, 10 do
			gauge.SetSpeed(0, 0)
			gauge.SetBoost(0)
		end
		expect(gauge._writes() == 0, "SetSpeed(0, 0) and SetBoost(0) on a fresh gauge write nothing")
	end)

	case("gauge: SetSpeed writes on change only (whole number, half degree)", function()
		local gauge = gaugeOn(REGULAR, false)
		local root = gauge.Instance
		local arcMask = maskOf(root, "ArcLeft", "Arc")
		local glowMask = maskOf(root, "ArcLeft", "Glow")

		-- 0.3 of the sweep is 81 degrees: the fill ends at 216, in the left half.
		gauge.SetSpeed(72, 0.3)
		local first = gauge._writes()
		expect(first == 5, "digits, two left masks, tip position and tip visibility, got " .. first)
		local left = M.Angles(0.3)
		expect(left == START + 81 + 90, "left edge at 216 degrees")
		expect(arcMask.Rotation == left and glowMask.Rotation == left, "glow and arc share the angle")
		expect(maskOf(root, "ArcRight", "Arc").Rotation == -20, "right half untouched before 12 o'clock")
		expect(root.Tip.Visible == true, "tip on")

		gauge.SetSpeed(72, 0.3)
		expect(gauge._writes() == first, "the same values write nothing")
		gauge.SetSpeed(72.3, 0.3001)
		expect(gauge._writes() == first, "inside the same whole number and half degree: nothing")
		gauge.SetSpeed(71.6, 0.2999)
		expect(gauge._writes() == first, "still 72 and the same half degree: nothing")

		gauge.SetSpeed(73, 0.3)
		expect(gauge._writes() == first + 1, "a new whole number is one write (the digits)")
		local before = gauge._writes()
		gauge.SetSpeed(73, 0.31)
		local cost = gauge._writes() - before
		expect(cost >= 2 and cost <= 3, "an angle step is two mask writes and at most one tip write, got " .. cost)
		expect(arcMask.Rotation == (M.Angles(0.31)), "mask moved")

		-- Past 12 o'clock (the r00 frame: 142 at 0.59) the left half is full and the right half carries the edge.
		gauge.SetSpeed(142, 0.59)
		local fullLeft, right = M.Angles(0.59)
		expect(fullLeft == 380 and arcMask.Rotation == 380, "left half full and parked")
		expect(maskOf(root, "ArcRight", "Arc").Rotation == right and right == 24.5, "right edge 24.5 past 12 o'clock")
		before = gauge._writes()
		gauge.SetSpeed(142, 0.59)
		expect(gauge._writes() == before, "the same values write nothing in the right half either")
	end)

	case("gauge: a steady drive costs at most 2 gradient writes, 1 tip write and the digits per call", function()
		local gauge = gaugeOn(REGULAR, false)
		local worst = 0
		-- 0.2 degrees a call through the left half, then through the right half (not across the seam). The first
		-- call of each range is the jump there and is not measured.
		for _, range in ipairs({ { 0.05, 0.45 }, { 0.55, 0.95 } }) do
			local fraction = range[1]
			gauge.SetSpeed(240 * fraction, fraction)
			local last = gauge._writes()
			while fraction < range[2] do
				fraction += 0.2 / SWEEP
				gauge.SetSpeed(240 * fraction, fraction)
				worst = math.max(worst, gauge._writes() - last)
				last = gauge._writes()
			end
		end
		expect(worst <= 4, "at most 4 property writes in a call, got " .. worst)
		-- Crossing 12 o'clock moves both halves once.
		gauge.SetSpeed(100, 0.49)
		local last = gauge._writes()
		gauge.SetSpeed(100, 0.51)
		expect(gauge._writes() - last <= 5, "the crossing call writes both halves once")
		local root = gauge.Instance
		local left, right = M.Angles(0.51)
		expect(maskOf(root, "ArcLeft", "Arc").Rotation == left and maskOf(root, "ArcRight", "Arc").Rotation == right,
			"both halves at their angles")
		expect(maskOf(root, "ArcLeft", "Glow").Rotation == left and maskOf(root, "ArcRight", "Glow").Rotation == right,
			"glow follows")
	end)

	case("gauge: SetBoost writes on a whole-percent change only", function()
		local gauge = gaugeOn(REGULAR, false)
		local root = gauge.Instance
		gauge.SetBoost(0.64)
		local first = gauge._writes()
		expect(first >= 2, "text and mask written")
		expect(root.BoostText.Text == "BOOST 64%", "text")
		local left, right = M.Angles(0.64)
		expect(maskOf(root, "BoostLeft", "BoostArc").Rotation == left and maskOf(root, "BoostRight", "BoostArc").Rotation == right,
			"boost masks at 64%")
		gauge.SetBoost(0.64)
		gauge.SetBoost(0.6449)
		gauge.SetBoost(0.6351)
		expect(gauge._writes() == first, "the same whole percent writes nothing")
		gauge.SetBoost(0.65)
		expect(gauge._writes() > first and root.BoostText.Text == "BOOST 65%", "a new percent writes")
		gauge.SetBoost(1)
		expect(root.BoostText.Text == "BOOST 100%", "full")
		expect(maskOf(root, "ArcLeft", "Arc").Rotation == (M.Angles(0)), "the speed arc is not touched by boost")
	end)

	case("gauge: SetVisibleBoost and SetUnit", function()
		local gauge = gaugeOn(REGULAR, false)
		local root = gauge.Instance
		gauge.SetVisibleBoost(false)
		expect(root.BoostLeft.Visible == false and root.BoostRight.Visible == false and root.BoostText.Visible == false,
			"boost arc and text hidden")
		gauge.SetVisibleBoost(true)
		expect(root.BoostLeft.Visible and root.BoostText.Visible, "shown again")
		gauge.Set({ ShowBoostText = false })
		expect(root.BoostLeft.Visible and root.BoostText.Visible == false, "text off, arc on")
		gauge.SetUnit("KM/H")
		expect(root.Unit.Text == "KM/H", "unit text")
		expect(not pcall(gauge.SetUnit, "KNOTS"), "unknown unit errors")
	end)

	case("gauge: Set unchanged writes nothing, unknown key errors, Destroy is repeat-safe", function()
		local gauge, parent = gaugeOn(REGULAR, false, { Name = "Gauge", LayoutOrder = 2, Unit = "MPH" })
		local root = gauge.Instance
		local snapshot = { root.Name, root.LayoutOrder, root.Visible, root.Size, root.Position, #root:GetDescendants(),
			root.Unit.Text, gauge._writes() }
		gauge.Set({ Name = "Gauge", LayoutOrder = 2, Unit = "MPH", Visible = true })
		local after = { root.Name, root.LayoutOrder, root.Visible, root.Size, root.Position, #root:GetDescendants(),
			root.Unit.Text, gauge._writes() }
		for index = 1, #snapshot do expect(snapshot[index] == after[index], "property " .. index .. " changed") end
		gauge.Set({ Visible = false })
		expect(root.Visible == false, "Visible written")
		gauge.Set({ Size = Tokens.Space.GaugeTouchSize })
		expect(root.Size.X.Offset == Tokens.Space.GaugeTouchSize, "Size relays out")
		expect(root.ArcRight.Position.X.Offset == Tokens.Space.GaugeTouchSize / 2, "windows follow the size")
		expect(not pcall(gauge.Set, { Colour = "Pink" }), "unknown key must error")
		expect(not pcall(gauge.Set, { Size = -1 }), "a bad size must error")
		expect(not pcall(M.New, parent, { Nope = 1 }, newScope()), "unknown prop must error")
		gauge.Destroy()
		gauge.Destroy()
		expect(#parent:GetChildren() == 0, "parent empty after Destroy")
		gauge.SetSpeed(100, 0.5)
		gauge.SetBoost(0.5)
		gauge.SetVisibleBoost(false)
		gauge.Set({ Unit = "KM/H" })
	end)

	case("gauge: destroying the scope destroys the component", function()
		local gauge, parent, scope = gaugeOn(REGULAR, false)
		gauge.SetSpeed(100, 0.4)
		scope:destroy()
		expect(#parent:GetChildren() == 0, "parent empty after scope destroy")
	end)

	case("gauge: builds with every asset empty", function()
		local real = Tokens.Asset
		local stubbed = pcall(function() Tokens.Asset = function() return nil end end)
		if not stubbed then return end -- a frozen Tokens table cannot be stubbed; the gallery covers the empty state
		table.insert(cleanups, function() Tokens.Asset = real end)
		local gauge = gaugeOn(REGULAR, false)
		local root = gauge.Instance
		expect(root.Track.Image == "" and root.ArcLeft.Arc.Image == "", "no image, no error")
		expect(root.Size.X.Offset == Tokens.Space.GaugeSize - Tokens.Space.GaugeSize % 2, "the size does not change")
		gauge.SetSpeed(88, 0.3)
		gauge.SetBoost(0.5)
	end)

	return results
end
