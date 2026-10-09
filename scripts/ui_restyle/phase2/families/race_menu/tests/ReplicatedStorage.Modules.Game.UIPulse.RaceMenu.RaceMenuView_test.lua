-- Pure tests for RaceMenu.RaceMenuView: every fixture state mounted on a detached stage at R1080 and C844 over the
-- fake model. No error, within budget, a second Render changes nothing, a row click creates and destroys nothing,
-- the reserved names are present, and no ScreenGui exists. Needs kit v2 (Controls.Header, Collections.List,
-- Data.StatusCluster, Data.FactList) in the harness source set.
return function(M, env)
	local results = {}
	local UIP = "ReplicatedStorage.Modules.Game.UIPulse."
	local BUDGET = 150 -- programme contract 5.2, race menu

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local Metrics = env.Load(UIP .. "Kit.Metrics")
	local fixtures = env.Load(UIP .. "Dev.Fixtures.RaceMenu")
	local screen = fixtures[1]

	local PRESETS = {
		R1080 = function()
			return Metrics.Fixed({ Size = Vector2.new(1920, 1080), TopBarHeight = 58, TopBarKeepOut = Vector2.new(208, 58) })
		end,
		C844 = function()
			return Metrics.Fixed({
				Size = Vector2.new(844, 390),
				TouchEnabled = true,
				Input = "Touch",
				TopBarHeight = 52,
				TopBarKeepOut = Vector2.new(120, 52),
			})
		end,
	}

	local function stateProps(id)
		for _, state in ipairs(screen.States) do
			if state.Id == id then
				return table.clone(state.Props)
			end
		end
		error("no fixture state " .. tostring(id))
	end

	local function mount(preset, stateId)
		local ctx = PRESETS[preset]()
		local parent = env.Detached("Frame")
		parent.Size = UDim2.fromOffset(ctx.Size.X, ctx.Size.Y)
		Metrics.Bind(parent, ctx)
		local scope = env.Scope()
		local component = screen.Mount(parent, stateProps(stateId), scope, ctx)
		return component, parent, scope, ctx
	end

	-- What a render may write, per descendant.
	local WATCHED = { "Visible", "Position", "Size", "AnchorPoint", "Text", "Image", "BackgroundTransparency", "ImageTransparency", "TextTransparency", "Active", "Name" }
	local function snapshot(root)
		local list = {}
		for _, instance in ipairs(root:GetDescendants()) do
			local record = { Instance = instance }
			for _, property in ipairs(WATCHED) do
				local ok, value = pcall(function()
					return instance[property]
				end)
				if ok then
					record[property] = value
				end
			end
			table.insert(list, record)
		end
		return list
	end

	local function sameInstances(before, after)
		if #before ~= #after then
			return false, "descendants " .. #before .. " -> " .. #after
		end
		local seen = {}
		for _, record in ipairs(before) do
			seen[record.Instance] = true
		end
		for _, record in ipairs(after) do
			if not seen[record.Instance] then
				return false, "new instance " .. record.Instance:GetFullName()
			end
		end
		return true, nil
	end

	local function sameProperties(before, after)
		local byInstance = {}
		for _, record in ipairs(before) do
			byInstance[record.Instance] = record
		end
		for _, record in ipairs(after) do
			local old = byInstance[record.Instance]
			if old then
				for _, property in ipairs(WATCHED) do
					if old[property] ~= record[property] then
						return false, record.Instance:GetFullName() .. "." .. property
					end
				end
			end
		end
		return true, nil
	end

	local function named(root, name)
		local found = {}
		for _, instance in ipairs(root:GetDescendants()) do
			if instance.Name == name then
				table.insert(found, instance)
			end
		end
		return found
	end

	case("module shape", function()
		expect(type(M) == "table" and type(M.Mount) == "function", "View.Mount exists")
		expect(type(screen) == "table" and screen.Id == "RaceMenu.Screen", "the fixture item is registered")
	end)

	for _, preset in ipairs({ "R1080", "C844" }) do
		for _, state in ipairs(screen.States) do
			case(preset .. " " .. state.Id .. ": mounts within budget, no ScreenGui, destroys clean", function()
				local component, parent, scope = mount(preset, state.Id)
				-- What the view made: everything under the stage root except the layer's own empty slot anchors.
				local count = 0
				for _, instance in ipairs(component.Layer.Root:GetDescendants()) do
					local isSlot = instance.Parent == component.Layer.Root and string.sub(instance.Name, 1, 4) == "Slot"
					if not isSlot then
						count += 1
					end
				end
				expect(count <= BUDGET, count .. " instances; the budget is " .. BUDGET)
				for _, instance in ipairs(parent:GetDescendants()) do
					expect(not instance:IsA("ScreenGui"), "a view never makes a ScreenGui")
					expect(not instance:IsA("UIStroke") and not instance:IsA("UICorner") and not instance:IsA("CanvasGroup"), "forbidden class " .. instance.ClassName)
				end
				expect(component.Layer.Root.Visible == (state.Props.Open ~= false), "root Visible follows the model")
				component.Destroy()
				component.Destroy()
				scope:destroy()
				expect(#parent:GetChildren() == 0, "the parent is empty after Destroy")
			end)
		end

		case(preset .. ": a second Render with unchanged state changes nothing", function()
			local component, parent, scope = mount(preset, "Default")
			component.View.Render("Test")
			local before = snapshot(parent)
			component.View.Render("Test")
			component.View.Render(nil)
			local after = snapshot(parent)
			local okInstances, whyInstances = sameInstances(before, after)
			expect(okInstances, tostring(whyInstances))
			local okProperties, whyProperties = sameProperties(before, after)
			expect(okProperties, "changed: " .. tostring(whyProperties))
			scope:destroy()
		end)

		case(preset .. ": a row click creates and destroys nothing", function()
			local component, parent, scope = mount(preset, "FiveEvents")
			local model = component.Model
			-- Grow every pool once (all five rows, the detail), then measure.
			model.Select("AkaneRing")
			model.Select("WaterfrontSprint")
			model.SetPage("Detail")
			model.SetPage("List")
			local before = snapshot(parent)
			model.Select("HarbourRun")
			model.Select("ShowroomLoop")
			model.Select("AkaneRing")
			local after = snapshot(parent)
			local ok, why = sameInstances(before, after)
			expect(ok, tostring(why))
			expect(model.SelectedKey() == "AkaneRing", "the selection moved")
			scope:destroy()
		end)

		case(preset .. ": filter tabs and the empty state create nothing once grown", function()
			local component, parent, scope = mount(preset, "FiveEvents")
			local model = component.Model
			model.SetFilter("Races")
			model.SetFilter("TimeTrials")
			model.SetFilter("All")
			local before = snapshot(parent)
			model.SetFilter("TimeTrials")
			model.SetFilter("All")
			local after = snapshot(parent)
			local ok, why = sameInstances(before, after)
			expect(ok, tostring(why))
			scope:destroy()
		end)

		case(preset .. ": reserved names and marks", function()
			local component, parent, scope = mount(preset, "Default")
			local lists = named(parent, "CardContent")
			expect(#lists == 1, "one CardContent, got " .. #lists)
			expect(lists[1]:GetAttribute("PulseMark") == "CardContent", "CardContent is marked through Input.Mark")
			local teleports = named(parent, "TeleportToStart")
			expect(#teleports == 1 and teleports[1]:IsA("GuiButton"), "one TeleportToStart GuiButton")
			expect(teleports[1]:GetAttribute("PulseMark") == "TeleportToStart", "TeleportToStart is marked through Input.Mark")
			for _, instance in ipairs(parent:GetDescendants()) do
				if instance:IsA("GuiButton") then
					expect(instance.Name ~= "Race" and instance.Name ~= "Car" and instance.Name ~= "Garage", "locked button name " .. instance.Name)
				end
			end
			component.Destroy()
			scope:destroy()
		end)

		case(preset .. ": the empty state disables both actions", function()
			local component, parent, scope = mount(preset, "Empty")
			local teleport = named(parent, "TeleportToStart")[1]
			expect(teleport ~= nil and teleport.Active == false, "TELEPORT is not active")
			local shownEmpty = false
			for _, instance in ipairs(parent:GetDescendants()) do
				if instance:IsA("TextLabel") and instance.Text == "NO EVENTS AVAILABLE" then
					shownEmpty = true
				end
			end
			expect(shownEmpty, "NO EVENTS AVAILABLE is drawn")
			component.Destroy()
			scope:destroy()
		end)
	end

	case("C844: the list page and the detail page swap by Visible only", function()
		local component, parent, scope = mount("C844", "Default")
		local model = component.Model
		model.SetPage("Detail")
		model.SetPage("List")
		local before = snapshot(parent)
		model.SetPage("Detail")
		local middle = snapshot(parent)
		model.SetPage("List")
		local after = snapshot(parent)
		local ok, why = sameInstances(before, middle)
		expect(ok, tostring(why))
		ok, why = sameInstances(before, after)
		expect(ok, tostring(why))
		local okProperties, whyProperties = sameProperties(before, after)
		expect(okProperties, "list page not restored: " .. tostring(whyProperties))
		scope:destroy()
	end)

	return results
end
