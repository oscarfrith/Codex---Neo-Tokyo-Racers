-- Owns the pure tests for Kit.Text; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.Text_test. Requires: none (modules come from env.Load).
local KIT = "ReplicatedStorage.Modules.Game.UIPulse.Kit."

local SNAPSHOT_PROPERTIES = {
	"Name", "Visible", "LayoutOrder", "ZIndex", "Size", "Position", "AutomaticSize",
	"Text", "TextSize", "TextColor3", "TextTransparency", "TextXAlignment", "TextYAlignment",
	"TextWrapped", "TextTruncate", "FontFace", "Scale", "MaxTextSize",
}

local function fakeScope()
	local items = {}
	local scope = {}
	function scope:connect(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(items, connection)
		return connection
	end
	function scope:add(item)
		table.insert(items, item)
		return item
	end
	function scope:task(callback, ...)
		return task.spawn(callback, ...)
	end
	function scope:destroy()
		for index = #items, 1, -1 do
			local item = items[index]
			if typeof(item) == "RBXScriptConnection" or (type(item) == "table" and item.Disconnect) then
				item:Disconnect()
			end
		end
		table.clear(items)
	end
	return scope
end

local function snapshot(root)
	local instances = root:GetDescendants()
	table.insert(instances, 1, root)
	local parts = {}
	for _, instance in instances do
		table.insert(parts, instance.ClassName)
		for _, property in SNAPSHOT_PROPERTIES do
			local ok, value = pcall(function()
				return instance[property]
			end)
			if ok then
				table.insert(parts, property .. "=" .. tostring(value))
			end
		end
	end
	return table.concat(parts, ";")
end

-- Budget count: the root and its descendants, less UITextSizeConstraints (API 7) and the holder UIScale (API2 2.6).
local function budgetCount(root)
	local count = 1
	for _, instance in root:GetDescendants() do
		if not instance:IsA("UITextSizeConstraint") and not instance:IsA("UIScale") then
			count += 1
		end
	end
	return count
end

return function(Text, env)
	local Metrics = env.Load(KIT .. "Metrics")
	local Tokens = env.Load(KIT .. "Tokens")
	local results = {}

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local function expect(actual, expected, what)
		if actual ~= expected then
			error(what .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
		end
	end

	local function near(actual, expected, what)
		if math.abs(actual - expected) > 1e-6 then
			error(what .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
		end
	end

	local r720 = Metrics.Fixed({ Size = Vector2.new(1280, 720) })
	local r1080 = Metrics.Fixed({ Size = Vector2.new(1920, 1080) })
	local r1440 = Metrics.Fixed({ Size = Vector2.new(2560, 1440) })
	local r2160 = Metrics.Fixed({ Size = Vector2.new(3840, 2160) })
	local c568 = Metrics.Fixed({ Size = Vector2.new(568, 320), TouchEnabled = true, Input = "Touch" })

	local function sizeCase(name, role, ctx, expectedSize, expectedHolder)
		case(name, function()
			local textSize, holderScale = Text.SizeFor(role, ctx)
			expect(textSize, expectedSize, "textSize")
			near(holderScale, expectedHolder, "holderScale")
		end)
	end

	-- API 3.4 check values.
	sizeCase("SizeFor ScreenTitle at 16/24 is 64", "ScreenTitle", r720, 64, 1)
	sizeCase("SizeFor ScreenTitle at 1.0 is 96", "ScreenTitle", r1080, 96, 1)
	sizeCase("SizeFor Label at 16/24 is 17", "Label", r720, 17, 1)
	sizeCase("SizeFor Label at 1.0 is 26", "Label", r1080, 26, 1)
	sizeCase("SizeFor Compact Label at 0.85 is 14", "Label", c568, 14, 1)

	-- Cap at 100; holder scale only for holder roles.
	sizeCase("SizeFor ScreenTitle at 32/24 is 100 under a 1.28 holder", "ScreenTitle", r1440, 100, 1.28)
	sizeCase("SizeFor SectionHead at 2.0 is 100 under a 1.30 holder", "SectionHead", r2160, 100, 1.3)
	sizeCase("SizeFor ButtonMain at 2.0 stops at 100 with no holder", "ButtonMain", r2160, 100, 1)
	sizeCase("SizeFor SectionHead at 1.0 has no holder", "SectionHead", r1080, 65, 1)

	case("SizeFor never returns under 14", function()
		-- No real context reaches the floor with the Phase 1 caps, so this one uses a stub below CompactMin.
		local stub = { Class = "Compact", Scale = 0.5 }
		for _, role in { "ScreenTitle", "Label", "Body", "Value", "TileNameSmall" } do
			local textSize, holderScale = Text.SizeFor(role, stub)
			expect(textSize, 14, role .. " textSize")
			near(holderScale, 1, role .. " holderScale")
		end
		for _, ctx in { r720, r1080, r1440, r2160, c568 } do
			for _, role in { "ScreenTitle", "SectionHead", "ButtonMain", "Button", "MenuButtonMain", "MenuButton",
				"TileName", "TileNameSmall", "Status", "Tab", "Value", "Label", "Body" } do
				local textSize = Text.SizeFor(role, ctx)
				if textSize < 14 or textSize > 100 then
					error(role .. " out of range: " .. tostring(textSize))
				end
			end
		end
	end)

	case("SizeFor and Font refuse an unknown role", function()
		expect(pcall(Text.SizeFor, "Nope", r1080), false, "SizeFor")
		expect(pcall(Text.Font, "Nope"), false, "Font")
	end)

	case("Font faces follow the roles", function()
		expect(Text.Font("Button").Weight, Enum.FontWeight.ExtraBold, "Button weight")
		expect(Text.Font("Button").Style, Enum.FontStyle.Italic, "Button style")
		expect(Text.Font("Label").Weight, Enum.FontWeight.SemiBold, "Label weight")
		expect(Text.Font("Label").Style, Enum.FontStyle.Italic, "Label style")
		expect(Text.Font("Body").Weight, Enum.FontWeight.Medium, "Body weight")
		expect(Text.Font("Body").Style, Enum.FontStyle.Normal, "Body style")
	end)

	case("Ready is a boolean and ReadyChanged connects", function()
		expect(type(Text.Ready), "boolean", "Ready")
		local connection = Text.ReadyChanged:Connect(function() end)
		connection:Disconnect()
		connection:Disconnect()
	end)

	case("estimate: one line, or the wrap width and as many lines as the run needs", function()
		local line = Text._estimate("ABCDE", 20, 0)
		near(line.X, 60, "one line width")
		near(line.Y, 20, "one line height")
		local short = Text._estimate("AB", 20, 100)
		near(short.X, 24, "a run under the wrap width keeps its width")
		near(short.Y, 20, "and is one line")
		local wrapped = Text._estimate(string.rep("A", 20), 20, 100)
		near(wrapped.X, 100, "wrapped width")
		near(wrapped.Y, 60, "three lines for a run of 240 in 100")
	end)

	-- Text.Measure waits through Text._bounded. The limit is stepped with a recorded timer, so no case yields: the
	-- waiting caller is a coroutine made here and the measuring call parks until the case resumes it.
	local function boundedCase(name, body)
		case(name, function()
			local realDelay = Text._delay
			local timers = {}
			Text._delay = function(seconds, callback)
				table.insert(timers, { Seconds = seconds, Fire = callback })
				return task.spawn(function() coroutine.yield() end)
			end
			local ok, detail = pcall(body, timers)
			Text._delay = realDelay
			if not ok then
				error(detail, 0)
			end
		end)
	end

	boundedCase("bounded: an answer that does not wait returns at once with no timer", function(timers)
		local ok, value, timedOut = Text._bounded(2, function(a, b)
			return a + b
		end, 3, 4)
		expect(ok, true, "ok")
		expect(value, 7, "value")
		expect(timedOut, false, "timedOut")
		expect(#timers, 0, "timers")
		local failed, message = Text._bounded(2, function()
			error("no face", 0)
		end)
		expect(failed, false, "a failure is reported as pcall does")
		expect(message, "no face", "message")
	end)

	boundedCase("bounded: gives up at the limit and drops the late answer", function(timers)
		local parked, outcome
		local caller = coroutine.create(function()
			outcome = table.pack(Text._bounded(2, function()
				parked = coroutine.running()
				return coroutine.yield()
			end))
		end)
		assert(coroutine.resume(caller))
		expect(coroutine.status(caller), "suspended", "the caller waits")
		expect(#timers, 1, "one timer")
		expect(timers[1].Seconds, 2, "the limit")
		expect(outcome, nil, "no result before the limit")
		timers[1].Fire()
		expect(coroutine.status(caller), "dead", "the caller is released at the limit")
		expect(outcome[1], false, "ok")
		expect(outcome[2], nil, "no result")
		expect(outcome[3], true, "timedOut")
		assert(coroutine.resume(parked, 5))
		expect(outcome[2], nil, "the late answer changes nothing")
		timers[1].Fire()
	end)

	boundedCase("bounded: an answer inside the limit releases the caller", function(timers)
		local parked, outcome
		local caller = coroutine.create(function()
			outcome = table.pack(Text._bounded(2, function()
				parked = coroutine.running()
				return coroutine.yield()
			end))
		end)
		assert(coroutine.resume(caller))
		expect(#timers, 1, "one timer")
		assert(coroutine.resume(parked, 5))
		expect(coroutine.status(caller), "dead", "the caller is released by the answer")
		expect(outcome[1], true, "ok")
		expect(outcome[2], 5, "result")
		expect(outcome[3], false, "timedOut")
		timers[1].Fire()
		expect(outcome[2], 5, "the timer firing afterwards changes nothing")
	end)

	local function mount(ctx, props)
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, ctx)
		local scope = fakeScope()
		return Text.Label(parent, props, scope), parent, scope
	end

	case("Label: structure, upper-casing and budget 2", function()
		local label, parent, scope = mount(r1080, { Text = "Spine Wing", Role = "TileName" })
		local root = label.Instance
		expect(root.ClassName, "Frame", "root class")
		expect(root.Name, "Label", "root name")
		expect(root.Parent, parent, "root parent")
		local child = root:FindFirstChild("Label")
		expect(child ~= nil and child.ClassName, "TextLabel", "child class")
		expect(child.Text, "SPINE WING", "upper-cased text")
		expect(child.TextSize, 46, "TextSize")
		expect(child.TextScaled, false, "TextScaled")
		expect(child:FindFirstChildOfClass("UITextSizeConstraint") ~= nil, true, "display role is Fixed")
		expect(root:FindFirstChildOfClass("UIScale"), nil, "no UIScale under 100")
		expect(budgetCount(root), 2, "budget")
		label.Destroy()
		scope:destroy()
	end)

	case("Label: Body keeps its case and is not Fixed; shadow budget 3", function()
		local label, _, scope = mount(r1080, { Text = "Buy Zephyr to unlock", Role = "Body", Shadow = true })
		local root = label.Instance
		local child = root:FindFirstChild("Label")
		expect(child.Text, "Buy Zephyr to unlock", "text")
		expect(child:FindFirstChildOfClass("UITextSizeConstraint"), nil, "body role grows")
		expect(root:FindFirstChild("Shadow") ~= nil, true, "shadow")
		expect(budgetCount(root), 3, "budget")
		label.Set({ Shadow = false })
		expect(root:FindFirstChild("Shadow"), nil, "shadow removed")
		expect(budgetCount(root), 2, "budget without shadow")
		label.Destroy()
		scope:destroy()
	end)

	case("Label: holder UIScale only above 100", function()
		local label, _, scope = mount(r1440, { Text = "Customise", Role = "ScreenTitle" })
		local scaler = label.Instance:FindFirstChildOfClass("UIScale")
		expect(scaler ~= nil, true, "UIScale present")
		expect(budgetCount(label.Instance), 2, "the holder UIScale is outside the budget")
		near(scaler.Scale, 1.28, "UIScale.Scale")
		expect(label.Instance:FindFirstChild("Label").TextSize, 100, "TextSize")
		label.Destroy()
		scope:destroy()
	end)

	case("Label: MaxWidth fixes the box and truncates; Wrap grows downward", function()
		local label, _, scope = mount(r1080, { Text = "Shifted Canal Sprint", Role = "TileName", MaxWidth = 200 })
		local root = label.Instance
		local child = root:FindFirstChild("Label")
		expect(root.Size.X.Offset, 200, "root width")
		expect(root.AutomaticSize, Enum.AutomaticSize.None, "root AutomaticSize")
		expect(child.TextTruncate, Enum.TextTruncate.AtEnd, "TextTruncate")
		label.Set({ Wrap = true })
		expect(root.AutomaticSize, Enum.AutomaticSize.Y, "root AutomaticSize wrapped")
		expect(child.TextWrapped, true, "TextWrapped")
		expect(child.TextTruncate, Enum.TextTruncate.None, "TextTruncate wrapped")
		label.Destroy()
		scope:destroy()
	end)

	case("Label: Set with an unchanged patch changes no property", function()
		local props = { Text = "Wing 2/4", Role = "SectionHead", Colour = "Pink", Align = "Right", MaxWidth = 300,
			Shadow = true, LayoutOrder = 3 }
		local label, _, scope = mount(r1080, props)
		local before = snapshot(label.Instance)
		label.Set(table.clone(props))
		expect(snapshot(label.Instance), before, "snapshot")
		label.Set({ Text = "Wing 3/4" })
		expect(label.Instance:FindFirstChild("Label").Text, "WING 3/4", "changed text")
		label.Destroy()
		scope:destroy()
	end)

	case("Label: unknown key, role, colour and align error", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r1080)
		local scope = fakeScope()
		expect(pcall(Text.Label, parent, { Text = "A", Role = "Label", Nope = 1 }, scope), false, "unknown key")
		expect(pcall(Text.Label, parent, { Text = "A", Role = "Nope" }, scope), false, "unknown role")
		expect(pcall(Text.Label, parent, { Text = "A" }, scope), false, "missing role")
		expect(pcall(Text.Label, parent, { Text = "A", Role = "Label", Colour = "Green" }, scope), false, "colour")
		expect(pcall(Text.Label, parent, { Text = "A", Role = "Label", Align = "Middle" }, scope), false, "align")
		expect(#parent:GetChildren(), 0, "nothing left behind")
		local label = Text.Label(parent, { Text = "A", Role = "Label" }, scope)
		expect(pcall(label.Set, { Nope = 1 }), false, "Set unknown key")
		expect(pcall(label.Set, { Role = "Nope" }), false, "Set unknown role")
		label.Destroy()
		scope:destroy()
	end)

	-- API2 2.6 ------------------------------------------------------------------------------------------------
	case("Label: display roles and Value are Fixed by default; Label and Body grow", function()
		for _, role in { "ScreenTitle", "Button", "Tab", "Status", "Value" } do
			local label, _, scope = mount(r1080, { Text = "74", Role = role })
			expect(label.Instance:FindFirstChild("Label"):FindFirstChildOfClass("UITextSizeConstraint") ~= nil, true,
				role .. " is Fixed")
			label.Destroy()
			scope:destroy()
		end
		for _, role in { "Label", "Body" } do
			local label, _, scope = mount(r1080, { Text = "Exotic", Role = role })
			expect(label.Instance:FindFirstChild("Label"):FindFirstChildOfClass("UITextSizeConstraint"), nil,
				role .. " grows")
			label.Set({ Fixed = true })
			expect(label.Instance:FindFirstChild("Label"):FindFirstChildOfClass("UITextSizeConstraint") ~= nil, true,
				role .. " with Fixed = true")
			label.Destroy()
			scope:destroy()
		end
	end)

	case("Label: the shadow uses Opacity.TextShadow and Space.TextShadowOffset", function()
		local label, _, scope = mount(r1080, { Text = "Wing 2/4", Role = "SectionHead", Shadow = true })
		local shadow = label.Instance:FindFirstChild("Shadow")
		local child = label.Instance:FindFirstChild("Label")
		expect(shadow ~= nil, true, "shadow")
		near(shadow.TextTransparency, 1 - Tokens.Opacity.TextShadow, "shadow transparency")
		expect(shadow.TextColor3, Tokens.Colour.Ink, "shadow colour")
		local drop = r1080.Px(Tokens.Space.TextShadowOffset)
		expect(shadow.Position.X.Offset - child.Position.X.Offset, drop, "shadow x offset")
		expect(shadow.Position.Y.Offset - child.Position.Y.Offset, drop, "shadow y offset")
		label.Destroy()
		scope:destroy()
	end)

	case("RawLabel: one plain TextLabel with the face, size and shift of the role; SizeLock only when Fixed", function()
		local parent = env.Detached("Frame")
		local fixed = Text.RawLabel(parent, "Value", r1080)
		expect(fixed.ClassName, "TextLabel", "class")
		expect(fixed.Parent, parent, "parent")
		expect(fixed.TextSize, (Text.SizeFor("Value", r1080)), "TextSize")
		expect(fixed.FontFace.Family, Text.Font("Value").Family, "font family")
		expect(fixed.FontFace.Weight, Enum.FontWeight.ExtraBold, "font weight")
		expect(fixed.TextScaled, false, "TextScaled")
		expect(fixed.BackgroundTransparency, 1, "background")
		expect(fixed.TextColor3, Tokens.Colour.White, "colour")
		local lock = fixed:FindFirstChild("SizeLock")
		expect(lock ~= nil and lock:IsA("UITextSizeConstraint"), true, "SizeLock on a Fixed role")
		expect(lock.MaxTextSize, fixed.TextSize, "SizeLock.MaxTextSize")
		expect(fixed.Position.Y.Offset <= 0, true, "the baseline shift lifts the label")
		expect(#fixed:GetChildren(), 1, "nothing else under the label")

		local grows = Text.RawLabel(parent, "Label", c568)
		expect(grows:FindFirstChild("SizeLock"), nil, "no SizeLock on a growing role")
		expect(grows.TextSize, 14, "Compact floor")
		local capped = Text.RawLabel(parent, "ScreenTitle", r2160)
		expect(capped.TextSize, 100, "a holder role stops at 100 in a raw label")
		expect(pcall(Text.RawLabel, parent, "Nope", r1080), false, "unknown role")
		expect(#parent:GetChildren(), 3, "three labels, nothing left by the failed call")
	end)

	case("StyleForeign: face, size, white and no stroke on a label the kit did not build", function()
		local label = env.Detached("TextLabel")
		label.TextStrokeTransparency = 0
		label.Text = "3"
		Text.StyleForeign(label, "ScreenTitle")
		expect(label.FontFace.Family, Text.Font("ScreenTitle").Family, "font family")
		expect(label.FontFace.Style, Enum.FontStyle.Italic, "font style")
		expect(label.TextColor3, Tokens.Colour.White, "colour")
		expect(label.TextStrokeTransparency, 1, "stroke")
		expect(label.TextSize >= 14 and label.TextSize <= 100, true, "TextSize in range")
		expect(label.Text, "3", "text untouched")
		expect(#label:GetChildren(), 0, "no child added")
		expect(pcall(Text.StyleForeign, label, "Nope"), false, "unknown role")
		expect(pcall(Text.StyleForeign, env.Detached("Frame"), "Label"), false, "not a TextLabel")
	end)

	case("ReadyChanged is a Luau signal with Connect, Once and Wait", function()
		expect(type(Text.ReadyChanged), "table", "signal type")
		expect(type(Text.ReadyChanged.Connect), "function", "Connect")
		expect(type(Text.ReadyChanged.Once), "function", "Once")
		expect(type(Text.ReadyChanged.Wait), "function", "Wait")
		local connection = Text.ReadyChanged:Once(function() end)
		connection:Disconnect()
	end)

	case("Label: Destroy leaves the parent empty and is repeat-safe", function()
		local label, parent, scope = mount(c568, { Text = "Exotic", Role = "Label", Upper = true })
		expect(label.Instance:FindFirstChild("Label").Text, "EXOTIC", "Upper = true")
		expect(label.Instance:FindFirstChild("Label").TextSize, 14, "Compact floor")
		label.Destroy()
		expect(#parent:GetChildren(), 0, "parent children")
		label.Destroy()
		label.Set({ Text = "Late" })
		scope:destroy()
	end)

	return results
end
