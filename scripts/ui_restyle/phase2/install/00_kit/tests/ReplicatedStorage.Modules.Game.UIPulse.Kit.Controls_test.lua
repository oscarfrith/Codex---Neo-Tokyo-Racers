-- Pure tests for Kit.Controls (API.md 13, API2 2.8 and 3.6). Runs in Edit through the harness; nothing is parented into the game tree and nothing yields.
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
		if limit ~= nil then
			case(label .. " " .. preset .. ": within budget " .. tostring(limit), function()
				local parent = stage(preset)
				local scope = newScope()
				local component = build(parent, props, scope)
				local count = budget(component.Instance)
				component.Destroy()
				scope:destroy()
				expect(count <= limit, "budget " .. limit .. ", found " .. count)
			end)
		end
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

	case("resolveButton: Default is slate at the button plate opacity with white text", function()
		local look = M._resolveButton("Default", {})
		expect(look.Fill == "Slate" and look.FillOpacity == Tokens.Opacity.ButtonPlate, "fill")
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
		-- Budgets of API2 2.8: 6, and 7 for Main (were 4 and 5).
		{ "Button Default", { Variant = "Default", Text = "Back", Icon = "back", OnActivated = nothing }, 6 },
		{ "Button Main", { Variant = "Main", Text = "Drive", Icon = "steering_wheel", OnActivated = nothing }, 7 },
		{ "Button Buy", { Variant = "Buy", Text = "Buy $150,000", OnActivated = nothing }, 6 },
		{ "Button Danger", { Variant = "Danger", Text = "Despawn", Icon = "close", OnActivated = nothing }, 6 },
		{ "Button Icon", { Variant = "Icon", Icon = "garage", OnActivated = nothing }, 6 },
		{ "Button Disabled", { Variant = "Main", Text = "Equip", Icon = "tick", Disabled = true, OnActivated = nothing }, 7 },
		{ "Button Large", { Variant = "Default", Size = "Large", Text = "Exit vehicle", Icon = "exit", OnActivated = nothing }, 6 },
		{ "Button Hud", { Variant = "Default", Size = "Hud", Text = "Controls", Icon = "gamepad", OnActivated = nothing }, 6 },
		{ "Button IconOnly selected", { Variant = "Default", Size = "Hud", Icon = "garage", IconOnly = true, Selected = true, OnActivated = nothing }, 6 },
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
		contract("ButtonRow", preset, M.ButtonRow, rowProps, 1 + 6 + 6 + 7)
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
			expect(tab.Size.X.Offset >= ctx.Touch(1), id .. " is narrower than the touch size")
		end
		tabs.Destroy()
		scope:destroy()
	end)
	case("tabWrap: a tab that would pass the limit starts the next line; the first of a line never wraps", function()
		local x, y = M._tabWrap(100, 0, 48, 56, 140)
		expect(x == 0 and y == 56, "did not wrap")
		x, y = M._tabWrap(92, 0, 48, 56, 140)
		expect(x == 92 and y == 0, "wrapped a tab that fits")
		x, y = M._tabWrap(0, 56, 300, 56, 140)
		expect(x == 0 and y == 56, "wrapped the first tab of a line")
		x, y = M._tabWrap(5000, 0, 48, 56, math.huge)
		expect(x == 5000 and y == 0, "wrapped with no limit")
	end)
	case("Tabs: tier buttons are touch size wide with the touch gap on Compact, and wrap inside the safe area", function()
		local parent, ctx = stage("C844")
		local scope = newScope()
		local items = {}
		for index, tier in ipairs({ "E", "D", "C", "B", "A", "S" }) do
			items[index] = { Id = tier, Text = tier, Tier = tier }
		end
		local tabs = M.Tabs(parent, { Selected = "E", Tabs = items }, scope)
		local root = tabs.Instance
		local floor = ctx.Touch(1)
		expect(floor >= Tokens.Space.TouchMin, "the touch floor is under TouchMin")
		expect(root.TabE.Size.X.Offset >= floor and root.TabS.Size.X.Offset >= floor, "a tier tab is narrower than the touch size")
		expect(root.TabD.Position.X.Offset - (root.TabE.Position.X.Offset + root.TabE.Size.X.Offset) >= Tokens.Space.TouchGap, "touch gap")
		expect(root.TabS.Position.Y.Offset == 0 and root.Size.Y.Offset == root.TabE.Size.Y.Offset, "six tier tabs wrapped on a phone")
		local many = {}
		for index = 1, 20 do
			many[index] = { Id = "T" .. index, Text = "E", Tier = "E" }
		end
		tabs.Set({ Tabs = many, Selected = "T1" })
		for index = 1, 20 do
			local tab = root["TabT" .. index]
			expect(tab.Position.X.Offset + tab.Size.X.Offset <= ctx.Size.X, "a tab passes the safe area")
		end
		expect(root.TabT20.Position.Y.Offset > 0 and root.Size.Y.Offset > root.TabT1.Size.Y.Offset, "twenty tabs did not wrap")
		expect(root.Size.X.Offset <= ctx.Size.X, "the row is wider than the safe area")
		tabs.Destroy()
		scope:destroy()
	end)
	case("Tabs: Regular with a mouse keeps natural widths on one line", function()
		local parent = stage("R1080")
		local scope = newScope()
		local many = {}
		for index = 1, 60 do
			many[index] = { Id = "T" .. index, Text = "E", Tier = "E" }
		end
		local tabs = M.Tabs(parent, { Selected = "T1", Tabs = many }, scope)
		local root = tabs.Instance
		expect(root.TabT60.Position.Y.Offset == 0 and root.Size.Y.Offset == root.TabT1.Size.Y.Offset, "Regular wrapped")
		local last = root.TabT60
		expect(root.Size.X.Offset == last.Position.X.Offset + last.Size.X.Offset, "Regular row width")
		tabs.Destroy()
		scope:destroy()
	end)

	---------------------------------------------------------------------------------------------
	-- API2 2.8: plates, hairlines, sizes, rows, tier tabs
	---------------------------------------------------------------------------------------------

	local function about(a, b)
		return math.abs(a - b) < 1e-4
	end

	case("resolveButton: hairlines on the slate plate only; a filled variant keeps its role base line when white", function()
		local default = M._resolveButton("Default", {})
		expect(default.Hair == true and default.BaseLine == false, "default")
		expect(M._resolveButton("Default", { Hover = true }).Hair == false, "hover keeps the hairlines")
		expect(M._resolveButton("Default", { Focused = true }).BaseLine == false, "a slate button has no role line")
		expect(M._resolveButton("Default", { Disabled = true }).Hair == false, "disabled keeps the hairlines")
		expect(M._resolveButton("Default", { Locked = true }).Hair == true, "locked lost the hairlines")
		for variant, role in pairs({ Main = "Pink", Buy = "Yellow", Danger = "Danger" }) do
			local idle = M._resolveButton(variant, {})
			local focus = M._resolveButton(variant, { Focused = true })
			local pressed = M._resolveButton(variant, { Pressed = true })
			expect(idle.Hair == false and idle.BaseLine == false, variant .. " idle")
			expect(focus.Fill == "White" and focus.BaseLine == role, variant .. " focus")
			expect(pressed.BaseLine == role, variant .. " pressed")
			expect(M._resolveButton(variant, { Disabled = true, Focused = true }).BaseLine == false, variant .. " disabled")
		end
	end)
	case("resolveButton: Selected holds the white fill; Disabled and Locked win over it", function()
		local selected = M._resolveButton("Icon", { Selected = true })
		expect(selected.Fill == "White" and selected.Ink == "Ink" and selected.Active == true, "selected")
		expect(M._resolveButton("Icon", { Selected = true, Disabled = true }).Fill == "Slate", "disabled")
		expect(M._resolveButton("Default", { Selected = true, Locked = true }).Fill == "Slate", "locked")
	end)
	case("buttonHeight: Menu 64, Hud, Large and Icon on Regular; the Compact drawn heights", function()
		local S = Tokens.Space
		expect(M._buttonHeight(false, "Default", "Menu") == S.ButtonHeight, "menu")
		expect(M._buttonHeight(false, "Main", "Hud") == S.HudButtonHeight, "hud")
		expect(M._buttonHeight(false, "Default", "Large") == S.ButtonHeightLarge, "large")
		expect(M._buttonHeight(false, "Icon", "Menu") == S.IconButton, "icon")
		expect(M._buttonHeight(true, "Default", "Menu") == S.CompactButtonDrawn, "compact menu")
		expect(M._buttonHeight(true, "Default", "Hud") == S.CompactHudButton, "compact hud")
		expect(M._buttonHeight(true, "Default", "Large") == S.TouchMin, "compact large")
	end)
	case("Button: HairTop and HairBottom on the slate plate; hidden when disabled and on Main", function()
		local parent, ctx = stage("R1080")
		local scope = newScope()
		local button = M.Button(parent, { Variant = "Default", Text = "Back", Icon = "back" }, scope)
		local fill = button.Instance.Fill
		local top, bottom = fill:FindFirstChild("HairTop"), fill:FindFirstChild("HairBottom")
		expect(top ~= nil and bottom ~= nil, "HairTop or HairBottom missing")
		expect(top.Visible == true and bottom.Visible == true, "hairlines hidden on the default plate")
		expect(fill.BackgroundColor3 == Tokens.Colour.Slate, "plate colour")
		expect(about(fill.BackgroundTransparency, 1 - Tokens.Opacity.ButtonPlate), "plate opacity")
		expect(top.BackgroundColor3 == Tokens.Colour.White and about(top.BackgroundTransparency, 1 - Tokens.Opacity.HairButtonTop), "top hairline")
		expect(about(bottom.BackgroundTransparency, 1 - Tokens.Opacity.HairButtonBottom), "bottom hairline")
		expect(top.Size.Y.Offset == ctx.Hair(Tokens.Space.Hairline) and bottom.Size.Y.Offset == ctx.Hair(Tokens.Space.Hairline), "thickness")
		expect(top.Size.X.Scale == 1 and bottom.AnchorPoint == Vector2.new(0, 1), "hairline boxes")
		button.Set({ Disabled = true })
		expect(top.Visible == false and bottom.Visible == false, "hairlines shown when disabled")
		button.Set({ Disabled = false, Variant = "Main" })
		expect(top.Visible == false and bottom.Visible == false, "hairlines shown on Main")
		expect(fill:FindFirstChild("HairTop") == top, "the hairline was rebuilt")
		button.Destroy()
		scope:destroy()
	end)
	case("Button Main: the glow is a sibling under Fill, on the plate's box, off when disabled", function()
		for _, preset in ipairs({ "R1080", "C844" }) do
			local parent = stage(preset)
			local scope = newScope()
			local button = M.Button(parent, { Variant = "Main", Text = "Drive", Icon = "steering_wheel" }, scope)
			local root = button.Instance
			local glow = root:FindFirstChild("Glow")
			expect(glow ~= nil and glow.Parent == root, preset .. ": Glow is not a child of the root")
			expect(glow.ZIndex < root.Fill.ZIndex, preset .. ": Glow is not under Fill")
			expect(glow.Position == root.Fill.Position and glow.Size == root.Fill.Size, preset .. ": Glow is not on the plate's box")
			expect(glow.Visible == true and glow.Active == false, preset .. ": Glow hidden or active")
			expect(root.Fill:FindFirstChild("Glow") == nil, preset .. ": a glow inside the plate would draw over it")
			button.Set({ Disabled = true })
			expect(glow.Visible == false, preset .. ": Glow shown when disabled")
			button.Destroy()
			scope:destroy()
		end
	end)
	case("Button: Hud height, IconOnly square, Selected is the white fill", function()
		local parent, ctx = stage("R1080")
		local scope = newScope()
		local hud = M.Button(parent, { Variant = "Default", Size = "Hud", Text = "Exit vehicle", Icon = "exit" }, scope)
		expect(hud.Instance.Fill.Size.Y.Offset == ctx.Px(Tokens.Space.HudButtonHeight), "hud height")
		local tile = M.Button(parent, { Variant = "Default", Size = "Hud", Text = "Garage", Icon = "garage", IconOnly = true }, scope)
		local fill = tile.Instance.Fill
		expect(fill.Size.X.Offset == fill.Size.Y.Offset, "IconOnly is not square")
		expect(fill.Label.Visible == false, "IconOnly shows text")
		expect(fill.BackgroundColor3 == Tokens.Colour.Slate, "idle fill")
		tile.Set({ Selected = true })
		expect(fill.BackgroundColor3 == Tokens.Colour.White and fill.BackgroundTransparency == 0, "selected fill")
		expect(tile.Instance.Active == true, "selected is inactive")
		expect(not pcall(M.Button, parent, { Text = "X", Size = "Tiny" }, scope), "unknown Size accepted")
		for _, child in ipairs(parent:GetChildren()) do
			child:Destroy()
		end
		scope:destroy()
	end)
	case("rowAnchor: a slot gives its own anchor; elsewhere Align decides; unknown Align errors", function()
		local x, y = M._rowAnchor(true, Vector2.new(0.5, 1), "Right")
		expect(x == 0.5 and y == 1, "slot anchor")
		x, y = M._rowAnchor(true, Vector2.new(1, 0), "Centre")
		expect(x == 1 and y == 0, "slot anchor, top right")
		x, y = M._rowAnchor(false, Vector2.new(0, 0), "Right")
		expect(x == 1 and y == 1, "Align Right")
		x, y = M._rowAnchor(false, Vector2.new(0, 0), "Centre")
		expect(x == 0.5 and y == 1, "Align Centre")
		expect(not pcall(M._rowAnchor, false, Vector2.new(0, 0), "Left"), "unknown Align accepted")
	end)
	case("ButtonRow: 64 high on Regular with Hud buttons on its bottom edge", function()
		local parent, ctx = stage("R1080")
		local scope = newScope()
		local row = M.ButtonRow(parent, {
			Align = "Centre",
			Size = "Hud",
			Buttons = {
				{ Id = "Controls", Text = "Controls", Icon = "gamepad" },
				{ Id = "Exit", Text = "Exit vehicle", Icon = "exit" },
			},
		}, scope)
		local rowHeight = ctx.Px(Tokens.Space.ButtonHeight)
		local exit = row.Button("Exit").Instance
		expect(row.Instance.Size.Y.Offset == rowHeight, "row height " .. row.Instance.Size.Y.Offset)
		expect(exit.Size.Y.Offset == ctx.Px(Tokens.Space.HudButtonHeight), "hud button height")
		expect(exit.Position.Y.Offset + exit.Size.Y.Offset == rowHeight, "the button is not on the bottom edge")
		expect(exit.Position.X.Offset - (row.Button("Controls").Instance.Size.X.Offset) == ctx.Px(Tokens.Space.Gap), "gap")
		row.Destroy()
		scope:destroy()
	end)
	case("ButtonRow: Place Slot copies the slot anchor on whole pixels; Place None leaves the root alone", function()
		local ctx = Metrics.Fixed(PRESETS.R1080)
		local scope = newScope()
		local buttons = { { Id = "Again", Text = "Race again", Icon = "loop" }, { Id = "Continue", Variant = "Main", Text = "Continue" } }

		local centre = env.Detached("Frame")
		centre.Name = "SlotBottomCentre"
		centre.AnchorPoint = Vector2.new(0.5, 1)
		Metrics.Bind(centre, ctx)
		local row = M.ButtonRow(centre, { Buttons = buttons }, scope)
		local root = row.Instance
		expect(root.AnchorPoint == Vector2.new(0, 1), "centre: anchor " .. tostring(root.AnchorPoint))
		expect(root.Position.X.Scale == 0.5 and root.Position.X.Offset == -math.floor(root.Size.X.Offset / 2), "centre: x")
		expect(root.Position.Y.Scale == 1 and root.Position.Y.Offset == 0, "centre: y")
		row.Destroy()

		local corner = env.Detached("Frame")
		corner.Name = "SlotActionBar"
		corner.AnchorPoint = Vector2.new(1, 0)
		Metrics.Bind(corner, ctx)
		row = M.ButtonRow(corner, { Buttons = buttons, Align = "Centre" }, scope)
		expect(row.Instance.AnchorPoint == Vector2.new(1, 0), "top right: anchor")
		expect(row.Instance.Position == UDim2.new(1, 0, 0, 0), "top right: position")
		row.Destroy()

		local plain = env.Detached("Frame")
		Metrics.Bind(plain, ctx)
		row = M.ButtonRow(plain, { Buttons = buttons, Place = "None" }, scope)
		expect(row.Instance.AnchorPoint == Vector2.new(0, 0) and row.Instance.Position == UDim2.new(0, 0, 0, 0), "Place None moved the root")
		expect(row.Instance.Size.X.Offset > 0, "Place None did not size the row")
		expect(not pcall(row.Set, { Place = "Floating" }), "unknown Place accepted")
		row.Destroy()
		scope:destroy()
	end)
	case("resolveTab: a tier button shows its base line always, its colour when idle, its fill when selected", function()
		local idle = M._resolveTab({ Tier = true })
		local selected = M._resolveTab({ Tier = true, Selected = true })
		local focus = M._resolveTab({ Tier = true, Selected = true, Focused = true })
		local locked = M._resolveTab({ Tier = true, Locked = true })
		expect(idle.Underline == true and idle.TierInk == true and idle.TierFill == false, "idle")
		expect(selected.TierFill == true and selected.Ink == "Ink" and selected.TierInk == false, "selected")
		expect(focus.Fill == true and focus.TierFill == false and focus.Ink == "Ink", "focus")
		expect(locked.Active == false and locked.Opacity == Tokens.Opacity.TabLocked and locked.TierInk == true, "locked")
		local plain = M._resolveTab({ Selected = true })
		expect(plain.TierInk == false and plain.TierFill == false, "a plain tab took a tier look")
	end)
	case("tabCaption: upper case name, then the count", function()
		expect(M._tabCaption({ Id = "Parts", Text = "Parts", Count = "7/7" }) == "PARTS 7/7", "name and count")
		expect(M._tabCaption({ Id = "Parts", Text = "Parts" }) == "PARTS", "name only")
		expect(M._tabCaption({ Id = "Count", Count = "3" }) == "3", "count only")
	end)
	case("Tabs: tier buttons use the tier colours; a locked one is inactive", function()
		local parent = stage("R1080")
		local scope = newScope()
		local tabs = M.Tabs(parent, {
			Selected = "C",
			Tabs = {
				{ Id = "E", Text = "E", Tier = "E" },
				{ Id = "C", Text = "C", Tier = "C", Count = "3" },
				{ Id = "S", Text = "S", Tier = "S", Locked = true },
			},
		}, scope)
		local root = tabs.Instance
		expect(root.TabC.BackgroundColor3 == Tokens.Tier.C and root.TabC.BackgroundTransparency == 0, "selected tier fill")
		expect(root.TabC.TextColor3 == Tokens.Colour.Ink and root.TabC.Text == "C 3", "selected tier letter")
		expect(root.TabE.TextColor3 == Tokens.Tier.E and root.TabE.BackgroundTransparency == 1, "idle tier letter")
		expect(root.TabE.Underline.Visible == true and root.TabE.Underline.BackgroundColor3 == Tokens.Tier.E, "tier base line")
		expect(root.TabS.Active == false and about(root.TabS.TextTransparency, 1 - Tokens.Opacity.TabLocked), "locked tier")
		local count = #root:GetDescendants()
		tabs.Select("E")
		expect(root.TabE.BackgroundColor3 == Tokens.Tier.E and root.TabE.BackgroundTransparency == 0, "the fill did not move")
		expect(root.TabC.BackgroundTransparency == 1 and root.TabC.TextColor3 == Tokens.Tier.C, "the old one kept its fill")
		expect(#root:GetDescendants() == count, "instances created or destroyed")
		expect(not pcall(M.Tabs, parent, { Tabs = { { Id = "Z", Text = "Z", Tier = "Z" } } }, scope), "unknown tier accepted")
		for _, child in ipairs(parent:GetChildren()) do
			child:Destroy()
		end
		scope:destroy()
	end)
	case("Tabs: Segment uses SwitchGap and draws no icons; Triggers and unknown Style", function()
		local parent, ctx = stage("R1080")
		local scope = newScope()
		local items = { { Id = "Shop", Text = "Shop", Icon = "dealership" }, { Id = "Owned", Text = "Owned", Icon = "garage" } }
		local segment = M.Tabs(parent, { Style = "Segment", Triggers = true, Selected = "Owned", Tabs = items }, scope)
		local root = segment.Instance
		local shop, owned = root.TabShop, root.TabOwned
		expect(shop:FindFirstChild("Icon") == nil and owned:FindFirstChild("Icon") == nil, "a Segment drew an icon")
		expect(owned.Position.X.Offset - (shop.Position.X.Offset + shop.Size.X.Offset) == ctx.Px(Tokens.Space.SwitchGap), "segment gap")
		expect(owned.Underline.Visible == true and shop.Underline.Visible == false, "underline")
		local plain = M.Tabs(parent, { Selected = "Owned", Tabs = items }, scope)
		expect(plain.Instance.TabShop:FindFirstChild("Icon") ~= nil, "a Tabs row lost its icon")
		expect(plain.Instance.Size.Y.Offset >= root.Size.Y.Offset, "a Segment is taller than a Tabs row")
		expect(not pcall(M.Tabs, parent, { Style = "Pills", Tabs = items }, scope), "unknown Style accepted")
		for _, child in ipairs(parent:GetChildren()) do
			child:Destroy()
		end
		scope:destroy()
	end)

	---------------------------------------------------------------------------------------------
	-- API2 3.6: Header, IconButton, Switch, Stepper, Slider, Swatch, Dropdown
	---------------------------------------------------------------------------------------------

	local headerProps = {
		Title = "Customise",
		Sub = "Choose time trial vehicle",
		Count = "6",
		Shadow = true,
		Tabs = tabsProps,
	}
	local dropdownProps = {
		Label = "Sort",
		Selected = "Rating",
		OnSelected = nothing,
		Options = { { Id = "Rating", Text = "Rating" }, { Id = "Name", Text = "Name" }, { Id = "Tier", Text = "Tier" } },
	}
	local sliderProps = {
		Value = 0.5,
		Label = "Hue",
		ValueText = "180",
		Gradient = ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1)),
		OnChanged = nothing,
		OnReleased = nothing,
	}
	for _, preset in ipairs({ "R1080", "C844" }) do
		contract("Header", preset, M.Header, headerProps, nil)
		contract("Header title only", preset, M.Header, { Title = "Races" }, nil)
		contract("IconButton", preset, M.IconButton, { Icon = "garage", Selected = true, OnActivated = nothing }, 4)
		contract("IconButton Small disabled", preset, M.IconButton, { Icon = "plus", Size = "Small", Disabled = true }, 4)
		contract("Switch", preset, M.Switch, { On = true, LabelOn = "Rotate", LabelOff = "North up", OnChanged = nothing }, 5)
		contract("Stepper", preset, M.Stepper, { Value = 3, Min = 1, Max = 5, OnChanged = nothing }, 9)
		contract("Slider", preset, M.Slider, sliderProps, 7)
		contract("Slider bare", preset, M.Slider, { Value = 0.25 }, 7)
		contract("Swatch", preset, M.Swatch, { Colour = Color3.new(1, 0, 0), Selected = true, OnActivated = nothing }, 3)
		contract("Dropdown", preset, M.Dropdown, dropdownProps, 5)
	end

	case("headerPlace: Regular starts at the slot; Compact sits beside the Roblox buttons, the rest under the bar", function()
		local x, y, below = M._headerPlace(false, 68, 70, 58, 208, 0, 60)
		expect(x == 0 and y == 0 and below == 60, "regular")
		x, y, below = M._headerPlace(true, 12, 8, 52, 120, 8, 17)
		expect(x == 116, "compact x " .. x)
		expect(y == 9, "compact y " .. y)
		expect(below == 44, "compact below " .. below)
		x, y, below = M._headerPlace(true, 12, 60, 52, 120, 8, 17)
		expect(x == 0 and y == 0 and below == 17, "a compact slot under the bar is left alone")
		x, y, below = M._headerPlace(true, 300, 8, 52, 120, 8, 17)
		expect(x == 0, "a slot right of the buttons is not moved")
	end)
	case("Header: mark, title, count, sub-line and tabs; Height is the stack; Set updates in place", function()
		local parent = stage("R1080")
		local scope = newScope()
		local header = M.Header(parent, headerProps, scope)
		local root = header.Instance
		for _, name in ipairs({ "TitleMark", "Title", "Count", "Sub", "Tabs" }) do
			expect(root:FindFirstChild(name) ~= nil, name .. " missing")
		end
		expect(root.Title.Label.Text == "CUSTOMISE", "title text")
		expect(header.Tabs ~= nil and header.Tabs.Instance == root.Tabs, "header.Tabs")
		expect(header.Height() > 0 and header.Height() == root.Size.Y.Offset, "Height")
		expect(root.Title.Position.X.Offset > root.TitleMark.Position.X.Offset, "the title is not right of the mark")
		expect(root.Sub.Position.Y.Offset >= root.TitleMark.Size.Y.Offset, "the sub-line is not under the title row")
		expect(root.Tabs.Position.Y.Offset > root.Sub.Position.Y.Offset, "the tabs are not under the sub-line")
		expect(root.Tabs.Position.Y.Offset + root.Tabs.Size.Y.Offset == header.Height(), "Height is not the bottom of the tabs")
		local count = #root:GetDescendants()
		header.Set({ Title = "Dealership", Count = "12" })
		expect(root.Title.Label.Text == "DEALERSHIP" and root.Count.Label.Text == "12", "Set did not write the texts")
		expect(#root:GetDescendants() == count, "a text change created or destroyed instances")
		header.Tabs.Select("Upgrades")
		expect(root.Tabs.TabUpgrades.Underline.Visible == true, "header.Tabs is not the live tabs component")
		header.Destroy()
		expect(#parent:GetChildren() == 0, "children left")
		scope:destroy()
	end)
	case("Header: keep-out rule 2 on Compact; MarkKey goes to the title TextLabel", function()
		local ctx = Metrics.Fixed({
			Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch",
			TopBarHeight = 52, TopBarKeepOut = Vector2.new(120, 52),
		})
		local slot = env.Detached("Frame")
		slot.Name = "SlotTopLeft"
		slot.Position = UDim2.fromOffset(12, 8)
		Metrics.Bind(slot, ctx)
		local scope = newScope()
		local header = M.Header(slot, { Title = "Dealership", Tabs = tabsProps, MarkKey = "Text.Dealership" }, scope)
		local root = header.Instance
		local markHeight = root.TitleMark.Size.Y.Offset
		local x, y, below = M._headerPlace(true, 12, 8, 52, 120, ctx.Px(Tokens.Space.CompactKeepOutGap), markHeight)
		expect(root.TitleMark.Position == UDim2.fromOffset(x, y), "the mark is not beside the Roblox buttons")
		expect(root.TitleMark.Position.X.Offset + 12 >= 120, "the mark is inside the keep-out")
		expect(root.Tabs.Position.Y.Offset == below + ctx.Px(Tokens.Space.CompactKeepOutGap), "the tabs do not start under the bar")
		expect(root.Tabs.Position.Y.Offset + 8 >= 52, "the tabs are inside the bar row")
		local marked = nil
		for _, child in ipairs(root.Title:GetChildren()) do
			if child:IsA("TextLabel") and child:GetAttribute("PulseMark") == "Text.Dealership" then
				marked = child
			end
		end
		expect(marked ~= nil, "the mark was not applied to the title TextLabel")
		expect(root:GetAttribute("PulseMark") == nil, "the mark went to the header root")
		header.Destroy()
		scope:destroy()
	end)
	case("iconButtonSize and IconButton: the action tile, its hit box and the selected look", function()
		local S = Tokens.Space
		local w, h = M._iconButtonSize(false, "Action")
		expect(w == S.ActionTileWidth and h == S.ActionTileHeight, "regular action tile")
		w, h = M._iconButtonSize(true, "Action")
		expect(w == S.CompactActionTile and h == S.CompactActionTile, "compact action tile")
		expect(not pcall(M._iconButtonSize, false, "Huge"), "unknown size accepted")
		for _, preset in ipairs({ "R1080", "C844" }) do
			local parent, ctx = stage(preset)
			local scope = newScope()
			local button = M.IconButton(parent, { Icon = "car" }, scope)
			local root = button.Instance
			w, h = M._iconButtonSize(ctx.Class == "Compact", "Action")
			expect(root:IsA("GuiButton") and root.Selectable == true and root.Active == true, preset .. ": not an active selectable GuiButton")
			expect(root.Fill.Size == UDim2.fromOffset(ctx.Px(w), ctx.Px(h)), preset .. ": drawn size")
			expect(root.Size == UDim2.fromOffset(ctx.Touch(w), ctx.Touch(h)), preset .. ": hit box")
			expect(root.Fill.BackgroundColor3 == Tokens.Colour.Slate and root.Fill.Icon.ImageColor3 == Tokens.Colour.White, preset .. ": idle look")
			button.Set({ Selected = true })
			expect(root.Fill.BackgroundColor3 == Tokens.Colour.White and root.Fill.Icon.ImageColor3 == Tokens.Colour.Ink, preset .. ": selected look")
			button.Set({ Selected = false, Disabled = true })
			expect(root.Active == false and root.Visible == true, preset .. ": disabled")
			expect(not pcall(M.IconButton, parent, {}, scope), preset .. ": built without an Icon")
			button.Destroy()
			scope:destroy()
		end
	end)
	case("Switch: two cells, the active one White with Ink text; disabled is inactive", function()
		local parent = stage("R1080")
		local scope = newScope()
		local switch = M.Switch(parent, { On = true, LabelOn = "Rotate", LabelOff = "North up" }, scope)
		local root = switch.Instance
		expect(root:IsA("TextButton") and root.Selectable == true, "not a selectable TextButton")
		expect(root.CellOn.Text == "ROTATE" and root.CellOff.Text == "NORTH UP", "labels")
		expect(root.CellOn.BackgroundTransparency == 0 and root.CellOn.TextColor3 == Tokens.Colour.Ink, "active cell")
		expect(about(root.CellOff.BackgroundTransparency, 1 - Tokens.Opacity.ChipNeutral), "idle cell")
		expect(root.CellOn.Size == root.CellOff.Size and root.CellOff.Position.X.Offset == root.CellOn.Size.X.Offset, "cells are not equal and side by side")
		local count = #root:GetDescendants()
		switch.Set({ On = false })
		expect(root.CellOff.BackgroundTransparency == 0 and root.CellOff.TextColor3 == Tokens.Colour.Ink, "the active cell did not move")
		expect(#root:GetDescendants() == count, "instances created or destroyed")
		switch.Set({ Disabled = true })
		expect(root.Active == false and root.Visible == true, "disabled")
		switch.Destroy()
		scope:destroy()
	end)
	case("stepValue and Stepper: buttons disable at the ends; Format writes the value", function()
		expect(M._stepValue(3, 1, 5, nil, 1) == 4 and M._stepValue(3, 1, 5, nil, -1) == 2, "one step")
		expect(M._stepValue(5, 1, 5, nil, 1) == 5 and M._stepValue(1, 1, 5, 2, -1) == 1, "held at the ends")
		expect(M._stepValue(4, 1, 5, 2, 1) == 5, "a step past the end stops on it")
		expect(M._stepValue(10, nil, nil, 5, 1) == 15, "no limits")
		local parent = stage("R1080")
		local scope = newScope()
		local stepper = M.Stepper(parent, {
			Value = 1, Min = 1, Max = 3,
			Format = function(value)
				return value .. " laps"
			end,
		}, scope)
		local root = stepper.Instance
		expect(root.Minus:IsA("GuiButton") and root.Plus:IsA("GuiButton") and root.Plus.Selectable == true, "buttons")
		expect(root.Minus.Active == false and root.Plus.Active == true, "at Min")
		expect(root.Plate.Value.Text == "1 LAPS", "value text " .. root.Plate.Value.Text)
		expect(root.Plate:FindFirstChild("HairTop") ~= nil and root.Plate:FindFirstChild("HairBottom") ~= nil, "plate hairlines")
		local count = #root:GetDescendants()
		stepper.Set({ Value = 3 })
		expect(root.Minus.Active == true and root.Plus.Active == false, "at Max")
		stepper.Set({ Value = 2 })
		expect(root.Minus.Active == true and root.Plus.Active == true, "between")
		expect(#root:GetDescendants() == count, "instances created or destroyed")
		stepper.Destroy()
		scope:destroy()
	end)
	case("slideValue and Slider: active, selectable; a value change moves the fill and handle only", function()
		expect(about(M._slideValue(0.5, 1, false), 0.51) and about(M._slideValue(0.5, -1, false), 0.49), "fine step")
		expect(about(M._slideValue(0.5, 1, true), 0.55), "coarse step")
		expect(M._slideValue(1, 1, true) == 1 and M._slideValue(0, -1, false) == 0, "held in 0..1")
		local parent = stage("R1080")
		local scope = newScope()
		local slider = M.Slider(parent, { Value = 0.25, Label = "Hue", ValueText = "90" }, scope)
		local root = slider.Instance
		expect(root:IsA("GuiButton") and root.Active == true and root.Selectable == true, "not an active selectable GuiButton")
		expect(about(root.Fill.Size.X.Scale, 0.25) and about(root.Handle.Position.X.Scale, 0.25), "value")
		expect(root.Label.Text == "HUE" and root.ValueText.Text == "90", "texts")
		expect(root.Fill.Visible == true and root.Track:FindFirstChildOfClass("UIGradient") == nil, "plain track")
		local size = root.Size
		slider.Set({ Value = 0.75, ValueText = "270" })
		expect(about(root.Fill.Size.X.Scale, 0.75) and about(root.Handle.Position.X.Scale, 0.75), "the value did not move")
		expect(root.ValueText.Text == "270" and root.Size == size, "value text or hit box")
		slider.Set({ Gradient = sliderProps.Gradient })
		expect(root.Track:FindFirstChildOfClass("UIGradient") ~= nil and root.Fill.Visible == false, "paint ramp")
		expect(root.Track.BackgroundTransparency == 0, "the ramp track is not opaque")
		slider.Set({ Value = 7 })
		expect(about(root.Handle.Position.X.Scale, 1), "a value above 1 is not held")
		slider.Destroy()
		scope:destroy()
	end)
	case("Swatch: its own colour; Selected adds the White frame and the Pink base line; a Color3 is required", function()
		local parent = stage("R1080")
		local scope = newScope()
		local red = Color3.new(1, 0, 0)
		local swatch = M.Swatch(parent, { Colour = red }, scope)
		local root = swatch.Instance
		expect(root:IsA("GuiButton") and root.Selectable == true, "not a selectable GuiButton")
		expect(root.Colour.BackgroundColor3 == red and root.Colour.Size == root.Size, "colour cell")
		expect(root.BackgroundTransparency == 1 and root.BaseLine.Visible == false, "idle frame or line")
		swatch.Set({ Selected = true })
		expect(root.BackgroundTransparency == 0 and root.BackgroundColor3 == Tokens.Colour.White, "white frame")
		expect(root.BaseLine.Visible == true and root.BaseLine.BackgroundColor3 == Tokens.Colour.Pink, "base line")
		expect(root.Colour.Size.X.Offset < root.Size.X.Offset, "the colour cell did not make room for the frame")
		expect(not pcall(M.Swatch, parent, { Colour = "Pink" }, scope), "a colour role accepted")
		expect(not pcall(M.Swatch, parent, {}, scope), "built without a colour")
		swatch.Destroy()
		expect(#parent:GetChildren() == 0, "children left")
		scope:destroy()
	end)
	case("Dropdown: the list is built on the first opening in the top frame, kept after, gone on Destroy", function()
		local parent = stage("R1080")
		local scope = newScope()
		local dropdown = M.Dropdown(parent, dropdownProps, scope)
		local root = dropdown.Instance
		expect(root:IsA("GuiButton") and root.Selectable == true, "not a selectable GuiButton")
		expect(root.Fill.Label.Text == "SORT" and root.Fill.Value.Text == "RATING", "closed texts")
		expect(#parent:GetChildren() == 1 and dropdown.IsOpen() == false, "something was built before the first opening")
		dropdown.Open()
		local catcher = parent:FindFirstChild("DropdownCatcher")
		expect(dropdown.IsOpen() == true and catcher ~= nil and catcher.Visible == true, "not open")
		expect(catcher:IsA("GuiButton") and catcher.ZIndex > root.ZIndex, "the catcher is not a button above the layer")
		local list = catcher:FindFirstChild("List")
		expect(list ~= nil and list:IsA("ScrollingFrame"), "List missing")
		local options = 0
		for _, child in ipairs(list:GetChildren()) do
			expect(child:IsA("TextButton") and child.Selectable == true, child.Name .. " is not a selectable TextButton")
			expect(budget(child) == 2, child.Name .. " is " .. budget(child) .. " instances, not 2")
			options = options + 1
		end
		expect(options == 3 and list:FindFirstChild("OptionName") ~= nil, "options")
		expect(list.CanvasSize.Y.Offset == 3 * list.OptionName.Size.Y.Offset, "canvas")
		expect(budget(root) <= 5, "the open list is inside the control")
		dropdown.Close()
		expect(dropdown.IsOpen() == false and catcher.Parent == parent and catcher.Visible == false, "close")
		dropdown.Open()
		expect(parent:FindFirstChild("DropdownCatcher") == catcher and #parent:GetChildren() == 2, "the list was rebuilt")
		dropdown.Set({ Selected = "Name" })
		expect(root.Fill.Value.Text == "NAME", "Set Selected")
		dropdown.Set({ Options = { { Id = "Name", Text = "Name" } } })
		expect(dropdown.IsOpen() == false, "an options change left the old list open")
		dropdown.Open()
		local rebuilt = parent:FindFirstChild("DropdownCatcher")
		expect(rebuilt ~= nil and rebuilt ~= catcher and #parent:GetChildren() == 2, "the stale list was kept")
		expect(not pcall(dropdown.Set, { Options = { { Text = "No id" } } }), "an option without an Id accepted")
		dropdown.Destroy()
		expect(#parent:GetChildren() == 0, "children left under the layer")
		scope:destroy()
	end)

	return results
end
