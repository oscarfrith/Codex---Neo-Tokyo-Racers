-- Pure tests for Kit.Collections (API.md 13, API2 2.9). Runs in Edit through the harness; nothing is parented into the game tree and nothing yields.
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
		"Text", "TextColor3", "TextTransparency", "TextSize", "Image", "ImageColor3", "ImageTransparency", "CanvasSize",
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

	local function vehicles()
		return {
			{ Key = "stinger", Title = "Stinger", Sub = "Exotic", Tier = "D", Rating = 316, Price = "$84,000", Icon = "car" },
			{ Key = "zephyr", Title = "Zephyr", Sub = "Exotic", Tier = "D", Rating = 390, Price = "$150,000", Icon = "car" },
			{ Key = "aurora", Title = "Aurora", Sub = "Exotic", Tier = "C", Rating = 540, Price = "$440,000", Icon = "car" },
			{ Key = "endura", Title = "Endura", Sub = "Exotic", Tier = "B", Rating = 675, Price = "$1.40M", Icon = "car", Status = "Locked" },
			{ Key = "rosso", Title = "Rosso", Sub = "Exotic", Tier = "A", Rating = 800, Price = "$4.40M", Icon = "car", Status = "Unaffordable" },
			{ Key = "seraph", Title = "Seraph", Sub = "Exotic", Tier = "S", Rating = 939, Status = "Owned", Icon = "car" },
		}
	end

	---------------------------------------------------------------------------------------------
	-- Pool keying (pure)
	---------------------------------------------------------------------------------------------

	case("planPool: first fill takes slots in order", function()
		local assign, order, count = M._planPool({}, 0, { "a", "b", "c" })
		expect(count == 3, "count " .. count)
		expect(assign.a == 1 and assign.b == 2 and assign.c == 3, "assignment")
		expect(order[1] == 1 and order[2] == 2 and order[3] == 3, "order")
	end)
	case("planPool: the same keys keep their slots and need no new slot", function()
		local first = M._planPool({}, 0, { "a", "b", "c" })
		local assign, order, count = M._planPool(first, 3, { "a", "b", "c" })
		expect(count == 3, "count " .. count)
		expect(assign.a == 1 and assign.b == 2 and assign.c == 3, "assignment moved")
		expect(#order == 3, "order length")
	end)
	case("planPool: a reorder keeps each key on its slot", function()
		local first = M._planPool({}, 0, { "a", "b", "c" })
		local assign, order, count = M._planPool(first, 3, { "c", "a", "b" })
		expect(count == 3, "count " .. count)
		expect(assign.a == 1 and assign.b == 2 and assign.c == 3, "assignment moved")
		expect(order[1] == 3 and order[2] == 1 and order[3] == 2, "order")
	end)
	case("planPool: a new key reuses a freed slot and never takes a kept one", function()
		local first = M._planPool({}, 0, { "a", "b", "c" })
		local assign, order, count = M._planPool(first, 3, { "d", "c", "a" })
		expect(count == 3, "pool grew to " .. count)
		expect(assign.a == 1 and assign.c == 3 and assign.d == 2 and assign.b == nil, "assignment")
		expect(order[1] == 2 and order[2] == 3 and order[3] == 1, "order")
	end)
	case("planPool: grows only by the shortfall, and a smaller set frees slots without shrinking the pool", function()
		local first = M._planPool({}, 0, { "a", "b" })
		local assign, _, count = M._planPool(first, 2, { "a", "b", "c", "d" })
		expect(count == 4 and assign.c == 3 and assign.d == 4, "growth")
		local fewer, order, kept = M._planPool(assign, 4, { "d" })
		expect(kept == 4, "pool shrank to " .. kept)
		expect(fewer.d == 4 and fewer.a == nil and order[1] == 4, "smaller set")
	end)
	case("planPool: a duplicate key errors and the previous map is not changed", function()
		local previous = { a = 1 }
		expect(not pcall(M._planPool, previous, 1, { "a", "b", "a" }), "duplicate accepted")
		expect(previous.a == 1 and previous.b == nil, "previous map mutated")
	end)

	---------------------------------------------------------------------------------------------
	-- State resolution (pure)
	---------------------------------------------------------------------------------------------

	case("resolveTile: Default is slate, white text, hairline base, active", function()
		local look = M._resolveTile("Default", "None", {})
		expect(look.Selected == false and look.Fill == "Slate" and look.FillOpacity == Tokens.Opacity.Panel, "fill")
		expect(look.Ink == "White" and look.Line == "White" and look.LineOpacity == Tokens.Opacity.HairBottom, "ink or line")
		expect(look.Glow == false and look.Grow == false and look.Active == true and look.Lock == false, "flags")
		expect(look.ChipFill == "White" and look.ChipFillOpacity == Tokens.Opacity.ChipNeutral, "chip")
	end)
	case("resolveTile: Selected is white fill, ink text, pink base line, glow and growth", function()
		local look = M._resolveTile("Selected", "None", {})
		expect(look.Selected == true and look.Fill == "White" and look.FillOpacity == 1 and look.Ink == "Ink", "fill or ink")
		expect(look.Line == "Pink" and look.LineOpacity == 1 and look.Glow == true and look.Grow == true, "line, glow or growth")
		expect(look.ChipFill == "Ink" and look.ChipInk == "White" and look.OnLight == true, "chips on white")
		expect(look.PriceInk == "Yellow", "price stays yellow")
	end)
	case("resolveTile: controller focus is the selected look", function()
		local focus = M._resolveTile("Default", "None", { Focused = true })
		local selected = M._resolveTile("Selected", "None", {})
		for key, value in pairs(selected) do
			expect(focus[key] == value, key .. " differs")
		end
	end)
	case("resolveTile: Locked is inactive at 0.6 with a lock, muted price and dimmed badge", function()
		local look = M._resolveTile("Default", "Locked", { Hover = true })
		expect(look.Active == false and look.Opacity == Tokens.Opacity.Locked and look.Lock == true, "locked")
		expect(look.PriceInk == "TextMuted" and look.BadgeDim == true, "price or badge")
		expect(look.LineOpacity == Tokens.Opacity.HairBottom, "hover changed a locked tile")
	end)
	-- API2 2.9: Unaffordable no longer sets Active = false (it can be selected and previewed).
	case("resolveTile: Unaffordable stays active with a muted price, a dimmed badge and no lock", function()
		local look = M._resolveTile("Default", "Unaffordable", {})
		expect(look.Active == true and look.PriceInk == "TextMuted" and look.Lock == false and look.Opacity == 1, "unaffordable")
		expect(look.BadgeDim == true, "badge")
		expect(M._resolveTile("Default", "Unaffordable", { Hover = true }).LineOpacity == Tokens.Opacity.HairTop, "hover")
		expect(M._resolveTile("Selected", "Unaffordable", {}).Fill == "White", "selected")
	end)
	case("resolveTile: Selectable false switches a tile off; Locked is active only when Selectable is true", function()
		expect(M._resolveTile("Default", "None", { Selectable = false }).Active == false, "Selectable false")
		expect(M._resolveTile("Default", "Owned", { Selectable = true }).Active == true, "Selectable true")
		expect(M._resolveTile("Default", "Locked", {}).Active == false, "Locked by default")
		expect(M._resolveTile("Default", "Locked", { Selectable = false }).Active == false, "Locked, Selectable false")
		local open = M._resolveTile("Default", "Locked", { Selectable = true })
		expect(open.Active == true and open.Lock == true and open.Opacity == Tokens.Opacity.Locked, "Locked, Selectable true")
		expect(M._resolveTile("Default", "Unaffordable", { Selectable = false }).Active == false, "Unaffordable, Selectable false")
	end)
	case("resolveTile: Owned and Fitted stay active; hover and press change the inner look only", function()
		local owned = M._resolveTile("Default", "Owned", {})
		local fitted = M._resolveTile("Default", "Fitted", {})
		local hover = M._resolveTile("Default", "None", { Hover = true })
		local pressed = M._resolveTile("Default", "None", { Hover = true, Pressed = true })
		expect(owned.Active == true and fitted.Active == true, "owned or fitted inactive")
		expect(hover.LineOpacity == Tokens.Opacity.HairTop and hover.Grow == false and hover.Fill == "Slate", "hover")
		expect(pressed.FillOpacity == 1 and pressed.Grow == false, "pressed")
	end)
	case("resolveTile: unknown State or Status errors", function()
		expect(not pcall(M._resolveTile, "Chosen", "None", {}), "State accepted")
		expect(not pcall(M._resolveTile, "Default", "Rented", {}), "Status accepted")
	end)
	case("corner: owned and fitted before price, price before free text", function()
		local text, kind = M._corner("Owned", "$6,000", nil)
		expect(text == "OWNED" and kind == "Neutral", "owned default text")
		text, kind = M._corner("Fitted", nil, "Fitted x2")
		expect(text == "Fitted x2" and kind == "Neutral", "fitted with its own text")
		text, kind = M._corner("None", "$6,000", "New")
		expect(text == "$6,000" and kind == "Price", "price")
		text, kind = M._corner("Unaffordable", "$4.40M", nil)
		expect(text == "$4.40M" and kind == "Price", "unaffordable price")
		text, kind = M._corner("None", "", "Empty")
		expect(text == "Empty" and kind == "Neutral", "free text")
		text, kind = M._corner("Locked", nil, nil)
		expect(text == nil and kind == nil, "nothing")
	end)
	case("resolveChip: every kind, and Muted", function()
		local fill, opacity, ink = M._resolveChip("Neutral", false)
		expect(fill == "White" and opacity == Tokens.Opacity.ChipNeutral and ink == "White", "neutral")
		fill, opacity, ink = M._resolveChip("Price", false)
		expect(fill == "Ink" and opacity == 1 and ink == "Yellow", "price")
		fill, opacity, ink = M._resolveChip("Price", true)
		expect(fill == "Ink" and ink == "TextMuted", "muted price")
		fill, opacity, ink = M._resolveChip("Cyan", false)
		expect(fill == "Cyan" and ink == "Ink", "cyan")
		fill, opacity, ink = M._resolveChip("Pink", false)
		expect(fill == "Pink" and ink == "White", "pink")
		fill, opacity, ink = M._resolveChip("Yellow", true)
		expect(fill == "Yellow" and ink == "Ink", "yellow ignores Muted")
		expect(not pcall(M._resolveChip, "Green", false), "unknown kind accepted")
	end)
	case("badgeSize: the three heights and their roles", function()
		local design, role = M._badgeSize("Large")
		expect(design == Tokens.Space.BadgeLarge and role == "Status", "large")
		design, role = M._badgeSize("Medium")
		expect(design == Tokens.Space.BadgeMedium and role == "Tab", "medium")
		design, role = M._badgeSize("Small")
		expect(design == Tokens.Space.BadgeSmall and role == "Value", "small")
		expect(not pcall(M._badgeSize, "Huge"), "unknown size accepted")
	end)

	---------------------------------------------------------------------------------------------
	-- Constructors
	---------------------------------------------------------------------------------------------

	local tiles = {
		{ "Tile Default", { Title = "Aurora", Sub = "Exotic", Tier = "C", Rating = 540, Price = "$440,000", Icon = "car", OnActivated = nothing } },
		{ "Tile Selected", { Title = "Zephyr", Sub = "Exotic", Tier = "D", Rating = 390, Price = "$150,000", Icon = "car", State = "Selected" } },
		{ "Tile Fitted", { Title = "Spine wing", Sub = "Spine", ChipLeft = "Std", Status = "Fitted", Icon = "upgrade" } },
		{ "Tile Locked full", { Title = "Seraph", Sub = "Tier C only", Tier = "S", Rating = 939, ChipLeft = "GT", Price = "$9.80M", Status = "Locked", Icon = "car" } },
		{ "Tile Unaffordable", { Title = "Rosso", Sub = "Exotic", Tier = "A", Rating = 800, Price = "$4.40M", Status = "Unaffordable" } },
		{ "Tile NoImage", { Title = "Endura", Image = "" } },
		{ "Tile Seven", { Title = "Drift thrusters", Sub = "Standard", ChipLeft = "05", Status = "Fitted", Compact7 = true, State = "Selected" } },
	}
	for _, entry in ipairs(tiles) do
		for _, preset in ipairs({ "R1080", "C844" }) do
			contract(entry[1], preset, M.Tile, entry[2], 13) -- API2 2.9 (was 12)
		end
	end

	local rows = {
		{ "ListRow Default", { Title = "Shifted canal sprint", Sub = "Circuit", OnActivated = nothing } },
		{ "ListRow Selected", { Title = "Seraph", Sub = "Exotic", Tier = "S", Right = "Parked", State = "Selected" } },
		{ "ListRow Locked full", { Title = "Showroom loop", Sub = "Unavailable", Tier = "A", Right = "$25,000", Image = "", Locked = true } },
	}
	for _, entry in ipairs(rows) do
		for _, preset in ipairs({ "R1080", "C844" }) do
			contract(entry[1], preset, M.ListRow, entry[2], 12) -- API2 2.9 (was 10)
		end
	end

	for _, preset in ipairs({ "R1080", "R720", "C844" }) do
		contract("Chip Price", preset, M.Chip, { Text = "$84,000", Kind = "Price", Muted = true }, 2)
		contract("Chip Neutral", preset, M.Chip, { Text = "Owned x2", Kind = "Neutral" }, 2)
		contract("TierBadge rating", preset, M.TierBadge, { Tier = "C", Rating = 540, OnLight = true }, 4)
		contract("TierBadge letter", preset, M.TierBadge, { Tier = "S", Size = "Small", Dim = true }, 4)
		contract("Rail", preset, M.Rail, { Heading = "Exotic", Count = "2/6", OnSelected = nothing }, nil)
		contract("Rail SelectOn Activate", preset, M.Rail, { Heading = "Exotic", Count = "2/6", SelectOn = "Activate", OnSelected = nothing }, nil)
	end

	case("Tile: the root is a selectable TextButton with Fill and Visual; the hit box is fixed", function()
		for _, preset in ipairs({ "R1080", "C844" }) do
			local parent, ctx = stage(preset)
			local scope = newScope()
			local tile = M.Tile(parent, { Title = "Aurora", Sub = "Exotic", Tier = "C", Rating = 540, Price = "$440,000" }, scope)
			local root = tile.Instance
			expect(root:IsA("TextButton") and root.Selectable == true, preset .. ": not a selectable TextButton")
			expect(root:FindFirstChild("Fill") ~= nil and root.Fill:FindFirstChild("Visual") ~= nil, preset .. ": Fill or Visual missing")
			local size = root.Size
			local fillHeight = root.Fill.Size.Y.Offset
			local visual = root.Fill.Visual.Size
			if ctx.Class == "Regular" then
				expect(size.X.Offset == ctx.Px(Tokens.Space.TileWidth) and size.Y.Offset == ctx.Px(Tokens.Space.TileHeight), preset .. ": cell size")
			else
				expect(size.X.Offset >= ctx.Px(Tokens.Space.CompactTileMinWidth) and size.Y.Offset >= ctx.Touch(1), preset .. ": under the touch size")
			end
			local count = #root:GetDescendants()
			tile.Set({ State = "Selected" })
			expect(root.Size == size, preset .. ": selection changed the hit box")
			expect(root.Fill.Size.Y.Offset > fillHeight, preset .. ": the fill did not grow")
			if ctx.Class == "Regular" then -- the Compact icon is a top-row part and keeps its size (A7)
				expect(root.Fill.Visual.Size.Y.Offset > visual.Y.Offset, preset .. ": the visual did not grow")
			end
			expect(#root:GetDescendants() == count, preset .. ": selection created or destroyed instances")
			tile.Set({ State = "Default" })
			expect(root.Fill.Size.Y.Offset == fillHeight and root.Fill.Visual.Size == visual, preset .. ": deselect did not restore")
			tile.Destroy()
			scope:destroy()
		end
	end)
	-- API2 2.9: an Unaffordable tile is active; its price is muted.
	case("Tile: Locked sets Active false and stays visible; Unaffordable and Owned stay active; Selectable", function()
		local parent = stage("R1080")
		local scope = newScope()
		local tile = M.Tile(parent, { Title = "Rosso", Price = "$4.40M", Status = "Unaffordable" }, scope)
		expect(tile.Instance.Active == true and tile.Instance.Visible == true, "unaffordable")
		expect(tile.Instance.Fill.Corner.TextColor3 == Tokens.Colour.TextMuted, "unaffordable price is not muted")
		tile.Set({ Status = "Locked" })
		expect(tile.Instance.Active == false and tile.Instance.Visible == true, "locked")
		tile.Set({ Selectable = true })
		expect(tile.Instance.Active == true, "locked with Selectable = true")
		tile.Set({ Selectable = false, Status = "Owned" })
		expect(tile.Instance.Active == false and tile.Instance.Visible == true, "Selectable = false")
		tile.Set({ Status = "Locked" })
		expect(tile.Instance.Active == false, "locked with Selectable = false")
		tile.Set({ Selectable = true })
		tile.Set({ Status = "Owned" })
		expect(tile.Instance.Active == true, "owned")
		tile.Set({ Status = "None" })
		expect(tile.Instance.Active == true, "none")
		tile.Destroy()
		scope:destroy()
	end)
	case("Tile: an unknown icon errors; an empty Image is the no-image state", function()
		local parent = stage("R1080")
		local scope = newScope()
		expect(not pcall(M.Tile, parent, { Title = "X", Icon = "not_an_icon" }, scope), "unknown icon accepted")
		for _, child in ipairs(parent:GetChildren()) do
			child:Destroy()
		end
		local tile = M.Tile(parent, { Title = "Endura", Image = "" }, scope)
		expect(tile.Instance.Fill.Visual.Image == "", "image not empty")
		tile.Destroy()
		scope:destroy()
	end)
	-- Capture module_shop_v2: a two-line name raised the sub-line into the picture box.
	case("Tile: with a two-line name the picture and the lock end above the sub-line; one line is unchanged", function()
		local parent = stage("R1080")
		local scope = newScope()
		local function bottom(gui)
			return gui.Position.Y.Offset + gui.Size.Y.Offset
		end
		local short = M.Tile(parent, { Title = "Wing", Sub = "Owned x1", Icon = "upgrade" }, scope)
		local oneLine = short.Instance.Fill.Visual.Size
		for _, picture in ipairs({ { Icon = "upgrade" }, { Image = "rbxassetid://1" } }) do
			local props = { Title = "Teardrop fenders extended wide body", Sub = "Buy Exotic Zephyr to unlock", Status = "Locked" }
			props.Icon, props.Image = picture.Icon, picture.Image
			local tile = M.Tile(parent, props, scope)
			local fill = tile.Instance.Fill
			for _, state in ipairs({ "Default", "Selected" }) do
				tile.Set({ State = state })
				local title = fill.Title
				if title.TextBounds.Y > title.TextSize * 1.5 then -- the name did wrap on this stage
					local subTop = fill.Sub.Position.Y.Offset
					expect(bottom(fill.Visual) <= subTop, state .. ": picture over the sub-line")
					expect(bottom(fill.Lock) <= subTop, state .. ": lock over the sub-line")
				end
			end
			tile.Destroy()
		end
		expect(short.Instance.Fill.Visual.Size == oneLine, "a one-line tile changed")
		short.Destroy()
		scope:destroy()
	end)
	case("ListRow: selectable GuiButton; Locked sets Active false; selection creates nothing", function()
		local parent = stage("R1080")
		local scope = newScope()
		local row = M.ListRow(parent, { Title = "Showroom loop", Sub = "Circuit", Right = "$25,000" }, scope)
		local root = row.Instance
		expect(root:IsA("GuiButton") and root.Selectable == true and root.Active == true, "not an active selectable GuiButton")
		local size = root.Size
		local count = #root:GetDescendants()
		row.Set({ State = "Selected" })
		row.Set({ State = "Default" })
		expect(root.Size == size and #root:GetDescendants() == count, "selection changed the hit box or the instance count")
		row.Set({ Locked = true })
		expect(root.Active == false and root.Visible == true, "locked")
		row.Destroy()
		scope:destroy()
	end)
	case("TierBadge: letter cell in the tier colour; rating cell follows OnLight", function()
		local parent = stage("R1080")
		local scope = newScope()
		local badge = M.TierBadge(parent, { Tier = "B", Rating = 675 }, scope)
		local root = badge.Instance
		expect(root.Letter.BackgroundColor3 == Tokens.Tier.B and root.Letter.TextColor3 == Tokens.Colour.Ink, "letter cell")
		expect(root.Letter.Text == "B" and root.Rating.Text == "675", "texts")
		expect(root.Rating.BackgroundColor3 == Tokens.Colour.White and root.Rating.TextColor3 == Tokens.Colour.Ink, "rating cell")
		badge.Set({ OnLight = true })
		expect(root.Rating.BackgroundColor3 == Tokens.Colour.Ink and root.Rating.TextColor3 == Tokens.Colour.White, "rating cell on light")
		expect(root.Letter.BackgroundColor3 == Tokens.Tier.B, "letter cell changed on light")
		expect(not pcall(badge.Set, { Tier = "Z" }), "unknown tier accepted")
		badge.Destroy()
		scope:destroy()
	end)
	case("Chip: Price is ink with yellow text, muted when Muted", function()
		local parent = stage("R1080")
		local scope = newScope()
		local chip = M.Chip(parent, { Text = "$6,000", Kind = "Price" }, scope)
		local root = chip.Instance
		expect(root.BackgroundColor3 == Tokens.Colour.Ink and root.Label.TextColor3 == Tokens.Colour.Yellow, "price")
		chip.Set({ Muted = true })
		expect(root.Label.TextColor3 == Tokens.Colour.TextMuted, "muted")
		chip.Destroy()
		scope:destroy()
	end)

	---------------------------------------------------------------------------------------------
	-- Rail: keyed pool
	---------------------------------------------------------------------------------------------

	local function rail(preset)
		local parent = stage(preset)
		local scope = newScope()
		local selections = {}
		local component = M.Rail(parent, {
			Heading = "Exotic",
			Count = "2/6",
			OnSelected = function(key)
				table.insert(selections, key)
			end,
		}, scope)
		return component, scope, selections
	end

	case("Rail: children Heading and Scroller; Tile(key) returns the pooled tile", function()
		local component, scope = rail("R1080")
		expect(component.Instance:FindFirstChild("Heading") ~= nil, "Heading missing")
		expect(component.Instance:FindFirstChild("Scroller") ~= nil and component.Instance.Scroller:IsA("ScrollingFrame"), "Scroller missing")
		component.SetItems(vehicles())
		local tile = component.Tile("aurora")
		expect(tile ~= nil and tile.Instance:IsA("TextButton") and tile.Instance.Visible == true, "Tile(key)")
		expect(component.Tile("nope") == nil, "unknown key returned a tile")
		component.Destroy()
		scope:destroy()
	end)
	for _, preset in ipairs({ "R1080", "C844" }) do
		case("Rail " .. preset .. ": SetItems twice with the same keys creates nothing and writes nothing", function()
			local component, scope = rail(preset)
			component.SetItems(vehicles())
			local before, count = snapshot(component.Instance)
			component.SetItems(vehicles())
			local same, detail = sameSnapshot(before, count, component.Instance)
			component.Destroy()
			scope:destroy()
			expect(same, detail)
		end)
		case("Rail " .. preset .. ": a selection change creates and destroys nothing", function()
			local component, scope = rail(preset)
			component.SetItems(vehicles())
			component.Select("stinger")
			local count = #component.Instance:GetDescendants()
			component.Select("zephyr")
			component.Select("seraph")
			component.Select("stinger")
			local after = #component.Instance:GetDescendants()
			component.Destroy()
			scope:destroy()
			expect(after == count, "instances " .. count .. " -> " .. after)
		end)
	end
	case("Rail: a key keeps its tile through a reorder; data changes reuse the pool", function()
		local component, scope = rail("R1080")
		component.SetItems(vehicles())
		local aurora = component.Tile("aurora")
		local seraph = component.Tile("seraph")
		local list = vehicles()
		list[1], list[6] = list[6], list[1]
		list[3].Price = "$399,000"
		local count = #component.Instance:GetDescendants()
		component.SetItems(list)
		expect(component.Tile("aurora") == aurora and component.Tile("seraph") == seraph, "a key moved to another tile")
		expect(#component.Instance:GetDescendants() == count, "a reorder or a price change created or destroyed instances")
		expect(seraph.Instance.Position.X.Offset < aurora.Instance.Position.X.Offset, "the reorder was not laid out")
		component.Destroy()
		scope:destroy()
	end)
	case("Rail: a smaller set hides tiles and keeps them parented; the same slots come back", function()
		local component, scope = rail("R1080")
		component.SetItems(vehicles())
		local scroller = component.Instance.Scroller
		local children = #scroller:GetChildren()
		local rosso = component.Tile("rosso").Instance
		component.SetItems({ vehicles()[1], vehicles()[2] })
		expect(#scroller:GetChildren() == children, "the pool was not kept parented")
		expect(rosso.Parent == scroller and rosso.Visible == false, "a freed tile was not hidden in place")
		expect(component.Tile("rosso") == nil, "a removed key still has a tile")
		local descendants = #component.Instance:GetDescendants()
		component.SetItems(vehicles())
		expect(#scroller:GetChildren() == children, "the pool grew although free tiles existed")
		expect(#component.Instance:GetDescendants() == descendants, "refilling the pool created instances")
		expect(component.Tile("rosso") ~= nil and component.Tile("rosso").Instance.Visible == true, "the key did not come back")
		component.Destroy()
		scope:destroy()
	end)
	case("Rail: Select sets one tile selected, does not call OnSelected, and survives SetItems", function()
		local component, scope, selections = rail("R1080")
		component.SetItems(vehicles())
		component.Select("zephyr")
		local zephyr = component.Tile("zephyr").Instance
		local aurora = component.Tile("aurora").Instance
		local grown = zephyr.Fill.Size.Y.Offset
		expect(grown > aurora.Fill.Size.Y.Offset, "the selected tile did not grow")
		expect(zephyr.Size == aurora.Size, "the selected hit box differs")
		component.Select("aurora")
		expect(aurora.Fill.Size.Y.Offset == grown and zephyr.Fill.Size.Y.Offset < grown, "the selection did not move")
		expect(#selections == 0, "OnSelected fired for a programmatic Select")
		component.SetItems(vehicles())
		expect(aurora.Fill.Size.Y.Offset == grown, "the selection was lost on SetItems")
		expect(not pcall(component.Select, "nope"), "unknown key accepted")
		component.Destroy()
		scope:destroy()
	end)
	case("Rail: SelectOn decides whether a focus move selects; an activation always does; the default is Focus", function()
		expect(M._railSelects(nil, "Focus") == true and M._railSelects("Focus", "Focus") == true, "the default rail selects on focus")
		expect(M._railSelects("Activate", "Focus") == false, "SelectOn Activate: focus only highlights")
		for _, mode in ipairs({ "Focus", "Activate" }) do
			expect(M._railSelects(mode, "Activate") == true, mode .. ": an activation selects")
		end
		expect(M._railSelects(nil, "Activate") == true, "default: an activation selects")
	end)
	case("Rail: SelectOn takes Focus or Activate only, in props and in Set; Select still works without a callback", function()
		local parent = stage("R1080")
		local scope = newScope()
		expect(not pcall(M.Rail, parent, { Heading = "Exotic", SelectOn = "Hover" }, scope), "unknown SelectOn accepted")
		local selections = {}
		local component = M.Rail(parent, {
			Heading = "Exotic",
			SelectOn = "Activate",
			OnSelected = function(key)
				table.insert(selections, key)
			end,
		}, scope)
		component.SetItems(vehicles())
		expect(not pcall(component.Set, { SelectOn = true }), "unknown SelectOn accepted by Set")
		component.Set({ SelectOn = "Focus" })
		component.Set({ SelectOn = "Activate" })
		component.Select("zephyr")
		expect(#selections == 0, "OnSelected fired for a programmatic Select")
		expect(component.Tile("zephyr").Instance.Fill.Size.Y.Offset > component.Tile("aurora").Instance.Fill.Size.Y.Offset, "Select did not select")
		component.Destroy()
		scope:destroy()
	end)
	case("Rail and List take OnActivated in props and in Set, and a programmatic Select does not call it", function()
		local parent = stage("R1080")
		local scope = newScope()
		local calls = 0
		local function count()
			calls += 1
		end
		local rail = M.Rail(parent, { Heading = "Exotic", OnSelected = count, OnActivated = count }, scope)
		rail.SetItems(vehicles())
		rail.Select("zephyr")
		rail.Set({ OnActivated = count })
		local list = M.List(parent, { OnSelected = count, OnActivated = count }, scope)
		list.Set({ OnActivated = count })
		expect(calls == 0, "a callback fired without an activation")
		expect(not pcall(M.Rail, parent, { Heading = "Exotic", OnActivate = count }, scope), "a misspelt key was accepted")
		rail.Destroy()
		list.Destroy()
		scope:destroy()
	end)
	case("Rail: duplicate or missing keys error; Destroy leaves nothing behind", function()
		local parent = stage("R1080")
		local scope = newScope()
		local component = M.Rail(parent, { Heading = "Exotic" }, scope)
		expect(not pcall(component.SetItems, { { Key = "a", Title = "A" }, { Key = "a", Title = "B" } }), "duplicate key accepted")
		expect(not pcall(component.SetItems, { { Title = "No key" } }), "missing key accepted")
		component.SetItems(vehicles())
		component.Destroy()
		component.Destroy()
		component.SetItems(vehicles())
		expect(#parent:GetChildren() == 0, "children left under the parent")
		scope:destroy()
	end)

	---------------------------------------------------------------------------------------------
	-- API2 2.9
	---------------------------------------------------------------------------------------------

	local function about(a, b)
		return math.abs(a - b) < 1e-4
	end

	case("corner: ChipRightKind colours the free-text chip; Tick wins over everything", function()
		local text, kind = M._corner("None", nil, "Empty", "Pink")
		expect(text == "Empty" and kind == "Pink", "pink chip")
		text, kind = M._corner("Fitted", nil, nil, "Cyan")
		expect(text == "FITTED" and kind == "Cyan", "cyan status chip")
		text, kind = M._corner("None", "$6,000", "New", "Pink")
		expect(text == "$6,000" and kind == "Price", "a price is still a price")
		text, kind = M._corner("Owned", "$6,000", nil, "Tick")
		expect(text ~= nil and kind == "Tick", "tick")
		text, kind = M._corner("None", nil, nil, "Neutral")
		expect(text == nil and kind == nil, "nothing")
		expect(not pcall(M._corner, "None", nil, "X", "Green"), "unknown kind accepted")
	end)
	case("Tile: slate plate with a HairBottom hairline; Selected is the Pink to Violet base line", function()
		for _, preset in ipairs({ "R1080", "C844" }) do
			local parent, ctx = stage(preset)
			local scope = newScope()
			local tile = M.Tile(parent, { Title = "Aurora", Sub = "Exotic", Tier = "C", Rating = 540, Price = "$440,000", Icon = "car" }, scope)
			local fill = tile.Instance.Fill
			local line = fill:FindFirstChild("HairBottom")
			expect(line ~= nil and line:IsA("Frame"), preset .. ": HairBottom missing")
			local gradient = line:FindFirstChildOfClass("UIGradient")
			expect(gradient ~= nil and gradient.Enabled == false, preset .. ": the gradient is on in the default state")
			expect(fill.BackgroundColor3 == Tokens.Colour.Slate and about(fill.BackgroundTransparency, 1 - Tokens.Opacity.Panel), preset .. ": plate")
			expect(line.Visible == true and line.BackgroundColor3 == Tokens.Colour.White, preset .. ": hairline colour")
			expect(about(line.BackgroundTransparency, 1 - Tokens.Opacity.HairBottom), preset .. ": hairline opacity")
			expect(line.Size.X.Offset == fill.Size.X.Offset and line.Position.Y.Offset + line.Size.Y.Offset == fill.Size.Y.Offset, preset .. ": hairline box")
			local thin = line.Size.Y.Offset
			tile.Set({ State = "Selected" })
			expect(gradient.Enabled == true and line.BackgroundTransparency == 0, preset .. ": selected base line")
			expect(line.Size.Y.Offset >= thin and line.Position.Y.Offset + line.Size.Y.Offset == fill.Size.Y.Offset, preset .. ": base line box")
			if ctx.Class == "Compact" then
				-- A7: a Compact tile never takes the White fill.
				expect(fill.BackgroundColor3 == Tokens.Colour.Slate and fill.BackgroundTransparency == 0, preset .. ": selected fill")
				expect(fill.Title.TextColor3 == Tokens.Colour.White, preset .. ": selected name is not light")
				expect(tile.Instance.Size.Y.Offset == ctx.Px(Tokens.Space.CompactTileHeight), preset .. ": compact tile height")
			else
				expect(fill.BackgroundColor3 == Tokens.Colour.White and fill.BackgroundTransparency == 0, preset .. ": selected fill")
			end
			tile.Destroy()
			scope:destroy()
		end
	end)
	-- A7 (mobile pass): the phone tile.
	case("compactTile: never a White fill; a picture gives the full-frame look", function()
		local selected = M._compactTile(M._resolveTile("Selected", "None", {}), {}, false)
		expect(selected.Fill == "Slate" and selected.FillOpacity == 1 and selected.Ink == "White", "selected fill or ink")
		expect(selected.OnLight == false and selected.ChipFill == "White" and selected.ChipInk == "White", "selected chips")
		expect(selected.Glow == true and selected.Grow == true and selected.Line == "Pink" and selected.LineOpacity == 1, "selected marks lost")
		local plain = M._compactTile(M._resolveTile("Default", "None", {}), {}, false)
		expect(plain.Fill == "Slate" and plain.FillOpacity == Tokens.Opacity.Panel and plain.Ink == "White", "default look changed")
		local picture = M._compactTile(M._resolveTile("Selected", "None", {}), {}, true)
		expect(picture.Fill == "Slate" and picture.Dim == 0 and picture.ChipFill == "Ink", "picture look")
		local locked = M._compactTile(M._resolveTile("Default", "Locked", {}), {}, false)
		expect(locked.Lock == true and locked.Active == false and locked.Opacity == Tokens.Opacity.Locked, "locked look changed")
	end)
	case("compactTop: the chip stays; the rating goes first, then the icon, then the tier letter", function()
		local function row(...)
			local tier, rating, icon = M._compactTop(...)
			return (tier and "T" or "") .. (rating and "R" or "") .. (icon and "I" or "")
		end
		expect(row(110, 48, 20, 32, 0, 4) == "TR", "badge and chip fit: " .. row(110, 48, 20, 32, 0, 4))
		expect(row(110, 48, 20, 32, 16, 4) == "TI", "the rating goes before the icon")
		expect(row(110, 83, 20, 32, 16, 4) == "T", "then the icon")
		expect(row(110, 100, 20, 32, 16, 4) == "", "then the letter")
		expect(row(110, 0, 20, 32, 16, 4) == "TRI", "no chip: everything")
		expect(row(110, 48, 0, 32, 16, 4) == "I", "a rating without a tier is never shown")
		expect(row(110, 0, 0, 0, 0, 4) == "", "nothing to show")
	end)
	case("Tile C844: one width for every name; the top row never overlaps; the name is clipped to two lines", function()
		local parent, ctx = stage("C844")
		local scope = newScope()
		local short = M.Tile(parent, { Title = "Rosso", Tier = "A", Rating = 800, Status = "Owned" }, scope)
		local long = M.Tile(parent, { Title = "Meridian grand tourer evoluzione GT", Tier = "S", Rating = 936, Price = "$12,000,000", Icon = "car", State = "Selected" }, scope)
		expect(short.Instance.Size == long.Instance.Size, "the name changed the tile's size")
		expect(short.Instance.Size.X.Offset >= ctx.Px(Tokens.Space.CompactTileMinWidth), "under the minimum width")
		for _, tile in ipairs({ short, long }) do
			local fill = tile.Instance.Fill
			local width = fill.Size.X.Offset
			local corner = fill.Corner
			expect(corner.Visible == true and corner.Position.X.Offset + corner.Size.X.Offset == width, "the chip is not in the corner")
			local reach = 0
			for _, name in ipairs({ "TierLetter", "TierRating", "Visual" }) do
				local part = fill:FindFirstChild(name)
				if part ~= nil and part.Visible then
					reach = math.max(reach, part.Position.X.Offset + part.Size.X.Offset)
				end
			end
			expect(reach <= corner.Position.X.Offset, "a top-row part reaches under the chip")
			local title = fill.Title
			expect(title.TextTruncate == Enum.TextTruncate.AtEnd and title.TextWrapped == true, "the name is not clipped")
			expect(title.Position.X.Offset >= 0 and title.Position.X.Offset + title.Size.X.Offset <= width, "the name box leaves the tile")
			expect(title.Position.Y.Offset >= corner.Position.Y.Offset + corner.Size.Y.Offset, "the name box reaches the top row")
			expect(fill:FindFirstChild("Sub") == nil and fill:FindFirstChild("ChipLeft") == nil, "a Compact tile has no sub-line or left chip")
		end
		local locked = M.Tile(parent, { Title = "Seraph", Status = "Locked", Price = "$9.80M" }, scope)
		expect(locked.Instance.Fill.Visual.Visible == true and locked.Instance.Fill:FindFirstChild("Lock") == nil, "the lock is the top-row icon")
		for _, child in ipairs(parent:GetChildren()) do
			child:Destroy()
		end
		scope:destroy()
	end)
	case("Tile: the glow is a sibling under Fill on the grown plate, shown only when selected", function()
		local parent = stage("R1080")
		local scope = newScope()
		local tile = M.Tile(parent, { Title = "Zephyr", Tier = "D", Rating = 390 }, scope)
		local root = tile.Instance
		local glow = root:FindFirstChild("Glow")
		expect(glow ~= nil and glow.Parent == root and glow.ZIndex < root.Fill.ZIndex, "Glow is not a sibling under Fill")
		expect(root.Fill:FindFirstChild("Glow") == nil, "a glow inside the plate would draw over it")
		expect(glow.Visible == false, "glow shown on a default tile")
		tile.Set({ State = "Selected" })
		expect(glow.Visible == true, "glow hidden on a selected tile")
		expect(glow.Position == root.Fill.Position and glow.Size == root.Fill.Size, "the glow is not on the plate's box")
		tile.Destroy()
		scope:destroy()
	end)
	case("Tile: ChipRightKind Pink, Cyan and Tick; a tile with every part stays within 13", function()
		local parent = stage("R1080")
		local scope = newScope()
		local tile = M.Tile(parent, { Title = "Wing", Sub = "Nothing fitted", ChipLeft = "07", ChipRight = "Empty", ChipRightKind = "Pink" }, scope)
		local fill = tile.Instance.Fill
		expect(fill.Corner.Text == "EMPTY" and fill.Corner.BackgroundColor3 == Tokens.Colour.Pink, "pink chip")
		expect(fill.Corner.TextColor3 == Tokens.Colour.White and fill.Corner.BackgroundTransparency == 0, "pink chip ink")
		tile.Set({ ChipRightKind = "Cyan" })
		expect(fill.Corner.BackgroundColor3 == Tokens.Colour.Cyan and fill.Corner.TextColor3 == Tokens.Colour.Ink, "cyan chip")
		tile.Set({ ChipRightKind = "Tick" })
		local tick = fill:FindFirstChild("Tick")
		expect(tick ~= nil and tick:IsA("ImageLabel") and tick.Visible == true, "tick missing")
		expect(tick.BackgroundColor3 == Tokens.Colour.Cyan and tick.BackgroundTransparency == 0, "tick cell")
		expect(tick.ImageColor3 == Tokens.Colour.Ink, "tick ink")
		expect(tick.Position.X.Offset + tick.Size.X.Offset == fill.Size.X.Offset and tick.Position.Y.Offset == 0, "tick is not in the corner")
		expect(fill.Corner.Visible == false, "the text chip shows under the tick")
		tile.Set({ Tier = "S", Rating = 939, Status = "Locked", Icon = "car" })
		local count = budget(tile.Instance)
		expect(count <= 13, "budget 13, found " .. count)
		tile.Set({ ChipRightKind = "Neutral" })
		expect(tick.Visible == false and fill.Corner.Visible == true, "back to the text chip")
		expect(not pcall(M.Tile, parent, { Title = "X", ChipRight = "Y", ChipRightKind = "Green" }, scope), "unknown ChipRightKind accepted")
		for _, child in ipairs(parent:GetChildren()) do
			child:Destroy()
		end
		scope:destroy()
	end)
	case("TierBadge: Dim lowers the whole badge to Opacity.Locked; one height on Compact", function()
		local parent = stage("R1080")
		local scope = newScope()
		local badge = M.TierBadge(parent, { Tier = "A", Rating = 800, Dim = true }, scope)
		local dim = 1 - Tokens.Opacity.Locked
		expect(badge.Instance.Letter.BackgroundColor3 == Tokens.Tier.A, "tier colour")
		expect(about(badge.Instance.Letter.BackgroundTransparency, dim) and about(badge.Instance.Letter.TextTransparency, dim), "letter cell")
		expect(about(badge.Instance.Rating.BackgroundTransparency, dim) and about(badge.Instance.Rating.TextTransparency, dim), "rating cell")
		badge.Destroy()
		local compactParent, ctx = stage("C844")
		local base = ctx.Px(Tokens.Space.CompactStatusHeight - Tokens.Space.Hairline - Tokens.Space.Hairline)
		for _, size in ipairs({ "Large", "Medium", "Small" }) do
			local compact = M.TierBadge(compactParent, { Tier = "C", Size = size }, scope)
			local height = compact.Instance.Size.Y.Offset
			expect(height == math.max(base, compact.Instance.Letter.TextSize), size .. ": compact height " .. height)
			compact.Destroy()
		end
		scope:destroy()
	end)
	case("columnBox: a narrow first column, equal shares for the rest, the last right aligned", function()
		local x, width, right = M._columnBox(1, 3, 22, 10, 46)
		expect(x == UDim.new(0, 22) and width == UDim.new(0, 46) and right == false, "first of three")
		x, width, right = M._columnBox(2, 3, 22, 10, 46)
		expect(x == UDim.new(0, 78) and width == UDim.new(0.5, -60) and right == false, "second of three")
		x, width, right = M._columnBox(3, 3, 22, 10, 46)
		expect(x == UDim.new(0.5, 28) and width == UDim.new(0.5, -50) and right == true, "third of three")
		x, width, right = M._columnBox(1, 1, 22, 10, 46)
		expect(x == UDim.new(0, 22) and width == UDim.new(1, -44) and right == false, "one column")
		x, width, right = M._columnBox(2, 2, 22, 10, 46)
		expect(x == UDim.new(0.5, 0) and width == UDim.new(0.5, -22) and right == true, "second of two")
	end)

	local columnRow = { Columns = { "1", "Neonrider", "Seraph", "-1.8" }, Height = 56, Accent = true, State = "Selected" }
	local chipRow = { Title = "Seraph", Sub = "Exotic", Tier = "S", Image = "rbxassetid://1", Right = "Parked", Chip = "Spawned", Locked = true, Accent = true }
	for _, preset in ipairs({ "R1080", "C844" }) do
		contract("ListRow Columns", preset, M.ListRow, columnRow, 12)
		contract("ListRow every part", preset, M.ListRow, chipRow, 12)
	end

	case("ListRow: hairline plate, glow as a sibling, Chip, ChipKind, Accent and Height", function()
		local parent, ctx = stage("R1080")
		local scope = newScope()
		local row = M.ListRow(parent, { Title = "Seraph", Sub = "Exotic", Chip = "Spawned", Height = 120 }, scope)
		local root = row.Instance
		local fill = root.Fill
		local line = fill:FindFirstChild("HairBottom")
		expect(line ~= nil and line:FindFirstChildOfClass("UIGradient") ~= nil, "HairBottom or its gradient missing")
		expect(about(line.BackgroundTransparency, 1 - Tokens.Opacity.HairBottom), "hairline opacity")
		expect(root.Size.Y.Offset == ctx.Px(120), "Height")
		expect(root:FindFirstChild("Glow") ~= nil and root.Glow.Visible == false and fill:FindFirstChild("Glow") == nil, "glow placement")
		expect(fill.Chip.Text == "SPAWNED" and fill.Chip.BackgroundColor3 == Tokens.Colour.White, "neutral chip")
		expect(fill:FindFirstChild("Accent") == nil, "an accent bar without Accent")
		local count = #root:GetDescendants()
		row.Set({ State = "Selected" })
		expect(root.Glow.Visible == true and line:FindFirstChildOfClass("UIGradient").Enabled == true, "selected")
		expect(fill.Chip.BackgroundColor3 == Tokens.Colour.Ink and fill.Chip.TextColor3 == Tokens.Colour.White, "chip on white")
		expect(#root:GetDescendants() == count, "selection created or destroyed instances")
		row.Set({ ChipKind = "Cyan" })
		expect(fill.Chip.BackgroundColor3 == Tokens.Colour.Cyan and fill.Chip.TextColor3 == Tokens.Colour.Ink, "cyan chip")
		row.Set({ Accent = true })
		expect(fill.Accent.Visible == true and fill.Accent.BackgroundColor3 == Tokens.Colour.Pink, "accent bar")
		expect(fill.Accent.Size.Y.Scale == 1 and fill.Accent.Size.X.Offset == ctx.Hair(Tokens.Space.TileBaseLine), "accent box")
		row.Set({ Accent = false, Chip = "" })
		expect(fill.Accent.Visible == false and fill.Chip.Visible == false, "accent or chip not hidden")
		expect(not pcall(row.Set, { ChipKind = "Green", Chip = "X" }), "unknown ChipKind accepted")
		row.Destroy()
		scope:destroy()
	end)
	case("ListRow: Columns replace the title, sub-line and right text, and go back", function()
		local parent = stage("R1080")
		local scope = newScope()
		local row = M.ListRow(parent, { Columns = { "1", "Neonrider", "Seraph", "-1.8" } }, scope)
		local fill = row.Instance.Fill
		expect(fill.Title.Text == "1" and fill.Column2.Text == "NEONRIDER" and fill.Column3.Text == "SERAPH", "column texts")
		expect(fill.Right.Text == "-1.8" and fill.Right.TextXAlignment == Enum.TextXAlignment.Right, "last column")
		expect(fill.Right.AnchorPoint == Vector2.new(0, 0) and fill.Right.Size.Y.Scale == 1, "last column box")
		expect(fill.Column2.Position.X.Offset > fill.Title.Position.X.Offset, "the columns are not in order")
		local count = #row.Instance:GetDescendants()
		row.Set({ Columns = { "2", "You", "Seraph", "+0.0" } })
		expect(fill.Title.Text == "2" and fill.Column2.Text == "YOU", "column update")
		expect(#row.Instance:GetDescendants() == count, "a column update created or destroyed instances")
		row.Set({ Columns = { "2", "You" } })
		expect(fill.Right.Text == "YOU" and fill.Column2.Visible == false and fill.Column3.Visible == false, "fewer columns")
		row.Set({ Columns = false, Title = "Showroom loop", Right = "$25,000" })
		expect(fill.Title.Text == "SHOWROOM LOOP" and fill.Right.Text == "$25,000", "back to a title row")
		expect(fill.Right.AnchorPoint == Vector2.new(1, 0) and fill.Column2.Visible == false, "the title row layout was not restored")
		row.Destroy()
		scope:destroy()
	end)

	---------------------------------------------------------------------------------------------
	-- Rail additions
	---------------------------------------------------------------------------------------------

	case("Rail: Width overrides; SetHeading writes the heading; HeadingRight sits on the heading line", function()
		local parent, ctx = stage("R1080")
		local scope = newScope()
		local component = M.Rail(parent, { Heading = "Wing", Count = "2/4", Width = 900 }, scope)
		local root = component.Instance
		expect(root.Size.X == UDim.new(0, ctx.Px(900)), "Width")
		expect(root.Heading.Label.Text == "WING 2/4", "heading")
		local right = root:FindFirstChild("HeadingRight")
		expect(right ~= nil and component.HeadingRight == right and right:IsA("Frame"), "HeadingRight")
		expect(right.Position.Y.Offset == 0 and right.Size.Y.Offset > 0, "HeadingRight is not on the heading line")
		expect(right.Size.Y.Offset < root.Scroller.Position.Y.Offset + ctx.Px(Tokens.Space.GlowTileRadius), "HeadingRight reaches into the cells")
		component.SetItems(vehicles())
		local before, count = snapshot(root)
		component.SetHeading("Wing", "2/4")
		local same, detail = sameSnapshot(before, count, root)
		expect(same, detail)
		component.SetHeading("Exotic", "3/6")
		expect(root.Heading.Label.Text == "EXOTIC 3/6", "SetHeading")
		component.SetHeading(nil, nil)
		expect(root.Heading.Visible == false, "an empty heading is still shown")
		component.Set({ Width = 600 })
		expect(root.Size.X == UDim.new(0, ctx.Px(600)), "Set Width")
		component.Destroy()
		scope:destroy()
	end)
	case("Rail: a sized parent is filled; a zero-size slot anchor runs to the right edge of the safe area", function()
		local scope = newScope()
		local ctx = Metrics.Fixed(PRESETS.R1080)
		local sized = env.Detached("Frame")
		sized.Name = "SlotBottomRail"
		sized.AnchorPoint = Vector2.new(0, 1)
		sized.Position = UDim2.fromOffset(68, 1050)
		sized.Size = UDim2.fromOffset(1852, 0)
		Metrics.Bind(sized, ctx)
		local filled = M.Rail(sized, { Heading = "Exotic" }, scope)
		expect(filled.Instance.Size.X == UDim.new(1, 0), "a sized slot is not filled")
		expect(filled.Instance.AnchorPoint == Vector2.new(0, 1) and filled.Instance.Position == UDim2.new(0, 0, 1, 0), "the rail does not stand on the slot")
		filled.Destroy()

		local anchor = env.Detached("Frame")
		anchor.Position = UDim2.fromOffset(68, 1050)
		Metrics.Bind(anchor, ctx)
		local running = M.Rail(anchor, { Heading = "Exotic" }, scope)
		expect(running.Instance.Size.X == UDim.new(0, 1920 - 68), "the rail does not run to the right edge")
		running.Destroy()
		scope:destroy()
	end)
	case("Rail: Rows 2 is a two-across grid that scrolls vertically; Rows 1 is the rail again", function()
		local parent, ctx = stage("C844")
		local scope = newScope()
		local component = M.Rail(parent, { Heading = "My vehicles", Count = "6", Width = 200, Rows = 2 }, scope)
		component.SetItems(vehicles())
		local root = component.Instance
		local first, second, third = component.Tile("stinger").Instance, component.Tile("zephyr").Instance, component.Tile("aurora").Instance
		expect(root.Scroller.ScrollingDirection == Enum.ScrollingDirection.Y, "the grid does not scroll vertically")
		expect(first.Size.X.Offset == second.Size.X.Offset and first.Size.X.Offset > 1, "the cells are not equal")
		expect(first.Size.X.Offset * 2 <= ctx.Px(200) and first.Size.X.Offset * 2 + ctx.Px(Tokens.Space.TouchMin) > ctx.Px(200), "two cells do not fill the width")
		expect(first.Position.Y.Offset == second.Position.Y.Offset and second.Position.X.Offset > first.Position.X.Offset, "the first row")
		expect(third.Position.X.Offset == first.Position.X.Offset and third.Position.Y.Offset > first.Position.Y.Offset, "the second row")
		expect(root.Scroller.CanvasSize.X.Offset == 0 and root.Scroller.CanvasSize.Y.Offset > third.Position.Y.Offset, "canvas")
		expect(root.AnchorPoint == Vector2.new(0, 0), "a grid hangs from the top of its parent")
		local count = #root:GetDescendants()
		component.Select("aurora")
		expect(root.Scroller.Selection.Visible == true and root.Scroller.Selection.Position.X.Offset == third.Position.X.Offset, "the selection glow")
		expect(#root:GetDescendants() == count, "a selection created or destroyed instances")
		component.Set({ Rows = 1 })
		expect(root.Scroller.ScrollingDirection == Enum.ScrollingDirection.X, "Rows 1 does not scroll horizontally")
		expect(third.Position.Y.Offset == first.Position.Y.Offset and third.Position.X.Offset > second.Position.X.Offset, "Rows 1 is not one row")
		expect(root.AnchorPoint == Vector2.new(0, 1), "Rows 1 does not stand on the slot")
		component.Destroy()
		scope:destroy()
	end)

	---------------------------------------------------------------------------------------------
	-- List: keyed pool of rows
	---------------------------------------------------------------------------------------------

	local function standings()
		return {
			{ Key = "neon", Columns = { "1", "Neonrider", "-1.8" } },
			{ Key = "you", Columns = { "2", "You", "Seraph" }, Accent = true },
			{ Key = "cyber", Columns = { "3", "Cyberwave", "+0.6" } },
			{ Key = "late", Columns = { "4", "Latebraker", "+2.4" }, Locked = true },
		}
	end
	local listProps = { RowHeight = 56, Header = { "#", "Driver", "Gap" }, OnSelected = nothing }
	local function buildList(parent, props, scope)
		local list = M.List(parent, props, scope)
		list.SetItems(standings())
		return list
	end
	for _, preset in ipairs({ "R1080", "C844" }) do
		contract("List", preset, buildList, listProps, nil)
		contract("List bare", preset, M.List, {}, nil)
	end

	case("List: Header, Scroller, Row(key), Width and RowHeight", function()
		local parent, ctx = stage("R1080")
		local scope = newScope()
		local list = M.List(parent, { RowHeight = 56, Width = 600, Header = { "#", "Driver", "Gap" } }, scope)
		list.SetItems(standings())
		local root = list.Instance
		expect(root:FindFirstChild("Header") ~= nil and root:FindFirstChild("Scroller") ~= nil and root.Scroller:IsA("ScrollingFrame"), "children")
		expect(root.Scroller.ScrollingDirection == Enum.ScrollingDirection.Y, "scroll direction")
		expect(root.Size.X == UDim.new(0, ctx.Px(600)), "Width")
		expect(root.Header.Column2.Text == "DRIVER" and root.Header.Column3.TextXAlignment == Enum.TextXAlignment.Right, "header columns")
		local you, neon = list.Row("you"), list.Row("neon")
		expect(you ~= nil and you.Instance:IsA("GuiButton") and you.Instance.Visible == true, "Row(key)")
		expect(list.Row("nope") == nil, "unknown key returned a row")
		expect(you.Instance.Size.Y.Offset == ctx.Px(56), "RowHeight")
		expect(you.Instance.Position.Y.Offset > neon.Instance.Position.Y.Offset + neon.Instance.Size.Y.Offset - 1, "the rows overlap")
		expect(you.Instance.Fill.Column2.Text == "YOU" and you.Instance.Fill.Accent.Visible == true, "row content")
		expect(you.Instance.Fill.Column2.Position.X == root.Header.Column2.Position.X, "a header column is not over its row column")
		expect(list.Row("late").Instance.Active == false, "locked row")
		expect(you.Instance:FindFirstChild("Glow") == nil, "a pooled row carries its own glow")
		expect(root.Size.Y.Offset > 4 * ctx.Px(56), "the list is shorter than its rows")
		list.Destroy()
		scope:destroy()
	end)
	-- Mobile pass round 2 (API2 amendments A15 and A16).
	case("ListRow C844: Selected is an opaque Slate plate with light text and the Pink to Violet line, never White", function()
		local parent, ctx = stage("C844")
		local scope = newScope()
		local row = M.ListRow(parent, { Title = "Showroom loop", Sub = "Circuit", Right = "$25,000", Chip = "New", Accent = true }, scope)
		local root = row.Instance
		local fill = root.Fill
		local line = fill.HairBottom
		local count = #root:GetDescendants()
		row.Set({ State = "Selected" })
		expect(fill.BackgroundColor3 == Tokens.Colour.Slate and fill.BackgroundTransparency == 0, "the selected plate is not opaque Slate")
		expect(fill.Title.TextColor3 == Tokens.Colour.White and fill.Sub.TextColor3 == Tokens.Colour.White, "the selected text is not light")
		expect(fill.Right.TextColor3 == Tokens.Colour.White, "the right-hand text is not light")
		expect(fill.Chip.BackgroundColor3 == Tokens.Colour.White and fill.Chip.TextColor3 == Tokens.Colour.White, "the neutral chip took the on-white look")
		expect(line:FindFirstChildOfClass("UIGradient").Enabled == true, "no Pink to Violet line")
		expect(line.Size.Y.Offset == ctx.Px(Tokens.Space.Hairline + Tokens.Space.Hairline), "the selected line is not the 4 dp one")
		expect(fill.Accent.Visible == true and fill.Accent.BackgroundColor3 == Tokens.Colour.Pink, "the Pink left bar went")
		expect(#root:GetDescendants() == count, "selection created or destroyed instances")
		row.Set({ State = "Default" })
		expect(about(fill.BackgroundTransparency, 1 - Tokens.Opacity.Panel) and fill.Title.TextColor3 == Tokens.Colour.White, "the default row changed")
		row.Destroy()
		-- Regular keeps the White plate with Ink text.
		local desk = stage("R1080")
		local deskRow = M.ListRow(desk, { Title = "Showroom loop", State = "Selected" }, scope)
		expect(deskRow.Instance.Fill.BackgroundColor3 == Tokens.Colour.White and deskRow.Instance.Fill.BackgroundTransparency == 0, "Regular selected fill changed")
		expect(deskRow.Instance.Fill.Title.TextColor3 == Tokens.Colour.Ink, "Regular selected text changed")
		deskRow.Destroy()
		scope:destroy()
	end)
	case("List: Dense drops the touch-size floor of the rows; the default keeps it; Set switches it", function()
		local parent, ctx = stage("C844")
		local scope = newScope()
		local list = M.List(parent, { RowHeight = 28, Header = { "#", "Driver", "Gap" } }, scope)
		list.SetItems(standings())
		local you = list.Row("you").Instance
		expect(you.Size.Y.Offset == ctx.Touch(1) and ctx.Touch(1) > ctx.Px(28), "the default list lost its touch-size rows")
		local tall = list.Instance.Size.Y.Offset
		list.Set({ Dense = true })
		expect(you.Size.Y.Offset == ctx.Px(28), "Dense did not drop the floor: " .. you.Size.Y.Offset)
		expect(list.Instance.Size.Y.Offset < tall, "the dense list is not shorter")
		local neon = list.Row("neon").Instance
		expect(you.Position.Y.Offset >= neon.Position.Y.Offset + neon.Size.Y.Offset, "dense rows overlap")
		list.Set({ Dense = false })
		expect(you.Size.Y.Offset == ctx.Touch(1), "Dense = false did not restore the floor")
		list.Destroy()
		local dense = M.List(parent, { RowHeight = 28, Dense = true }, scope)
		dense.SetItems(standings())
		expect(dense.Row("you").Instance.Size.Y.Offset == ctx.Px(28), "Dense in props")
		dense.Destroy()
		-- Regular with a mouse has no floor either way.
		local desk, deskCtx = stage("R1080")
		local plain = M.List(desk, { RowHeight = 56 }, scope)
		plain.SetItems(standings())
		local before = plain.Row("you").Instance.Size
		plain.Set({ Dense = true })
		expect(plain.Row("you").Instance.Size == before and before.Y.Offset == deskCtx.Px(56), "Dense changed a Regular row")
		plain.Destroy()
		scope:destroy()
	end)
	for _, preset in ipairs({ "R1080", "C844" }) do
		case("List " .. preset .. ": SetItems twice with the same keys creates nothing and writes nothing", function()
			local parent = stage(preset)
			local scope = newScope()
			local list = buildList(parent, listProps, scope)
			local before, count = snapshot(list.Instance)
			list.SetItems(standings())
			local same, detail = sameSnapshot(before, count, list.Instance)
			list.Destroy()
			scope:destroy()
			expect(same, detail)
		end)
	end
	case("List: a key keeps its row; a selection or data change creates nothing; freed rows stay parented", function()
		local parent = stage("R1080")
		local scope = newScope()
		local selections = {}
		local list = M.List(parent, {
			RowHeight = 56,
			OnSelected = function(key)
				table.insert(selections, key)
			end,
		}, scope)
		list.SetItems(standings())
		local scroller = list.Instance.Scroller
		local you, cyber = list.Row("you"), list.Row("cyber")
		local count = #list.Instance:GetDescendants()
		local children = #scroller:GetChildren()
		list.Select("you")
		list.Select("cyber")
		expect(scroller.Selection.Visible == true and scroller.Selection.Position.Y.Offset == cyber.Instance.Position.Y.Offset, "the selection glow")
		expect(cyber.Instance.Fill.BackgroundColor3 == Tokens.Colour.White and you.Instance.Fill.BackgroundColor3 == Tokens.Colour.Slate, "the selection did not move")
		expect(#selections == 0, "OnSelected fired for a programmatic Select")
		local reordered = standings()
		reordered[1], reordered[3] = reordered[3], reordered[1]
		reordered[2].Columns = { "2", "You", "Aurora" }
		list.SetItems(reordered)
		expect(list.Row("you") == you and list.Row("cyber") == cyber, "a key moved to another row")
		expect(cyber.Instance.Position.Y.Offset < you.Instance.Position.Y.Offset, "the reorder was not laid out")
		expect(you.Instance.Fill.Right.Text == "AURORA", "the data change was not written")
		expect(cyber.Instance.Fill.BackgroundColor3 == Tokens.Colour.White, "the selection was lost on SetItems")
		expect(#list.Instance:GetDescendants() == count, "a selection, reorder or data change created or destroyed instances")
		list.SetItems({ standings()[1] })
		expect(#scroller:GetChildren() == children and you.Instance.Parent == scroller and you.Instance.Visible == false, "a freed row was not hidden in place")
		expect(list.Row("you") == nil and scroller.Selection.Visible == false, "a removed key is still there")
		list.SetItems(standings())
		expect(#scroller:GetChildren() == children and #list.Instance:GetDescendants() == count, "refilling the pool created instances")
		expect(not pcall(list.Select, "nope"), "unknown key accepted")
		expect(not pcall(list.SetItems, { { Key = "a" }, { Key = "a" } }), "duplicate key accepted")
		expect(not pcall(list.SetItems, { { Title = "No key" } }), "missing key accepted")
		list.Destroy()
		list.Destroy()
		list.SetItems(standings())
		expect(#parent:GetChildren() == 0, "children left under the parent")
		scope:destroy()
	end)

	---------------------------------------------------------------------------------------------
	-- Pool
	---------------------------------------------------------------------------------------------

	case("Pool: Take reuses a released item before it makes one; reset runs on release; Count", function()
		local resets = 0
		local pool = M.Pool(function(index)
			return { Index = index, Idle = false }
		end, function(item)
			item.Idle = true
			resets = resets + 1
		end)
		local a, b = pool.Take(), pool.Take()
		expect(a.Index == 1 and b.Index == 2 and a ~= b, "make order")
		local made, out = pool.Count()
		expect(made == 2 and out == 2, "count after two takes")
		pool.Release(a)
		pool.Release(a)
		expect(a.Idle == true and resets == 1, "reset ran " .. resets .. " times")
		local again = pool.Take()
		expect(again == a, "a released item was not reused")
		made, out = pool.Count()
		expect(made == 2 and out == 2, "count after reuse")
		pool.ReleaseAll()
		made, out = pool.Count()
		expect(made == 2 and out == 0 and resets == 3, "ReleaseAll")
		pool.Release({})
		expect(resets == 3, "an item the pool never made was reset")
		local c, d, e = pool.Take(), pool.Take(), pool.Take()
		expect(e.Index == 3 and c ~= d, "growth by the shortfall only")
		expect(not pcall(M.Pool, nil, function() end), "a pool without make accepted")
	end)

	return results
end
