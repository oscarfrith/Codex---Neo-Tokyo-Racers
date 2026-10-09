-- Owns the pure tests for Kit.Surface; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase1). tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.Surface_test. Requires: none (modules come from env.Load).
local KIT = "ReplicatedStorage.Modules.Game.UIPulse.Kit."

local SNAPSHOT_PROPERTIES = {
	"Name", "Visible", "LayoutOrder", "ZIndex", "Active", "Size", "Position", "AnchorPoint",
	"BackgroundColor3", "BackgroundTransparency", "Image", "ImageColor3", "ImageTransparency",
	"ImageRectOffset", "ImageRectSize", "ScaleType", "SliceCenter", "SliceScale", "Rotation",
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

return function(Surface, env)
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

	local r1080 = Metrics.Fixed({ Size = Vector2.new(1920, 1080) })
	local r720 = Metrics.Fixed({ Size = Vector2.new(1280, 720) })
	local c844 = Metrics.Fixed({ Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch" })

	-- The checks every constructor shares (API 13): budget, unchanged Set, unknown key, Destroy.
	local function common(name, constructor, ctx, props, budget)
		case(name .. ": builds on a detached parent within budget " .. budget, function()
			local parent = env.Detached("Frame")
			Metrics.Bind(parent, ctx)
			local scope = fakeScope()
			local component = constructor(parent, props, scope)
			expect(component.Instance.Parent, parent, "root parent")
			expect(#parent:GetChildren(), 1, "one root")
			local count = 1 + #component.Instance:GetDescendants()
			if count > budget then
				error("budget " .. budget .. " exceeded: " .. count)
			end

			local before = snapshot(component.Instance)
			component.Set(table.clone(props))
			expect(snapshot(component.Instance), before, "unchanged Set")

			expect(pcall(component.Set, { Nope = true }), false, "Set unknown key")
			local bad = table.clone(props)
			bad.Nope = true
			expect(pcall(constructor, parent, bad, scope), false, "constructor unknown key")
			expect(#parent:GetChildren(), 1, "failed constructor leaves nothing")

			component.Set({ Visible = false, LayoutOrder = 7, Name = "Renamed" })
			expect(component.Instance.Visible, false, "Visible")
			expect(component.Instance.LayoutOrder, 7, "LayoutOrder")
			expect(component.Instance.Name, "Renamed", "Name")

			component.Destroy()
			expect(#parent:GetChildren(), 0, "parent empty after Destroy")
			component.Destroy()
			component.Set({ Visible = true })
			scope:destroy()
		end)
	end

	common("Panel", Surface.Panel, r1080, { Width = 480, Height = 300 }, 4)
	common("Panel (no hairlines, Compact)", Surface.Panel, c844, { Hairlines = false, Pad = 12 }, 4)
	common("Hairline Top", Surface.Hairline, r1080, { Edge = "Top" }, 1)
	common("Hairline Bottom", Surface.Hairline, r720, { Edge = "Bottom", Colour = "Pink", Opacity = 1 }, 1)
	common("Scrim Menu", Surface.Scrim, r1080, { Kind = "Menu" }, 2)
	common("Scrim Confirm", Surface.Scrim, r1080, { Kind = "Confirm" }, 2)
	common("Scrim Garage", Surface.Scrim, c844, { Kind = "Garage" }, 2)
	common("Glow Tile", Surface.Glow, r1080, { Kind = "Tile", Colour = "Pink" }, 1)
	common("Glow Button", Surface.Glow, r1080, { Kind = "Button", Colour = "Pink" }, 1)
	common("Glow Line", Surface.Glow, c844, { Kind = "Line", Colour = "Pink" }, 1)
	common("Glow Ring", Surface.Glow, r1080, { Kind = "Ring", Colour = "Cyan" }, 1)
	common("Icon", Surface.Icon, r1080, { Icon = "lock", Colour = "White", Size = 64 }, 1)

	case("Panel: children, look and geometry", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r720)
		local scope = fakeScope()
		local panel = Surface.Panel(parent, { Width = 480, Height = 300 }, scope)
		local root = panel.Instance
		expect(root.Name, "Panel", "name")
		expect(root.Active, true, "Active")
		expect(root.BackgroundColor3, Tokens.Colour.Slate, "colour")
		expect(root.Size, UDim2.fromOffset(r720.Px(480), r720.Px(300)), "size")
		local hairTop = root:FindFirstChild("HairTop")
		local hairBottom = root:FindFirstChild("HairBottom")
		local content = root:FindFirstChild("Content")
		expect(hairTop ~= nil and hairBottom ~= nil and content ~= nil, true, "required children")
		expect(panel.Content, content, "component.Content")
		expect(hairTop.Size.Y.Offset, r720.Hair(Tokens.Space.Hairline), "hairline thickness")
		expect(content.Position, UDim2.fromOffset(r720.Px(Tokens.Space.Pad), r720.Px(Tokens.Space.Pad)), "pad")
		panel.Set({ Hairlines = false })
		expect(hairTop.Visible, false, "HairTop hidden")
		expect(hairBottom.Visible, false, "HairBottom hidden")
		panel.Destroy()
		scope:destroy()
	end)

	case("Hairline: edge and default opacity", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r1080)
		local scope = fakeScope()
		local line = Surface.Hairline(parent, { Edge = "Bottom" }, scope)
		expect(line.Instance.AnchorPoint, Vector2.new(0, 1), "anchor")
		expect(line.Instance.Size, UDim2.new(1, 0, 0, r1080.Hair(Tokens.Space.Hairline)), "size")
		expect(pcall(Surface.Hairline, parent, { Edge = "Left" }, scope), false, "unknown edge")
		expect(pcall(Surface.Hairline, parent, {}, scope), false, "missing edge")
		line.Destroy()
		scope:destroy()
	end)

	case("Scrim: full size, inactive, gradient only where drawn", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r1080)
		local scope = fakeScope()
		local scrim = Surface.Scrim(parent, { Kind = "Menu" }, scope)
		expect(scrim.Instance.Active, false, "Active")
		expect(scrim.Instance.Size, UDim2.fromScale(1, 1), "size")
		expect(scrim.Instance:FindFirstChildOfClass("UIGradient") ~= nil, true, "Menu gradient")
		scrim.Set({ Kind = "Confirm" })
		expect(scrim.Instance:FindFirstChildOfClass("UIGradient"), nil, "Confirm is flat")
		expect(scrim.Instance.BackgroundColor3, Tokens.Colour.Black, "Confirm colour")
		expect(pcall(scrim.Set, { Kind = "Nope" }), false, "unknown kind")
		scrim.Destroy()
		scope:destroy()
	end)

	case("Glow: zero-size Frame while the asset is empty", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r1080)
		local scope = fakeScope()
		local glow = Surface.Glow(parent, { Kind = "Tile", Colour = "Pink" }, scope)
		if Tokens.Asset("GlowSoft") == nil then
			expect(glow.Instance.ClassName, "Frame", "class")
			expect(glow.Instance.Size, UDim2.fromOffset(0, 0), "size")
		else
			expect(glow.Instance.ClassName, "ImageLabel", "class")
			expect(glow.Instance.ScaleType, Enum.ScaleType.Slice, "ScaleType")
		end
		expect(glow.Instance.ZIndex, parent.ZIndex - 1, "ZIndex below the parent")
		expect(pcall(Surface.Glow, parent, { Kind = "Tile" }, scope), false, "missing colour")
		expect(pcall(Surface.Glow, parent, { Kind = "Halo", Colour = "Pink" }, scope), false, "unknown kind")
		glow.Destroy()
		scope:destroy()
	end)

	case("Icon: sheet cell, box kept with no image, unknown name errors", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r720)
		local scope = fakeScope()
		local icon = Surface.Icon(parent, { Icon = "lock", Colour = "Yellow", Size = 64 }, scope)
		local cell = Tokens.Icons.Cell
		local glyph = Tokens.Icons.Glyphs.lock
		expect(icon.Instance.ClassName, "ImageLabel", "class")
		expect(icon.Instance.Size, UDim2.fromOffset(r720.Px(64), r720.Px(64)), "box")
		expect(icon.Instance.ImageRectOffset, Vector2.new(glyph[1] * cell, glyph[2] * cell), "ImageRectOffset")
		expect(icon.Instance.ImageRectSize, Vector2.new(cell, cell), "ImageRectSize")
		expect(icon.Instance.ImageColor3, Tokens.Colour.Yellow, "colour")
		expect(icon.Instance.Image, Tokens.Asset("IconSheet") or "", "image")
		expect(pcall(Surface.Icon, parent, { Icon = "no_such_icon", Colour = "White", Size = 64 }, scope), false,
			"unknown icon")
		expect(pcall(icon.Set, { Icon = "no_such_icon" }), false, "Set unknown icon")
		icon.Destroy()
		scope:destroy()
	end)

	return results
end
