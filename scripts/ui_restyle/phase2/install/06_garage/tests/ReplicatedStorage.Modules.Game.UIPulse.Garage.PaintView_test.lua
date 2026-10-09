-- Pure tests for Garage.PaintView: the Classic palette and ramps as data, the value texts, the fit rule, and the
-- controls mounted on a detached stage (a drag previews, a release or a preset commits, a message keeps a drag).
return function(M, env)
	local results = {}
	local UIP = "ReplicatedStorage.Modules.Game.UIPulse."

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	case("palette: two rows of thirteen, the Classic colours", function()
		local rows = M._palette()
		expect(#rows == 2 and #rows[1] == 13 and #rows[2] == 13, "2 x 13")
		expect(rows[1][1] == Color3.new(1, 1, 1) and rows[2][1] == Color3.fromRGB(180, 180, 184), "column 1")
		expect(rows[1][2] == Color3.fromRGB(66, 66, 72) and rows[2][2] == Color3.new(0, 0, 0), "column 2")
		expect(rows[1][3] == Color3.fromHSV(0, 0.48, 1) and rows[2][3] == Color3.fromHSV(0, 0.86, 0.42), "first hue")
		expect(rows[1][13] == Color3.fromHSV(0.93, 0.48, 1) and rows[2][13] == Color3.fromHSV(0.93, 0.86, 0.42), "last hue")
	end)

	case("ramps: hue wheel, white to the hue, black to the tint", function()
		local hue, saturation, brightness = M._ramps(0.5, 0.25)
		expect(#hue.Keypoints == 7 and hue.Keypoints[4].Value == Color3.fromHSV(0.5, 1, 1), "hue stops")
		expect(saturation.Keypoints[1].Value == Color3.new(1, 1, 1) and saturation.Keypoints[2].Value == Color3.fromHSV(0.5, 1, 1), "saturation")
		expect(brightness.Keypoints[1].Value == Color3.new(0, 0, 0) and brightness.Keypoints[2].Value == Color3.fromHSV(0.5, 0.25, 1), "brightness")
	end)

	case("value text and fit", function()
		expect(M._valueText(1, 236 / 360) == "236\u{00B0}" and M._valueText(2, 0.52) == "52%" and M._valueText(3, 0.26) == "26%", "texts")
		expect(M._fit(952, 64, 10, 13) == 13 and M._fit(951, 64, 10, 13) == 12 and M._fit(0, 64, 10, 13) == 0 and M._fit(5000, 64, 10, 13) == 13, "fit")
		expect(M._fit(100, 0, 10, 13) == 0, "no side, nothing fits")
	end)

	local Metrics = env.Load(UIP .. "Kit.Metrics")
	local Layers = env.Load(UIP .. "Kit.Layers")

	local function mount(compact)
		local ctx = compact
			and Metrics.Fixed({ Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch", TopBarHeight = 52, TopBarKeepOut = Vector2.new(120, 52) })
			or Metrics.Fixed({ Size = Vector2.new(1920, 1080), TopBarHeight = 58, TopBarKeepOut = Vector2.new(208, 58) })
		local parent = env.Detached("Frame")
		parent.Size = UDim2.fromOffset(ctx.Size.X, ctx.Size.Y)
		Metrics.Bind(parent, ctx)
		local scope = env.Scope()
		local stage = Layers.Stage(parent, ctx, "Scene")
		local calls = {}
		local view = M.New(stage.Slot("TopLeft"), stage.Slot("BottomRail"), {
			OnChannel = function(channel)
				table.insert(calls, "channel:" .. channel)
			end,
			OnColour = function(channel, colour, commit)
				table.insert(calls, { Channel = channel, Colour = colour, Commit = commit })
			end,
		}, scope, ctx)
		return view, parent, scope, calls
	end

	local function count(root, className, visibleOnly)
		local total = 0
		for _, instance in ipairs(root:GetDescendants()) do
			if instance.Name:sub(1, 6) == "Preset" and instance:IsA(className) and (not visibleOnly or instance.Visible) then
				total += 1
			end
		end
		return total
	end

	for _, compact in ipairs({ false, true }) do
		local label = compact and "C844" or "R1080"
		case(label .. ": hidden until shown; presets built once; Show twice writes nothing new", function()
			local view, parent, scope = mount(compact)
			expect(view.Controls.Visible == false and view.Palette.Visible == false, "hidden at build")
			local paint = { Target = "ALL", Channels = { "Primary", "Secondary", "Detail", "Neon" }, Selected = "Primary", Colours = { Primary = Color3.fromHSV(0.25, 0.5, 0.75) } }
			view.Show(paint, 1)
			expect(view.Controls.Visible and view.Palette.Visible, "shown")
			expect(count(parent, "GuiButton", false) == 26, "26 preset swatches")
			local shown = count(parent, "GuiButton", true)
			expect(compact and shown <= 13 or shown == 26, "Compact shows one row, Regular both: " .. shown)
			local before = #parent:GetDescendants()
			view.Show(paint, 1)
			view.Show({ Target = "ALL", Channels = { "Primary", "Secondary", "Detail", "Neon" }, Selected = "Secondary", Colours = {} }, 2)
			expect(#parent:GetDescendants() == before, "no instance created by a channel change")
			view.Hide()
			expect(view.Controls.Visible == false and view.Palette.Visible == false, "hidden")
			scope:destroy()
		end)
	end

	case("showing reports nothing to the caller; presets are buttons; Destroy is repeat-safe", function()
		local view, parent, scope, calls = mount(false)
		view.Show({ Target = "ALL", Channels = { "Primary", "Detail" }, Selected = "Detail", Colours = {} }, 1)
		local preset = nil
		for _, instance in ipairs(parent:GetDescendants()) do
			if instance.Name == "Preset2_2" then
				preset = instance
			end
		end
		expect(preset ~= nil and preset:IsA("GuiButton"), "the black preset is a button")
		expect(#calls == 0, "nothing reported by showing")
		view.Destroy()
		view.Destroy()
		scope:destroy()
	end)

	case("layout rules: presets stand clear of the controls; the Regular panel holds its sliders", function()
		expect(M._presetsClear(331, 334, 10) == true and M._presetsClear(344, 334, 10) == true, "844x390: the presets start under the sliders")
		expect(M._presetsClear(345, 334, 10) == false, "more than the touch padding over the presets")
		expect(M._presetsClear(320, 265, 9) == false, "568x320: the slider row is on the preset row")
		expect(M._panelHeight(320, 42, { 71, 71, 71 }, 10, 22) == 329, "three labelled sliders need more than the start height")
		expect(M._panelHeight(320, 42, { 40, 40, 40 }, 10, 22) == 320, "never under the start height")
	end)

	case("seed: an unset channel starts at Classic's pure white (GarageUI L523), a set one at its colour", function()
		expect(M._seed(nil) == Color3.new(1, 1, 1), "unset is Color3.new(1,1,1)")
		expect(M._seed("red") == Color3.new(1, 1, 1), "a value that is not a colour counts as unset")
		local h, s, v = Color3.toHSV(M._seed(nil))
		expect(s == 0 and v == 1, "saturation 0, value 1: not the kit White token, got " .. tostring(h) .. " " .. tostring(s) .. " " .. tostring(v))
		local set = Color3.fromRGB(12, 200, 90)
		expect(M._seed(set) == set, "a set channel is unchanged")
	end)

	return results
end
