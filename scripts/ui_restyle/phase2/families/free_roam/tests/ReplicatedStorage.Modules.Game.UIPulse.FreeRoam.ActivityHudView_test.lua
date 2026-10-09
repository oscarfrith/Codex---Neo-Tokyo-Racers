-- Pure tests for FreeRoam.ActivityHudView: the colour-to-role mapping, button order, countdown and timer rules, and
-- the view mounted on a detached stage at R1080 and C844 over a fake model. Nothing is parented into the game tree.
return function(M, env)
	local results = {}
	local KIT = "ReplicatedStorage.Modules.Game.UIPulse.Kit."

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end
	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end
	local function newScope()
		if env.Scope then return env.Scope() end
		local items = {}
		local scope = {}
		function scope:connect(signal, callback)
			local connection = signal:Connect(callback)
			table.insert(items, connection)
			return connection
		end
		function scope:add(item) table.insert(items, item); return item end
		function scope:destroy()
			for _, item in ipairs(items) do
				if typeof(item) == "RBXScriptConnection" or (type(item) == "table" and item.Disconnect) then item:Disconnect() end
			end
		end
		return scope
	end

	local Tokens = env.Load(KIT .. "Tokens")
	local THEME = {
		Telemetry = Tokens.Colour.Cyan, HighSpeed = Tokens.Colour.Pink, ElectricBlue = Tokens.Colour.Violet,
		Muted = Tokens.Colour.TextMuted, Text = Tokens.Colour.White,
	}

	-- A fake model with the getters the view reads; the test sets the fields and calls Render.
	local function fakeModel()
		local model = { Theme = THEME, Now = 0, Server = 0, Pressed = {}, Cancelled = 0 }
		model.Clock = function() return model.Now end
		model.ServerNow = function() return model.Server end
		model.StripEntry = function() return model.StripValue end
		model.OfferState = function() return model.OfferValue end
		model.CountdownState = function() return model.CountdownValue end
		model.RankUpState = function() return model.RankValue end
		model.Cancel = function() model.Cancelled += 1 end
		model.PressOffer = function(record, index) table.insert(model.Pressed, { Record = record, Index = index }) end
		model.CountdownEnded = function(record)
			if model.CountdownValue == record then model.CountdownValue = nil end
			model.Ended = record
		end
		return model
	end

	local function mount(size, touch)
		local Metrics = env.Load(KIT .. "Metrics")
		local Layers = env.Load(KIT .. "Layers")
		local ctx = Metrics.Fixed({ Size = size, TouchEnabled = touch, Input = touch and "Touch" or "KeyboardAndMouse" })
		local stage = env.Detached("Frame")
		stage.Size = UDim2.fromOffset(size.X, size.Y)
		Metrics.Bind(stage, ctx)
		local layer = Layers.Stage(stage, ctx, "Hud")
		local scope = newScope()
		local model = fakeModel()
		local view = M.Mount(layer, model, scope, layer)
		return view, model, layer, scope
	end

	case("_roleOf: theme colours map back to roles by value", function()
		expect(M._roleOf(THEME, THEME.HighSpeed, "Cyan") == "Pink", "HighSpeed")
		expect(M._roleOf(THEME, THEME.Telemetry, "White") == "Cyan", "Telemetry")
		expect(M._roleOf(THEME, THEME.ElectricBlue, "White") == "Violet", "ElectricBlue")
		expect(M._roleOf(THEME, nil, "Cyan") == "Cyan" and M._roleOf(THEME, "x", "White") == "White", "default")
	end)

	case("_variantOf and _orderButtons: accept is main and right-most, a cash stake is Buy, order otherwise kept", function()
		expect(M._variantOf(THEME, THEME.Telemetry) == "Main" and M._variantOf(THEME, THEME.HighSpeed) == "Buy" and M._variantOf(THEME, nil) == "Default", "variants")
		local duel = M._orderButtons(THEME, { { Text = "ACCEPT", Accent = THEME.Telemetry, Enabled = true }, { Text = "DECLINE", Enabled = true } })
		expect(duel[1].Text == "DECLINE" and duel[1].Index == 2 and duel[2].Text == "ACCEPT" and duel[2].Index == 1 and duel[2].Variant == "Main", "accept last, original index kept")
		local stakes = M._orderButtons(THEME, {
			{ Text = "FREE", Enabled = true }, { Text = "$500", Accent = THEME.HighSpeed, Enabled = false }, { Text = "CANCEL", Enabled = true },
		})
		expect(stakes[1].Text == "FREE" and stakes[2].Variant == "Buy" and stakes[2].Disabled == true and stakes[3].Text == "CANCEL", "stake menu order kept")
		expect(stakes[1].Id == "Option1" and stakes[3].Id == "Option3", "ids")
		expect(#M._orderButtons(THEME, nil) == 0, "no buttons")
	end)

	case("_countdown: Classic 203-214", function()
		local kind, whole = M._countdown(2.2)
		expect(kind == "Number" and whole == 3, "ceil")
		kind, whole = M._countdown(500)
		expect(kind == "Number" and whole == 99, "two cells at most")
		expect(M._countdown(0) == "Go" and M._countdown(-0.89) == "Go", "GO! for 0.9 s")
		expect(M._countdown(-0.9) == "Done" and M._countdown(-5) == "Done", "then done")
	end)

	case("_cardWidth: the class width, or the option row plus its two pads when that is wider", function()
		expect(M._cardWidth(650, 400, 22) == 650, "a two-button row keeps the class width")
		expect(M._cardWidth(650, 606, 22) == 650, "a row that just fits")
		expect(M._cardWidth(650, 1030, 22) == 1074, "a five-button stake menu widens the card")
		expect(M._cardWidth(300, 0, 22) == 300, "no row")
	end)

	case("_timerWidth: whole pixels, clamped", function()
		expect(M._timerWidth(600, 0, 15) == 600, "full")
		expect(M._timerWidth(600, 7.5, 15) == 300, "half")
		expect(M._timerWidth(600, 30, 15) == 0, "over")
		expect(M._timerWidth(600, -1, 15) == 600, "before")
		expect(M._timerWidth(600, 1, nil) == 0 and M._timerWidth(600, 1, 0) == 0, "no timeout")
	end)

	for _, preset in ipairs({ { Name = "R1080", Size = Vector2.new(1920, 1080), Touch = false }, { Name = "C844", Size = Vector2.new(844, 390), Touch = true } }) do
		local tag = " at " .. preset.Name

		case("Mount: the four reserved names exist and everything starts hidden" .. tag, function()
			local view, _model, layer, scope = mount(preset.Size, preset.Touch)
			for _, name in ipairs({ "JobStrip", "Offer", "Countdown", "RankUp" }) do
				local found = layer.Root:FindFirstChild(name, true)
				expect(found ~= nil, name .. " exists")
				expect(found.Visible == false, name .. " starts hidden")
			end
			expect(view.LiveNeeded() == false, "nothing live")
			view.Destroy()
			view.Destroy()
			scope:destroy()
		end)

		case("Strip: shows, updates in place, hides; Render twice creates nothing" .. tag, function()
			local view, model, layer, scope = mount(preset.Size, preset.Touch)
			local strip = layer.Root:FindFirstChild("JobStrip", true)
			model.StripValue = { Kind = "Taxi", Text = "TAXI FARE · NEONRIDER · 1.2 MI", Colour = THEME.Telemetry }
			view.Render("Strip")
			expect(strip.Visible == true, "shown")
			local count = #layer.Root:GetDescendants()
			model.StripValue = { Kind = "Duel", Text = "DUEL VS A VERY LONG DISPLAY NAME INDEED · $5,000", Colour = THEME.HighSpeed }
			view.Render("Strip")
			view.Render("Strip")
			view.Render()
			expect(#layer.Root:GetDescendants() == count, "no instance created or destroyed by a strip change")
			expect(strip:FindFirstChild("Edge", true).BackgroundColor3 == Tokens.Colour.Pink, "HighSpeed gives the pink edge")
			model.StripValue = nil
			view.Render("Strip")
			expect(strip.Visible == false, "hidden")
			view.Destroy()
			scope:destroy()
		end)

		case("Offer: card, one button per option, timer line, close" .. tag, function()
			local view, model, layer, scope = mount(preset.Size, preset.Touch)
			local offer = layer.Root:FindFirstChild("Offer", true)
			local record = {
				Title = "DUEL CHALLENGE", Body = "NEONRIDER challenges you to a street duel for $5,000. Winner takes $10,000.",
				Timeout = 15, StartedAt = 0,
				Buttons = { { Text = "ACCEPT", Accent = THEME.Telemetry, Enabled = true }, { Text = "DECLINE", Enabled = true } },
			}
			model.OfferValue = record
			view.Render("Offer")
			expect(offer.Visible == true and view.LiveNeeded() == true, "shown")
			local options = offer:FindFirstChild("Options", true)
			expect(options ~= nil, "button row built")
			local buttons = 0
			for _, item in ipairs(options:GetDescendants()) do
				if item:IsA("GuiButton") then buttons += 1 end
			end
			expect(buttons == 2, "two buttons, got " .. buttons)
			local fill = offer:FindFirstChild("Timer"):FindFirstChild("Fill")
			model.Now = 7.5
			view._step()
			local half = fill.Size.X.Offset
			expect(fill.Size.X.Scale == 0 and half > 0 and math.abs(half * 2 - offer.Size.X.Offset) <= 1, "timer at half")
			view._step()
			expect(fill.Size.X.Offset == half, "unchanged time writes the same width")
			model.OfferValue = nil
			view.Render("Offer")
			expect(offer.Visible == false and offer:FindFirstChild("Options", true) == nil and view.LiveNeeded() == false, "closed and the row is gone")
			view.Destroy()
			scope:destroy()
		end)

		case("Countdown: number, GO!, then the model is told it ended" .. tag, function()
			local view, model, layer, scope = mount(preset.Size, preset.Touch)
			local countdown = layer.Root:FindFirstChild("Countdown", true)
			local record = { GoAt = 3, Label = "DUEL" }
			model.CountdownValue = record
			view.Render("Countdown")
			expect(countdown.Visible == true, "shown")
			view._step()
			expect(countdown:FindFirstChild("Number").Visible == true and countdown:FindFirstChild("Go").Visible == false, "number phase")
			model.Server = 3.2
			view._step()
			expect(countdown:FindFirstChild("Number").Visible == false and countdown:FindFirstChild("Go").Visible == true, "GO! phase")
			model.Server = 4
			view._step()
			expect(model.Ended == record, "ended once past 0.9 s")
			view.Render("Countdown")
			expect(countdown.Visible == false, "hidden")
			view.Destroy()
			scope:destroy()
		end)

		case("RankUp: Classic rank text, reward only when there is Cash" .. tag, function()
			local Data = env.Load(KIT .. "Data")
			local saved = Data._foundation
			Data._foundation = function()
				local function money(value) return "$" .. tostring(value) end
				return { FormatFullMoney = money, FormatCompactMoney = money, FormatFreeRoamMoney = money }
			end
			local ok, detail = pcall(function()
				local view, model, layer, scope = mount(preset.Size, preset.Touch)
				local card = layer.Root:FindFirstChild("RankUp", true)
				model.RankValue = { Text = "RANK 7", Cash = 5000 }
				view.Render("RankUp")
				expect(card.Visible == true and card:FindFirstChild("RewardRow", true).Visible == true, "shown with a reward")
				model.RankValue = { Text = "RANK 8", Cash = 0 }
				view.Render("RankUp")
				expect(card:FindFirstChild("RewardRow", true).Visible == false, "no reward row without Cash")
				model.RankValue = nil
				view.Render("RankUp")
				expect(card.Visible == false, "hidden")
				view.Destroy()
				scope:destroy()
			end)
			Data._foundation = saved
			if not ok then error(detail, 0) end
		end)

		case("Button and Label: the Classic call shape is accepted" .. tag, function()
			local _view, _model, layer, scope = mount(preset.Size, preset.Touch)
			local button = M.Button(layer.Root, {
				Name = "DuelChallengeButton", Text = "CHALLENGE", Size = UDim2.fromOffset(240, 52),
				Color = THEME.Muted, StrokeColor = THEME.HighSpeed, TextColor = THEME.Text,
			}, scope)
			expect(typeof(button) == "Instance" and button:IsA("TextButton"), "a TextButton root")
			expect(button.Name == "DuelChallengeButton" and button.Parent == layer.Root, "name and parent")
			button.AnchorPoint = Vector2.new(0.5, 1)
			button.Position = UDim2.new(0.5, 0, 1, -120)
			button.Visible = false
			button.Text = "CHALLENGE NEONRIDER"
			expect(button.TextTransparency == 1, "the root never draws its own text")
			local label = M.Label(layer.Root, { Name = "Text", Text = "hello", Role = "Heading", Color = THEME.Muted, XAlignment = Enum.TextXAlignment.Center }, scope, THEME)
			label.Text = "changed"
			label.Visible = false
			expect(label.Name == "Text", "reads fall through to the holder")
			scope:destroy()
		end)
	end

	return results
end
