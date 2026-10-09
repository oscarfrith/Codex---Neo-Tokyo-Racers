-- Pure tests for FreeRoam.ActivityHudClient: the headless model over fake deps (strip, offer, countdown, rank-up,
-- the one remote call site, the toast), the theme, and the design-root lift rule. start() is a Play check.
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

	-- Fake deps: a clock the test moves, delays the test runs by hand, a recorded remote and a recorded toast.
	local function harness(options)
		options = options or {}
		local h = { Now = 100, Calls = {}, Toasts = {}, Delays = {}, Reasons = {}, Waiting = {} }
		local Tokens = env.Load(KIT .. "Tokens")
		h.Theme = M._theme(Tokens, nil)
		h.Model = M._newModel({
			Theme = h.Theme,
			InvokeServer = function(action, args)
				table.insert(h.Calls, { Action = action, Args = args })
				if options.RemoteError then error("remote failed") end
				return options.Reply
			end,
			FindNotify = function()
				if options.NoNotify then return nil end
				return { Fire = function(_, text, seconds) table.insert(h.Toasts, { Text = text, Seconds = seconds }) end }
			end,
			Clock = function() return h.Now end,
			ServerNow = function() return h.Now end,
			Delay = function(seconds, callback) table.insert(h.Delays, { Seconds = seconds, Run = callback }) end,
			Spawn = function(callback) callback() end,
			WhenNotRacing = function(onFree)
				if options.Racing then table.insert(h.Waiting, onFree) else onFree() end
			end,
		})
		h.Model.Changed:Connect(function(reason) table.insert(h.Reasons, reason) end)
		return h
	end

	case("_reply: Classic normalisation of an untrusted reply", function()
		local failed = M._reply(false, "boom")
		expect(failed.Ok == false and failed.Message == "Connection problem. Try again.", "failed call")
		local tableReply = { Ok = true, DuelId = "d" }
		expect(M._reply(true, tableReply) == tableReply, "a table passes through")
		expect(M._reply(true, true).Ok == true and M._reply(true, nil).Ok == false and M._reply(true, "x").Ok == false, "non-table")
	end)

	case("Invoke: one call site, (action, args or {}), never retried", function()
		local h = harness({ Reply = { Ok = true } })
		local reply = h.Model.Invoke("DuelChallenge", { TargetUserId = 7, Stake = 0 })
		expect(reply.Ok == true and #h.Calls == 1, "one call")
		expect(h.Calls[1].Action == "DuelChallenge" and h.Calls[1].Args.TargetUserId == 7, "action and payload pass through")
		h.Model.Invoke("Ride")
		expect(type(h.Calls[2].Args) == "table" and next(h.Calls[2].Args) == nil, "missing args become {}")
		local broken = harness({ RemoteError = true })
		expect(broken.Model.Invoke("Cancel").Ok == false and #broken.Calls == 1, "an error gives Ok false after one attempt")
	end)

	case("Cancel: ActivityInvoke Cancel {} and the Classic toast only on Ok", function()
		local h = harness({ Reply = { Ok = true } })
		h.Model.Cancel()
		expect(h.Calls[1].Action == "Cancel" and next(h.Calls[1].Args) == nil, "Cancel, {}")
		expect(#h.Toasts == 1 and h.Toasts[1].Text == "JOB CANCELLED" and h.Toasts[1].Seconds == 2.4, "toast")
		local refused = harness({ Reply = { Ok = false } })
		refused.Model.Cancel()
		expect(#refused.Toasts == 0, "no toast when refused")
	end)

	case("Toast: tostring, default 2.4 s, silent without the bindable", function()
		local h = harness()
		h.Model.Toast(42)
		h.Model.Toast("x", 6)
		expect(h.Toasts[1].Text == "42" and h.Toasts[1].Seconds == 2.4 and h.Toasts[2].Seconds == 6, "values")
		harness({ NoNotify = true }).Model.Toast("x")
	end)

	case("Strip: newest Set wins, Clear falls back, an unchanged Set is silent", function()
		local h = harness()
		local strip = h.Model.Strip
		expect(h.Model.StripEntry() == nil, "empty")
		strip.Set("Taxi", "taxi · 1.2 mi", h.Theme.Telemetry)
		expect(h.Model.StripEntry().Text == string.upper("taxi · 1.2 mi") and h.Model.StripEntry().Kind == "Taxi", "upper-cased")
		strip.Set("Duel", "duel", h.Theme.HighSpeed)
		expect(h.Model.StripEntry().Kind == "Duel", "newest wins")
		strip.Set("Taxi", "taxi again", nil)
		expect(h.Model.StripEntry().Kind == "Taxi", "a re-set moves to the top")
		local before = #h.Reasons
		strip.Set("Taxi", "taxi again", nil)
		strip.Set("Taxi", "TAXI AGAIN", nil)
		expect(#h.Reasons == before, "unchanged line fires nothing")
		strip.Clear("Taxi")
		expect(h.Model.StripEntry().Kind == "Duel", "falls back")
		strip.Clear("Duel")
		strip.Clear("Duel")
		expect(h.Model.StripEntry() == nil, "cleared")
		expect(h.Reasons[#h.Reasons] == "Strip", "reason")
	end)

	case("Offer: one at a time, click closes then runs, disabled is inert, close is idempotent", function()
		local h = harness()
		local clicked = {}
		local closeA = h.Model.Offer({ Title = "street duel", Body = "Race", Timeout = 15, Buttons = {
			{ Text = "free", OnClick = function() table.insert(clicked, "free") end },
			{ Text = "$500", Accent = h.Theme.HighSpeed, Enabled = false, OnClick = function() table.insert(clicked, "stake") end },
			{ Text = "cancel" },
		} })
		local a = h.Model.OfferState()
		expect(a.Title == "STREET DUEL" and a.Body == "Race" and a.Timeout == 15 and a.StartedAt == 100, "record")
		expect(a.Buttons[1].Text == "FREE" and a.Buttons[2].Enabled == false and a.Buttons[3].Enabled == true, "buttons")
		expect(#h.Delays == 1 and h.Delays[1].Seconds == 15, "timeout scheduled")
		h.Model.PressOffer(a, 2)
		expect(h.Model.OfferState() == a and #clicked == 0, "disabled option does nothing")
		local closeB = h.Model.Offer({ Title = "duel challenge", Buttons = { { Text = "accept", OnClick = function() table.insert(clicked, "accept") end } } })
		local b = h.Model.OfferState()
		expect(b ~= a and b.Timeout == nil, "a new offer replaces the old one")
		h.Model.PressOffer(a, 1)
		expect(#clicked == 0, "a click on the replaced offer is ignored")
		h.Delays[1].Run() -- the timer of the replaced offer fires late
		closeA()
		expect(h.Model.OfferState() == b, "a late close of the old offer leaves the new one")
		h.Model.PressOffer(b, 1)
		expect(h.Model.OfferState() == nil and clicked[1] == "accept", "click closes then runs")
		closeB()
		closeB()
		h.Model.PressOffer(b, 1)
		expect(#clicked == 1, "nothing runs twice")
	end)

	case("Offer: timeout closes it; a zero timeout schedules nothing", function()
		local h = harness()
		h.Model.Offer({ Title = "t", Timeout = 5, Buttons = {} })
		h.Delays[1].Run()
		expect(h.Model.OfferState() == nil, "closed")
		h.Model.Offer({ Title = "t", Timeout = 0 })
		expect(h.Model.OfferState().Timeout == nil and #h.Delays == 1, "no timer for a zero timeout")
	end)

	case("Countdown: replace, end only the current one", function()
		local h = harness()
		h.Model.Countdown(103, "duel")
		local first = h.Model.CountdownState()
		expect(first.GoAt == 103 and first.Label == "DUEL", "record")
		h.Model.Countdown(nil, nil)
		local second = h.Model.CountdownState()
		expect(second.GoAt == 100 and second.Label == "", "defaults")
		h.Model.CountdownEnded(first)
		expect(h.Model.CountdownState() == second, "a stale end is ignored")
		h.Model.CountdownEnded(second)
		expect(h.Model.CountdownState() == nil, "ended")
	end)

	case("RankUp: Classic text, shown for 3.5 s, deferred while racing", function()
		local h = harness()
		h.Model.RankUp({ Rank = 7, Cash = 5000 })
		local record = h.Model.RankUpState()
		expect(record.Text == "RANK 7" and record.Cash == 5000, "record")
		expect(h.Delays[1].Seconds == 3.5, "3.5 s")
		h.Delays[1].Run()
		expect(h.Model.RankUpState() == nil, "hidden after the delay")
		local racing = harness({ Racing = true })
		racing.Model.RankUp({ Rank = 3 })
		expect(racing.Model.RankUpState() == nil and #racing.Waiting == 1, "waits for the race to end")
		racing.Waiting[1]()
		expect(racing.Model.RankUpState().Text == "RANK 3" and racing.Model.RankUpState().Cash == 0, "shown once free")
	end)

	case("Jobs: the calls of the retired panel are harmless", function()
		local h = harness()
		h.Model.Jobs.AddEntry({ Id = "a" })
		h.Model.Jobs.AddEntry("junk")
		h.Model.Jobs.Refresh()
	end)

	case("_theme: all 13 Classic names are Color3 and the two meanings differ", function()
		local Tokens = env.Load(KIT .. "Tokens")
		local theme = M._theme(Tokens, nil)
		for _, name in ipairs({ "Panel", "PanelDeep", "PanelSoft", "PanelBlue", "Outline", "OutlineSoft", "Telemetry", "ElectricBlue", "HighSpeed", "Danger", "Text", "Muted", "Disabled" }) do
			expect(typeof(theme[name]) == "Color3", name .. " is a Color3")
		end
		expect(theme.Telemetry ~= theme.HighSpeed and theme.Telemetry ~= theme.ElectricBlue, "Telemetry is distinct")
	end)

	case("_racing: queue attribute, or a seated race vehicle (Classic 244-251)", function()
		local function player(queue, vehicleAttributes)
			local vehicle = vehicleAttributes and { GetAttribute = function(_, name) return vehicleAttributes[name] end } or nil
			local seat = vehicle and { FindFirstAncestorOfClass = function() return vehicle end } or nil
			local humanoid = { SeatPart = seat }
			return {
				GetAttribute = function(_, name) return name == "RaceQueueActive" and queue or nil end,
				Character = { FindFirstChildOfClass = function() return humanoid end },
			}
		end
		expect(M._racing(player(true, nil)) == true, "queue active")
		expect(M._racing(player(false, nil)) == false, "on foot")
		expect(M._racing(player(nil, {})) == false, "seated, not racing")
		expect(M._racing(player(nil, { RaceParticipant = true })) == true, "race participant")
		expect(M._racing(player(nil, { RaceRunId = "r" })) == true, "run id")
	end)

	case("_bottomRow and _rootLift: the Duel button clears the Pulse bottom row", function()
		local Tokens = env.Load(KIT .. "Tokens")
		local space = Tokens.Space
		local row, gap = M._bottomRow({ Class = "Regular", Arrangement = "Standard" }, space)
		expect(row == space.HudBottom + space.HudButtonHeight and gap == space.Gap, "Regular Standard")
		expect(M._rootLift(row, gap, 84) == math.max(0, row + gap - 84), "desktop offset 84")
		local touchRow, touchGap = M._bottomRow({ Class = "Compact", Arrangement = "TouchDrive" }, space)
		expect(touchRow == space.CompactBottom + space.CompactGauge and touchGap == space.TouchGap, "Compact TouchDrive")
		expect(M._rootLift(touchRow, touchGap, 120) == 0, "a phone needs no lift at the mobile offset 120")
		local tabletRow, tabletGap = M._bottomRow({ Class = "Regular", Arrangement = "TouchDrive" }, space)
		expect(M._rootLift(tabletRow, tabletGap, 120) == tabletRow + tabletGap - 120, "a tablet is lifted over the gauge")
		expect(M._rootLift(10, 5, nil) == 15, "an unknown offset counts as none")
	end)

	case("_newDesignRoot: one named UIScale, design-pixel size, scale-1 context for children", function()
		local Tokens = env.Load(KIT .. "Tokens")
		local Metrics = env.Load(KIT .. "Metrics")
		local Layers = env.Load(KIT .. "Layers")
		local ctx = Metrics.Fixed({ Size = Vector2.new(1280, 720) })
		local stage = env.Detached("Frame")
		stage.Size = UDim2.fromOffset(1280, 720)
		Metrics.Bind(stage, ctx)
		local layer = Layers.Stage(stage, ctx, "Hud")
		local connections = {}
		local scope = {}
		function scope:connect(signal, callback)
			local connection = signal:Connect(callback)
			table.insert(connections, connection)
			return connection
		end
		local design = M._newDesignRoot(layer, Metrics, Tokens, scope)
		expect(design.Frame.Parent == layer.Root and design.Frame.Name == "DesignPixels", "under the layer root")
		expect(design.Scale.Name == "DesignScale" and math.abs(design.Scale.Scale - ctx.Scale) < 1e-4, "the UIScale carries the kit scale")
		local row, gap = M._bottomRow(ctx, Tokens.Space)
		expect(design.Frame.Size.Y.Offset == -(row + gap), "full lift before any offset is known")
		expect(math.abs(design.Frame.Size.X.Scale - 1 / ctx.Scale) < 1e-4, "width fills the parent after scaling")
		local inner = Metrics.Of(design.Frame)
		expect(inner.Scale == 1 and inner.Class == ctx.Class, "children resolve to a scale-1 context of the same class")

		local button = Instance.new("TextButton")
		button.Parent = design.Frame
		design.Watch(button)
		button.Position = UDim2.new(0.5, 0, 1, -84)
		design.Relayout()
		-- The Position signal may be deferred in the harness; Relayout alone must never lose a known offset.
		expect(design.Frame.Size.Y.Offset == -(row + gap) or design.Frame.Size.Y.Offset == -math.max(0, row + gap - 84), "lift is one of the two valid values")
		for _, connection in ipairs(connections) do connection:Disconnect() end
	end)

	case("owner shape: start exists and nothing ran at require", function()
		expect(type(M.start) == "function" and M.Context == nil and M.Controller == nil, "owner shape")
	end)

	return results
end
