-- Pure tests for RaceSession.RaceHudView: the view mounted on a detached Layers.Stage at R1080 and C844 over the canned
-- fixture model (Dev.Fixtures.RaceSession), for every fixture state. No real model, remote or player attribute.
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local Metrics = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Metrics")
	local Data = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Data")
	local Fixtures = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.RaceSession")

	local PRESETS = {
		R1080 = { Size = Vector2.new(1920, 1080), TouchEnabled = false, TopBarHeight = 58, TopBarKeepOut = Vector2.new(208, 58) },
		C844 = { Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch", TopBarHeight = 52, TopBarKeepOut = Vector2.new(120, 52) },
	}

	local function item(id)
		for _, entry in ipairs(Fixtures) do
			if entry.Id == id then
				return entry
			end
		end
		error("fixture item missing: " .. id)
	end

	-- Money goes through Kit.Data, whose Classic formatter is replaced here so nothing in the place is required.
	local function withMoney(body)
		local original = Data._foundation
		local function format(value)
			local text = tostring(math.floor((tonumber(value) or 0) + 0.5))
			local changed
			repeat
				text, changed = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
			until changed == 0
			return "$" .. text
		end
		Data._foundation = function()
			return {
				FormatFullMoney = format,
				FormatFreeRoamMoney = format,
				FormatCompactMoney = function(value)
					value = tonumber(value) or 0
					if value >= 1000000 then
						return string.format("$%.1fM", value / 1000000)
					end
					return format(value)
				end,
			}
		end
		local ok, detail = pcall(body)
		Data._foundation = original
		if not ok then
			error(detail, 0)
		end
	end

	local function mount(entry, props, preset)
		local stage = env.Detached("Frame")
		stage.Name = "Stage"
		stage.Size = UDim2.fromOffset(PRESETS[preset].Size.X, PRESETS[preset].Size.Y)
		local ctx = Metrics.Fixed(PRESETS[preset])
		Metrics.Bind(stage, ctx)
		local scope = env.Scope()
		local component = entry.Mount(stage, props, scope, ctx)
		return stage, component, scope
	end

	-- Everything a render could have changed, as one string.
	local function snapshot(root)
		local lines = {}
		for _, instance in ipairs(root:GetDescendants()) do
			local line = instance.ClassName .. ":" .. instance:GetFullName()
			if instance:IsA("GuiObject") then
				line ..= "|" .. tostring(instance.Visible) .. "|" .. tostring(instance.Size) .. "|" .. tostring(instance.Position)
					.. "|" .. tostring(instance.BackgroundTransparency) .. "|" .. tostring(instance.BackgroundColor3)
			end
			if instance:IsA("TextLabel") or instance:IsA("TextButton") then
				line ..= "|" .. instance.Text .. "|" .. tostring(instance.TextColor3)
			end
			if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
				line ..= "|" .. instance.Image .. "|" .. tostring(instance.ImageRectOffset) .. "|" .. tostring(instance.ImageColor3)
			end
			table.insert(lines, line)
		end
		return table.concat(lines, "\n")
	end

	-- Budget count (API1 7): descendants, without glows and text-size locks.
	local function budget(root)
		local count = 0
		for _, instance in ipairs(root:GetDescendants()) do
			if not instance:IsA("UITextSizeConstraint") and instance.Name ~= "Glow" then
				count += 1
			end
		end
		return count
	end

	local hud = item("RaceSession.RaceHud")
	-- The stage layer adds its own Root and slot frames; they are not part of the HUD budget of 140.
	local STAGE_ALLOWANCE = 40

	case("helpers: _digits and _signature", function()
		expect(M._digits(2, 99) == "2" and M._digits(nil, 99) == "-" and M._digits(140, 99) == "99", "digits")
		expect(M._digits("7", 99) == "7" and M._digits(3.9, 99) == "3", "numbers only")
		local a = M._signature({ { Key = "row1", Columns = { "1", "A" }, You = false } })
		local b = M._signature({ { Key = "row1", Columns = { "1", "A" }, You = true } })
		local c = M._signature({ { Key = "row1", Columns = { "1", "B" }, You = false } })
		expect(a ~= b and a ~= c and a == M._signature({ { Key = "row1", Columns = { "1", "A" }, You = false } }), "signature")
	end)

	for _, preset in ipairs({ "R1080", "C844" }) do
		for _, state in ipairs(hud.States) do
			case(preset .. " " .. state.Id .. ": mounts, within budget, a second render changes nothing, destroy is clean", function()
				local stage, component, scope = mount(hud, state.Props, preset)
				if state.Props.Confirm ~= true then
					local count = budget(stage)
					expect(count <= 140 + STAGE_ALLOWANCE, "HUD budget 140: " .. tostring(count))
				end
				local before = snapshot(stage)
				local instances = #stage:GetDescendants()
				component.Set({})
				component.Set(state.Props)
				expect(#stage:GetDescendants() == instances, "a second render creates and destroys nothing")
				expect(snapshot(stage) == before, "a second render changes no property")
				expect(pcall(component.Set, { NoSuchKey = true }) == false, "an unknown key errors")
				component.Destroy()
				scope:destroy()
			end)
		end

		case(preset .. ": every state through one mounted view; a state change creates and destroys nothing", function()
			local stage, component, scope = mount(hud, hud.States[1].Props, preset)
			local function apply(state)
				local patch = { Active = true, Mode = "Race", Tier = "E", Rows = {} }
				for key, value in pairs(state.Props) do
					patch[key] = value
				end
				component.Set(patch)
			end
			-- The pooled board grows to its largest state first (rows, and a third column in a time trial).
			for _, state in ipairs(hud.States) do
				if state.Props.Confirm ~= true and state.Props.Active ~= false then
					apply(state)
				end
			end
			local instances = #stage:GetDescendants()
			for _, state in ipairs(hud.States) do
				if state.Props.Confirm ~= true then
					apply(state)
					expect(#stage:GetDescendants() == instances, state.Id .. ": instance count changed")
				end
			end
			component.Destroy()
			scope:destroy()
		end)
	end

	case("reserved child names are present (CONTRACT.md: SessionControls and the Classic panel names)", function()
		local stage, component, scope = mount(hud, hud.States[1].Props, "R1080")
		for _, name in ipairs({ "LapProgress", "PrimaryMetric", "SessionBoard", "SessionControls" }) do
			expect(stage:FindFirstChild(name, true) ~= nil, name)
		end
		expect(stage:FindFirstChild("Reset", true) ~= nil and stage:FindFirstChild("Exit", true) ~= nil, "buttons")
		component.Destroy()
		scope:destroy()
	end)

	case("the route map is drawn on Regular Standard only (Classic line 149; c08)", function()
		local regular, regularComponent, regularScope = mount(hud, hud.States[1].Props, "R1080")
		expect(regular:FindFirstChild("RaceMap", true) ~= nil, "Regular has the map holder")
		expect(regular:FindFirstChild("RaceMap", true).Visible == false, "hidden while the event has no map image")
		expect(regular:FindFirstChild("PlayerMarker", true) ~= nil, "marker")
		regularComponent.Set({ MapImage = "rbxasset://textures/ui/GuiImagePlaceholder.png" })
		expect(regular:FindFirstChild("RaceMap", true).Visible == true, "shown with an image")
		regularComponent.Destroy()
		regularScope:destroy()
		local compact, compactComponent, compactScope = mount(hud, hud.States[1].Props, "C844")
		expect(compact:FindFirstChild("RaceMap", true) == nil, "Compact has none")
		compactComponent.Destroy()
		compactScope:destroy()
	end)

	case("the hidden state hides the layer root", function()
		local _, component, scope = mount(hud, { Active = false }, "R1080")
		local root = component.Instance
		expect(root.Visible == false, "hidden")
		component.Set({ Active = true, Mode = "Race", Place = 1, Suffix = "ST" })
		expect(root.Visible == true, "shown")
		component.Set({ Active = false })
		expect(root.Visible == false, "hidden again")
		component.Destroy()
		scope:destroy()
	end)

	return results
end
