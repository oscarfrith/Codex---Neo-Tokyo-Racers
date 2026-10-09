-- Owns the pure tests for Kit.BigNumber; does not own the harness, and never yields or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.BigNumber_test. Requires: none (modules come from env.Load).
local KIT = "ReplicatedStorage.Modules.Game.UIPulse.Kit."

local CELL_PROPERTIES = {
	"Name", "Visible", "Size", "Position", "Image", "ImageColor3", "ImageRectOffset", "ImageRectSize",
	"ImageTransparency", "Text", "TextColor3", "TextSize", "TextXAlignment",
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
			elseif type(item) == "function" then
				item()
			end
		end
		table.clear(items)
	end
	return scope
end

-- One string per instance: every listed property it has.
local function describe(instance)
	local parts = { instance.ClassName }
	for _, property in CELL_PROPERTIES do
		local ok, value = pcall(function()
			return instance[property]
		end)
		if ok then
			table.insert(parts, property .. "=" .. tostring(value))
		end
	end
	return table.concat(parts, ";")
end

local function snapshot(root)
	local parts = { describe(root) }
	for _, instance in root:GetDescendants() do
		table.insert(parts, describe(instance))
	end
	return table.concat(parts, "|")
end

-- Property name -> value for one cell, for a per-property comparison.
local function cellState(cell)
	local state = {}
	for _, property in CELL_PROPERTIES do
		local ok, value = pcall(function()
			return cell[property]
		end)
		if ok then
			state[property] = value
		end
	end
	return state
end

local function changedProperties(before, after)
	local names = {}
	for _, property in CELL_PROPERTIES do
		if before[property] ~= after[property] then
			table.insert(names, property)
		end
	end
	table.sort(names)
	return table.concat(names, ",")
end

return function(BigNumber, env)
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

	local big = Sprites.Digits[256]
	local small = Sprites.Digits[128]
	local flat = Tokens.Asset(big.Asset) == nil or Tokens.Asset(small.Asset) == nil

	local function round(value)
		return math.floor(value + 0.5)
	end

	local function build(ctx, props)
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, ctx)
		local scope = fakeScope()
		return BigNumber.New(parent, props, scope), parent, scope
	end

	local function cellsOf(component, count)
		local cells = {}
		for index = 1, count do
			cells[index] = component.Instance:FindFirstChild("Cell" .. index)
		end
		return cells
	end

	-- Pure functions ---------------------------------------------------------------------------------

	case("SheetFor: the small sheet up to its own cap, the large one above", function()
		expect(BigNumber.SheetFor(small.Cap), 128, "at the small cap")
		expect(BigNumber.SheetFor(small.Cap + 1), 256, "one above")
		expect(BigNumber.SheetFor(10), 128, "tiny")
		expect(BigNumber.SheetFor(big.Cap * 2), 256, "huge")
		expect(small.Cap, 92, "API2 3.1: 128 when capPx <= 92")
	end)

	case("Layout: fixed digits sit centred in pitch slots", function()
		for _, id in { 128, 256 } do
			local sheet = Sprites.Digits[id]
			local overhang = (sheet.Cell[1] - sheet.Pitch) / 2
			local layout = BigNumber.Layout("142", id)
			expect(#layout.Cells, 3, "cells on " .. id)
			for index, token in { "1", "4", "2" } do
				expect(layout.Cells[index].Token, token, "token " .. index)
				expect(layout.Cells[index].X, (index - 1) * sheet.Pitch - overhang, "x " .. index .. " on " .. id)
			end
			expect(layout.Width, 3 * sheet.Pitch, "width on " .. id)
			expect(layout.Unknown, nil, "nothing unknown")
		end
	end)

	case("Layout: a narrow and a wide digit take the same slot (no jitter)", function()
		local a = BigNumber.Layout("111", 256)
		local b = BigNumber.Layout("444", 256)
		for index = 1, 3 do
			expect(a.Cells[index].X, b.Cells[index].X, "x " .. index)
		end
		expect(a.Width, b.Width, "width")
	end)

	case("Layout: tight uses PitchTight", function()
		local layout = BigNumber.Layout("90", 256, true)
		local overhang = (big.Cell[1] - big.PitchTight) / 2
		expect(layout.Cells[1].X, -overhang, "first")
		expect(layout.Cells[2].X, big.PitchTight - overhang, "second")
		expect(layout.Width, 2 * big.PitchTight, "width")
	end)

	case("Layout: punctuation is drawn at pen - originX and advances by its own advance", function()
		local colon = Sprites.Punct[256].Glyphs[":"]
		local advance, origin = colon[5], colon[6]
		local overhang = (big.Cell[1] - big.Pitch) / 2
		local layout = BigNumber.Layout("1:23", 256)
		expect(#layout.Cells, 4, "cells")
		expect(layout.Cells[2].Token, ":", "colon token")
		expect(layout.Cells[2].X, big.Pitch - origin, "colon x")
		expect(layout.Cells[3].X, big.Pitch + advance - overhang, "digit after the colon")
		expect(layout.Width, 3 * big.Pitch + advance, "width")
	end)

	case("Layout: longest token first", function()
		local function tokens(text)
			local list = {}
			for _, cell in BigNumber.Layout(text, 256).Cells do
				table.insert(list, cell.Token)
			end
			return table.concat(list, " ")
		end
		expect(tokens("88KM/H"), "8 8 KM/H", "KM/H")
		expect(tokens("231MPH"), "2 3 1 MPH", "MPH")
		expect(tokens("+120XP"), "+ 1 2 0 XP", "XP")
		expect(tokens("KM"), "K M", "K then M")
		expect(tokens("$1.4M"), "$ 1 . 4 M", "short money")
		expect(tokens("x2,5%-/"), "x 2 , 5 % - /", "every single token")
	end)

	case("Layout: a space advances half a pitch and takes no cell", function()
		local overhang = (big.Cell[1] - big.Pitch) / 2
		local layout = BigNumber.Layout("1 2", 256)
		expect(#layout.Cells, 2, "cells")
		expect(layout.Cells[2].X, big.Pitch * 1.5 - overhang, "second digit")
		expect(layout.Width, big.Pitch * 2.5, "width")
	end)

	case("Layout: proportional advances (Fixed = false)", function()
		local one = big.Glyphs["1"]
		local advance, origin = one[3], one[4]
		local layout = BigNumber.Layout("11", 256, false, true)
		expect(layout.Cells[1].X, -origin, "first")
		expect(layout.Cells[2].X, advance - origin, "second")
		expect(layout.Width, 2 * advance, "width")
	end)

	case("Layout: unknown characters are skipped and listed; bad arguments error", function()
		local layout = BigNumber.Layout("1a2", 256)
		expect(#layout.Cells, 2, "cells")
		expect(type(layout.Unknown), "table", "Unknown list")
		expect(layout.Unknown[1], "a", "the character")
		expect(pcall(BigNumber.Layout, 12, 256), false, "text must be a string")
		expect(pcall(BigNumber.Layout, "12", 64), false, "unknown sheet")
		expect(#BigNumber.Layout("", 128).Cells, 0, "empty text")
	end)

	-- Component ----------------------------------------------------------------------------------------

	local function common(name, ctx, props, budget)
		case(name .. ": builds detached within budget " .. budget .. ", Set and Destroy", function()
			local component, parent, scope = build(ctx, props)
			expect(component.Instance.Parent, parent, "root parent")
			expect(#parent:GetChildren(), 1, "one root")
			local count = 1 + #component.Instance:GetDescendants()
			for _, instance in component.Instance:GetDescendants() do
				if instance:IsA("UITextSizeConstraint") then
					count -= 1
				end
			end
			if count > budget then
				error("budget " .. budget .. " exceeded: " .. count)
			end

			local before = snapshot(component.Instance)
			component.Set(table.clone(props))
			expect(snapshot(component.Instance), before, "unchanged Set")
			component.SetText(props.Text)
			expect(snapshot(component.Instance), before, "unchanged SetText")

			expect(pcall(component.Set, { Nope = true }), false, "Set unknown key")
			local bad = table.clone(props)
			bad.Nope = true
			expect(pcall(BigNumber.New, parent, bad, scope), false, "constructor unknown key")
			expect(#parent:GetChildren(), 1, "failed constructor leaves nothing")

			component.Set({ Visible = false, LayoutOrder = 7, Name = "Renamed" })
			expect(component.Instance.Visible, false, "Visible")
			expect(component.Instance.LayoutOrder, 7, "LayoutOrder")
			expect(component.Instance.Name, "Renamed", "Name")

			component.Destroy()
			expect(#parent:GetChildren(), 0, "parent empty after Destroy")
			component.Destroy()
			component.Set({ Visible = true })
			component.SetText("1")
			scope:destroy()
		end)
	end

	common("Speed R1080", r1080, { Text = "142", Role = "Speed", MaxCells = 3, Align = "Centre" }, flat and 2 or 4)
	common("Timer R720", r720, { Text = "03:11.842", Role = "Timer", MaxCells = 9, Align = "Left", Tight = true }, flat and 2 or 10)
	common("Hero C844", c844, { Text = "$20,000", Role = "Hero", Colour = "Yellow", MaxCells = 10, Fixed = false }, flat and 2 or 11)
	common("Countdown C844", c844, { Text = "3", Role = "Countdown", MaxCells = 1 }, 2)

	case("New: required props, bad values and unknown characters error and leave nothing", function()
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, r1080)
		local scope = fakeScope()
		expect(pcall(BigNumber.New, parent, { Text = "1", MaxCells = 3 }, scope), false, "Role required")
		expect(pcall(BigNumber.New, parent, { Text = "1", Role = "Speed" }, scope), false, "MaxCells required")
		expect(pcall(BigNumber.New, parent, { Text = "1", Role = "Nope", MaxCells = 3 }, scope), false, "unknown Role")
		expect(pcall(BigNumber.New, parent, { Text = "1", Role = "Speed", MaxCells = 0 }, scope), false, "MaxCells 0")
		expect(pcall(BigNumber.New, parent, { Text = "1", Role = "Speed", MaxCells = 2.5 }, scope), false, "MaxCells fraction")
		expect(pcall(BigNumber.New, parent, { Text = "1", Role = "Speed", MaxCells = 3, Colour = "Nope" }, scope), false, "Colour")
		expect(pcall(BigNumber.New, parent, { Text = "1", Role = "Speed", MaxCells = 3, Align = "Middle" }, scope), false, "Align")
		expect(pcall(BigNumber.New, parent, { Text = "1a", Role = "Speed", MaxCells = 3 }, scope), false, "unknown character at build")
		expect(#parent:GetChildren(), 0, "nothing left")
		scope:destroy()
	end)

	case("New: every NumberCap role builds on both classes", function()
		for role in Tokens.NumberCap.Regular do
			for _, ctx in { r1080, c844 } do
				local component, _, scope = build(ctx, { Text = "1", Role = role, MaxCells = 2 })
				component.Destroy()
				scope:destroy()
			end
		end
	end)

	case("New: the root has the fixed size MaxCells x pitch by the cell height", function()
		local component, _, scope = build(r1080, { Text = "7", Role = "Speed", MaxCells = 3, Align = "Right" })
		local capPx = r1080.Px(Tokens.NumberCap.Regular.Speed)
		local sheet = Sprites.Digits[BigNumber.SheetFor(capPx)]
		local scale = capPx / sheet.Cap
		local expected = UDim2.fromOffset(3 * math.max(1, round(sheet.Pitch * scale)), math.max(1, round(sheet.Cell[2] * scale)))
		expect(component.Instance.Size, expected, "size")
		component.SetText("142")
		expect(component.Instance.Size, expected, "size after a longer text")
		component.SetText("")
		expect(component.Instance.Size, expected, "size after an empty text")
		component.Destroy()
		scope:destroy()
	end)

	case("Set: MaxCells cannot change; SetText needs a string", function()
		local component, _, scope = build(r1080, { Text = "1", Role = "Speed", MaxCells = 3 })
		expect(pcall(component.Set, { MaxCells = 4 }), false, "MaxCells change")
		expect(pcall(component.Set, { MaxCells = 3 }), true, "same MaxCells")
		expect(pcall(component.SetText, 12), false, "number")
		component.Destroy()
		scope:destroy()
	end)

	if flat then
		case("Flat state: one text label carries the text", function()
			local component, _, scope = build(r1080, { Text = "142", Role = "Speed", MaxCells = 3, Colour = "Cyan" })
			local label = component.Instance:FindFirstChild("Flat")
			expect(label ~= nil and label:IsA("TextLabel"), true, "Flat label")
			expect(label.Text, "142", "text")
			expect(label.TextColor3, Tokens.Colour.Cyan, "colour")
			component.SetText("99")
			expect(label.Text, "99", "SetText")
			component.Destroy()
			scope:destroy()
		end)
		return results
	end

	case("Cells: sheet, rectangle, draw size and tint", function()
		local component, _, scope = build(r1080, { Text = "142", Role = "Speed", MaxCells = 3, Colour = "Pink" })
		local capPx = r1080.Px(Tokens.NumberCap.Regular.Speed)
		local id = BigNumber.SheetFor(capPx)
		local sheet = Sprites.Digits[id]
		local scale = capPx / sheet.Cap
		local cells = cellsOf(component, 3)
		for index, token in { "1", "4", "2" } do
			local cell = cells[index]
			local glyph = sheet.Glyphs[token]
			expect(cell.ClassName, "ImageLabel", "class " .. index)
			expect(cell.Visible, true, "visible " .. index)
			expect(cell.Image, Tokens.Asset(sheet.Asset), "image " .. index)
			expect(cell.ImageRectOffset, Vector2.new(glyph[1], glyph[2]), "offset " .. index)
			expect(cell.ImageRectSize, Vector2.new(sheet.Cell[1], sheet.Cell[2]), "rect " .. index)
			expect(cell.Size, UDim2.fromOffset(round(sheet.Cell[1] * scale), round(sheet.Cell[2] * scale)), "size " .. index)
			expect(cell.ImageColor3, Tokens.Colour.Pink, "tint " .. index)
			expect(cell.Position.X.Offset % 1, 0, "whole pixel " .. index)
		end
		component.Destroy()
		scope:destroy()
	end)

	case("Cells: Compact picks the small sheet; punctuation comes from the punctuation sheet", function()
		local component, _, scope = build(c844, { Text = "1:2", Role = "Timer", MaxCells = 3 })
		local capPx = c844.Px(Tokens.NumberCap.Compact.Timer)
		expect(BigNumber.SheetFor(capPx), 128, "sheet")
		local cells = cellsOf(component, 3)
		local colon = Sprites.Punct[128].Glyphs[":"]
		expect(cells[1].ImageRectSize, Vector2.new(small.Cell[1], small.Cell[2]), "digit rect")
		expect(cells[2].Image, Tokens.Asset(Sprites.Punct[128].Asset) or "", "punctuation image")
		expect(cells[2].ImageRectOffset, Vector2.new(colon[1], colon[2]), "colon offset")
		expect(cells[2].ImageRectSize, Vector2.new(colon[3], colon[4]), "colon rect")
		component.Destroy()
		scope:destroy()
	end)

	case("SetText: only the cell whose token changed is touched, and only its rectangle", function()
		local component, _, scope = build(r1080, { Text = "142", Role = "Speed", MaxCells = 3, Align = "Right" })
		local cells = cellsOf(component, 3)
		local before = { cellState(cells[1]), cellState(cells[2]), cellState(cells[3]) }
		local instancesBefore = #component.Instance:GetDescendants()
		component.SetText("143")
		expect(changedProperties(before[1], cellState(cells[1])), "", "cell 1 untouched")
		expect(changedProperties(before[2], cellState(cells[2])), "", "cell 2 untouched")
		expect(changedProperties(before[3], cellState(cells[3])), "ImageRectOffset", "cell 3: rectangle only")
		expect(#component.Instance:GetDescendants(), instancesBefore, "nothing created")

		local whole = snapshot(component.Instance)
		component.SetText("143")
		expect(snapshot(component.Instance), whole, "unchanged text writes nothing")
		component.Set({ Text = "143" })
		expect(snapshot(component.Instance), whole, "unchanged Set writes nothing")
		component.Destroy()
		scope:destroy()
	end)

	case("SetText: a digit to punctuation swap rewrites image, rectangle and size of that cell only", function()
		local component, _, scope = build(r1080, { Text = "1234", Role = "Timer", MaxCells = 4 })
		local cells = cellsOf(component, 4)
		local before = { cellState(cells[1]), cellState(cells[2]) }
		component.SetText("1:34")
		expect(changedProperties(before[1], cellState(cells[1])), "", "cell 1 untouched")
		local changed = changedProperties(before[2], cellState(cells[2]))
		if not string.find(changed, "ImageRectOffset", 1, true) or not string.find(changed, "ImageRectSize", 1, true)
			or not string.find(changed, "Size", 1, true) then
			error("cell 2 should change rectangle and size, changed: " .. changed)
		end
		component.Destroy()
		scope:destroy()
	end)

	case("SetText: cells appear and disappear through Visible; the pool never grows", function()
		local component, _, scope = build(r1080, { Text = "142", Role = "Speed", MaxCells = 3, Align = "Right" })
		local cells = cellsOf(component, 3)
		component.SetText("7")
		expect(cells[1].Visible, true, "cell 1 shown")
		expect(cells[2].Visible, false, "cell 2 hidden")
		expect(cells[3].Visible, false, "cell 3 hidden")
		component.SetText("")
		expect(cells[1].Visible, false, "all hidden")
		component.SetText("99")
		expect(cells[1].Visible and cells[2].Visible, true, "two shown")
		expect(cells[3].Visible, false, "third hidden")
		component.SetText("12345")
		expect(#component.Instance:GetChildren(), 3, "overflow is cut, not grown")
		expect(cells[3].Visible, true, "three shown")
		component.Destroy()
		scope:destroy()
	end)

	case("Align: Left starts at the layout x, Right ends at the root edge, Centre splits the slack", function()
		local capPx = r1080.Px(Tokens.NumberCap.Regular.Speed)
		local sheet = Sprites.Digits[BigNumber.SheetFor(capPx)]
		local scale = capPx / sheet.Cap
		local layout = BigNumber.Layout("7", sheet == big and 256 or 128)
		local first = round(layout.Cells[1].X * scale)
		local width = round(layout.Width * scale)

		local left, _, scopeA = build(r1080, { Text = "7", Role = "Speed", MaxCells = 3, Align = "Left" })
		local right, _, scopeB = build(r1080, { Text = "7", Role = "Speed", MaxCells = 3, Align = "Right" })
		local centre, _, scopeC = build(r1080, { Text = "7", Role = "Speed", MaxCells = 3, Align = "Centre" })
		local rootWidth = left.Instance.Size.X.Offset
		expect(left.Instance.Cell1.Position.X.Offset, first, "left")
		expect(right.Instance.Cell1.Position.X.Offset, rootWidth - width + first, "right")
		expect(centre.Instance.Cell1.Position.X.Offset, round((rootWidth - layout.Width * scale) / 2) + first, "centre")
		left.Destroy()
		right.Destroy()
		centre.Destroy()
		scopeA:destroy()
		scopeB:destroy()
		scopeC:destroy()
	end)

	return results
end
