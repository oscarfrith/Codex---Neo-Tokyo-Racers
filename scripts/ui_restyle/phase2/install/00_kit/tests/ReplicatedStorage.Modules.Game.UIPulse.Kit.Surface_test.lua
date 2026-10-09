-- Owns the pure tests for Kit.Surface; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.Surface_test. Requires: none (modules come from env.Load).
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
	local Sprites = env.Load(KIT .. "Sprites")
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
	-- API2 2.7 states 3 for Garage; two gradients need two frames, so it is 4 (k2 NOTES, ambiguity 3).
	common("Scrim Garage", Surface.Scrim, c844, { Kind = "Garage" }, 4)
	common("Scrim Hud", Surface.Scrim, r1080, { Kind = "Hud" }, 3)
	common("Icon with Opacity", Surface.Icon, c844, { Icon = "tick", Colour = "Cyan", Size = 32, Opacity = 0.4 }, 1)
	common("TitleMark", Surface.TitleMark, r1080, {}, 1)
	common("TitleMark Height", Surface.TitleMark, c844, { Height = 18 }, 1)
	common("MapIcon", Surface.MapIcon, r1080, { Icon = "Race", Colour = "Pink", Size = 48 }, 1)
	common("MapIcon pin", Surface.MapIcon, c844, { Icon = "Waypoint", Size = 32 }, 1)
	common("KeyCap text", Surface.KeyCap, r1080, { Text = "E" }, 2)
	common("KeyCap word", Surface.KeyCap, r720, { Text = "Space", Size = 48 }, 2)
	common("KeyCap glyph", Surface.KeyCap, c844, { Icon = "pad_a" }, 2)
	common("Divider", Surface.Divider, r1080, {}, 1)
	common("Divider upright", Surface.Divider, c844, { Vertical = true, Opacity = 0.5 }, 1)
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

	case("Panel: nil Height fills; FitContent sizes to Content plus the pad; Height wins", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r720)
		local scope = fakeScope()
		local pad = r720.Px(Tokens.Space.Pad)
		local fill = Surface.Panel(parent, { Width = 480 }, scope)
		expect(fill.Instance.Size, UDim2.new(0, r720.Px(480), 1, 0), "nil Height fills")
		expect(fill.Content.AutomaticSize, Enum.AutomaticSize.None, "a filling panel has a fixed Content")
		expect(fill.Content.Size, UDim2.new(1, -pad - pad, 1, -pad - pad), "filling Content size")
		fill.Destroy()
		local fit = Surface.Panel(parent, { Width = 480, FitContent = true }, scope)
		expect(fit.Instance.Size.Y.Scale, 0, "a FitContent panel fills the parent")
		expect(fit.Instance.Size.Y.Offset, math.ceil(fit.Content.AbsoluteSize.Y) + pad + pad, "FitContent height")
		expect(fit.Content.AutomaticSize, Enum.AutomaticSize.Y, "Content does not grow")
		expect(fit.Content.Size, UDim2.new(1, -pad - pad, 0, 0), "fitting Content size")
		fit.Set({ Height = 300 })
		expect(fit.Instance.Size, UDim2.fromOffset(r720.Px(480), r720.Px(300)), "Height does not win")
		expect(fit.Content.AutomaticSize, Enum.AutomaticSize.None, "Content still grows under a Height")
		expect(pcall(Surface.Panel, parent, { FitContent = "yes" }, scope), false, "a string FitContent was accepted")
		fit.Destroy()
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
		local cell = Sprites.Icons.Cell
		local glyph = Sprites.Icons.Glyphs.lock
		expect(icon.Instance.ClassName, "ImageLabel", "class")
		expect(icon.Instance.Size, UDim2.fromOffset(r720.Px(64), r720.Px(64)), "box")
		expect(icon.Instance.ImageRectOffset, Vector2.new(glyph[1] * cell, glyph[2] * cell), "ImageRectOffset")
		expect(icon.Instance.ImageRectSize, Vector2.new(cell, cell), "ImageRectSize")
		expect(icon.Instance.ImageColor3, Tokens.Colour.Yellow, "colour")
		expect(icon.Instance.Image, Tokens.Asset("IconSheet") or "", "image")
		expect(icon.Instance.ImageTransparency, 0, "opaque by default")
		icon.Set({ Opacity = 0.4 })
		expect(math.abs(icon.Instance.ImageTransparency - 0.6) < 1e-6, true, "Opacity")
		expect(pcall(Surface.Icon, parent, { Icon = "no_such_icon", Colour = "White", Size = 64 }, scope), false,
			"unknown icon")
		expect(pcall(icon.Set, { Icon = "no_such_icon" }), false, "Set unknown icon")
		icon.Destroy()
		scope:destroy()
	end)

	-- API2 2.7 ------------------------------------------------------------------------------------------------
	-- Runs body with every asset id emptied (the flat state of API1 3.6), then puts the ids back.
	local function withNoAssets(body)
		if table.isfrozen(Tokens.Assets) then
			return -- nothing to empty: the ids cannot be changed in this build
		end
		local saved = table.clone(Tokens.Assets)
		for key in saved do
			Tokens.Assets[key] = ""
		end
		local ok, detail = pcall(body)
		for key, value in saved do
			Tokens.Assets[key] = value
		end
		if not ok then
			error(detail, 0)
		end
	end

	case("every constructor builds with every asset empty, and Glow is then a zero-size Frame", function()
		withNoAssets(function()
			local parent = env.Detached("Frame")
			Metrics.Bind(parent, r1080)
			local scope = fakeScope()
			local built = {
				Surface.Icon(parent, { Icon = "car", Colour = "White", Size = 64 }, scope),
				Surface.MapIcon(parent, { Icon = "Garage", Size = 48 }, scope),
				Surface.TitleMark(parent, {}, scope),
				Surface.KeyCap(parent, { Text = "F" }, scope),
				Surface.KeyCap(parent, { Icon = "pad_x" }, scope),
				Surface.Divider(parent, {}, scope),
				Surface.Scrim(parent, { Kind = "Hud" }, scope),
			}
			local glow = Surface.Glow(parent, { Kind = "Button", Colour = "Pink" }, scope)
			expect(glow.Instance.ClassName, "Frame", "glow class")
			expect(glow.Instance.Size, UDim2.fromOffset(0, 0), "glow size")
			expect(built[1].Instance.Image, "", "icon image")
			expect(built[1].Instance.Size, UDim2.fromOffset(64, 64), "the icon keeps its box")
			expect(built[3].Instance.Image, "", "title mark image")
			expect(built[3].Instance.BackgroundTransparency, 0, "title mark is a block")
			expect(built[3].Instance.BackgroundColor3, Tokens.Colour.Pink, "title mark is Pink")
			expect(built[4].Instance.BackgroundTransparency, 0, "key cap is a flat box")
			glow.Destroy()
			for _, component in built do
				component.Destroy()
			end
			expect(#parent:GetChildren(), 0, "parent empty")
			scope:destroy()
		end)
	end)

	case("Glow: with an id it is a tinted 9-slice one radius past each edge", function()
		if Tokens.Asset("GlowSoft") == nil then
			return
		end
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r1080)
		local scope = fakeScope()
		local glow = Surface.Glow(parent, { Kind = "Tile", Colour = "Pink" }, scope)
		local radius = r1080.Px(Tokens.Space.GlowTileRadius)
		expect(glow.Instance.ClassName, "ImageLabel", "class")
		expect(glow.Instance.Image, Tokens.Asset("GlowSoft"), "image")
		expect(glow.Instance.ImageColor3, Tokens.Colour.Pink, "tint")
		expect(glow.Instance.ScaleType, Enum.ScaleType.Slice, "ScaleType")
		expect(glow.Instance.SliceCenter, Tokens.Slices.GlowSoft.Center, "SliceCenter")
		expect(glow.Instance.Position, UDim2.fromOffset(-radius, -radius), "position")
		expect(glow.Instance.Size, UDim2.new(1, radius + radius, 1, radius + radius), "size")
		glow.Destroy()
		scope:destroy()
	end)

	case("TitleMark: untinted, the aspect of the art, default height from the token", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r1080)
		local scope = fakeScope()
		local mark = Surface.TitleMark(parent, {}, scope)
		local art = Sprites.Rings.TitleSlash.Size
		local height = r1080.Px(Tokens.Space.TitleMarkHeight)
		expect(mark.Instance.ClassName, "ImageLabel", "class")
		expect(mark.Instance.Size.Y.Offset, height, "height")
		expect(mark.Instance.Size.X.Offset, math.floor(height * art[1] / art[2] + 0.5), "width")
		expect(mark.Instance.ImageColor3, Color3.new(1, 1, 1), "never tinted")
		expect(mark.Instance.Image, Tokens.Asset("TitleSlash") or "", "image")
		mark.Set({ Height = 30 })
		expect(mark.Instance.Size.Y.Offset, r1080.Px(30), "Height prop")
		mark.Destroy()
		scope:destroy()
	end)

	case("MapIcon: sheet cell, pin anchor, Tint accepted here only", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r1080)
		local scope = fakeScope()
		local sheet = Sprites.MapIcons
		local icon = Surface.MapIcon(parent, { Icon = "Race", Colour = "Cyan", Size = 48 }, scope)
		local glyph = sheet.Glyphs.Race
		expect(icon.Instance.ImageRectOffset, Vector2.new(glyph[1] * sheet.Cell, glyph[2] * sheet.Cell), "ImageRectOffset")
		expect(icon.Instance.ImageRectSize, Vector2.new(sheet.Cell, sheet.Cell), "ImageRectSize")
		expect(icon.Instance.AnchorPoint, Vector2.new(0.5, 0.5), "centre anchor")
		expect(icon.Instance.ImageColor3, Tokens.Colour.Cyan, "role colour")
		expect(icon.Instance.Image, Tokens.Asset("MapIconSheet") or "", "image")
		local tint = Color3.new(0.25, 0.5, 0.75)
		icon.Set({ Icon = "Waypoint", Tint = tint })
		expect(icon.Instance.AnchorPoint, Vector2.new(0.5, sheet.PinTipY), "pin anchors on its tip")
		expect(icon.Instance.ImageColor3, tint, "Tint")
		expect(pcall(Surface.MapIcon, parent, { Icon = "lock", Size = 48 }, scope), false, "an icon-sheet name")
		expect(pcall(Surface.MapIcon, parent, { Icon = "Race", Size = 48, Tint = "Pink" }, scope), false, "Tint not a Color3")
		expect(pcall(Surface.Icon, parent, { Icon = "lock", Colour = "White", Size = 48, Tint = tint }, scope), false,
			"Icon accepted a Tint")
		icon.Destroy()
		scope:destroy()
	end)

	case("KeyCap: a white cap with an Ink letter, or a pad glyph", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r1080)
		local scope = fakeScope()
		local cap = Surface.KeyCap(parent, { Text = "e" }, scope)
		local size = r1080.Px(Tokens.Space.KeyCapSize)
		local letter = cap.Instance:FindFirstChild("Letter")
		expect(cap.Instance.ClassName, "ImageLabel", "class")
		expect(cap.Instance.Size.Y.Offset, size, "height")
		expect(cap.Instance.Size.X.Offset >= size, true, "at least square")
		expect(letter ~= nil and letter.Text, "E", "letter")
		expect(letter.TextColor3, Tokens.Colour.Ink, "letter colour")
		expect(letter.TextScaled, false, "TextScaled")
		expect(cap.Instance.ImageColor3, Tokens.Colour.White, "cap colour")
		if Tokens.Asset("KeyCap") ~= nil then
			expect(cap.Instance.ScaleType, Enum.ScaleType.Slice, "ScaleType")
			expect(cap.Instance.SliceCenter, Tokens.Slices.KeyCap.Center, "SliceCenter")
		end
		cap.Set({ Icon = "pad_a" })
		local glyph = Sprites.Icons.Glyphs.pad_a
		expect(cap.Instance.ImageRectOffset, Vector2.new(glyph[1] * Sprites.Icons.Cell, glyph[2] * Sprites.Icons.Cell), "glyph cell")
		expect(cap.Instance.Size, UDim2.fromOffset(size, size), "glyph box")
		expect(letter.Visible, false, "letter hidden for a glyph")
		expect(pcall(Surface.KeyCap, parent, { Icon = "no_such_icon" }, scope), false, "unknown glyph")
		cap.Destroy()
		scope:destroy()
	end)

	case("Divider: one hairline frame, across or upright", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r720)
		local scope = fakeScope()
		local divider = Surface.Divider(parent, {}, scope)
		local hair = r720.Hair(Tokens.Space.Hairline)
		expect(divider.Instance.ClassName, "Frame", "class")
		expect(divider.Instance.Size, UDim2.new(1, 0, 0, hair), "across")
		expect(divider.Instance.BackgroundColor3, Tokens.Colour.White, "colour")
		divider.Set({ Vertical = true, Opacity = 1 })
		expect(divider.Instance.Size, UDim2.new(0, hair, 1, 0), "upright")
		expect(divider.Instance.BackgroundTransparency, 0, "Opacity")
		divider.Destroy()
		scope:destroy()
	end)

	case("Scrim: Garage has a left and a bottom fade; Hud is one inactive gradient; a kind change cleans up", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r1080)
		local scope = fakeScope()
		local scrim = Surface.Scrim(parent, { Kind = "Garage" }, scope)
		local bottom = scrim.Instance:FindFirstChild("Bottom")
		expect(scrim.Instance:FindFirstChildOfClass("UIGradient") ~= nil, true, "left gradient")
		expect(bottom ~= nil and bottom:FindFirstChildOfClass("UIGradient") ~= nil, true, "bottom gradient")
		expect(bottom.Active, false, "bottom fade does not block input")
		scrim.Set({ Kind = "Hud" })
		expect(scrim.Instance:FindFirstChild("Bottom"), nil, "bottom fade removed")
		expect(scrim.Instance.Active, false, "Hud inactive")
		expect(scrim.Instance:FindFirstChildOfClass("UIGradient").Rotation, 90, "Hud gradient is vertical")
		expect(1 + #scrim.Instance:GetDescendants(), 2, "Hud instances")
		scrim.Destroy()
		scope:destroy()
	end)

	return results
end
