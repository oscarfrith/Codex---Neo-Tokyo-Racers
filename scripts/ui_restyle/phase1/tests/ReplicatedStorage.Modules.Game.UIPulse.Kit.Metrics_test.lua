-- Pure tests for Kit.Metrics (API.md 6 and 13). Detached instances only, no yield.
return function(M: any, env: any): { { name: string, ok: boolean, detail: string? } }
	local results = {}
	local function case(name, body)
		local ok, detail = pcall(body)
		if ok then
			table.insert(results, { name = "Metrics: " .. name, ok = true })
		else
			table.insert(results, { name = "Metrics: " .. name, ok = false, detail = tostring(detail) })
		end
	end

	local function near(a, b)
		return math.abs(a - b) < 1e-9
	end

	local function compute(width, height, wasCompact, touch, input)
		return M.Compute({
			SafeSize = Vector2.new(width, height),
			TouchEnabled = touch == true,
			PreferredInput = input or "KeyboardAndMouse",
			WasCompact = wasCompact,
		})
	end

	case("scale check values", function()
		local checks = {
			{ 1280, 720, "Regular", 16 / 24 },
			{ 1920, 1080, "Regular", 1 },
			{ 2560, 1440, "Regular", 32 / 24 },
			{ 2065, 1152, "Regular", 25 / 24 },
			{ 3440, 1440, "Regular", 32 / 24 },
			{ 3840, 2160, "Regular", 2 },
			{ 7680, 4320, "Regular", 2 },
			{ 1180, 820, "Regular", 17 / 24 },
			{ 844, 390, "Compact", 1 },
			{ 568, 320, "Compact", 0.85 },
			{ 640, 360, "Compact", 0.9 },
			{ 932, 430, "Compact", 1.1 },
			{ 1100, 590, "Compact", 1.1 },
		}
		for _, check in checks do
			local got = compute(check[1], check[2], false)
			local label = check[1] .. "x" .. check[2]
			assert(got.Class == check[3], label .. " class " .. got.Class)
			assert(near(got.Scale, check[4]), label .. " scale " .. tostring(got.Scale))
		end
	end)

	case("Compact enter and leave", function()
		assert(compute(1000, 600, false).Class == "Regular", "1000x600 enters only below the line")
		assert(compute(1000, 599, false).Class == "Compact", "height under 600")
		assert(compute(999, 800, false).Class == "Compact", "width under 1000")
		assert(compute(1280, 620, false).Class == "Regular", "620 high, was Regular")
		assert(compute(1280, 620, true).Class == "Compact", "620 high, was Compact: stays")
		assert(compute(1280, 639, true).Class == "Compact", "639 high, was Compact: stays")
		assert(compute(1280, 640, true).Class == "Regular", "640 high leaves")
		assert(compute(999, 700, true).Class == "Compact", "narrow stays Compact")
		assert(compute(1280, 620, nil).Class == "Regular", "WasCompact nil reads as false")
	end)

	case("bands", function()
		assert(compute(1599, 1080).Band == "Narrow", "1599")
		assert(compute(1600, 1080).Band == "Normal", "1600")
		assert(compute(2300, 1080).Band == "Normal", "2300")
		assert(compute(2301, 1080).Band == "Wide", "2301")
		assert(compute(844, 390).Band == "Narrow", "Compact carries a band")
	end)

	case("arrangement and input", function()
		assert(compute(1920, 1080, false, false).Arrangement == "Standard", "no touch")
		assert(compute(1920, 1080, false, true).Arrangement == "TouchDrive", "touch")
		assert(compute(844, 390, false, true, "Gamepad").Class == "Compact", "class is geometry only")
		assert(compute(1920, 1080, false, false, "KeyboardAndMouse").Input == "KeyboardAndMouse", "kbm")
		assert(compute(1920, 1080, false, false, "Gamepad").Input == "Gamepad", "gamepad")
		assert(compute(1920, 1080, false, false, "MicroGamepad").Input == "Gamepad", "MicroGamepad maps")
		assert(compute(1920, 1080, false, true, "Touch").Input == "Touch", "touch input")
	end)

	case("Compute is pure", function()
		local input = { SafeSize = Vector2.new(1920, 1080), TouchEnabled = false, PreferredInput = "Gamepad" }
		local a = M.Compute(input)
		local b = M.Compute(input)
		assert(a ~= b, "returns a new table")
		assert(a.Scale == b.Scale and a.Class == b.Class and a.Input == b.Input, "same answer")
		assert(input.WasCompact == nil and input.PreferredInput == "Gamepad", "input untouched")
	end)

	case("Fixed context fields", function()
		local ctx = M.Fixed({
			Size = Vector2.new(844, 390),
			TouchEnabled = true,
			Input = "Touch",
			TopBarHeight = 52,
			TopBarKeepOut = Vector2.new(120, 52),
		})
		assert(ctx.Class == "Compact" and ctx.Arrangement == "TouchDrive" and ctx.Input == "Touch", "answers")
		assert(ctx.Scale == 1, "scale")
		assert(ctx.Size == Vector2.new(844, 390), "size")
		assert(ctx.Origin == Vector2.new(0, 0), "origin")
		assert(ctx.TopBarHeight == 52 and ctx.TopBarKeepOut == Vector2.new(120, 52), "top bar")
		assert(typeof(ctx.Changed) == "RBXScriptSignal", "Changed is a signal")
		local plain = M.Fixed({ Size = Vector2.new(1920, 1080) })
		assert(plain.Class == "Regular" and plain.Input == "KeyboardAndMouse", "defaults")
		assert(plain.Arrangement == "Standard" and plain.Band == "Normal", "defaults 2")
		assert(type(plain.TopBarHeight) == "number" and typeof(plain.TopBarKeepOut) == "Vector2", "top bar defaults")
		assert(M.Fixed({ Size = Vector2.new(844, 390), TouchEnabled = true }).Input == "Touch", "touch default input")
		assert(not pcall(M.Fixed, {}), "Size is required")
	end)

	case("Px, Hair and Touch rounding", function()
		local r720 = M.Fixed({ Size = Vector2.new(1280, 720) })
		local r1080 = M.Fixed({ Size = Vector2.new(1920, 1080) })
		local r1440 = M.Fixed({ Size = Vector2.new(2560, 1440) })
		local c844 = M.Fixed({ Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch" })
		local c568 = M.Fixed({ Size = Vector2.new(568, 320), TouchEnabled = true, Input = "Touch" })

		assert(r1080.Px(22) == 22 and r1080.Px(64) == 64, "identity at 1")
		assert(r720.Px(22) == 15, "22 at 16/24 is " .. r720.Px(22))
		assert(r720.Px(64) == 43, "64 at 16/24 is " .. r720.Px(64))
		assert(r1440.Px(22) == 29, "22 at 32/24 is " .. r1440.Px(22))
		assert(r720.Px(0) == 0 and r1440.Px(0) == 0, "0 stays 0")
		assert(r720.Px(0.5) == 1, "non-zero is at least 1")
		assert(c568.Px(48) == 41, "48 at 0.85 is " .. c568.Px(48))
		assert(r720.Px(22) % 1 == 0, "whole pixels")

		assert(r720.Hair(2) == 1, "hair 2 at 16/24")
		assert(r1080.Hair(2) == 2, "hair 2 at 1")
		assert(r1440.Hair(2) == 3, "hair 2 at 32/24")
		assert(r720.Hair(0.1) == 1 and r720.Hair(0) == 1, "hair is at least 1")

		assert(r1080.Touch(36) == 36, "mouse: no floor")
		assert(c844.Touch(36) == 48, "Compact touch: 48 floor")
		assert(c844.Touch(64) == 64, "larger than the floor")
		assert(c568.Touch(36) == 48, "floor is real px, not scaled")
		local tablet = M.Fixed({ Size = Vector2.new(1920, 1080), TouchEnabled = true, Input = "Touch" })
		assert(tablet.Class == "Regular" and tablet.Touch(36) == 48, "Regular with touch input")
		local smallWindow = M.Fixed({ Size = Vector2.new(844, 390) })
		assert(smallWindow.Input == "KeyboardAndMouse" and smallWindow.Touch(36) == 48, "Compact with a mouse")
	end)

	case("Of with and without Bind", function()
		local root = env.Detached("Frame")
		local child = env.Detached("Frame")
		local grandchild = env.Detached("TextLabel")
		local other = env.Detached("Frame")
		child.Parent = root
		grandchild.Parent = child

		local screen = M.Screen()
		assert(M.Screen() == screen, "Screen is one context")
		assert(type(screen.Scale) == "number" and typeof(screen.Size) == "Vector2", "screen fields")
		assert(typeof(screen.Origin) == "Vector2" and typeof(screen.TopBarKeepOut) == "Vector2", "screen fields 2")
		assert(typeof(screen.Changed) == "RBXScriptSignal", "screen Changed")
		assert(screen.Px(0) == 0 and screen.Hair(2) >= 1, "screen helpers")
		assert(M.Of(grandchild) == screen, "unbound resolves to Screen")

		local ctx = M.Fixed({ Size = Vector2.new(1280, 720) })
		M.Bind(root, ctx)
		assert(M.Of(root) == ctx, "root")
		assert(M.Of(grandchild) == ctx, "descendant")
		assert(M.Of(other) == screen, "an unrelated instance is not bound")

		local inner = M.Fixed({ Size = Vector2.new(844, 390), TouchEnabled = true })
		M.Bind(child, inner)
		assert(M.Of(grandchild) == inner, "nearest bound ancestor wins")
		assert(M.Of(root) == ctx, "outer binding unchanged")

		local replaced = M.Fixed({ Size = Vector2.new(2560, 1440) })
		M.Bind(root, replaced)
		assert(M.Of(root) == replaced, "Bind again replaces")

		assert(not pcall(M.Bind, nil, ctx), "Bind refuses a nil root")
		assert(not pcall(M.Bind, other, nil), "Bind refuses a nil context")
	end)

	return results
end
