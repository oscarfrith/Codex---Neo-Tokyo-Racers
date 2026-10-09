-- Pure tests for Kit.Collections (API.md 13). Runs in Edit through the harness; nothing is parented into the game tree and nothing yields.
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
	case("resolveTile: Unaffordable is inactive with a muted price and no lock", function()
		local look = M._resolveTile("Default", "Unaffordable", {})
		expect(look.Active == false and look.PriceInk == "TextMuted" and look.Lock == false and look.Opacity == 1, "unaffordable")
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
			contract(entry[1], preset, M.Tile, entry[2], 12)
		end
	end

	local rows = {
		{ "ListRow Default", { Title = "Shifted canal sprint", Sub = "Circuit", OnActivated = nothing } },
		{ "ListRow Selected", { Title = "Seraph", Sub = "Exotic", Tier = "S", Right = "Parked", State = "Selected" } },
		{ "ListRow Locked full", { Title = "Showroom loop", Sub = "Unavailable", Tier = "A", Right = "$25,000", Image = "", Locked = true } },
	}
	for _, entry in ipairs(rows) do
		for _, preset in ipairs({ "R1080", "C844" }) do
			contract(entry[1], preset, M.ListRow, entry[2], 10)
		end
	end

	for _, preset in ipairs({ "R1080", "R720", "C844" }) do
		contract("Chip Price", preset, M.Chip, { Text = "$84,000", Kind = "Price", Muted = true }, 2)
		contract("Chip Neutral", preset, M.Chip, { Text = "Owned x2", Kind = "Neutral" }, 2)
		contract("TierBadge rating", preset, M.TierBadge, { Tier = "C", Rating = 540, OnLight = true }, 4)
		contract("TierBadge letter", preset, M.TierBadge, { Tier = "S", Size = "Small", Dim = true }, 4)
		contract("Rail", preset, M.Rail, { Heading = "Exotic", Count = "2/6", OnSelected = nothing }, nil)
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
			expect(root.Fill.Visual.Size.Y.Offset > visual.Y.Offset, preset .. ": the visual did not grow")
			expect(#root:GetDescendants() == count, preset .. ": selection created or destroyed instances")
			tile.Set({ State = "Default" })
			expect(root.Fill.Size.Y.Offset == fillHeight and root.Fill.Visual.Size == visual, preset .. ": deselect did not restore")
			tile.Destroy()
			scope:destroy()
		end
	end)
	case("Tile: Locked and Unaffordable set Active false and stay visible; Owned stays active", function()
		local parent = stage("R1080")
		local scope = newScope()
		local tile = M.Tile(parent, { Title = "Rosso", Price = "$4.40M", Status = "Unaffordable" }, scope)
		expect(tile.Instance.Active == false and tile.Instance.Visible == true, "unaffordable")
		tile.Set({ Status = "Locked" })
		expect(tile.Instance.Active == false and tile.Instance.Visible == true, "locked")
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

	return results
end
