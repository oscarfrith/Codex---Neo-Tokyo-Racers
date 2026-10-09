-- Pure tests for Kit.Controls (API.md 13). Runs in Edit through the harness; nothing is parented into the game tree and nothing yields.
return function(M, env)
	local results = {}
	local Metrics = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Metrics")
	local Tokens = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens")

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = (not ok) and tostring(detail) or nil })
	end

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	-- A stand-in for Core.ConnectionScope with the same four methods.
	local function newScope()
		local scope = { items = {}, dead = false }
		function scope:connect(signal, callback)
			assert(not self.dead, "scope destroyed")
			local connection = signal:Connect(callback)
			table.insert(self.items, connection)
			return connection
		end
		function scope:add(item)
			table.insert(self.items, item)
			return item
		end
		function scope:task(callback, ...)
			return self:add(task.spawn(callback, ...))
		end
		function scope:destroy()
			self.dead = true
			for index = #self.items, 1, -1 do
				local item = self.items[index]
				self.items[index] = nil
				if typeof(item) == "RBXScriptConnection" then
					item:Disconnect()
				end
			end
		end
		return scope
	end

	local PRESETS = {
		R1080 = { Size = Vector2.new(1920, 1080), TouchEnabled = false, Input = "KeyboardAndMouse" },
		R720 = { Size = Vector2.new(1280, 720), TouchEnabled = false, Input = "KeyboardAndMouse" },
		C844 = { Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch" },
	}

	local function stage(preset)
		local parent = env.Detached("Frame")
		local ctx = Metrics.Fixed(PRESETS[preset])
		Metrics.Bind(parent, ctx)
		return parent, ctx
	end

	local function underGlow(instance, root)
		local current = instance
		while current ~= nil and current ~= root do
			if current.Name == "Glow" then
				return true
			end
			current = current.Parent
		end
		return false
	end

	-- Descendants including the root, excluding a Glow and every UITextSizeConstraint (API.md 7).
	local function budget(root)
		local total = 1
		for _, descendant in ipairs(root:GetDescendants()) do
			if not descendant:IsA("UITextSizeConstraint") and not underGlow(descendant, root) then
				total = total + 1
			end
		end
		return total
	end

	local WATCHED = {
		"Name", "Size", "Position", "AnchorPoint", "Visible", "Active", "BackgroundColor3", "BackgroundTransparency",
		"Text", "TextColor3", "TextTransparency", "TextSize", "Image", "ImageColor3", "ImageTransparency", "Enabled",
	}

	local function snapshot(root)
		local list = root:GetDescendants()
		table.insert(list, root)
		local map = {}
		for _, instance in ipairs(list) do
			local parts = {}
			for _, property in ipairs(WATCHED) do
				local ok, value = pcall(function()
					return instance[property]
				end)
				parts[#parts + 1] = ok and tostring(value) or "-"
			end
			map[instance] = table.concat(parts, "|")
		end
		return map, #list
	end

	local function sameSnapshot(before, beforeCount, root)
		local after, afterCount = snapshot(root)
		if beforeCount ~= afterCount then
			return false, "instance count " .. beforeCount .. " -> " .. afterCount
		end
		for instance, text in pairs(before) do
			if after[instance] ~= text then
				return false, instance:GetFullName() .. ": " .. text .. " -> " .. tostring(after[instance])
			end
		end
		return true, nil
	end

	local function nothing() end

	-- The checks every constructor must pass (API.md 13).
	local function contract(label, preset, build, props, limit)
		case(label .. " " .. preset .. ": builds detached with every asset empty", function()
			local parent = stage(preset)
			local scope = newScope()
			local component = build(parent, props, scope)
			expect(typeof(component.Instance) == "Instance" and component.Instance:IsA("GuiObject"), "Instance is not a GuiObject")
			expect(component.Instance.Parent == parent, "root is not under the parent")
			expect(type(component.Set) == "function" and type(component.Destroy) == "function", "Set or Destroy missing")
			component.Destroy()
			scope:destroy()
		end)
		case(label .. " " .. preset .. ": within budget " .. tostring(limit), function()
			local parent = stage(preset)
			local scope = newScope()
			local component = build(parent, props, scope)
			local count = budget(component.Instance)
			component.Destroy()
			scope:destroy()
			expect(count <= limit, "budget " .. limit .. ", found " .. count)
		end)
		case(label .. " " .. preset .. ": Set with an unchanged patch changes nothing", function()
			local parent = stage(preset)
			local scope = newScope()
			local component = build(parent, props, scope)
			local before, count = snapshot(component.Instance)
			component.Set(props)
			local same, detail = sameSnapshot(before, count, component.Instance)
			component.Destroy()
			scope:destroy()
			expect(same, detail)
		end)
		case(label .. " " .. preset .. ": unknown key errors", function()
			local parent = stage(preset)
			local scope = newScope()
			local component = build(parent, props, scope)
			local okSet = pcall(component.Set, { NotAKey = 1 })
			local okNew = pcall(build, parent, { NotAKey = 1 }, scope)
			component.Destroy()
			for _, child in ipairs(parent:GetChildren()) do
				child:Destroy()
			end
			scope:destroy()
			expect(not okSet, "Set accepted an unknown key")
			expect(not okNew, "the constructor accepted an unknown key")
		end)
		case(label .. " " .. preset .. ": Destroy leaves the parent empty and is repeat-safe", function()
			local parent = stage(preset)
			local scope = newScope()
			local component = build(parent, props, scope)
			component.Destroy()
			component.Destroy()
			component.Set(props)
			local left = #parent:GetChildren()
			scope:destroy()
			expect(left == 0, left .. " children left under the parent")
		end)
	end

	---------------------------------------------------------------------------------------------
	-- State resolution (pure)
	---------------------------------------------------------------------------------------------

	case("resolveButton: Default is slate at panel opacity with white text", function()
		local look = M._resolveButton("Default", {})
		expect(look.Fill == "Slate" and look.FillOpacity == Tokens.Opacity.Panel, "fill")
		expect(look.Ink == "White" and look.Active == true and look.Opacity == 1, "ink, active or opacity")
		expect(look.Gradient == false and look.Glow == false, "gradient or glow")
	end)
	case("resolveButton: Main has the gradient and the glow", function()
		local look = M._resolveButton("Main", {})
		expect(look.Gradient == true and look.Glow == true and look.Ink == "White", "main look")
	end)
	case("resolveButton: Buy is yellow with ink text; Danger is red with white text", function()
		local buy = M._resolveButton("Buy", {})
		local danger = M._resolveButton("Danger", {})
		expect(buy.Fill == "Yellow" and buy.Ink == "Ink" and buy.FillOpacity == 1, "buy")
		expect(danger.Fill == "Danger" and danger.Ink == "White", "danger")
	end)
	case("resolveButton: hover and focus are white fill with ink text, on every variant", function()
		for _, variant in ipairs({ "Default", "Main", "Buy", "Danger", "Icon" }) do
			for _, flag in ipairs({ "Hover", "Focused" }) do
				local look = M._resolveButton(variant, { [flag] = true })
				expect(look.Fill == "White" and look.FillOpacity == 1 and look.Ink == "Ink", variant .. " " .. flag)
				expect(look.Gradient == false and look.Active == true, variant .. " " .. flag .. " gradient or active")
			end
		end
	end)
	case("resolveButton: pressed changes the fill, not the active state", function()
		local look = M._resolveButton("Default", { Pressed = true, Hover = true })
		expect(look.Fill == "TextSecondary" and look.Ink == "Ink" and look.Active == true, "pressed look")
	end)
	case("resolveButton: Disabled is inactive at 0.4, without glow, and ignores hover", function()
		local look = M._resolveButton("Main", { Disabled = true, Hover = true, Focused = true, Pressed = true })
		expect(look.Active == false and look.Opacity == Tokens.Opacity.Disabled, "active or opacity")
		expect(look.Glow == false and look.Gradient == true and look.Ink == "White", "glow, gradient or ink")
	end)
	case("resolveButton: Locked, and Active switched off from outside, are inactive at the locked opacity", function()
		local locked = M._resolveButton("Default", { Locked = true, Hover = true })
		local outside = M._resolveButton("Default", { Inactive = true })
		expect(locked.Active == false and locked.Opacity == Tokens.Opacity.Locked and locked.Fill == "Slate", "locked")
		expect(outside.Active == false and outside.Opacity == Tokens.Opacity.Locked, "inactive")
	end)
	case("resolveButton: Disabled wins over Locked", function()
		local look = M._resolveButton("Buy", { Disabled = true, Locked = true })
		expect(look.Opacity == Tokens.Opacity.Disabled, "opacity")
	end)
	case("resolveButton: an unknown variant errors", function()
		expect(not pcall(M._resolveButton, "Huge", {}), "accepted")
	end)
	case("caption: upper case; chevrons on Main and Buy only; none on Icon", function()
		expect(M._caption("Default", "Back") == "BACK", "default")
		expect(M._caption("Main", "Drive") == "DRIVE \u{00BB}", "main")
		expect(M._caption("Buy", "Buy $150,000") == "BUY $150,000 \u{00BB}", "buy")
		expect(M._caption("Icon", "Garage") == "", "icon")
		expect(M._caption("Default", nil) == "" and M._caption("Main", "") == "", "empty")
	end)
	case("rowPatch: a full patch, so a dropped value returns to its default", function()
		local patch = M._rowPatch({ Id = "Back", Text = "Back" }, "Menu")
		expect(patch.Variant == "Default" and patch.Disabled == false and patch.Locked == false, "defaults")
		expect(patch.Icon == "" and patch.MarkKey == "" and patch.OnActivated == false and patch.MinWidth == false, "cleared values")
		expect(patch.Name == "ButtonBack" and patch.Size == "Menu", "name or size")
		expect(not pcall(M._rowPatch, { Id = "X", Colour = "Pink" }, "Menu"), "unknown button key accepted")
		expect(not pcall(M._rowPatch, { Text = "No id" }, "Menu"), "missing Id accepted")
	end)
	case("resolveTab: active, inactive, hover, focus and locked", function()
		local active = M._resolveTab({ Selected = true })
		local idle = M._resolveTab({})
		local hover = M._resolveTab({ Hover = true })
		local focus = M._resolveTab({ Focused = true, Selected = true })
		local locked = M._resolveTab({ Locked = true, Hover = true, Focused = true })
		expect(active.Ink == "White" and active.Underline == true and active.Active == true, "active")
		expect(idle.Ink == "TextMuted" and idle.Underline == false and idle.Fill == false, "inactive")
		expect(hover.Ink == "White" and hover.Underline == false, "hover")
		expect(focus.Ink == "Ink" and focus.Fill == true and focus.Underline == true, "focus")
		expect(locked.Active == false and locked.Opacity == Tokens.Opacity.TabLocked and locked.Fill == false, "locked")
	end)
	case("stepTab: skips locked tabs and stops at the ends", function()
		local list = { { Id = "A" }, { Id = "B", Locked = true }, { Id = "C" } }
		expect(M._stepTab(list, "A", 1) == "C", "next over a locked tab")
		expect(M._stepTab(list, "C", -1) == "A", "previous over a locked tab")
		expect(M._stepTab(list, "C", 1) == nil, "past the end")
		expect(M._stepTab(list, "A", -1) == nil, "before the start")
		expect(M._stepTab(list, nil, 1) == "A" and M._stepTab(list, nil, -1) == "C", "from nothing selected")
	end)

	---------------------------------------------------------------------------------------------
	-- Constructors
	---------------------------------------------------------------------------------------------

	local buttons = {
		{ "Button Default", { Variant = "Default", Text = "Back", Icon = "back", OnActivated = nothing }, 4 },
		{ "Button Main", { Variant = "Main", Text = "Drive", Icon = "steering_wheel", OnActivated = nothing }, 5 },
		{ "Button Buy", { Variant = "Buy", Text = "Buy $150,000", OnActivated = nothing }, 4 },
		{ "Button Danger", { Variant = "Danger", Text = "Despawn", Icon = "close", OnActivated = nothing }, 4 },
		{ "Button Icon", { Variant = "Icon", Icon = "garage", OnActivated = nothing }, 4 },
		{ "Button Disabled", { Variant = "Main", Text = "Equip", Icon = "tick", Disabled = true, OnActivated = nothing }, 5 },
		{ "Button Large", { Variant = "Default", Size = "Large", Text = "Exit vehicle", Icon = "exit", OnActivated = nothing }, 4 },
	}
	for _, entry in ipairs(buttons) do
		for _, preset in ipairs({ "R1080", "C844" }) do
			contract(entry[1], preset, M.Button, entry[2], entry[3])
		end
	end

	local rowProps = {
		Align = "Right",
		Buttons = {
			{ Id = "Back", Variant = "Default", Text = "Back", Icon = "back", OnActivated = nothing },
			{ Id = "Drive", Variant = "Default", Text = "Drive", Icon = "steering_wheel", Disabled = true, OnActivated = nothing },
			{ Id = "Equip", Variant = "Main", Text = "Equip", Icon = "tick", OnActivated = nothing },
		},
	}
	local tabsProps = {
		Selected = "Parts",
		OnSelected = nothing,
		Tabs = {
			{ Id = "Parts", Text = "Parts", Icon = "customise" },
			{ Id = "Upgrades", Text = "Upgrades", Icon = "upgrade" },
			{ Id = "Paint", Text = "Paint", Icon = "paint", Locked = true },
		},
	}
	for _, preset in ipairs({ "R1080", "R720", "C844" }) do
		contract("ButtonRow", preset, M.ButtonRow, rowProps, 1 + 4 + 4 + 5)
		contract("Tabs", preset, M.Tabs, tabsProps, 3 * 3 + 1)
	end

	case("Button: the root is a selectable GuiButton with a child Fill; the hit box is ctx.Touch", function()
		for _, preset in ipairs({ "R1080", "C844" }) do
			local parent, ctx = stage(preset)
			local scope = newScope()
			local button = M.Button(parent, { Variant = "Default", Text = "Back", Icon = "back" }, scope)
			local root = button.Instance
			local compact = ctx.Class == "Compact"
			local drawn = compact and Tokens.Space.CompactButtonDrawn or Tokens.Space.ButtonHeight
			expect(root:IsA("GuiButton") and root.Selectable == true, preset .. ": not a selectable GuiButton")
			expect(root:FindFirstChild("Fill") ~= nil and root.Fill:IsA("Frame"), preset .. ": no Fill frame")
			expect(root.Size.Y.Offset == ctx.Touch(drawn), preset .. ": hit box height")
			expect(root.Fill.Size.Y.Offset == ctx.Px(drawn), preset .. ": drawn height")
			expect(root.Size.X.Scale == 0 and root.Size.Y.Scale == 0, preset .. ": scale in the size")
			button.Destroy()
			scope:destroy()
		end
	end)
	case("Button: Disabled and Locked set Active false and keep Visible; clearing restores Active", function()
		local parent = stage("R1080")
		local scope = newScope()
		local button = M.Button(parent, { Variant = "Buy", Text = "Buy $4.40M", Disabled = true }, scope)
		expect(button.Instance.Active == false and button.Instance.Visible == true, "disabled")
		button.Set({ Disabled = false })
		expect(button.Instance.Active == true, "enabled again")
		button.Set({ Locked = true })
		expect(button.Instance.Active == false and button.Instance.Visible == true, "locked")
		button.Destroy()
		scope:destroy()
	end)
	case("Button: a state change keeps the hit box and creates nothing", function()
		local parent = stage("R1080")
		local scope = newScope()
		local button = M.Button(parent, { Variant = "Main", Text = "Drive", Icon = "steering_wheel" }, scope)
		local size = button.Instance.Size
		local count = #button.Instance:GetDescendants()
		button.Set({ Disabled = true })
		button.Set({ Disabled = false, Locked = true })
		button.Set({ Locked = false })
		expect(button.Instance.Size == size, "hit box changed")
		expect(#button.Instance:GetDescendants() == count, "instances created or destroyed")
		button.Destroy()
		scope:destroy()
	end)
	case("Button: Main keeps the minimum width; Set writes a new text", function()
		local parent, ctx = stage("R1080")
		local scope = newScope()
		local button = M.Button(parent, { Variant = "Main", Text = "Go" }, scope)
		expect(button.Instance.Size.X.Offset >= ctx.Px(Tokens.Space.ButtonMainMinWidth), "narrower than the minimum")
		button.Set({ Text = "Equip" })
		expect(button.Instance.Fill.Label.Text == "EQUIP \u{00BB}", "label text " .. button.Instance.Fill.Label.Text)
		button.Destroy()
		scope:destroy()
	end)
	case("ButtonRow: order as given, Button(id), in-place update for the same ids", function()
		local parent = stage("R1080")
		local scope = newScope()
		local row = M.ButtonRow(parent, rowProps, scope)
		local back, drive, equip = row.Button("Back"), row.Button("Drive"), row.Button("Equip")
		expect(back ~= nil and drive ~= nil and equip ~= nil, "Button(id) returned nil")
		expect(row.Button("Nope") == nil, "unknown id returned a component")
		expect(back.Instance.Position.X.Offset < drive.Instance.Position.X.Offset, "back is not left of drive")
		expect(drive.Instance.Position.X.Offset < equip.Instance.Position.X.Offset, "main is not right-most")
		expect(drive.Instance.Active == false and equip.Instance.Active == true, "disabled state")
		local count = #row.Instance:GetDescendants()
		row.Set({
			Buttons = {
				{ Id = "Back", Variant = "Default", Text = "Back", Icon = "back", OnActivated = nothing },
				{ Id = "Drive", Variant = "Default", Text = "Drive", Icon = "steering_wheel", OnActivated = nothing },
				{ Id = "Equip", Variant = "Main", Text = "Equip", Icon = "tick", Disabled = true, OnActivated = nothing },
			},
		})
		expect(row.Button("Drive") == drive, "the button was rebuilt for the same id")
		expect(drive.Instance.Active == true and equip.Instance.Active == false, "states not updated in place")
		expect(#row.Instance:GetDescendants() == count, "instances created or destroyed on an in-place update")
		row.Destroy()
		scope:destroy()
	end)
	case("Tabs: Select moves the underline, creates nothing and does not call OnSelected", function()
		local parent = stage("R1080")
		local scope = newScope()
		local calls = 0
		local tabs = M.Tabs(parent, {
			Selected = "Parts",
			OnSelected = function()
				calls = calls + 1
			end,
			Tabs = tabsProps.Tabs,
		}, scope)
		local root = tabs.Instance
		local count = #root:GetDescendants()
		expect(root.TabParts.Underline.Visible == true and root.TabUpgrades.Underline.Visible == false, "first underline")
		tabs.Select("Upgrades")
		expect(root.TabParts.Underline.Visible == false and root.TabUpgrades.Underline.Visible == true, "underline did not move")
		expect(#root:GetDescendants() == count, "instances created or destroyed")
		expect(calls == 0, "OnSelected fired for a programmatic Select")
		expect(root.TabPaint.Active == false and root.TabPaint.Visible == true, "locked tab")
		expect(not pcall(tabs.Select, "Nope"), "unknown tab accepted")
		tabs.Destroy()
		scope:destroy()
	end)
	case("Tabs: every tab is a selectable GuiButton at least the touch size on Compact", function()
		local parent, ctx = stage("C844")
		local scope = newScope()
		local tabs = M.Tabs(parent, tabsProps, scope)
		for _, id in ipairs({ "TabParts", "TabUpgrades", "TabPaint" }) do
			local tab = tabs.Instance:FindFirstChild(id)
			expect(tab ~= nil and tab:IsA("GuiButton") and tab.Selectable == true, id .. " is not a selectable GuiButton")
			expect(tab.Size.Y.Offset >= ctx.Touch(1), id .. " is under the touch size")
		end
		tabs.Destroy()
		scope:destroy()
	end)

	return results
end
