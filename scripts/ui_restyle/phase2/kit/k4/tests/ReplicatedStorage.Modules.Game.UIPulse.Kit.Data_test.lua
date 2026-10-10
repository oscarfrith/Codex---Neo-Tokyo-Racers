-- Owns the pure tests for Kit.Data; does not own the harness, and never yields, requires a Classic module or parents into the game tree.
-- Pulse UI (phase2). tests/ReplicatedStorage.Modules.Game.UIPulse.Kit.Data_test. Requires: none (modules come from env.Load).
local KIT = "ReplicatedStorage.Modules.Game.UIPulse.Kit."

local SNAPSHOT_PROPERTIES = {
	"Name", "Visible", "LayoutOrder", "ZIndex", "Active", "Size", "Position", "AnchorPoint",
	"BackgroundColor3", "BackgroundTransparency", "Image", "ImageColor3", "ImageTransparency",
	"ImageRectOffset", "ImageRectSize", "ScaleType", "TileSize", "Rotation",
	"Text", "TextColor3", "TextSize", "TextTransparency", "TextXAlignment", "FontFace",
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

-- Descendants including the root, without size-lock constraints and without the `skip` subtree.
local function countInstances(root, skip)
	local count = 1
	for _, instance in root:GetDescendants() do
		local skipped = instance:IsA("UITextSizeConstraint")
		if skip ~= nil and (instance == skip or instance:IsDescendantOf(skip)) then
			skipped = true
		end
		if not skipped then
			count += 1
		end
	end
	return count
end

local function instanceSet(root)
	local set = {}
	for _, instance in root:GetDescendants() do
		set[instance] = true
	end
	return set
end

local function sameSet(a, b)
	for instance in a do
		if not b[instance] then
			return false
		end
	end
	for instance in b do
		if not a[instance] then
			return false
		end
	end
	return true
end

return function(Data, env)
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

	-- The fake foundation (API2 3.5 test seam). It records every call; nothing Classic is required.
	local calls = {}
	local presenters = {}
	local bindings = {}
	local fake = {}
	function fake.FormatCompactMoney(value)
		table.insert(calls, "compact:" .. tostring(value))
		return "C$" .. tostring(value)
	end
	function fake.FormatFullMoney(value)
		table.insert(calls, "full:" .. tostring(value))
		return "F$" .. tostring(value)
	end
	function fake.FormatFreeRoamMoney(value)
		table.insert(calls, "freeroam:" .. tostring(value))
		return "R$" .. tostring(value)
	end
	function fake.ProjectEconomy(response, fallback)
		table.insert(calls, "project")
		return { Cash = response and response.Cash or fallback and fallback.Cash, Response = response, Fallback = fallback }
	end
	-- Shaped as the Classic presenter: methods take self; SetTarget snaps and renders (displayed, authoritative).
	function fake.CreateCashDisplayPresenter(render, options)
		local presenter = { Render = render, Options = options, Targets = {}, Destroyed = false, BadSelf = false }
		function presenter:SetTarget(value)
			if self ~= presenter then
				presenter.BadSelf = true
				return
			end
			table.insert(presenter.Targets, value)
			render(value, value)
		end
		function presenter:Destroy()
			presenter.Destroyed = true
		end
		table.insert(presenters, presenter)
		return presenter
	end
	function fake.BindReplicatedCash(player, callback)
		local binding = { Player = player, Callback = callback, Disconnected = false }
		table.insert(bindings, binding)
		callback(100, nil) -- the Classic binding publishes the current value at once
		return function()
			binding.Disconnected = true
		end
	end

	local realFoundation = Data._foundation
	case("Seam: Data._foundation is a replaceable function", function()
		expect(type(realFoundation), "function", "Data._foundation")
	end)
	Data._foundation = function()
		return fake
	end

	local function build(constructor, ctx, props)
		local parent = env.Detached("Frame")
		Metrics.Bind(parent, ctx)
		local scope = fakeScope()
		return constructor(parent, props, scope), parent, scope
	end

	-- Money ------------------------------------------------------------------------------------------

	case("Money: the shared formatters, called with the amount untouched", function()
		table.clear(calls)
		expect(Data.Money(1234.5, false), "F$1234.5", "full")
		expect(Data.Money(1234.5), "F$1234.5", "full by default")
		expect(Data.Money(3613709, true), "C$3613709", "compact")
		expect(Data.FreeRoamMoney(77), "R$77", "free roam")
		expect(table.concat(calls, " "), "full:1234.5 full:1234.5 compact:3613709 freeroam:77", "calls")
	end)

	case("ProjectEconomy: passes the reply and the fallback through and returns the projection", function()
		table.clear(calls)
		local response, fallback = { Cash = 5 }, { Cash = 9 }
		local projection = Data.ProjectEconomy(response, fallback)
		expect(projection.Response, response, "response")
		expect(projection.Fallback, fallback, "fallback")
		expect(projection.Cash, 5, "cash")
		expect(calls[1], "project", "called once")
		expect(#calls, 1, "one call")
	end)

	-- Pure helpers -------------------------------------------------------------------------------------

	case("_segments: whole segments, gain and loss", function()
		local function row(value, preview, count)
			local filled, from, previewed, kind = Data._segments(value, preview, count)
			return filled .. "," .. from .. "," .. previewed .. "," .. tostring(kind)
		end
		expect(row(0.77, nil, 16), "12,12,0,nil", "value only")
		expect(row(0.77, false, 16), "12,12,0,nil", "false clears the preview")
		expect(row(0, nil, 16), "0,0,0,nil", "empty")
		expect(row(1, nil, 16), "16,16,0,nil", "full")
		expect(row(2, nil, 16), "16,16,0,nil", "clamped above")
		expect(row(-1, nil, 16), "0,0,0,nil", "clamped below")
		expect(row(0.63, 0.66, 16), "10,10,1,Gain", "gain")
		expect(row(0.61, 0.59, 16), "9,9,1,Loss", "loss")
		expect(row(0.25, 0.75, 8), "2,2,4,Gain", "eight segments")
		expect(row(0.5, 0.5, 16), "8,8,0,nil", "equal preview")
	end)

	case("_segments: a preview that differs always shows one segment", function()
		local function row(value, preview, count)
			local filled, from, previewed, kind = Data._segments(value, preview, count)
			return filled .. "," .. from .. "," .. previewed .. "," .. tostring(kind)
		end
		expect(row(0.5, 0.505, 16), "8,8,1,Gain", "small gain")
		expect(row(0.5, 0.495, 16), "7,7,1,Loss", "small loss")
		expect(row(0.99, 1, 16), "15,15,1,Gain", "gain at the top")
		expect(row(1, 0.99, 16), "15,15,1,Loss", "loss at the top")
		expect(row(0, 0.01, 16), "0,0,1,Gain", "gain at the bottom")
		expect(row(0.01, 0, 16), "0,0,1,Loss", "loss at the bottom")
	end)

	case("_deltaText: sign, whole and fractional values, suffix", function()
		expect(Data._deltaText(3), "+3", "gain")
		expect(Data._deltaText(-2), "-2", "loss")
		expect(Data._deltaText(100), "+100", "three digits")
		expect(Data._deltaText(1.5, "%"), "+1.5%", "fraction and suffix")
		expect(Data._deltaText(-0.5), "-0.5", "negative fraction")
		expect(Data._deltaText(4, ""), "+4", "empty suffix")
	end)

	case("_statRow: bar fractions, value text and delta", function()
		local plain = Data._statRow({ Id = "a", Label = "Speed", Value = 77 })
		expect(plain.Value, 77 / 100, "value fraction")
		expect(plain.Preview, false, "no preview")
		expect(plain.Text, "77", "text")
		expect(plain.Delta, 0, "delta")
		local gain = Data._statRow({ Id = "b", Label = "Handling", Value = 63, Preview = 66 })
		expect(gain.Value, 63 / 100, "current on the bar")
		expect(gain.Preview, 66 / 100, "preview on the bar")
		expect(gain.Text, "66", "the previewed number is printed")
		expect(gain.Delta, 3, "delta")
		local scaled = Data._statRow({ Id = "c", Label = "Boost", Value = 320, Max = 400, Preview = 250 })
		expect(scaled.Value, 0.8, "Max")
		expect(scaled.Preview, 0.625, "Max on the preview")
		expect(scaled.Delta, -70, "loss")
		local over = Data._statRow({ Id = "d", Label = "Speed", Value = 140 })
		expect(over.Value, 1, "clamped")
		expect(over.Text, "140", "text is not clamped")
		expect(Data._statRow({ Id = "e", Label = "Braking", Value = 50, Text = "N/A" }).Text, "N/A", "Text wins")
		expect(Data._statRow({ Id = "f", Label = "Drift", Value = 71.6 }).Text, "72", "rounded")
	end)

	case("_statusParts: what each mode shows", function()
		local vehicle = Data._statusParts({ Mode = "Vehicle", Tier = "S", Rating = 939, Rank = 6 }, false)
		expect(vehicle.Strip, true, "strip")
		expect(vehicle.Icon, "car", "car icon")
		expect(vehicle.Badge, true, "badge")
		expect(vehicle.Text, nil, "no text")
		expect(vehicle.Rank, true, "rank")
		local onFoot = Data._statusParts({ Mode = "Vehicle", Label = "On foot", Rank = 6 }, false)
		expect(onFoot.Badge, false, "no badge")
		expect(onFoot.Icon, "passenger", "on-foot icon")
		expect(onFoot.Text, "On foot", "label")
		local garage = Data._statusParts({ Mode = "Garage", Spaces = "3 / 4", ShowPlus = true, Rank = 6 }, false)
		expect(garage.Icon, "garage", "garage icon")
		expect(garage.Text, "3 / 4", "spaces")
		expect(garage.Plus, true, "spaces plus")
		expect(Data._statusParts({ Mode = "Garage", Spaces = "3 / 4" }, false).Plus, false, "no plus unless asked")
		expect(Data._statusParts({ Mode = "Vehicle", Tier = "S", ShowPlus = true }, false).Plus, false, "no spaces plus on Vehicle")
		expect(Data._statusParts({ Mode = "Garage", Spaces = "0 / 2", Rank = 6 }, true).Rank, false, "no rank ring on Compact")
		expect(Data._statusParts({ Mode = "Vehicle", Tier = "S" }, false).Rank, false, "no rank without a number")
		expect(Data._statusParts({ Mode = "CashOnly", Tier = "S", Rank = 6 }, false).Strip, false, "CashOnly has no strip")
	end)

	-- Shared constructor checks (API1 13) --------------------------------------------------------------

	local function common(name, constructor, ctx, props, budget, skipName)
		case(name .. ": builds detached within budget " .. budget .. ", Set and Destroy", function()
			local component, parent, scope = build(constructor, ctx, props)
			local root = component.Instance
			expect(root.Parent, parent, "root parent")
			expect(#parent:GetChildren(), 1, "one root")
			local skip = skipName and root:FindFirstChild(skipName) or nil
			local count = countInstances(root, skip)
			if count > budget then
				error("budget " .. budget .. " exceeded: " .. count)
			end

			local before = snapshot(root)
			component.Set(table.clone(props))
			expect(snapshot(root), before, "unchanged Set")

			expect(pcall(component.Set, { Nope = true }), false, "Set unknown key")
			local bad = table.clone(props)
			bad.Nope = true
			expect(pcall(constructor, parent, bad, scope), false, "constructor unknown key")
			expect(#parent:GetChildren(), 1, "failed constructor leaves nothing")

			component.Set({ LayoutOrder = 7, Name = "Renamed" })
			expect(root.LayoutOrder, 7, "LayoutOrder")
			expect(root.Name, "Renamed", "Name")
			component.Set({ Visible = false })
			expect(root.Visible, false, "Visible")

			component.Destroy()
			expect(#parent:GetChildren(), 0, "parent empty after Destroy")
			component.Destroy()
			component.Set({ Visible = true })
			scope:destroy()
		end)
	end

	local SIX_ROWS = {
		{ Id = "Speed", Label = "Speed", Value = 80 },
		{ Id = "Accel", Label = "Accel", Value = 74 },
		{ Id = "Handling", Label = "Handling", Value = 63, Preview = 66 },
		{ Id = "Drift", Label = "Drift", Value = 61, Preview = 63 },
		{ Id = "Braking", Label = "Braking", Value = 62 },
		{ Id = "Boost", Label = "Boost", Value = 61, Preview = 59 },
	}
	local FACTS = {
		{ Id = "Route", Icon = "route", Label = "Route", Value = "Circuit" },
		{ Id = "Laps", Icon = "loop", Label = "Laps", Value = "3" },
		{ Id = "Players", Icon = "players", Label = "Players", Value = "2 to 6" },
		{ Id = "Prize", Label = "Prize", Value = "$10,000", Kind = "Prize" },
	}
	local function nothing() end

	common("SegmentedBar", Data.SegmentedBar, r1080, { Value = 0.77 }, 4)
	common("SegmentedBar preview (Compact)", Data.SegmentedBar, c844, { Value = 0.6, Preview = 0.7, Segments = 8 }, 4)
	common("DeltaChip gain", Data.DeltaChip, r1080, { Delta = 3 }, 3)
	common("DeltaChip loss (Compact)", Data.DeltaChip, c844, { Delta = -2, Suffix = "%" }, 3)
	common("CashChip", Data.CashChip, r1080, { Compact = false }, 6)
	common("CashChip with plus (Compact)", Data.CashChip, c844, { Plus = true, OnPlus = nothing }, 6)
	common("StatusCluster Vehicle", Data.StatusCluster, r1080, { Mode = "Vehicle", Tier = "S", Rating = 939, Rank = 6 }, 20, "Cash")
	common("StatusCluster Garage", Data.StatusCluster, r720,
		{ Mode = "Garage", Spaces = "3 / 4", Rank = 6, ShowPlus = true, OnSpacesPlus = nothing, OnCashPlus = nothing }, 20, "Cash")
	common("StatusCluster Garage (Compact)", Data.StatusCluster, c844, { Mode = "Garage", Spaces = "0 / 2" }, 20, "Cash")
	common("StatusCluster CashOnly (Compact)", Data.StatusCluster, c844, { Mode = "CashOnly" }, 20, "Cash")
	common("StatPanel", Data.StatPanel, r1080,
		{ Title = "Stinger", Tier = "D", Rating = 321, Sub = { "Fitted wing  Spine Wing Standard", "Previewing  Spine Wing EVO" }, Rows = SIX_ROWS },
		12 + 12 * #SIX_ROWS)
	common("StatPanel (Compact)", Data.StatPanel, c844,
		{ Title = "Zephyr", Tier = "D", Rating = 390, Rows = SIX_ROWS, Price = "$150,000" }, 12 + 12 * #SIX_ROWS)
	common("StatPanel empty", Data.StatPanel, r720, { Title = "" }, 12)
	common("FactList", Data.FactList, r1080, { Rows = FACTS }, 2 + 6 * #FACTS)
	common("FactList (Compact)", Data.FactList, c844, { Rows = FACTS, Width = 200 }, 2 + 6 * #FACTS)

	-- SegmentedBar -------------------------------------------------------------------------------------

	case("SegmentedBar: four instances, tiled strips, whole-segment widths", function()
		local bar, _, scope = build(Data.SegmentedBar, r1080, { Value = 0.77 })
		local root = bar.Instance
		expect(1 + #root:GetDescendants(), 4, "instances")
		local pitch = r1080.Px(Tokens.Space.SegmentWidth + Tokens.Space.SegmentGap)
		local height = r1080.Px(Tokens.Space.SegmentHeight)
		expect(root.Size, UDim2.fromOffset(16 * pitch, height), "root: 16 segments")
		expect(root.Empty.Size, UDim2.fromOffset(16 * pitch, height), "empty strip")
		expect(root.Empty.ScaleType, Enum.ScaleType.Tile, "tiled")
		expect(root.Empty.TileSize, UDim2.new(0, pitch, 1, 0), "tile = one segment and its gap")
		expect(root.Empty.ImageColor3, Tokens.Colour.White, "empty colour")
		if math.abs(root.Empty.ImageTransparency - (1 - Tokens.Opacity.SegmentEmpty)) > 1e-4 then
			error("empty transparency " .. root.Empty.ImageTransparency)
		end
		expect(root.Fill.Size, UDim2.fromOffset(12 * pitch, height), "fill: 12 whole segments")
		expect(root.Fill.Image, Tokens.Asset("SegmentStrip") or "", "strip image")
		expect(root.Gain.Visible, false, "no preview")

		bar.Set({ Preview = 0.9 })
		expect(1 + #root:GetDescendants(), 4, "still four")
		expect(root.Gain.Visible, true, "gain shown")
		expect(root.Gain.Position, UDim2.fromOffset(12 * pitch, 0), "gain starts after the fill")
		expect(root.Gain.Size, UDim2.fromOffset(2 * pitch, height), "gain: 2 segments")
		expect(root.Gain.ImageColor3, Tokens.Colour.Cyan, "gain is Cyan")

		bar.Set({ Preview = 0.5 })
		expect(root.Fill.Size, UDim2.fromOffset(8 * pitch, height), "loss: fill stops at the preview")
		expect(root.Gain.Position, UDim2.fromOffset(8 * pitch, 0), "loss starts at the preview")
		expect(root.Gain.Size, UDim2.fromOffset(4 * pitch, height), "loss: 4 segments")
		expect(root.Gain.ImageColor3, Tokens.Colour.Pink, "loss is Pink")

		bar.Set({ PreviewColour = "Cyan" })
		expect(root.Gain.ImageColor3, Tokens.Colour.Cyan, "PreviewColour wins")
		bar.Set({ Preview = false })
		expect(root.Gain.Visible, false, "false clears the preview")
		expect(root.Fill.Size, UDim2.fromOffset(12 * pitch, height), "fill back at the value")

		bar.Set({ Segments = 8 })
		expect(root.Size, UDim2.fromOffset(8 * pitch, height), "8 segments")
		bar.Set({ Value = 0 })
		expect(root.Fill.Visible, false, "empty value hides the fill")

		expect(pcall(bar.Set, { Value = "half" }), false, "Value type")
		expect(pcall(bar.Set, { PreviewColour = "Yellow" }), false, "PreviewColour")
		expect(pcall(bar.Set, { Segments = 0 }), false, "Segments")
		bar.Destroy()
		scope:destroy()
	end)

	-- DeltaChip ----------------------------------------------------------------------------------------

	case("DeltaChip: Cyan and up for a gain, Pink and down for a loss, hidden at zero", function()
		local chip, _, scope = build(Data.DeltaChip, r1080, { Delta = 3 })
		local root = chip.Instance
		expect(root.Visible, true, "shown")
		expect(root.BackgroundColor3, Tokens.Colour.Cyan, "gain colour")
		expect(root.Label.Text, "+3", "gain text")
		local upGlyph = root.Arrow.ImageRectOffset
		chip.Set({ Delta = -2 })
		expect(root.BackgroundColor3, Tokens.Colour.Pink, "loss colour")
		expect(root.Label.Text, "-2", "loss text")
		expect(root.Arrow.ImageRectOffset ~= upGlyph, true, "the arrow turns: colour is not the only signal")
		chip.Set({ Delta = 0 })
		expect(root.Visible, false, "hidden at zero")
		chip.Set({ Delta = 1, Visible = false })
		expect(root.Visible, false, "Visible = false wins")
		chip.Set({ Visible = true })
		expect(root.Visible, true, "shown again")
		expect(pcall(chip.Set, { Delta = "3" }), false, "Delta type")
		chip.Destroy()
		scope:destroy()
	end)

	-- CashChip -----------------------------------------------------------------------------------------

	case("CashChip: no money is formatted at build; SetAmount prints through the shared formatter", function()
		table.clear(calls)
		local chip, _, scope = build(Data.CashChip, r1080, { Compact = false })
		local label = chip.Instance.Amount
		expect(#calls, 0, "the constructor formats nothing (it may not yield)")
		expect(label.Text, "", "empty until an amount arrives")
		expect(chip.Instance:FindFirstChildOfClass("UIGradient") ~= nil, true, "Yellow gradient")
		expect(label.TextColor3, Tokens.Colour.Ink, "Ink text")
		expect(chip.Instance.Coin ~= nil, true, "coin icon")

		chip.SetAmount(3613709)
		expect(label.Text, "F$3613709", "full form")
		chip.Set({ Compact = true })
		expect(label.Text, "C$3613709", "short form")
		chip.Set({ Compact = false, FreeRoam = true })
		expect(label.Text, "R$3613709", "free-roam form")
		expect(pcall(chip.SetAmount, "lots"), false, "SetAmount type")
		chip.Destroy()
		scope:destroy()
	end)

	case("CashChip: the default form follows the class", function()
		local regular, _, scopeA = build(Data.CashChip, r1080, {})
		local compact, _, scopeB = build(Data.CashChip, c844, {})
		regular.SetAmount(5)
		compact.SetAmount(5)
		expect(regular.Instance.Amount.Text, "F$5", "Regular: full")
		expect(compact.Instance.Amount.Text, "C$5", "Compact: short")
		expect(regular.Instance.Size.Y.Offset, r1080.Px(Tokens.Space.StatusHeight), "Regular height")
		expect(compact.Instance.Size.Y.Offset, c844.Px(Tokens.Space.CompactStatusHeight), "Compact height")
		regular.Destroy()
		compact.Destroy()
		scopeA:destroy()
		scopeB:destroy()
	end)

	case("CashChip: the plus is a real button, built on first use, within budget", function()
		local pressed = 0
		local chip, _, scope = build(Data.CashChip, r1080, { Compact = false })
		expect(chip.Instance:FindFirstChild("Plus"), nil, "no plus yet")
		chip.Set({ Plus = true, OnPlus = function()
			pressed += 1
		end })
		local plus = chip.Instance:FindFirstChild("Plus")
		expect(plus ~= nil and plus:IsA("GuiButton"), true, "plus button")
		expect(plus.Visible, true, "shown")
		if countInstances(chip.Instance) > 6 then
			error("budget 6 exceeded: " .. countInstances(chip.Instance))
		end
		chip.Set({ Plus = false })
		expect(plus.Visible, false, "hidden, not destroyed")
		expect(plus.Parent, chip.Instance, "kept")
		chip.Destroy()
		scope:destroy()
	end)

	case("CashChip (Compact): the plus hit box is at least 48 dp", function()
		local chip, _, scope = build(Data.CashChip, c844, { Plus = true, OnPlus = nothing })
		local plus = chip.Instance.Plus
		if plus.Size.X.Offset < Tokens.Space.TouchMin or plus.Size.Y.Offset < Tokens.Space.TouchMin then
			error("plus hit box " .. tostring(plus.Size))
		end
		chip.Destroy()
		scope:destroy()
	end)

	case("CashChip.Bind: presenter and leaderstats binding from the foundation, released through scope", function()
		table.clear(presenters)
		table.clear(bindings)
		local player = { Name = "FakePlayer" }
		local chip, _, scope = build(Data.CashChip, r1080, { Compact = false })
		local label = chip.Instance.Amount
		chip.Bind(player)
		expect(#presenters, 1, "one presenter")
		expect(#bindings, 1, "one binding")
		local presenter, binding = presenters[1], bindings[1]
		expect(binding.Player, player, "bound to the given player")
		expect(presenter.BadSelf, false, "SetTarget is called as a method")
		expect(presenter.Targets[1], 100, "the replicated value reaches SetTarget untouched")
		expect(presenter.Options, nil, "Classic presenter options are not overridden")
		expect(label.Text, "F$100", "the label shows the presenter's figure")

		-- A count: the presenter renders (displayed, authoritative). The chip prints what it is given.
		local widthBefore = chip.Instance.Size.X.Offset
		presenter.Render(150, 200)
		expect(label.Text, "F$150", "mid-count figure")
		if chip.Instance.Size.X.Offset < widthBefore then
			error("the chip shrank during a count")
		end
		local counting = snapshot(chip.Instance)
		presenter.Render(150, 200)
		expect(snapshot(chip.Instance), counting, "same figure writes nothing")
		presenter.Render(200, 200)
		expect(label.Text, "F$200", "final figure")

		binding.Callback(250, nil)
		expect(presenter.Targets[2], 250, "later values go to the same presenter")
		expect(label.Text, "F$250", "label follows")

		scope:destroy()
		expect(binding.Disconnected, true, "binding released by the scope")
		expect(presenter.Destroyed, true, "presenter released by the scope")
		chip.Destroy()
	end)

	case("CashChip.Bind: binding again or Destroy releases the earlier binding", function()
		table.clear(presenters)
		table.clear(bindings)
		local chip, _, scope = build(Data.CashChip, c844, {})
		chip.Bind({ Name = "A" })
		chip.Bind({ Name = "B" })
		expect(#bindings, 2, "two bindings made")
		expect(bindings[1].Disconnected, true, "first released")
		expect(presenters[1].Destroyed, true, "first presenter released")
		expect(bindings[2].Disconnected, false, "second live")
		chip.Destroy()
		expect(bindings[2].Disconnected, true, "released by Destroy")
		expect(presenters[2].Destroyed, true, "presenter released by Destroy")
		presenters[2].Render(999, 999)
		chip.Bind({ Name = "C" })
		expect(#bindings, 2, "a destroyed chip binds nothing")
		scope:destroy()
	end)

	-- StatusCluster ------------------------------------------------------------------------------------

	case("StatusCluster: embeds the cash chip and shows the mode's parts", function()
		local cluster, _, scope = build(Data.StatusCluster, r1080, { Mode = "Vehicle", Tier = "S", Rating = 939, Rank = 6 })
		local root = cluster.Instance
		expect(type(cluster.Cash), "table", "cluster.Cash")
		expect(cluster.Cash.Instance:IsDescendantOf(root), true, "the chip is inside")
		expect(type(cluster.Cash.Bind), "function", "the chip binds")
		expect(root.Size.Y.Offset, r1080.Px(Tokens.Space.StatusHeight) + 2 * r1080.Px(Tokens.Space.StatusPad), "strip height")
		expect(root.Plate.Visible, true, "slate strip")
		expect(root.Plate.BackgroundColor3, Tokens.Colour.Slate, "slate")
		expect(root:FindFirstChild("TierBadge") ~= nil, true, "tier badge")
		expect(root.Rank.Text, "6", "rank number")
		expect(root.Divider.Visible, true, "divider")
		expect(cluster.Cash.Instance.Position.Y.Offset, r1080.Px(Tokens.Space.StatusPad), "chip inside the pad")

		cluster.Cash.SetAmount(3613709)
		expect(cluster.Cash.Instance.Amount.Text, "F$3613709", "cash through the chip")
		local right = cluster.Cash.Instance.Position.X.Offset + cluster.Cash.Instance.Size.X.Offset
		expect(root.Size.X.Offset, right + r1080.Px(Tokens.Space.StatusPad), "the strip ends one pad after the chip")

		cluster.SetRank(12)
		expect(root.Rank.Text, "12", "SetRank")
		cluster.SetRank(nil)
		expect(root.Rank.Visible, false, "no rank")
		expect(root.Divider.Visible, false, "no divider without a rank")

		cluster.SetVehicle(nil, nil)
		expect(root.TierBadge.Visible, false, "on foot: badge hidden")
		cluster.SetVehicle("C", 540)
		expect(root.TierBadge.Visible, true, "badge back")
		expect(pcall(cluster.SetVehicle, "Z", 1), false, "unknown tier")
		cluster.Destroy()
		scope:destroy()
	end)

	case("StatusCluster: Garage shows spaces and both plus buttons; CashOnly is the chip alone", function()
		local spaces, cash = 0, 0
		local cluster, _, scope = build(Data.StatusCluster, r1080, {
			Mode = "Garage", Spaces = "3 / 4", Rank = 6, ShowPlus = true,
			OnSpacesPlus = function()
				spaces += 1
			end,
			OnCashPlus = function()
				cash += 1
			end,
		})
		local root = cluster.Instance
		expect(root.Info.Text, "3 / 4", "spaces")
		expect(root:FindFirstChild("SpacesPlus") ~= nil, true, "spaces plus")
		expect(root.SpacesPlus:IsA("GuiButton"), true, "a real button")
		expect(cluster.Cash.Instance:FindFirstChild("Plus") ~= nil, true, "cash plus")
		expect(root:FindFirstChild("TierBadge"), nil, "no badge was ever built")
		if countInstances(root, cluster.Cash.Instance) > 20 then
			error("budget 20 exceeded: " .. countInstances(root, cluster.Cash.Instance))
		end

		cluster.SetSpaces("4 / 4")
		expect(root.Info.Text, "4 / 4", "SetSpaces")
		local settled = snapshot(root)
		cluster.SetSpaces("4 / 4")
		expect(snapshot(root), settled, "same spaces writes nothing")

		local before = instanceSet(root)
		cluster.Set({ Mode = "CashOnly" })
		expect(root.Plate.Visible, false, "no strip")
		expect(root.Info.Visible, false, "no spaces")
		expect(root.SpacesPlus.Visible, false, "no spaces plus")
		expect(root.Size, cluster.Cash.Instance.Size, "the root is the chip")
		expect(cluster.Cash.Instance.Position, UDim2.fromOffset(0, 0), "chip at the origin")
		expect(sameSet(before, instanceSet(root)), true, "a mode change creates and destroys nothing")
		expect(pcall(cluster.Set, { Mode = "Wallet" }), false, "unknown Mode")
		cluster.Destroy()
		scope:destroy()
	end)

	-- StatPanel ----------------------------------------------------------------------------------------

	case("StatPanel: header, pooled rows, bars, value cells and delta chips", function()
		local panel, _, scope = build(Data.StatPanel, r1080, {
			Title = "Stinger", Tier = "D", Rating = 321, Sub = { "Fitted wing  Spine Wing Standard" }, Rows = SIX_ROWS,
		})
		local root = panel.Instance
		local content = root:FindFirstChild("Content")
		expect(content ~= nil, true, "a Surface.Panel root")
		expect(root.Size, UDim2.fromOffset(r1080.Px(Tokens.Space.StatPanelWidth), r1080.Px(Tokens.Space.StatPanelHeight)), "token size")
		expect(content.Title.Text, "STINGER", "title")
		expect(content.Sub1.Text, "Fitted wing  Spine Wing Standard", "sub-line as given")
		expect(content.Sub1.Visible, true, "sub 1 shown")
		expect(content.Sub2.Visible, false, "sub 2 hidden")
		expect(content.Price.Visible, false, "no price row on Regular")
		expect(content:FindFirstChild("TierBadge") ~= nil, true, "badge")
		for index, row in SIX_ROWS do
			local frame = content:FindFirstChild("Row" .. index)
			expect(frame ~= nil and frame.Visible, true, "row " .. index)
			expect(frame.Label.Text, string.upper(row.Label), "label " .. index)
			expect(frame.Value.Text, tostring(row.Preview or row.Value), "value " .. index)
			expect(1 + #frame.Bar:GetDescendants(), 4, "bar instances " .. index)
			expect(frame.Delta.Visible, row.Preview ~= nil, "delta chip " .. index)
		end
		expect(content.Row3.Delta.Label.Text, "+3", "gain chip")
		expect(content.Row6.Delta.Label.Text, "-2", "loss chip")
		expect(content.Row6.Delta.BackgroundColor3, Tokens.Colour.Pink, "loss is Pink")
		expect(content.Row3.Bar.Gain.Visible, true, "previewed segments")
		expect(content.Row1.Bar.Gain.Visible, false, "no preview on a plain row")
		-- Every bar has the same whole number of segments and ends before the value cell.
		local pitch = r1080.Px(Tokens.Space.SegmentWidth + Tokens.Space.SegmentGap)
		local barWidth = content.Row1.Bar.Size.X.Offset
		expect(barWidth % pitch, 0, "whole segments")
		if barWidth > 16 * pitch or barWidth < pitch then
			error("bar width " .. barWidth)
		end
		if content.Row1.Bar.Position.X.Offset + barWidth > content.Row1.Value.Position.X.Offset then
			error("the bar runs into the value cell")
		end
		panel.Destroy()
		scope:destroy()
	end)

	case("StatPanel.SetRows: unchanged ids update in place; nothing is created or destroyed", function()
		local panel, _, scope = build(Data.StatPanel, r1080, { Title = "Stinger", Tier = "D", Rating = 321, Rows = SIX_ROWS })
		local root = panel.Instance
		local content = root.Content
		panel.SetRows(SIX_ROWS)
		local before = instanceSet(root)
		local settled = snapshot(root)
		panel.SetRows(SIX_ROWS)
		expect(snapshot(root), settled, "same rows write nothing")

		local changed = table.clone(SIX_ROWS)
		changed[1] = { Id = "Speed", Label = "Speed", Value = 80, Preview = 84 }
		changed[3] = { Id = "Handling", Label = "Handling", Value = 63 }
		panel.SetRows(changed)
		expect(sameSet(before, instanceSet(root)), true, "same instances")
		expect(content.Row1.Value.Text, "84", "row 1 value")
		expect(content.Row1.Delta.Visible, true, "row 1 chip shown")
		expect(content.Row1.Delta.Label.Text, "+4", "row 1 chip")
		expect(content.Row3.Value.Text, "63", "row 3 value")
		expect(content.Row3.Delta.Visible, false, "row 3 chip hidden")
		expect(content.Row3.Bar.Gain.Visible, false, "row 3 preview cleared")

		panel.SetRows({ SIX_ROWS[1], SIX_ROWS[2] })
		expect(sameSet(before, instanceSet(root)), true, "fewer rows destroy nothing")
		expect(content.Row2.Visible, true, "row 2 shown")
		expect(content.Row3.Visible, false, "row 3 hidden")
		panel.SetRows(SIX_ROWS)
		expect(sameSet(before, instanceSet(root)), true, "back to six: pool reused")
		expect(content.Row6.Visible, true, "row 6 shown again")

		expect(pcall(panel.SetRows, { { Id = "x", Label = "Speed" } }), false, "a row needs a Value")
		expect(pcall(panel.SetRows, "rows"), false, "rows must be a list")
		panel.Destroy()
		scope:destroy()
	end)

	case("StatPanel.SetHeader: replaces the header in place", function()
		local panel, _, scope = build(Data.StatPanel, r1080, {
			Title = "Stinger", Tier = "D", Rating = 321, Sub = { "One", "Two" }, Rows = SIX_ROWS,
		})
		local content = panel.Instance.Content
		expect(content.Sub2.Visible, true, "two sub-lines")
		panel.SetHeader({ Title = "Zephyr", Tier = "C", Rating = 540, Sub = { "Exotic" } })
		expect(content.Title.Text, "ZEPHYR", "title")
		expect(content.Sub1.Text, "Exotic", "sub 1")
		expect(content.Sub2.Visible, false, "sub 2 cleared")
		expect(content.TierBadge.Visible, true, "badge kept")
		panel.SetHeader({})
		expect(content.Title.Text, "ZEPHYR", "a missing Title keeps the old one")
		expect(content.TierBadge.Visible, false, "a missing Tier clears the badge")
		expect(content.Sub1.Visible, false, "a missing Sub clears the lines")
		expect(pcall(panel.SetHeader, { Tier = "Z" }), false, "unknown tier")
		expect(pcall(panel.SetHeader, "Zephyr"), false, "needs a table")
		panel.Destroy()
		scope:destroy()
	end)

	case("StatPanel (Compact): collapsed form with a price row and a fitted height", function()
		local panel, _, scope = build(Data.StatPanel, c844, {
			Title = "Zephyr", Tier = "D", Rating = 390, Sub = { "Exotic" }, Rows = SIX_ROWS, Price = "$150,000",
		})
		local root = panel.Instance
		local content = root.Content
		expect(root.Size.X.Offset, c844.Px(Tokens.Space.CompactStatPanelWidth), "Compact width")
		expect(content.Sub1.Visible, false, "no sub-lines")
		expect(content.Price.Visible, true, "price row")
		expect(content.Price.Text, "$150,000", "the price string is printed as given")
		expect(content.Price.BackgroundColor3, Tokens.Colour.Yellow, "Yellow chip")
		expect(content.PriceLabel.Text, "PRICE", "price label")
		local bar = content.Row1.Bar
		local pitch = c844.Px((Tokens.Space.SegmentWidth + Tokens.Space.SegmentGap) * Tokens.Space.TouchGap / Tokens.Space.Pad)
		if bar.Size.X.Offset > 8 * pitch then
			error("Compact bar wider than 8 segments: " .. bar.Size.X.Offset)
		end
		local last = content.Row6
		local bottom = last.Position.Y.Offset + last.Size.Y.Offset
		local pad = content.Position.Y.Offset
		expect(root.Size.Y.Offset, bottom + 2 * pad, "the panel ends one pad under the last row")
		panel.Set({ Price = "$4.4M" })
		expect(content.Price.Text, "$4.4M", "Set Price")
		panel.Destroy()
		scope:destroy()
	end)

	-- FactList -----------------------------------------------------------------------------------------

	case("FactList: icon and label left, value right, dividers between rows, Prize on a Yellow chip", function()
		local list, _, scope = build(Data.FactList, r1080, { Rows = FACTS, Width = 560 })
		local root = list.Instance
		local rowHeight = r1080.Px(Tokens.Space.FactRowHeight)
		expect(root.Size, UDim2.fromOffset(r1080.Px(560), #FACTS * rowHeight), "size")
		for index, row in FACTS do
			local frame = root:FindFirstChild("Row" .. index)
			expect(frame ~= nil and frame.Visible, true, "row " .. index)
			expect(frame.Position, UDim2.fromOffset(0, (index - 1) * rowHeight), "row place " .. index)
			expect(frame.Label.Text, string.upper(row.Label), "label " .. index)
			expect(frame.Value.Text, string.upper(row.Value), "value " .. index)
			expect(frame:FindFirstChild("Icon") ~= nil, row.Icon ~= nil, "icon " .. index)
			expect(frame.Divider.Visible, index < #FACTS, "divider " .. index)
		end
		expect(root.Row1.Value.BackgroundTransparency, 1, "a text value has no plate")
		expect(root.Row1.Value.TextXAlignment, Enum.TextXAlignment.Right, "text value is right-aligned")
		expect(root.Row4.Value.BackgroundTransparency, 0, "prize chip")
		expect(root.Row4.Value.BackgroundColor3, Tokens.Colour.Yellow, "prize chip is Yellow")
		expect(root.Row4.Value.TextColor3, Tokens.Colour.Ink, "prize text is Ink")
		expect(root.Row4.Label.Position.X.Offset, 0, "a row without an icon starts at the edge")
		if root.Row1.Label.Position.X.Offset <= 0 then
			error("a row with an icon is indented")
		end
		list.Destroy()
		scope:destroy()
	end)

	-- Mobile pass round 2 (API2 amendment A17).
	case("factSplit: the value keeps its width, the label has the rest less a gap, nothing passes the row", function()
		local box, inset, shown = Data._factSplit(300, 0, 80, 10)
		expect(box, 80, "a value that fits keeps its width")
		expect(inset, 90, "the label gives up the value and a gap")
		expect(shown, true, "the label shows")
		box, inset, shown = Data._factSplit(300, 40, 80, 10)
		expect(inset, 130, "the icon inset counts")
		box, inset, shown = Data._factSplit(200, 40, 500, 10)
		expect(box, 160, "a value wider than the row is cut to the row less the icon")
		expect(shown, false, "no room is left for the label")
		box, inset, shown = Data._factSplit(0, 40, 500, 10)
		expect(box, 500, "an unmeasured row cuts nothing")
		expect(shown, true, "an unmeasured row shows the label")
	end)

	case("FactList: the label ends before the value and both end in an ellipsis", function()
		local rows = {
			{ Id = "Laps", Icon = "loop", Label = "Laps and checkpoints", Value = "3 / 17 checkpoints" },
			{ Id = "Prize", Label = "Platinum prize", Value = "$1,250,000", Kind = "Prize" },
		}
		local list, _, scope = build(Data.FactList, c844, { Rows = rows, Width = 176 })
		local root = list.Instance
		local gap = c844.Px(Tokens.Space.Gap * Tokens.Space.TouchGap / Tokens.Space.Pad)
		for index = 1, #rows do
			local frame = root:FindFirstChild("Row" .. index)
			local label, value = frame.Label, frame.Value
			expect(label.TextTruncate, Enum.TextTruncate.AtEnd, "label truncation " .. index)
			expect(value.TextTruncate, Enum.TextTruncate.AtEnd, "value truncation " .. index)
			expect(label.Size.X.Scale, 1, "the label follows the row width " .. index)
			local drawn = index == 2 and value.Size.X.Offset or math.ceil(value.TextBounds.X)
			expect(label.Size.X.Offset, -(label.Position.X.Offset + drawn + gap), "the label ends a gap before the value " .. index)
			if value.Size.X.Scale == 0 and value.Size.X.Offset > c844.Px(176) then
				error("the prize chip is wider than the row")
			end
		end
		list.Destroy()
		scope:destroy()
	end)

	case("FactList.SetRows: pooled; the same rows write nothing", function()
		local list, _, scope = build(Data.FactList, r1080, { Rows = FACTS, Width = 560 })
		local root = list.Instance
		list.SetRows(FACTS)
		local before = instanceSet(root)
		local settled = snapshot(root)
		list.SetRows(FACTS)
		expect(snapshot(root), settled, "same rows write nothing")

		local changed = table.clone(FACTS)
		changed[2] = { Id = "Laps", Icon = "loop", Label = "Laps", Value = "5" }
		list.SetRows(changed)
		expect(sameSet(before, instanceSet(root)), true, "same instances")
		expect(root.Row2.Value.Text, "5", "value updated")

		list.SetRows({ FACTS[1] })
		expect(sameSet(before, instanceSet(root)), true, "fewer rows destroy nothing")
		expect(root.Row2.Visible, false, "row 2 hidden")
		expect(root.Row1.Divider.Visible, false, "the last row has no divider")
		expect(root.Size.Y.Offset, r1080.Px(Tokens.Space.FactRowHeight), "one row high")
		list.SetRows({})
		expect(root.Row1.Visible, false, "empty")

		expect(pcall(list.SetRows, { { Id = "x", Label = "Laps" } }), false, "a row needs a Value")
		expect(pcall(list.SetRows, { { Id = "x", Label = "Laps", Value = "3", Kind = "Gold" } }), false, "unknown Kind")
		expect(pcall(list.Set, { Width = "wide" }), false, "Width type")
		list.Destroy()
		scope:destroy()
	end)

	-- Put the seam back (API1 13).
	Data._foundation = realFoundation

	return results
end
