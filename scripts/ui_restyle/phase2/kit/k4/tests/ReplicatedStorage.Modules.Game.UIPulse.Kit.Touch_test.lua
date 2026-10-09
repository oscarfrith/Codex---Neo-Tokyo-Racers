-- Owns the pure tests for Kit.Touch; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.Touch_test. Requires: none (modules come from env.Load).
local KIT = "ReplicatedStorage.Modules.Game.UIPulse.Kit."

local SNAPSHOT_PROPERTIES = {
	"Name", "Visible", "LayoutOrder", "ZIndex", "Active", "Size", "Position", "AnchorPoint",
	"BackgroundTransparency", "Image", "ImageColor3", "ImageTransparency", "ImageRectOffset", "ImageRectSize",
	"Rotation", "ClipsDescendants",
}
local CONTROLS = { "Accelerate", "Brake", "Turn", "Drift", "Boost" }
-- API2 3.8 says 6 for Boost; the two-half reveal it also asks for needs 9 (NOTES.md, A7).
local BOOST_INSTANCES = 9

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
			elseif type(item) == "function" then
				item()
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

return function(Touch, env)
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

	local r1080 = Metrics.Fixed({ Size = Vector2.new(1920, 1080), TouchEnabled = true, Input = "Touch" })
	local c844 = Metrics.Fixed({ Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch" })
	local c568 = Metrics.Fixed({ Size = Vector2.new(568, 320), TouchEnabled = true, Input = "Touch" })
	local contexts = { r1080, c844, c568 }

	case("Metrics: the context carries Dp (API2 2.3)", function()
		for _, ctx in contexts do
			expect(type(ctx.Dp), "function", "ctx.Dp")
		end
		expect(c844.Dp(48), c844.Px(48), "Compact Dp is Px")
		expect(r1080.Dp(48), math.round(48 * Tokens.Scale.RegularDp), "Regular Dp is dp x ScaleRegularDp")
	end)

	-- So the remaining cases still say something if the case above fails: the API2 2.3 rule, locally.
	for _, ctx in contexts do
		if type(ctx.Dp) ~= "function" then
			local own = ctx
			own.Dp = function(dp)
				if own.Class == "Compact" then
					return own.Px(dp)
				end
				return math.max(1, math.round(dp * (Tokens.Scale.RegularDp or 1.25)))
			end
		end
	end

	local function build(ctx, props)
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, ctx)
		local scope = fakeScope()
		return Touch.Button(parent, props, scope), parent, scope
	end

	-- Pure functions ---------------------------------------------------------------------------------

	case("_percent: whole percent, clamped", function()
		expect(Touch._percent(0), 0, "0")
		expect(Touch._percent(1), 100, "1")
		expect(Touch._percent(0.644), 64, "0.644")
		expect(Touch._percent(0.646), 65, "0.646")
		expect(Touch._percent(-1), 0, "below")
		expect(Touch._percent(2), 100, "above")
		expect(Touch._percent(0 / 0), 0, "not a number")
	end)

	case("_chargeAngles: clockwise from 12 o'clock, right half first", function()
		local function pair(percent)
			local right, left = Touch._chargeAngles(percent)
			return right .. "," .. left
		end
		expect(pair(0), "0,180", "empty")
		expect(pair(25), "90,180", "quarter")
		expect(pair(50), "180,180", "half")
		expect(pair(75), "180,270", "three quarters")
		expect(pair(100), "180,360", "full")
	end)

	case("_geometry: hit boxes of 48 dp or more, the art centred on the plate, whole pixels", function()
		for _, ctx in contexts do
			local least = ctx.Dp(Tokens.Space.TouchMin)
			for _, control in CONTROLS do
				local sprite = Sprites.Touch[control]
				local geometry = Touch._geometry(control, ctx)
				local label = control .. " at " .. tostring(ctx.Size)
				if geometry.Hit.X < least or geometry.Hit.Y < least then
					error(label .. ": hit box " .. tostring(geometry.Hit) .. " is under " .. least)
				end
				if geometry.Hit.X < ctx.Dp(sprite.HitDp[1]) or geometry.Hit.Y < ctx.Dp(sprite.HitDp[2]) then
					error(label .. ": hit box smaller than HitDp")
				end
				expect(geometry.Frame, Vector2.new(ctx.Dp(sprite.FrameDp[1]), ctx.Dp(sprite.FrameDp[2])), label .. " frame")
				for _, value in { geometry.Hit.X, geometry.Hit.Y, geometry.Art.X, geometry.Art.Y } do
					expect(value % 1, 0, label .. " whole pixels")
				end
				-- The plate (centred in the art frame) must lie inside the hit box.
				local plateW, plateH = ctx.Dp(sprite.PlateDp[1]), ctx.Dp(sprite.PlateDp[2])
				local plateX = geometry.Art.X + (geometry.Frame.X - plateW) / 2
				local plateY = geometry.Art.Y + (geometry.Frame.Y - plateH) / 2
				if plateX < -1 or plateY < -1 or plateX + plateW > geometry.Hit.X + 1 or plateY + plateH > geometry.Hit.Y + 1 then
					error(label .. ": plate leaves the hit box")
				end
			end
		end
		expect(pcall(Touch._geometry, "Horn", c844), false, "unknown control")
	end)

	case("_geometry: accelerate sits bottom right, brake bottom centre, the others centred", function()
		local function plate(control)
			local sprite = Sprites.Touch[control]
			local geometry = Touch._geometry(control, c844)
			local plateW, plateH = c844.Dp(sprite.PlateDp[1]), c844.Dp(sprite.PlateDp[2])
			local x = geometry.Art.X + (geometry.Frame.X - plateW) / 2
			local y = geometry.Art.Y + (geometry.Frame.Y - plateH) / 2
			return x, y, plateW, plateH, geometry.Hit
		end
		local function near(actual, expected, what)
			if math.abs(actual - expected) > 1 then
				error(what .. ": expected about " .. expected .. ", got " .. actual)
			end
		end
		local x, y, w, h, hit = plate("Accelerate")
		near(x + w, hit.X, "accelerate right edge")
		near(y + h, hit.Y, "accelerate bottom edge")
		x, y, w, h, hit = plate("Brake")
		near(x + w / 2, hit.X / 2, "brake centre")
		near(y + h, hit.Y, "brake bottom edge")
		for _, control in { "Turn", "Drift", "Boost" } do
			x, y, w, h, hit = plate(control)
			near(x + w / 2, hit.X / 2, control .. " centre x")
			near(y + h / 2, hit.Y / 2, control .. " centre y")
		end
	end)

	-- Component ----------------------------------------------------------------------------------------

	for _, control in CONTROLS do
		local budget = control == "Boost" and BOOST_INSTANCES or 2
		case(control .. ": builds detached within " .. budget .. " instances, Set and Destroy", function()
			local props = { Control = control, Name = control .. "Button" }
			local component, parent, scope = build(c844, props)
			local root = component.Instance
			expect(root.Parent, parent, "root parent")
			expect(#parent:GetChildren(), 1, "one root")
			expect(root.Name, control .. "Button", "the given name")
			expect(root.ClassName, "TextButton", "Classic class by default")
			expect(root.Active, true, "Active")
			expect(root.BackgroundTransparency, 1, "transparent")
			expect(root.Text, "", "no text")
			local count = 1 + #root:GetDescendants()
			if count > budget then
				error("budget " .. budget .. " exceeded: " .. count)
			end
			local art = root:FindFirstChild("Art")
			expect(art ~= nil and art:IsA("ImageLabel"), true, "Art")
			local geometry = Touch._geometry(control, c844)
			expect(root.Size, UDim2.fromOffset(geometry.Hit.X, geometry.Hit.Y), "hit box")
			expect(art.Size, UDim2.fromOffset(geometry.Frame.X, geometry.Frame.Y), "art frame")
			expect(art.Position, UDim2.fromOffset(geometry.Art.X, geometry.Art.Y), "art place")
			expect(art.ImageColor3, Color3.new(1, 1, 1), "baked art stays white")

			local before = snapshot(root)
			component.Set(table.clone(props))
			expect(snapshot(root), before, "unchanged Set")
			component.SetPressed(false)
			component.SetDisabled(false)
			component.SetCharge(0)
			expect(snapshot(root), before, "unchanged setters")

			expect(pcall(component.Set, { Nope = true }), false, "Set unknown key")
			local bad = table.clone(props)
			bad.Nope = true
			expect(pcall(Touch.Button, parent, bad, scope), false, "constructor unknown key")
			expect(pcall(Touch.Button, parent, { Control = control }, scope), false, "Name required")
			expect(pcall(Touch.Button, parent, { Name = "X" }, scope), false, "Control required")
			expect(pcall(Touch.Button, parent, { Control = "Horn", Name = "X" }, scope), false, "unknown Control")
			expect(#parent:GetChildren(), 1, "failed constructors leave nothing")
			expect(pcall(component.Set, { Control = control == "Brake" and "Turn" or "Brake" }), false, "Control cannot change")

			component.Set({ Visible = false, LayoutOrder = 7, Name = "Renamed" })
			expect(root.Visible, false, "Visible")
			expect(root.LayoutOrder, 7, "LayoutOrder")
			expect(root.Name, "Renamed", "Name")

			component.Destroy()
			expect(#parent:GetChildren(), 0, "parent empty after Destroy")
			component.Destroy()
			component.Set({ Visible = true })
			component.SetPressed(true)
			component.SetDisabled(true)
			component.SetCharge(1)
			scope:destroy()
		end)
	end

	case("Class: ImageButton when the fork asks for it; anything else errors", function()
		local component, parent, scope = build(c844, { Control = "Turn", Name = "TurnLeft", Class = "ImageButton" })
		expect(component.Instance.ClassName, "ImageButton", "class")
		expect(component.Instance.Image, "", "the root draws nothing")
		expect(pcall(component.Set, { Class = "TextButton" }), false, "Class cannot change")
		expect(pcall(Touch.Button, parent, { Control = "Turn", Name = "X", Class = "Frame" }, scope), false, "not a button class")
		component.Destroy()
		scope:destroy()
	end)

	case("SetPressed: swaps the art between the idle and the pressed image; nothing is layered", function()
		for _, control in CONTROLS do
			local sprite = Sprites.Touch[control]
			local component, _, scope = build(c844, { Control = control, Name = control })
			local art = component.Instance.Art
			local count = #component.Instance:GetDescendants()
			expect(art.Image, Tokens.Asset(sprite.Idle) or "", control .. " idle")
			component.SetPressed(true)
			expect(art.Image, Tokens.Asset(sprite.Pressed) or "", control .. " pressed")
			expect(#component.Instance:GetDescendants(), count, control .. " no new instance")
			component.SetPressed(false)
			expect(art.Image, Tokens.Asset(sprite.Idle) or "", control .. " idle again")
			if Tokens.Asset(sprite.Idle) ~= nil and Tokens.Asset(sprite.Pressed) ~= nil then
				expect(Tokens.Asset(sprite.Idle) ~= Tokens.Asset(sprite.Pressed), true, control .. " two different images")
			end
			component.Destroy()
			scope:destroy()
		end
	end)

	case("SetDisabled: the art fades to TouchDisabled and comes back", function()
		local component, _, scope = build(c844, { Control = "Brake", Name = "Brake" })
		local art = component.Instance.Art
		expect(art.ImageTransparency, 0, "enabled")
		component.SetDisabled(true)
		if math.abs(art.ImageTransparency - (1 - Tokens.Opacity.TouchDisabled)) > 1e-4 then
			error("disabled transparency " .. art.ImageTransparency)
		end
		expect(component.Instance.Active, true, "the look only: Active is the fork's business")
		component.SetDisabled(false)
		expect(art.ImageTransparency, 0, "enabled again")
		component.Destroy()
		scope:destroy()
	end)

	case("Mirror: the right-hand control is the same image flipped", function()
		local plain, _, scopeA = build(c844, { Control = "Turn", Name = "TurnLeft" })
		local mirrored, _, scopeB = build(c844, { Control = "Turn", Name = "TurnRight", Mirror = true })
		expect(plain.Instance.Art.ImageRectSize, Vector2.zero, "plain uses the whole image")
		expect(mirrored.Instance.Art.ImageRectOffset, Vector2.new(512, 0), "mirror offset")
		expect(mirrored.Instance.Art.ImageRectSize, Vector2.new(-512, 512), "mirror size")
		expect(mirrored.Instance.Art.Image, plain.Instance.Art.Image, "same image")
		expect(mirrored.Instance.Size, plain.Instance.Size, "same hit box")
		plain.Destroy()
		mirrored.Destroy()
		scopeA:destroy()
		scopeB:destroy()
	end)

	case("Boost: charge ring of two half windows, written per whole percent", function()
		local component, _, scope = build(c844, { Control = "Boost", Name = "Boost" })
		local root = component.Instance
		local track = root:FindFirstChild("ChargeTrack")
		local right = root:FindFirstChild("ChargeRight")
		local left = root:FindFirstChild("ChargeLeft")
		expect(track ~= nil and right ~= nil and left ~= nil, true, "ring parts")
		expect(right.ClipsDescendants and left.ClipsDescendants, true, "windows clip")
		local rightMask = right.Fill:FindFirstChildOfClass("UIGradient")
		local leftMask = left.Fill:FindFirstChildOfClass("UIGradient")
		expect(rightMask ~= nil and leftMask ~= nil, true, "masks")
		expect(rightMask.Rotation, 0, "empty right")
		expect(leftMask.Rotation, 180, "empty left")

		local geometry = Touch._geometry("Boost", c844)
		local side = track.Size.X.Offset
		expect(side, math.floor(geometry.Frame.X * 1.02 + 0.5), "ring frame is 1.02 x the art frame")
		expect(left.Size.X.Offset + right.Size.X.Offset, side, "the two windows cover the ring")
		expect(right.Fill.Size, track.Size, "right fill is the whole ring")
		expect(right.Fill.Position.X.Offset, -left.Size.X.Offset, "right fill shifted back by the left half")
		expect(right.Position.X.Offset, left.Position.X.Offset + left.Size.X.Offset, "windows meet")
		if math.abs(track.ImageTransparency - (1 - Tokens.Opacity.RankTrackImage)) > 1e-4 then
			error("track transparency " .. track.ImageTransparency)
		end
		expect(track.Image, Tokens.Asset("RankArc") or "", "ring image")

		component.SetCharge(0.5)
		expect(rightMask.Rotation, 180, "half right")
		expect(leftMask.Rotation, 180, "half left")
		local before = snapshot(root)
		component.SetCharge(0.501)
		expect(snapshot(root), before, "same whole percent writes nothing")
		component.SetCharge(0.75)
		expect(leftMask.Rotation, 270, "three quarters left")
		component.SetCharge(5)
		expect(leftMask.Rotation, 360, "clamped full")
		component.Set({ Charge = 0.25 })
		expect(rightMask.Rotation, 90, "Set Charge")
		expect(leftMask.Rotation, 180, "Set Charge left")
		component.Destroy()
		scope:destroy()
	end)

	case("Other controls: SetCharge is a no-op and adds nothing", function()
		local component, _, scope = build(c844, { Control = "Drift", Name = "DriftLeft" })
		local before = snapshot(component.Instance)
		component.SetCharge(0.5)
		expect(snapshot(component.Instance), before, "nothing written")
		expect(#component.Instance:GetDescendants(), 1, "only Art")
		component.Destroy()
		scope:destroy()
	end)

	case("Visual only: no attribute is written on any instance", function()
		for _, control in CONTROLS do
			local component, _, scope = build(c844, { Control = control, Name = control })
			component.SetPressed(true)
			component.SetDisabled(true)
			component.SetCharge(0.4)
			local instances = component.Instance:GetDescendants()
			table.insert(instances, component.Instance)
			for _, instance in instances do
				expect(next(instance:GetAttributes()), nil, control .. " attributes on " .. instance.Name)
			end
			component.Destroy()
			scope:destroy()
		end
	end)

	case("Regular touch screens: sizes come from ctx.Dp, not ctx.Px", function()
		local sprite = Sprites.Touch.Accelerate
		local component, _, scope = build(r1080, { Control = "Accelerate", Name = "Accelerator" })
		expect(component.Instance.Size, UDim2.fromOffset(r1080.Dp(sprite.HitDp[1]), r1080.Dp(sprite.HitDp[2])), "hit box")
		expect(component.Instance.Art.Size, UDim2.fromOffset(r1080.Dp(sprite.FrameDp[1]), r1080.Dp(sprite.FrameDp[2])), "art")
		component.Destroy()
		scope:destroy()
	end)

	return results
end
